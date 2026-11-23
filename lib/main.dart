import 'package:flutter/material.dart';
import 'router.dart';
import 'app/data/auth_repository.dart';
import 'app/l10n/app_strings.dart';
import 'app/services/push_notification_service.dart';
import 'app/theme/app_settings.dart';
import 'app/theme/app_theme.dart';
import 'app/utils/sign_out.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await PushNotificationService.instance.init();
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
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp.router(
          title: 'Flovig',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: settings.themeMode,
          builder: (context, child) => AppStringsScope(
            isIndonesian: settings.isIndonesian,
            child: child ?? const SizedBox.shrink(),
          ),
          routerConfig: appRouter,
        );
      },
    );
  }
}
