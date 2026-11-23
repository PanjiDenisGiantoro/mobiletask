import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../data/task_repository.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_widgets.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/task_tile.dart';
import 'add_task_form_sheet.dart';
import 'ticket_screens.dart';

/// Halaman "Work Activities" (Aktivitas Kerja) — menyatukan 4 tab modul manajemen pekerjaan
/// sesuai desain web ProjectHub Pro:
/// 1. `Task` (dengan filter Status, Prioritas, Assignee, Proyek, mode List & Kanban, `+ Tambah Task`)
/// 2. `Sprint` (dengan badge jumlah Active, filter Status, proyek, milestone, periode, progress story points)
/// 3. `Recurring` (dengan filter Status, daftar recurring task atau empty state)
/// 4. `Ticket` (3 kartu ringkasan Total Tickets, Tiket Terbuka, SLA Breach, filter Status & Prioritas, daftar tiket)
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _SprintWithProject {
  final Project project;
  final Sprint sprint;
  const _SprintWithProject(this.project, this.sprint);
}

class _TasksScreenState extends State<TasksScreen> {
  int _activeTab = 0; // 0: Task, 1: Sprint, 2: Recurring, 3: Ticket
  int _pageSize = 10;

  // Filter & Pagination Tab Task
  String _taskStatus = 'all';
  String _taskPriority = 'all';
  String _taskAssignee = 'all';
  String _taskProject = 'all';
  String _taskSearch = '';
  bool _taskKanbanView = false;
  int _taskPage = 1;

  // Filter & Pagination Tab Sprint
  String _sprintStatus = 'all';
  int _sprintPage = 1;

  // Filter Tab Recurring
  String _recurringStatus = 'all';

  // Filter & Pagination Tab Ticket
  String _ticketStatus = 'all';
  String _ticketPriority = 'all';
  int _ticketPage = 1;

  PhStore get _store => PhStore.instance;
  List<TaskEntry> get _tasks => TaskRepository.instance.tasks;
  List<Ticket> get _tickets => _store.tickets;

  List<_SprintWithProject> get _allSprints {
    final list = <_SprintWithProject>[];
    for (final p in _store.projects) {
      for (final s in p.sprints) {
        list.add(_SprintWithProject(p, s));
      }
    }
    list.sort((a, b) => b.sprint.id.compareTo(a.sprint.id));
    return list;
  }

  int get _activeSprintsCount =>
      _allSprints.where((e) => e.sprint.status == 'active').length;

  int get _doneThisWeekCount {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _tasks.where((t) {
      if (!t.done) return false;
      final d = DateTime.tryParse(t.dueDate);
      if (d == null) return false;
      return !d.isBefore(weekStart) && d.isBefore(weekEnd);
    }).length;
  }

  bool get _loading => _store.syncing && _tasks.isEmpty && _store.projects.isEmpty;

  @override
  void initState() {
    super.initState();
    TaskRepository.instance.addListener(_onChanged);
    _store.addListener(_onChanged);
    if (!_store.synced) _store.sync();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TaskRepository.instance.removeListener(_onChanged);
    _store.removeListener(_onChanged);
    super.dispose();
  }

