// lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'core/app_router.dart';
import 'core/theme/theme_controller.dart';
import 'core/services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  _wakeUpServer(); // ← fire-and-forget, don't await so app launches instantly
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
          theme:      AppTheme.light,
          darkTheme:  AppTheme.dark,
          themeMode:  mode,
          routerConfig: appRouter,
        );
      },
    );
  }
}

// Wakes up the Render free-tier server in the background
Future<void> _wakeUpServer() async {
  try {
    await http
        .get(Uri.parse('${ApiService.baseUrl}/api/health'))
        .timeout(const Duration(seconds: 60));
  } catch (_) {} // silently ignore — just waking it up
}