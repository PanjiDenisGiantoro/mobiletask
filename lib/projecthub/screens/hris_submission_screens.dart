import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../stitch_frontend_interface_application/app_theme.dart';
import '../hris_remote.dart';
import '../ph_format.dart';
import '../ph_models.dart';
import '../ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

final _store = PhStore.instance;

String _range(String a, String b) => a == b ? fmtDate(a) : '${fmtDate(a)} - ${fmtDate(b)}';
int _dayCount(String a, String b) {
  final s = DateTime.tryParse(a), e = DateTime.tryParse(b);
  if (s == null || e == null) return 0;
  final d = e.difference(s).inDays + 1;
  return d > 0 ? d : 0;
}

/// Muat data HRIS sekali saat layar HRIS pertama dibuka.
void ensureHrisLoaded() {
  if (!_store.hrisSynced && !_store.hrisSyncing) _store.syncHris();
}

/// Isi layar HRIS: tampilkan loading/galat sync (mis. paket HRIS tidak aktif)
/// atau [child] dengan tarik-untuk-muat-ulang.
Widget hrisBody({required Widget Function() child}) {
  if (!_store.hrisSynced) {
    return RefreshIndicator(
      onRefresh: _store.syncHris,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        if (_store.hrisError == null)
          const Padding(padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator()))
        else
          PhEmpty(Icons.lock_outline, _store.hrisError!),
      ]),
    );
  }
  return RefreshIndicator(onRefresh: _store.syncHris, child: child());
}

Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
  try {
    await action();
    if (context.mounted) phToast(context, done);
  } catch (e) {
    if (context.mounted) phToast(context, '$e');
  }
}

/// Tombol setuju/tolak yang membuka form catatan (alasan wajib saat menolak).
void _decide(BuildContext context, {required String title, required String decision, required Future<void> Function(String notes) apply}) {
  openPhForm(
    context,
    PhFormConfig(
      title: title,
      note: decision == 'approved' ? 'Pengajuan akan disetujui dan karyawan mendapat notifikasi.' : '',
      saveLabel: decision == 'approved' ? 'Setujui' : 'Tolak',
      doneMessage: decision == 'approved' ? 'Disetujui' : 'Ditolak',
      fields: [
        if (decision == 'rejected') const PhField('notes', 'Alasan penolakan', type: PhFieldType.multiline, required: true),
      ],
      onSave: (v) async {
        await apply('${v['notes'] ?? ''}');
        return null;
      },
    ),
  );
}

/// Baris aksi untuk pengajuan berstatus pending: pemilik bisa membatalkan,
/// approver (sesuai izin server) bisa menyetujui/menolak.
List<Widget> _pendingActions(
  BuildContext context, {
  required bool isMine,
  required bool canApprove,
  required String label,
  required Future<void> Function() cancel,
  required Future<void> Function(String decision, String notes) decide,
}) =>
    [
      phGap(),
      if (canApprove && !isMine)
        Row(children: [
          Expanded(child: phGreenButton('Setujui', () => _decide(context, title: 'Setujui $label', decision: 'approved', apply: (n) => decide('approved', n)))),
          const SizedBox(width: 8),
          Expanded(child: phRedButton('Tolak', () => _decide(context, title: 'Tolak $label', decision: 'rejected', apply: (n) => decide('rejected', n)))),
        ]),
      if (isMine)
        phRedButton('Batalkan pengajuan', () async {
          final ok = await phConfirm(context, title: 'Batalkan pengajuan?', message: 'Pengajuan $label ini akan dibatalkan.', confirm: 'Batalkan');
          if (ok && context.mounted) await _run(context, cancel, 'Pengajuan dibatalkan');
        }),
    ];

