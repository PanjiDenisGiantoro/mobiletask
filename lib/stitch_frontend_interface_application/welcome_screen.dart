import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'login_form_screen.dart';
import 'home_screen.dart';
import 'widgets/app_icons.dart';

class _OnboardSlide {
  final String asset;
  final String title;
  final String subtitle;
  final String chip;
  final Color accent;

  const _OnboardSlide({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.accent,
  });
}

/// Onboarding carousel: tiap slide menampilkan mockup produk (SVG di
/// assets/icons) melayang dengan tilt 3D yang mengikuti gestur swipe,
/// warna aksen & progress bar berubah mengikuti konten tiap slide.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _floatController;
  int _page = 0;

  static const _slides = [
    _OnboardSlide(
      asset: 'assets/icons/project.svg',
      title: 'Kelola Semua Proyek\ndalam Satu Tempat',
      subtitle: 'Atur proyek, deadline, dan progres tim tanpa ribet.',
      chip: '4 proyek aktif',
      accent: AppColors.info,
    ),
    _OnboardSlide(
      asset: 'assets/icons/task.svg',
      title: 'Pantau Tugas\nSecara Real-Time',
      subtitle: 'Tandai selesai dan lihat prioritas dalam genggaman.',
      chip: '3 dari 5 selesai',
      accent: AppColors.accent400,
    ),
    _OnboardSlide(
      asset: 'assets/icons/team.svg',
      title: 'Kolaborasi Tim\nJadi Lebih Mudah',
      subtitle: 'Diskusi dan koordinasi tanpa hambatan jarak.',
      chip: '12 anggota online',
      accent: AppColors.heroStart,
    ),
    _OnboardSlide(
      asset: 'assets/icons/laporan.svg',
      title: 'Satu Akun untuk\nSemua Kebutuhan Kerja',
      subtitle: 'Semua fitur Flovig, dalam satu genggaman.',
      chip: '+18% minggu ini',
      accent: AppColors.success,
    ),
  ];

  bool get _isLast => _page == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      _openLoginForm();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() {
    _controller.animateToPage(
      _slides.length - 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _openLoginForm() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => const LoginFormScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutExpo,
          );
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

  void _quickLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _slides[_page].accent;
    return Scaffold(
      backgroundColor: AppColors.onboardingBg,
      body: Stack(
        children: [
          _buildAmbientGlow(accent),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildProgressTrack(accent)),
                      if (!_isLast) ...[
                        const SizedBox(width: AppSpacing.md),
                        GestureDetector(
                          onTap: _skip,
                          child: const Text(
                            'Lewati',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _buildSlide(i, _slides[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: _isLast ? _buildFinalActions() : _buildNextButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlow(Color accent) {
    return Positioned(
      top: -60,
      right: -50,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: 0.28),
                accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTrack(Color accent) {
    return Row(
      children: List.generate(_slides.length, (i) {
        final active = i <= _page;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == _slides.length - 1 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: active ? null : AppColors.onboardingTrack,
              gradient: active
                  ? LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.55)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSlide(int index, _OnboardSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTiltCard(index, slide),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiltCard(int index, _OnboardSlide slide) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _floatController]),
      builder: (context, child) {
        var page = _page.toDouble();
        if (_controller.hasClients && _controller.position.haveDimensions) {
          page = _controller.page ?? _page.toDouble();
        }
        final delta = (index - page).clamp(-1.0, 1.0);
        final float = math.sin(_floatController.value * math.pi * 2) * 5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(delta * -0.55)
            ..translateByDouble(0.0, float, 0.0, 1.0),
          child: Opacity(
            opacity: (1 - delta.abs() * 0.4).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    slide.accent.withValues(alpha: 0.35),
                    slide.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            SvgPicture.asset(slide.asset, width: 168, height: 168),
            Positioned(right: -4, bottom: 6, child: _buildChip(slide)),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(_OnboardSlide slide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F38),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: slide.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            slide.chip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.heroStart,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Lanjut',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFinalActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: _openLoginForm,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              child: const Text(
                'Masuk',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _openLoginForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.heroStart,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Daftar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        InkWell(
          onTap: _quickLogin,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: const AppIcon(
              AppIconType.fingerprint,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}
