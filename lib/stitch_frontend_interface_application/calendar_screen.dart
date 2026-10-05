import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../projecthub/ph_api.dart';
import '../projecthub/ph_format.dart';
import '../projecthub/ph_store.dart';
import 'app_theme.dart';

/// Satu agenda dari `/calendar/events` (task, milestone, sprint, tiket).
class _CalEvent {
  final String id;
  final String title;
  final String type;
  final String project;
  final String status;
  final Color color;
  const _CalEvent(this.id, this.title, this.type, this.project, this.status, this.color);
}

/// Halaman "Kalender" — tenggat task, milestone, sprint, dan SLA tiket dari
/// endpoint kalender web (CalendarWebController), per bulan yang ditampilkan.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final DateTime _today;
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _format = CalendarFormat.month;
  final Map<DateTime, List<_CalEvent>> _events = {};
  final Set<String> _loadedMonths = {};
  bool _loading = false;
  String? _error;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(DateTime.now());
    _focusedDay = _today;
    _selectedDay = _today;
    _loadMonth(_today);
  }

  Future<void> _loadMonth(DateTime month, {bool force = false}) async {
    final key = '${month.year}-${month.month}';
    if (!force && _loadedMonths.contains(key)) return;
    _loadedMonths.add(key);
    setState(() => _loading = true);
    try {
      final start = isoDate(DateTime(month.year, month.month, 1));
      final end = isoDate(DateTime(month.year, month.month + 1, 0));
      final list = await PhApi.instance.get('/calendar/events?start=$start&end=$end') as List;
      _events.removeWhere((d, _) => d.year == month.year && d.month == month.month);
      for (final e in list) {
        final day = DateTime.tryParse('${e['start']}');
        if (day == null) continue;
        final props = e['extendedProps'] as Map? ?? const {};
        final hex = int.tryParse('${e['color'] ?? ''}'.replaceFirst('#', ''), radix: 16);
        _events.putIfAbsent(_dateOnly(day), () => []).add(_CalEvent(
              '${e['id']}',
              '${e['title']}',
              '${props['type'] ?? ''}',
              '${props['project'] ?? ''}',
              '${props['status'] ?? ''}',
              hex == null ? AppColors.heroStart : Color(0xFF000000 | hex),
            ));
      }
      _error = null;
    } on ApiException catch (e) {
      _loadedMonths.remove(key);
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_CalEvent> _eventsFor(DateTime day) => _events[_dateOnly(day)] ?? const [];

  static const _typeLabels = {'task': 'Task', 'milestone': 'Milestone', 'sprint': 'Sprint', 'ticket': 'Tiket'};

  void _open(_CalEvent e) {
    final id = e.id.substring(e.id.indexOf('-') + 1);
    switch (e.type) {
      case 'task':
        context.push('/task/$id');
      case 'ticket':
        context.push('/ticket/$id');
      default:
        final p = PhStore.instance.projectByName(e.project);
        if (p != null) context.push('/project/${p.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _eventsFor(_selectedDay ?? _today);
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
        title: const Text('Kalender'),
        actions: [
          IconButton(tooltip: 'Muat ulang', icon: const Icon(Icons.refresh), onPressed: () => _loadMonth(_focusedDay, force: true)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TableCalendar<_CalEvent>(
              firstDay: DateTime(_today.year - 1),
              lastDay: DateTime(_today.year + 1),
              focusedDay: _focusedDay,
              calendarFormat: _format,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _eventsFor,
              onFormatChanged: (format) => setState(() => _format = format),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                _focusedDay = focused;
                _loadMonth(focused);
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
              ),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: AppColors.grey100, shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
                selectedDecoration: BoxDecoration(color: AppColors.heroStart, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: selectedEvents.isEmpty
                ? Center(
                    child: Text(_error ?? 'Tidak ada agenda di tanggal ini', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey400)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: selectedEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => InkWell(
                      onTap: () => _open(selectedEvents[i]),
                      child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_rounded, color: selectedEvents[i].color, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedEvents[i].title,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.grey900),
                                ),
                                Text(
                                  [_typeLabels[selectedEvents[i].type] ?? selectedEvents[i].type, selectedEvents[i].project, selectedEvents[i].status].where((x) => x.isNotEmpty).join(' · '),
                                  style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.grey400),
                        ],
                      ),
                    ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
