import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/user_config.dart';
import 'services/db_service.dart';
import 'core/notification_helper.dart';
import 'screens/splash_screen.dart';

void main() async {
  // 1. Инициализация привязок
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Мгновенный запуск UI
  runApp(const WNodeApp());

  // 3. Загрузка сервисов "вдогонку"
  _initAppServices();
}

Future<void> _initAppServices() async {
  try {
    // Стиль системных панелей
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Параллельная загрузка конфига и пушей
    await Future.wait([
      UserConfig().load(),
      NotificationHelper.initSystemNotifications(),
    ]);

    debugPrint("✅ Системные службы W-Node готовы");
  } catch (e) {
    debugPrint("⚠️ Ошибка инициализации сервисов: $e");
  }
}

class WNodeApp extends StatefulWidget {
  const WNodeApp({super.key});

  @override
  State<WNodeApp> createState() => _WNodeAppState();
}

class _WNodeAppState extends State<WNodeApp> {
  // Ключ для показа SnackBar из любой точки приложения
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // Слушаем интернет через 3 секунды после старта
    Future.delayed(const Duration(seconds: 3), () {
      _initConnectivityListener();
    });
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      // Если интернет появился (не 'none')
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        try {
          // Пытаемся синхронизировать данные при восстановлении сети
          await DBService().syncWithCloud();

          _scaffoldKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Связь восстановлена. Склад синхронизирован!',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Color(0xFF00E676),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          debugPrint("❌ Ошибка авто-синхронизации: $e");
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
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldKey, // Подключаем ключ
      title: 'W-Node',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00B0FF),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
