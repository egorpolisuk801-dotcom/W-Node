import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:convert';
import '../core/app_colors.dart';
import '../services/db_service.dart';
import '../core/user_config.dart';
import '../core/notification_helper.dart';
import '../core/smart_icons.dart'; // 🔥 ІМПОРТУЄМО НАШ НОВИЙ МОЗГ

class AddUniversalScreen extends StatefulWidget {
  const AddUniversalScreen({super.key});

  @override
  State<AddUniversalScreen> createState() => _AddUniversalScreenState();
}

class _AddUniversalScreenState extends State<AddUniversalScreen> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _simpleQtyCtrl = TextEditingController();

  // 🔥 Змінні для живої іконки
  IconData _currentSmartIcon = Icons.inventory_2_rounded;
  Color _currentIconColor = Colors.blueAccent;

  // --- ДАННЫЕ СЕТОК ---
  final List<String> _digitsRows = ["1", "2", "3", "4", "5", "6", "7", "8"];
  final List<String> _digitsCols = [
    "40",
    "42",
    "44",
    "46",
    "48",
    "50",
    "52",
    "54",
    "56",
    "58",
    "60",
    "62",
    "64",
    "66",
    "68",
    "70"
  ];
  final List<String> _lettersRows = ["XS", "S", "M", "R", "L", "XL"];
  final List<String> _lettersCols = [
    "XS",
    "S",
    "M",
    "L",
    "XL",
    "XXL",
    "3XL",
    "4XL"
  ];
  final List<String> _shoesCols = List.generate(18, (i) => "${35 + i}");
  final List<String> _hatsCols = [
    "54",
    "55",
    "56",
    "57",
    "58",
    "59",
    "60",
    "61",
    "62",
    "63"
  ];
  final List<String> _hatsRangeCols = [
    "54-55",
    "56-57",
    "58-59",
    "60-61",
    "62-63"
  ];
  final List<String> _hatsWideCols = ["54-56", "58-60", "62-64"];
  final List<String> _glovesCols = ["1", "2", "3", "4"];
  final List<String> _glovesSLCols = ["S", "M", "L", "XL"];
  final List<String> _linenCols = List.generate(15, (i) => "${42 + (i * 2)}");

  // --- СПИСОК ТИПОВ ---
  final List<String> _clothesTypes = [
    "Цифри",
    "Букви",
    "Взуття",
    "Головні убори",
    "ГУ (Діапазон)",
    "ГУ (Широкі)",
    "Рукавички",
    "Рукавички (S-XL)",
    "Білизна",
    "Просте"
  ];
  final List<String> _invTypes = ["Букви", "Цифри", "Взуття", "ГУ (Діапазон)"];

  bool _isInventory = false;

  // 🔥 НОВІ ЗМІННІ ДЛЯ СКЛАДІВ 🔥
  List<String> _warehouses = [];
  String _selectedWh = "ООС";

  String _currentSubType = "Цифри";
  String _selectedRow = "1";
  String _selectedCategory = "I";

  bool _invUseGrid = true;
  Map<String, int> _quantities = {};
  bool _isSaving = false;
  int _lastTapTime = 0;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();

    // 🔥 Слухаємо кожну літеру, яку вводить користувач
    _nameCtrl.addListener(_updateSmartIcon);
  }

  // 🔥 МЕТОД ДЛЯ ЗАВАНТАЖЕННЯ СПИСКУ СКЛАДІВ З НАЛАШТУВАНЬ 🔥
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
    _selectedWh = _warehouses.first; // За замовчуванням вибираємо перший склад
  }

  @override
  void dispose() {
    // 🔥 Обов'язково чистимо пам'ять при виході
    _nameCtrl.removeListener(_updateSmartIcon);
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _simpleQtyCtrl.dispose();
    super.dispose();
  }

  // 🔥 Метод для оновлення іконки на льоту
  void _updateSmartIcon() {
    setState(() {
      _currentSmartIcon = SmartIcons.getIconForName(_nameCtrl.text);
      _currentIconColor = SmartIcons.getColorForIcon(_currentSmartIcon);
    });
  }

  bool _shouldShowType(String type) {
    final cfg = UserConfig();
    if (_isInventory) return true;
    switch (type) {
      case "Цифри":
        return cfg.itemShowDigits;
      case "Букви":
        return cfg.itemShowLetters;
      case "Взуття":
        return cfg.itemShowShoes;
      case "Головні убори":
        return cfg.itemShowHats;
      case "ГУ (Діапазон)":
        return cfg.itemShowHatsR;
      case "ГУ (Широкі)":
        return cfg.itemShowHatsW;
      case "Рукавички":
        return cfg.itemShowGloves;
      case "Рукавички (S-XL)":
        return cfg.itemShowGlovesSL;
      case "Білизна":
        return cfg.itemShowLinen;
      default:
        return true;
    }
  }

  void _setMode(bool inventory) {
    setState(() {
      _isInventory = inventory;
      _quantities.clear();
      _simpleQtyCtrl.clear();
      _currentSubType = "Цифри";
      _selectedRow = "1";
    });
  }

  void _setSubType(String type) {
    setState(() {
      _currentSubType = type;
      _quantities.clear();
      if (type == "Цифри")
        _selectedRow = "1";
      else if (type == "Букви")
        _selectedRow = "XS";
      else
        _selectedRow = "";
    });
  }

  int get _totalCount {
    if ((_isInventory && !_invUseGrid) ||
        (!_isInventory && _currentSubType == "Просте")) {
      return int.tryParse(_simpleQtyCtrl.text) ?? 0;
    }
    int total = 0;
    _quantities.forEach((_, v) => total += v);
    return total;
  }

  void _showBulkInputDialog(String key, int currentVal) {
    TextEditingController qtyCtrl = TextEditingController(
        text: currentVal > 0 ? currentVal.toString() : "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("$key : Кількість",
            style: TextStyle(color: AppColors.textMain)),
        content: _neuTextField(qtyCtrl, "0", isNum: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Відміна", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              int? val = int.tryParse(qtyCtrl.text);
              if (val != null) setState(() => _quantities[key] = val);
              Navigator.pop(ctx);
            },
            child: const Text("ОК", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _save() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTime < 2000) return;
    _lastTapTime = now;
    if (_isSaving) return;

    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Введіть назву!")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      int total = _totalCount;
      Map<String, int> finalData = {};
      bool isSimple = (_isInventory && !_invUseGrid) ||
          (!_isInventory && _currentSubType == "Просте");

      if (!isSimple) {
        _quantities.forEach((k, v) {
          if (v > 0) finalData[k] = v;
        });
      }

      String uid =
          "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}";
      Map<String, dynamic> item = {
        'uid': uid,
        'name': _nameCtrl.text,
        'location': _locationCtrl.text,
        'category': _selectedCategory,
        'warehouse': _selectedWh,
        'type': _isInventory ? "Інвентар" : _currentSubType,
        'total': total,
        'size_data': finalData,
        'is_inventory': _isInventory ? 1 : 0,
      };

      await DBService().saveItem(item);

      if (mounted) {
        Navigator.pop(context, true);
        NotificationHelper.showSuccess(context, "Створено: ${item['name']}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Помилка: $e")));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isInventory ? "Додати Інвентар" : "Додати Одяг",
            style: TextStyle(
                color: AppColors.textMain, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textMain),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: _neuDeco(pressed: true),
              child: Row(children: [
                Expanded(
                    child: _tabBtn(
                        "Одяг 👕", !_isInventory, () => _setMode(false))),
                Expanded(
                    child: _tabBtn(
                        "Інвентар 🛠", _isInventory, () => _setMode(true))),
              ]),
            ),
            const SizedBox(height: 20),
            _sectionHeader("Інформація"),

            // 🔥 ВИКЛИКАЄМО ТЕКСТОВЕ ПОЛЕ З ІКОНКОЮ
            _neuTextField(_nameCtrl, "Назва (напр. Футболка)",
                icon: _currentSmartIcon, iconColor: _currentIconColor),
            const SizedBox(height: 10),

            _neuTextField(_locationCtrl, "Місце (напр. Полиця 2)"),
            const SizedBox(height: 10),

            // 🔥 ОНОВЛЕНИЙ СЕЛЕКТОР СКЛАДІВ 🔥
            _whSelector(),

            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.all(4),
                  decoration: _neuDeco(pressed: true),
                  child: Row(children: [
                    Expanded(
                        child: _neuSelectableBtn("I", _selectedCategory == "I",
                            () => setState(() => _selectedCategory = "I"))),
                    const SizedBox(width: 5),
                    Expanded(
                        child: _neuSelectableBtn(
                            "II",
                            _selectedCategory == "II",
                            () => setState(() => _selectedCategory = "II"))),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: _totalCounterWidget()),
            ]),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader("Розмірна сітка"),
                if (_isInventory)
                  Row(children: [
                    Text(_invUseGrid ? "Сітка" : "Просте",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 12)),
                    Switch(
                        value: _invUseGrid,
                        activeColor: AppColors.accent,
                        onChanged: (v) => setState(() => _invUseGrid = v)),
                  ]),
              ],
            ),
            if (!_isInventory || (_isInventory && _invUseGrid))
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                    children:
                        (_isInventory ? _invTypes : _clothesTypes).map((t) {
                  if (!_shouldShowType(t)) return const SizedBox();
                  return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _typeChip(t));
                }).toList()),
              ),
            const SizedBox(height: 5),
            if ((_isInventory && !_invUseGrid) ||
                (!_isInventory && _currentSubType == "Просте"))
              _neuTextField(_simpleQtyCtrl, "Введіть кількість (шт)",
                  isNum: true)
            else
              _buildUniversalGridBody(),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _isSaving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 55,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _isSaving ? Colors.grey : AppColors.accent,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: _isSaving
                        ? null
                        : [
                            BoxShadow(
                                color: AppColors.accent.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ]),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ЗБЕРЕГТИ",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, left: 5),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.8)),
    );
  }

  Widget _buildUniversalGridBody() {
    switch (_currentSubType) {
      case "Цифри":
        return _build2DGrid(_digitsRows, _digitsCols);
      case "Букви":
        return _build2DGrid(_lettersRows, _lettersCols);
      case "Взуття":
        return _build1DGrid(_shoesCols);
      case "Головні убори":
        return _build1DGrid(_hatsCols);
      case "ГУ (Діапазон)":
        return _build1DGrid(_hatsRangeCols);
      case "ГУ (Широкі)":
        return _build1DGrid(_hatsWideCols);
      case "Рукавички":
        return _build1DGrid(_glovesCols);
      case "Рукавички (S-XL)":
        return _build1DGrid(_glovesSLCols);
      case "Білизна":
        return _build1DGrid(_linenCols);
      default:
        return const SizedBox();
    }
  }

  Widget _build1DGrid(List<String> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
      child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: items.map((val) {
            int qty = _quantities[val] ?? 0;
            return _gridBtn(val, qty, () {
              HapticFeedback.lightImpact();
              setState(() => _quantities[val] = qty + 1);
            }, () => _showBulkInputDialog(val, qty));
          }).toList()),
    );
  }

  Widget _build2DGrid(List<String> rows, List<String> cols) {
    return Column(children: [
      Text("ЗРІСТ:", style: TextStyle(color: Colors.grey, fontSize: 11)),
      const SizedBox(height: 5),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
          child: Row(
              children: rows.map((r) {
            bool active = _selectedRow == r;
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                    onTap: () => setState(() => _selectedRow = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 45,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: active
                              ? Border.all(
                                  color: _isInventory
                                      ? Colors.purple
                                      : AppColors.accentBlue,
                                  width: 2)
                              : null,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                      color: (_isInventory
                                              ? Colors.purple
                                              : AppColors.accentBlue)
                                          .withOpacity(0.3),
                                      blurRadius: 6)
                                ]
                              : [
                                  BoxShadow(
                                      color: AppColors.shadowTop,
                                      offset: Offset(-2, -2),
                                      blurRadius: 2),
                                  BoxShadow(
                                      color: AppColors.shadowBottom,
                                      offset: Offset(2, 2),
                                      blurRadius: 2)
                                ]),
                      child: Text(r,
                          style: TextStyle(
                              color: active
                                  ? (_isInventory
                                      ? Colors.purple
                                      : AppColors.accentBlue)
                                  : AppColors.textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    )));
          }).toList())),
      const SizedBox(height: 10),
      Text("Розміри ($_selectedRow):",
          style: const TextStyle(color: Colors.grey, fontSize: 11)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(5),
        child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: cols.map((c) {
              String key = "$c-$_selectedRow";
              int qty = _quantities[key] ?? 0;
              return _gridBtn(c, qty, () {
                if (_selectedRow.isEmpty) return;
                HapticFeedback.lightImpact();
                setState(() => _quantities[key] = qty + 1);
              }, () {
                if (_selectedRow.isNotEmpty) _showBulkInputDialog(key, qty);
              });
            }).toList()),
      )
    ]);
  }

  Widget _gridBtn(
      String label, int qty, VoidCallback onTap, VoidCallback onLong) {
    bool active = qty > 0;
    Color actColor = _isInventory ? Colors.purple : AppColors.accentBlue;
    double fontSize = label.length > 3 ? 11 : 13;

    return GestureDetector(
        onTap: onTap,
        onLongPress: onLong,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 45,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: active ? Border.all(color: actColor, width: 2) : null,
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: actColor.withOpacity(0.3), blurRadius: 6)
                      ]
                    : [
                        BoxShadow(
                            color: AppColors.shadowTop,
                            offset: const Offset(-2, -2),
                            blurRadius: 3),
                        BoxShadow(
                            color: AppColors.shadowBottom,
                            offset: const Offset(2, 2),
                            blurRadius: 3)
                      ]),
            child: Stack(children: [
              Center(
                  child: Text(label,
                      style: TextStyle(
                          color: active ? actColor : AppColors.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize))),
              if (active)
                Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            color: actColor, shape: BoxShape.circle),
                        child: Text("$qty",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)))),
            ])));
  }

  Widget _typeChip(String t) {
    bool act = _currentSubType == t;
    return GestureDetector(
      onTap: () => _setSubType(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(16),
            border: act
                ? Border.all(
                    color: _isInventory ? Colors.purple : AppColors.accentBlue,
                    width: 1.5)
                : null,
            boxShadow: act
                ? [
                    BoxShadow(
                        color: (_isInventory
                                ? Colors.purple
                                : AppColors.accentBlue)
                            .withOpacity(0.2),
                        blurRadius: 6)
                  ]
                : [
                    BoxShadow(
                        color: AppColors.shadowTop,
                        offset: Offset(-2, -2),
                        blurRadius: 3),
                    BoxShadow(
                        color: AppColors.shadowBottom,
                        offset: Offset(2, 2),
                        blurRadius: 3)
                  ]),
        child: Text(t,
            style: TextStyle(
                color: act
                    ? (_isInventory ? Colors.purple : AppColors.accentBlue)
                    : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }

  Widget _tabBtn(String txt, bool active, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: active ? AppColors.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: AppColors.shadowTop,
                            offset: Offset(-2, -2),
                            blurRadius: 4),
                        BoxShadow(
                            color: AppColors.shadowBottom,
                            offset: Offset(2, 2),
                            blurRadius: 4)
                      ]
                    : null),
            alignment: Alignment.center,
            child: Text(txt,
                style: TextStyle(
                    color: active ? AppColors.textMain : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14))));
  }

  // 🔥 ОНОВЛЕНИЙ ВІДЖЕТ ДЛЯ ВИБОРУ СКЛАДУ (Dropdown) 🔥
  Widget _whSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowTop,
              offset: const Offset(2, 2),
              blurRadius: 2,
              spreadRadius: -1),
          BoxShadow(
              color: AppColors.shadowBottom,
              offset: const Offset(-2, -2),
              blurRadius: 2,
              spreadRadius: -1)
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedWh,
          icon: Icon(Icons.arrow_drop_down_rounded,
              color: AppColors.accentBlue, size: 30),
          dropdownColor: AppColors.bg,
          isExpanded: true,
          style: TextStyle(
              color: AppColors.textMain,
              fontSize: 15,
              fontWeight: FontWeight.bold),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedWh = newValue;
              });
            }
          },
          items: _warehouses.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text("Склад: $value"),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _neuSelectableBtn(String text, bool active, VoidCallback onTap) {
    Color actColor = _isInventory ? Colors.purple : AppColors.accentBlue;
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: active ? AppColors.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: AppColors.shadowTop,
                            offset: const Offset(-2, -2),
                            blurRadius: 4),
                        BoxShadow(
                            color: AppColors.shadowBottom,
                            offset: const Offset(2, 2),
                            blurRadius: 4)
                      ]
                    : null),
            child: Text(text,
                style: TextStyle(
                    color: active ? actColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12))));
  }

  Widget _totalCounterWidget() {
    return Container(
        height: 60,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(16),
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
          const Text("ВСЬОГО",
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          Text("$_totalCount",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain))
        ]));
  }

  // 🔥 ПРОКАЧАНИЙ ВІДЖЕТ: Тепер приймає іконку
  Widget _neuTextField(TextEditingController ctrl, String hint,
      {bool isNum = false, IconData? icon, Color? iconColor}) {
    return Container(
        decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadowTop,
                  offset: const Offset(2, 2),
                  blurRadius: 2,
                  spreadRadius: -1),
              BoxShadow(
                  color: AppColors.shadowBottom,
                  offset: const Offset(-2, -2),
                  blurRadius: 2,
                  spreadRadius: -1)
            ]),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: TextField(
            controller: ctrl,
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            style: TextStyle(
                color: AppColors.textMain,
                fontSize: 14,
                fontWeight: FontWeight.bold),
            decoration: InputDecoration(
                prefixIcon: icon != null
                    ? Icon(icon, color: iconColor ?? AppColors.accent)
                    : null,
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    vertical: 15, horizontal: icon != null ? 0 : 10),
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)))));
  }

  BoxDecoration _neuDeco({bool pressed = false}) {
    return BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: pressed
            ? [
                BoxShadow(
                    color: AppColors.shadowTop,
                    offset: const Offset(2, 2),
                    blurRadius: 3,
                    spreadRadius: -1),
                BoxShadow(
                    color: AppColors.shadowBottom,
                    offset: const Offset(-2, -2),
                    blurRadius: 3,
                    spreadRadius: -1)
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
              ]);
  }
}
