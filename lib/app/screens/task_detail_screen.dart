import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/task_repository.dart';
import '../widgets/task_tile.dart';
import '../utils/ph_format.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../widgets/ph_widgets.dart';

// Palet slate/blue mengikuti modal task di web projecthub_pro.
const _slate900 = Color(0xFF0F172A);
const _slate700 = Color(0xFF334155);
const _slate500 = Color(0xFF64748B);
const _slate400 = Color(0xFF94A3B8);
const _slate200 = Color(0xFFE2E8F0);
const _slate100 = Color(0xFFF1F5F9);
const _slate50 = Color(0xFFF8FAFC);
const _blue = Color(0xFF2563EB);
const _blue50 = Color(0xFFEFF6FF);
const _red = Color(0xFFDC2626);

const _statusDot = {
  'todo': Color(0xFF94A3B8),
  'in_progress': Color(0xFF3B82F6),
  'review': Color(0xFFF59E0B),
  'done': Color(0xFF10B981),
};

const _priorityStyle = {
  'urgent': (Color(0xFFEF4444), Icons.keyboard_double_arrow_up_rounded),
  'high': (Color(0xFFF97316), Icons.arrow_upward_rounded),
  'medium': (Color(0xFFF59E0B), Icons.drag_handle_rounded),
  'low': (Color(0xFF10B981), Icons.arrow_downward_rounded),
};

