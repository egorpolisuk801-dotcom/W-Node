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
  /// Скло — світлий глассморфізм.
  static const _glass = _Palette(
    bg: Color(0xFFD5E3F4),
    card: Color(0xCCF7FBFF),
    text: Color(0xFF17304A),
    muted: Color(0xFF5E7590),
    accent: Color(0xFF2F6BFF),
    accentBlue: Color(0xFF7A5CFF),
    warning: Color(0xFFE08A2A),
    danger: Color(0xFFE15B6A),
    shadowTop: Color(0xB3FFFFFF),
    shadowBottom: Color(0x1A1A2744),
    onAccent: Color(0xFFF7FBFF),
    goldDeep: Color(0xFFB9CDE4),
    goldLight: Color(0xE6FFFFFF),
  );

  /// Бруталізм — світлий, чорна рамка.
  static const _brutal = _Palette(
    bg: Color(0xFFFFF4D8),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF111111),
    muted: Color(0xFF3A3A3A),
    accent: Color(0xFFFFD000),
    accentBlue: Color(0xFFFF4D6A),
    warning: Color(0xFF111111),
    danger: Color(0xFFFF3B30),
    shadowTop: Color(0xFFFFFFFF),
    shadowBottom: Color(0xFF111111),
    onAccent: Color(0xFF111111),
    goldDeep: Color(0xFF111111),
    goldLight: Color(0xFFFFE14A),
  );

  /// Неоморфізм — м’який світлий рельєф.
  static const _neo = _Palette(
    bg: Color(0xFFE4EAF3),
    card: Color(0xFFE4EAF3),
    text: Color(0xFF2C3644),
    muted: Color(0xFF7B8798),
    accent: Color(0xFF8B97AB),
    accentBlue: Color(0xFF9AA6BA),
    warning: Color(0xFFC4A574),
    danger: Color(0xFFC47A7A),
    shadowTop: Color(0xFFF8FBFF),
    shadowBottom: Color(0xFFA3B1C6),
    onAccent: Color(0xFFF7F9FC),
    goldDeep: Color(0xFFC5D0E0),
    goldLight: Color(0xFFF4F7FB),
  );

  /// Кіберпанк — темний неон.
  static const _cyber = _Palette(
    bg: Color(0xFF07060D),
    card: Color(0xFF12101A),
    text: Color(0xFFE7F6FF),
    muted: Color(0xFF7E8CA6),
    accent: Color(0xFF00E5FF),
    accentBlue: Color(0xFFFF2BD6),
    warning: Color(0xFFFFE14A),
    danger: Color(0xFFFF3355),
    shadowTop: Color(0x6600E5FF),
    shadowBottom: Color(0xCC000000),
    onAccent: Color(0xFF041016),
    goldDeep: Color(0xFF1A1030),
    goldLight: Color(0x66FF2BD6),
  );

  static _Palette get _p {
    switch (UserConfig().themeId) {
      case AppThemeId.glass:
        return _glass;
      case AppThemeId.brutal:
        return _brutal;
      case AppThemeId.neo:
        return _neo;
      default:
        return _cyber;
    }
  }

  static bool get isDark => UserConfig().themeId == AppThemeId.cyber;

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
      case AppThemeId.glass:
        return const [Color(0xFFEAF3FC), Color(0xFFD5E3F4), Color(0xFFC5D6EE)];
      case AppThemeId.brutal:
        return const [Color(0xFFFFF8E8), Color(0xFFFFF4D8), Color(0xFFFFE7A8)];
      case AppThemeId.neo:
        return const [Color(0xFFF2F5FA), Color(0xFFE4EAF3), Color(0xFFD5DEEA)];
      default:
        return const [Color(0xFF120818), Color(0xFF07060D), Color(0xFF030208)];
    }
  }

  static Color get glassTint {
    switch (UserConfig().themeId) {
      case AppThemeId.glass:
        return const Color(0xFFF7FBFF);
      case AppThemeId.brutal:
        return const Color(0xFFFFFFFF);
      case AppThemeId.neo:
        return const Color(0xFFE4EAF3);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  static Color get border {
    switch (UserConfig().themeId) {
      case AppThemeId.brutal:
        return const Color(0xFF111111);
      case AppThemeId.neo:
        return const Color(0x00000000);
      case AppThemeId.cyber:
        return const Color(0xFF00E5FF);
      default:
        return const Color(0xCCFFFFFF);
    }
  }

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
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.border, width: 1.1),
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
