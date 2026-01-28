import 'package:flutter/material.dart';
import 'app_colors.dart';

class NotificationHelper {
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green, Icons.check_circle_outline);
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.redAccent, Icons.error_outline);
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, AppColors.accentBlue, Icons.info_outline);
  }

  static void _showSnackBar(
      BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Убираем предыдущие
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.bg, // Темный фон
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: color.withOpacity(0.5), width: 1), // Цветная обводка
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
