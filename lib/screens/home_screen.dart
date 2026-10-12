import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vibration/vibration.dart';
import '../core/app_colors.dart';
import '../core/user_config.dart';
import '../core/shell_controller.dart';
import '../core/tactical_ui.dart';
import '../core/fun_moments.dart';
import '../services/db_service.dart';
import '../services/last_action.dart';
import '../core/smart_icons.dart';
import '../core/size_grids.dart';

import 'add_universal_screen.dart';
import 'season_settings_screen.dart';
import 'calculator_screen.dart';
import 'scan_screen.dart';
import 'transfer_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isConnected = false;

  String _searchQuery = "";
  String _activeFilter = "Все";
  int? _expandedItemId;

  Set<String> _winterSet = {};
  Set<String> _summerSet = {};
  Set<String> _invSet = {};

  List<String> _warehouses = [];

  final Map<String, Timer> _debounceTimers = {};
  final Map<String, int> _pendingDeltas = {};
  final Map<String, int> _initialQuantities = {};

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Анімація для пульсуючого радара підключення
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initData();
    ShellController.tab.addListener(_onTab);
  }

  void _onTab() {
    if (ShellController.tab.value == 1 && mounted) {
      _loadLocalData();
    }
  }

  @override
  void dispose() {
    ShellController.tab.removeListener(_onTab);
    _pulseController.dispose();
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _initData() async {
    _loadWarehouses();
    await _loadLocalData();
    _syncData();
  }

  void _loadWarehouses() {
    final cfg = UserConfig();
    try {
      if (cfg.wh1Name.startsWith('[')) {
        _warehouses = List<String>.from(jsonDecode(cfg.wh1Name));
      } else {
        _warehouses =
            [cfg.wh1Name, cfg.wh2Name].where((e) => e.isNotEmpty).toList();
      }
    } catch (e) {
      _warehouses = ["ООС", "ППД"];
    }
    if (_warehouses.isEmpty) _warehouses = ["ООС", "ППД"];

    if (_activeFilter != "Все" &&
        _activeFilter != "Зима" &&
        _activeFilter != "Літо" &&
        _activeFilter != "Видача") {
      if (!_warehouses.contains(_activeFilter)) {
        _activeFilter = "Все";
      }
    }
  }

  void _vibrate({int duration = 30}) async {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    } else {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: duration);
      }
    }
  }

  void _showNotification(String message, bool isPositive) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isPositive ? Icons.check_circle : Icons.remove_circle,
              color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)))
        ]),
        backgroundColor: isPositive ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 180,
            left: 20,
            right: 20),
        duration: const Duration(milliseconds: 1000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 8,
      ),
    );
  }

  Map<String, dynamic> _parseSizeSafe(dynamic data) {
    if (data == null) return {};
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(data));
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Future<void> _loadLocalData() async {
    try {
      final data = await DBService().getAllItems();
      final w = await DBService().getCustomList('winter');
      final s = await DBService().getCustomList('summer');
      final i = await DBService().getCustomList('inventory');

      if (mounted) {
        setState(() {
          _items = data;
          _winterSet = w.toSet();
          _summerSet = s.toSet();
          _invSet = i.toSet();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncData() async {
    if (_isSyncing) return;
    if (mounted) setState(() => _isSyncing = true);
    try {
      await DBService().syncWithCloud();
      _loadWarehouses();
      await _loadLocalData();
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isSyncing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(
      Map<String, dynamic> item, String? sizeKey, int delta) async {
    _vibrate(duration: 30);

    String itemKey = "${item['id']}_${sizeKey ?? 'total'}";
    Map<String, dynamic> newSizes = _parseSizeSafe(item['size_data']);
    int currentTotal = int.tryParse(item['total'].toString()) ?? 0;

    int cur = sizeKey != null
        ? (int.tryParse(newSizes[sizeKey].toString()) ?? 0)
        : currentTotal;

    if (!_initialQuantities.containsKey(itemKey)) {
      _initialQuantities[itemKey] = cur;
    }

    int next = cur + delta;
    if (next < 0) {
      _showNotification("Мінімум 0", false);
      return;
    }

    if (sizeKey != null) {
      newSizes[sizeKey] = next;
      int tempTotal = 0;
      newSizes.forEach((k, v) => tempTotal += int.tryParse(v.toString()) ?? 0);
      item['total'] = tempTotal;
    } else {
      item['total'] = next;
    }
    item['size_data'] = newSizes;
    setState(() {});

    _pendingDeltas[itemKey] = (_pendingDeltas[itemKey] ?? 0) + delta;
    int accumulatedDelta = _pendingDeltas[itemKey]!;

    String actionName = item['name'];
    String sizeInfo = sizeKey != null ? " ($sizeKey)" : "";
    String sign = accumulatedDelta > 0 ? "+" : "";

    _showNotification(
        "$actionName$sizeInfo $sign$accumulatedDelta", accumulatedDelta > 0);

    _debounceTimers[itemKey]?.cancel();
    _debounceTimers[itemKey] =
        Timer(const Duration(milliseconds: 600), () async {
      int finalDelta = _pendingDeltas[itemKey] ?? 0;

      if (finalDelta != 0) {
        try {
          final res = await DBService().applyStockDelta(
            localId: item['id'] as int,
            sizeKey: sizeKey,
            delta: finalDelta,
          );
          if (res.startsWith('Помилка')) {
            if (mounted) _showNotification(res, false);
          } else {
            LastAction.remember(LastStockAction(
              localId: item['id'] as int,
              sizeKey: sizeKey,
              delta: finalDelta,
              message: res,
            ));
            if (mounted) {
              LastAction.showSnack(context, res, onUndone: _loadLocalData);
            }
          }
        } catch (e) {
          if (mounted) _showNotification("Помилка збереження", false);
        }
      }

      _pendingDeltas.remove(itemKey);
      _initialQuantities.remove(itemKey);
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = _items.where((item) {
        final name = (item['name'] ?? "").toString();
        final String itemId = item['id'].toString();

        final searchParams = name.toLowerCase() +
            (item['category'] ?? "").toString().toLowerCase();
        final search = _searchQuery.toLowerCase();

        bool matchSearch = searchParams.contains(search);
        bool matchFilter = true;

        String itemWh = (item['warehouse'] ?? "").toString().toUpperCase();

        if (_warehouses.contains(_activeFilter)) {
          matchFilter = itemWh.contains(_activeFilter.toUpperCase());
        } else if (_activeFilter == "Зима") {
          matchFilter = _winterSet.contains(itemId);
        } else if (_activeFilter == "Літо") {
          matchFilter = _summerSet.contains(itemId);
        } else if (_activeFilter == "Видача") {
          matchFilter = _invSet.contains(itemId);
        }

        return matchSearch && matchFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSeasonActive = _activeFilter == "Зима" ||
        _activeFilter == "Літо" ||
        _activeFilter == "Видача";

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: TacBackdrop(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _syncData,
          color: AppColors.accent,
          backgroundColor: AppColors.bg,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader()
                    .animate()
                    .fade(duration: 400.ms)
                    .slideY(begin: -0.1, curve: Curves.easeOut),
              ),
              SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyFilterDelegate(child: _buildFilterRow())),
              if (_isLoading)
                SliverFillRemaining(
                    child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.accent)))
              else if (_filteredItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 56, color: AppColors.accent.withOpacity(0.45)),
                          const SizedBox(height: 12),
                          Text(
                              _items.isEmpty
                                  ? "Полиці ще порожні"
                                  : "Такої речі тут немає",
                              style: TextStyle(
                                  color: AppColors.textMain,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(
                              _items.isEmpty
                                  ? FunCopy.emptyStock()
                                  : FunCopy.emptySearch(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.muted.withOpacity(0.85),
                                  height: 1.4))
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _itemCard(_filteredItems[i])
                              .animate(delay: (i.clamp(0, 10) * 20).ms)
                              .fade(duration: 250.ms)
                              .slideY(
                                  begin: 0.05,
                                  duration: 250.ms,
                                  curve: Curves.easeOutCubic),
                          childCount: _filteredItems.length)),
                ),
            ],
          ),
        ),
      ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isSeasonActive) ...[
            FloatingActionButton.extended(
              heroTag: "calc_btn",
              backgroundColor: AppColors.accent,
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              icon: Icon(Icons.analytics_rounded,
                  color: AppColors.onAccent, size: 20),
              label: Text("Аналіз",
                  style: TextStyle(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              onPressed: () {
                _vibrate(duration: 30);
                String sKey = _activeFilter == 'Зима'
                    ? 'winter'
                    : (_activeFilter == 'Літо' ? 'summer' : 'inventory');
                String sName = _activeFilter.toUpperCase();

                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CalculatorScreen(
                            seasonKey: sKey, seasonName: sName)));
              },
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            heroTag: "scan_btn",
            mini: true,
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.accent,
            elevation: 6,
            child: const Icon(Icons.qr_code_scanner_rounded, size: 22),
            onPressed: () async {
              _vibrate(duration: 30);
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()));
              if (mounted) _loadLocalData();
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "add_btn",
            backgroundColor: AppColors.accent,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            child: Icon(Icons.add_rounded, color: AppColors.onAccent, size: 30),
            onPressed: () async {
              _vibrate(duration: 50);
              final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddUniversalScreen()));
              if (res == true) _loadLocalData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('W-Node', style: TacStyle.stencil),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text("Склад",
                      style: TacStyle.title),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: _isConnected
                                  ? AppColors.accent
                                  : (_isSyncing
                                      ? AppColors.warning
                                      : AppColors.danger),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: (_isConnected
                                            ? AppColors.accent
                                            : AppColors.danger)
                                        .withOpacity(
                                            0.6 * _pulseController.value),
                                    blurRadius: 6 * _pulseController.value,
                                    spreadRadius: 1 * _pulseController.value)
                              ]),
                        );
                      })
                ],
              ),
              Text(
                  _isSyncing
                      ? "Оновлення з W1.2..."
                      : "${_filteredItems.length} з ${_items.length} позицій",
                  style: TextStyle(
                      color: AppColors.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Row(children: [
            _iconBtn(Icons.rule_rounded, AppColors.silk, () async {
              _vibrate(duration: 20);
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SeasonSettingsScreen()));
              _loadLocalData();
            }),
          ])
        ]),
        const SizedBox(height: 12),
        Text(
          "Натисни картку, щоб видати або прийняти. "
          "Вправо — сезони, вліво — архів.",
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.3),
        ),
        const SizedBox(height: 12),
        VolGlass(
          radius: 24,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 48,
            child: TextField(
            onChanged: (val) {
              _searchQuery = val;
              _applyFilters();
            },
            style: TextStyle(
                color: AppColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
                hintText: "Пошук за назвою або категорією",
                hintStyle: TextStyle(color: AppColors.muted.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.accentBlue, size: 22),
                border: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
            ),
          ),
        ),
      ]),
    );
  }

  int _countFor(String key) {
    if (key == "Все") return _items.length;
    return _items.where((item) {
      final String itemId = item['id'].toString();
      final String itemWh = (item['warehouse'] ?? "").toString().toUpperCase();
      if (_warehouses.contains(key)) {
        return itemWh.contains(key.toUpperCase());
      } else if (key == "Зима") {
        return _winterSet.contains(itemId);
      } else if (key == "Літо") {
        return _summerSet.contains(itemId);
      } else if (key == "Видача") {
        return _invSet.contains(itemId);
      }
      return true;
    }).length;
  }

  Widget _buildFilterRow() {
    List<Widget> chips = [
      _chip("Все", "Все", Icons.dashboard_rounded, AppColors.muted),
      const SizedBox(width: 10),
    ];

    List<Color> whColors = [
      AppColors.accentBlue,
      Colors.indigoAccent,
      Colors.teal,
      Colors.deepPurple
    ];
    List<IconData> whIcons = [
      Icons.store_rounded,
      Icons.store_mall_directory_rounded,
      Icons.warehouse_rounded,
      Icons.domain_rounded
    ];

    for (int i = 0; i < _warehouses.length; i++) {
      String wh = _warehouses[i];
      chips.add(_chip(
          wh, wh, whIcons[i % whIcons.length], whColors[i % whColors.length]));
      chips.add(const SizedBox(width: 10));
    }

    chips.addAll([
      _chip("Зима", null, Icons.ac_unit_rounded, AppColors.ice),
      const SizedBox(width: 10),
      _chip("Літо", null, Icons.wb_sunny_rounded, AppColors.sun),
      const SizedBox(width: 10),
      _chip("Видача", "Інвентар", Icons.handyman_rounded, AppColors.silk),
    ]);

    return Container(
      color: AppColors.bg,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: chips,
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color col, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border)),
            child: Icon(icon, color: col, size: 20)));
  }

  Widget _chip(String key, [String? label, IconData? icon, Color? iconColor]) {
    bool active = _activeFilter == key;
    return GestureDetector(
      onTap: () {
        _vibrate(duration: 20);
        setState(() {
          _activeFilter = key;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: active ? AppColors.accent.withOpacity(0.14) : AppColors.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: active ? AppColors.accent : AppColors.border,
                width: active ? 1.4 : 1)),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon,
                size: 16,
                color: active ? AppColors.accent : (iconColor ?? AppColors.muted)),
            const SizedBox(width: 6)
          ],
          Text(
              "${label ?? key} (${_countFor(key)})",
              style: TextStyle(
                  color: active ? AppColors.accent : AppColors.muted,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    String cleanCat = category.trim().toUpperCase();
    if (cleanCat.isEmpty || cleanCat == "NULL") return const SizedBox.shrink();
    String label = "КАТ: I";
    Color color = AppColors.ice;
    if (cleanCat.contains("II") || cleanCat.contains("2")) {
      label = "КАТ: II";
      color = AppColors.sun;
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5), width: 1)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5)));
  }

  String _gridLabel(Map<String, dynamic> item) {
    final label = SizeGrids.resolveLabel(item['item_type'], item['size_data']);
    if (label.isEmpty ||
        label == '—' ||
        label == 'Інвентар' ||
        label == 'Просте') {
      return '';
    }
    return label;
  }

  Widget _buildGridBadge(String label, Color color) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.35), width: 1)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.3)));
  }

  // 🔥 ОНОВЛЕНИЙ ВІДЖЕТ ДЛЯ БІРКИ ТИПУ 🔥
  Widget _buildTypeBadge(bool isInventory, Color color) {
    String label = isInventory ? "ІНВЕНТАР" : "РЕЧІ";
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5), width: 1)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5)));
  }

  Widget _itemCard(Map<String, dynamic> item) {
    bool expanded = _expandedItemId == item['id'];
    int total = int.tryParse(item['total'].toString()) ?? 0;
    String name = item['name'] ?? "No Name";
    String cat = item['category'] ?? "";
    String wh = item['warehouse'] ?? "";

    var rawIsInv = item['is_inventory'];
    bool isInventory = (rawIsInv == 1) ||
        (rawIsInv == true) ||
        (rawIsInv.toString() == "1") ||
        (item['item_type'] == "Інвентар");
    String rawDate = item['date_added']?.toString() ?? "";
    String date = (rawDate.length >= 10) ? rawDate.substring(0, 10) : rawDate;
    String priceLabel = AppColors.formatPrice(item['price']);

    IconData typeIcon = SmartIcons.getIcon(isInventory);
    Color typeColor = SmartIcons.getColor(isInventory);

    return Dismissible(
      key: ValueKey("${item['local_id']}_dismiss"),
      direction: DismissDirection.horizontal,
      background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.85),
              borderRadius: BorderRadius.circular(4)),
          child: Icon(Icons.menu_open_rounded,
              color: AppColors.onAccent, size: 28)),
      secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4)),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 28)),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart) {
          _vibrate(duration: 50);
          await _deleteItem(item['local_id'], item['server_id']);
          return false;
        } else if (dir == DismissDirection.startToEnd) {
          _vibrate(duration: 20);
          _showQuickActionMenu(item);
          return false;
        }
        return false;
      },
      child: GestureDetector(
        onTap: () {
          _vibrate(duration: 20);
          setState(() => _expandedItemId = expanded ? null : item['id']);
        },
        child: VolGlass(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          radius: 28,
          glow: expanded ? typeColor : null,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: typeColor.withOpacity(0.4))),
                  child: Icon(typeIcon, color: typeColor, size: 22)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // 🔥 ТУТ ВИКЛИКАЄТЬСЯ НОВА УНІВЕРСАЛЬНА БІРКА 🔥
                          _buildTypeBadge(isInventory, typeColor),
                          if (_gridLabel(item).isNotEmpty)
                            _buildGridBadge(_gridLabel(item), typeColor),
                          _buildCategoryBadge(cat),
                          if (priceLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.accent.withOpacity(0.4))),
                              child: Text(priceLabel,
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10)),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.place_rounded,
                                  size: 12, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 100),
                                child: Text(wh,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              )
                            ],
                          )
                        ])
                  ])),
              Container(
                  width: 45,
                  height: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border)),
                  child: Text("$total",
                      style: TextStyle(
                          color: total == 0 ? Colors.redAccent : typeColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 16))),
            ]),
            if (expanded) ...[
              const SizedBox(height: 15),
              Divider(color: AppColors.muted.withOpacity(0.2), thickness: 1),
              const SizedBox(height: 8),
              Text("− видати   + прийняти   затисни для пачки",
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
              const SizedBox(height: 12),
              _controlPanel(item, total, isInventory, typeColor),
              const SizedBox(height: 12),
              Row(children: [
                TextButton.icon(
                  onPressed: () => _showEditItem(item),
                  icon: Icon(Icons.edit_rounded,
                      size: 16, color: AppColors.accentBlue),
                  label: Text('Редагувати',
                      style: TextStyle(
                          color: AppColors.accentBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                const Spacer(),
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(date,
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500))
              ])
            ]
          ]),
        ),
      ),
    );
  }

  Widget _controlPanel(
      Map<String, dynamic> item, int total, bool isInventory, Color typeColor) {
    Map<String, dynamic> sizes = _parseSizeSafe(item['size_data']);

    if (sizes.isEmpty) {
      return _qtyRow(
          label: "Загальна кількість",
          val: total,
          onMinus: () => _updateQuantity(item, null, -1),
          onPlus: () => _updateQuantity(item, null, 1),
          onMinusLong: () => _showBulkDialog(item, null, false),
          onPlusLong: () => _showBulkDialog(item, null, true),
          color: typeColor,
          large: true);
    }
    if (sizes.length == 1) {
      String key = sizes.keys.first;
      int val = int.tryParse(sizes[key].toString()) ?? 0;
      return _qtyRow(
          label: key,
          val: val,
          onMinus: () => _updateQuantity(item, key, -1),
          onPlus: () => _updateQuantity(item, key, 1),
          onMinusLong: () => _showBulkDialog(item, key, false),
          onPlusLong: () => _showBulkDialog(item, key, true),
          color: typeColor,
          large: true);
    }

    final keys = sizes.keys.toList();
    return Column(
      children: keys.map((key) {
        int val = int.tryParse(sizes[key].toString()) ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _qtyRow(
              label: key,
              val: val,
              onMinus: () => _updateQuantity(item, key, -1),
              onPlus: () => _updateQuantity(item, key, 1),
              onMinusLong: () => _showBulkDialog(item, key, false),
              onPlusLong: () => _showBulkDialog(item, key, true),
              color: typeColor),
        );
      }).toList(),
    );
  }

  Widget _qtyRow({
    required String label,
    required int val,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required VoidCallback onMinusLong,
    required VoidCallback onPlusLong,
    required Color color,
    bool large = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: 12, vertical: large ? 14 : 10),
      decoration: AppColors.cardDeco(radius: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
                const SizedBox(height: 2),
                Text("$val",
                    style: TextStyle(
                        color: val == 0 ? AppColors.danger : AppColors.textMain,
                        fontWeight: FontWeight.w900,
                        fontSize: large ? 28 : 22,
                        height: 1.1)),
              ],
            ),
          ),
          _stepBtn(
              icon: Icons.remove_rounded,
              label: "Видати",
              color: AppColors.danger,
              onTap: onMinus,
              onLong: onMinusLong),
          const SizedBox(width: 8),
          _stepBtn(
              icon: Icons.add_rounded,
              label: "Прийняти",
              color: AppColors.accent,
              onTap: onPlus,
              onLong: onPlusLong),
        ],
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onLong,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLong,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showBulkDialog(Map<String, dynamic> item, String? sizeKey, bool isAdd) {
    _vibrate(duration: 30);
    TextEditingController qtyCtrl = TextEditingController();
    String title = isAdd ? "Додати кількість" : "Відняти кількість";
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.bg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                title: Text(title,
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                content: Container(
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.shadowTop,
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                              spreadRadius: -2),
                          BoxShadow(
                              color: AppColors.shadowBottom,
                              offset: const Offset(-2, -2),
                              blurRadius: 4,
                              spreadRadius: -2)
                        ]),
                    child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                            hintText: "0",
                            hintStyle: TextStyle(color: AppColors.muted),
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10)))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Скасувати",
                          style: TextStyle(color: AppColors.muted, fontSize: 14))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4))),
                      onPressed: () {
                        _vibrate(duration: 60);
                        int val = int.tryParse(qtyCtrl.text) ?? 0;
                        if (val > 0) {
                          int delta = isAdd ? val : -val;
                          _updateQuantity(item, sizeKey, delta);
                        }
                        Navigator.pop(ctx);
                      },
                      child: Text("ОК",
                          style: TextStyle(
                              color: AppColors.onAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)))
                ]));
  }

  Future<void> _deleteItem(int localId, int? serverId) async {
    _vibrate(duration: 50);
    bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.bg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                title: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Text("Видалити?",
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text("Цей запис буде переміщено в архів.",
                    style: TextStyle(color: AppColors.muted, fontSize: 15)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text("Ні",
                          style: TextStyle(color: AppColors.muted, fontSize: 15))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Так",
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)))
                ]));
    if (confirm) {
      _vibrate(duration: 100);
      final db = await DBService().localDb;
      await db.update('items', {'is_deleted': 1, 'is_unsynced': 1},
          where: 'local_id = ?', whereArgs: [localId]);
      await DBService()
          .logHistory("Видалено", "Товар ID $localId", "Переміщено в архів");
      _loadLocalData();
      DBService().syncWithCloud();
    }
  }

  void _showEditItem(Map<String, dynamic> item) {
    final nameCtrl =
        TextEditingController(text: '${item['name'] ?? ''}');
    final locCtrl =
        TextEditingController(text: '${item['location'] ?? ''}');
    final priceCtrl = TextEditingController(
        text: (double.tryParse('${item['price'] ?? 0}') ?? 0) > 0
            ? '${item['price']}'
            : '');
    String warehouse = '${item['warehouse'] ?? ''}';
    if (warehouse.isEmpty && _warehouses.isNotEmpty) {
      warehouse = _warehouses.first;
    }
    String category = '${item['category'] ?? 'I'}';
    if (category != 'I' && category != 'II') category = 'I';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: TacSheet.shape,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          InputDecoration deco(String hint) => InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.muted),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none),
              );
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 14),
                  Text('Редагувати картку',
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w900,
                          fontSize: 18)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: AppColors.textMain),
                    decoration: deco('Назва'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locCtrl,
                    style: TextStyle(color: AppColors.textMain),
                    decoration: deco('Місце (полиця, ящик...)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppColors.textMain),
                    decoration: deco('Ціна за шт, грн'),
                  ),
                  const SizedBox(height: 12),
                  Text('Склад',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _warehouses.map((wh) {
                      final on = warehouse == wh;
                      return GestureDetector(
                        onTap: () => setModal(() => warehouse = wh),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: on
                                ? AppColors.accent.withOpacity(0.15)
                                : AppColors.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color:
                                    on ? AppColors.accent : AppColors.border),
                          ),
                          child: Text(wh,
                              style: TextStyle(
                                  color: on
                                      ? AppColors.accent
                                      : AppColors.textMain,
                                  fontWeight: FontWeight.w800)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text('Категорія',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(children: [
                    ChoiceChip(
                      label: const Text('I'),
                      selected: category == 'I',
                      onSelected: (_) => setModal(() => category = 'I'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('II'),
                      selected: category == 'II',
                      onSelected: (_) => setModal(() => category = 'II'),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final price = double.tryParse(
                                priceCtrl.text.replaceAll(',', '.')) ??
                            0;
                        await DBService().updateItemDetails(
                          localId: item['id'] as int,
                          name: name,
                          location: locCtrl.text.trim(),
                          warehouse: warehouse,
                          category: category,
                          price: price,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadLocalData();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent),
                      child: const Text('Зберегти',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showQuickActionMenu(Map<String, dynamic> item) {
    String itemIdStr = item['id'].toString();

    bool isWinter = _winterSet.contains(itemIdStr);
    bool isSummer = _summerSet.contains(itemIdStr);
    bool isInv = _invSet.contains(itemIdStr);

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.shadowTop,
                          blurRadius: 15,
                          offset: const Offset(0, -5))
                    ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),
                    Text("Швидкі дії",
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    _quickActionTile(
                        icon: Icons.swap_horiz_rounded,
                        title: "Перемістити на інший склад",
                        isActive: true,
                        color: AppColors.accentBlue,
                        onTap: () {
                          Navigator.pop(ctx);
                          TransferSheet.show(context,
                              item: item, onDone: _loadLocalData);
                        }),
                    _quickActionTile(
                        icon: Icons.edit_rounded,
                        title: "Редагувати картку",
                        isActive: true,
                        color: AppColors.accentBlue,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showEditItem(item);
                        }),
                    _quickActionTile(
                        icon: Icons.ac_unit_rounded,
                        title: isWinter ? "Прибрати із Зими" : "Додати в Зиму",
                        isActive: isWinter,
                        color: AppColors.ice,
                        onTap: () async {
                          _vibrate(duration: 20);
                          await DBService()
                              .toggleItemInList('winter', itemIdStr, !isWinter);
                          setModalState(() => isWinter = !isWinter);
                          _loadLocalData();
                        }),
                    _quickActionTile(
                        icon: Icons.wb_sunny_rounded,
                        title: isSummer ? "Прибрати з Літа" : "Додати в Літо",
                        isActive: isSummer,
                        color: AppColors.sun,
                        onTap: () async {
                          _vibrate(duration: 20);
                          await DBService()
                              .toggleItemInList('summer', itemIdStr, !isSummer);
                          setModalState(() => isSummer = !isSummer);
                          _loadLocalData();
                        }),
                    _quickActionTile(
                        icon: Icons.handyman_rounded,
                        title: isInv ? "Прибрати з Видачі" : "Додати у Видачу",
                        isActive: isInv,
                        color: AppColors.silk,
                        onTap: () async {
                          _vibrate(duration: 20);
                          await DBService()
                              .toggleItemInList('inventory', itemIdStr, !isInv);
                          setModalState(() => isInv = !isInv);
                          _loadLocalData();
                        }),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            }));
  }

  Widget _quickActionTile(
      {required IconData icon,
      required String title,
      required bool isActive,
      required Color color,
      required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : AppColors.bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: isActive ? color.withOpacity(0.3) : Colors.transparent)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(icon, color: isActive ? color : AppColors.muted, size: 24),
        title: Text(title,
            style: TextStyle(
                color: isActive ? color : AppColors.muted,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        trailing: isActive
            ? Icon(Icons.check_circle_rounded, color: color, size: 24)
            : Icon(Icons.circle_outlined, color: AppColors.muted, size: 24),
      ),
    );
  }
}

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyFilterDelegate({required this.child});
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
          decoration: BoxDecoration(
              color: AppColors.bg,
              boxShadow: overlapsContent
                  ? [
                      const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 3))
                    ]
                  : null),
          child: child);
  @override
  double get maxExtent => 60;
  @override
  double get minExtent => 60;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
