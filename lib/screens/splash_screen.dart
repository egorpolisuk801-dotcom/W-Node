import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/tactical_ui.dart';
import '../core/fun_moments.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _ring = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  @override
  void dispose() {
    _in.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: TacBackdrop(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _in, curve: Curves.easeOut),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
              child: Column(
                children: [
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _ring,
                    builder: (_, child) {
                      return Container(
                        width: 132,
                        height: 132,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent
                                .withOpacity(0.25 + 0.45 * (1 - _ring.value)),
                            width: 1.2,
                          ),
                        ),
                        child: Transform.scale(
                          scale: 1 + 0.04 * (0.5 - (_ring.value - 0.5).abs()),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 104,
                      height: 104,
                      alignment: Alignment.center,
                      child: VolGlass(
                        radius: 32,
                        padding: const EdgeInsets.all(22),
                        glow: AppColors.accent,
                        child: Icon(Icons.inventory_2_rounded,
                            color: AppColors.textMain, size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('W-NODE', style: TacStyle.stencil.copyWith(fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('Склад',
                      style: TacStyle.title.copyWith(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text('Облік складу',
                      style: TacStyle.muted.copyWith(fontSize: 15)),
                  const Spacer(),
                  Text(FunCopy.splashHint(),
                      style: TacStyle.muted.copyWith(fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
