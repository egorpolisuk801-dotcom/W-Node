import 'dart:ui';

import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/fun_moments.dart';
import '../core/tactical_ui.dart';
import '../core/theme_controller.dart';
import '../core/user_config.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _bar;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _bar = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  void dispose() {
    _in.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = UserConfig().themeId;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: TacBackdrop(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _in, curve: Curves.easeOut),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
              child: Column(
                children: [
                  const Spacer(),
                  _IntroMark(id: id),
                  const SizedBox(height: 28),
                  Text(AppThemeId.title(id).toUpperCase(),
                      style: TacStyle.stencil.copyWith(fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('Склад', style: TacStyle.title.copyWith(fontSize: 42)),
                  const SizedBox(height: 8),
                  Text(_line(id), style: TacStyle.muted.copyWith(fontSize: 15)),
                  const Spacer(),
                  Text(FunCopy.splashHint(),
                      textAlign: TextAlign.center,
                      style: TacStyle.muted.copyWith(fontSize: 14)),
                  const SizedBox(height: 16),
                  _IntroBar(id: id, progress: _bar),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _line(String id) {
    switch (id) {
      case AppThemeId.brutal:
        return 'Прямі кути. Чорна рамка.';
      case AppThemeId.neo:
        return 'М’який рельєф без рамки.';
      case AppThemeId.cyber:
        return 'Темний екран. Неонові лінії.';
      default:
        return 'Матове скло на світлому тлі.';
    }
  }
}

class _IntroMark extends StatelessWidget {
  final String id;
  const _IntroMark({required this.id});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.inventory_2_rounded,
        size: 42,
        color: id == AppThemeId.brutal
            ? const Color(0xFF111111)
            : id == AppThemeId.cyber
                ? const Color(0xFF00E5FF)
                : AppColors.textMain);
    if (id == AppThemeId.brutal) {
      return Container(
        width: 112,
        height: 112,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFFFE14A),
          border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF111111), width: 4)),
          boxShadow: [
            BoxShadow(color: Color(0xFF111111), offset: Offset(8, 8)),
          ],
        ),
        child: icon,
      );
    }
    if (id == AppThemeId.neo) {
      return Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE4EAF3),
          boxShadow: [
            BoxShadow(
                color: Color(0xFFF8FBFF), offset: Offset(-8, -8), blurRadius: 16),
            BoxShadow(
                color: Color(0xFFA3B1C6), offset: Offset(8, 8), blurRadius: 16),
          ],
        ),
        child: icon,
      );
    }
    if (id == AppThemeId.cyber) {
      return Container(
        width: 116,
        height: 116,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF100E18),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF00E5FF), width: 1.4),
          boxShadow: const [
            BoxShadow(color: Color(0x6600E5FF), blurRadius: 18),
          ],
        ),
        child: icon,
      );
    }
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x99FFFFFF),
            border: Border.all(color: const Color(0xEEFFFFFF), width: 1.4),
          ),
          child: icon,
        ),
      ),
    );
  }
}

class _IntroBar extends StatelessWidget {
  final String id;
  final Animation<double> progress;
  const _IntroBar({required this.id, required this.progress});

  @override
  Widget build(BuildContext context) {
    final brutal = id == AppThemeId.brutal;
    final cyber = id == AppThemeId.cyber;
    final radius = brutal ? 0.0 : 99.0;
    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        return Container(
          height: brutal ? 14 : 8,
          decoration: BoxDecoration(
            color: brutal
                ? const Color(0xFFFFFFFF)
                : cyber
                    ? const Color(0xFF1A1630)
                    : AppColors.card,
            borderRadius: BorderRadius.circular(radius),
            border: brutal
                ? Border.all(color: const Color(0xFF111111), width: 3)
                : null,
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.value.clamp(0.04, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: brutal
                    ? const Color(0xFF111111)
                    : cyber
                        ? const Color(0xFF00E5FF)
                        : AppColors.accent,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: cyber
                    ? const [
                        BoxShadow(color: Color(0xAA00E5FF), blurRadius: 8)
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
