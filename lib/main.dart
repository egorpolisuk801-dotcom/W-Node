import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Добавил для настройки статус-бара

// Если работаешь только на телефоне, этот импорт можно закомментировать
import 'package:sqflite/sqflite.dart';

import 'core/user_config.dart';
// import 'core/app_colors.dart'; // Закомментировал, используем цвета прямо в теме для надежности
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Настройка цвета статус-бара (делаем прозрачным)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final config = UserConfig();
  await config.load();

  runApp(const WNodeApp());
}

class WNodeApp extends StatelessWidget {
  const WNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- ЦВЕТОВАЯ ПАЛИТРА (CYBERPUNK / PRO) ---
    const primaryColor = Color(0xFF00E676); // Неоновый зеленый (как на ПК)
    const secondaryColor = Color(0xFF00B0FF); // Неоновый синий
    const bgColor = Color(0xFF121212); // Глубокий черный
    const cardColor = Color(0xFF1E1E1E); // Темно-серый для карточек
    const errorColor = Color(0xFFFF5252); // Яркий красный

    return MaterialApp(
      title: 'W-Node',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,

      // --- НАСТРОЙКА ТЕМНОЙ ТЕМЫ ---
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        primaryColor: primaryColor,
        useMaterial3: true,

        // Цветовая схема
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: cardColor,
          background: bgColor,
          error: errorColor,
        ),

        // Стиль карточек (товаров)
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 4,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Мягкие углы
            side: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1), // Тонкая обводка
          ),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        ),

        // Поля ввода (Поиск и добавление)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF252525),
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: primaryColor, width: 2), // Подсветка при вводе
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        // Кнопки
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.black, // Черный текст на зеленой кнопке
            elevation: 2,
            textStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),

        // Плавающая кнопка (+)
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
        ),

        // Диалоговые окна
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF252525),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}
