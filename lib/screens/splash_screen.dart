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

    // 1. Настраиваем контроллер анимации (длится 2 секунды)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // 2. Анимация увеличения (Эффект пружины)
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // 3. Анимация прозрачности (Появление)
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Запускаем анимацию
    _controller.forward();

    // 4. Запускаем инициализацию базы данных в фоне
    _initData();
  }

  Future<void> _initData() async {
    // Тут мы реально подключаемся к базе, пока идет анимация
    await DBService().initConnection();

    // Ждем минимум 3 секунды, чтобы юзер успел насладиться красотой
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg, // Темный фон
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Анимированный Логотип
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bg,
                          boxShadow: [
                            // Внешнее свечение (ВАУ эффект)
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.6),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                            // Внутреннее свечение
                            BoxShadow(
                              color: AppColors.accentBlue.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(0, 0),
                            ),
                          ],
                          border: Border.all(
                              color: AppColors.accent.withOpacity(0.5),
                              width: 2)),
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
                                  Shadow(
                                      color: AppColors.accent, blurRadius: 15),
                                ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 50),

            // Индикатор загрузки
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.withOpacity(0.2),
                color: AppColors.accent,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "INITIALIZING SYSTEM...",
              style: TextStyle(
                  color: AppColors.accentBlue,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }
}
