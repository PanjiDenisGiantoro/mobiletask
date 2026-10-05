import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../data/hris_remote.dart';
import '../utils/ph_format.dart';
import '../data/ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';
import 'hris_submission_screens.dart' show ensureHrisLoaded, hrisBody;

final _store = PhStore.instance;

const bonusTypes = {'bonus': 'Bonus', 'thr': 'THR', 'gratifikasi': 'Gratifikasi', 'jasa_produksi': 'Jasa produksi', 'lainnya': 'Lainnya'};
const employmentTypes = {'tetap': 'Karyawan tetap', 'kontrak': 'Kontrak', 'outsourcing': 'Outsourcing', 'lainnya': 'Lainnya'};

// ============================================================ Penggajian

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    ensureHrisLoaded();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool get _admin => _store.can('view payroll');

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar('Penggajian', bottom: phTabBar(_tab, const ['Slip', 'Bonus', 'Gaji'])),
          body: TabBarView(controller: _tab, children: [
            hrisBody(child: () => _slips(context)),
            hrisBody(child: () => _bonuses(context)),
            hrisBody(child: () => _salaries(context)),
          ]),
        ),
      );

  Widget _slips(BuildContext context) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(AppSpacing.md), children: [
        if (_store.payrolls.isEmpty) const PhEmpty(Icons.receipt_long_outlined, 'Belum ada slip gaji'),
        for (final p in _store.payrolls)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhListRow(
              title: '${_admin ? '${_store.nameOf(p.userId)} · ' : ''}${monthsLong[p.month - 1]} ${p.year}',
              subtitle: 'Gaji bersih ${rp(p.gajiBersih)}',
              trailing: PhPill.status('payroll', p.status),
              trailingNote: 'Hadir ${p.hariHadir} dari ${p.hariKerja} hari',
              onTap: () => context.push('/payroll/${p.id}'),
            ),
          ),
        if (_store.can('generate payroll')) PhButton('Generate payroll', icon: Icons.calculate_outlined, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => _generateForm(context)),
      ]);

  Widget _bonuses(BuildContext context) => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(AppSpacing.md), children: [
        if (_store.bonuses.isEmpty) const PhEmpty(Icons.card_giftcard, 'Belum ada bonus'),
        for (final b in _store.bonuses)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhListRow(
              title: '${_store.nameOf(b.userId)} · ${bonusTypes[b.type] ?? b.type}',
              subtitle: '${b.description.isEmpty ? '' : '${b.description} · '}${monthsLong[b.month - 1]} ${b.year}',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(rp(b.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (_store.can('delete payroll'))
                  IconButton(
                    tooltip: 'Hapus bonus',
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    onPressed: () async {
                      final ok = await phConfirm(context, title: 'Hapus bonus?', message: '${bonusTypes[b.type]} ${rp(b.amount)} untuk ${_store.nameOf(b.userId)} akan dihapus.');
                      if (ok && context.mounted) await _guard(context, () => _store.deleteBonus(b), 'Bonus dihapus');
                    },
                  ),
              ]),
            ),
          ),
        if (_store.can('create payroll')) PhButton('Tambah bonus', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => _bonusForm(context)),
      ]);

  Widget _salaries(BuildContext context) {
    final ids = _admin ? [for (final e in _store.employees) e.id] : [PhStore.meId];
    return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(AppSpacing.md), children: [
      for (final id in ids)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Builder(builder: (context) {
            final s = _store.salaries[id];
            return PhListRow(
              title: _store.nameOf(id),
              subtitle: s == null
                  ? 'Data gaji belum diatur'
                  : 'Gaji pokok ${rp(s.gajiPokok)} · ${s.statusPajak} · BPJS Kes ${s.bpjsKesehatan ? 'Ya' : 'Tidak'} / TK ${s.bpjsKetenagakerjaan ? 'Ya' : 'Tidak'}',
              trailingNote: s == null ? null : 'berlaku ${fmtDate(s.effectiveDate)}',
              onTap: _store.can(s == null ? 'create payroll' : 'update payroll') ? () => _salaryForm(context, id) : null,
            );
          }),
        ),
    ]);
  }

  Future<void> _guard(BuildContext context, Future<void> Function() action, String done) async {
    try {
      await action();
      if (context.mounted) phToast(context, done);
    } catch (e) {
      if (context.mounted) phToast(context, '$e');
    }
  }

  List<(String, String)> get _staffOptions => [for (final e in _store.employees.where((e) => e.isActive)) (e.id, e.name)];

  void _generateForm(BuildContext context) {
    final now = DateTime.now();
    openPhForm(
      context,
      PhFormConfig(
        title: 'Generate Payroll',
        note: 'Dihitung server dari data gaji, absensi, lembur, reimburse, bonus, kasbon, dan pajak.',
        doneMessage: 'Payroll dibuat',
        fields: [
          PhField('userId', 'Karyawan', type: PhFieldType.select, options: _staffOptions),
          PhField('year', 'Tahun', type: PhFieldType.number, required: true, initial: now.year),
          PhField('month', 'Bulan (1-12)', type: PhFieldType.number, required: true, initial: now.month),
        ],
        onSave: (v) async {
          final m = int.tryParse('${v['month']}') ?? 0, y = int.tryParse('${v['year']}') ?? 0;
          if (m < 1 || m > 12) return 'Bulan harus 1 sampai 12';
          if ('${v['userId']}'.isEmpty) return 'Pilih karyawan';
          await _store.generatePayroll('${v['userId']}', y, m);
          return null;
        },
      ),
    );
  }

  void _bonusForm(BuildContext context) {
    final now = DateTime.now();
    openPhForm(
      context,
      PhFormConfig(
        title: 'Tambah Bonus',
        doneMessage: 'Bonus ditambahkan',
        fields: [
          PhField('userId', 'Karyawan', type: PhFieldType.select, options: _staffOptions),
          PhField('year', 'Tahun', type: PhFieldType.number, required: true, initial: now.year),
          PhField('month', 'Bulan (1-12)', type: PhFieldType.number, required: true, initial: now.month),
          PhField('type', 'Jenis', type: PhFieldType.select, options: [for (final e in bonusTypes.entries) (e.key, e.value)]),
          const PhField('amount', 'Jumlah (Rp)', type: PhFieldType.number, required: true),
          const PhField('description', 'Deskripsi'),
        ],
        onSave: (v) async {
          final m = int.tryParse('${v['month']}') ?? 0;
          if (m < 1 || m > 12) return 'Bulan harus 1 sampai 12';
          if ('${v['userId']}'.isEmpty) return 'Pilih karyawan';
          await _store.createBonus(v);
          return null;
        },
      ),
    );
  }

  void _salaryForm(BuildContext context, String userId) {
    final e = _store.salaries[userId];
    final ptkp = _store.ptkpOptions.isEmpty
        ? [for (final s in const ['TK/0', 'TK/1', 'TK/2', 'TK/3', 'K/0', 'K/1', 'K/2', 'K/3']) (s, s)]
        : [for (final o in _store.ptkpOptions.entries) (o.key, o.value)];
    openPhForm(
      context,
      PhFormConfig(
        title: 'Gaji ${_store.nameOf(userId)}',
        note: e == null ? '' : 'Ubah tanggal "Berlaku sejak" untuk mencatat periode gaji baru; tanggal sama memperbarui data yang ada.',
        doneMessage: 'Data gaji tersimpan',
        fields: [
          PhField('gajiPokok', 'Gaji pokok (Rp)', type: PhFieldType.number, required: true, initial: e?.gajiPokok),
          PhField('tunjanganTransport', 'Tunjangan transport (Rp)', type: PhFieldType.number, initial: e?.tunjanganTransport ?? 0),
          PhField('tunjanganMakan', 'Tunjangan makan (Rp)', type: PhFieldType.number, initial: e?.tunjanganMakan ?? 0),
          PhField('tunjanganJabatan', 'Tunjangan jabatan (Rp)', type: PhFieldType.number, initial: e?.tunjanganJabatan ?? 0),
          PhField('npwp', 'NPWP', initial: e?.npwp, hint: '00.000.000.0-000.000'),
          PhField('statusPajak', 'Status pajak (PTKP)', type: PhFieldType.select, options: ptkp, initial: e?.statusPajak ?? ptkp.first.$1),
          PhField('bpjsKesehatan', 'BPJS Kesehatan', type: PhFieldType.toggle, initial: e?.bpjsKesehatan ?? true),
          PhField('bpjsKetenagakerjaan', 'BPJS Ketenagakerjaan', type: PhFieldType.toggle, initial: e?.bpjsKetenagakerjaan ?? true),
          PhField('effectiveDate', 'Berlaku sejak', type: PhFieldType.date, required: true, initial: e?.effectiveDate ?? isoDate(DateTime.now())),
        ],
        onSave: (v) async {
          final newPeriod = e != null && v['effectiveDate'] != e.effectiveDate && _store.can('create payroll');
          await _store.saveSalary(userId, v, newPeriod: newPeriod);
          return null;
        },
      ),
    );
  }
}

