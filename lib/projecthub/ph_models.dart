// Model data sistem projecthub_pro. Nama field mengikuti kolom tabel database
// (mis. projects.budget_alert_threshold -> Project.budgetThreshold).

class PhUser {
  final String id;
  final String name;
  final bool isClient;
  const PhUser(this.id, this.name, {this.isClient = false});
}

// ---------------------------------------------------------------- Proyek

class Milestone {
  final int id;
  String title;
  String description;
  String status; // pending | in_progress | completed
  String startDate;
  String dueDate;
  String assignedTo;
  String? clientApprovedAt;
  Milestone({
    required this.id,
    required this.title,
    this.description = '',
    this.status = 'pending',
    this.startDate = '',
    this.dueDate = '',
    this.assignedTo = '',
    this.clientApprovedAt,
  });
}

class Sprint {
  final int id;
  int milestoneId;
  String name;
  String goal;
  String status; // planned | active | completed
  String startDate;
  String endDate;
  String milestone;
  Sprint({
    required this.id,
    this.milestoneId = 0,
    required this.name,
    this.goal = '',
    this.status = 'planned',
    this.startDate = '',
    this.endDate = '',
    this.milestone = '',
  });
}

class ProjectMember {
  final int id;
  String userId;
  String role;
  int maxHoursPerDay;
  ProjectMember({required this.id, required this.userId, required this.role, this.maxHoursPerDay = 8});
}

class BudgetEntry {
  final int id;
  String type; // income | expense
  String category;
  String description;
  double amount;
  String entryDate;
  String reference;
  BudgetEntry({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.entryDate,
    this.reference = '',
  });
}

class Risk {
  final int id;
  String title;
  String description;
  String category; // technical | schedule | resource | budget | external | other
  int probability; // 1-5
  int impact; // 1-5
  String status; // open | mitigated | accepted | closed
  String mitigationPlan;
  String owner;
  Risk({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'technical',
    this.probability = 3,
    this.impact = 3,
    this.status = 'open',
    this.mitigationPlan = '',
    this.owner = '',
  });
  int get score => probability * impact;
}

class ProjectFile {
  final int id;
  String url;
  String folder;
  String name;
  String mimeType;
  int size;
  String description;
  ProjectFile({
    required this.id,
    this.url = '',
    required this.folder,
    required this.name,
    this.mimeType = 'application/octet-stream',
    this.size = 0,
    this.description = '',
  });
}

class TimeLog {
  final int id;
  int taskId;
  String taskTitle;
  String userId;
  String startedAt;
  String? endedAt;
  int minutes;
  String notes;
  bool running;
  DateTime? startedAtTime;
  TimeLog({
    this.taskId = 0,
    required this.id,
    required this.taskTitle,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.minutes = 0,
    this.notes = '',
    this.running = false,
    this.startedAtTime,
  });
}

class Project {
  final int id;
  String name;
  String description;
  String clientId; // kosong = internal
  String managerId;
  String status; // draft | active | on_hold | completed | cancelled
  String startDate;
  String endDate;
  double budget;
  int budgetThreshold;
  String githubUrl;
  String meetLink;
  String meetAt;
  int progress;
  // Field khusus tampilan daftar proyek di aplikasi mobile.
  String category;
  int totalTasks;
  int doneTasks;
  List<int> memberColors;
  final List<Milestone> milestones;
  final List<Sprint> sprints;
  final List<ProjectMember> members;
  final List<BudgetEntry> budgetEntries;
  final List<Risk> risks;
  final List<ProjectFile> files;
  final List<TimeLog> timeLogs;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    this.clientId = '',
    this.managerId = '',
    this.status = 'active',
    this.startDate = '',
    this.endDate = '',
    this.budget = 0,
    this.budgetThreshold = 80,
    this.githubUrl = '',
    this.meetLink = '',
    this.meetAt = '',
    this.progress = 0,
    this.category = 'Design',
    this.totalTasks = 0,
    this.doneTasks = 0,
    this.memberColors = const [0xFF0F7BD4],
    List<Milestone>? milestones,
    List<Sprint>? sprints,
    List<ProjectMember>? members,
    List<BudgetEntry>? budgetEntries,
    List<Risk>? risks,
    List<ProjectFile>? files,
    List<TimeLog>? timeLogs,
  })  : milestones = milestones ?? [],
        sprints = sprints ?? [],
        members = members ?? [],
        budgetEntries = budgetEntries ?? [],
        risks = risks ?? [],
        files = files ?? [],
        timeLogs = timeLogs ?? [];

  double get income => budgetEntries.where((e) => e.type == 'income').fold(0.0, (s, e) => s + e.amount);
  double get expense => budgetEntries.where((e) => e.type == 'expense').fold(0.0, (s, e) => s + e.amount);
  int get budgetUsedPercent => budget <= 0 ? 0 : (expense / budget * 100).round();
  bool get completed => status == 'completed';
}

