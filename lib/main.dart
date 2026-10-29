import 'package:flutter/material.dart';
import 'router.dart';
import 'app/data/auth_repository.dart';
import 'app/theme/app_theme.dart';
import 'app/utils/sign_out.dart';

void main() {
  // Token kedaluwarsa/dicabut di tengah pemakaian: keluar ke layar awal.
  AuthRepository.instance.onSessionExpired = () {
    clearAccountData();
    appRouter.go('/welcome');
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flovig',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
