import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/db_service.dart';

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
    setState(() => _isLoading = true);
    try {
      final logs = await DBService().getLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ФУНКЦИЯ ОЧИСТКИ
  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.bg,
              title: Text("Очистити історію?",
                  style: TextStyle(color: AppColors.textMain)),
              content: Text("Це видалить всі записи з телефону.",
                  style: TextStyle(color: Colors.grey)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text("Ні")),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text("Так", style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm == true) {
      await DBService().clearLogs();
      _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Історія (Офлайн)",
            style: TextStyle(
                color: AppColors.textMain, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textMain),
        elevation: 0,
        actions: [
          // КНОПКА ОЧИСТКИ
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _clearHistory,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.accentBlue),
            onPressed: _loadLogs,
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
                      Icon(Icons.history_toggle_off,
                          size: 80, color: Colors.grey.withOpacity(0.2)),
                      SizedBox(height: 10),
                      Text("Історія порожня",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _logs.length,
                  itemBuilder: (ctx, i) {
                    final log = _logs[i];
                    return _buildLogCard(log);
                  },
                ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    IconData icon = Icons.info_outline;
    Color color = Colors.grey;
    String type = log['type']?.toString() ?? 'info';

    switch (type) {
      case 'add':
        icon = Icons.add_circle_outline;
        color = Colors.green;
        break;
      case 'edit':
        icon = Icons.edit_outlined;
        color = AppColors.accentBlue;
        break;
      case 'error':
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowTop,
              offset: Offset(-2, -2),
              blurRadius: 4),
          BoxShadow(
              color: AppColors.shadowBottom,
              offset: Offset(2, 2),
              blurRadius: 4),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(log['action']?.toString() ?? "",
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(log['time']?.toString() ?? "",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                SizedBox(height: 4),
                Text(log['details']?.toString() ?? "",
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
