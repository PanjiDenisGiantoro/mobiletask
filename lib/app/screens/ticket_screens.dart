import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../data/ph_api.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

const ticketTypes = {'bug': 'Bug', 'issue': 'Issue', 'enhancement': 'Enhancement', 'security': 'Security', 'performance': 'Performance'};
const ticketCategories = {
  'frontend': 'Frontend', 'backend': 'Backend', 'database': 'Database', 'api': 'API',
  'infrastructure': 'Infrastruktur', 'integration': 'Integrasi', 'configuration': 'Konfigurasi', 'other': 'Lainnya',
};

/// Gaya badge tipe tiket (mengikuti tampilan web: BUG merah, ENHANCEMENT ungu,
/// PERFORMANCE hijau/teal, SECURITY oranye, ISSUE biru).
(String, Color, Color) ticketTypeStyle(String type) => switch (type) {
      'bug' => ('BUG', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      'enhancement' => ('ENHANCEMENT', const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
      'performance' => ('PERFORMANCE', const Color(0xFF0D9488), const Color(0xFFCCFBF1)),
      'security' => ('SECURITY', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
      'issue' => ('ISSUE', const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
      _ => (type.toUpperCase(), AppColors.grey700, AppColors.grey100),
    };

class TicketTypeBadge extends StatelessWidget {
  final String type;
  const TicketTypeBadge(this.type, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = ticketTypeStyle(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.small)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.3)),
    );
  }
}

class TicketDotPill extends StatelessWidget {
  final String group;
  final String statusKey;
  const TicketDotPill(this.group, this.statusKey, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = statusStyle(group, statusKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: s.fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(s.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.fg)),
        ],
      ),
    );
  }
}

class TicketSlaBadge extends StatelessWidget {
  final Ticket ticket;
  final bool fullLabel;
  const TicketSlaBadge(this.ticket, {super.key, this.fullLabel = false});

  @override
  Widget build(BuildContext context) {
    if (ticket.slaBreached) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(AppRadius.small)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Text(
              fullLabel ? 'SLA BREACHED' : 'BREACHED',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626), letterSpacing: 0.2),
            ),
          ],
        ),
      );
    }
    final ago = timeAgo(ticket.createdAt.isNotEmpty ? ticket.createdAt : ticket.resolvedAt);
    if (ago.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time_rounded, size: 13, color: AppColors.grey500),
        const SizedBox(width: 4),
        Text(ago, style: const TextStyle(fontSize: 11.5, color: AppColors.grey700, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Kebijakan SLA per prioritas: (menit respons, menit penyelesaian). Tabel sla_policies.
const _sla = {'critical': (60, 240), 'high': (240, 1440), 'medium': (480, 4320), 'low': (1440, 10080)};

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  String _filter = 'all';
  String _query = '';
  final _store = PhStore.instance;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final q = _query.trim().toLowerCase();
          final list = _store.tickets.where((t) => (_filter == 'all' || t.status == _filter) && (q.isEmpty || t.title.toLowerCase().contains(q))).toList();
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: phAppBar('Bug Tickets'),
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'tickets_fab',
              backgroundColor: AppColors.heroStart,
              foregroundColor: Colors.white,
              onPressed: () => openTicketForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Tiket Baru'),
            ),
            body: Column(children: [
              PhChipBar(
                items: const [('all', 'Semua'), ('open', 'Open'), ('in_progress', 'In Progress'), ('pending_review', 'Review'), ('resolved', 'Resolved'), ('closed', 'Closed')],
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Cari tiket...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
                    filled: true,
                    fillColor: AppColors.grey100,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty && _store.syncing
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _store.sync,
                        child: list.isEmpty
                            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [PhEmpty(Icons.inbox_outlined, _store.syncError ?? 'Tidak ada tiket yang cocok')])
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                                itemCount: list.length,
                                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (_, i) => TicketRow(list[i]),
                              ),
                      ),
              ),
            ]),
          );
        },
      );
}

class TicketRow extends StatelessWidget {
  final Ticket t;
  final Project? project;
  const TicketRow(this.t, {super.key, this.project});

