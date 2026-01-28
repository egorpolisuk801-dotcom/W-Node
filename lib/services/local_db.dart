import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDB {
  static final LocalDB _instance = LocalDB._internal();
  factory LocalDB() => _instance;
  LocalDB._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'local_warehouse.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Таблица товаров (локальная копия)
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER, 
            name TEXT,
            location TEXT,
            category TEXT,
            warehouse TEXT,
            total_quantity INTEGER,
            item_type TEXT,
            size_data TEXT,
            is_inventory INTEGER,
            date_added TEXT,
            is_unsynced INTEGER DEFAULT 0, -- 1 если нужно отправить на сервер
            is_deleted INTEGER DEFAULT 0   -- 1 если удалено офлайн
          )
        ''');
        // Таблица логов
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT,
            details TEXT,
            type TEXT,
            time TEXT
          )
        ''');
      },
    );
  }

  // --- ТОВАРЫ ---

  Future<List<Map<String, dynamic>>> getItems() async {
    final db = await database;
    // Берем только те, что НЕ помечены как удаленные
    return await db.query('items', where: 'is_deleted = 0', orderBy: 'id DESC');
  }

  Future<int> insertItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('items', item);
  }

  Future<int> updateItem(int id, Map<String, dynamic> item) async {
    final db = await database;
    return await db.update('items', item, where: 'id = ?', whereArgs: [id]);
  }

  // Найти товар по серверному ID (чтобы обновить его)
  Future<int> updateItemByServerId(
      int serverId, Map<String, dynamic> item) async {
    final db = await database;
    return await db
        .update('items', item, where: 'server_id = ?', whereArgs: [serverId]);
  }

  // Удаление (мягкое - ставим метку, чтобы потом удалить и на сервере)
  Future<void> softDeleteItem(int id) async {
    final db = await database;
    await db.update('items', {'is_deleted': 1, 'is_unsynced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // Полная перезапись таблицы (когда скачали свежее с сервера)
  Future<void> clearAndFillItems(List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('items'); // Удаляем всё старое
      for (var item in items) {
        await txn.insert('items', item);
      }
    });
  }

  // --- СИНХРОНИЗАЦИЯ ---

  // Получить всё, что мы изменили офлайн
  Future<List<Map<String, dynamic>>> getUnsyncedItems() async {
    final db = await database;
    return await db.query('items', where: 'is_unsynced = 1');
  }

  // Пометить, что синхронизация прошла успешно
  Future<void> markAsSynced(int id, int serverId) async {
    final db = await database;
    await db.update(
        'items',
        {
          'is_unsynced': 0,
          'server_id': serverId // Запоминаем ID, который выдал сервер
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  // --- ЛОГИ ---

  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await database;
    return await db.query('logs', orderBy: 'id DESC', limit: 100);
  }

  Future<void> addLog(String action, String details, String type) async {
    final db = await database;
    await db.insert('logs', {
      'action': action,
      'details': details,
      'type': type,
      'time': DateTime.now().toString().substring(11, 16)
    });
  }

  Future<void> clearLogs() async {
    final db = await database;
    await db.delete('logs');
  }
}
