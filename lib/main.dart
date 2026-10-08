import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/theme_controller.dart';
import 'services/storage_service.dart';
import 'services/firebase_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();
  await ThemeController().init();
  await FirebaseService().init();

  runApp(const PageLabApp());
}

class PageLabApp extends StatelessWidget {
  const PageLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController(),
      builder: (context, _) {
        return MaterialApp(
          title: 'PageLab - All your images & PDFs, in one place',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController().themeMode,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
