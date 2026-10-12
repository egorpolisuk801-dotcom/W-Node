import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class UserConfig {
  static final UserConfig _instance = UserConfig._internal();
  factory UserConfig() => _instance;
  UserConfig._internal();

  // 🛡 Убрали late, сделали prefs nullable
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint("✅ SharedPreferences успешно загружены");
    } catch (e) {
      debugPrint("❌ Ошибка загрузки SharedPreferences: $e");
    }
  }

  // Вспомогательный метод, чтобы не дублировать проверку
  T _getValue<T>(String key, T defaultValue) {
    if (_prefs == null) return defaultValue;
    final value = _prefs!.get(key);
    if (value == null) return defaultValue;
    return value as T;
  }

  // === НАСТРОЙКИ СЕРВЕРА ===
  String get dbHost =>
      _getValue('db_host', 'aws-1-eu-west-1.pooler.supabase.com');
  String get dbUser => _getValue('db_user', 'postgres.qzgatfjezjzqshqpuejh');
  String get dbPass => _getValue('db_pass', 'EgorPolisuk0711');
  String get dbName => _getValue('db_name', 'postgres');

  // === СКЛАДЫ ===
  String get wh1Name => _getValue('wh1_name', 'Склад-1');
  String get wh2Name => _getValue('wh2_name', 'Склад-2');

  List<String> get warehouses {
    try {
      if (wh1Name.startsWith('[')) {
        final parsed = jsonDecode(wh1Name);
        if (parsed is List) {
          final names = parsed
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (names.isNotEmpty) return names;
        }
      }
    } catch (_) {}
    final pair =
        [wh1Name, wh2Name].where((e) => e.isNotEmpty).toList();
    return pair.isEmpty ? const ['ООС', 'ППД'] : pair;
  }

  bool get isDarkMode => themeId == 'cyber';

  String get themeId {
    final stored = _getValue('theme_id', '');
    const known = {'glass', 'brutal', 'neo', 'cyber'};
    if (known.contains(stored)) return stored;
    if (stored == 'light') return 'glass';
    if (stored == 'corporate') return 'neo';
    if (stored == 'tactical') return 'brutal';
    if (stored == 'hud') return 'cyber';
    return _getValue('is_dark_mode', true) ? 'cyber' : 'glass';
  }

  Future<void> setThemeId(String id) async {
    if (_prefs == null) await load();
    const known = {'glass', 'brutal', 'neo', 'cyber'};
    final next = known.contains(id) ? id : 'cyber';
    await _prefs?.setString('theme_id', next);
    await _prefs?.setBool('is_dark_mode', next == 'cyber');
  }

  String get lastIssuePerson => _getValue('last_issue_person', '');

  Future<void> setLastIssuePerson(String name) async {
    if (_prefs == null) await load();
    await _prefs?.setString('last_issue_person', name);
  }

  String get _todayStamp {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  int get todayHits {
    if (_getValue('fun_day', '') != _todayStamp) return 0;
    return _prefs?.getInt('fun_hits') ?? 0;
  }

  Future<int> bumpTodayHits() async {
    if (_prefs == null) await load();
    final today = _todayStamp;
    if (_getValue('fun_day', '') != today) {
      await _prefs?.setString('fun_day', today);
      await _prefs?.setInt('fun_hits', 1);
      return 1;
    }
    final next = todayHits + 1;
    await _prefs?.setInt('fun_hits', next);
    return next;
  }

  String get sizeGridsJson => _getValue('size_grids', '');

  Future<void> setSizeGridsJson(String value) async {
    if (_prefs == null) await load();
    await _prefs?.setString('size_grids', value);
  }

  String get lastSyncAt => _getValue('last_sync_at', '');

  Future<void> setLastSyncNow() async {
    if (_prefs == null) await load();
    await _prefs?.setString('last_sync_at', DateTime.now().toIso8601String());
  }

  // === ВИДИМОСТЬ КАТЕГОРИЙ ===
  bool get itemShowDigits => _getValue('show_digits', true);
  bool get itemShowLetters => _getValue('show_letters', true);
  bool get itemShowShoes => _getValue('show_shoes', true);
  bool get itemShowHats => _getValue('show_hats', true);
  bool get itemShowHatsR => _getValue('show_hats_r', true);
  bool get itemShowGloves => _getValue('show_gloves', true);
  bool get itemShowHatsW => _getValue('show_hats_w', true);
  bool get itemShowGlovesSL => _getValue('show_gloves_sl', true);
  bool get itemShowLinen => _getValue('show_linen', true);

  bool get invShowDigits => _getValue('inv_digits', true);
  bool get invShowLetters => _getValue('inv_letters', true);
  bool get invShowShoes => _getValue('inv_shoes', true);
  bool get invShowRanges => _getValue('inv_ranges', true);

  // === МЕТОДЫ СОХРАНЕНИЯ ===
  Future<void> setString(String key, String value) async =>
      await _prefs?.setString(key, value);
  Future<void> setBool(String key, bool value) async =>
      await _prefs?.setBool(key, value);

  Future<void> save({
    required String host,
    required String user,
    required String pass,
    required String dbname,
    required String w1,
    required String w2,
    required bool darkMode,
    bool iDig = true,
    bool iLet = true,
    bool iShoe = true,
    bool iHat = true,
    bool iHatR = true,
    bool iGlov = true,
    bool iHatW = true,
    bool iGlovSL = true,
    bool iLinen = true,
    bool invLet = true,
    bool invDig = true,
    bool invShoe = true,
    bool invRng = true,
  }) async {
    if (_prefs == null) await load();

    await _prefs?.setString('db_host', host);
    await _prefs?.setString('db_user', user);
    await _prefs?.setString('db_pass', pass);
    await _prefs?.setString('db_name', dbname);
    await _prefs?.setString('wh1_name', w1);
    await _prefs?.setString('wh2_name', w2);
    await _prefs?.setBool('is_dark_mode', darkMode);
    await _prefs?.setBool('show_digits', iDig);
    await _prefs?.setBool('show_letters', iLet);
    await _prefs?.setBool('show_shoes', iShoe);
    await _prefs?.setBool('show_hats', iHat);
    await _prefs?.setBool('show_hats_r', iHatR);
    await _prefs?.setBool('show_gloves', iGlov);
    await _prefs?.setBool('show_hats_w', iHatW);
    await _prefs?.setBool('show_gloves_sl', iGlovSL);
    await _prefs?.setBool('show_linen', iLinen);
    await _prefs?.setBool('inv_letters', invLet);
    await _prefs?.setBool('inv_digits', invDig);
    await _prefs?.setBool('inv_shoes', invShoe);
    await _prefs?.setBool('inv_ranges', invRng);
  }
}
