import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../stitch_frontend_interface_application/auth_repository.dart';

/// File yang diunggah lewat [PhApi.upload].
class ApiFile {
  final String field;
  final String name;
  final List<int> bytes;
  const ApiFile(this.field, this.name, this.bytes);
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, [this.statusCode = 0]);

  @override
  String toString() => message;
}

/// Klien HTTP ke API ProjectHub Pro (`/root/projecthub_pro/routes/api.php`).
/// Token Sanctum diambil dari [AuthRepository].
class PhApi {
  PhApi._();
  static final PhApi instance = PhApi._();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (AuthRepository.instance.token != null) 'Authorization': 'Bearer ${AuthRepository.instance.token}',
      };

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Map<String, Object?>? body]) => _send('POST', path, body);
  Future<dynamic> put(String path, [Map<String, Object?>? body]) => _send('PUT', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);
  Future<dynamic> patch(String path, [Map<String, Object?>? body]) => _send('PATCH', path, body);

  /// POST multipart untuk unggah file. [fields] dikirim sebagai teks; nilai
  /// List dikirim sebagai `key[]` (format array Laravel), bool sebagai 1/0.
  Future<dynamic> upload(String path, Map<String, Object?> fields, List<ApiFile> files) async {
    final req = http.MultipartRequest('POST', Uri.parse('$kApiBaseUrl$path'))
      ..headers.addAll({..._headers}..remove('Content-Type'));
    fields.forEach((k, v) {
      if (v == null) return;
      if (v is List) {
        for (var i = 0; i < v.length; i++) {
          req.fields['$k[$i]'] = '${v[i]}';
        }
      } else {
        req.fields[k] = v is bool ? (v ? '1' : '0') : '$v';
      }
    });
    for (final f in files) {
      req.files.add(http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.name));
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
    } on TimeoutException {
      throw const ApiException('Unggah file terlalu lama, coba lagi');
    } catch (_) {
      throw const ApiException('Tidak dapat terhubung ke server');
    }
    return _handle(res);
  }

  /// Mengambil semua halaman dari endpoint Laravel `paginate()`.
  Future<List<Map<String, dynamic>>> getAll(String path) async {
    final out = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final sep = path.contains('?') ? '&' : '?';
      final res = await get('$path${sep}page=$page');
      if (res is List) return res.whereType<Map<String, dynamic>>().toList();
      if (res is! Map<String, dynamic>) return out;
      out.addAll((res['data'] as List? ?? const []).whereType<Map<String, dynamic>>());
      final last = res['last_page'] as int? ?? 1;
      if (page >= last || page >= 50) return out;
      page++;
    }
  }

  Future<dynamic> _send(String method, String path, [Map<String, Object?>? body]) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 20)));
    } on TimeoutException {
      throw const ApiException('Server tidak merespons, coba lagi');
    } catch (_) {
      throw const ApiException('Tidak dapat terhubung ke server');
    }
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    dynamic decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    final msg = decoded is Map ? _errorMessage(decoded) : null;
    throw ApiException(
      switch (res.statusCode) {
        401 => 'Sesi berakhir, silakan login ulang',
        403 => msg ?? 'Anda tidak punya akses untuk aksi ini',
        404 => 'Data tidak ditemukan',
        _ => msg ?? 'Permintaan gagal (${res.statusCode})',
      },
      res.statusCode,
    );
  }

  /// Pesan validasi Laravel: ambil error field pertama bila ada.
  String? _errorMessage(Map decoded) {
    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return '${first.first}';
    }
    final m = decoded['message'];
    return m is String && m.isNotEmpty ? m : null;
  }
}
