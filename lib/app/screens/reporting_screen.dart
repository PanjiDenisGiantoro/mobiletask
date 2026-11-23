import 'package:flutter/material.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../data/task_repository.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_widgets.dart';

enum _ReportModuleId {
  projects,
  tasks,
  tickets,
  requests,
  campaigns,
  invoices,
  budgets,
}

class _ReportModuleMeta {
  final _ReportModuleId id;
  final String group;
  final String title;
  final String subtitle;

  const _ReportModuleMeta({
    required this.id,
    required this.group,
    required this.title,
    required this.subtitle,
  });
}

/// Halaman "Laporan & Ekspor Data" (Reporting) — diakses dari
/// Admin & Pengaturan -> Reporting -> Reporting.
/// Menampilkan Katalog Laporan (7 modul), filter Status & rentang tanggal,
/// pencarian hasil, tabel/daftar data dinamis, serta tombol Unduh PDF & Excel.
class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key});

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  static const _modules = <_ReportModuleMeta>[
    _ReportModuleMeta(
      id: _ReportModuleId.projects,
      group: 'PROYEK & TUGAS',
      title: 'Proyek',
      subtitle: 'Daftar proyek, klien, manager, dan status.',
    ),
    _ReportModuleMeta(
      id: _ReportModuleId.tasks,
      group: 'PROYEK & TUGAS',
      title: 'Tugas Proyek',
      subtitle: 'Daftar tugas lintas proyek, assignee, prioritas, dan tenggat.',
    ),
    _ReportModuleMeta(
      id: _ReportModuleId.tickets,
      group: 'TIKET & DUKUNGAN',
      title: 'Tiket & SLA',
      subtitle: 'Laporan kendala teknis, tingkat prioritas, dan kepatuhan SLA.',
    ),
    _ReportModuleMeta(
      id: _ReportModuleId.requests,
      group: 'TIKET & DUKUNGAN',
      title: 'Customer Requests',
      subtitle: 'Permintaan fitur, revisi, dan persetujuan dari klien.',
    ),
    _ReportModuleMeta(
      id: _ReportModuleId.campaigns,
      group: 'MARKETING',
      title: 'Campaigns',
      subtitle: 'Ringkasan aktivitas kampanye dan deliverables marketing.',
    ),
    _ReportModuleMeta(
      id: _ReportModuleId.invoices,
      group: 'KEUANGAN',
      title: 'Invoice',
      subtitle: 'Daftar tagihan proyek, nilai nominal, dan status pembayaran.',
    ),
    _ReportModuleMeta(
      id: _ReportModuleId.budgets,
      group: 'KEUANGAN',
      title: 'Anggaran Proyek',
      subtitle: 'Realisasi anggaran, pemasukan, dan pengeluaran per proyek.',
    ),
  ];

  _ReportModuleId _activeId = _ReportModuleId.projects;
  bool _showFilter = true;

  String _draftStatus = 'all';
  DateTime? _draftFrom;
  DateTime? _draftTo;

  String _appliedStatus = 'all';
  DateTime? _appliedFrom;
  DateTime? _appliedTo;

  String _search = '';

  PhStore get _store => PhStore.instance;

  _ReportModuleMeta get _activeMeta =>
      _modules.firstWhere((m) => m.id == _activeId, orElse: () => _modules.first);

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);
    TaskRepository.instance.addListener(_onChanged);
    if (!_store.synced) _store.sync();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    TaskRepository.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _selectModule(_ReportModuleId id) {
    setState(() {
      _activeId = id;
      _draftStatus = 'all';
      _appliedStatus = 'all';
      _draftFrom = null;
      _draftTo = null;
      _appliedFrom = null;
      _appliedTo = null;
      _search = '';
    });
  }

  void _applyFilter() {
    setState(() {
      _appliedStatus = _draftStatus;
      _appliedFrom = _draftFrom;
      _appliedTo = _draftTo;
    });
  }

  void _resetFilter() {
    setState(() {
      _draftStatus = 'all';
      _draftFrom = null;
      _draftTo = null;
      _appliedStatus = 'all';
      _appliedFrom = null;
      _appliedTo = null;
      _search = '';
    });
  }

  bool _inAppliedDateRange(String iso) {
    if (_appliedFrom == null && _appliedTo == null) return true;
    final d = DateTime.tryParse(iso);
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (_appliedFrom != null && day.isBefore(_appliedFrom!)) return false;
    if (_appliedTo != null && day.isAfter(_appliedTo!)) return false;
    return true;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _draftFrom : _draftTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      final dOnly = DateTime(picked.year, picked.month, picked.day);
      if (isFrom) {
        _draftFrom = dOnly;
      } else {
        _draftTo = dOnly;
      }
    });
  }

  List<(String, String)> _statusOptionsFor(_ReportModuleId id) {
    switch (id) {
      case _ReportModuleId.projects:
        return const [
          ('all', 'Semua'),
          ('active', 'Active'),
          ('draft', 'Draft'),
          ('on_hold', 'On Hold'),
          ('completed', 'Completed'),
          ('cancelled', 'Cancelled'),
        ];
      case _ReportModuleId.tasks:
        return const [
          ('all', 'Semua'),
          ('todo', 'Todo'),
          ('in_progress', 'In Progress'),
          ('review', 'Review'),
          ('done', 'Completed'),
        ];
      case _ReportModuleId.tickets:
        return const [
          ('all', 'Semua'),
          ('open', 'Open'),
          ('assigned', 'Assigned'),
          ('in_progress', 'In Progress'),
          ('pending_review', 'Pending Review'),
          ('resolved', 'Resolved'),
          ('closed', 'Closed'),
        ];
      case _ReportModuleId.requests:
        return const [
          ('all', 'Semua'),
          ('waiting_approval', 'Menunggu Persetujuan'),
          ('approved', 'Disetujui'),
          ('in_progress', 'Dikerjakan'),
          ('completed', 'Selesai'),
          ('rejected', 'Ditolak'),
        ];
      default:
        return const [('all', 'Semua')];
    }
  }

  /// Bangun baris tabel generik: `(headers, rows)` agar 7 modul tampil rapi & seragam.
  (List<String>, List<List<String>>) _buildTableData() {
    final q = _search.trim().toLowerCase();

    switch (_activeId) {
      case _ReportModuleId.projects:
        final list = _store.projects.where((p) {
          if (_appliedStatus != 'all' && p.status != _appliedStatus) return false;
          if (!_inAppliedDateRange(p.startDate)) return false;
          if (q.isNotEmpty) {
            final clientName = p.clientId.isEmpty ? '' : _store.nameOf(p.clientId);
            final leadName = p.managerId.isEmpty ? '' : _store.nameOf(p.managerId);
            final hit = p.name.toLowerCase().contains(q) ||
                clientName.toLowerCase().contains(q) ||
                leadName.toLowerCase().contains(q) ||
                '${p.id}'.contains(q);
            if (!hit) return false;
          }
          return true;
        }).toList()
          ..sort((a, b) => b.id.compareTo(a.id));

        return (
          ['ID', 'NAMA PROYEK', 'KLIEN', 'LEAD PROJECT', 'STATUS', 'PROGRESS', 'ANGGARAN', 'MULAI', 'SELESAI'],
          [
            for (final p in list)
              [
                '${p.id}',
                p.name,
                p.clientId.isEmpty ? '-' : _store.nameOf(p.clientId),
                p.managerId.isEmpty ? '-' : _store.nameOf(p.managerId),
                statusLabel('project', p.status),
                '${p.totalTasks > 0 ? (p.doneTasks / p.totalTasks * 100).round() : p.progress}%',
                p.budget <= 0 ? '-' : rp(p.budget),
                p.startDate.isEmpty ? '-' : _slashDate(p.startDate),
                p.endDate.isEmpty ? '-' : _slashDate(p.endDate),
              ],
          ],
        );

      case _ReportModuleId.tasks:
        final list = TaskRepository.instance.tasks.where((t) {
          if (_appliedStatus != 'all' && t.status != _appliedStatus) return false;
          if (!_inAppliedDateRange(t.dueDate)) return false;
          if (q.isNotEmpty) {
            final assignee = t.assignedTo.isEmpty ? '' : _store.nameOf(t.assignedTo);
            final hit = t.title.toLowerCase().contains(q) ||
                t.project.toLowerCase().contains(q) ||
                assignee.toLowerCase().contains(q);
            if (!hit) return false;
          }
          return true;
        }).toList()
          ..sort((a, b) => b.id.compareTo(a.id));

        return (
          ['ID', 'JUDUL TASK', 'PROYEK', 'ASSIGNEE', 'PRIORITAS', 'STATUS', 'TENGGAT'],
          [
            for (final t in list)
              [
                '${t.id}',
                t.title,
                t.project.isEmpty ? '-' : t.project,
                t.assignedTo.isEmpty ? '-' : _store.nameOf(t.assignedTo),
                t.priority.name.toUpperCase(),
                statusLabel('task', t.status),
                t.dueDate.isEmpty ? '-' : _slashDate(t.dueDate),
              ],
          ],
        );

      case _ReportModuleId.tickets:
        final list = _store.tickets.where((t) {
          if (_appliedStatus != 'all' && t.status != _appliedStatus) return false;
          if (!_inAppliedDateRange(t.createdAt)) return false;
          if (q.isNotEmpty) {
            final hit = t.title.toLowerCase().contains(q) ||
                t.projectName.toLowerCase().contains(q) ||
                t.type.toLowerCase().contains(q);
            if (!hit) return false;
          }
          return true;
        }).toList()
          ..sort((a, b) => b.id.compareTo(a.id));

        return (
          ['ID', 'JUDUL TIKET', 'PROYEK', 'TIPE', 'PRIORITAS', 'STATUS', 'SLA'],
          [
            for (final t in list)
              [
                'TK-${t.id}',
                t.title,
                t.projectName.isEmpty ? '-' : t.projectName,
                t.type.toUpperCase(),
                t.priority.toUpperCase(),
                statusLabel('ticket', t.status),
                t.slaBreached ? 'Breached' : 'Aman',
              ],
          ],
        );

      case _ReportModuleId.requests:
        final list = _store.requests.where((r) {
          if (_appliedStatus != 'all' && r.status != _appliedStatus) return false;
          if (!_inAppliedDateRange(r.createdAt)) return false;
          if (q.isNotEmpty) {
            final hit = r.title.toLowerCase().contains(q) ||
                r.projectName.toLowerCase().contains(q);
            if (!hit) return false;
          }
          return true;
        }).toList()
          ..sort((a, b) => b.id.compareTo(a.id));

        return (
          ['ID', 'JUDUL REQUEST', 'PROYEK', 'TIPE', 'PRIORITAS', 'STATUS', 'DIBUAT'],
          [
            for (final r in list)
              [
                '${r.id}',
                r.title,
                r.projectName.isEmpty ? '-' : r.projectName,
                r.type,
                r.priority.toUpperCase(),
                r.status,
                r.createdAt.isEmpty ? '-' : _slashDate(r.createdAt),
              ],
          ],
        );

      case _ReportModuleId.campaigns:
        return (
          ['ID', 'NAMA CAMPAIGN', 'CHANNEL', 'STATUS', 'MULAI', 'SELESAI'],
          const [],
        );

      case _ReportModuleId.invoices:
        return (
          ['NO. INVOICE', 'PROYEK', 'KLIEN', 'NOMINAL', 'STATUS', 'JATUH TEMPO'],
          const [],
        );

      case _ReportModuleId.budgets:
        final list = _store.projects.where((p) {
          if (_appliedStatus != 'all' && p.status != _appliedStatus) return false;
          if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) return false;
          return true;
        }).toList()
          ..sort((a, b) => b.id.compareTo(a.id));

        return (
          ['ID', 'NAMA PROYEK', 'ANGGARAN', 'PEMASUKAN', 'PENGELUARAN', 'TERPAKAI', 'STATUS'],
          [
            for (final p in list)
              [
                '${p.id}',
                p.name,
                p.budget <= 0 ? '-' : rp(p.budget),
                rp(p.income),
                rp(p.expense),
                '${p.budgetUsedPercent}%',
                statusLabel('project', p.status),
              ],
          ],
        );
    }
  }

  String _slashDate(String iso) {
    if (iso.length < 10) return '-';
    final p = iso.substring(0, 10).split('-');
    if (p.length != 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  String _mmddyyyy(DateTime? d) {
    if (d == null) return 'mm/dd/yyyy';
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final (headers, rows) = _buildTableData();

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
        title: const Text('Reporting'),
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
          final isWide = constraints.maxWidth >= 840;
          return RefreshIndicator(
            onRefresh: _store.sync,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(isWide ? 22 : 12, 16, isWide ? 22 : 12, 100),
              children: [
                _buildHeroHeader(isWide, rows.length),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 248, child: _buildCatalogSidebar()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMainContent(isWide, headers, rows)),
                    ],
                  )
                else ...[
                  _buildCatalogSidebar(),
                  const SizedBox(height: 12),
                  _buildMainContent(isWide, headers, rows),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Header `Laporan & Ekspor Data` + tombol `Unduh PDF` & `Unduh Excel`.
  Widget _buildHeroHeader(bool isWide, int rowCount) {
    final exportButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => phToast(
            context,
            'Menyiapkan ekspor PDF untuk ${_activeMeta.title} ($rowCount baris data)...',
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFFEF2F2),
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFFECACA)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          icon: const Icon(Icons.description_outlined, size: 17),
          label: const Text('Unduh PDF', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
        OutlinedButton.icon(
          onPressed: () => phToast(
            context,
            'Menyiapkan ekspor Excel untuk ${_activeMeta.title} ($rowCount baris data)...',
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFECFDF5),
            foregroundColor: const Color(0xFF059669),
            side: const BorderSide(color: Color(0xFFA7F3D0)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          icon: const Icon(Icons.table_view_outlined, size: 17),
          label: const Text('Unduh Excel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ],
    );

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Laporan & Ekspor Data',
          style: TextStyle(
            fontSize: isWide ? 23 : 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Eksplorasi data, filter kustom, dan unduh laporan resmi dalam format PDF & Excel.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
      ],
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
                Expanded(child: titleColumn),
                const SizedBox(width: 16),
                exportButtons,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleColumn,
                const SizedBox(height: 12),
                exportButtons,
              ],
            ),
    );
  }

  /// Sidebar Katalog Laporan (7 Modul) untuk layar lebar/web.
  Widget _buildCatalogSidebar() {
    final groups = <String>[];
    for (final m in _modules) {
      if (!groups.contains(m.group)) groups.add(m.group);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'KATALOG LAPORAN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF64748B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_modules.length} Modul',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final grp in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6, left: 4),
              child: Text(
                grp,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF94A3B8)),
              ),
            ),
            for (final m in _modules.where((x) => x.group == grp))
              _catalogItem(m),
          ],
        ],
      ),
    );
  }

  Widget _catalogItem(_ReportModuleMeta m) {
    final active = _activeId == m.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => _selectModule(m.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9.5),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Colors.white : const Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  m.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
              if (active) const Icon(Icons.chevron_right_rounded, size: 17, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isWide, List<String> headers, List<List<String>> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kartu Info Modul & Filter
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _formatGroupTitle(_activeMeta.group),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                              ),
                            ),
                            Text(
                              '• ${rows.length} baris data ditemukan',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _activeMeta.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _activeMeta.subtitle,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showFilter = !_showFilter),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.filter_alt_outlined, size: 15),
                    label: Text(
                      _showFilter ? 'Sembunyikan Filter' : 'Tampilkan Filter',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (_showFilter) ...[
                const SizedBox(height: 16),
                _buildFilterGrid(isWide),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _applyFilter,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Terapkan Filter', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _resetFilter,
                      child: const Text('Reset', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Kartu Hasil Data
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      width: isWide ? 240 : double.infinity,
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _search = v),
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                              decoration: const InputDecoration(
                                hintText: 'Cari dalam hasil...',
                                hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Menampilkan ${rows.length} data',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 42, horizontal: 16),
                  child: Center(
                    child: Text(
                      'Tidak ada baris data untuk modul dan filter ini.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 54,
                    horizontalMargin: 16,
                    columnSpacing: 22,
                    columns: [
                      for (final h in headers)
                        DataColumn(
                          label: Text(
                            h,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
                          ),
                        ),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          cells: [
                            for (var c = 0; c < r.length; c++)
                              DataCell(
                                headers[c] == 'STATUS'
                                    ? _statusCellBadge(r[c])
                                    : Text(
                                        r[c],
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: c <= 1 ? FontWeight.w700 : FontWeight.w500,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterGrid(bool isWide) {
    final options = _statusOptionsFor(_activeId);
    final selectedStatusLabel = options.firstWhere((o) => o.$1 == _draftStatus, orElse: () => options.first).$2;

    final statusField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        PopupMenuButton<String>(
          onSelected: (v) => setState(() => _draftStatus = v),
          itemBuilder: (_) => [
            for (final (val, lbl) in options)
              PopupMenuItem(value: val, child: Text(lbl, style: const TextStyle(fontSize: 12.5))),
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
              children: [
                Expanded(
                  child: Text(selectedStatusLabel, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A))),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );

    Widget dateField(String label, DateTime? value, bool isFrom) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pickDate(isFrom: isFrom),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _mmddyyyy(value),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: value == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (isWide) {
      return Row(
        children: [
          Expanded(child: statusField),
          const SizedBox(width: 12),
          Expanded(child: dateField('Tanggal Mulai (Dari)', _draftFrom, true)),
          const SizedBox(width: 12),
          Expanded(child: dateField('Tanggal Mulai (Sampai)', _draftTo, false)),
        ],
      );
    }

    return Column(
      children: [
        statusField,
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: dateField('Tanggal Mulai (Dari)', _draftFrom, true)),
            const SizedBox(width: 10),
            Expanded(child: dateField('Tanggal Mulai (Sampai)', _draftTo, false)),
          ],
        ),
      ],
    );
  }

  Widget _statusCellBadge(String status) {
    final low = status.toLowerCase();
    final isGreen = low.contains('active') || low.contains('aktif') || low.contains('completed') || low.contains('selesai') || low.contains('resolved');
    final isRed = low.contains('cancel') || low.contains('reject') || low.contains('tolak');
    final fg = isGreen
        ? const Color(0xFF15803D)
        : (isRed ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
    final bg = isGreen
        ? const Color(0xFFECFDF5)
        : (isRed ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5.5, height: 5.5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  String _formatGroupTitle(String raw) {
    switch (raw) {
      case 'PROYEK & TUGAS':
        return 'Proyek & Tugas';
      case 'TIKET & DUKUNGAN':
        return 'Tiket & Dukungan';
      case 'MARKETING':
        return 'Marketing';
      case 'KEUANGAN':
        return 'Keuangan';
      default:
        return raw;
    }
  }
}