  @override
  Widget build(BuildContext context) {
    final store = PhStore.instance;
    final commentTotal = t.comments.isNotEmpty ? t.comments.length : t.commentsCount;
    final createdDate = t.createdAt.isEmpty ? '' : fmtDate(t.createdAt.split(' ').first);
    return PhCard(
      onTap: () => context.push('/ticket/${t.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TicketTypeBadge(t.type),
              const SizedBox(width: 8),
              Text('#${t.id}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey500)),
              const SizedBox(width: 4),
              Text('TK-${t.id}', style: const TextStyle(fontSize: 10.5, color: AppColors.grey400)),
              const Spacer(),
              TicketSlaBadge(t),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit Tiket #${t.id}',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.edit_note_rounded, size: 19, color: AppColors.grey500),
                onPressed: () => openTicketForm(context, ticket: t, project: project),
              ),
              const Icon(Icons.chevron_right_rounded, size: 19, color: AppColors.grey400),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.grey900, height: 1.25),
          ),
          if (t.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              t.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.grey500, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TicketDotPill('priority', t.priority),
              TicketDotPill('ticket', t.status),
              if (t.milestone.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.small)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_outlined, size: 12, color: AppColors.grey700),
                      const SizedBox(width: 4),
                      Text(t.milestone, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.grey700)),
                    ],
                  ),
                ),
              if (commentTotal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mode_comment_outlined, size: 12, color: AppColors.grey500),
                      const SizedBox(width: 4),
                      Text('$commentTotal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.grey100),
          const SizedBox(height: 10),
          Row(
            children: [
              PhAvatar(t.assigneeId, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.assigneeId.isEmpty ? 'Belum ditugaskan' : store.nameOf(t.assigneeId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey900),
                    ),
                    Text(
                      'Oleh: ${t.reporterId.isEmpty ? '-' : store.nameOf(t.reporterId)}${project == null && t.projectName.isNotEmpty ? ' · ${t.projectName}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.grey500),
                    ),
                  ],
                ),
              ),
              if (createdDate.isNotEmpty)
                Text(createdDate, style: const TextStyle(fontSize: 11.5, color: AppColors.grey700, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _store = PhStore.instance;
  final _comment = TextEditingController();
  final _check = TextEditingController();
  late final TextEditingController _solution = TextEditingController();
  int _activeTab = 0; // 0: Detail & Solusi | 1: Komentar & Diskusi | 2: Riwayat Aktivitas
  String? _selectedStatus;
  String? _selectedErrorCategory;
  PhPickedFile? _pickedAttachment;
  bool _savingStatus = false;
  bool _savingSolution = false;
  bool _sendingComment = false;

  @override
  void dispose() {
    _comment.dispose();
    _check.dispose();
    _solution.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final t = _store.ticketById(widget.ticketId);
    if (t != null) {
      _selectedStatus = t.status;
      _selectedErrorCategory = t.errorCategory;
      _solution.text = t.solution;
      _run(_store.loadTicketDetail(t).then((_) {
        if (!mounted) return;
        setState(() {
          _selectedStatus = t.status;
          _selectedErrorCategory = t.errorCategory;
          if (_solution.text.isEmpty && t.solution.isNotEmpty) _solution.text = t.solution;
        });
      }));
    }
  }

  Future<void> _run(Future<void> action) async {
    try {
      await action;
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  /// Simpan perubahan status dari kartu STATUS TIKET (atau tombol aksi cepat).
  void _promptAndSaveStatus(Ticket t, String to) {
    openPhForm(
      context,
      PhFormConfig(
        title: 'Ubah status ke ${statusLabel('ticket', to)}',
        saveLabel: 'Simpan Status',
        doneMessage: 'Status: ${statusLabel('ticket', to)}',
        fields: [
          PhField(
            'description',
            'Catatan perubahan status',
            type: PhFieldType.multiline,
            required: true,
            initial: 'Status diubah menjadi ${statusLabel('ticket', to)}',
            hint: 'Apa yang dikerjakan / alasan perubahan',
          ),
        ],
        onSave: (v) async {
          setState(() => _savingStatus = true);
          try {
            final pending = await _store.setTicketStatus(t, to, v['description'] as String);
            if (mounted) {
              setState(() => _selectedStatus = t.status);
              if (pending != null) phToast(context, pending);
            }
          } finally {
            if (mounted) setState(() => _savingStatus = false);
          }
          return null;
        },
      ),
    );
  }

  Future<void> _saveSolution(Ticket t) async {
    setState(() => _savingSolution = true);
    try {
      final f = _pickedAttachment;
      await _store.saveTicketSolution(
        t,
        errorCategory: _selectedErrorCategory ?? '',
        solution: _solution.text.trim(),
        attachment: f == null ? null : ApiFile('attachments[]', f.name, f.bytes),
      );
      if (mounted) {
        setState(() => _pickedAttachment = null);
        phToast(context, 'Solusi & kategori error disimpan');
      }
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _savingSolution = false);
    }
  }

  Future<void> _sendComment(Ticket t) async {
    final v = _comment.text.trim();
    if (v.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      await _store.addTicketComment(t, v);
      _comment.clear();
      if (mounted) phToast(context, 'Komentar terkirim');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      phToast(context, 'Tidak dapat membuka tautan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _store.ticketById(widget.ticketId);
    if (t == null) return Scaffold(appBar: phAppBar('Tiket'), body: const PhEmpty(Icons.bug_report_outlined, 'Tiket tidak ditemukan'));
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final sla = _sla[t.priority] ?? (480, 4320);
        final currentStatus = _selectedStatus ?? t.status;
        final ticketCode = '#TKT-${t.id.toString().padLeft(4, '0')}';
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar(
            ticketCode,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: TextButton.icon(
                  onPressed: () => openTicketForm(context, ticket: t),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF3C7),
                    foregroundColor: const Color(0xFFB45309),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFB45309)),
                  label: const Text('Edit Tiket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 48),
            children: [
              // ── Header Card (Badges + Judul + Meta Pelapor & Waktu) ──
              PhCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.full)),
                          child: Text(ticketCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.grey700)),
                        ),
                        TicketTypeBadge(t.type),
                        TicketDotPill('priority', t.priority),
                        TicketDotPill('ticket', t.status),
                        if (t.slaBreached) TicketSlaBadge(t, fullLabel: true),
                        if (t.slaPaused) const PhPill('SLA dijeda', fg: Color(0xFFB15600), bg: AppColors.warningBg),
                        if (t.escalated) const PhPill('Dieskalasi', fg: Color(0xFFB15600), bg: AppColors.warningBg),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.title,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.grey900, height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.grey500),
                            const SizedBox(width: 4),
                            const Text('Dilaporkan oleh: ', style: TextStyle(fontSize: 12, color: AppColors.grey500)),
                            Text(
                              t.reporterId.isEmpty ? '-' : _store.nameOf(t.reporterId),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey900),
                            ),
                          ],
                        ),
                        if (t.createdAt.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.grey500),
                              const SizedBox(width: 4),
                              Text(
                                '${timeAgo(t.createdAt)} (${fmtDateTime(t.createdAt)})',
                                style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              phGap(AppSpacing.sm),

              // ── Segmented Sub-Tabs: Detail & Solusi | Komentar & Diskusi | Riwayat Aktivitas ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _subTabButton(0, Icons.description_outlined, 'Detail & Solusi', null),
                    const SizedBox(width: 8),
                    _subTabButton(1, Icons.chat_bubble_outline_rounded, 'Komentar & Diskusi', t.comments.isNotEmpty ? t.comments.length : t.commentsCount),
                    const SizedBox(width: 8),
                    _subTabButton(2, Icons.history_rounded, 'Riwayat Aktivitas', t.history.length),
                  ],
                ),
              ),
              phGap(AppSpacing.md),

              // ── Isi Sub-Tab Aktif ──
              if (_activeTab == 0) _buildDetailAndSolutionTab(t),
              if (_activeTab == 1) _buildCommentsTab(t),
              if (_activeTab == 2) _buildHistoryTab(t),

              phGap(AppSpacing.md),

              // ── Kartu Status Tiket, SLA Target, Google Meet, Petugas, Pelapor, Info Proyek ──
              _buildStatusAndSidebarCards(t, currentStatus, sla),
            ],
          ),
        );
      },
    );
  }

  Widget _subTabButton(int index, IconData icon, String label, int? count) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: active ? const Color(0xFFBFDBFE) : AppColors.grey100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? const Color(0xFF2563EB) : AppColors.grey700),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? const Color(0xFF2563EB) : AppColors.grey700,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFDBEAFE) : AppColors.grey100,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? const Color(0xFF1D4ED8) : AppColors.grey700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailAndSolutionTab(Ticket t) {
    final categoryValue = (_selectedErrorCategory != null && ticketCategories.containsKey(_selectedErrorCategory))
        ? _selectedErrorCategory!
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // DESKRIPSI MASALAH
        PhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DESKRIPSI MASALAH',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.grey500, letterSpacing: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                t.description.isEmpty ? '-' : t.description,
                style: const TextStyle(fontSize: 14, color: AppColors.grey900, height: 1.5),
              ),
            ],
          ),
        ),
        phGap(AppSpacing.md),

        // KATEGORI ERROR & SOLUSI
        PhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KATEGORI ERROR & SOLUSI',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.grey900, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              const Text('Kategori Error', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.grey700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: categoryValue,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.grey100.withValues(alpha: 0.6),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: BorderSide.none),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('— Pilih Kategori Error —', style: TextStyle(fontSize: 13.5, color: AppColors.grey500))),
                  for (final e in ticketCategories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13.5))),
                ],
                onChanged: (v) => setState(() => _selectedErrorCategory = v ?? ''),
              ),
              const SizedBox(height: 12),
              const Text('Solusi / Catatan Perbaikan Teknis', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.grey700)),
              const SizedBox(height: 6),
              TextField(
                controller: _solution,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Jelaskan akar penyebab masalah dan solusi/patch yang telah diterapkan...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.grey400),
                  filled: true,
                  fillColor: AppColors.grey100.withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Tambah File Lampiran', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.grey700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await pickPhFile(context);
                      if (picked != null && mounted) setState(() => _pickedAttachment = picked);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF2563EB),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
                    ),
                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                    label: const Text('Choose Files', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pickedAttachment?.name ?? 'No file chosen',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.grey500),
                    ),
                  ),
                  if (_pickedAttachment != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => setState(() => _pickedAttachment = null),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _savingSolution ? null : () => _saveSolution(t),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                  child: Text(
                    _savingSolution ? 'Menyimpan...' : 'Simpan Solusi & Lampiran',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        phGap(AppSpacing.md),

        // LAMPIRAN FILE
        PhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'LAMPIRAN FILE',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.grey900, letterSpacing: 0.5),
                  ),
                  const Spacer(),
                  Text(
                    '${t.attachments.length} FILE',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (t.attachments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'Belum ada lampiran file untuk tiket ini.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.grey500),
                    ),
                  ),
                )
              else
                for (final a in t.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: PhListRow(
                      leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary600),
                      title: a.name,
                      subtitle: a.size > 0 ? fileSize(a.size) : '',
                      onTap: a.url.isEmpty ? null : () => _openUrl(a.url),
                    ),
                  ),
            ],
          ),
        ),

        // Checklist (bila ada item checklist atau pengguna ingin menambah)
        if (t.checklist.isNotEmpty) ...[
          phGap(AppSpacing.md),
          PhSection(
            'Checklist (${t.checklist.where((c) => c.done).length}/${t.checklist.length})',
            child: Column(children: [
              for (final c in t.checklist)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PhCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: CheckboxListTile(
                        value: c.done,
                        activeColor: AppColors.heroStart,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(c.body, style: TextStyle(fontSize: 14, decoration: c.done ? TextDecoration.lineThrough : null, color: c.done ? AppColors.grey700 : AppColors.grey900)),
                        onChanged: (_) => _run(_store.toggleChecklistItem(t, c)),
                      ),
                    ),
                  ),
                ),
              _InputRow(controller: _check, hint: 'Tambah item checklist', icon: Icons.add, tooltip: 'Tambah', onSend: () {
                final v = _check.text.trim();
                if (v.isEmpty) return;
                _check.clear();
                _run(_store.addChecklistItem(t, v));
              }),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentsTab(Ticket t) {
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Belum ada komentar atau diskusi.', style: TextStyle(fontSize: 13, color: AppColors.grey500)),
              ),
            )
          else
            for (final c in t.comments)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.grey100.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PhAvatar(c.userId, size: 30),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _store.nameOf(c.userId),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900),
                          ),
                        ),
                        Text(
                          timeAgo(c.at).isNotEmpty ? timeAgo(c.at) : fmtDateTime(c.at),
                          style: const TextStyle(fontSize: 11, color: AppColors.grey500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(c.body, style: const TextStyle(fontSize: 13.5, color: AppColors.grey900, height: 1.45)),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          const Text('Tambah Komentar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey900)),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Tulis komentar, update status kerja, atau masukan...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.grey100.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _sendingComment ? null : () => _sendComment(t),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
              ),
              icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
              label: Text(
                _sendingComment ? 'Mengirim...' : 'Kirim Komentar',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Ticket t) {
    if (t.history.isEmpty) {
      return const PhCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('Belum ada riwayat aktivitas.', style: TextStyle(fontSize: 13, color: AppColors.grey500)),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final h in t.history)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(_store.nameOf(h.actorId), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                            const Text('mengubah', style: TextStyle(fontSize: 13, color: AppColors.grey700)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(4)),
                              child: Text(h.field, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                            ),
                            const Text('dari', style: TextStyle(fontSize: 13, color: AppColors.grey700)),
                            Text(
                              h.oldValue,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.grey500, decoration: TextDecoration.lineThrough),
                            ),
                            const Text('menjadi', style: TextStyle(fontSize: 13, color: AppColors.grey700)),
                            Text(
                              h.newValue,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(fmtDateTime(h.at), style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                    ],
                  ),
                  if (h.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Text(h.description, style: const TextStyle(fontSize: 12.5, color: AppColors.grey700)),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusAndSidebarCards(Ticket t, String currentStatus, (int, int) sla) {
    final assigneeUser = _store.users[t.assigneeId];
    final reporterUser = _store.users[t.reporterId];
    final statusItems = statusOptions('ticket');
    final validStatus = statusItems.any((e) => e.$1 == currentStatus) ? currentStatus : statusItems.first.$1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // STATUS TIKET
        PhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STATUS TIKET',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.grey500, letterSpacing: 0.6),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: validStatus,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.grey100.withValues(alpha: 0.6),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: BorderSide.none),
                ),
                items: [
                  for (final s in statusItems)
                    DropdownMenuItem(value: s.$1, child: Text(s.$2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedStatus = v);
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _savingStatus ? null : () => _promptAndSaveStatus(t, validStatus),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                  child: const Text('Simpan Status', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        phGap(AppSpacing.sm),

        // SLA TARGET (tetap menyertakan label 'SLA' dan info respons untuk kompatibilitas tes)
        PhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('SLA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.grey500, letterSpacing: 0.6)),
                  const Text(' TARGET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.grey500, letterSpacing: 0.6)),
                  const Spacer(),
                  Text(
                    t.slaBreached ? 'Terlewat' : (t.slaPaused ? 'Dijeda' : 'Berjalan'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.slaBreached ? const Color(0xFFDC2626) : (t.slaPaused ? const Color(0xFFD97706) : AppColors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: t.slaBreached ? 1.0 : (t.status == 'resolved' || t.status == 'closed' ? 1.0 : 0.5),
                  minHeight: 7,
                  backgroundColor: AppColors.grey100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    t.slaBreached ? const Color(0xFFE11D48) : AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Terpakai: ${t.slaBreached ? '100%' : (t.status == 'resolved' || t.status == 'closed' ? '100%' : '50%')}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.grey700, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    'Batas: ${t.slaDueAt.isEmpty ? '-' : fmtDateTime(t.slaDueAt)}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.grey500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${statusLabel('priority', t.priority)}: respons ${sla.$1 ~/ 60} jam, selesai ${sla.$2 >= 1440 ? '${sla.$2 ~/ 1440} hari' : '${sla.$2 ~/ 60} jam'}',
                style: const TextStyle(fontSize: 11, color: AppColors.grey500),
              ),
            ],
          ),
        ),
        phGap(AppSpacing.sm),

        // GOOGLE MEET
        PhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GOOGLE MEET',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.grey500, letterSpacing: 0.6),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openUrl(t.meetLink.isNotEmpty ? t.meetLink : 'https://meet.google.com/new'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: Text(
                    t.meetLink.isNotEmpty ? 'Buka Google Meet' : 'Buat Google Meet',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        phGap(AppSpacing.sm),

        // PETUGAS (ASSIGNEE) & PELAPOR
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PhCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PETUGAS (ASSIGNEE)',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PhAvatar(t.assigneeId, size: 34),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.assigneeId.isEmpty ? 'Belum ditugaskan' : _store.nameOf(t.assigneeId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey900),
                              ),
                              if (assigneeUser != null && assigneeUser.email.isNotEmpty)
                                Text(
                                  assigneeUser.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.grey500),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PhCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PELAPOR',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.grey500, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PhAvatar(t.reporterId, size: 34),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.reporterId.isEmpty ? '-' : _store.nameOf(t.reporterId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey900),
                              ),
                              if (reporterUser != null && reporterUser.email.isNotEmpty)
                                Text(
                                  reporterUser.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.grey500),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        phGap(AppSpacing.sm),

        // Info Proyek / Milestone / Dibuat
        KvCard([
          ('Proyek', t.projectName),
          ('Milestone', t.milestone.isEmpty ? '—' : t.milestone),
          ('Dibuat', t.createdAt.isEmpty ? '—' : fmtDateTime(t.createdAt)),
        ]),
      ],
    );
  }
}

class _InputRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String tooltip;
  final VoidCallback onSend;
  const _InputRow({required this.controller, required this.hint, required this.icon, required this.tooltip, required this.onSend});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.grey100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(tooltip: tooltip, style: IconButton.styleFrom(backgroundColor: AppColors.heroStart), onPressed: onSend, icon: Icon(icon, size: 18)),
      ]);
}

