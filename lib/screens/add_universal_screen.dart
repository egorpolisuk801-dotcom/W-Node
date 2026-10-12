import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:convert';
import '../core/app_colors.dart';
import '../core/camo_button.dart';
import '../services/db_service.dart';
import '../core/user_config.dart';
import '../core/notification_helper.dart';
import '../core/smart_icons.dart';
import '../core/size_grids.dart';
import '../core/tactical_ui.dart';

class AddUniversalScreen extends StatefulWidget {
  const AddUniversalScreen({super.key});

  @override
  State<AddUniversalScreen> createState() => _AddUniversalScreenState();
}

class _AddUniversalScreenState extends State<AddUniversalScreen> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _simpleQtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  // 🔥 Змінні для живої іконки
  IconData _currentSmartIcon = Icons.inventory_2_rounded;
  Color _currentIconColor = AppColors.accentBlue;

  List<SizeGrid> _catalog = SizeGrids.catalog();
  String? _gridId;
  bool _useSimple = false;

  bool _isInventory = false;

  // 🔥 НОВІ ЗМІННІ ДЛЯ СКЛАДІВ 🔥
  List<String> _warehouses = [];
  String _selectedWh = "ООС";

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
    _ensureGrid();
    _refreshGrids();

    // 🔥 Слухаємо кожну літеру, яку вводить користувач
    _nameCtrl.addListener(_updateSmartIcon);
  }

  List<SizeGrid> get _visibleGrids =>
      SizeGrids.forMode(_catalog, inventory: _isInventory);

  SizeGrid? get _activeGrid {
    for (final grid in _visibleGrids) {
      if (grid.id == _gridId) return grid;
    }
    return null;
  }

  bool get _isSimple {
    if (_isInventory) return !_invUseGrid || _activeGrid == null;
    return _useSimple || _activeGrid == null;
  }

  void _ensureGrid() {
    final grids = _visibleGrids;
    if (grids.isEmpty) {
      _gridId = null;
      return;
    }
    final current = _activeGrid;
    if (current == null) {
      _gridId = grids.first.id;
      _selectedRow = grids.first.rows.isNotEmpty ? grids.first.rows.first : '';
      return;
    }
    if (!current.rows.contains(_selectedRow) && current.rows.isNotEmpty) {
      _selectedRow = current.rows.first;
    }
  }

  Future<void> _refreshGrids() async {
    await DBService().syncSizeGrids();
    if (!mounted) return;
    setState(() {
      _catalog = SizeGrids.catalog();
      _ensureGrid();
    });
  }

  void _selectGrid(SizeGrid grid) {
    setState(() {
      _useSimple = false;
      _gridId = grid.id;
      _quantities.clear();
      _selectedRow = grid.rows.isNotEmpty ? grid.rows.first : '';
    });
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
    _priceCtrl.dispose();
    super.dispose();
  }

  // 🔥 Метод для оновлення іконки на льоту
  void _updateSmartIcon() {
    setState(() {
      _currentSmartIcon = SmartIcons.getIconForName(_nameCtrl.text);
      _currentIconColor = SmartIcons.getColorForIcon(_currentSmartIcon);
    });
  }

  void _setMode(bool inventory) {
    setState(() {
      _isInventory = inventory;
      _quantities.clear();
      _simpleQtyCtrl.clear();
      _useSimple = false;
      _gridId = null;
      _ensureGrid();
    });
  }

  int get _totalCount {
    if (_isSimple) {
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
        shape: TacSheet.dialog(),
        title: Text("$key : Кількість",
            style: TextStyle(color: AppColors.textMain)),
        content: _neuTextField(qtyCtrl, "0", isNum: true),
        actions: [
          CamoButton(
            label: 'Скасувати',
            tone: CamoTone.deep,
            compact: true,
            onPressed: () => Navigator.pop(ctx),
          ),
          CamoButton(
            label: 'ОК',
            tone: CamoTone.olive,
            compact: true,
            onPressed: () {
              int? val = int.tryParse(qtyCtrl.text);
              if (val != null) setState(() => _quantities[key] = val);
              Navigator.pop(ctx);
            },
          ),
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
      bool isSimple = _isSimple;

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
        'type': isSimple
            ? (_isInventory ? 'Інвентар' : 'Просте')
            : (_activeGrid?.name ?? 'Просте'),
        'total': total,
        'size_data': finalData,
        'is_inventory': _isInventory ? 1 : 0,
        'price': double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
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
      appBar: TacAppBar(
        title: _isInventory ? 'Додати інвентар' : 'Додати річ',
        code: 'Нова позиція',
      ),
      body: TacBackdrop(
        child: SingleChildScrollView(
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
            _neuTextField(_priceCtrl, "Ціна за шт, грн",
                isNum: true,
                icon: Icons.payments_outlined,
                iconColor: AppColors.accent),
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
            if (!_isInventory || _invUseGrid)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  ..._visibleGrids.map((grid) {
                    return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _typeChip(
                            grid.name,
                            grid.id == _gridId &&
                                (_isInventory || !_useSimple),
                            () => _selectGrid(grid)));
                  }),
                  if (!_isInventory)
                    _typeChip('Просте', _useSimple, () {
                      setState(() {
                        _useSimple = true;
                        _quantities.clear();
                      });
                    }),
                ]),
              ),
            const SizedBox(height: 5),
            if (_isSimple)
              _neuTextField(_simpleQtyCtrl, "Введіть кількість (шт)",
                  isNum: true)
            else
              _buildUniversalGridBody(),
            const SizedBox(height: 40),
            TacButton(
              label: 'Зберегти',
              icon: Icons.save_outlined,
              onTap: _isSaving ? () {} : _save,
            ),
            const SizedBox(height: 30),
          ],
        ),
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
    final grid = _activeGrid;
    if (grid == null) return const SizedBox();
    if (grid.isMatrix) return _build2DGrid(grid.rows, grid.cols);
    return _build1DGrid(grid.cols);
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
      Text("Зріст", style: TextStyle(color: Colors.grey, fontSize: 11)),
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
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: active
                                  ? (_isInventory
                                      ? AppColors.silk
                                      : AppColors.accentBlue)
                                  : AppColors.border,
                              width: active ? 2 : 1)),
                      child: Text(r,
                          style: TextStyle(
                              color: active
                                  ? (_isInventory
                                      ? AppColors.silk
                                      : AppColors.accentBlue)
                                  : AppColors.textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    )));
          }).toList())),
      const SizedBox(height: 10),
      Text("Розміри ($_selectedRow):",
          style: TextStyle(color: AppColors.muted, fontSize: 11)),
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
    Color actColor = _isInventory ? AppColors.silk : AppColors.accentBlue;
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
                color: AppColors.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: active ? actColor : AppColors.border, width: 1.5)),
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

  Widget _typeChip(String label, bool act, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: act
                    ? (_isInventory ? AppColors.silk : AppColors.accentBlue)
                    : AppColors.border,
                width: act ? 1.5 : 1)),
        child: Text(label,
            style: TextStyle(
                color: act
                    ? (_isInventory ? AppColors.silk : AppColors.accentBlue)
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
                color: active ? AppColors.card : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: active
                    ? Border.all(color: AppColors.border)
                    : Border.all(color: Colors.transparent)),
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
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
    Color actColor = _isInventory ? AppColors.silk : AppColors.accentBlue;
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: active ? AppColors.card : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: active ? actColor : Colors.transparent)),
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
        decoration: AppColors.cardDeco(),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text("Усього",
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
        decoration: AppColors.cardDeco(),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: TextField(
            controller: ctrl,
            keyboardType: isNum
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
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
    return AppColors.cardDeco(
        borderColor: pressed ? AppColors.border : AppColors.border);
  }
}
