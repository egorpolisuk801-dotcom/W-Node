import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/user_config.dart';
import '../services/db_service.dart';

import 'add_universal_screen.dart';
import 'settings_screen.dart';
import 'logs_screen.dart';

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
  String _activeFilter = "Все";
  int? _expandedItemId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadLocalData();
    _syncData();
  }

  Future<void> _loadLocalData() async {
    try {
      final data = await DBService().getAllItems();
      if (mounted) {
        setState(() {
          _items = data;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading local data: $e");
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
      print("Sync error: $e");
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _deleteItem(int localId, int? serverId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Видалити?", style: TextStyle(color: AppColors.textMain)),
        content: Text("Цей запис буде переміщено в архів (видалено).",
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Ні", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text("Так", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm) {
      final db = await DBService().localDb;
      await db.update('items', {'is_deleted': 1, 'is_unsynced': 1},
          where: 'local_id = ?', whereArgs: [localId]);

      _loadLocalData();
      DBService().syncWithCloud();
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = _items.where((item) {
        final name = (item['name'] ?? "").toString().toLowerCase();
        final cat = (item['category'] ?? "").toString().toLowerCase();
        final wh = (item['warehouse'] ?? "").toString();
        // Проверяем и type, и item_type
        final type =
            (item['item_type'] ?? item['type'] ?? "").toString().toLowerCase();

        final search = _searchQuery.toLowerCase();
        bool matchSearch = name.contains(search) ||
            cat.contains(search) ||
            type.contains(search);

        bool matchWh = true;
        final config = UserConfig();
        if (_activeFilter == "Склад 1") matchWh = (wh == config.wh1Name);
        if (_activeFilter == "Склад 2") matchWh = (wh == config.wh2Name);

        return matchSearch && matchWh;
      }).toList();
    });
  }

  Future<void> _updateQuantity(
      Map<String, dynamic> item, String? sizeKey, int delta) async {
    Map<String, dynamic> newSizes = Map.from(item['size_data'] ?? {});
    int currentTotal = int.tryParse(item['total'].toString()) ?? 0;
    int newTotal = currentTotal;

    if (sizeKey != null) {
      int cur = int.tryParse(newSizes[sizeKey].toString()) ?? 0;
      int next = cur + delta;
      if (next < 0) return;
      newSizes[sizeKey] = next;

      newTotal = 0;
      newSizes.forEach((k, v) => newTotal += int.tryParse(v.toString()) ?? 0);
    } else {
      newTotal += delta;
      if (newTotal < 0) return;
    }

    setState(() {
      item['size_data'] = newSizes;
      item['total'] = newTotal;
    });

    try {
      await DBService().updateItemSizes(
        item['id'],
        item['name'],
        item['category'],
        newSizes,
        newTotal,
      );
    } catch (e) {
      _loadLocalData();
    }
  }

  void _showBulkDialog(Map<String, dynamic> item, String? sizeKey, bool isAdd) {
    TextEditingController qtyCtrl = TextEditingController();
    String title = isAdd ? "Додати кількість" : "Відняти кількість";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    spreadRadius: -2),
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Відміна", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              int val = int.tryParse(qtyCtrl.text) ?? 0;
              if (val > 0) {
                int delta = isAdd ? val : -val;
                _updateQuantity(item, sizeKey, delta);
              }
              Navigator.pop(ctx);
            },
            child: const Text("ОК", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _syncData,
          color: AppColors.accent,
          backgroundColor: AppColors.bg,
          notificationPredicate: (notification) {
            return notification.depth == 0;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyFilterDelegate(
                  child: _buildFilterRow(),
                ),
              ),
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
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 5),
                      Text("Потягніть вниз ⬇️ для оновлення",
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _itemCard(_filteredItems[i]),
                      childCount: _filteredItems.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
        onPressed: () async {
          final res = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddUniversalScreen()));
          if (res == true) {
            _loadLocalData();
          }
        },
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
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowBottom,
            offset: const Offset(0, 5),
            blurRadius: 15,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                _iconBtn(
                    Icons.history,
                    AppColors.accentBlue,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LogsScreen()))),
                const SizedBox(width: 15),
                _iconBtn(Icons.settings, AppColors.textMain, () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()));
                  _loadLocalData();
                }),
              ])
            ],
          ),
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
                      blurRadius: 6),
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
        ],
      ),
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
          _chip("Склад 1", config.wh1Name),
          const SizedBox(width: 12),
          _chip("Склад 2", config.wh2Name)
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color col, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
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
                  blurRadius: 5),
            ]),
        child: Icon(icon, color: col, size: 24),
      ),
    );
  }

  Widget _chip(String key, [String? label]) {
    bool active = _activeFilter == key;
    return GestureDetector(
      onTap: () {
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
                        spreadRadius: -2),
                    BoxShadow(
                        color: AppColors.accent.withOpacity(0.1),
                        blurRadius: 6,
                        spreadRadius: 1)
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
        child: Text(label ?? key,
            style: TextStyle(
                color: active ? AppColors.accent : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    bool expanded = _expandedItemId == item['id'];
    int total = int.tryParse(item['total'].toString()) ?? 0;
    String name = item['name'] ?? "No Name";
    String cat = item['category'] ?? "";
    String wh = item['warehouse'] ?? "";

    // 🔥 СУПЕР-НАДЕЖНАЯ ПРОВЕРКА: "Это Инвентарь?"
    // Проверяем сразу 3 поля, чтобы точно не ошибиться
    var rawIsInv = item['is_inventory'];
    bool flagCheck =
        (rawIsInv == 1) || (rawIsInv == true) || (rawIsInv.toString() == "1");

    String typeStr = (item['item_type'] ?? item['type'] ?? "").toString();
    bool typeCheck = typeStr == "Інвентар";

    // Если хоть что-то говорит "Да", значит это инвентарь
    bool isInventory = flagCheck || typeCheck;

    String rawDate = item['date_added']?.toString() ?? "";
    String date = (rawDate.length >= 10) ? rawDate.substring(0, 10) : rawDate;

    // 🎨 ЦВЕТА И ИКОНКИ
    IconData typeIcon = isInventory ? Icons.handyman : Icons.checkroom;
    Color typeColor = isInventory ? Colors.purpleAccent : AppColors.accentBlue;
    String subTitle = isInventory ? "Інвентар • $wh" : "Кат: $cat • $wh";

    return Dismissible(
      key: ValueKey(item['local_id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (dir) async {
        await _deleteItem(item['local_id'], item['server_id']);
        return false;
      },
      child: GestureDetector(
        onTap: () =>
            setState(() => _expandedItemId = expanded ? null : item['id']),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: TextStyle(
                              color: AppColors.textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text(subTitle,
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold))
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
                  const Icon(Icons.calendar_today,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(date,
                      style: const TextStyle(color: Colors.grey, fontSize: 12))
                ])
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String txt, Color col) {
    if (txt.isEmpty) return const SizedBox.shrink();
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: col.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Text(txt,
            style: TextStyle(
                color: col, fontSize: 12, fontWeight: FontWeight.bold)));
  }

  Widget _controlPanel(Map<String, dynamic> item, int total, bool isInventory) {
    Map<String, dynamic> sizes = item['size_data'] ?? {};

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

      String label = key;
      String subLabel = "";
      String normalizedKey = key.replaceAll("/", "-");

      if (normalizedKey.contains("-")) {
        var parts = normalizedKey.split("-");
        label = parts[0];
        if (parts.length > 1) subLabel = "Зріст ${parts[1]}";
      }

      return _verticalStyleCard(
        label: label,
        subLabel: subLabel,
        val: val,
        onMinus: () => _updateQuantity(item, key, -1),
        onPlus: () => _updateQuantity(item, key, 1),
        onMinusLong: () => _showBulkDialog(item, key, false),
        onPlusLong: () => _showBulkDialog(item, key, true),
        isInv: isInventory,
      );
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

        String label = key;
        String subLabel = "";
        String normalizedKey = key.replaceAll("/", "-");

        if (normalizedKey.contains("-")) {
          var parts = normalizedKey.split("-");
          label = parts[0];
          if (parts.length > 1) subLabel = "Зріст ${parts[1]}";
        }

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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (subLabel.isNotEmpty)
              Column(children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(subLabel,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ])
            else
              Text(label,
                  style: TextStyle(
                      color: Colors.grey[600],
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
                  small: true),
            ])
          ]),
        );
      },
    );
  }

  Widget _verticalStyleCard({
    required String label,
    String subLabel = "",
    required int val,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required VoidCallback onMinusLong,
    required VoidCallback onPlusLong,
    required bool isInv,
    IconData? icon,
  }) {
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.grey, size: 24),
                const SizedBox(width: 8)
              ],
              if (subLabel.isNotEmpty)
                Column(children: [
                  Text(label,
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                  Text(subLabel,
                      style: TextStyle(
                          color: isInv ? Colors.purple : AppColors.accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ])
              else
                Text(label,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _bigBtn(Icons.remove, onMinus, onMinusLong, isInv),
              Text("$val",
                  style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 30,
                      fontWeight: FontWeight.bold)),
              _bigBtn(Icons.add, onPlus, onPlusLong, isInv),
            ],
          )
        ],
      ),
    );
  }

  Widget _bigBtn(
      IconData icon, VoidCallback onTap, VoidCallback onLongPress, bool isInv,
      {bool small = false}) {
    double size = small ? 40 : 55;
    Color activeColor = isInv ? Colors.purple : AppColors.accent;
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
        child: Icon(icon, color: activeColor, size: size * 0.5),
      ),
    );
  }
}

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyFilterDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
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
      child: child,
    );
  }

  @override
  double get maxExtent => 70;

  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
