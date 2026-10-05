import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'stitch_frontend_interface_application/auth_repository.dart';

/// Splash screen. Animasi utama berasal dari `assets/lottie/splash.json`
/// (Lottie) — ganti file itu untuk mengubah motion tanpa menyentuh kode ini.
/// Transisi fade ke halaman Welcome didefinisikan di route '/welcome' pada
/// [appRouter], bukan di sini. Kalau ada sesi login tersimpan, langsung ke
/// '/home'.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _textController;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineOpacity;

  bool _navigated = false;
  final Future<bool> _session = AuthRepository.instance.restoreSession();

  @override
  void initState() {
    super.initState();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _textController.forward();
    });

    // Jaring pengaman: kalau file Lottie belum ada / gagal load,
    // tetap lanjut ke layar berikutnya setelah beberapa detik.
    Future.delayed(const Duration(milliseconds: 3200), _goNext);
  }

  Future<void> _goNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final loggedIn = await _session;
    if (!mounted) return;
    context.go(loggedIn ? '/home' : '/welcome');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A30),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071A30), Color(0xFF0A87E0), Color(0xFF14D6B4)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Lottie.asset(
                          'assets/lottie/splash.json',
                          fit: BoxFit.contain,
                          repeat: true,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/images/flovig_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: const Text(
                            'Flovig',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _taglineOpacity,
                        child: Text(
                          'Manage · Collaborate · Deliver',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
