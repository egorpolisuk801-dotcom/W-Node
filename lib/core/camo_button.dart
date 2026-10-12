import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Підсвітка клавіші. Сама клавіша завжди лісова, колір смужки різний.
enum CamoTone { olive, moss, khaki, brown, deep }

class CamoToneData {
  static Color glow(CamoTone tone) {
    switch (tone) {
      case CamoTone.olive:
        return const Color(0xFFC6D36A);
      case CamoTone.moss:
        return const Color(0xFF7FA04A);
      case CamoTone.khaki:
        return const Color(0xFFD2BE86);
      case CamoTone.brown:
        return const Color(0xFFA87848);
      case CamoTone.deep:
        return const Color(0xFF3E6A48);
    }
  }

  static Color base(CamoTone tone) {
    switch (tone) {
      case CamoTone.olive:
        return const Color(0xFF3A4624);
      case CamoTone.moss:
        return const Color(0xFF2C3A22);
      case CamoTone.khaki:
        return const Color(0xFF4A4030);
      case CamoTone.brown:
        return const Color(0xFF3A2E24);
      case CamoTone.deep:
        return const Color(0xFF1A2418);
    }
  }

  static List<Color> blotches(CamoTone tone) {
    switch (tone) {
      case CamoTone.olive:
        return const [
          Color(0xFF6E8430),
          Color(0xFF243018),
          Color(0xFFC4B06A),
          Color(0xFF4E6230),
          Color(0xFF1C2614),
        ];
      case CamoTone.moss:
        return const [
          Color(0xFF3E5428),
          Color(0xFF1E2A16),
          Color(0xFF8A9A48),
          Color(0xFF2A3820),
          Color(0xFF5C6E32),
        ];
      case CamoTone.khaki:
        return const [
          Color(0xFF8A7848),
          Color(0xFF3A3424),
          Color(0xFFC6B48A),
          Color(0xFF5A4E34),
          Color(0xFF2A2618),
        ];
      case CamoTone.brown:
        return const [
          Color(0xFF6A4A32),
          Color(0xFF241C16),
          Color(0xFFA89068),
          Color(0xFF3E3428),
          Color(0xFF4A3828),
        ];
      case CamoTone.deep:
        return const [
          Color(0xFF243222),
          Color(0xFF10160E),
          Color(0xFF4A5C30),
          Color(0xFF1A2216),
          Color(0xFF2E3A24),
        ];
    }
  }

  static CamoTone cycle(int index) =>
      CamoTone.values[index.abs() % CamoTone.values.length];
}

class WoodlandKeyPainter extends CustomPainter {
  final CamoTone tone;
  const WoodlandKeyPainter(this.tone);

  static const _spots = <List<double>>[
    [0.18, 0.35, 0.72, 0.90],
    [0.78, 0.28, 0.64, 0.80],
    [0.48, 0.72, 0.90, 0.70],
    [0.12, 0.78, 0.50, 0.55],
    [0.86, 0.70, 0.46, 0.62],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(rect, Paint()..color = CamoToneData.base(tone));
    final colors = CamoToneData.blotches(tone);
    for (var i = 0; i < _spots.length; i++) {
      final s = _spots[i];
      final blob = Rect.fromCenter(
        center: Offset(size.width * s[0], size.height * s[1]),
        width: size.shortestSide * s[2] + size.width * 0.25,
        height: size.shortestSide * s[3] + size.height * 0.35,
      );
      canvas.drawOval(blob, Paint()..color = colors[i]);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.42),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.42)),
    );
    final bar = size.height < 36 ? 3.0 : 5.0;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - bar, size.width, bar),
      Paint()..color = CamoToneData.glow(tone),
    );
    canvas.restore();
    canvas.drawRRect(
      r.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x66000000),
    );
    canvas.drawLine(
      Offset(10, 1.2),
      Offset(size.width - 10, 1.2),
      Paint()
        ..color = const Color(0x55E6DCC4)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant WoodlandKeyPainter oldDelegate) =>
      oldDelegate.tone != tone;
}

class CamoPlate extends StatelessWidget {
  final Widget child;
  final CamoTone tone;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool dim;

  const CamoPlate({
    super.key,
    required this.child,
    required this.tone,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final glow = CamoToneData.glow(tone);
    final plate = Opacity(
      opacity: onTap == null ? 0.42 : (dim ? 0.62 : 1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: dim
              ? const []
              : [
                  const BoxShadow(
                    color: Color(0x99000000),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: glow.withOpacity(0.42),
                    offset: const Offset(0, 7),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: WoodlandKeyPainter(tone),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
    if (onTap == null) return plate;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      child: plate,
    );
  }
}

class CamoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CamoTone tone;
  final bool vertical;
  final bool compact;
  final Widget? child;

  const CamoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = CamoTone.olive,
    this.vertical = false,
    this.compact = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFF4F0E4);
    final style = TextStyle(
      color: ink,
      fontWeight: FontWeight.w800,
      fontSize: compact ? 13 : 15,
      height: 1.15,
      letterSpacing: 0.2,
    );
    final iconWidget = icon == null
        ? null
        : Icon(icon, color: ink, size: vertical ? 22 : 18);
    final labelWidget = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return CamoPlate(
      tone: tone,
      onTap: onPressed,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 14,
      ),
      child: child ??
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth.isFinite;
              if (vertical) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconWidget != null) iconWidget,
                    if (iconWidget != null) const SizedBox(height: 6),
                    labelWidget,
                  ],
                );
              }
              return Row(
                mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconWidget != null) ...[
                    iconWidget,
                    const SizedBox(width: 8),
                  ],
                  if (wide)
                    Flexible(child: labelWidget)
                  else
                    labelWidget,
                ],
              );
            },
          ),
    );
  }
}
