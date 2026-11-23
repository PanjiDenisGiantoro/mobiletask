import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Mengelola preferensi tampilan (Dark Mode) dan bahasa (Indonesia / Inggris)
/// secara global dengan penyimpanan persisten.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _storage = FlutterSecureStorage();
  static const _themeKey = 'app_theme_mode';
  static const _localeKey = 'app_locale';
  static const _readNotifsKey = 'read_notification_ids';
  static const _notifEnabledKey = 'app_notifications_enabled';

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('id');
  bool _notificationsEnabled = true;
  final Set<String> _readNotificationIds = {};

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isIndonesian => _locale.languageCode == 'id';
  bool get notificationsEnabled => _notificationsEnabled;

  bool isNotificationRead(String id) => _readNotificationIds.contains(id);

  Future<void> load() async {
    try {
      final savedTheme = await _storage.read(key: _themeKey);
      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      }

      final savedLocale = await _storage.read(key: _localeKey);
      if (savedLocale == 'en' || savedLocale == 'id') {
        _locale = Locale(savedLocale!);
      }

      final savedRead = await _storage.read(key: _readNotifsKey);
      if (savedRead != null && savedRead.isNotEmpty) {
        _readNotificationIds
          ..clear()
          ..addAll(savedRead.split(',').where((e) => e.isNotEmpty));
      }

      final savedNotif = await _storage.read(key: _notifEnabledKey);
      if (savedNotif != null) {
        _notificationsEnabled = savedNotif != '0';
      }
    } catch (_) {
      // Fallback ke default (light, id) jika storage belum tersedia.
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();
    try {
      await _storage.write(key: _notifEnabledKey, value: enabled ? '1' : '0');
    } catch (_) {}
  }

  Future<void> markNotificationRead(String id) async {
    if (_readNotificationIds.add(id)) {
      notifyListeners();
      try {
        await _storage.write(
          key: _readNotifsKey,
          value: _readNotificationIds.join(','),
        );
      } catch (_) {}
    }
  }

  Future<void> markAllNotificationsRead(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      if (_readNotificationIds.add(id)) changed = true;
    }
    if (changed) {
      notifyListeners();
      try {
        await _storage.write(
          key: _readNotifsKey,
          value: _readNotificationIds.join(','),
        );
      } catch (_) {}
    }
  }

  Future<void> setDarkMode(bool dark) async {
    final next = dark ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == next) return;
    _themeMode = next;
    notifyListeners();
    try {
      await _storage.write(key: _themeKey, value: dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    if (code != 'id' && code != 'en') return;
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    notifyListeners();
    try {
      await _storage.write(key: _localeKey, value: code);
    } catch (_) {}
  }
}
