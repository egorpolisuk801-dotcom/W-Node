import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Внутрішні модулі системи
import 'core/user_config.dart';
import 'services/db_service.dart';
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Паралельно завантажуємо конфіг і пуш-сповіщення
    await Future.wait([
      UserConfig().load(),
      NotificationHelper.initSystemNotifications(),
    ]);

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

class _WNodeAppState extends State<WNodeApp> {
  // Ключі для глобального доступу до вікон та сповіщень
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    // Запуск слухача інтернету із затримкою
    Future.delayed(const Duration(seconds: 3), () {
      _initConnectivityListener();
    });

    // Запуск перевірки оновлень (після того, як відмалюється Splash)
    Future.delayed(const Duration(seconds: 4), () {
      if (_navigatorKey.currentContext != null) {
        AppUpdater.checkForUpdates(_navigatorKey.currentContext!);
      }
    });
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      // Якщо інтернет є (не 'none')
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        try {
          await DBService().syncWithCloud();

          // Показуємо красиве сповіщення про відновлення зв'язку
          _scaffoldKey.currentState?.showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi_rounded, color: Colors.black, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Зв\'язок відновлено. Склади синхронізовано.',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF00E676),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (e) {
          debugPrint("❌ Помилка авто-синхронізації: $e");
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
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldKey,
      title: 'W-Logistics',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      // Глобальна тактична тема додатку
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            const Color(0xFF0B1120), // Глибокий чорно-синій фон
        primaryColor: const Color(0xFF00E676), // Неоновий зелений
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00B0FF),
          surface: Color(0xFF1E293B), // Колір карток
        ),
        fontFamily: 'Roboto', // Базовий системний шрифт
      ),
      home: const SplashScreen(),
    );
  }
}

// =======================================================
// 🚀 МОДУЛЬ АВТОМАТИЧНОГО ОНОВЛЕННЯ СИСТЕМИ
// =======================================================
class AppUpdater {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // Отримуємо поточну версію з паспорта програми
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // Запитуємо хмару про актуальну версію
      final response = await Supabase.instance.client
          .from('global_settings')
          .select()
          .inFilter('setting_key', ['app_version', 'apk_url']);

      String latestVersion = '';
      String apkUrl = '';

      for (var row in response) {
        if (row['setting_key'] == 'app_version') {
          latestVersion = row['setting_value'].toString();
        }
        if (row['setting_key'] == 'apk_url') {
          apkUrl = row['setting_value'].toString();
        }
      }

      // Якщо версії не збігаються — б'ємо на сполох
      if (latestVersion.isNotEmpty && currentVersion != latestVersion) {
        _showUpdateDialog(context, currentVersion, latestVersion, apkUrl);
      }
    } catch (e) {
      debugPrint("⚠️ Помилка перевірки оновлень: $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String currentVersion,
      String newVersion, String url) {
    showDialog(
      context: context,
      barrierDismissible: false, // Блокуємо закриття вікна кліком повз нього
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1120), // Термінальний фон
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00E676), width: 1.5),
          ),
          // 🔥 ТУТ ВИПРАВЛЕНО ЖОВТУ СТРІЧКУ 🔥
          title: Row(
            children: [
              const Icon(Icons.system_update_alt, color: Color(0xFF00E676)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "СИСТЕМНЕ ОНОВЛЕННЯ",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 16, // Трохи зменшили для безпеки
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Знайдено критичне оновлення модуля логістики. Завантажте файл для продовження роботи.",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              // Блок з версіями в стилі терміналу
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("> Поточна версія: v$currentVersion",
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontFamily: 'Courier',
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Text("> Актуальна база: v$newVersion",
                        style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontFamily: 'Courier',
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ПІЗНІШЕ",
                  style: TextStyle(color: Colors.grey, letterSpacing: 1.0)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                elevation: 10,
                shadowColor: const Color(0xFF00E676).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () async {
                try {
                  final Uri fileUrl = Uri.parse(url);
                  if (await canLaunchUrl(fileUrl)) {
                    await launchUrl(fileUrl,
                        mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint("Помилка відкриття посилання: $e");
                }
              },
              child: const Text("ОНОВИТИ ЗАРАЗ",
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            ),
          ],
        );
      },
    );
  }
}
