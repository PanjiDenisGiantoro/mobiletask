import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_repository.dart';
import '../utils/ph_format.dart';
import 'ph_models.dart';

/// Sumber data bersama untuk modul projecthub_pro di aplikasi mobile.
/// Semua isi dimuat dari API: proyek, task, tiket, request, dan approval lewat
/// `PhRemote.sync()` (ph_remote.dart); HRIS lewat `HrisRemote.syncHris()`
/// (hris_remote.dart); chat lewat chat_remote.dart.
class PhStore extends ChangeNotifier {
  PhStore._();
  static final PhStore instance = PhStore._();

  /// ID user yang sedang login (users.id di server).
  static String get meId => '${AuthRepository.instance.currentUser?.id ?? ''}';

  bool syncing = false;
  bool synced = false;
  String? syncError;

  // Status sinkronisasi HRIS (hris_remote.dart).
  bool hrisSyncing = false;
  bool hrisSynced = false;
  String? hrisError;
  final Set<String> hrisPermissions = {};
  bool can(String permission) => hrisPermissions.contains(permission);

  /// Pengguna dari server (users.id sebagai string), diisi saat sync.
  final Map<String, PhUser> users = {};

  /// ID company aktif milik user yang sedang login.
  static String get activeCompanyId {
    final raw = AuthRepository.instance.currentUser?.raw;
    final comp = raw?['company'];
    final cid = raw?['company_id'] ?? (comp is Map ? comp['id'] : null);
    if (cid == null || '$cid' == 'null') return '';
    return '$cid'.trim();
  }

  String nameOf(String id) => users[id]?.name ?? '-';

  /// Daftar user (Member & Client) yang hanya berasal dari company aktif.
  List<PhUser> get companyUsers {
    final cid = activeCompanyId;
    if (cid.isEmpty) return users.values.toList();
    final projectMemberIds = <String>{
      meId,
      for (final p in projects) ...[
        if (p.managerId.isNotEmpty) p.managerId,
        if (p.clientId.isNotEmpty) p.clientId,
        for (final m in p.members)
          if (m.userId.isNotEmpty) m.userId,
      ],
    };
    return users.values.where((u) {
      if (u.companyId.isNotEmpty) return u.companyId == cid;
      return projectMemberIds.contains(u.id);
    }).toList();
  }

  List<PhUser> get staff => companyUsers.where((u) => !u.isClient).toList();
  List<PhUser> get clients => companyUsers.where((u) => u.isClient).toList();

  void changed() => notifyListeners();

  // ------------------------------------------------------------ proyek
  final List<Project> projects = [];
  final Set<int> favoriteProjectIds = {};
  bool _favoritesLoaded = false;
  static const _favStorageKey = 'ph_favorite_projects';

  bool isFavoriteProject(int projectId) => favoriteProjectIds.contains(projectId);

