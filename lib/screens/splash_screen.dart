import 'dart:async';
import 'package:flutter/material.dart';

// 🛑 ВРЕМЕННО ЗАБЛОКИРОВАЛИ ВСЕ ИМПОРТЫ ТВОИХ ФАЙЛОВ 🛑
// Если ошибка в них, то без них экран запустится.
// import '../core/app_colors.dart';
// import '../services/db_service.dart';
// import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Просто ждем 3 секунды и ничего не делаем. Никакой базы, никаких переходов.
    Future.delayed(const Duration(seconds: 3), () {
      debugPrint("⏳ 3 секунды прошло. UI работает стабильно.");
    });
  }

  @override
  Widget build(BuildContext context) {
    // Используем жестко заданные цвета, чтобы исключить сбой в AppColors
    const bgColor = Color(0xFF121212);
    const accentColor = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(color: accentColor, width: 2),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, size: 80, color: accentColor),
                  SizedBox(height: 10),
                  Text(
                    "W-NODE ISOLATED",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: accentColor),
          ],
        ),
      ),
    );
  }
}
