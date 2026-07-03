import 'package:flutter/material.dart';
import 'app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                _buildProfileInfo(),
                const SizedBox(height: AppSpacing.md),
                _buildStatsRow(),
                const SizedBox(height: AppSpacing.md),
                _buildSection('Account', _accountItems()),
                const SizedBox(height: AppSpacing.md),
                _buildSection('Preferences', _preferenceItems()),
                const SizedBox(height: AppSpacing.md),
                _buildSection('Support', _supportItems()),
                const SizedBox(height: AppSpacing.md),
                _buildLogoutButton(),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppColors.heroStart,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroStart, AppColors.heroMid, AppColors.heroEnd],
            ),
          ),
        ),
      ),
      title: const Text('Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.heroStart, AppColors.heroEnd],
              ),
              border: Border.all(color: AppColors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.heroStart.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'PG',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Panji Giantoro',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.grey900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Product Manager',
            style: TextStyle(fontSize: 14, color: AppColors.grey700),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.grey400),
              const SizedBox(width: 2),
              const Text(
                'Jakarta, Indonesia',
                style: TextStyle(fontSize: 12, color: AppColors.grey400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Row(
          children: [
            _buildStatItem('12', 'Projects'),
            _buildDivider(),
            _buildStatItem('48', 'Tasks'),
            _buildDivider(),
            _buildStatItem('5', 'Teams'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.heroStart,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.grey700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => const SizedBox(width: AppSpacing.sm);

  Widget _buildSection(String title, List<_MenuItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.grey700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
                            ? const Radius.circular(AppRadius.medium)
                            : Radius.zero,
                        bottom: isLast
                            ? const Radius.circular(AppRadius.medium)
                            : Radius.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 4),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: item.color.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.small),
                              ),
                              child: Icon(item.icon,
                                  color: item.color, size: 20),
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
                              const Icon(Icons.chevron_right,
                                  color: AppColors.grey400, size: 20),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                          height: 1, indent: 68, color: AppColors.grey100),
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
            color: AppColors.heroStart),
        _MenuItem(
            icon: Icons.lock_outline,
            label: 'Change Password',
            color: AppColors.heroStart),
        _MenuItem(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            color: AppColors.heroStart,
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeColor: AppColors.heroStart,
            )),
      ];

  List<_MenuItem> _preferenceItems() => [
        _MenuItem(
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            color: AppColors.grey700,
            trailing: Switch(
              value: false,
              onChanged: (_) {},
              activeColor: AppColors.heroStart,
            )),
        _MenuItem(
            icon: Icons.language_outlined,
            label: 'Language',
            color: AppColors.grey700,
            trailing: const Text('Indonesian',
                style: TextStyle(fontSize: 13, color: AppColors.grey400))),
      ];

  List<_MenuItem> _supportItems() => [
        _MenuItem(
            icon: Icons.help_outline,
            label: 'Help Center',
            color: AppColors.info),
        _MenuItem(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            color: AppColors.info),
        _MenuItem(
            icon: Icons.info_outline,
            label: 'About Flovig',
            color: AppColors.info,
            trailing: const Text('v1.0.0',
                style: TextStyle(fontSize: 13, color: AppColors.grey400))),
      ];

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.logout, color: AppColors.error),
          label: const Text('Log Out',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            side: const BorderSide(color: AppColors.error, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
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
