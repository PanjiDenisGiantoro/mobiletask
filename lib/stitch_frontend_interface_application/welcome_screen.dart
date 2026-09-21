import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'widgets/app_icons.dart';
import 'widgets/hero_banner_carousel.dart';

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
      asset: 'assets/icons/project.svg',
      title: 'Proyek',
      accent: AppColors.info,
    ),
    _WelcomeMenu(
      asset: 'assets/icons/task.svg',
      title: 'Tugas',
      accent: AppColors.warning,
    ),
    _WelcomeMenu(
      asset: 'assets/icons/team.svg',
      title: 'Tim',
      accent: AppColors.heroStart,
    ),
    _WelcomeMenu(
      asset: 'assets/icons/laporan.svg',
      title: 'Laporan',
      accent: AppColors.accent400,
    ),
  ];

  void _openLogin(BuildContext context) => context.push('/login');

  void _openRegister(BuildContext context) => context.push('/register');

  void _quickLogin(BuildContext context) => context.go('/home');

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
                  const SizedBox(height: AppSpacing.xl),
                  _buildBrandLockup(),
                  const SizedBox(height: AppSpacing.xxl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _buildMenuRow(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
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
          width: 88,
          height: 88,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Flovig',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.grey900,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.accent400,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Project & Team Management',
          style: TextStyle(color: AppColors.grey500, fontSize: 12.5, fontWeight: FontWeight.w500),
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
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: menu.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: SvgPicture.asset(menu.asset, fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        Text(
          menu.title,
          style: const TextStyle(
            color: AppColors.grey700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Belum punya akun? ',
              style: TextStyle(color: AppColors.grey700, fontSize: 13),
            ),
            GestureDetector(
              onTap: () => _openRegister(context),
              child: const Text(
                'Daftar',
                style: TextStyle(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