// ============================================================ Cuti & Izin

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    ensureHrisLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final b = _store.myAnnualBalance;
          final list = _store.leaveRequests.where((r) => _filter == 'all' || r.status == _filter).toList();
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: phAppBar('Cuti & Izin', actions: [if (_store.hrisSynced) IconButton(tooltip: 'Ajukan cuti', icon: const Icon(Icons.add), onPressed: () => openLeaveForm(context))]),
            body: Column(children: [
              PhChipBar(items: const [('all', 'Semua'), ('pending', 'Menunggu'), ('approved', 'Disetujui'), ('rejected', 'Ditolak')], selected: _filter, onSelected: (v) => setState(() => _filter = v)),
              Expanded(
                child: hrisBody(
                  child: () => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                    children: [
                      if (b != null)
                        PhSection(
                          'Saldo ${_store.leaveType(b.leaveTypeId).name} (${b.year})',
                          child: PhCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${b.remaining} hari tersisa', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary800)),
                              phGap(),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: (b.quota + b.carriedOver) == 0 ? 0 : (b.used / (b.quota + b.carriedOver)).clamp(0, 1).toDouble(),
                                  minHeight: 6,
                                  backgroundColor: AppColors.grey100,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.primary600),
                                ),
                              ),
                              phGap(),
                              Text('Kuota ${b.quota} · Dibawa dari tahun lalu ${b.carriedOver} · Terpakai ${b.used}', style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
                            ]),
                          ),
                        ),
                      PhSection(
                        'Pengajuan',
                        child: list.isEmpty
                            ? const PhEmpty(Icons.inbox_outlined, 'Belum ada pengajuan dengan status ini')
                            : Column(children: [
                                for (final r in list)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    child: PhListRow(
                                      title: _store.nameOf(r.userId),
                                      subtitle: '${_store.leaveType(r.leaveTypeId).name} · ${_range(r.startDate, r.endDate)} · ${r.totalDays} hari',
                                      trailing: PhPill.status('submission', r.status),
                                      onTap: () => context.push('/leave/${r.id}'),
                                    ),
                                  ),
                              ]),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          );
        },
      );
}

class LeaveDetailScreen extends StatelessWidget {
  final int requestId;
  const LeaveDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final r = _store.leaveRequests.where((e) => e.id == requestId).firstOrNull;
          if (r == null) return Scaffold(appBar: phAppBar('Detail Cuti'), body: const PhEmpty(Icons.inbox_outlined, 'Pengajuan tidak ditemukan'));
          final t = _store.leaveType(r.leaveTypeId);
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: phAppBar('Detail Cuti'),
            body: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40), children: [
              PhHeaderCard(title: _store.nameOf(r.userId), pills: [PhPill.status('submission', r.status), PhPill(t.name, fg: const Color(0xFF1565C0), bg: AppColors.primary50)]),
              if (r.status == 'pending')
                ..._pendingActions(
                  context,
                  isMine: r.userId == PhStore.meId,
                  canApprove: _store.can('approve leave'),
                  label: 'Cuti',
                  cancel: () => _store.cancelLeave(r),
                  decide: (d, n) => _store.decideLeave(r, d, n),
                ),
              PhSection('Informasi', child: KvCard([
                ('Jenis cuti', '${t.name}${t.code.isEmpty ? '' : ' (${t.code})'}'),
                ('Mulai', fmtDate(r.startDate)),
                ('Selesai', fmtDate(r.endDate)),
                ('Total hari kerja', '${r.totalDays} hari'),
                ('Dibayar', t.isPaid ? 'Ya' : 'Tidak'),
                ('Lampiran', r.attachment.isEmpty ? (t.needsAttachment ? 'Belum dilampirkan' : 'Tidak ada') : r.attachment.split('/').last),
                ('Diputuskan oleh', r.approvedBy.isEmpty ? '-' : _store.nameOf(r.approvedBy)),
              ])),
              PhSection('Alasan', child: PhCard(child: Text(r.reason, style: const TextStyle(fontSize: 14, height: 1.5)))),
              if (r.rejectionReason.isNotEmpty) PhSection('Alasan penolakan', child: PhCard(child: Text(r.rejectionReason, style: const TextStyle(fontSize: 14, color: Color(0xFFC62828))))),
            ]),
          );
        },
      );
}

