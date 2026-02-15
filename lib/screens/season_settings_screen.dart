import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/db_service.dart';
import 'norms_settings_screen.dart'; // 🔥 ІМПОРТ ЕКРАНУ НОРМ ВИДАЧІ

class SeasonSettingsScreen extends StatefulWidget {
  const SeasonSettingsScreen({super.key});

  @override
  State<SeasonSettingsScreen> createState() => _SeasonSettingsScreenState();
}

class _SeasonSettingsScreenState extends State<SeasonSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];

  Set<String> _winterList = {};
  Set<String> _summerList = {};
  Set<String> _invList = {};

  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _loadData();
  }

  Future<void> _loadData() async {
    final items = await DBService().getAllItems();

    final w = await DBService().getCustomList('winter');
    final s = await DBService().getCustomList('summer');
    final i = await DBService().getCustomList('inventory');

    if (mounted) {
      setState(() {
        _allItems = items;
        _filteredItems = items;
        _winterList = w.toSet();
        _summerList = s.toSet();
        _invList = i.toSet();
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      _searchQuery = query;
      _filteredItems = _allItems.where((item) {
        final name = item['name'].toString().toLowerCase();
        final wh = (item['warehouse'] ?? "").toString().toLowerCase();
        return name.contains(query.toLowerCase()) ||
            wh.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _toggleItem(
      String listType, String itemId, bool currentVal) async {
    bool newVal = !currentVal;

    setState(() {
      if (listType == 'winter') {
        newVal ? _winterList.add(itemId) : _winterList.remove(itemId);
      } else if (listType == 'summer') {
        newVal ? _summerList.add(itemId) : _summerList.remove(itemId);
      } else {
        newVal ? _invList.add(itemId) : _invList.remove(itemId);
      }
    });

    await DBService().toggleItemInList(listType, itemId, newVal);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF121212);
    const cardColor = Color(0xFF1E1E1E);
    const primaryColor = Color(0xFF00E676);
    const accentColor = Color(0xFF00B0FF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("НАЛАШТУВАННЯ СПИСКІВ",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white)),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        // 🔥 КНОПКА ПЕРЕХОДУ В НОРМИ ВИДАЧІ
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: primaryColor, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NormsSettingsScreen()),
              );
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.ac_unit), text: "ЗИМА"),
            Tab(icon: Icon(Icons.wb_sunny), text: "ЛІТО"),
            Tab(icon: Icon(Icons.handyman), text: "ВИДАЧА"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: TextField(
                onChanged: _filterItems,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Пошук...",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, color: accentColor),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList("winter", _winterList, const Color(0xFF00B0FF)),
                _buildList("summer", _summerList, const Color(0xFFFFA000)),
                _buildList("inventory", _invList, const Color(0xFFE040FB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(String listType, Set<String> activeSet, Color themeColor) {
    if (_filteredItems.isEmpty) {
      return Center(
          child:
              Text("Немає даних", style: TextStyle(color: Colors.grey[700])));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filteredItems.length,
      itemBuilder: (ctx, i) {
        final item = _filteredItems[i];

        final String itemId = item['id'].toString();
        final name = item['name'] ?? "Без назви";
        final warehouse =
            (item['warehouse'] ?? "Не вказано").toString().toUpperCase();
        final category = item['category'] ?? "";

        final isChecked = activeSet.contains(itemId);

        Color whColor = Colors.grey;
        if (warehouse.contains("ООС")) whColor = const Color(0xFF00E676);
        if (warehouse.contains("ППД")) whColor = const Color(0xFF2979FF);

        return GestureDetector(
          onTap: () => _toggleItem(listType, itemId, isChecked),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: isChecked
                  ? Border.all(color: themeColor, width: 2)
                  : Border.all(color: Colors.white10, width: 1),
              boxShadow: isChecked
                  ? [
                      BoxShadow(
                          color: themeColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : [
                      const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isChecked ? themeColor : Colors.transparent,
                    border: Border.all(
                        color: isChecked ? themeColor : Colors.grey[700]!,
                        width: 2),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: isChecked
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: whColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: whColor.withOpacity(0.5)),
                            ),
                            child: Text(warehouse,
                                style: TextStyle(
                                    color: whColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          if (category.isNotEmpty)
                            Text(category,
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
