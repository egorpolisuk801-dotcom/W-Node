import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_colors.dart';
import 'camo_button.dart';
import 'theme_controller.dart';
import 'user_config.dart';

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
    final id = UserConfig().themeId;
    final r = BorderRadius.circular(radius);
    final glass = id == AppThemeId.glass;
    final brutal = id == AppThemeId.brutal;
    final neo = id == AppThemeId.neo;
    final plate = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: brutal
            ? const [
                BoxShadow(color: Color(0xFF111111), offset: Offset(5, 5)),
              ]
            : neo
                ? const [
                    BoxShadow(
                      color: Color(0xFFF8FBFF),
                      offset: Offset(-6, -6),
                      blurRadius: 12,
                    ),
                    BoxShadow(
                      color: Color(0xFFA3B1C6),
                      offset: Offset(6, 6),
                      blurRadius: 12,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: glass
                          ? const Color(0x221A2744)
                          : (glow ?? AppColors.accent).withOpacity(0.35),
                      offset: const Offset(0, 8),
                      blurRadius: glass ? 18 : 16,
                    ),
                  ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: glass ? 16 : 0,
            sigmaY: glass ? 16 : 0,
          ),
          child: CustomPaint(
            painter: _StylePanelPainter(radius: radius, glow: glow),
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

class _StylePanelPainter extends CustomPainter {
  final double radius;
  final Color? glow;
  _StylePanelPainter({required this.radius, this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final id = UserConfig().themeId;
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(r);
    if (id == AppThemeId.glass) {
      canvas.drawRect(rect, Paint()..color = const Color(0xB8FFFFFF));
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.45),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
          ).createShader(rect),
      );
    } else if (id == AppThemeId.brutal) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF));
    } else if (id == AppThemeId.neo) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFFE4EAF3));
    } else {
      canvas.drawRect(rect, Paint()..color = const Color(0xFF12101A));
      final neon = glow ?? const Color(0xFF00E5FF);
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - 2, size.width, 2),
        Paint()..color = neon,
      );
    }
    canvas.restore();
    final stroke = id == AppThemeId.brutal
        ? const Color(0xFF111111)
        : id == AppThemeId.cyber
            ? (glow ?? const Color(0xFF00E5FF))
            : id == AppThemeId.glass
                ? const Color(0xEEFFFFFF)
                : const Color(0x00000000);
    if (id != AppThemeId.neo) {
      canvas.drawRRect(
        r.deflate(id == AppThemeId.brutal ? 1.5 : 0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = id == AppThemeId.brutal ? 3 : 1.2
          ..color = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StylePanelPainter old) =>
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
              child: CustomPaint(
                painter: _ThemeWashPainter(t),
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
            Icon(icon, size: 15, color: styleInk(active ? CamoTone.olive : CamoTone.deep)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  color: styleInk(active ? CamoTone.olive : CamoTone.deep),
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
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            UserConfig().themeId == AppThemeId.brutal ? 4 : 16),
        borderSide: BorderSide(
          color: AppColors.border,
          width: UserConfig().themeId == AppThemeId.brutal ? 3 : 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            UserConfig().themeId == AppThemeId.brutal ? 4 : 16),
        borderSide: BorderSide(color: AppColors.accent, width: 2),
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

class _ThemeWashPainter extends CustomPainter {
  final double t;
  _ThemeWashPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final id = UserConfig().themeId;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.scene,
        ).createShader(rect),
    );
    if (id == AppThemeId.brutal) {
      canvas.drawRect(
        Rect.fromLTWH(-16, size.height * 0.06, 72, 72),
        Paint()..color = const Color(0xFFFFE14A),
      );
      canvas.drawRect(
        Rect.fromLTWH(-10, size.height * 0.06 + 6, 72, 72),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF111111),
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width - 54, size.height * 0.78, 86, 22),
        Paint()..color = const Color(0xFF111111),
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width - 96, 28, 64, 64),
        Paint()..color = const Color(0xFFFF7AD9),
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width - 88, 36, 64, 64),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF111111),
      );
      return;
    }
    if (id == AppThemeId.neo) {
      _orb(canvas, Offset(size.width * 0.82, 70 + 12 * t), 170,
          const Color(0x55FFFFFF));
      _orb(canvas, Offset(20, size.height * 0.82), 190,
          const Color(0x33A3B1C6));
      return;
    }
    if (id == AppThemeId.cyber) {
      final line = Paint()
        ..color = const Color(0x2A00E5FF)
        ..strokeWidth = 1;
      for (var i = 0; i < 5; i++) {
        final y = size.height * (0.16 + i * 0.16) + t * 10;
        canvas.drawLine(Offset(0, y), Offset(size.width, y - 28), line);
      }
      _orb(canvas, Offset(size.width * 0.78, size.height * 0.18), 130,
          const Color(0x5500E5FF));
      _orb(canvas, Offset(16, size.height * 0.74), 110, const Color(0x44FF2BD6));
      return;
    }
    _orb(canvas, Offset(size.width * 0.78 + 12 * t, 10), 210,
        const Color(0x99FFFFFF));
    _orb(canvas, Offset(-10, size.height * 0.7), 190,
        AppColors.accent.withOpacity(0.22));
  }

  void _orb(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _ThemeWashPainter old) => old.t != t;
}
