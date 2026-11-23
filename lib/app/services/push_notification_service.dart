import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../../router.dart';
import '../data/auth_repository.dart';
import '../data/ph_store.dart';
import '../theme/app_settings.dart';

/// Handler pesan FCM saat aplikasi di background / terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Mengelola Push Notification (FCM + Local Notifications) untuk Flovig.
/// - Aman dijalankan walau `google-services.json` belum dipasang (fallback ke local notifications).
/// - Saat `google-services.json` tersedia, otomatis registrasi FCM token ke backend
///   (`POST /api/device-tokens`) dan menavigasikan tap notifikasi ke layar tujuan.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _channelId = 'flovig_high_importance';
  static const _channelName = 'Flovig Updates';
  static const _channelDesc = 'Notifikasi update proyek, tugas, tiket, dan pesan Flovig';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _localReady = false;
  bool _firebaseReady = false;
  String? _lastToken;

  bool get isFirebaseReady => _firebaseReady;
  String? get currentToken => _lastToken;

  Future<void> init() async {
    await _initLocalNotifications();
    await _initFirebaseMessaging();
  }

  Future<void> _initLocalNotifications() async {
    if (_localReady || kIsWeb) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: darwinInit),
        onDidReceiveNotificationResponse: (resp) {
          final payload = resp.payload;
          if (payload != null && payload.isNotEmpty) {
            _navigateFromRoute(payload);
          }
        },
      );

      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
      _localReady = true;
    } catch (e) {
      debugPrint('[PushNotificationService] Local init skipped: $e');
    }
  }

  Future<void> _initFirebaseMessaging() async {
    if (_firebaseReady || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      // Normal bila google-services.json belum dipasang.
      debugPrint('[PushNotificationService] Firebase not configured yet: $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final fcm = FirebaseMessaging.instance;

      await fcm.requestPermission(alert: true, badge: true, sound: true);
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Pesan masuk saat aplikasi sedang terbuka (foreground) -> tampilkan heads-up banner
      // hanya jika sesuai company aktif dan proyek yang diikuti user.
      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        if (!AppSettings.instance.notificationsEnabled) return;
        if (!_matchesCompanyAndJoinedProject(msg.data)) return;
        final notif = msg.notification;
        final title = notif?.title ?? '${msg.data['title'] ?? 'Flovig'}';
        final body = notif?.body ?? '${msg.data['body'] ?? ''}';
        if (title.isEmpty && body.isEmpty) return;
        showLocalNotification(
          id: msg.hashCode,
          title: title,
          body: body,
          route: _routeFromData(msg.data),
        );
      });

      // Tap notifikasi dari background.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
        final route = _routeFromData(msg.data);
        if (route != null) _navigateFromRoute(route);
      });

      // Tap notifikasi saat aplikasi dibuka dari kondisi terminated.
      final initial = await fcm.getInitialMessage();
      if (initial != null) {
        final route = _routeFromData(initial.data);
        if (route != null) {
          Future.delayed(const Duration(milliseconds: 600), () => _navigateFromRoute(route));
        }
      }

      // Sinkron ulang bila FCM token dirotasi.
      fcm.onTokenRefresh.listen((newToken) {
        _lastToken = newToken;
        if (AuthRepository.instance.isLoggedIn && AppSettings.instance.notificationsEnabled) {
          _sendTokenToBackend(newToken);
        }
      });

      _lastToken = await fcm.getToken();
      if (AuthRepository.instance.isLoggedIn &&
          AppSettings.instance.notificationsEnabled &&
          _lastToken != null) {
        await _sendTokenToBackend(_lastToken!);
      }
    } catch (e) {
      debugPrint('[PushNotificationService] FCM setup error: $e');
    }
  }

  /// Kirim FCM token perangkat ke backend (`POST /api/device-tokens`).
  Future<void> syncTokenWithBackend() async {
    if (!_firebaseReady || !AuthRepository.instance.isLoggedIn) return;
    if (!AppSettings.instance.notificationsEnabled) return;
    try {
      final token = _lastToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _lastToken = token;
      await _sendTokenToBackend(token);
    } catch (_) {}
  }

  /// Cabut FCM token perangkat di backend (`DELETE /api/device-tokens`) saat logout / notif dimatikan.
  Future<void> unregisterTokenFromBackend() async {
    if (!_firebaseReady) return;
    final authToken = AuthRepository.instance.token;
    if (authToken == null || authToken.isEmpty) return;
    try {
      final fcmToken = _lastToken ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;
      await http
          .delete(
            Uri.parse('$kApiBaseUrl/device-tokens'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  String _activeCompanyId() {
    final raw = AuthRepository.instance.currentUser?.raw;
    final comp = raw?['company'];
    final cid = raw?['company_id'] ?? (comp is Map ? comp['id'] : null);
    return cid == null ? '' : '$cid'.trim();
  }

  /// Guard sisi mobile: pastikan push berasal dari company aktif dan proyek yang
  /// benar-benar diikuti user (member, manager, atau client proyek).
  bool _matchesCompanyAndJoinedProject(Map<String, dynamic> data) {
    final myCompanyId = _activeCompanyId();
    final msgCompanyId = '${data['company_id'] ?? ''}'.trim();
    if (myCompanyId.isNotEmpty && msgCompanyId.isNotEmpty && msgCompanyId != myCompanyId) {
      return false;
    }

    final rawPid = '${data['project_id'] ?? (data['type'] == 'project' ? data['id'] : '')}'.trim();
    final pid = int.tryParse(rawPid);
    if (pid != null && pid > 0 && PhStore.instance.projects.isNotEmpty) {
      final project = PhStore.instance.projectById(pid);
      if (project == null) return false;
      final meId = PhStore.meId;
      final joined = project.managerId == meId ||
          project.clientId == meId ||
          project.members.any((m) => m.userId == meId);
      if (!joined) return false;
    }
    return true;
  }

  Future<void> _sendTokenToBackend(String fcmToken) async {
    final authToken = AuthRepository.instance.token;
    if (authToken == null || authToken.isEmpty) return;
    final platform = kIsWeb
        ? 'web'
        : (Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'));
    final companyId = _activeCompanyId();
    try {
      await http
          .post(
            Uri.parse('$kApiBaseUrl/device-tokens'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'token': fcmToken,
              'platform': platform,
              if (companyId.isNotEmpty) 'company_id': companyId,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Tidak memblokir alur login bila endpoint backend belum tersedia.
    }
  }

  /// Tampilkan notifikasi lokal pada status bar HP (bisa dipakai foreground maupun trigger lokal).
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!_localReady || !AppSettings.instance.notificationsEnabled) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _local.show(id, title, body, details, payload: route);
  }

  String? _routeFromData(Map<String, dynamic> data) {
    final route = '${data['route'] ?? ''}'.trim();
    if (route.startsWith('/')) return route;
    final type = '${data['type'] ?? ''}'.toLowerCase().trim();
    final id = '${data['id'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    switch (type) {
      case 'task':
        return '/task/$id';
      case 'ticket':
        return '/ticket/$id';
      case 'project':
        return '/project/$id';
      case 'chat':
      case 'dm':
        return '/thread/${Uri.encodeComponent('dm:$id')}';
      default:
        return null;
    }
  }

  void _navigateFromRoute(String route) {
    if (!AuthRepository.instance.isLoggedIn) return;
    try {
      appRouter.push(route);
    } catch (_) {}
  }
}
