import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/hero_banner_carousel.dart';

class _WelcomeMenu {
  final String asset;
  final String title;
  final Color accent;

  const _WelcomeMenu({
    required this.asset,
    required this.title,
    required this.accent,
  });
}

/// Welcome page bergaya aplikasi mobile modern (referensi: super-app
/// perbankan) — hero banner lengkung di atas, wordmark brand besar di
/// tengah, baris 4 menu akses cepat, lalu tombol Masuk besar + link Daftar.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _menus = [
    _WelcomeMenu(
      asset: 'assets/icons/illustrations/project_management.svg',
      title: 'Proyek',
      accent: AppColors.info,
    ),
    _WelcomeMenu(
      asset: 'assets/icons/illustrations/task.svg',
      title: 'Tugas',
      accent: AppColors.warning,
    ),
    _WelcomeMenu(
      asset: 'assets/icons/illustrations/human_source.svg',
      title: 'Tim',
      accent: AppColors.heroStart,
    ),
    _WelcomeMenu(
      asset: 'assets/icons/illustrations/pie_chart.svg',
      title: 'Laporan',
      accent: AppColors.accent400,
    ),
  ];

  void _openLogin(BuildContext context) => context.push('/login');

  Future<void> _quickLogin(BuildContext context) async {
    try {
      await AuthRepository.instance.loginWithBiometrics();
      if (context.mounted) context.go('/home');
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildBottomBlobs(),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HeroBannerCarousel(),
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.lg),
                        child: _buildSupportButton(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.16, 0.84, 1.0],
                          ).createShader(rect),
                          blendMode: BlendMode.dstIn,
                          child: Opacity(
                            opacity: 0.92,
                            child: Image.asset(
                              'assets/images/welcome_center_bg.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: _buildBrandLockup(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _buildMenuRow(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _buildAuthActions(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'v1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.grey400, fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bantuan akan segera hadir')),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.headset_mic_outlined, color: AppColors.primary700, size: 22),
      ),
    );
  }

  Widget _buildBrandLockup() {
    return Column(
      children: [
        Image.asset(
          'assets/images/flovig_logo.png',
          width: 72,
          height: 72,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 4),
        Text(
          'flovig',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.primary600,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.accent400,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'by PT Arunika Solusi Inovasi',
              style: TextStyle(color: AppColors.grey900, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _menus
          .asMap()
          .entries
          .map((e) => FadeInUp(
                delay: Duration(milliseconds: 100 * e.key),
                duration: const Duration(milliseconds: 500),
                child: _buildMenuItem(e.value),
              ))
          .toList(),
    );
  }

  Widget _buildMenuItem(_WelcomeMenu menu) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: menu.accent.withValues(alpha: 0.25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SvgPicture.asset(menu.asset, fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            menu.title,
            style: const TextStyle(
              color: AppColors.grey900,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: () => _openLogin(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: const Text(
                    'Masuk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: () => _quickLogin(context),
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.accent400.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent400.withValues(alpha: 0.4)),
                ),
                child: const AppIcon(
                  AppIconType.fingerprint,
                  color: AppColors.accent400,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBlobs() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              bottom: -100,
              left: -70,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent200.withValues(alpha: 0.18),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              right: -80,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.heroEnd.withValues(alpha: 0.14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