/// Form pengajuan cuti. Total hari kerja, saldo, dan syarat jenis cuti
/// dihitung ulang oleh server (LeaveService).
void openLeaveForm(BuildContext context) {
  final types = _store.leaveTypes.where((t) => t.eligible).toList();
  final blocked = _store.leaveTypes.where((t) => !t.eligible && t.blockedMessage.isNotEmpty).map((t) => t.blockedMessage).toList();
  if (types.isEmpty) {
    phToast(context, blocked.isNotEmpty ? blocked.first : 'Belum ada jenis cuti yang bisa diajukan');
    return;
  }
  openPhForm(
    context,
    PhFormConfig(
      title: 'Ajukan Cuti',
      note: blocked.isEmpty ? '' : blocked.join('\n'),
      doneMessage: 'Pengajuan cuti dikirim',
      fields: [
        PhField('leaveTypeId', 'Jenis cuti', type: PhFieldType.select, options: [for (final t in types) ('${t.id}', '${t.name}${t.needsAttachment ? ' (wajib lampiran)' : ''}')], initial: '${types.first.id}'),
        const PhField('startDate', 'Tanggal mulai', type: PhFieldType.date, required: true),
        const PhField('endDate', 'Tanggal selesai', type: PhFieldType.date, required: true),
        const PhField('totalDays', 'Rentang tanggal', type: PhFieldType.number, unit: 'hari', readOnly: true, hint: 'Hari kerja dihitung server (tanpa akhir pekan).'),
        const PhField('reason', 'Alasan', type: PhFieldType.multiline, required: true),
        const PhField('attachment', 'Lampiran (surat dokter, dll)', type: PhFieldType.file),
      ],
      derive: (v) {
        final d = _dayCount('${v['startDate']}', '${v['endDate']}');
        return {'totalDays': d == 0 ? '' : '$d'};
      },
      onSave: (v) async {
        final t = _store.leaveType(int.parse(v['leaveTypeId'] as String));
        if (_dayCount(v['startDate'] as String, v['endDate'] as String) == 0) return 'Tanggal selesai harus sama atau setelah tanggal mulai';
        if (t.needsAttachment && v['attachmentFile'] == null) return 'Jenis ${t.name} wajib melampirkan dokumen';
        await _store.submitLeave(v);
        return null;
      },
    ),
  );
}

// ============================================================ Lembur

const dayTypeLabels = {'weekday': 'Hari kerja', 'weekend': 'Akhir pekan', 'holiday': 'Hari libur'};

class OvertimeScreen extends StatefulWidget {
  const OvertimeScreen({super.key});

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  @override
  void initState() {
    super.initState();
    ensureHrisLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar('Lembur'),
          floatingActionButton: _store.hrisSynced
              ? FloatingActionButton.extended(heroTag: 'overtime_fab', backgroundColor: AppColors.heroStart, foregroundColor: Colors.white, onPressed: () => openOvertimeForm(context), icon: const Icon(Icons.add), label: const Text('Ajukan Lembur'))
              : null,
          body: hrisBody(
            child: () => _store.overtimes.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [PhEmpty(Icons.schedule, 'Belum ada lembur')])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                    itemCount: _store.overtimes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final o = _store.overtimes[i];
                      return PhListRow(
                        title: '${_store.nameOf(o.userId)} · ${fmtDate(o.date)}',
                        subtitle: '${dayTypeLabels[o.dayType] ?? o.dayType} · ${o.startTime} - ${o.endTime} · ${_hours(o.totalHours)} jam',
                        trailing: PhPill.status('submission', o.status),
                        trailingNote: o.totalAmount > 0 ? rp(o.totalAmount) : 'dihitung saat disetujui',
                        onTap: () => context.push('/overtime/${o.id}'),
                      );
                    },
                  ),
          ),
        ),
      );
}

String _hours(double h) => h == h.roundToDouble() ? '${h.round()}' : h.toString().replaceAll('.', ',');

