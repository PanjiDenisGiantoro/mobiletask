import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../utils/sign_out.dart';
import '../data/attendance_repository.dart';
import '../data/hris_remote.dart';
import '../utils/ph_format.dart';
import '../data/ph_store.dart';
import '../widgets/ph_widgets.dart';
import '../widgets/stat_card.dart';

// ── Dashboard body untuk mode HRIS (tab index 0) ────────────────────────────

class HrisDashboardBody extends StatefulWidget {
  const HrisDashboardBody({super.key});

  @override
  State<HrisDashboardBody> createState() => _HrisDashboardBodyState();
}

class _HrisDashboardBodyState extends State<HrisDashboardBody> {
  @override
  void initState() {
    super.initState();
    final store = PhStore.instance;
    if (!store.hrisSynced) store.syncHris();
    AttendanceRepository.instance.loadTeam(isoDate(DateTime.now()));
  }

  static const _quickActions = [
    {
      'icon': 'assets/icons/illustrations/to_do.svg',
      'label': 'Absen Masuk',
      'route': '/attendance',
      'color': AppColors.heroStart,
      'bg': Color(0xFFEDE9FE),
    },
    {
      'icon': 'assets/icons/illustrations/calendar.svg',
      'label': 'Ajukan Cuti',
      'route': '/leave',
      'color': AppColors.warning,
      'bg': AppColors.warningBg,
    },
    {
      'icon': 'assets/icons/illustrations/revenue.svg',
      'label': 'Slip Gaji',
      'route': '/payroll',
      'color': AppColors.success,
      'bg': AppColors.successBg,
    },
    {
      'icon': 'assets/icons/illustrations/cv.svg',
      'label': 'Karyawan',
      'route': '/employees',
      'color': AppColors.info,
      'bg': Color(0xFFE3F2FD),
    },
  ];

  static const _services = [
    ('Absensi dan rekap', 'assets/icons/illustrations/to_do.svg', '/attendance'),
    ('Cuti & Izin', 'assets/icons/illustrations/calendar.svg', '/leave'),
    ('Lembur', 'assets/icons/illustrations/deadline.svg', '/overtime'),
    ('Reimburse', 'assets/icons/illustrations/file_management.svg', '/reimburse'),
    ('Kasbon', 'assets/icons/illustrations/notes.svg', '/kasbon'),
    ('Penggajian', 'assets/icons/illustrations/revenue.svg', '/payroll'),
    ('Data Karyawan', 'assets/icons/illustrations/cv.svg', '/employees'),
    ('Jadwal Shift', 'assets/icons/illustrations/timeline.svg', '/shift-schedule'),
    ('Hari Libur', 'assets/icons/illustrations/creativity.svg', '/holidays'),
    ('Pendaftaran Wajah', 'assets/icons/illustrations/human_source.svg', '/faces'),
    ('Konfigurasi Absensi', 'assets/icons/illustrations/gear.svg', '/attendance-settings'),
    ('Shift Kerja', 'assets/icons/illustrations/processing.svg', '/shift-settings'),
  ];
  /// Tiga pengajuan HRIS terbaru (cuti, lembur, reimburse) dari server.
  List<(String, String)> _activity(PhStore store) {
    final items = <(String, String, String)>[
      for (final l in store.leaveRequests.take(5)) (l.startDate, '${store.nameOf(l.userId)} mengajukan ${store.leaveType(l.leaveTypeId).name}', statusLabel('submission', l.status)),
      for (final o in store.overtimes.take(5)) (o.date, '${store.nameOf(o.userId)} mengajukan lembur ${o.totalHours} jam', statusLabel('submission', o.status)),
      for (final r in store.reimbursements.take(5)) (r.expenseDate, '${store.nameOf(r.userId)} klaim ${r.title}', statusLabel('submission', r.status)),
    ]..sort((x, y) => y.$1.compareTo(x.$1));
    return [for (final i in items.take(3)) (i.$2, '${fmtDate(i.$1)} · ${i.$3}')];
  }

