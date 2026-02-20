import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../core/app_colors.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
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
      appBar: AppBar(
        title: Text("ІСТОРІЯ ОПЕРАЦІЙ",
            style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textMain),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep,
                color: Colors.redAccent, size: 28),
            onPressed: () => _showClearDialog(),
            tooltip: "Очистити історію",
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _logs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  color: AppColors.accent,
                  backgroundColor: AppColors.bg,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) => _buildLogCard(_logs[i]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off,
              size: 80, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 15),
          const Text("Журнал операцій порожній",
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    String device = log['device'] ?? "Unknown";
    String details = log['details'] ?? "Без опису";
    String timestamp = log['timestamp'] ?? "";

    // Перевіряємо статус синхронізації
    bool isUnsynced = log['is_unsynced'] == 1 || log['is_unsynced'] == true;

    if (timestamp.length > 16) {
      timestamp = timestamp.substring(0, 16);
    }

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
    Color color = Colors.blue;
    IconData actionIcon = Icons.info_outline;

    if (type.contains("додано") || type.contains("створено")) {
      color = const Color(0xFF00E676);
      actionIcon = Icons.add_circle;
    } else if (type.contains("видал") || type.contains("вилучено")) {
      color = const Color(0xFFFF3D00);
      actionIcon = Icons.remove_circle;
    } else if (type.contains("зміна") || type.contains("редаг")) {
      color = Colors.orangeAccent;
      actionIcon = Icons.edit_note;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 6)),
          ),
          padding: const EdgeInsets.all(16),
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

              _buildSmartDetails(details, color),

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
                        const Icon(Icons.cloud_upload_outlined,
                            size: 14, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        const Text("Очікує",
                            style: TextStyle(
                                color: Colors.orangeAccent,
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
                      style: const TextStyle(
                          color: Colors.white70,
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
                      style: const TextStyle(
                          color: Colors.white,
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: Colors.redAccent.withOpacity(0.5), width: 1.5)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Очищення",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            "Видалити всю історію операцій? Цю дію неможливо скасувати.",
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Скасувати",
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                _clearLogs();
              },
              child: const Text("Видалити",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