// ---------------------------------------------------------------- Task

class TaskComment {
  final String userId;
  final String body;
  final String at;
  const TaskComment(this.userId, this.body, this.at);
}

class TaskDependency {
  final String dependsOn;
  final String type; // finish_to_start | start_to_start | finish_to_finish
  const TaskDependency(this.dependsOn, this.type);
}

// ---------------------------------------------------------------- Tiket

class TicketChecklistItem {
  final int id;
  String body;
  bool done;
  TicketChecklistItem(this.body, {this.id = 0, this.done = false});
}

class TicketHistory {
  final String actorId;
  final String field;
  final String oldValue;
  final String newValue;
  final String at;
  const TicketHistory(this.actorId, this.field, this.oldValue, this.newValue, this.at);
}

class Ticket {
  final int id;
  String projectName;
  String milestone;
  String title;
  String description;
  String solution;
  String type; // bug | issue | enhancement | security | performance
  String errorCategory; // frontend | backend | database | api | infrastructure | integration | configuration | other
  String priority; // critical | high | medium | low
  String status; // open | assigned | in_progress | pending_review | resolved | closed | reopened
  String reporterId;
  String assigneeId;
  String slaDueAt;
  bool slaBreached;
  bool slaPaused;
  bool escalated;
  String resolvedAt;
  final List<TicketChecklistItem> checklist;
  final List<TaskComment> comments;
  final List<TicketHistory> history;

  Ticket({
    required this.id,
    required this.projectName,
    required this.title,
    required this.description,
    this.milestone = '',
    this.solution = '',
    this.type = 'bug',
    this.errorCategory = 'frontend',
    this.priority = 'medium',
    this.status = 'open',
    this.reporterId = '',
    this.assigneeId = '',
    this.slaDueAt = '',
    this.slaBreached = false,
    this.slaPaused = false,
    this.escalated = false,
    this.resolvedAt = '',
    List<TicketChecklistItem>? checklist,
    List<TaskComment>? comments,
    List<TicketHistory>? history,
  })  : checklist = checklist ?? [],
        comments = comments ?? [],
        history = history ?? [];
}

class CustomerRequest {
  final int id;
  String projectName;
  String customerId;
  String title;
  String description;
  String type; // feature_request | bug_report | change_request | general_inquiry
  String priority; // low | medium | high | urgent
  String status; // waiting_approval | approved | rejected | done
  String rejectionReason;
  String marketingNotes;
  String reviewedBy;
  String approvedBy;
  String approvedAt;
  String completedBy;
  String completedAt;
  String attachment;
  String createdAt;

  CustomerRequest({
    required this.id,
    required this.projectName,
    required this.customerId,
    required this.title,
    required this.description,
    this.type = 'feature_request',
    this.priority = 'medium',
    this.status = 'waiting_approval',
    this.rejectionReason = '',
    this.marketingNotes = '',
    this.reviewedBy = '',
    this.approvedBy = '',
    this.approvedAt = '',
    this.completedBy = '',
    this.completedAt = '',
    this.attachment = '',
    this.createdAt = '',
  });
}

