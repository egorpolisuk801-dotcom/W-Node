// 🔥 ФИНАЛЬНЫЙ СТАРТ: iOS БЕЗ БЛОКИРОВОК 🔥
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/user_config.dart';
import 'services/db_service.dart';
import 'core/notification_helper.dart';
import 'screens/splash_screen.dart';

void main() async {
  // 1. Инициализация привязок Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. СРАЗУ запускаем UI, не дожидаясь конфигов
  runApp(const WNodeApp());

  // 3. Запускаем сервисы в фоновом режиме
  _initServicesInBackground();
}

Future<void> _initServicesInBackground() async {
  try {
    // Устанавливаем стиль статус-бара сразу
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Запускаем всё без await в цепочке, чтобы один сбой не вешал другие
    NotificationHelper.initSystemNotifications()
        .catchError((e) => debugPrint("🔔 Push error: $e"));
    UserConfig().load().catchError((e) => debugPrint("⚙️ Config error: $e"));

    debugPrint("✅ Фоновые процессы инициированы");
  } catch (e) {
    debugPrint("⚠️ Критическая ошибка инициализации: $e");
  }
}

class WNodeApp extends StatelessWidget {
  const WNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00E676);
    const secondaryColor = Color(0xFF00B0FF);
    const bgColor = Color(0xFF121212);

    return MaterialApp(
      title: 'W-Node',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        primaryColor: primaryColor,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: Color(0xFF1E1E1E),
        ),
      ),
      // Сразу открываем заставку
      home: const SplashScreen(),
    );
  }
}
