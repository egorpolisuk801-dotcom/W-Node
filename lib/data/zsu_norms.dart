import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NormGroup {
  final String id;
  final String label;
  final IconData icon;
  const NormGroup(this.id, this.label, this.icon);

  static const head = NormGroup('head', 'Головні убори', Icons.face_rounded);
  static const upper = NormGroup('upper', 'Верх', Icons.checkroom_rounded);
  static const lower = NormGroup('lower', 'Низ', Icons.layers_rounded);
  static const shoes = NormGroup('shoes', 'Взуття', Icons.directions_walk_rounded);
  static const inv = NormGroup('inv', 'Інвентар', Icons.inventory_2_rounded);
  static const other = NormGroup('other', 'Інше', Icons.more_horiz_rounded);

  static const all = [head, upper, lower, shoes, inv, other];

  static NormGroup ofId(String id) =>
      all.firstWhere((g) => g.id == id, orElse: () => other);

  static bool _has(String n, List<String> keys) =>
      keys.any((k) => n.contains(k));

  static String idFor(String name) {
    final n = name.toLowerCase();
    if (_has(n, [
          'бронежилет',
          'чохол для броне',
          'чохол до броне',
          'плавуч',
          'мішок спальн',
          'килим спальн',
          'сидіння польове',
          'фляга',
          'казанок',
          'окуляр',
          'налокітник',
          'наколінник',
          'навушник',
          'підсумок',
          'рюкзак',
          'гідросистем',
          'карабін',
          'тент',
          'пальник',
          'кобура',
          'ліхтарик',
          'табірний',
          'душ польовий',
          'обігрів',
          'полог',
          'протимоскіт',
          'розвантажув',
          'беруш',
          'сумка',
        ]) ||
        (n.contains('шолом') && !n.contains('підшолом'))) {
      return inv.id;
    }
    if (_has(n, [
      'кашкет',
      'кепі',
      'панама',
      'шапка',
      'берет',
      'пілотк',
      'балаклава',
      'безкозирк',
      'стрічка до кашкет',
      'шарф',
    ]) ||
        (n.contains('маска') && !n.contains('окуляр'))) {
      return head.id;
    }
    if (_has(n, [
      'черевик',
      'напівчеревик',
      'берц',
      'чобіт',
      'капц',
      'бахіл',
      'туфл',
    ])) {
      return shoes.id;
    }
    if (_has(n, [
      'штани',
      'спідниц',
      'труси',
      'білизна',
      'фуфайка',
      'топ жіноч',
      'шкарпетк',
      'кальсон',
    ])) {
      return lower.id;
    }
    if (_has(n, [
      'костюм',
      'куртка',
      'кітел',
      'тужурк',
      'пальто',
      'плащ',
      'бушлат',
      'пончо',
      'комбінезон',
      'сорочка',
      'маскувальн',
    ])) {
      return upper.id;
    }
    return other.id;
  }
}

class ZsuNormItem {
  final String n;
  final String name;
  final String unit;
  final String qtyPeace;
  final String qtyWar;
  final String termPeace;
  final String termWar;

  const ZsuNormItem({
    required this.n,
    required this.name,
    required this.unit,
    required this.qtyPeace,
    required this.qtyWar,
    required this.termPeace,
    required this.termWar,
  });

  factory ZsuNormItem.fromJson(Map<String, dynamic> j) => ZsuNormItem(
        n: '${j['n'] ?? ''}',
        name: '${j['name'] ?? ''}',
        unit: '${j['unit'] ?? ''}',
        qtyPeace: '${j['qtyPeace'] ?? ''}',
        qtyWar: '${j['qtyWar'] ?? ''}',
        termPeace: '${j['termPeace'] ?? ''}',
        termWar: '${j['termWar'] ?? ''}',
      );

  String get groupId => NormGroup.idFor(name);

  bool matches(String q) {
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q);
  }
}

class ZsuNormTable {
  final String code;
  final String title;
  final String hint;
  final List<ZsuNormItem> items;

  const ZsuNormTable({
    required this.code,
    required this.title,
    required this.hint,
    required this.items,
  });

  factory ZsuNormTable.fromJson(Map<String, dynamic> j) => ZsuNormTable(
        code: '${j['code'] ?? ''}',
        title: '${j['title'] ?? ''}',
        hint: '${j['hint'] ?? ''}',
        items: ((j['items'] as List?) ?? [])
            .map((e) => ZsuNormItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  String get who {
    switch (code) {
      case '1':
        return 'Усім військовослужбовцям';
      case '2':
        return 'Бойовий спецкомплект';
      case '4':
        return 'Повсякденна форма';
      case '8':
        return 'Корабельний склад';
      case '12':
        return 'Радіотехнічні частини ПС';
      case '13':
        return 'Льотний склад';
      case '18':
        return 'Десант ДШВ';
      case '19':
        return 'ССО, тип С';
      case '21':
        return 'Надводні кораблі';
      default:
        return title;
    }
  }

  String get chip {
    switch (code) {
      case '1':
        return 'БЄК · усім';
      case '2':
        return 'БСК';
      case '4':
        return 'Повсякденна';
      case '8':
        return 'Корабельний склад';
      case '12':
        return 'Спецодяг ПС';
      case '13':
        return 'Льотний';
      case '18':
        return 'Десант';
      case '19':
        return 'Тип С';
      case '21':
        return 'Надводні кораблі';
      default:
        return title;
    }
  }
}

class ZsuForce {
  final String id;
  final String name;
  final String short;
  final String hint;
  final List<String> tableIds;

  const ZsuForce({
    required this.id,
    required this.name,
    required this.short,
    required this.hint,
    required this.tableIds,
  });

  factory ZsuForce.fromJson(Map<String, dynamic> j) => ZsuForce(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        short: '${j['short'] ?? ''}',
        hint: '${j['hint'] ?? ''}',
        tableIds: ((j['tableIds'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

class ZsuNormsCatalog {
  final String source;
  final String sourceUrl;
  final Map<String, ZsuNormTable> tables;
  final List<ZsuForce> forces;

  const ZsuNormsCatalog({
    required this.source,
    required this.sourceUrl,
    required this.tables,
    required this.forces,
  });

  factory ZsuNormsCatalog.fromJson(Map<String, dynamic> j) {
    final rawTables = Map<String, dynamic>.from(j['tables'] ?? {});
    return ZsuNormsCatalog(
      source: '${j['source'] ?? ''}',
      sourceUrl: '${j['sourceUrl'] ?? ''}',
      tables: rawTables.map((k, v) =>
          MapEntry(k, ZsuNormTable.fromJson(Map<String, dynamic>.from(v)))),
      forces: ((j['forces'] as List?) ?? [])
          .map((e) => ZsuForce.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static ZsuNormsCatalog? _cache;

  static Future<ZsuNormsCatalog> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/zsu_norms.json');
    _cache = ZsuNormsCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _cache!;
  }
}