const _depLabel = {
  'finish_to_start': 'Selesai ke mulai',
  'start_to_start': 'Mulai ke mulai',
  'finish_to_finish': 'Selesai ke selesai',
};

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _store = PhStore.instance;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _hours = TextEditingController();
  final _points = TextEditingController();
  final _comment = TextEditingController();

  String _status = 'todo', _priority = 'medium', _assignee = '', _milestone = '', _sprint = '', _start = '', _due = '';
  bool _dirty = false, _saving = false, _preview = false;
  String _feed = 'all';

  TaskEntry? get _task => TaskRepository.instance.byId(widget.taskId);

  @override
  void initState() {
    super.initState();
    final t = _task;
    if (t == null) return;
    _load(t);
    for (final c in [_title, _desc, _hours, _points]) {
      c.addListener(_markDirty);
    }
    if (t.projectId != 0) _store.loadTaskComments(t).catchError((_) => <TaskComment>[]);
  }

  void _load(TaskEntry t) {
    _status = t.status;
    _priority = t.priority.name;
    _assignee = t.assignedTo;
    _milestone = t.milestone;
    _sprint = t.sprint;
    _start = t.startDate;
    _due = t.dueDate;
    _title.text = t.title;
    _desc.text = t.description;
    _hours.text = t.estimatedHours > 0 ? '${t.estimatedHours}' : '';
    _points.text = t.storyPoints > 0 ? '${t.storyPoints}' : '';
    _dirty = false;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _set(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  @override
  void dispose() {
    for (final c in [_title, _desc, _hours, _points, _comment]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;
    if (t == null) {
      return Scaffold(appBar: phAppBar('Detail Task'), body: const PhEmpty(Icons.task_alt, 'Task tidak ditemukan'));
    }
    final project = t.projectId != 0 ? _store.projectById(t.projectId) : _store.projectByName(t.project);
    final editable = project != null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([TaskRepository.instance, _store]),
        builder: (context, _) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(children: [
              _header(t),
              const Divider(height: 1, color: _slate200),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    _titleRow(editable),
                    const SizedBox(height: 12),
                    _assigneeRow(editable),
                    const SizedBox(height: 20),
                    _fields(project, editable),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: _slate100),
                    const SizedBox(height: 20),
                    _notes(editable),
                    if (t.done && t.completionNotes.isNotEmpty) ...[const SizedBox(height: 20), _completion(t)],
                    if (t.dependencies.isNotEmpty) ...[const SizedBox(height: 20), _dependencies(t)],
                    const SizedBox(height: 24),
                    _activity(t),
                  ],
                ),
              ),
              if (editable) _footer(t),
            ]),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ header

  Widget _header(TaskEntry t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        child: Row(children: [
          _StatusPill(_status, onTap: () => _pickStatus()),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(6)),
            child: Text('TASK-${t.id}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('•  ${t.project}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _slate500)),
          ),
          IconButton(
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded, color: _slate500),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ]),
      );

  Widget _titleRow(bool editable) {
    final done = _status == 'done';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: InkResponse(
          onTap: editable ? () => _set(() => _status = done ? 'todo' : 'done') : null,
          radius: 18,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? const Color(0xFF10B981) : null,
              border: Border.all(color: done ? const Color(0xFF10B981) : _slate400, width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: _title,
          enabled: editable,
          maxLines: null,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: done ? _slate400 : _slate900,
            decoration: done ? TextDecoration.lineThrough : null,
            height: 1.25,
          ),
          decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Task title...', contentPadding: EdgeInsets.zero),
        ),
      ),
    ]);
  }

  Widget _assigneeRow(bool editable) => Row(children: [
        const Icon(Icons.person_outline_rounded, size: 18, color: _slate400),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            if (_assignee.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                decoration: BoxDecoration(color: _blue50, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: const Color(0xFFDBEAFE))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PhAvatar(_assignee, size: 22),
                  const SizedBox(width: 6),
                  Text(_store.nameOf(_assignee), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _slate700)),
                  if (editable) ...[
                    const SizedBox(width: 4),
                    InkResponse(onTap: () => _set(() => _assignee = ''), radius: 12, child: const Icon(Icons.close_rounded, size: 14, color: _slate400)),
                  ],
                ]),
              ),
            if (editable)
              _GhostChip(_assignee.isEmpty ? 'Add Assignee' : 'Change', onTap: () async {
                final v = await _pick('Assignee', [for (final u in _store.staff) (u.id, u.name)], _assignee,
                    leading: (id) => PhAvatar(id, size: 26));
                if (v != null) _set(() => _assignee = v);
              }),
          ]),
        ),
      ]);

  // ------------------------------------------------------------ fields

  Widget _fields(Project? project, bool editable) {
    final p = _priorityStyle[_priority] ?? _priorityStyle['medium']!;
    final overdue = _due.length >= 10 && _status != 'done' && DateTime.tryParse(_due)?.isBefore(_today()) == true;
    Widget pair(Widget a, Widget b) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
        );
    return Column(children: [
      pair(
        _FieldBox(
          label: 'Status',
          onTap: editable ? _pickStatus : null,
          leading: _Dot(_statusDot[_status] ?? _slate400),
          value: statusLabel('task', _status),
        ),
        _FieldBox(
          label: 'Priority',
          onTap: editable
              ? () async {
                  final v = await _pick('Priority', [for (final e in TaskPriority.values) (e.name, statusLabel('priority', e.name))], _priority,
                      leading: (k) => Icon(_priorityStyle[k]!.$2, size: 18, color: _priorityStyle[k]!.$1));
                  if (v != null) _set(() => _priority = v);
                }
              : null,
          leading: Icon(p.$2, size: 18, color: p.$1),
          value: statusLabel('priority', _priority),
          valueColor: p.$1,
          borderColor: p.$1.withValues(alpha: 0.6),
        ),
      ),
      pair(
        _FieldBox(
          label: 'Start date',
          onTap: editable ? () => _pickDate(_start, (v) => _start = v) : null,
          value: _ddmmyyyy(_start),
          trailing: Icons.calendar_today_outlined,
        ),
        _FieldBox(
          label: 'Due date',
          badge: overdue ? const _OverdueBadge() : null,
          onTap: editable ? () => _pickDate(_due, (v) => _due = v) : null,
          value: _ddmmyyyy(_due),
          trailing: Icons.calendar_today_outlined,
        ),
      ),
      pair(
        _FieldBox(
          label: 'Milestone',
          onTap: editable
              ? () async {
                  final v = await _pick('Milestone', [('', 'Tanpa milestone'), for (final m in project!.milestones) (m.title, m.title)], _milestone);
                  if (v != null) _set(() => _milestone = v);
                }
              : null,
          leading: const Icon(Icons.flag_outlined, size: 18, color: Color(0xFF8B5CF6)),
          value: _milestone.isEmpty ? 'Tanpa milestone' : _milestone,
        ),
        _FieldBox(
          label: 'Sprint',
          onTap: editable
              ? () async {
                  final v = await _pick('Sprint', [('', 'Tanpa sprint'), for (final s in project!.sprints) (s.name, s.name)], _sprint);
                  if (v != null) _set(() => _sprint = v);
                }
              : null,
          leading: const Icon(Icons.bolt_outlined, size: 18, color: Color(0xFF6366F1)),
          value: _sprint.isEmpty ? 'Tanpa sprint' : _sprint,
        ),
      ),
      pair(
        _NumberBox(label: 'Estimasi', controller: _hours, suffix: 'jam', enabled: editable),
        _NumberBox(label: 'Story points', controller: _points, enabled: editable),
      ),
    ]);
  }

  Widget _notes(bool editable) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Notes & Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _slate900))),
          _Segmented(
            items: const [('write', 'Write'), ('preview', 'Preview')],
            value: _preview ? 'preview' : 'write',
            onChanged: (v) => setState(() => _preview = v == 'preview'),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 130),
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: _slate200), borderRadius: BorderRadius.circular(12)),
          child: _preview
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_desc.text.trim().isEmpty ? 'Belum ada catatan.' : _desc.text,
                      style: TextStyle(fontSize: 13, height: 1.55, color: _desc.text.trim().isEmpty ? _slate400 : _slate700)),
                )
              : TextField(
                  controller: _desc,
                  enabled: editable,
                  minLines: 5,
                  maxLines: null,
                  style: const TextStyle(fontSize: 13, height: 1.55, color: _slate700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                    hintText: 'Add detailed notes, instructions, or markdown checklist here...',
                    hintStyle: TextStyle(fontSize: 13, color: _slate400),
                  ),
                ),
        ),
      ]);

  Widget _completion(TaskEntry t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFA7F3D0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Completion Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
          const SizedBox(height: 6),
          Text(t.completionNotes, style: const TextStyle(fontSize: 13, height: 1.5, color: _slate700)),
        ]),
      );

  Widget _dependencies(TaskEntry t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Caps('Dependencies'),
        const SizedBox(height: 10),
        for (final d in t.dependencies)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.link_rounded, size: 16, color: _slate400),
              const SizedBox(width: 8),
              Expanded(child: Text(d.dependsOn, style: const TextStyle(fontSize: 13, color: _slate700))),
              Text(_depLabel[d.type] ?? d.type, style: const TextStyle(fontSize: 11, color: _slate500)),
            ]),
          ),
      ]);

  // ------------------------------------------------------------ activity

  Widget _activity(TaskEntry t) {
    final logs = [for (final p in _store.projects) ...p.timeLogs.where((l) => l.taskTitle == t.title)];
    final items = <(String, Widget)>[
      if (_feed != 'activity') for (final c in t.comments) (c.at, _FeedItem(userId: c.userId, at: c.at, body: c.body, isComment: true)),
      if (_feed != 'comments')
        for (final l in logs)
          (
            l.startedAt,
            _FeedItem(
              userId: l.userId,
              at: l.startedAt,
              body: 'mencatat waktu ${l.minutes ~/ 60}j ${l.minutes % 60}m${l.notes.isEmpty ? '' : ' — ${l.notes}'}',
            ),
          ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return Container(
      decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(14), border: Border.all(color: _slate200)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: _slate500),
          const SizedBox(width: 8),
          const Expanded(child: _Caps('Activity & Comments')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(AppRadius.full)),
            child: Text('${t.comments.length + logs.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
          ),
        ]),
        const SizedBox(height: 12),
        _Segmented(
          expand: true,
          items: const [('all', 'All'), ('comments', 'Comments'), ('activity', 'Activity Log')],
          value: _feed,
          onChanged: (v) => setState(() => _feed = v),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Belum ada aktivitas.', style: TextStyle(fontSize: 12, color: _slate400))),
          )
        else
          for (final i in items) Padding(padding: const EdgeInsets.only(bottom: 14), child: i.$2),
        if (t.projectId != 0) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _slate200)),
            child: TextField(
              controller: _comment,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                hintText: 'Write a comment or response...',
                hintStyle: TextStyle(fontSize: 13, color: _slate400),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _blue, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 18)),
              onPressed: () => _send(t),
              child: const Text('Send Comment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _footer(TaskEntry t) => Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _slate200))),
        child: Row(children: [
          TextButton.icon(
            onPressed: _saving ? null : () => _delete(t),
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _red),
            label: const Text('Delete Task', style: TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _saving ? null : () => _dirty ? setState(() => _load(t)) : Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(shape: const StadiumBorder(), side: const BorderSide(color: _slate200), foregroundColor: _slate700),
            child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _dirty && !_saving ? () => _save(t) : null,
            style: FilledButton.styleFrom(backgroundColor: _blue, shape: const StadiumBorder()),
            icon: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save Changes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  // ------------------------------------------------------------ actions

  Future<void> _pickStatus() async {
    final v = await _pick('Status', statusOptions('task'), _status, leading: (k) => _Dot(_statusDot[k] ?? _slate400));
    if (v != null) _set(() => _status = v);
  }

  Future<String?> _pick(String title, List<(String, String)> options, String current, {Widget Function(String key)? leading}) =>
      showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.6),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _slate900)),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final o in options)
                    ListTile(
                      leading: leading == null || o.$1.isEmpty ? null : leading(o.$1),
                      title: Text(o.$2, style: const TextStyle(fontSize: 14)),
                      trailing: o.$1 == current ? const Icon(Icons.check_rounded, color: _blue) : null,
                      onTap: () => Navigator.pop(c, o.$1),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      );

  Future<void> _pickDate(String current, void Function(String) assign) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) _set(() => assign(isoDate(d)));
  }

  Future<bool> _confirmDiscard() => phConfirm(
        context,
        title: 'Unsaved Changes',
        message: 'Perubahan pada task ini belum disimpan. Buang perubahan?',
        confirm: 'Buang',
      );

  Future<void> _save(TaskEntry t) async {
    if (_title.text.trim().isEmpty) return phToast(context, 'Judul task wajib diisi');
    if (_start.isNotEmpty && _due.isNotEmpty && _due.compareTo(_start) < 0) {
      return phToast(context, 'Tenggat harus setelah tanggal mulai');
    }
    setState(() => _saving = true);
    try {
      await _store.updateTask(t, {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'assignedTo': _assignee,
        'milestone': _milestone,
        'sprint': _sprint,
        'priority': _priority,
        'status': _status,
        'startDate': _start,
        'dueDate': _due,
        'estimatedHours': _hours.text.trim(),
        'storyPoints': _points.text.trim(),
      });
      if (!mounted) return;
      setState(() => _load(t));
      phToast(context, 'Task tersimpan');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(TaskEntry t) async {
    final ok = await phConfirm(context, title: 'Delete This Task?', message: '"${t.title}" akan dihapus permanen.');
    if (!ok || !mounted) return;
    try {
      await _store.deleteTask(t);
      if (!mounted) return;
      setState(() => _dirty = false);
      phToast(context, 'Task dihapus');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  Future<void> _send(TaskEntry t) async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    try {
      await _store.addTaskComment(t, text);
      _comment.clear();
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _ddmmyyyy(String iso) {
    if (iso.length < 10) return 'dd/mm/yyyy';
    final p = iso.substring(0, 10).split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }
}

// ------------------------------------------------------------ widgets

class _Caps extends StatelessWidget {
  final String text;
  const _Caps(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: _slate700));
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _StatusPill extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  const _StatusPill(this.status, {required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: _blue50,
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFFBFDBFE))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(_statusDot[status] ?? _slate400),
              const SizedBox(width: 6),
              Text(statusLabel('task', status), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1D4ED8)),
            ]),
          ),
        ),
      );
}

