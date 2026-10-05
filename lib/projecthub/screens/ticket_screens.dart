import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../stitch_frontend_interface_application/app_theme.dart';
import '../ph_format.dart';
import '../ph_models.dart';
import '../ph_remote.dart';
import '../ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

const ticketTypes = {'bug': 'Bug', 'issue': 'Issue', 'enhancement': 'Enhancement', 'security': 'Security', 'performance': 'Performance'};
const ticketCategories = {
  'frontend': 'Frontend', 'backend': 'Backend', 'database': 'Database', 'api': 'API',
  'infrastructure': 'Infrastruktur', 'integration': 'Integrasi', 'configuration': 'Konfigurasi', 'other': 'Lainnya',
};

/// Kebijakan SLA per prioritas: (menit respons, menit penyelesaian). Tabel sla_policies.
const _sla = {'critical': (60, 240), 'high': (240, 1440), 'medium': (480, 4320), 'low': (1440, 10080)};

const _flow = <String, List<(String, String, bool)>>{
  'open': [('assigned', 'Tugaskan', false), ('in_progress', 'Mulai kerjakan', false)],
  'assigned': [('in_progress', 'Mulai kerjakan', false)],
  'in_progress': [('pending_review', 'Kirim untuk review', false)],
  'pending_review': [('resolved', 'Selesaikan', true), ('in_progress', 'Kembali ke pengerjaan', false)],
  'resolved': [('closed', 'Tutup tiket', true), ('reopened', 'Buka lagi', false)],
  'closed': [('reopened', 'Buka lagi', false)],
  'reopened': [('in_progress', 'Mulai kerjakan', false)],
};

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
  const TicketRow(this.t, {super.key});

  @override
  Widget build(BuildContext context) => PhListRow(
        title: 'TK-${t.id} ${t.title}',
        subtitle: '${t.projectName} · ${ticketTypes[t.type]} · ${t.assigneeId.isEmpty ? 'Belum ditugaskan' : PhStore.instance.nameOf(t.assigneeId)}',
        trailing: PhPill.status('ticket', t.status),
        trailingNote: statusLabel('priority', t.priority),
        onTap: () => context.push('/ticket/${t.id}'),
      );
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

  @override
  void dispose() {
    _comment.dispose();
    _check.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final t = _store.ticketById(widget.ticketId);
    if (t != null) _run(_store.loadTicketDetail(t));
  }

  Future<void> _run(Future<void> action) async {
    try {
      await action;
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  /// API mewajibkan catatan untuk setiap perubahan status. Bila kebijakan
  /// approval berlaku, server membuat approval dan status belum berubah.
  void _go(Ticket t, String to) {
    openPhForm(
      context,
      PhFormConfig(
        title: 'Ubah status ke ${statusLabel('ticket', to)}',
        saveLabel: 'Kirim',
        doneMessage: 'Status: ${statusLabel('ticket', to)}',
        fields: const [PhField('description', 'Catatan', type: PhFieldType.multiline, required: true, hint: 'Apa yang dikerjakan / alasan perubahan')],
        onSave: (v) async {
          final pending = await _store.setTicketStatus(t, to, v['description'] as String);
          if (pending != null && mounted) phToast(context, pending);
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _store.ticketById(widget.ticketId);
    if (t == null) return Scaffold(appBar: phAppBar('Tiket'), body: const PhEmpty(Icons.bug_report_outlined, 'Tiket tidak ditemukan'));
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final sla = _sla[t.priority]!;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar('TK-${t.id}', actions: [IconButton(tooltip: 'Ubah tiket', icon: const Icon(Icons.edit_outlined), onPressed: () => openTicketForm(context, ticket: t))]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40),
            children: [
              PhHeaderCard(title: t.title, pills: [
                PhPill.status('ticket', t.status),
                PhPill.status('priority', t.priority),
                PhPill(ticketTypes[t.type]!, fg: const Color(0xFF1565C0), bg: AppColors.primary50),
                if (t.slaBreached) const PhPill('SLA terlewat', fg: Color(0xFFC62828), bg: AppColors.errorBg),
                if (t.slaPaused) const PhPill('SLA dijeda', fg: Color(0xFFB15600), bg: AppColors.warningBg),
                if (t.escalated) const PhPill('Dieskalasi', fg: Color(0xFFB15600), bg: AppColors.warningBg),
              ]),
              phGap(),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in _flow[t.status] ?? const <(String, String, bool)>[])
                  f.$3 ? phGreenButton(f.$2, () => _go(t, f.$1)) : phSoftButton(f.$2, () => _go(t, f.$1)),
              ].map((w) => SizedBox(width: (MediaQuery.of(context).size.width - 2 * AppSpacing.md - 8) / 2, child: w)).toList()),
              PhSection(
                'Informasi',
                child: KvCard([
                  ('Proyek', t.projectName),
                  ('Milestone', t.milestone),
                  ('Kategori error', ticketCategories[t.errorCategory]),
                  ('Pelapor', _store.nameOf(t.reporterId)),
                  ('Ditugaskan ke', t.assigneeId.isEmpty ? 'Belum ditugaskan' : _store.nameOf(t.assigneeId)),
                  ('Selesai', t.resolvedAt.isEmpty ? '-' : fmtDateTime(t.resolvedAt)),
                ]),
              ),
              PhSection(
                'SLA',
                child: KvCard([
                  ('Kebijakan SLA', '${statusLabel('priority', t.priority)}: respons ${sla.$1 ~/ 60} jam, selesai ${sla.$2 >= 1440 ? '${sla.$2 ~/ 1440} hari' : '${sla.$2 ~/ 60} jam'}'),
                  ('Jatuh tempo', fmtDateTime(t.slaDueAt)),
                  ('Status', '${t.slaBreached ? 'Terlewat' : t.slaPaused ? 'Dijeda' : 'Berjalan'}${t.escalated ? ', sudah dieskalasi' : ''}'),
                ]),
              ),
              PhSection('Deskripsi', child: PhCard(child: Text(t.description, style: const TextStyle(fontSize: 14, height: 1.5)))),
              PhSection('Solusi', child: PhCard(child: Text(t.solution.isEmpty ? 'Belum ada solusi.' : t.solution, style: const TextStyle(fontSize: 14, height: 1.5)))),
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
              PhSection(
                'Komentar (${t.comments.length})',
                child: Column(children: [
                  for (final c in t.comments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PhCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [PhAvatar(c.userId), const SizedBox(width: 8), Text(_store.nameOf(c.userId), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const Spacer(), Text(fmtDateTime(c.at), style: const TextStyle(fontSize: 11, color: AppColors.grey500))]),
                          const SizedBox(height: 6),
                          Text(c.body, style: const TextStyle(fontSize: 14)),
                        ]),
                      ),
                    ),
                  _InputRow(controller: _comment, hint: 'Tulis komentar', icon: Icons.send_rounded, tooltip: 'Kirim', onSend: () {
                    final v = _comment.text.trim();
                    if (v.isEmpty) return;
                    _comment.clear();
                    _run(_store.addTicketComment(t, v));
                  }),
                ]),
              ),
              PhSection(
                'Riwayat perubahan',
                child: t.history.isEmpty
                    ? const PhCard(child: Text('Belum ada riwayat.', style: TextStyle(fontSize: 13, color: AppColors.grey700)))
                    : PhCard(
                        child: Column(children: [
                          for (final h in t.history)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text.rich(TextSpan(style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.grey900), children: [
                                  TextSpan(text: _store.nameOf(h.actorId), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  TextSpan(text: ' mengubah ${h.field} dari '),
                                  TextSpan(text: h.oldValue, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const TextSpan(text: ' ke '),
                                  TextSpan(text: h.newValue, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  TextSpan(text: '\n${fmtDateTime(h.at)}', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                                ])),
                              ),
                            ),
                        ]),
                      ),
              ),
            ],
          ),
        );
      },
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

