import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/app_colors.dart';
import '../core/camo_button.dart';
import '../core/tactical_ui.dart';
import '../core/fun_moments.dart';
import 'settings_screen.dart';
import 'season_settings_screen.dart';
import 'norms_settings_screen.dart';
import 'calculator_screen.dart';
import 'scan_screen.dart';
import 'kit_issue_screen.dart';
import 'transfer_pick_screen.dart';
import 'official_norms_screen.dart';
import 'admin_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: TacBackdrop(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TacHeader(
              callsign: 'Меню',
              subtitle: FunCopy.menuLine(),
            ),
            const SizedBox(height: 22),
            _tile(
              Icons.hub_rounded,
              CamoTone.olive,
              'Адмін',
              'Mac, Windows і цей телефон: зв’язок і оновлення без кабелю',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminScreen())),
            ),
            _tile(
              Icons.qr_code_scanner_rounded,
              CamoTone.moss,
              'Сканер QR',
              'Мішки й ящики: підтвердити, відхилити або змінити кількість',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScanScreen())),
            ),
            _tile(
              Icons.checkroom_rounded,
              CamoTone.khaki,
              'Комплект 1 особі',
              'Зима / Літо / Видача на прізвище, з розмірами',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const KitIssueScreen())),
            ),
            _tile(
              Icons.swap_horiz_rounded,
              CamoTone.brown,
              'Переміщення між складами',
              'ООС ↔ ППД: списати з одного, зарахувати на інший',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TransferPickScreen())),
            ),
            _tile(
              Icons.ac_unit_rounded,
              CamoTone.deep,
              'Сезонні списки',
              'Що входить у Зиму, Літо і Видачу',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SeasonSettingsScreen())),
            ),
            _tile(
              Icons.menu_book_rounded,
              CamoTone.olive,
              'Норми',
              'СВ, ВМС, ПС, ДШВ, ССО: назва, строк, мирний і воєнний час',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OfficialNormsScreen())),
            ),
            _tile(
              Icons.tune_rounded,
              CamoTone.moss,
              'Норми видачі',
              'Скільки речей на 1 особу (для аналізу комплектів)',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NormsSettingsScreen())),
            ),
            _tile(
              Icons.analytics_rounded,
              CamoTone.khaki,
              'Аналіз комплектів',
              'Скільки осіб можна одягнути зараз',
              () => _openCalcPicker(),
            ),
            _tile(
              Icons.settings_rounded,
              CamoTone.brown,
              'Налаштування',
              'Сервер, склади, розмірні сітки, тема',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(height: 12),
            _helpCard(),
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(FunCopy.splashHint(),
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w700)),
                    backgroundColor: AppColors.card,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Text(
                  'W-Node  $_version',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _openCalcPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: TacSheet.shape,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 16),
            Text('Який комплект порахувати?',
                style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 12),
            CamoButton(
              label: 'Зима',
              icon: Icons.ac_unit_rounded,
              tone: CamoTone.deep,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CalculatorScreen(
                            seasonKey: 'winter', seasonName: 'Зима')));
              },
            ),
            const SizedBox(height: 8),
            CamoButton(
              label: 'Літо',
              icon: Icons.wb_sunny_rounded,
              tone: CamoTone.khaki,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CalculatorScreen(
                            seasonKey: 'summer', seasonName: 'Літо')));
              },
            ),
            const SizedBox(height: 8),
            CamoButton(
              label: 'Видача',
              icon: Icons.handyman_rounded,
              tone: CamoTone.moss,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CalculatorScreen(
                            seasonKey: 'inventory', seasonName: 'Видача')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, CamoTone tone, String title, String subtitle,
      VoidCallback onTap) {
    const ink = Color(0xFFF4F0E4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CamoPlate(
        tone: tone,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: ink, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: ink.withOpacity(0.78),
                          fontSize: 12,
                          height: 1.25)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: ink),
          ],
        ),
      ),
    );
  }

  Widget _helpCard() {
    return TacCard(
      accent: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Як користуватись на телефоні',
                style: TextStyle(
                    color: AppColors.textMain, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          _helpLine('Огляд', 'картина складу: залишки, комплекти, проблеми'),
          _helpLine('Сканер', 'QR на мішку: розмір, потім підтвердити. Ліхтарик зверху'),
          _helpLine('Кому', 'у сканері вибери прізвище — в історії буде «кому»'),
          _helpLine('Скасувати', 'після видачі 8 сек є кнопка «Скасувати», або стрілка назад у сканері'),
          _helpLine('Офлайн', 'без мережі все пишеться на телефон і саме піде на комп\'ютер'),
          _helpLine('Комплект', 'Меню → Комплект 1 особі: прізвище, Зима/Літо, розміри, видати все'),
          _helpLine('Норми', 'Меню → Норми: офіційні таблиці МОУ по родах військ'),
          _helpLine('Переміщення', 'свайп вправо на речі або Меню → ООС ↔ ППД'),
          _helpLine('Свайп вправо', 'додати річ у Зиму / Літо / Видачу'),
          _helpLine('Свайп вліво', 'прибрати позицію в архів'),
          _helpLine('Історія', 'що змінили на ПК або на телефоні'),
        ],
      ),
    );
  }

  Widget _helpLine(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(title,
                style: TextStyle(
                    color: AppColors.accentBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
          Expanded(
            child: Text(text,
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
