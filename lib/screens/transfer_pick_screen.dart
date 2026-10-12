import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/tactical_ui.dart';
import '../services/db_service.dart';
import 'transfer_sheet.dart';

class TransferPickScreen extends StatefulWidget {
  const TransferPickScreen({super.key});

  @override
  State<TransferPickScreen> createState() => _TransferPickScreenState();
}

class _TransferPickScreenState extends State<TransferPickScreen> {
  List<Map<String, dynamic>> _items = [];
  String _q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DBService().getAllItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((i) {
      if (_q.isEmpty) return true;
      final hay =
          '${i['name']} ${i['warehouse']} ${i['category']} ${i['location']}'
              .toLowerCase();
      return hay.contains(_q.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const TacAppBar(
        title: 'Переміщення',
        code: 'Переміщення',
      ),
      body: TacBackdrop(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              style: TextStyle(color: AppColors.textMain),
              decoration: TacField.of('Пошук речі…', icon: Icons.search),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      return TacCard(
                        margin: EdgeInsets.zero,
                        accent: AppColors.accentBlue,
                        onTap: () async {
                          await TransferSheet.show(context,
                              item: item, onDone: _load);
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['name']}',
                                      style: TextStyle(
                                          color: AppColors.textMain,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${item['warehouse'] ?? ''}  •  ${item['total'] ?? 0} шт',
                                      style: TextStyle(color: AppColors.muted)),
                                ],
                              ),
                            ),
                            Icon(Icons.swap_horiz_rounded,
                                color: AppColors.accentBlue),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
