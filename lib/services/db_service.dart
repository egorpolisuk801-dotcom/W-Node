import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  Database? _localDb;
  PostgreSQLConnection? _pgConnection;

  // БЛОКИРОВКА СИНХРОНИЗАЦИИ
  bool _isSyncActive = false;

  // ==========================================
  // 📱 ЛОКАЛЬНАЯ БАЗА
  // ==========================================

  Future<Database> get localDb async {
    if (_localDb != null) return _localDb!;
    _localDb = await _initLocalDB();
    return _localDb!;
  }

  Future<Database> _initLocalDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    // 🔥 v16 - чтобы создалась новая таблица для списков
    String path = join(documentsDirectory.path, "inventory_system_v16.db");

    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      // 1. Таблица товаров
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

      // 2. Таблица логов
      await db.execute('''
        CREATE TABLE logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_name TEXT,
          action_type TEXT,
          details TEXT,
          timestamp TEXT,
          device TEXT, 
          is_unsynced INTEGER DEFAULT 1
        )
      ''');

      // 3. 🔥 НОВАЯ ТАБЛИЦА: СПИСКИ (Зима/Лето/Инвентарь)
      await db.execute('''
        CREATE TABLE custom_lists (
          list_type TEXT, -- 'winter', 'summer', 'inventory'
          item_name TEXT,
          PRIMARY KEY (list_type, item_name)
        )
      ''');
    });
  }

  // ==========================================
  // 📝 МЕТОДЫ ДЛЯ СПИСКОВ (Зима/Лето)
  // ==========================================

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

  // ==========================================
  // ☁️ ОБЛАКО (Supabase)
  // ==========================================

  Future<bool> initConnection() async {
    if (_pgConnection != null && !_pgConnection!.isClosed) return true;

    try {
      print("🔄 Подключение к Supabase...");
      final settings = PostgreSQLConnection(
          'aws-1-eu-west-1.pooler.supabase.com', 5432, 'postgres',
          username: 'postgres.qzgatfjezjzqshqpuejh',
          password: 'EgorPolisuk0711',
          useSSL: true,
          timeoutInSeconds: 30,
          queryTimeoutInSeconds: 60);

      await settings.open();
      _pgConnection = settings;
      print("✅ Успешное подключение к Supabase");
      return true;
    } catch (e) {
      print("❌ Ошибка подключения (Cloud): $e");
      _pgConnection = null;
      return false;
    }
  }

  // ==========================================
  // 🚀 СИНХРОНИЗАЦИЯ
  // ==========================================

  Future<void> syncWithCloud() async {
    if (_isSyncActive) {
      print("⏳ Синхронизация уже идет...");
      return;
    }

    _isSyncActive = true;

    try {
      bool connected = await initConnection();
      if (!connected) return;

      final db = await localDb;

      // 1. ОТПРАВКА ЛОГОВ
      final unsyncedLogs = await db.query('logs', where: 'is_unsynced = 1');
      for (var log in unsyncedLogs) {
        try {
          await _pgConnection!.query(
              "INSERT INTO history_logs (item_name, action_type, details, device, timestamp) VALUES (@name, @act, @det, 'Phone', @time)",
              substitutionValues: {
                'name': log['item_name'],
                'act': log['action_type'],
                'det': log['details'],
                'time': log['timestamp']
              });
          await db.update('logs', {'is_unsynced': 0},
              where: 'id = ?', whereArgs: [log['id']]);
        } catch (e) {
          print("Log sync skip: $e");
        }
      }

      // 2. ОТПРАВКА ТОВАРОВ
      final unsynced = await db.query('items', where: 'is_unsynced = 1');
      for (var item in unsynced) {
        await _uploadSingleItem(db, item);
      }

      // 3. СКАЧИВАНИЕ НОВЫХ
      await _fastMergeFromCloud(db);
    } catch (e) {
      print("❌ Ошибка синхронизации: $e");
    } finally {
      _isSyncActive = false;
    }
  }

  Future<void> _uploadSingleItem(Database db, Map<String, dynamic> item) async {
    int localId = item['local_id'] as int;
    int? serverId = item['server_id'] as int?;
    bool isDeleted = (item['is_deleted'] == 1);
    String uid = item['uid'] ?? "";

    try {
      if (isDeleted) {
        if (serverId != null) {
          await _pgConnection!.query("DELETE FROM items WHERE id = @id",
              substitutionValues: {'id': serverId});
        }
        await db.delete('items', where: 'local_id = ?', whereArgs: [localId]);
      } else if (serverId == null) {
        // Проверка дубликатов по UID
        var check = await _pgConnection!.query(
            "SELECT id FROM items WHERE uid = @uid",
            substitutionValues: {'uid': uid});

        if (check.isNotEmpty) {
          int existingId = check.first[0] as int;
          await db.update('items', {'server_id': existingId, 'is_unsynced': 0},
              where: 'local_id = ?', whereArgs: [localId]);
        } else {
          await _pgConnection!.query(
            "INSERT INTO items (name, location, category, warehouse, total_quantity, item_type, size_data, is_inventory, date_added, uid, device) VALUES (@name, @loc, @cat, @wh, @total, @type, @size, @isInv, @date, @uid, 'Phone')",
            substitutionValues: {
              'name': item['name'],
              'loc': item['location'],
              'cat': item['category'],
              'wh': item['warehouse'],
              'total': item['total_quantity'],
              'type': item['item_type'],
              'size': item['size_data'],
              'isInv': item['is_inventory'],
              'date': item['date_added'],
              'uid': uid
            },
          );
          final res = await _pgConnection!.query(
              "SELECT id FROM items WHERE uid = @uid",
              substitutionValues: {'uid': uid});
          if (res.isNotEmpty) {
            await db.update(
                'items', {'server_id': res.first[0], 'is_unsynced': 0},
                where: 'local_id = ?', whereArgs: [localId]);
          }
        }
      } else {
        await _pgConnection!.query(
            "UPDATE items SET size_data = @size, total_quantity = @total, date_edited = @date WHERE id = @id",
            substitutionValues: {
              'size': item['size_data'],
              'total': item['total_quantity'],
              'date': DateTime.now().toIso8601String(),
              'id': serverId
            });
        await db.update('items', {'is_unsynced': 0},
            where: 'local_id = ?', whereArgs: [localId]);
      }
    } catch (e) {
      print("Ошибка загрузки элемента ($uid): $e");
    }
  }

  Future<void> _fastMergeFromCloud(Database db) async {
    try {
      final results =
          await _pgConnection!.mappedResultsQuery("SELECT * FROM items");
      List<int> cloudIds = [];

      await db.transaction((txn) async {
        for (final row in results) {
          Map<String, dynamic> map = row['items'] ?? row.values.first;
          int sId = map['id'];
          String uid = (map['uid'] ?? "srv_$sId").toString();
          cloudIds.add(sId);

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
  // CRUD МЕТОДЫ (Добавить/Удалить/Логи)
  // ==========================================

  Future<void> saveItem(Map<String, dynamic> item) async {
    final db = await localDb;
    await db.insert('items', {
      'uid': item['uid'],
      'name': item['name'],
      'location': item['location'],
      'category': item['category'],
      'warehouse': item['warehouse'],
      'total_quantity': item['total'],
      'item_type': item['type'],
      'size_data': jsonEncode(item['size_data'] ?? {}),
      'is_inventory': (item['is_inventory'] == true) ? 1 : 0,
      'date_added': DateTime.now().toIso8601String(),
      'is_unsynced': 1,
      'is_deleted': 0
    });
    // 🔥 Запись в лог (теперь работает)
    await logHistory("Додано", item['name'], "К-сть: ${item['total']}");
    syncWithCloud();
  }

  // 🔥 ПУБЛИЧНЫЙ МЕТОД ИСТОРИИ (Был потерян, теперь на месте)
  Future<void> logHistory(String action, String name, String details) async {
    final db = await localDb;
    await db.insert('logs', {
      'item_name': name,
      'action_type': action,
      'details': details,
      'timestamp': DateTime.now().toString().substring(0, 19),
      'device': 'Phone',
      'is_unsynced': 1
    });
  }

  // Обертка для старого кода, если где-то используется
  Future<void> _addLog(String type, String name, String details) async {
    await logHistory(type, name, details);
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

  Future<void> updateItemQuantity(int localId, int newTotal) async {
    final db = await localDb;
    await db.update('items', {'total_quantity': newTotal, 'is_unsynced': 1},
        where: 'local_id = ?', whereArgs: [localId]);
    syncWithCloud();
  }

  Future<void> deleteItem(int localId) async {
    final db = await localDb;
    await db.update('items', {'is_deleted': 1, 'is_unsynced': 1},
        where: 'local_id = ?', whereArgs: [localId]);

    await logHistory("Видалення", "ID: $localId", "Видалено з телефону");
    syncWithCloud();
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    if (await initConnection()) {
      try {
        final res = await _pgConnection!.mappedResultsQuery(
            "SELECT * FROM history_logs ORDER BY id DESC LIMIT 50");
        return res.map((row) => row['history_logs']!).toList();
      } catch (e) {
        print(e);
      }
    }
    final db = await localDb;
    return await db.query('logs', orderBy: "id DESC");
  }

  Future<void> clearLogs() async {
    try {
      if (await initConnection())
        await _pgConnection!.query("DELETE FROM history_logs");
    } catch (_) {}
    final db = await localDb;
    await db.delete('logs');
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await localDb;
    final results = await db.query('items',
        where: 'is_deleted = 0', orderBy: "local_id DESC");
    return results.map((item) {
      Map<String, dynamic> sizes = {};
      try {
        if (item['size_data'] != null) {
          var decoded = jsonDecode(item['size_data'] as String);
          if (decoded is Map) sizes = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
      return {
        ...item,
        'id': item['local_id'],
        'total': item['total_quantity'],
        'size_data': sizes,
        'is_inventory': item['is_inventory'] == 1,
        'needs_sync': item['is_unsynced'] == 1
      };
    }).toList();
  }
}
