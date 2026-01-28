import 'package:flutter/material.dart';

// ✅ Импорты
import 'core/user_config.dart';
import 'core/app_colors.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Загружаем настройки
  final config = UserConfig();
  await config.load();

  // 2. Запускаем приложение
  runApp(const WNodeApp());
}

class WNodeApp extends StatelessWidget {
  const WNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'W-Node',
      debugShowCheckedModeBanner: false,

      // Принудительно темная тема
      themeMode: ThemeMode.dark,

      // Настройка ТЕМНОЙ темы
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.accent,
        useMaterial3: true,

        // Цвета
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentBlue,
          surface: AppColors.bg,
          background: AppColors.bg,
        ),

        // Я УБРАЛ dialogTheme, ЧТОБЫ ИСПРАВИТЬ ОШИБКУ НА WINDOWS
      ),

      // Светлая тема (резерв)
      theme: ThemeData.light(useMaterial3: true),

      // ✅ Запуск с заставки
      home: const SplashScreen(),
    );
  }
}