class OvertimeDetailScreen extends StatelessWidget {
  final int overtimeId;
  const OvertimeDetailScreen({super.key, required this.overtimeId});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final o = _store.overtimes.where((e) => e.id == overtimeId).firstOrNull;
          if (o == null) return Scaffold(appBar: phAppBar('Detail Lembur'), body: const PhEmpty(Icons.schedule, 'Lembur tidak ditemukan'));
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: phAppBar('Detail Lembur'),
            body: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40), children: [
              PhCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_store.nameOf(o.userId), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                phGap(6),
                PhPill.status('submission', o.status),
                phGap(6),
                Text(o.totalAmount > 0 ? rp(o.totalAmount) : 'Upah dihitung saat disetujui', style: TextStyle(fontSize: o.totalAmount > 0 ? 26 : 14, fontWeight: FontWeight.w700, color: AppColors.primary800)),
              ])),
              if (o.status == 'pending')
                ..._pendingActions(
                  context,
                  isMine: o.userId == PhStore.meId,
                  canApprove: _store.can('approve overtime'),
                  label: 'Lembur',
                  cancel: () => _store.cancelOvertime(o),
                  decide: (d, n) => _store.decideOvertime(o, d, n),
                ),
              PhSection('Informasi', child: KvCard([
                ('Tanggal', fmtDate(o.date)),
                ('Jenis hari', dayTypeLabels[o.dayType] ?? o.dayType),
                ('Jam', '${o.startTime} - ${o.endTime}'),
                ('Total jam', '${_hours(o.totalHours)} jam'),
                ('Upah sejam', o.hourlyWage > 0 ? rp(o.hourlyWage) : '-'),
                ('Total upah', o.totalAmount > 0 ? rp(o.totalAmount) : '-'),
                ('Diputuskan oleh', o.approvedBy.isEmpty ? '-' : _store.nameOf(o.approvedBy)),
              ])),
              if (o.breakdown.isNotEmpty) PhSection('Rincian perhitungan', child: _Breakdown(o.breakdown, o.totalAmount)),
              if (o.description.isNotEmpty) PhSection('Deskripsi', child: PhCard(child: Text(o.description, style: const TextStyle(fontSize: 14)))),
              if (o.rejectionReason.isNotEmpty) PhSection('Alasan penolakan', child: PhCard(child: Text(o.rejectionReason, style: const TextStyle(fontSize: 14, color: Color(0xFFC62828))))),
            ]),
          );
        },
      );
}

class _Breakdown extends StatelessWidget {
  final List<OvertimeLine> lines;
  final int total;
  const _Breakdown(this.lines, this.total);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.large), boxShadow: phCardShadow),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (final l in lines)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [Expanded(child: Text('${l.label}: ${_hours(l.hours)} jam × ${l.multiplier}', style: const TextStyle(fontSize: 13))), Text(rp(l.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))])),
          Container(color: AppColors.primary50, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))), Text(rp(total), style: const TextStyle(fontWeight: FontWeight.w700))])),
        ]),
      );
}

/// Form pengajuan lembur. Jenis hari dan perkiraan upah dihitung server
/// dari tanggal, hari libur perusahaan, gaji pokok, dan overtime_rules.
void openOvertimeForm(BuildContext context) {
  openPhForm(
    context,
    PhFormConfig(
      title: 'Ajukan Lembur',
      doneMessage: 'Pengajuan lembur dikirim',
      fields: [
        PhField('date', 'Tanggal', type: PhFieldType.date, required: true, initial: isoDate(DateTime.now())),
        const PhField('startTime', 'Jam mulai', type: PhFieldType.time, required: true, initial: '18:00'),
        const PhField('endTime', 'Jam selesai', type: PhFieldType.time, required: true, initial: '20:00'),
        const PhField('preview', '', type: PhFieldType.info),
        const PhField('description', 'Deskripsi pekerjaan', type: PhFieldType.multiline, required: true),
      ],
      preview: (v) => _OvertimePreview(date: '${v['date']}', start: '${v['startTime']}', end: '${v['endTime']}'),
      onSave: (v) async {
        final a = _minutes('${v['startTime']}'), b = _minutes('${v['endTime']}');
        if (a == null || b == null || b <= a) return 'Jam selesai harus setelah jam mulai (lembur lewat tengah malam diajukan per hari)';
        await _store.submitOvertime(v);
        return null;
      },
    ),
  );
}

/// Perkiraan upah lembur dari server; dimuat ulang saat tanggal/jam berubah.
class _OvertimePreview extends StatefulWidget {
  final String date, start, end;
  const _OvertimePreview({required this.date, required this.start, required this.end});

