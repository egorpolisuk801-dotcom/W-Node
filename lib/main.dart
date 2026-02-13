import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/user_config.dart';
import 'services/db_service.dart';
import 'core/notification_helper.dart';

// ВРЕМЕННО ОТКЛЮЧИЛИ ТВОЙ SPLASH SCREEN ДЛЯ ПРОВЕРКИ
// import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WNodeApp());
  _initServicesInBackground();
}

Future<void> _initServicesInBackground() async {
  try {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    await NotificationHelper.initSystemNotifications();
    final config = UserConfig();
    await config.load();

    debugPrint("✅ Фоновые сервисы запущены");
  } catch (e) {
    debugPrint("⚠️ Ошибка: $e");
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
              content: Text('✅ Связь восстановлена!'),
              backgroundColor: Color(0xFF00E676),
              duration: Duration(seconds: 3),
            ),
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
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldKey,
      debugShowCheckedModeBanner: false,
      // СТАВИМ ЗАГЛУШКУ ВМЕСТО ТВОЕГО SPLASH SCREEN
      home: const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00E676)),
              SizedBox(height: 20),
              Text(
                "W-NODE SYSTEM BOOT...",
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
