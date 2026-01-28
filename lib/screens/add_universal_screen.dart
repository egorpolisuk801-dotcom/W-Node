import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../services/db_service.dart';
import '../core/user_config.dart';
import '../core/notification_helper.dart'; // Если есть файл уведомлений

class AddUniversalScreen extends StatefulWidget {
  const AddUniversalScreen({super.key});

  @override
  State<AddUniversalScreen> createState() => _AddUniversalScreenState();
}

class _AddUniversalScreenState extends State<AddUniversalScreen> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _simpleQtyCtrl = TextEditingController();

  // === ДАННЫЕ ДЛЯ МАТРИЦ (РОСТ + РАЗМЕР) ===
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

  // === ДАННЫЕ ДЛЯ ЛИНЕЙНЫХ СПИСКОВ ===
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
    "53-54",
    "54-55",
    "55-56",
    "56-57",
    "57-58",
    "58-59",
    "59-60",
    "60-61",
    "61-62"
  ];
  final List<String> _glovesCols = ["1", "2", "3", "4"];

  // === ТИПЫ ===
  final List<String> _clothesTypes = [
    "Цифри",
    "Букви",
    "Взуття",
    "Головні убори",
    "ГУ (Діапазон)",
    "Рукавички",
    "Просте"
  ];
  final List<String> _invTypes = ["Букви", "Цифри", "Взуття", "ГУ (Діапазон)"];

  // === СОСТОЯНИЕ ===
  bool _isInventory = false;
  String _selectedWh = "ООС";

  // Общие переменные для сеток
  String _currentSubType = "Цифри"; // Текущий тип сетки (Цифры/Буквы/...)
  String _selectedRow = "1"; // Выбранный РОСТ (для матриц)

  // Специфика Инвентаря
  String _invSelectedCat = "I";
  bool _invUseGrid = true;

  Map<String, int> _quantities = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (UserConfig().wh1Name.isNotEmpty) _selectedWh = UserConfig().wh1Name;
  }

  // --- ПРОВЕРКА НАСТРОЕК ---
  bool _shouldShowType(String type) {
    final cfg = UserConfig();
    // Логика отображения вкладок (Инвентарь или Вещи)
    if (_isInventory) {
      switch (type) {
        case "Цифри":
          return cfg.invShowDigits;
        case "Букви":
          return cfg.invShowLetters;
        case "Взуття":
          return cfg.invShowShoes;
        case "ГУ (Діапазон)":
          return cfg.invShowRanges;
        default:
          return true;
      }
    } else {
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
        case "Рукавички":
          return cfg.itemShowGloves;
        case "Просте":
          return true;
        default:
          return true;
      }
    }
  }

  // Смена режима (Вещи <-> Инвентарь)
  void _setMode(bool inventory) {
    setState(() {
      _isInventory = inventory;
      _quantities.clear();
      _simpleQtyCtrl.clear();
      // Сброс к дефолтам
      _currentSubType = "Цифри";
      _selectedRow = "1";
    });
  }

  // Смена типа сетки (Вкладки)
  void _setSubType(String type) {
    setState(() {
      _currentSubType = type;
      _quantities.clear();

      // Умный выбор дефолтного роста
      if (type == "Цифри")
        _selectedRow = "1";
      else if (type == "Букви")
        _selectedRow = "XS";
      else
        _selectedRow = ""; // Для обуви и прочего рост не нужен
    });
  }

  int get _totalCount {
    // Если режим "Простое число" (в вещах или инвентаре)
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
        title: Text("$key : Кількість",
            style: TextStyle(color: AppColors.textMain)),
        content: _neuTextField(qtyCtrl, "0", isNum: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Відміна")),
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
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);

    int total = _totalCount;
    Map<String, int> finalData = {};

    bool isSimple = (_isInventory && !_invUseGrid) ||
        (!_isInventory && _currentSubType == "Просте");

    if (!isSimple) {
      _quantities.forEach((k, v) {
        if (v > 0) finalData[k] = v;
      });
    }

    Map<String, dynamic> item = {
      'name': _nameCtrl.text,
      'location': _locationCtrl.text,
      'category': _isInventory
          ? _invSelectedCat
          : (_catCtrl.text.isEmpty ? "Одяг" : _catCtrl.text),
      'warehouse': _selectedWh,
      'type': _isInventory ? "Інвентар" : _currentSubType,
      'total': total,
      'size_data': finalData,
      'is_inventory': _isInventory,
    };

    try {
      await DBService().saveItem(item);
      DBService().syncWithCloud();
      try {
        NotificationHelper.showSuccess(context, "Створено: ${item['name']}");
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Збережено!")));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      try {
        NotificationHelper.showError(context, "Помилка: $e");
      } catch (ex) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Помилка: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. ПЕРЕКЛЮЧАТЕЛЬ РЕЖИМА
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

            // 2. ОБЩИЕ ПОЛЯ
            _neuTextField(_nameCtrl, "Назва (напр. Куртка)"),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(flex: 2, child: _neuTextField(_locationCtrl, "Місце")),
              const SizedBox(width: 15),
              Expanded(flex: 3, child: _whSelector()),
            ]),
            const SizedBox(height: 15),

            // 3. ИНТЕРФЕЙС (ВЕЩИ ИЛИ ИНВЕНТАРЬ)
            if (!_isInventory) _buildClothesUI() else _buildInventoryUI(),

            const SizedBox(height: 40),

            // 4. КНОПКА СОХРАНИТЬ
            GestureDetector(
              onTap: _isSaving ? null : _save,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: _neuDeco().copyWith(color: AppColors.accent),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ЗБЕРЕГТИ",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI: ВЕЩИ ---
  Widget _buildClothesUI() {
    return Column(
      children: [
        // Ряд: Категория + Счетчик
        Row(
          children: [
            Expanded(
                child: _neuTextField(_catCtrl, "Категорія (напр. Футболки)")),
            const SizedBox(width: 15),
            _totalCounterWidget(), // ВОТ ОН, РОДНОЙ
          ],
        ),
        const SizedBox(height: 15),

        // Вкладки
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: _clothesTypes.map((t) {
              if (!_shouldShowType(t)) return const SizedBox();
              bool act = _currentSubType == t;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _setSubType(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    decoration: _neuDeco(pressed: act),
                    child: Text(t,
                        style: TextStyle(
                            color: act ? AppColors.accentBlue : Colors.grey,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // СЕТКА (ОБЩАЯ ДЛЯ ВСЕХ)
        if (_currentSubType == "Просте")
          _neuTextField(_simpleQtyCtrl, "Введіть кількість (шт)", isNum: true)
        else
          _buildUniversalGridBody(), // ИСПОЛЬЗУЕМ ОБЩУЮ ФУНКЦИЮ С РОСТАМИ
      ],
    );
  }

  // --- UI: ИНВЕНТАРЬ ---
  Widget _buildInventoryUI() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 55,
                padding: const EdgeInsets.all(4),
                decoration: _neuDeco(pressed: true),
                child: Row(children: [
                  Expanded(
                      child: _neuSelectableBtn("I", _invSelectedCat == "I",
                          () => setState(() => _invSelectedCat = "I"))),
                  Expanded(
                      child: _neuSelectableBtn("II", _invSelectedCat == "II",
                          () => setState(() => _invSelectedCat = "II"))),
                ]),
              ),
            ),
            const SizedBox(width: 15),
            _totalCounterWidget(),
          ],
        ),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_invUseGrid ? "📐 СІТКА (ПК)" : "🔢 ПРОСТЕ ЧИСЛО",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textMain)),
          Switch(
              value: _invUseGrid,
              activeColor: AppColors.accent,
              onChanged: (v) => setState(() => _invUseGrid = v)),
        ]),
        const SizedBox(height: 10),
        if (!_invUseGrid)
          _neuTextField(_simpleQtyCtrl, "Введіть кількість (шт)", isNum: true)
        else
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _invTypes.map((t) {
                    if (!_shouldShowType(t)) return const SizedBox();
                    bool act = _currentSubType == t;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => _setSubType(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          decoration: _neuDeco(pressed: act),
                          child: Text(t,
                              style: TextStyle(
                                  color: act ? Colors.purple : Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              _buildUniversalGridBody(), // ИСПОЛЬЗУЕМ ТУ ЖЕ ОБЩУЮ ФУНКЦИЮ
            ],
          ),
      ],
    );
  }

  // === ГЛАВНАЯ ФУНКЦИЯ ПОСТРОЕНИЯ СЕТОК (ОБЩАЯ) ===
  // Теперь она используется и для Вещей, и для Инвентаря.
  // Поэтому Роста будут ВЕЗДЕ, где выбраны "Цифри" или "Букви".
  Widget _buildUniversalGridBody() {
    switch (_currentSubType) {
      case "Цифри":
        return _build2DGrid(_digitsRows, _digitsCols); // ЕСТЬ РОСТ!
      case "Букви":
        return _build2DGrid(_lettersRows, _lettersCols); // ЕСТЬ РОСТ!
      case "Взуття":
        return _build1DGrid(_shoesCols);
      case "Головні убори":
        return _build1DGrid(_hatsCols);
      case "ГУ (Діапазон)":
        return _build1DGrid(_hatsRangeCols);
      case "Рукавички":
        return _build1DGrid(_glovesCols);
      default:
        return const SizedBox();
    }
  }

  // Линейная сетка (Обувь и т.д.)
  Widget _build1DGrid(List<String> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: items.map((val) {
        int qty = _quantities[val] ?? 0;
        return _gridBtn(val, qty, () {
          HapticFeedback.lightImpact();
          setState(() => _quantities[val] = qty + 1);
        }, () => _showBulkInputDialog(val, qty));
      }).toList(),
    );
  }

  // Матрица (РОСТ + РАЗМЕР)
  Widget _build2DGrid(List<String> rows, List<String> cols) {
    return Column(
      children: [
        // ВЫБОР РОСТА (ОН ТЕПЕРЬ ЕСТЬ ВСЕГДА)
        const Text("Оберіть РОСТ:",
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: rows.map((r) {
              bool active = _selectedRow == r;
              return Padding(
                padding: const EdgeInsets.only(right: 15),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRow = r),
                  child: Container(
                    width: 50,
                    height: 45,
                    alignment: Alignment.center,
                    decoration: _neuDeco(pressed: active),
                    child: Text(r,
                        style: TextStyle(
                            color: active
                                ? (_isInventory
                                    ? Colors.purple
                                    : AppColors.accentBlue)
                                : AppColors.textMain,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        Text("Розміри для росту $_selectedRow:",
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: cols.map((c) {
            String key = "$c-$_selectedRow"; // Ключ с ростом
            int qty = _quantities[key] ?? 0;
            return _gridBtn(c, qty, () {
              if (_selectedRow.isEmpty) return;
              HapticFeedback.lightImpact();
              setState(() => _quantities[key] = qty + 1);
            }, () {
              if (_selectedRow.isNotEmpty) _showBulkInputDialog(key, qty);
            });
          }).toList(),
        )
      ],
    );
  }

  // --- КОМПОНЕНТЫ ---
  Widget _gridBtn(
      String label, int qty, VoidCallback onTap, VoidCallback onLong) {
    bool active = qty > 0;
    Color actColor = _isInventory ? Colors.purple : AppColors.accentBlue;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLong,
      child: Container(
        width: 60,
        height: 50,
        decoration: _neuDeco(pressed: active),
        child: Stack(
          children: [
            Center(
                child: Text(label,
                    style: TextStyle(
                        color: active ? actColor : AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 14))),
            if (active)
              Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: actColor, shape: BoxShape.circle),
                      child: Text("$qty",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String txt, bool active, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: active ? AppColors.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: active
                    ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
                    : null),
            alignment: Alignment.center,
            child: Text(txt,
                style: TextStyle(
                    color: active ? AppColors.textMain : Colors.grey,
                    fontWeight: FontWeight.bold))));
  }

  Widget _whSelector() {
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: _neuDeco(pressed: true),
        child: Row(children: [
          Expanded(
              child: _neuSelectableBtn(
                  UserConfig().wh1Name,
                  _selectedWh == UserConfig().wh1Name,
                  () => setState(() => _selectedWh = UserConfig().wh1Name))),
          Expanded(
              child: _neuSelectableBtn(
                  UserConfig().wh2Name,
                  _selectedWh == UserConfig().wh2Name,
                  () => setState(() => _selectedWh = UserConfig().wh2Name)))
        ]));
  }

  Widget _neuSelectableBtn(String text, bool active, VoidCallback onTap) {
    Color actColor = _isInventory ? Colors.purple : AppColors.accentBlue;
    return GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: active ? AppColors.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: AppColors.shadowTop,
                            offset: const Offset(-2, -2),
                            blurRadius: 5),
                        BoxShadow(
                            color: AppColors.shadowBottom,
                            offset: const Offset(2, 2),
                            blurRadius: 5)
                      ]
                    : null),
            child: Text(text,
                style: TextStyle(
                    color: active ? actColor : Colors.grey,
                    fontWeight: FontWeight.bold))));
  }

  Widget _totalCounterWidget() {
    return Container(
        width: 80,
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: _neuDeco(),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text("ВСЬОГО",
              style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text("$_totalCount",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain))
        ]));
  }

  Widget _neuTextField(TextEditingController ctrl, String hint,
      {bool isNum = false}) {
    return Container(
        decoration: _neuDeco(pressed: true),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: TextField(
            controller: ctrl,
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            style: TextStyle(
                color: AppColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.bold),
            decoration: InputDecoration(
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)))));
  }

  BoxDecoration _neuDeco({bool pressed = false}) {
    return BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: pressed
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
                    blurRadius: 6),
                BoxShadow(
                    color: AppColors.shadowBottom,
                    offset: const Offset(3, 3),
                    blurRadius: 6)
              ]);
  }
}
