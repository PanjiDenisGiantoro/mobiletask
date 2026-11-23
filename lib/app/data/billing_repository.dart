import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_repository.dart';
import 'ph_api.dart';

class StorageBreakdownItem {
  final String menu;
  final int bytes;
  final int percent;

  const StorageBreakdownItem({
    required this.menu,
    required this.bytes,
    required this.percent,
  });
}

class BillingSubscription {
  final int? packageId;
  final String packageSlug;
  final String packageName;
  final String planName;
  final String activeUntil;
  final bool isLifetime;
  final bool isExpired;
  final int daysRemaining;
  final int? maxUsers;
  final int userCount;
  final int? maxProjects;
  final int projectCount;
  final int? maxStorageBytes;
  final int storageUsedBytes;
  final List<StorageBreakdownItem> storageBreakdown;

  const BillingSubscription({
    this.packageId,
    this.packageSlug = '',
    this.packageName = '',
    this.planName = '',
    this.activeUntil = '',
    this.isLifetime = false,
    this.isExpired = false,
    this.daysRemaining = 0,
    this.maxUsers,
    this.userCount = 0,
    this.maxProjects,
    this.projectCount = 0,
    this.maxStorageBytes,
    this.storageUsedBytes = 0,
    this.storageBreakdown = const [],
  });

  bool get hasPackage => packageId != null || planName.isNotEmpty || packageName.isNotEmpty;

  String get displayPlanName =>
      planName.isNotEmpty ? planName : (packageName.isNotEmpty ? packageName : 'Free');

  factory BillingSubscription.fromJson(Map<String, dynamic> j) {
    final pkg = j['package'] is Map ? j['package'] as Map : null;
    final limits = j['limits'] is Map ? j['limits'] as Map : const {};
    final totalStorage = _toInt(limits['storage_used_bytes']);
    final rawBreakdown = j['storage_breakdown'] ??
        limits['storage_breakdown'] ??
        j['storage_by_menu'] ??
        limits['storage_by_menu'];
    final parsedBreakdown = <StorageBreakdownItem>[];
    if (rawBreakdown is List) {
      for (final item in rawBreakdown) {
        if (item is Map) {
          final bytes = _toInt(item['bytes'] ?? item['size']);
          final pct = _toInt(
            item['percent'],
            totalStorage > 0 ? ((bytes / totalStorage) * 100).round() : 0,
          );
          parsedBreakdown.add(StorageBreakdownItem(
            menu: '${item['label'] ?? item['menu'] ?? item['name'] ?? '-'}',
            bytes: bytes,
            percent: pct.clamp(0, 100),
          ));
        }
      }
    } else if (rawBreakdown is Map) {
      rawBreakdown.forEach((k, v) {
        final bytes = v is Map ? _toInt(v['bytes'] ?? v['size']) : _toInt(v);
        final pct = v is Map
            ? _toInt(v['percent'], totalStorage > 0 ? ((bytes / totalStorage) * 100).round() : 0)
            : (totalStorage > 0 ? ((bytes / totalStorage) * 100).round() : 0);
        parsedBreakdown.add(StorageBreakdownItem(
          menu: '$k',
          bytes: bytes,
          percent: pct.clamp(0, 100),
        ));
      });
    }

    return BillingSubscription(
      packageId: _toIntOrNull(pkg?['id']),
      packageSlug: '${pkg?['slug'] ?? ''}',
      packageName: '${pkg?['name'] ?? ''}',
      planName: '${j['plan_name'] ?? ''}',
      activeUntil: '${j['active_until'] ?? ''}',
      isLifetime: j['is_lifetime'] == true || j['is_lifetime'] == 1,
      isExpired: j['is_expired'] == true || j['is_expired'] == 1,
      daysRemaining: _toInt(j['days_remaining']),
      maxUsers: _toIntOrNull(limits['max_users']),
      userCount: _toInt(limits['user_count']),
      maxProjects: _toIntOrNull(limits['max_projects']),
      projectCount: _toInt(limits['project_count']),
      maxStorageBytes: _toIntOrNull(limits['max_storage_bytes']),
      storageUsedBytes: totalStorage,
      storageBreakdown: parsedBreakdown,
    );
  }
}

class BillingPackage {
  final int id;
  final String slug;
  final String name;
  final String tagline;
  final String description;
  final int pricePerUser;
  final int pricePerUserYearly;
  final int yearlySavingPercent;
  final int minUsers;
  final int? maxUsers;
  final int? maxProjects;
  final String storageLabel;
  final bool isPopular;
  final String ctaType;
  final List<String> features;
  final bool isOwned;

