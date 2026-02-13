import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/db_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Запускаем безопасную инициализацию
    _safeInit();
  }

  Future<void> _safeInit() async {
    try {
      // 1. Минимальное время показа (3 секунды)
      final minDisplayTime = Future.delayed(const Duration(seconds: 3));

      // 2. Попытка подключения к БД с жестким таймаутом (5 секунд)
      // Если база не ответит за 5 секунд, вылетит ошибка, которую поймает catch
      final dbInit =
          DBService().initConnection().timeout(const Duration(seconds: 5));

      // Ждем завершения обоих процессов
      await Future.wait([minDisplayTime, dbInit]);
    } catch (e) {
      debugPrint("⚠️ Инициализация завершена с ошибкой/таймаутом: $e");
      // Даже если база упала, мы идем дальше, чтобы не висеть на заставке
    } finally {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.bg,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.6),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: AppColors.accentBlue.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner,
                        size: 80, color: AppColors.textMain),
                    const SizedBox(height: 10),
                    Text(
                      "W-NODE",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        letterSpacing: 5,
                        shadows: [
                          Shadow(color: AppColors.accent, blurRadius: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.withOpacity(0.1),
                color: AppColors.accent,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "INITIALIZING SYSTEM...",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
      ),
    );
  }
}
