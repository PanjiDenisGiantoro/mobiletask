import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../data/admin_api_repository.dart';
import '../data/ph_store.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_widgets.dart';

class _DraftInvoiceItem {
  String description;
  int quantity;
  int unitPrice;
  _DraftInvoiceItem({this.description = '', this.quantity = 1, this.unitPrice = 0});
  int get total => quantity * unitPrice;
}

/// Halaman "Invoice & Penagihan" — terhubung ke API `/invoices`.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _api = AdminApiRepository.instance;
  String _statusFilter = ''; // '' | draft | sent | paid | overdue
  String _search = '';
  int _pageSize = 15;
  int _page = 1;

  List<ApiInvoice> _items = [];
  ApiInvoiceStats _stats = const ApiInvoiceStats();
  bool _canCreate = false;
  bool _canUpdate = false;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;
  int? _busyInvoiceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchInvoices(
        status: _statusFilter,
        search: _search,
        page: targetPage,
        perPage: _pageSize,
      );
      if (mounted) {
        setState(() {
          _items = res.data;
          _stats = res.stats;
          _canCreate = res.canCreate;
          _canUpdate = res.canUpdate;
          _page = res.currentPage;
          _lastPage = res.lastPage;
          _total = res.total;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateInvoice() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _CreateInvoiceScreen()),
    );
    if (created == true && mounted) {
      await _load(page: 1);
      if (mounted) phToast(context, 'Invoice berhasil diterbitkan');
    }
  }

  Future<void> _downloadInvoicePdf(ApiInvoice inv) async {
    setState(() => _busyInvoiceId = inv.id);
    try {
      final bytes = await _api.downloadInvoicePdf(inv.id);
      await Printing.sharePdf(bytes: bytes, filename: '${inv.invoiceNumber}.pdf');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busyInvoiceId = null);
    }
  }

  Future<void> _showDetail(ApiInvoice summary) async {
    ApiInvoice inv = summary;
    try {
      inv = await _api.fetchInvoiceDetail(summary.id);
    } catch (_) {}
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv.invoiceNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('${inv.clientName} · ${inv.projectName.isEmpty ? 'Internal' : inv.projectName}', style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                    ],
                  ),
                ),
                _statusBadge(inv.status),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            if (inv.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Rincian item tersedia di dokumen PDF.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500)),
              )
            else
              for (final it in inv.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('${it.description} (${it.quantity}x)', style: const TextStyle(fontSize: 12.5))),
                      Text(rp(it.total), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            const Divider(height: 18, color: AppColors.border),
            Row(
              children: [
                Text('Subtotal: ${rp(inv.subtotal)} · PPN ${inv.tax.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                const Spacer(),
                Text(rp(inv.total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary600)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_canUpdate && inv.status == 'draft')
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await _api.sendInvoice(inv.id);
                        await _load();
                        if (mounted) phToast(context, 'Invoice ${inv.invoiceNumber} dikirim ke klien');
                      } catch (e) {
                        if (mounted) phToast(context, '$e');
                      }
                    },
                    child: const Text('Kirim ke Klien'),
                  ),
                if (_canUpdate && inv.status != 'paid' && inv.status != 'cancelled')
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await _api.markInvoicePaid(inv.id);
                        await _load();
                        if (mounted) phToast(context, 'Invoice ${inv.invoiceNumber} ditandai Lunas');
                      } catch (e) {
                        if (mounted) phToast(context, '$e');
                      }
                    },
                    child: const Text('Tandai Lunas'),
                  ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _downloadInvoicePdf(inv);
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary600),
                  icon: const Icon(Icons.download_rounded, size: 17),
                  label: const Text('Unduh PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paidRatio = _stats.totalAmount == 0 ? 0 : ((_stats.paidAmount / _stats.totalAmount) * 100).round();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Invoice & Penagihan', actions: [
        IconButton(tooltip: 'Muat ulang', onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          return RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(isWide ? 22 : 14, 16, isWide ? 22 : 14, 100),
              children: [
                _buildHeader(isWide),
                const SizedBox(height: 14),
                _buildStatsGrid(isWide, paidRatio),
                const SizedBox(height: 14),
                _buildFilterBar(isWide),
                const SizedBox(height: 14),
                _buildTableCard(isWide),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    final textCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFDBEAFE))),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 3, backgroundColor: AppColors.primary600),
              SizedBox(width: 6),
              Text('Financial & Client Billing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary700)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Invoice & Penagihan', style: TextStyle(fontSize: isWide ? 23 : 20, fontWeight: FontWeight.w800, color: AppColors.grey900)),
        const SizedBox(height: 4),
        const Text('Pantau arus kas, status invoice klien, dan pembayaran termin proyek secara transparan.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500)),
      ],
    );

    final btn = _canCreate
        ? FilledButton.icon(
            onPressed: _openCreateInvoice,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary600, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Buat Invoice Baru', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          )
        : const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF0F7FF)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: isWide
          ? Row(children: [Expanded(child: textCol), if (_canCreate) ...[const SizedBox(width: 14), btn]])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [textCol, if (_canCreate) ...[const SizedBox(height: 12), SizedBox(width: double.infinity, child: btn)]]),
    );
  }

  Widget _buildStatsGrid(bool isWide, int paidRatio) {
    final cards = [
      _statCard('TOTAL DITAGIHKAN', rp(_stats.totalAmount), AppColors.grey900, 'Total tagihan diterbitkan', '${_stats.totalCount} Invoice', AppColors.grey900, Icons.receipt_long_outlined, AppColors.primary50, AppColors.primary600),
      _statCard('SUDAH LUNAS', rp(_stats.paidAmount), AppColors.success, '${_stats.paidCount} invoice lunas', '$paidRatio% rasio', AppColors.grey500, Icons.check_circle_outline_rounded, AppColors.successBg, AppColors.success),
      _statCard('MENUNGGU PEMBAYARAN', rp(_stats.pendingAmount), AppColors.grey900, 'Tagihan berjalan', '${_stats.pendingCount} pending', const Color(0xFFD97706), Icons.access_time_rounded, AppColors.warningBg, const Color(0xFFD97706)),
      _statCard('JATUH TEMPO (OVERDUE)', rp(_stats.overdueAmount), AppColors.error, 'Status penagihan', '${_stats.overdueCount} invoice telat', AppColors.error, Icons.warning_amber_rounded, AppColors.errorBg, AppColors.error),
    ];

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]),
      ],
    );
  }

  Widget _statCard(String title, String value, Color valColor, String left, String right, Color rightColor, IconData icon, Color iconBg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.grey500))),
              Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 15, color: iconColor)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: valColor))),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.grey100),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: Text(left, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.grey400))),
              Text(right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: rightColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isWide) {
    const chips = [('', 'Semua'), ('draft', 'Draft'), ('sent', 'Terkirim'), ('paid', 'Lunas'), ('overdue', 'Jatuh Tempo')];
    final statusPills = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (k, lbl) in chips)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(lbl),
                selected: _statusFilter == k,
                onSelected: (_) {
                  setState(() => _statusFilter = k);
                  _load(page: 1);
                },
                selectedColor: AppColors.primary600,
                backgroundColor: AppColors.bg,
                labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusFilter == k ? Colors.white : AppColors.grey700),
              ),
            ),
        ],
      ),
    );

    final searchField = Container(
      height: 38,
      width: isWide ? 240 : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: AppColors.grey400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) {
                _search = v;
                _load(page: 1);
              },
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(hintText: 'Cari no. invoice, klien, proyek...', hintStyle: TextStyle(fontSize: 12, color: AppColors.grey400), border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: isWide
          ? Row(children: [Expanded(child: statusPills), const SizedBox(width: 12), searchField])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [statusPills, const SizedBox(height: 10), searchField]),
    );
  }

  Widget _buildTableCard(bool isWide) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          if (isWide)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: AppColors.border))),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('NO. INVOICE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500))),
                  Expanded(flex: 3, child: Text('KLIEN / PEMBAYAR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500))),
                  Expanded(flex: 3, child: Text('PROYEK TERKAIT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500))),
                  Expanded(flex: 2, child: Text('TOTAL TAGIHAN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500))),
                  Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500))),
                  Expanded(flex: 2, child: Text('JATUH TEMPO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500))),
                  SizedBox(width: 90, child: Text('AKSI', textAlign: TextAlign.end, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500))),
                ],
              ),
            ),
          if (_loading && _items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _items.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error))))
          else if (_items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Belum ada data invoice.', style: TextStyle(fontSize: 13, color: AppColors.grey400))))
          else
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0 || !isWide) const Divider(height: 1, color: AppColors.grey100),
              isWide ? _buildWideRow(_items[i]) : _buildMobileRow(_items[i]),
            ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)), border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Text('Total $_total invoice · Halaman $_page/$_lastPage', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                const Spacer(),
                if (_lastPage > 1) ...[
                  IconButton(visualDensity: VisualDensity.compact, onPressed: _page > 1 ? () => _load(page: _page - 1) : null, icon: const Icon(Icons.chevron_left_rounded, size: 19)),
                  IconButton(visualDensity: VisualDensity.compact, onPressed: _page < _lastPage ? () => _load(page: _page + 1) : null, icon: const Icon(Icons.chevron_right_rounded, size: 19)),
                ],
                PopupMenuButton<int>(
                  onSelected: (s) {
                    setState(() => _pageSize = s);
                    _load(page: 1);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 10, child: Text('Show 10')),
                    PopupMenuItem(value: 15, child: Text('Show 15')),
                    PopupMenuItem(value: 25, child: Text('Show 25')),
                    PopupMenuItem(value: 50, child: Text('Show 50')),
                  ],
                  child: Text('Show $_pageSize ▾', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.grey700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideRow(ApiInvoice inv) {
    final busy = _busyInvoiceId == inv.id;
    return InkWell(
      onTap: () => _showDetail(inv),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(inv.invoiceNumber, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.grey900))),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(radius: 15, backgroundColor: AppColors.primary600, child: Text(initials(inv.clientName), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(inv.clientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(999)),
                  child: Text(inv.projectName.isEmpty ? 'Internal' : inv.projectName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.grey700)),
                ),
              ),
            ),
            Expanded(flex: 2, child: Text(rp(inv.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.grey900))),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _statusBadge(inv.status))),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmtDate(inv.dueDate), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: inv.isOverdue ? AppColors.error : AppColors.grey900)),
                  if (inv.isOverdue) const Text('Lewat deadline', style: TextStyle(fontSize: 10, color: AppColors.error)),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => _showDetail(inv), child: const Text('Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(visualDensity: VisualDensity.compact, onPressed: () => _downloadInvoicePdf(inv), icon: const Icon(Icons.download_outlined, size: 17, color: AppColors.grey500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(ApiInvoice inv) {
    return InkWell(
      onTap: () => _showDetail(inv),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(inv.invoiceNumber, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                const Spacer(),
                _statusBadge(inv.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('${inv.clientName} · ${inv.projectName.isEmpty ? 'Internal' : inv.projectName}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.grey700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(rp(inv.total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary600)),
                const Spacer(),
                Text('Jatuh tempo: ${fmtDate(inv.dueDate)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: inv.isOverdue ? AppColors.error : AppColors.grey500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (label, fg, bg) = switch (status) {
      'paid' => ('Lunas', AppColors.success, AppColors.successBg),
      'sent' => ('Terkirim', AppColors.primary600, AppColors.primary50),
      'overdue' => ('Jatuh Tempo', AppColors.error, AppColors.errorBg),
      'cancelled' => ('Dibatalkan', AppColors.grey700, AppColors.grey100),
      _ => ('Draft', const Color(0xFFB45309), AppColors.warningBg),
    };
    return PhPill(label, fg: fg, bg: bg);
  }
}

/// Form "Buat Invoice Baru" -> `POST /invoices`.
class _CreateInvoiceScreen extends StatefulWidget {
  const _CreateInvoiceScreen();

  @override
  State<_CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<_CreateInvoiceScreen> {
  final _api = AdminApiRepository.instance;
  int? _projectId;
  int? _clientId;
  String _issueDate = isoDate(DateTime.now());
  String _dueDate = isoDate(DateTime.now().add(const Duration(days: 14)));
  int _taxPercent = 11;
  final List<_DraftInvoiceItem> _items = [_DraftInvoiceItem(quantity: 1, unitPrice: 0)];
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  PhStore get _store => PhStore.instance;

  @override
  void initState() {
    super.initState();
    _projectId = _store.projects.firstOrNull?.id;
    final firstClient = _store.clients.firstOrNull;
    _clientId = firstClient != null ? int.tryParse(firstClient.id) : null;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _subtotal => _items.fold<int>(0, (s, e) => s + e.total);
  int get _taxAmount => ((_subtotal * _taxPercent) / 100).round();
  int get _grandTotal => _subtotal + _taxAmount;

  Future<void> _pickDate(bool isIssue) async {
    final base = DateTime.tryParse(isIssue ? _issueDate : _dueDate) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: base, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (picked == null) return;
    setState(() {
      if (isIssue) {
        _issueDate = isoDate(picked);
      } else {
        _dueDate = isoDate(picked);
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_clientId == null) {
      phToast(context, 'Pilih klien penerima tagihan terlebih dahulu');
      return;
    }
    final validItems = _items.where((e) => e.description.trim().isNotEmpty).toList();
    if (validItems.isEmpty) {
      phToast(context, 'Isi minimal 1 deskripsi item tagihan');
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.createInvoice({
        if (_projectId != null) 'project_id': _projectId,
        'client_id': _clientId,
        'issue_date': _issueDate,
        'due_date': _dueDate,
        'tax': _taxPercent,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'items': [
          for (final it in validItems)
            {'description': it.description.trim(), 'quantity': it.quantity, 'unit_price': it.unitPrice},
        ],
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Buat Invoice Baru'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      PhCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('1. Informasi Penerima & Entitas', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            const Text('Pilih Proyek', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int?>(
                              initialValue: _projectId,
                              isExpanded: true,
                              decoration: _inputDeco(),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('— Tanpa Proyek —')),
                                for (final p in _store.projects)
                                  DropdownMenuItem<int?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) => setState(() => _projectId = v),
                            ),
                            const SizedBox(height: 12),
                            const Text('Klien / Penerima Tagihan *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int?>(
                              initialValue: _clientId,
                              isExpanded: true,
                              decoration: _inputDeco(),
                              hint: const Text('— Pilih Klien —'),
                              items: [
                                for (final c in _store.clients)
                                  if (int.tryParse(c.id) != null)
                                    DropdownMenuItem<int?>(value: int.parse(c.id), child: Text(c.name, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) => setState(() => _clientId = v),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _dateInput('Tanggal Terbit *', _issueDate, () => _pickDate(true))),
                                const SizedBox(width: 10),
                                Expanded(child: _dateInput('Jatuh Tempo *', _dueDate, () => _pickDate(false))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('Pajak PPN / Tax (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: '$_taxPercent',
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco(suffixText: '%'),
                              onChanged: (v) => setState(() => _taxPercent = int.tryParse(v) ?? 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      PhCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(child: Text('2. Rincian Item Tagihan', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() => _items.add(_DraftInvoiceItem())),
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Tambah Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (var i = 0; i < _items.length; i++)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('Item #${i + 1}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.grey500)),
                                        const Spacer(),
                                        if (_items.length > 1)
                                          InkWell(
                                            onTap: () => setState(() => _items.removeAt(i)),
                                            child: const Text('Hapus', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.error)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      initialValue: _items[i].description,
                                      decoration: _inputDeco(hint: 'Deskripsi pekerjaan / layanan...'),
                                      onChanged: (v) => _items[i].description = v,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            initialValue: '${_items[i].quantity}',
                                            keyboardType: TextInputType.number,
                                            decoration: _inputDeco(hint: 'Qty'),
                                            onChanged: (v) => setState(() => _items[i].quantity = (int.tryParse(v) ?? 1).clamp(1, 9999)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: '${_items[i].unitPrice}',
                                            keyboardType: TextInputType.number,
                                            decoration: _inputDeco(hint: 'Harga Satuan (Rp)'),
                                            onChanged: (v) => setState(() => _items[i].unitPrice = int.tryParse(v) ?? 0),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(rp(_items[i].total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const Divider(height: 18, color: AppColors.border),
                            _summaryRow('Subtotal', rp(_subtotal)),
                            _summaryRow('Pajak PPN ($_taxPercent%)', rp(_taxAmount)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Spacer(),
                                const Text('GRAND TOTAL   ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                Text(rp(_grandTotal), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      PhCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('3. Catatan Pembayaran', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _notesCtrl,
                              minLines: 3,
                              maxLines: 5,
                              decoration: _inputDeco(hint: 'Instruksi transfer rekening atau catatan tambahan (opsional)...'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Batal', style: TextStyle(color: AppColors.grey700, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary600, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Terbitkan Invoice', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _dateInput(String label, String value, VoidCallback onTap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Expanded(child: Text(fmtDate(value), style: const TextStyle(fontSize: 13))),
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.grey500),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _summaryRow(String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Spacer(),
            Text('$label   ', style: const TextStyle(fontSize: 12.5, color: AppColors.grey500)),
            SizedBox(width: 110, child: Text(val, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
          ],
        ),
      );

  InputDecoration _inputDeco({String? hint, String? suffixText}) => InputDecoration(
        filled: true,
        fillColor: AppColors.bg,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.grey400),
        suffixText: suffixText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.primary600, width: 1.5)),
      );
}

/// Halaman "Activity Log" — terhubung ke API `/activity-logs`.
class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final _api = AdminApiRepository.instance;
  String _logName = '';
  String _search = '';
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  List<ApiActivityLog> _logs = [];
  List<(String, String)> _logNames = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchActivityLogs(logName: _logName, search: _search, page: targetPage);
      if (mounted) {
        setState(() {
          _logs = res.data;
          _page = res.currentPage;
          _lastPage = res.lastPage;
          _total = res.total;
          if (res.logNames.isNotEmpty) _logNames = res.logNames;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Activity Log', actions: [
        IconButton(tooltip: 'Muat ulang', onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            TextField(
              onChanged: (v) {
                _search = v;
                _load(page: 1);
              },
              decoration: InputDecoration(
                hintText: 'Cari deskripsi aktivitas...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.grey400),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Semua'),
                      selected: _logName.isEmpty,
                      onSelected: (_) {
                        setState(() => _logName = '');
                        _load(page: 1);
                      },
                      selectedColor: AppColors.primary600,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _logName.isEmpty ? Colors.white : AppColors.grey700),
                    ),
                  ),
                  for (final (val, lbl) in _logNames)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(lbl),
                        selected: _logName == val,
                        onSelected: (_) {
                          setState(() => _logName = val);
                          _load(page: 1);
                        },
                        selectedColor: AppColors.primary600,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _logName == val ? Colors.white : AppColors.grey700),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading && _logs.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _logs.isEmpty)
              PhCard(child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)))
            else if (_logs.isEmpty)
              const PhCard(child: Center(child: Text('Belum ada catatan aktivitas.', style: TextStyle(color: AppColors.grey400))))
            else ...[
              PhCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _logs.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.grey100),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: AppColors.primary50,
                              child: Text(initials(_logs[i].causerName), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary700)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_logs[i].causerName} · ${_logs[i].description}${_logs[i].subjectName.isNotEmpty ? ' "${_logs[i].subjectName}"' : ''}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.grey900),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      PhPill(_logs[i].logLabel, fg: AppColors.primary700, bg: AppColors.primary50),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_logs[i].subjectType} #${_logs[i].subjectId} · ${fmtDateTime(_logs[i].createdAt)}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.grey500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_lastPage > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(onPressed: _page > 1 ? () => _load(page: _page - 1) : null, icon: const Icon(Icons.chevron_left_rounded)),
                    Text('Halaman $_page / $_lastPage ($_total log)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    IconButton(onPressed: _page < _lastPage ? () => _load(page: _page + 1) : null, icon: const Icon(Icons.chevron_right_rounded)),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
