import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'task_repository.dart';
import 'widgets/task_tile.dart';

/// Halaman "Laporan" — statistik tugas real-time dari [TaskRepository],
/// divisualisasikan dengan fl_chart (pie chart selesai/belum, bar chart
/// per prioritas).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    TaskRepository.instance.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    TaskRepository.instance.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = TaskRepository.instance.tasks;
    final done = tasks.where((t) => t.done).length;
    final notDone = tasks.length - done;
    final byPriority = {
      for (final p in TaskPriority.values)
        p: tasks.where((t) => t.priority == p).length,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.heroStart,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroStart, AppColors.heroMid],
            ),
          ),
        ),
        title: const Text('Laporan'),
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('Belum ada tugas untuk dilaporkan'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _ReportCard(
                  title: 'Progres Tugas',
                  child: SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 36,
                              sections: [
                                PieChartSectionData(
                                  value: done.toDouble(),
                                  color: AppColors.success,
                                  title: '$done',
                                  radius: 46,
                                  titleStyle: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                PieChartSectionData(
                                  value: notDone.toDouble(),
                                  color: AppColors.grey100,
                                  title: '$notDone',
                                  radius: 46,
                                  titleStyle: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _LegendDot(color: AppColors.success, label: 'Selesai ($done)'),
                              const SizedBox(height: AppSpacing.sm),
                              _LegendDot(color: AppColors.grey100, label: 'Berjalan ($notDone)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ReportCard(
                  title: 'Tugas per Prioritas',
                  child: SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (byPriority.values.isEmpty
                                ? 1
                                : byPriority.values.reduce((a, b) => a > b ? a : b))
                            .toDouble() +
                            1,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final labels = {0: 'High', 1: 'Medium', 2: 'Low'};
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    labels[value.toInt()] ?? '',
                                    style: const TextStyle(fontSize: 11, color: AppColors.grey700),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          _barGroup(0, byPriority[TaskPriority.high]!, AppColors.error),
                          _barGroup(1, byPriority[TaskPriority.medium]!, AppColors.warning),
                          _barGroup(2, byPriority[TaskPriority.low]!, AppColors.success),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  BarChartGroupData _barGroup(int x, int count, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: count.toDouble(), color: color, width: 28, borderRadius: BorderRadius.circular(6)),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ReportCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.grey900)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.grey700)),
      ],
    );
  }
}
