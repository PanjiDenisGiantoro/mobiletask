import 'dart:async';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/billing_repository.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_widgets.dart';

/// Halaman "Payment History & Langganan" — terhubung ke API Langganan DOKU Checkout:
/// - `GET /billing/subscription`
/// - `GET /billing/packages`, `GET /billing/payment-methods`, `GET /billing/packages/{id}/quote`
/// - `POST /billing/checkout/{id}`
/// - `GET /billing/orders`, `GET /billing/orders/{order_number}`,
///   `GET /billing/orders/{order_number}/pay`, `GET /billing/orders/{order_number}/invoice`
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _repo = BillingRepository.instance;
  String? _busyOrder;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChanged);
    _loadAll();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAll({int page = 1}) async {
    await Future.wait([
      _repo.fetchSubscription(),
      _repo.fetchOrders(page: page),
    ]);
  }

  @override
  void dispose() {
    _repo.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _launchPaymentUrl(String url, String orderNumber) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) phToast(context, 'URL pembayaran tidak valid');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      phToast(context, 'Tidak dapat membuka halaman pembayaran DOKU');
      return;
    }
    if (!mounted) return;
    await _showPollingDialog(orderNumber);
  }

  Future<void> _showPollingDialog(String orderNumber) async {
    var stopped = false;
    var elapsedSeconds = 0;
    String status = 'pending';
    String statusLabel = 'Menunggu Pembayaran';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (!stopped && elapsedSeconds == 0) {
              elapsedSeconds = 1;
              Future<void>.microtask(() async {
                while (!stopped && elapsedSeconds <= 120) {
                  await Future.delayed(const Duration(seconds: 4));
                  if (stopped) break;
                  elapsedSeconds += 4;
                  try {
                    final fresh = await _repo.fetchOrderDetail(orderNumber);
                    status = fresh.status;
                    statusLabel = fresh.statusLabel.isNotEmpty ? fresh.statusLabel : fresh.status;
                    if (ctx.mounted) setDialogState(() {});
                    if (fresh.status != 'pending') {
                      stopped = true;
                      await _repo.fetchSubscription();
                      await _repo.fetchOrders(page: _repo.currentPage);
                      break;
                    }
                  } catch (_) {
                    // Lanjut polling sampai timeout 2 menit
                  }
                }
                if (!stopped) {
                  stopped = true;
                  if (ctx.mounted) setDialogState(() {});
                }
              });
            }

            final isPaid = status == 'paid';
            final isFailed = status == 'failed' || status == 'expired';
            final timedOut = stopped && status == 'pending';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Icon(
                    isPaid
                        ? Icons.check_circle_rounded
                        : (isFailed ? Icons.error_outline_rounded : Icons.hourglass_top_rounded),
                    color: isPaid
                        ? const Color(0xFF16A34A)
                        : (isFailed ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Status Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order: $orderNumber', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (isPaid)
                    const Text(
                      'Pembayaran berhasil dikonfirmasi! Langganan perusahaan Anda telah diperbarui.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF15803D)),
                    )
                  else if (isFailed)
                    Text(
                      'Status transaksi: $statusLabel. Silakan lakukan checkout ulang.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
                    )
                  else if (timedOut)
                    const Text(
                      'Menunggu konfirmasi pembayaran dari DOKU. Anda dapat mengecek statusnya kembali di Riwayat Pembayaran.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    )
                  else ...[
                    const Text(
                      'Menunggu konfirmasi pembayaran dari DOKU...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    stopped = true;
                    Navigator.of(ctx).pop();
                  },
                  child: Text(isPaid ? 'Selesai' : 'Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _payPendingOrder(BillingOrder order) async {
    setState(() => _busyOrder = order.orderNumber);
    try {
      final url = await _repo.getPayUrl(order.orderNumber);
      if (mounted) await _launchPaymentUrl(url, order.orderNumber);
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busyOrder = null);
    }
  }

  Future<void> _checkOrderStatus(BillingOrder order) async {
    setState(() => _busyOrder = order.orderNumber);
    try {
      final fresh = await _repo.fetchOrderDetail(order.orderNumber);
      if (fresh.status == 'paid') {
        await _repo.fetchSubscription();
      }
      if (mounted) {
        phToast(context, 'Status ${fresh.orderNumber}: ${fresh.statusLabel.isNotEmpty ? fresh.statusLabel : fresh.status}');
      }
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busyOrder = null);
    }
  }

  Future<void> _downloadInvoice(BillingOrder order) async {
    setState(() => _busyOrder = order.orderNumber);
    try {
      final bytes = await _repo.downloadInvoiceBytes(order.orderNumber);
      await Printing.sharePdf(bytes: bytes, filename: 'invoice-${order.orderNumber}.pdf');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busyOrder = null);
    }
  }

  Future<void> _openCheckoutSheet({int? preselectPackageId}) async {
    final result = await showModalBottomSheet<BillingCheckoutResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(preselectPackageId: preselectPackageId),
    );
    if (result != null && result.paymentUrl.isNotEmpty && mounted) {
      final orderNum = result.order?.orderNumber ?? '';
      await _repo.fetchOrders(page: 1);
      if (mounted) {
        await _launchPaymentUrl(result.paymentUrl, orderNum);
      }
    }
  }

  void _showOrderDetail(BillingOrder o) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.orderNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        '${o.packageName} · ${o.cycleLabel} · ${o.userCount} User',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                _statusPill(o.status, o.statusLabel),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            _kv('Metode Pembayaran', o.paymentMethodName.isEmpty ? o.paymentMethodCode : o.paymentMethodName),
            _kv('Subtotal Paket', rp(o.gross > 0 ? o.gross : o.subtotal)),
            if (o.discount > 0)
              _kv(o.promoName.isNotEmpty ? 'Diskon (${o.promoName})' : 'Diskon Promo', '- ${rp(o.discount)}'),
            if (o.ppn > 0) _kv('PPN (${o.ppnRate}%)', rp(o.ppn)),
            if (o.fee > 0) _kv('Biaya Layanan', rp(o.fee)),
            const Divider(height: 18, color: Color(0xFFE2E8F0)),
            Row(
              children: [
                const Text('Total Bayar', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(
                  o.amountLabel.isNotEmpty ? o.amountLabel : rp(o.total),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))),
          Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  String _formatStorageCap(int bytes) {
    if (bytes >= 1073741824) {
      final gb = bytes / 1073741824;
      return '${gb == gb.roundToDouble() ? gb.round() : gb.toStringAsFixed(1)} GB';
    }
    return fileSize(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final sub = _repo.subscription;

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
        title: const Text('Langganan & Payment History'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => _loadAll(page: _repo.currentPage),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 780;
          return RefreshIndicator(
            onRefresh: () => _loadAll(page: _repo.currentPage),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(isWide ? 22 : 14, 16, isWide ? 22 : 14, 100),
              children: [
                _buildTopHeader(isWide, sub),
                const SizedBox(height: 16),
                _buildQuotaSection(isWide, sub),
                const SizedBox(height: 14),
                _buildStorageBreakdownCard(sub),
                const SizedBox(height: 14),
                _buildPaymentHistorySection(isWide),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopHeader(bool isWide, BillingSubscription? sub) {
    final subtitle = const Text(
      'Pemakaian kuota paket dan riwayat transaksi langganan perusahaan Anda.',
      style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
    );
    final ctaBtn = FilledButton(
      onPressed: () => _openCheckoutSheet(preselectPackageId: sub?.packageId),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Perpanjang / Upgrade Paket', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: subtitle),
          const SizedBox(width: 12),
          ctaBtn,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        subtitle,
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ctaBtn),
      ],
    );
  }

  Widget _buildQuotaSection(bool isWide, BillingSubscription? sub) {
    final planName = sub?.displayPlanName ?? 'Free';
    final projUsed = sub?.projectCount ?? 0;
    final projMax = sub?.maxProjects;
    final projPct = (projMax != null && projMax > 0) ? ((projUsed / projMax) * 100).round().clamp(0, 100) : 0;

    final userUsed = sub?.userCount ?? 0;
    final userMax = sub?.maxUsers;
    final userPct = (userMax != null && userMax > 0) ? ((userUsed / userMax) * 100).round().clamp(0, 100) : 0;

    final storUsed = sub?.storageUsedBytes ?? 0;
    final storMax = sub?.maxStorageBytes;
    final storPct = (storMax != null && storMax > 0) ? ((storUsed / storMax) * 100).round().clamp(0, 100) : 0;

    final hasWarning = projPct >= 80 || userPct >= 80 || storPct >= 80 || (sub?.isExpired ?? false);

    final cards = [
      _quotaCard(
        title: 'Project',
        percent: projPct,
        usedLabel: '$projUsed',
        maxLabel: projMax != null ? ' / $projMax' : ' / ∞',
        note: 'Project yang dihapus tidak dihitung.',
      ),
      _quotaCard(
        title: 'User',
        percent: userPct,
        usedLabel: '$userUsed',
        maxLabel: userMax != null ? ' / $userMax' : ' / ∞',
        note: 'User aktif & nonaktif dihitung. Akun client tidak dihitung.',
      ),
      _quotaCard(
        title: 'Storage',
        percent: storPct,
        usedLabel: fileSize(storUsed),
        maxLabel: storMax != null ? ' / ${_formatStorageCap(storMax)}' : ' / ∞',
        note: 'Avatar, logo & foto wajah absensi tidak dihitung.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pemakaian Kuota — Paket $planName',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
            if (sub != null)
              PhPill(
                sub.isLifetime
                    ? 'Lifetime'
                    : (sub.isExpired ? 'Kedaluwarsa' : 'Aktif · ${sub.daysRemaining} hari'),
                fg: sub.isExpired ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                bg: sub.isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
              ),
          ],
        ),
        if (hasWarning) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              (sub?.isExpired ?? false)
                  ? 'Masa aktif langganan telah berakhir. Perpanjang paket agar seluruh fitur tetap berjalan.'
                  : 'Sebagian kuota hampir atau sudah habis. Upgrade paket agar tim tetap bisa menambah data.',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (isWide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
              ],
            ),
          )
        else
          Column(
            children: [
              cards[0],
              const SizedBox(height: 10),
              cards[1],
              const SizedBox(height: 10),
              cards[2],
            ],
          ),
      ],
    );
  }

  Widget _quotaCard({
    required String title,
    required int percent,
    required String usedLabel,
    required String maxLabel,
    required String note,
  }) {
    final isDanger = percent >= 90;
    final isWarn = percent >= 80 && percent < 90;
    final barColor = isDanger
        ? const Color(0xFFEF4444)
        : (isWarn ? const Color(0xFFF59E0B) : const Color(0xFF2563EB));
    final pctColor = isDanger ? const Color(0xFFDC2626) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ),
              Text(
                '$percent%',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: pctColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: usedLabel,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                TextSpan(
                  text: maxLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildStorageBreakdownCard(BillingSubscription? sub) {
    final items = sub?.storageBreakdown ?? const <StorageBreakdownItem>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              'Rincian Storage per Menu',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('MENU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                Expanded(flex: 4, child: Text('PEMAKAIAN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                SizedBox(width: 84, child: Text('UKURAN', textAlign: TextAlign.end, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Text(
                sub == null
                    ? 'Memuat rincian pemakaian storage...'
                    : 'Total storage terpakai: ${fileSize(sub.storageUsedBytes)}.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        items[i].menu,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: (items[i].percent / 100).clamp(0.0, 1.0),
                                minHeight: 7,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 34,
                            child: Text(
                              '${items[i].percent}%',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        fileSize(items[i].bytes),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildPaymentHistorySection(bool isWide) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Riwayat Pembayaran',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
                if (_repo.totalOrders > 0)
                  PhPill('${_repo.totalOrders} Transaksi', fg: const Color(0xFF2563EB), bg: const Color(0xFFEFF6FF)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (isWide)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('NO. ORDER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('PAKET', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('JUMLAH', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('TANGGAL DIBUAT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('TANGGAL DIBAYAR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  SizedBox(width: 110, child: Text('AKSI', textAlign: TextAlign.end, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                ],
              ),
            ),
          if (_repo.ordersLoading && _repo.orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_repo.ordersError != null && _repo.orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _repo.ordersError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ),
            )
          else if (_repo.orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 34, horizontal: 16),
              child: Center(
                child: Text(
                  'Belum ada riwayat pembayaran.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else ...[
            for (var i = 0; i < _repo.orders.length; i++) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              isWide ? _buildWideOrderRow(_repo.orders[i]) : _buildOrderCard(_repo.orders[i]),
            ],
            if (_repo.lastPage > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _repo.currentPage > 1 ? () => _repo.fetchOrders(page: _repo.currentPage - 1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      'Halaman ${_repo.currentPage} dari ${_repo.lastPage}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: _repo.currentPage < _repo.lastPage ? () => _repo.fetchOrders(page: _repo.currentPage + 1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWideOrderRow(BillingOrder o) {
    final busy = _busyOrder == o.orderNumber;
    return InkWell(
      onTap: () => _showOrderDetail(o),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(o.orderNumber, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ),
            Expanded(
              flex: 2,
              child: Text('${o.packageName} (${o.userCount})', style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
            ),
            Expanded(
              flex: 2,
              child: Text(
                o.amountLabel.isNotEmpty ? o.amountLabel : rp(o.amount),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(alignment: Alignment.centerLeft, child: _statusPill(o.status, o.statusLabel)),
            ),
            Expanded(
              flex: 2,
              child: Text(o.createdAt.isEmpty ? '-' : fmtDateTime(o.createdAt), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ),
            Expanded(
              flex: 2,
              child: Text(o.paidAt.isEmpty ? '-' : fmtDateTime(o.paidAt), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ),
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerRight,
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : (o.status == 'pending' && o.isPayable
                        ? FilledButton(
                            onPressed: () => _payPendingOrder(o),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Bayar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          )
                        : (o.status == 'paid'
                            ? OutlinedButton(
                                onPressed: () => _downloadInvoice(o),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Invoice', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              )
                            : TextButton(
                                onPressed: () => _openCheckoutSheet(preselectPackageId: o.packageId),
                                child: const Text('Ulangi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BillingOrder o) {
    final busy = _busyOrder == o.orderNumber;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showOrderDetail(o),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.orderNumber,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
                _statusPill(o.status, o.statusLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Paket ${o.packageName} · ${o.cycleLabel} (${o.userCount} User)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (o.paymentMethodName.isNotEmpty)
                  Text(o.paymentMethodName, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                if (o.createdAt.isNotEmpty)
                  Text(fmtDateTime(o.createdAt), style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.amountLabel.isNotEmpty ? o.amountLabel : rp(o.amount),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                  ),
                ),
                if (busy)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else if (o.status == 'pending') ...[
                  TextButton(
                    onPressed: () => _checkOrderStatus(o),
                    child: const Text('Cek Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  if (o.isPayable)
                    FilledButton(
                      onPressed: () => _payPendingOrder(o),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      child: const Text('Bayar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ] else if (o.status == 'paid')
                  OutlinedButton.icon(
                    onPressed: () => _downloadInvoice(o),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                    label: const Text('Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _openCheckoutSheet(preselectPackageId: o.packageId),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const Text('Checkout Ulang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status, String rawLabel) {
    final (label, fg, bg) = switch (status) {
      'paid' => (rawLabel.isNotEmpty ? rawLabel : 'Lunas', const Color(0xFF15803D), const Color(0xFFECFDF5)),
      'pending' => (rawLabel.isNotEmpty ? rawLabel : 'Menunggu Pembayaran', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
      'failed' => (rawLabel.isNotEmpty ? rawLabel : 'Gagal', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      _ => (rawLabel.isNotEmpty ? rawLabel : 'Kedaluwarsa', const Color(0xFF475569), const Color(0xFFF1F5F9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Sheet Checkout Paket & Metode Pembayaran DOKU.
class _CheckoutSheet extends StatefulWidget {
  final int? preselectPackageId;
  const _CheckoutSheet({this.preselectPackageId});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _repo = BillingRepository.instance;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  int? _selectedPkgId;
  int _users = 1;
  String _cycle = 'monthly';
  String _selectedMethod = '';
  BillingQuote? _quote;
  bool _quoteLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _repo.fetchPackagesAndMethods();
      final pkgs = _repo.packages;
      if (pkgs.isNotEmpty) {
        final owned = pkgs.where((p) => p.isOwned).firstOrNull;
        final pre = widget.preselectPackageId != null
            ? pkgs.where((p) => p.id == widget.preselectPackageId).firstOrNull
            : null;
        _selectedPkgId = (pre ?? owned ?? pkgs.first).id;
        _users = _repo.defaultUserCount.clamp(1, 99999);
      }
      if (_repo.paymentMethods.isNotEmpty) {
        _selectedMethod = _repo.paymentMethods.first.code;
      }
      _loading = false;
      if (mounted) setState(() {});
      await _refreshQuote();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _refreshQuote() async {
    final pkgId = _selectedPkgId;
    if (pkgId == null) return;
    setState(() => _quoteLoading = true);
    try {
      final q = await _repo.fetchQuote(pkgId, users: _users, cycle: _cycle);
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _submitCheckout() async {
    final pkgId = _selectedPkgId;
    if (pkgId == null || _selectedMethod.isEmpty) {
      phToast(context, 'Pilih paket dan metode pembayaran terlebih dahulu');
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _repo.checkout(
        pkgId,
        users: _users,
        cycle: _cycle,
        paymentMethod: _selectedMethod,
      );
      if (mounted) Navigator.of(context).pop(res);
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsByGroup = <String, List<BillingPaymentMethod>>{};
    for (final m in _repo.paymentMethods) {
      methodsByGroup.putIfAbsent(m.group, () => []).add(m);
    }

    final selectedFee = _quote?.fees.where((f) => f.code == _selectedMethod).firstOrNull;
    final grandTotal = selectedFee?.total ?? _quote?.total ?? 0;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Pilih Paket & Pembayaran', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                ),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text('1. Pilih Paket', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          for (final pkg in _repo.packages)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setState(() {
                                    _selectedPkgId = pkg.id;
                                    if (_users < pkg.minUsers) _users = pkg.minUsers;
                                  });
                                  _refreshQuote();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _selectedPkgId == pkg.id ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _selectedPkgId == pkg.id ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                      width: _selectedPkgId == pkg.id ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                Text(pkg.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                                if (pkg.isOwned)
                                                  PhPill('Paket Anda', fg: const Color(0xFF15803D), bg: const Color(0xFFECFDF5)),
                                                if (pkg.isPopular)
                                                  PhPill('Populer', fg: const Color(0xFF2563EB), bg: const Color(0xFFDBEAFE)),
                                              ],
                                            ),
                                            if (pkg.tagline.isNotEmpty)
                                              Text(pkg.tagline, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${rp(_cycle == 'yearly' ? pkg.pricePerUserYearly : pkg.pricePerUser)}/user',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Text('2. Siklus & Jumlah User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'monthly', label: Text('Bulanan')),
                                    ButtonSegment(value: 'yearly', label: Text('Tahunan')),
                                  ],
                                  selected: {_cycle},
                                  onSelectionChanged: (s) {
                                    setState(() => _cycle = s.first);
                                    _refreshQuote();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _users > 1
                                          ? () {
                                              setState(() => _users--);
                                              _refreshQuote();
                                            }
                                          : null,
                                      icon: const Icon(Icons.remove_rounded, size: 18),
                                    ),
                                    Text('$_users user', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setState(() => _users++);
                                        _refreshQuote();
                                      },
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text('3. Metode Pembayaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          for (final grp in methodsByGroup.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 4),
                              child: Text(grp.key, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                            ),
                            for (final pm in grp.value)
                              Builder(
                                builder: (_) {
                                  final feeOpt = _quote?.fees.where((f) => f.code == pm.code).firstOrNull;
                                  final selected = _selectedMethod == pm.code;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(11),
                                      onTap: () => setState(() => _selectedMethod = pm.code),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                                          borderRadius: BorderRadius.circular(11),
                                          border: Border.all(
                                            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                              size: 18,
                                              color: selected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Text(pm.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                            ),
                                            if (feeOpt != null)
                                              Text(
                                                'Fee ${rp(feeOpt.fee)}',
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                          if (_quote != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  _qRow('Harga Paket (${_quote!.users} user)', rp(_quote!.gross)),
                                  if (_quote!.discount > 0)
                                    _qRow('Diskon ${_quote!.promoName}', '- ${rp(_quote!.discount)}'),
                                  _qRow('PPN (${_quote!.ppnRate}%)', rp(_quote!.ppn)),
                                  if (selectedFee != null) _qRow('Biaya Layanan', rp(selectedFee.fee)),
                                  const Divider(height: 14),
                                  Row(
                                    children: [
                                      const Text('Total Bayar', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                                      const Spacer(),
                                      if (_quoteLoading)
                                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      else
                                        Text(rp(grandTotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_loading || _submitting || _selectedPkgId == null) ? null : _submitCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        grandTotal > 0 ? 'Bayar via DOKU · ${rp(grandTotal)}' : 'Lanjutkan ke DOKU Checkout',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
