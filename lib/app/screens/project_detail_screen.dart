import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../data/task_repository.dart';
import 'ph_forms_project.dart';
import '../utils/ph_format.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../widgets/ph_widgets.dart';
import 'ticket_screens.dart' show TicketRow, openTicketForm, ticketTypes;

/// Urutan tab: 5 pertama (Ringkasan..Chat) tab inti yang sering dipakai,
/// selalu terlihat tanpa scroll; sisanya dijangkau lewat kartu menu di tab
/// Ringkasan (lompat langsung via `_tab.animateTo`) atau scroll TabBar.
const _tabs = ['Ringkasan', 'Task', 'Milestone', 'Sprint', 'Chat', 'Tim', 'Budget', 'File', 'Knowledge Base', 'Timesheet', 'Tiket'];

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: _tabs.length, vsync: this);
  String _taskFilter = 'all';
  DateTimeRange? _taskDateRange = currentMonthRange();
  String _taskSearch = '';
  final _store = PhStore.instance;
  bool _loading = true;
  String? _error;
  final Set<int> _expandedMilestones = {};
  final Set<int> _expandedSprints = {};
  bool _milestoneDiagram = false;
  bool _exportingMilestoneImage = false;
  DateTimeRange? _milestoneDateRange = currentMonthRange();
  String _milestoneSearch = '';
  bool _sprintTableView = false;
  final Set<int> _expandedSprintRows = {};
  String _sprintSearch = '';
  bool _filesGridView = true;
  String _fileSource = 'all'; // all | task | standalone
  String _fileType = 'all'; // all | file | link
  String _fileFolder = 'all';
  String _fileSearch = '';
  String _kbCategory = 'all';
  String _kbSearch = '';
  DateTime _ganttMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _ganttSearch = '';
  String _ganttStatus = 'all';
  bool _exportingGantt = false;
  String _ticketSearch = '';
  String _ticketStatus = 'all';
  String _ticketPriority = 'all';
  String _ticketType = 'all';

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
      listenable: Listenable.merge([_store, TaskRepository.instance, _tab]),
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.heroStart,
          foregroundColor: Colors.white,
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.heroStart, AppColors.heroMid]),
            ),
          ),
          leading: _tab.index == 0
              ? null
              : IconButton(tooltip: 'Kembali ke Ringkasan', icon: const Icon(Icons.arrow_back), onPressed: () => _tab.animateTo(0)),
          title: Row(
            children: [
              _ProjectLogo(project: p, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(_tab.index == 0 ? p.name : _tabs[_tab.index], maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          actions: [IconButton(tooltip: 'Ubah proyek', icon: const Icon(Icons.edit_outlined), onPressed: () => openProjectForm(context, project: p))],
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _overview(p),
            _tasks(p),
            _milestones(p),
            _sprints(p),
            _chat(p),
            _team(p),
            _budget(p),
            _files(p),
            _knowledgeBase(p),
            _timesheet(p),
            _tickets(p),
          ],
        ),
      ),
    );
  }

  Widget _searchField(String hint, String value, ValueChanged<String> onChanged) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.grey400, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.grey500),
                onPressed: () => onChanged(''),
              ),
        filled: true,
        fillColor: AppColors.grey100,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
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
    final categoryColor = switch (p.category) {
      'Development' || 'Internal' => AppColors.success,
      'Marketing' => AppColors.warning,
      _ => AppColors.info,
    };
    return _list([
      PhCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectLogo(project: p, size: 56),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      PhPill(p.category, fg: categoryColor, bg: categoryColor.withValues(alpha: 0.12)),
                      PhPill.status('project', p.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      phGap(AppSpacing.md),
      _projectInformationCard(p, used, over),
      phGap(AppSpacing.md),
      _overviewMenuGrid(p, tasks),
      phGap(AppSpacing.md),
      _taskStatusDistribution(tasks),
      phGap(AppSpacing.md),
      _activeSprintSpotlight(p),
      phGap(AppSpacing.md),
      _milestonesDeliveryPipeline(p),
      phGap(AppSpacing.md),
      _teamMembersSummary(p),
      phGap(AppSpacing.md),
      _recentTicketsIssues(p),
    ]);
  }

  /// Satu kartu "Project Information" (deskripsi + info kunci + budget),
  /// menggantikan 4 kartu putih terpisah (Progres/Budget/Informasi/Deskripsi)
  /// yang bikin layar jadi tumpukan kotak putih berulang — dipisah dengan
  /// divider tipis di dalam, bukan kartu mengambang baru tiap bagian.
  Widget _projectInformationCard(Project p, int used, bool over) {
    Widget divider() => const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Divider(height: 1, color: AppColors.grey100));
    Widget kv(String k, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 92, child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.grey500))),
              Expanded(child: v),
            ],
          ),
        );
    Widget kvText(String k, String v) => kv(k, Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.grey900)));

    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLinkHeader('Project Information', null, 'Kelola Budget', () => _tab.animateTo(6)),
          if (p.description.isNotEmpty) ...[
            phGap(AppSpacing.sm),
            Text(p.description, style: const TextStyle(fontSize: 13, color: AppColors.grey700, height: 1.5)),
          ],
          divider(),
          kvText('Status', statusLabel('project', p.status)),
          kvText('Client', p.clientId.isEmpty ? 'Internal' : _store.nameOf(p.clientId)),
          kv('Project Lead', Row(children: [
            PhAvatar(p.managerId, size: 20),
            const SizedBox(width: 6),
            Flexible(child: Text(_store.nameOf(p.managerId), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ])),
          kvText('Periode', '${fmtDate(p.startDate)} – ${fmtDate(p.endDate)}'),
          kvText('Siklus Kerja', '${p.sprints.length} Sprint · ${p.milestones.length} Milestone'),
          divider(),
          Row(children: [
            const Text('Pengeluaran / Budget', style: TextStyle(fontSize: 12, color: AppColors.grey500)),
            const SizedBox(width: 8),
            Expanded(child: Text('${rp(p.expense)} / ${rp(p.budget)}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          ]),
          phGap(AppSpacing.sm),
          _Meter(percent: used, threshold: p.budgetThreshold, over: over),
          phGap(AppSpacing.sm),
          Text(
            over ? 'Pengeluaran ($used%) melewati ambang peringatan ${p.budgetThreshold}%.' : 'Terpakai $used%. Ambang peringatan ${p.budgetThreshold}%.',
            style: TextStyle(fontSize: 11.5, color: over ? const Color(0xFFC62828) : AppColors.grey500, fontWeight: over ? FontWeight.w600 : FontWeight.w400),
          ),
        ],
      ),
    );
  }

  /// Header "Judul ... Link →" dipakai berulang di kartu-kartu ringkasan baru.
  Widget _sectionLinkHeader(String title, String? subtitle, String linkLabel, VoidCallback onTap, {Color dot = AppColors.primary700}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(margin: const EdgeInsets.only(top: 5), width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
            ],
          ),
        ),
        TextButton(onPressed: onTap, child: Text(linkLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
      ],
    );
  }

  /// Kartu menu ke seluruh tab modul proyek (Task, Milestone, Sprint, Chat, Tim,
  /// Budget, File, Knowledge Base, Timesheet, Tiket) — menggunakan grid 2 kolom × 5 baris
  /// dengan tinggi tetap (`mainAxisExtent: 64`) dan info ringkasan langsung di tiap kartu.
  Widget _overviewMenuGrid(Project p, List<TaskEntry> tasks) {
    final ticketCount = _store.tickets
        .where((t) => t.projectId == p.id || t.projectName == p.name)
        .length;

    final items = <(String, String, String, int, Color)>[
      ('assets/icons/illustrations/task.svg', 'Task', '${tasks.length} Tugas', 1, const Color(0xFFF59E0B)),
      ('assets/icons/illustrations/checklist.svg', 'Milestone', '${p.milestones.length} Target', 2, AppColors.primary700),
      ('assets/icons/illustrations/agile.svg', 'Sprint', '${p.sprints.length} Siklus', 3, AppColors.accent400),
      ('assets/icons/illustrations/brainstorming.svg', 'Chat', 'Diskusi Tim', 4, AppColors.primary600),
      ('assets/icons/illustrations/human_source.svg', 'Tim', '${p.members.length} Anggota', 5, const Color(0xFF0284C7)),
      ('assets/icons/illustrations/revenue.svg', 'Budget', '${p.budgetUsedPercent}% Terpakai', 6, AppColors.success),
      ('assets/icons/illustrations/file_management.svg', 'File', '${p.files.length} Berkas', 7, AppColors.info),
      ('assets/icons/illustrations/tutorial.svg', 'Knowledge Base', '${p.kbDocuments.length} Dokumen', 8, const Color(0xFF8E24AA)),
      ('assets/icons/illustrations/timeline.svg', 'Timesheet', 'Gantt & Jam', 9, const Color(0xFFEA580C)),
      ('assets/icons/illustrations/review.svg', 'Tiket', '$ticketCount Tiket', 10, AppColors.error),
    ];

    return PhCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: AppColors.primary700, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modul & Menu Proyek', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                    SizedBox(height: 1),
                    Text('Akses cepat ke seluruh fitur dan ruang kerja proyek', style: TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${items.length} Modul',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 64,
            ),
            itemBuilder: (context, i) {
              final (svgAsset, label, subtitle, index, color) = items[i];
              return Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _tab.animateTo(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: color.withValues(alpha: 0.18)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: SvgPicture.asset(svgAsset, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(Icons.chevron_right_rounded, size: 15, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// "Task Status Distribution" — sebaran status seluruh task + story points.
  Widget _taskStatusDistribution(List<TaskEntry> tasks) {
    final total = tasks.length;
    final counts = {
      'todo': tasks.where((t) => t.status == 'todo').length,
      'in_progress': tasks.where((t) => t.status == 'in_progress').length,
      'review': tasks.where((t) => t.status == 'review').length,
      'done': tasks.where((t) => t.status == 'done').length,
    };
    final totalPts = tasks.fold<int>(0, (s, t) => s + t.storyPoints);
    final donePts = tasks.where((t) => t.done).fold<int>(0, (s, t) => s + t.storyPoints);
    final completePercent = total > 0 ? (counts['done']! / total * 100).round() : 0;

    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLinkHeader('Task Status Distribution', 'Sebaran status seluruh task dalam project', 'Buka Kanban', () => _tab.animateTo(1)),
          phGap(AppSpacing.sm),
          if (total == 0)
            const Text('Belum ada task.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  for (final key in ['todo', 'in_progress', 'review', 'done'])
                    if (counts[key]! > 0) Expanded(flex: counts[key]!, child: Container(color: _ganttStatusColors[key])),
                ]),
              ),
            ),
            phGap(AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: 8,
              children: [
                for (final key in ['todo', 'in_progress', 'review', 'done'])
                  _legendDot(_ganttStatusColors[key]!, '${statusLabel('task', key)}  ${counts[key]} (${total > 0 ? (counts[key]! / total * 100).round() : 0}%)'),
              ],
            ),
            phGap(AppSpacing.sm),
            const Divider(height: 1, color: AppColors.grey100),
            phGap(AppSpacing.sm),
            Row(children: [
              Expanded(child: Text('Story Points: $donePts / $totalPts pts terealisasi', style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
              Text('$completePercent% Complete', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
            ]),
          ],
        ],
      ),
    );
  }

  /// "Active Sprint Spotlight" — sprint berstatus aktif saat ini.
  Widget _activeSprintSpotlight(Project p) {
    final active = p.sprints.where((s) => s.status == 'active').firstOrNull;
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLinkHeader('Active Sprint Spotlight', null, 'Semua Sprint', () => _tab.animateTo(3), dot: AppColors.warning),
          phGap(AppSpacing.sm),
          if (active == null)
            const Text('Tidak ada sprint yang sedang aktif.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            Builder(builder: (_) {
              final sprintTasks = _sprintTasks(p, active);
              final (done, total) = _taskCounts(sprintTasks);
              final progress = total > 0 ? done / total : 0.0;
              return Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(AppRadius.medium)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary700, borderRadius: BorderRadius.circular(AppRadius.small)),
                        child: const Text('ACTIVE NOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(active.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                    ]),
                    if (active.goal.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(active.goal, style: const TextStyle(fontSize: 12.5, color: AppColors.grey700))),
                    phGap(AppSpacing.sm),
                    Text('Periode: ${fmtDate(active.startDate)} – ${fmtDate(active.endDate)}', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                    phGap(AppSpacing.sm),
                    Row(children: [
                      const Text('Sprint Completion', style: TextStyle(fontSize: 11.5, color: AppColors.grey700)),
                      const Spacer(),
                      Text('$done / $total Tasks (${(progress * 100).round()}%)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: AppColors.white, valueColor: const AlwaysStoppedAnimation(AppColors.primary600)),
                    ),
                    phGap(AppSpacing.sm),
                    Row(children: [
                      if (active.leadId.isNotEmpty) ...[
                        PhAvatar(active.leadId, size: 22),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_store.nameOf(active.leadId), style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
                      ] else
                        const Spacer(),
                      FilledButton(
                        onPressed: () => openSprintForm(context, p, sprint: active),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary700, minimumSize: const Size(0, 34)),
                        child: const Text('Kelola Sprint Ini', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// "Milestones Delivery Pipeline" — target rilis & capaian milestone.
  Widget _milestonesDeliveryPipeline(Project p) {
    final tasks = TaskRepository.instance.tasks.where((t) => t.projectId == p.id).toList();
    final shown = p.milestones.take(4).toList();
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLinkHeader('Milestones Delivery Pipeline', 'Target rilis dan capaian milestone project', 'Roadmap Lengkap', () => _tab.animateTo(2), dot: AppColors.success),
          phGap(AppSpacing.sm),
          if (shown.isEmpty)
            const Text('Belum ada milestone.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (final m in shown)
              Builder(builder: (_) {
                final mTasks = tasks.where((t) => t.milestone == m.title).toList();
                final (done, total) = _taskCounts(mTasks);
                final progress = total > 0 ? done / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: statusStyle('milestone', m.status).fg, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                        Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.primary600)),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(child: Text('${mTasks.length} tasks terhubung', style: const TextStyle(fontSize: 11, color: AppColors.grey500))),
                        if (m.dueDate.isNotEmpty) Text('Target: ${fmtDate(m.dueDate)}', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                      ]),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }

  /// "Team Members" — ringkasan anggota tim proyek.
  Widget _teamMembersSummary(Project p) {
    final tasks = TaskRepository.instance.tasks.where((t) => t.projectId == p.id).toList();
    const previewCount = 5;
    final shown = p.members.take(previewCount).toList();
    final remaining = p.members.length - shown.length;
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLinkHeader('Team Members (${p.members.length})', 'Anggota yang berkontribusi dalam project ini', 'Kelola Tim', () => _tab.animateTo(5)),
          phGap(AppSpacing.sm),
          if (shown.isEmpty)
            const Text('Belum ada anggota.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else ...[
            for (final m in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(children: [
                  PhAvatar(m.userId, size: 32, imageUrl: m.photoUrl, images: m.images),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_store.nameOf(m.userId), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(m.role.isEmpty ? 'Anggota' : m.role, style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                      ],
                    ),
                  ),
                  Text('${tasks.where((t) => t.assignedTo == m.userId).length} Task', style: const TextStyle(fontSize: 11.5, color: AppColors.grey700)),
                ]),
              ),
            if (remaining > 0)
              TextButton(
                onPressed: () => _tab.animateTo(5),
                child: Text('+ Lihat $remaining anggota lainnya', style: const TextStyle(fontSize: 12.5)),
              ),
          ],
        ],
      ),
    );
  }

  /// "Recent Tickets & Issues" — tiket terbuka yang butuh perhatian.
  Widget _recentTicketsIssues(Project p) {
    final tickets = _store.tickets
        .where((t) => (t.projectId == p.id || t.projectName == p.name) && t.status != 'closed' && t.status != 'resolved')
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    final shown = tickets.take(3).toList();
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLinkHeader('Recent Tickets & Issues', 'Tiket terbuka yang membutuhkan perhatian', 'Semua Tiket', () => _tab.animateTo(10), dot: AppColors.error),
          phGap(AppSpacing.sm),
          if (shown.isEmpty)
            const Text('Tidak ada tiket aktif yang dilaporkan.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (final t in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () => context.push('/ticket/${t.id}'),
                  child: Row(children: [
                    Expanded(child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    PhPill.status('ticket', t.status),
                  ]),
                ),
              ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.grey700)),
        ],
      );

  // ---------------------------------------------------------------- Task
  Widget _tasks(Project p) {
    final all = TaskRepository.instance.tasks.where((t) => t.projectId == p.id).toList();
    final range = _taskDateRange;
    var byDate = range == null ? all : all.where((t) => inDateRange(t.dueDate, range)).toList();
    if (_taskSearch.trim().isNotEmpty) {
      final q = _taskSearch.trim().toLowerCase();
      byDate = byDate.where((t) => t.title.toLowerCase().contains(q)).toList();
    }
    final list = byDate.where((t) => _taskFilter == 'all' || t.status == _taskFilter).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: _searchField('Cari task...', _taskSearch, (v) => setState(() => _taskSearch = v)),
        ),
        phGap(AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: DateRangeFilterBar(
            range: _taskDateRange,
            onChanged: (r) => setState(() => _taskDateRange = r),
          ),
        ),
        phGap(AppSpacing.sm),
        PhChipBar(items: [('all', 'Semua'), ...statusOptions('task')], selected: _taskFilter, onSelected: (v) => setState(() => _taskFilter = v)),
        Expanded(
          child: _list([
            if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 48), child: PhEmpty(Icons.inbox_outlined, 'Belum ada task di rentang/kolom ini')),
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

  // ---------------------------------------------------------------- Milestone (hierarchy: Milestone -> Sprint -> Task)
  List<TaskEntry> _tasksOfProject(Project p) => TaskRepository.instance.tasks.where((t) => t.projectId == p.id).toList();

  (int, int) _taskCounts(Iterable<TaskEntry> tasks) => (tasks.where((t) => t.done).length, tasks.length);

  List<Milestone> _dateFilteredMilestones(Project p) {
    var list = p.milestones;
    final range = _milestoneDateRange;
    if (range != null) list = list.where((m) => inDateRange(m.dueDate, range)).toList();
    if (_milestoneSearch.trim().isNotEmpty) {
      final q = _milestoneSearch.trim().toLowerCase();
      list = list.where((m) => m.title.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Widget _milestones(Project p) {
    final tasks = _tasksOfProject(p);
    final milestones = _dateFilteredMilestones(p);
    return _list([
      if (p.milestones.isNotEmpty) ...[
        _searchField('Cari milestone...', _milestoneSearch, (v) => setState(() => _milestoneSearch = v)),
        phGap(AppSpacing.sm),
        DateRangeFilterBar(
          range: _milestoneDateRange,
          onChanged: (r) => setState(() => _milestoneDateRange = r),
        ),
        phGap(AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _milestoneViewToggle()),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: 'Download gambar',
              onPressed: _exportingMilestoneImage || milestones.isEmpty ? null : () => _exportMilestoneImage(p, milestones, tasks),
              icon: _exportingMilestoneImage
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, color: AppColors.primary700),
            ),
          ],
        ),
      ],
      phGap(AppSpacing.sm),
      if (p.milestones.isEmpty) const PhEmpty(Icons.flag_outlined, 'Belum ada milestone'),
      if (p.milestones.isNotEmpty && milestones.isEmpty) const PhEmpty(Icons.event_busy_outlined, 'Tidak ada milestone yang cocok'),
      if (milestones.isNotEmpty && !_milestoneDiagram)
        ..._milestoneTableBody(p, milestones, tasks)
      else if (milestones.isNotEmpty)
        ..._milestoneDiagramBody(p, milestones, tasks),
      if (p.milestones.isEmpty) PhButton('Milestone baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openMilestoneForm(context, p)),
    ]);
  }

  Widget _milestoneViewToggle() {
    Widget seg(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary700 : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.grey700)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        children: [
          seg('Hierarchy Table', !_milestoneDiagram, () => setState(() => _milestoneDiagram = false)),
          seg('Hierarchy Diagram', _milestoneDiagram, () => setState(() => _milestoneDiagram = true)),
        ],
      ),
    );
  }

  List<Widget> _milestoneTableBody(Project p, List<Milestone> milestones, List<TaskEntry> tasks) {
    final range = _milestoneDateRange;
    var standalone = tasks.where((t) => t.milestone.isEmpty && t.sprint.isEmpty).toList();
    if (range != null) standalone = standalone.where((t) => inDateRange(t.dueDate, range)).toList();
    final relevantSprints = p.sprints.where((s) => milestones.any((m) => m.id == s.milestoneId));
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _expandedMilestones.addAll(milestones.map((m) => m.id));
              _expandedSprints.addAll(relevantSprints.map((s) => s.id));
            }),
            child: const Text('Expand All'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _expandedMilestones.clear();
              _expandedSprints.clear();
            }),
            child: const Text('Collapse All'),
          ),
        ],
      ),
      for (final m in milestones) _milestoneBlock(p, m, tasks),
      PhButton('Milestone baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openMilestoneForm(context, p)),
      if (standalone.isNotEmpty) ...[
        phGap(AppSpacing.md),
        const Text('Standalone Activities', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey700)),
        phGap(AppSpacing.sm),
        for (final t in standalone) Padding(padding: const EdgeInsets.only(bottom: 6), child: _taskRow(t)),
      ],
    ];
  }

  List<Widget> _milestoneDiagramBody(Project p, List<Milestone> milestones, List<TaskEntry> tasks) {
    return [
      _milestoneDiagramRoot(p),
      Center(child: Container(width: 2, height: 18, color: AppColors.grey400)),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(child: _milestoneDiagramColumnsRow(p, milestones, tasks)),
      ),
    ];
  }

  Widget _milestoneDiagramRoot(Project p) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.heroStart, AppColors.primary800]),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Column(
            children: [
              const Text('PROJECT ROOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1)),
              Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      );

  Widget _milestoneDiagramColumnsRow(Project p, List<Milestone> milestones, List<TaskEntry> tasks) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [for (final m in milestones) _milestoneDiagramColumn(p, m, tasks)],
      );

  Widget _milestoneDiagramColumn(Project p, Milestone m, List<TaskEntry> allTasks) {
    final sprints = p.sprints.where((s) => s.milestoneId == m.id).toList();
    final milestoneTasks = allTasks.where((t) => t.milestone == m.title).toList();
    final (done, total) = _taskCounts(milestoneTasks);
    final progress = total > 0 ? done / total : 0.0;
    return Container(
      width: 230,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(height: 14, width: 2, color: AppColors.grey400)),
          InkWell(
            onTap: () => openMilestoneForm(context, p, milestone: m),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.medium), boxShadow: phCardShadow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _hierarchyBadge('MS-${m.id.toString().padLeft(2, '0')}', AppColors.primary50, AppColors.primary700),
                    const Spacer(),
                    Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                  ]),
                  phGap(4),
                  Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  phGap(6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.primary600)),
                  ),
                ],
              ),
            ),
          ),
          if (sprints.isNotEmpty) Center(child: Container(width: 2, height: 14, color: AppColors.grey400)),
          for (final s in sprints) Padding(padding: const EdgeInsets.only(bottom: 10), child: _milestoneDiagramSprintCard(p, s, allTasks)),
        ],
      ),
    );
  }

  Widget _milestoneDiagramSprintCard(Project p, Sprint s, List<TaskEntry> allTasks) {
    final sprintTasks = allTasks.where((t) => t.sprint == s.name).toList();
    final (done, total) = _taskCounts(sprintTasks);
    final progress = total > 0 ? done / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.medium), boxShadow: phCardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _hierarchyBadge('SP-${s.id.toString().padLeft(2, '0')}', AppColors.accent200.withValues(alpha: 0.3), AppColors.primary800),
            const Spacer(),
            Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.heroStart)),
          ]),
          phGap(4),
          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          phGap(2),
          InkWell(
            onTap: () => openSprintForm(context, p, sprint: s),
            child: Row(
              children: [
                Text('Tasks (${sprintTasks.length})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primary700)),
                const Spacer(),
                const Text('Click to edit', style: TextStyle(fontSize: 10, color: AppColors.grey400)),
              ],
            ),
          ),
          phGap(6),
          for (final t in sprintTasks.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  PhAvatar(t.assignedTo, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                  Text(
                    t.done ? 'Done' : 'Open',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: t.done ? const Color(0xFF2E7D32) : AppColors.grey500),
                  ),
                ],
              ),
            ),
          if (sprintTasks.length > 6) Text('+${sprintTasks.length - 6} lainnya', style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
          if (sprintTasks.isEmpty) const Text('Belum ada task', style: TextStyle(fontSize: 10.5, color: AppColors.grey500)),
        ],
      ),
    );
  }

  Widget _milestoneBlock(Project p, Milestone m, List<TaskEntry> allTasks) {
    final expanded = _expandedMilestones.contains(m.id);
    final sprints = p.sprints.where((s) => s.milestoneId == m.id).toList();
    final directTasks = allTasks.where((t) => t.milestone == m.title && t.sprint.isEmpty).toList();
    final milestoneTasks = allTasks.where((t) => t.milestone == m.title).toList();
    final (done, total) = _taskCounts(milestoneTasks);
    final progress = total > 0 ? done / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhCard(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => expanded ? _expandedMilestones.remove(m.id) : _expandedMilestones.add(m.id)),
              child: Row(
                children: [
                  Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 20, color: AppColors.grey500),
                  _hierarchyBadge('MS-${m.id.toString().padLeft(2, '0')}', AppColors.primary50, AppColors.primary700),
                  const SizedBox(width: 6),
                  Expanded(child: Text(m.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                  PhPill.status('milestone', m.status),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Ubah milestone',
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.grey500),
                    onPressed: () => openMilestoneForm(context, p, milestone: m),
                  ),
                ],
              ),
            ),
            phGap(6),
            Row(children: [
              if (m.assignedTo.isNotEmpty) ...[
                PhAvatar(m.assignedTo, size: 22),
                const SizedBox(width: 6),
                Text(_store.nameOf(m.assignedTo), style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.primary600)),
                ),
              ),
              const SizedBox(width: 6),
              Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary700)),
            ]),
            phGap(4),
            Text('${fmtDate(m.startDate)} – ${fmtDate(m.dueDate)}', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
            if (expanded) ...[
              if (m.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(m.description, style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
              if (m.clientApprovedAt != null) Padding(padding: const EdgeInsets.only(top: 8), child: PhPill('Disetujui client ${fmtDateTime(m.clientApprovedAt)}', fg: const Color(0xFF2E7D32), bg: AppColors.successBg)),
              phGap(AppSpacing.sm),
              for (final s in sprints) Padding(padding: const EdgeInsets.only(left: 14, bottom: 6), child: _sprintBlock(p, s, allTasks)),
              for (final t in directTasks) Padding(padding: const EdgeInsets.only(left: 28, bottom: 6), child: _taskRow(t)),
              if (sprints.isEmpty && directTasks.isEmpty) const Padding(padding: EdgeInsets.only(left: 28), child: Text('Belum ada sprint/task', style: TextStyle(fontSize: 12, color: AppColors.grey500))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sprintBlock(Project p, Sprint s, List<TaskEntry> allTasks) {
    final expanded = _expandedSprints.contains(s.id);
    final sprintTasks = allTasks.where((t) => t.sprint == s.name).toList();
    final (done, total) = _taskCounts(sprintTasks);
    final progress = total > 0 ? done / total : 0.0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: const Border(left: BorderSide(color: AppColors.primary200, width: 3)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => expanded ? _expandedSprints.remove(s.id) : _expandedSprints.add(s.id)),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 18, color: AppColors.grey500),
                _hierarchyBadge('SP-${s.id.toString().padLeft(2, '0')}', AppColors.accent200.withValues(alpha: 0.3), AppColors.primary800),
                const SizedBox(width: 6),
                Expanded(child: Text('${s.name}  (${sprintTasks.length} task${sprintTasks.length == 1 ? '' : 's'})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                PhPill.status('sprint', s.status),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Ubah sprint',
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.grey500),
                  onPressed: () => openSprintForm(context, p, sprint: s),
                ),
              ],
            ),
          ),
          phGap(4),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: AppColors.white, valueColor: const AlwaysStoppedAnimation(AppColors.heroStart)),
              ),
            ),
            const SizedBox(width: 6),
            Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.heroStart)),
          ]),
          phGap(4),
          Text('${fmtDate(s.startDate)} – ${fmtDate(s.endDate)}', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
          if (expanded) ...[
            phGap(AppSpacing.xs),
            for (final t in sprintTasks) Padding(padding: const EdgeInsets.only(left: 14, bottom: 6), child: _taskRow(t)),
            if (sprintTasks.isEmpty) const Text('Belum ada task', style: TextStyle(fontSize: 11.5, color: AppColors.grey500)),
          ],
        ],
      ),
    );
  }

  Widget _taskRow(TaskEntry t) {
    return InkWell(
      onTap: () => context.push('/task/${t.id}'),
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 6, color: AppColors.grey400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.grey900)),
            ),
            PhPill.status('task', t.status),
            const SizedBox(width: 6),
            Text(statusLabel('priority', t.priority.name), style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
          ],
        ),
      ),
    );
  }

  Widget _hierarchyBadge(String label, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.small)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );

  /// Ekspor tampilan Milestone (table/diagram) yang sedang aktif jadi file PNG
  /// — dirender tanpa batas scroll/viewport supaya konten yang terpotong di
  /// layar tetap ikut tersimpan utuh.
  Future<void> _exportMilestoneImage(Project p, List<Milestone> milestones, List<TaskEntry> tasks) async {
    setState(() => _exportingMilestoneImage = true);
    try {
      final content = _milestoneDiagram
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _milestoneDiagramRoot(p),
                Center(child: Container(width: 2, height: 18, color: AppColors.grey400)),
                _milestoneDiagramColumnsRow(p, milestones, tasks),
              ],
            )
          : SizedBox(
              width: 380,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: _milestoneTableBody(p, milestones, tasks),
              ),
            );
      final bytes = await _captureFullSize(
        Material(
          color: AppColors.bg,
          child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: content),
        ),
      );
      if (bytes == null) throw Exception('Gagal membuat gambar');
      final view = _milestoneDiagram ? 'diagram' : 'table';
      final fileName = 'milestone_${view}_${p.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final message = await _savePng(bytes, fileName);
      if (mounted) phToast(context, message);
    } catch (e) {
      if (mounted) phToast(context, 'Gagal menyimpan gambar: $e');
    } finally {
      if (mounted) setState(() => _exportingMilestoneImage = false);
    }
  }

  /// Render [child] tak-terlihat (di luar layar, lewat Overlay) dengan ukuran
  /// bebas (tidak dibatasi viewport) lalu tangkap jadi PNG.
  Future<Uint8List?> _captureFullSize(Widget child) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -20000,
        top: 0,
        child: Directionality(textDirection: TextDirection.ltr, child: RepaintBoundary(key: key, child: child)),
      ),
    );
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 200));
      final boundary = key.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  Future<String> _savePng(Uint8List bytes, String fileName) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Gal.putImageBytes(bytes, name: fileName);
      return 'Gambar disimpan ke galeri';
    }
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    return 'Gambar disimpan di ${file.path}';
  }

  // ---------------------------------------------------------------- Sprint
  List<TaskEntry> _sprintTasks(Project p, Sprint s) => _tasksOfProject(p).where((t) => t.sprint == s.name).toList();

  List<Sprint> _searchFilteredSprints(Project p) {
    if (_sprintSearch.trim().isEmpty) return p.sprints;
    final q = _sprintSearch.trim().toLowerCase();
    return p.sprints.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  Widget _sprints(Project p) {
    final sprints = _searchFilteredSprints(p);
    return _list([
      if (p.sprints.isNotEmpty) ...[
        _searchField('Cari sprint...', _sprintSearch, (v) => setState(() => _sprintSearch = v)),
        phGap(AppSpacing.sm),
        _sprintViewToggle(),
        phGap(AppSpacing.sm),
      ],
      if (p.sprints.isEmpty) const PhEmpty(Icons.flag_outlined, 'Belum ada sprint'),
      if (p.sprints.isNotEmpty && sprints.isEmpty) const PhEmpty(Icons.search_off_rounded, 'Tidak ada sprint yang cocok'),
      if (sprints.isNotEmpty && !_sprintTableView)
        ..._sprintCardRoadmapBody(p, sprints)
      else if (sprints.isNotEmpty)
        ..._sprintTableBody(p, sprints),
      if (p.sprints.isEmpty) PhButton('Sprint baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openSprintForm(context, p)),
    ]);
  }

  Widget _sprintViewToggle() {
    Widget seg(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary700 : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.grey700)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        children: [
          seg('Card & Roadmap', !_sprintTableView, () => setState(() => _sprintTableView = false)),
          seg('Sprint Table', _sprintTableView, () => setState(() => _sprintTableView = true)),
        ],
      ),
    );
  }

  // -------------------------------------------------- Card & Roadmap
  List<Widget> _sprintCardRoadmapBody(Project p, List<Sprint> sprints) {
    return [
      _sprintStatsGrid(sprints),
      phGap(AppSpacing.md),
      _sprintRoadmap(p, sprints),
      phGap(AppSpacing.md),
      for (final s in sprints) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _sprintCard(p, s)),
      PhButton('Sprint baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openSprintForm(context, p)),
    ];
  }

  /// Ringkasan status sprint sebagai donut chart + legenda — "Terlambat"
  /// dibuat eksklusif terhadap Aktif/Direncanakan (sprint lewat tenggat tapi
  /// belum selesai dihitung sekali sebagai Terlambat, bukan dobel).
  Widget _sprintStatsGrid(List<Sprint> sprints) {
    final total = sprints.length;
    final today = isoDate(DateTime.now());
    bool overdue(Sprint s) => s.status != 'completed' && s.endDate.isNotEmpty && s.endDate.compareTo(today) < 0;
    final completed = sprints.where((s) => s.status == 'completed').length;
    final late = sprints.where(overdue).length;
    final active = sprints.where((s) => s.status == 'active' && !overdue(s)).length;
    final planned = sprints.where((s) => s.status == 'planned' && !overdue(s)).length;

    if (total == 0) return const SizedBox.shrink();

    return PhCard(
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 30,
                  sections: [
                    if (active > 0) PieChartSectionData(value: active.toDouble(), color: AppColors.info, showTitle: false, radius: 22),
                    if (completed > 0) PieChartSectionData(value: completed.toDouble(), color: AppColors.success, showTitle: false, radius: 22),
                    if (late > 0) PieChartSectionData(value: late.toDouble(), color: AppColors.error, showTitle: false, radius: 22),
                    if (planned > 0) PieChartSectionData(value: planned.toDouble(), color: AppColors.grey400, showTitle: false, radius: 22),
                  ],
                )),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                    const Text('Sprint', style: TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sprintStatLegend(AppColors.info, 'Aktif Sekarang', active),
                const SizedBox(height: 8),
                _sprintStatLegend(AppColors.success, 'Selesai', completed),
                const SizedBox(height: 8),
                _sprintStatLegend(AppColors.error, 'Terlambat', late),
                const SizedBox(height: 8),
                _sprintStatLegend(AppColors.grey400, 'Direncanakan', planned),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sprintStatLegend(Color color, String label, int value) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.grey700))),
          Text('$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900)),
        ],
      );

  Widget _sprintCard(Project p, Sprint s) {
    final tasks = _sprintTasks(p, s);
    final (done, total) = _taskCounts(tasks);
    final progress = total > 0 ? done / total : 0.0;
    final end = DateTime.tryParse(s.endDate);
    int? daysLeft;
    if (end != null) {
      final today = DateTime.now();
      daysLeft = DateTime(end.year, end.month, end.day).difference(DateTime(today.year, today.month, today.day)).inDays;
    }
    final milestoneTitle = p.milestones.where((m) => m.id == s.milestoneId).firstOrNull?.title ?? s.milestone;
    return PhCard(
      onTap: () => openSprintForm(context, p, sprint: s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _hierarchyBadge('SP-${s.id.toString().padLeft(2, '0')}', AppColors.accent200.withValues(alpha: 0.3), AppColors.primary800),
            const SizedBox(width: 6),
            PhPill.status('sprint', s.status),
            if (s.priority.isNotEmpty) ...[const SizedBox(width: 6), PhPill.status('priority', s.priority)],
            const Spacer(),
            IconButton(
              tooltip: 'Hapus sprint',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.grey400),
              onPressed: () => _confirmDelete('sprint', () => _store.deleteSprint(p, s)),
            ),
          ]),
          if (milestoneTitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: _hierarchyBadge(milestoneTitle, AppColors.primary50, AppColors.primary700)),
          phGap(6),
          Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (s.goal.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.goal, style: const TextStyle(fontSize: 12.5, color: AppColors.grey700))),
          phGap(10),
          Row(children: [
            if (s.leadId.isNotEmpty) ...[
              PhAvatar(s.leadId, size: 22),
              const SizedBox(width: 6),
              Text(_store.nameOf(s.leadId), style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
            ],
            const Spacer(),
            Text('${fmtDate(s.startDate)} → ${fmtDate(s.endDate)}', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
          ]),
          if (daysLeft != null && s.status != 'completed')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                daysLeft < 0 ? '${-daysLeft} hari terlambat' : '$daysLeft hari lagi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: daysLeft < 0 ? AppColors.error : AppColors.grey500),
              ),
            ),
          phGap(10),
          Row(children: [
            const Text('Sprint Progress', style: TextStyle(fontSize: 11.5, color: AppColors.grey700)),
            const SizedBox(width: 6),
            Text('$total task', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary700)),
            const Spacer(),
            Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary700)),
          ]),
          phGap(4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.primary600)),
          ),
        ],
      ),
    );
  }

  bool _exportingSprintRoadmap = false;

  /// "Sprint Execution Roadmap" — Gantt sederhana, scroll horizontal,
  /// sprint dikelompokkan per status seperti di web.
  Widget _sprintRoadmap(Project p, List<Sprint> sprints) {
    if (!_sprintRoadmapHasDates(sprints)) return const SizedBox.shrink();
    return PhCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sprint Execution Roadmap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const Text('Timeline and iterations schedule', style: TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Download PDF',
              visualDensity: VisualDensity.compact,
              onPressed: _exportingSprintRoadmap ? null : () => _exportSprintRoadmapPdf(p, sprints),
              icon: _exportingSprintRoadmap
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary700),
            ),
          ]),
          phGap(AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _sprintRoadmapGrid(p, sprints),
          ),
        ],
      ),
    );
  }

  bool _sprintRoadmapHasDates(List<Sprint> sprints) {
    final starts = [for (final s in sprints) DateTime.tryParse(s.startDate)].whereType<DateTime>();
    final ends = [for (final s in sprints) DateTime.tryParse(s.endDate)].whereType<DateTime>();
    return starts.isNotEmpty && ends.isNotEmpty;
  }

  /// Grid Gantt pada lebar natural (jumlah hari * pxPerDay) — dipakai baik
  /// untuk tampilan layar (dibungkus scroll horizontal) maupun ekspor PDF
  /// (ditangkap langsung tanpa viewport supaya tidak terpotong).
  Widget _sprintRoadmapGrid(Project p, List<Sprint> sprints) {
    final starts = [for (final s in sprints) DateTime.tryParse(s.startDate)].whereType<DateTime>().toList();
    final ends = [for (final s in sprints) DateTime.tryParse(s.endDate)].whereType<DateTime>().toList();
    if (starts.isEmpty || ends.isEmpty) return const SizedBox.shrink();

    final rangeStart = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final rangeEndRaw = ends.reduce((a, b) => a.isAfter(b) ? a : b);
    final gridStart = DateTime(rangeStart.year, rangeStart.month, 1);
    final gridEnd = DateTime(rangeEndRaw.year, rangeEndRaw.month + 1, 0);
    const pxPerDay = 8.0;
    final totalWidth = (gridEnd.difference(gridStart).inDays + 1) * pxPerDay;
    const labelWidth = 150.0;

    final months = <DateTime>[];
    var cursor = DateTime(gridStart.year, gridStart.month, 1);
    while (!cursor.isAfter(gridEnd)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    double offsetFor(DateTime d) => d.difference(gridStart).inDays * pxPerDay;
    final today = DateTime.now();
    final todayOffset = offsetFor(DateTime(today.year, today.month, today.day));

    final groups = <String, List<Sprint>>{
      'Sedang Berjalan': sprints.where((s) => s.status == 'active').toList(),
      'Direncanakan': sprints.where((s) => s.status == 'planned').toList(),
      'Selesai': sprints.where((s) => s.status == 'completed').toList(),
    }..removeWhere((_, v) => v.isEmpty);

    return SizedBox(
      width: totalWidth + labelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: labelWidth),
            SizedBox(
              width: totalWidth,
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final m in months)
                    Positioned(
                      left: offsetFor(m),
                      width: pxPerDay * DateTime(m.year, m.month + 1, 0).day,
                      child: Center(
                        child: Text('${monthsShort[m.month - 1]} ${m.year}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.grey500)),
                      ),
                    ),
                  if (todayOffset >= 0 && todayOffset <= totalWidth) Positioned(left: todayOffset, top: 0, bottom: -4, child: Container(width: 2, color: AppColors.error)),
                ],
              ),
            ),
          ]),
          const Divider(height: 16),
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${entry.key.toUpperCase()} (${entry.value.length})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary700, letterSpacing: 0.5)),
            ),
            for (final s in entry.value) _ganttRow(p, s, gridStart, pxPerDay, totalWidth, labelWidth),
          ],
        ],
      ),
    );
  }

  /// Render Gantt pada lebar natural + judul, lalu simpan sebagai satu
  /// halaman PDF (ukuran halaman menyesuaikan lebar roadmap).
  Future<void> _exportSprintRoadmapPdf(Project p, List<Sprint> sprints) async {
    setState(() => _exportingSprintRoadmap = true);
    try {
      final content = Material(
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sprint Execution Roadmap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Text('Timeline and iterations schedule', style: TextStyle(fontSize: 12, color: AppColors.grey500)),
              phGap(AppSpacing.md),
              _sprintRoadmapGrid(p, sprints),
            ],
          ),
        ),
      );
      final bytes = await _captureFullSize(content);
      if (bytes == null) throw Exception('Gagal membuat gambar roadmap');
      final image = await ui.instantiateImageCodec(bytes).then((c) => c.getNextFrame()).then((f) => f.image);
      final doc = pw.Document();
      final pdfImage = pw.MemoryImage(bytes);
      final pageWidth = image.width.toDouble();
      final pageHeight = image.height.toDouble();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, pageHeight, marginAll: 0),
          build: (_) => pw.Image(pdfImage, fit: pw.BoxFit.contain),
        ),
      );
      final pdfBytes = await doc.save();
      final fileName = 'sprint_roadmap_${p.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      if (mounted) phToast(context, 'Gagal membuat PDF: $e');
    } finally {
      if (mounted) setState(() => _exportingSprintRoadmap = false);
    }
  }

  Widget _ganttRow(Project p, Sprint s, DateTime gridStart, double pxPerDay, double totalWidth, double labelWidth) {
    final start = DateTime.tryParse(s.startDate) ?? gridStart;
    final end = DateTime.tryParse(s.endDate) ?? start;
    final left = (start.difference(gridStart).inDays * pxPerDay).clamp(0.0, totalWidth);
    final width = ((end.difference(start).inDays + 1) * pxPerDay).clamp(20.0, totalWidth);
    final tasks = _sprintTasks(p, s);
    final (done, total) = _taskCounts(tasks);
    final progress = total > 0 ? done / total : 0.0;
    final color = switch (s.status) {
      'active' => AppColors.primary600,
      'completed' => AppColors.success,
      _ => AppColors.grey400,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: InkWell(
              onTap: () => openSprintForm(context, p, sprint: s),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hierarchyBadge('SP-${s.id.toString().padLeft(2, '0')}', AppColors.accent200.withValues(alpha: 0.3), AppColors.primary800),
                    Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    Text('$total task', style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: totalWidth,
            height: 26,
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  child: Container(
                    width: width,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------- Sprint Table (= Sprint Iteration Directory)
  List<Widget> _sprintTableBody(Project p, List<Sprint> sprints) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => setState(() => _expandedSprintRows.addAll(sprints.map((s) => s.id))), child: const Text('Expand All')),
          TextButton(onPressed: () => setState(_expandedSprintRows.clear), child: const Text('Collapse All')),
        ],
      ),
      for (final s in sprints) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _sprintTableRow(p, s)),
      PhButton('Sprint baru', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openSprintForm(context, p)),
    ];
  }

  Widget _sprintTableRow(Project p, Sprint s) {
    final expanded = _expandedSprintRows.contains(s.id);
    final tasks = _sprintTasks(p, s);
    final (done, total) = _taskCounts(tasks);
    final progress = total > 0 ? done / total : 0.0;
    final milestoneTitle = p.milestones.where((m) => m.id == s.milestoneId).firstOrNull?.title ?? s.milestone;
    return PhCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => expanded ? _expandedSprintRows.remove(s.id) : _expandedSprintRows.add(s.id)),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 20, color: AppColors.grey500),
                _hierarchyBadge('SP-${s.id.toString().padLeft(2, '0')}', AppColors.accent200.withValues(alpha: 0.3), AppColors.primary800),
                const SizedBox(width: 6),
                Expanded(child: Text('${s.name}  ($total task${total == 1 ? '' : 's'})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Ubah sprint',
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.grey500),
                  onPressed: () => openSprintForm(context, p, sprint: s),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Hapus sprint',
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.grey400),
                  onPressed: () => _confirmDelete('sprint', () => _store.deleteSprint(p, s)),
                ),
              ],
            ),
          ),
          if (milestoneTitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, left: 28), child: _hierarchyBadge(milestoneTitle, AppColors.primary50, AppColors.primary700)),
          phGap(6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(children: [
              if (s.leadId.isNotEmpty) ...[
                PhAvatar(s.leadId, size: 20),
                const SizedBox(width: 6),
                Text(_store.nameOf(s.leadId), style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
                const SizedBox(width: 10),
              ],
              PhPill.status('sprint', s.status),
              if (s.priority.isNotEmpty) ...[const SizedBox(width: 6), PhPill.status('priority', s.priority)],
            ]),
          ),
          phGap(6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.primary600)),
                ),
              ),
              const SizedBox(width: 6),
              Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary700)),
            ]),
          ),
          phGap(4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text('${fmtDate(s.startDate)} → ${fmtDate(s.endDate)}', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
          ),
          if (expanded) ...[
            phGap(AppSpacing.sm),
            for (final t in tasks) Padding(padding: const EdgeInsets.only(left: 28, bottom: 6), child: _taskRow(t)),
            if (tasks.isEmpty) const Padding(padding: EdgeInsets.only(left: 28), child: Text('Belum ada task', style: TextStyle(fontSize: 12, color: AppColors.grey500))),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Tim
  Widget _team(Project p) => _list([
        for (final m in p.members) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _teamMemberCard(p, m)),
        PhButton('Tambah anggota', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openMemberForm(context, p)),
      ]);

  Widget _teamMemberCard(Project p, ProjectMember m) {
    final user = _store.users[m.userId];
    final memberImages = <String>[
      ...m.images,
      for (final url in (user?.images ?? const <String>[]))
        if (!m.images.contains(url)) url,
    ];
    final tasks = TaskRepository.instance.tasks.where((t) => t.projectId == p.id && t.assignedTo == m.userId).toList();
    final done = tasks.where((t) => t.done).length;
    final total = tasks.length;
    final percent = total > 0 ? (done / total * 100).round() : 0;
    final tickets = _store.tickets.where((t) => t.assigneeId == m.userId && (t.projectId == p.id || t.projectName == p.name)).length;
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhAvatar(m.userId, size: 48, imageUrl: m.photoUrl, images: memberImages),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_store.nameOf(m.userId), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    if (user != null && user.email.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 2), child: Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.grey500))),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Keluarkan ${_store.nameOf(m.userId)}',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.person_remove_outlined, color: AppColors.error, size: 20),
                onPressed: () => _confirmDelete('anggota', () => _store.removeMember(p, m)),
              ),
            ],
          ),
          phGap(AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (user != null && user.role.isNotEmpty) PhPill(_titleCaseRole(user.role), fg: AppColors.primary700, bg: AppColors.primary50),
              PhPill(m.role.isEmpty ? 'Anggota' : m.role, fg: AppColors.grey700, bg: AppColors.grey100),
            ],
          ),
          phGap(AppSpacing.sm),
          const Divider(height: 1, color: AppColors.grey100),
          phGap(AppSpacing.sm),
          Row(children: [
            const Text('Tugas Selesai', style: TextStyle(fontSize: 12.5, color: AppColors.grey700)),
            const Spacer(),
            Text('$done / $total ($percent%)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary700)),
          ]),
          phGap(6),
          Row(children: [
            const Icon(Icons.confirmation_number_outlined, size: 14, color: AppColors.grey400),
            const SizedBox(width: 4),
            Text('$tickets Tiket', style: const TextStyle(fontSize: 12.5, color: AppColors.grey700)),
          ]),
          phGap(6),
          Row(children: [
            const Icon(Icons.event_outlined, size: 14, color: AppColors.grey400),
            const SizedBox(width: 4),
            Text('Bergabung: ${user != null && user.joinedAt.isNotEmpty ? fmtDate(user.joinedAt) : '-'}', style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
          ]),
        ],
      ),
    );
  }

  String _titleCaseRole(String role) => role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}';

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

  // ---------------------------------------------------------------- File
  List<ProjectFile> _filteredFiles(Project p) {
    var list = p.files.where((f) {
      if (_fileSource == 'task' && !f.fromTask) return false;
      if (_fileSource == 'standalone' && f.fromTask) return false;
      if (_fileType == 'file' && f.isLink) return false;
      if (_fileType == 'link' && !f.isLink) return false;
      if (_fileFolder != 'all' && f.folder != _fileFolder) return false;
      return true;
    }).toList();
    if (_fileSearch.trim().isNotEmpty) {
      final q = _fileSearch.trim().toLowerCase();
      list = list.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Widget _files(Project p) {
    final all = p.files;
    final taskFiles = all.where((f) => f.fromTask).length;
    final standaloneFiles = all.length - taskFiles;
    final links = all.where((f) => f.isLink).length;
    final totalSize = all.fold<int>(0, (s, f) => s + f.size);
    final folders = <String, int>{};
    for (final f in all) {
      folders.update(f.folder, (v) => v + 1, ifAbsent: () => 1);
    }
    final filtered = _filteredFiles(p);

    return _list([
      if (all.isNotEmpty) ...[
        _filesStatsRow(all.length, taskFiles, standaloneFiles, links, totalSize),
        phGap(AppSpacing.md),
        _searchField('Cari nama file atau link...', _fileSearch, (v) => setState(() => _fileSearch = v)),
        phGap(AppSpacing.sm),
        Row(children: [
          Expanded(child: _filesViewToggle()),
          const SizedBox(width: AppSpacing.sm),
          IconButton(tooltip: 'Tambah link', icon: const Icon(Icons.add_link_rounded, color: AppColors.primary700), onPressed: () => openLinkForm(context, p)),
          IconButton(tooltip: 'Unggah file', icon: const Icon(Icons.upload_file_rounded, color: AppColors.primary700), onPressed: () => openFileForm(context, p)),
        ]),
        phGap(AppSpacing.md),
        _fileFilterRow([
          (Icons.apps_rounded, 'all', 'Semua', all.length, AppColors.grey700),
          (Icons.attach_file_rounded, 'task', 'Lampiran Task', taskFiles, AppColors.info),
          (Icons.create_new_folder_rounded, 'standalone', 'Standalone', standaloneFiles, AppColors.success),
        ], _fileSource, (v) => setState(() => _fileSource = v)),
        const SizedBox(height: 8),
        _fileFilterRow([
          (Icons.filter_list_rounded, 'all', 'Semua Tipe', all.length, AppColors.grey700),
          (Icons.insert_drive_file_outlined, 'file', 'File', all.length - links, AppColors.primary700),
          (Icons.link_rounded, 'link', 'Link', links, AppColors.warning),
        ], _fileType, (v) => setState(() => _fileType = v)),
        if (folders.length > 1) ...[
          const SizedBox(height: 8),
          _fileFilterRow([
            (Icons.folder_rounded, 'all', 'Semua Folder', all.length, AppColors.grey700),
            for (final e in folders.entries) (Icons.folder_outlined, e.key, e.key, e.value, AppColors.primary600),
          ], _fileFolder, (v) => setState(() => _fileFolder = v)),
        ],
        phGap(AppSpacing.sm),
      ],
      if (all.isEmpty) const PhEmpty(Icons.folder_open_outlined, 'Belum ada file'),
      if (all.isNotEmpty && filtered.isEmpty) const PhEmpty(Icons.search_off_rounded, 'Tidak ada file yang cocok'),
      if (filtered.isNotEmpty) (_filesGridView ? _filesGrid(p, filtered) : _filesListView(p, filtered)),
      if (all.isEmpty) ...[
        phGap(AppSpacing.md),
        PhButton('Unggah file', icon: Icons.upload_file, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openFileForm(context, p)),
      ],
    ]);
  }

  /// Donut Lampiran Task vs Standalone (keduanya persis menjumlah ke Total
  /// Berkas) + baris metrik Tautan/Links terpisah (bukan irisan pie karena
  /// sebuah link bisa saja lampiran task ATAU standalone, jadi tidak
  /// eksklusif terhadap dua slice di atas — digabung jadi satu slice akan
  /// menyesatkan). Kapasitas Storage jadi kartu sendiri di bawahnya.
  Widget _filesStatsRow(int total, int taskFiles, int standalone, int links, int totalSize) {
    if (total == 0) return const SizedBox.shrink();
    return Column(
      children: [
        PhCard(
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 26,
                      sections: [
                        if (taskFiles > 0) PieChartSectionData(value: taskFiles.toDouble(), color: AppColors.info, showTitle: false, radius: 20),
                        if (standalone > 0) PieChartSectionData(value: standalone.toDouble(), color: AppColors.success, showTitle: false, radius: 20),
                      ],
                    )),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                      const Text('Berkas', style: TextStyle(fontSize: 9.5, color: AppColors.grey500)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sprintStatLegend(AppColors.info, 'Lampiran Task', taskFiles),
                    const SizedBox(height: 8),
                    _sprintStatLegend(AppColors.success, 'File Standalone', standalone),
                    const SizedBox(height: 8),
                    _sprintStatLegend(AppColors.warning, 'Tautan / Links', links),
                  ],
                ),
              ),
            ],
          ),
        ),
        phGap(AppSpacing.sm),
        PhCard(
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.accent400.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.small)),
              child: const Icon(Icons.storage_rounded, color: AppColors.accent400, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kapasitas Storage', style: TextStyle(fontSize: 12, color: AppColors.grey700)),
                  Text('Total ukuran berkas', style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                ],
              ),
            ),
            Text(fileSize(totalSize), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.accent400)),
          ]),
        ),
      ],
    );
  }

  /// Baris filter chip custom (ikon + label + count), dipakai untuk Sumber,
  /// Tipe, dan Folder di tab File — lebih tegas secara visual dibanding
  /// pill generik: warna aksen beda per kategori, terisi solid saat aktif.
  Widget _fileFilterRow(List<(IconData, String, String, int, Color)> items, String selected, ValueChanged<String> onSelected) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (icon, key, label, count, color) = items[i];
          final active = key == selected;
          return GestureDetector(
            onTap: () => onSelected(key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? color : AppColors.grey100,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: active ? Colors.white : color),
                  const SizedBox(width: 5),
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.grey700)),
                  const SizedBox(width: 4),
                  Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white70 : AppColors.grey500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filesViewToggle() {
    Widget seg(IconData icon, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: selected ? AppColors.primary700 : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.full)),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: selected ? Colors.white : AppColors.grey700),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(children: [
        seg(Icons.grid_view_rounded, _filesGridView, () => setState(() => _filesGridView = true)),
        seg(Icons.view_list_rounded, !_filesGridView, () => setState(() => _filesGridView = false)),
      ]),
    );
  }

  Widget _filesGrid(Project p, List<ProjectFile> files) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.7,
      ),
      itemCount: files.length,
      itemBuilder: (_, i) => _fileGridCard(p, files[i]),
    );
  }

  Widget _fileGridCard(Project p, ProjectFile f) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.medium), boxShadow: phCardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _openFile(f),
            child: SizedBox(
              height: 84,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: f.mimeType.startsWith('image/') && f.url.isNotEmpty
                        ? CachedNetworkImage(imageUrl: f.url, fit: BoxFit.cover, errorWidget: (_, _, _) => _fileIconBg(f))
                        : _fileIconBg(f),
                  ),
                  Positioned(top: 6, left: 6, child: _miniBadge(f.isLink ? 'Link' : 'File', f.isLink ? AppColors.info : AppColors.primary700)),
                  Positioned(top: 6, right: 6, child: _miniBadge(f.fromTask ? 'Task' : 'Standalone', f.fromTask ? AppColors.primary700 : AppColors.success)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (f.fromTask)
                  Text(f.taskTitle.isEmpty ? 'Task' : f.taskTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.primary700, fontWeight: FontWeight.w600))
                else
                  Text('Folder: ${f.folder}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                const SizedBox(height: 4),
                Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(children: [
                  PhAvatar(f.uploaderId, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.isLink ? 'Link' : fileSize(f.size), style: const TextStyle(fontSize: 10.5, color: AppColors.grey500))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(timeAgo(f.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.grey400))),
                  IconButton(
                    tooltip: 'Hapus ${f.name}',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.error),
                    onPressed: () => _confirmDelete(f.isLink ? 'link' : 'file', () => _store.deleteFile(p, f)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileIconBg(ProjectFile f) => Container(
        color: (f.isLink ? AppColors.info : AppColors.primary700).withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: Icon(
          f.isLink ? Icons.link_rounded : (f.mimeType.startsWith('image/') ? Icons.image_outlined : Icons.insert_drive_file_outlined),
          size: 32,
          color: f.isLink ? AppColors.info : AppColors.primary700,
        ),
      );

  Widget _miniBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.small)),
        child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
      );

  Widget _filesListView(Project p, List<ProjectFile> files) {
    return Column(
      children: [for (final f in files) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _fileListRow(p, f))],
    );
  }

  Widget _fileListRow(Project p, ProjectFile f) {
    final accent = f.isLink ? AppColors.info : (f.mimeType.startsWith('image/') ? AppColors.accent400 : AppColors.primary700);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: () => _openFile(f),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.medium), boxShadow: phCardShadow),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.small)),
                child: Icon(f.isLink ? Icons.link_rounded : (f.mimeType.startsWith('image/') ? Icons.image_outlined : Icons.insert_drive_file_outlined), color: accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _miniBadge(f.fromTask ? 'Task' : 'Standalone', f.fromTask ? AppColors.primary700 : AppColors.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          f.fromTask ? (f.taskTitle.isEmpty ? '-' : f.taskTitle) : f.folder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.grey700),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('${f.isLink ? 'Link' : fileSize(f.size)} · ${timeAgo(f.createdAt)}', style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus ${f.name}',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => _confirmDelete(f.isLink ? 'link' : 'file', () => _store.deleteFile(p, f)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(ProjectFile f) async {
    if (f.url.isEmpty) return;
    if (f.mimeType.startsWith('image/')) {
      _preview(f);
      return;
    }
    final uri = Uri.tryParse(f.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      phToast(context, 'Tidak dapat membuka tautan');
    }
  }

  // ---------------------------------------------------------------- Knowledge Base
  List<KbDocument> _filteredKbDocuments(Project p) {
    var list = p.kbDocuments.where((d) => _kbCategory == 'all' || d.category == _kbCategory).toList();
    if (_kbSearch.trim().isNotEmpty) {
      final q = _kbSearch.trim().toLowerCase();
      list = list.where((d) => d.title.toLowerCase().contains(q) || d.summary.toLowerCase().contains(q) || d.body.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Widget _knowledgeBase(Project p) {
    final docs = p.kbDocuments;
    final filtered = _filteredKbDocuments(p);
    final categoryCounts = <String, int>{for (final c in statusOptions('kb_category')) c.$1: docs.where((d) => d.category == c.$1).length};

    return _list([
      Row(children: [
        const Expanded(child: Text('Knowledge Base & Documentation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        PhPill('${docs.length} Dokumen', fg: AppColors.primary700, bg: AppColors.primary50),
      ]),
      const SizedBox(height: 4),
      const Text(
        'Pusat dokumentasi tim & onboarding: BRD, PRD, FSD, MOM hasil meeting, arsitektur sistem, dan panduan teknis.',
        style: TextStyle(fontSize: 12, color: AppColors.grey700),
      ),
      phGap(AppSpacing.md),
      PhButton('Tambah Dokumen', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openKbDocumentForm(context, p)),
      phGap(AppSpacing.md),
      _fileFilterRow([
        (Icons.apps_rounded, 'all', 'Semua Dokumen', docs.length, AppColors.grey700),
        for (final c in statusOptions('kb_category')) (Icons.circle, c.$1, c.$2, categoryCounts[c.$1] ?? 0, statusStyle('kb_category', c.$1).fg),
      ], _kbCategory, (v) => setState(() => _kbCategory = v)),
      phGap(AppSpacing.sm),
      _searchField('Cari berdasarkan judul, ringkasan, atau isi dokumen...', _kbSearch, (v) => setState(() => _kbSearch = v)),
      phGap(AppSpacing.sm),
      Text('Menampilkan ${filtered.length} dokumen', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
      phGap(AppSpacing.sm),
      if (docs.isEmpty) const PhEmpty(Icons.menu_book_outlined, 'Belum ada dokumen'),
      if (docs.isNotEmpty && filtered.isEmpty) const PhEmpty(Icons.search_off_rounded, 'Tidak ada dokumen yang cocok'),
      for (final d in filtered) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _kbDocumentCard(p, d)),
    ]);
  }

  Widget _kbDocumentCard(Project p, KbDocument d) {
    final style = statusStyle('kb_category', d.category);
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            PhPill(style.label, fg: style.fg, bg: style.bg),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.small)),
              child: Text('v${d.version}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.grey700)),
            ),
          ]),
          phGap(AppSpacing.sm),
          Text(d.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (d.summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(d.summary, style: const TextStyle(fontSize: 13, color: AppColors.grey700))),
          if (d.attachments.isNotEmpty) ...[
            phGap(AppSpacing.sm),
            Text('LAMPIRAN FILE (${d.attachments.length})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.grey500, letterSpacing: 0.4)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in d.attachments)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.small)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.insert_drive_file_outlined, size: 14, color: AppColors.grey500),
                      const SizedBox(width: 4),
                      Text(a.name, style: const TextStyle(fontSize: 11.5, color: AppColors.grey900)),
                      const SizedBox(width: 4),
                      Text(fileSize(a.size), style: const TextStyle(fontSize: 10, color: AppColors.grey400)),
                    ]),
                  ),
              ],
            ),
          ],
          phGap(AppSpacing.md),
          const Divider(height: 1, color: AppColors.grey100),
          phGap(AppSpacing.sm),
          Row(children: [
            PhAvatar(d.authorId, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_store.nameOf(d.authorId), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(timeAgo(d.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ubah dokumen',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.grey500),
              onPressed: () => openKbDocumentForm(context, p, doc: d),
            ),
            TextButton(onPressed: () => _readKbDocument(d), child: const Text('Baca →')),
          ]),
        ],
      ),
    );
  }

  void _readKbDocument(KbDocument d) {
    final style = statusStyle('kb_category', d.category);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(4)))),
              phGap(AppSpacing.md),
              Row(children: [
                PhPill(style.label, fg: style.fg, bg: style.bg),
                const SizedBox(width: 8),
                Text('v${d.version}', style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
              ]),
              phGap(AppSpacing.sm),
              Text(d.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              if (d.summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(d.summary, style: const TextStyle(fontSize: 13.5, color: AppColors.grey700))),
              phGap(AppSpacing.md),
              if (d.body.isNotEmpty)
                Text(d.body, style: const TextStyle(fontSize: 14, height: 1.6))
              else
                const Text('Belum ada isi dokumen.', style: TextStyle(fontSize: 13, color: AppColors.grey500)),
              if (d.attachments.isNotEmpty) ...[
                phGap(AppSpacing.lg),
                const Text('LAMPIRAN FILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey500, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                for (final a in d.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: PhListRow(
                      leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary600),
                      title: a.name,
                      subtitle: fileSize(a.size),
                      onTap: a.url.isEmpty ? null : () => _openKbAttachment(a),
                    ),
                  ),
              ],
              phGap(AppSpacing.lg),
              Row(children: [
                PhAvatar(d.authorId, size: 28),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_store.nameOf(d.authorId), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(fmtDateTime(d.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                  ],
                ),
              ]),
              phGap(60),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openKbAttachment(KbAttachment a) async {
    final uri = Uri.tryParse(a.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      phToast(context, 'Tidak dapat membuka file');
    }
  }

  // ---------------------------------------------------------------- Timesheet (Gantt Chart jadwal task)
  static const _ganttStatusColors = {
    'todo': Color(0xFF9575CD),
    'in_progress': AppColors.info,
    'review': Color(0xFFD81B60),
    'done': AppColors.success,
  };
  static const _ganttSprintColor = Color(0xFF5E35B1);

  bool _isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  /// Posisi & lebar bar (px) pada grid bulan [monthStart]..[monthStart+daysInMonth],
  /// dipotong (clamp) ke batas bulan yang sedang ditampilkan. Null kalau task
  /// tidak punya tanggal sama sekali atau di luar bulan ini.
  (double, double)? _ganttBarRange(String startIso, String endIso, DateTime monthStart, int daysInMonth, double pxPerDay) {
    final s = DateTime.tryParse(startIso);
    final e = DateTime.tryParse(endIso);
    if (s == null && e == null) return null;
    var start = s ?? e!;
    var end = e ?? s!;
    if (end.isBefore(start)) end = start;
    final monthEndExclusive = monthStart.add(Duration(days: daysInMonth));
    if (end.isBefore(monthStart) || start.isAfter(monthEndExclusive.subtract(const Duration(days: 1)))) return null;
    if (start.isBefore(monthStart)) start = monthStart;
    if (end.isAfter(monthEndExclusive.subtract(const Duration(days: 1)))) end = monthEndExclusive.subtract(const Duration(days: 1));
    final left = start.difference(monthStart).inDays * pxPerDay;
    final width = (end.difference(start).inDays + 1) * pxPerDay;
    return (left, width);
  }

  List<TaskEntry> _filteredGanttTasks(Project p) {
    var list = TaskRepository.instance.tasks.where((t) => t.projectId == p.id).toList();
    if (_ganttStatus != 'all') list = list.where((t) => t.status == _ganttStatus).toList();
    if (_ganttSearch.trim().isNotEmpty) {
      final q = _ganttSearch.trim().toLowerCase();
      list = list.where((t) => t.title.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Widget _timesheet(Project p) {
    final allTasks = TaskRepository.instance.tasks.where((t) => t.projectId == p.id).toList();
    final tasks = _filteredGanttTasks(p);

    return _list([
      Row(children: [
        IconButton(onPressed: () => setState(() => _ganttMonth = DateTime(_ganttMonth.year, _ganttMonth.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Center(
            child: Text('${monthsLong[_ganttMonth.month - 1]} ${_ganttMonth.year}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        IconButton(onPressed: () => setState(() => _ganttMonth = DateTime(_ganttMonth.year, _ganttMonth.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
        IconButton(
          tooltip: 'Download PDF',
          onPressed: _exportingGantt || allTasks.isEmpty ? null : () => _exportGanttPdf(p, tasks),
          icon: _exportingGantt
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary700),
        ),
      ]),
      phGap(AppSpacing.sm),
      if (allTasks.isNotEmpty) ...[
        _searchField('Cari task...', _ganttSearch, (v) => setState(() => _ganttSearch = v)),
        phGap(AppSpacing.sm),
        _fileFilterRow([
          (Icons.apps_rounded, 'all', 'Semua', allTasks.length, AppColors.grey700),
          (Icons.radio_button_unchecked, 'todo', 'To Do', allTasks.where((t) => t.status == 'todo').length, _ganttStatusColors['todo']!),
          (Icons.autorenew_rounded, 'in_progress', 'In Progress', allTasks.where((t) => t.status == 'in_progress').length, _ganttStatusColors['in_progress']!),
          (Icons.rate_review_outlined, 'review', 'Review', allTasks.where((t) => t.status == 'review').length, _ganttStatusColors['review']!),
          (Icons.check_circle_outline, 'done', 'Done', allTasks.where((t) => t.status == 'done').length, _ganttStatusColors['done']!),
        ], _ganttStatus, (v) => setState(() => _ganttStatus = v)),
        phGap(AppSpacing.sm),
      ],
      if (allTasks.isEmpty) const PhEmpty(Icons.view_timeline_outlined, 'Belum ada task berjadwal'),
      if (allTasks.isNotEmpty && tasks.isEmpty) const PhEmpty(Icons.search_off_rounded, 'Tidak ada task yang cocok'),
      if (tasks.isNotEmpty)
        PhCard(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _ganttGrid(p, tasks),
          ),
        ),
      phGap(AppSpacing.md),
      _ganttLegend(),
    ]);
  }

  /// Grid Gantt pada lebar natural (jumlah hari dalam bulan * pxPerDay) —
  /// dipakai untuk tampilan layar (dibungkus scroll horizontal) maupun
  /// ekspor PDF (ditangkap langsung tanpa viewport).
  Widget _ganttGrid(Project p, List<TaskEntry> tasks) {
    final monthStart = DateTime(_ganttMonth.year, _ganttMonth.month, 1);
    final daysInMonth = DateTime(_ganttMonth.year, _ganttMonth.month + 1, 0).day;
    const pxPerDay = 36.0;
    const labelWidth = 176.0;
    final totalWidth = daysInMonth * pxPerDay;
    final today = DateTime.now();

    final bySprint = <String, List<TaskEntry>>{};
    for (final t in tasks) {
      bySprint.putIfAbsent(t.sprint, () => []).add(t);
    }
    final sprintByName = {for (final s in p.sprints) s.name: s};

    return SizedBox(
      width: totalWidth + labelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: labelWidth),
            for (var i = 0; i < daysInMonth; i++)
              Builder(builder: (_) {
                final d = monthStart.add(Duration(days: i));
                final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                return Container(
                  width: pxPerDay,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: _isWeekend(d) ? AppColors.grey100 : null,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(weekdaysLong[d.weekday - 1].substring(0, 3).toUpperCase(), style: const TextStyle(fontSize: 8.5, color: AppColors.grey400)),
                    const SizedBox(height: 2),
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: isToday ? const BoxDecoration(color: AppColors.primary700, shape: BoxShape.circle) : null,
                      child: Text('${d.day}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isToday ? Colors.white : AppColors.grey700)),
                    ),
                  ]),
                );
              }),
          ]),
          const Divider(height: 14),
          for (final entry in bySprint.entries) ...[
            if (entry.key.isNotEmpty)
              _ganttSprintRow(p, sprintByName[entry.key], entry.key, entry.value.length, monthStart, daysInMonth, pxPerDay, labelWidth)
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('TANPA SPRINT (${entry.value.length})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.grey500, letterSpacing: 0.5)),
              ),
            for (final t in entry.value) _ganttTaskRow(t, monthStart, daysInMonth, pxPerDay, labelWidth),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Future<void> _exportGanttPdf(Project p, List<TaskEntry> tasks) async {
    setState(() => _exportingGantt = true);
    try {
      final content = Material(
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gantt Chart — ${monthsLong[_ganttMonth.month - 1]} ${_ganttMonth.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              phGap(AppSpacing.md),
              _ganttGrid(p, tasks),
              phGap(AppSpacing.md),
              _ganttLegend(),
            ],
          ),
        ),
      );
      final bytes = await _captureFullSize(content);
      if (bytes == null) throw Exception('Gagal membuat gambar Gantt chart');
      final image = await ui.instantiateImageCodec(bytes).then((c) => c.getNextFrame()).then((f) => f.image);
      final doc = pw.Document();
      final pdfImage = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(image.width.toDouble(), image.height.toDouble(), marginAll: 0),
          build: (_) => pw.Image(pdfImage, fit: pw.BoxFit.contain),
        ),
      );
      final pdfBytes = await doc.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: 'gantt_${p.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e) {
      if (mounted) phToast(context, 'Gagal membuat PDF: $e');
    } finally {
      if (mounted) setState(() => _exportingGantt = false);
    }
  }

  Widget _ganttSprintRow(Project p, Sprint? s, String name, int taskCount, DateTime monthStart, int daysInMonth, double pxPerDay, double labelWidth) {
    final totalWidth = daysInMonth * pxPerDay;
    final range = s == null ? null : _ganttBarRange(s.startDate, s.endDate, monthStart, daysInMonth, pxPerDay);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: InkWell(
              onTap: s == null ? null : () => openSprintForm(context, p, sprint: s),
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ganttSprintColor)),
            ),
          ),
          SizedBox(
            width: totalWidth,
            height: 26,
            child: Stack(children: [
              if (range != null)
                Positioned(
                  left: range.$1,
                  child: Container(
                    width: range.$2,
                    height: 22,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: _ganttSprintColor, borderRadius: BorderRadius.circular(6)),
                    child: Text('« $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _ganttTaskRow(TaskEntry t, DateTime monthStart, int daysInMonth, double pxPerDay, double labelWidth) {
    final totalWidth = daysInMonth * pxPerDay;
    final range = _ganttBarRange(t.startDate.isEmpty ? t.dueDate : t.startDate, t.dueDate, monthStart, daysInMonth, pxPerDay);
    final color = _ganttStatusColors[t.status] ?? AppColors.grey400;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: InkWell(
              onTap: () => context.push('/task/${t.id}'),
              child: Row(children: [
                PhAvatar(t.assignedTo, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      Text(statusLabel('task', t.status), style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          SizedBox(
            width: totalWidth,
            height: 26,
            child: Stack(children: [
              if (range != null)
                Positioned(
                  left: range.$1,
                  child: Container(
                    width: range.$2,
                    height: 22,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    child: range.$2 > 70
                        ? Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600))
                        : null,
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _ganttLegend() {
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.grey700)),
        ]);
    return Wrap(spacing: 14, runSpacing: 8, children: [
      dot(_ganttStatusColors['todo']!, 'To Do'),
      dot(_ganttStatusColors['in_progress']!, 'In Progress'),
      dot(_ganttStatusColors['review']!, 'Review'),
      dot(_ganttStatusColors['done']!, 'Done'),
      dot(_ganttSprintColor, 'Sprint'),
    ]);
  }

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
    final all = _store.tickets.where((t) => t.projectId == p.id || t.projectName == p.name).toList();
    final activeCount = all.where((t) => t.status != 'resolved' && t.status != 'closed').length;
    final doneCount = all.where((t) => t.status == 'resolved' || t.status == 'closed').length;
    final breachCount = all.where((t) => t.slaBreached).length;

    final q = _ticketSearch.trim().toLowerCase();
    final filtered = all.where((t) {
      if (_ticketStatus != 'all' && t.status != _ticketStatus) return false;
      if (_ticketPriority != 'all' && t.priority != _ticketPriority) return false;
      if (_ticketType != 'all' && t.type != _ticketType) return false;
      if (q.isNotEmpty && !t.title.toLowerCase().contains(q) && !t.description.toLowerCase().contains(q) && !'${t.id}'.contains(q)) {
        return false;
      }
      return true;
    }).toList();

    return _list([
      // ── 4 Kartu Ringkasan Metrik Tiket (Grid 2x2) ──
      Row(
        children: [
          Expanded(
            child: _ticketSummaryCard(
              icon: Icons.confirmation_number_outlined,
              iconColor: AppColors.grey700,
              iconBg: AppColors.grey100,
              label: 'TOTAL TICKETS',
              value: '${all.length}',
              valueColor: AppColors.grey900,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ticketSummaryCard(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFFD97706),
              iconBg: const Color(0xFFFEF3C7),
              label: 'TIKET AKTIF',
              value: '$activeCount',
              valueColor: const Color(0xFFD97706),
            ),
          ),
        ],
      ),
      phGap(AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: _ticketSummaryCard(
              icon: Icons.check_rounded,
              iconColor: const Color(0xFF16A34A),
              iconBg: const Color(0xFFDCFCE7),
              label: 'SELESAI',
              value: '$doneCount',
              valueColor: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ticketSummaryCard(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFDC2626),
              iconBg: const Color(0xFFFEE2E2),
              label: 'SLA BREACH',
              value: '$breachCount',
              valueColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
      phGap(AppSpacing.md),

      // ── Header Tickets & Issues + Search + Filter Dropdowns ──
      PhCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Tickets & Issues',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.grey900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text('${all.length}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.grey700)),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => openTicketForm(context, project: p),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: const Text('Create Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Daftar tiket kendala, bug, dan issue teknis yang dilaporkan pada proyek ini',
              style: TextStyle(fontSize: 12, color: AppColors.grey500),
            ),
            const SizedBox(height: 12),
            _searchField('Cari judul tiket...', _ticketSearch, (v) => setState(() => _ticketSearch = v)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ticketFilterMenu(
                    icon: Icons.check_circle_outline_rounded,
                    prefix: 'Status',
                    selected: _ticketStatus,
                    options: [('all', 'All Status'), ...statusOptions('ticket')],
                    onSelected: (v) => setState(() => _ticketStatus = v),
                  ),
                  const SizedBox(width: 8),
                  _ticketFilterMenu(
                    icon: Icons.warning_amber_rounded,
                    prefix: 'Prioritas',
                    selected: _ticketPriority,
                    options: [
                      ('all', 'All Priority'),
                      for (final e in statusOptions('priority').where((e) => e.$1 != 'urgent')) e,
                    ],
                    onSelected: (v) => setState(() => _ticketPriority = v),
                  ),
                  const SizedBox(width: 8),
                  _ticketFilterMenu(
                    icon: Icons.sell_outlined,
                    prefix: 'Tipe',
                    selected: _ticketType,
                    options: [
                      ('all', 'All Types'),
                      for (final e in ticketTypes.entries) (e.key, e.value),
                    ],
                    onSelected: (v) => setState(() => _ticketType = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      phGap(AppSpacing.md),

      // ── Daftar Tiket ──
      if (all.isEmpty)
        const PhEmpty(Icons.bug_report_outlined, 'Tidak ada tiket untuk proyek ini')
      else if (filtered.isEmpty)
        const PhEmpty(Icons.search_off_rounded, 'Tidak ada tiket yang cocok dengan filter'),
      for (final t in filtered)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TicketRow(t, project: p),
        ),
    ]);
  }

  Widget _ticketSummaryCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return PhCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppRadius.medium)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500, letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: valueColor, height: 1.15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketFilterMenu({
    required IconData icon,
    required String prefix,
    required String selected,
    required List<(String, String)> options,
    required ValueChanged<String> onSelected,
  }) {
    final currentLabel = options.where((o) => o.$1 == selected).firstOrNull?.$2 ?? options.first.$2;
    final isFiltered = selected != 'all';
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<String>(
            value: o.$1,
            child: Row(
              children: [
                Icon(
                  o.$1 == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: o.$1 == selected ? AppColors.primary700 : AppColors.grey400,
                ),
                const SizedBox(width: 8),
                Text(o.$2, style: TextStyle(fontSize: 13, fontWeight: o.$1 == selected ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.primary50 : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: isFiltered ? AppColors.primary600 : AppColors.grey400.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isFiltered ? AppColors.primary700 : AppColors.grey500),
            const SizedBox(width: 5),
            Text('$prefix: ', style: const TextStyle(fontSize: 12, color: AppColors.grey500, fontWeight: FontWeight.w500)),
            Text(
              currentLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isFiltered ? AppColors.primary800 : AppColors.grey900,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isFiltered ? AppColors.primary700 : AppColors.grey500),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Chat
  Widget _chat(Project p) => _list([
        PhButton('Buka chat proyek', icon: Icons.chat_bubble_outline, onPressed: () => context.push('/thread/${Uri.encodeComponent('proj:${p.id}')}')),
        phGap(),
        const Text('Anggota tim proyek otomatis ada di chat ini.', style: TextStyle(fontSize: 12, color: AppColors.grey700)),
      ]);
}

class _ProjectLogo extends StatelessWidget {
  final Project project;
  final double size;
  const _ProjectLogo({required this.project, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: project.logoUrl.isEmpty
          ? Icon(Icons.folder_copy_rounded, color: AppColors.primary700, size: size * 0.5)
          : CachedNetworkImage(
              imageUrl: project.logoUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox(),
              errorWidget: (_, _, _) => Icon(Icons.folder_copy_rounded, color: AppColors.primary700, size: size * 0.5),
            ),
    );
  }
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
