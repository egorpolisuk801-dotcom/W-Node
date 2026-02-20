import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/user_config.dart';
import '../services/db_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Контроллеры
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _dbNameCtrl = TextEditingController();
  final _wh1Ctrl = TextEditingController();
  final _wh2Ctrl = TextEditingController();

  // Состояние
  bool _isDark = true;
  bool _isLoading = false;
  bool _showPassword = false;

  // Видимость (Вещи)
  bool _iDig = true;
  bool _iLet = true;
  bool _iShoe = true;
  bool _iHat = true;
  bool _iHatR = true;
  bool _iGlov = true;
  bool _iHatW = true;
  bool _iGlovSL = true;
  bool _iLinen = true;

  // Видимость (Инвентарь)
  bool _invLet = true;
  bool _invDig = true;
  bool _invShoe = true;
  bool _invRng = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final cfg = UserConfig();
    _hostCtrl.text = cfg.dbHost;
    _userCtrl.text = cfg.dbUser;
    _passCtrl.text = cfg.dbPass;
    _dbNameCtrl.text = cfg.dbName;
    _wh1Ctrl.text = cfg.wh1Name;
    _wh2Ctrl.text = cfg.wh2Name;

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

  void _save() async {
    setState(() => _isLoading = true);

    await UserConfig().save(
      host: _hostCtrl.text.trim(),
      user: _userCtrl.text.trim(),
      pass: _passCtrl.text.trim(),
      dbname: _dbNameCtrl.text.trim(),
      w1: _wh1Ctrl.text.isEmpty ? "Склад 1" : _wh1Ctrl.text,
      w2: _wh2Ctrl.text.isEmpty ? "Склад 2" : _wh2Ctrl.text,
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
          content: const Text("Налаштування збережено!",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
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
      w1: _wh1Ctrl.text,
      w2: _wh2Ctrl.text,
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
        const SnackBar(
            content: Text("Ви вийшли з сервера"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
      Navigator.pop(context);
    }
  }

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
            // --- 📡 СЕРВЕР ---
            _header("📡 СЕРВЕР (Supabase)"),
            _neuField(_hostCtrl, "Host (Адреса)", icon: Icons.cloud),
            const SizedBox(height: 15),
            _neuField(_dbNameCtrl, "Database (Назва БД)", icon: Icons.storage),
            const SizedBox(height: 15),
            _neuField(_userCtrl, "User (Користувач)", icon: Icons.person),
            const SizedBox(height: 15),
            _neuField(_passCtrl, "Password (Пароль)",
                icon: Icons.lock,
                isPass: !_showPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                )),

            const SizedBox(height: 40),

            // --- 🏢 СКЛАДИ ---
            _header("🏢 НАЗВИ СКЛАДІВ"),
            Row(children: [
              Expanded(child: _neuField(_wh1Ctrl, "Склад 1")),
              const SizedBox(width: 15),
              Expanded(child: _neuField(_wh2Ctrl, "Склад 2")),
            ]),

            const SizedBox(height: 40),

            // --- 🎨 ІНТЕРФЕЙС ---
            _header("🎨 ІНТЕРФЕЙС"),
            _switchTile(
                "Темна тема", _isDark, (v) => setState(() => _isDark = v)),

            const SizedBox(height: 40),

            // --- 👕 РЕЧІ ---
            _header("👕 КАТЕГОРІЇ: РЕЧІ"),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _filterChip("Цифри", _iDig, (v) => setState(() => _iDig = v)),
              _filterChip("Букви", _iLet, (v) => setState(() => _iLet = v)),
              _filterChip("Взуття", _iShoe, (v) => setState(() => _iShoe = v)),
              _filterChip("Головні", _iHat, (v) => setState(() => _iHat = v)),
              _filterChip(
                  "ГУ Діап.", _iHatR, (v) => setState(() => _iHatR = v)),
              _filterChip(
                  "ГУ Широкі", _iHatW, (v) => setState(() => _iHatW = v)),
              _filterChip(
                  "Рукавиці", _iGlov, (v) => setState(() => _iGlov = v)),
              _filterChip(
                  "Рук. S-XL", _iGlovSL, (v) => setState(() => _iGlovSL = v)),
              _filterChip(
                  "Білизна", _iLinen, (v) => setState(() => _iLinen = v)),
            ]),

            const SizedBox(height: 40),

            // --- 🎒 ІНВЕНТАР ---
            _header("🎒 КАТЕГОРІЇ: ІНВЕНТАР"),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _filterChip("Букви", _invLet, (v) => setState(() => _invLet = v)),
              _filterChip("Цифри", _invDig, (v) => setState(() => _invDig = v)),
              _filterChip(
                  "Взуття", _invShoe, (v) => setState(() => _invShoe = v)),
              _filterChip(
                  "Діапазон", _invRng, (v) => setState(() => _invRng = v)),
            ]),

            const SizedBox(height: 50),

            // --- 💾 КНОПКА ЗБЕРЕЖЕННЯ ---
            GestureDetector(
              onTap: _isLoading ? null : _save,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        offset: const Offset(0, 5),
                        blurRadius: 10),
                  ],
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ЗБЕРЕГТИ НАЛАШТУВАННЯ",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
              ),
            ),

            const SizedBox(height: 30),
            Divider(color: Colors.grey.withOpacity(0.2)),
            const SizedBox(height: 30),

            // --- 🚪 КНОПКА ВИХОДУ ---
            GestureDetector(
              onTap: _isLoading ? null : _exitServer,
              child: Container(
                height: 55,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.shadowTop,
                          offset: const Offset(-2, -2),
                          blurRadius: 4),
                      BoxShadow(
                          color: AppColors.shadowBottom,
                          offset: const Offset(2, 2),
                          blurRadius: 4),
                    ]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 10),
                    Text("Вийти з сервера",
                        style: TextStyle(
                            color: Colors.red,
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

  // СТИЛЬ ЗАГОЛОВКІВ ГРУП
  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 15, left: 5),
        child: Text(text,
            style: TextStyle(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.5)),
      );

  // ОРИГІНАЛЬНЕ ОБ'ЄМНЕ ТЕКСТОВЕ ПОЛЕ
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
            TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
          prefixIcon:
              icon != null ? Icon(icon, color: AppColors.accentBlue) : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  // ОРИГІНАЛЬНИЙ ОБ'ЄМНИЙ ПЕРЕМИКАЧ
  Widget _switchTile(String title, bool val, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowTop,
              offset: const Offset(-2, -2),
              blurRadius: 5),
          BoxShadow(
              color: AppColors.shadowBottom,
              offset: const Offset(2, 2),
              blurRadius: 5),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.textMain, fontWeight: FontWeight.bold)),
          Switch(
            value: val,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  // ОРИГІНАЛЬНА ОБ'ЄМНА КНОПКА-ЧІП
  Widget _filterChip(String label, bool selected, Function(bool) onSelect) {
    return GestureDetector(
      onTap: () => onSelect(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(15),
          border: selected
              ? Border.all(color: AppColors.accentBlue, width: 1.5)
              : null,
          boxShadow: selected
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
                      offset: const Offset(-2, -2),
                      blurRadius: 4),
                  BoxShadow(
                      color: AppColors.shadowBottom,
                      offset: const Offset(2, 2),
                      blurRadius: 4),
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