class _GhostChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostChip(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const StadiumBorder(side: BorderSide(color: _slate200)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, size: 14, color: _slate500),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _slate500)),
            ]),
          ),
        ),
      );
}

class _Segmented extends StatelessWidget {
  final List<(String, String)> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool expand;
  const _Segmented({required this.items, required this.value, required this.onChanged, this.expand = false});

  @override
  Widget build(BuildContext context) {
    Widget seg((String, String) i) {
      final on = i.$1 == value;
      return GestureDetector(
        onTap: () => onChanged(i.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: on ? const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))] : null,
          ),
          child: Text(i.$2, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? (expand ? _slate900 : _blue) : _slate500)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final i in items) expand ? Expanded(child: seg(i)) : seg(i)],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Widget? badge;
  const _FieldLabel(this.label, {this.badge});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _slate500))),
          ?badge,
        ]),
      );
}

class _FieldBox extends StatelessWidget {
  final String label;
  final String value;
  final Widget? leading;
  final Widget? badge;
  final IconData trailing;
  final Color? valueColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  const _FieldBox({
    required this.label,
    required this.value,
    this.leading,
    this.badge,
    this.trailing = Icons.keyboard_arrow_down_rounded,
    this.valueColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label, badge: badge),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor ?? _slate200, width: borderColor == null ? 1 : 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  child: Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? (value == 'dd/mm/yyyy' ? _slate400 : _slate900))),
                ),
                Icon(trailing, size: trailing == Icons.keyboard_arrow_down_rounded ? 20 : 16, color: _slate500),
              ]),
            ),
          ),
        ),
      ]);
}

