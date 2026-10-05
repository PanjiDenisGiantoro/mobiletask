import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../stitch_frontend_interface_application/auth_repository.dart';
import 'ph_api.dart';

class AttendanceRecord {
  final int id;
  final String date;
  final String status; // hadir | alpha | izin | sakit | cuti | libur
  final String checkIn;
  final String checkOut;
  final String checkIn2;
  final String checkOut2;
  final int? distanceIn;
  final String notes;

  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    this.checkIn = '',
    this.checkOut = '',
    this.checkIn2 = '',
    this.checkOut2 = '',
    this.distanceIn,
    this.notes = '',
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: j['id'] as int? ?? 0,
        date: '${j['date'] ?? ''}',
        status: '${j['status'] ?? 'hadir'}',
        checkIn: '${j['check_in'] ?? ''}',
        checkOut: '${j['check_out'] ?? ''}',
        checkIn2: '${j['check_in_2'] ?? ''}',
        checkOut2: '${j['check_out_2'] ?? ''}',
        distanceIn: (j['distance_in'] as num?)?.round(),
        notes: '${j['notes'] ?? ''}',
      );
}

class AttendanceShift {
  final String name;
  final String label;
  final String breakStart;
  final String breakEnd;
  final int toleranceMinutes;
  final bool isSplit;

  const AttendanceShift(this.name, this.label, this.breakStart, this.breakEnd, this.toleranceMinutes, this.isSplit);

  factory AttendanceShift.fromJson(Map<String, dynamic> j) => AttendanceShift(
        '${j['name'] ?? ''}',
        '${j['label'] ?? ''}',
        '${j['break_start_time'] ?? ''}',
        '${j['break_end_time'] ?? ''}',
        j['tolerance_minutes'] as int? ?? 0,
        j['is_split'] == true,
      );
}

/// Aturan validasi absensi perusahaan (tabel attendance_settings).
class AttendanceRules {
  final bool locationEnabled;
  final int maxDistanceMeters;
  final bool locationForCheckout;
  final bool faceEnabled;
  final bool faceForCheckout;
  final bool faceEnrolled;

  const AttendanceRules({
    this.locationEnabled = false,
    this.maxDistanceMeters = 0,
    this.locationForCheckout = false,
    this.faceEnabled = false,
    this.faceForCheckout = false,
    this.faceEnrolled = false,
  });

  factory AttendanceRules.fromJson(Map<String, dynamic> j) => AttendanceRules(
        locationEnabled: j['is_location_enabled'] == true && j['office_latitude'] != null,
        maxDistanceMeters: j['max_distance_meters'] as int? ?? 0,
        locationForCheckout: j['require_location_for_checkout'] == true,
        faceEnabled: j['is_face_recognition_enabled'] == true,
        faceForCheckout: j['require_face_for_checkout'] == true,
        faceEnrolled: j['face_enrolled'] == true,
      );
}

class AttendanceToday {
  final String date;

  /// day_off | checkin_1 | checkout_1 | checkin_2 | checkout_2 | done
  final String state;
  final String holiday;
  final AttendanceShift? shift;
  final AttendanceRecord? attendance;
  final AttendanceRules rules;

  const AttendanceToday({required this.date, required this.state, this.holiday = '', this.shift, this.attendance, this.rules = const AttendanceRules()});

  factory AttendanceToday.fromJson(Map<String, dynamic> j) => AttendanceToday(
        date: '${j['date'] ?? ''}',
        state: '${j['state'] ?? 'checkin_1'}',
        holiday: '${j['holiday'] ?? ''}',
        shift: j['shift'] is Map<String, dynamic> ? AttendanceShift.fromJson(j['shift'] as Map<String, dynamic>) : null,
        attendance: j['attendance'] is Map<String, dynamic> ? AttendanceRecord.fromJson(j['attendance'] as Map<String, dynamic>) : null,
        rules: j['setting'] is Map<String, dynamic> ? AttendanceRules.fromJson(j['setting'] as Map<String, dynamic>) : const AttendanceRules(),
      );

  bool get isCheckIn => state == 'checkin_1' || state == 'checkin_2';
  bool get needsLocation => rules.locationEnabled && (isCheckIn || rules.locationForCheckout);
  bool get needsFace => rules.faceEnabled && (isCheckIn || rules.faceForCheckout);
}

class TeamAttendance {
  final String date;
  final int total;
  final int present;
  final List<(String name, AttendanceRecord? record)> employees;
  const TeamAttendance(this.date, this.total, this.present, this.employees);
}

