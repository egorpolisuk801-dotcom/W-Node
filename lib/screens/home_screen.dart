import 'dart:async';
import 'dart:convert'; // 🔥 ДОДАНО ДЛЯ БЕЗПЕЧНОГО ПАРСИНГУ
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vibration/vibration.dart';
import '../core/app_colors.dart';
import '../core/user_config.dart';
import '../services/db_service.dart';

import 'add_universal_screen.dart';
import 'settings_screen.dart';
import 'logs_screen.dart';
import 'season_settings_screen.dart';
import 'calculator_screen.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isConnected = false;

  String _searchQuery = "";
  String _activeFilter = "Все"; // Текущий фильтр
  int? _expandedItemId;

  // Списки для фильтрации (теперь хранят ID)
  Set<String> _winterSet = {};
  Set<String> _summerSet = {};
  Set<String> _invSet = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadLocalData();
    _syncData();
  }

  void _vibrate({int duration = 50}) async {
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
              color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)))
        ]),
        backgroundColor: isPositive ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 200,
            left: 20,
            right: 20),
        duration: const Duration(milliseconds: 800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  // 🔥 БРОНЬОВАНИЙ ПАРСЕР РОЗМІРІВ ДЛЯ ЗАХИСТУ ВІД ВИЛЬОТІВ
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
    _vibrate(duration: 40);

    // 🔥 Використовуємо безпечний парсер замість простого Map.from
    Map<String, dynamic> newSizes = _parseSizeSafe(item['size_data']);
    int currentTotal = int.tryParse(item['total'].toString()) ?? 0;

    if (sizeKey != null) {
      int cur = int.tryParse(newSizes[sizeKey].toString()) ?? 0;
      int next = cur + delta;
      if (next < 0) return;
      newSizes[sizeKey] = next;
      int tempTotal = 0;
      newSizes.forEach((k, v) => tempTotal += int.tryParse(v.toString()) ?? 0);
      item['total'] = tempTotal;
    } else {
      int next = currentTotal + delta;
      if (next < 0) return;
      item['total'] = next;
    }
    item['size_data'] = newSizes;
    setState(() {}); // Оновлюємо UI миттєво

    String actionName = item['name'];
    String sizeInfo = sizeKey != null ? " ($sizeKey)" : "";
    String sign = delta > 0 ? "+" : "";
    _showNotification("$actionName$sizeInfo $sign$delta", delta > 0);

    // Зберігаємо у фоні
    Future.delayed(Duration.zero, () async {
      try {
        await DBService().updateItemSizes(item['id'], item['name'],
            item['category'], newSizes, item['total']);
        String details = sizeKey != null
            ? "Розмір $sizeKey: $sign$delta"
            : "Загальна к-сть: $sign$delta";
        await DBService().logHistory(
            item['name'], delta > 0 ? "Додано" : "Вилучено", details);
      } catch (e) {
        // 🔥 Прибрали виклик _loadLocalData() при помилці, щоб не викликати нескінченний цикл
        if (mounted) _showNotification("Помилка збереження", false);
      }
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
        final config = UserConfig();

        String itemWh = (item['warehouse'] ?? "").toString().toUpperCase();
        String wh1 = config.wh1Name.toUpperCase();
        String wh2 = config.wh2Name.toUpperCase();

        if (_activeFilter == "Зима") {
          matchFilter = _winterSet.contains(itemId);
        } else if (_activeFilter == "Літо") {
          matchFilter = _summerSet.contains(itemId);
        } else if (_activeFilter == "Видача") {
          matchFilter = _invSet.contains(itemId);
        } else if (_activeFilter == "Склад 1") {
          matchFilter = itemWh.contains(wh1);
        } else if (_activeFilter == "Склад 2") {
          matchFilter = itemWh.contains(wh2);
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
      body: SafeArea(
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
                    .fade(duration: 500.ms)
                    .slideY(begin: -0.2, curve: Curves.easeOutExpo),
              ),
              SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyFilterDelegate(child: _buildFilterRow())),
              if (_isLoading)
                const SliverFillRemaining(
                    child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.accent)))
              else if (_filteredItems.isEmpty)
                SliverFillRemaining(
                    child: Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                      Icon(Icons.inbox, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      const Text("Список пустий",
                          style: TextStyle(color: Colors.grey))
                    ])))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 100),
                  sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _itemCard(_filteredItems[i])
                              .animate(delay: (i.clamp(0, 10) * 40).ms)
                              .fade(duration: 300.ms)
                              .slideY(
                                  begin: 0.1,
                                  duration: 300.ms,
                                  curve: Curves.easeOutQuad),
                          childCount: _filteredItems.length)),
                ),
            ],
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
              backgroundColor: const Color(0xFF00E676),
              icon: const Icon(Icons.analytics_outlined,
                  color: Color(0xFF121212)),
              label: const Text("АНАЛІЗ КОМПЛЕКТАЦІЇ",
                  style: TextStyle(
                      color: Color(0xFF121212), fontWeight: FontWeight.bold)),
              onPressed: () {
                _vibrate(duration: 30);
                String sKey = _activeFilter == 'Зима'
                    ? 'winter'
                    : (_activeFilter == 'Літо' ? 'summer' : 'inventory');
                String sName = _activeFilter.toUpperCase();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CalculatorScreen(seasonKey: sKey, seasonName: sName),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton(
            heroTag: "add_btn",
            backgroundColor: AppColors.accent,
            elevation: 10,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 25),
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadowBottom,
                offset: const Offset(0, 5),
                blurRadius: 15)
          ]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text("W-Node",
                style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 26)),
            const SizedBox(width: 10),
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: _isConnected
                        ? Colors.green
                        : (_isSyncing ? Colors.orange : Colors.red),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: (_isConnected ? Colors.green : Colors.red)
                              .withOpacity(0.6),
                          blurRadius: 8)
                    ]))
          ]),
          Row(children: [
            _iconBtn(Icons.history, AppColors.accentBlue, () {
              _vibrate(duration: 20);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LogsScreen()));
            }),
            const SizedBox(width: 10),
            _iconBtn(Icons.checklist_rtl, Colors.purpleAccent, () async {
              _vibrate(duration: 20);
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SeasonSettingsScreen()));
              _loadLocalData();
            }),
            const SizedBox(width: 10),
            _iconBtn(Icons.settings, AppColors.textMain, () async {
              _vibrate(duration: 20);
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadLocalData();
            }),
          ])
        ]),
        const SizedBox(height: 25),
        Container(
          decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: AppColors.shadowTop,
                    offset: const Offset(-3, -3),
                    blurRadius: 6),
                BoxShadow(
                    color: AppColors.shadowBottom,
                    offset: const Offset(3, 3),
                    blurRadius: 6)
              ]),
          child: TextField(
            onChanged: (val) {
              _searchQuery = val;
              _applyFilters();
            },
            style: TextStyle(color: AppColors.textMain, fontSize: 18),
            decoration: InputDecoration(
                hintText: "Пошук...",
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
                prefixIcon:
                    Icon(Icons.search, color: AppColors.accentBlue, size: 26),
                border: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 20)),
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterRow() {
    final config = UserConfig();
    return Container(
      color: AppColors.bg,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _chip("Все"),
          const SizedBox(width: 12),
          _chip("Склад 1", config.wh1Name, Icons.store, Colors.blueAccent),
          const SizedBox(width: 12),
          _chip("Склад 2", config.wh2Name, Icons.store_mall_directory,
              Colors.indigoAccent),
          const SizedBox(width: 12),
          _chip("Зима", null, Icons.ac_unit, Colors.cyan),
          const SizedBox(width: 12),
          _chip("Літо", null, Icons.wb_sunny, Colors.orange),
          const SizedBox(width: 12),
          _chip("Видача", "Інвентар", Icons.handyman, Colors.purple),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color col, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadowTop,
                      offset: const Offset(-3, -3),
                      blurRadius: 5),
                  BoxShadow(
                      color: AppColors.shadowBottom,
                      offset: const Offset(3, 3),
                      blurRadius: 5)
                ]),
            child: Icon(icon, color: col, size: 22)));
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(24),
            border:
                active ? Border.all(color: AppColors.accent, width: 1.5) : null,
            boxShadow: active
                ? [
                    BoxShadow(
                        color: AppColors.shadowTop,
                        offset: const Offset(2, 2),
                        blurRadius: 3,
                        spreadRadius: -2),
                    BoxShadow(
                        color: AppColors.shadowBottom,
                        offset: const Offset(-2, -2),
                        blurRadius: 3,
                        spreadRadius: -2)
                  ]
                : [
                    BoxShadow(
                        color: AppColors.shadowTop,
                        offset: const Offset(-3, -3),
                        blurRadius: 5),
                    BoxShadow(
                        color: AppColors.shadowBottom,
                        offset: const Offset(3, 3),
                        blurRadius: 5)
                  ]),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon,
                size: 16,
                color: active ? AppColors.accent : (iconColor ?? Colors.grey)),
            const SizedBox(width: 6)
          ],
          Text(label ?? key,
              style: TextStyle(
                  color: active ? AppColors.accent : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    String cleanCat = category.trim().toUpperCase();
    if (cleanCat.isEmpty || cleanCat == "NULL") return const SizedBox.shrink();
    String label = "I";
    Color color = Colors.cyanAccent;
    if (cleanCat.contains("II") || cleanCat.contains("2")) {
      label = "II";
      color = Colors.orangeAccent;
    }
    return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.5), width: 1)),
        child: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)));
  }

  Widget _buildInventoryBadge() {
    return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.purpleAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: Colors.purpleAccent.withOpacity(0.5), width: 1)),
        child: const Text("ІНВЕНТАР",
            style: TextStyle(
                color: Colors.purpleAccent,
                fontWeight: FontWeight.bold,
                fontSize: 10)));
  }

  Widget _itemCard(Map<String, dynamic> item) {
    bool expanded = _expandedItemId == item['id'];
    int total = int.tryParse(item['total'].toString()) ?? 0;
    String name = item['name'] ?? "No Name";
    String cat = item['category'] ?? "";
    String wh = item['warehouse'] ?? "";
    var rawIsInv = item['is_inventory'];
    bool flagCheck =
        (rawIsInv == 1) || (rawIsInv == true) || (rawIsInv.toString() == "1");
    bool isInventory = flagCheck || (item['item_type'] == "Інвентар");
    String rawDate = item['date_added']?.toString() ?? "";
    String date = (rawDate.length >= 10) ? rawDate.substring(0, 10) : rawDate;
    IconData typeIcon = isInventory ? Icons.handyman : Icons.checkroom;
    Color typeColor = isInventory ? Colors.purpleAccent : AppColors.accentBlue;

    return Dismissible(
      key: ValueKey("${item['local_id']}_dismiss"),
      direction: DismissDirection.horizontal,
      background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: AppColors.accentBlue,
              borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.menu_open, color: Colors.white, size: 30)),
      secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: Colors.red, borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.delete, color: Colors.white, size: 30)),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: AppColors.shadowBottom,
                    offset: const Offset(5, 5),
                    blurRadius: 12),
                BoxShadow(
                    color: AppColors.shadowTop,
                    offset: const Offset(-5, -5),
                    blurRadius: 12)
              ],
              border: expanded
                  ? Border.all(color: typeColor.withOpacity(0.5), width: 1.5)
                  : null),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(typeIcon, color: typeColor, size: 24)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        maxLines: 3,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (isInventory) _buildInventoryBadge(),
                      _buildCategoryBadge(cat),
                      const Icon(Icons.place, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(wh,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      )
                    ])
                  ])),
              Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.bg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.shadowTop,
                            offset: const Offset(-3, -3),
                            blurRadius: 5),
                        BoxShadow(
                            color: AppColors.shadowBottom,
                            offset: const Offset(3, 3),
                            blurRadius: 5)
                      ]),
                  child: Text("$total",
                      style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18))),
            ]),
            if (expanded) ...[
              const SizedBox(height: 20),
              Divider(color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 15),
              _controlPanel(item, total, isInventory),
              const SizedBox(height: 15),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(date,
                    style: const TextStyle(color: Colors.grey, fontSize: 12))
              ])
            ]
          ]),
        ),
      ),
    );
  }

  Widget _controlPanel(Map<String, dynamic> item, int total, bool isInventory) {
    // 🔥 БЕЗПЕЧНИЙ ПАРСИНГ!
    Map<String, dynamic> sizes = _parseSizeSafe(item['size_data']);

    if (sizes.isEmpty) {
      return _verticalStyleCard(
          label: "Загальна кількість",
          val: total,
          onMinus: () => _updateQuantity(item, null, -1),
          onPlus: () => _updateQuantity(item, null, 1),
          onMinusLong: () => _showBulkDialog(item, null, false),
          onPlusLong: () => _showBulkDialog(item, null, true),
          isInv: isInventory,
          icon: isInventory ? Icons.build : Icons.checkroom);
    }
    if (sizes.length == 1) {
      String key = sizes.keys.first;
      int val = int.tryParse(sizes[key].toString()) ?? 0;
      return _verticalStyleCard(
          label: key,
          val: val,
          onMinus: () => _updateQuantity(item, key, -1),
          onPlus: () => _updateQuantity(item, key, 1),
          onMinusLong: () => _showBulkDialog(item, key, false),
          onPlusLong: () => _showBulkDialog(item, key, true),
          isInv: isInventory);
    }
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15),
        itemCount: sizes.length,
        itemBuilder: (ctx, i) {
          String key = sizes.keys.elementAt(i);
          int val = int.tryParse(sizes[key].toString()) ?? 0;
          return Container(
            decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadowTop,
                      offset: const Offset(-2, -2),
                      blurRadius: 4),
                  BoxShadow(
                      color: AppColors.shadowBottom,
                      offset: const Offset(2, 2),
                      blurRadius: 4)
                ]),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(key,
                  style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 5),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _bigBtn(Icons.remove, () => _updateQuantity(item, key, -1),
                    () => _showBulkDialog(item, key, false), isInventory,
                    small: true),
                Text("$val",
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                _bigBtn(Icons.add, () => _updateQuantity(item, key, 1),
                    () => _showBulkDialog(item, key, true), isInventory,
                    small: true)
              ])
            ]),
          );
        });
  }

  Widget _verticalStyleCard(
      {required String label,
      required int val,
      required VoidCallback onMinus,
      required VoidCallback onPlus,
      required VoidCallback onMinusLong,
      required VoidCallback onPlusLong,
      required bool isInv,
      IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadowTop,
                offset: const Offset(-3, -3),
                blurRadius: 6),
            BoxShadow(
                color: AppColors.shadowBottom,
                offset: const Offset(3, 3),
                blurRadius: 6)
          ]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey, size: 24),
            const SizedBox(width: 8)
          ],
          Text(label,
              style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 20))
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _bigBtn(Icons.remove, onMinus, onMinusLong, isInv),
          Text("$val",
              style: TextStyle(
                  color: AppColors.textMain,
                  fontSize: 30,
                  fontWeight: FontWeight.bold)),
          _bigBtn(Icons.add, onPlus, onPlusLong, isInv)
        ])
      ]),
    );
  }

  Widget _bigBtn(
      IconData icon, VoidCallback onTap, VoidCallback onLongPress, bool isInv,
      {bool small = false}) {
    double size = small ? 40 : 55;
    return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(50),
        child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadowBottom,
                      offset: const Offset(4, 4),
                      blurRadius: 6),
                  BoxShadow(
                      color: AppColors.shadowTop,
                      offset: const Offset(-4, -4),
                      blurRadius: 6)
                ]),
            child: Icon(icon,
                color: isInv ? Colors.purple : AppColors.accent,
                size: size * 0.5)));
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
                    borderRadius: BorderRadius.circular(24)),
                title: Text(title, style: TextStyle(color: AppColors.textMain)),
                content: Container(
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.shadowTop,
                              offset: const Offset(2, 2),
                              blurRadius: 3,
                              spreadRadius: -2),
                          BoxShadow(
                              color: AppColors.shadowBottom,
                              offset: const Offset(-2, -2),
                              blurRadius: 3,
                              spreadRadius: -2)
                        ]),
                    child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                            hintText: "Введіть число",
                            hintStyle: TextStyle(color: Colors.grey),
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 15)))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Відміна",
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      onPressed: () {
                        _vibrate(duration: 60);
                        int val = int.tryParse(qtyCtrl.text) ?? 0;
                        if (val > 0) {
                          int delta = isAdd ? val : -val;
                          _updateQuantity(item, sizeKey, delta);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text("ОК",
                          style: TextStyle(color: Colors.white)))
                ]));
  }

  Future<void> _deleteItem(int localId, int? serverId) async {
    _vibrate(duration: 50);
    bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.bg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text("Видалити?",
                    style: TextStyle(color: AppColors.textMain)),
                content: const Text("Цей запис буде переміщено в архів.",
                    style: TextStyle(color: Colors.grey)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Ні",
                          style: TextStyle(color: Colors.grey))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Так",
                          style: TextStyle(color: Colors.red)))
                ]));
    if (confirm) {
      _vibrate(duration: 100);
      final db = await DBService().localDb;
      await db.update('items', {'is_deleted': 1, 'is_unsynced': 1},
          where: 'local_id = ?', whereArgs: [localId]);
      await DBService()
          .logHistory("Товар ID $localId", "Видалено", "Переміщено в архів");
      _loadLocalData();
      DBService().syncWithCloud();
    }
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
                        const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.shadowTop,
                          blurRadius: 10,
                          offset: const Offset(0, -5))
                    ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),
                    Text("Швидкі дії",
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _quickActionTile(
                        icon: Icons.ac_unit,
                        title: isWinter ? "Прибрати із Зими" : "Додати в Зиму",
                        isActive: isWinter,
                        color: Colors.cyan,
                        onTap: () async {
                          _vibrate(duration: 20);
                          await DBService()
                              .toggleItemInList('winter', itemIdStr, !isWinter);
                          setModalState(() => isWinter = !isWinter);
                          _loadLocalData();
                        }),
                    _quickActionTile(
                        icon: Icons.wb_sunny,
                        title: isSummer ? "Прибрати з Літа" : "Додати в Літо",
                        isActive: isSummer,
                        color: Colors.orange,
                        onTap: () async {
                          _vibrate(duration: 20);
                          await DBService()
                              .toggleItemInList('summer', itemIdStr, !isSummer);
                          setModalState(() => isSummer = !isSummer);
                          _loadLocalData();
                        }),
                    _quickActionTile(
                        icon: Icons.handyman,
                        title: isInv ? "Прибрати з Видачі" : "Додати у Видачу",
                        isActive: isInv,
                        color: Colors.purple,
                        onTap: () async {
                          _vibrate(duration: 20);
                          await DBService()
                              .toggleItemInList('inventory', itemIdStr, !isInv);
                          setModalState(() => isInv = !isInv);
                          _loadLocalData();
                        }),
                    const SizedBox(height: 20),
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
        color: isActive ? color.withOpacity(0.1) : AppColors.bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isActive ? color : Colors.grey),
        title: Text(title,
            style: TextStyle(
                color: isActive ? color : Colors.grey,
                fontWeight: FontWeight.bold)),
        trailing: isActive
            ? Icon(Icons.check_circle, color: color)
            : const Icon(Icons.circle_outlined, color: Colors.grey),
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
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 4))
                    ]
                  : null),
          child: child);
  @override
  double get maxExtent => 70;
  @override
  double get minExtent => 70;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
