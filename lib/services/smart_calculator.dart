import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 ДОДАНО
import '../core/size_converter.dart';

class SmartCalculator {
  static final List<String> _poolKeywords = [
    'черевики',
    'шапка',
    'феска',
    'шарф',
    'труба',
    'рукавички',
    'шкарпетки',
    'взуття',
    'рюкзак',
    'баул',
    'спальник',
    'каремат',
    'берці',
    'берцы',
    'кросівки',
    'чоботи',
    'ремінь',
    'пояс'
  ];

  static Map<String, dynamic> _parseSizeData(dynamic data) {
    if (data == null) return {};
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  static bool _isPoolItem(String? itemName, Map<String, dynamic> sizes) {
    if (sizes.isEmpty) return true;
    if (itemName == null) return false;

    String nameLower = itemName.toLowerCase();
    if (_poolKeywords.any((keyword) => nameLower.contains(keyword)))
      return true;

    bool isNumericSizesOnly = true;
    for (var key in sizes.keys) {
      String s = key.toString().trim();
      if (s.contains('/') || RegExp(r'[a-zA-Zа-яА-Я]').hasMatch(s)) {
        isNumericSizesOnly = false;
        break;
      }
    }

    if (sizes.isNotEmpty && isNumericSizesOnly) return true;
    return false;
  }

  // 🔥 ТЕПЕР ФУНКЦІЯ АСИНХРОННА І ПРИЙМАЄ seasonKey (winter/summer)
  static Future<Map<String, dynamic>> calculateSeason(
      List<Map<String, dynamic>> allItems,
      List<dynamic> activeItemIds,
      String seasonKey) async {
    try {
      // 1. ЗАВАНТАЖУЄМО ТВОЇ НОРМИ З ПАМ'ЯТІ ТЕЛЕФОНУ
      final prefs = await SharedPreferences.getInstance();
      final String normsStr = prefs.getString('norms_$seasonKey') ?? '{}';
      final Map<String, dynamic> customNorms = jsonDecode(normsStr);

      // 2. ДИНАМІЧНА ФУНКЦІЯ ОТРИМАННЯ НОРМИ
      int getNormFor(String? itemName) {
        if (itemName == null) return 1;
        if (customNorms.containsKey(itemName)) {
          return int.tryParse(customNorms[itemName].toString()) ?? 1;
        }
        return 1; // За замовчуванням завжди 1 шт.
      }

      List<String> validIds = activeItemIds.map((e) => e.toString()).toList();
      List<Map<String, dynamic>> targetItems = allItems.where((item) {
        return validIds.contains(item['id'].toString());
      }).toList();

      if (targetItems.isEmpty) {
        return {
          'error': 'Додайте товари у список цього сезону (Вкладка Зима/Літо).'
        };
      }

      List<Map<String, dynamic>> sizedClothes = [];
      List<Map<String, dynamic>> poolAccessories = [];

      for (var item in targetItems) {
        String name = item['name']?.toString() ?? '';
        Map<String, dynamic> sizes = _parseSizeData(item['size_data']);

        if (_isPoolItem(name, sizes)) {
          poolAccessories.add(item);
        } else {
          sizedClothes.add(item);
        }
      }

      // --- РІВЕНЬ 1: ЗАГАЛЬНИЙ ПУЛ ---
      int maxPoolKits = 999999;
      String poolBottleneck = "";

      for (var item in poolAccessories) {
        dynamic rawTotal = item['total_quantity'] ?? item['total'] ?? 0;
        int total = int.tryParse(rawTotal.toString()) ?? 0;

        int norm = getNormFor(item['name']); // 🔥 ЧИТАЄМО ТВОЮ НОРМУ
        if (norm <= 0) norm = 1;

        int possibleKits = total ~/ norm;
        if (possibleKits < maxPoolKits) {
          maxPoolKits = possibleKits;
          poolBottleneck = item['name']?.toString() ?? 'Аксесуар';
        }
      }
      if (poolAccessories.isEmpty) maxPoolKits = 999999;

      // --- РІВЕНЬ 2: ОДЯГ ЗА РОЗМІРАМИ ---
      Set<String> allNormalizedSizes = {};
      for (var item in sizedClothes) {
        Map<String, dynamic> sizes = _parseSizeData(item['size_data']);
        for (String rawSize in sizes.keys) {
          allNormalizedSizes.add(SizeConverter.normalize(rawSize));
        }
      }

      int totalSizedKits = 0;
      Map<String, int> kitsBySize = {};
      String clothingBottleneck = "";

      for (String targetSize in allNormalizedSizes) {
        int minKitsForThisSize = 999999;

        for (var item in sizedClothes) {
          Map<String, dynamic> sizes = _parseSizeData(item['size_data']);

          int norm = getNormFor(item['name']); // 🔥 ЧИТАЄМО ТВОЮ НОРМУ
          if (norm <= 0) norm = 1;

          int totalSuitable = 0;
          for (var entry in sizes.entries) {
            if (SizeConverter.normalize(entry.key.toString()) == targetSize) {
              totalSuitable += int.tryParse(entry.value.toString()) ?? 0;
            }
          }

          int possible = totalSuitable ~/ norm;
          if (possible < minKitsForThisSize) {
            minKitsForThisSize = possible;
            if (possible == 0) {
              clothingBottleneck =
                  "${item['name']} (немає розміру $targetSize)";
            }
          }
        }

        if (minKitsForThisSize > 0 && minKitsForThisSize != 999999) {
          totalSizedKits += minKitsForThisSize;
          kitsBySize[targetSize] = minKitsForThisSize;
        }
      }
      if (sizedClothes.isEmpty) totalSizedKits = 999999;

      int finalDeployable =
          (totalSizedKits < maxPoolKits) ? totalSizedKits : maxPoolKits;

      String finalBottleneck = "";
      if (finalDeployable == 0) {
        if (totalSizedKits == 0 && sizedClothes.isNotEmpty) {
          finalBottleneck = clothingBottleneck.isNotEmpty
              ? clothingBottleneck
              : "Недостатньо елементів одягу.";
        } else {
          finalBottleneck = poolBottleneck;
        }
      } else if (totalSizedKits < maxPoolKits) {
        finalBottleneck = "Одяг (закінчились розміри)";
      } else {
        finalBottleneck = poolBottleneck;
      }

      return {
        'total_ready': finalDeployable == 999999 ? 0 : finalDeployable,
        'clothing_limit': totalSizedKits == 999999 ? 0 : totalSizedKits,
        'accessories_limit': maxPoolKits == 999999 ? 0 : maxPoolKits,
        'bottleneck_item': finalBottleneck,
        'kits_by_size': kitsBySize,
      };
    } catch (e) {
      return {'error': 'ПОМИЛКА РОЗРАХУНКУ: $e'};
    }
  }
}
