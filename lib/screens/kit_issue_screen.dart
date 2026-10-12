import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/camo_button.dart';
import '../core/user_config.dart';
import '../core/tactical_ui.dart';
import '../core/fun_moments.dart';
import '../services/db_service.dart';
import '../services/kit_issue_service.dart';
import '../services/last_action.dart';

class KitIssueScreen extends StatefulWidget {
  const KitIssueScreen({super.key});

  @override
  State<KitIssueScreen> createState() => _KitIssueScreenState();
}

class _KitIssueScreenState extends State<KitIssueScreen> {
  String _seasonKey = 'winter';
  String? _personName;
  bool _loading = true;
  bool _saving = false;
  List<KitLine> _lines = [];

  @override
  void initState() {
    super.initState();
    final last = UserConfig().lastIssuePerson.trim();
    if (last.isNotEmpty) _personName = last;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final items = await DBService().getAllItems();
    final ids = await DBService().getCustomList(_seasonKey);
    final remembered = await KitIssueService.loadRemembered(_personName ?? '');
    final lines = await KitIssueService.buildLines(
      allItems: items,
      seasonIds: ids,
      seasonKey: _seasonKey,
      remembered: remembered,
    );
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  Future<void> _pickPerson() async {
    String q = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: TacSheet.shape,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: DBService().getPersonnel(query: q),
            builder: (ctx, snap) {
              final people = snap.data ?? [];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Кому комплект?',
                          style: TextStyle(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setModal(() => q = v),
                        style: TextStyle(color: AppColors.textMain),
                        decoration: InputDecoration(
                          hintText: 'Пошук ПІБ...',
                          hintStyle: TextStyle(color: AppColors.muted),
                          filled: true,
                          fillColor: AppColors.bg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: people.isEmpty
                            ? Center(
                                child: Text(
                                  'Список порожній. Введи ПІБ і додай, або синхронізуй W1.2.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              )
                            : ListView.builder(
                                itemCount: people.length,
                                itemBuilder: (_, i) {
                                  final p = people[i];
                                  final name = '${p['full_name']}';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(name,
                                        style: TextStyle(
                                            color: AppColors.textMain,
                                            fontWeight: FontWeight.w800)),
                                    subtitle: Text(
                                        '${p['unit'] ?? ''} ${p['rank'] ?? ''}'
                                            .trim(),
                                        style:
                                            TextStyle(color: AppColors.muted)),
                                    onTap: () {
                                      Navigator.pop(ctx, name);
                                    },
                                  );
                                },
                              ),
                      ),
                      CamoButton(
                        label: q.trim().length < 2
                            ? 'Введи ПІБ, щоб додати'
                            : 'Додати «${q.trim()}»',
                        icon: Icons.person_add_alt_1_rounded,
                        tone: CamoTone.moss,
                        onPressed: q.trim().length < 2
                            ? null
                            : () async {
                                await DBService().addPerson(fullName: q.trim());
                                if (ctx.mounted) Navigator.pop(ctx, q.trim());
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
      },
    ).then((name) async {
      if (name is! String || name.trim().isEmpty) return;
      _personName = name.trim();
      await UserConfig().setLastIssuePerson(_personName!);
      await _reload();
    });
  }

  Future<void> _confirm() async {
    final person = (_personName ?? '').trim();
    if (person.isEmpty) {
      LastAction.showSnack(context, 'Спочатку вибери, кому видаємо',
          error: true);
      return;
    }
    if (_lines.isEmpty) {
      LastAction.showSnack(context, 'Список комплекту порожній', error: true);
      return;
    }
    final blocked = _lines.where((l) => !l.enough).toList();
    if (blocked.isNotEmpty) {
      LastAction.showSnack(context,
          'Не вистачає: ${blocked.map((e) => e.name).take(3).join(', ')}',
          error: true);
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final done = <LastStockAction>[];
    final failed = <String>[];
    for (final line in _lines) {
      final res = await DBService().applyStockDelta(
        localId: line.localId,
        sizeKey: line.needsSize ? line.sizeKey : null,
        delta: -line.norm,
        issuedTo: person,
      );
      if (res.startsWith('Помилка')) {
        failed.add('${line.name}: $res');
      } else {
        done.add(LastStockAction(
          localId: line.localId,
          sizeKey: line.needsSize ? line.sizeKey : null,
          delta: -line.norm,
          message: res,
        ));
      }
    }
    await KitIssueService.saveRemembered(person, _lines);
    if (!mounted) return;
    setState(() => _saving = false);
    if (done.isNotEmpty) LastAction.rememberBatch(done);
    final seasonName = _seasonKey == 'winter'
        ? 'Зима'
        : (_seasonKey == 'summer' ? 'Літо' : 'Видача');
    if (failed.isEmpty) {
      final hits = await UserConfig().bumpTodayHits();
      if (mounted) {
        final mile = FunCopy.milestone(hits);
        await FunStamp.show(
          context,
          title: mile ?? 'Комплект пішов',
          hint: FunCopy.afterIssue(person),
          icon: mile != null
              ? Icons.local_fire_department_rounded
              : Icons.checkroom_rounded,
        );
      }
      if (!mounted) return;
      LastAction.showSnack(
          context, 'Видано $seasonName: ${done.length} позицій → $person');
      await _reload();
    } else {
      LastAction.showSnack(context,
          'Частина не пройшла (${failed.length}). ${failed.first}',
          error: done.isEmpty);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingSize = _lines.where((l) => !l.sizeReady).length;
    final notEnough = _lines.where((l) => l.sizeReady && !l.enough).length;
    final ready = _lines.where((l) => l.enough).length;
    final canGo = (_personName ?? '').isNotEmpty &&
        _lines.isNotEmpty &&
        missingSize == 0 &&
        notEnough == 0 &&
        !_saving;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const TacAppBar(
        title: 'Комплект',
        code: 'Видача',
      ),
      body: TacBackdrop(
        child: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickPerson,
                        child: TacCard(
                          onTap: _pickPerson,
                          accent: _personName == null
                              ? AppColors.border
                              : AppColors.accent,
                          child: Row(
                            children: [
                              Icon(Icons.person_rounded,
                                  color: _personName == null
                                      ? AppColors.muted
                                      : AppColors.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _personName == null
                                      ? 'Вибери, кому видаємо'
                                      : _personName!,
                                  style: TextStyle(
                                      color: AppColors.textMain,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              Icon(Icons.expand_more_rounded,
                                  color: AppColors.muted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _seasonChip('ЗИМА', 'winter', Icons.ac_unit_rounded,
                              AppColors.ice),
                          const SizedBox(width: 8),
                          _seasonChip('ЛІТО', 'summer', Icons.wb_sunny_rounded,
                              AppColors.sun),
                          const SizedBox(width: 8),
                          _seasonChip('ВИДАЧА', 'inventory',
                              Icons.handyman_rounded, AppColors.silk),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _lines.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'У цьому списку ще немає речей.\nДодай їх у Меню → Сезонні списки.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.muted, height: 1.4),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _lines.length,
                          itemBuilder: (_, i) => _lineCard(_lines[i]),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        if (missingSize > 0)
                          Text('Вибери розмір у $missingSize позиціях',
                              style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700)),
                        if (notEnough > 0)
                          Text('Не вистачає залишку: $notEnough',
                              style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        CamoButton(
                          label: 'Видати комплект  •  $ready позицій',
                          tone: CamoTone.olive,
                          onPressed: canGo && !_saving ? _confirm : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFF4F0E4)),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _seasonChip(String label, String key, IconData icon, Color color) {
    final on = _seasonKey == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_seasonKey == key) return;
          setState(() => _seasonKey = key);
          _reload();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? color.withOpacity(0.18) : AppColors.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: on ? color : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: on ? color : AppColors.muted, size: 18),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: on ? color : AppColors.muted,
                      fontWeight: FontWeight.w900,
                      fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineCard(KitLine line) {
    final ok = line.enough;
    return TacCard(
      margin: const EdgeInsets.only(bottom: 8),
      accent: ok ? AppColors.accent : AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.name,
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w800)),
              ),
              Text('×${line.norm}',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            line.needsSize
                ? (line.sizeKey == null
                    ? '${line.warehouse}  •  вибери розмір'
                    : '${line.warehouse}  •  ${line.sizeKey}  •  ${line.stock} шт')
                : '${line.warehouse}  •  на складі ${line.stock} шт',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (line.needsSize) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: line.sizeKeys.map((key) {
                final on = line.sizeKey == key;
                final qty = line.stockFor(key);
                return GestureDetector(
                  onTap: () => setState(() => line.sizeKey = key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: on
                          ? AppColors.accent.withOpacity(0.18)
                          : AppColors.bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: on ? AppColors.accent : AppColors.border),
                    ),
                    child: Text('$key  ($qty)',
                        style: TextStyle(
                            color: qty < line.norm && on
                                ? AppColors.danger
                                : (on
                                    ? AppColors.accent
                                    : AppColors.textMain),
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