// ---------------------------------------------------------------- Approval

class ApprovalStep {
  final String approverId;
  final String role;
  String status; // pending | approved | rejected | skipped
  String notes;
  String decidedAt;
  ApprovalStep(this.approverId, this.role, {this.status = 'pending', this.notes = '', this.decidedAt = ''});
}

/// Rujukan objek yang berubah saat approval diputuskan.
class ApprovalRef {
  final String kind; // ticket | leave | overtime
  final int id;
  final String to;
  const ApprovalRef(this.kind, this.id, {this.to = ''});
}

class Approval {
  final int id;
  String module;
  String action;
  String label;
  String requestedBy;
  String status; // pending | approved | rejected | expired | cancelled
  String expiresAt;
  String flowType; // sequential | parallel_all | any_of | single
  final List<ApprovalStep> steps;
  ApprovalRef? ref;
  bool mine;

  Approval({
    required this.id,
    required this.module,
    required this.action,
    required this.label,
    required this.requestedBy,
    required this.expiresAt,
    required this.flowType,
    required this.steps,
    this.status = 'pending',
    this.ref,
    this.mine = false,
  });

  /// Approval cuti/lembur masih lokal (modul HRIS belum punya API).
  bool get isLocal => ref != null && ref!.kind != 'ticket';
}

// ---------------------------------------------------------------- Chat

class ChatMessage {
  final int id;
  final String userId;
  String body;
  final int parentId;
  bool edited;

  /// emoji -> nama pengguna yang bereaksi.
  final Map<String, List<String>> reactions;

  /// Emoji yang sudah dipakai user yang login.
  final Set<String> myReactions;
  final String attachment;
  final String attachmentUrl;
  final String createdAt;
  bool deleted;

  /// Cuplikan pesan yang dibalas ("Nama: isi"), dari server.
  final String parentText;
  ChatMessage({
    required this.id,
    required this.userId,
    required this.body,
    this.parentId = 0,
    this.edited = false,
    Map<String, List<String>>? reactions,
    Set<String>? myReactions,
    this.attachment = '',
    this.attachmentUrl = '',
    this.createdAt = '',
    this.deleted = false,
    this.parentText = '',
  })  : reactions = reactions ?? {},
        myReactions = myReactions ?? {};
}

class Forum {
  final int id;
  String name;
  String description;
  final List<String> members;
  String lastAt;
  Forum({required this.id, required this.name, this.description = '', required this.members, this.lastAt = ''});
}

class DirectThread {
  final String userId;
  String lastAt;
  int unread;
  DirectThread(this.userId, {this.lastAt = '', this.unread = 0});
}

// ---------------------------------------------------------------- HRIS

class Employee {
  final String id;
  String name;
  String email;
  String employmentType; // tetap | kontrak | outsourcing | lainnya
  String hireDate;
  String contractEndDate;
  String organizationUnit;
  String structuralLevel;
  String shiftId;
  String shiftName;
  bool isActive;
  bool faceEnrolled;
  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.employmentType,
    required this.hireDate,
    this.contractEndDate = '',
    required this.organizationUnit,
    required this.structuralLevel,
    required this.shiftId,
    this.shiftName = '',
    this.isActive = true,
    this.faceEnrolled = false,
  });
}

class AttendanceSettings {
  bool isLocationEnabled = true;
  String officeName = 'Kantor Pusat Flovig';
  double officeLatitude = -6.2088;
  double officeLongitude = 106.8456;
  int maxDistanceMeters = 100;
  bool requireLocationForCheckout = true;
  bool isFaceRecognitionEnabled = true;
  double faceRecognitionThreshold = 0.5;
  bool requireFaceForCheckout = false;
}

class TodayAttendance {
  String checkIn = '';
  String checkOut = '';
  String checkIn2 = '';
  String checkOut2 = '';
  String notes = '';
  final Map<String, String> info = {};
  bool simulateOutsideRadius = false;
  bool simulateFaceMismatch = false;
}

