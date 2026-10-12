import 'dart:convert';

import '../core/size_converter.dart';

class QrPayload {
  final String raw;
  final String? name;
  final String? size;
  final String? uid;
  final int? qty;

  const QrPayload(
      {required this.raw, this.name, this.size, this.uid, this.qty});
}

class QrMatch {
  final Map<String, dynamic> item;
  final QrPayload payload;
  final String? sizeKey;

  const QrMatch(
      {required this.item, required this.payload, required this.sizeKey});
}

class QrParser {
  static QrPayload parse(String raw) {
    final text = raw.trim();
    String? name;
    String? size;
    String? uid;
    int? qty;

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        name = _str(decoded, ['name', 'найменування', 'назва', 'title', 'item']);
        size = _str(decoded, ['size', 'розмір', 'rozmir', 'sz']);
        uid = _str(decoded, ['uid', 'id', 'code', 'qr']);
        qty = int.tryParse('${decoded['qty'] ?? decoded['quantity'] ?? ''}');
      }
    } catch (_) {}

    if (uid == null && text.startsWith('W1|')) {
      final parts = text.split('|');
      if (parts.length >= 3) {
        uid = parts[1].trim();
        name ??= parts[2].trim();
        if (parts.length > 3) {
          size ??= parts.sublist(3).join('|').trim();
        }
      }
    }

    if (name == null) {
      for (final part in text.split(RegExp(r'[\n;|]'))) {
        final kv = part.split(RegExp(r'[:=]'));
        if (kv.length >= 2) {
          final k = kv.first.trim().toLowerCase();
          final v = kv.sublist(1).join(':').trim();
          if (k.contains('name') || k.contains('назв') || k.contains('найм')) {
            name = v;
          } else if (k.contains('size') || k.contains('розмір')) {
            size = v;
          } else if (k.contains('uid') || k == 'id' || k == 'code') {
            uid = v;
          } else if (k.contains('qty') || k.contains('к-сть') || k.contains('кільк')) {
            qty = int.tryParse(v);
          }
        }
      }
    }

    final gs1 = RegExp(r'\(01\)\s*(\d{13,14})').firstMatch(text);
    if (gs1 != null) {
      uid ??= gs1.group(1);
    }

    if (uid == null &&
        text.length >= 6 &&
        !text.contains(' ') &&
        !text.startsWith('http') &&
        !text.startsWith('{') &&
        !text.startsWith('W1|')) {
      uid = text;
    }

    return QrPayload(raw: text, name: name, size: size, uid: uid, qty: qty);
  }

  /// EAN-13 / GTIN variants of the same factory barcode.
  static List<String> codeVariants(String raw) {
    final out = <String>{};
    final text = raw.trim();
    if (text.isEmpty) return [];
    out.add(text);
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      out.add(digits);
      if (digits.length == 13) out.add('0$digits');
      if (digits.length == 14 && digits.startsWith('0')) {
        out.add(digits.substring(1));
      }
      if (digits.length == 12) out.add('0$digits');
    }
    return out.toList();
  }

  static bool isFactoryCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8 && digits.length <= 14 && digits == raw.trim();
  }

  static String? _str(Map map, List<String> keys) {
    for (final k in keys) {
      for (final entry in map.entries) {
        if (entry.key.toString().toLowerCase() == k.toLowerCase()) {
          final v = entry.value?.toString().trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }
    }
    return null;
  }

  static QrMatch? match(QrPayload payload, List<Map<String, dynamic>> items,
      {String? boundUid, int? boundLocalId}) {
    Map<String, dynamic>? found;

    if (boundLocalId != null) {
      for (final item in items) {
        if (item['id'] == boundLocalId || item['local_id'] == boundLocalId) {
          found = item;
          break;
        }
      }
    }

    if (found == null && boundUid != null && boundUid.isNotEmpty) {
      for (final item in items) {
        if ('${item['uid']}' == boundUid) {
          found = item;
          break;
        }
      }
    }

    found ??= _byExact(items, payload.uid);
    found ??= _byExact(items, payload.raw);
    for (final v in codeVariants(payload.raw)) {
      found ??= _byExact(items, v);
    }
    if (payload.name != null && !isFactoryCode(payload.name!)) {
      found ??= _byName(items, payload.name!);
    }
    if (!isFactoryCode(payload.raw)) {
      found ??= _byName(items, payload.raw);
    }

    if (found == null) return null;
    return QrMatch(
        item: found,
        payload: payload,
        sizeKey: _resolveSize(found, payload.size));
  }

  static Map<String, dynamic>? _byExact(
      List<Map<String, dynamic>> items, String? value) {
    if (value == null || value.isEmpty) return null;
    final v = value.toLowerCase();
    for (final item in items) {
      if ('${item['uid']}'.toLowerCase() == v) return item;
      if ('${item['name']}'.toLowerCase() == v) return item;
      if ('${item['location']}'.toLowerCase() == v) return item;
    }
    return null;
  }

  static Map<String, dynamic>? _byName(
      List<Map<String, dynamic>> items, String needle) {
    final n = needle.toLowerCase().trim();
    if (n.length < 3) return null;
    Map<String, dynamic>? best;
    int bestScore = 0;
    for (final item in items) {
      final name = '${item['name']}'.toLowerCase();
      int score = 0;
      if (name == n) {
        score = 100;
      } else if (name.contains(n) || n.contains(name)) {
        score = 60;
      }
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore >= 60 ? best : null;
  }

  static String? _resolveSize(Map<String, dynamic> item, String? fromQr) {
    final sizes = sizesOf(item);
    final keys = realSizeKeys(sizes);
    if (keys.isEmpty) return null;
    if (fromQr != null && fromQr.isNotEmpty) {
      for (final key in keys) {
        if (key.toLowerCase() == fromQr.toLowerCase()) return key;
      }
      final nQr = SizeConverter.normalize(fromQr);
      for (final key in keys) {
        if (SizeConverter.normalize(key) == nQr) return key;
      }
      for (final key in keys) {
        if (key.toLowerCase().contains(fromQr.toLowerCase()) ||
            fromQr.toLowerCase().contains(key.toLowerCase())) {
          return key;
        }
      }
    }
    if (keys.length == 1) return keys.first;
    return null;
  }

  static bool isDummySizeKey(String key) {
    final k = key.toLowerCase().trim();
    return k.isEmpty ||
        k.startsWith('__') ||
        k == 'кількість' ||
        k == 'количество' ||
        k == 'qty' ||
        k == 'quantity' ||
        k == 'total' ||
        k == 'всього' ||
        k == 'загальна';
  }

  static Map<String, dynamic> sizesOf(Map<String, dynamic> item) {
    final raw = item['size_data'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  static List<String> realSizeKeys(Map sizes) {
    final keys = sizes.keys
        .map((k) => k.toString())
        .where((k) => !isDummySizeKey(k))
        .toList();
    keys.sort((a, b) {
      final na = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
      final nb = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');
      if (na != null && nb != null && na != nb) return na.compareTo(nb);
      return a.compareTo(b);
    });
    return keys;
  }

  static bool needsSizePick(Map<String, dynamic> item) {
    final sizes = sizesOf(item);
    if (realSizeKeys(sizes).isNotEmpty) return true;
    final t = '${item['item_type'] ?? item['type'] ?? ''}'.toLowerCase();
    if (t.contains('інвентар') || t.contains('просте')) return false;
    return t.contains('цифр') ||
        t.contains('букв') ||
        t.contains('взутт') ||
        t.contains('головн') ||
        t.contains('гу ') ||
        t.contains('рукавич') ||
        t.contains('білиз');
  }
}
