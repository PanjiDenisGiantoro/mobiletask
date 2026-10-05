import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Base URL API ProjectHub Pro (Laravel, lihat /root/projecthub_pro/routes/api.php).
const String kApiBaseUrl = 'https://flovig.com/api';

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

  const AuthUser({required this.id, required this.name, required this.email, required this.roles});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List? ?? const [])
        .map((r) => r is Map ? '${r['name']}' : '$r')
        .toList();
    return AuthUser(
      id: json['id'] as int,
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      roles: roles,
    );
  }
}

/// Sesi login ke flovig.com via endpoint Sanctum `/auth/login`, `/auth/me`,
/// `/auth/logout`. Token disimpan di secure storage (Keychain/Keystore)
/// supaya sesi bertahan setelah aplikasi ditutup.
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  final _storage = const FlutterSecureStorage();

  String? _token;
  AuthUser? _user;

  String? get token => _token;
  AuthUser? get currentUser => _user;
  bool get isLoggedIn => _token != null;

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
      return _user!;
    }
    if (res.statusCode == 422) throw const AuthException('Email atau password salah');
    if (res.statusCode == 403) throw const AuthException('Akun Anda tidak aktif');
    throw AuthException('${body['message'] ?? 'Login gagal (${res.statusCode})'}');
  }

  /// Memulihkan sesi tersimpan saat aplikasi dibuka. Token divalidasi ke
  /// `/auth/me`; kalau server menolak (401) sesi dihapus, kalau server tidak
  /// terjangkau sesi tersimpan tetap dipakai.
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
          .get(Uri.parse('$kApiBaseUrl/auth/me'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final userJson = _decode(res.body);
        _user = AuthUser.fromJson(userJson);
        await _persist(userJson);
      } else if (res.statusCode == 401) {
        await _clearSession();
        return false;
      }
    } catch (_) {
      // Offline: tetap pakai sesi tersimpan.
    }
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