  const BillingPackage({
    required this.id,
    this.slug = '',
    required this.name,
    this.tagline = '',
    this.description = '',
    this.pricePerUser = 0,
    this.pricePerUserYearly = 0,
    this.yearlySavingPercent = 0,
    this.minUsers = 1,
    this.maxUsers,
    this.maxProjects,
    this.storageLabel = '',
    this.isPopular = false,
    this.ctaType = 'register',
    this.features = const [],
    this.isOwned = false,
  });

  factory BillingPackage.fromJson(Map<String, dynamic> j) {
    return BillingPackage(
      id: _toInt(j['id']),
      slug: '${j['slug'] ?? ''}',
      name: '${j['name'] ?? ''}',
      tagline: '${j['tagline'] ?? ''}',
      description: '${j['description'] ?? ''}',
      pricePerUser: _toInt(j['price_per_user']),
      pricePerUserYearly: _toInt(j['price_per_user_yearly']),
      yearlySavingPercent: _toInt(j['yearly_saving_percent']),
      minUsers: _toInt(j['min_users'], 1).clamp(1, 99999),
      maxUsers: _toIntOrNull(j['max_users']),
      maxProjects: _toIntOrNull(j['max_projects']),
      storageLabel: '${j['storage_label'] ?? ''}',
      isPopular: j['is_popular'] == true || j['is_popular'] == 1,
      ctaType: '${j['cta_type'] ?? 'register'}',
      features: [
        for (final f in (j['features'] as List? ?? const [])) '$f',
      ],
      isOwned: j['is_owned'] == true || j['is_owned'] == 1,
    );
  }
}

class BillingPaymentMethod {
  final String code;
  final String name;
  final String group;
  final int feeFlat;
  final double feePercent;

  const BillingPaymentMethod({
    required this.code,
    required this.name,
    this.group = 'Lainnya',
    this.feeFlat = 0,
    this.feePercent = 0,
  });

  factory BillingPaymentMethod.fromJson(Map<String, dynamic> j) {
    return BillingPaymentMethod(
      code: '${j['code'] ?? ''}',
      name: '${j['name'] ?? ''}',
      group: '${j['group'] ?? 'Lainnya'}',
      feeFlat: _toInt(j['fee_flat']),
      feePercent: double.tryParse('${j['fee_percent'] ?? 0}') ?? 0,
    );
  }
}

class BillingFeeOption {
  final String code;
  final String name;
  final int fee;
  final int total;

  const BillingFeeOption({
    required this.code,
    required this.name,
    required this.fee,
    required this.total,
  });

  factory BillingFeeOption.fromJson(Map<String, dynamic> j) {
    return BillingFeeOption(
      code: '${j['code'] ?? ''}',
      name: '${j['name'] ?? ''}',
      fee: _toInt(j['fee']),
      total: _toInt(j['total']),
    );
  }
}

class BillingQuote {
  final int users;
  final String cycle;
  final int months;
  final int pricePerUser;
  final int gross;
  final String promoName;
  final int discount;
  final int subtotal;
  final int ppnRate;
  final int ppn;
  final int total;
  final int durationDays;
  final List<BillingFeeOption> fees;

  const BillingQuote({
    this.users = 1,
    this.cycle = 'monthly',
    this.months = 1,
    this.pricePerUser = 0,
    this.gross = 0,
    this.promoName = '',
    this.discount = 0,
    this.subtotal = 0,
    this.ppnRate = 11,
    this.ppn = 0,
    this.total = 0,
    this.durationDays = 30,
    this.fees = const [],
  });

  factory BillingQuote.fromJson(Map<String, dynamic> j) {
    final q = j['quote'] is Map ? j['quote'] as Map : j;
    final promo = q['promo'] is Map ? q['promo'] as Map : null;
    return BillingQuote(
      users: _toInt(q['users'], 1),
      cycle: '${q['cycle'] ?? 'monthly'}',
      months: _toInt(q['months'], 1),
      pricePerUser: _toInt(q['price_per_user']),
      gross: _toInt(q['gross']),
      promoName: '${promo?['name'] ?? ''}',
      discount: _toInt(q['discount']),
      subtotal: _toInt(q['subtotal']),
      ppnRate: _toInt(q['ppn_rate'], 11),
      ppn: _toInt(q['ppn']),
      total: _toInt(q['total']),
      durationDays: _toInt(q['duration_days'], 30),
      fees: [
        for (final f in (j['fees'] as List? ?? const []))
          if (f is Map<String, dynamic>) BillingFeeOption.fromJson(f),
      ],
    );
  }
}

class BillingOrder {
  final int id;
  final String orderNumber;
  final int? packageId;
  final String packageName;
  final String billingCycle;
  final int userCount;
  final String cycleLabel;
  final int amount;
  final String amountLabel;
  final int gross;
  final String promoName;
  final int discount;
  final int subtotal;
  final int ppnRate;
  final int ppn;
  final int fee;
  final int total;
  final String paymentMethodCode;
  final String paymentMethodName;
  final String status; // pending | paid | failed | expired
  final String statusLabel;
  final bool isPayable;
  final int durationDays;
  final String createdAt;
  final String paidAt;
  final String paymentExpiresAt;
  final String invoiceUrl;

