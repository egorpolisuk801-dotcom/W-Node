import 'package:flutter/material.dart';
import 'dart:async';

// 🔥 ПІДКЛЮЧЕНО СПРАВЖНІЙ ГОЛОВНИЙ ЕКРАН 🔥
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _loadingText = "ІНІЦІАЛІЗАЦІЯ W-NODE CORE...";
  double _progressValue = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Налаштування анімації пульсації логотипу
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Запуск хакерської послідовності завантаження
    _startBootSequence();
  }

  void _startBootSequence() async {
    // Етап 1: Початок
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _loadingText = "ПІДКЛЮЧЕННЯ ДО SUPABASE CLOUD...";
      _progressValue = 0.35;
    });

    // Етап 2: Синхронізація
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _loadingText = "СИНХРОНІЗАЦІЯ ДАНИХ СКЛАДІВ...";
      _progressValue = 0.75;
    });

    // Етап 3: Фіналізація
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _loadingText = "СИСТЕМА АКТИВОВАНА. ВХІД...";
      _progressValue = 1.0;
    });

    // Коротка пауза для ефекту "успіху"
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // 🔥 ПЕРЕХІД НА ГОЛОВНИЙ ЕКРАН (ТЕПЕР НА HOMESCREEN) 🔥
    // pushReplacement видаляє Splash з пам'яті, щоб не можна було повернутися назад
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(), // <--- ВАЖЛИВА ЗМІНА ТУТ
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Плавне розчинення (Fade) при переході
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120), // Глибокий тактичний фон
      body: Stack(
        children: [
          // Радіальний градієнт для ефекту глибини
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF00E676).withOpacity(0.08),
                    const Color(0xFF0B1120),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Пульсуючий неоновий логотип
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF00E676), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E676).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.memory_rounded,
                      size: 80,
                      color: Color(0xFF00E676),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Назва системи
                const Text(
                  "W-LOGISTICS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "SECURE COMMAND CENTER",
                  style: TextStyle(
                    color: Color(0xFF00B0FF), // Неоновий синій підзаголовок
                    fontSize: 14,
                    letterSpacing: 3.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                // Нижня панель завантаження (Термінал)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 45.0, vertical: 60.0),
                  child: Column(
                    children: [
                      // Тонка смуга прогресу
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progressValue,
                          backgroundColor: const Color(0xFF1E293B),
                          color: const Color(0xFF00E676),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 25),
                      // Рядок стану термінала
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.terminal_rounded,
                              color: Color(0xFF00E676), size: 18),
                          const SizedBox(width: 12),
                          Text(
                            _loadingText,
                            style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontFamily: 'Courier', // Моноширинний шрифт
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