  List<TaskEntry> get _filteredTasks {
    final list = _tasks.where((t) {
      if (_taskSearch.trim().isNotEmpty) {
        final q = _taskSearch.trim().toLowerCase();
        if (!t.title.toLowerCase().contains(q) && !t.project.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_taskStatus != 'all' && t.status != _taskStatus) return false;
      if (_taskPriority != 'all') {
        final p = switch (t.priority) {
          TaskPriority.urgent => 'urgent',
          TaskPriority.high => 'high',
          TaskPriority.medium => 'medium',
          TaskPriority.low => 'low',
        };
        if (p != _taskPriority) return false;
      }
      if (_taskAssignee != 'all' && t.assignedTo != _taskAssignee) return false;
      if (_taskProject != 'all' && t.project != _taskProject) return false;
      return true;
    }).toList();
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  List<_SprintWithProject> get _filteredSprints {
    return _allSprints.where((item) {
      if (_sprintStatus != 'all' && item.sprint.status != _sprintStatus) return false;
      return true;
    }).toList();
  }

  List<Ticket> get _filteredTickets {
    final list = _tickets.where((t) {
      if (_ticketStatus != 'all' && t.status != _ticketStatus) return false;
      if (_ticketPriority != 'all' && t.priority != _ticketPriority) return false;
      return true;
    }).toList();
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.heroStart,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroStart, AppColors.heroMid],
            ),
          ),
        ),
        title: const Text('Work Activities'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _store.sync,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: _store.sync,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 12),
                  _buildModuleTabs(),
                  const SizedBox(height: 14),
                  if (_activeTab == 0) _buildTaskTab(),
                  if (_activeTab == 1) _buildSprintTab(),
                  if (_activeTab == 2) _buildRecurringTab(),
                  if (_activeTab == 3) _buildTicketTab(),
                ],
              ),
            ),
    );
  }

  /// Header `MANAJEMEN PEKERJAAN` + `Work Activities (Aktivitas Kerja)` + pill `Total Tugas` & `Selesai Minggu Ini`.
  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MANAJEMEN PEKERJAAN',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Work Activities',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _statPill(
                  dotColor: const Color(0xFF2563EB),
                  label: 'Total Tugas: ',
                  value: '${_tasks.length}',
                ),
                _statPill(
                  dotColor: const Color(0xFF10B981),
                  label: 'Selesai Minggu Ini: ',
                  value: '$_doneThisWeekCount',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _statPill({required Color dotColor, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  /// Baris 4 tab seperti di web: `Task [100]`, `Sprint [7 Active]`, `Recurring`, `Ticket [9]`.
  Widget _buildModuleTabs() {
    final tabs = <(String, String?)>[
      ('Task', '${_tasks.length}'),
      ('Sprint', '$_activeSprintsCount Active'),
      ('Recurring', null),
      ('Ticket', '${_tickets.length}'),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = _activeTab == i;
            final (label, badge) = tabs[i];
            return InkWell(
              onTap: () => setState(() => _activeTab = i),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: Container(
                margin: const EdgeInsets.only(right: 18),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? const Color(0xFF2563EB) : Colors.transparent,
                      width: 2.4,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: active ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: TASK
  // ===========================================================================
  Widget _buildTaskTab() {
    final tasks = _filteredTasks;
    final assigneeIds = _tasks.map((t) => t.assignedTo).where((id) => id.isNotEmpty).toSet().toList();
    final projectNames = _store.projects.map((p) => p.name).toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris Filter + List/Kanban Switcher + Tombol + Tambah Task
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dropdownFilterPill(
              valueLabel: _taskStatus == 'all' ? 'Semua Status' : statusLabel('task', _taskStatus),
              active: _taskStatus != 'all',
              items: const [
                ('all', 'Semua Status'),
                ('todo', 'Todo'),
                ('in_progress', 'In Progress'),
                ('review', 'Review'),
                ('done', 'Completed'),
              ],
              onSelected: (v) => setState(() {
                _taskStatus = v;
                _taskPage = 1;
              }),
            ),
            _dropdownFilterPill(
              valueLabel: _taskPriority == 'all' ? 'Semua Prioritas' : _taskPriority.toUpperCase(),
              active: _taskPriority != 'all',
              items: const [
                ('all', 'Semua Prioritas'),
                ('urgent', 'Urgent'),
                ('high', 'High'),
                ('medium', 'Medium'),
                ('low', 'Low'),
              ],
              onSelected: (v) => setState(() {
                _taskPriority = v;
                _taskPage = 1;
              }),
            ),
            _dropdownFilterPill(
              valueLabel: _taskAssignee == 'all' ? 'Semua Assignee' : _store.nameOf(_taskAssignee),
              active: _taskAssignee != 'all',
              items: [
                const ('all', 'Semua Assignee'),
                for (final uid in assigneeIds) (uid, _store.nameOf(uid)),
              ],
              onSelected: (v) => setState(() {
                _taskAssignee = v;
                _taskPage = 1;
              }),
            ),
            _dropdownFilterPill(
              valueLabel: _taskProject == 'all' ? 'Filter Proyek' : _taskProject,
              active: _taskProject != 'all',
              items: [
                const ('all', 'Filter Proyek (Semua)'),
                for (final pName in projectNames) (pName, pName),
              ],
              onSelected: (v) => setState(() {
                _taskProject = v;
                _taskPage = 1;
              }),
            ),
            // List | Kanban toggle
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _viewToggleBtn(
                    active: !_taskKanbanView,
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'List',
                    onTap: () => setState(() => _taskKanbanView = false),
                  ),
                  _viewToggleBtn(
                    active: _taskKanbanView,
                    icon: Icons.view_kanban_outlined,
                    label: 'Kanban',
                    onTap: () => setState(() => _taskKanbanView = true),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => showAddTaskFormSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Tambah Task', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_taskKanbanView)
          _buildTaskKanbanBoard(tasks)
        else
          _buildTaskListCard(tasks),
      ],
    );
  }

  Widget _viewToggleBtn({
    required bool active,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF1F5F9) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListCard(List<TaskEntry> tasks) {
    if (tasks.isEmpty) {
      return PhCard(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
        child: Center(
          child: Text(
            _store.syncError ?? 'Belum ada task yang sesuai dengan filter.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    final totalPages = (tasks.length / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _taskPage.clamp(1, totalPages);
    final startIdx = (currentPage - 1) * _pageSize;
    final endIdx = (startIdx + _pageSize).clamp(0, tasks.length);
    final pageItems = tasks.sublist(startIdx, endIdx);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < pageItems.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildTaskRowItem(pageItems[i]),
          ],
          _buildPaginationFooter(
            totalItems: tasks.length,
            startIdx: startIdx,
            endIdx: endIdx,
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (p) => setState(() => _taskPage = p),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRowItem(TaskEntry t) {
    final (prioLabel, prioFg, prioBg, prioDot) = switch (t.priority) {
      TaskPriority.urgent => ('Urgent', const Color(0xFFDC2626), const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
      TaskPriority.high => ('High', const Color(0xFFEA580C), const Color(0xFFFFEDD5), const Color(0xFFF97316)),
      TaskPriority.medium => ('Medium', const Color(0xFFB45309), const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
      TaskPriority.low => ('Low', const Color(0xFF475569), const Color(0xFFF1F5F9), const Color(0xFF94A3B8)),
    };

    final (stLabel, stFg, stBg) = switch (t.status) {
      'review' => ('Review', const Color(0xFF9333EA), const Color(0xFFF3E8FF)),
      'in_progress' => ('In progress', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
      'done' => ('Completed', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      _ => ('Todo', const Color(0xFF475569), const Color(0xFFF1F5F9)),
    };

    return InkWell(
      onTap: () => context.push('/task/${t.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: prioDot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (t.project.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                t.project,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          _badgePill(prioLabel, fg: prioFg, bg: prioBg),
                          _badgePill(stLabel, fg: stFg, bg: stBg, showDot: true),
                          if (t.milestone.isNotEmpty)
                            Text(
                              'Milestone: ${t.milestone}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          if (t.sprint.isNotEmpty)
                            Text(
                              'Sprint: ${t.sprint}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _detailOutlineBtn(() => context.push('/task/${t.id}')),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  if (t.assignedTo.isNotEmpty) ...[
                    PhAvatar(t.assignedTo, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _store.nameOf(t.assignedTo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ),
                  ] else
                    const Expanded(
                      child: Text(
                        'Belum ada assignee',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  if (t.dueDate.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          fmtDate(t.dueDate),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskKanbanBoard(List<TaskEntry> tasks) {
    const columns = <(String, String, Color)>[
      ('todo', 'Todo', Color(0xFF64748B)),
      ('in_progress', 'In Progress', Color(0xFF2563EB)),
      ('review', 'Review', Color(0xFF9333EA)),
      ('done', 'Completed', Color(0xFF16A34A)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (colKey, colTitle, colColor) in columns)
            Container(
              width: 270,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: colColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(colTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          '${tasks.where((t) => t.status == colKey).length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final t in tasks.where((t) => t.status == colKey))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/task/${t.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                              if (t.project.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(t.project, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (t.assignedTo.isNotEmpty) PhAvatar(t.assignedTo, size: 18),
                                  const Spacer(),
                                  if (t.dueDate.isNotEmpty)
                                    Text(fmtDate(t.dueDate), style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SPRINT
  // ===========================================================================
  Widget _buildSprintTab() {
    final sprints = _filteredSprints;
    final totalPages = (sprints.length / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _sprintPage.clamp(1, totalPages);
    final startIdx = (currentPage - 1) * _pageSize;
    final endIdx = (startIdx + _pageSize).clamp(0, sprints.length);
    final pageItems = sprints.isEmpty ? const <_SprintWithProject>[] : sprints.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdownFilterPill(
          valueLabel: _sprintStatus == 'all' ? 'Semua Status' : _sprintStatus.toUpperCase(),
          active: _sprintStatus != 'all',
          items: const [
            ('all', 'Semua Status'),
            ('planned', 'Planned'),
            ('active', 'Active'),
            ('completed', 'Completed'),
          ],
          onSelected: (v) => setState(() {
            _sprintStatus = v;
            _sprintPage = 1;
          }),
        ),
        const SizedBox(height: 12),
        if (sprints.isEmpty)
          const PhCard(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Center(
              child: Text(
                'Belum ada sprint.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < pageItems.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSprintRowItem(pageItems[i]),
                ],
                _buildPaginationFooter(
                  totalItems: sprints.length,
                  startIdx: startIdx,
                  endIdx: endIdx,
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: (p) => setState(() => _sprintPage = p),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSprintRowItem(_SprintWithProject item) {
    final s = item.sprint;
    final p = item.project;
    final (stLabel, stFg, stBg) = switch (s.status) {
      'active' => ('Active', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
      'completed' => ('Completed', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      _ => ('Planned', const Color(0xFF475569), const Color(0xFFF1F5F9)),
    };

    final sprintTasks = _tasks.where((t) => t.projectId == p.id && t.sprint == s.name).toList();
    final totalPts = sprintTasks.fold<int>(0, (sum, t) => sum + t.storyPoints);
    final donePts = sprintTasks.where((t) => t.done).fold<int>(0, (sum, t) => sum + t.storyPoints);
    final ratio = totalPts > 0 ? (donePts / totalPts).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: () => context.push('/project/${p.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                          if (s.milestone.isNotEmpty) ...[
                            const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
                            Text(
                              s.milestone,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                          _badgePill(stLabel, fg: stFg, bg: stBg),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push('/project/${p.id}'),
                  child: const Text('Detail', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.date_range_outlined, size: 13.5, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${fmtDate(s.startDate)} — ${fmtDate(s.endDate)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
                if (totalPts > 0) ...[
                  SizedBox(
                    width: 68,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$donePts/$totalPts pts',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: RECURRING
  // ===========================================================================
  Widget _buildRecurringTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdownFilterPill(
          valueLabel: _recurringStatus == 'all' ? 'Semua Status' : _recurringStatus.toUpperCase(),
          active: _recurringStatus != 'all',
          items: const [
            ('all', 'Semua Status'),
            ('active', 'Active'),
            ('paused', 'Paused'),
          ],
          onSelected: (v) => setState(() => _recurringStatus = v),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('JUDUL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                    Expanded(flex: 2, child: Text('PROYEK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                    Expanded(flex: 2, child: Text('FREKUENSI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                    Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 42, horizontal: 16),
                child: Center(
                  child: Text(
                    'Belum ada recurring task.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: TICKET
  // ===========================================================================
  Widget _buildTicketTab() {
    final all = _tickets;
    final openCount = all.where((t) => t.status != 'resolved' && t.status != 'closed').length;
    final breachCount = all.where((t) => t.slaBreached).length;
    final filtered = _filteredTickets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb kecil `Projects > Tickets`
        Row(
          children: [
            const Text('Projects', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
            ),
            const Text('Tickets', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openTicketForm(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Create Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 3 Kartu Summary: Total Tickets, Tiket Terbuka, SLA Breach (persis Screenshot 4)
        Row(
          children: [
            Expanded(
              child: _ticketSummaryCard(
                value: '${all.length}',
                label: 'Total Tickets',
                valueColor: const Color(0xFF0F172A),
                borderColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ticketSummaryCard(
                value: '$openCount',
                label: 'Tiket Terbuka',
                valueColor: const Color(0xFFEA580C),
                borderColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ticketSummaryCard(
                value: '$breachCount',
                label: 'SLA Breach',
                valueColor: const Color(0xFFDC2626),
                borderColor: const Color(0xFFFECACA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _dropdownFilterPill(
              valueLabel: _ticketStatus == 'all' ? 'Semua Status' : statusLabel('ticket', _ticketStatus),
              active: _ticketStatus != 'all',
              items: const [
                ('all', 'Semua Status'),
                ('open', 'Open'),
                ('assigned', 'Assigned'),
                ('in_progress', 'In Progress'),
                ('pending_review', 'Pending Review'),
                ('resolved', 'Resolved'),
                ('closed', 'Closed'),
              ],
              onSelected: (v) => setState(() {
                _ticketStatus = v;
                _ticketPage = 1;
              }),
            ),
            _dropdownFilterPill(
              valueLabel: _ticketPriority == 'all' ? 'Semua Prioritas' : _ticketPriority.toUpperCase(),
              active: _ticketPriority != 'all',
              items: const [
                ('all', 'Semua Prioritas'),
                ('critical', 'Critical'),
                ('high', 'High'),
                ('medium', 'Medium'),
                ('low', 'Low'),
              ],
              onSelected: (v) => setState(() {
                _ticketPriority = v;
                _ticketPage = 1;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const PhCard(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Center(
              child: Text(
                'Belum ada tiket yang sesuai filter.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          Builder(
            builder: (context) {
              final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 9999);
              final currentPage = _ticketPage.clamp(1, totalPages);
              final startIdx = (currentPage - 1) * _pageSize;
              final endIdx = (startIdx + _pageSize).clamp(0, filtered.length);
              final pageItems = filtered.sublist(startIdx, endIdx);
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < pageItems.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      _buildTicketRowItem(pageItems[i]),
                    ],
                    _buildPaginationFooter(
                      totalItems: filtered.length,
                      startIdx: startIdx,
                      endIdx: endIdx,
                      currentPage: currentPage,
                      totalPages: totalPages,
                      onPageChanged: (p) => setState(() => _ticketPage = p),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _ticketSummaryCard({
    required String value,
    required String label,
    required Color valueColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: valueColor),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketRowItem(Ticket t) {
    final (prioLabel, prioFg, prioBg) = switch (t.priority) {
      'critical' => ('Critical', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      'high' => ('High', const Color(0xFFEA580C), const Color(0xFFFFEDD5)),
      'medium' => ('Medium', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
      _ => ('Low', const Color(0xFF475569), const Color(0xFFF1F5F9)),
    };

    final (stLabel, stFg, stBg) = switch (t.status) {
      'resolved' => ('Resolved', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      'pending_review' => ('Pending review', const Color(0xFFEA580C), const Color(0xFFFFEDD5)),
      'in_progress' => ('In progress', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
      'assigned' => ('Assigned', const Color(0xFF9333EA), const Color(0xFFF3E8FF)),
      _ => ('Open', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
    };

    final typeCap = t.type.isEmpty ? 'Bug' : '${t.type[0].toUpperCase()}${t.type.substring(1)}';

    return InkWell(
      onTap: () => context.push('/ticket/${t.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            t.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (t.slaBreached)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BREACH',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            t.projectName,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                          if (t.milestone.isNotEmpty) ...[
                            const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
                            Text(t.milestone, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                          ],
                          const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
                          Text(typeCap, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                          _badgePill(prioLabel, fg: prioFg, bg: prioBg),
                          _badgePill(stLabel, fg: stFg, bg: stBg),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push('/ticket/${t.id}'),
                  child: const Text('Detail', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Reporter: ${t.reporterId.isEmpty ? '-' : _store.nameOf(t.reporterId)}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                Text(
                  'Assignee: ${t.assigneeId.isEmpty ? '—' : _store.nameOf(t.assigneeId)}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                if (t.slaDueAt.isNotEmpty)
                  Text(
                    'SLA: ${timeAgo(t.slaDueAt)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                if (t.createdAt.isNotEmpty)
                  Text(
                    fmtDate(t.createdAt),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SHARED HELPERS
  // ===========================================================================
  Widget _dropdownFilterPill({
    required String valueLabel,
    required bool active,
    required List<(String, String)> items,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (val, label) in items)
          PopupMenuItem<String>(
            value: val,
            child: Text(label, style: const TextStyle(fontSize: 12.5)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? const Color(0xFF2563EB) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgePill(String label, {required Color fg, required Color bg, bool showDot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(width: 5.5, height: 5.5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _detailOutlineBtn(VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Detail',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
            ),
            SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  /// Footer pagination seperti di web:
  /// `Showing 1 to 10 of 100 results` | `Show [10 v]` | `< 1 2 3 ... >`
  Widget _buildPaginationFooter({
    required int totalItems,
    required int startIdx,
    required int endIdx,
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    final visiblePages = <int>[];
    for (var p = 1; p <= totalPages; p++) {
      if (totalPages <= 7 || p == 1 || p == totalPages || (p - currentPage).abs() <= 2) {
        visiblePages.add(p);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Show ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              PopupMenuButton<int>(
                onSelected: (size) => setState(() {
                  _pageSize = size;
                  _taskPage = 1;
                  _sprintPage = 1;
                  _ticketPage = 1;
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12))),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_pageSize', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const SizedBox(width: 3),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Showing ${totalItems == 0 ? 0 : startIdx + 1} to $endIdx of $totalItems results',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pageBtn(
                  label: '‹',
                  enabled: currentPage > 1,
                  active: false,
                  onTap: () => onPageChanged(currentPage - 1),
                ),
                for (var i = 0; i < visiblePages.length; i++) ...[
                  if (i > 0 && visiblePages[i] - visiblePages[i - 1] > 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('…', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ),
                  _pageBtn(
                    label: '${visiblePages[i]}',
                    enabled: true,
                    active: visiblePages[i] == currentPage,
                    onTap: () => onPageChanged(visiblePages[i]),
                  ),
                ],
                _pageBtn(
                  label: '›',
                  enabled: currentPage < totalPages,
                  active: false,
                  onTap: () => onPageChanged(currentPage + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageBtn({
    required String label,
    required bool enabled,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE2E8F0) : Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: active ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: !enabled
                  ? const Color(0xFFCBD5E1)
                  : (active ? const Color(0xFF0F172A) : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }
}