class _NumberBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffix;
  final bool enabled;
  const _NumberBox({required this.label, required this.controller, this.suffix, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slate200));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label),
      SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _slate900),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: _slate400),
            suffixText: suffix,
            suffixStyle: const TextStyle(fontSize: 12, color: _slate500),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border.copyWith(borderSide: const BorderSide(color: _blue, width: 1.5)),
          ),
        ),
      ),
    ]);
  }
}

class _OverdueBadge extends StatelessWidget {
  const _OverdueBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(AppRadius.full)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          _Dot(_red),
          SizedBox(width: 4),
          Text('Overdue', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _red)),
        ]),
      );
}

class _FeedItem extends StatelessWidget {
  final String userId;
  final String at;
  final String body;
  final bool isComment;
  const _FeedItem({required this.userId, required this.at, required this.body, this.isComment = false});

  @override
  Widget build(BuildContext context) {
    final name = PhStore.instance.nameOf(userId);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PhAvatar(userId, size: 26),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isComment) ...[
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _slate900)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
              child: Text(body, style: const TextStyle(fontSize: 13, height: 1.45, color: _slate700)),
            ),
          ] else
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '$name ', style: const TextStyle(fontWeight: FontWeight.w700, color: _slate900)),
                TextSpan(text: body),
              ]),
              style: const TextStyle(fontSize: 12, height: 1.45, color: _slate700),
            ),
          const SizedBox(height: 3),
          Text(fmtDateTime(at), style: const TextStyle(fontSize: 10, color: _slate400)),
        ]),
      ),
    ]);
  }
}
