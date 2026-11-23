import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

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
    title: 'Satu Platform untuk\nProyek & Tugas Tim',
    subtitle: 'Kelola proyek, tugas, sprint, & kolaborasi tim dalam genggaman.',
    watermark: 'assets/images/banner_flovig_workspace.jpg',
  ),
  BannerSlide(
    badge: 'KEUNGGULAN UTAMA',
    title: 'Pantau Progres\nReal-Time & Akurat',
    subtitle: 'Kanban board, SLA tiket, & laporan PDF/Excel instan.',
    watermark: 'assets/images/banner_flovig_features.jpg',
  ),
  BannerSlide(
    badge: 'PROMO · HEMAT 17%',
    title: 'Upgrade Paket Pro\nLebih Hemat Tahunan',
    subtitle: 'Bayar praktis lewat DOKU QRIS, VA & E-Wallet.',
    watermark: 'assets/images/banner_flovig_promo.jpg',
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.md, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    slide.badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  slide.title,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slide.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 138,
            height: 138,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: slide.watermark.endsWith('.svg')
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: SvgPicture.asset(slide.watermark, fit: BoxFit.contain),
                    )
                  : Image.asset(
                      slide.watermark,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.white.withValues(alpha: 0.15),
                        alignment: Alignment.center,
                        child: Image.asset('assets/images/flovig_logo.png', width: 64, height: 64, fit: BoxFit.contain),
                      ),
                    ),
            ),
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
