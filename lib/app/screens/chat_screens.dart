import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../data/chat_remote.dart';
import '../data/ph_api.dart';
import '../utils/ph_format.dart';
import '../data/ph_models.dart';
import '../data/ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

final _store = PhStore.instance;
final _chat = ChatRepository.instance;

String _threadPath(String key) => '/thread/${Uri.encodeComponent(key)}';

/// Chat 3 tab: Proyek (project_messages), Pesan (direct messages), Forum.
class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));

  @override
  void initState() {
    super.initState();
    _chat.loadInbox();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _chat,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar('Chat', bottom: phTabBar(_tab, const ['Proyek', 'Pesan', 'Forum'])),
          floatingActionButton: _tab.index != 2
              ? null
              : FloatingActionButton(
                  heroTag: 'chat_fab',
                  tooltip: 'Forum baru',
                  backgroundColor: AppColors.heroStart,
                  foregroundColor: Colors.white,
                  onPressed: () => _newForum(context),
                  child: const Icon(Icons.add),
                ),
          body: TabBarView(controller: _tab, children: [
            _list(_chat.projects, 'Belum ada proyek yang bisa Anda akses'),
            _list(_chat.directs, 'Belum ada rekan di perusahaan Anda'),
            _list(_chat.forums, 'Belum ada forum. Buat forum dengan tombol +'),
          ]),
        ),
      );

  Widget _list(List<ChatRoom> rooms, String empty) => RefreshIndicator(
        onRefresh: _chat.loadInbox,
        child: rooms.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                if (_chat.loading)
                  const Padding(padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator()))
                else
                  PhEmpty(Icons.chat_bubble_outline, _chat.error ?? empty),
              ])
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final r = rooms[i];
                  return PhListRow(
                    leading: r.isDirect ? PhAvatar(r.targetId, size: 40) : null,
                    title: r.name,
                    subtitle: r.lastText.isEmpty ? (r.memberCount > 0 ? '${r.memberCount} anggota · belum ada pesan' : 'Belum ada pesan') : r.lastText,
                    trailing: _unread(r.unread),
                    trailingNote: r.lastAt.isEmpty ? null : r.lastAt,
                    onTap: () => context.push(_threadPath(r.key)),
                  );
                },
              ),
      );

  Widget _unread(int n) => n == 0
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: AppColors.heroStart, borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        );

  void _newForum(BuildContext context) {
    openPhForm(
      context,
      PhFormConfig(
        title: 'Forum Baru',
        note: 'Anda otomatis menjadi anggota forum.',
        doneMessage: 'Forum dibuat',
        fields: [
          const PhField('name', 'Nama forum', required: true),
          const PhField('description', 'Deskripsi', type: PhFieldType.multiline),
          PhField('members', 'Undang anggota', type: PhFieldType.multi, options: [for (final u in _chat.peers) (u.id, u.name)]),
        ],
        onSave: (v) async {
          await _chat.createForum('${v['name']}', '${v['description'] ?? ''}', [...(v['members'] as List<String>)]);
          return null;
        },
      ),
    );
  }
}

class ChatThreadScreen extends StatefulWidget {
  /// Kunci thread: `proj:<id proyek>`, `dm:<id user>`, atau `forum:<id>`.
  final String threadKey;
  const ChatThreadScreen({super.key, required this.threadKey});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  ChatMessage? _replyTo;
  ChatMessage? _editing;
  ApiFile? _file;
  bool _sending = false;
  bool _loading = true;
  String? _error;
  Timer? _poll;

