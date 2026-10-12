import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Внутрішні модулі системи
import 'core/user_config.dart';
import 'core/theme_controller.dart';
import 'core/app_colors.dart';
import 'services/db_service.dart';
import 'services/admin_link.dart';
import 'core/notification_helper.dart';
import 'screens/splash_screen.dart';

void main() async {
  // 1. Ініціалізація рушія Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Підключення до бази даних Supabase
  await Supabase.initialize(
    url: 'https://qzgatfjezjzqshqpuejh.supabase.co',
    anonKey: 'sb_publishable_KdPbnLB4DpKjjaoPP9agig_EWMpdM7h',
  );

  // 3. Запуск UI
  runApp(const WNodeApp());

  // 4. Завантаження фонових сервісів
  _initAppServices();
}

Future<void> _initAppServices() async {
  try {
    // Робимо системну панель (де годинник і батарея) прозорою
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          AppColors.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          AppColors.isDark ? Brightness.dark : Brightness.light,
    ));

    // Паралельно завантажуємо конфіг і пуш-сповіщення
    await Future.wait([
      UserConfig().load(),
      NotificationHelper.initSystemNotifications(),
    ]);
    ThemeController.loadFromConfig();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          AppColors.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          AppColors.isDark ? Brightness.dark : Brightness.light,
    ));

    debugPrint("✅ Системні служби W-NODE успішно запущені");
  } catch (e) {
    debugPrint("⚠️ Помилка ініціалізації сервісів: $e");
  }
}

class WNodeApp extends StatefulWidget {
  const WNodeApp({super.key});

  @override
  State<WNodeApp> createState() => _WNodeAppState();
}

class _WNodeAppState extends State<WNodeApp> with WidgetsBindingObserver {
  // Ключі для глобального доступу до вікон та сповіщень
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeController.theme.addListener(_onTheme);

    Future.delayed(const Duration(seconds: 3), () {
      _initConnectivityListener();
    });

    // Поки додаток відкритий — пробуємо віддати чергу на сервер кожні 20 с.
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      DBService().syncWithCloud();
    });
    AdminLink.instance.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdminLink.instance.start();
      DBService().syncWithCloud();
    }
  }

  void _onTheme() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          AppColors.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          AppColors.isDark ? Brightness.dark : Brightness.light,
    ));
    if (mounted) setState(() {});
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online) {
        _wasOffline = true;
        return;
      }
      try {
        await DBService().syncWithCloud();
        if (!_wasOffline) return;
        _wasOffline = false;

        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_rounded, color: Color(0xFFE7EEF3), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Зв\'язок відновлено. Дані пішли на W1.2',
                    style: TextStyle(
                        color: Color(0xFFE7EEF3),
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2A3138),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0x66FFFFFF))),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        debugPrint("❌ Помилка авто-синхронізації: $e");
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeController.theme.removeListener(_onTheme);
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldKey,
      title: 'W-Node',
      debugShowCheckedModeBanner: false,
      themeMode: AppColors.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.accent,
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: AppColors.accent,
          secondary: AppColors.accentBlue,
          surface: AppColors.card,
          onPrimary: AppColors.onAccent,
          onSurface: AppColors.textMain,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.accent,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentBlue,
          surface: AppColors.card,
          onPrimary: AppColors.onAccent,
          onSurface: AppColors.textMain,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.card,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
