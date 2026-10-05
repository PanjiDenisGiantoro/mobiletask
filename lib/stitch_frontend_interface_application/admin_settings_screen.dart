import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_theme.dart';

/// Menu admin/owner (Members, Organization & Access, Subscription & Billing,
/// System, Analytics manajemen) yang dipindah keluar dari sheet "Lainnya"
/// di Dashboard karena bukan menu harian untuk user biasa — diakses lewat
/// tab Profil supaya sheet cepat tetap ringkas.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        title: const Text('Admin & Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        children: [
          const Text(
            'Khusus admin/owner — kelola anggota, organisasi, dan sistem.',
            style: TextStyle(fontSize: 12.5, color: AppColors.grey500),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildGroup(context, 'Absensi', [
            _AdminItem(icon: Icons.schedule_rounded, label: 'Shift Kerja', accent: AppColors.heroStart, route: '/shift-settings'),
          ]),
          const SizedBox(height: AppSpacing.md),
          _buildGroup(context, 'Members', [
            _AdminItem(icon: Icons.badge_rounded, label: 'Employee', accent: AppColors.info, route: '/employees'),
            _AdminItem(icon: Icons.handshake_rounded, label: 'Clients', accent: AppColors.info),
          ]),
          const SizedBox(height: AppSpacing.md),
          _buildGroup(context, 'Analytics & Reporting', [
            _AdminItem(icon: Icons.speed_rounded, label: 'Workload', accent: AppColors.success),
            _AdminItem(icon: Icons.insights_rounded, label: 'Analytics', accent: AppColors.success),
          ]),
          const SizedBox(height: AppSpacing.md),
          _buildGroup(context, 'Organization & Access', [
            _AdminItem(icon: Icons.apartment_rounded, label: 'Perusahaan', accent: AppColors.primary600),
            _AdminItem(icon: Icons.admin_panel_settings_rounded, label: 'Roles', accent: AppColors.primary600),
            _AdminItem(icon: Icons.vpn_key_rounded, label: 'Permissions', accent: AppColors.primary600),
          ]),
          const SizedBox(height: AppSpacing.md),
          _buildGroup(context, 'Subscription & Billing', [
            _AdminItem(icon: Icons.payments_rounded, label: 'Payment History', accent: AppColors.warning),
          ]),
          const SizedBox(height: AppSpacing.md),
          _buildGroup(context, 'System', [
            _AdminItem(icon: Icons.history_rounded, label: 'Activity Logs', accent: AppColors.grey700),
            _AdminItem(icon: Icons.mark_email_unread_rounded, label: 'Notifikasi Email', accent: AppColors.grey700),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String title, List<_AdminItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.grey500,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isLast = i == items.length - 1;
              return Column(
                children: [
                  InkWell(
                    onTap: () => item.route != null
                        ? context.push(item.route!)
                        : _toast(context, 'Fitur ${item.label} akan segera hadir'),
                    borderRadius: BorderRadius.vertical(
                      top: i == 0 ? const Radius.circular(AppRadius.large) : Radius.zero,
                      bottom: isLast ? const Radius.circular(AppRadius.large) : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.small),
                            ),
                            child: Icon(item.icon, color: item.accent, size: 19),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.grey900,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.grey400, size: 20),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, indent: 68, color: AppColors.grey100),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _AdminItem {
  final IconData icon;
  final String label;
  final Color accent;
  final String? route;

  const _AdminItem({required this.icon, required this.label, required this.accent, this.route});
}
