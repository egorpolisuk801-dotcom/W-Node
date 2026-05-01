import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb; // Нужно для работы в браузере
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../core/user_config.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  Database? _localDb;
  final _supabase = Supabase.instance.client;
  bool _isSyncActive = false;

  // ==========================================
  // 📱 ЛОКАЛЬНАЯ БАЗА (SQLite)
  // ==========================================
  Future<Database> get localDb async {
    if (_localDb != null) return _localDb!;
    _localDb = await _initLocalDB();
    return _localDb!;
  }

  Future<Database> _initLocalDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "inventory_system_v17.db");

    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE items (
          local_id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          uid TEXT UNIQUE,
          name TEXT,
          location TEXT,
          category TEXT,
          warehouse TEXT,
          item_type TEXT,
          total_quantity INTEGER,
          size_data TEXT,
          is_inventory INTEGER DEFAULT 0,
          date_added TEXT,
          date_edited TEXT,
          is_unsynced INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0
        )
      ''');
      await db.execute("CREATE INDEX idx_server_id ON items(server_id)");
      await db.execute("CREATE INDEX idx_uid ON items(uid)");

      await db.execute('''
        CREATE TABLE logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_id INTEGER, 
          item_name TEXT,
          action_type TEXT,
          details TEXT,
          timestamp TEXT,
          device TEXT, 
          is_unsynced INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE custom_lists (
          list_type TEXT,
          item_name TEXT,
          PRIMARY KEY (list_type, item_name)
        )
      ''');
    });
  }

  // ==========================================
  // ☁️ ОБЛАКО И ПОДКЛЮЧЕНИЕ
  // ==========================================
  Future<bool> hasInternet() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> initConnection() async {
    return await hasInternet();
  }

  // ==========================================
  // 🚀 СИНХРОНИЗАЦИЯ С SUPABASE
  // ==========================================
  Future<void> syncWithCloud() async {
    if (_isSyncActive) return;
    _isSyncActive = true;

    try {
      if (!await hasInternet()) return;

      await syncWarehouses();
      final db = await localDb;

      // 1. ОТПРАВКА ЛОГОВ (history_logs)
      final unsyncedLogs = await db.query('logs', where: 'is_unsynced = 1');
      for (var log in unsyncedLogs) {
        try {
          await _supabase.from('history_logs').insert({
            'item_name': log['item_name'],
            'action_type': log['action_type'],
            'details': log['details'],
            'device': kIsWeb ? 'Web' : 'Phone',
            'timestamp': log['timestamp']
          });
          await db.update('logs', {'is_unsynced': 0},
              where: 'id = ?', whereArgs: [log['id']]);
        } catch (e) {
          print("Log sync skip: $e");
        }
      }

      // 2. ОТПРАВКА ЛОКАЛЬНЫХ ИЗМЕНЕНИЙ (items)
      final unsynced = await db.query('items', where: 'is_unsynced = 1');
      for (var item in unsynced) {
        await _uploadSingleItem(db, item);
      }

      // 3. ПОЛУЧЕНИЕ ОБНОВЛЕНИЙ ИЗ ОБЛАКА
      await _fastMergeFromCloud(db);
    } catch (e) {
      print("❌ Ошибка синхронизации: $e");
    } finally {
      _isSyncActive = false;
    }
  }

  // 🔥 ОНОВЛЕНО: Тепер телефон повністю підкоряється списку складів з Хмари 🔥
  Future<void> syncWarehouses() async {
    try {
      final response = await _supabase
          .from('global_settings')
          .select('setting_value')
          .eq('setting_key', 'warehouses')
          .limit(1);

      if (response.isNotEmpty && response.first['setting_value'] != null) {
        // Беремо актуальний список прямо з бази (який ти міг змінити на ПК)
        String cloudJson = response.first['setting_value'].toString();
        final cfg = UserConfig();

        // Мовчки, без запитань перезаписуємо локальні налаштування телефону
        await cfg.save(
            w1: cloudJson,
            w2: "",
            host: cfg.dbHost,
            user: cfg.dbUser,
            pass: cfg.dbPass,
            dbname: cfg.dbName,
            darkMode: cfg.isDarkMode,
            iDig: cfg.itemShowDigits,
            iLet: cfg.itemShowLetters,
            iShoe: cfg.itemShowShoes,
            iHat: cfg.itemShowHats,
            iHatR: cfg.itemShowHatsR,
            iGlov: cfg.itemShowGloves,
            iHatW: cfg.itemShowHatsW,
            iGlovSL: cfg.itemShowGlovesSL,
            iLinen: cfg.itemShowLinen,
            invLet: cfg.invShowLetters,
            invDig: cfg.invShowDigits,
            invShoe: cfg.invShowShoes,
            invRng: cfg.invShowRanges);
      }
    } catch (e) {
      print("Помилка синхронізації складів: $e");
    }
  }

  Future<void> _uploadSingleItem(Database db, Map<String, dynamic> item) async {
    int localId = item['local_id'] as int;
    int? serverId = item['server_id'] as int?;
    bool isDeleted = (item['is_deleted'] == 1);
    String uid = item['uid'] ?? "";

    dynamic parsedSizeData = {};
    try {
      parsedSizeData = jsonDecode(item['size_data'].toString());
    } catch (_) {
      parsedSizeData = {};
    }

    try {
      if (isDeleted) {
        if (serverId != null) {
          await _supabase
              .from('items')
              .update({'is_deleted': 1}).eq('id', serverId);
        }
        await db.delete('items', where: 'local_id = ?', whereArgs: [localId]);
      } else if (serverId == null) {
        final check = await _supabase.from('items').select('id').eq('uid', uid);

        if (check.isNotEmpty) {
          int existingId = check.first['id'] as int;
          await db.update('items', {'server_id': existingId, 'is_unsynced': 0},
              where: 'local_id = ?', whereArgs: [localId]);
        } else {
          final response = await _supabase.from('items').insert({
            'name': item['name'],
            'location': item['location'],
            'category': item['category'],
            'warehouse': item['warehouse'],
            'total_quantity': item['total_quantity'],
            'item_type': item['item_type'],
            'size_data': parsedSizeData,
            'is_inventory':
                (item['is_inventory'] == 1 || item['is_inventory'] == true)
                    ? 1
                    : 0,
            'date_added': item['date_added'],
            'uid': uid
          }).select('id');

          if (response.isNotEmpty) {
            await db.update(
                'items', {'server_id': response.first['id'], 'is_unsynced': 0},
                where: 'local_id = ?', whereArgs: [localId]);
          }
        }
      } else {
        await _supabase.from('items').update({
          'size_data': parsedSizeData,
          'total_quantity': item['total_quantity'],
          'date_edited': DateTime.now().toIso8601String()
        }).eq('id', serverId);

        await db.update('items', {'is_unsynced': 0},
            where: 'local_id = ?', whereArgs: [localId]);
      }
    } catch (e) {
      print("Ошибка загрузки элемента ($uid): $e");
    }
  }

  Future<void> _fastMergeFromCloud(Database db) async {
    try {
      final results = await _supabase.from('items').select();
      List<int> cloudIds = [];

      await db.transaction((txn) async {
        for (final map in results) {
          int sId = map['id'];
          String uid = (map['uid'] ?? "srv_$sId").toString();
          cloudIds.add(sId);

          int isDeletedFromCloud =
              (map['is_deleted'] == 1 || map['is_deleted'] == true) ? 1 : 0;

          if (isDeletedFromCloud == 1) {
            await txn.delete('items',
                where: 'server_id = ? OR uid = ?', whereArgs: [sId, uid]);
            continue;
          }

          String sizeJson = "{}";
          if (map['size_data'] != null) {
            sizeJson = map['size_data'] is Map
                ? jsonEncode(map['size_data'])
                : map['size_data'].toString();
          }

          Map<String, dynamic> data = {
            'server_id': sId,
            'uid': uid,
            'name': (map['name'] ?? "").toString(),
            'location': (map['location'] ?? "").toString(),
            'category': (map['category'] ?? "I").toString(),
            'warehouse': (map['warehouse'] ?? "ООС").toString(),
            'total_quantity': map['total_quantity'] ?? 0,
            'item_type': (map['item_type'] ?? "Просте").toString(),
            'size_data': sizeJson,
            'is_inventory':
                (map['is_inventory'] == true || map['is_inventory'] == 1)
                    ? 1
                    : 0,
            'date_added': (map['date_added'] ?? "").toString(),
            'is_unsynced': 0,
            'is_deleted': 0
          };

          List<Map> checkId = await txn
              .query('items', where: 'server_id = ?', whereArgs: [sId]);

          if (checkId.isNotEmpty) {
            await txn.update('items', data,
                where: 'server_id = ?', whereArgs: [sId]);
          } else {
            List<Map> checkUid =
                await txn.query('items', where: 'uid = ?', whereArgs: [uid]);
            if (checkUid.isNotEmpty) {
              await txn
                  .update('items', data, where: 'uid = ?', whereArgs: [uid]);
            } else {
              await txn.insert('items', data);
            }
          }
        }

        if (cloudIds.isNotEmpty) {
          String ids = cloudIds.join(',');
          await txn.rawDelete(
              'DELETE FROM items WHERE server_id IS NOT NULL AND server_id NOT IN ($ids)');
        } else if (results.isEmpty) {
          await txn.rawDelete('DELETE FROM items WHERE server_id IS NOT NULL');
        }
      });
    } catch (e) {
      print("Merge error: $e");
    }
  }

  // ==========================================
  // 🔥 CRUD + LOGS
  // ==========================================
  Future<void> saveItem(Map<String, dynamic> item) async {
    final db = await localDb;
    int id = await db.insert('items', {
      'uid': item['uid'],
      'name': item['name'],
      'location': item['location'],
      'category': item['category'],
      'warehouse': item['warehouse'],
      'total_quantity': item['total'],
      'item_type': item['type'],
      'size_data': jsonEncode(item['size_data'] ?? {}),
      'is_inventory':
          (item['is_inventory'] == true || item['is_inventory'] == 1) ? 1 : 0,
      'date_added': DateTime.now().toIso8601String(),
      'is_unsynced': 1,
      'is_deleted': 0
    });

    await logHistory(
        "Додано", item['name'], "Початкова к-сть: ${item['total']}",
        itemId: id);
    syncWithCloud();
  }

  Future<void> logHistory(String action, String name, String details,
      {int? itemId}) async {
    final db = await localDb;
    await db.insert('logs', {
      'item_id': itemId,
      'item_name': name,
      'action_type': action,
      'details': details,
      'timestamp': DateTime.now().toString().substring(0, 19),
      'device': kIsWeb ? 'Web' : 'Phone',
      'is_unsynced': 1
    });
  }

  Future<void> updateItemSizes(int localId, String name, String category,
      Map<String, dynamic> newSizes, int newTotal) async {
    final db = await localDb;
    await db.update(
        'items',
        {
          'size_data': jsonEncode(newSizes),
          'total_quantity': newTotal,
          'is_unsynced': 1
        },
        where: 'local_id = ?',
        whereArgs: [localId]);
    syncWithCloud();
  }

  Future<void> deleteItem(int localId) async {
    final db = await localDb;
    var res = await db.query('items',
        columns: ['total_quantity', 'name'],
        where: 'local_id = ?',
        whereArgs: [localId]);
    if (res.isNotEmpty) {
      String name = res.first['name'] as String;
      int total = res.first['total_quantity'] as int;
      await db.update('items', {'is_deleted': 1, 'is_unsynced': 1},
          where: 'local_id = ?', whereArgs: [localId]);
      await logHistory(
          "Видалення", name, "🗑️ Видалено (На залишку було: $total шт.)",
          itemId: localId);
    }
    syncWithCloud();
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await localDb;
    final localUnsynced = await db.rawQuery('''
      SELECT h.*, COALESCE(i.name, h.item_name) as item_name
      FROM logs h LEFT JOIN items i ON h.item_id = i.local_id
      WHERE h.is_unsynced = 1 ORDER BY h.id DESC
    ''');

    List<Map<String, dynamic>> finalLogs =
        List<Map<String, dynamic>>.from(localUnsynced);

    if (await hasInternet()) {
      try {
        final res = await _supabase
            .from('history_logs')
            .select()
            .order('id', ascending: false)
            .limit(50);
        finalLogs.addAll(res.map((e) => {...e, 'is_unsynced': 0}));
        finalLogs.sort((a, b) =>
            b['timestamp'].toString().compareTo(a['timestamp'].toString()));
      } catch (_) {}
    }
    return finalLogs;
  }

  Future<void> clearLogs() async {
    try {
      if (await hasInternet()) {
        await _supabase.from('history_logs').delete().gt('id', 0);
      }
    } catch (_) {}
    final db = await localDb;
    await db.delete('logs');
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await localDb;
    final results = await db.query('items',
        where: 'is_deleted = 0', orderBy: "local_id DESC");
    return results.map((item) {
      return {
        ...item,
        'id': item['local_id'],
        'total': item['total_quantity'],
        'size_data': jsonDecode((item['size_data'] ?? '{}') as String),
        'is_inventory': item['is_inventory'] == 1,
        'needs_sync': item['is_unsynced'] == 1
      };
    }).toList();
  }

  Future<void> toggleItemInList(
      String listType, String itemName, bool add) async {
    final db = await localDb;
    if (add) {
      await db.insert(
          'custom_lists', {'list_type': listType, 'item_name': itemName},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('custom_lists',
          where: 'list_type = ? AND item_name = ?',
          whereArgs: [listType, itemName]);
    }
  }

  Future<List<String>> getCustomList(String listType) async {
    final db = await localDb;
    final res = await db
        .query('custom_lists', where: 'list_type = ?', whereArgs: [listType]);
    return res.map((e) => e['item_name'] as String).toList();
  }
}
