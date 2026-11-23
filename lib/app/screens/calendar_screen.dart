import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/ph_api.dart';
import '../data/ph_store.dart';
import '../data/task_repository.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

/// Satu agenda dari `/calendar/events` (task, milestone, sprint, tiket, atau custom event).
class _CalEvent {
  final String id;
  final String title;
  final String type;
  final String project;
  final String status;
  final String colorHex;
  final Color color;
  final DateTime date;
  final List<String> tags;
  final String category;

  const _CalEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.project,
    required this.status,
    required this.colorHex,
    required this.color,
    required this.date,
    this.tags = const [],
    this.category = '',
  });
}

enum _CalViewMode { month, week, day, list }

/// Halaman "Kalender" — menyesuaikan desain web ProjectHub Pro (Month / Week / Day / List,
/// Search events, filter Colors / Tags / Categories, Google Calendar Connected badge,
/// tombol + New Event, serta sel kalender dengan badge jumlah event & pill event berwarna).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final DateTime _today;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  _CalViewMode _viewMode = _CalViewMode.month;

  final Map<DateTime, List<_CalEvent>> _events = {};
  final Set<String> _loadedMonths = {};
  bool _loading = false;
  String? _error;

  String _searchQuery = '';
  String _selectedColorKey = 'all';
  String _selectedTag = 'all';
  String _selectedCategory = 'all';

  static const _weekdaysSunFirst = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _typeLabels = {
    'task': 'Task',
    'milestone': 'Milestone',
    'sprint': 'Sprint',
    'ticket': 'Tiket',
    'event': 'Event',
  };

  static const _colorPresets = <(String, String, Color)>[
    ('all', 'All Colors', Color(0xFF64748B)),
    ('blue', 'Blue (Task)', Color(0xFF2563EB)),
    ('amber', 'Orange (Milestone / Warning)', Color(0xFFF59E0B)),
    ('pink', 'Pink (Sprint)', Color(0xFFF43F5E)),
    ('green', 'Green (Completed / Event)', Color(0xFF10B981)),
    ('purple', 'Purple (Review)', Color(0xFF8B5CF6)),
  ];

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(DateTime.now());
    _focusedDay = _today;
    _selectedDay = _today;
    _loadMonth(_today);
  }

  Color _defaultColorForType(String type, String status) {
    if (status == 'done' || status == 'completed' || status == 'resolved') {
      return const Color(0xFF10B981);
    }
    switch (type) {
      case 'milestone':
        return const Color(0xFFF59E0B);
      case 'sprint':
        return const Color(0xFFF43F5E);
      case 'ticket':
        return const Color(0xFFF59E0B);
      case 'task':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _colorKeyOf(Color c, String type, String status) {
    final v = c.toARGB32() & 0xFFFFFF;
    if (v == 0x10B981 || v == 0x059669 || v == 0x16A34A || status == 'done' || status == 'completed') {
      return 'green';
    }
    if (v == 0xF59E0B || v == 0xD97706 || v == 0xEA580C || type == 'milestone' || type == 'ticket') {
      return 'amber';
    }
    if (v == 0xF43F5E || v == 0xE11D48 || v == 0xEC4899 || type == 'sprint') {
      return 'pink';
    }
    if (v == 0x8B5CF6 || v == 0x7C3AED || v == 0x9333EA) {
      return 'purple';
    }
    return 'blue';
  }

  Future<void> _loadMonth(DateTime month, {bool force = false}) async {
    final key = '${month.year}-${month.month}';
    if (!force && _loadedMonths.contains(key)) return;
    _loadedMonths.add(key);
    setState(() => _loading = true);
    try {
      final start = isoDate(DateTime(month.year, month.month, 1));
      final end = isoDate(DateTime(month.year, month.month + 1, 0));
      final res = await PhApi.instance.get('/calendar/events?start=$start&end=$end');
      final list = res is List
          ? res
          : (res is Map ? (res['events'] ?? res['data'] ?? const []) as List : const []);

      _events.removeWhere((d, _) => d.year == month.year && d.month == month.month);
      for (final raw in list) {
        if (raw is! Map) continue;
        final day = DateTime.tryParse('${raw['start'] ?? raw['date'] ?? ''}');
        if (day == null) continue;
        final props = raw['extendedProps'] as Map? ?? const {};
        final type = '${props['type'] ?? raw['type'] ?? 'task'}'.toLowerCase();
        final status = '${props['status'] ?? raw['status'] ?? ''}'.toLowerCase();
        final project = '${props['project'] ?? raw['project'] ?? ''}';
        final category = '${props['category'] ?? raw['category'] ?? type}';
        final rawColor = '${raw['color'] ?? raw['backgroundColor'] ?? ''}'.replaceFirst('#', '').trim();
        final hex = int.tryParse(rawColor, radix: 16);
        final color = hex == null ? _defaultColorForType(type, status) : Color(0xFF000000 | hex);
        final colorKey = _colorKeyOf(color, type, status);

        final rawTags = props['tags'] ?? raw['tags'];
        final tags = <String>[
          if (rawTags is List) ...rawTags.map((t) => '$t'.trim()).where((t) => t.isNotEmpty),
          if (type.isNotEmpty) _typeLabels[type] ?? type,
          if (status.isNotEmpty) status,
        ];

        final dOnly = _dateOnly(day);
        _events.putIfAbsent(dOnly, () => []).add(
              _CalEvent(
                id: '${raw['id'] ?? '${type}_${day.millisecondsSinceEpoch}'}',
                title: '${raw['title'] ?? '-'}',
                type: type,
                project: project,
                status: status,
                colorHex: colorKey,
                color: color,
                date: dOnly,
                tags: tags,
                category: category,
              ),
            );
      }
      _mergeStoreFallbackForMonth(month);
      _error = null;
    } on ApiException catch (e) {
      _loadedMonths.remove(key);
      _mergeStoreFallbackForMonth(month);
      _error = e.message;
    } catch (_) {
      _mergeStoreFallbackForMonth(month);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Jika ada task/milestone/sprint/tiket di store lokal untuk bulan ini yang belum masuk,
  /// gabungkan supaya tampilan kalender selalu lengkap.
  void _mergeStoreFallbackForMonth(DateTime month) {
    final store = PhStore.instance;
    final existingIds = <String>{
      for (final list in _events.values)
        for (final e in list) e.id,
    };

    void addIfInMonth({
      required String id,
      required String title,
      required String type,
      required String project,
      required String status,
      required String? dateIso,
    }) {
      if (dateIso == null || dateIso.isEmpty || existingIds.contains(id)) return;
      final parsed = DateTime.tryParse(dateIso);
      if (parsed == null || parsed.year != month.year || parsed.month != month.month) return;
      final dOnly = _dateOnly(parsed);
      final color = _defaultColorForType(type, status);
      _events.putIfAbsent(dOnly, () => []).add(
            _CalEvent(
              id: id,
              title: title,
              type: type,
              project: project,
              status: status,
              colorHex: _colorKeyOf(color, type, status),
              color: color,
              date: dOnly,
              tags: [_typeLabels[type] ?? type, if (status.isNotEmpty) status],
              category: type,
            ),
          );
      existingIds.add(id);
    }

    for (final t in TaskRepository.instance.tasks) {
      addIfInMonth(
        id: 'task-${t.id}',
        title: t.title,
        type: 'task',
        project: t.project,
        status: t.status,
        dateIso: t.dueDate,
      );
    }
    for (final p in store.projects) {
      for (final m in p.milestones) {
        addIfInMonth(
          id: 'milestone-${m.id}',
          title: m.title,
          type: 'milestone',
          project: p.name,
          status: m.status,
          dateIso: m.dueDate,
        );
      }
      for (final s in p.sprints) {
        addIfInMonth(
          id: 'sprint-${s.id}',
          title: s.name,
          type: 'sprint',
          project: p.name,
          status: s.status,
          dateIso: s.endDate,
        );
      }
    }
    for (final tk in store.tickets) {
      addIfInMonth(
        id: 'ticket-${tk.id}',
        title: tk.title,
        type: 'ticket',
        project: tk.projectName,
        status: tk.status,
        dateIso: tk.slaDueAt.isNotEmpty ? tk.slaDueAt : tk.createdAt,
      );
    }
  }

  bool _matchesFilter(_CalEvent e) {
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      final hit = e.title.toLowerCase().contains(q) ||
          e.project.toLowerCase().contains(q) ||
          e.type.toLowerCase().contains(q);
      if (!hit) return false;
    }
    if (_selectedColorKey != 'all' && e.colorHex != _selectedColorKey) {
      return false;
    }
    if (_selectedTag != 'all' && !e.tags.any((t) => t.toLowerCase() == _selectedTag.toLowerCase())) {
      return false;
    }
    if (_selectedCategory != 'all') {
      final catMatch = e.type.toLowerCase() == _selectedCategory.toLowerCase() ||
          e.category.toLowerCase() == _selectedCategory.toLowerCase() ||
          e.project.toLowerCase() == _selectedCategory.toLowerCase();
      if (!catMatch) return false;
    }
    return true;
  }

  List<_CalEvent> _eventsFor(DateTime day) {
    final list = _events[_dateOnly(day)] ?? const [];
    return list.where(_matchesFilter).toList();
  }

  List<_CalEvent> _allFilteredEventsInFocusedMonth() {
    final result = <_CalEvent>[];
    final entries = _events.entries
        .where((e) => e.key.year == _focusedDay.year && e.key.month == _focusedDay.month)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      result.addAll(entry.value.where(_matchesFilter));
    }
    return result;
  }

  Set<String> _availableTags() {
    final s = <String>{'Task', 'Milestone', 'Sprint', 'Tiket'};
    for (final list in _events.values) {
      for (final e in list) {
        s.addAll(e.tags.where((t) => t.isNotEmpty));
      }
    }
    return s;
  }

  Set<String> _availableCategories() {
    final s = <String>{'task', 'milestone', 'sprint', 'ticket'};
    for (final list in _events.values) {
      for (final e in list) {
        if (e.project.isNotEmpty) s.add(e.project);
      }
    }
    return s;
  }

  void _stepPeriod(int delta) {
    setState(() {
      if (_viewMode == _CalViewMode.month || _viewMode == _CalViewMode.list) {
        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
        _selectedDay = _focusedDay;
      } else if (_viewMode == _CalViewMode.week) {
        _focusedDay = _focusedDay.add(Duration(days: 7 * delta));
        _selectedDay = _focusedDay;
      } else {
        _focusedDay = _focusedDay.add(Duration(days: delta));
        _selectedDay = _focusedDay;
      }
    });
    _loadMonth(_focusedDay);
  }

  void _goToday() {
    setState(() {
      _focusedDay = _today;
      _selectedDay = _today;
    });
    _loadMonth(_today);
  }

  void _open(_CalEvent e) {
    final dashIdx = e.id.indexOf('-');
    final id = dashIdx >= 0 ? e.id.substring(dashIdx + 1) : e.id;
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

  Future<void> _openNewEventSheet() async {
    final defaultDate = isoDate(_selectedDay);
    await openPhForm(
      context,
      PhFormConfig(
        title: 'New Event',
        saveLabel: 'Simpan Event',
        fields: [
          const PhField('title', 'Judul Event / Agenda', required: true, hint: 'Contoh: Diskusi Urgent terkait Payment Gateway'),
          const PhField(
            'type',
            'Kategori',
            type: PhFieldType.select,
            initial: 'event',
            options: [
              ('event', 'Event / Meeting'),
              ('task', 'Task Deadline'),
              ('milestone', 'Milestone'),
              ('sprint', 'Sprint'),
            ],
          ),
          PhField(
            'project',
            'Proyek (Opsional)',
            type: PhFieldType.select,
            required: false,
            initial: PhStore.instance.projects.firstOrNull?.name ?? '',
            options: [
              const ('', '— Umum / Tanpa Proyek —'),
              for (final p in PhStore.instance.projects) (p.name, p.name),
            ],
          ),
          PhField('date', 'Tanggal', type: PhFieldType.date, initial: defaultDate),
          const PhField(
            'color',
            'Warna Label',
            type: PhFieldType.select,
            initial: 'blue',
            options: [
              ('blue', 'Biru (Default / Task)'),
              ('amber', 'Oranye (Urgent / Milestone)'),
              ('pink', 'Pink (Sprint)'),
              ('green', 'Hijau (Completed / Routine)'),
              ('purple', 'Ungu (Review)'),
            ],
          ),
        ],
        onSave: (res) {
          final date = _dateOnly(DateTime.tryParse('${res['date']}') ?? _selectedDay);
          final colorKey = '${res['color'] ?? 'blue'}';
          final color = _colorPresets.firstWhere((c) => c.$1 == colorKey, orElse: () => _colorPresets[1]).$3;
          final type = '${res['type'] ?? 'event'}';
          if (mounted) {
            setState(() {
              _events.putIfAbsent(date, () => []).add(
                    _CalEvent(
                      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                      title: '${res['title'] ?? 'Agenda Baru'}',
                      type: type,
                      project: '${res['project'] ?? ''}',
                      status: 'scheduled',
                      colorHex: colorKey,
                      color: color,
                      date: date,
                      tags: [_typeLabels[type] ?? 'Event'],
                      category: type,
                    ),
                  );
              _selectedDay = date;
              _focusedDay = date;
            });
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadMonth(_focusedDay, force: true),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          return RefreshIndicator(
            onRefresh: () => _loadMonth(_focusedDay, force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isWide ? 20 : 12),
              children: [
                _buildTopControls(isWide),
                const SizedBox(height: 12),
                _buildSearchAndFilters(isWide),
                if (_loading) ...[
                  const SizedBox(height: 10),
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                ],
                const SizedBox(height: 12),
                if (_viewMode == _CalViewMode.month) ...[
                  _buildMonthGridCard(isWide),
                  const SizedBox(height: 14),
                  _buildSelectedDaySection(),
                ] else if (_viewMode == _CalViewMode.week) ...[
                  _buildWeekViewCard(isWide),
                  const SizedBox(height: 14),
                  _buildSelectedDaySection(),
                ] else if (_viewMode == _CalViewMode.day) ...[
                  _buildSelectedDaySection(fullView: true),
                ] else ...[
                  _buildListViewCard(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Header seperti tampilan Web:
  /// `November 2026` `<` `Today` `>` | Segmented `Month | Week | Day | List` | `Google Calendar Connected` | `+ New Event`
  Widget _buildTopControls(bool isWide) {
    final monthTitle = '${_monthsEn[_focusedDay.month - 1]} ${_focusedDay.year}';

    final titleAndNav = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          monthTitle,
          style: TextStyle(
            fontSize: isWide ? 24 : 19,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 10),
        _circleNavButton(Icons.chevron_left_rounded, () => _stepPeriod(-1)),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _goToday,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Today',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _circleNavButton(Icons.chevron_right_rounded, () => _stepPeriod(1)),
      ],
    );

    final viewSwitcher = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewTabButton(_CalViewMode.month, Icons.calendar_today_outlined, 'Month'),
          _viewTabButton(_CalViewMode.week, Icons.view_week_outlined, 'Week'),
          _viewTabButton(_CalViewMode.day, Icons.access_time_rounded, 'Day'),
          _viewTabButton(_CalViewMode.list, Icons.format_list_bulleted_rounded, 'List'),
        ],
      ),
    );

    final gcalBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text(
            'Google Calendar',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Connected',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
            ),
          ),
        ],
      ),
    );

    final newEventBtn = FilledButton.icon(
      onPressed: _openNewEventSheet,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: const Icon(Icons.add_rounded, size: 17),
      label: const Text('New Event', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    );

    if (isWide) {
      return Row(
        children: [
          titleAndNav,
          const Spacer(),
          viewSwitcher,
          const SizedBox(width: 10),
          gcalBadge,
          const SizedBox(width: 10),
          newEventBtn,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: titleAndNav)),
            const SizedBox(width: 8),
            newEventBtn,
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              viewSwitcher,
              const SizedBox(width: 8),
              gcalBadge,
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleNavButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF334155)),
      ),
    );
  }

  Widget _viewTabButton(_CalViewMode mode, IconData icon, String label) {
    final active = _viewMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search bar `Search events...` + 3 filter pill (`Colors`, `Tags`, `Categories`).
  Widget _buildSearchAndFilters(bool isWide) {
    final hasActiveFilter = _selectedColorKey != 'all' ||
        _selectedTag != 'all' ||
        _selectedCategory != 'all' ||
        _searchQuery.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'Search events...',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _searchQuery = ''),
                  child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildColorsFilterPill(),
              const SizedBox(width: 8),
              _buildTagsFilterPill(),
              const SizedBox(width: 8),
              _buildCategoriesFilterPill(),
              if (hasActiveFilter) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _selectedColorKey = 'all';
                    _selectedTag = 'all';
                    _selectedCategory = 'all';
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorsFilterPill() {
    final current = _colorPresets.firstWhere((c) => c.$1 == _selectedColorKey, orElse: () => _colorPresets.first);
    final active = _selectedColorKey != 'all';
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _selectedColorKey = v),
      itemBuilder: (_) => [
        for (final (key, label, color) in _colorPresets)
          PopupMenuItem<String>(
            value: key,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
      ],
      child: _filterChipBox(
        icon: Icons.filter_alt_outlined,
        label: active ? current.$2.split(' ').first : 'Colors',
        active: active,
        dotColor: active ? current.$3 : null,
      ),
    );
  }

  Widget _buildTagsFilterPill() {
    final tags = _availableTags().toList()..sort();
    final active = _selectedTag != 'all';
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _selectedTag = v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('All Tags', style: TextStyle(fontSize: 12.5))),
        for (final t in tags)
          PopupMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5))),
      ],
      child: _filterChipBox(
        icon: Icons.sell_outlined,
        label: active ? 'Tag: $_selectedTag' : 'Tags',
        active: active,
      ),
    );
  }

  Widget _buildCategoriesFilterPill() {
    final cats = _availableCategories().toList()..sort();
    final active = _selectedCategory != 'all';
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _selectedCategory = v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('All Categories', style: TextStyle(fontSize: 12.5))),
        for (final c in cats)
          PopupMenuItem(
            value: c,
            child: Text(_typeLabels[c] ?? c, style: const TextStyle(fontSize: 12.5)),
          ),
      ],
      child: _filterChipBox(
        icon: Icons.folder_outlined,
        label: active ? (_typeLabels[_selectedCategory] ?? _selectedCategory) : 'Categories',
        active: active,
      ),
    );
  }

  Widget _filterChipBox({
    required IconData icon,
    required String label,
    required bool active,
    Color? dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ] else ...[
            Icon(icon, size: 13.5, color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? const Color(0xFF2563EB) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  /// Grid kalender bulanan (Sun..Sat) persis seperti screenshot web, namun
  /// dioptimalkan agar di layar mobile maupun web tetap proporsional & bisa diklik.
  Widget _buildMonthGridCard(bool isWide) {
    final firstOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final startOffset = firstOfMonth.weekday % 7; // Sunday = 0, Monday = 1, ...
    final gridStart = firstOfMonth.subtract(Duration(days: startOffset));
    final lastOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final totalDaysNeeded = startOffset + lastOfMonth.day;
    final rowCount = (totalDaysNeeded / 7).ceil();
    final cellCount = rowCount * 7;

    final days = List<DateTime>.generate(cellCount, (i) => _dateOnly(gridStart.add(Duration(days: i))));
    final cellHeight = isWide ? 114.0 : 88.0;
    final maxPills = isWide ? 3 : 2;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Hari: Sun Mon Tue Wed Thu Fri Sat
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                for (final wd in _weekdaysSunFirst)
                  Expanded(
                    child: Center(
                      child: Text(
                        wd,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Baris-baris tanggal
          for (var r = 0; r < rowCount; r++)
            Container(
              height: cellHeight,
              decoration: BoxDecoration(
                border: r < rowCount - 1
                    ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: _buildDayCell(
                        day: days[r * 7 + c],
                        inMonth: days[r * 7 + c].month == _focusedDay.month,
                        isWide: isWide,
                        maxPills: maxPills,
                        hasRightBorder: c < 6,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayCell({
    required DateTime day,
    required bool inMonth,
    required bool isWide,
    required int maxPills,
    required bool hasRightBorder,
  }) {
    final isToday = day == _today;
    final isSelected = day == _selectedDay;
    final dayEvents = _eventsFor(day);
    final overflowCount = dayEvents.length - maxPills;

    return InkWell(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 8 : 4, vertical: isWide ? 7 : 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEFF6FF).withValues(alpha: 0.65)
              : (inMonth ? Colors.white : const Color(0xFFFAFAFC)),
          border: Border(
            right: hasRightBorder ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isToday ? 24 : null,
                  height: isToday ? 24 : null,
                  alignment: isToday ? Alignment.center : null,
                  decoration: isToday
                      ? const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)
                      : null,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: isWide ? 12.5 : 11.5,
                      fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w700,
                      color: isToday
                          ? Colors.white
                          : (inMonth ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const Spacer(),
                if (dayEvents.isNotEmpty)
                  Text(
                    isWide ? '${dayEvents.length} event' : '${dayEvents.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final ev in dayEvents.take(maxPills))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = day);
                    _open(ev);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 7 : 4, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: ev.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ev.type == 'sprint' ? '🏃 ${ev.title}' : ev.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isWide ? 10.5 : 9.2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
            if (overflowCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  '+$overflowCount lainnya',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Tampilan mode `Week` (7 hari dalam minggu terpilih).
  Widget _buildWeekViewCard(bool isWide) {
    final startOffset = _selectedDay.weekday % 7;
    final weekStart = _dateOnly(_selectedDay.subtract(Duration(days: startOffset)));
    final weekDays = List<DateTime>.generate(7, (i) => _dateOnly(weekStart.add(Duration(days: i))));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedDay = weekDays[i]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: weekDays[i] == _selectedDay
                        ? const Color(0xFF2563EB)
                        : (weekDays[i] == _today ? const Color(0xFFEFF6FF) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _weekdaysSunFirst[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: weekDays[i] == _selectedDay ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${weekDays[i].day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: weekDays[i] == _selectedDay ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _eventsFor(weekDays[i]).isEmpty
                              ? Colors.transparent
                              : (weekDays[i] == _selectedDay ? Colors.white24 : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _eventsFor(weekDays[i]).isEmpty ? '' : '${_eventsFor(weekDays[i]).length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: weekDays[i] == _selectedDay ? Colors.white : const Color(0xFF334155),
                          ),
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

  /// Panel detail agenda pada tanggal yang sedang dipilih (memudahkan pengguna mobile
  /// melihat judul lengkap dan membuka detail task/tiket/proyek).
  Widget _buildSelectedDaySection({bool fullView = false}) {
    final selectedEvents = _eventsFor(_selectedDay);
    return PhCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_note_rounded, size: 19, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      longDay(_selectedDay),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      selectedEvents.isEmpty
                          ? 'Tidak ada agenda pada tanggal ini'
                          : '${selectedEvents.length} agenda terjadwal',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (fullView) ...[
                IconButton(
                  tooltip: 'Hari sebelumnya',
                  onPressed: () => _stepPeriod(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Hari berikutnya',
                  onPressed: () => _stepPeriod(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ],
          ),
          if (_error != null && selectedEvents.isEmpty) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
          ],
          if (selectedEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final ev in selectedEvents) ...[
              _buildEventDetailRow(ev),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  /// Tampilan mode `List` (seluruh event bulan aktif yang lolos filter).
  Widget _buildListViewCard() {
    final all = _allFilteredEventsInFocusedMonth();
    return PhCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Daftar Agenda Bulan Ini',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              PhPill('${all.length} event', fg: const Color(0xFF2563EB), bg: const Color(0xFFEFF6FF)),
            ],
          ),
          const SizedBox(height: 12),
          if (all.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Tidak ada agenda yang sesuai filter pada bulan ini.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            for (final ev in all) ...[
              _buildEventDetailRow(ev, showDateBadge: true),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _buildEventDetailRow(_CalEvent ev, {bool showDateBadge = false}) {
    final typeLabel = _typeLabels[ev.type] ?? ev.type.toUpperCase();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(ev),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 36,
              decoration: BoxDecoration(
                color: ev.color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: ev.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ev.color),
                        ),
                      ),
                      if (showDateBadge) ...[
                        const SizedBox(width: 6),
                        Text(
                          fmtDate(isoDate(ev.date)),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ev.title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  if (ev.project.isNotEmpty || ev.status.isNotEmpty)
                    Text(
                      [ev.project, if (ev.status.isNotEmpty) ev.status].where((x) => x.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
