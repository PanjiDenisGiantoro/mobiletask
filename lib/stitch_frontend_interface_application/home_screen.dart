import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'app_theme.dart';
import 'app_mode.dart';
import 'add_task_form_sheet.dart';
import 'projects_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'hris_screens.dart';
import '../projecthub/chat_remote.dart';
import '../projecthub/ph_format.dart';
import '../projecthub/ph_models.dart';
import '../projecthub/ph_remote.dart';
import '../projecthub/ph_store.dart';
import 'task_repository.dart';
import '../projecthub/screens/ph_screens.dart';
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

  /// Tombol "+" di tengah bottom nav: mode Task Management langsung buka
  /// form "Tugas Baru", mode HRIS buka menu Absen/Cuti.
  void _onAddTap() {
    if (_mode == AppMode.hris) {
      _openHrisQuickMenu();
    } else {
      showAddTaskFormSheet(context);
    }
  }

  void _openHrisQuickMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        void pushLater(String path) {
          Navigator.of(sheetContext).pop();
          context.push(path);
        }

        return _MoreMenuSheet(
          title: 'Aksi Cepat',
          sections: [
            _MoreMenuSection(
              title: 'Kehadiran',
              entries: [
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/to_do.svg',
                  label: 'Absen Masuk/Keluar',
                  accent: AppColors.error,
                  onTap: () => pushLater('/attendance'),
                ),
              ],
            ),
            _MoreMenuSection(
              title: 'Pengajuan',
              entries: [
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/calendar.svg',
                  label: 'Ajukan Cuti',
                  accent: AppColors.heroStart,
                  onTap: () => pushLater('/leave'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/deadline.svg',
                  label: 'Ajukan Lembur',
                  accent: AppColors.heroStart,
                  onTap: () => pushLater('/overtime'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/file_management.svg',
                  label: 'Klaim Reimburse',
                  accent: AppColors.heroStart,
                  onTap: () => pushLater('/reimburse'),
                ),
              ],
            ),
          ],
        );
      },
    );
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
        onAddTap: _onAddTap,
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
  final VoidCallback onAddTap;

  const _FloatingNavBar({
    required this.mode,
    required this.selectedIndex,
    required this.onTap,
    required this.onAddTap,
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
                  onTap: onAddTap,
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
//
// Layout mengikuti referensi super-app (search bar + banner promo + kartu
// statistik mengambang + grid menu cepat + banner achievement + kartu
// reward/rating), disesuaikan dengan konten Flovig (proyek/tugas/tim).

class _QuickMenuItem {
  final String svgAsset;
  final String label;
  final Color accent;
  final String? badge;
  final VoidCallback? onTap;

  const _QuickMenuItem({
    required this.svgAsset,
    required this.label,
    required this.accent,
    this.badge,
    this.onTap,
  });
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  bool _showStreakCard = true;
  bool _showRatingCard = true;
  int _ratingStars = 0;

  late final PageController _favProjectsController;
  late int _favProjectsPage;

  static const _favIcons = [
    Icons.design_services_rounded,
    Icons.code_rounded,
    Icons.campaign_rounded,
    Icons.language_rounded,
  ];

  /// Proyek aktif dari API (maks. 4) untuk carousel "Proyek Favorit".
  List<Map<String, dynamic>> get _favoriteProjects {
    final active = PhStore.instance.projects.where((p) => p.status == 'active').take(4).toList();
    return [
      for (var i = 0; i < active.length; i++)
        {
          'id': active[i].id,
          'title': active[i].name,
          'category': active[i].category,
          'icon': _favIcons[i % _favIcons.length],
          'progress': _progressOf(active[i]),
          'done': active[i].doneTasks,
          'total': active[i].totalTasks,
        },
    ];
  }

  static double _progressOf(Project p) =>
      p.totalTasks > 0 ? p.doneTasks / p.totalTasks : p.progress / 100;

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PhStore.instance.addListener(_onStoreChanged);
    TaskRepository.instance.addListener(_onStoreChanged);
    ChatRepository.instance.addListener(_onStoreChanged);
    if (!PhStore.instance.synced) PhStore.instance.sync();
    ChatRepository.instance.loadInbox();
    // Rentang halaman besar & semu-tak-terbatas supaya carousel bisa digeser
    // terus ke kiri maupun kanan. 4992 habis dibagi 1–4 (jumlah proyek
    // favorit yang mungkin), jadi halaman awal selalu proyek pertama.
    const loopStart = 4992;
    _favProjectsPage = loopStart;
    _favProjectsController = PageController(
      viewportFraction: 0.74,
      initialPage: loopStart,
    );
  }

  @override
  void dispose() {
    PhStore.instance.removeListener(_onStoreChanged);
    TaskRepository.instance.removeListener(_onStoreChanged);
    ChatRepository.instance.removeListener(_onStoreChanged);
    _favProjectsController.dispose();
    super.dispose();
  }

  static const _priorityIcons = [
    'assets/icons/illustrations/laptop_management.svg',
    'assets/icons/illustrations/presentation.svg',
  ];

  /// Dua proyek aktif dengan tenggat terdekat.
  List<Map<String, dynamic>> get _priorities {
    final today = isoDate(DateTime.now());
    final list = PhStore.instance.projects
        .where((p) => p.status == 'active' && p.endDate.isNotEmpty && p.endDate.compareTo(today) >= 0)
        .toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    return [
      for (var i = 0; i < list.length && i < 2; i++)
        {
          'id': list[i].id,
          'title': list[i].name,
          'icon': _priorityIcons[i],
          'meta': '${list[i].totalTasks} tugas · ${DateTime.parse(list[i].endDate).difference(DateTime.parse(today)).inDays} hari',
          'progress': '${(_progressOf(list[i]) * 100).round()}%',
        },
    ];
  }

  /// Tiga task terbaru dari API.
  List<Map<String, dynamic>> get _activity => [
        for (final t in TaskRepository.instance.tasks.take(3))
          {'title': t.title, 'date': t.dueDate.isEmpty ? '-' : fmtDate(t.dueDate), 'done': t.done},
      ];

  String? get _openTaskBadge {
    final me = PhStore.meId;
    final n = TaskRepository.instance.tasks.where((t) => !t.done && t.assignedTo == me).length;
    return n == 0 ? null : '$n';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<_QuickMenuItem> get _menuItems => [
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/project_management.svg',
          label: 'Proyek',
          accent: AppColors.info,
          badge: PhStore.instance.projects.isEmpty ? null : '${PhStore.instance.projects.length}',
          onTap: () => context.push('/projects'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/task.svg',
          label: 'Tugas',
          accent: AppColors.warning,
          badge: _openTaskBadge,
          onTap: () => context.push('/tasks'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/human_source.svg',
          label: 'Tim',
          accent: AppColors.heroStart,
          badge: 'Live',
          onTap: () => _toast('Fitur Tim akan segera hadir'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/pie_chart.svg',
          label: 'Laporan',
          accent: AppColors.success,
          onTap: () => context.push('/reports'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/calendar.svg',
          label: 'Kalender',
          accent: AppColors.accent400,
          onTap: () => context.push('/calendar'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/brainstorming.svg',
          label: 'Chat',
          accent: AppColors.primary600,
          badge: ChatRepository.instance.totalUnread == 0 ? null : '${ChatRepository.instance.totalUnread}',
          onTap: () => context.push('/messages'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/stamp.svg',
          label: 'Persetujuan',
          accent: AppColors.error,
          badge: PhStore.instance.pendingForMe == 0 ? null : '${PhStore.instance.pendingForMe}',
          onTap: () => context.push('/approvals'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/organize.svg',
          label: 'Lainnya',
          accent: AppColors.grey500,
          onTap: _openMoreMenu,
        ),
      ];

  void _openMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        void close() => Navigator.of(sheetContext).pop();
        void toastLater(String message) {
          close();
          _toast(message);
        }
        void pushLater(String path) {
          close();
          context.push(path);
        }

        return _MoreMenuSheet(
          sections: [
            _MoreMenuSection(
              title: 'Workspace',
              entries: [
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/calendar.svg',
                  label: 'Calendar',
                  accent: AppColors.heroStart,
                  onTap: () => pushLater('/calendar'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/presentation.svg',
                  label: 'Meetings',
                  accent: AppColors.heroStart,
                  onTap: () => toastLater('Fitur Meetings akan segera hadir'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/web.svg',
                  label: 'Global Search',
                  accent: AppColors.heroStart,
                  onTap: () => toastLater('Fitur Global Search akan segera hadir'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/productive.svg',
                  label: 'Aktivitas Kerja',
                  accent: AppColors.heroStart,
                  onTap: () => toastLater('Fitur Aktivitas Kerja akan segera hadir'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/notes.svg',
                  label: 'Requests',
                  accent: AppColors.heroStart,
                  onTap: () => pushLater('/requests'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/stamp.svg',
                  label: 'Approvals',
                  accent: AppColors.heroStart,
                  onTap: () => pushLater('/approvals'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/review.svg',
                  label: 'Bug Tickets',
                  accent: AppColors.heroStart,
                  onTap: () => pushLater('/tickets'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/revenue.svg',
                  label: 'Invoices',
                  accent: AppColors.heroStart,
                  onTap: () => toastLater('Fitur Invoices akan segera hadir'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/pie_chart.svg',
                  label: 'Reports',
                  accent: AppColors.heroStart,
                  onTap: () => pushLater('/reports'),
                ),
              ],
            ),
            _MoreMenuSection(
              title: 'Lainnya',
              entries: [
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/gear.svg',
                  label: 'Admin & Pengaturan',
                  accent: AppColors.primary600,
                  onTap: () => pushLater('/admin-settings'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _buildTopBanner(context),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildStatsCard(context),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMenuGrid(),
                  const SizedBox(height: AppSpacing.md),
                  _buildAiAssistantPromo(),
                  const SizedBox(height: AppSpacing.md),
                  _buildAchievementBanner(context),
                  if (_showStreakCard) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildStreakCard(),
                  ],
                  if (_showRatingCard) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildRatingCard(),
                  ],
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
            ),
          ),
        ],
      ),
    );
  }

  /// Background ungu (search bar + kartu promo), meniru banner atas pada
  /// referensi super-app — cuma warnanya disesuaikan ke brand Flovig.
  Widget _buildTopBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 60),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroStart, AppColors.heroMid, AppColors.heroEnd],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _buildSearchRow(context),
          ),
          const SizedBox(height: AppSpacing.md),
          // Carousel dibiarkan penuh lebar container (tidak dibatasi
          // padding md) supaya kartu sebelum/sesudah ikut kepotong di
          // tepi layar — jelas kelihatan ini carousel yang bisa digeser.
          _buildFavoriteProjectsCarousel(),
        ],
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppColors.grey400, size: 20),
                SizedBox(width: 8),
                Text(
                  'Cari proyek, tugas...',
                  style: TextStyle(color: AppColors.grey400, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () => _toast('Fitur Flovig PRO akan segera hadir'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Color(0xFF8D6E00), size: 16),
                SizedBox(width: 3),
                Text(
                  'Upgrade\nPRO',
                  style: TextStyle(
                    color: Color(0xFF8D6E00),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () => _toast('Buka tab Profil di bawah untuk lihat akun kamu'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(
                  'P',
                  style: TextStyle(
                    color: AppColors.heroStart,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      '3',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Carousel "Proyek Favorit" (maks. 4), pengganti kartu promo Laporan
  /// Otomatis di header — bisa digeser untuk memilih proyek favorit mana
  /// yang mau dibuka.
  Widget _buildFavoriteProjectsCarousel() {
    final favorites = _favoriteProjects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.md + 4, bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.white, size: 15),
              SizedBox(width: 4),
              Text(
                'Proyek Favorit',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (favorites.isEmpty)
          Container(
            height: 168,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: PhStore.instance.syncing
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    PhStore.instance.syncError ?? 'Belum ada proyek aktif',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
          )
        else ...[
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _favProjectsController,
            onPageChanged: (i) => setState(() => _favProjectsPage = i),
            itemCount: 10000,
            itemBuilder: (context, i) => AnimatedBuilder(
              animation: _favProjectsController,
              builder: (context, child) {
                double page = _favProjectsPage.toDouble();
                if (_favProjectsController.hasClients &&
                    _favProjectsController.position.haveDimensions) {
                  page = _favProjectsController.page ?? page;
                }
                final delta = (page - i).clamp(-1.0, 1.0);
                final scale = 1 - delta.abs() * 0.14;
                final angle = delta * 0.5;
                final dy = delta.abs() * 10;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0018)
                    ..translateByDouble(0.0, dy, 0.0, 1.0)
                    ..rotateY(angle)
                    ..scaleByDouble(scale, scale, scale, 1.0),
                  child: Opacity(
                    opacity: 1 - delta.abs() * 0.25,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildFavoriteProjectCard(
                  favorites[i % favorites.length],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(favorites.length, (i) {
            final active = i == _favProjectsPage % favorites.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: active ? 0.95 : 0.4),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            );
          }),
        ),
        ],
      ],
    );
  }

  Widget _buildFavoriteProjectCard(Map<String, dynamic> p) {
    final progress = p['progress'] as double;
    return GestureDetector(
      onTap: () {
        context.push('/project/${p['id']}');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -12,
              top: -12,
              child: Opacity(
                opacity: 0.16,
                child: Icon(p['icon'] as IconData, size: 88, color: Colors.white),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        (p['category'] as String).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.15),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${p['done']}/${p['total']} tugas · ${(progress * 100).round()}%',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu promo AI Asisten, pindahan dari posisi kartu Laporan Otomatis
  /// lama — sekarang ditaruh dekat banner pencapaian di bagian bawah.
  Widget _buildAiAssistantPromo() {
    return GestureDetector(
      onTap: () => _toast('Fitur AI Asisten akan segera hadir'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6D5DF6), Color(0xFF35C2E8)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D5DF6).withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -16,
              top: -16,
              child: Opacity(
                opacity: 0.16,
                child: Icon(Icons.auto_awesome_rounded, size: 96, color: Colors.white),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Text(
                          'BARU',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'AI Asisten Flovig',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tanya status proyek, minta draft laporan, kelola tugas — cukup ngobrol.',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu statistik mengambang di atas banner, meniru kartu saldo pada
  /// referensi super-app.
  Widget _buildStatsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.heroStart.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const AppIcon(AppIconType.folder, color: AppColors.heroStart, size: 19),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '12 Proyek',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.grey900),
                ),
                Text(
                  'sedang berjalan',
                  style: TextStyle(fontSize: 11, color: AppColors.grey500),
                ),
              ],
            ),
          ),
          _statAction(
            icon: Icons.add_rounded,
            label: 'Tambah',
            onTap: () => context.push('/projects'),
          ),
          const SizedBox(width: AppSpacing.sm),
          _statAction(
            icon: Icons.history_rounded,
            label: 'Riwayat',
            onTap: () => _toast('Riwayat aktivitas akan segera hadir'),
          ),
          const SizedBox(width: AppSpacing.sm),
          _statAction(
            icon: Icons.grid_view_rounded,
            label: 'Lainnya',
            badge: '8',
            onTap: _openMoreMenu,
          ),
        ],
      ),
    );
  }

  Widget _statAction({
    required IconData icon,
    required String label,
    String? badge,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent400,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
              if (badge != null)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.grey700, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Grid 4x2 menu cepat dengan badge kecil di tiap ikon, meniru grid
  /// layanan (GoRide/GoCar/dst.) pada referensi.
  Widget _buildMenuGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.card,
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppSpacing.md,
          mainAxisExtent: 78,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _menuItems.length,
        itemBuilder: (context, i) => _buildMenuTile(_menuItems[i]),
      ),
    );
  }

  Widget _buildMenuTile(_QuickMenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SvgPicture.asset(item.svgAsset, fit: BoxFit.contain),
              ),
              if (item.badge != null)
                Positioned(
                  right: -8,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.grey900,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      item.badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppColors.grey700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Banner hijau ala "Lihat keuntungan PLUS" pada referensi, di sini
  /// dipakai untuk mempromosikan pencapaian/produktivitas.
  Widget _buildAchievementBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => _toast('Halaman pencapaian akan segera hadir'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.success, Color(0xFF7CB342)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Selesaikan tugas, dapat pencapaian',
              style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  /// Kartu progres mingguan (mirip kartu klaim hadiah 1/7 hari pada
  /// referensi), dipakai untuk streak produktivitas.
  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Streak produktif kamu!',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary600,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 3),
                          Text('5/7 Hari', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pertahankan sampai akhir minggu',
                      style: TextStyle(fontSize: 10.5, color: AppColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary600, size: 20),
          ),
          GestureDetector(
            onTap: () => setState(() => _showStreakCard = false),
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.close_rounded, color: AppColors.grey400, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu ajakan rating rekan kerja, meniru kartu "Kasih driver rating,
  /// yuk!" pada referensi.
  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.grey100,
            child: AppIcon(AppIconType.person, color: AppColors.grey500, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beri rating ke rekan kerja',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey900),
                ),
                const Text(
                  'Sarah · Backend API v2',
                  style: TextStyle(fontSize: 10.5, color: AppColors.grey500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < _ratingStars;
                    return GestureDetector(
                      onTap: () => setState(() => _ratingStars = i + 1),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: filled ? const Color(0xFFFFB300) : AppColors.grey400,
                        size: 20,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showRatingCard = false),
            child: const Icon(Icons.close_rounded, color: AppColors.grey400, size: 16),
          ),
        ],
      ),
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

class _MoreMenuEntry {
  final String svgAsset;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _MoreMenuEntry({
    required this.svgAsset,
    required this.label,
    required this.accent,
    required this.onTap,
  });
}

class _MoreMenuSection {
  final String title;
  final List<_MoreMenuEntry> entries;

  const _MoreMenuSection({required this.title, required this.entries});
}

/// Bottom sheet "Menu lainnya", meniru struktur sidebar lengkap aplikasi
/// task management (Workspace, Analytics & Reporting, Members, dst.) supaya
/// semua menu yang belum tersambung ke flow terlihat jelas alih-alih cuma
/// snackbar kosong saat tombol "Lainnya" ditekan.
class _MoreMenuSheet extends StatelessWidget {
  final String title;
  final List<_MoreMenuSection> sections;
  const _MoreMenuSheet({this.title = 'Menu lainnya', required this.sections});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grey900),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                itemCount: sections.length,
                itemBuilder: (context, i) {
                  final section = sections[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                        child: Text(
                          section.title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.grey400,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      ...section.entries.map((e) => _MoreMenuTile(entry: e)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  final _MoreMenuEntry entry;
  const _MoreMenuTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: entry.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(entry.svgAsset, fit: BoxFit.contain),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                entry.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.grey900),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 18),
          ],
        ),
      ),
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

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final done = activity['done'] == true;
    final color = done ? AppColors.success : AppColors.error;
    final bg = done ? AppColors.successBg : AppColors.errorBg;
    final icon = done ? 'assets/icons/illustrations/checklist.svg' : 'assets/icons/illustrations/deadline.svg';

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
