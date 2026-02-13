import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/user_config.dart';
import 'services/db_service.dart';
import 'screens/splash_screen.dart';
import 'core/notification_helper.dart';

void main() async {
  // 1. Инициализация движка Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. СРАЗУ ЗАПУСКАЕМ ПРИЛОЖЕНИЕ (чтобы убрать белый экран)
  runApp(const WNodeApp());

  // 3. ЗАПУСКАЕМ СЕРВИСЫ В ФОНЕ (не блокируя основной поток)
  _initServicesInBackground();
}

/// Функция фоновой загрузки сервисов
Future<void> _initServicesInBackground() async {
  try {
    // Настройка статус-бара
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Грузим тяжелые компоненты
    await NotificationHelper.initSystemNotifications();

    final config = UserConfig();
    await config.load();

    debugPrint("✅ Фоновые сервисы W-Node успешно запущены");
  } catch (e) {
    debugPrint("⚠️ Ошибка фоновой инициализации: $e");
  }
}

class WNodeApp extends StatefulWidget {
  const WNodeApp({super.key});

  @override
  State<WNodeApp> createState() => _WNodeAppState();
}

class _WNodeAppState extends State<WNodeApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Даем приложению 3 секунды "продышаться" перед включением слушателя сети
    Future.delayed(const Duration(seconds: 3), () {
      _initConnectivityListener();
    });
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        try {
          await DBService().syncWithCloud();

          _scaffoldKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Связь восстановлена. Склад синхронизирован!',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Color(0xFF00E676),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );

          NotificationHelper.showSystemPush(
            'W-Node: Связь восстановлена',
            'Офлайн-данные успешно отправлены на склад.',
          );
        } catch (e) {
          debugPrint("❌ Ошибка синхронизации: $e");
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00E676);
    const secondaryColor = Color(0xFF00B0FF);
    const bgColor = Color(0xFF121212);
    const cardColor = Color(0xFF1E1E1E);

    return MaterialApp(
      scaffoldMessengerKey: _scaffoldKey,
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
          surface: cardColor,
          background: bgColor,
        ),
        cardTheme: CardThemeData(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
        ),
      ),
      // Сразу показываем SplashScreen, пока в фоне грузятся сервисы
      home: const SplashScreen(),
    );
  }
}
