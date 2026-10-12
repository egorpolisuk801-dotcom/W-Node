import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/tactical_ui.dart';
import '../core/user_config.dart';
import '../services/db_service.dart';
import '../services/last_action.dart';
import '../services/qr_parser.dart';

class TransferSheet {
  static Future<bool> show(
    BuildContext context, {
    required Map<String, dynamic> item,
    String? preselectedSize,
    VoidCallback? onDone,
  }) async {
    final warehouses = UserConfig().warehouses;
    final srcWh = '${item['warehouse'] ?? ''}'.trim();
    final destOptions =
        warehouses.where((w) => w.toLowerCase() != srcWh.toLowerCase()).toList();
    if (destOptions.isEmpty) {
      if (context.mounted) {
        LastAction.showSnack(
            context, 'Немає іншого складу для переміщення',
            error: true);
      }
      return false;
    }

    final sizes = QrParser.sizesOf(item);
    final sizeKeys = QrParser.realSizeKeys(sizes);
    final needsSize = QrParser.needsSizePick(item) && sizeKeys.isNotEmpty;

    String destWh = destOptions.first;
    String? sizeKey = preselectedSize;
    if (sizeKey != null && sizeKeys.isNotEmpty && !sizeKeys.contains(sizeKey)) {
      sizeKey = null;
    }
    if (!needsSize) sizeKey = null;
    if (sizeKeys.length == 1) sizeKey = sizeKeys.first;
    int qty = 1;

    int stockOf(String? key) {
      if (key != null && key.isNotEmpty) {
        return int.tryParse('${sizes[key]}') ?? 0;
      }
      return int.tryParse('${item['total'] ?? item['total_quantity']}') ?? 0;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: TacSheet.shape,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          final stock = stockOf(sizeKey);
          if (qty > stock && stock > 0) qty = stock;
          final locked = needsSize && (sizeKey == null || sizeKey!.isEmpty);
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TacSheet.handle(),
                const SizedBox(height: 16),
                Text('Переміщення', style: TacStyle.stencil),
                const SizedBox(height: 6),
                Text('${item['name']}',
                    style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
                const SizedBox(height: 4),
                Text('зараз: $srcWh  •  $stock шт${sizeKey != null ? ' ($sizeKey)' : ''}',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 16),
                Text('Куди',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: destOptions.map((wh) {
                    final on = destWh == wh;
                    return GestureDetector(
                      onTap: () => setModal(() => destWh = wh),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.accentBlue.withOpacity(0.18)
                              : AppColors.bg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: on
                                  ? AppColors.accentBlue
                                  : AppColors.border,
                              width: on ? 2 : 1),
                        ),
                        child: Text(wh,
                            style: TextStyle(
                                color: on
                                    ? AppColors.accentBlue
                                    : AppColors.textMain,
                                fontWeight: FontWeight.w900)),
                      ),
                    );
                  }).toList(),
                ),
                if (needsSize) ...[
                  const SizedBox(height: 16),
                  Text('Розмір',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sizeKeys.map((key) {
                      final on = sizeKey == key;
                      final q = int.tryParse('${sizes[key]}') ?? 0;
                      return GestureDetector(
                        onTap: () => setModal(() {
                          sizeKey = key;
                          qty = 1;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: on
                                ? AppColors.accent.withOpacity(0.16)
                                : AppColors.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color:
                                    on ? AppColors.accent : AppColors.border,
                                width: on ? 2 : 1),
                          ),
                          child: Text('$key  •  $q',
                              style: TextStyle(
                                  color: on
                                      ? AppColors.accent
                                      : AppColors.textMain,
                                  fontWeight: FontWeight.w800)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Кількість',
                        style: TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    _qtyBtn(Icons.remove, () {
                      if (qty > 1) setModal(() => qty--);
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('$qty',
                          style: TextStyle(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w900,
                              fontSize: 22)),
                    ),
                    _qtyBtn(Icons.add, () {
                      if (qty < stock) setModal(() => qty++);
                    }),
                  ],
                ),
                const SizedBox(height: 18),
                TacButton(
                  label: locked
                      ? 'Вибери розмір'
                      : stock <= 0
                          ? 'Немає залишку'
                          : 'Перемістити $qty шт → $destWh',
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.accentBlue,
                  onTap: locked || stock <= 0
                      ? () {}
                      : () async {
                            HapticFeedback.mediumImpact();
                            final sourceId = item['id'] as int;
                            final res = await DBService().transferStock(
                              sourceLocalId: sourceId,
                              destWarehouse: destWh,
                              sizeKey: sizeKey,
                              qty: qty,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx, res.ok);
                            if (!context.mounted) return;
                            if (!res.ok) {
                              LastAction.showSnack(context, res.message,
                                  error: true);
                              return;
                            }
                            LastAction.rememberBatch([
                              LastStockAction(
                                localId: sourceId,
                                sizeKey: res.sizeKey,
                                delta: -res.qty,
                                message: res.message,
                              ),
                              LastStockAction(
                                localId: res.destLocalId,
                                sizeKey: res.sizeKey,
                                delta: res.qty,
                                message: res.message,
                              ),
                            ]);
                            LastAction.showSnack(context, res.message,
                                onUndone: onDone);
                            onDone?.call();
                          },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
    return ok == true;
  }

  static Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textMain, size: 20),
      ),
    );
  }
}
