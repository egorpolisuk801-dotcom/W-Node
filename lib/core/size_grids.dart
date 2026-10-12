import 'dart:convert';

import 'user_config.dart';

/// Каталог розмірних сіток. Телефон не створює сітки:
/// бере правки з хмари (їх зберігає ПК) і накладає на типові.
class SizeGrid {
  final String id;
  final String name;
  final String chip;
  final String kind;
  final List<String> rows;
  final List<String> cols;
  final String scope;
  final bool builtin;

  const SizeGrid({
    required this.id,
    required this.name,
    required this.chip,
    required this.kind,
    required this.rows,
    required this.cols,
    required this.scope,
    required this.builtin,
  });

  bool get isMatrix => kind == 'matrix';
}

class SizeGrids {
  static List<String> _nums(int start, int stop, [int step = 1]) {
    final out = <String>[];
    for (var i = start; i < stop; i += step) {
      out.add('$i');
    }
    return out;
  }

  static const _scopes = {
    'digits': 'both',
    'letters': 'items',
    'shoes': 'both',
    'hats': 'items',
    'hats_range': 'items',
    'hats_wide': 'items',
    'gloves': 'items',
    'gloves_sl': 'items',
    'linen': 'items',
    'inv_letters': 'inventory',
    'inv_hats': 'inventory',
  };

  static List<SizeGrid> defaults() {
    final grids = <SizeGrid>[
      SizeGrid(
        id: 'digits',
        name: 'Цифри',
        chip: 'ЦИФРИ',
        kind: 'matrix',
        rows: _nums(1, 9),
        cols: _nums(40, 72, 2),
        scope: 'both',
        builtin: true,
      ),
      const SizeGrid(
        id: 'letters',
        name: 'Букви',
        chip: 'БУКВИ',
        kind: 'matrix',
        rows: ['XShort', 'Short', 'Regular', 'Long', 'XLong'],
        cols: ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL'],
        scope: 'items',
        builtin: true,
      ),
      SizeGrid(
        id: 'shoes',
        name: 'Взуття',
        chip: 'ВЗУТТЯ 35–52',
        kind: 'sizes',
        rows: const ['К-сть'],
        cols: _nums(35, 53),
        scope: 'both',
        builtin: true,
      ),
      const SizeGrid(
        id: 'hats',
        name: 'Головні убори',
        chip: 'ГОЛ. УБОРИ',
        kind: 'sizes',
        rows: ['К-сть'],
        cols: ['54', '55', '56', '57', '58', '59', '60', '61', '62', '63'],
        scope: 'items',
        builtin: true,
      ),
      const SizeGrid(
        id: 'hats_range',
        name: 'ГУ (Діапазон)',
        chip: 'ГУ 54–55',
        kind: 'sizes',
        rows: ['К-сть'],
        cols: ['54-55', '56-57', '58-59', '60-61', '62-63'],
        scope: 'items',
        builtin: true,
      ),
      const SizeGrid(
        id: 'hats_wide',
        name: 'ГУ (Широкі)',
        chip: 'ГУ 54–56',
        kind: 'sizes',
        rows: ['К-сть'],
        cols: ['54-56', '58-60', '62-64'],
        scope: 'items',
        builtin: true,
      ),
      const SizeGrid(
        id: 'gloves',
        name: 'Рукавички',
        chip: 'РУКАВ. 1–4',
        kind: 'sizes',
        rows: ['К-сть'],
        cols: ['1', '2', '3', '4'],
        scope: 'items',
        builtin: true,
      ),
      const SizeGrid(
        id: 'gloves_sl',
        name: 'Рукавички (S-XL)',
        chip: 'РУКАВ. S–XL',
        kind: 'sizes',
        rows: ['К-сть'],
        cols: ['S', 'M', 'L', 'XL'],
        scope: 'items',
        builtin: true,
      ),
      SizeGrid(
        id: 'linen',
        name: 'Білизна',
        chip: 'БІЛИЗНА',
        kind: 'sizes',
        rows: const ['К-сть'],
        cols: _nums(42, 72, 2),
        scope: 'items',
        builtin: true,
      ),
      const SizeGrid(
        id: 'inv_letters',
        name: 'Букви інвентаря',
        chip: 'БУКВИ ІНВ.',
        kind: 'matrix',
        rows: ['XS', 'S', 'M', 'R', 'L', 'XL'],
        cols: ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL'],
        scope: 'inventory',
        builtin: true,
      ),
      const SizeGrid(
        id: 'inv_hats',
        name: 'ГУ інвентаря',
        chip: 'ГУ ІНВ.',
        kind: 'sizes',
        rows: ['К-сть'],
        cols: [
          '53-54',
          '54-55',
          '55-56',
          '56-57',
          '57-58',
          '58-59',
          '59-60',
          '60-61',
          '61-62'
        ],
        scope: 'inventory',
        builtin: true,
      ),
    ];
    return grids
        .map((g) => SizeGrid(
              id: g.id,
              name: g.name,
              chip: g.chip,
              kind: g.kind,
              rows: g.rows,
              cols: g.cols,
              scope: _scopes[g.id] ?? g.scope,
              builtin: g.builtin,
            ))
        .toList();
  }

