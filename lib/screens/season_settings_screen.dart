import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/tactical_ui.dart';
import '../services/db_service.dart';
import 'norms_settings_screen.dart';

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
    final bgColor = AppColors.bg;
    final primaryColor = AppColors.accent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: TacAppBar(
        title: 'Списки',
        code: 'Списки',
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: primaryColor, size: 24),
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
          unselectedLabelColor: AppColors.muted,
          indicatorColor: primaryColor,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.ac_unit, size: 18), text: "Зима"),
            Tab(icon: Icon(Icons.wb_sunny, size: 18), text: "Літо"),
            Tab(icon: Icon(Icons.handyman, size: 18), text: "Видача"),
          ],
        ),
      ),
      body: TacBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: _filterItems,
                style: TextStyle(color: AppColors.textMain, fontSize: 15),
                decoration: TacField.of('Пошук…', icon: Icons.search),
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

        return TacCard(
          margin: const EdgeInsets.only(bottom: 8),
          accent: isChecked ? themeColor : AppColors.border,
          onTap: () => _toggleItem(listType, itemId, isChecked),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isChecked ? themeColor : Colors.transparent,
                  border: Border.all(
                      color: isChecked ? themeColor : AppColors.muted, width: 1.4),
                ),
                child: isChecked
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 15,
                            fontWeight: isChecked
                                ? FontWeight.w900
                                : FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: whColor.withOpacity(0.16),
                            border: Border.all(color: whColor.withOpacity(0.5)),
                          ),
                          child: Text(warehouse,
                              style: TextStyle(
                                  color: whColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8)),
                        ),
                        const SizedBox(width: 8),
                        if (category.isNotEmpty)
                          Text(category,
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
