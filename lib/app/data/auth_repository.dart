import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import '../services/push_notification_service.dart';

/// Base URL API ProjectHub Pro (Laravel, lihat /root/projecthub_pro/routes/api.php).
const String kApiBaseUrl = 'https://flovig.com/api';

/// Base URL file publik Laravel (storage:link) — path relatif dari API
/// (mis. "project-images/xxx.jpg") diakses lewat sini, bukan [kApiBaseUrl].
const String kStorageBaseUrl = 'https://flovig.com/storage';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthUser {
  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final Map<String, dynamic> raw;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.raw = const {},
  });

  bool get isAdmin => roles.any((r) {
        final low = r.toLowerCase().trim();
        return low == 'admin' ||
            low == 'owner' ||
            low == 'super_admin' ||
            low == 'superadmin' ||
            low == 'administrator';
      });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List? ?? const [])
        .map((r) => r is Map ? '${r['name']}' : '$r')
        .toList();
    return AuthUser(
      id: json['id'] as int,
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      roles: roles,
      raw: json,
    );
  }
}

/// Sesi login ke flovig.com via endpoint Sanctum `/auth/login`,
/// `/auth/refresh`, `/auth/logout`. Token disimpan di secure storage
/// (Keychain/Keystore) supaya sesi bertahan setelah aplikasi ditutup.
///
/// Token kedaluwarsa 30 hari setelah terakhir diperpanjang; setiap aplikasi
/// dibuka [restoreSession] memperpanjangnya, jadi hanya akun yang lama tidak
/// membuka aplikasi yang harus login ulang.
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _bioEmailKey = 'bio_email';
  static const _bioPasswordKey = 'bio_password';
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  String? _token;
  AuthUser? _user;

  String? get token => _token;
  AuthUser? get currentUser => _user;
  bool get isLoggedIn => _token != null;

  /// Dipanggil sekali saat server menolak token sesi aktif (kedaluwarsa atau
  /// dicabut), setelah sesi lokal dihapus. Dipasang di `main.dart`.
  void Function()? onSessionExpired;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Hanya untuk test: pasang sesi tanpa lewat layar login.
  @visibleForTesting
  void debugSetSession(String token, AuthUser user) {
    _token = token;
    _user = user;
  }

  Future<AuthUser> login(String email, String password) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$kApiBaseUrl/auth/login'),
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const AuthException('Server tidak merespons, coba lagi');
    } catch (_) {
      throw const AuthException('Tidak dapat terhubung ke server');
    }

    final body = _decode(res.body);
    if (res.statusCode == 200) {
      _token = body['token'] as String;
      final userJson = body['user'] as Map<String, dynamic>;
      _user = AuthUser.fromJson(userJson);
      await _persist(userJson);
      await _saveBiometricCredentials(email, password);
      unawaited(PushNotificationService.instance.syncTokenWithBackend());
      return _user!;
    }
    if (res.statusCode == 422) throw const AuthException('Email atau password salah');
    if (res.statusCode == 403) throw const AuthException('Akun Anda tidak aktif');
    throw AuthException('${body['message'] ?? 'Login gagal (${res.statusCode})'}');
  }

  /// Memulihkan sesi tersimpan saat aplikasi dibuka. Token divalidasi dan
  /// diperpanjang lewat `/auth/refresh`; kalau server menolak (401) sesi
  /// dihapus, kalau server tidak terjangkau sesi tersimpan tetap dipakai.
  Future<bool> restoreSession() async {
    try {
      _token = await _storage.read(key: _tokenKey);
      final rawUser = await _storage.read(key: _userKey);
      if (rawUser != null) _user = AuthUser.fromJson(_decode(rawUser));
    } catch (_) {
      _token = null;
    }
    if (_token == null) return false;

    try {
      final res = await http
          .post(Uri.parse('$kApiBaseUrl/auth/refresh'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final userJson = _decode(res.body)['user'] as Map<String, dynamic>;
        _user = AuthUser.fromJson(userJson);
        await _persist(userJson);
      } else if (res.statusCode == 401) {
        await _clearSession();
        return false;
      }
    } catch (_) {
      // Offline: tetap pakai sesi tersimpan.
    }
    unawaited(PushNotificationService.instance.syncTokenWithBackend());
    return true;
  }

  /// Sesi lokal dibuang lebih dulu, baru token dicabut di server tanpa
  /// ditunggu. Kalau urutannya dibalik, login ulang yang terjadi selama
  /// request logout berjalan ikut terhapus saat request itu selesai.
  Future<void> logout() async {
    final token = _token;
    await _clearSession();
    if (token == null) return;
    unawaited(http
        .post(
          Uri.parse('$kApiBaseUrl/auth/logout'),
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10))
        .then((_) {}, onError: (_) {}));
  }

  /// Respons 401 untuk request yang dikirim dengan [sentToken]. Diabaikan
  /// kalau sesi sudah berganti (mis. request lama selesai setelah login ulang)
  /// atau sudah ditangani oleh 401 lain yang datang bersamaan.
  Future<void> handleUnauthorized(String? sentToken) async {
    if (sentToken == null || sentToken != _token) return;
    await _clearSession();
    onSessionExpired?.call();
  }

  Future<void> _saveBiometricCredentials(String email, String password) async {
    try {
      await _storage.write(key: _bioEmailKey, value: email);
      await _storage.write(key: _bioPasswordKey, value: password);
    } catch (_) {}
  }

  /// Muat profil terbaru milik user yang sedang login dari `GET /profile`.
  Future<AuthUser> fetchProfile() async {
    final http.Response res;
    try {
      res = await http
          .get(Uri.parse('$kApiBaseUrl/profile'), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('Server tidak merespons, coba lagi');
    } catch (_) {
      throw const AuthException('Tidak dapat terhubung ke server');
    }
    final body = _decode(res.body);
    if (res.statusCode == 200) {
      final data = body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : body;
      _user = AuthUser.fromJson(data);
      await _persist(data);
      return _user!;
    }
    throw AuthException('${body['message'] ?? 'Gagal memuat profil (${res.statusCode})'}');
  }

  /// Perbarui profil pengguna via `PUT /profile`.
  Future<AuthUser> updateProfile({
    String? name,
    String? timezone,
    bool? emailNotificationsEnabled,
  }) async {
    final payload = <String, Object?>{
      if (name != null) 'name': name.trim(),
      if (timezone != null) 'timezone': timezone,
      if (emailNotificationsEnabled != null) 'email_notifications_enabled': emailNotificationsEnabled,
    };
    final http.Response res;
    try {
      res = await http
          .put(Uri.parse('$kApiBaseUrl/profile'), headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('Server tidak merespons, coba lagi');
    } catch (_) {
      throw const AuthException('Tidak dapat terhubung ke server');
    }
    final body = _decode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : body;
      _user = AuthUser.fromJson(data);
      await _persist(data);
      return _user!;
    }
    throw AuthException(_extractError(body, 'Gagal memperbarui profil (${res.statusCode})'));
  }

  /// Unggah foto profil baru via `POST /profile/avatar` (multipart field `avatar`).
  Future<AuthUser> uploadAvatar(List<int> bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$kApiBaseUrl/profile/avatar'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      })
      ..files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: filename));

    final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
    } on TimeoutException {
      throw const AuthException('Unggah foto terlalu lama, coba lagi');
    } catch (_) {
      throw const AuthException('Tidak dapat terhubung ke server');
    }
    final body = _decode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : body;
      _user = AuthUser.fromJson(data);
      await _persist(data);
      return _user!;
    }
    throw AuthException(_extractError(body, 'Gagal mengunggah foto profil (${res.statusCode})'));
  }

  /// Hapus foto profil saat ini via `DELETE /profile/avatar`.
  Future<AuthUser> deleteAvatar() async {
    final http.Response res;
    try {
      res = await http
          .delete(Uri.parse('$kApiBaseUrl/profile/avatar'), headers: _headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('Server tidak merespons, coba lagi');
    } catch (_) {
      throw const AuthException('Tidak dapat terhubung ke server');
    }
    final body = _decode(res.body);
    if (res.statusCode == 200) {
      final data = body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : body;
      _user = AuthUser.fromJson(data);
      await _persist(data);
      return _user!;
    }
    throw AuthException(_extractError(body, 'Gagal menghapus foto profil (${res.statusCode})'));
  }

  /// Ubah password akun melalui `PUT /profile/password`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final payload = {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': confirmPassword,
    };
    final http.Response res;
    try {
      res = await http
          .put(Uri.parse('$kApiBaseUrl/profile/password'), headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('Server tidak merespons, coba lagi');
    } catch (_) {
      throw const AuthException('Tidak dapat terhubung ke server');
    }
    final body = _decode(res.body);
    if (res.statusCode == 200 || res.statusCode == 204) {
      final bioEmail = await _storage.read(key: _bioEmailKey);
      if (bioEmail != null && bioEmail.isNotEmpty) {
        await _saveBiometricCredentials(bioEmail, newPassword);
      }
      return;
    }
    throw AuthException(_extractError(body, 'Gagal memperbarui password (${res.statusCode})'));
  }

  /// Kirim permintaan lupa password (`POST /auth/forgot-password`).
  /// Mengembalikan `(message, resendAfterSeconds)`.
  Future<(String, int)> forgotPassword(String email) async {
    late final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$kApiBaseUrl/auth/forgot-password'),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('Server tidak merespons, coba lagi');
    } catch (_) {
      throw const AuthException('Tidak dapat terhubung ke server');
    }
    final body = _decode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      final msg = '${body['message'] ?? ''}'.trim();
      final resendRaw = body['resend_after'];
      final resendAfter = resendRaw is num ? resendRaw.toInt() : (int.tryParse('$resendRaw') ?? 60);
      return (
        msg.isNotEmpty ? msg : 'Jika email terdaftar, token reset password sudah dikirim.',
        resendAfter > 0 ? resendAfter : 60,
      );
    }
    throw AuthException(_extractError(body, 'Gagal mengirim token reset (${res.statusCode})'));
  }

  /// Reset password menggunakan token 64 karakter dari email (`POST /auth/reset-password`).
  Future<String> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    late final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$kApiBaseUrl/auth/reset-password'),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'email': email,
              'token': token,
              'password': password,
              'password_confirmation': confirmPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('Server tidak merespons, coba lagi');
    } catch (_) {
      throw const AuthException('Tidak dapat terhubung ke server');
    }
    final body = _decode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      final msg = '${body['message'] ?? ''}'.trim();
      return msg.isNotEmpty ? msg : 'Password berhasil direset. Silakan login dengan password baru.';
    }
    throw AuthException(_extractError(body, 'Gagal mereset password (${res.statusCode})'));
  }

  String _extractError(Map<String, dynamic> body, String fallback) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstVal = errors.values.first;
      if (firstVal is List && firstVal.isNotEmpty) return '${firstVal.first}';
      if (firstVal != null) return '$firstVal';
    }
    final msg = '${body['message'] ?? ''}'.trim();
    return msg.isNotEmpty ? msg : fallback;
  }

  Future<bool> hasBiometricCredentials() async {
    try {
      final email = await _storage.read(key: _bioEmailKey);
      final pass = await _storage.read(key: _bioPasswordKey);
      return email != null && email.isNotEmpty && pass != null && pass.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Login cepat dengan sidik jari / Face ID menggunakan kredensial aman
  /// yang tersimpan saat login manual sebelumnya.
  Future<AuthUser> loginWithBiometrics() async {
    if (kIsWeb) {
      throw const AuthException('Login sidik jari hanya tersedia di aplikasi Android / iOS');
    }
    final email = await _storage.read(key: _bioEmailKey);
    final pass = await _storage.read(key: _bioPasswordKey);
    if (email == null || email.isEmpty || pass == null || pass.isEmpty) {
      throw const AuthException('Silakan login dengan email & password terlebih dahulu untuk mengaktifkan sidik jari');
    }

    bool supported = false;
    try {
      supported = await _localAuth.isDeviceSupported() || await _localAuth.canCheckBiometrics;
    } catch (_) {
      supported = false;
    }
    if (!supported) {
      throw const AuthException('Perangkat ini tidak mendukung autentikasi biometrik / sidik jari');
    }

    final bool ok;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah untuk masuk ke Flovig',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      throw AuthException('Autentikasi sidik jari gagal: $e');
    }
    if (!ok) {
      throw const AuthException('Verifikasi sidik jari dibatalkan');
    }
    return login(email, pass);
  }

  /// Gagal simpan (mis. web tanpa HTTPS, Web Crypto tidak tersedia) tidak
  /// menggagalkan login; sesi hanya tidak bertahan setelah aplikasi ditutup.
  Future<void> _persist(Map<String, dynamic> userJson) async {
    try {
      await _storage.write(key: _tokenKey, value: _token);
      await _storage.write(key: _userKey, value: jsonEncode(userJson));
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (_) {}
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }
}
