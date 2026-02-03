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
    // Тут мы получаем данные.
    // ВАЖНО: Чтобы имена появились, следующим шагом нам нужно будет обновить db_service.dart
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
        title: Text("Історія операцій",
            style: TextStyle(
                color: AppColors.textMain, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textMain),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
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
                        horizontal: 16, vertical: 10),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) => _buildLogCard(_logs[i]),
                  ),
                ),
    );
  }

  // Красивая заглушка, если пусто
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off,
              size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 15),
          Text("Історія порожня",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    // 1. Безопасное получение данных
    String device = log['device'] ?? "Unknown";
    String details = log['details'] ?? "Без опису";
    String timestamp = log['timestamp'] ?? "";

    // Если дата длинная, обрезаем секунды для красоты
    if (timestamp.length > 16) {
      timestamp = timestamp.substring(0, 16);
    }

    // ЛОГИКА ИМЕНИ: Если имя есть - показываем, если нет - пишем ID
    String itemName =
        log['item_name'] ?? "Товар (ID: ${log['item_id'] ?? '?'})";
    if (itemName == "???") itemName = "Видалений товар #${log['item_id']}";

    // 2. Иконка устройства
    IconData deviceIcon = Icons.help_outline;
    if (device == "PC")
      deviceIcon = Icons.computer;
    else if (device == "Phone") deviceIcon = Icons.smartphone;

    // 3. Определение цвета и иконки по типу действия
    String type = log['action_type'] ?? "";
    Color color = Colors.blue; // Стандартный цвет
    IconData actionIcon = Icons.info;

    if (type.toLowerCase().contains("додано") ||
        type.toLowerCase().contains("створено")) {
      color = Colors.green;
      actionIcon = Icons.add_circle_outline;
    } else if (type.toLowerCase().contains("видал")) {
      color = Colors.redAccent;
      actionIcon = Icons.delete_outline;
    } else if (type.toLowerCase().contains("зміна") ||
        type.toLowerCase().contains("редаг")) {
      color = Colors.orange;
      actionIcon = Icons.edit_note;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(15),
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(
                    color: color, width: 5)), // Цветная полоска слева
          ),
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Верхняя строка: Иконка действия + Название товара
              Row(
                children: [
                  Icon(actionIcon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(itemName,
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Детали операции
              Text(details,
                  style: TextStyle(
                      color: AppColors.textMain.withOpacity(0.8),
                      fontSize: 14)),

              Divider(color: Colors.grey.withOpacity(0.2), height: 20),

              // Нижняя строка: Время и Устройство
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(timestamp,
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(deviceIcon, size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(device,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.accent,
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

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Очищення", style: TextStyle(color: AppColors.textMain)),
        content: Text("Видалити всю історію операцій?",
            style: TextStyle(color: AppColors.textMain)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Скасувати",
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, shape: const StadiumBorder()),
              onPressed: () {
                Navigator.pop(ctx);
                _clearLogs();
              },
              child: const Text("Видалити",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
