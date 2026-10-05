import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

const requestTypes = {'feature_request': 'Permintaan fitur', 'bug_report': 'Laporan bug', 'change_request': 'Permintaan perubahan', 'general_inquiry': 'Pertanyaan umum'};

// ============================================================ Customer Requests

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String _filter = 'all';
  final _store = PhStore.instance;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final list = _store.requests.where((r) => _filter == 'all' || r.status == _filter).toList();
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: phAppBar('Customer Requests'),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'requests_fab',
          backgroundColor: AppColors.heroStart,
          foregroundColor: Colors.white,
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add),
          label: const Text('Permintaan Baru'),
        ),
        body: Column(
          children: [
            PhChipBar(items: [('all', 'Semua'), ...statusOptions('request')], selected: _filter, onSelected: (v) => setState(() => _filter = v)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _store.sync,
                child: list.isEmpty
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [PhEmpty(Icons.inbox_outlined, _store.syncError ?? 'Tidak ada permintaan dengan status ini')])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final r = list[i];
                          return PhListRow(
                            title: r.title,
                            subtitle: '${r.projectName} · ${requestTypes[r.type]} · ${_store.nameOf(r.customerId)}',
                            trailing: PhPill.status('request', r.status),
                            trailingNote: statusLabel('priority', r.priority),
                            onTap: () => context.push('/request/${r.id}'),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      );
    },
  );

  void _openForm(BuildContext context) {
    openPhForm(
      context,
      PhFormConfig(
        title: 'Permintaan Baru',
        doneMessage: 'Permintaan dikirim',
        fields: [
          PhField('projectName', 'Proyek', type: PhFieldType.select, required: true, options: [for (final p in _store.projects) (p.name, p.name)], initial: _store.projects.firstOrNull?.name),
          const PhField('title', 'Judul', required: true),
          const PhField('description', 'Deskripsi', type: PhFieldType.multiline, required: true),
          PhField('type', 'Jenis', type: PhFieldType.select, options: [for (final e in requestTypes.entries) (e.key, e.value)], initial: 'feature_request'),
          PhField('priority', 'Prioritas', type: PhFieldType.select, options: statusOptions('priority').where((e) => e.$1 != 'critical').toList(), initial: 'medium'),
        ],
        onSave: (v) async {
          await _store.createRequest(v);
          return null;
        },
      ),
    );
  }
}

class RequestDetailScreen extends StatefulWidget {
  final int requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _store = PhStore.instance;
  TextEditingController? _notes;

