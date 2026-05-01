import 'package:flutter/material.dart';
import 'user_config.dart';

class AppColors {
  // === СВЕТЛАЯ ТЕМА (Чистый титан) ===
  static const Color _bgLight = Color(0xFFE6EAEF);
  static const Color _textMainLight = Color(0xFF2D3436);
  static const Color _shadowLightTop = Color(0xFFFFFFFF);
  static const Color _shadowLightBottom = Color(0xFFA3B1C6);

  // === ТЕМНАЯ ТЕМА (Dark Tactical / Gunmetal) ===
  static const Color _bgDark = Color(0xFF181A1C); // Глубокий карбон/сталь
  static const Color _textMainDark =
      Color(0xFFE2E5E9); // Чистый, но не слепящий белый

  // Верхний блик: резкий, холодный серый (эффект металла)
  static const Color _shadowDarkTop = Color(0xFF26292D);

  // Нижняя тень: жесткая, почти черная (эффект толстой пластины)
  static const Color _shadowDarkBottom = Color(0xFF0C0D0E);

  // === АКЦЕНТЫ (Неоновый HUD) ===
  static const Color accent =
      Color(0xFFFF6D00); // Тактический оранжевый (Hazard Orange)
  static const Color accentBlue =
      Color(0xFF00E5FF); // Неоновый голубой (Cyan HUD)

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
