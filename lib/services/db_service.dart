import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb; // Нужно для работы в браузере
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../core/user_config.dart';
import 'qr_parser.dart';

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

    return await openDatabase(path, version: 5, onCreate: (db, version) async {
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
          price REAL DEFAULT 0.0,
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
      await _createQrMaps(db);
      await _createPersonnel(db);
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        try {
          await db.execute(
              "ALTER TABLE items ADD COLUMN price REAL DEFAULT 0.0");
        } catch (_) {}
      }
      if (oldVersion < 3) {
        await _createQrMaps(db);
      }
      if (oldVersion < 4) {
        await _createQrMaps(db);
        try {
          await db.execute(
              'ALTER TABLE qr_maps ADD COLUMN item_local_id INTEGER');
        } catch (_) {}
      }
      if (oldVersion < 5) {
        await _createPersonnel(db);
      }
    });
  }

  static Future<void> _createPersonnel(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS personnel (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit TEXT DEFAULT '',
        rank TEXT DEFAULT '',
        full_name TEXT NOT NULL,
        UNIQUE(full_name, unit)
      )
    ''');
  }

  static Future<void> _createQrMaps(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS qr_maps (
        code TEXT PRIMARY KEY,
        item_uid TEXT,
        item_local_id INTEGER,
        created_at TEXT
      )
    ''');
  }

  // ==========================================
  // ☁️ ОБЛАКО И ПОДКЛЮЧЕНИЕ
  // ==========================================
  Future<bool> hasInternet() async {
    if (kIsWeb) return true;
    Future<bool> lookup(String host) async {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 3));
        return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    // Спочатку сам сервер складу — Google може бути недоступний, а хмара працює.
    if (await lookup('qzgatfjezjzqshqpuejh.supabase.co')) return true;
    if (await lookup('google.com')) return true;
    return false;
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
      await syncSizeGrids();
      await syncQrBindings();
      await syncPersonnel();
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
      await UserConfig().setLastSyncNow();
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
            'price': item['price'] ?? 0.0,
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
          'name': item['name'],
          'location': item['location'],
          'category': item['category'],
          'warehouse': item['warehouse'],
          'size_data': parsedSizeData,
          'total_quantity': item['total_quantity'],
          'price': item['price'] ?? 0.0,
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
            'price': map['price'] ?? 0.0,
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
            if (checkId.first['is_unsynced'] == 1) continue;
            await txn.update('items', data,
                where: 'server_id = ?', whereArgs: [sId]);
          } else {
            List<Map> checkUid =
                await txn.query('items', where: 'uid = ?', whereArgs: [uid]);
            if (checkUid.isNotEmpty) {
              if (checkUid.first['is_unsynced'] == 1) continue;
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
              'DELETE FROM items WHERE server_id IS NOT NULL AND is_unsynced = 0 AND server_id NOT IN ($ids)');
        } else if (results.isEmpty) {
          await txn.rawDelete(
              'DELETE FROM items WHERE server_id IS NOT NULL AND is_unsynced = 0');
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
      'price': item['price'] ?? 0.0,
      'is_inventory':
          (item['is_inventory'] == true || item['is_inventory'] == 1) ? 1 : 0,
      'date_added': DateTime.now().toIso8601String(),
      'is_unsynced': 1,
      'is_deleted': 0
    });

    await logHistory(
        "Додано",
        item['name'],
        "Початкова к-сть: ${item['total']}"
            "${(item['price'] != null && (item['price'] as num) > 0) ? ' (Ціна: ${item['price']})' : ''}",
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

  Future<void> updateItemDetails({
    required int localId,
    required String name,
    required String location,
    required String warehouse,
    required String category,
    required double price,
  }) async {
    final db = await localDb;
    final rows = await db.query('items',
        where: 'local_id = ? AND is_deleted = 0', whereArgs: [localId]);
    if (rows.isEmpty) return;
    final old = rows.first;
    await db.update(
        'items',
        {
          'name': name.trim(),
          'location': location.trim(),
          'warehouse': warehouse,
          'category': category,
          'price': price,
          'is_unsynced': 1
        },
        where: 'local_id = ?',
        whereArgs: [localId]);
    await logHistory(
        'Редаговано',
        name.trim(),
        'Назва: ${old['name']} → ${name.trim()}  •  місце: ${old['location']} → ${location.trim()}  •  склад: ${old['warehouse']} → $warehouse  •  ціна: ${old['price']} → $price',
        itemId: localId);
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
            .limit(200);
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

  Future<String> applyStockDelta({
    required int localId,
    String? sizeKey,
    required int delta,
    String? issuedTo,
    bool isUndo = false,
    bool sync = true,
    String? actionOverride,
    String? note,
  }) async {
    if (delta == 0) return 'Кількість не змінено';
    final db = await localDb;
    final rows = await db.query('items',
        where: 'local_id = ? AND is_deleted = 0', whereArgs: [localId]);
    if (rows.isEmpty) return 'Помилка: позицію не знайдено';

    final row = rows.first;
    Map<String, dynamic> sizes = {};
    try {
      sizes = Map<String, dynamic>.from(
          jsonDecode((row['size_data'] ?? '{}').toString()));
    } catch (_) {}

    int currentTotal = int.tryParse('${row['total_quantity']}') ?? 0;
    final realKeys = QrParser.realSizeKeys(sizes);
    if (realKeys.isNotEmpty && (sizeKey == null || sizeKey.trim().isEmpty)) {
      return 'Помилка: обери розмір — на коді його немає';
    }

    int cur = sizeKey != null
        ? (int.tryParse('${sizes[sizeKey]}') ?? 0)
        : currentTotal;
    int next = cur + delta;
    if (next < 0) return 'Помилка: не можна менше 0';

    if (sizeKey != null) {
      sizes[sizeKey] = next;
      currentTotal = sizes.values
          .fold<int>(0, (sum, v) => sum + (int.tryParse('$v') ?? 0));
    } else {
      currentTotal = next;
    }

    await db.update(
        'items',
        {
          'size_data': jsonEncode(sizes),
          'total_quantity': currentTotal,
          'is_unsynced': 1
        },
        where: 'local_id = ?',
        whereArgs: [localId]);

    String actionType;
    if (isUndo) {
      actionType = 'Скасовано';
    } else if (actionOverride != null && actionOverride.trim().isNotEmpty) {
      actionType = actionOverride.trim();
    } else if (delta > 0) {
      actionType = 'Додано';
    } else {
      actionType = 'Видано';
    }
    final sizeInfo = sizeKey != null ? ' ($sizeKey)' : '';
    final sign = delta > 0 ? '+' : '-';
    var logName = '${row['name']}$sizeInfo';
    var details = 'Було: $cur ➔ $sign${delta.abs()} ➔ Стало: $next';
    if (!isUndo && issuedTo != null && issuedTo.trim().isNotEmpty && delta < 0) {
      logName = '$logName → ${issuedTo.trim()}';
      details = '$details  •  кому: ${issuedTo.trim()}';
    }
    if (!isUndo && note != null && note.trim().isNotEmpty) {
      details = '$details  •  ${note.trim()}';
    }
    if (isUndo) {
      details = 'Відміна попередньої дії. $details';
    }
    await logHistory(actionType, logName, details, itemId: localId);
    if (sync) syncWithCloud();
    if (isUndo) {
      return 'Скасовано: ${row['name']}$sizeInfo';
    }
    final who = (!isUndo && issuedTo != null && issuedTo.trim().isNotEmpty && delta < 0)
        ? '  → ${issuedTo.trim()}'
        : '';
    return '${row['name']}$sizeInfo  $sign${delta.abs()}  (стало $next)$who';
  }

  Future<({bool ok, String message, int destLocalId, String? sizeKey, int qty})>
      transferStock({
    required int sourceLocalId,
    required String destWarehouse,
    String? sizeKey,
    required int qty,
  }) async {
    ({bool ok, String message, int destLocalId, String? sizeKey, int qty}) fail(
            String m) =>
        (ok: false, message: m, destLocalId: 0, sizeKey: sizeKey, qty: qty);

    if (qty <= 0) return fail('Помилка: кількість має бути більша за 0');
    final destWh = destWarehouse.trim();
    if (destWh.isEmpty) return fail('Помилка: обери склад призначення');

    final db = await localDb;
    final srcRows = await db.query('items',
        where: 'local_id = ? AND is_deleted = 0',
        whereArgs: [sourceLocalId]);
    if (srcRows.isEmpty) return fail('Помилка: позицію не знайдено');
    final src = srcRows.first;
    final srcWh = '${src['warehouse'] ?? ''}'.trim();
    if (srcWh.toLowerCase() == destWh.toLowerCase()) {
      return fail('Помилка: це той самий склад');
    }

    Map<String, dynamic> srcSizes = {};
    try {
      srcSizes = Map<String, dynamic>.from(
          jsonDecode((src['size_data'] ?? '{}').toString()));
    } catch (_) {}
    final realKeys = QrParser.realSizeKeys(srcSizes);
    if (realKeys.isNotEmpty && (sizeKey == null || sizeKey.trim().isEmpty)) {
      return fail('Помилка: обери розмір');
    }
    final key = (sizeKey != null && sizeKey.trim().isNotEmpty)
        ? sizeKey.trim()
        : null;
    final srcCur = key != null
        ? (int.tryParse('${srcSizes[key]}') ?? 0)
        : (int.tryParse('${src['total_quantity']}') ?? 0);
    if (qty > srcCur) {
      return fail('Помилка: на $srcWh лише $srcCur шт.');
    }

    final name = '${src['name']}';
    final destRows = await db.query(
      'items',
      where: 'name = ? AND warehouse = ? AND is_deleted = 0',
      whereArgs: [name, destWh],
    );
    int destId;
    if (destRows.isNotEmpty) {
      destId = destRows.first['local_id'] as int;
    } else {
      final emptySizes = <String, dynamic>{};
      for (final k in realKeys) {
        emptySizes[k] = 0;
      }
      destId = await db.insert('items', {
        'uid': 'ph_mv_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'location': src['location'],
        'category': src['category'],
        'warehouse': destWh,
        'item_type': src['item_type'],
        'total_quantity': 0,
        'size_data': jsonEncode(emptySizes),
        'price': src['price'] ?? 0.0,
        'is_inventory': src['is_inventory'] ?? 0,
        'date_added': DateTime.now().toIso8601String(),
        'is_unsynced': 1,
        'is_deleted': 0,
      });
    }

    final out = await applyStockDelta(
      localId: sourceLocalId,
      sizeKey: key,
      delta: -qty,
      sync: false,
      actionOverride: 'Переміщено',
      note: 'на склад: $destWh',
    );
    if (out.startsWith('Помилка')) return fail(out);

    final inn = await applyStockDelta(
      localId: destId,
      sizeKey: key,
      delta: qty,
      sync: false,
      actionOverride: 'Переміщено',
      note: 'зі складу: $srcWh',
    );
    if (inn.startsWith('Помилка')) {
      await applyStockDelta(
        localId: sourceLocalId,
        sizeKey: key,
        delta: qty,
        sync: false,
        isUndo: true,
      );
      return fail(inn);
    }

    syncWithCloud();
    final sizeInfo = key != null ? ' ($key)' : '';
    return (
      ok: true,
      message: '$name$sizeInfo  $srcWh → $destWh  ($qty шт)',
      destLocalId: destId,
      sizeKey: key,
      qty: qty,
    );
  }

  Future<void> bindQr(String code, String uid, {int? localId}) async {
    final db = await localDb;
    final now = DateTime.now().toIso8601String();
    for (final variant in QrParser.codeVariants(code)) {
      await db.insert(
          'qr_maps',
          {
            'code': variant,
            'item_uid': uid,
            'item_local_id': localId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    syncWithCloud();
  }

  Future<({String? uid, int? localId})?> findQrBinding(String code) async {
    final db = await localDb;
    for (final variant in QrParser.codeVariants(code)) {
      final res = await db.query('qr_maps',
          where: 'code = ?', whereArgs: [variant], limit: 1);
      if (res.isEmpty) continue;
      final uid = res.first['item_uid']?.toString();
      final localId = res.first['item_local_id'] as int?;
      if ((uid == null || uid.isEmpty) && localId == null) continue;
      return (uid: (uid == null || uid.isEmpty) ? null : uid, localId: localId);
    }
    return null;
  }

  /// Каталог сіток із ПК. Телефон тільки читає, свої сітки не пише.
  Future<void> syncSizeGrids() async {
    try {
      if (!await hasInternet()) return;
      final response = await _supabase
          .from('global_settings')
          .select('setting_value')
          .eq('setting_key', 'size_grids')
          .limit(1);
      if (response.isEmpty || response.first['setting_value'] == null) return;
      final raw = response.first['setting_value'].toString().trim();
      if (raw.isEmpty || raw == '[]') return;
      jsonDecode(raw);
      await UserConfig().setSizeGridsJson(raw);
    } catch (e) {
      print('Size grids sync skip: $e');
    }
  }

  Future<void> syncQrBindings() async {
    try {
      final db = await localDb;
      final local = await db.query('qr_maps');
      final localMap = <String, String>{};
      for (final row in local) {
        final code = '${row['code']}';
        final uid = '${row['item_uid'] ?? ''}';
        if (code.isNotEmpty && uid.isNotEmpty) localMap[code] = uid;
      }

      final res = await _supabase
          .from('global_settings')
          .select('setting_value')
          .eq('setting_key', 'qr_bindings')
          .limit(1);

      Map<String, dynamic> cloud = {};
      if (res.isNotEmpty && res.first['setting_value'] != null) {
        try {
          final decoded = jsonDecode(res.first['setting_value'].toString());
          if (decoded is Map) cloud = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }

      final merged = <String, String>{};
      for (final e in cloud.entries) {
        final v = e.value?.toString() ?? '';
        if (e.key.toString().isNotEmpty && v.isNotEmpty) {
          merged[e.key.toString()] = v;
        }
      }
      merged.addAll(localMap);

      for (final e in merged.entries) {
        await db.insert(
            'qr_maps',
            {
              'code': e.key,
              'item_uid': e.value,
              'created_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final payload = jsonEncode(merged);
      if (res.isNotEmpty) {
        await _supabase.from('global_settings').update({
          'setting_value': payload,
          'updated_at': DateTime.now().toIso8601String()
        }).eq('setting_key', 'qr_bindings');
      } else {
        await _supabase.from('global_settings').insert({
          'setting_key': 'qr_bindings',
          'setting_value': payload
        });
      }
    } catch (e) {
      print('QR bindings sync skip: $e');
    }
  }

  Future<void> syncPersonnel() async {
    try {
      final db = await localDb;
      final localRows = await db.query('personnel');
      final merged = <String, Map<String, String>>{};

      void add(String name, String unit, String rank) {
        final n = name.trim();
        if (n.isEmpty) return;
        merged['$n|${unit.trim()}'] = {
          'full_name': n,
          'unit': unit.trim(),
          'rank': rank.trim(),
        };
      }

      for (final r in localRows) {
        add('${r['full_name']}', '${r['unit'] ?? ''}', '${r['rank'] ?? ''}');
      }

      final res = await _supabase
          .from('global_settings')
          .select('setting_value')
          .eq('setting_key', 'personnel_list')
          .limit(1);
      if (res.isNotEmpty && res.first['setting_value'] != null) {
        try {
          final decoded = jsonDecode(res.first['setting_value'].toString());
          if (decoded is List) {
            for (final p in decoded) {
              if (p is Map) {
                add('${p['full_name'] ?? ''}', '${p['unit'] ?? ''}',
                    '${p['rank'] ?? ''}');
              }
            }
          }
        } catch (_) {}
      }

      for (final p in merged.values) {
        await db.insert('personnel', p,
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final payload = jsonEncode(merged.values.toList());
      if (res.isNotEmpty) {
        await _supabase.from('global_settings').update({
          'setting_value': payload,
          'updated_at': DateTime.now().toIso8601String()
        }).eq('setting_key', 'personnel_list');
      } else {
        await _supabase.from('global_settings').insert(
            {'setting_key': 'personnel_list', 'setting_value': payload});
      }
    } catch (e) {
      print('Personnel sync skip: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPersonnel({String query = ''}) async {
    final db = await localDb;
    final rows = await db.query('personnel',
        orderBy: 'unit COLLATE NOCASE, full_name COLLATE NOCASE');
    if (query.trim().isEmpty) return rows;
    final q = query.toLowerCase();
    return rows.where((r) {
      final hay = '${r['full_name']} ${r['unit']} ${r['rank']}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> addPerson({
    required String fullName,
    String unit = '',
    String rank = '',
  }) async {
    final name = fullName.trim();
    if (name.isEmpty) return;
    final db = await localDb;
    await db.insert(
        'personnel',
        {
          'full_name': name,
          'unit': unit.trim(),
          'rank': rank.trim(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    syncWithCloud();
  }

  Future<int> pendingCount() async {
    final db = await localDb;
    final items = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM items WHERE is_unsynced = 1 AND is_deleted = 0')) ??
        0;
    final logs = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM logs WHERE is_unsynced = 1')) ??
        0;
    return items + logs;
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
