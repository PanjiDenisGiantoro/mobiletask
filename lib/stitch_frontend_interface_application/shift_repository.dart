import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Definisi satu shift kerja untuk absensi (mis. Shift Pagi 08:00–17:00).
class WorkShift {
  final String id;
  String name;
  String startTime;
  String endTime;
  Color color;

  WorkShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.color,
  });

  String get range => '$startTime–$endTime';
}

/// Sumber data shift absensi bersama: daftar shift yang bisa diatur admin
/// di [ShiftSettingsScreen], dan pemetaan karyawan → shift supaya
/// [AttendanceScreen] bisa menampilkan shift masing-masing user.
class ShiftRepository extends ChangeNotifier {
  ShiftRepository._() {
    _employeeShiftId = {
      for (final name in _initialEmployees) name: shifts.first.id,
    };
    _employeeShiftId['Reza Pratama'] = shifts[1].id;
    _employeeShiftId['Hendra Wijaya'] = shifts[2].id;
  }

  static final ShiftRepository instance = ShiftRepository._();

  static const _initialEmployees = [
    'Budi Santoso',
    'Siti Rahma',
    'Reza Pratama',
    'Dika Ramadhan',
    'Hendra Wijaya',
  ];

  final List<WorkShift> shifts = [
    WorkShift(id: 'pagi', name: 'Shift Pagi', startTime: '08:00', endTime: '17:00', color: AppColors.info),
    WorkShift(id: 'siang', name: 'Shift Siang', startTime: '13:00', endTime: '21:00', color: AppColors.warning),
    WorkShift(id: 'malam', name: 'Shift Malam', startTime: '21:00', endTime: '05:00', color: AppColors.primary700),
  ];

  late final Map<String, String> _employeeShiftId;

  List<String> get employees => _employeeShiftId.keys.toList(growable: false);

  WorkShift? shiftFor(String employeeName) {
    final id = _employeeShiftId[employeeName];
    if (id == null) return null;
    try {
      return shifts.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  void assignShift(String employeeName, String shiftId) {
    _employeeShiftId[employeeName] = shiftId;
    notifyListeners();
  }

  void addShift({required String name, required String startTime, required String endTime, required Color color}) {
    shifts.add(WorkShift(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      startTime: startTime,
      endTime: endTime,
      color: color,
    ));
    notifyListeners();
  }

  void updateShift(WorkShift shift, {required String name, required String startTime, required String endTime, required Color color}) {
    shift.name = name;
    shift.startTime = startTime;
    shift.endTime = endTime;
    shift.color = color;
    notifyListeners();
  }

  void deleteShift(WorkShift shift) {
    if (shifts.length <= 1) return;
    shifts.remove(shift);
    final fallbackId = shifts.first.id;
    for (final name in _employeeShiftId.keys) {
      if (_employeeShiftId[name] == shift.id) {
        _employeeShiftId[name] = fallbackId;
      }
    }
    notifyListeners();
  }
}
