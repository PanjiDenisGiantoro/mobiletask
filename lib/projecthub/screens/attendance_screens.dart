import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../stitch_frontend_interface_application/app_theme.dart';
import '../../stitch_frontend_interface_application/auth_repository.dart';
import '../../stitch_frontend_interface_application/shift_repository.dart';
import '../attendance_repository.dart';
import '../ph_format.dart';
import '../hris_remote.dart';
import '../ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';
import 'hris_submission_screens.dart' show ensureHrisLoaded, hrisBody;

final _store = PhStore.instance;
final _repo = AttendanceRepository.instance;

const _statusColors = {
  'hadir': Color(0xFF43A047),
  'alpha': Color(0xFFE53935),
  'izin': Color(0xFF1E88E5),
  'sakit': Color(0xFFFB8C00),
  'cuti': Color(0xFF7E57C2),
  'libur': Color(0xFF9E9E9E),
};

const _actionLabels = {
  'checkin_1': 'Absen Masuk',
  'checkout_1': 'Absen Keluar',
  'checkin_2': 'Absen Masuk Sesi 2',
  'checkout_2': 'Absen Keluar Sesi 2',
};

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  DateTime _teamDate = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _repo.loadToday();
    _repo.loadMonth(_month.year, _month.month);
    _repo.loadTeam(isoDate(_teamDate));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _repo,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: phAppBar('Absensi', bottom: phTabBar(_tab, const ['Hari Ini', 'Rekap', 'Tim'])),
          body: TabBarView(controller: _tab, children: [_today(context), _rekap(context), _team()]),
        ),
      );

  // ------------------------------------------------------------ Hari Ini
  Widget _today(BuildContext context) {
    final t = _repo.today;
    if (t == null) {
      return RefreshIndicator(
        onRefresh: _repo.loadToday,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          if (_repo.loading)
            const Padding(padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator()))
          else
            PhEmpty(Icons.fingerprint, _repo.error ?? 'Data absensi belum tersedia'),
        ]),
      );
    }
    final a = t.attendance;
    final shift = t.shift;
    final split = shift?.isSplit ?? false;
    final action = _actionLabels[t.state];
    final rules = t.rules;
    return RefreshIndicator(
      onRefresh: _repo.loadToday,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        children: [
          PhCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(longDay(DateTime.parse(t.date)), style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
              phGap(4),
              Row(children: [
                Expanded(child: Text(AuthRepository.instance.currentUser?.name ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                if (t.state == 'day_off')
                  const PhPill('Libur', fg: AppColors.grey700, bg: AppColors.grey100)
                else if (a?.checkIn.isEmpty ?? true)
                  const PhPill('Belum absen', fg: Color(0xFFB15600), bg: AppColors.warningBg)
                else
                  PhPill.status('attendance', a!.status),
              ]),
            ]),
          ),
          PhSection('Shift hari ini', child: shift == null
              ? const PhCard(child: Text('Anda belum punya shift. Hubungi admin HR.', style: TextStyle(fontSize: 13, color: AppColors.grey700)))
              : KvCard([
                  ('Shift', shift.name),
                  ('Jam kerja', shift.label),
                  ('Istirahat', shift.breakStart.isEmpty ? '-' : '${shift.breakStart} - ${shift.breakEnd}'),
                  ('Toleransi terlambat', '${shift.toleranceMinutes} menit'),
                  if (t.holiday.isNotEmpty) ('Hari libur', t.holiday),
                ])),
          PhSection('Validasi', child: KvCard([
            ('Lokasi', rules.locationEnabled ? 'Wajib, radius maksimum ${rules.maxDistanceMeters} m dari kantor' : 'Tidak diwajibkan'),
            ('Pengenalan wajah', rules.faceEnabled ? (rules.faceEnrolled ? 'Wajib, wajah terdaftar' : 'Wajib, wajah belum terdaftar') : 'Tidak diwajibkan'),
          ])),
          PhSection('Catatan kehadiran', child: KvCard([
            ('${split ? 'Sesi 1: ' : ''}Masuk', _time(a?.checkIn, a?.distanceIn)),
            ('${split ? 'Sesi 1: ' : ''}Keluar', _time(a?.checkOut, null)),
            if (split) ('Sesi 2: Masuk', _time(a?.checkIn2, null)),
            if (split) ('Sesi 2: Keluar', _time(a?.checkOut2, null)),
            if ((a?.notes ?? '').isNotEmpty) ('Keterangan', a!.notes),
          ])),
          phGap(AppSpacing.md),
          if (action != null)
            PhButton(_submitting ? 'Memproses...' : action, icon: Icons.fingerprint, onPressed: _submitting ? null : _absen)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: t.state == 'day_off'
                  ? const PhPill('Hari ini libur sesuai jadwal', fg: AppColors.grey700, bg: AppColors.grey100)
                  : const PhPill('Absensi hari ini selesai', fg: Color(0xFF2E7D32), bg: AppColors.successBg),
            ),
          PhSection('Lainnya', child: Column(children: [
            for (final e in [('Jadwal Shift', Icons.schedule, '/shift-schedule'), ('Hari Libur', Icons.event, '/holidays'), ('Pendaftaran Wajah', Icons.face_retouching_natural, '/faces')])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PhListRow(
                  leading: Icon(e.$2, color: AppColors.primary600),
                  title: e.$1,
                  trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
                  onTap: () => context.push(e.$3),
                ),
              ),
          ])),
        ],
      ),
    );
  }

  String _time(String? hhmm, int? distance) {
    if (hhmm == null || hhmm.isEmpty) return '-';
    return distance == null ? hhmm : '$hhmm · $distance m dari kantor';
  }

  Future<void> _absen() async {
    setState(() => _submitting = true);
    try {
      final message = await _repo.submit();
      if (mounted) phToast(context, message);
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ------------------------------------------------------------ Rekap
  /// Status satu tanggal dari data server. Tanggal kerja yang lewat tanpa
  /// data dibiarkan kosong (tidak ditebak sebagai alpha).
  String _statusFor(DateTime d, Map<String, AttendanceRecord> byDate) {
    final key = isoDate(d);
    final rec = byDate[key];
    if (rec != null) return rec.status;
    if (_repo.holidayOn(key) != null) return 'libur';
    return '';
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    if (_repo.monthRecords(_month.year, _month.month) == null) _repo.loadMonth(_month.year, _month.month);
  }

  Widget _rekap(BuildContext context) {
    final records = _repo.monthRecords(_month.year, _month.month);
    final byDate = {for (final r in records ?? const <AttendanceRecord>[]) r.date: r};
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // Minggu = 0
    final totals = {for (final k in _statusColors.keys) k: 0};
    final cells = <Widget>[for (var i = 0; i < lead; i++) const SizedBox()];
    for (var d = 1; d <= days; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final s = _statusFor(date, byDate);
      if (totals.containsKey(s)) totals[s] = totals[s]! + 1;
      final sel = isoDate(date) == isoDate(_selected);
      cells.add(InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selected = date),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: sel ? Border.all(color: AppColors.heroStart, width: 2) : null),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$d', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColors[s] ?? Colors.transparent)),
          ]),
        ),
      ));
    }
    final selKey = isoDate(_selected);
    final rec = byDate[selKey];
    final holiday = _repo.holidayOn(selKey);
    return RefreshIndicator(
      onRefresh: () => _repo.loadMonth(_month.year, _month.month),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        children: [
          PhCard(
            child: Column(children: [
              Row(children: [
                IconButton(tooltip: 'Bulan sebelumnya', icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                Expanded(child: Center(child: Text('${monthsLong[_month.month - 1]} ${_month.year}', style: const TextStyle(fontWeight: FontWeight.w700)))),
                IconButton(tooltip: 'Bulan berikutnya', icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
              ]),
              Row(children: [for (final w in const ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']) Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 11, color: AppColors.grey700))))]),
              phGap(4),
              if (records == null)
                const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
              else
                GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.05, children: cells),
              phGap(),
              Wrap(spacing: 12, runSpacing: 4, children: [
                for (final e in _statusColors.entries)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: e.value)),
                    const SizedBox(width: 5),
                    Text('${statusLabel('attendance', e.key)} ${totals[e.key]}', style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
                  ]),
              ]),
            ]),
          ),
          PhSection('Detail ${fmtDate(selKey)}', child: rec == null
              ? PhCard(child: Text(holiday != null ? 'Libur: $holiday' : 'Tidak ada data absensi untuk tanggal ini.', style: const TextStyle(fontSize: 13, color: AppColors.grey700)))
              : KvCard([
                  ('Status', PhPill.status('attendance', rec.status)),
                  ('Masuk', _time(rec.checkIn, rec.distanceIn)),
                  ('Keluar', _time(rec.checkOut, null)),
                  if (rec.checkIn2.isNotEmpty) ('Sesi 2', '${rec.checkIn2} - ${rec.checkOut2.isEmpty ? '?' : rec.checkOut2}'),
                  ('Catatan', rec.notes.isEmpty ? '-' : rec.notes),
                ])),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Tim
  Widget _team() {
    final team = _repo.team;
    (String, Color, Color) badge(AttendanceRecord? r) {
      if (r == null || r.checkIn.isEmpty) {
        return r == null ? ('Belum absen', AppColors.grey700, AppColors.grey100) : (statusLabel('attendance', r.status), const Color(0xFFC62828), AppColors.errorBg);
      }
      if (r.notes.contains('Telat')) return ('Terlambat', const Color(0xFFC62828), AppColors.errorBg);
      if (r.checkOut.isEmpty) return ('Belum pulang', const Color(0xFF1565C0), AppColors.primary50);
      return ('Hadir', const Color(0xFF2E7D32), AppColors.successBg);
    }

    return RefreshIndicator(
      onRefresh: () => _repo.loadTeam(isoDate(_teamDate)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        children: [
          PhCard(
            child: Row(children: [
              IconButton(
                tooltip: 'Hari sebelumnya',
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _teamDate = _teamDate.subtract(const Duration(days: 1)));
                  _repo.loadTeam(isoDate(_teamDate));
                },
              ),
              Expanded(child: Center(child: Text(longDay(_teamDate), style: const TextStyle(fontWeight: FontWeight.w700)))),
              IconButton(
                tooltip: 'Hari berikutnya',
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() => _teamDate = _teamDate.add(const Duration(days: 1)));
                  _repo.loadTeam(isoDate(_teamDate));
                },
              ),
            ]),
          ),
          phGap(AppSpacing.md),
          if (team == null)
            PhEmpty(Icons.groups_outlined, _repo.teamError ?? 'Memuat absensi tim...')
          else ...[
            PhCard(child: Row(children: [
              const Icon(Icons.groups, color: AppColors.heroStart, size: 26),
              const SizedBox(width: 12),
              Expanded(child: Text('${team.present} dari ${team.total} karyawan hadir', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
            ])),
            phGap(AppSpacing.md),
            for (final e in team.employees)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PhCard(
                  child: Row(children: [
                    CircleAvatar(backgroundColor: const Color(0xFFDCEBF7), child: Text(initials(e.$1), style: const TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w500, fontSize: 15))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        Text('Masuk ${_time(e.$2?.checkIn, null)}  ·  Keluar ${_time(e.$2?.checkOut, null)}', style: const TextStyle(fontSize: 13, color: AppColors.grey500)),
                      ]),
                    ),
                    Builder(builder: (_) {
                      final b = badge(e.$2);
                      return PhPill(b.$1, fg: b.$2, bg: b.$3);
                    }),
                  ]),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================ Jadwal Shift, Hari Libur, Wajah

const _scheduleModes = [('shift', 'Pakai shift tertentu'), ('off', 'Libur'), ('default', 'Kembali ke shift profil')];

class ShiftScheduleScreen extends StatefulWidget {
  const ShiftScheduleScreen({super.key});

  @override
  State<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  @override
  void initState() {
    super.initState();
    ensureHrisLoaded();
    ShiftRepository.instance.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_store, ShiftRepository.instance]),
        builder: (context, _) {
          final list = [..._store.schedules]..sort((a, b) => a.date.compareTo(b.date));
          final shifts = ShiftRepository.instance.shifts;
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: phAppBar('Jadwal Shift'),
            body: hrisBody(
              child: () => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(AppSpacing.md), children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text('Jadwal khusus per tanggal menimpa shift default di profil karyawan (2 bulan ke depan).', style: TextStyle(fontSize: 12.5, color: AppColors.grey700)),
                ),
                if (list.isEmpty) const PhEmpty(Icons.event, 'Belum ada jadwal khusus'),
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: PhListRow(
                      title: _store.nameOf(s.userId),
                      subtitle: fmtDate(s.date),
                      trailing: s.shiftId.isEmpty
                          ? const PhPill('Libur', fg: AppColors.grey700, bg: AppColors.grey100)
                          : PhPill(shifts.where((x) => x.id == s.shiftId).firstOrNull?.name ?? 'Shift #${s.shiftId}', fg: const Color(0xFF1565C0), bg: AppColors.primary50),
                    ),
                  ),
                if (_store.can('update absensi'))
                  PhButton('Atur jadwal', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openPhForm(
                        context,
                        PhFormConfig(
                          title: 'Atur Jadwal Shift',
                          doneMessage: 'Jadwal shift diperbarui',
                          fields: [
                            PhField('userId', 'Karyawan', type: PhFieldType.select, options: [for (final e in _store.employees.where((e) => e.isActive)) (e.id, e.name)]),
                            PhField('date', 'Tanggal', type: PhFieldType.date, required: true, initial: isoDate(DateTime.now())),
                            PhField('mode', 'Jadwal', type: PhFieldType.select, options: _scheduleModes, initial: 'shift'),
                            PhField('shiftId', 'Shift', type: PhFieldType.select, options: [for (final s in shifts.where((s) => s.isActive)) (s.id, '${s.name} (${s.range})')]),
                          ],
                          onSave: (v) async {
                            if ('${v['userId']}'.isEmpty) return 'Pilih karyawan';
                            if (v['mode'] == 'shift' && '${v['shiftId']}'.isEmpty) return 'Pilih shift';
                            await _store.saveSchedule('${v['userId']}', '${v['date']}', '${v['mode']}', '${v['shiftId']}');
                            return null;
                          },
                        ),
                      )),
              ]),
            ),
          );
        },
      );
}

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key});

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  @override
  void initState() {
    super.initState();
    ensureHrisLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final list = [..._store.holidays]..sort((a, b) => a.date.compareTo(b.date));
          final canEdit = _store.can('update absensi');
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: phAppBar('Hari Libur ${DateTime.now().year}'),
            body: hrisBody(
              child: () => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(AppSpacing.md), children: [
                if (list.isEmpty) const PhEmpty(Icons.event, 'Belum ada hari libur'),
                for (final h in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: PhListRow(
                      title: h.name,
                      subtitle: fmtDate(h.date),
                      trailing: !canEdit
                          ? null
                          : IconButton(
                              tooltip: 'Hapus ${h.name}',
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () async {
                                final ok = await phConfirm(context, title: 'Hapus hari libur?', message: '${h.name} (${fmtDate(h.date)}) akan dihapus.');
                                if (!ok || !context.mounted) return;
                                try {
                                  await _store.deleteHoliday(h);
                                  if (context.mounted) phToast(context, 'Hari libur dihapus');
                                } catch (e) {
                                  if (context.mounted) phToast(context, '$e');
                                }
                              },
                            ),
                    ),
                  ),
                if (canEdit)
                  PhButton('Tambah hari libur', icon: Icons.add, color: AppColors.primary50, fg: AppColors.primary800, onPressed: () => openPhForm(
                        context,
                        PhFormConfig(
                          title: 'Hari Libur',
                          doneMessage: 'Hari libur ditambahkan',
                          fields: const [PhField('date', 'Tanggal', type: PhFieldType.date, required: true), PhField('name', 'Nama hari libur', required: true)],
                          onSave: (v) async {
                            if (_store.holidays.any((h) => h.date == v['date'])) return 'Tanggal ini sudah terdaftar';
                            await _store.addHoliday('${v['date']}', '${v['name']}');
                            return null;
                          },
                        ),
                      )),
              ]),
            ),
          );
        },
      );
}

