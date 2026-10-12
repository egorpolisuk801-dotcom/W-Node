import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/tactical_ui.dart';
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
    final cardColor = AppColors.card;
    final accentGreen = AppColors.accent;
    final accentRed = AppColors.danger;
    final accentBlue = AppColors.accentBlue;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: TacAppBar(
        title: widget.seasonName,
        code: 'Аналіз',
      ),
      body: TacBackdrop(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: accentGreen))
            : _buildDashboard(cardColor, accentGreen, accentRed, accentBlue),
      ),
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
          TacCard(
            accent: totalReady > 0 ? green : red,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            child: Column(
              children: [
                Text(
                  "Готові комплекти до видачі",
                  style: TacStyle.stencil.copyWith(
                      color: totalReady > 0 ? AppColors.muted : red,
                      fontSize: 11),
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
                Text(
                  "осіб",
                  style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TacCard(
            child: Text(
              "Комплект = повний набір зі списку сезону на 1 особу. "
              "Якщо тут 0 — якась річ закінчилась і блокує видачу.",
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
          if (isDeficit) ...[
            TacCard(
              accent: red,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: red, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Критичний дефіцит",
                            style: TextStyle(
                                color: red,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          totalReady == 0
                              ? "Неможливо зібрати жодного комплекту. Причина:\n$bottleneck"
                              : "Одягу вистачає на $clothingLimit осіб, але видачу блокує:\n$bottleneck",
                          style: TextStyle(
                              color: AppColors.textMain, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          const TacSection(code: 'Розміри', hint: 'одяг'),
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

                      return TacCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "РОЗМІР  $size",
                              style: TextStyle(
                                  color: AppColors.textMain,
                                  fontSize: 16,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w900),
                            ),
                            Text(
                              "$count шт",
                              style: TextStyle(
                                  color: blue,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16),
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
