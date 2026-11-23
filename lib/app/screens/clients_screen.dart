import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

/// Halaman "Manajemen Klien" — diakses dari Admin & Pengaturan -> Members -> Clients.
/// Menyesuaikan desain web ProjectHub Pro (header External Stakeholders & Clients,
/// 3 kartu ringkasan, pencarian & filter status, daftar klien dengan proyek terkait,
/// status aktif/nonaktif, tanggal bergabung, Edit/Hapus, dan pagination Show 10).
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _search = '';
  String _statusFilter = 'all'; // all | active | inactive
  int _pageSize = 10;
  int _page = 1;

  PhStore get _store => PhStore.instance;

  List<PhUser> get _allClients {
    final list = _store.clients.toList();
    list.sort((a, b) => (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0));
    return list;
  }

  List<PhUser> get _filtered {
    return _allClients.where((c) {
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        final hit = c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.id.toLowerCase().contains(q);
        if (!hit) return false;
      }
      if (_statusFilter == 'active' && !c.isActive) return false;
      if (_statusFilter == 'inactive' && c.isActive) return false;
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);
    if (!_store.synced) _store.sync();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _openClientForm([PhUser? existing]) async {
    await openPhForm(
      context,
      PhFormConfig(
        title: existing == null ? 'Tambah Klien' : 'Edit Klien',
        saveLabel: existing == null ? 'Simpan Klien' : 'Perbarui Klien',
        doneMessage: existing == null ? 'Klien berhasil ditambahkan' : 'Data klien diperbarui',
        fields: [
          PhField('name', 'Nama Perusahaan / Kontak Klien', required: true, initial: existing?.name ?? ''),
          PhField('email', 'Email Klien', required: true, initial: existing?.email ?? ''),
          if (existing == null)
            const PhField('password', 'Password Portal (Opsional)', hint: 'Minimal 6 karakter bila membuat akun login'),
          PhField(
            'status',
            'Status Akun',
            type: PhFieldType.select,
            initial: (existing?.isActive ?? true) ? 'active' : 'inactive',
            options: const [
              ('active', 'Aktif'),
              ('inactive', 'Nonaktif'),
            ],
          ),
        ],
        onSave: (values) async {
          await _store.saveClientUser(existing, values);
          return null;
        },
      ),
    );
  }

  Future<void> _confirmDelete(PhUser client) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Klien'),
        content: Text('Yakin ingin menghapus akun klien "${client.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _store.deleteClientUser(client);
      if (mounted) phToast(context, 'Klien dihapus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = _allClients;
    final activeCount = clients.where((c) => c.isActive).length;
    final inactiveCount = clients.length - activeCount;
    final activeRatio = clients.isEmpty ? 0 : ((activeCount / clients.length) * 100).round();
    final filtered = _filtered;

    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _page.clamp(1, totalPages);
    final startIdx = (currentPage - 1) * _pageSize;
    final endIdx = (startIdx + _pageSize).clamp(0, filtered.length);
    final pageItems = filtered.isEmpty ? const <PhUser>[] : filtered.sublist(startIdx, endIdx);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.heroStart,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroStart, AppColors.heroMid],
            ),
          ),
        ),
        title: const Text('Manajemen Klien'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _store.sync,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 780;
          return RefreshIndicator(
            onRefresh: _store.sync,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(isWide ? 22 : 14, 16, isWide ? 22 : 14, 100),
              children: [
                _buildHeroHeader(isWide),
                const SizedBox(height: 14),
                _buildStatsRow(
                  isWide: isWide,
                  total: clients.length,
                  active: activeCount,
                  inactive: inactiveCount,
                  activeRatio: activeRatio,
                ),
                const SizedBox(height: 14),
                _buildFilterBar(isWide),
                const SizedBox(height: 14),
                _buildClientsTableCard(
                  isWide: isWide,
                  items: pageItems,
                  totalFiltered: filtered.length,
                  startIdx: startIdx,
                  endIdx: endIdx,
                  currentPage: currentPage,
                  totalPages: totalPages,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroHeader(bool isWide) {
    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 3, backgroundColor: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                'External Stakeholders & Clients',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manajemen Klien',
          style: TextStyle(
            fontSize: isWide ? 23 : 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kelola akun perwakilan klien, akses portal proyek, dan status kerjasama perusahaan.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
      ],
    );

    final addBtn = FilledButton.icon(
      onPressed: () => _openClientForm(),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: const Text('Tambah Klien', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF0F7FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: headerText),
                const SizedBox(width: 16),
                addBtn,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerText,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: addBtn),
              ],
            ),
    );
  }

  Widget _buildStatsRow({
    required bool isWide,
    required int total,
    required int active,
    required int inactive,
    required int activeRatio,
  }) {
    final cards = [
      _statCard(
        title: 'TOTAL KLIEN',
        value: '$total',
        valueColor: const Color(0xFF0F172A),
        subtitle: 'perusahaan terdaftar',
        footerLeft: 'Database mitra',
        footerRight: 'Aktif & Terhubung',
        footerRightColor: const Color(0xFF0F172A),
        icon: Icons.badge_outlined,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      ),
      _statCard(
        title: 'KLIEN AKTIF',
        value: '$active',
        valueColor: const Color(0xFF16A34A),
        subtitle: 'dapat login ke portal',
        footerLeft: 'Rasio keaktifan',
        footerRight: '$activeRatio% aktif',
        footerRightColor: const Color(0xFF16A34A),
        icon: Icons.check_circle_outline_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF16A34A),
      ),
      _statCard(
        title: 'KLIEN NONAKTIF',
        value: '$inactive',
        valueColor: const Color(0xFF0F172A),
        subtitle: 'akses ditangguhkan',
        footerLeft: 'Status akun',
        footerRight: 'Nonaktif',
        footerRightColor: const Color(0xFF475569),
        icon: Icons.block_rounded,
        iconBg: const Color(0xFFF1F5F9),
        iconColor: const Color(0xFF64748B),
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 10),
        cards[2],
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required Color valueColor,
    required String subtitle,
    required String footerLeft,
    required String footerRight,
    required Color footerRightColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
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
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: valueColor),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  footerLeft,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),
              Text(
                footerRight,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: footerRightColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isWide) {
    final searchBox = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 17, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() {
                _search = v;
                _page = 1;
              }),
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                hintText: 'Cari nama / email klien...',
                hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );

    final statusDropdown = PopupMenuButton<String>(
      onSelected: (v) => setState(() {
        _statusFilter = v;
        _page = 1;
      }),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'all', child: Text('Semua Status', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'active', child: Text('Aktif', style: TextStyle(fontSize: 12.5))),
        PopupMenuItem(value: 'inactive', child: Text('Nonaktif', style: TextStyle(fontSize: 12.5))),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusFilter == 'all'
                  ? 'Semua Status'
                  : (_statusFilter == 'active' ? 'Aktif' : 'Nonaktif'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isWide
          ? Row(
              children: [
                SizedBox(width: 260, child: searchBox),
                const SizedBox(width: 10),
                statusDropdown,
              ],
            )
          : Row(
              children: [
                Expanded(child: searchBox),
                const SizedBox(width: 8),
                statusDropdown,
              ],
            ),
    );
  }

  Widget _buildClientsTableCard({
    required bool isWide,
    required List<PhUser> items,
    required int totalFiltered,
    required int startIdx,
    required int endIdx,
    required int currentPage,
    required int totalPages,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          if (isWide)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('PERUSAHAAN & KONTAK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 3, child: Text('EMAIL KLIEN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 4, child: Text('PROYEK TERKAIT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('STATUS AKUN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('BERGABUNG', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  SizedBox(width: 96, child: Text('AKSI', textAlign: TextAlign.end, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                ],
              ),
            ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Center(
                child: Text(
                  'Belum ada data klien yang sesuai.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0 || !isWide) const Divider(height: 1, color: Color(0xFFF1F5F9)),
              isWide ? _buildWideRow(items[i]) : _buildMobileRow(items[i]),
            ],
          _buildPaginationFooter(
            totalItems: totalFiltered,
            startIdx: startIdx,
            endIdx: endIdx,
            currentPage: currentPage,
            totalPages: totalPages,
          ),
        ],
      ),
    );
  }

  Widget _buildWideRow(PhUser c) {
    final relatedProjects = _store.projects.where((p) => p.clientId == c.id).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                PhAvatar(c.id, size: 36, imageUrl: c.photoUrl, images: c.images),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'ID: #${c.id}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              c.email.isEmpty ? '-' : c.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
          ),
          Expanded(
            flex: 4,
            child: relatedProjects.isEmpty
                ? const Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in relatedProjects) _projectChip(p),
                    ],
                  ),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: _statusBadge(c.isActive)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              c.joinedAt.isEmpty ? '-' : fmtDate(c.joinedAt),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _openClientForm(c),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text('Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _confirmDelete(c),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text('Hapus', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(PhUser c) {
    final relatedProjects = _store.projects.where((p) => p.clientId == c.id).toList();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhAvatar(c.id, size: 38, imageUrl: c.photoUrl, images: c.images),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'ID: #${c.id}${c.email.isNotEmpty ? ' · ${c.email}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _statusBadge(c.isActive),
            ],
          ),
          if (relatedProjects.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in relatedProjects) _projectChip(p),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 5),
              Text(
                'Bergabung: ${c.joinedAt.isEmpty ? '-' : fmtDate(c.joinedAt)}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openClientForm(c),
                child: const Text('Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
              ),
              TextButton(
                onPressed: () => _confirmDelete(c),
                child: const Text('Hapus', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projectChip(Project p) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => context.push('/project/${p.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: Text(
          p.name,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
        ),
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Aktif' : 'Nonaktif',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF15803D) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter({
    required int totalItems,
    required int startIdx,
    required int endIdx,
    required int currentPage,
    required int totalPages,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Text('Show ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          PopupMenuButton<int>(
            onSelected: (size) => setState(() {
              _pageSize = size;
              _page = 1;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
              PopupMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12))),
              PopupMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12))),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_pageSize', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Showing ${totalItems == 0 ? 0 : startIdx + 1} to $endIdx of $totalItems results',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),
          if (totalPages > 1) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: currentPage > 1 ? () => setState(() => _page = currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 19),
            ),
            Text('$currentPage / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: currentPage < totalPages ? () => setState(() => _page = currentPage + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 19),
            ),
          ],
        ],
      ),
    );
  }
}
