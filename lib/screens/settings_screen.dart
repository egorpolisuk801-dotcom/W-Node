import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/user_config.dart';
import '../services/db_service.dart'; // На случай если нужно сбросить соединение

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Контроллеры для текста
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _dbNameCtrl = TextEditingController();
  final _wh1Ctrl = TextEditingController();
  final _wh2Ctrl = TextEditingController();

  // Переменные для переключателей
  bool _isDark = true;
  bool _isLoading = false;

  // Видимость (Вещи)
  bool _iDig = true;
  bool _iLet = true;
  bool _iShoe = true;
  bool _iHat = true;
  bool _iHatR = true;
  bool _iGlov = true;

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

  // Загружаем текущие настройки в поля
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

      _invLet = cfg.invShowLetters;
      _invDig = cfg.invShowDigits;
      _invShoe = cfg.invShowShoes;
      _invRng = cfg.invShowRanges;
    });
  }

  // Сохранение настроек
  void _save() async {
    setState(() => _isLoading = true);

    // ИСПРАВЛЕНИЕ: Передаем ВСЕ параметры, включая dbname
    await UserConfig().save(
      host: _hostCtrl.text.trim(),
      user: _userCtrl.text.trim(),
      pass: _passCtrl.text.trim(),
      dbname: _dbNameCtrl.text.trim(), // <--- ВОТ ЭТО БЫЛО ПРОПУЩЕНО
      w1: _wh1Ctrl.text.isEmpty ? "Склад 1" : _wh1Ctrl.text,
      w2: _wh2Ctrl.text.isEmpty ? "Склад 2" : _wh2Ctrl.text,
      darkMode: _isDark,

      // Видимость
      iDig: _iDig, iLet: _iLet, iShoe: _iShoe,
      iHat: _iHat, iHatR: _iHatR, iGlov: _iGlov,
      invLet: _invLet, invDig: _invDig,
      invShoe: _invShoe, invRng: _invRng,
    );

    // Переинициализируем соединение с новыми данными
    await DBService().initConnection();

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Налаштування збережено! Перезапустіть додаток.")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title:
            Text("Налаштування", style: TextStyle(color: AppColors.textMain)),
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textMain),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header("Сервер (Supabase)"),
            _neuField(_hostCtrl, "Host (Адреса)"),
            const SizedBox(height: 10),
            _neuField(_userCtrl, "User (Користувач)"),
            const SizedBox(height: 10),
            _neuField(_passCtrl, "Password (Пароль)", isPass: true),
            const SizedBox(height: 10),
            _neuField(_dbNameCtrl, "Database (Назва БД)"),
            const SizedBox(height: 30),
            _header("Склади"),
            Row(children: [
              Expanded(child: _neuField(_wh1Ctrl, "Назва Складу 1")),
              const SizedBox(width: 10),
              Expanded(child: _neuField(_wh2Ctrl, "Назва Складу 2")),
            ]),
            const SizedBox(height: 30),
            _header("Інтерфейс"),
            _switchTile(
                "Темна тема", _isDark, (v) => setState(() => _isDark = v)),
            const SizedBox(height: 30),
            _header("Категорії: РЕЧІ"),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _filterChip("Цифри", _iDig, (v) => setState(() => _iDig = v)),
              _filterChip("Букви", _iLet, (v) => setState(() => _iLet = v)),
              _filterChip("Взуття", _iShoe, (v) => setState(() => _iShoe = v)),
              _filterChip("Головні", _iHat, (v) => setState(() => _iHat = v)),
              _filterChip(
                  "ГУ Діап.", _iHatR, (v) => setState(() => _iHatR = v)),
              _filterChip(
                  "Рукавиці", _iGlov, (v) => setState(() => _iGlov = v)),
            ]),
            const SizedBox(height: 20),
            _header("Категорії: ІНВЕНТАР"),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _filterChip("Букви", _invLet, (v) => setState(() => _invLet = v)),
              _filterChip("Цифри", _invDig, (v) => setState(() => _invDig = v)),
              _filterChip(
                  "Взуття", _invShoe, (v) => setState(() => _invShoe = v)),
              _filterChip(
                  "Діапазон", _invRng, (v) => setState(() => _invRng = v)),
            ]),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _isLoading ? null : _save,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadowBottom,
                        offset: const Offset(4, 4),
                        blurRadius: 10),
                    BoxShadow(
                        color: AppColors.shadowTop,
                        offset: const Offset(-4, -4),
                        blurRadius: 10),
                  ],
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ЗБЕРЕГТИ ВСЕ",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---
  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Text(text,
            style: TextStyle(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      );

  Widget _neuField(TextEditingController ctrl, String hint,
      {bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
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
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        style: TextStyle(color: AppColors.textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
      ),
    );
  }

  Widget _switchTile(String title, bool val, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
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

  Widget _filterChip(String label, bool selected, Function(bool) onSelect) {
    return GestureDetector(
      onTap: () => onSelect(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(20),
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
                      spreadRadius: -2),
                ]
              : [
                  BoxShadow(
                      color: AppColors.shadowTop,
                      offset: const Offset(-3, -3),
                      blurRadius: 5),
                  BoxShadow(
                      color: AppColors.shadowBottom,
                      offset: const Offset(3, 3),
                      blurRadius: 5),
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
