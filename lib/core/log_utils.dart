import 'package:flutter/material.dart';
import 'app_colors.dart';

class LogUtils {
  static DateTime? parseTime(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  static bool isWithinHours(dynamic raw, int hours) {
    final dt = parseTime(raw);
    if (dt == null) return true;
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return true;
    return diff.inHours < hours;
  }

  static String timeLabel(dynamic raw) {
    final dt = parseTime(raw);
    if (dt == null) return raw?.toString() ?? '';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) return '$hh:$mm';
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}  $hh:$mm';
  }

  static Color actionColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('переміщ')) return AppColors.accentBlue;
    if (t.contains('додано') || t.contains('створено')) return AppColors.accent;
    if (t.contains('видал') || t.contains('видано') || t.contains('вилучено')) {
      return AppColors.danger;
    }
    if (t.contains('зміна') || t.contains('редаг')) return AppColors.warning;
    return AppColors.accentBlue;
  }

  static ({String? was, String? delta, String? became, String fallback})
      parseChange(String details) {
    if (details.contains('➔')) {
      final parts = details.split('➔').map((e) => e.trim()).toList();
      if (parts.length == 3) {
        return (
          was: parts[0].replaceAll('Було:', '').trim(),
          delta: parts[1].trim(),
          became: parts[2].replaceAll('Стало:', '').trim(),
          fallback: details,
        );
      }
    }
    return (was: null, delta: null, became: null, fallback: details);
  }
}

class ChangeBadge extends StatelessWidget {
  final String details;
  final Color color;
  final bool compact;

  const ChangeBadge(
      {super.key,
      required this.details,
      required this.color,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final parsed = LogUtils.parseChange(details);
    if (parsed.was == null) {
      if (details.isEmpty) return const SizedBox.shrink();
      return Text(parsed.fallback,
          maxLines: compact ? 1 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 11 : 13));
    }

    return Container(
      padding: EdgeInsets.symmetric(
          vertical: compact ? 6 : 10, horizontal: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _col('БУЛО', parsed.was!, false),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(parsed.delta!,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 13 : 16)),
          ),
          _col('СТАЛО', parsed.became!, true),
        ],
      ),
    );
  }

  Widget _col(String label, String value, bool end) {
    return Column(
      crossAxisAlignment:
          end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800)),
        Text(value,
            style: TextStyle(
                color: AppColors.textMain,
                fontSize: compact ? 14 : 18,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}
