import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'app_theme.dart';

/// Halaman "Kalender" — jadwal & pengingat tim, dirender dengan
/// table_calendar. Data event di sini masih contoh statis relatif terhadap
/// hari ini (belum tersambung ke tanggal jatuh tempo tugas asli).
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
  late final Map<DateTime, List<String>> _events;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(DateTime.now());
    _focusedDay = _today;
    _selectedDay = _today;
    _events = {
      _today: const ['Standup harian', 'Review desain onboarding'],
      _dateOnly(_today.add(const Duration(days: 1))): const ['Deadline Sprint 12'],
      _dateOnly(_today.add(const Duration(days: 3))): const ['Rapat mingguan tim'],
      _dateOnly(_today.add(const Duration(days: 7))): const ['Demo ke stakeholder'],
    };
  }

  List<String> _eventsFor(DateTime day) => _events[_dateOnly(day)] ?? const [];

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
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TableCalendar<String>(
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
              onPageChanged: (focused) => _focusedDay = focused,
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
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: selectedEvents.isEmpty
                ? const Center(
                    child: Text('Tidak ada agenda di tanggal ini', style: TextStyle(color: AppColors.grey400)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: selectedEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => Container(
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
                          const Icon(Icons.event_rounded, color: AppColors.heroStart, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              selectedEvents[i],
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.grey900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
