import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/camo_button.dart';
import '../core/shell_controller.dart';
import '../core/tactical_ui.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'logs_screen.dart';
import 'menu_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    HomeScreen(),
    LogsScreen(),
    MenuScreen(),
  ];

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Огляд'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Склад'),
    (Icons.history_outlined, Icons.history_rounded, 'Журнал'),
    (Icons.apps_outlined, Icons.apps_rounded, 'Меню'),
  ];

  @override
  void initState() {
    super.initState();
    ShellController.tab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final next = ShellController.tab.value;
    if (next != _index && mounted) {
      setState(() => _index = next.clamp(0, _pages.length - 1));
    }
  }

  @override
  void dispose() {
    ShellController.tab.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: SafeArea(
          top: false,
          child: VolGlass(
            radius: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final on = _index == i;
                final tab = _tabs[i];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: CamoPlate(
                      tone: CamoTone.values[i],
                      dim: !on,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      onTap: () {
                        setState(() => _index = i);
                        ShellController.tab.value = i;
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(on ? tab.$2 : tab.$1,
                              color: styleInk(CamoTone.values[i]), size: 20),
                          const SizedBox(height: 3),
                          Text(tab.$3,
                              style: TextStyle(
                                  color: styleInk(CamoTone.values[i]),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
