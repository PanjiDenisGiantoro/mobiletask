import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'add_task_form_sheet.dart';
import 'projects_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'hris_screens.dart';
import '../data/attendance_repository.dart';
import '../data/auth_repository.dart';
import '../data/chat_remote.dart';
import '../utils/ph_format.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../data/task_repository.dart';
import 'ph_screens.dart';
import '../widgets/app_icons.dart';
import '../widgets/ph_widgets.dart';

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
      _DashboardBody(onOpenProfile: () => setState(() => _selectedNav = 3)),
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

  static const _taskLabels = ['Beranda', 'Proyek', '', 'Tugas', 'Profil'];
  static const _hrisLabels = ['Beranda', 'Absensi', '', 'Cuti', 'Profil'];

  List<String> get _labels => mode == AppMode.hris ? _hrisLabels : _taskLabels;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 68,
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
                return Semantics(
                  button: true,
                  label: mode == AppMode.hris ? 'Buat pengajuan' : 'Tambah tugas',
                  child: GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 48,
                    height: 48,
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
                      size: 21,
                    ),
                  ),
                  ),
                );
              }
              final navIndex = i > 2 ? i - 1 : i;
              final selected = selectedIndex == navIndex;
              final color = selected ? AppColors.primary700 : AppColors.grey700;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  child: InkResponse(
                    onTap: () => onTap(navIndex),
                    radius: 32,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          _icons[i]!,
                          color: color,
                          size: 22,
                          strokeWidth: selected ? 2.0 : 1.7,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _labels[i],
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
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
  final VoidCallback onOpenProfile;

  const _DashboardBody({required this.onOpenProfile});

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final _attendance = AttendanceRepository.instance;
  bool _submitting = false;

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
    _attendance.addListener(_onStoreChanged);
    if (!PhStore.instance.synced) PhStore.instance.sync();
    ChatRepository.instance.loadInbox();
    if (_attendance.today == null) _attendance.loadToday();
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
    _attendance.removeListener(_onStoreChanged);
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
          {
            'title': t.title,
            'date': t.dueDate.isEmpty ? 'Tanpa tenggat' : 'Tenggat ${fmtDate(t.dueDate)}',
            'done': t.done,
            'late': !t.done && t.dueDate.isNotEmpty && t.dueDate.compareTo(isoDate(DateTime.now())) < 0,
          },
      ];

  String? get _openTaskBadge {
    final me = PhStore.meId;
    final n = TaskRepository.instance.tasks.where((t) => !t.done && t.assignedTo == me).length;
    return n == 0 ? null : '$n';
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
          svgAsset: 'assets/icons/illustrations/notes.svg',
          label: 'Pengajuan',
          accent: AppColors.heroStart,
          onTap: () => context.push('/requests'),
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
              child: _buildAttendanceCard(),
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
                  if (_priorities.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionHeader('Tenggat terdekat'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildPriorityRow(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle('Tugas terbaru'),
                  const SizedBox(height: AppSpacing.sm),
                  if (_activity.isEmpty)
                    const Text('Belum ada tugas.', style: TextStyle(fontSize: 13, color: AppColors.grey700)),
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

  String get _firstName {
    final name = AuthRepository.instance.currentUser?.name.trim() ?? '';
    return name.isEmpty ? '' : name.split(' ').first;
  }

  Widget _buildSearchRow(BuildContext context) {
    final now = DateTime.now();
    final h = now.hour;
    final salam = h < 11 ? 'Selamat pagi' : h < 15 ? 'Selamat siang' : h < 18 ? 'Selamat sore' : 'Selamat malam';
    final initial = _firstName.isEmpty ? '?' : _firstName.characters.first.toUpperCase();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _firstName.isEmpty ? salam : '$salam, $_firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                longDay(now),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Semantics(
          button: true,
          label: 'Buka profil',
          child: InkResponse(
            onTap: widget.onOpenProfile,
            radius: 28,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Text(
                initial,
                style: const TextStyle(color: AppColors.primary700, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
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
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
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
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAttendance() async {
    setState(() => _submitting = true);
    try {
      final message = await _attendance.submit();
      if (mounted) phToast(context, message);
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _hm(String? v) => (v == null || v.length < 5) ? '--:--' : v.substring(0, 5);

  /// Kartu absen hari ini, mengambang di bawah header.
  Widget _buildAttendanceCard() {
    final today = _attendance.today;
    String title;
    String subtitle;
    String? action;

    if (today == null) {
      title = _attendance.loading ? 'Memuat absensi…' : 'Absensi belum bisa dimuat';
      subtitle = _attendance.loading ? 'Sebentar ya' : (_attendance.error ?? 'Coba lagi beberapa saat');
      if (!_attendance.loading) action = 'Coba lagi';
    } else {
      final rec = today.attendance;
      final shift = today.shift?.label ?? '';
      final shiftText = shift.isEmpty ? '' : 'Shift $shift';
      switch (today.state) {
        case 'day_off':
          title = 'Hari ini libur';
          subtitle = today.holiday.isNotEmpty ? today.holiday : 'Tidak ada jadwal shift';
        case 'checkout_1' || 'checkout_2':
          title = 'Masuk pukul ${_hm(today.state == 'checkout_2' ? rec?.checkIn2 : rec?.checkIn)}';
          subtitle = shiftText.isEmpty ? 'Jangan lupa absen pulang' : shiftText;
          action = 'Absen pulang';
        case 'done':
          final out = (rec?.checkOut2.isNotEmpty ?? false) ? rec!.checkOut2 : rec?.checkOut;
          title = 'Absen hari ini selesai';
          subtitle = '${_hm(rec?.checkIn)} – ${_hm(out)}';
        default:
          title = 'Belum absen masuk';
          subtitle = shiftText.isEmpty ? 'Absen sekarang untuk mulai bekerja' : shiftText;
          action = 'Absen masuk';
      }
    }

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.large),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.card,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.large),
          onTap: () => context.push('/attendance'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.heroStart.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const AppIcon(AppIconType.fingerprint, color: AppColors.primary700, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.grey900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.grey700),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _submitting
                        ? null
                        : today == null
                            ? _attendance.loadToday
                            : _submitAttendance,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    ),
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(action, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ),
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
        padding: EdgeInsets.zero,
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
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.grey900, fontWeight: FontWeight.w600),
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
        TextButton(
          onPressed: () => context.push('/projects'),
          child: const Text(
            'Lihat semua',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityRow() {
    final items = _priorities;
    return Row(
      children: [for (var i = 0; i < items.length; i++) items[i]].map((p) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: identical(p, items.first) && items.length > 1 ? AppSpacing.sm : 0,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p['meta'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grey700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  p['progress'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary700,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.grey700,
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey900),
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grey900),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final done = activity['done'] == true;
    final late = activity['late'] == true;
    final color = done ? const Color(0xFF2E7D32) : late ? const Color(0xFFC62828) : AppColors.primary700;
    final bg = done ? AppColors.successBg : late ? AppColors.errorBg : AppColors.primary50;
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey900,
                  ),
                ),
                Text(
                  activity['date'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grey700,
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
              done ? 'Selesai' : late ? 'Terlambat' : 'Berjalan',
              style: TextStyle(
                fontSize: 11,
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
