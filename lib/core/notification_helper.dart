import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'app_colors.dart';

class NotificationHelper {
  // ==========================================
  // 📱 СИСТЕМНЫЕ PUSH-УВЕДОМЛЕНИЯ (В ШТОРКУ)
  // ==========================================

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Инициализация (нужно вызвать при запуске приложения)
  static Future<void> initSystemNotifications() async {
    // Используем стандартную иконку приложения
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    // Запрос прав на уведомления (нужно для Android 13+)
    _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Вызов самого системного уведомления
  static Future<void> showSystemPush(String title, String body) async {
    // 1. Включаем вибрацию (если телефон её поддерживает)
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != null && hasVibrator) {
      Vibration.vibrate(duration: 500); // Короткий уверенный "вжик"
    }

    // 2. Настраиваем канал (Android требует каналы для пушей)
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'wnode_sync_channel', // ID канала
      'Синхронизация склада', // Имя канала в настройках
      channelDescription: 'Уведомления о фоновой синхронизации данных',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF00E676), // Твой зеленый цвет для иконки
      playSound: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // 3. Показываем пуш
    await _notificationsPlugin.show(
      0, // ID уведомления (0 - чтобы заменять старое, а не плодить список)
      title,
      body,
      platformDetails,
    );
  }

  // ==========================================
  // 🎨 ВНУТРЕННИЕ УВЕДОМЛЕНИЯ (SNACKBAR)
  // ==========================================

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
