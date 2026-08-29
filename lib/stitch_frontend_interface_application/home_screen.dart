import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_theme.dart';
import 'app_mode.dart';
import 'projects_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'hris_screens.dart';
import 'widgets/app_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNav = 0;
  AppMode _mode = AppMode.taskManagement;

  List<Widget> get _screens {
    if (_mode == AppMode.hris) {
      return [
        const HrisDashboardBody(),
        const AttendanceScreen(),
        const LeaveScreen(),
        ProfileScreen(currentMode: _mode, onModeChanged: _changeMode),
      ];
    }
    return [
      const _DashboardBody(),
      const ProjectsScreen(),
      const TasksScreen(),
      ProfileScreen(currentMode: _mode, onModeChanged: _changeMode),
    ];
  }

  void _changeMode(AppMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _selectedNav, children: _screens),
      bottomNavigationBar: _FloatingNavBar(
        mode: _mode,
        selectedIndex: _selectedNav,
        onTap: (i) => setState(() => _selectedNav = i),
      ),
    );
  }
}

/// Bottom nav mengambang versi terang, sesuai referensi baru (putih, bukan
/// gelap seperti iterasi sebelumnya). Ikon menyesuaikan mode aplikasi
/// (Task Management atau HRIS) yang dipilih dari Profile.
class _FloatingNavBar extends StatelessWidget {
  final AppMode mode;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.mode,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _taskIcons = [
    AppIconType.home,
    AppIconType.folder,
    null,
    AppIconType.tasks,
    AppIconType.person,
  ];

  static const _hrisIcons = [
    AppIconType.home,
    AppIconType.fingerprint,
    null,
    AppIconType.leave,
    AppIconType.person,
  ];

  List<AppIconType?> get _icons =>
      mode == AppMode.hris ? _hrisIcons : _taskIcons;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: [
              BoxShadow(
                color: AppColors.grey900.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              if (i == 2) {
                return GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.heroStart,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.heroStart.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const AppIcon(
                      AppIconType.plus,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                );
              }
              final navIndex = i > 2 ? i - 1 : i;
              final selected = selectedIndex == navIndex;
              return IconButton(
                onPressed: () => onTap(navIndex),
                icon: AppIcon(
                  _icons[i]!,
                  color: selected ? AppColors.heroStart : AppColors.grey400,
                  size: 21,
                  strokeWidth: selected ? 2.0 : 1.7,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Dashboard body (tab index 0) ─────────────────────────────────────────────

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final List<Map<String, dynamic>> _quickActions = const [
    {'icon': 'assets/icons/project.svg', 'label': 'Proyek'},
    {'icon': 'assets/icons/task.svg', 'label': 'Tugas'},
    {'icon': 'assets/icons/team.svg', 'label': 'Tim'},
    {'icon': 'assets/icons/laporan.svg', 'label': 'Laporan'},
  ];

  final List<Map<String, dynamic>> _priorities = const [
    {
      'title': 'Backend API v2',
      'icon': 'assets/icons/code.svg',
      'meta': '18 tugas · 1 minggu',
      'progress': '40%',
    },
    {
      'title': 'Marketing Q2',
      'icon': 'assets/icons/campaign.svg',
      'meta': '10 tugas · 3 hari',
      'progress': '80%',
    },
  ];

  final List<Map<String, dynamic>> _activity = const [
    {'title': 'Wireframe onboarding', 'date': '12 Mei', 'done': true},
    {'title': 'Fix bug login Android', 'date': '10 Mei', 'done': false},
    {'title': 'Setup CI/CD pipeline', 'date': '8 Mei', 'done': true},
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          100,
        ),
        children: [
          _buildHeroCard(context),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle('Akses cepat'),
          const SizedBox(height: AppSpacing.sm),
          _buildQuickActions(),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader('Prioritas minggu ini'),
          const SizedBox(height: AppSpacing.sm),
          _buildPriorityRow(),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle('Aktivitas terbaru'),
          const SizedBox(height: AppSpacing.sm),
          ..._activity.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ActivityTile(activity: a),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroStart, AppColors.heroMid, AppColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
    Text(
                      'Tim Alpha',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    SizedBox(width: 2),
                    AppIcon(
                      AppIconType.chevronDown,
                      color: Colors.white,
                      size: 14,
                      strokeWidth: 2,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const AppIcon(
                AppIconType.bell,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              const CircleAvatar(
                radius: 13,
                backgroundColor: Colors.white,
                child: Text(
                  'P',
                  style: TextStyle(
                    color: AppColors.heroStart,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Halo, Panji',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ini progres proyek kamu hari ini',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 4,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const AppIcon(
                    AppIconType.folder,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '12 proyek',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'sedang berjalan',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 4,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Text(
                    '+ Proyek',
                    style: TextStyle(
                      color: AppColors.heroStart,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _tag('Aktif', AppColors.success, AppColors.successBg),
                          const SizedBox(width: 6),
                          _tag(
                            'Prioritas tinggi',
                            AppColors.error,
                            AppColors.errorBg,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Mobile App Redesign',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Sprint 3 · Tim mobile',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.grey500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Row(
                        children: [
                          AppIcon(
                            AppIconType.calendar,
                            size: 11,
                            color: AppColors.grey500,
                            strokeWidth: 1.4,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Deadline 20 Mei',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.grey500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const _ProgressRing(progress: 0.65),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _quickActions.map((a) {
        return GestureDetector(
          onTap: () {},
          child: Column(
            children: [
              SvgPicture.asset(
                a['icon'] as String,
                width: 56,
                height: 56,
              ),
              const SizedBox(height: 6),
              Text(
                a['label'] as String,
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SectionTitle(title),
        GestureDetector(
          onTap: () {},
          child: const Text(
            'Lihat semua',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.heroStart,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityRow() {
    return Row(
      children: _priorities.map((p) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: p == _priorities.first ? AppSpacing.sm : 0,
            ),
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.large),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(p['icon'] as String, width: 32, height: 32),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  p['title'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p['meta'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.grey500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  p['progress'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heroStart,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14),
    );
  }
}

/// Ring progress sederhana pakai CustomPaint — tidak butuh package tambahan.
class _ProgressRing extends StatelessWidget {
  final double progress;
  const _ProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(64, 64),
            painter: _RingPainter(progress: progress.clamp(0.0, 1.0)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey900,
                ),
              ),
              const Text(
                'selesai',
                style: TextStyle(fontSize: 8, color: AppColors.grey500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 7) / 2;

    final track = Paint()
      ..color = AppColors.grey100
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = AppColors.heroStart
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final done = activity['done'] == true;
    final color = done ? AppColors.success : AppColors.error;
    final bg = done ? AppColors.successBg : AppColors.errorBg;
    final icon = done ? 'assets/icons/check.svg' : 'assets/icons/alert.svg';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 4,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          SvgPicture.asset(icon, width: 34, height: 34),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey900,
                  ),
                ),
                Text(
                  activity['date'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.grey500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              done ? 'Selesai' : 'Terlambat',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