/// Form tiket (mengikuti modal Create / Edit Ticket di web).
void openTicketForm(BuildContext context, {Ticket? ticket, Project? project}) {
  final store = PhStore.instance;
  final t = ticket;
  final targetProject = project ??
      (t != null && t.projectId != 0 ? store.projectById(t.projectId) : null) ??
      (t != null && t.projectName.isNotEmpty ? store.projectByName(t.projectName) : null) ??
      store.projects.firstOrNull;
  final milestoneOptions = <(String, String)>[
    ('', '— Tanpa Milestone —'),
    for (final m in (targetProject?.milestones ?? const <Milestone>[])) (m.title, m.title),
  ];
  final memberOptions = <(String, String)>[
    if (targetProject != null && targetProject.members.isNotEmpty)
      for (final m in targetProject.members) (m.userId, store.nameOf(m.userId))
    else
      for (final u in store.staff) (u.id, u.name),
  ];
  openPhForm(
    context,
    PhFormConfig(
      title: t == null ? 'Create Ticket' : 'Edit Ticket #${t.id}',
      note: 'Perbarui detail kendala, prioritas, status, atau petugas',
      saveLabel: t == null ? 'Buat Tiket' : 'Perbarui Tiket',
      doneMessage: t == null ? 'Tiket dibuat' : 'Tiket diperbarui',
      fields: [
        PhField(
          'projectName',
          'Proyek',
          type: PhFieldType.select,
          options: [for (final p in store.projects) (p.name, p.name)],
          initial: t?.projectName ?? targetProject?.name,
          readOnly: t != null || project != null,
        ),
        PhField('title', 'Judul Tiket', required: true, initial: t?.title),
        PhField(
          'description',
          'Deskripsi Lengkap',
          type: PhFieldType.multiline,
          required: true,
          initial: t?.description,
          hint: 'Langkah reproduksi, hasil yang diharapkan',
        ),
        PhField('status', 'Status Tiket', type: PhFieldType.select, options: statusOptions('ticket'), initial: t?.status ?? 'open'),
        PhField(
          'priority',
          'Prioritas',
          type: PhFieldType.select,
          options: [for (final e in statusOptions('priority').where((e) => e.$1 != 'urgent')) e],
          initial: t?.priority ?? 'medium',
        ),
        PhField('type', 'Tipe Masalah', type: PhFieldType.select, options: [for (final e in ticketTypes.entries) (e.key, e.value)], initial: t?.type ?? 'bug'),
        PhField(
          'errorCategory',
          'Kategori Error (Opsional)',
          type: PhFieldType.select,
          options: [('', '— Pilih Kategori —'), for (final e in ticketCategories.entries) (e.key, e.value)],
          initial: t?.errorCategory ?? '',
        ),
        PhField(
          'milestone',
          'Milestone (Opsional)',
          type: PhFieldType.select,
          options: milestoneOptions,
          initial: milestoneOptions.any((o) => o.$1 == (t?.milestone ?? '')) ? (t?.milestone ?? '') : '',
        ),
        PhField(
          'assigneeIds',
          'Tugaskan ke Anggota Tim (Hanya Member)',
          type: PhFieldType.multi,
          options: memberOptions,
          initial: t?.assigneeIds ?? const <String>[],
          hint: 'Bisa pilih lebih dari 1',
        ),
        const PhField(
          'attachment',
          'Tambah Lampiran Baru (Maks. 5 file)',
          type: PhFieldType.file,
          hint: 'PNG, JPG, PDF, ZIP, maksimal 10MB per file.',
        ),
      ],
      onSave: (v) async {
        final f = v['attachmentFile'] as PhPickedFile?;
        await store.saveTicket(
          t,
          v,
          attachment: f == null ? null : ApiFile('attachments[]', f.name, f.bytes),
        );
        return null;
      },
    ),
  );
}
