import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_mode.dart';
import 'welcome_screen.dart';

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileCard(),
                const SizedBox(height: AppSpacing.lg),
                _buildModeSwitch(),
                const SizedBox(height: AppSpacing.lg),
                _buildSection('Account', _accountItems()),
                const SizedBox(height: AppSpacing.md),
                _buildSection('Preferences', _preferenceItems()),
                const SizedBox(height: AppSpacing.md),
                _buildSection('Support', _supportItems()),
                const SizedBox(height: AppSpacing.lg),
                _buildLogoutButton(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
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
      title: const Text(
        'Profile',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.heroStart, AppColors.heroEnd],
                    ),
                    border: Border.all(color: AppColors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.heroStart.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'PG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.heroStart,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Panji Giantoro',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.grey900,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.heroStart.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Text(
                'Product Manager',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heroStart,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: AppColors.grey400,
                ),
                const SizedBox(width: 2),
                const Text(
                  'Jakarta, Indonesia',
                  style: TextStyle(fontSize: 11, color: AppColors.grey400),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            const Divider(color: AppColors.grey100, height: 1),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                _buildStatItem('12', 'Projects'),
                _buildStatDivider(),
                _buildStatItem('48', 'Tasks'),
                _buildStatDivider(),
                _buildStatItem('5', 'Teams'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MODE APLIKASI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.grey500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                children: [
                  _buildModeOption(
                    icon: Icons.task_alt_rounded,
                    label: 'Task Management',
                    mode: AppMode.taskManagement,
                  ),
                  _buildModeOption(
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
    required IconData icon,
    required String label,
    required AppMode mode,
  }) {
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
                color: selected ? Colors.white : AppColors.grey500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.grey500,
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

  Widget _buildSection(String title, List<_MenuItem> items) {
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
                      onTap: () {},
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
                                color: item.color.withValues(alpha: 0.1),
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.grey900,
                                ),
                              ),
                            ),
                            if (item.trailing != null)
                              item.trailing!
                            else
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.grey400,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        indent: 68,
                        color: AppColors.grey100,
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

  List<_MenuItem> _accountItems() => [
    _MenuItem(
      icon: Icons.person_outline,
      label: 'Edit Profile',
      color: AppColors.heroStart,
    ),
    _MenuItem(
      icon: Icons.lock_outline,
      label: 'Change Password',
      color: AppColors.heroStart,
    ),
    _MenuItem(
      icon: Icons.notifications_outlined,
      label: 'Notifications',
      color: AppColors.heroStart,
      trailing: Switch(
        value: true,
        onChanged: (_) {},
        activeThumbColor: AppColors.heroStart,
      ),
    ),
  ];

  List<_MenuItem> _preferenceItems() => [
    _MenuItem(
      icon: Icons.dark_mode_outlined,
      label: 'Dark Mode',
      color: AppColors.grey700,
      trailing: Switch(
        value: false,
        onChanged: (_) {},
        activeThumbColor: AppColors.heroStart,
      ),
    ),
    _MenuItem(
      icon: Icons.language_outlined,
      label: 'Language',
      color: AppColors.grey700,
      trailing: const Text(
        'Indonesian',
        style: TextStyle(fontSize: 13, color: AppColors.grey400),
      ),
    ),
  ];

  List<_MenuItem> _supportItems() => [
    _MenuItem(
      icon: Icons.help_outline,
      label: 'Help Center',
      color: AppColors.info,
    ),
    _MenuItem(
      icon: Icons.privacy_tip_outlined,
      label: 'Privacy Policy',
      color: AppColors.info,
    ),
    _MenuItem(
      icon: Icons.info_outline,
      label: 'About Flovig',
      color: AppColors.info,
      trailing: const Text(
        'v1.0.0',
        style: TextStyle(fontSize: 13, color: AppColors.grey400),
      ),
    ),
  ];

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
          onTap: () => _logout(context),
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: AppColors.error, size: 18),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Log Out',
                  style: TextStyle(
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

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.trailing,
  });
}
