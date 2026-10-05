import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class BannerSlide {
  final String badge;
  final String title;
  final String subtitle;
  final String watermark;

  const BannerSlide({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.watermark,
  });
}

const kDefaultBannerSlides = [
  BannerSlide(
    badge: 'FLOVIG WORKSPACE',
    title: 'Satu Akun untuk\nSemua Kebutuhan Kerja',
    subtitle: 'Kelola proyek, tugas, dan tim dalam satu aplikasi.',
    watermark: 'assets/images/flovig_logo.png',
  ),
  BannerSlide(
    badge: 'PROYEK',
    title: 'Kelola Proyek\nLebih Rapi',
    subtitle: 'Atur deadline dan progres tim tanpa ribet.',
    watermark: 'assets/icons/illustrations/project_management.svg',
  ),
  BannerSlide(
    badge: 'TUGAS',
    title: 'Pantau Tugas\nReal-Time',
    subtitle: 'Tandai selesai dan lihat prioritas dalam genggaman.',
    watermark: 'assets/icons/illustrations/task.svg',
  ),
  BannerSlide(
    badge: 'TIM',
    title: 'Kolaborasi Tim\nTanpa Batas',
    subtitle: 'Diskusi dan koordinasi jarak jauh jadi mudah.',
    watermark: 'assets/icons/illustrations/human_source.svg',
  ),
];

/// Banner promo lengkung dengan carousel foto/ilustrasi (geser otomatis
/// tiap ~4 detik, bisa juga digeser manual) + indikator titik di bawahnya.
/// Dipakai bersama di Welcome, Login, dan Register agar headernya seragam.
class HeroBannerCarousel extends StatefulWidget {
  final List<BannerSlide> slides;
  final double slideHeight;

  const HeroBannerCarousel({
    super.key,
    this.slides = kDefaultBannerSlides,
    this.slideHeight = 210,
  });

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 4000), (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % widget.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(56),
        bottomRight: Radius.circular(56),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary900, AppColors.primary700, AppColors.heroStart],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: widget.slideHeight,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => _buildSlide(widget.slides[i]),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDots(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(BannerSlide slide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            top: -10,
            child: Opacity(
              opacity: 0.14,
              child: slide.watermark.endsWith('.svg')
                  ? SvgPicture.asset(slide.watermark, width: 150, height: 150)
                  : Image.asset(slide.watermark, width: 170, height: 170, fit: BoxFit.contain),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  slide.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                slide.title,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                slide.subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.slides.length, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.95 : 0.4),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        );
      }),
    );
  }
}