/// Status pendaftaran wajah dari server. Deskriptor wajah dibuat oleh
/// face-api.js di halaman web, jadi pendaftaran dilakukan lewat web.
class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
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
          appBar: phAppBar('Pendaftaran Wajah'),
          body: hrisBody(
            child: () => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(AppSpacing.md), children: [
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Pendaftaran wajah dilakukan di halaman web HRIS → Absensi → Pengaturan, karena deskriptor wajah dibuat oleh pemindai di browser. Di sini Anda bisa melihat siapa yang sudah terdaftar.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.grey700, height: 1.45),
                ),
              ),
              if (_store.employees.isEmpty) const PhEmpty(Icons.face_retouching_natural, 'Data karyawan tidak tersedia untuk akun Anda'),
              for (final e in _store.employees.where((e) => e.isActive))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: PhListRow(
                    leading: PhAvatar(e.id, size: 34),
                    title: e.name,
                    subtitle: e.faceEnrolled ? 'Wajah terdaftar' : 'Belum terdaftar',
                    trailing: e.faceEnrolled
                        ? const PhPill('Terdaftar', fg: Color(0xFF2E7D32), bg: AppColors.successBg)
                        : const PhPill('Belum', fg: AppColors.grey700, bg: AppColors.grey100),
                  ),
                ),
            ]),
          ),
        ),
      );
}

