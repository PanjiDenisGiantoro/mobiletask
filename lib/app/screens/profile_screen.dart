import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_strings.dart';
import '../services/push_notification_service.dart';
import '../theme/app_settings.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import '../data/auth_repository.dart';
import '../utils/sign_out.dart';
import '../data/task_repository.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../widgets/ph_widgets.dart';

class ProfileScreen extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;

  const ProfileScreen({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: RefreshIndicator(
        onRefresh: PhStore.instance.sync,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            PhStore.instance,
            TaskRepository.instance,
            AppSettings.instance,
          ]),
          builder: (context, _) => CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, s),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildProfileCard(context, s),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(context, s.sectionAccount, _accountItems(context, s)),
                    const SizedBox(height: AppSpacing.md),
                    _buildSection(context, s.sectionAdmin, _adminItems(context, s)),
                    const SizedBox(height: AppSpacing.md),
                    _buildSection(context, s.sectionPreferences, _preferenceItems(context, s)),
                    const SizedBox(height: AppSpacing.md),
                    _buildSection(context, s.sectionSupport, _supportItems(context, s)),
                    const SizedBox(height: AppSpacing.lg),
                    _buildLogoutButton(context, s),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, S s) {
    return SliverAppBar(
      expandedHeight: 20,
      pinned: true,
      backgroundColor: AppColors.heroStart,
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppRadius.xl),
            bottomRight: Radius.circular(AppRadius.xl),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.heroStart,
                      AppColors.heroMid,
                      AppColors.heroEnd,
                    ],
                  ),
                ),
              ),
              Positioned(right: -30, top: -20, child: _decorCircle(120, 0.10)),
              Positioned(left: -20, bottom: -30, child: _decorCircle(90, 0.10)),
              Positioned(right: 60, bottom: 10, child: _decorCircle(24, 0.16)),
            ],
          ),
        ),
      ),
      title: Text(
        s.navProfile,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _decorCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, S s) {
    final c = context.colors;
    final user = AuthRepository.instance.currentUser;
    final raw = user?.raw;
    final rawImgs = raw != null ? extractUserImages(raw) : const <String>[];
    final storeUser = PhStore.instance.users[PhStore.meId];
    final imgs = storeUser != null && storeUser.images.isNotEmpty ? storeUser.images : rawImgs;
    final url = storeUser != null && storeUser.photoUrl.isNotEmpty
        ? storeUser.photoUrl
        : (imgs.isNotEmpty ? imgs.first : '');
    final roleLabel = (user?.roles ?? const ['Member'])
        .map((r) => r.isEmpty ? 'Member' : r[0].toUpperCase() + r.substring(1))
        .join(', ');

    final projCount = PhStore.instance.projects.length;
    final taskCount = TaskRepository.instance.tasks.where((t) => t.assignedTo == PhStore.meId).length;
    final teamCount = PhStore.instance.projects.where((p) => p.members.any((m) => m.userId == PhStore.meId)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: c.isDark
                    ? [AppColors.darkSurface, AppColors.darkSurfaceElevated]
                    : [Colors.white, const Color(0xFFEFF6FF)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: c.border),
              boxShadow: c.cardShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '-',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roleLabel,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: c.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => context.push('/profile/edit'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary600,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(s.editProfile, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => context.push('/profile/edit'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.surface,
                          border: Border.all(color: AppColors.primary200, width: 2),
                        ),
                        child: PhAvatar(PhStore.meId, size: 78, imageUrl: url, images: imgs),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.grey900,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.surface, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _heroStatPill(context, Icons.folder_copy_outlined, '$projCount', s.projects)),
              const SizedBox(width: 8),
              Expanded(child: _heroStatPill(context, Icons.task_alt_rounded, '$taskCount', s.tasks)),
              const SizedBox(width: 8),
              Expanded(child: _heroStatPill(context, Icons.groups_outlined, '$teamCount', s.teams)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStatPill(BuildContext context, IconData icon, String value, String label) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.isDark ? AppColors.primary600 : AppColors.grey900,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.textPrimary)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitch(BuildContext context, S s) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.appMode,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                children: [
                  _buildModeOption(
                    context: context,
                    icon: Icons.task_alt_rounded,
                    label: 'Task Management',
                    mode: AppMode.taskManagement,
                  ),
                  _buildModeOption(
                    context: context,
                    icon: Icons.badge_outlined,
                    label: 'HRIS',
                    mode: AppMode.hris,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required AppMode mode,
  }) {
    final c = context.colors;
    final selected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.heroStart : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.heroStart.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : c.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.grey900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.grey500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 26, color: AppColors.grey100);
  }

  Widget _buildSection(BuildContext context, String title, List<_MenuItem> items) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: c.isDark ? Border.all(color: c.border) : null,
              boxShadow: c.cardShadow,
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isLast = i == items.length - 1;
                return Column(
                  children: [
                    InkWell(
                      onTap: item.onTap,
                      borderRadius: BorderRadius.vertical(
                        top: i == 0
                            ? const Radius.circular(AppRadius.large)
                            : Radius.zero,
                        bottom: isLast
                            ? const Radius.circular(AppRadius.large)
                            : Radius.zero,
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
                                color: item.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.small,
                                ),
                              ),
                              child: Icon(
                                item.icon,
                                color: item.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            if (item.trailing != null)
                              item.trailing!
                            else
                              Icon(
                                Icons.chevron_right,
                                color: c.textFaint,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 68,
                        color: c.surfaceAlt,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<_MenuItem> _accountItems(BuildContext context, S s) => [
    _MenuItem(
      icon: Icons.person_outline,
      label: s.editProfile,
      color: AppColors.heroStart,
      onTap: () => context.push('/profile/edit'),
    ),
    _MenuItem(
      icon: Icons.lock_outline,
      label: s.changePassword,
      color: AppColors.heroStart,
      onTap: () => context.push('/profile/edit?focus=password'),
    ),
    _MenuItem(
      icon: Icons.notifications_outlined,
      label: s.notifications,
      color: AppColors.heroStart,
      trailing: Switch(
        value: AppSettings.instance.notificationsEnabled,
        onChanged: (v) async {
          await AppSettings.instance.setNotificationsEnabled(v);
          if (v) {
            await PushNotificationService.instance.syncTokenWithBackend();
          } else {
            await PushNotificationService.instance.unregisterTokenFromBackend();
          }
        },
        activeThumbColor: AppColors.heroStart,
      ),
    ),
  ];

  List<_MenuItem> _adminItems(BuildContext context, S s) => [
    _MenuItem(
      icon: Icons.admin_panel_settings_rounded,
      label: s.adminAndSettings,
      color: AppColors.primary600,
      onTap: () => context.push('/admin-settings'),
    ),
  ];

  List<_MenuItem> _preferenceItems(BuildContext context, S s) {
    final settings = AppSettings.instance;
    final c = context.colors;
    return [
      _MenuItem(
        icon: Icons.dark_mode_outlined,
        label: s.darkMode,
        color: c.isDark ? AppColors.primary400 : AppColors.grey700,
        onTap: () => settings.setDarkMode(!settings.isDarkMode),
        trailing: Switch(
          value: settings.isDarkMode,
          onChanged: (v) => settings.setDarkMode(v),
          activeThumbColor: AppColors.heroStart,
        ),
      ),
      _MenuItem(
        icon: Icons.language_outlined,
        label: s.language,
        color: c.isDark ? AppColors.primary400 : AppColors.grey700,
        onTap: () => _showLanguagePicker(context, s),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.languageName,
              style: TextStyle(fontSize: 13, color: c.textFaint, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: c.textFaint, size: 20),
          ],
        ),
      ),
    ];
  }

  Future<void> _showLanguagePicker(BuildContext context, S s) async {
    final c = context.colors;
    final current = AppSettings.instance.languageCode;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  s.chooseLanguage,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _langOptionTile(
                  context: sheetCtx,
                  flag: '🇮🇩',
                  title: s.indonesian,
                  subtitle: 'Bahasa Indonesia (ID)',
                  selected: current == 'id',
                  onTap: () async {
                    await AppSettings.instance.setLanguage('id');
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                ),
                const SizedBox(height: 8),
                _langOptionTile(
                  context: sheetCtx,
                  flag: '🇺🇸',
                  title: s.english,
                  subtitle: 'English (EN)',
                  selected: current == 'en',
                  onTap: () async {
                    await AppSettings.instance.setLanguage('en');
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _langOptionTile({
    required BuildContext context,
    required String flag,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: c.primary, size: 22),
          ],
        ),
      ),
    );
  }

  List<_MenuItem> _supportItems(BuildContext context, S s) => [
    _MenuItem(
      icon: Icons.help_outline,
      label: s.helpCenter,
      color: AppColors.info,
      onTap: () => context.push('/help-center'),
    ),
    _MenuItem(
      icon: Icons.privacy_tip_outlined,
      label: s.privacyPolicy,
      color: AppColors.info,
      onTap: () => context.push('/privacy-policy'),
    ),
    _MenuItem(
      icon: Icons.info_outline,
      label: s.aboutFlovig,
      color: AppColors.info,
      onTap: () => _showAboutDialog(context, s),
      trailing: const Text(
        'v1.0.0',
        style: TextStyle(fontSize: 13, color: AppColors.grey400),
      ),
    ),
  ];

  void _showAboutDialog(BuildContext context, S s) {
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/images/flovig_logo.png', width: 36, height: 36),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flovig', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary)),
                Text('v1.0.0', style: TextStyle(fontSize: 12, color: c.textMuted)),
              ],
            ),
          ],
        ),
        content: Text(
          S.tr(
            'Platform kolaborasi proyek, manajemen tugas, HRIS, dan penagihan perusahaan oleh PT Arunika Solusi Inovasi.',
            'Project collaboration, task management, HRIS, and billing platform by PT Arunika Solusi Inovasi.',
          ),
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(S.tr('Tutup', 'Close')),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, S s) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
          onTap: () => confirmSignOut(context),
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: c.errorBg,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout, color: AppColors.error, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  s.logOut,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.trailing,
    this.onTap,
  });
}

/// Fallback avatar (inisial nama) selagi foto profil dari jaringan dimuat
/// atau gagal diambil.
class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'PG',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
