import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class FunCopy {
  static String hello() {
    final n = DateTime.now();
    final h = n.hour;
    final d = n.weekday;
    if (d == DateTime.friday && h >= 16) return 'Пʼятниця. Майже.';
    if ((d == DateTime.saturday || d == DateTime.sunday) && h < 12) {
      return 'Вихідний. Склад не знає.';
    }
    if (h < 6) return 'Тиха ніч';
    if (h < 11) return 'Доброго ранку';
    if (h < 17) return 'Добрий день';
    if (h < 22) return 'Добрий вечір';
    return 'Ще не спиш?';
  }

  static String splashHint() {
    const lines = [
      'Ящики люблять порядок',
      'Розмір — половина справи',
      'Один скан — і вже в обліку',
      'Не шукай — скануй',
      'Берці без розміру — як чай без цукру',
      'Ящик за ящиком — і вже вечір',
      'Полиці памʼятають усе',
    ];
    return lines[DateTime.now().second % lines.length];
  }

  static String todayLine(int hits) {
    if (hits <= 0) return 'Склад ще тихий. Перша видача сьогодні — твоя.';
    if (hits == 1) return 'Перша видача сьогодні вже є. Поїхали далі.';
    final word = (hits % 10 >= 2 && hits % 10 <= 4 && (hits % 100 < 10 || hits % 100 > 20))
        ? 'рухи'
        : 'рухів';
    if (hits < 8) return 'Сьогодні вже $hits $word. Темп хороший.';
    return 'Сьогодні $hits $word. Склад тебе чує.';
  }

  static String? milestone(int hits) {
    switch (hits) {
      case 5:
        return 'Пʼять рухів. Розігрівся.';
      case 10:
        return 'Десять. Склад уже в ритмі.';
      case 25:
        return '25 сьогодні. Це вже зміна.';
      default:
        return null;
    }
  }

  static const tips = [
    'Потягни екран вниз — полиці освіжаться',
    'У сканері зверху є ліхтарик. QR його любить',
    'Довге натискання на привітання — випадкова фраза',
    'Після видачі 8 секунд можна скасувати',
    'Натисни цю смужку — буде інша підказка',
    'Комплект одній особі — з Меню, не зі сканера',
  ];

  static String tip(int i) => tips[i % tips.length];

  static String scanIdle() =>
      'Наведи на QR. Підтвердити — видати одну штуку.\nЦе швидко. Майже магія.';

  static String emptyStock() =>
      'Тут тихо, як у порожньому ящику.\nПотягни вниз — підтягнемо склад.';

  static String emptySearch() =>
      'Такої речі на полицях не видно.\nСпробуй інше слово або фільтр.';

  static String emptyLogsToday() =>
      'Сьогодні ніхто нічого не чіпав.\nАбо всі святі — або зміна ще попереду.';

  static String emptyLogsAll() =>
      'Журнал чистий, як нова накладна.\nПерша дія з\'явиться тут.';

  static String afterIssue(String person) {
    final n = person.trim();
    if (n.isEmpty) return 'Комплект пішов. Гарна робота.';
    final first = n.split(RegExp(r'\s+')).first;
    return 'Комплект для $first зібрано. Можна дихати.';
  }

  static String afterScan(bool issued) =>
      issued ? 'Є. Пішло зі складу.' : 'Прийнято. Полиця стала важчою.';

  static String menuLine() => 'Сканер, видача, переміщення — і трохи налаштувань';
}

class FunStamp {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? hint,
    IconData icon = Icons.check_rounded,
  }) async {
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'stamp',
      barrierColor: Colors.black.withOpacity(0.28),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, __) =>
          _StampDialog(title: title, hint: hint, icon: icon),
      transitionBuilder: (ctx, a, _, child) {
        final t = Curves.easeOutBack.transform(a.value);
        return Opacity(
          opacity: a.value,
          child: Transform.scale(scale: 0.72 + 0.28 * t, child: child),
        );
      },
    );
  }
}

class _StampDialog extends StatefulWidget {
  final String title;
  final String? hint;
  final IconData icon;
  const _StampDialog({required this.title, this.hint, required this.icon});

  @override
  State<_StampDialog> createState() => _StampDialogState();
}

class _StampDialogState extends State<_StampDialog> {
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _autoClose = Timer(const Duration(milliseconds: 1100), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: _StampCard(
            title: widget.title, hint: widget.hint, icon: widget.icon),
      ),
    );
  }
}

class _StampCard extends StatelessWidget {
  final String title;
  final String? hint;
  final IconData icon;
  const _StampCard({required this.title, this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(
              painter: _BurstPainter(AppColors.accent),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.onAccent, size: 34),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final Color color;
  _BurstPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()..color = color.withOpacity(0.28);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * 38, c.dy + math.sin(a) * 38),
        i.isEven ? 3.5 : 2.2,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.color != color;
}
