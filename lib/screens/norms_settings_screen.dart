import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../services/db_service.dart';

class NormsSettingsScreen extends StatefulWidget {
  const NormsSettingsScreen({super.key});

  @override
  State<NormsSettingsScreen> createState() => _NormsSettingsScreenState();
}

class _NormsSettingsScreenState extends State<NormsSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Унікальні імена товарів для кожного сезону
  List<String> _winterNames = [];
  List<String> _summerNames = [];

  // Збережені норми (Назва товару -> Кількість)
  Map<String, int> _winterNorms = {};
  Map<String, int> _summerNorms = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final allItems = await DBService().getAllItems();
    final wIds = await DBService().getCustomList('winter');
    final sIds = await DBService().getCustomList('summer');

    // Отримуємо унікальні назви товарів, які є у списках
    Set<String> wNames = {};
    Set<String> sNames = {};

    for (var item in allItems) {
      String id = item['id'].toString();
      String name = item['name']?.toString() ?? "Без назви";
      if (wIds.contains(id)) wNames.add(name);
      if (sIds.contains(id)) sNames.add(name);
    }

    // Завантажуємо збережені норми
    final prefs = await SharedPreferences.getInstance();
    final wNormsStr = prefs.getString('norms_winter') ?? '{}';
    final sNormsStr = prefs.getString('norms_summer') ?? '{}';

    Map<String, dynamic> rawW = jsonDecode(wNormsStr);
    Map<String, dynamic> rawS = jsonDecode(sNormsStr);

    setState(() {
      _winterNames = wNames.toList()..sort();
      _summerNames = sNames.toList()..sort();

      _winterNorms =
          rawW.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 1));
      _summerNorms =
          rawS.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 1));

      _isLoading = false;
    });
  }

  Future<void> _updateNorm(String seasonKey, String itemName, int delta) async {
    Vibration.vibrate(duration: 30);
    setState(() {
      if (seasonKey == 'winter') {
        int current = _winterNorms[itemName] ?? 1;
        int next = current + delta;
        if (next > 0) _winterNorms[itemName] = next;
      } else {
        int current = _summerNorms[itemName] ?? 1;
        int next = current + delta;
        if (next > 0) _summerNorms[itemName] = next;
      }
    });

    // Одразу зберігаємо
    final prefs = await SharedPreferences.getInstance();
    if (seasonKey == 'winter') {
      await prefs.setString('norms_winter', jsonEncode(_winterNorms));
    } else {
      await prefs.setString('norms_summer', jsonEncode(_summerNorms));
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF121212);
    const cardColor = Color(0xFF1E1E1E);
    const primaryColor = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("НОРМИ ВИДАЧІ (НА 1 ОСІБ)",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white)),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: "ЗИМА"), Tab(text: "ЛІТО")],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList('winter', _winterNames, _winterNorms, Colors.cyan),
                _buildList('summer', _summerNames, _summerNorms, Colors.orange),
              ],
            ),
    );
  }

  Widget _buildList(String seasonKey, List<String> names,
      Map<String, int> norms, Color themeColor) {
    if (names.isEmpty) {
      return const Center(
          child: Text("Додайте товари у цей сезон",
              style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: names.length,
      itemBuilder: (ctx, i) {
        String name = names[i];
        int qty = norms[name] ?? 1; // За замовчуванням норма 1

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: themeColor),
                    onPressed: () => _updateNorm(seasonKey, name, -1),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text("$qty",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: themeColor),
                    onPressed: () => _updateNorm(seasonKey, name, 1),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
