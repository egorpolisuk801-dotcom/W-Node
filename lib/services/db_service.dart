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

  // 🔥 БЛОКИРОВКА СИНХРОНИЗАЦИИ
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
    String path = join(documentsDirectory.path, "inventory_system_v14.db");

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
          item_name TEXT,
          action_type TEXT,
          details TEXT,
          timestamp TEXT,
          device TEXT, 
          is_unsynced INTEGER DEFAULT 1
        )
      ''');
    });
  }

  // ==========================================
  // ☁️ ОБЛАКО (ИСПРАВЛЕН ТАЙМ-АУТ)
  // ==========================================

  Future<bool> initConnection() async {
    // Если соединение есть и открыто - используем его
    if (_pgConnection != null && !_pgConnection!.isClosed) return true;

    try {
      print("🔄 Подключение к Supabase...");

      // 🔥 FIX: Увеличены тайм-ауты для медленного интернета
      final settings = PostgreSQLConnection(
          'aws-1-eu-west-1.pooler.supabase.com', 5432, 'postgres',
          username: 'postgres.qzgatfjezjzqshqpuejh',
          password: 'EgorPolisuk0711',
          useSSL: true,
          timeoutInSeconds: 30, // Было 5 -> Стало 30
          queryTimeoutInSeconds: 60); // Было 10 -> Стало 60

      await settings.open();
      _pgConnection = settings;
      print("✅ Успешное подключение к Supabase");
      return true;
    } catch (e) {
      print("❌ Ошибка подключения (Cloud): $e");
      _pgConnection = null; // Сбрасываем, чтобы попробовать снова
      return false;
    }
  }

  // ==========================================
  // 🚀 СИНХРОНИЗАЦИЯ
  // ==========================================

  Future<void> syncWithCloud() async {
    if (_isSyncActive) {
      print("⏳ Синхронизация уже идет, ждем...");
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

      // 2. ОТПРАВКА ТОВАРОВ (Создание / Обновление / Удаление)
      final unsynced = await db.query('items', where: 'is_unsynced = 1');
      for (var item in unsynced) {
        await _uploadSingleItem(db, item);
      }

      // 3. СКАЧИВАНИЕ НОВЫХ ДАННЫХ
      await _fastMergeFromCloud(db);
    } catch (e) {
      print("❌ Общая ошибка синхронизации: $e");
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
        // УДАЛЕНИЕ
        if (serverId != null) {
          await _pgConnection!.query("DELETE FROM items WHERE id = @id",
              substitutionValues: {'id': serverId});
        }
        // Удаляем из локальной базы окончательно
        await db.delete('items', where: 'local_id = ?', whereArgs: [localId]);
      } else if (serverId == null) {
        // СОЗДАНИЕ (INSERT)
        // Сначала проверим, нет ли такого UID на сервере (защита от дублей)
        var check = await _pgConnection!.query(
            "SELECT id FROM items WHERE uid = @uid",
            substitutionValues: {'uid': uid});

        if (check.isNotEmpty) {
          // Если уже есть - просто привязываем ID
          int existingId = check.first[0] as int;
          await db.update('items', {'server_id': existingId, 'is_unsynced': 0},
              where: 'local_id = ?', whereArgs: [localId]);
        } else {
          // Если нет - заливаем
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
          // Получаем ID только что созданной записи
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
        // ОБНОВЛЕНИЕ (UPDATE)
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

          // Ищем, есть ли такой товар локально
          List<Map> checkId = await txn
              .query('items', where: 'server_id = ?', whereArgs: [sId]);

          if (checkId.isNotEmpty) {
            // Если есть - обновляем (но только если локально не меняли недавно)
            // Для простоты - обновляем всегда, так как сервер главнее
            await txn.update('items', data,
                where: 'server_id = ?', whereArgs: [sId]);
          } else {
            // Пробуем найти по UID
            List<Map> checkUid =
                await txn.query('items', where: 'uid = ?', whereArgs: [uid]);
            if (checkUid.isNotEmpty) {
              await txn
                  .update('items', data, where: 'uid = ?', whereArgs: [uid]);
            } else {
              // Если нет ни по ID, ни по UID - создаем
              await txn.insert('items', data);
            }
          }
        }

        // Удаляем локальные товары, которых нет на сервере (но только те, что уже были синхронизированы)
        if (cloudIds.isNotEmpty) {
          String ids = cloudIds.join(',');
          await txn.rawDelete(
              'DELETE FROM items WHERE server_id IS NOT NULL AND server_id NOT IN ($ids)');
        } else if (results.isEmpty) {
          // Если сервер пуст - чистим все синхронизированное
          await txn.rawDelete('DELETE FROM items WHERE server_id IS NOT NULL');
        }
      });
    } catch (e) {
      print("Merge error: $e");
    }
  }

  // --- CRUD МЕТОДЫ ---

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
      'is_unsynced': 1, // Помечаем как требующий отправки
      'is_deleted': 0
    });
    await _addLog("Додано", item['name'],
        "К-сть: ${item['total']} | Кат: ${item['category']}");

    // Запускаем синхронизацию в фоне
    syncWithCloud();
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

    // Не пишем лог на каждое нажатие +/-, это слишком много.
    // Но можно раскомментировать, если нужно.
    // await _addLog("Зміна", name, "К-сть: $newTotal");

    syncWithCloud();
  }

  Future<void> updateItemQuantity(int localId, int newTotal) async {
    final db = await localDb;
    await db.update('items', {'total_quantity': newTotal, 'is_unsynced': 1},
        where: 'local_id = ?', whereArgs: [localId]);
    syncWithCloud();
  }

  // 🔥 НОВЫЙ МЕТОД: УДАЛЕНИЕ
  Future<void> deleteItem(int localId) async {
    final db = await localDb;
    // Не удаляем физически, а ставим флаг удаления
    await db.update('items', {'is_deleted': 1, 'is_unsynced': 1},
        where: 'local_id = ?', whereArgs: [localId]);

    await _addLog("Видалення", "ID: $localId", "Видалено з телефону");
    syncWithCloud();
  }

  Future<void> _addLog(String type, String name, String details) async {
    final db = await localDb;
    await db.insert('logs', {
      'item_name': name,
      'action_type': type,
      'details': details,
      'timestamp': DateTime.now().toString().substring(0, 19),
      'device': 'Phone',
      'is_unsynced': 1
    });
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
    } catch (e) {
      print(e);
    }
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
