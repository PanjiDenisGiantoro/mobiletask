import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../data/task_repository.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_widgets.dart';

/// Halaman "Laporan" -> "Workspace Analytics": ringkasan lintas-proyek dari
/// data yang sudah tersinkron (task, proyek, tiket, milestone, time log).
/// Dua chart tren waktu (task dibuat per hari/minggu) di referensi web
/// sengaja tidak dibuat di sini karena [TaskEntry] tidak punya timestamp
/// "dibuat pada" — menampilkan tren palsu lebih buruk daripada tidak sama
/// sekali (lih. CLAUDE.md / antislop R-17).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _periodDays = 30;

  @override
  void initState() {
    super.initState();
    TaskRepository.instance.addListener(_onChanged);
    PhStore.instance.addListener(_onChanged);
    if (!PhStore.instance.synced) PhStore.instance.sync();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    TaskRepository.instance.removeListener(_onChanged);
    PhStore.instance.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = TaskRepository.instance.tasks;
    final projects = PhStore.instance.projects;
    final tickets = PhStore.instance.tickets;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.heroStart,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.heroStart, AppColors.heroMid]),
          ),
        ),
        title: const Text('Workspace Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: PhStore.instance.sync,
        child: tasks.isEmpty && projects.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 160),
                children: const [Center(child: Text('Belum ada data untuk dianalisis'))],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _header(),
                  phGap(AppSpacing.md),
                  _kpiGrid(tasks, projects, tickets),
                  phGap(AppSpacing.md),
                  _taskStatusDonut(tasks),
                  phGap(AppSpacing.md),
                  _topDeveloper(projects),
                  phGap(AppSpacing.md),
                  _projectProgress(projects),
                  phGap(AppSpacing.md),
                  _ticketsByPriority(tickets),
                  phGap(AppSpacing.md),
                  _milestoneOverall(projects),
                  phGap(AppSpacing.md),
                  _projectsByStatus(projects),
                ],
              ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.sensors_rounded, size: 11, color: AppColors.primary700),
            const SizedBox(width: 4),
            const Text('Real-time Intelligence & Telemetry', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary700)),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('Workspace Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.grey900)),
        const SizedBox(height: 4),
        Text(
          'Metrik produktivitas tim, penyelesaian tugas, dan status SLA · Periode aktif: $_periodDays hari terakhir',
          style: const TextStyle(fontSize: 12, color: AppColors.grey700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final d in [7, 14, 30, 90]) ...[
              _periodChip(d),
              if (d != 90) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  Widget _periodChip(int days) {
    final active = _periodDays == days;
    return GestureDetector(
      onTap: () => setState(() => _periodDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary700 : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: active ? AppColors.primary700 : AppColors.grey100),
        ),
        child: Text('$days Hari', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.grey700)),
      ),
    );
  }

  Widget _kpiGrid(List<TaskEntry> tasks, List<Project> projects, List<Ticket> tickets) {
    final done = tasks.where((t) => t.done).length;
    final completionRate = tasks.isEmpty ? 0 : (done / tasks.length * 100).round();
    final today = isoDate(DateTime.now());
    final overdue = tasks.where((t) => !t.done && t.dueDate.isNotEmpty && t.dueDate.compareTo(today) < 0).length;
    final activeProjects = projects.where((p) => p.status == 'active').length;
    final completedProjects = projects.where((p) => p.status == 'completed').length;
    final openTickets = tickets.where((t) => t.status != 'closed' && t.status != 'resolved').length;
    final slaBreach = tickets.where((t) => t.slaBreached).length;

    // Row+Expanded+stretch (bukan GridView rasio-tetap) supaya tinggi kartu
    // menyesuaikan kontennya sendiri — tidak overflow walau teks/label panjang.
    final card1 = _kpiCard(
          label: 'TINGKAT SELESAI TASK',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.primary700,
          value: '$completionRate%',
          note: '$done selesai',
          noteColor: AppColors.success,
          footer: 'Total: ${tasks.length} task',
          footerTrailing: '${tasks.length - done} aktif',
          progress: tasks.isEmpty ? 0 : done / tasks.length,
        );
    final card2 = _kpiCard(
          label: 'PORTOFOLIO PROYEK',
          icon: Icons.folder_rounded,
          color: AppColors.primary600,
          value: '$activeProjects',
          note: 'aktif berjalan',
          noteColor: AppColors.primary600,
          footer: '$completedProjects selesai',
          footerTrailing: '${projects.length} total',
        );
    final card3 = _kpiCard(
          label: 'KETERLAMBATAN (OVERDUE)',
          icon: Icons.schedule_rounded,
          color: AppColors.error,
          value: '$overdue',
          note: 'task lewat deadline',
          noteColor: AppColors.error,
          footer: 'Status Tenggat',
          footerTrailing: overdue > 0 ? 'Perlu Eskalasi' : 'Aman',
          footerTrailingColor: overdue > 0 ? AppColors.error : AppColors.success,
        );
    final card4 = _kpiCard(
          label: 'TIKET BUG & SLA',
          icon: Icons.confirmation_number_rounded,
          color: AppColors.warning,
          value: '$openTickets',
          note: 'tiket terbuka',
          noteColor: AppColors.warning,
          footer: slaBreach > 0 ? '$slaBreach SLA Breach' : 'SLA Aman',
          footerColor: slaBreach > 0 ? AppColors.error : AppColors.success,
          footerTrailing: '',
        );

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: card1),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: card2),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: card3),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: card4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String label,
    required IconData icon,
    required Color color,
    required String value,
    required String note,
    required Color noteColor,
    required String footer,
    Color? footerColor,
    required String footerTrailing,
    Color? footerTrailingColor,
    double? progress,
  }) {
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.grey500, letterSpacing: 0.3))),
            Icon(icon, size: 16, color: color),
          ]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(note, style: TextStyle(fontSize: 10.5, color: noteColor, fontWeight: FontWeight.w600)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: AppColors.grey100, valueColor: AlwaysStoppedAnimation(color)),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text(footer, style: TextStyle(fontSize: 10, color: footerColor ?? AppColors.grey400))),
            Text(footerTrailing, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: footerTrailingColor ?? AppColors.grey500)),
          ]),
        ],
      ),
    );
  }

  Widget _taskStatusDonut(List<TaskEntry> tasks) {
    final counts = {
      'todo': tasks.where((t) => t.status == 'todo').length,
      'in_progress': tasks.where((t) => t.status == 'in_progress').length,
      'review': tasks.where((t) => t.status == 'review').length,
      'done': tasks.where((t) => t.status == 'done').length,
    };
    const colors = {
      'todo': Color(0xFF9E9E9E),
      'in_progress': AppColors.info,
      'review': Color(0xFFFBC02D),
      'done': AppColors.success,
    };
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distribusi Status Task', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('Komposisi seluruh task saat ini', style: TextStyle(fontSize: 11, color: AppColors.grey500)),
                ],
              ),
            ),
            Text('${tasks.length} Total', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
          ]),
          phGap(AppSpacing.md),
          if (tasks.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Belum ada task', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))))
          else
            Row(children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 32,
                  sections: [
                    for (final key in counts.keys)
                      if (counts[key]! > 0) PieChartSectionData(value: counts[key]!.toDouble(), color: colors[key], showTitle: false, radius: 24),
                  ],
                )),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final key in counts.keys) ...[
                      _legendRow(colors[key]!, statusLabel('task', key), counts[key]!),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, int value) => Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
        Text('$value', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey900)),
      ]);

  /// Total jam kerja (dari [TimeLog.minutes]) per user, dijumlah lintas
  /// semua proyek, difilter ke [_periodDays] terakhir berdasar [TimeLog.startedAt].
  Widget _topDeveloper(List<Project> projects) {
    final cutoff = DateTime.now().subtract(Duration(days: _periodDays));
    final minutesByUser = <String, int>{};
    for (final p in projects) {
      for (final l in p.timeLogs) {
        final started = DateTime.tryParse(l.startedAt);
        if (started != null && started.isBefore(cutoff)) continue;
        minutesByUser.update(l.userId, (v) => v + l.minutes, ifAbsent: () => l.minutes);
      }
    }
    final sorted = minutesByUser.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final maxMinutes = top.isEmpty || top.first.value == 0 ? 1 : top.first.value;

    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top Developer (Jam Kerja)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('Total waktu tercatat, periode terpilih', style: TextStyle(fontSize: 11, color: AppColors.grey500)),
                ],
              ),
            ),
            const Icon(Icons.timer_outlined, color: AppColors.grey400, size: 18),
          ]),
          phGap(AppSpacing.md),
          if (top.isEmpty)
            const Text('Belum ada data time log tercatat.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (final e in top)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(PhStore.instance.nameOf(e.key), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                      Text('${e.value ~/ 60}j ${e.value % 60}m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(value: e.value / maxMinutes, minHeight: 6, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.primary600)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _projectProgress(List<Project> projects) {
    final active = projects.where((p) => p.status == 'active').toList();
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress Proyek Aktif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const Text('Rasio penyelesaian task tiap proyek aktif', style: TextStyle(fontSize: 11, color: AppColors.grey500)),
          phGap(AppSpacing.md),
          if (active.isEmpty)
            const Text('Tidak ada proyek aktif.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (final p in active)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Builder(builder: (_) {
                  final progress = p.totalTasks > 0 ? p.doneTasks / p.totalTasks : 0.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                        Text('${(progress * 100).round()}% (${p.doneTasks}/${p.totalTasks})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.grey100,
                          valueColor: AlwaysStoppedAnimation(progress >= 1 ? AppColors.success : AppColors.warning),
                        ),
                      ),
                    ],
                  );
                }),
              ),
        ],
      ),
    );
  }

  Widget _ticketsByPriority(List<Ticket> tickets) {
    const order = ['critical', 'high', 'medium', 'low'];
    const labels = {'critical': 'Critical', 'high': 'High', 'medium': 'Medium', 'low': 'Low'};
    const colors = {
      'critical': AppColors.error,
      'high': Color(0xFFFB8C00),
      'medium': Color(0xFFFBC02D),
      'low': AppColors.grey400,
    };
    final counts = {for (final k in order) k: tickets.where((t) => t.priority == k).length};
    final highest = counts.values.fold(0, (a, b) => a > b ? a : b);
    final maxCount = highest == 0 ? 1 : highest;
    final open = tickets.where((t) => t.status != 'closed' && t.status != 'resolved').length;

    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('Tiket per Prioritas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            Text('$open Terbuka', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
          ]),
          phGap(AppSpacing.md),
          if (tickets.isEmpty)
            const Text('Belum ada tiket.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (final k in order)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(children: [
                  SizedBox(width: 58, child: Text(labels[k]!, style: const TextStyle(fontSize: 12, color: AppColors.grey700))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(value: counts[k]! / maxCount, minHeight: 10, backgroundColor: AppColors.grey100, valueColor: AlwaysStoppedAnimation(colors[k])),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 18, child: Text('${counts[k]}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
              ),
        ],
      ),
    );
  }

  Widget _milestoneOverall(List<Project> projects) {
    final all = projects.expand((p) => p.milestones).toList();
    final done = all.where((m) => m.status == 'completed').length;
    final percent = all.isEmpty ? 0 : (done / all.length * 100).round();
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('Milestone Keseluruhan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            Text('$percent%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success)),
          ]),
          phGap(AppSpacing.sm),
          Text('$done / ${all.length} milestone selesai', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          phGap(AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(value: all.isEmpty ? 0 : done / all.length, minHeight: 8, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.success)),
          ),
        ],
      ),
    );
  }

  Widget _projectsByStatus(List<Project> projects) {
    const order = ['active', 'draft', 'on_hold', 'completed', 'cancelled'];
    final counts = {for (final k in order) k: projects.where((p) => p.status == k).length}..removeWhere((_, v) => v == 0);
    final maxCount = counts.values.isEmpty ? 1 : counts.values.reduce((a, b) => a > b ? a : b);

    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('Distribusi Proyek per Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            Text('${projects.length} Proyek', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
          ]),
          const Text('Pipeline fase pengerjaan seluruh proyek', style: TextStyle(fontSize: 11, color: AppColors.grey500)),
          phGap(AppSpacing.md),
          if (counts.isEmpty)
            const Text('Belum ada proyek.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (final e in counts.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(statusLabel('project', e.key), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                      Text('${e.value} (${(e.value / projects.length * 100).round()}%)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(value: e.value / maxCount, minHeight: 8, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.info)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