  String get _key => widget.threadKey;
  bool get _isProject => _key.startsWith('proj:');

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _chat.loadThread(_key, poll: true).catchError((_) {}));
  }

  Future<void> _load() async {
    try {
      await _chat.loadThread(_key);
      _error = null;
      _toBottom();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    _chat.loadInbox();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  (String, String) get _titles {
    final room = _chat.room(_key);
    final id = _key.substring(_key.indexOf(':') + 1);
    if (_isProject) {
      final p = _store.projectById(int.tryParse(id) ?? 0);
      return (room?.name ?? p?.name ?? 'Chat proyek', p == null ? 'Chat proyek' : '${p.members.length} anggota proyek');
    }
    if (_key.startsWith('dm:')) return (room?.name ?? _store.nameOf(id), 'Pesan langsung');
    return (room?.name ?? 'Forum', room == null ? 'Forum' : '${room.memberCount} anggota forum');
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if ((text.isEmpty && _file == null) || _sending) return;
    setState(() => _sending = true);
    try {
      final editing = _editing;
      if (editing != null) {
        await _chat.edit(_key, editing, text);
      } else {
        await _chat.send(_key, text, parentId: _replyTo?.id ?? 0, file: _file);
      }
      _input.clear();
      _replyTo = null;
      _editing = null;
      _file = null;
      _toBottom();
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickFile() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) phToast(context, 'Ukuran file maksimal 10 MB');
        return;
      }
      setState(() => _file = ApiFile('files[]', x.name, bytes));
    } catch (_) {
      if (mounted) phToast(context, 'Galeri tidak dapat dibuka di perangkat ini');
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) {
        final (title, sub) = _titles;
        final list = _chat.threads[_key] ?? const <ChatMessage>[];
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.heroStart,
            foregroundColor: Colors.white,
            flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.heroStart, AppColors.heroMid]))),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              Text(sub, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
            ]),
          ),
          body: Column(children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? PhEmpty(Icons.chat_bubble_outline, _error ?? 'Belum ada pesan. Mulai percakapan.')
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final m = list[i];
                            return _Bubble(
                              message: m,
                              reactions: _isProject,
                              onReact: (e) => _action(() => _chat.react(_key, m, e)),
                              onReply: () => setState(() {
                                _replyTo = m;
                                _editing = null;
                              }),
                              onEdit: () => setState(() {
                                _editing = m;
                                _replyTo = null;
                                _input.text = m.body;
                              }),
                              onDelete: () async {
                                final ok = await phConfirm(context, title: 'Hapus pesan?', message: 'Pesan ini akan dihapus untuk semua anggota.');
                                if (ok) await _action(() => _chat.remove(_key, m));
                              },
                            );
                          },
                        ),
            ),
            if (_replyTo != null) _banner('Membalas ${_store.nameOf(_replyTo!.userId).split(' ').first}: ${_replyTo!.body}', AppColors.primary50, () => setState(() => _replyTo = null)),
            if (_editing != null)
              _banner('Mengubah pesan', AppColors.warningBg, () => setState(() {
                    _editing = null;
                    _input.clear();
                  })),
            if (_file != null) _banner('Lampiran: ${_file!.name}', AppColors.grey100, () => setState(() => _file = null)),
            SafeArea(
              top: false,
              child: Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  if (_isProject) IconButton(tooltip: 'Lampirkan gambar', icon: const Icon(Icons.attach_file, color: AppColors.grey700), onPressed: _pickFile),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan',
                        filled: true,
                        fillColor: AppColors.grey100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Kirim',
                    style: IconButton.styleFrom(backgroundColor: AppColors.heroStart),
                    onPressed: _sending ? null : _send,
                    icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 20),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _banner(String text, Color bg, VoidCallback onClose) => Container(
        color: bg,
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(children: [
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Batal', icon: const Icon(Icons.close, size: 16), onPressed: onClose),
        ]),
      );
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool reactions;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _Bubble({required this.message, required this.reactions, required this.onReact, required this.onReply, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final me = message.userId == PhStore.meId;
    final fg = me ? Colors.white : AppColors.grey900;
    final time = DateTime.tryParse(message.createdAt)?.toLocal();
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: me ? AppColors.primary700 : AppColors.white, borderRadius: BorderRadius.circular(14), boxShadow: phCardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!me) Text(_store.nameOf(message.userId), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary700)),
            if (message.parentText.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: me ? Colors.white54 : AppColors.grey400, width: 3))),
                child: Text(message.parentText, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: me ? Colors.white70 : AppColors.grey700)),
              ),
            if (message.deleted)
              Text('Pesan dihapus', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: fg.withValues(alpha: 0.7)))
            else if (message.body.isNotEmpty)
              Text(message.body, style: TextStyle(fontSize: 14, color: fg, height: 1.35)),
            if (!message.deleted && message.attachmentUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: RegExp(r'\.(jpe?g|png|gif|webp)$', caseSensitive: false).hasMatch(message.attachment)
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(message.attachmentUrl, height: 160, fit: BoxFit.cover, errorBuilder: (_, _, _) => Text(message.attachment, style: TextStyle(fontSize: 12, color: fg))))
                    : Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.attach_file, size: 14, color: fg), const SizedBox(width: 2), Flexible(child: Text(message.attachment, style: TextStyle(fontSize: 12, color: fg)))]),
              ),
            Text('${time == null ? '' : hhmm(time)}${message.edited ? ' · diedit' : ''}', style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.7))),
            if (!message.deleted) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (reactions)
                  for (final e in {'👍', '✅', '🙏', ...message.reactions.keys})
                    _chip('$e${(message.reactions[e]?.length ?? 0) > 0 ? ' ${message.reactions[e]!.length}' : ''}', () => onReact(e), me, active: message.myReactions.contains(e)),
                _chip('Balas', onReply, me),
                if (me) _chip('Ubah', onEdit, me),
                if (me) _chip('Hapus', onDelete, me),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, bool me, {bool active = false}) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? (me ? Colors.white30 : AppColors.primary50) : (me ? Colors.white12 : AppColors.grey100),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: me ? Colors.white : AppColors.grey900)),
        ),
      );
}
