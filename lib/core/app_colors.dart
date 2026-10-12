import 'package:flutter/material.dart';
import 'theme_controller.dart';
import 'user_config.dart';

class _Palette {
  final Color bg;
  final Color card;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentBlue;
  final Color warning;
  final Color danger;
  final Color shadowTop;
  final Color shadowBottom;
  final Color onAccent;
  final Color goldDeep;
  final Color goldLight;

  const _Palette({
    required this.bg,
    required this.card,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentBlue,
    required this.warning,
    required this.danger,
    required this.shadowTop,
    required this.shadowBottom,
    required this.onAccent,
    required this.goldDeep,
    required this.goldLight,
  });
}

class AppColors {
  /// Поле — холодне срібло.
  static const _hud = _Palette(
    bg: Color(0xFFD5DCE6),
    card: Color(0x73FFFFFF),
    text: Color(0xFF1B2430),
    muted: Color(0xFF4A5968),
    accent: Color(0xFF243140),
    accentBlue: Color(0xFF3E5368),
    warning: Color(0xFF8A6A32),
    danger: Color(0xFF8E3E38),
    shadowTop: Color(0xFFFFFFFF),
    shadowBottom: Color(0x33000000),
    onAccent: Color(0xFFF7FAFC),
    goldDeep: Color(0xFFB7C3D0),
    goldLight: Color(0xF2FFFFFF),
  );

  /// День — тепле пісочне скло, не копія Поля.
  static const _light = _Palette(
    bg: Color(0xFFE6D7C2),
    card: Color(0x73FFF6EA),
    text: Color(0xFF2C2418),
    muted: Color(0xFF6A5A46),
    accent: Color(0xFF2F5A42),
    accentBlue: Color(0xFF6A4E32),
    warning: Color(0xFF8A5A28),
    danger: Color(0xFF8E3E38),
    shadowTop: Color(0xFFFFF8EE),
    shadowBottom: Color(0x33281810),
    onAccent: Color(0xFFF8F3EA),
    goldDeep: Color(0xFFCDB89A),
    goldLight: Color(0xF2FFF6EA),
  );

  /// Олива — скло з польовим відтінком.
  static const _corporate = _Palette(
    bg: Color(0xFF1C221C),
    card: Color(0x2EFFFFFF),
    text: Color(0xFFE6EEE6),
    muted: Color(0xFFA3B2A3),
    accent: Color(0xFF9BBF8A),
    accentBlue: Color(0xFFC5D4C0),
    warning: Color(0xFFD2B48C),
    danger: Color(0xFFD48980),
    shadowTop: Color(0x55FFFFFF),
    shadowBottom: Color(0x66000000),
    onAccent: Color(0xFF142016),
    goldDeep: Color(0xFF2A332A),
    goldLight: Color(0x66FFFFFF),
  );

  /// Нічне скло.
  static const _tactical = _Palette(
    bg: Color(0xFF121820),
    card: Color(0x2EFFFFFF),
    text: Color(0xFFE4EAF0),
    muted: Color(0xFF93A4B5),
    accent: Color(0xFF8FB4C8),
    accentBlue: Color(0xFFD0DCE4),
    warning: Color(0xFFD2B48C),
    danger: Color(0xFFD48980),
    shadowTop: Color(0x55FFFFFF),
    shadowBottom: Color(0x66000000),
    onAccent: Color(0xFF121820),
    goldDeep: Color(0xFF24303A),
    goldLight: Color(0x66FFFFFF),
  );

  static _Palette get _p {
    switch (UserConfig().themeId) {
      case AppThemeId.light:
        return _light;
      case AppThemeId.corporate:
        return _corporate;
      case AppThemeId.tactical:
        return _tactical;
      default:
        return _hud;
    }
  }

  static bool get isDark {
    final id = UserConfig().themeId;
    return id == AppThemeId.corporate || id == AppThemeId.tactical;
  }

  static Color get bg => _p.bg;
  static Color get card => _p.card;
  static Color get surface => _p.card;
  static Color get textMain => _p.text;
  static Color get muted => _p.muted;
  static Color get accent => _p.accent;
  static Color get accentBlue => _p.accentBlue;
  static Color get neonBlue => _p.accentBlue;
  static Color get warning => _p.warning;
  static Color get danger => _p.danger;
  static Color get onAccent => _p.onAccent;
  static Color get shadowTop => _p.shadowTop;
  static Color get shadowBottom => _p.shadowBottom;
  static Color get shadowDark => shadowBottom;
  static Color get goldDeep => _p.goldDeep;
  static Color get goldLight => _p.goldLight;

  static Color get ice =>
      isDark ? const Color(0xFFB7CDD8) : const Color(0xFF3E5C6A);
  static Color get sun =>
      isDark ? const Color(0xFFD2B48C) : const Color(0xFF8A6A32);
  static Color get silk =>
      isDark ? const Color(0xFFB7C4A8) : const Color(0xFF4E6248);

  static List<Color> get scene {
    switch (UserConfig().themeId) {
      case AppThemeId.light:
        return const [Color(0xFFF8F1E4), Color(0xFFE6D4BA), Color(0xFFD4C0A2)];
      case AppThemeId.corporate:
        return const [Color(0xFF2C3828), Color(0xFF1A2218), Color(0xFF10160F)];
      case AppThemeId.tactical:
        return const [Color(0xFF1A2836), Color(0xFF101820), Color(0xFF080E14)];
      default:
        return const [Color(0xFFF4F7FB), Color(0xFFD7DEE8), Color(0xFFC5CEDA)];
    }
  }

  static Color get glassTint {
    switch (UserConfig().themeId) {
      case AppThemeId.light:
        return const Color(0xFFFFF3E4);
      case AppThemeId.corporate:
        return const Color(0xFFD5E4C8);
      case AppThemeId.tactical:
        return const Color(0xFFC9D7E6);
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  static Color get border =>
      (isDark ? glassTint : Colors.white).withOpacity(isDark ? 0.22 : 0.72);

  static LinearGradient get metal => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                accent.withOpacity(0.38),
                accent.withOpacity(0.12),
              ]
            : [
                Colors.white.withOpacity(0.70),
                glassTint.withOpacity(0.28),
              ],
      );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
          offset: const Offset(0, 12),
          blurRadius: 24,
        ),
        BoxShadow(
          color: Colors.white.withOpacity(isDark ? 0.06 : 0.8),
          offset: const Offset(0, -1),
          blurRadius: 0,
        ),
      ];

  static BoxDecoration cardDeco({Color? borderColor, double radius = 22}) {
    final light = !isDark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: light
            ? [
                glassTint.withOpacity(0.45),
                glassTint.withOpacity(0.28),
                glassTint.withOpacity(0.16),
              ]
            : [
                glassTint.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
                const Color(0x55000000),
              ],
        stops: const [0.0, 0.45, 1.0],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: borderColor ??
              Colors.white.withOpacity(light ? 0.85 : 0.28),
          width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x240B1520),
          offset: Offset(0, 14),
          blurRadius: 18,
          spreadRadius: -8,
        ),
      ],
    );
  }

  static String formatPrice(dynamic raw) {
    final v = double.tryParse('$raw') ?? 0;
    if (v <= 0) return '';
    if (v == v.roundToDouble()) return '${v.toInt()} грн';
    return '${v.toStringAsFixed(2)} грн';
  }
}
