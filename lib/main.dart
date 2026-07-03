import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'stitch_frontend_interface_application/app_theme.dart';
import 'stitch_frontend_interface_application/welcome_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flovig',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(nextScreen: WelcomeScreen()),
    );
  }
}
