import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_repository.dart';
import 'ph_api.dart';

class ApiRole {
  final int id;
  final String name;
  final String label;
  final bool isSystem;
  final bool canEdit;
  final bool canDelete;
  final int usersCount;

  const ApiRole({
    required this.id,
    required this.name,
    required this.label,
    this.isSystem = false,
    this.canEdit = false,
    this.canDelete = false,
    this.usersCount = 0,
  });

  factory ApiRole.fromJson(Map<String, dynamic> j) => ApiRole(
        id: _toInt(j['id']),
        name: '${j['name'] ?? ''}',
        label: '${j['label'] ?? j['name'] ?? ''}',
        isSystem: j['is_system'] == true || j['is_system'] == 1,
        canEdit: j['can_edit'] == true || j['can_edit'] == 1,
        canDelete: j['can_delete'] == true || j['can_delete'] == 1,
        usersCount: _toInt(j['users_count']),
      );
}

class ApiPermItem {
  final String name;
  final String label;
  const ApiPermItem({required this.name, required this.label});
}

class ApiPermGroup {
  final String name;
  final String module;
  final List<ApiPermItem> permissions;
  const ApiPermGroup({required this.name, required this.module, required this.permissions});
}

class ApiPermRole {
  final int id;
  final String name;
  final String label;
  final bool isSystem;
  bool isCustomized;
  final Set<String> permissions;

  ApiPermRole({
    required this.id,
    required this.name,
    required this.label,
    required this.isSystem,
    required this.isCustomized,
    required this.permissions,
  });

  factory ApiPermRole.fromJson(Map<String, dynamic> j) => ApiPermRole(
        id: _toInt(j['id']),
        name: '${j['name'] ?? ''}',
        label: '${j['label'] ?? j['name'] ?? ''}',
        isSystem: j['is_system'] == true || j['is_system'] == 1,
        isCustomized: j['is_customized'] == true || j['is_customized'] == 1,
        permissions: {
          for (final p in (j['permissions'] as List? ?? const [])) '$p',
        },
      );
}

class ApiPermissionsData {
  final List<ApiPermGroup> groups;
  final List<ApiPermRole> roles;
  final String note;
  final int totalPermissions;
  final int totalRoles;

  const ApiPermissionsData({
    required this.groups,
    required this.roles,
    this.note = '',
    this.totalPermissions = 0,
    this.totalRoles = 0,
  });
}

class ApiActivityLog {
  final int id;
  final String logName;
  final String logLabel;
  final String description;
  final String event;
  final String subjectType;
  final int subjectId;
  final String causerName;
  final String causerEmail;
  final String causerAvatarUrl;
  final String subjectName;
  final String createdAt;

  const ApiActivityLog({
    required this.id,
    required this.logName,
    required this.logLabel,
    required this.description,
    required this.event,
    required this.subjectType,
    required this.subjectId,
    required this.causerName,
    this.causerEmail = '',
    this.causerAvatarUrl = '',
    this.subjectName = '',
    this.createdAt = '',
  });

  factory ApiActivityLog.fromJson(Map<String, dynamic> j) {
    final causer = j['causer'] is Map ? j['causer'] as Map : const {};
    final props = j['properties'] is Map ? j['properties'] as Map : const {};
    final attrs = props['attributes'] is Map ? props['attributes'] as Map : const {};
    final title = '${attrs['name'] ?? attrs['title'] ?? attrs['invoice_number'] ?? ''}';
    return ApiActivityLog(
      id: _toInt(j['id']),
      logName: '${j['log_name'] ?? ''}',
      logLabel: '${j['log_label'] ?? j['log_name'] ?? ''}',
      description: '${j['description'] ?? ''}',
      event: '${j['event'] ?? ''}',
      subjectType: '${j['subject_type'] ?? ''}',
      subjectId: _toInt(j['subject_id']),
      causerName: '${causer['name'] ?? 'Sistem'}',
      causerEmail: '${causer['email'] ?? ''}',
      causerAvatarUrl: '${causer['avatar_url'] ?? ''}',
      subjectName: title,
      createdAt: '${j['created_at'] ?? ''}',
    );
  }
}

