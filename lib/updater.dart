import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdater {
  // Головна функція перевірки
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Дізнаємося поточну версію програми на телефоні
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Йдемо в Supabase за найсвіжішою версією
      final response = await Supabase.instance.client
          .from('global_settings')
          .select()
          .inFilter('setting_key', ['app_version', 'apk_url']);

      String latestVersion = '';
      String apkUrl = '';

      // Розбираємо відповідь від сервера
      for (var row in response) {
        if (row['setting_key'] == 'app_version')
          latestVersion = row['setting_value'].toString();
        if (row['setting_key'] == 'apk_url')
          apkUrl = row['setting_value'].toString();
      }

      // 3. Порівнюємо версії
      if (latestVersion.isNotEmpty && currentVersion != latestVersion) {
        // Якщо версії не збігаються — показуємо вікно оновлення!
        _showUpdateDialog(context, latestVersion, apkUrl);
      }
    } catch (e) {
      debugPrint("Помилка перевірки оновлень: $e");
    }
  }

  // Вікно, яке вискочить користувачу
  static void _showUpdateDialog(
      BuildContext context, String newVersion, String url) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Забороняємо закрити кліком повз вікно (опціонально)
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("🚀 Доступне оновлення!",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
              "Знайдено нову версію системи W1.2 (v$newVersion).\n\nОновіть програму, щоб отримати нові функції та покращення стабільності."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Пізніше", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF10B981), // Твій фірмовий зелений
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final Uri fileUrl = Uri.parse(url);
                // Відкриваємо браузер для завантаження APK
                if (await canLaunchUrl(fileUrl)) {
                  await launchUrl(fileUrl,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: const Text("Оновити зараз",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
