import 'package:flutter/foundation.dart';
import 'user_config.dart';

class AppThemeId {
  static const hud = 'hud';
  static const light = 'light';
  static const corporate = 'corporate';
  static const tactical = 'tactical';

  static const all = [hud, light, corporate, tactical];

  static String title(String id) {
    switch (id) {
      case light:
        return 'День';
      case corporate:
        return 'Олива';
      case tactical:
        return 'Ніч';
      default:
        return 'Поле';
    }
  }

  static String hint(String id) {
    switch (id) {
      case light:
        return 'Світлий хакі';
      case corporate:
        return 'Мох';
      case tactical:
        return 'Нічний ліс';
      default:
        return 'Лісовий камуфляж';
    }
  }
}

class ThemeController {
  static final ValueNotifier<String> theme =
      ValueNotifier<String>(AppThemeId.hud);

  static void set(String id) {
    theme.value = id;
    UserConfig().setThemeId(id);
  }

  static void loadFromConfig() {
    theme.value = UserConfig().themeId;
  }
}