class ApiActivityPage {
  final List<ApiActivityLog> data;
  final int currentPage;
  final int lastPage;
  final int total;
  final List<(String, String)> logNames;

  const ApiActivityPage({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.logNames,
  });
}

class ApiInvoiceItem {
  final String description;
  final int quantity;
  final int unitPrice;
  final int total;

  const ApiInvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory ApiInvoiceItem.fromJson(Map<String, dynamic> j) => ApiInvoiceItem(
        description: '${j['description'] ?? ''}',
        quantity: _toInt(j['quantity'], 1),
        unitPrice: _toNumInt(j['unit_price']),
        total: _toNumInt(j['total'], _toInt(j['quantity'], 1) * _toNumInt(j['unit_price'])),
      );
}

class ApiInvoice {
  final int id;
  final String invoiceNumber;
  final String status; // draft | sent | paid | overdue | cancelled
  final String issueDate;
  final String dueDate;
  final int subtotal;
  final double tax;
  final int total;
  final String paidAt;
  final String notes;
  final int? projectId;
  final String projectName;
  final int? clientId;
  final String clientName;
  final String clientEmail;
  final List<ApiInvoiceItem> items;

  const ApiInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    this.issueDate = '',
    this.dueDate = '',
    this.subtotal = 0,
    this.tax = 0,
    this.total = 0,
    this.paidAt = '',
    this.notes = '',
    this.projectId,
    this.projectName = '',
    this.clientId,
    this.clientName = '',
    this.clientEmail = '',
    this.items = const [],
  });

  bool get isOverdue {
    if (status == 'overdue') return true;
    if (status == 'paid' || status == 'cancelled' || dueDate.isEmpty) return false;
    final due = DateTime.tryParse(dueDate);
    if (due == null) return false;
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  factory ApiInvoice.fromJson(Map<String, dynamic> j) {
    final proj = j['project'] is Map ? j['project'] as Map : null;
    final cli = j['client'] is Map ? j['client'] as Map : null;
    final rawItems = j['items'] as List? ?? const [];
    return ApiInvoice(
      id: _toInt(j['id']),
      invoiceNumber: '${j['invoice_number'] ?? '#${j['id']}'}',
      status: '${j['status'] ?? 'draft'}'.toLowerCase(),
      issueDate: '${j['issue_date'] ?? ''}',
      dueDate: '${j['due_date'] ?? ''}',
      subtotal: _toNumInt(j['subtotal']),
      tax: double.tryParse('${j['tax'] ?? 0}') ?? 0,
      total: _toNumInt(j['total']),
      paidAt: '${j['paid_at'] ?? ''}',
      notes: '${j['notes'] ?? ''}',
      projectId: _toIntOrNull(proj?['id'] ?? j['project_id']),
      projectName: '${proj?['name'] ?? ''}',
      clientId: _toIntOrNull(cli?['id'] ?? j['client_id']),
      clientName: '${cli?['name'] ?? '-'}',
      clientEmail: '${cli?['email'] ?? ''}',
      items: [
        for (final it in rawItems)
          if (it is Map<String, dynamic>) ApiInvoiceItem.fromJson(it),
      ],
    );
  }
}

class ApiInvoiceStats {
  final int totalAmount;
  final int paidAmount;
  final int pendingAmount;
  final int overdueAmount;
  final int totalCount;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;

  const ApiInvoiceStats({
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.pendingAmount = 0,
    this.overdueAmount = 0,
    this.totalCount = 0,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.overdueCount = 0,
  });