class Holiday {
  final int id;
  String date;
  String name;
  Holiday(this.id, this.date, this.name);
}

class ShiftSchedule {
  final int id;
  String userId;
  String shiftId;
  String date;
  ShiftSchedule(this.id, this.userId, this.shiftId, this.date);
}

class LeaveType {
  final int id;
  final String name;
  final String code;
  final int defaultQuota;
  final bool isPaid;
  final bool needsAttachment;
  final bool hasBalance;

  /// False kalau user belum memenuhi syarat (mis. masa kerja); alasannya di [blockedMessage].
  final bool eligible;
  final String blockedMessage;
  const LeaveType(this.id, this.name, this.code,
      {this.defaultQuota = 0, this.isPaid = true, this.needsAttachment = false, this.hasBalance = false, this.eligible = true, this.blockedMessage = ''});
}

class LeaveBalance {
  final int leaveTypeId;
  final int year;
  int quota;
  int used;
  int carriedOver;
  LeaveBalance(this.leaveTypeId, this.year, {required this.quota, required this.used, required this.carriedOver});
  int get remaining => quota + carriedOver - used;
}

class LeaveRequest {
  final int id;
  String userId;
  int leaveTypeId;
  String startDate;
  String endDate;
  int totalDays;
  String reason;
  String attachment;
  String status; // pending | approved | rejected | cancelled
  String approvedBy;
  String rejectionReason;
  LeaveRequest({
    required this.id,
    required this.userId,
    required this.leaveTypeId,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    this.attachment = '',
    this.status = 'pending',
    this.approvedBy = '',
    this.rejectionReason = '',
  });
}

class OvertimeRule {
  final String dayType; // weekday | weekend
  final int hourFrom;
  final int hourTo;
  final double multiplier;
  final String label;
  const OvertimeRule(this.dayType, this.hourFrom, this.hourTo, this.multiplier, this.label);
}

class OvertimeLine {
  final String label;
  final double hours;
  final double multiplier;
  final int amount;
  const OvertimeLine(this.label, this.hours, this.multiplier, this.amount);
}

class Overtime {
  final int id;
  String userId;
  String date;
  String dayType; // weekday | weekend | holiday
  String startTime;
  String endTime;
  double totalHours;
  int hourlyWage;
  int totalAmount;
  List<OvertimeLine> breakdown;
  String description;
  String status;
  String approvedBy;
  String rejectionReason;
  Overtime({
    required this.id,
    required this.userId,
    required this.date,
    required this.dayType,
    required this.startTime,
    required this.endTime,
    required this.totalHours,
    required this.hourlyWage,
    required this.totalAmount,
    required this.breakdown,
    this.description = '',
    this.status = 'pending',
    this.approvedBy = '',
    this.rejectionReason = '',
  });
}

class Reimbursement {
  final int id;
  String userId;
  String category; // transport | makan | akomodasi | medis | pulsa | lainnya
  String title;
  String description;
  String expenseDate;
  int amount;
  String receipt;
  String status;
  String approvedBy;
  String rejectionReason;
  bool inPayroll;
  Reimbursement({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    this.description = '',
    required this.expenseDate,
    required this.amount,
    this.receipt = '',
    this.status = 'pending',
    this.approvedBy = '',
    this.rejectionReason = '',
    this.inPayroll = false,
  });
}

class Kasbon {
  final int id;
  String userId;
  String tanggal;
  int jumlah;
  int cicilanPerBulan;
  int sisa;
  String periodeTerakhir;
  int potonganPeriodeTerakhir;
  String status; // berjalan | lunas
  String keterangan;
  Kasbon({
    required this.id,
    required this.userId,
    required this.tanggal,
    required this.jumlah,
    required this.cicilanPerBulan,
    required this.sisa,
    this.periodeTerakhir = '',
    this.potonganPeriodeTerakhir = 0,
    this.status = 'berjalan',
    this.keterangan = '',
  });
}