  const BillingOrder({
    required this.id,
    required this.orderNumber,
    this.packageId,
    this.packageName = '',
    this.billingCycle = 'monthly',
    this.userCount = 1,
    this.cycleLabel = 'Bulanan',
    this.amount = 0,
    this.amountLabel = '',
    this.gross = 0,
    this.promoName = '',
    this.discount = 0,
    this.subtotal = 0,
    this.ppnRate = 11,
    this.ppn = 0,
    this.fee = 0,
    this.total = 0,
    this.paymentMethodCode = '',
    this.paymentMethodName = '',
    this.status = 'pending',
    this.statusLabel = 'Menunggu Pembayaran',
    this.isPayable = false,
    this.durationDays = 30,
    this.createdAt = '',
    this.paidAt = '',
    this.paymentExpiresAt = '',
    this.invoiceUrl = '',
  });

  factory BillingOrder.fromJson(Map<String, dynamic> j) {
    final pkg = j['package'] is Map ? j['package'] as Map : null;
    final br = j['breakdown'] is Map ? j['breakdown'] as Map : const {};
    final pm = j['payment_method'] is Map ? j['payment_method'] as Map : null;
    return BillingOrder(
      id: _toInt(j['id']),
      orderNumber: '${j['order_number'] ?? ''}',
      packageId: _toIntOrNull(pkg?['id']),
      packageName: '${pkg?['name'] ?? ''}',
      billingCycle: '${j['billing_cycle'] ?? 'monthly'}',
      userCount: _toInt(j['user_count'], 1),
      cycleLabel: '${j['cycle_label'] ?? ''}',
      amount: _toInt(j['amount']),
      amountLabel: '${j['amount_label'] ?? ''}',
      gross: _toInt(br['gross']),
      promoName: '${br['promo_name'] ?? ''}',
      discount: _toInt(br['discount']),
      subtotal: _toInt(br['subtotal']),
      ppnRate: _toInt(br['ppn_rate'], 11),
      ppn: _toInt(br['ppn']),
      fee: _toInt(br['fee']),
      total: _toInt(br['total'], _toInt(j['amount'])),
      paymentMethodCode: '${pm?['code'] ?? ''}',
      paymentMethodName: '${pm?['name'] ?? ''}',
      status: '${j['status'] ?? 'pending'}'.toLowerCase(),
      statusLabel: '${j['status_label'] ?? ''}',
      isPayable: j['is_payable'] == true || j['is_payable'] == 1,
      durationDays: _toInt(j['duration_days'], 30),
      createdAt: '${j['created_at'] ?? ''}',
      paidAt: '${j['paid_at'] ?? ''}',
      paymentExpiresAt: '${j['payment_expires_at'] ?? ''}',
      invoiceUrl: '${j['invoice_url'] ?? ''}',
    );
  }
}

class BillingCheckoutResult {
  final String message;
  final String paymentUrl;
  final BillingOrder? order;

  const BillingCheckoutResult({
    required this.message,
    required this.paymentUrl,
    this.order,
  });
}

/// Repository API Langganan & Payment History (DOKU Checkout).
class BillingRepository extends ChangeNotifier {
  BillingRepository._();
  static final BillingRepository instance = BillingRepository._();

  final _api = PhApi.instance;

  BillingSubscription? subscription;
  bool subscriptionLoading = false;
  String? subscriptionError;

  List<BillingPackage> packages = [];
  BillingPackage? contactPackage;
  int ppnRate = 11;
  int defaultUserCount = 1;
  List<BillingPaymentMethod> paymentMethods = [];

  List<BillingOrder> orders = [];
  int currentPage = 1;
  int lastPage = 1;
  int totalOrders = 0;
  bool ordersLoading = false;
  String? ordersError;

  void clear() {
    subscription = null;
    subscriptionError = null;
    packages = [];
    contactPackage = null;
    paymentMethods = [];
    orders = [];
    currentPage = 1;
    lastPage = 1;
    totalOrders = 0;
    ordersError = null;
    notifyListeners();
  }

  Future<BillingSubscription?> fetchSubscription() async {
    if (!AuthRepository.instance.isLoggedIn) return null;
    subscriptionLoading = true;
    subscriptionError = null;
    notifyListeners();
    try {
      final res = await _api.get('/billing/subscription');
      if (res is Map<String, dynamic>) {
        final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
        subscription = BillingSubscription.fromJson(data);
      }
      subscriptionError = null;
    } on ApiException catch (e) {
      subscriptionError = e.message;
    } catch (_) {
      subscriptionError = 'Gagal memuat status langganan';
    } finally {
      subscriptionLoading = false;
      notifyListeners();
    }
    return subscription;
  }

