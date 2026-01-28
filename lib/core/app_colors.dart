import 'package:flutter/material.dart';
import 'user_config.dart';

class AppColors {
  // === СВЕТЛАЯ ТЕМА ===
  static const Color _bgLight = Color(0xFFEFEEEE);
  static const Color _textMainLight = Color(0xFF3E4E5E);
  static const Color _shadowLightTop = Colors.white; // Белый блик
  static const Color _shadowLightBottom = Color(0xFFA6B0C3); // Серая тень

  // === ТЕМНАЯ ТЕМА (Исправлено) ===
  static const Color _bgDark = Color(0xFF292D32);
  static const Color _textMainDark = Color(0xFFE0E0E0);
  // Блик теперь темно-серый (светлее фона), а не белый!
  static const Color _shadowDarkTop = Color(0xFF3E444B);
  // Тень черная
  static const Color _shadowDarkBottom = Color(0xFF15171A);

  // === АКЦЕНТЫ ===
  static const Color accent = Color(0xFFFF8C42); // Оранжевый
  static const Color accentBlue = Color(0xFF4CB2FF); // Голубой

  // === ЛОГИКА ===
  static bool get isDark => UserConfig().isDarkMode;

  static Color get bg => isDark ? _bgDark : _bgLight;
  static Color get textMain => isDark ? _textMainDark : _textMainLight;

  static Color get shadowTop => isDark ? _shadowDarkTop : _shadowLightTop;
  static Color get shadowBottom =>
      isDark ? _shadowDarkBottom : _shadowLightBottom;

  static Color get shadowDark => shadowBottom;
  static Color get surface => bg;
}
