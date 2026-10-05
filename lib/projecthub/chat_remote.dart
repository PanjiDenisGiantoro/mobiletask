import 'dart:async';

import 'package:flutter/foundation.dart';

import '../stitch_frontend_interface_application/auth_repository.dart';
import 'ph_api.dart';
import 'ph_models.dart';
import 'ph_store.dart';

/// Satu percakapan di daftar chat (proyek, DM, atau forum).
class ChatRoom {
  /// Kunci thread: `proj:<id proyek>`, `dm:<id user>`, atau `forum:<id>`.
  final String key;
  final String name;
  final int unread;
  final String lastText;
  final String lastAt;
  final int memberCount;
  const ChatRoom(this.key, this.name, {this.unread = 0, this.lastText = '', this.lastAt = '', this.memberCount = 0});

  bool get isProject => key.startsWith('proj:');
  bool get isDirect => key.startsWith('dm:');
  String get targetId => key.substring(key.indexOf(':') + 1);
}

/// Chat lewat endpoint yang sama dengan halaman web (ChatWebController,
/// DirectMessageWebController, ForumWebController). Pesan baru diambil dengan
/// polling `?after=<id terakhir>` selama layar percakapan terbuka.
class ChatRepository extends ChangeNotifier {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  final _api = PhApi.instance;
  final _store = PhStore.instance;

  List<ChatRoom> projects = [];
  List<ChatRoom> directs = [];
  List<ChatRoom> forums = [];

  /// Rekan satu company yang bisa diajak DM / diundang ke forum.
  List<PhUser> peers = [];
  final Map<String, List<ChatMessage>> threads = {};
  bool loading = false;
  String? error;

  int get totalUnread => [...projects, ...directs, ...forums].fold(0, (s, r) => s + r.unread);