  static List<String> _clean(dynamic values) {
    final out = <String>[];
    final seen = <String>{};
    if (values is! List) return out;
    for (final raw in values) {
      final text = raw.toString().trim();
      if (text.isEmpty || seen.contains(text)) continue;
      seen.add(text);
      out.add(text);
    }
    return out;
  }

  static List<Map<String, dynamic>> _readSaved() {
    final raw = UserConfig().sizeGridsJson.trim();
    if (raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static SizeGrid _normalize(Map<String, dynamic>? src, SizeGrid? base) {
    var kind = (src?['kind'] ?? base?.kind ?? 'sizes').toString();
    if (kind != 'matrix' && kind != 'sizes') kind = 'sizes';
    var rows = _clean(src != null && src.containsKey('rows') ? src['rows'] : base?.rows);
    final cols = _clean(src != null && src.containsKey('cols') ? src['cols'] : base?.cols);
    if (kind == 'sizes') rows = const ['К-сть'];
    var name = (src?['name'] ?? base?.name ?? 'Сітка').toString().trim();
    if (name.isEmpty) name = 'Сітка';
    var chip = (src?['chip'] ?? base?.chip ?? name).toString().trim();
    if (chip.isEmpty) chip = name;
    var scope = (src?['scope'] ?? base?.scope ?? 'both').toString();
    if (scope != 'items' && scope != 'inventory' && scope != 'both') {
      scope = 'both';
    }
    final id = (src?['id'] ?? base?.id ?? name).toString();
    final builtin = src?['builtin'] == true ||
        (src?['builtin'] == null && (base?.builtin ?? false));
    return SizeGrid(
      id: id,
      name: name,
      chip: chip,
      kind: kind,
      rows: rows,
      cols: cols,
      scope: scope,
      builtin: builtin,
    );
  }

  static List<SizeGrid> catalog() {
    final saved = _readSaved();
    final removed = <String>{};
    final entries = <Map<String, dynamic>>[];
    for (final item in saved) {
      final gid = '${item['id'] ?? ''}';
      if (gid.isEmpty) continue;
      if (item['removed'] == true) {
        removed.add(gid);
        continue;
      }
      entries.add(item);
    }
    final byId = {for (final item in entries) '${item['id']}': item};
    final out = <SizeGrid>[];
    final known = {...removed};
    for (final base in defaults()) {
      known.add(base.id);
      if (removed.contains(base.id)) continue;
      out.add(_normalize(byId[base.id], base));
    }
    for (final item in entries) {
      final gid = '${item['id'] ?? ''}';
      if (gid.isEmpty || known.contains(gid) || item['builtin'] == true) continue;
      final grid = _normalize(item, null);
      if (grid.cols.isNotEmpty) out.add(grid);
    }
    return out;
  }

  static List<SizeGrid> forItems([List<SizeGrid>? grids]) {
    final source = grids ?? catalog();
    return source.where((g) => g.scope == 'items' || g.scope == 'both').toList();
  }

  static List<SizeGrid> forInventory([List<SizeGrid>? grids]) {
    final source = grids ?? catalog();
    return source
        .where((g) => g.scope == 'inventory' || g.scope == 'both')
        .toList();
  }

  static bool _allowed(SizeGrid grid, {required bool inventory}) {
    if (!grid.builtin) return true;
    final cfg = UserConfig();
    switch (grid.id) {
      case 'digits':
        return inventory ? cfg.invShowDigits : cfg.itemShowDigits;
      case 'letters':
        return cfg.itemShowLetters;
      case 'shoes':
        return inventory ? cfg.invShowShoes : cfg.itemShowShoes;
      case 'hats':
        return cfg.itemShowHats;
      case 'hats_range':
        return cfg.itemShowHatsR;
      case 'hats_wide':
        return cfg.itemShowHatsW;
      case 'gloves':
        return cfg.itemShowGloves;
      case 'gloves_sl':
        return cfg.itemShowGlovesSL;
      case 'linen':
        return cfg.itemShowLinen;
      case 'inv_letters':
        return cfg.invShowLetters;
      case 'inv_hats':
        return cfg.invShowRanges;
      default:
        return true;
    }
  }

  static List<SizeGrid> forMode(List<SizeGrid> source, {required bool inventory}) {
    final scoped = inventory ? forInventory(source) : forItems(source);
    return scoped.where((g) => _allowed(g, inventory: inventory)).toList();
  }

  static Set<String> _sizeKeys(dynamic sizeRaw) {
    Map<dynamic, dynamic>? data;
    if (sizeRaw is Map) {
      data = sizeRaw;
    } else if (sizeRaw is String && sizeRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(sizeRaw);
        if (decoded is Map) data = decoded;
      } catch (_) {}
    }
    if (data == null) return {};
    final keys = <String>{};
    data.forEach((key, value) {
      final n = int.tryParse('$value') ?? 0;
      if (n <= 0) return;
      keys.add('$key'.trim().toLowerCase().replaceAll('/', '-').replaceAll('_', '-'));
    });
    return keys;
  }

  static int _score(SizeGrid grid, Set<String> keys) {
    if (keys.isEmpty) return 0;
    final expected = <String>{};
    if (grid.isMatrix) {
      for (final col in grid.cols) {
        for (final row in grid.rows) {
          final c = col.trim().toLowerCase().replaceAll('/', '-');
          final r = row.trim().toLowerCase().replaceAll('/', '-');
          expected.add('$c-$r');
          expected.add('$r-$c');
        }
      }
    } else {
      for (final col in grid.cols) {
        expected.add(col.trim().toLowerCase().replaceAll('/', '-'));
      }
    }
    var score = 0;
    for (final key in keys) {
      if (expected.contains(key)) score++;
    }
    return score;
  }

  static int matchIndex(List<SizeGrid> grids, String typeName, Set<String> keys) {
    final names = grids.map((g) => g.name).toList();
    final named = names.indexOf(typeName);
    if (named >= 0) return named;
    var bestI = 0;
    var best = 0;
    for (var i = 0; i < grids.length; i++) {
      final score = _score(grids[i], keys);
      if (score > best) {
        best = score;
        bestI = i;
      }
    }
    return bestI;
  }

  /// Назва сітки для картки. Якщо в базі лишилось «Інвентар», шукає сітку за розмірами.
  static String resolveLabel(dynamic storedType, dynamic sizeRaw, [List<SizeGrid>? grids]) {
    final source = grids ?? catalog();
    final stored = '${storedType ?? ''}'.trim();
    if (source.any((g) => g.name == stored)) return stored;
    final keys = _sizeKeys(sizeRaw);
    if (keys.isNotEmpty && !(keys.length == 1 && keys.contains('кількість'))) {
      if (source.isEmpty) return stored.isEmpty ? '—' : stored;
      final idx = matchIndex(source, '', keys);
      if (_score(source[idx], keys) > 0) return source[idx].name;
    }
    return stored.isEmpty ? '—' : stored;
  }
}
