import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_colors.dart';
import 'camo_button.dart';

class TacStyle {
  static const radius = 20.0;

  static TextStyle get stencil => TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 2.4,
        height: 1,
      );

  static TextStyle get title => TextStyle(
        color: AppColors.textMain,
        fontWeight: FontWeight.w600,
        fontSize: 30,
        letterSpacing: -0.4,
        height: 1.05,
      );

  static TextStyle get body => TextStyle(
        color: AppColors.textMain,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        height: 1.35,
      );

  static TextStyle get muted => TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 1.4,
      );
}

class VolGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? glow;

  const VolGlass({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final plate = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark
                ? const Color(0x99000000)
                : const Color(0x330B1520),
            offset: const Offset(0, 14),
            blurRadius: 24,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: AppColors.isDark
                ? const Color(0x22FFFFFF)
                : const Color(0x99FFFFFF),
            offset: const Offset(0, -1),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: CustomPaint(
            painter: _BevelPainter(radius: radius, glow: glow),
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

class _BevelPainter extends CustomPainter {
  final double radius;
  final Color? glow;
  _BevelPainter({required this.radius, this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final light = !AppColors.isDark;
    final tint = AppColors.glassTint;
    canvas.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? [
                  tint.withOpacity(0.45),
                  tint.withOpacity(0.25),
                  tint.withOpacity(0.14),
                ]
              : [
                  tint.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                  const Color(0x66000000),
                ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.36),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            light ? tint.withOpacity(0.40) : tint.withOpacity(0.10),
            const Color(0x00FFFFFF),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.36)),
    );
    canvas.restore();

    canvas.drawRRect(
      r.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? [
                  tint,
                  tint.withOpacity(0.67),
                  tint.withOpacity(0.40),
                ]
              : [
                  tint.withOpacity(0.28),
                  Colors.white.withOpacity(0.08),
                  const Color(0x44000000),
                ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      r.deflate(3.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x22000000),
    );
  }

  @override
  bool shouldRepaint(covariant _BevelPainter old) =>
      old.radius != radius || old.glow != glow;
}

class TacBackdrop extends StatefulWidget {
  final Widget child;
  const TacBackdrop({super.key, required this.child});

  @override
  State<TacBackdrop> createState() => _TacBackdropState();
}

class _TacBackdropState extends State<TacBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_glow.value);
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: AppColors.scene,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -120 + 28 * t,
              right: -80 + 18 * t,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (AppColors.isDark ? AppColors.glassTint : Colors.white)
                            .withOpacity(AppColors.isDark ? 0.12 : 0.50),
                        Colors.white.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40 - 20 * t,
              left: -90,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.10),
                        AppColors.accent.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PixelTintPainter(t),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class TacCard extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final EdgeInsets margin;

  const TacCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return VolGlass(
      margin: margin,
      padding: padding,
      radius: TacStyle.radius,
      glow: accent,
      onTap: onTap,
      child: child,
    )
        .animate()
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 320.ms, curve: Curves.easeOut);
  }
}

class TacHeader extends StatelessWidget {
  final String callsign;
  final String subtitle;
  final List<Widget>? actions;
  const TacHeader({
    super.key,
    required this.callsign,
    required this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('W-NODE', style: TacStyle.stencil),
              const SizedBox(height: 8),
              Text(callsign, style: TacStyle.title),
              const SizedBox(height: 6),
              Text(subtitle, style: TacStyle.muted),
            ],
          ),
        ),
        if (actions != null) ...actions!,
      ],
    )
        .animate()
        .fadeIn(duration: 420.ms)
        .slideY(begin: -0.06, end: 0, duration: 420.ms);
  }
}

class TacLed extends StatelessWidget {
  final Color color;
  final double size;
  const TacLed({super.key, required this.color, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.7), blurRadius: 8),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.55, end: 1, duration: 1200.ms);
  }
}

class TacChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  const TacChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CamoPlate(
      tone: active ? CamoTone.olive : CamoTone.deep,
      dim: !active,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: const Color(0xFFF4F0E4)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFF4F0E4),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class TacButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;
  final bool filled;
  final CamoTone? tone;
  const TacButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.icon,
    this.filled = true,
    this.tone,
  });

  CamoTone get _tone {
    if (tone != null) return tone!;
    if (!filled) return CamoTone.moss;
    final c = color;
    if (c == null) return CamoTone.olive;
    if (c == AppColors.danger) return CamoTone.deep;
    if (c == AppColors.accentBlue || c == AppColors.sun) return CamoTone.khaki;
    if (c == AppColors.warning) return CamoTone.brown;
    return CamoTone.olive;
  }

  @override
  Widget build(BuildContext context) {
    return CamoButton(
      label: label,
      icon: icon,
      tone: _tone,
      onPressed: onTap,
    );
  }
}

class TacIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const TacIconBox({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.22),
            color.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class TacSection extends StatelessWidget {
  final String code;
  final String hint;
  const TacSection({super.key, required this.code, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 1.5,
          color: AppColors.accent,
        ),
        const SizedBox(width: 8),
        Text(code,
            style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.3)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(hint,
              overflow: TextOverflow.ellipsis, style: TacStyle.muted),
        ),
      ],
    );
  }
}

class TacAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? code;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool implyLeading;

  const TacAppBar({
    super.key,
    required this.title,
    this.code,
    this.actions,
    this.bottom,
    this.implyLeading = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (bottom?.preferredSize.height ?? 1));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: implyLeading,
      iconTheme: IconThemeData(color: AppColors.textMain),
      title: Text(title,
          semanticsLabel: code ?? title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              letterSpacing: 0.3)),
      actions: actions,
      bottom: bottom ??
          PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              decoration: BoxDecoration(gradient: AppColors.metal),
            ),
          ),
    );
  }
}

class TacField {
  static InputDecoration of(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AppColors.accent, size: 20),
      filled: true,
      fillColor: AppColors.card.withOpacity(0.85),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.accent, width: 1.3),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
    );
  }
}

class TacSheet {
  static const double radius = 28;

  static ShapeBorder get shape => RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
        side: BorderSide(color: AppColors.border),
      );

  static ShapeBorder dialog([Color? accent]) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: accent ?? AppColors.border),
      );

  static Widget handle() => Center(
        child: Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(
            gradient: AppColors.metal,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );
}

class _PixelTintPainter extends CustomPainter {
  final double t;
  _PixelTintPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AppColors.isDark
          ? const Color(0x14FFFFFF)
          : const Color(0x123A4554);
    final shade = Paint()
      ..color = AppColors.isDark
          ? const Color(0x10000000)
          : const Color(0x0A1A2430);
    const step = 18.0;
    final shift = (t * step);
    for (double y = -step; y < size.height + step; y += step) {
      for (double x = -step; x < size.width + step; x += step) {
        final gx = x + shift;
        final gy = y;
        final n = ((x / step).floor() * 3 + (y / step).floor() * 7) % 6;
        if (n == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(gx, gy, 8, 8),
              const Radius.circular(2),
            ),
            ink,
          );
        } else if (n == 3) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(gx + 5, gy + 5, 6, 6),
              const Radius.circular(2),
            ),
            shade,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelTintPainter old) => old.t != t;
}
