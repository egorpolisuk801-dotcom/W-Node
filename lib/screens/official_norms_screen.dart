import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/tactical_ui.dart';
import '../data/zsu_norms.dart';

class OfficialNormsScreen extends StatelessWidget {
  const OfficialNormsScreen({super.key});

  static const _icons = <String, IconData>{
    'sv': Icons.terrain_rounded,
    'vms': Icons.directions_boat_rounded,
    'ps': Icons.flight_rounded,
    'dshv': Icons.arrow_downward_rounded,
    'sso': Icons.visibility_rounded,
  };

  static const _colors = <String, Color>{
    'sv': Color(0xFFC45C26),
    'vms': Color(0xFF2A6F97),
    'ps': Color(0xFF3D7A5A),
    'dshv': Color(0xFFB45309),
    'sso': Color(0xFF5B4B3A),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const TacAppBar(title: 'Норми ЗСУ', code: 'Норми'),
      body: TacBackdrop(
        child: FutureBuilder<ZsuNormsCatalog>(
          future: ZsuNormsCatalog.load(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Center(
                  child: CircularProgressIndicator(color: AppColors.accent));
            }
            final cat = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                TacCard(
                  accent: AppColors.accent,
                  child: Text(
                    'Наказ МОУ № 232. На одну особу: назва, строк носіння, '
                    'кількість у мирний час і в особливий період (воєнний стан).\n'
                    'БЄК видається всім силам. Далі — те, що саме для роду військ.',
                    style: TextStyle(
                        color: AppColors.textMain, height: 1.4, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
                ...cat.forces.map((f) {
                  final color = _colors[f.id] ?? AppColors.accent;
                  return TacCard(
                    accent: color,
                    margin: const EdgeInsets.only(bottom: 10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                _ForceNormsScreen(catalog: cat, force: f)),
                      );
                    },
                    child: Row(
                      children: [
                        TacIconBox(
                            icon: _icons[f.id] ?? Icons.shield_rounded,
                            color: color),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name,
                                  style: TextStyle(
                                      color: AppColors.textMain,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(f.hint,
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.accent),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final uri = Uri.parse(cat.sourceUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    'Відкрити закон на сайті Ради',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(cat.source,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 11, height: 1.35)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ForceNormsScreen extends StatefulWidget {
  final ZsuNormsCatalog catalog;
  final ZsuForce force;
  const _ForceNormsScreen({required this.catalog, required this.force});

  @override
  State<_ForceNormsScreen> createState() => _ForceNormsScreenState();
}

class _Row {
  final ZsuNormItem item;
  final ZsuNormTable table;
  const _Row(this.item, this.table);
}

class _ForceNormsScreenState extends State<_ForceNormsScreen> {
  String _q = '';
  String _group = '';
  String _tableId = '';

  List<ZsuNormTable> get _tables {
    final ids = _tableId.isEmpty ? widget.force.tableIds : [_tableId];
    return ids
        .map((id) => widget.catalog.tables[id])
        .whereType<ZsuNormTable>()
        .toList();
  }

  List<_Row> _rowsFor(ZsuNormTable table) {
    final q = _q.trim().toLowerCase();
    return table.items
        .where((item) =>
            item.matches(q) &&
            (_group.isEmpty || item.groupId == _group))
        .map((item) => _Row(item, table))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tables = _tables;
    final any = tables.any((t) => _rowsFor(t).isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TacAppBar(
        title: widget.force.short,
        code: widget.force.name,
      ),
      body: TacBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: TextStyle(color: AppColors.textMain),
                decoration: InputDecoration(
                  hintText: 'Пошук: куртка, берці, кепі…',
                  hintStyle: TextStyle(color: AppColors.muted),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            _chipStrip(
              child: Row(
                children: [
                  TacChip(
                    label: 'Усі структури',
                    active: _tableId.isEmpty,
                    onTap: () => setState(() => _tableId = ''),
                  ),
                  const SizedBox(width: 8),
                  ...widget.force.tableIds.map((id) {
                    final t = widget.catalog.tables[id];
                    if (t == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TacChip(
                        label: t.chip,
                        active: _tableId == id,
                        onTap: () => setState(
                            () => _tableId = _tableId == id ? '' : id),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _chipStrip(
              child: Row(
                children: [
                  TacChip(
                    label: 'Увесь одяг',
                    active: _group.isEmpty,
                    onTap: () => setState(() => _group = ''),
                  ),
                  const SizedBox(width: 8),
                  ...NormGroup.all.map((g) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TacChip(
                          label: g.label,
                          icon: g.icon,
                          active: _group == g.id,
                          onTap: () => setState(
                              () => _group = _group == g.id ? '' : g.id),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: !any
                  ? Center(
                      child: Text('Нічого не знайдено',
                          style: TextStyle(color: AppColors.muted)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      children: [
                        for (final table in tables)
                          ..._structureBlocks(table),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipStrip({required Widget child}) {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
    );
  }

  List<Widget> _structureBlocks(ZsuNormTable table) {
    final rows = _rowsFor(table);
    if (rows.isEmpty) return const [];
    final grouped = <String, List<_Row>>{};
    for (final g in NormGroup.all) {
      final chunk = rows.where((r) => r.item.groupId == g.id).toList();
      if (chunk.isNotEmpty) grouped[g.id] = chunk;
    }
    return [
      _structureBanner(table, rows.length),
      for (final g in NormGroup.all)
        if (grouped.containsKey(g.id)) _groupBlock(g, grouped[g.id]!),
      const SizedBox(height: 10),
    ];
  }

  Widget _structureBanner(ZsuNormTable table, int count) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12, top: 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('КОМУ',
              style: TextStyle(
                  color: AppColors.onAccent.withOpacity(0.8),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(table.who,
              style: TextStyle(
                  color: AppColors.onAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  height: 1.15)),
          const SizedBox(height: 4),
          Text('Норма № ${table.code} · $count позицій',
              style: TextStyle(
                  color: AppColors.onAccent.withOpacity(0.85), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _groupBlock(NormGroup group, List<_Row> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TacSection(code: group.label, hint: '${rows.length}'),
          const SizedBox(height: 10),
          ...rows.map((r) => _itemCard(r)),
        ],
      ),
    );
  }

  Widget _itemCard(_Row row) {
    final item = row.item;
    return TacCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name,
              style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1.25)),
          const SizedBox(height: 2),
          Text(
            item.unit.isEmpty ? 'на 1 особу' : item.unit,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill('Мирний', item.qtyPeace, item.termPeace, AppColors.accent),
              const SizedBox(width: 8),
              _pill('Воєнний', item.qtyWar, item.termWar, const Color(0xFFB45309)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String qty, String t, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 11)),
            const SizedBox(height: 2),
            Text('$qty · $t',
                style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
