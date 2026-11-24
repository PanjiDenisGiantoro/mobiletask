import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_strings.dart';
import '../theme/app_settings.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'add_task_form_sheet.dart';
import 'ai_assistant_sheet.dart';
import 'members_clients_screen.dart';
import 'projects_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'hris_screens.dart';
import '../data/auth_repository.dart';
import '../data/billing_repository.dart';
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
  bool _quickRadialOpen = false;

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

  /// Tombol "+" di tengah bottom nav: mode Task Management membuka semicircle
  /// radial menu (Jadwal, Tugas Baru, Tiket Baru), mode HRIS buka menu Absen/Cuti.
  void _onAddTap() {
    if (_mode == AppMode.hris) {
      _openHrisQuickMenu();
    } else {
      setState(() => _quickRadialOpen = !_quickRadialOpen);
    }
  }

  void _closeRadialAndRun(VoidCallback action) {
    setState(() => _quickRadialOpen = false);
    action();
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
    final c = context.colors;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: Stack(
        children: [
          IndexedStack(index: _selectedNav, children: _screens),
          if (_quickRadialOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _quickRadialOpen = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  color: Colors.black.withValues(alpha: 0.16),
                ),
              ),
            ),
          if (_selectedNav == 0 && !_quickRadialOpen)
            Positioned(
              right: 16,
              bottom: bottomInset + 96,
              child: Tooltip(
                message: 'Runa AI Assistant',
                child: GestureDetector(
                  onTap: () => showAiAssistantSheet(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF7C3AED),
                              AppColors.primary600,
                              AppColors.accent400,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary600.withValues(alpha: 0.42),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0F172A),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/runa_ai_avatar.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34D399),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + 54,
            child: IgnorePointer(
              ignoring: !_quickRadialOpen,
              child: Center(
                child: _QuickAddRadialMenu(
                  open: _quickRadialOpen,
                  onCalendar: () => _closeRadialAndRun(() => context.push('/calendar')),
                  onTask: () => _closeRadialAndRun(() => showAddTaskFormSheet(context)),
                  onTicket: () => _closeRadialAndRun(() => context.push('/tickets')),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        mode: _mode,
        selectedIndex: _selectedNav,
        isRadialOpen: _quickRadialOpen,
        onTap: (i) => setState(() {
          _quickRadialOpen = false;
          _selectedNav = i;
        }),
        onAddTap: _onAddTap,
      ),
    );
  }
}

/// Semicircle radial menu biru yang mekar halus di atas tombol "+" saat diketuk:
/// Kiri = Jadwal/Kalender, Tengah Atas = Tugas Baru, Kanan = Tiket Baru.
class _QuickAddRadialMenu extends StatelessWidget {
  final bool open;
  final VoidCallback onCalendar;
  final VoidCallback onTask;
  final VoidCallback onTicket;

  const _QuickAddRadialMenu({
    required this.open,
    required this.onCalendar,
    required this.onTask,
    required this.onTicket,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: open ? 1.0 : 0.25,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: open ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 214,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(110)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.accent400,
                AppColors.primary600,
                AppColors.heroStart,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary600.withValues(alpha: 0.36),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Kiri: Jadwal / Kalender
              Positioned(
                left: 18,
                bottom: 22,
                child: _radialAction(
                  icon: Icons.calendar_month_outlined,
                  label: S.tr('Jadwal', 'Schedule'),
                  onTap: onCalendar,
                ),
              ),
              // Tengah Atas: Tugas Baru
              Positioned(
                left: 0,
                right: 0,
                top: 10,
                child: Center(
                  child: _radialAction(
                    icon: Icons.task_alt_rounded,
                    label: S.tr('Tugas', 'Task'),
                    onTap: onTask,
                  ),
                ),
              ),
              // Kanan: Tiket Baru
              Positioned(
                right: 18,
                bottom: 22,
                child: _radialAction(
                  icon: Icons.confirmation_number_outlined,
                  label: S.tr('Tiket', 'Ticket'),
                  onTap: onTicket,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radialAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation bar melengkung (curved notch) dengan bola ikon aktif
/// yang meluncur & memantul (bounce) saat berpindah tab.
class _FloatingNavBar extends StatefulWidget {
  final AppMode mode;
  final int selectedIndex;
  final bool isRadialOpen;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const _FloatingNavBar({
    required this.mode,
    required this.selectedIndex,
    this.isRadialOpen = false,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar>
    with SingleTickerProviderStateMixin {
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

  late final AnimationController _controller;
  late Animation<double> _posAnim;
  late Animation<double> _orbLiftAnim;
  late Animation<double> _orbScaleAnim;
  double _currentSlot = 0;

  int _slotForNav(int navIndex) => navIndex >= 2 ? navIndex + 1 : navIndex;

  List<AppIconType?> get _icons =>
      widget.mode == AppMode.hris ? _hrisIcons : _taskIcons;

  List<String> _labels(S s) => widget.mode == AppMode.hris
      ? [s.navHome, s.navAttendance, '', s.navLeave, s.navProfile]
      : [s.navHome, s.navProjects, '', s.navActivities, s.navProfile];

  @override
  void initState() {
    super.initState();
    _currentSlot = _slotForNav(widget.selectedIndex).toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _posAnim = AlwaysStoppedAnimation<double>(_currentSlot);
    _orbLiftAnim = const AlwaysStoppedAnimation<double>(0);
    _orbScaleAnim = const AlwaysStoppedAnimation<double>(1);
  }

  @override
  void didUpdateWidget(covariant _FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final from = _posAnim.value;
      final to = _slotForNav(widget.selectedIndex).toDouble();
      _currentSlot = to;

      _posAnim = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      );

      // Transisi halus tanpa lompatan vertikal berlebih.
      _orbLiftAnim = const AlwaysStoppedAnimation<double>(0);

      _orbScaleAnim = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.93).chain(CurveTween(curve: Curves.easeOut)),
          weight: 45,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.93, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 55,
        ),
      ]).animate(_controller);

      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);
    final labels = _labels(s);
    const barTopOffset = 18.0;
    const barBodyHeight = 64.0;
    const innerPad = 12.0;
    const orbSize = 46.0;
    const notchRadius = 27.0; // orbRadius (23) + gap presisi (4)
    const filletRadius = 7.0;
    const totalHalfSpan = notchRadius + filletRadius; // 34.0
    const centerBtnSize = 44.0;
    final activeSlot = _slotForNav(widget.selectedIndex);
    final activeIcon = _icons[activeSlot] ?? AppIconType.home;
    // Putih ke abu-abuan lembut di light mode, adaptif di dark mode
    final barBg = c.isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9);
    final inactiveIconColor = c.isDark ? AppColors.darkTextMuted : AppColors.grey700;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: barTopOffset + barBodyHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final usableWidth = width - (innerPad * 2);
              final slotWidth = usableWidth / 5;

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final pos = _posAnim.value;
                  final rawCenterX = innerPad + (pos + 0.5) * slotWidth;
                  final notchCenterX = rawCenterX.clamp(
                    totalHalfSpan + 4,
                    width - totalHalfSpan - 4,
                  );

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Floating rounded bar putih ke abu-abuan dengan lekukan lingkaran presisi
                      Positioned(
                        left: 0,
                        right: 0,
                        top: barTopOffset,
                        height: barBodyHeight,
                        child: CustomPaint(
                          painter: _CurvedNavBarPainter(
                            notchCenterX: notchCenterX,
                            notchRadius: notchRadius,
                            filletRadius: filletRadius,
                            backgroundColor: barBg,
                            borderColor: c.isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            shadowColor: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.10),
                          ),
                        ),
                      ),

                      // Bola lingkaran aktif konsentris tepat di pusat lekukan (y = barTopOffset + filletRadius)
                      Positioned(
                        left: notchCenterX - orbSize / 2,
                        top: (barTopOffset + filletRadius - orbSize / 2) + _orbLiftAnim.value,
                        child: Transform.scale(
                          scale: _orbScaleAnim.value,
                          child: Container(
                            width: orbSize,
                            height: orbSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.accent400,
                                  AppColors.primary600,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary600.withValues(alpha: 0.38),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: AppIcon(
                                activeIcon,
                                color: Colors.white,
                                size: 22,
                                strokeWidth: 2.1,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Tombol "+" di tengah sedikit lebih besar & duduk di dalam lekukan ke atas
                      Positioned(
                        left: width / 2 - centerBtnSize / 2,
                        top: barTopOffset - 2,
                        child: Semantics(
                          button: true,
                          label: widget.mode == AppMode.hris
                              ? S.tr('Buat pengajuan', 'Create request')
                              : S.tr('Tambah tugas', 'Add task'),
                          child: Tooltip(
                            message: widget.mode == AppMode.hris
                                ? S.tr('Buat pengajuan', 'Create request')
                                : S.tr('Tambah tugas', 'Add task'),
                            child: GestureDetector(
                              onTap: widget.onAddTap,
                              child: Container(
                                width: centerBtnSize,
                                height: centerBtnSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.heroStart,
                                      AppColors.primary600,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: barBg,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary600.withValues(alpha: 0.34),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: AnimatedRotation(
                                    turns: widget.isRadialOpen ? 0.125 : 0.0,
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeInOutCubic,
                                    child: const AppIcon(
                                      AppIconType.plus,
                                      color: Colors.white,
                                      size: 21,
                                      strokeWidth: 2.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 5 slot ikon bersih di dalam floating bar
                      Positioned(
                        left: innerPad,
                        right: innerPad,
                        top: barTopOffset,
                        height: barBodyHeight,
                        child: Row(
                          children: List.generate(5, (i) {
                            if (i == 2) {
                              return const Expanded(child: SizedBox.shrink());
                            }

                            final navIndex = i > 2 ? i - 1 : i;
                            final selected = widget.selectedIndex == navIndex;
                            final labelColor = selected ? c.primary : inactiveIconColor;

                            return Expanded(
                              child: Semantics(
                                button: true,
                                selected: selected,
                                label: labels[i],
                                child: Tooltip(
                                  message: labels[i],
                                  child: InkResponse(
                                    onTap: () => widget.onTap(navIndex),
                                    radius: 28,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        AnimatedOpacity(
                                          duration: const Duration(milliseconds: 180),
                                          opacity: selected ? 0.0 : 1.0,
                                          child: AnimatedScale(
                                            duration: const Duration(milliseconds: 220),
                                            scale: selected ? 0.5 : 1.0,
                                            child: AppIcon(
                                              _icons[i]!,
                                              color: inactiveIconColor,
                                              size: 21,
                                              strokeWidth: 1.85,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 7),
                                          child: Text(
                                            labels[i],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: labelColor,
                                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Menggambar floating rounded bar dengan lekukan busur lingkaran presisi
/// (semicircle konsentris dengan bola aktif + fillet tangensial halus di tepi atas).
class _CurvedNavBarPainter extends CustomPainter {
  final double notchCenterX;
  final double notchRadius;
  final double filletRadius;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;

  const _CurvedNavBarPainter({
    required this.notchCenterX,
    required this.notchRadius,
    required this.filletRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const cornerR = 20.0;
    final R = notchRadius;
    final f = filletRadius;
    final span = R + f;
    final cx = notchCenterX.clamp(span + 4, w - span - 4);
    final leftTangentX = cx - span;
    final rightTangentX = cx + span;
    final topLeftR = leftTangentX < cornerR ? leftTangentX : cornerR;
    final topRightR = (w - rightTangentX) < cornerR ? (w - rightTangentX) : cornerR;

    // Lekukan ke atas halus di tengah (untuk tombol "+") yang otomatis mereda
    // sesaat jika lekukan tab aktif sedang melintas melewati tengah.
    final midX = w / 2;
    const bumpHalfW = 28.0;
    final distFromMid = (cx - midX).abs();
    final bumpFactor = ((distFromMid - (span + 10)) / 16.0).clamp(0.0, 1.0);
    final bumpH = 11.0 * bumpFactor;
    final bumpLeft = midX - bumpHalfW;
    final bumpRight = midX + bumpHalfW;

    void addDownwardNotch(Path p) {
      p
        ..arcToPoint(
          Offset(cx - R, f),
          radius: Radius.circular(f),
          clockwise: true,
        )
        ..arcToPoint(
          Offset(cx + R, f),
          radius: Radius.circular(R),
          clockwise: false,
        )
        ..arcToPoint(
          Offset(rightTangentX, 0),
          radius: Radius.circular(f),
          clockwise: true,
        );
    }

    void addUpwardCenterBump(Path p) {
      if (bumpH <= 0.2) return;
      p
        ..cubicTo(
          bumpLeft + bumpHalfW * 0.45,
          0,
          midX - bumpHalfW * 0.45,
          -bumpH,
          midX,
          -bumpH,
        )
        ..cubicTo(
          midX + bumpHalfW * 0.45,
          -bumpH,
          bumpRight - bumpHalfW * 0.45,
          0,
          bumpRight,
          0,
        );
    }

    final path = Path()
      ..moveTo(0, topLeftR)
      ..quadraticBezierTo(0, 0, topLeftR, 0);

    if (cx < midX) {
      path.lineTo(leftTangentX, 0);
      addDownwardNotch(path);
      if (bumpH > 0.2 && bumpLeft >= rightTangentX) {
        path.lineTo(bumpLeft, 0);
        addUpwardCenterBump(path);
      }
    } else {
      if (bumpH > 0.2 && bumpRight <= leftTangentX) {
        path.lineTo(bumpLeft, 0);
        addUpwardCenterBump(path);
      }
      path.lineTo(leftTangentX, 0);
      addDownwardNotch(path);
    }

    path
      ..lineTo(w - topRightR, 0)
      ..quadraticBezierTo(w, 0, w, topRightR)
      ..lineTo(w, h - cornerR)
      ..quadraticBezierTo(w, h, w - cornerR, h)
      ..lineTo(cornerR, h)
      ..quadraticBezierTo(0, h, 0, h - cornerR)
      ..close();

    canvas.drawShadow(path, shadowColor, 12, true);

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (borderColor != Colors.transparent) {
      final strokePaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedNavBarPainter oldDelegate) =>
      oldDelegate.notchCenterX != notchCenterX ||
      oldDelegate.notchRadius != notchRadius ||
      oldDelegate.filletRadius != filletRadius ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.borderColor != borderColor;
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
  late final PageController _favProjectsController;
  late int _favProjectsPage;

  static const _favIcons = [
    Icons.design_services_rounded,
    Icons.code_rounded,
    Icons.campaign_rounded,
    Icons.language_rounded,
  ];

  /// Proyek favorit pilihan user (dari menu Projects), atau fallback ke proyek aktif (maks. 4).
  List<Map<String, dynamic>> get _favoriteProjects {
    final store = PhStore.instance;
    final favIds = store.favoriteProjectIds;
    final selected = favIds.isNotEmpty
        ? store.projects.where((p) => favIds.contains(p.id)).toList()
        : store.projects.where((p) => p.status == 'active').take(4).toList();
    return [
      for (var i = 0; i < selected.length; i++)
        {
          'id': selected[i].id,
          'title': selected[i].name,
          'category': selected[i].category,
          'icon': _favIcons[i % _favIcons.length],
          'logoUrl': selected[i].logoUrl,
          'progress': _progressOf(selected[i]),
          'done': selected[i].doneTasks,
          'total': selected[i].totalTasks,
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
    BillingRepository.instance.addListener(_onStoreChanged);
    PhStore.instance.loadFavoriteProjects();
    if (!PhStore.instance.synced) PhStore.instance.sync();
    ChatRepository.instance.loadInbox();
    if ((AuthRepository.instance.currentUser?.isAdmin ?? false) &&
        BillingRepository.instance.subscription == null) {
      BillingRepository.instance.fetchSubscription();
    }
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
    BillingRepository.instance.removeListener(_onStoreChanged);
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
          accent: const Color(0xFF2563EB),
          badge: PhStore.instance.projects.isEmpty ? null : '${PhStore.instance.projects.length}',
          onTap: () => context.push('/projects'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/task.svg',
          label: 'Work Activities',
          accent: const Color(0xFFF59E0B),
          badge: _openTaskBadge,
          onTap: () => context.push('/tasks'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/notes.svg',
          label: 'Pengajuan',
          accent: const Color(0xFF4F46E5),
          onTap: () => context.push('/requests'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/pie_chart.svg',
          label: 'Analytics',
          accent: const Color(0xFF10B981),
          onTap: () => context.push('/reports'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/calendar.svg',
          label: 'Kalender',
          accent: const Color(0xFF06B6D4),
          onTap: () => context.push('/calendar'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/brainstorming.svg',
          label: 'Chat',
          accent: const Color(0xFF7C3AED),
          badge: ChatRepository.instance.totalUnread == 0 ? null : '${ChatRepository.instance.totalUnread}',
          onTap: () => context.push('/messages'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/stamp.svg',
          label: 'Persetujuan',
          accent: const Color(0xFFE11D48),
          badge: PhStore.instance.pendingForMe == 0 ? null : '${PhStore.instance.pendingForMe}',
          onTap: () => context.push('/approvals'),
        ),
        _QuickMenuItem(
          svgAsset: 'assets/icons/illustrations/organize.svg',
          label: 'Lainnya',
          accent: const Color(0xFF475569),
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
              title: 'Lainnya',
              entries: [
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/human_source.svg',
                  label: 'Role',
                  accent: AppColors.primary600,
                  onTap: () => pushLater('/roles'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/folder_secure.svg',
                  label: 'Permission',
                  accent: AppColors.primary600,
                  onTap: () => pushLater('/permissions'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/timeline.svg',
                  label: 'Activity Log',
                  accent: AppColors.info,
                  onTap: () => pushLater('/activity-logs'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/revenue.svg',
                  label: 'Invoices',
                  accent: AppColors.success,
                  onTap: () => pushLater('/invoices'),
                ),
                _MoreMenuEntry(
                  svgAsset: 'assets/icons/illustrations/gear.svg',
                  label: 'Admin & Pengaturan',
                  accent: AppColors.grey700,
                  onTap: () => pushLater('/admin-settings'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _onRefresh() => Future.wait([
        PhStore.instance.sync(),
        ChatRepository.instance.loadInbox(),
        if (AuthRepository.instance.currentUser?.isAdmin ?? false)
          BillingRepository.instance.fetchSubscription(),
      ]);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _buildTopBanner(context),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildProjectStatusCard(),
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
                  _buildMembersClientsCarousel(),
                  if (AuthRepository.instance.currentUser?.isAdmin ?? false) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildPaymentStatusCard(),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _buildTaskDistributionCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildActiveSprintsCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildProjectProgressCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildTeamActivityCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildRecentTicketsCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildUpcomingDeadlinesCard(),
                ],
              ),
            ),
          ),
        ],
        ),
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
    final salam = h < 11
        ? S.tr('Selamat pagi', 'Good morning')
        : h < 15
            ? S.tr('Selamat siang', 'Good afternoon')
            : h < 18
                ? S.tr('Selamat sore', 'Good evening')
                : S.tr('Selamat malam', 'Good night');
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
        _buildNotificationBell(context),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Buka profil',
          child: InkResponse(
            onTap: widget.onOpenProfile,
            radius: 28,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Builder(
                builder: (_) {
                  final raw = AuthRepository.instance.currentUser?.raw;
                  final rawImgs = raw != null ? extractUserImages(raw) : const <String>[];
                  final storeUser = PhStore.instance.users[PhStore.meId];
                  final imgs = storeUser != null && storeUser.images.isNotEmpty
                      ? storeUser.images
                      : rawImgs;
                  final url = storeUser != null && storeUser.photoUrl.isNotEmpty
                      ? storeUser.photoUrl
                      : (imgs.isNotEmpty ? imgs.first : '');
                  return PhAvatar(
                    PhStore.meId,
                    size: 40,
                    imageUrl: url,
                    images: imgs,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _companyScopeKey() {
    final raw = AuthRepository.instance.currentUser?.raw;
    final comp = raw?['company'];
    final cid = raw?['company_id'] ?? (comp is Map ? comp['id'] : null) ?? '0';
    return 'c${cid}_u${PhStore.meId}';
  }

  String _companyDisplayName() {
    final raw = AuthRepository.instance.currentUser?.raw;
    final comp = raw?['company'];
    if (comp is Map && '${comp['name'] ?? ''}'.trim().isNotEmpty) {
      return '${comp['name']}'.trim();
    }
    final cname = '${raw?['company_name'] ?? ''}'.trim();
    return cname;
  }

  bool _isJoinedProject(Project p, String meId) {
    if (meId.isEmpty) return false;
    return p.managerId == meId ||
        p.clientId == meId ||
        p.members.any((m) => m.userId == meId);
  }

  /// Kumpulkan notifikasi update proyek yang diikuti user pada company aktif.
  List<_HomeNotifItem> _collectProjectNotifications() {
    final meId = PhStore.meId;
    final scope = _companyScopeKey();
    final settings = AppSettings.instance;

    final joinedProjects = PhStore.instance.projects
        .where((p) => _isJoinedProject(p, meId))
        .toList();
    final joinedIds = {for (final p in joinedProjects) p.id};

    final items = <_HomeNotifItem>[];

    // 1. Update Tugas pada proyek yang diikuti user
    for (final t in TaskRepository.instance.tasks) {
      if (t.done) continue;
      final inMyProject = t.projectId > 0 && joinedIds.contains(t.projectId);
      final assignedToMe = t.assignedTo == meId;
      if (!inMyProject && !assignedToMe) continue;
      final nid = '${scope}_task_${t.id}_${t.status}';
      if (settings.isNotificationRead(nid)) continue;
      items.add(_HomeNotifItem(
        id: nid,
        kind: 'task',
        title: t.title,
        subtitle: '${t.project.isNotEmpty ? t.project : S.tr('Proyek', 'Project')} • ${t.status}',
        dateTimeLabel: _formatNotifDateTime(
          t.dueDate.isNotEmpty ? t.dueDate : t.startDate,
        ),
        route: '/task/${t.id}',
      ));
    }

    // 2. Update Tiket pada proyek yang diikuti user
    for (final tk in PhStore.instance.tickets) {
      if (tk.status == 'closed' || tk.status == 'resolved') continue;
      final inMyProject = tk.projectId > 0 && joinedIds.contains(tk.projectId);
      final mine = tk.assigneeId == meId ||
          tk.assigneeIds.contains(meId) ||
          tk.reporterId == meId;
      if (!inMyProject && !mine) continue;
      final nid = '${scope}_ticket_${tk.id}_${tk.status}';
      if (settings.isNotificationRead(nid)) continue;
      final projName = tk.projectName.isNotEmpty
          ? tk.projectName
          : (PhStore.instance.projectById(tk.projectId)?.name ?? S.tr('Tiket', 'Ticket'));
      items.add(_HomeNotifItem(
        id: nid,
        kind: 'ticket',
        title: tk.title,
        subtitle: '$projName • ${S.tr('Tiket', 'Ticket')} (${tk.status})',
        dateTimeLabel: _formatNotifDateTime(
          tk.createdAt.isNotEmpty ? tk.createdAt : tk.slaDueAt,
        ),
        route: '/ticket/${tk.id}',
      ));
    }

    // 3. Update Proyek yang diikuti user
    for (final p in joinedProjects) {
      if (p.status == 'cancelled') continue;
      final nid = '${scope}_proj_${p.id}_${p.status}_${p.progress}';
      if (settings.isNotificationRead(nid)) continue;
      items.add(_HomeNotifItem(
        id: nid,
        kind: 'project',
        title: p.name,
        subtitle: S.tr(
          'Update Proyek • Progres ${p.progress}% (${p.doneTasks}/${p.totalTasks} tugas)',
          'Project Update • Progress ${p.progress}% (${p.doneTasks}/${p.totalTasks} tasks)',
        ),
        dateTimeLabel: _formatNotifDateTime(
          p.endDate.isNotEmpty ? p.endDate : p.startDate,
        ),
        route: '/project/${p.id}',
      ));
    }

    return items;
  }

  String _formatNotifDateTime(String? raw) {
    if (raw != null && raw.trim().isNotEmpty) {
      final dt = DateTime.tryParse(raw.trim());
      if (dt != null) {
        final local = dt.toLocal();
        final hh = local.hour.toString().padLeft(2, '0');
        final mm = local.minute.toString().padLeft(2, '0');
        return '${fmtDate(local.toIso8601String())}, $hh:$mm';
      }
      if (raw.length >= 16) return fmtDateTime(raw);
      if (raw.length >= 10) return fmtDate(raw);
    }
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '${fmtDate(now.toIso8601String())}, $hh:$mm';
  }

  Widget _buildNotificationBell(BuildContext context) {
    final totalNotif = _collectProjectNotifications().length;

    return Semantics(
      button: true,
      label: S.of(context).notifications,
      child: InkWell(
        onTap: () => _openNotificationsSheet(context),
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            if (totalNotif > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.heroStart, width: 1.5),
                  ),
                  child: Text(
                    totalNotif > 99 ? '99+' : '$totalNotif',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openNotificationsSheet(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);
    final companyName = _companyDisplayName();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            AppSettings.instance,
            PhStore.instance,
            TaskRepository.instance,
          ]),
          builder: (ctx, _) {
            final settings = AppSettings.instance;
            final items = _collectProjectNotifications();
            final allIds = [for (final it in items) it.id];

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.76,
                ),
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, color: c.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.notifications,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Text(
                                  companyName.isNotEmpty
                                      ? S.tr(
                                          'Update proyek yang Anda ikuti • $companyName',
                                          'Updates from your joined projects • $companyName',
                                        )
                                      : S.tr(
                                          'Update proyek yang Anda ikuti',
                                          'Updates from your joined projects',
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (allIds.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => settings.markAllNotificationsRead(allIds),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(Icons.done_all_rounded, size: 16, color: c.primary),
                              label: Text(
                                S.tr('Sudah dibaca semua', 'Mark all read'),
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.primary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.notifications_off_outlined, size: 34, color: c.textFaint),
                                const SizedBox(height: 8),
                                Text(
                                  S.tr('Semua notifikasi proyek sudah dibaca', 'All project notifications read'),
                                  style: TextStyle(fontSize: 13, color: c.textMuted, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final it in items)
                                _buildNotifTile(
                                  context: context,
                                  id: it.id,
                                  icon: it.kind == 'ticket'
                                      ? Icons.confirmation_number_outlined
                                      : (it.kind == 'project'
                                          ? Icons.folder_copy_outlined
                                          : Icons.task_alt_rounded),
                                  iconColor: it.kind == 'ticket'
                                      ? AppColors.warning
                                      : (it.kind == 'project' ? AppColors.success : c.primary),
                                  iconBg: it.kind == 'ticket'
                                      ? c.warningBg
                                      : (it.kind == 'project' ? c.successBg : c.primarySoft),
                                  title: it.title,
                                  subtitle: it.subtitle,
                                  dateTimeLabel: it.dateTimeLabel,
                                  onTap: () {
                                    settings.markNotificationRead(it.id);
                                    Navigator.pop(sheetCtx);
                                    context.push(it.route);
                                  },
                                  onMarkRead: () => settings.markNotificationRead(it.id),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotifTile({
    required BuildContext context,
    required String id,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String dateTimeLabel,
    required VoidCallback onTap,
    required VoidCallback onMarkRead,
  }) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: iconBg,
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          S.tr('Belum dibaca', 'Unread'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: c.primary,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.schedule_rounded, size: 12, color: c.textFaint),
                        const SizedBox(width: 3),
                        Text(
                          dateTimeLabel,
                          style: TextStyle(fontSize: 10.5, color: c.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: onMarkRead,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 13, color: c.primary),
                              const SizedBox(width: 4),
                              Text(
                                S.tr('Sudah dibaca', 'Mark as read'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersClientsCarousel() {
    final c = context.colors;
    final users = PhStore.instance.companyUsers
      ..sort((a, b) {
        if (a.isClient != b.isClient) return a.isClient ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final preview = users.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(S.tr('Member & Client', 'Members & Clients')),
            TextButton(
              onPressed: () => context.push('/members-clients'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                S.of(context).viewAll,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (preview.isEmpty)
          PhCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  S.tr('Belum ada data member atau client', 'No members or clients yet'),
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preview.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final u = preview[i];
                final badgeLabel = u.isClient
                    ? 'Client'
                    : (u.role.isNotEmpty
                        ? '${u.role[0].toUpperCase()}${u.role.substring(1)}'
                        : 'Member');
                final badgeFg = u.isClient ? const Color(0xFFD97706) : c.primary;
                final badgeBg = u.isClient ? c.warningBg : c.primarySoft;

                return SizedBox(
                  width: 126,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showMemberClientDetailSheet(context, u),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.border),
                        boxShadow: c.cardShadow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              PhAvatar(
                                u.id,
                                size: 46,
                                imageUrl: u.photoUrl,
                                images: u.images,
                              ),
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: u.isActive ? AppColors.success : c.textFaint,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.surface, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            u.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
            if ((p['logoUrl'] as String).isEmpty)
              Positioned(
                right: -12,
                top: -12,
                child: Opacity(
                  opacity: 0.16,
                  child: Icon(p['icon'] as IconData, size: 88, color: Colors.white),
                ),
              )
            else
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 44,
                  height: 44,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: p['logoUrl'] as String,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const SizedBox(),
                    errorWidget: (_, _, _) => Icon(p['icon'] as IconData, color: AppColors.primary700, size: 22),
                  ),
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

  /// Kartu ringkasan status proyek (beres vs belum), mengambang di bawah
  /// header — menggantikan kartu absensi harian pada mode Task Management.
  Widget _buildProjectStatusCard() {
    final projects = PhStore.instance.projects;
    final total = projects.length;
    final done = projects.where((p) => p.completed).length;
    final notDone = total - done;
    final pct = total == 0 ? 0 : (done / total * 100).round();

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
          onTap: () => context.push('/reports'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: total == 0
                      ? Container(
                          decoration: BoxDecoration(
                            color: AppColors.heroStart.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const AppIcon(AppIconType.chart, color: AppColors.primary700, size: 22),
                        )
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 12,
                            sections: [
                              PieChartSectionData(
                                value: done.toDouble(),
                                color: AppColors.success,
                                showTitle: false,
                                radius: 10,
                              ),
                              PieChartSectionData(
                                value: notDone.toDouble(),
                                color: AppColors.grey400,
                                showTitle: false,
                                radius: 10,
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        total == 0 ? 'Belum ada proyek' : '$done dari $total proyek beres · $pct%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.grey900),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _legendDot(AppColors.success, 'Beres $done'),
                          const SizedBox(width: AppSpacing.sm),
                          _legendDot(AppColors.grey400, 'Belum $notDone'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
      ],
    );
  }

  /// Kartu "Payment Status / Status Langganan" di Dashboard dari `GET /billing/subscription`.
  Widget _buildPaymentStatusCard() {
    final repo = BillingRepository.instance;
    final sub = repo.subscription;
    final isExpired = sub?.isExpired ?? false;
    final isLifetime = sub?.isLifetime ?? false;
    final days = sub?.daysRemaining ?? 0;

    final Color statusBg;
    final Color statusFg;
    final String statusText;
    if (sub == null) {
      statusBg = const Color(0xFFF1F5F9);
      statusFg = const Color(0xFF475569);
      statusText = repo.subscriptionLoading ? 'Memuat...' : 'Cek Paket';
    } else if (isLifetime) {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF15803D);
      statusText = 'Lifetime';
    } else if (isExpired) {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
      statusText = 'Kedaluwarsa';
    } else if (days <= 7) {
      statusBg = const Color(0xFFFFEDD5);
      statusFg = const Color(0xFFEA580C);
      statusText = 'Sisa $days hari';
    } else {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF15803D);
      statusText = 'Aktif · $days hari';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.large),
      onTap: () => context.push('/payment-history'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(
            color: isExpired ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (isExpired ? AppColors.error : AppColors.primary700).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.payments_rounded,
                color: isExpired ? AppColors.error : AppColors.primary700,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Status Langganan',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.grey500),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusFg),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub == null
                        ? (repo.subscriptionError ?? 'Ketuk untuk lihat riwayat & paket')
                        : 'Paket ${sub.displayPlanName} · ${sub.userCount}/${sub.maxUsers?.toString() ?? '∞'} User · ${sub.projectCount}/${sub.maxProjects?.toString() ?? '∞'} Proyek',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
          ],
        ),
      ),
    );
  }

  /// 1. Kartu "Task Distribution" (Donut Chart + Done / In Progress / Review / To Do).
  Widget _buildTaskDistributionCard() {
    final tasks = TaskRepository.instance.tasks;
    final total = tasks.length;
    final done = tasks.where((t) => t.status == 'done').length;
    final inProgress = tasks.where((t) => t.status == 'in_progress').length;
    final review = tasks.where((t) => t.status == 'review').length;
    final todo = tasks.where((t) => t.status != 'done' && t.status != 'in_progress' && t.status != 'review').length;

    int pct(int n) => total == 0 ? 0 : (n / total * 100).round();

    final segments = [
      ('Done', done, const Color(0xFF10B981)),
      ('In Progress', inProgress, const Color(0xFF2563EB)),
      ('Review', review, const Color(0xFFF59E0B)),
      ('To Do', todo, const Color(0xFF94A3B8)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.pie_chart_outline_rounded, size: 18, color: Color(0xFF9333EA)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Task Distribution', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                    Text('$total total active tasks', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 142,
              height: 142,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 44,
                      sections: total == 0
                          ? [PieChartSectionData(value: 1, color: const Color(0xFFE2E8F0), radius: 18, showTitle: false)]
                          : [
                              for (final (_, count, color) in segments)
                                if (count > 0)
                                  PieChartSectionData(
                                    value: count.toDouble(),
                                    color: color,
                                    radius: 18,
                                    showTitle: false,
                                  ),
                            ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                      const Text('TOTAL TASKS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.grey500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final (label, count, color) in segments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.grey700))),
                  Text('${pct(count)}%', style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 24,
                    child: Text('$count', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 2. Kartu "Active Sprints" (`Sprints currently running in agile cycles`).
  Widget _buildActiveSprintsCard() {
    final store = PhStore.instance;
    final tasks = TaskRepository.instance.tasks;
    final today = isoDate(DateTime.now());
    final activeSprints = <(Project, Sprint)>[];
    for (final p in store.projects) {
      for (final s in p.sprints) {
        if (s.status == 'active') activeSprints.add((p, s));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.bolt_rounded, size: 19, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Sprints', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                    Text('Sprints currently running in agile cycles', style: TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/projects'),
                child: const Text('View all →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeSprints.isEmpty)
            const Text('Belum ada sprint aktif.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (var i = 0; i < activeSprints.length && i < 4; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Builder(builder: (_) {
                final (p, s) = activeSprints[i];
                final sTasks = tasks.where((t) => t.projectId == p.id && t.sprint == s.name).toList();
                final doneCnt = sTasks.where((t) => t.done).length;
                final totalCnt = sTasks.length;
                final ratio = totalCnt > 0 ? (doneCnt / totalCnt).clamp(0.0, 1.0) : 0.0;
                final overdue = s.endDate.isNotEmpty && s.endDate.compareTo(today) < 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/project/${p.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(6)),
                              child: Text('SP-${s.id}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: overdue ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                overdue ? 'Overdue' : 'Active',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: overdue ? const Color(0xFFDC2626) : const Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(s.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('$doneCnt/$totalCnt tasks · ${(ratio * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
        ],
      ),
    );
  }

  /// 3. Kartu "Project Progress".
  Widget _buildProjectProgressCard() {
    final projects = PhStore.instance.projects.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.work_outline_rounded, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Project Progress', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.grey900)),
              ),
              TextButton(
                onPressed: () => context.push('/projects'),
                child: const Text('View all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (projects.isEmpty)
            const Text('Belum ada proyek.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (final p in projects) ...[
              InkWell(
                onTap: () => context.push('/project/${p.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.clientId.isEmpty ? p.name : '${p.name} · ${PhStore.instance.nameOf(p.clientId)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900),
                            ),
                          ),
                          Text('${(_progressOf(p) * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _progressOf(p).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('${p.doneTasks}/${p.totalTasks} tasks completed', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                          const Spacer(),
                          Text('${p.sprints.length} sprints', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// 4. Kartu "Team Activity" (`Recent task & ticket updates`).
  Widget _buildTeamActivityCard() {
    final store = PhStore.instance;
    final tasks = TaskRepository.instance.tasks.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.history_toggle_off_rounded, size: 18, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Team Activity', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                    Text('Recent task & ticket updates', style: TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            const Text('Belum ada aktivitas tim.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (var i = 0; i < tasks.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
              InkWell(
                onTap: () => context.push('/task/${tasks[i].id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PhAvatar(tasks[i].assignedTo.isNotEmpty ? tasks[i].assignedTo : tasks[i].createdBy, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12.5, color: AppColors.grey700, height: 1.35),
                                children: [
                                  TextSpan(
                                    text: tasks[i].assignedTo.isEmpty ? 'User' : store.nameOf(tasks[i].assignedTo),
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.grey900),
                                  ),
                                  TextSpan(
                                    text: tasks[i].done ? ' menyelesaikan task ' : ' sedang mengerjakan task ',
                                  ),
                                  TextSpan(
                                    text: tasks[i].title,
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                  ),
                                ],
                              ),
                            ),
                            if (tasks[i].dueDate.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(timeAgo(tasks[i].dueDate), style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// 5. Kartu "Recent Tickets" (`Issues & support queue`).
  Widget _buildRecentTicketsCard() {
    final tickets = PhStore.instance.tickets.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.confirmation_number_outlined, size: 18, color: Color(0xFFDC2626)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Tickets', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                    Text('Issues & support queue', style: TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/tickets'),
                child: const Text('View all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tickets.isEmpty)
            const Text('Belum ada tiket.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (var i = 0; i < tickets.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
              InkWell(
                onTap: () => context.push('/ticket/${tickets[i].id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tickets[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '#${tickets[i].id} • ${tickets[i].projectName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.grey500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 5,
                        children: [
                          PhPill(
                            tickets[i].priority.isEmpty ? 'Medium' : '${tickets[i].priority[0].toUpperCase()}${tickets[i].priority.substring(1)}',
                            fg: tickets[i].priority == 'critical' ? const Color(0xFFDC2626) : const Color(0xFFEA580C),
                            bg: tickets[i].priority == 'critical' ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5),
                          ),
                          if (tickets[i].slaBreached)
                            const PhPill('SLA Breached', fg: Color(0xFFDC2626), bg: Color(0xFFFEE2E2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// 6. Kartu "Upcoming Deadlines" (`Milestone target schedules`).
  Widget _buildUpcomingDeadlinesCard() {
    final items = <(Project, Milestone)>[];
    for (final p in PhStore.instance.projects) {
      for (final m in p.milestones) {
        if (m.status != 'completed' && m.dueDate.isNotEmpty) {
          items.add((p, m));
        }
      }
    }
    items.sort((a, b) => a.$2.dueDate.compareTo(b.$2.dueDate));
    final today = isoDate(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upcoming Deadlines', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                    Text('Milestone target schedules', style: TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('Belum ada jadwal milestone.', style: TextStyle(fontSize: 12.5, color: AppColors.grey500))
          else
            for (var i = 0; i < items.length && i < 4; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Builder(builder: (_) {
                final (p, m) = items[i];
                final dt = DateTime.tryParse(m.dueDate);
                final dayStr = dt != null ? '${dt.day}' : '-';
                final monStr = dt != null ? monthsShort[dt.month - 1] : '';
                final isToday = m.dueDate == today;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/project/${p.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(dayStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8), height: 1.1)),
                              Text(monStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                              const SizedBox(height: 2),
                              Text(
                                '${p.name} • ${isToday ? 'Today' : fmtDate(m.dueDate)}',
                                style: TextStyle(fontSize: 11.5, color: isToday ? const Color(0xFFDC2626) : AppColors.grey500, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
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
                width: 50,
                height: 50,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.accent.withValues(alpha: 0.08),
                      item.accent.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: item.accent.withValues(alpha: 0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: item.accent.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: SvgPicture.asset(item.svgAsset, fit: BoxFit.contain),
              ),
              if (item.badge != null)
                Positioned(
                  right: -7,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      item.badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.colors.textPrimary, fontWeight: FontWeight.w600),
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
          child: Text(
            S.of(context).viewAll,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.primary,
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
    final c = context.colors;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c.textSecondary,
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
    final c = context.colors;
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 18),
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
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
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

class _HomeNotifItem {
  final String id;
  final String kind; // task | ticket | project
  final String title;
  final String subtitle;
  final String dateTimeLabel;
  final String route;

  const _HomeNotifItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.dateTimeLabel,
    required this.route,
  });
}
