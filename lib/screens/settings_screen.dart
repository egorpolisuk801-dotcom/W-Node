import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/user_config.dart';
import '../services/db_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Контроллери
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _dbNameCtrl = TextEditingController();
  final _newWhCtrl = TextEditingController();

  // Стан
  bool _isDark = true;
  bool _isLoading = false;
  bool _showPassword = false;

  // Склади
  List<String> _warehouses = [];

  // Видимість (Речі)
  bool _iDig = true;
  bool _iLet = true;
  bool _iShoe = true;
  bool _iHat = true;
  bool _iHatR = true;
  bool _iGlov = true;
  bool _iHatW = true;
  bool _iGlovSL = true;
  bool _iLinen = true;

  // Видимість (Інвентар)
  bool _invLet = true;
  bool _invDig = true;
  bool _invShoe = true;
  bool _invRng = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _dbNameCtrl.dispose();
    _newWhCtrl.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final cfg = UserConfig();
    _hostCtrl.text = cfg.dbHost;
    _userCtrl.text = cfg.dbUser;
    _passCtrl.text = cfg.dbPass;
    _dbNameCtrl.text = cfg.dbName;

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

    setState(() {
      _isDark = cfg.isDarkMode;
      _iDig = cfg.itemShowDigits;
      _iLet = cfg.itemShowLetters;
      _iShoe = cfg.itemShowShoes;
      _iHat = cfg.itemShowHats;
      _iHatR = cfg.itemShowHatsR;
      _iGlov = cfg.itemShowGloves;
      _iHatW = cfg.itemShowHatsW;
      _iGlovSL = cfg.itemShowGlovesSL;
      _iLinen = cfg.itemShowLinen;
      _invLet = cfg.invShowLetters;
      _invDig = cfg.invShowDigits;
      _invShoe = cfg.invShowShoes;
      _invRng = cfg.invShowRanges;
    });
  }

  Future<void> _updateCloudWarehouses(List<String> updatedList) async {
    try {
      final supabase = Supabase.instance.client;
      String jsonList = jsonEncode(updatedList);
      final check = await supabase
          .from('global_settings')
          .select('id')
          .eq('setting_key', 'warehouses');
      if (check.isNotEmpty) {
        await supabase.from('global_settings').update({
          'setting_value': jsonList,
          'updated_at': DateTime.now().toIso8601String()
        }).eq('setting_key', 'warehouses');
      } else {
        await supabase
            .from('global_settings')
            .insert({'setting_key': 'warehouses', 'setting_value': jsonList});
      }
    } catch (e) {
      print("Помилка відправки складів у хмару: $e");
    }
  }

  void _save() async {
    setState(() => _isLoading = true);

    await UserConfig().save(
      host: _hostCtrl.text.trim(),
      user: _userCtrl.text.trim(),
      pass: _passCtrl.text.trim(),
      dbname: _dbNameCtrl.text.trim(),
      w1: jsonEncode(_warehouses),
      w2: "",
      darkMode: _isDark,
      iDig: _iDig,
      iLet: _iLet,
      iShoe: _iShoe,
      iHat: _iHat,
      iHatR: _iHatR,
      iGlov: _iGlov,
      iHatW: _iHatW,
      iGlovSL: _iGlovSL,
      iLinen: _iLinen,
      invLet: _invLet,
      invDig: _invDig,
      invShoe: _invShoe,
      invRng: _invRng,
    );

    await _updateCloudWarehouses(_warehouses);
    await DBService().initConnection();

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Налаштування збережено!",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _exitServer() async {
    setState(() => _isLoading = true);
    _hostCtrl.clear();
    _userCtrl.clear();
    _passCtrl.clear();
    _dbNameCtrl.clear();

    await UserConfig().save(
      host: "",
      user: "",
      pass: "",
      dbname: "",
      w1: jsonEncode(_warehouses),
      w2: "",
      darkMode: _isDark,
      iDig: _iDig,
      iLet: _iLet,
      iShoe: _iShoe,
      iHat: _iHat,
      iHatR: _iHatR,
      iGlov: _iGlov,
      iHatW: _iHatW,
      iGlovSL: _iGlovSL,
      iLinen: _iLinen,
      invLet: _invLet,
      invDig: _invDig,
      invShoe: _invShoe,
      invRng: _invRng,
    );

    await DBService().initConnection();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text("Ви вийшли з сервера"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20))),
      );
      Navigator.pop(context);
    }
  }

  // ==========================================
  // ВИКЛИК ПІДМЕНЮ (BOTTOM SHEETS)
  // ==========================================

  void _showServerSheet() {
    _showCustomSheet(
        title: "📡 Підключення до БД",
        child: Column(
          children: [
            _neuField(_hostCtrl, "Host (Адреса)", icon: Icons.cloud),
            const SizedBox(height: 15),
            _neuField(_dbNameCtrl, "Database (Назва БД)", icon: Icons.storage),
            const SizedBox(height: 15),
            _neuField(_userCtrl, "User (Користувач)", icon: Icons.person),
            const SizedBox(height: 15),
            StatefulBuilder(
              builder: (ctx, setInnerState) => _neuField(
                  _passCtrl, "Password (Пароль)",
                  icon: Icons.lock,
                  isPass: !_showPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey),
                    onPressed: () =>
                        setInnerState(() => _showPassword = !_showPassword),
                  )),
            ),
            const SizedBox(height: 20),
          ],
        ));
  }

  void _showWarehousesSheet() {
    _showCustomSheet(
        title: "🏢 Управління складами",
        child: StatefulBuilder(builder: (ctx, setInnerState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _warehouses
                    .map((wh) => Chip(
                          label: Text(wh,
                              style: TextStyle(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.bg,
                          deleteIcon: const Icon(Icons.close,
                              color: Colors.redAccent, size: 20),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          onDeleted: () async {
                            if (_warehouses.length > 1) {
                              setInnerState(() => _warehouses.remove(wh));
                              setState(() {}); // Оновлюємо головний екран
                              await _updateCloudWarehouses(_warehouses);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: const Text(
                                          "Має бути хоча б один склад!"),
                                      backgroundColor: Colors.red));
                            }
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                      child: _neuField(_newWhCtrl, "Новий склад...",
                          icon: Icons.add_business)),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: () async {
                      final text = _newWhCtrl.text.trim();
                      if (text.isNotEmpty && !_warehouses.contains(text)) {
                        setInnerState(() {
                          _warehouses.add(text);
                          _newWhCtrl.clear();
                        });
                        setState(() {});
                        await _updateCloudWarehouses(_warehouses);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: AppColors.accentBlue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.shadowBottom,
                                offset: const Offset(3, 3),
                                blurRadius: 6),
                            BoxShadow(
                                color: AppColors.shadowTop,
                                offset: const Offset(-2, -2),
                                blurRadius: 4),
                          ]),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
            ],
          );
        }));
  }

  void _showItemCategoriesSheet() {
    _showCustomSheet(
        title: "👕 Категорії: Речі",
        child: StatefulBuilder(builder: (ctx, setInnerState) {
          return Wrap(spacing: 12, runSpacing: 12, children: [
            _filterChip("Цифри", _iDig, (v) {
              setInnerState(() => _iDig = v);
              setState(() {});
            }),
            _filterChip("Букви", _iLet, (v) {
              setInnerState(() => _iLet = v);
              setState(() {});
            }),
            _filterChip("Взуття", _iShoe, (v) {
              setInnerState(() => _iShoe = v);
              setState(() {});
            }),
            _filterChip("Головні", _iHat, (v) {
              setInnerState(() => _iHat = v);
              setState(() {});
            }),
            _filterChip("ГУ Діап.", _iHatR, (v) {
              setInnerState(() => _iHatR = v);
              setState(() {});
            }),
            _filterChip("ГУ Широкі", _iHatW, (v) {
              setInnerState(() => _iHatW = v);
              setState(() {});
            }),
            _filterChip("Рукавиці", _iGlov, (v) {
              setInnerState(() => _iGlov = v);
              setState(() {});
            }),
            _filterChip("Рук. S-XL", _iGlovSL, (v) {
              setInnerState(() => _iGlovSL = v);
              setState(() {});
            }),
            _filterChip("Білизна", _iLinen, (v) {
              setInnerState(() => _iLinen = v);
              setState(() {});
            }),
          ]);
        }));
  }

  void _showInvCategoriesSheet() {
    _showCustomSheet(
        title: "🎒 Категорії: Інвентар",
        child: StatefulBuilder(builder: (ctx, setInnerState) {
          return Wrap(spacing: 12, runSpacing: 12, children: [
            _filterChip("Букви", _invLet, (v) {
              setInnerState(() => _invLet = v);
              setState(() {});
            }),
            _filterChip("Цифри", _invDig, (v) {
              setInnerState(() => _invDig = v);
              setState(() {});
            }),
            _filterChip("Взуття", _invShoe, (v) {
              setInnerState(() => _invShoe = v);
              setState(() {});
            }),
            _filterChip("Діапазон", _invRng, (v) {
              setInnerState(() => _invRng = v);
              setState(() {});
            }),
          ]);
        }));
  }

  // ==========================================
  // ГОЛОВНИЙ ІНТЕРФЕЙС
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("НАЛАШТУВАННЯ",
            style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textMain),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _menuTile(
              title: "Сервер (Supabase)",
              subtitle: _hostCtrl.text.isNotEmpty
                  ? "Підключено: ${_dbNameCtrl.text}"
                  : "Не налаштовано",
              icon: Icons.dns_rounded,
              color: Colors.blueAccent,
              onTap: _showServerSheet,
            ),
            _menuTile(
              title: "Склади",
              subtitle: "${_warehouses.length} складів активно",
              icon: Icons.domain_rounded,
              color: Colors.orangeAccent,
              onTap: _showWarehousesSheet,
            ),
            _menuTile(
              title: "Відображення: Речі",
              subtitle: "Налаштування розмірних сіток",
              icon: Icons.checkroom_rounded,
              color: Colors.teal,
              onTap: _showItemCategoriesSheet,
            ),
            _menuTile(
              title: "Відображення: Інвентар",
              subtitle: "Налаштування категорій інвентарю",
              icon: Icons.handyman_rounded,
              color: Colors.purpleAccent,
              onTap: _showInvCategoriesSheet,
            ),

            const SizedBox(height: 10),
            _switchTile("Темна тема інтерфейсу", _isDark,
                (v) => setState(() => _isDark = v)),

            const SizedBox(height: 50),

            // --- 💾 КНОПКА ЗБЕРЕЖЕННЯ ---
            GestureDetector(
              onTap: _isLoading ? null : _save,
              child: Container(
                height: 65,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        offset: const Offset(0, 8),
                        blurRadius: 15)
                  ],
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ЗБЕРЕГТИ ВСІ ЗМІНИ",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
              ),
            ),

            const SizedBox(height: 30),
            Divider(color: Colors.grey.withOpacity(0.15), thickness: 2),
            const SizedBox(height: 30),

            // --- 🚪 КНОПКА ВИХОДУ ---
            GestureDetector(
              onTap: _isLoading ? null : _exitServer,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: Colors.redAccent.withOpacity(0.5), width: 2),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.logout, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text("Видалити дані сервера",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ВІДЖЕТИ ДИЗАЙНУ
  // ==========================================

  Widget _menuTile(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadowTop,
                offset: const Offset(-4, -4),
                blurRadius: 8),
            BoxShadow(
                color: AppColors.shadowBottom,
                offset: const Offset(4, 4),
                blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 28),
          ],
        ),
      ),
    );
  }

  void _showCustomSheet({required String title, required Widget child}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 15),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, // 🔥 ВИПРАВЛЕНО 🔥
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                width: 50,
                height: 6,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10)),
              )),
              const SizedBox(height: 25),
              Text(title,
                  style: TextStyle(
                      color: AppColors.accentBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const SizedBox(height: 25),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _neuField(TextEditingController ctrl, String hint,
      {bool isPass = false, IconData? icon, Widget? suffixIcon}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowTop,
              offset: const Offset(-3, -3),
              blurRadius: 6),
          BoxShadow(
              color: AppColors.shadowBottom,
              offset: const Offset(3, 3),
              blurRadius: 6),
        ],
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        style:
            TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
          prefixIcon:
              icon != null ? Icon(icon, color: AppColors.accentBlue) : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _switchTile(String title, bool val, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowTop,
              offset: const Offset(-3, -3),
              blurRadius: 6),
          BoxShadow(
              color: AppColors.shadowBottom,
              offset: const Offset(3, 3),
              blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Switch(
              value: val, onChanged: onChanged, activeColor: AppColors.accent),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, Function(bool) onSelect) {
    return GestureDetector(
      onTap: () => onSelect(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: AppColors.accentBlue, width: 2)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.shadowTop,
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                      spreadRadius: -1),
                  BoxShadow(
                      color: AppColors.shadowBottom,
                      offset: const Offset(-2, -2),
                      blurRadius: 4,
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
                ],
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.accentBlue : Colors.grey,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
