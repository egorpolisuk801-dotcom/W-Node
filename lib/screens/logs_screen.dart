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
        title: Text("Історія змін",
            style: TextStyle(
                color: AppColors.textMain, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textMain),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: () => _showClearDialog(),
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _logs.isEmpty
              ? Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history,
                        size: 60, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 10),
                    Text("Історія порожня",
                        style: TextStyle(color: Colors.grey)),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  color: AppColors.accent,
                  backgroundColor: AppColors.bg,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) => _buildLogCard(_logs[i]),
                  ),
                ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    // 1. Получаем устройство из базы
    String device = log['device'] ?? "Unknown";
    String details = log['details'] ?? "";

    // 2. Иконка устройства
    IconData deviceIcon = Icons.help_outline;
    if (device == "PC")
      deviceIcon = Icons.computer;
    else if (device == "Phone") deviceIcon = Icons.smartphone;

    // 3. Цвета
    String type = log['action_type'] ?? "";
    Color color = AppColors.accentBlue;
    IconData actionIcon = Icons.info;

    if (type.contains("Додано") || type.contains("Створено")) {
      color = Colors.green;
      actionIcon = Icons.add_circle;
    } else if (type.contains("Видалення")) {
      color = Colors.red;
      actionIcon = Icons.delete;
    } else if (type.contains("Зміна")) {
      color = Colors.orange;
      actionIcon = Icons.edit;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
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
                offset: const Offset(3, 3),
                blurRadius: 5),
          ],
          border: Border.all(color: color.withOpacity(0.1))),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(actionIcon, color: color, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(log['item_name'] ?? "???",
                            style: TextStyle(
                                color: AppColors.textMain,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                            overflow: TextOverflow.ellipsis)),
                    Icon(deviceIcon, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(device,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(details,
                    style: TextStyle(
                        color: AppColors.textMain.withOpacity(0.8),
                        fontSize: 14)),
                const SizedBox(height: 6),
                Text(log['timestamp'] ?? "",
                    style: TextStyle(
                        color: Colors.grey.withOpacity(0.6), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Очищення", style: TextStyle(color: AppColors.textMain)),
        content: Text("Видалити всю історію (на телефоні та в хмарі)?",
            style: TextStyle(color: AppColors.textMain)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Ні", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, shape: const StadiumBorder()),
              onPressed: () {
                Navigator.pop(ctx);
                _clearLogs();
              },
              child: const Text("Видалити все",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
