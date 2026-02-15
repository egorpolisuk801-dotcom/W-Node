import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/smart_calculator.dart';

class CalculatorScreen extends StatefulWidget {
  final String seasonName;
  final String seasonKey;

  const CalculatorScreen(
      {super.key, required this.seasonName, required this.seasonKey});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _calcResult = {};

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() => _isLoading = true);

    try {
      final allItems = await DBService().getAllItems();
      final activeIds = await DBService().getCustomList(widget.seasonKey);

      // 🔥 ТЕПЕР ФУНКЦІЯ АСИНХРОННА І ЧЕКАЄ НАЛАШТУВАННЯ З ПАМ'ЯТІ ТЕЛЕФОНУ
      final result = await SmartCalculator.calculateSeason(
          allItems, activeIds, widget.seasonKey);

      setState(() {
        _calcResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _calcResult = {'error': 'Критична помилка завантаження: $e'};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF121212);
    const cardColor = Color(0xFF1E1E1E);
    const accentGreen = Color(0xFF00E676);
    const accentRed = Color(0xFFFF3D00);
    const accentBlue = Color(0xFF00B0FF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "АНАЛІЗ: ${widget.seasonName}",
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 2),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGreen))
          : _buildDashboard(cardColor, accentGreen, accentRed, accentBlue),
    );
  }

  Widget _buildDashboard(Color cardColor, Color green, Color red, Color blue) {
    if (_calcResult.containsKey('error')) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _calcResult['error'].toString(),
            style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    int totalReady = _calcResult['total_ready'] ?? 0;
    int clothingLimit = _calcResult['clothing_limit'] ?? 0;
    String bottleneck = _calcResult['bottleneck_item']?.toString() ?? "";

    Map<String, int> kitsBySize = {};
    if (_calcResult['kits_by_size'] != null) {
      try {
        kitsBySize = Map<String, int>.from(_calcResult['kits_by_size']);
      } catch (_) {}
    }

    bool isDeficit = bottleneck.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: totalReady > 0
                      ? green.withOpacity(0.5)
                      : red.withOpacity(0.5),
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: totalReady > 0
                        ? green.withOpacity(0.1)
                        : red.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5)
              ],
            ),
            child: Column(
              children: [
                Text(
                  "ГОТОВІ КОМПЛЕКТИ ДО ВИДАЧІ",
                  style: TextStyle(
                      color: totalReady > 0 ? Colors.grey : red,
                      fontSize: 14,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "$totalReady",
                  style: TextStyle(
                      color: totalReady > 0 ? green : red,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      height: 1),
                ),
                const Text(
                  "ОСІБ",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (isDeficit) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: red, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: red, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("КРИТИЧНИЙ ДЕФІЦИТ",
                            style: TextStyle(
                                color: red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          totalReady == 0
                              ? "Неможливо зібрати жодного комплекту. Причина:\n$bottleneck"
                              : "Одягу вистачає на $clothingLimit осіб, але видачу блокує:\n$bottleneck",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            "РОЗПОДІЛ ЗА РОЗМІРАМИ (ОДЯГ)",
            style: TextStyle(
                color: blue, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: kitsBySize.isEmpty
                ? Center(
                    child: Text(
                        "Немає даних по розмірах\n(Можливо, розміри різних речей не співпадають)",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])))
                : ListView.builder(
                    itemCount: kitsBySize.length,
                    itemBuilder: (context, index) {
                      String size = kitsBySize.keys.elementAt(index);
                      int count = kitsBySize[size]!;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Розмір: $size",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "$count шт",
                                style: TextStyle(
                                    color: blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
