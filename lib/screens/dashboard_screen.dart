import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../core/user_config.dart';
import '../core/shell_controller.dart';
import '../core/log_utils.dart';
import '../core/tactical_ui.dart';
import '../core/fun_moments.dart';
import '../services/db_service.dart';
import '../services/smart_calculator.dart';
import 'add_universal_screen.dart';
import 'calculator_screen.dart';
import 'scan_screen.dart';
import 'season_settings_screen.dart';
import 'kit_issue_screen.dart';
import 'transfer_pick_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  bool _syncing = false;
  bool _online = false;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _logs = [];
  List<String> _warehouses = [];

  int _winterReady = 0;
  int _summerReady = 0;
  String _winterBlock = '';
  String _summerBlock = '';
  int _winterCount = 0;
  int _tip = DateTime.now().minute;
  int _summerCount = 0;
  int _issueCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh(sync: true);
    ShellController.tab.addListener(_onTab);
  }

  void _onTab() {
    if (ShellController.tab.value == 0 && mounted) {
      _loadLocal();
    }
  }

  @override
  void dispose() {
    ShellController.tab.removeListener(_onTab);
    super.dispose();
  }

  Future<void> _refresh({bool sync = false}) async {
    if (sync) setState(() => _syncing = true);
    try {
      if (sync) {
        await DBService().syncWithCloud();
      }
      await _loadLocal();
    } catch (_) {
      if (mounted) setState(() => _online = false);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _loadLocal() async {
    final items = await DBService().getAllItems();
    final logs = await DBService().getLogs();
    final winter = await DBService().getCustomList('winter');
    final summer = await DBService().getCustomList('summer');
    final issue = await DBService().getCustomList('inventory');
    final online = await DBService().hasInternet();

    Map<String, dynamic> wCalc = {};
    Map<String, dynamic> sCalc = {};
    try {
      if (winter.isNotEmpty) {
        wCalc = await SmartCalculator.calculateSeason(items, winter, 'winter');
      }
      if (summer.isNotEmpty) {
        sCalc = await SmartCalculator.calculateSeason(items, summer, 'summer');
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _items = items;
      _logs = logs
          .where((l) => LogUtils.isWithinHours(l['timestamp'], 24))
          .toList();
      _warehouses = _readWarehouses();
      _online = online;
      _winterCount = winter.length;
      _summerCount = summer.length;
      _issueCount = issue.length;
      _winterReady = wCalc['total_ready'] ?? 0;
      _summerReady = sCalc['total_ready'] ?? 0;
      _winterBlock = (wCalc['bottleneck_item'] ?? '').toString();
      _summerBlock = (sCalc['bottleneck_item'] ?? '').toString();
      _loading = false;
    });
  }

  List<String> _readWarehouses() {
    final cfg = UserConfig();
    try {
      if (cfg.wh1Name.startsWith('[')) {
        return List<String>.from(jsonDecode(cfg.wh1Name));
      }
      return [cfg.wh1Name, cfg.wh2Name].where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return ['ООС', 'ППД'];
    }
  }

  int get _totalQty => _items.fold<int>(
      0, (sum, i) => sum + (int.tryParse('${i['total']}') ?? 0));

  double get _totalValue => _items.fold<double>(0, (sum, i) {
        final qty = int.tryParse('${i['total']}') ?? 0;
        final price = double.tryParse('${i['price'] ?? 0}') ?? 0;
        return sum + qty * price;
      });

  int get _zeroCount => _items
      .where((i) => (int.tryParse('${i['total']}') ?? 0) <= 0)
      .length;

  int get _pendingSync =>
      _items.where((i) => i['needs_sync'] == true).length;

  List<Map<String, dynamic>> get _zeroItems => _items
      .where((i) => (int.tryParse('${i['total']}') ?? 0) <= 0)
      .take(4)
      .toList();

  String _syncLabel() {
    final raw = UserConfig().lastSyncAt;
    if (raw.isEmpty) return 'ще не синхронізовано';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd.MM  HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Map<String, int> _qtyByWarehouse() {
    final map = <String, int>{};
    for (final wh in _warehouses) {
      map[wh] = 0;
    }
    for (final item in _items) {
      final wh = (item['warehouse'] ?? '').toString();
      final qty = int.tryParse('${item['total']}') ?? 0;
      String? key;
      for (final name in _warehouses) {
        if (wh.toUpperCase().contains(name.toUpperCase())) {
          key = name;
          break;
        }
      }
      key ??= wh.isEmpty ? 'Інше' : wh;
      map[key] = (map[key] ?? 0) + qty;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: TacBackdrop(
        child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: () => _refresh(sync: true),
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _header(),
                    const SizedBox(height: 12),
                    _tipChip(),
                    const SizedBox(height: 16),
                    _statusCard(),
                    const SizedBox(height: 14),
                    _kpiRow(),
                    const SizedBox(height: 18),
                    const TacSection(code: 'Склади', hint: 'на полицях'),
                    const SizedBox(height: 10),
                    _warehousesBlock(),
                    const SizedBox(height: 18),
                    TacSection(
                        code: 'Комплекти',
                        hint: _issueCount > 0
                            ? 'у видачі $_issueCount'
                            : 'готовність'),
                    const SizedBox(height: 10),
                    _kitsRow(),
                    const SizedBox(height: 10),
                    TacButton(
                      label: 'Видати комплект 1 особі',
                      icon: Icons.checkroom_rounded,
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const KitIssueScreen()));
                        if (mounted) _loadLocal();
                      },
                    ),
                    const SizedBox(height: 8),
                    TacButton(
                      label: 'Перемістити між складами',
                      icon: Icons.swap_horiz_rounded,
                      color: AppColors.accentBlue,
                      filled: false,
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TransferPickScreen()));
                        if (mounted) _loadLocal();
                      },
                    ),
                    if (_zeroItems.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const TacSection(code: 'Тривога', hint: 'нуль на складі'),
                      const SizedBox(height: 10),
                      _alerts(),
                    ],
                    const SizedBox(height: 18),
                    const TacSection(code: 'Журнал', hint: 'останні 24 год'),
                    const SizedBox(height: 10),
                    _recent(),
                    const SizedBox(height: 18),
                    _quickActions(),
                  ],
                ),
        ),
      ),
      ),
    );
  }

  Widget _header() {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(FunCopy.splashHint(),
              style: TextStyle(
                  color: AppColors.textMain, fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ));
      },
      child: TacHeader(
        callsign: FunCopy.hello(),
        subtitle: FunCopy.todayLine(UserConfig().todayHits),
      actions: [
        IconButton(
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScanScreen()));
            if (mounted) _loadLocal();
          },
          icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.accent),
          tooltip: 'Сканер QR',
        ),
        IconButton(
          onPressed: _syncing ? null : () => _refresh(sync: true),
          icon: _syncing
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent))
              : Icon(Icons.sync_rounded, color: AppColors.textMain),
          tooltip: 'Синхронізувати',
        ),
      ],
      ),
    );
  }

  Widget _tipChip() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _tip++);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.wb_incandescent_outlined,
                color: AppColors.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(FunCopy.tip(_tip),
                  style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final color = _online ? AppColors.accent : AppColors.danger;
    return TacCard(
      accent: color,
      child: Row(
        children: [
          TacLed(color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _online ? 'Є зв\'язок зі складом' : 'Немає мережі — черга на відправку',
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(
                    _online
                        ? 'Остання синхронізація: ${_syncLabel()}'
                        : 'Немає мережі — зміни збережуться і підуть на Mac/Windows.',
                    style: TacStyle.muted),
                if (_pendingSync > 0) ...[
                  const SizedBox(height: 4),
                  Text('$_pendingSync змін у черзі',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ],
                if (_totalValue > 0) ...[
                  const SizedBox(height: 4),
                  Text('Вартість: ${AppColors.formatPrice(_totalValue)}',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiRow() {
    return Row(
      children: [
        _kpi('Позиції', '${_items.length}', Icons.inventory_2_rounded,
            AppColors.accentBlue),
        const SizedBox(width: 8),
        _kpi('Штук', '$_totalQty', Icons.layers_rounded, AppColors.accent),
        const SizedBox(width: 8),
        _kpi(_zeroCount > 0 ? 'Нуль' : 'Чисто', '$_zeroCount',
            Icons.warning_amber_rounded,
            _zeroCount > 0 ? AppColors.danger : AppColors.muted),
      ],
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: TacCard(
        accent: color,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _warehousesBlock() {
    final qty = _qtyByWarehouse();
    if (qty.isEmpty) {
      return _emptyHint('Склади ще думають. Потягни вниз — прокинемось разом.');
    }
    return Column(
      children: qty.entries.map((e) {
        final max = qty.values.fold<int>(1, (a, b) => a > b ? a : b);
        final ratio = max == 0 ? 0.0 : e.value / max;
        return TacCard(
              accent: AppColors.accentBlue,
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () => ShellController.go(1),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warehouse_rounded,
                        color: AppColors.accentBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(e.key,
                            style: TextStyle(
                                color: AppColors.textMain,
                                fontWeight: FontWeight.w800))),
                    Text('${e.value} шт',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0, 1),
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          );
      }).toList(),
    );
  }

  Widget _kitsRow() {
    return Row(
      children: [
        _kitCard('ЗИМА', _winterReady, _winterCount, _winterBlock, 'winter',
            Icons.ac_unit_rounded, AppColors.ice),
        const SizedBox(width: 8),
        _kitCard('ЛІТО', _summerReady, _summerCount, _summerBlock, 'summer',
            Icons.wb_sunny_rounded, AppColors.sun),
      ],
    );
  }

  Widget _kitCard(String name, int ready, int listCount, String block,
      String key, IconData icon, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (listCount == 0) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SeasonSettingsScreen()));
            return;
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      CalculatorScreen(seasonKey: key, seasonName: name)));
        },
        child: TacCard(
          accent: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(name,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Text('$ready',
                  style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      height: 1)),
              Text('комплектів',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                listCount == 0
                    ? 'Список порожній — натисни'
                    : (block.isNotEmpty && ready == 0
                        ? 'Блокує: $block'
                        : '$listCount позицій у списку'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: listCount == 0 ? AppColors.warning : AppColors.muted,
                    fontSize: 11,
                    height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alerts() {
    return Column(
      children: _zeroItems.map((item) {
        return TacCard(
          accent: AppColors.danger,
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.remove_circle_outline,
                  color: AppColors.danger, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${item['name']}',
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w700)),
              ),
              Text('${item['warehouse'] ?? ''}',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _recent() {
    if (_logs.isEmpty) {
      return _emptyHint(
          'Сьогодні змін ще не було. Усе старше — у вкладці Історія.');
    }
    return Column(
      children: [
        Container(
          height: 260,
          decoration: AppColors.cardDeco(radius: 4),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            itemCount: _logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final log = _logs[i];
              final type = (log['action_type'] ?? '').toString();
              final color = LogUtils.actionColor(type);
              final details = (log['details'] ?? '').toString();
              return GestureDetector(
                onTap: () => ShellController.go(2),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${log['item_name'] ?? type}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.textMain,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ),
                          Text(LogUtils.timeLabel(log['timestamp']),
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('$type  •  ${log['device'] ?? ''}',
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 11)),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ChangeBadge(
                            details: details, color: color, compact: true),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => ShellController.go(2),
          child: Text('Вся історія →',
              style: TextStyle(
                  color: AppColors.accentBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
        if (_pendingSync > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('$_pendingSync змін ще не пішли в хмару',
                style: TextStyle(color: AppColors.warning, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(Icons.qr_code_scanner_rounded, 'Сканер',
              AppColors.accent, () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScanScreen()));
            if (mounted) _loadLocal();
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(Icons.add_rounded, 'Додати', AppColors.accentBlue,
              () async {
            final res = await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddUniversalScreen()));
            if (res == true) _loadLocal();
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(Icons.inventory_2_outlined, 'Склад',
              AppColors.silk, () => ShellController.go(1)),
        ),
      ],
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return TacCard(
      accent: color,
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 11)),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: TextStyle(color: AppColors.muted, height: 1.4)),
    );
  }
}