  /// Pengajuan pending milik orang lain yang boleh diputuskan user ini.
  int _pendingForMe(PhStore store) {
    final me = PhStore.meId;
    return (store.can('approve leave') ? store.leaveRequests.where((e) => e.status == 'pending' && e.userId != me).length : 0) +
        (store.can('approve overtime') ? store.overtimes.where((e) => e.status == 'pending' && e.userId != me).length : 0) +
        (store.can('approve reimbursement') ? store.reimbursements.where((e) => e.status == 'pending' && e.userId != me).length : 0);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 11 ? 'Selamat pagi' : h < 15 ? 'Selamat siang' : h < 18 ? 'Selamat sore' : 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([PhStore.instance, AttendanceRepository.instance]),
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final store = PhStore.instance;
    final team = AttendanceRepository.instance.team;
    final name = AuthRepository.instance.currentUser?.name ?? '';
    final pending = _pendingForMe(store);
    final activity = _activity(store);
    String count(bool known, int n) => known ? '$n' : '-';
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 0,
          backgroundColor: AppColors.primary700,
          title: const Text(
            'Flovig HRIS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Log Out',
              onPressed: () => confirmSignOut(context),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.accent400,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}${name.isEmpty ? '' : ', ${name.split(' ').first}'}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ringkasan kepegawaian hari ini',
                  style: TextStyle(fontSize: 14, color: AppColors.grey700),
                ),
                if (store.hrisError != null && !store.hrisSynced)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: PhListRow(
                      leading: const Icon(Icons.lock_outline, color: AppColors.error),
                      title: store.hrisError!,
                      subtitle: 'Tarik untuk memuat ulang atau hubungi admin',
                      onTap: store.syncHris,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.4,
                  children: [
                    StatCard(
                      value: count(team != null || store.employees.isNotEmpty, team?.total ?? store.employees.length),
                      label: 'Total Karyawan',
                      icon: Icons.groups_outlined,
                      color: AppColors.heroStart,
                    ),
                    StatCard(
                      value: count(team != null, team?.present ?? 0),
                      label: 'Hadir Hari Ini',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                    StatCard(
                      value: count(store.hrisSynced, store.leaveRequests.where((l) => l.status == 'pending').length),
                      label: 'Cuti Pending',
                      icon: Icons.event_busy_outlined,
                      color: AppColors.warning,
                    ),
                    StatCard(
                      value: count(team != null, team?.employees.where((e) => e.$2?.notes.contains('Telat') ?? false).length ?? 0),
                      label: 'Terlambat',
                      icon: Icons.schedule_outlined,
                      color: AppColors.error,
                    ),
                  ],
                ),
                if (pending == 0)
                  const SizedBox(height: AppSpacing.lg)
                else
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                    child: PhListRow(
                      leading: const Icon(Icons.fact_check_outlined, color: AppColors.warning),
                      title: '$pending pengajuan menunggu persetujuan Anda',
                      subtitle: 'Cuti, lembur, dan reimburse',
                      trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
                      onTap: () => context.push(store.leaveRequests.any((e) => e.status == 'pending' && e.userId != PhStore.meId) ? '/leave' : store.overtimes.any((e) => e.status == 'pending' && e.userId != PhStore.meId) ? '/overtime' : '/reimburse'),
                    ),
                  ),
                const Text(
                  'Aksi Cepat',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey900,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _quickActions.map((a) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.push(a['route'] as String),
                      child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: a['bg'] as Color,
                            borderRadius: BorderRadius.circular(
                              AppRadius.large,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: SvgPicture.asset(a['icon'] as String, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a['label'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.grey700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Layanan HRIS',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey900,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 3.1,
                  children: [
                    for (final s in _services)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push(s.$3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            boxShadow: AppShadows.card,
                          ),
                          child: Row(
                            children: [
                              SvgPicture.asset(s.$2, width: 24, height: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.$1,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.grey900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Aktivitas Terbaru',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey900,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (activity.isEmpty)
                  const Text('Belum ada pengajuan.', style: TextStyle(fontSize: 13, color: AppColors.grey700)),
                ...activity.map(
                  (a) => Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm + 4),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle_notifications_outlined,
                          color: AppColors.heroStart,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            a.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.grey900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          a.$2,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
