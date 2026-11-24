import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app/data/auth_repository.dart';

/// Splash screen bergaya "Recollect Splash Animation UI" dengan 14 kartu kolase,
/// animasi siklus 5.5 detik yang berulang selama 30 detik, dan tombol "Get Started"
/// di bagian bawah untuk langsung lanjut ke halaman berikutnya.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loopCtrl;
  Timer? _autoTimer;
  bool _navigated = false;
  final Future<bool> _session = AuthRepository.instance.restoreSession();

  static const _cards = <_MosaicCardSpec>[
    // Baris atas
    _MosaicCardSpec(
      dx: -0.34,
      dy: -0.34,
      w: 88,
      h: 82,
      appearStart: 0.01,
      suckDelay: 0.00,
      tilt: -0.07,
      glowColor: Color(0xFF2563EB),
      imageAsset: 'assets/images/splash_card_it.jpg',
      label: 'IT · Dev',
    ),
    _MosaicCardSpec(
      dx: -0.06,
      dy: -0.36,
      w: 96,
      h: 84,
      appearStart: 0.04,
      suckDelay: 0.015,
      tilt: 0.03,
      glowColor: Color(0xFF0EA5E9),
      imageAsset: 'assets/images/banner_flovig_workspace.jpg',
      label: 'Workspace',
    ),
    _MosaicCardSpec(
      dx: 0.28,
      dy: -0.34,
      w: 88,
      h: 82,
      appearStart: 0.07,
      suckDelay: 0.03,
      tilt: 0.06,
      glowColor: Color(0xFF10B981),
      imageAsset: 'assets/images/splash_card_sales.jpg',
      label: 'Sales',
    ),

    // Baris kedua
    _MosaicCardSpec(
      dx: -0.36,
      dy: -0.19,
      w: 86,
      h: 82,
      appearStart: 0.10,
      suckDelay: 0.045,
      tilt: -0.05,
      glowColor: Color(0xFFF59E0B),
      imageAsset: 'assets/images/splash_card_calendar.jpg',
      label: 'Jadwal',
    ),
    _MosaicCardSpec(
      dx: -0.11,
      dy: -0.20,
      w: 104,
      h: 96,
      appearStart: 0.13,
      suckDelay: 0.06,
      tilt: -0.02,
      glowColor: Color(0xFF14B8A6),
      imageAsset: 'assets/images/splash_office_3d.jpg',
      label: 'Smart Office',
    ),
    _MosaicCardSpec(
      dx: 0.16,
      dy: -0.21,
      w: 90,
      h: 84,
      appearStart: 0.16,
      suckDelay: 0.075,
      tilt: 0.04,
      glowColor: Color(0xFF7C3AED),
      imageAsset: 'assets/images/splash_card_accounting.jpg',
      label: 'Accounting',
    ),
    _MosaicCardSpec(
      dx: 0.37,
      dy: -0.18,
      w: 82,
      h: 80,
      appearStart: 0.19,
      suckDelay: 0.09,
      tilt: 0.07,
      glowColor: Color(0xFF4F46E5),
      imageAsset: 'assets/images/runa_ai_avatar.png',
      label: 'Runa AI',
    ),

    // Baris ketiga
    _MosaicCardSpec(
      dx: -0.33,
      dy: -0.04,
      w: 88,
      h: 82,
      appearStart: 0.22,
      suckDelay: 0.105,
      tilt: -0.06,
      glowColor: Color(0xFFEC4899),
      imageAsset: 'assets/images/splash_card_team.jpg',
      label: 'Tim',
    ),
    _MosaicCardSpec(
      dx: -0.05,
      dy: -0.04,
      w: 96,
      h: 86,
      appearStart: 0.25,
      suckDelay: 0.12,
      tilt: 0.02,
      glowColor: Color(0xFF1D4ED8),
      imageAsset: 'assets/images/banner_flovig_features.jpg',
      label: 'Analytics',
    ),
    _MosaicCardSpec(
      dx: 0.24,
      dy: -0.05,
      w: 88,
      h: 82,
      appearStart: 0.28,
      suckDelay: 0.135,
      tilt: -0.04,
      glowColor: Color(0xFF06B6D4),
      imageAsset: 'assets/images/splash_card_tickets.jpg',
      label: 'Tiket',
    ),

    // Baris keempat
    _MosaicCardSpec(
      dx: -0.31,
      dy: 0.10,
      w: 86,
      h: 78,
      appearStart: 0.31,
      suckDelay: 0.15,
      tilt: 0.05,
      glowColor: Color(0xFF38BDF8),
      imageAsset: 'assets/images/splash_card_it.jpg',
      label: 'Kanban',
    ),
    _MosaicCardSpec(
      dx: -0.07,
      dy: 0.11,
      w: 90,
      h: 78,
      appearStart: 0.34,
      suckDelay: 0.165,
      tilt: -0.03,
      glowColor: Color(0xFFF59E0B),
      imageAsset: 'assets/images/splash_card_calendar.jpg',
      label: 'Sprint',
    ),
    _MosaicCardSpec(
      dx: 0.18,
      dy: 0.10,
      w: 88,
      h: 78,
      appearStart: 0.37,
      suckDelay: 0.18,
      tilt: 0.04,
      glowColor: Color(0xFF10B981),
      imageAsset: 'assets/images/splash_card_sales.jpg',
      label: 'Target',
    ),
    _MosaicCardSpec(
      dx: 0.36,
      dy: 0.09,
      w: 80,
      h: 76,
      appearStart: 0.40,
      suckDelay: 0.195,
      tilt: -0.06,
      glowColor: Color(0xFF3B82F6),
      imageAsset: 'assets/images/banner_flovig_promo.jpg',
      label: 'Flovig Pro',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Siklus animasi kolase → tersedot ke ikon Flovig → tampil tengah (berulang halus)
    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();

    // Auto lanjut otomatis setelah 30 detik jika user belum menekan Get Started
    _autoTimer = Timer(const Duration(seconds: 30), _goNext);
  }

  Future<void> _goNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    _autoTimer?.cancel();
    final loggedIn = await _session;
    if (!mounted) return;
    context.go(loggedIn ? '/home' : '/welcome');
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _loopCtrl.dispose();
    super.dispose();
  }

  double _interval(double t, double start, double end, [Curve curve = Curves.linear]) {
    if (t <= start) return 0.0;
    if (t >= end) return 1.0;
    return curve.transform((t - start) / (end - start));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B16),
      body: AnimatedBuilder(
        animation: _loopCtrl,
        builder: (context, _) {
          final size = MediaQuery.of(context).size;
          final cx = size.width / 2;
          final cy = size.height * 0.44;
          final t = _loopCtrl.value;

          // Posisi target ikon Flovig: di bawah kolase (cy + 0.24*h),
          // lalu naik mulus ke tengah (cy) saat seluruh kartu tersedot masuk,
          // kemudian turun lagi untuk siklus berikutnya.
          final logoRise = _interval(t, 0.74, 0.85, Curves.easeOutCubic);
          final logoReset = _interval(t, 0.94, 1.0, Curves.easeInOutCubic);
          final logoStartY = cy + size.height * 0.24;
          final logoY = logoStartY + (cy - logoStartY) * (logoRise * (1 - logoReset));

          // Denyut ikon Flovig saat menyedot 14 kartu (0.52 -> 0.76)
          final absorbPulse = (t >= 0.52 && t <= 0.76)
              ? 1.0 + math.sin((t - 0.52) / 0.24 * math.pi * 6).abs() * 0.12
              : 1.0;

          final centerZoom = 1.0 + (logoRise * (1 - logoReset)) * 0.24;
          final logoSize = 68.0 * absorbPulse * centerZoom;
          final wordmarkFade = _interval(t, 0.77, 0.85, Curves.easeOut) *
              (1.0 - _interval(t, 0.92, 0.98, Curves.easeIn));

          return Stack(
            fit: StackFit.expand,
            children: [
              // Latar gelap premium + ambient glow biru
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.12),
                    radius: 0.95,
                    colors: [
                      Color(0xFF0E1D3A),
                      Color(0xFF060B16),
                    ],
                  ),
                ),
              ),

              // 14 kartu kolase muncul bertahap lalu tersedot ke ikon Flovig
              for (final card in _cards) _buildAnimatedCard(card, size, cx, cy, logoY, t),

              // Ikon Flovig yang menyedot kartu lalu tampil besar di tengah
              Positioned(
                left: cx - logoSize / 2,
                top: logoY - logoSize / 2,
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  padding: EdgeInsets.all(logoSize * 0.18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(logoSize * 0.28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.48),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/flovig_launcher_icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/images/flovig_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Wordmark "flovig" muncul saat logo berada di tengah
              if (wordmarkFade > 0.01)
                Positioned(
                  left: 0,
                  right: 0,
                  top: logoY + 56,
                  child: Opacity(
                    opacity: wordmarkFade.clamp(0.0, 1.0),
                    child: Column(
                      children: [
                        Text(
                          'flovig',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Manage · Collaborate · Deliver',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF93C5FD),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Tombol Get Started + footer perusahaan di bagian bawah
              Positioned(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _goNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'by PT Arunika Solusi Inovasi',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimatedCard(
    _MosaicCardSpec card,
    Size size,
    double cx,
    double cy,
    double targetLogoY,
    double t,
  ) {
    final appear = _interval(t, card.appearStart, card.appearStart + 0.11, Curves.easeOutBack);
    if (appear <= 0.001) return const SizedBox.shrink();

    final suckStart = 0.50 + card.suckDelay;
    final suckEnd = (suckStart + 0.11).clamp(0.0, 0.78);
    final suck = _interval(t, suckStart, suckEnd, Curves.easeInCubic);
    if (suck >= 0.995) return const SizedBox.shrink();

    final originX = cx + card.dx * size.width;
    final originY = cy + card.dy * size.height;
    final idleBob = math.sin(t * math.pi * 6 + card.appearStart * 14) * 3.5 * (1 - suck);

    final x = originX + (cx - originX) * suck;
    final y = (originY + idleBob) + (targetLogoY - (originY + idleBob)) * suck;

    final scale = (0.35 + 0.65 * appear) * (1.0 - suck * 0.88);
    final opacity = (appear.clamp(0.0, 1.0)) * (1.0 - _interval(suck, 0.65, 1.0));
    final rotation = card.tilt * (1 - suck) + (suck * (card.dx > 0 ? -0.35 : 0.35));

    return Positioned(
      left: x - card.w / 2,
      top: y - card.h / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale.clamp(0.05, 1.2),
            child: Container(
              width: card.w,
              height: card.h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF0F172A),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.24),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: card.glowColor.withValues(alpha: 0.36),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(card.imageAsset, fit: BoxFit.cover),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.68),
                          ],
                        ),
                      ),
                      child: Text(
                        card.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MosaicCardSpec {
  final double dx;
  final double dy;
  final double w;
  final double h;
  final double appearStart;
  final double suckDelay;
  final double tilt;
  final Color glowColor;
  final String imageAsset;
  final String label;

  const _MosaicCardSpec({
    required this.dx,
    required this.dy,
    required this.w,
    required this.h,
    required this.appearStart,
    required this.suckDelay,
    required this.tilt,
    required this.glowColor,
    required this.imageAsset,
    required this.label,
  });
}