  @override
  State<_OvertimePreview> createState() => _OvertimePreviewState();
}

class _OvertimePreviewState extends State<_OvertimePreview> {
  Future<Map<String, dynamic>>? _future;
  String _key = '';

  void _load() {
    final key = '${widget.date}|${widget.start}|${widget.end}';
    if (key == _key) return;
    _key = key;
    final a = _minutes(widget.start), b = _minutes(widget.end);
    _future = (a == null || b == null || b <= a || widget.date.isEmpty) ? null : _store.previewOvertime(widget.date, widget.start, widget.end);
  }

  @override
  Widget build(BuildContext context) {
    _load();
    final f = _future;
    if (f == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>>(
      future: f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const PhCard(child: Text('Menghitung perkiraan...', style: TextStyle(fontSize: 13)));
        if (snap.hasError) return PhCard(child: Text('${snap.error}', style: const TextStyle(fontSize: 13, color: AppColors.error)));
        final p = snap.data!;
        final hours = (p['total_hours'] as num?)?.toDouble() ?? 0;
        final day = dayTypeLabels['${p['day_type']}'] ?? '${p['day_type']}';
        if (p['has_salary'] != true) {
          return PhCard(child: Text('$day · ${_hours(hours)} jam. Upah belum bisa diperkirakan karena data gaji Anda belum diatur HR.', style: const TextStyle(fontSize: 13)));
        }
        return PhCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Perkiraan: $day, ${_hours(hours)} jam, upah sejam ${rp((p['upah_sejam'] as num?)?.round() ?? 0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          for (final l in (p['breakdown'] as List? ?? const [])) Text('${l['label']}: ${_hours((l['hours'] as num).toDouble())} jam × ${l['multiplier']}', style: const TextStyle(fontSize: 13)),
          Text('Total ${rp((p['total'] as num?)?.round() ?? 0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]));
      },
    );
  }
}

int? _minutes(String hhmmText) {
  final p = hhmmText.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
  return (h == null || m == null) ? null : h * 60 + m;
}

// ============================================================ Reimburse

const reimburseCategories = {'transport': 'Transport', 'makan': 'Makan', 'akomodasi': 'Akomodasi', 'medis': 'Medis', 'pulsa': 'Pulsa', 'lainnya': 'Lainnya'};

class ReimburseScreen extends StatefulWidget {
  const ReimburseScreen({super.key});

  @override
  State<ReimburseScreen> createState() => _ReimburseScreenState();
}

class _ReimburseScreenState extends State<ReimburseScreen> {
  @override
  void initState() {
    super.initState();
    ensureHrisLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar('Reimburse'),
          floatingActionButton: _store.hrisSynced
              ? FloatingActionButton.extended(heroTag: 'reimburse_fab', backgroundColor: AppColors.heroStart, foregroundColor: Colors.white, onPressed: () => openReimburseForm(context), icon: const Icon(Icons.add), label: const Text('Klaim Baru'))
              : null,
          body: hrisBody(
            child: () => _store.reimbursements.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [PhEmpty(Icons.receipt_long_outlined, 'Belum ada klaim')])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                    itemCount: _store.reimbursements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final r = _store.reimbursements[i];
                      return PhListRow(title: r.title, subtitle: '${_store.nameOf(r.userId)} · ${reimburseCategories[r.category] ?? r.category} · ${fmtDate(r.expenseDate)}', trailing: PhPill.status('submission', r.status), trailingNote: rp(r.amount), onTap: () => context.push('/reimburse/${r.id}'));
                    },
                  ),
          ),
        ),
      );
}

