import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'welcome_screen.dart';
import 'widgets/stat_card.dart';

// ── Dashboard body untuk mode HRIS (tab index 0) ────────────────────────────

class HrisDashboardBody extends StatelessWidget {
  const HrisDashboardBody({super.key});

  static const _quickActions = [
    {
      'icon': Icons.fingerprint,
      'label': 'Absen Masuk',
      'color': AppColors.heroStart,
      'bg': Color(0xFFEDE9FE),
    },
    {
      'icon': Icons.event_busy_outlined,
      'label': 'Ajukan Cuti',
      'color': AppColors.warning,
      'bg': AppColors.warningBg,
    },
    {
      'icon': Icons.receipt_long_outlined,
      'label': 'Slip Gaji',
      'color': AppColors.success,
      'bg': AppColors.successBg,
    },
    {
      'icon': Icons.badge_outlined,
      'label': 'Karyawan',
      'color': AppColors.info,
      'bg': Color(0xFFE3F2FD),
    },
  ];

  static const _activity = [
    {'title': 'Budi Santoso mengajukan cuti tahunan', 'time': '10 menit lalu'},
    {'title': 'Siti Rahma absen masuk pukul 08:02', 'time': '1 jam lalu'},
    {'title': 'Reza Pratama absen keluar pukul 17:05', 'time': '2 jam lalu'},
  ];

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => _logout(context),
            ),
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.accent400,
                child: Text(
                  'P',
                  style: TextStyle(
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
                const Text(
                  'Selamat pagi, Panji',
                  style: TextStyle(
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
                const SizedBox(height: AppSpacing.lg),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.4,
                  children: const [
                    StatCard(
                      value: '86',
                      label: 'Total Karyawan',
                      icon: Icons.groups_outlined,
                      color: AppColors.heroStart,
                    ),
                    StatCard(
                      value: '79',
                      label: 'Hadir Hari Ini',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                    StatCard(
                      value: '4',
                      label: 'Cuti Pending',
                      icon: Icons.event_busy_outlined,
                      color: AppColors.warning,
                    ),
                    StatCard(
                      value: '3',
                      label: 'Terlambat',
                      icon: Icons.schedule_outlined,
                      color: AppColors.error,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
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
                    return Column(
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
                          child: Icon(
                            a['icon'] as IconData,
                            color: a['color'] as Color,
                            size: 24,
                          ),
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
                    );
                  }).toList(),
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
                ..._activity.map(
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
                            a['title']!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.grey900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          a['time']!,
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

// ── Absensi (tab index 1 pada mode HRIS) ────────────────────────────────────

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  static const _records = [
    {
      'name': 'Budi Santoso',
      'checkIn': '08:00',
      'checkOut': '17:02',
      'status': 'Tepat Waktu',
    },
    {
      'name': 'Siti Rahma',
      'checkIn': '08:02',
      'checkOut': '17:00',
      'status': 'Tepat Waktu',
    },
    {
      'name': 'Reza Pratama',
      'checkIn': '08:41',
      'checkOut': '17:15',
      'status': 'Terlambat',
    },
    {
      'name': 'Dika Ramadhan',
      'checkIn': '07:55',
      'checkOut': '-',
      'status': 'Belum Pulang',
    },
    {
      'name': 'Hendra Wijaya',
      'checkIn': '-',
      'checkOut': '-',
      'status': 'Tidak Hadir',
    },
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'Tepat Waktu':
        return AppColors.success;
      case 'Terlambat':
        return AppColors.error;
      case 'Belum Pulang':
        return AppColors.info;
      default:
        return AppColors.grey500;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'Tepat Waktu':
        return AppColors.successBg;
      case 'Terlambat':
        return AppColors.errorBg;
      case 'Belum Pulang':
        return const Color(0xFFE3F2FD);
      default:
        return AppColors.grey100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
        title: const Text('Absensi'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.large),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  color: AppColors.heroStart,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    '79 dari 86 karyawan hadir hari ini',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _records.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final r = _records[i];
                final status = r['status']!;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.heroStart.withValues(
                          alpha: 0.12,
                        ),
                        child: Text(
                          r['name']!.substring(0, 1),
                          style: const TextStyle(
                            color: AppColors.heroStart,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['name']!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Masuk ${r['checkIn']}  ·  Keluar ${r['checkOut']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.grey500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusBg(status),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cuti & Izin (tab index 2 pada mode HRIS) ────────────────────────────────

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  static const _requests = [
    {
      'name': 'Budi Santoso',
      'type': 'Cuti Tahunan',
      'range': '10 - 12 Jul 2026',
      'status': 'Menunggu',
    },
    {
      'name': 'Siti Rahma',
      'type': 'Sakit',
      'range': '3 Jul 2026',
      'status': 'Disetujui',
    },
    {
      'name': 'Dika Ramadhan',
      'type': 'Izin',
      'range': '5 Jul 2026',
      'status': 'Disetujui',
    },
    {
      'name': 'Hendra Wijaya',
      'type': 'Cuti Tahunan',
      'range': '1 - 2 Jul 2026',
      'status': 'Ditolak',
    },
  ];

  Color _statusColor(String status) => switch (status) {
    'Disetujui' => AppColors.success,
    'Ditolak' => AppColors.error,
    _ => AppColors.warning,
  };

  Color _statusBg(String status) => switch (status) {
    'Disetujui' => AppColors.successBg,
    'Ditolak' => AppColors.errorBg,
    _ => AppColors.warningBg,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
        title: const Text('Cuti & Izin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final r = _requests[i];
          final status = r['status']!;
          return Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['name']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r['type']} · ${r['range']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
