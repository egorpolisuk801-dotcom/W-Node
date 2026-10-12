import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_parser.dart';

class KitLine {
  final Map<String, dynamic> item;
  final int norm;
  final bool needsSize;
  final Map<String, dynamic> sizes;
  final List<String> sizeKeys;
  String? sizeKey;

  KitLine({
    required this.item,
    required this.norm,
    required this.needsSize,
    required this.sizes,
    required this.sizeKeys,
    this.sizeKey,
  });

  int get localId => item['id'] as int;
  String get name => '${item['name'] ?? ''}';
  String get warehouse => '${item['warehouse'] ?? ''}';

  int stockFor(String? key) {
    if (key == null || key.isEmpty) {
      return int.tryParse('${item['total']}') ?? 0;
    }
    return int.tryParse('${sizes[key]}') ?? 0;
  }

  int get stock => stockFor(needsSize ? sizeKey : null);

  bool get sizeReady => !needsSize || (sizeKey != null && sizeKey!.isNotEmpty);
  bool get enough => sizeReady && stock >= norm;
}

class KitIssueService {
  static Future<Map<String, int>> loadNorms(String seasonKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('norms_$seasonKey') ?? '{}';
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map(
        (k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 1));
  }

  static Future<List<KitLine>> buildLines({
    required List<Map<String, dynamic>> allItems,
    required List<String> seasonIds,
    required String seasonKey,
    Map<String, String>? remembered,
  }) async {
    final norms = await loadNorms(seasonKey);
    final idSet = seasonIds.map((e) => e.toString()).toSet();
    final lines = <KitLine>[];

    for (final item in allItems) {
      if (!idSet.contains(item['id'].toString())) continue;
      final name = '${item['name'] ?? ''}';
      var norm = norms[name] ?? 1;
      if (norm <= 0) norm = 1;
      final sizes = QrParser.sizesOf(item);
      final keys = QrParser.realSizeKeys(sizes);
      final needs = keys.isNotEmpty || QrParser.needsSizePick(item);
      String? preset;
      if (remembered != null && remembered[name] != null) {
        final want = remembered[name]!;
        if (keys.contains(want)) {
          preset = want;
        } else {
          for (final k in keys) {
            if (k.toLowerCase() == want.toLowerCase()) {
              preset = k;
              break;
            }
          }
        }
      }
      if (preset == null && keys.length == 1) preset = keys.first;

      lines.add(KitLine(
        item: item,
        norm: norm,
        needsSize: needs && keys.isNotEmpty,
        sizes: sizes,
        sizeKeys: keys,
        sizeKey: preset,
      ));
    }
    return lines;
  }

  static Future<Map<String, String>> loadRemembered(String person) async {
    if (person.trim().isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kit_sizes_${person.trim()}') ?? '{}';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> saveRemembered(
      String person, List<KitLine> lines) async {
    if (person.trim().isEmpty) return;
    final map = <String, String>{};
    for (final line in lines) {
      if (line.sizeKey != null && line.sizeKey!.isNotEmpty) {
        map[line.name] = line.sizeKey!;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kit_sizes_${person.trim()}', jsonEncode(map));
  }
}
