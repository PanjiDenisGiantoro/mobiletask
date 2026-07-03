import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'login_form_screen.dart';
import 'home_screen.dart';

/// Layar sambutan sebelum login, mengikuti referensi desain login.png:
/// header biru dengan ilustrasi, kartu putih "Fast Menu", lalu tombol Login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _fastMenu = [
    {'icon': Icons.folder_outlined, 'label': 'Proyek', 'color': Color(0xFF1565C0), 'bg': Color(0xFFE3F2FD)},
    {'icon': Icons.checklist_outlined, 'label': 'Tugas', 'color': Color(0xFFE65100), 'bg': Color(0xFFFFF3E0)},
    {'icon': Icons.groups_outlined, 'label': 'Tim', 'color': Color(0xFFD84315), 'bg': Color(0xFFFBE9E7)},
    {'icon': Icons.bar_chart_rounded, 'label': 'Laporan', 'color': AppColors.success, 'bg': AppColors.successBg},
  ];

  void _openLoginForm(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const LoginFormScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutExpo);
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved);
          final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
          return SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
      ),
    );
  }

  void _quickLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _buildHeader(context)),
            _buildFastMenuCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary900, AppColors.primary700, AppColors.primary600],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: _FloatingBubbles())),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset('assets/images/flovig_logo.webp', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Flovig',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'M O B I L E',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Halo, Panji Giantoro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Selamat Datang!',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildIllustration(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      height: 150,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const Icon(Icons.diversity_3_rounded, size: 96, color: Colors.white),
          Positioned(
            left: 4,
            top: 6,
            child: _sticker(Icons.description_outlined, AppColors.accent400, -0.2),
          ),
          Positioned(
            right: 6,
            top: 0,
            child: _sticker(Icons.workspace_premium_outlined, AppColors.warning, 0.25),
          ),
          Positioned(
            left: 12,
            bottom: 4,
            child: _sticker(Icons.auto_awesome, Colors.white, 0.15, filled: false),
          ),
          Positioned(
            right: 0,
            bottom: 16,
            child: _sticker(Icons.star_rounded, Colors.white, -0.15, filled: false),
          ),
        ],
      ),
    );
  }

  Widget _sticker(IconData icon, Color color, double rotation, {bool filled = true}) {
    if (!filled) {
      return Transform.rotate(
        angle: rotation,
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 18),
      );
    }
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildFastMenuCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Fast Menu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey900),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 15, color: AppColors.grey400),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _fastMenu.map((m) {
              return Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: m['bg'] as Color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.grey700, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _openLoginForm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: () => _quickLogin(context),
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fingerprint, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bulatan-bulatan kecil transparan yang melayang perlahan secara acak
/// di atas header biru, sebagai dekorasi abstrak.
class _FloatingBubbles extends StatefulWidget {
  const _FloatingBubbles();

  @override
  State<_FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<_FloatingBubbles> with TickerProviderStateMixin {
  static const _specs = [
    {'left': 0.08, 'top': 0.10, 'size': 14.0, 'opacity': 0.20, 'duration': 4200, 'amplitude': 16.0},
    {'left': 0.86, 'top': 0.08, 'size': 9.0, 'opacity': 0.24, 'duration': 3600, 'amplitude': 12.0},
    {'left': 0.20, 'top': 0.78, 'size': 8.0, 'opacity': 0.18, 'duration': 5000, 'amplitude': 14.0},
    {'left': 0.72, 'top': 0.86, 'size': 17.0, 'opacity': 0.14, 'duration': 4600, 'amplitude': 18.0},
    {'left': 0.93, 'top': 0.52, 'size': 6.0, 'opacity': 0.26, 'duration': 3200, 'amplitude': 10.0},
    {'left': 0.05, 'top': 0.45, 'size': 12.0, 'opacity': 0.2, 'duration': 5200, 'amplitude': 12.0},
    {'left': 0.48, 'top': 0.04, 'size': 7.0, 'opacity': 0.22, 'duration': 3800, 'amplitude': 10.0},
    {'left': 0.35, 'top': 0.32, 'size': 5.0, 'opacity': 0.18, 'duration': 4400, 'amplitude': 8.0},
  ];

  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_specs.length, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _specs[i]['duration'] as int),
      );
      Future.delayed(Duration(milliseconds: 150 * i), () {
        if (mounted) controller.repeat(reverse: true);
      });
      return controller;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: List.generate(_specs.length, (i) {
            final spec = _specs[i];
            final amplitude = spec['amplitude'] as double;
            final size = spec['size'] as double;
            return AnimatedBuilder(
              animation: _controllers[i],
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_controllers[i].value) - 0.5;
                return Positioned(
                  left: constraints.maxWidth * (spec['left'] as double) + t * amplitude * 0.7,
                  top: constraints.maxHeight * (spec['top'] as double) + t * amplitude,
                  child: child!,
                );
              },
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: spec['opacity'] as double),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