class PayslipScreen extends StatelessWidget {
  final int payrollId;
  const PayslipScreen({super.key, required this.payrollId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _store, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final p = _store.payrolls.where((e) => e.id == payrollId).firstOrNull;
    if (p == null) return Scaffold(appBar: phAppBar('Slip Gaji'), body: const PhEmpty(Icons.receipt_long_outlined, 'Slip tidak ditemukan'));
    Widget block(String title, List<(String, String)> rows, {String? totalLabel, String? total}) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.large), boxShadow: phCardShadow),
            child: Column(children: [
              Container(width: double.infinity, color: AppColors.grey100, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey700, letterSpacing: 0.5))),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 13))),
                    const SizedBox(width: 8),
                    Text(r.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              if (total != null)
                Container(
                  color: AppColors.primary50,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Expanded(child: Text(totalLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    Text(total, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
        );
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Slip Gaji'),
      body: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40), children: [
        PhCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_store.nameOf(p.userId), style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
          Row(children: [Expanded(child: Text('${monthsLong[p.month - 1]} ${p.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))), PhPill.status('payroll', p.status)]),
          phGap(4),
          const Text('Gaji bersih', style: TextStyle(fontSize: 12, color: AppColors.grey700)),
          Text(rp(p.gajiBersih), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary800)),
          Text(p.paidAt.isEmpty ? 'Belum dibayar' : 'Dibayar ${fmtDateTime(p.paidAt)}', style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
        ])),
        block('Kehadiran', [('Hari kerja', '${p.hariKerja}'), ('Hari hadir', '${p.hariHadir}'), ('Hari cuti', '${p.hariCuti}'), ('Hari alpha', '${p.hariAlpha}')]),
        block('Pendapatan', [
          ('Gaji pokok', rp(p.gajiPokok)),
          ('Tunjangan transport', rp(p.tunjanganTransport)),
          ('Tunjangan makan', rp(p.tunjanganMakan)),
          ('Tunjangan jabatan', rp(p.tunjanganJabatan)),
          ('Tunjangan lainnya', rp(p.tunjanganLainnya)),
          if (p.tunjanganPph21 > 0) ('Tunjangan PPh21', rp(p.tunjanganPph21)),
          ('Bonus', rp(p.bonus)),
          ('Lembur', rp(p.lembur)),
          ('Reimburse', rp(p.reimburse)),
        ], totalLabel: 'Penghasilan bruto', total: rp(p.penghasilanBruto)),
        block('Potongan', [
          ('Potongan alpha', rp(p.potonganAlpha)),
          ('Potongan kasbon', rp(p.potonganKasbon)),
          ('BPJS Kesehatan', rp(p.potonganBpjsKes)),
          ('BPJS Ketenagakerjaan', rp(p.potonganBpjsTk)),
          ('PPh21${p.pph21Scheme.isEmpty ? '' : ' (${p.pph21Scheme})'}', rp(p.potonganPph21)),
          ('Potongan lainnya', rp(p.potonganLainnya)),
        ], totalLabel: 'Total potongan', total: rp(p.totalPotongan)),
        block('Tanggungan perusahaan', [('BPJS Kesehatan', rp(p.tanggunganBpjsKes)), ('BPJS Ketenagakerjaan', rp(p.tanggunganBpjsTk)), ('PPh21', rp(p.tanggunganPph21))], totalLabel: 'Total tanggungan', total: rp(p.totalTanggunganPerusahaan)),
        if (p.status == 'draft' && _store.can('update payroll')) ...[
          phGap(AppSpacing.md),
          phGreenButton('Finalisasi slip', () async {
            final ok = await phConfirm(context, title: 'Finalisasi slip?', message: 'Slip ${monthsLong[p.month - 1]} ${p.year} untuk ${_store.nameOf(p.userId)} tidak bisa diubah setelah final. Karyawan mendapat notifikasi.', confirm: 'Finalisasi');
            if (!ok || !context.mounted) return;
            try {
              await _store.finalizePayroll(p);
              if (context.mounted) phToast(context, 'Slip difinalisasi');
            } catch (e) {
              if (context.mounted) phToast(context, '$e');
            }
          }),
        ],
      ]),
    );
  }
}

