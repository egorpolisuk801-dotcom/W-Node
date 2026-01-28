import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppConstants {
  // Числа можно оставить const, они не зависят от других файлов
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 15.0;

  // Стиль текста делаем 'final', чтобы Flutter не ругался на использование цвета
  static final TextStyle neonTitleStyle = TextStyle(
    color: AppColors.neonBlue, // Цвет берется из app_colors.dart
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
    shadows: [
      Shadow(
        color: AppColors.neonBlue,
        blurRadius: 10,
      )
    ],
  );
}
