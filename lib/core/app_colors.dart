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
  /// Поле — нічний лісовий камуфляж.
  static const _hud = _Palette(
    bg: Color(0xFF121610),
    card: Color(0xFF1C2418),
    text: Color(0xFFF3F0E6),
    muted: Color(0xFFA8B09A),
    accent: Color(0xFF9AAE62),
    accentBlue: Color(0xFFC4B07A),
    warning: Color(0xFFC4A06A),
    danger: Color(0xFF8C5A48),
    shadowTop: Color(0x33FFFFFF),
    shadowBottom: Color(0x88000000),
    onAccent: Color(0xFFF4F1E6),
    goldDeep: Color(0xFF2A3324),
    goldLight: Color(0x66D7C49A),
  );

  /// День — світлий хакі.
  static const _light = _Palette(
    bg: Color(0xFFE4D7C0),
    card: Color(0xFFF3E8D4),
    text: Color(0xFF241C14),
    muted: Color(0xFF6E5E48),
    accent: Color(0xFF3E5330),
    accentBlue: Color(0xFF6A5438),
    warning: Color(0xFF8A6230),
    danger: Color(0xFF7A4038),
    shadowTop: Color(0xFFFFF8EE),
    shadowBottom: Color(0x33281810),
    onAccent: Color(0xFFF7F1E6),
    goldDeep: Color(0xFFC4B08A),
    goldLight: Color(0xF2FFF8EC),
  );

  /// Олива — мох.
  static const _corporate = _Palette(
    bg: Color(0xFF141A12),
    card: Color(0xFF1E281C),
    text: Color(0xFFE8F0E4),
    muted: Color(0xFF9AAB96),
    accent: Color(0xFF8FA86A),
    accentBlue: Color(0xFFC6B48A),
    warning: Color(0xFFD2B48C),
    danger: Color(0xFFC48A78),
    shadowTop: Color(0x33FFFFFF),
    shadowBottom: Color(0x88000000),
    onAccent: Color(0xFFF4F1E6),
    goldDeep: Color(0xFF24301E),
    goldLight: Color(0x66C5D4B0),
  );

  /// Ніч — майже чорний ліс.
  static const _tactical = _Palette(
    bg: Color(0xFF0C100E),
    card: Color(0xFF161C14),
    text: Color(0xFFF2F0E8),
    muted: Color(0xFF8E9888),
    accent: Color(0xFF7E9458),
    accentBlue: Color(0xFFB7A078),
    warning: Color(0xFFC4A06A),
    danger: Color(0xFFA87858),
    shadowTop: Color(0x22FFFFFF),
    shadowBottom: Color(0x99000000),
    onAccent: Color(0xFFF4F1E6),
    goldDeep: Color(0xFF1C2418),
    goldLight: Color(0x55C4B48A),
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

  static bool get isDark => UserConfig().themeId != AppThemeId.light;

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
        return const [Color(0xFFF3E6CC), Color(0xFFE4D3B4), Color(0xFFCDB892)];
      case AppThemeId.corporate:
        return const [Color(0xFF24301C), Color(0xFF141C12), Color(0xFF0C120C)];
      case AppThemeId.tactical:
        return const [Color(0xFF161C14), Color(0xFF0C100E), Color(0xFF070A08)];
      default:
        return const [Color(0xFF24301C), Color(0xFF141A12), Color(0xFF0C100C)];
    }
  }

  static Color get glassTint {
    switch (UserConfig().themeId) {
      case AppThemeId.light:
        return const Color(0xFFF6E7CF);
      case AppThemeId.corporate:
        return const Color(0xFFC5D4B0);
      case AppThemeId.tactical:
        return const Color(0xFFC4B48A);
      default:
        return const Color(0xFFD5C49A);
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
      color: light ? const Color(0xFFE7D8BE) : const Color(0xFF1A2216),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: borderColor ??
              (light ? const Color(0xFF8A7848) : const Color(0xFF3A4632)),
          width: 1.1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          offset: Offset(0, 8),
          blurRadius: 14,
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