class ReimburseDetailScreen extends StatelessWidget {
  final int reimburseId;
  const ReimburseDetailScreen({super.key, required this.reimburseId});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final r = _store.reimbursements.where((e) => e.id == reimburseId).firstOrNull;
          if (r == null) return Scaffold(appBar: phAppBar('Detail Reimburse'), body: const PhEmpty(Icons.receipt_long_outlined, 'Klaim tidak ditemukan'));
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: phAppBar('Detail Reimburse'),
            body: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40), children: [
              PhCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                phGap(6),
                PhPill.status('submission', r.status),
                phGap(6),
                Text(rp(r.amount), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary800)),
              ])),
              if (r.status == 'pending')
                ..._pendingActions(
                  context,
                  isMine: r.userId == PhStore.meId,
                  canApprove: _store.can('approve reimbursement'),
                  label: 'Klaim',
                  cancel: () => _store.cancelReimbursement(r),
                  decide: (d, n) => _store.decideReimbursement(r, d, n),
                ),
              PhSection('Informasi', child: KvCard([
                ('Pengaju', _store.nameOf(r.userId)),
                ('Kategori', reimburseCategories[r.category] ?? r.category),
                ('Tanggal biaya', fmtDate(r.expenseDate)),
                ('Bukti', r.receipt.isEmpty ? 'Belum dilampirkan' : r.receipt.split('/').last),
                ('Diputuskan oleh', r.approvedBy.isEmpty ? '-' : _store.nameOf(r.approvedBy)),
                ('Masuk penggajian', r.inPayroll ? 'Ya' : 'Belum'),
              ])),
              if (r.receipt.isNotEmpty && RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(r.receipt))
                PhSection('Foto bukti', child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.large), child: Image.network(r.receipt, fit: BoxFit.cover, errorBuilder: (_, _, _) => const PhCard(child: Text('Gambar bukti tidak dapat dimuat', style: TextStyle(fontSize: 13)))))),
              if (r.description.isNotEmpty) PhSection('Deskripsi', child: PhCard(child: Text(r.description, style: const TextStyle(fontSize: 14)))),
              if (r.rejectionReason.isNotEmpty) PhSection('Alasan penolakan', child: PhCard(child: Text(r.rejectionReason, style: const TextStyle(fontSize: 14, color: Color(0xFFC62828))))),
            ]),
          );
        },
      );
}

/// Form klaim reimburse. Foto struk diunggah ke server (maks 2 MB).
void openReimburseForm(BuildContext context) {
  openPhForm(
    context,
    PhFormConfig(
      title: 'Klaim Reimburse',
      doneMessage: 'Klaim dikirim',
      fields: [
        PhField('category', 'Kategori', type: PhFieldType.select, options: [for (final e in reimburseCategories.entries) (e.key, e.value)]),
        const PhField('title', 'Judul', required: true),
        const PhField('description', 'Deskripsi', type: PhFieldType.multiline),
        PhField('expenseDate', 'Tanggal biaya', type: PhFieldType.date, required: true, initial: isoDate(DateTime.now())),
        const PhField('amount', 'Jumlah (Rp)', type: PhFieldType.number, required: true),
        const PhField('receipt', 'Foto bukti / struk', type: PhFieldType.file),
      ],
      onSave: (v) async {
        final amount = int.tryParse('${v['amount']}') ?? 0;
        if (amount <= 0) return 'Jumlah harus lebih dari nol';
        final file = v['receiptFile'] as PhPickedFile?;
        if (file != null && file.bytes.length > 2 * 1024 * 1024) return 'Ukuran foto bukti maksimal 2 MB';
        await _store.submitReimbursement(v);
        return null;
      },
    ),
  );
}

// ============================================================ Kasbon

class KasbonScreen extends StatefulWidget {
  const KasbonScreen({super.key});

  @override
  State<KasbonScreen> createState() => _KasbonScreenState();
}