  Future<void> loadFavoriteProjects() async {
    if (_favoritesLoaded) return;
    _favoritesLoaded = true;
    try {
      const storage = FlutterSecureStorage();
      final raw = await storage.read(key: _favStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          favoriteProjectIds
            ..clear()
            ..addAll(decoded.map((e) => int.tryParse('$e')).whereType<int>());
          notifyListeners();
        }
      }
    } catch (_) {
      // Abaikan bila storage tidak tersedia
    }
  }

  Future<void> toggleFavoriteProject(int projectId) async {
    if (favoriteProjectIds.contains(projectId)) {
      favoriteProjectIds.remove(projectId);
    } else {
      favoriteProjectIds.add(projectId);
    }
    notifyListeners();
    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: _favStorageKey, value: jsonEncode(favoriteProjectIds.toList()));
    } catch (_) {
      // Abaikan bila storage tidak tersedia
    }
  }
  // ID lokal dimulai jauh di atas ID server supaya tidak bentrok.
  int _id = 1000000;
  int nextId() => _id++;

  Project? projectById(int id) {
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  Project? projectByName(String name) {
    for (final p in projects) {
      if (p.name == name) return p;
    }
    return null;
  }

  // ------------------------------------------------------------ tiket / request / approval
  final List<Ticket> tickets = [];
  final List<CustomerRequest> requests = [];
  final List<Approval> approvals = [];

  Ticket? ticketById(int id) => tickets.where((t) => t.id == id).firstOrNull;
  CustomerRequest? requestById(int id) => requests.where((t) => t.id == id).firstOrNull;
  Approval? approvalById(int id) => approvals.where((t) => t.id == id).firstOrNull;

  int get pendingForMe => approvals.where((a) => a.mine && a.status == 'pending').length;

  /// Kosongkan data server saat logout supaya akun berikutnya tidak melihatnya.
  void clearRemote() {
    projects.clear();
    tickets.clear();
    requests.clear();
    approvals.clear();
    users.clear();
    for (final l in <List<Object>>[leaveTypes, leaveBalances, leaveRequests, overtimes, reimbursements, kasbons, bonuses, payrolls, employees, holidays, schedules]) {
      l.clear();
    }
    salaries.clear();
    hrisPermissions.clear();
    synced = hrisSynced = false;
    syncError = hrisError = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ HRIS
  final AttendanceSettings attendanceSettings = AttendanceSettings();
  final TodayAttendance today = TodayAttendance();
  final List<Holiday> holidays = [];
  final List<ShiftSchedule> schedules = [];
  final List<Employee> employees = [];
  final List<LeaveType> leaveTypes = [];
  final List<LeaveBalance> leaveBalances = [];
  final List<LeaveRequest> leaveRequests = [];
  final List<Overtime> overtimes = [];
  final List<Reimbursement> reimbursements = [];
  final List<Kasbon> kasbons = [];
  final Map<String, EmployeeSalary> salaries = {};

  /// Pilihan status pajak PTKP dari server (kode -> label).
  final Map<String, String> ptkpOptions = {};
  final List<Bonus> bonuses = [];
  final List<Payroll> payrolls = [];

  static const overtimeRules = [
    OvertimeRule('weekday', 1, 1, 1.5, 'Jam pertama'),
    OvertimeRule('weekday', 2, 99, 2, 'Jam berikutnya'),
    OvertimeRule('weekend', 1, 8, 2, 'Jam 1-8'),
    OvertimeRule('weekend', 9, 9, 3, 'Jam ke-9'),
    OvertimeRule('weekend', 10, 99, 4, 'Jam ke-10 ke atas'),
  ];

  LeaveType leaveType(int id) => leaveTypes.firstWhere((t) => t.id == id, orElse: () => LeaveType(id, 'Cuti #$id', '-'));

  /// Saldo cuti pertama yang punya kuota (umumnya Cuti Tahunan), null kalau belum ada.
  LeaveBalance? get myAnnualBalance => leaveBalances.firstOrNull;
  Employee? employeeById(String id) => employees.where((e) => e.id == id).firstOrNull;

  /// Upah sejam = gaji pokok / 173 (aturan umum lembur).
  int get hourlyWage => ((salaries[meId]?.gajiPokok ?? 0) / 173).round();

  List<OvertimeLine> overtimeBreakdown(String dayType, double hours) {
    final rules = overtimeRules.where((r) => r.dayType == (dayType == 'holiday' ? 'weekend' : dayType));
    final lines = <OvertimeLine>[];
    for (final r in rules) {
      final capacity = (r.hourTo - r.hourFrom + 1).toDouble();
      final hrs = (hours - (r.hourFrom - 1)).clamp(0, capacity).toDouble();
      if (hrs <= 0) continue;
      lines.add(OvertimeLine(r.label, hrs, r.multiplier, (hrs * r.multiplier * hourlyWage).round()));
    }
    return lines;
  }

  // ------------------------------------------------------------ approval side effects
  void applyApproval(Approval a, String decision, String notes) {
    final step = a.steps.firstWhere((s) => s.approverId == meId, orElse: () => a.steps.first);
    step.status = decision;
    step.notes = notes;
    step.decidedAt = '${isoDate(DateTime.now())} ${hhmm(DateTime.now())}';
    a.status = decision;
    a.mine = false;
    final ref = a.ref;
    if (ref != null) {
      switch (ref.kind) {
        case 'ticket':
          final t = ticketById(ref.id);
          if (t != null && decision == 'approved') {
            addTicketHistory(t, 'Status', statusLabel('ticket', t.status), statusLabel('ticket', ref.to));
            t.status = ref.to;
            if (ref.to == 'resolved') t.resolvedAt = '${isoDate(DateTime.now())} ${hhmm(DateTime.now())}';
          }
        case 'leave':
          final l = leaveRequests.where((e) => e.id == ref.id).firstOrNull;
          if (l != null) {
            l.status = decision;
            l.approvedBy = meId;
            l.rejectionReason = decision == 'rejected' ? notes : '';
          }
        case 'overtime':
          final o = overtimes.where((e) => e.id == ref.id).firstOrNull;
          if (o != null) {
            o.status = decision;
            o.approvedBy = meId;
            o.rejectionReason = decision == 'rejected' ? notes : '';
          }
      }
    }
    notifyListeners();
  }

  void addTicketHistory(Ticket t, String field, String from, String to) {
    t.history.insert(0, TicketHistory(meId, field, from, to, '${isoDate(DateTime.now())} ${hhmm(DateTime.now())}'));
  }
}
