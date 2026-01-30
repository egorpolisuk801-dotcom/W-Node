import 'dart:io';
import 'package:flutter/material.dart';

// ❌ 1. ОТКЛЮЧАЕМ БИБЛИОТЕКУ ДЛЯ ПК (чтобы не было ошибки)
// import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'core/user_config.dart';
import 'core/app_colors.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ❌ 2. ОТКЛЮЧАЕМ ИНИЦИАЛИЗАЦИЮ WINDOWS
  /*
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  */

  final config = UserConfig();
  await config.load();

  runApp(const WNodeApp());
}

class WNodeApp extends StatelessWidget {
  const WNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'W-Node',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.accent,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentBlue,
          surface: const Color(0xFF1E1E1E),
          background: AppColors.bg,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      theme: ThemeData.light(useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}
