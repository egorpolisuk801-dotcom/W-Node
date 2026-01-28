import 'dart:convert';
import 'package:postgres/postgres.dart';
import '../core/user_config.dart';
import 'local_db.dart'; // Подключаем локальную базу

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  PostgreSQLConnection? _connection;
  bool _isOnline = false;

  // === ПОДКЛЮЧЕНИЕ (Проверка связи) ===
  Future<bool> initConnection() async {
    if (_connection != null && !_connection!.isClosed) return true;
    final cfg = UserConfig();
    if (cfg.dbHost.isEmpty) return false;

    try {
      final settings = PostgreSQLConnection(
        cfg.dbHost, 5432, cfg.dbName,
        username: cfg.dbUser, password: cfg.dbPass,
        useSSL: true, timeoutInSeconds: 3, // Быстрый таймаут
      );
      await settings.open();
      _connection = settings;
      _isOnline = true;
      return true;
    } catch (e) {
      print("ОФЛАЙН РЕЖИМ: $e");
      _isOnline = false;
      return false;
    }
  }

  // === ГЛАВНАЯ ФУНКЦИЯ СИНХРОНИЗАЦИИ ===
  Future<void> syncWithCloud() async {
    bool connected = await initConnection();
    if (!connected) return; // Нет интернета - выходим, работаем локально

    try {
      // 1. ОТПРАВЛЯЕМ ЛОКАЛЬНЫЕ ИЗМЕНЕНИЯ НА СЕРВЕР
      final unsynced = await LocalDB().getUnsyncedItems();

      for (var item in unsynced) {
        int localId = item['id'];
        int? serverId = item['server_id'];
        bool isDeleted = item['is_deleted'] == 1;

        if (isDeleted) {
          if (serverId != null) {
            await _connection!.query("DELETE FROM items WHERE id = @id",
                substitutionValues: {'id': serverId});
          }
          final db = await LocalDB().database;
          await db.delete('items', where: 'id = ?', whereArgs: [localId]);
        } else if (serverId == null) {
          // ЭТО НОВЫЙ ТОВАР -> INSERT
          var result = await _connection!.query(
            """
            INSERT INTO items (name, location, category, warehouse, total_quantity, item_type, size_data, is_inventory, date_added)
            VALUES (@name, @loc, @cat, @wh, @total, @type, @size, @isInv, @date)
            RETURNING id
            """,
            substitutionValues: {
              'name': item['name'],
              'loc': item['location'],
              'cat': item['category'],
              'wh': item['warehouse'],
              'total': item['total_quantity'],
              'type': item['item_type'],
              'size': item[
                  'size_data'], // Тут уже лежит строка JSON из локальной БД
              'isInv': item['is_inventory'],
              'date': item['date_added'],
            },
          );
          int newServerId = result.first[0] as int;
          await LocalDB().markAsSynced(localId, newServerId);
        } else {
          // ИЗМЕНЕНИЕ -> UPDATE
          await _connection!.query(
              "UPDATE items SET size_data = @size, total_quantity = @total WHERE id = @id",
              substitutionValues: {
                'size': item['size_data'],
                'total': item['total_quantity'],
                'id': serverId,
              });
          await LocalDB().markAsSynced(localId, serverId);
        }
      }

      // 2. СКАЧИВАЕМ СВЕЖИЕ ДАННЫЕ С СЕРВЕРА
      await _downloadAllFromCloud();
    } catch (e) {
      print("Ошибка синхронизации: $e");
    }
  }

  // Скачать всё с сервера и сохранить в телефон
  Future<void> _downloadAllFromCloud() async {
    try {
      List<Map<String, Map<String, dynamic>>> results =
          await _connection!.mappedResultsQuery(
        "SELECT * FROM items ORDER BY id DESC",
      );

      List<Map<String, dynamic>> itemsForLocal = [];
      for (final row in results) {
        Map<String, dynamic> map = row['items'] ?? row.values.first;

        // --- ИСПРАВЛЕНИЕ ОШИБКИ ЗДЕСЬ ---
        // Postgres может вернуть size_data как Map, а SQLite нужен String.
        // Делаем jsonEncode.
        dynamic rawSize = map['size_data'];
        String sizeJson = "{}";

        if (rawSize != null) {
          if (rawSize is Map) {
            sizeJson = jsonEncode(rawSize);
          } else if (rawSize is String) {
            sizeJson = rawSize;
          }
        }

        itemsForLocal.add({
          'server_id': map['id'],
          'name': map['name'],
          'location': map['location'],
          'category': map['category'],
          'warehouse': map['warehouse'],
          'total_quantity': map['total_quantity'],
          'item_type': map['item_type'],
          'size_data': sizeJson, // Теперь это точно Строка, ошибки не будет
          'is_inventory':
              (map['is_inventory'] == true || map['is_inventory'] == 1) ? 1 : 0,
          'date_added': (map['date_added']).toString(),
          'is_unsynced': 0,
          'is_deleted': 0
        });
      }
      // Перезаписываем локальную базу
      await LocalDB().clearAndFillItems(itemsForLocal);
    } catch (e) {
      print("Ошибка загрузки с облака: $e");
    }
  }

  // === ЧТЕНИЕ ДАННЫХ ===
  Future<List<Map<String, dynamic>>> getAllItems() async {
    syncWithCloud(); // Фоновая синхронизация

    final localItems = await LocalDB().getItems();

    List<Map<String, dynamic>> uiItems = [];
    for (var item in localItems) {
      Map<String, dynamic> sizes = {};
      try {
        // Превращаем строку JSON обратно в Map для экрана
        if (item['size_data'] != null && item['size_data'].isNotEmpty) {
          sizes = Map<String, dynamic>.from(jsonDecode(item['size_data']));
        }
      } catch (_) {}

      uiItems.add({
        'id': item['id'],
        'server_id': item['server_id'],
        'name': item['name'],
        'location': item['location'],
        'category': item['category'],
        'warehouse': item['warehouse'],
        'total': item['total_quantity'],
        'type': item['item_type'],
        'size_data': sizes,
        'is_inventory': item['is_inventory'] == 1,
        'date': item['date_added'],
        'needs_sync': item['is_unsynced'] == 1,
      });
    }
    return uiItems;
  }

  // === СОХРАНЕНИЕ ===
  Future<void> saveItem(Map<String, dynamic> item) async {
    String sizeJson = jsonEncode(item['size_data'] ?? {});
    int isInvInt = (item['is_inventory'] == true) ? 1 : 0;

    await LocalDB().insertItem({
      'name': item['name'],
      'location': item['location'],
      'category': item['category'],
      'warehouse': item['warehouse'],
      'total_quantity': item['total'],
      'item_type': item['type'],
      'size_data': sizeJson,
      'is_inventory': isInvInt,
      'date_added': DateTime.now().toIso8601String(),
      'is_unsynced': 1,
      'server_id': null
    });

    LocalDB().addLog("Створено (Офлайн)", "${item['name']}", "add");
    syncWithCloud();
  }

  // === ОБНОВЛЕНИЕ ===
  Future<void> updateItemSizes(int localId, String name,
      Map<String, dynamic> newSizes, int newTotal, dynamic logInfo) async {
    String sizeJson = jsonEncode(newSizes);

    await LocalDB().updateItem(localId,
        {'size_data': sizeJson, 'total_quantity': newTotal, 'is_unsynced': 1});

    LocalDB().addLog("Зміна (Офлайн)", logInfo.toString(), "edit");
    syncWithCloud();
  }

  // === ИСТОРИЯ ===
  Future<List<Map<String, dynamic>>> getLogs() async {
    return await LocalDB().getLogs();
  }

  Future<void> clearLogs() async {
    await LocalDB().clearLogs();
  }
}