  Future<void> fetchPackagesAndMethods() async {
    final results = await Future.wait<dynamic>([
      _api.get('/billing/packages'),
      _api.get('/billing/payment-methods'),
    ]);
    final pkgRes = results[0];
    if (pkgRes is Map<String, dynamic>) {
      final list = pkgRes['data'] as List? ?? const [];
      packages = [
        for (final item in list)
          if (item is Map<String, dynamic>) BillingPackage.fromJson(item),
      ];
      contactPackage = pkgRes['contact_package'] is Map<String, dynamic>
          ? BillingPackage.fromJson(pkgRes['contact_package'] as Map<String, dynamic>)
          : null;
      ppnRate = _toInt(pkgRes['ppn_rate'], 11);
      defaultUserCount = _toInt(pkgRes['default_user_count'], 1).clamp(1, 99999);
    }

    final pmRes = results[1];
    final pmList = pmRes is List
        ? pmRes
        : (pmRes is Map ? (pmRes['data'] as List? ?? const []) : const []);
    paymentMethods = [
      for (final item in pmList)
        if (item is Map<String, dynamic>) BillingPaymentMethod.fromJson(item),
    ];
    notifyListeners();
  }

  Future<BillingQuote> fetchQuote(int packageId, {int? users, String cycle = 'monthly'}) async {
    final query = <String>['cycle=$cycle', if (users != null) 'users=$users'];
    final res = await _api.get('/billing/packages/$packageId/quote?${query.join('&')}');
    if (res is Map<String, dynamic>) {
      return BillingQuote.fromJson(res);
    }
    throw const ApiException('Format quote tidak valid');
  }

  Future<BillingCheckoutResult> checkout(
    int packageId, {
    required int users,
    required String cycle,
    required String paymentMethod,
  }) async {
    final res = await _api.post('/billing/checkout/$packageId', {
      'users': users,
      'cycle': cycle,
      'payment_method': paymentMethod,
    });
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : null;
      return BillingCheckoutResult(
        message: '${res['message'] ?? 'Order berhasil dibuat'}',
        paymentUrl: '${res['payment_url'] ?? ''}',
        order: data != null ? BillingOrder.fromJson(data) : null,
      );
    }
    throw const ApiException('Gagal membuat transaksi checkout');
  }

  Future<void> fetchOrders({int page = 1, int perPage = 15}) async {
    ordersLoading = true;
    ordersError = null;
    notifyListeners();
    try {
      final res = await _api.get('/billing/orders?page=$page&per_page=$perPage');
      if (res is Map<String, dynamic>) {
        final rawList = res['data'] as List? ?? const [];
        orders = [
          for (final item in rawList)
            if (item is Map<String, dynamic>) BillingOrder.fromJson(item),
        ];
        currentPage = _toInt(res['current_page'], page);
        lastPage = _toInt(res['last_page'], 1);
        totalOrders = _toInt(res['total'], orders.length);
      }
      ordersError = null;
    } on ApiException catch (e) {
      ordersError = e.message;
    } catch (_) {
      ordersError = 'Gagal memuat riwayat pembayaran';
    } finally {
      ordersLoading = false;
      notifyListeners();
    }
  }

  Future<BillingOrder> fetchOrderDetail(String orderNumber) async {
    final res = await _api.get('/billing/orders/$orderNumber');
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
      final fresh = BillingOrder.fromJson(data);
      final idx = orders.indexWhere((o) => o.orderNumber == fresh.orderNumber);
      if (idx >= 0) {
        orders[idx] = fresh;
        notifyListeners();
      }
      return fresh;
    }
    throw const ApiException('Detail order tidak ditemukan');
  }

  Future<String> getPayUrl(String orderNumber) async {
    final res = await _api.get('/billing/orders/$orderNumber/pay');
    if (res is Map<String, dynamic>) {
      final url = '${res['payment_url'] ?? ''}';
      if (url.isNotEmpty) return url;
    }
    throw const ApiException('Link pembayaran tidak tersedia');
  }

  Future<Uint8List> downloadInvoiceBytes(String orderNumber) async {
    final token = AuthRepository.instance.token;
    final uri = Uri.parse('$kApiBaseUrl/billing/orders/$orderNumber/invoice');
    final res = await http.get(
      uri,
      headers: {
        'Accept': 'application/pdf',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    if (res.statusCode == 403) {
      throw const ApiException('Anda tidak memiliki izin access billing untuk mengunduh invoice', 403);
    }
    throw ApiException('Gagal mengunduh invoice (HTTP ${res.statusCode})', res.statusCode);
  }
}

int _toInt(Object? v, [int fallback = 0]) => v is int ? v : int.tryParse('${v ?? ''}') ?? fallback;
int? _toIntOrNull(Object? v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