class EmployeeSalary {
  /// employee_salaries.id di server; 0 = belum tersimpan.
  int id;
  int gajiPokok;
  int tunjanganTransport;
  int tunjanganMakan;
  int tunjanganJabatan;
  String npwp;
  String statusPajak; // TK/0 ... K/3
  bool bpjsKesehatan;
  bool bpjsKetenagakerjaan;
  String effectiveDate;
  EmployeeSalary({
    required this.gajiPokok,
    required this.tunjanganTransport,
    required this.tunjanganMakan,
    required this.tunjanganJabatan,
    this.npwp = '',
    this.statusPajak = 'TK/0',
    this.bpjsKesehatan = true,
    this.bpjsKetenagakerjaan = true,
    required this.effectiveDate,
    this.id = 0,
  });
}

class Bonus {
  final int id;
  String userId;
  int year;
  int month;
  String type; // bonus | thr | gratifikasi | jasa_produksi | lainnya
  int amount;
  String description;
  Bonus(this.id, this.userId, this.year, this.month, this.type, this.amount, this.description);
}

class Payroll {
  final int id;
  final String userId;
  final int year;
  final int month;
  final String status; // draft | finalized | paid
  final String paidAt;
  final int gajiPokok;
  final int tunjanganTransport;
  final int tunjanganMakan;
  final int tunjanganJabatan;
  final int tunjanganLainnya;
  final int bonus;
  final int lembur;
  final int reimburse;
  final int hariKerja;
  final int hariHadir;
  final int hariCuti;
  final int hariAlpha;
  final int potonganAlpha;
  final int potonganKasbon;
  final int potonganBpjsKes;
  final int potonganBpjsTk;
  final int potonganPph21;
  final int potonganLainnya;
  final String pph21Scheme;
  final int tanggunganBpjsKes;
  final int tanggunganBpjsTk;
  final int tanggunganPph21;

  const Payroll({
    required this.id,
    required this.year,
    required this.month,
    required this.status,
    this.paidAt = '',
    required this.gajiPokok,
    required this.tunjanganTransport,
    required this.tunjanganMakan,
    required this.tunjanganJabatan,
    this.tunjanganLainnya = 0,
    this.bonus = 0,
    this.lembur = 0,
    this.reimburse = 0,
    required this.hariKerja,
    required this.hariHadir,
    required this.hariCuti,
    required this.hariAlpha,
    required this.potonganAlpha,
    this.potonganKasbon = 0,
    required this.potonganBpjsKes,
    required this.potonganBpjsTk,
    required this.potonganPph21,
    this.potonganLainnya = 0,
    this.pph21Scheme = 'TER kategori B',
    required this.tanggunganBpjsKes,
    required this.tanggunganBpjsTk,
    this.tanggunganPph21 = 0,
    this.userId = '',
    this.tunjanganPph21 = 0,
    this.serverBruto,
    this.serverTotalPotongan,
    this.serverGajiBersih,
    this.serverTanggungan,
  });

  final int tunjanganPph21;

  // Total hasil hitung PayrollService di server; dipakai apa adanya bila ada.
  final int? serverBruto;
  final int? serverTotalPotongan;
  final int? serverGajiBersih;
  final int? serverTanggungan;

  int get penghasilanBruto =>
      serverBruto ?? gajiPokok + tunjanganTransport + tunjanganMakan + tunjanganJabatan + tunjanganLainnya + bonus + lembur - potonganAlpha;
  int get totalPotongan => serverTotalPotongan ?? potonganAlpha + potonganKasbon + potonganBpjsKes + potonganBpjsTk + potonganPph21 + potonganLainnya;
  int get gajiBersih =>
      serverGajiBersih ?? penghasilanBruto + reimburse - (potonganKasbon + potonganBpjsKes + potonganBpjsTk + potonganPph21 + potonganLainnya);
  int get totalTanggunganPerusahaan => serverTanggungan ?? tanggunganBpjsKes + tanggunganBpjsTk + tanggunganPph21;
}