  Future<void> loadInbox() async {
    await Future<void>.value(); // dipanggil dari initState
    if (!AuthRepository.instance.isLoggedIn) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final j = await _api.get('/chat/inbox') as Map<String, dynamic>;
      ChatRoom room(String prefix, Map<String, dynamic> r) {
        final last = r['last_message'] is Map ? r['last_message'] as Map : null;
        return ChatRoom(
          '$prefix:${r['id']}',
          '${r['name'] ?? ''}',
          unread: r['unread_count'] as int? ?? 0,
          lastText: last == null ? '' : '${last['is_mine'] == true ? 'Anda' : '${last['user_name']}'.split(' ').first}: ${last['body']}',
          lastAt: last == null ? '' : '${last['time'] ?? ''}',
          memberCount: r['member_count'] as int? ?? 0,
        );
      }

      projects = [for (final r in (j['projects'] as List? ?? const [])) room('proj', r as Map<String, dynamic>)];
      directs = [for (final r in (j['dms'] as List? ?? const [])) room('dm', r as Map<String, dynamic>)]
        ..sort((a, b) => (b.lastAt.isEmpty ? 0 : 1).compareTo(a.lastAt.isEmpty ? 0 : 1));
      forums = [for (final r in (j['forums'] as List? ?? const [])) room('forum', r as Map<String, dynamic>)];
      peers = [for (final p in (j['allPeers'] as List? ?? const [])) PhUser('${p['id']}', '${p['name']}')];
      for (final p in peers) {
        _store.users.putIfAbsent(p.id, () => p);
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  ChatRoom? room(String key) => [...projects, ...directs, ...forums].where((r) => r.key == key).firstOrNull;

  String _base(String key) {
    final id = key.substring(key.indexOf(':') + 1);
    if (key.startsWith('proj:')) return '/projects/$id/chat';
    if (key.startsWith('dm:')) return '/messages/$id';
    return '/forums/$id';
  }

  String _messagesPath(String key) {
    final id = key.substring(key.indexOf(':') + 1);
    if (key.startsWith('proj:')) return '/projects/$id/chat/messages';
    if (key.startsWith('dm:')) return '/messages/$id/thread';
    return '/forums/$id/messages';
  }

  String _readPath(String key) => '${_base(key)}/read';

  /// Muat pesan; dengan [poll] hanya mengambil pesan setelah id terakhir.
  Future<void> loadThread(String key, {bool poll = false}) async {
    final list = threads.putIfAbsent(key, () => []);
    final after = poll && list.isNotEmpty ? list.map((m) => m.id).reduce((a, b) => a > b ? a : b) : 0;
    final j = await _api.get('${_messagesPath(key)}${after > 0 ? '?after=$after' : ''}') as Map<String, dynamic>;
    final fresh = [for (final m in (j['messages'] as List? ?? const [])) _message(m as Map<String, dynamic>)];
    if (after == 0) {
      list
        ..clear()
        ..addAll(fresh);
    } else {
      for (final m in fresh) {
        list.removeWhere((e) => e.id == m.id);
        list.add(m);
      }
    }
    if (fresh.isNotEmpty || after == 0) {
      unawaited(_api.post(_readPath(key)).catchError((_) => null));
      notifyListeners();
    }
  }

  Future<void> send(String key, String body, {int parentId = 0, ApiFile? file}) async {
    final fields = <String, Object?>{'body': body, if (parentId != 0) 'parent_id': parentId};
    final res = file != null && key.startsWith('proj:')
        ? await _api.upload(_base(key), fields, [ApiFile('files[]', file.name, file.bytes)])
        : await _api.post(key.startsWith('forum:') ? '${_base(key)}/messages' : _base(key), fields);
    final m = res is Map && res['message'] is Map<String, dynamic> ? _message(res['message'] as Map<String, dynamic>) : null;
    if (m != null) {
      final list = threads.putIfAbsent(key, () => []);
      list
        ..removeWhere((e) => e.id == m.id)
        ..add(m);
    }
    notifyListeners();
  }

  String _messagePath(String key, int id) => key.startsWith('forum:') ? '${_base(key)}/messages/$id' : '${_base(key)}/$id';

  Future<void> edit(String key, ChatMessage m, String body) async {
    await _api.put(_messagePath(key, m.id), {'body': body});
    m
      ..body = body
      ..edited = true;
    notifyListeners();
  }

  Future<void> remove(String key, ChatMessage m) async {
    await _api.delete(_messagePath(key, m.id));
    m
      ..deleted = true
      ..body = '';
    notifyListeners();
  }

  /// Reaksi emoji (hanya chat proyek, sama dengan web).
  Future<void> react(String key, ChatMessage m, String emoji) async {
    final res = await _api.post('${_messagePath(key, m.id)}/react', {'emoji': emoji}) as Map<String, dynamic>;
    _applyReactions(m, res['reactions']);
    notifyListeners();
  }

  Future<String> createForum(String name, String description, List<String> memberIds) async {
    final res = await _api.post('/forums', {'name': name, 'description': description, 'member_ids': memberIds}) as Map<String, dynamic>;
    await loadInbox();
    return 'forum:${(res['forum'] as Map)['id']}';
  }

  void clear() {
    projects = [];
    directs = [];
    forums = [];
    peers = [];
    threads.clear();
    notifyListeners();
  }

  ChatMessage _message(Map<String, dynamic> j) {
    final user = j['user'] as Map? ?? const {};
    final uid = '${user['id'] ?? ''}';
    if (uid.isNotEmpty) _store.users.putIfAbsent(uid, () => PhUser(uid, '${user['name'] ?? '-'}'));
    final parent = j['parent'] as Map?;
    final atts = (j['attachments'] as List? ?? const []);
    final m = ChatMessage(
      id: j['id'] as int? ?? 0,
      userId: uid,
      body: '${j['body'] ?? ''}',
      parentId: parent == null ? 0 : parent['id'] as int? ?? 0,
      parentText: parent == null ? '' : '${'${parent['user']}'.split(' ').first}: ${parent['body']}',
      edited: j['edited_at'] != null,
      deleted: j['deleted'] == true,
      createdAt: '${j['created_at'] ?? ''}',
      attachment: atts.isEmpty ? '' : '${atts.first['name']}',
      attachmentUrl: atts.isEmpty ? '' : '${atts.first['url']}',
    );
    _applyReactions(m, j['reactions']);
    return m;
  }

  void _applyReactions(ChatMessage m, Object? groups) {
    m.reactions.clear();
    m.myReactions.clear();
    for (final g in (groups as List? ?? const [])) {
      final emoji = '${g['emoji']}';
      m.reactions[emoji] = [for (final u in (g['users'] as List? ?? const [])) '$u'];
      if (g['reacted'] == true) m.myReactions.add(emoji);
    }
  }
}
