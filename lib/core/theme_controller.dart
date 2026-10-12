import 'package:flutter/foundation.dart';
import 'user_config.dart';

class AppThemeId {
  static const glass = 'glass';
  static const brutal = 'brutal';
  static const neo = 'neo';
  static const cyber = 'cyber';

  static const all = [glass, brutal, neo, cyber];

  static String canonical(String id) {
    switch (id) {
      case glass:
      case brutal:
      case neo:
      case cyber:
        return id;
      case 'light':
        return glass;
      case 'corporate':
        return neo;
      case 'tactical':
        return brutal;
      default:
        return cyber;
    }
  }

  static String title(String id) {
    switch (canonical(id)) {
      case glass:
        return 'Скло';
      case brutal:
        return 'Бруталізм';
      case neo:
        return 'Нео';
      default:
        return 'Кібер';
    }
  }

  static String hint(String id) {
    switch (canonical(id)) {
      case glass:
        return 'Глассморфізм, світла';
      case brutal:
        return 'Необруталізм, світла';
      case neo:
        return 'Неоморфізм, світла';
      default:
        return 'Темний кіберпанк';
    }
  }
}

class ThemeController {
  static final ValueNotifier<String> theme =
      ValueNotifier<String>(AppThemeId.cyber);

  static void set(String id) {
    final next = AppThemeId.canonical(id);
    theme.value = next;
    UserConfig().setThemeId(next);
  }

  static void loadFromConfig() {
    theme.value = AppThemeId.canonical(UserConfig().themeId);
  }
}
