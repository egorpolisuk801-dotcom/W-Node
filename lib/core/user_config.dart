import 'package:shared_preferences/shared_preferences.dart';

class UserConfig {
  static final UserConfig _instance = UserConfig._internal();
  factory UserConfig() => _instance;
  UserConfig._internal();

  late SharedPreferences _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // === НАСТРОЙКИ СЕРВЕРА ===
  String get dbHost =>
      _prefs.getString('db_host') ?? 'aws-1-eu-west-1.pooler.supabase.com';
  String get dbUser =>
      _prefs.getString('db_user') ?? 'postgres.qzgatfjezjzqshqpuejh';
  String get dbPass => _prefs.getString('db_pass') ?? 'EgorPolisuk0711';
  String get dbName => _prefs.getString('db_name') ?? 'postgres';

  // === СКЛАДЫ ===
  String get wh1Name => _prefs.getString('wh1_name') ?? 'Склад-1';
  String get wh2Name => _prefs.getString('wh2_name') ?? 'Склад-2';

  bool get isDarkMode => _prefs.getBool('is_dark_mode') ?? true;

  // === ВИДИМОСТЬ КАТЕГОРИЙ (ВЕЩИ) ===
  bool get itemShowDigits => _prefs.getBool('show_digits') ?? true;
  bool get itemShowLetters => _prefs.getBool('show_letters') ?? true;
  bool get itemShowShoes => _prefs.getBool('show_shoes') ?? true;
  bool get itemShowHats => _prefs.getBool('show_hats') ?? true;
  bool get itemShowHatsR => _prefs.getBool('show_hats_r') ?? true;
  bool get itemShowGloves => _prefs.getBool('show_gloves') ?? true;

  // === ВИДИМОСТЬ КАТЕГОРИЙ (ИНВЕНТАРЬ) ===
  bool get invShowDigits => _prefs.getBool('inv_digits') ?? true;
  bool get invShowLetters => _prefs.getBool('inv_letters') ?? true;
  bool get invShowShoes => _prefs.getBool('inv_shoes') ?? true;
  bool get invShowRanges => _prefs.getBool('inv_ranges') ?? true;

  // === ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ===
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  // === ГЛАВНОЕ СОХРАНЕНИЕ (ИСПРАВЛЕНО) ===
  // Теперь принимает ВСЕ параметры, которые отправляет SettingsScreen
  Future<void> save({
    required String host,
    required String user,
    required String pass,
    required String dbname,
    required String w1,
    required String w2,
    required bool darkMode,

    // Настройки видимости (с дефолтными значениями, чтобы не ломать старый код)
    bool iDig = true,
    bool iLet = true,
    bool iShoe = true,
    bool iHat = true,
    bool iHatR = true,
    bool iGlov = true,
    bool invLet = true,
    bool invDig = true,
    bool invShoe = true,
    bool invRng = true,
  }) async {
    // 1. Сервер
    await _prefs.setString('db_host', host);
    await _prefs.setString('db_user', user);
    await _prefs.setString('db_pass', pass);
    await _prefs.setString('db_name', dbname);

    // 2. Склады и Тема
    await _prefs.setString('wh1_name', w1);
    await _prefs.setString('wh2_name', w2);
    await _prefs.setBool('is_dark_mode', darkMode);

    // 3. Видимость (Вещи)
    await _prefs.setBool('show_digits', iDig);
    await _prefs.setBool('show_letters', iLet);
    await _prefs.setBool('show_shoes', iShoe);
    await _prefs.setBool('show_hats', iHat);
    await _prefs.setBool('show_hats_r', iHatR);
    await _prefs.setBool('show_gloves', iGlov);

    // 4. Видимость (Инвентарь)
    await _prefs.setBool('inv_letters', invLet);
    await _prefs.setBool('inv_digits', invDig);
    await _prefs.setBool('inv_shoes', invShoe);
    await _prefs.setBool('inv_ranges', invRng);
  }
}