/// Buka form konfigurasi absensi setelah nilai terbaru dimuat dari server.
Future<void> openAttendanceSettingsForm(BuildContext context) async {
  try {
    final s = await _store.loadAttendanceSetting();
    if (context.mounted) await openPhForm(context, attendanceSettingsConfig(s));
  } catch (e) {
    if (context.mounted) phToast(context, '$e');
  }
}

/// Form konfigurasi absensi (tabel attendance_settings). Butuh izin "update absensi".
PhFormConfig attendanceSettingsConfig(Map<String, dynamic> s) => PhFormConfig(
      title: 'Konfigurasi Absensi',
      doneMessage: 'Konfigurasi tersimpan',
      fields: [
        PhField('isLocationEnabled', 'Validasi lokasi (GPS)', type: PhFieldType.toggle, initial: s['is_location_enabled'] == true),
        PhField('officeName', 'Nama kantor', initial: s['office_name']),
        PhField('officeLatitude', 'Latitude kantor', type: PhFieldType.number, initial: s['office_latitude']),
        PhField('officeLongitude', 'Longitude kantor', type: PhFieldType.number, initial: s['office_longitude']),
        PhField('maxDistanceMeters', 'Jarak maksimum', type: PhFieldType.number, unit: 'meter', initial: s['max_distance_meters'] ?? 100),
        PhField('requireLocationForCheckout', 'Wajib lokasi saat check-out', type: PhFieldType.toggle, initial: s['require_location_for_checkout'] == true),
        PhField('isFaceRecognitionEnabled', 'Pengenalan wajah', type: PhFieldType.toggle, initial: s['is_face_recognition_enabled'] == true),
        PhField('faceRecognitionThreshold', 'Sensitivitas (ambang jarak wajah, 0.3-0.9)', type: PhFieldType.number, initial: s['face_recognition_threshold'] ?? 0.55, hint: 'Makin kecil makin ketat.'),
        PhField('requireFaceForCheckout', 'Wajib wajah saat check-out', type: PhFieldType.toggle, initial: s['require_face_for_checkout'] == true),
      ],
      onSave: (v) async {
        if (v['isLocationEnabled'] == true && (double.tryParse('${v['officeLatitude']}') == null || double.tryParse('${v['officeLongitude']}') == null)) {
          return 'Isi latitude dan longitude kantor untuk validasi lokasi';
        }
        await _store.saveAttendanceSetting(v);
        await _repo.loadToday();
        return null;
      },
    );

/// Rute `/attendance-settings`: muat konfigurasi dari server lalu tampilkan form.
class AttendanceSettingsScreen extends StatelessWidget {
  const AttendanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _store.loadAttendanceSetting(),
        builder: (context, snap) {
          if (snap.hasData) return PhFormScreen(config: attendanceSettingsConfig(snap.data!));
          return Scaffold(
            appBar: phAppBar('Konfigurasi Absensi'),
            body: snap.hasError ? PhEmpty(Icons.lock_outline, '${snap.error}') : const Center(child: CircularProgressIndicator()),
          );
        },
      );
}
