import 'package:flutter/material.dart';
import '../projecthub/ph_api.dart';
import 'app_theme.dart';
import 'auth_repository.dart';

/// Definisi satu shift kerja untuk absensi (mis. Shift Pagi 08:00–17:00).
class WorkShift {
  /// shifts.id di server (sebagai string).
  final String id;
  String name;
  String startTime;
  String endTime;
  Color color;
  // Kolom tabel shifts: break_start_time, break_end_time, tolerance_minutes, is_active.
  String breakStart;
  String breakEnd;
  int toleranceMinutes;
  bool isActive;

  /// Hari kerja (0 = Minggu ... 6 = Sabtu), tabel shift_working_days.
  List<int> workingDays;

  WorkShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.breakStart = '',
    this.breakEnd = '',
    this.toleranceMinutes = 0,
    this.isActive = true,
    this.workingDays = const [1, 2, 3, 4, 5],
  });

  String get range => '$startTime–$endTime';
  String get breakRange => breakStart.isEmpty ? '-' : '$breakStart–$breakEnd';
}

/// Shift kerja perusahaan dan pemetaan karyawan → shift, dibaca/disimpan lewat
/// API `/hris/shifts` dan `/hris/employees`. Dipakai [ShiftSettingsScreen].
class ShiftRepository extends ChangeNotifier {
  ShiftRepository._();
  static final ShiftRepository instance = ShiftRepository._();

  static const _palette = [AppColors.info, AppColors.warning, AppColors.primary700, AppColors.success, AppColors.error, AppColors.accent400];

  final _api = PhApi.instance;
  final List<WorkShift> shifts = [];

  /// Warna hanya untuk tampilan (tidak disimpan server), per id shift.
  final Map<String, Color> _colors = {};

  /// Nama karyawan → (id user, id shift default).
  final Map<String, (String, String)> _employees = {};

  bool loading = false;
  String? error;

  List<String> get employees => _employees.keys.toList(growable: false);

  void clear() {
    shifts.clear();
    _colors.clear();
    _employees.clear();
    loading = false;
    error = null;
    notifyListeners();
  }

  Future<void> load() async {
    await Future<void>.value(); // dipanggil dari initState
    if (!AuthRepository.instance.isLoggedIn) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.get('/hris/shifts'),
        _api.get('/hris/employees').catchError((_) => const <dynamic>[]),
      ]);
      shifts
        ..clear()
        ..addAll([for (final j in (results[0] as List? ?? const [])) _shift(j as Map<String, dynamic>)]);
      _employees
        ..clear()
        ..addAll({
          for (final e in (results[1] as List? ?? const []))
            if (e['is_active'] != false) '${e['name']}': ('${e['id']}', e['shift_id'] == null ? '' : '${e['shift_id']}'),
        });
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  WorkShift? shiftFor(String employeeName) {
    final id = _employees[employeeName]?.$2;
    if (id == null || id.isEmpty) return null;
    return shifts.where((s) => s.id == id).firstOrNull;
  }

  Future<void> assignShift(String employeeName, String shiftId) async {
    final emp = _employees[employeeName];
    if (emp == null) return;
    await _api.put('/hris/employees/${emp.$1}/shift', {'shift_id': int.tryParse(shiftId)});
    _employees[employeeName] = (emp.$1, shiftId);
    notifyListeners();
  }

  Map<String, Object?> _body(String name, String startTime, String endTime, String breakStart, String breakEnd, int toleranceMinutes, List<int> workingDays) => {
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'break_start_time': breakStart.isEmpty ? null : breakStart,
        'break_end_time': breakEnd.isEmpty ? null : breakEnd,
        'tolerance_minutes': toleranceMinutes,
        'working_days': workingDays,
      };

  Future<void> addShift({
    required String name,
    required String startTime,
    required String endTime,
    required Color color,
    String breakStart = '',
    String breakEnd = '',
    int toleranceMinutes = 0,
    List<int> workingDays = const [1, 2, 3, 4, 5],
  }) async {
    final j = await _api.post('/hris/shifts', _body(name, startTime, endTime, breakStart, breakEnd, toleranceMinutes, workingDays)) as Map<String, dynamic>;
    _colors['${j['id']}'] = color;
    shifts.add(_shift(j));
    notifyListeners();
  }

  Future<void> updateShift(
    WorkShift shift, {
    required String name,
    required String startTime,
    required String endTime,
    required Color color,
    String? breakStart,
    String? breakEnd,
    int? toleranceMinutes,
    List<int>? workingDays,
  }) async {
    final j = await _api.put(
      '/hris/shifts/${shift.id}',
      _body(name, startTime, endTime, breakStart ?? shift.breakStart, breakEnd ?? shift.breakEnd, toleranceMinutes ?? shift.toleranceMinutes, workingDays ?? shift.workingDays),
    ) as Map<String, dynamic>;
    _colors[shift.id] = color;
    final fresh = _shift(j);
    shift
      ..name = fresh.name
      ..startTime = fresh.startTime
      ..endTime = fresh.endTime
      ..color = color
      ..breakStart = fresh.breakStart
      ..breakEnd = fresh.breakEnd
      ..toleranceMinutes = fresh.toleranceMinutes
      ..workingDays = fresh.workingDays;
    notifyListeners();
  }

  /// Karyawan yang memakai shift ini otomatis kembali ke "tanpa shift" (server: nullOnDelete).
  Future<void> deleteShift(WorkShift shift) async {
    await _api.delete('/hris/shifts/${shift.id}');
    shifts.remove(shift);
    for (final e in _employees.entries.toList()) {
      if (e.value.$2 == shift.id) _employees[e.key] = (e.value.$1, '');
    }
    notifyListeners();
  }

  WorkShift _shift(Map<String, dynamic> j) {
    final id = '${j['id']}';
    return WorkShift(
      id: id,
      name: '${j['name'] ?? ''}',
      startTime: '${j['start_time'] ?? ''}',
      endTime: '${j['end_time'] ?? ''}',
      color: _colors.putIfAbsent(id, () => _palette[(int.tryParse(id) ?? 0) % _palette.length]),
      breakStart: '${j['break_start_time'] ?? ''}',
      breakEnd: '${j['break_end_time'] ?? ''}',
      toleranceMinutes: j['tolerance_minutes'] as int? ?? 0,
      isActive: j['is_active'] != false,
      workingDays: [for (final d in (j['working_days'] as List? ?? const [])) d as int],
    );
  }
}
