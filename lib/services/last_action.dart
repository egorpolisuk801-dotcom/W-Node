import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'db_service.dart';

class LastStockAction {
  final int localId;
  final String? sizeKey;
  final int delta;
  final String message;
  final DateTime at;

  LastStockAction({
    required this.localId,
    required this.sizeKey,
    required this.delta,
    required this.message,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  bool get isFresh =>
      DateTime.now().difference(at) < const Duration(seconds: 20);
}

class LastAction {
  static List<LastStockAction> _batch = [];

  static LastStockAction? get current {
    if (_batch.isEmpty) return null;
    final last = _batch.last;
    return last.isFresh ? last : null;
  }

  static void remember(LastStockAction action) => _batch = [action];

  static void rememberBatch(List<LastStockAction> actions) {
    _batch = List<LastStockAction>.from(actions);
  }

  static void clear() => _batch = [];

  static Future<String> undo() async {
    if (current == null) return 'Немає що скасувати';
    final copy = _batch.reversed.toList();
    clear();
    for (final action in copy) {
      await DBService().applyStockDelta(
        localId: action.localId,
        sizeKey: action.sizeKey,
        delta: -action.delta,
        isUndo: true,
      );
    }
    if (copy.length == 1) {
      return 'Скасовано: ${copy.first.message}';
    }
    return 'Скасовано комплект (${copy.length} позицій)';
  }

  static void showSnack(BuildContext context, String message,
      {bool error = false, VoidCallback? onUndone}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final canUndo = !error && current != null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: TextStyle(
              color: error ? Colors.white : AppColors.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 14)),
      backgroundColor: error ? AppColors.danger : AppColors.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: error ? AppColors.danger : AppColors.accent)),
      duration: Duration(seconds: error ? 3 : 8),
      action: canUndo
          ? SnackBarAction(
              label: 'Скасувати',
              textColor: AppColors.accent,
              onPressed: () async {
                final res = await undo();
                if (!context.mounted) return;
                onUndone?.call();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res,
                      style: TextStyle(
                          color: res.startsWith('Помилка')
                              ? Colors.white
                              : AppColors.textMain,
                          fontWeight: FontWeight.w700)),
                  backgroundColor: res.startsWith('Помилка')
                      ? AppColors.danger
                      : AppColors.card,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              },
            )
          : null,
    ));
  }
}