class _KasbonScreenState extends State<KasbonScreen> {
  @override
  void initState() {
    super.initState();
    ensureHrisLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar('Kasbon'),
          floatingActionButton: _store.can('create payroll')
              ? FloatingActionButton.extended(heroTag: 'kasbon_fab', backgroundColor: AppColors.heroStart, foregroundColor: Colors.white, onPressed: () => _openForm(context), icon: const Icon(Icons.add), label: const Text('Kasbon Baru'))
              : null,
          body: hrisBody(
            child: () => _store.kasbons.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [PhEmpty(Icons.payments_outlined, 'Belum ada kasbon')])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                    itemCount: _store.kasbons.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final k = _store.kasbons[i];
                      return PhListRow(title: '${_store.nameOf(k.userId)} · ${rp(k.jumlah)}', subtitle: 'Cicilan ${rp(k.cicilanPerBulan)}/bulan · sisa ${rp(k.sisa)}', trailing: PhPill.status('kasbon', k.status), trailingNote: fmtDate(k.tanggal), onTap: () => context.push('/kasbon/${k.id}'));
                    },
                  ),
          ),
        ),
      );

  void _openForm(BuildContext context) {
    final staff = _store.employees.where((e) => e.isActive).toList();
    openPhForm(
      context,
      PhFormConfig(
        title: 'Kasbon Baru',
        note: 'Dipotong otomatis dari gaji tiap periode payroll.',
        doneMessage: 'Kasbon dicatat',
        fields: [
          PhField('userId', 'Karyawan', type: PhFieldType.select, options: [for (final e in staff) (e.id, e.name)]),
          PhField('tanggal', 'Tanggal', type: PhFieldType.date, required: true, initial: isoDate(DateTime.now())),
          const PhField('jumlah', 'Jumlah (Rp)', type: PhFieldType.number, required: true),
          const PhField('cicilanPerBulan', 'Cicilan per bulan (Rp)', type: PhFieldType.number, required: true),
          const PhField('keterangan', 'Keterangan'),
        ],
        onSave: (v) async {
          final jumlah = int.tryParse('${v['jumlah']}') ?? 0, cicilan = int.tryParse('${v['cicilanPerBulan']}') ?? 0;
          if ('${v['userId']}'.isEmpty) return 'Pilih karyawan';
          if (jumlah <= 0 || cicilan <= 0) return 'Jumlah dan cicilan harus lebih dari nol';
          if (cicilan > jumlah) return 'Cicilan tidak boleh melebihi jumlah kasbon';
          await _store.createKasbon(v);
          return null;
        },
      ),
    );
  }
}

class KasbonDetailScreen extends StatelessWidget {
  final int kasbonId;
  const KasbonDetailScreen({super.key, required this.kasbonId});

  @override
  Widget build(BuildContext context) {
    final k = _store.kasbons.where((e) => e.id == kasbonId).firstOrNull;
    if (k == null) return Scaffold(appBar: phAppBar('Detail Kasbon'), body: const PhEmpty(Icons.payments_outlined, 'Kasbon tidak ditemukan'));
    final pct = k.jumlah == 0 ? 0 : ((k.jumlah - k.sisa) / k.jumlah * 100).round();
    final canDelete = _store.can('delete payroll') && k.sisa == k.jumlah;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Detail Kasbon', actions: [
        if (canDelete)
          IconButton(
            tooltip: 'Hapus kasbon',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await phConfirm(context, title: 'Hapus kasbon?', message: 'Kasbon ${rp(k.jumlah)} untuk ${_store.nameOf(k.userId)} akan dihapus.');
              if (!ok || !context.mounted) return;
              await _run(context, () => _store.deleteKasbon(k), 'Kasbon dihapus');
              if (context.mounted) context.pop();
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40), children: [
        PhCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(_store.nameOf(k.userId), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))), PhPill.status('kasbon', k.status)]),
          phGap(6),
          Text(rp(k.sisa), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary800)),
          Text('sisa dari ${rp(k.jumlah)}', style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
          phGap(),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct / 100, minHeight: 6, backgroundColor: AppColors.grey100, valueColor: const AlwaysStoppedAnimation(AppColors.primary600))),
          phGap(4),
          Text('Terbayar $pct%', style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
        ])),
        PhSection('Informasi', child: KvCard([
          ('Tanggal', fmtDate(k.tanggal)),
          ('Jumlah', rp(k.jumlah)),
          ('Cicilan per bulan', rp(k.cicilanPerBulan)),
          ('Sisa', rp(k.sisa)),
          ('Periode potongan terakhir', k.periodeTerakhir.isEmpty ? '-' : k.periodeTerakhir),
          ('Potongan periode terakhir', rp(k.potonganPeriodeTerakhir)),
          ('Keterangan', k.keterangan.isEmpty ? '-' : k.keterangan),
        ])),
      ]),
    );
  }
}
