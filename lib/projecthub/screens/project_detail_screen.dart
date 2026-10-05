import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../stitch_frontend_interface_application/app_theme.dart';
import '../../stitch_frontend_interface_application/task_repository.dart';
import '../ph_forms_project.dart';
import '../ph_format.dart';
import '../ph_models.dart';
import '../ph_remote.dart';
import '../ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

const _tabs = ['Ringkasan', 'Task', 'Milestone', 'Sprint', 'Tim', 'Budget', 'Risiko', 'File', 'Timesheet', 'Tiket', 'Chat'];

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: _tabs.length, vsync: this);
  String _taskFilter = 'all';
  final _store = PhStore.instance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = _store.projectById(widget.projectId);
    if (p == null) return;
    try {
      await _store.loadProjectWorkspace(p);
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) phToast(context, done);
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  Future<void> _confirmDelete(String what, Future<void> Function() action) async {
    final ok = await phConfirm(context, title: 'Hapus $what?', message: '$what ini akan dihapus dari proyek.');
    if (ok) await _run(action, '${what[0].toUpperCase()}${what.substring(1)} dihapus');
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.projectById(widget.projectId);
    if (p == null) {
      return Scaffold(appBar: phAppBar('Proyek'), body: const PhEmpty(Icons.folder_off_outlined, 'Proyek tidak ditemukan'));
    }
    return ListenableBuilder(
      listenable: Listenable.merge([_store, TaskRepository.instance]),
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: phAppBar(
          p.name,
          actions: [IconButton(tooltip: 'Ubah proyek', icon: const Icon(Icons.edit_outlined), onPressed: () => openProjectForm(context, project: p))],
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [for (final t in _tabs) Tab(text: t)],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _overview(p),
            _tasks(p),
            _milestones(p),
            _sprints(p),
            _team(p),
            _budget(p),
            _risks(p),
            _files(p),
            _timesheet(p),
            _tickets(p),
            _chat(p),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Widget> children) => RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error))),
            ...children,
          ],
        ),
      );

  // ---------------------------------------------------------------- Ringkasan
  Widget _overview(Project p) {
    final tasks = TaskRepository.instance.tasks.where((t) => t.projectId == p.id).toList();
    final used = p.budgetUsedPercent;
    final over = used >= p.budgetThreshold;
    return _list([
      PhSection(
        'Progres',
        child: PhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${p.progress}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary800)),
                const SizedBox(width: 8),
                Expanded(child: Text('${tasks.where((t) => t.done).length} dari ${tasks.length} task selesai', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
              ]),
              phGap(),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(value: p.progress / 100, minHeight: 8, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.primary600)),
              ),
              phGap(),
              const Text('Kolom progress proyek, diperbarui otomatis dari status task.', style: TextStyle(fontSize: 12, color: AppColors.grey700)),
            ],
          ),
        ),
      ),
      PhSection(
        'Budget',
        child: PhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Pengeluaran / budget', style: TextStyle(fontSize: 12, color: AppColors.grey700)),
                const SizedBox(width: 8),
                Expanded(child: Text('${rp(p.expense)} / ${rp(p.budget)}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              ]),
              phGap(),
              _Meter(percent: used, threshold: p.budgetThreshold, over: over),
              phGap(),
              Text(
                over ? 'Pengeluaran ($used%) melewati ambang peringatan ${p.budgetThreshold}%.' : 'Terpakai $used%. Ambang peringatan ${p.budgetThreshold}%.',
                style: TextStyle(fontSize: 12, color: over ? const Color(0xFFC62828) : AppColors.grey700, fontWeight: over ? FontWeight.w500 : FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
      PhSection(
        'Informasi',
        child: KvCard([
          ('Status', PhPill.status('project', p.status)),
          ('Lead Project', _store.nameOf(p.managerId)),
          ('Client', p.clientId.isEmpty ? 'Internal' : _store.nameOf(p.clientId)),
          ('Mulai', fmtDate(p.startDate)),
          ('Selesai', fmtDate(p.endDate)),
          ('Budget', rp(p.budget)),
          ('Ambang budget', '${p.budgetThreshold}%'),
          ('Repo GitHub', p.githubUrl.isEmpty ? '-' : p.githubUrl),
          ('Google Meet', p.meetLink.isEmpty ? 'Belum diatur' : '${p.meetLink} (${fmtDateTime(p.meetAt)})'),
        ]),
      ),
      PhSection('Deskripsi', child: PhCard(child: Text(p.description.isEmpty ? '-' : p.description, style: const TextStyle(fontSize: 14, height: 1.5)))),
    ]);
  }

  // ---------------------------------------------------------------- Task
  Widget _tasks(Project p) {
    final all = TaskRepository.instance.tasks.where((t) => t.projectId == p.id).toList();
    final list = all.where((t) => _taskFilter == 'all' || t.status == _taskFilter).toList();
    return Column(
      children: [
        PhChipBar(items: [('all', 'Semua'), ...statusOptions('task')], selected: _taskFilter, onSelected: (v) => setState(() => _taskFilter = v)),
        Expanded(
          child: _list([
            if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 48), child: PhEmpty(Icons.inbox_outlined, 'Belum ada task di kolom ini')),
            for (final t in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PhListRow(
                  title: t.title,
                  subtitle: '${_store.nameOf(t.assignedTo)} · tenggat ${t.dueDate.isEmpty ? t.due : fmtDate(t.dueDate)}${t.storyPoints > 0 ? ' · ${t.storyPoints} pts' : ''}',
                  trailing: PhPill.status('task', t.status),
                  trailingNote: statusLabel('priority', t.priority.name),
                  onTap: () => context.push('/task/${t.id}'),
                ),
              ),
            PhButton('Task baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openTaskForm(context, project: p)),
          ]),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Milestone
  Widget _milestones(Project p) => _list([
        if (p.milestones.isEmpty) const PhEmpty(Icons.flag_outlined, 'Belum ada milestone'),
        for (final m in p.milestones)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(m.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                    PhPill.status('milestone', m.status),
                  ]),
                  if (m.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(m.description, style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
                  phGap(),
                  Row(children: [
                    Expanded(child: Text('${fmtDate(m.startDate)} sampai ${fmtDate(m.dueDate)}', style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
                    if (m.assignedTo.isNotEmpty) ...[
                      PhAvatar(m.assignedTo),
                      const SizedBox(width: 6),
                      Text(_store.nameOf(m.assignedTo), style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
                    ],
                  ]),
                  if (m.clientApprovedAt != null) Padding(padding: const EdgeInsets.only(top: 8), child: PhPill('Disetujui client ${fmtDateTime(m.clientApprovedAt)}', fg: const Color(0xFF2E7D32), bg: AppColors.successBg)),
                  TextButton(onPressed: () => openMilestoneForm(context, p, milestone: m), child: const Text('Ubah milestone')),
                ],
              ),
            ),
          ),
        PhButton('Milestone baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openMilestoneForm(context, p)),
      ]);

  // ---------------------------------------------------------------- Sprint
  Widget _sprints(Project p) => _list([
        if (p.sprints.isEmpty) const PhEmpty(Icons.flag_outlined, 'Belum ada sprint'),
        for (final s in p.sprints)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                    PhPill.status('sprint', s.status),
                  ]),
                  phGap(6),
                  Text('Goal: ${s.goal.isEmpty ? '-' : s.goal}', style: const TextStyle(fontSize: 13)),
                  phGap(4),
                  Text('${fmtDate(s.startDate)} sampai ${fmtDate(s.endDate)}${s.milestone.isEmpty ? '' : ' · Milestone: ${s.milestone}'}', style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
                  Row(children: [
                    TextButton(onPressed: () => openSprintForm(context, p, sprint: s), child: const Text('Ubah sprint')),
                    TextButton(onPressed: () => _confirmDelete('sprint', () => _store.deleteSprint(p, s)), child: const Text('Hapus', style: TextStyle(color: AppColors.error))),
                  ]),
                ],
              ),
            ),
          ),
        PhButton('Sprint baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openSprintForm(context, p)),
      ]);

  // ---------------------------------------------------------------- Tim
  Widget _team(Project p) => _list([
        for (final m in p.members)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhListRow(
              leading: PhAvatar(m.userId, size: 34),
              title: _store.nameOf(m.userId),
              subtitle: '${m.role.isEmpty ? 'Anggota' : m.role} · maks ${m.maxHoursPerDay} jam/hari',
              trailing: IconButton(
                tooltip: 'Keluarkan ${_store.nameOf(m.userId)}',
                icon: const Icon(Icons.person_remove_outlined, color: AppColors.error, size: 20),
                onPressed: () => _confirmDelete('anggota', () => _store.removeMember(p, m)),
              ),
            ),
          ),
        PhButton('Tambah anggota', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openMemberForm(context, p)),
      ]);

  // ---------------------------------------------------------------- Budget
  Widget _budget(Project p) => _list([
        Row(children: [
          Expanded(child: PhCard(padding: const EdgeInsets.all(12), child: _Amount('Pemasukan', p.income, const Color(0xFF2E7D32)))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: PhCard(padding: const EdgeInsets.all(12), child: _Amount('Pengeluaran', p.expense, const Color(0xFFC62828)))),
        ]),
        phGap(AppSpacing.sm),
        PhListRow(
          leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primary600),
          title: 'Ambang peringatan ${p.budgetThreshold}%',
          subtitle: 'Terpakai ${p.budgetUsedPercent}% dari budget ${rp(p.budget)}',
          trailing: const Icon(Icons.edit_outlined, color: AppColors.grey400, size: 18),
          onTap: () => openBudgetThresholdForm(context, p),
        ),
        phGap(AppSpacing.md),
        if (p.budgetEntries.isEmpty) const PhEmpty(Icons.payments_outlined, 'Belum ada entri budget'),
        for (final b in p.budgetEntries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhListRow(
              title: '${b.category} · ${b.description}',
              subtitle: '${fmtDate(b.entryDate)}${b.reference.isEmpty ? '' : ' · Ref ${b.reference}'}',
              trailing: Text('${b.type == 'income' ? '+' : '-'} ${rp(b.amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: b.type == 'income' ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
              onTap: () => _confirmDelete('entri budget', () => _store.deleteBudgetEntry(p, b)),
            ),
          ),
        PhButton('Entri budget', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openBudgetForm(context, p)),
      ]);

  // ---------------------------------------------------------------- Risiko
  Widget _risks(Project p) => _list([
        if (p.risks.isEmpty) const PhEmpty(Icons.warning_amber_rounded, 'Belum ada risiko tercatat'),
        for (final r in p.risks)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _Score(r.score),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('${riskCategories[r.category]} · probabilitas ${r.probability} × dampak ${r.impact}', style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
                      ]),
                    ),
                    PhPill.status('risk', r.status),
                  ]),
                  if (r.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(r.description, style: const TextStyle(fontSize: 13))),
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('Rencana mitigasi: ${r.mitigationPlan.isEmpty ? '-' : r.mitigationPlan}', style: const TextStyle(fontSize: 13))),
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('Pemilik: ${r.owner.isEmpty ? '-' : r.owner}', style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
                  Row(children: [
                    TextButton(onPressed: () => openRiskForm(context, p, risk: r), child: const Text('Ubah risiko')),
                    TextButton(onPressed: () => _confirmDelete('risiko', () => _store.deleteRisk(p, r)), child: const Text('Hapus', style: TextStyle(color: AppColors.error))),
                  ]),
                ],
              ),
            ),
          ),
        PhButton('Risiko baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openRiskForm(context, p)),
      ]);

  // ---------------------------------------------------------------- File
  Widget _files(Project p) {
    final folders = <String, List<ProjectFile>>{};
    for (final f in p.files) {
      folders.putIfAbsent(f.folder, () => []).add(f);
    }
    return _list([
      if (folders.isEmpty) const PhEmpty(Icons.folder_open_outlined, 'Belum ada file'),
      for (final e in folders.entries)
        PhSection(
          e.key,
          child: Column(children: [
            for (final f in e.value)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PhListRow(
                  leading: Icon(f.mimeType.startsWith('image/') ? Icons.image_outlined : Icons.insert_drive_file_outlined, color: AppColors.primary600),
                  title: f.name,
                  subtitle: f.description.isEmpty ? fileSize(f.size) : '${f.description} · ${fileSize(f.size)}',
                  trailing: IconButton(
                    tooltip: 'Hapus ${f.name}',
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: () => _confirmDelete('file', () => _store.deleteFile(p, f)),
                  ),
                  onTap: f.mimeType.startsWith('image/') ? () => _preview(f) : null,
                ),
              ),
          ]),
        ),
      phGap(AppSpacing.md),
      PhButton('Unggah file', icon: Icons.upload_file, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openFileForm(context, p)),
    ]);
  }

  // ---------------------------------------------------------------- Timesheet
  Widget _timesheet(Project p) {
    final total = p.timeLogs.fold<int>(0, (s, l) => s + l.minutes);
    final running = p.timeLogs.where((l) => l.running && l.userId == PhStore.meId).firstOrNull;
    return _list([
      PhCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total waktu tercatat', style: TextStyle(fontSize: 12, color: AppColors.grey700)),
              Text('${total ~/ 60} jam ${total % 60} menit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (running != null)
            phRedButton('Hentikan timer', () => _stopTimer(p, running), icon: Icons.stop)
          else
            PhButton('Mulai timer', icon: Icons.play_arrow, compact: true, onPressed: () => _startTimer(p)),
        ]),
      ),
      phGap(AppSpacing.md),
      if (p.timeLogs.isEmpty) const PhEmpty(Icons.schedule, 'Belum ada time log'),
      for (final l in p.timeLogs)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PhListRow(
            title: l.taskTitle,
            subtitle: '${_store.nameOf(l.userId)} · ${fmtDateTime(l.startedAt)}${l.endedAt == null || l.endedAt!.length < 16 ? '' : ' sampai ${l.endedAt!.substring(11, 16)}'}${l.notes.isEmpty ? '' : ' · ${l.notes}'}',
            trailing: l.running ? const PhPill('Berjalan', fg: Color(0xFFB15600), bg: AppColors.warningBg) : Text('${l.minutes ~/ 60}j ${l.minutes % 60}m', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      PhButton('Catat waktu manual', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openTimeLogForm(context, p)),
    ]);
  }

  /// Timer berjalan di server (time_logs.is_running); satu user hanya punya satu timer aktif.
  void _startTimer(Project p) {
    final tasks = TaskRepository.instance.tasks.where((t) => t.projectId == p.id && !t.done).toList();
    if (tasks.isEmpty) {
      phToast(context, 'Tidak ada task yang belum selesai');
      return;
    }
    openPhForm(
      context,
      PhFormConfig(
        title: 'Mulai Timer',
        note: 'Timer lain milik Anda yang masih berjalan akan dihentikan otomatis.',
        saveLabel: 'Mulai',
        doneMessage: 'Timer dimulai',
        fields: [
          PhField('taskId', 'Task', type: PhFieldType.select, options: [for (final t in tasks) ('${t.id}', t.title)]),
          const PhField('notes', 'Catatan', type: PhFieldType.multiline),
        ],
        onSave: (v) async {
          await _store.logTime(p, int.parse('${v['taskId']}'), 'start', notes: '${v['notes'] ?? ''}');
          return null;
        },
      ),
    );
  }

  void _stopTimer(Project p, TimeLog l) => _run(() => _store.logTime(p, l.taskId, 'stop'), 'Timer dihentikan');

  void _preview(ProjectFile f) => showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: InteractiveViewer(child: Image.network(f.url, errorBuilder: (_, _, _) => const Padding(padding: EdgeInsets.all(24), child: Text('Gambar tidak dapat dimuat'))))),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
          ]),
        ),
      );

  // ---------------------------------------------------------------- Tiket
  Widget _tickets(Project p) {
    final list = _store.tickets.where((t) => t.projectName == p.name).toList();
    return _list([
      if (list.isEmpty) const PhEmpty(Icons.bug_report_outlined, 'Tidak ada tiket untuk proyek ini'),
      for (final t in list)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PhListRow(
            title: 'TK-${t.id} ${t.title}',
            subtitle: '${t.type} · ${t.assigneeId.isEmpty ? 'Belum ditugaskan' : _store.nameOf(t.assigneeId)}',
            trailing: PhPill.status('ticket', t.status),
            trailingNote: statusLabel('priority', t.priority),
            onTap: () => context.push('/ticket/${t.id}'),
          ),
        ),
      PhButton('Laporkan tiket', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => context.push('/tickets')),
    ]);
  }

  // ---------------------------------------------------------------- Chat
  Widget _chat(Project p) => _list([
        PhButton('Buka chat proyek', icon: Icons.chat_bubble_outline, onPressed: () => context.push('/thread/${Uri.encodeComponent('proj:${p.id}')}')),
        phGap(),
        const Text('Anggota tim proyek otomatis ada di chat ini.', style: TextStyle(fontSize: 12, color: AppColors.grey700)),
      ]);
}

class _Meter extends StatelessWidget {
  final int percent;
  final int threshold;
  final bool over;
  const _Meter({required this.percent, required this.threshold, required this.over});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 3,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppColors.grey100,
                    valueColor: AlwaysStoppedAnimation(over ? AppColors.error : AppColors.primary600),
                  ),
                ),
              ),
              Positioned(left: c.maxWidth * threshold / 100, top: 0, child: Container(width: 2, height: 14, color: AppColors.grey900)),
            ],
          ),
        ),
      );
}

class _Amount extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Amount(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
          Text(rp(value), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

class _Score extends StatelessWidget {
  final int score;
  const _Score(this.score);

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = score >= 15
        ? (const Color(0xFFC62828), AppColors.errorBg)
        : score >= 8
            ? (const Color(0xFFB15600), AppColors.warningBg)
            : (const Color(0xFF2E7D32), AppColors.successBg);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text('$score', style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
