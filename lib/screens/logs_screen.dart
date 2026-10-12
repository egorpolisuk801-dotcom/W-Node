import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../core/app_colors.dart';
import '../core/camo_button.dart';
import '../core/log_utils.dart';
import '../core/tactical_ui.dart';
import '../core/fun_moments.dart';
import '../core/shell_controller.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _todayOnly = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    ShellController.tab.addListener(_onTab);
  }

  void _onTab() {
    if (ShellController.tab.value == 2 && mounted) {
      _loadLogs();
    }
  }

  @override
  void dispose() {
    ShellController.tab.removeListener(_onTab);
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final logs = await DBService().getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    setState(() => _isLoading = true);
    await DBService().clearLogs();
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TacAppBar(
        title: 'Журнал',
        code: 'Журнал',
        implyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep, color: AppColors.danger, size: 26),
            onPressed: () => _showClearDialog(),
            tooltip: "Очистити історію",
          )
        ],
      ),
      body: TacBackdrop(
        child: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      _filterChip('Сьогодні', today: true),
                      const SizedBox(width: 8),
                      _filterChip('Вся історія', today: false),
                    ],
                  ),
                ),
                Expanded(
                  child: _visibleLogs.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadLogs,
                          color: AppColors.accent,
                          backgroundColor: AppColors.bg,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _visibleLogs.length,
                            itemBuilder: (ctx, i) =>
                                _buildLogCard(_visibleLogs[i]),
                          ),
                        ),
                ),
              ],
            ),
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleLogs {
    if (!_todayOnly) return _logs;
    return _logs
        .where((l) => LogUtils.isWithinHours(l['timestamp'], 24))
        .toList();
  }

  Widget _filterChip(String label, {required bool today}) {
    final on = _todayOnly == today;
    return GestureDetector(
      onTap: () => setState(() => _todayOnly = today),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.accent.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: on ? AppColors.accent : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: on ? AppColors.accent : AppColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 56, color: AppColors.accent.withOpacity(0.45)),
            const SizedBox(height: 14),
            Text(
                _todayOnly ? 'Тихий день' : 'Порожній журнал',
                style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
                _todayOnly
                    ? FunCopy.emptyLogsToday()
                    : FunCopy.emptyLogsAll(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.muted, fontSize: 14, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    String device = log['device'] ?? "Unknown";
    String details = (log['details'] ?? "").toString();
    String timestamp = LogUtils.timeLabel(log['timestamp']);
    bool isUnsynced = log['is_unsynced'] == 1 || log['is_unsynced'] == true;

    String fullItemName =
        log['item_name'] ?? "Товар (ID: ${log['item_id'] ?? '?'})";
    if (fullItemName == "???")
      fullItemName = "Видалений товар #${log['item_id']}";

    String itemName = fullItemName;
    String sizeTag = "";
    if (fullItemName.contains("(Розмір:")) {
      var parts = fullItemName.split("(Розмір:");
      itemName = parts[0].trim();
      sizeTag = parts[1].replaceAll(")", "").trim();
    }

    IconData deviceIcon = Icons.help_outline;
    if (device == "PC") {
      deviceIcon = Icons.computer;
    } else if (device == "Phone") {
      deviceIcon = Icons.smartphone;
    }

    String type = (log['action_type'] ?? "").toString().toLowerCase();
    Color color = const Color(0xFFC4B07A);
    IconData actionIcon = Icons.info_outline;

    if (type.contains("переміщ")) {
      color = const Color(0xFFC4B07A);
      actionIcon = Icons.swap_horiz_rounded;
    } else if (type.contains("додано") || type.contains("створено")) {
      color = const Color(0xFF8FA86A);
      actionIcon = Icons.add_circle;
    } else if (type.contains("видал") || type.contains("вилучено")) {
      color = const Color(0xFFA87848);
      actionIcon = Icons.remove_circle;
    } else if (type.contains("зміна") || type.contains("редаг")) {
      color = AppColors.sun;
      actionIcon = Icons.edit_note;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TacCard(
        accent: color,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(actionIcon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(itemName,
                            style: TextStyle(
                                color: AppColors.textMain,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (sizeTag.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: color.withOpacity(0.5), width: 1)),
                            child: Text("Розмір: $sizeTag",
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ChangeBadge(details: details, color: color),

              const SizedBox(height: 12),
              Divider(color: Colors.grey.withOpacity(0.2), height: 1),
              const SizedBox(height: 12),

              // ПІДВАЛ (ЧАС, СТАТУС ТА ПРИСТРІЙ)
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(timestamp,
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),

                  // 🔥 ОСЬ ЦЕЙ СТАТУС СИНХРОНІЗАЦІЇ
                  if (isUnsynced)
                    Row(
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 14, color: AppColors.sun),
                        const SizedBox(width: 4),
                        Text("Очікує",
                            style: TextStyle(
                                color: AppColors.sun,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.cloud_done_rounded,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text("В хмарі",
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),

                  const SizedBox(width: 12),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.accentBlue.withOpacity(0.3))),
                    child: Row(
                      children: [
                        Icon(deviceIcon, size: 12, color: AppColors.accentBlue),
                        const SizedBox(width: 4),
                        Text(device,
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildSmartDetails(String details, Color actionColor) {
    if (details.contains('➔')) {
      List<String> parts = details.split('➔').map((e) => e.trim()).toList();

      if (parts.length == 3) {
        String was = parts[0].replaceAll('Було:', '').trim();
        String delta = parts[1].trim();
        String became = parts[2].replaceAll('Стало:', '').trim();

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("БУЛО",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  Text(was,
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: actionColor.withOpacity(0.5))),
                child: Text(delta,
                    style: TextStyle(
                        color: actionColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("СТАЛО",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  Text(became,
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        );
      }
    }
    return Text(details,
        style: TextStyle(
            color: AppColors.textMain.withOpacity(0.8), fontSize: 14));
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: TacSheet.dialog(AppColors.danger),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text("Очищення",
                style: TextStyle(
                    color: AppColors.textMain, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            "Видалити всю історію операцій? Цю дію неможливо скасувати.",
            style: TextStyle(color: Colors.grey)),
        actions: [
          CamoButton(
            label: 'Скасувати',
            tone: CamoTone.moss,
            compact: true,
            onPressed: () => Navigator.pop(ctx),
          ),
          CamoButton(
            label: 'Видалити',
            tone: CamoTone.brown,
            compact: true,
            onPressed: () {
              Navigator.pop(ctx);
              _clearLogs();
            },
          ),
        ],
      ),
    );
  }
}
