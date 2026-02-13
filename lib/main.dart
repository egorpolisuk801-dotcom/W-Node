import 'dart:async'; // Добавили для таймеров и подписок
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Добавили плагин сети

import 'core/user_config.dart';
import 'services/db_service.dart'; // Подключаем твой сервис БД
import 'screens/splash_screen.dart';
import 'core/notification_helper.dart'; // 🔥 ДОБАВИЛИ ИМПОРТ ХЕЛПЕРА УВЕДОМЛЕНИЙ

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Инициализируем систему Push-уведомлений до запуска приложения
  await NotificationHelper.initSystemNotifications();

  // Настройка цвета статус-бара
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final config = UserConfig();
  await config.load();

  runApp(const WNodeApp());
}

// ПРЕВРАТИЛИ В STATEFUL WIDGET, ЧТОБЫ СЛУШАТЬ ИНТЕРНЕТ
class WNodeApp extends StatefulWidget {
  const WNodeApp({super.key});

  @override
  State<WNodeApp> createState() => _WNodeAppState();
}

class _WNodeAppState extends State<WNodeApp> {
  // Подписка на изменение сети
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // Ключ для вызова уведомлений из любого места программы
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();

    // Включаем "слухача" интернета при запуске программы
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      // Если появилась хоть какая-то связь (Wi-Fi, 4G, Ethernet)
      if (!results.contains(ConnectivityResult.none)) {
        print("🌐 Связь восстановлена! Проверяем офлайн-данные...");

        // ЗАПУСКАЕМ ТВОЮ ФУНКЦИЮ СИНХРОНИЗАЦИИ ИЗ db_service.dart
        await DBService().syncWithCloud();

        // Показываем красивое зеленое уведомление внутри приложения
        _scaffoldKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Связь восстановлена. Склад синхронизирован!',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Color(0xFF00E676), // Твой primaryColor
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating, // Плавающая плашка
          ),
        );

        // 🔥 ВЫЗЫВАЕМ СИСТЕМНЫЙ ПУШ И ВИБРАЦИЮ В ШТОРКУ 🔥
        NotificationHelper.showSystemPush(
          'W-Node: Связь восстановлена',
          'Офлайн-данные успешно отправлены на склад.',
        );
      }
    });
  }

  @override
  void dispose() {
    // Убиваем слушателя при закрытии приложения, чтобы не жрал батарею
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- ЦВЕТОВАЯ ПАЛИТРА (CYBERPUNK / PRO) ---
    const primaryColor = Color(0xFF00E676);
    const secondaryColor = Color(0xFF00B0FF);
    const bgColor = Color(0xFF121212);
    const cardColor = Color(0xFF1E1E1E);
    const errorColor = Color(0xFFFF5252);

    return MaterialApp(
      scaffoldMessengerKey:
          _scaffoldKey, // <-- ВАЖНО: Привязали ключ для уведомлений
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
          // ignore: deprecated_member_use
          background: bgColor,
          error: errorColor,
        ),
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 4,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        ),
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
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.black,
            elevation: 2,
            textStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
        ),
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