// ============================================================ Data Karyawan

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    ensureHrisLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: _store, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = _store.employees.where((e) => q.isEmpty || e.name.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Data Karyawan'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan...',
              prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.grey100,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: hrisBody(child: () => list.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [PhEmpty(Icons.person_search, _store.can('view payroll') || _store.can('view absensi') ? 'Tidak ada karyawan yang cocok' : 'Anda tidak punya akses ke data karyawan')])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final e = list[i];
                    return PhListRow(
                      title: e.name,
                      subtitle: '${e.organizationUnit} · ${e.structuralLevel} · ${employmentTypes[e.employmentType] ?? e.employmentType}',
                      trailing: PhPill(e.isActive ? 'Aktif' : 'Nonaktif', fg: e.isActive ? const Color(0xFF2E7D32) : AppColors.grey700, bg: e.isActive ? AppColors.successBg : AppColors.grey100),
                      onTap: () => context.push('/employee/${e.id}'),
                    );
                  },
                )),
        ),
      ]),
    );
  }
}

class EmployeeDetailScreen extends StatelessWidget {
  final String employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context) {
    final e = _store.employeeById(employeeId);
    if (e == null) return Scaffold(appBar: phAppBar('Profil Karyawan'), body: const PhEmpty(Icons.person_off_outlined, 'Karyawan tidak ditemukan'));
    final salary = _store.salaries[e.id];
    final daysLeft = e.contractEndDate.isEmpty ? null : DateTime.tryParse(e.contractEndDate)?.difference(DateTime.now()).inDays;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Profil Karyawan'),
      body: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 40), children: [
        PhCard(child: Row(children: [
          PhAvatar(e.id, size: 52),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), Text('${e.structuralLevel} · ${e.organizationUnit}', style: const TextStyle(fontSize: 12, color: AppColors.grey700))])),
          PhPill(e.isActive ? 'Aktif' : 'Nonaktif', fg: e.isActive ? const Color(0xFF2E7D32) : AppColors.grey700, bg: e.isActive ? AppColors.successBg : AppColors.grey100),
        ])),
        PhSection('Data kepegawaian', child: KvCard([
          ('Email', e.email),
          ('Tipe kerja', employmentTypes[e.employmentType] ?? e.employmentType),
          ('Tanggal masuk', e.hireDate.isEmpty ? '-' : fmtDate(e.hireDate)),
          ('Akhir kontrak', e.contractEndDate.isEmpty ? '-' : '${fmtDate(e.contractEndDate)}${daysLeft == null ? '' : daysLeft >= 0 ? ' ($daysLeft hari lagi)' : ' (sudah berakhir)'}'),
          ('Unit organisasi', e.organizationUnit),
          ('Level struktural', e.structuralLevel),
          ('Shift', e.shiftName.isEmpty ? '-' : e.shiftName),
          ('Wajah', e.faceEnrolled ? 'Terdaftar' : 'Belum terdaftar'),
        ])),
        if (salary != null)
          PhSection('Gaji', child: KvCard([
            ('Gaji pokok', rp(salary.gajiPokok)),
            ('Tunjangan', rp(salary.tunjanganTransport + salary.tunjanganMakan + salary.tunjanganJabatan)),
            ('Status pajak', salary.statusPajak),
            ('Berlaku sejak', fmtDate(salary.effectiveDate)),
          ])),
      ]),
    );
  }
}
