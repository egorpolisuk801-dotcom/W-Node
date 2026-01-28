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
  bool _isConnected = false;
  String _searchQuery = "";
  String _activeFilter = "Все";
  int? _expandedItemId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await DBService().getAllItems();
      setState(() {
        _items = data;
        _isConnected = true;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = _items.where((item) {
        final name = (item['name'] ?? "").toString().toLowerCase();
        final cat = (item['category'] ?? "").toString().toLowerCase();
        final wh = (item['warehouse'] ?? "").toString();
        final type = (item['type'] ?? "").toString().toLowerCase();

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
          newSizes,
          newTotal,
          sizeKey != null
              ? "$sizeKey (${delta > 0 ? '+' : ''}$delta)"
              : "Зміна кількості");
    } catch (e) {
      _loadData();
    }
  }

  void _showBulkDialog(Map<String, dynamic> item, String? sizeKey, bool isAdd) {
    TextEditingController qtyCtrl = TextEditingController();
    String title = isAdd ? "Додати кількість" : "Відняти кількість";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: TextStyle(color: AppColors.textMain)),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(
              color: AppColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "Введіть число",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.accentBlue)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Відміна", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
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
    final config = UserConfig();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.bg,
        title: Row(children: [
          Text("W-Node",
              style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 22)),
          const SizedBox(width: 8),
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: _isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (_isConnected)
                      BoxShadow(
                          color: Colors.green.withOpacity(0.5), blurRadius: 5)
                  ]))
        ]),
        actions: [
          IconButton(
              icon: Icon(Icons.history, color: AppColors.accentBlue),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LogsScreen()))),
          IconButton(
              icon: Icon(Icons.settings, color: AppColors.textMain),
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
                _loadData();
              }),
        ],
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadowTop,
                        offset: const Offset(-2, -2),
                        blurRadius: 5),
                    BoxShadow(
                        color: AppColors.shadowBottom,
                        offset: const Offset(2, 2),
                        blurRadius: 5)
                  ]),
              child: TextField(
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilters();
                },
                style: TextStyle(color: AppColors.textMain),
                decoration: InputDecoration(
                    hintText: "Пошук...",
                    prefixIcon: Icon(Icons.search, color: AppColors.accentBlue),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ),
          ),
          // Фильтры
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(children: [
              _chip("Все"),
              const SizedBox(width: 10),
              _chip("Склад 1", config.wh1Name),
              const SizedBox(width: 10),
              _chip("Склад 2", config.wh2Name)
            ]),
          ),
          const SizedBox(height: 10),
          // Список
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.accent,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                      itemCount: _filteredItems.length,
                      itemBuilder: (ctx, i) => _itemCard(_filteredItems[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () async {
          final res = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddUniversalScreen()));
          if (res == true) _loadData();
        },
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3))
                  ]
                : [
                    BoxShadow(
                        color: AppColors.shadowTop,
                        offset: const Offset(-2, -2),
                        blurRadius: 4),
                    BoxShadow(
                        color: AppColors.shadowBottom,
                        offset: const Offset(2, 2),
                        blurRadius: 4)
                  ]),
        child: Text(label ?? key,
            style: TextStyle(
                color: active ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    bool expanded = _expandedItemId == item['id'];
    int total = int.tryParse(item['total'].toString()) ?? 0;
    String name = item['name'] ?? "No Name";
    String cat = item['category'] ?? "";
    String wh = item['warehouse'] ?? "";
    bool isInventory = (item['type'] == "Інвентар") ||
        (item['is_inventory'] == true) ||
        (item['is_inventory'] == 1);

    String rawDate = item['date']?.toString() ?? "";
    String date = (rawDate.length >= 10) ? rawDate.substring(0, 10) : rawDate;

    IconData typeIcon =
        isInventory ? Icons.build_circle_outlined : Icons.checkroom;
    Color typeColor = isInventory ? Colors.purple : AppColors.accentBlue;

    return GestureDetector(
      onTap: () =>
          setState(() => _expandedItemId = expanded ? null : item['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadowBottom,
                  offset: const Offset(5, 5),
                  blurRadius: 10),
              BoxShadow(
                  color: AppColors.shadowTop,
                  offset: const Offset(-5, -5),
                  blurRadius: 10)
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(typeIcon, color: typeColor, size: 20),
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
                      if (cat.isNotEmpty && cat != "Інвентар")
                        _badge(cat, typeColor),
                      if (cat.isNotEmpty && cat != "Інвентар")
                        const SizedBox(width: 8),
                      _badge(wh, Colors.orange[800]!)
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
                            offset: const Offset(-2, -2),
                            blurRadius: 4),
                        BoxShadow(
                            color: AppColors.shadowBottom,
                            offset: const Offset(2, 2),
                            blurRadius: 4)
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
                Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(date, style: TextStyle(color: Colors.grey, fontSize: 12))
              ])
            ]
          ],
        ),
      ),
    );
  }

  Widget _badge(String txt, Color col) {
    if (txt.isEmpty) return const SizedBox.shrink();
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: col.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Text(txt,
            style: TextStyle(
                color: col, fontSize: 13, fontWeight: FontWeight.w600)));
  }

  // === ЛОГИКА ОТОБРАЖЕНИЯ ПАНЕЛИ ===
  Widget _controlPanel(Map<String, dynamic> item, int total, bool isInventory) {
    Map<String, dynamic> sizes = item['size_data'] ?? {};

    // 1. ПУСТОЙ СПИСОК РАЗМЕРОВ -> Широкая панель
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

    // 2. ОДИН РАЗМЕР -> Широкая панель
    if (sizes.length == 1) {
      String key = sizes.keys.first;
      int val = int.tryParse(sizes[key].toString()) ?? 0;

      String label = key;
      String subLabel = "";
      if (key.contains("-")) {
        var parts = key.split("-");
        label = parts[0];
        if (parts.length > 1) subLabel = "Рост ${parts[1]}";
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

    // 3. МНОГО РАЗМЕРОВ -> СЕТКА
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
        if (key.contains("-")) {
          var parts = key.split("-");
          label = parts[0];
          if (parts.length > 1) subLabel = "Рост ${parts[1]}";
        }

        return Container(
          decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(15),
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
                    style: TextStyle(
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

  // --- ШИРОКАЯ КАРТОЧКА ---
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
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(15),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.grey, size: 20),
                SizedBox(width: 8)
              ],
              if (subLabel.isNotEmpty)
                Column(children: [
                  Text(label,
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
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
                        fontSize: 18)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _bigBtn(Icons.remove, onMinus, onMinusLong, isInv),
              Text("$val",
                  style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 24,
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
    double size = small ? 35 : 50;
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
                  offset: const Offset(3, 3),
                  blurRadius: 5),
              BoxShadow(
                  color: AppColors.shadowTop,
                  offset: const Offset(-3, -3),
                  blurRadius: 5)
            ]),
        child: Icon(icon, color: activeColor, size: size * 0.5),
      ),
    );
  }
}
