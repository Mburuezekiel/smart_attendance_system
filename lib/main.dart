// lib/main.dart

import 'package:flutter/material.dart';
import 'core/app_router.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (_, mode, __) {
        return MaterialApp.router(
          title: 'EduTrack MUT',
          debugShowCheckedModeBanner: false,
          theme:      AppTheme.light,   // ← full design system (green, cards, inputs…)
          darkTheme:  AppTheme.dark,    // ← full dark variant
          themeMode:  mode,             // ← live-switches when user toggles in Settings
          routerConfig: appRouter,
        );
      },
    );
  }
}