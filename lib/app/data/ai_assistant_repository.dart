import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_repository.dart';

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

class AiProposedAction {
  final String tool;
  final String label;
  final Map<String, dynamic> args;

  const AiProposedAction({
    required this.tool,
    required this.label,
    required this.args,
  });

  factory AiProposedAction.fromJson(Map<String, dynamic> j) => AiProposedAction(
        tool: '${j['tool'] ?? ''}',
        label: '${j['label'] ?? ''}',
        args: j['args'] is Map ? Map<String, dynamic>.from(j['args'] as Map) : const {},
      );
}

class AiExecuteResult {
  final String message;
  final int? projectId;
  final int? taskId;

  const AiExecuteResult({
    required this.message,
    this.projectId,
    this.taskId,
  });

  String? get nativeRoute {
    if (taskId != null && taskId! > 0) return '/task/$taskId';
    if (projectId != null && projectId! > 0) return '/project/$projectId';
    return null;
  }
}

class AiChatMessage {
  final String role; // 'user' | 'assistant'
  String content;
  AiProposedAction? action;
  bool actionExecuting;
  bool actionExecuted;
  bool actionDismissed;
  String? actionResultMessage;
  String? actionRoute;
  bool isStreaming;
  bool isError;

  AiChatMessage({
    required this.role,
    this.content = '',
    this.action,
    this.actionExecuting = false,
    this.actionExecuted = false,
    this.actionDismissed = false,
    this.actionResultMessage,
    this.actionRoute,
    this.isStreaming = false,
    this.isError = false,
  });
}

sealed class AiChatEvent {}

class AiTextChunkEvent extends AiChatEvent {
  final String chunk;
  AiTextChunkEvent(this.chunk);
}

class AiActionProposalEvent extends AiChatEvent {
  final AiProposedAction action;
  final String reply;
  AiActionProposalEvent(this.action, this.reply);
}

/// Repository untuk AI Assistant (Runa):
/// - `POST /ai/chat` (streaming `text/plain` maupun JSON usulan aksi)
/// - `POST /ai/execute-action` (eksekusi buat proyek/task terkonfirmasi)
class AiAssistantRepository extends ChangeNotifier {
  AiAssistantRepository._();
  static final AiAssistantRepository instance = AiAssistantRepository._();

  final List<AiChatMessage> messages = [];

  void clear() {
    messages.clear();
    notifyListeners();
  }

  Map<String, String> _headers() {
    final token = AuthRepository.instance.token ?? '';
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Bangun payload maksimal 20 pesan terakhir (user/assistant) untuk `/ai/chat`.
  List<Map<String, String>> buildHistoryPayload() {
    final valid = messages
        .where((m) => !m.isError && m.content.trim().isNotEmpty)
        .toList();
    final tail = valid.length > 20 ? valid.sublist(valid.length - 20) : valid;
    return tail.map((m) {
      final text = m.content.trim();
      return {
        'role': m.role == 'assistant' ? 'assistant' : 'user',
        'content': text.length > 4000 ? text.substring(0, 4000) : text,
      };
    }).toList();
  }

  /// Kirim percakapan ke `POST /ai/chat` (timeout minimal 120 detik).
  Stream<AiChatEvent> sendChat(List<Map<String, String>> history) async* {
    final client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse('$kApiBaseUrl/ai/chat'))
        ..headers.addAll(_headers())
        ..body = jsonEncode({'messages': history});

      final res = await client
          .send(req)
          .timeout(const Duration(seconds: 120));

      final contentType = (res.headers['content-type'] ?? '').toLowerCase();

      if (res.statusCode == 401) {
        AuthRepository.instance.onSessionExpired?.call();
        throw const AiException('Sesi login kedaluwarsa. Silakan masuk ulang.');
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final rawBody = await res.stream.bytesToString();
        throw AiException(_extractError(rawBody, res.statusCode));
      }

      if (contentType.startsWith('text/plain')) {
        await for (final chunk in res.stream
            .transform(utf8.decoder)
            .timeout(const Duration(seconds: 120))) {
          if (chunk.isNotEmpty) {
            yield AiTextChunkEvent(chunk);
          }
        }
      } else {
        final rawBody = await res.stream
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 120));
        final decoded = _tryDecode(rawBody);
        final actionJson = decoded['action'];
        final reply = '${decoded['reply'] ?? ''}'.trim();
        if (actionJson is Map<String, dynamic>) {
          yield AiActionProposalEvent(AiProposedAction.fromJson(actionJson), reply);
        } else {
          final fallback = reply.isNotEmpty
              ? reply
              : '${decoded['error'] ?? decoded['message'] ?? rawBody}'.trim();
          if (fallback.isNotEmpty) yield AiTextChunkEvent(fallback);
        }
      }
    } on TimeoutException {
      throw const AiException(
        'AI Assistant sedang sibuk/lambat merespons. Coba lagi sesaat lagi.',
      );
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException('Tidak dapat terhubung ke AI Assistant.');
    } finally {
      client.close();
    }
  }

  /// Eksekusi aksi yang telah dikonfirmasi user (`POST /ai/execute-action`).
  Future<AiExecuteResult> executeAction(AiProposedAction action) async {
    late final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$kApiBaseUrl/ai/execute-action'),
            headers: _headers(),
            body: jsonEncode({
              'tool': action.tool,
              'args': action.args,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const AiException('Server tidak merespons saat menjalankan aksi.');
    } catch (_) {
      throw const AiException('Tidak dapat terhubung ke server.');
    }

    if (res.statusCode == 401) {
      AuthRepository.instance.onSessionExpired?.call();
      throw const AiException('Sesi login kedaluwarsa.');
    }

    final body = _tryDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      int? toInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
      return AiExecuteResult(
        message: '${body['message'] ?? 'Aksi berhasil dijalankan.'}',
        projectId: toInt(body['project_id']),
        taskId: toInt(body['task_id']),
      );
    }
    throw AiException(_extractError(res.body, res.statusCode));
  }

  Map<String, dynamic> _tryDecode(String raw) {
    try {
      final d = jsonDecode(raw);
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  String _extractError(String rawBody, int status) {
    if (status == 429) {
      return 'Terlalu banyak permintaan ke Runa (maks 20/menit). Tunggu sebentar.';
    }
    final body = _tryDecode(rawBody);
    final err = '${body['error'] ?? ''}'.trim();
    if (err.isNotEmpty) return err;
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return '${first.first}';
      if (first != null) return '$first';
    }
    final msg = '${body['message'] ?? ''}'.trim();
    if (msg.isNotEmpty) return msg;
    if (status == 502) return 'AI Assistant sedang tidak tersedia.';
    if (status == 504) return 'AI Assistant sedang sibuk/lambat merespons. Coba lagi sesaat lagi.';
    return 'Gagal menghubungi AI Assistant ($status).';
  }
}