  @override
  void dispose() {
    _notes?.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> action, String done) async {
    try {
      await action;
      if (mounted) phToast(context, done);
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  void _reject(CustomerRequest r) {
    openPhForm(
      context,
      PhFormConfig(
        title: 'Tolak Permintaan',
        saveLabel: 'Tolak permintaan',
        doneMessage: 'Permintaan ditolak',
        fields: const [PhField('reason', 'Alasan penolakan', type: PhFieldType.multiline, required: true)],
        onSave: (v) async {
          await _store.rejectRequest(r, v['reason'] as String);
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _store.requestById(widget.requestId);
    if (r == null) return Scaffold(appBar: phAppBar('Permintaan'), body: const PhEmpty(Icons.inbox_outlined, 'Permintaan tidak ditemukan'));
    _notes ??= TextEditingController(text: r.marketingNotes);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: phAppBar('Permintaan #${r.id}'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40),
          children: [
            PhHeaderCard(
              title: r.title,
              pills: [
                PhPill.status('request', r.status),
                PhPill.status('priority', r.priority),
                PhPill(requestTypes[r.type]!, fg: const Color(0xFF1565C0), bg: AppColors.primary50),
              ],
            ),
            phGap(),
            if (r.status == 'waiting_approval')
              Row(
                children: [
                  Expanded(child: phGreenButton('Setujui', () => _run(_store.approveRequest(r), 'Permintaan disetujui'))),
                  const SizedBox(width: 8),
                  Expanded(child: phRedButton('Tolak', () => _reject(r))),
                ],
              ),
            if (r.status == 'approved') phGreenButton('Tandai selesai', () => _run(_store.completeRequest(r), 'Permintaan ditandai selesai')),
            PhSection(
              'Informasi',
              child: KvCard([
                ('Proyek', r.projectName),
                ('Client', _store.nameOf(r.customerId)),
                ('Diajukan', fmtDate(r.createdAt)),
                ('Lampiran', r.attachment),
                ('Ditinjau oleh', r.reviewedBy.isEmpty ? '-' : _store.nameOf(r.reviewedBy)),
                ('Disetujui oleh', r.approvedBy.isEmpty ? '-' : '${_store.nameOf(r.approvedBy)} (${fmtDateTime(r.approvedAt)})'),
                ('Diselesaikan oleh', r.completedBy.isEmpty ? '-' : '${_store.nameOf(r.completedBy)} (${fmtDateTime(r.completedAt)})'),
              ]),
            ),
            PhSection(
              'Deskripsi',
              child: PhCard(child: Text(r.description, style: const TextStyle(fontSize: 14, height: 1.5))),
            ),
            if (r.rejectionReason.isNotEmpty)
              PhSection(
                'Alasan penolakan',
                child: PhCard(
                  child: Text(r.rejectionReason, style: const TextStyle(fontSize: 14, color: Color(0xFFC62828))),
                ),
              ),
            PhSection(
              'Catatan marketing',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Catatan internal untuk client',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: BorderSide.none),
                    ),
                  ),
                  phGap(),
                  phSoftButton('Simpan catatan', () {
                    r.marketingNotes = _notes!.text;
                    phToast(context, 'Catatan tersimpan');
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ Approvals

const flowLabels = {'sequential': 'Berurutan', 'parallel_all': 'Semua harus setuju', 'any_of': 'Salah satu cukup', 'single': 'Satu approver'};

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final _store = PhStore.instance;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final pending = _store.pendingForMe;
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: phAppBar('Approvals', bottom: phTabBar(_tab, ['Untuk saya${pending > 0 ? ' ($pending)' : ''}', 'Diajukan saya', 'Riwayat'])),
        body: TabBarView(
          controller: _tab,
          children: [
            _list(_store.approvals.where((a) => a.mine && a.status == 'pending').toList()),
            _list(_store.approvals.where((a) => a.requestedBy == PhStore.meId).toList()),
            _list(_store.approvals.where((a) => a.status != 'pending').toList()),
          ],
        ),
      );
    },
  );

  Widget _list(List<Approval> list) => RefreshIndicator(
    onRefresh: _store.sync,
    child: list.isEmpty
        ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [PhEmpty(Icons.check_circle_outline, 'Tidak ada persetujuan di daftar ini')])
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final a = list[i];
              return PhListRow(
                title: '${a.module} · ${a.action}',
                subtitle: '${a.label}\nDiajukan oleh ${_store.nameOf(a.requestedBy)}',
                trailing: PhPill.status('approval', a.status),
                trailingNote: 'Batas ${fmtDate(a.expiresAt)}',
                onTap: () => context.push('/approval/${a.id}'),
              );
            },
          ),
  );
}

class ApprovalDetailScreen extends StatelessWidget {
  final int approvalId;
  const ApprovalDetailScreen({super.key, required this.approvalId});

  @override
  Widget build(BuildContext context) {
    final store = PhStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final a = store.approvalById(approvalId);
        if (a == null) return Scaffold(appBar: phAppBar('Persetujuan'), body: const PhEmpty(Icons.check_circle_outline, 'Persetujuan tidak ditemukan'));
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar('Detail Persetujuan'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40),
            children: [
              PhHeaderCard(
                title: '${a.module} · ${a.action}',
                pills: [PhPill.status('approval', a.status)],
                extra: Text(a.label, style: const TextStyle(fontSize: 13)),
              ),
              if (a.status == 'pending' && a.mine) ...[
                phGap(),
                Row(
                  children: [
                    Expanded(child: phGreenButton('Setujui', () => _decide(context, a, 'approved'))),
                    const SizedBox(width: 8),
                    Expanded(child: phRedButton('Tolak', () => _decide(context, a, 'rejected'))),
                  ],
                ),
              ],
              PhSection(
                'Informasi',
                child: KvCard([
                  ('Modul', a.module),
                  ('Aksi', a.action),
                  ('Diajukan oleh', store.nameOf(a.requestedBy)),
                  ('Alur approval', flowLabels[a.flowType]),
                  ('Kedaluwarsa', fmtDateTime(a.expiresAt)),
                  ('Keputusan', a.status == 'pending' ? '-' : statusLabel('approval', a.status)),
                ]),
              ),
              PhSection(
                'Langkah approval',
                child: PhCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < a.steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: a.steps[i].status == 'approved'
                                    ? AppColors.successBg
                                    : a.steps[i].status == 'rejected'
                                    ? AppColors.errorBg
                                    : AppColors.grey100,
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: store.nameOf(a.steps[i].approverId),
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                          ),
                                          TextSpan(
                                            text: ' (${a.steps[i].role})',
                                            style: const TextStyle(fontSize: 12, color: AppColors.grey700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    PhPill.status('approval', a.steps[i].status),
                                    if (a.steps[i].notes.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '"${a.steps[i].notes}"${a.steps[i].decidedAt.isEmpty ? '' : ' · ${fmtDateTime(a.steps[i].decidedAt)}'}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.grey700),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _decide(BuildContext context, Approval a, String decision) {
    openPhForm(
      context,
      PhFormConfig(
        title: decision == 'approved' ? 'Setujui' : 'Tolak',
        note: '${a.module} · ${a.action}: ${a.label}',
        saveLabel: decision == 'approved' ? 'Setujui' : 'Tolak',
        doneMessage: decision == 'approved' ? 'Persetujuan diberikan' : 'Pengajuan ditolak',
        fields: [PhField('notes', 'Catatan', type: PhFieldType.multiline, required: decision == 'rejected', hint: decision == 'rejected' ? 'Alasan penolakan' : 'Opsional')],
        onSave: (v) async {
          final store = PhStore.instance;
          if (a.isLocal) {
            store.applyApproval(a, decision, v['notes'] as String);
          } else {
            await store.decideApproval(a, decision, v['notes'] as String);
          }
          return null;
        },
      ),
    );
  }
}