/// Form tiket. Field mengikuti tabel `bug_tickets`.
void openTicketForm(BuildContext context, {Ticket? ticket}) {
  final store = PhStore.instance;
  final t = ticket;
  openPhForm(
    context,
    PhFormConfig(
      title: t == null ? 'Tiket Baru' : 'Ubah Tiket',
      doneMessage: 'Tiket tersimpan',
      fields: [
        PhField('projectName', 'Proyek', type: PhFieldType.select, options: [for (final p in store.projects) (p.name, p.name)], initial: t?.projectName ?? store.projects.firstOrNull?.name, readOnly: t != null),
        PhField('title', 'Judul', required: true, initial: t?.title),
        PhField('description', 'Deskripsi', type: PhFieldType.multiline, required: true, initial: t?.description, hint: 'Langkah reproduksi, hasil yang diharapkan'),
        PhField('type', 'Tipe', type: PhFieldType.select, options: [for (final e in ticketTypes.entries) (e.key, e.value)], initial: t?.type ?? 'bug'),
        PhField('priority', 'Prioritas', type: PhFieldType.select, options: [for (final e in statusOptions('priority').where((e) => e.$1 != 'urgent')) e], initial: t?.priority ?? 'medium', hint: 'Prioritas menentukan kebijakan SLA (sla_policies).'),
        PhField('assigneeId', 'Ditugaskan ke', type: PhFieldType.select, options: [('', 'Belum ditugaskan'), for (final u in store.staff) (u.id, u.name)], initial: t?.assigneeId ?? ''),
      ],
      onSave: (v) async {
        await store.saveTicket(t, v);
        return null;
      },
    ),
  );
}