/// Absensi lewat API `/hris/attendance/*` di ProjectHub Pro. Aturan
/// check-in/out (shift malam, sesi split, telat) dihitung server.
class AttendanceRepository extends ChangeNotifier {
  AttendanceRepository._();
  static final AttendanceRepository instance = AttendanceRepository._();

  final _api = PhApi.instance;

  AttendanceToday? today;
  bool loading = false;
  String? error;

  /// Riwayat per bulan, key "yyyy-MM".
  final Map<String, List<AttendanceRecord>> history = {};

  /// Hari libur per tahun: tanggal -> nama.
  final Map<int, Map<String, String>> holidays = {};

  TeamAttendance? team;
  String? teamError;

  Future<void> loadToday() async {
    await Future<void>.value(); // dipanggil dari initState
    if (!AuthRepository.instance.isLoggedIn) {
      error = 'Silakan login untuk memakai absensi';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      today = AttendanceToday.fromJson(await _api.get('/hris/attendance/today') as Map<String, dynamic>);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Check-in atau check-out sesuai state hari ini. Mengembalikan pesan
  /// server (mis. "Check-in berhasil. Telat 12 menit"). Galat dilempar
  /// sebagai [ApiException].
  Future<String> submit() async {
    final t = today;
    if (t == null) throw const ApiException('Data absensi belum dimuat');
    if (t.needsFace) {
      throw const ApiException('Perusahaan mewajibkan verifikasi wajah. Fitur ini belum tersedia di aplikasi, silakan absen lewat web.');
    }
    final body = <String, Object?>{};
    if (t.needsLocation) {
      final pos = await _position();
      body['lat'] = pos.latitude;
      body['lng'] = pos.longitude;
    }
    final path = t.isCheckIn ? '/hris/attendance/check-in' : '/hris/attendance/check-out';
    try {
      final res = await _api.post(path, body) as Map<String, dynamic>;
      _applyResult(res);
      return '${res['message'] ?? 'Absensi tercatat'}';
    } on ApiException {
      // 422 dari server berisi alasan penolakan (mis. sudah absen, terlalu jauh).
      await loadToday();
      rethrow;
    }
  }

  void _applyResult(Map<String, dynamic> res) {
    if (res['today'] is Map<String, dynamic>) today = AttendanceToday.fromJson(res['today'] as Map<String, dynamic>);
    final key = today?.date.substring(0, 7);
    history.remove(key);
    notifyListeners();
  }

  Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException('GPS tidak aktif. Aktifkan lokasi lalu coba lagi.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw const ApiException('Izin lokasi ditolak. Absensi perusahaan Anda mewajibkan lokasi.');
    }
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
  }

  Future<void> loadMonth(int year, int month) async {
    final key = '$year-${month.toString().padLeft(2, '0')}';
    if (!AuthRepository.instance.isLoggedIn) return;
    try {
      final results = await Future.wait([
        _api.get('/hris/attendance/history?year=$year&month=$month'),
        if (!holidays.containsKey(year)) _api.get('/hris/attendance/holidays?year=$year'),
      ]);
      history[key] = [for (final r in (results[0] as List? ?? const [])) AttendanceRecord.fromJson(r as Map<String, dynamic>)];
      if (results.length > 1) {
        holidays[year] = {for (final h in (results[1] as List? ?? const [])) '${h['date']}': '${h['name']}'};
      }
    } on ApiException catch (e) {
      error ??= e.message;
    }
    notifyListeners();
  }

  List<AttendanceRecord>? monthRecords(int year, int month) => history['$year-${month.toString().padLeft(2, '0')}'];

  String? holidayOn(String isoDate) => holidays[int.tryParse(isoDate.substring(0, 4)) ?? 0]?[isoDate];

  Future<void> loadTeam(String isoDate) async {
    await Future<void>.value();
    if (!AuthRepository.instance.isLoggedIn) return;
    teamError = null;
    try {
      final j = await _api.get('/hris/attendance/team?date=$isoDate') as Map<String, dynamic>;
      team = TeamAttendance(
        '${j['date']}',
        j['total'] as int? ?? 0,
        j['present'] as int? ?? 0,
        [
          for (final e in (j['employees'] as List? ?? const []))
            ('${e['name']}', e['attendance'] is Map<String, dynamic> ? AttendanceRecord.fromJson(e['attendance'] as Map<String, dynamic>) : null),
        ],
      );
    } on ApiException catch (e) {
      team = null;
      teamError = e.message;
    }
    notifyListeners();
  }

  void clear() {
    today = null;
    error = null;
    history.clear();
    holidays.clear();
    team = null;
    teamError = null;
    notifyListeners();
  }
}