  factory ApiInvoiceStats.fromJson(Map<String, dynamic> j) => ApiInvoiceStats(
        totalAmount: _toNumInt(j['total_amount']),
        paidAmount: _toNumInt(j['paid_amount']),
        pendingAmount: _toNumInt(j['pending_amount']),
        overdueAmount: _toNumInt(j['overdue_amount']),
        totalCount: _toInt(j['total_count']),
        paidCount: _toInt(j['paid_count']),
        pendingCount: _toInt(j['pending_count']),
        overdueCount: _toInt(j['overdue_count']),
      );
}

class ApiInvoicePage {
  final List<ApiInvoice> data;
  final int currentPage;
  final int lastPage;
  final int total;
  final ApiInvoiceStats stats;
  final bool canCreate;
  final bool canUpdate;

  const ApiInvoicePage({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.stats,
    this.canCreate = false,
    this.canUpdate = false,
  });
}

/// Client API untuk Roles, Permissions, Activity Logs, dan Invoices.
class AdminApiRepository {
  AdminApiRepository._();
  static final AdminApiRepository instance = AdminApiRepository._();

  final _api = PhApi.instance;

  // ------------------------------------------------------------------ Roles

  Future<List<ApiRole>> fetchRoles({String search = ''}) async {
    final q = search.trim().isEmpty ? '' : '?search=${Uri.encodeQueryComponent(search.trim())}';
    final res = await _api.get('/roles$q');
    final list = res is List ? res : (res is Map ? (res['data'] as List? ?? const []) : const []);
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) ApiRole.fromJson(item),
    ];
  }

  Future<ApiRole> createRole(String name) async {
    final res = await _api.post('/roles', {'name': name.trim()}) as Map<String, dynamic>;
    final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
    return ApiRole.fromJson(data);
  }

  Future<ApiRole> updateRole(int id, String name) async {
    final res = await _api.put('/roles/$id', {'name': name.trim()}) as Map<String, dynamic>;
    final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
    return ApiRole.fromJson(data);
  }

  Future<void> deleteRole(int id) async {
    await _api.delete('/roles/$id');
  }

  // ------------------------------------------------------------ Permissions

  Future<ApiPermissionsData> fetchPermissions() async {
    final res = await _api.get('/permissions') as Map<String, dynamic>;
    final groups = <ApiPermGroup>[];
    for (final g in (res['groups'] as List? ?? const [])) {
      if (g is! Map<String, dynamic>) continue;
      groups.add(ApiPermGroup(
        name: '${g['name'] ?? ''}',
        module: '${g['module'] ?? ''}',
        permissions: [
          for (final p in (g['permissions'] as List? ?? const []))
            if (p is Map) ApiPermItem(name: '${p['name'] ?? ''}', label: '${p['label'] ?? p['name'] ?? ''}'),
        ],
      ));
    }
    final roles = <ApiPermRole>[
      for (final r in (res['roles'] as List? ?? const []))
        if (r is Map<String, dynamic>) ApiPermRole.fromJson(r),
    ];
    final stats = res['stats'] is Map ? res['stats'] as Map : const {};
    return ApiPermissionsData(
      groups: groups,
      roles: roles,
      note: '${res['note'] ?? ''}',
      totalPermissions: _toInt(stats['total_permissions']),
      totalRoles: _toInt(stats['total_roles'], roles.length),
    );
  }

  Future<List<String>> savePermissions(String roleName, List<String> permissions) async {
    final res = await _api.put('/permissions/$roleName', {'permissions': permissions}) as Map<String, dynamic>;
    final data = res['data'] is Map ? res['data'] as Map : const {};
    return [for (final p in (data['permissions'] as List? ?? const [])) '$p'];
  }

  Future<List<String>> resetPermissions(String roleName) async {
    final res = await _api.post('/permissions/$roleName/reset') as Map<String, dynamic>;
    final data = res['data'] is Map ? res['data'] as Map : const {};
    return [for (final p in (data['permissions'] as List? ?? const [])) '$p'];
  }

  // ---------------------------------------------------------- Activity Logs

  Future<ApiActivityPage> fetchActivityLogs({
    String logName = '',
    String search = '',
    int page = 1,
    int perPage = 25,
  }) async {
    final params = <String>[
      'page=$page',
      'per_page=$perPage',
      if (logName.isNotEmpty) 'log_name=${Uri.encodeQueryComponent(logName)}',
      if (search.trim().isNotEmpty) 'search=${Uri.encodeQueryComponent(search.trim())}',
    ];
    final res = await _api.get('/activity-logs?${params.join('&')}') as Map<String, dynamic>;
    final list = [
      for (final item in (res['data'] as List? ?? const []))
        if (item is Map<String, dynamic>) ApiActivityLog.fromJson(item),
    ];
    final logNames = <(String, String)>[
      for (final ln in (res['log_names'] as List? ?? const []))
        if (ln is Map) ('${ln['value'] ?? ''}', '${ln['label'] ?? ln['value'] ?? ''}'),
    ];
    return ApiActivityPage(
      data: list,
      currentPage: _toInt(res['current_page'], page),
      lastPage: _toInt(res['last_page'], 1),
      total: _toInt(res['total'], list.length),
      logNames: logNames,
    );
  }

  // --------------------------------------------------------------- Invoices

  Future<ApiInvoicePage> fetchInvoices({
    String status = '',
    String search = '',
    int page = 1,
    int perPage = 15,
  }) async {
    final params = <String>[
      'page=$page',
      'per_page=$perPage',
      if (status.isNotEmpty) 'status=${Uri.encodeQueryComponent(status)}',
      if (search.trim().isNotEmpty) 'search=${Uri.encodeQueryComponent(search.trim())}',
    ];
    final res = await _api.get('/invoices?${params.join('&')}') as Map<String, dynamic>;
    final list = [
      for (final item in (res['data'] as List? ?? const []))
        if (item is Map<String, dynamic>) ApiInvoice.fromJson(item),
    ];
    final statsMap = res['stats'] is Map<String, dynamic> ? res['stats'] as Map<String, dynamic> : const <String, dynamic>{};
    final canMap = res['can'] is Map ? res['can'] as Map : const {};
    return ApiInvoicePage(
      data: list,
      currentPage: _toInt(res['current_page'], page),
      lastPage: _toInt(res['last_page'], 1),
      total: _toInt(res['total'], list.length),
      stats: ApiInvoiceStats.fromJson(statsMap),
      canCreate: canMap['create'] == true || canMap['create'] == 1,
      canUpdate: canMap['update'] == true || canMap['update'] == 1,
    );
  }

  Future<ApiInvoice> fetchInvoiceDetail(int id) async {
    final res = await _api.get('/invoices/$id') as Map<String, dynamic>;
    final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
    return ApiInvoice.fromJson(data);
  }

  Future<ApiInvoice> createInvoice(Map<String, Object?> payload) async {
    final res = await _api.post('/invoices', payload) as Map<String, dynamic>;
    final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
    return ApiInvoice.fromJson(data);
  }

  Future<void> sendInvoice(int id) async {
    await _api.put('/invoices/$id/send');
  }

  Future<void> markInvoicePaid(int id) async {
    await _api.put('/invoices/$id/mark-paid');
  }

  Future<Uint8List> downloadInvoicePdf(int id) async {
    final token = AuthRepository.instance.token;
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/invoices/$id/pdf'),
      headers: {
        'Accept': 'application/pdf',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) return res.bodyBytes;
    if (res.statusCode == 403) throw const ApiException('Tidak memiliki izin access invoices', 403);
    throw ApiException('Gagal mengunduh PDF invoice (HTTP ${res.statusCode})', res.statusCode);
  }
}

int _toInt(Object? v, [int fallback = 0]) => v is int ? v : int.tryParse('${v ?? ''}') ?? fallback;
int? _toIntOrNull(Object? v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
int _toNumInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.round();
  return double.tryParse('${v ?? ''}')?.round() ?? fallback;
}
