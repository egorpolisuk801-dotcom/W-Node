import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/user_config.dart';
import '../core/theme_controller.dart';
import '../core/tactical_ui.dart';
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
  String _themeId = AppThemeId.hud;
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
      _themeId = cfg.themeId;
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
      darkMode: _themeId == AppThemeId.corporate ||
          _themeId == AppThemeId.tactical,
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

    await UserConfig().setThemeId(_themeId);
    ThemeController.set(_themeId);
    await _updateCloudWarehouses(_warehouses);
    await DBService().initConnection();

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Налаштування збережено!",
              style: TextStyle(
                  color: AppColors.onAccent, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: TacSheet.dialog(),
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
            shape: TacSheet.dialog(AppColors.danger)),
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
                              borderRadius: BorderRadius.circular(4)),
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
                          borderRadius: BorderRadius.circular(4),
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
                          Icon(Icons.add, color: AppColors.onAccent, size: 28),
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
      appBar: const TacAppBar(
        title: 'Налаштування',
        code: 'Налаштування',
      ),
      body: TacBackdrop(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _menuTile(
                title: "Сервер (Supabase)",
                subtitle: _hostCtrl.text.isNotEmpty
                    ? "Підключено: ${_dbNameCtrl.text}"
                    : "Не налаштовано",
                icon: Icons.dns_rounded,
                color: AppColors.accentBlue,
                onTap: _showServerSheet,
              ),
              _menuTile(
                title: "Склади",
                subtitle: "${_warehouses.length} складів активно",
                icon: Icons.domain_rounded,
                color: AppColors.warning,
                onTap: _showWarehousesSheet,
              ),
              _menuTile(
                title: "Відображення: Речі",
                subtitle: "Налаштування розмірних сіток",
                icon: Icons.checkroom_rounded,
                color: AppColors.accent,
                onTap: _showItemCategoriesSheet,
              ),
              _menuTile(
                title: "Відображення: Інвентар",
                subtitle: "Налаштування категорій інвентарю",
                icon: Icons.handyman_rounded,
                color: AppColors.silk,
                onTap: _showInvCategoriesSheet,
              ),
              const TacSection(code: 'Тема', hint: 'вигляд програми'),
              const SizedBox(height: 12),
              _themePicker(),
              const SizedBox(height: 28),
              TacButton(
                label: 'Зберегти всі зміни',
                icon: Icons.save_outlined,
                onTap: _isLoading ? () {} : _save,
              ),
              const SizedBox(height: 14),
              TacButton(
                label: 'Видалити дані сервера',
                icon: Icons.logout,
                color: AppColors.danger,
                filled: false,
                onTap: _isLoading ? () {} : _exitServer,
              ),
            ],
          ),
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
    return TacCard(
      margin: const EdgeInsets.only(bottom: 12),
      accent: color,
      onTap: onTap,
      child: Row(
        children: [
          TacIconBox(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 22),
        ],
      ),
    );
  }

  void _showCustomSheet({required String title, required Widget child}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: TacSheet.shape,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 16,
            right: 16,
            top: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TacSheet.handle(),
              const SizedBox(height: 16),
              Text(title,
                  style: TacStyle.stencil.copyWith(fontSize: 13)),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _neuField(TextEditingController ctrl, String hint,
      {bool isPass = false, IconData? icon, Widget? suffixIcon}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass,
      style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
      decoration: TacField.of(hint, icon: icon).copyWith(suffixIcon: suffixIcon),
    );
  }

  Widget _themePicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppThemeId.all.map((id) {
        final selected = _themeId == id;
        return SizedBox(
          width: 156,
          child: TacCard(
            accent: selected ? AppColors.accent : AppColors.border,
            onTap: () {
              setState(() {
                _themeId = id;
                _isDark = id == AppThemeId.corporate ||
                    id == AppThemeId.tactical;
              });
              ThemeController.set(id);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                    id == AppThemeId.light
                        ? Icons.wb_sunny_outlined
                        : (id == AppThemeId.tactical
                            ? Icons.nights_stay_rounded
                            : (id == AppThemeId.corporate
                                ? Icons.park_outlined
                                : Icons.blur_on_rounded)),
                    color: selected ? AppColors.accent : AppColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(AppThemeId.title(id),
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                Text(AppThemeId.hint(id),
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _filterChip(String label, bool selected, Function(bool) onSelect) {
    return TacChip(
      label: label,
      active: selected,
      onTap: () => onSelect(!selected),
    );
  }
}
