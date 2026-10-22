import 'dart:math' as math;

import 'package:flutter/material.dart';

const _blue = Color(0xFF168BE1);

/// Gol menu ka ek item: text (timeframe) ya icon (tool).
class RadialItem {
  const RadialItem({
    this.label,
    this.icon,
    this.asset,
    this.selected = false,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;

  /// Image icon (assets/icons/...) - ring pe safed rang me.
  final String? asset;
  final bool selected;
  final VoidCallback onTap;
}

/// MT5 chart ka blue ring menu (chart pe tap se). [center] chart-local.
/// Khulte waqt chhote se bada + thoda ghoom ke (round) khulta hai, band
/// hote waqt ulta animation chal ke [onClose].
class RadialMenu extends StatefulWidget {
  const RadialMenu({
    super.key,
    required this.center,
    required this.items,
    required this.onClose,
  });

  final Offset center;
  final List<RadialItem> items;
  final VoidCallback onClose;

  static const outer = 112.0;
  static const ring = 46.0;

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 220),
  )..forward();

  /// Ghoomna: size wahi, smooth chakkar - bina overshoot / jhatke ke ruke.
  late final _spin = CurvedAnimation(
    parent: _anim,
    // easeOut - aakhir tak raftaar rehti hai, dheere-dheere atakta nahi.
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  /// Fade-in pehle 25% me hi.
  late final _fade = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0, 0.25, curve: Curves.easeOut),
    reverseCurve: Curves.easeIn,
  );

  bool _closing = false;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Band = turant poora gayab (koi fade / reverse animation nahi).
  void _close([VoidCallback? then]) {
    if (_closing) return;
    _closing = true;
    widget.onClose();
    then?.call();
  }

  @override
  Widget build(BuildContext context) {
    const outer = RadialMenu.outer;
    const ring = RadialMenu.ring;
    const mid = outer - ring / 2;
    // MT5 jaisa: pehla item (M1) upar-left (~-142°) se, clockwise -
    // timeframes upar-right arc pe, tools neeche-left arc pe.
    const start = -142 * math.pi / 180;
    final items = widget.items;
    final step = 2 * math.pi / math.max(1, items.length);
    final c = widget.center;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            onPanDown: (_) {},
          ),
        ),
        Positioned(
          left: c.dx - outer,
          top: c.dy - outer,
          width: outer * 2,
          height: outer * 2,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              return Opacity(
                opacity: _fade.value.clamp(0.0, 1.0),
                child: Transform.rotate(
                  // Tez round ghoom ke khulna: +180° se 0° (ulti disha).
                  angle: (1 - _spin.value) * math.pi,
                  // Chhote se poora size - easeOutCubic, koi overshoot nahi
                  // (bada hoke wapas chhota nahi hota).
                  child: Transform.scale(
                    scale: 0.2 + 0.8 * _spin.value,
                    child: child,
                  ),
                ),
              );
            },
            // Alag layer: chart ke live ticks se ring dobara na bane, ghoomna
            // smooth rahe.
            child: RepaintBoundary(
              child: Stack(
                children: [
                  // Ring ya beech ke khali hisse pe (item ke bahar) tap = band.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: const IgnorePointer(
                        child: CustomPaint(painter: _RingPainter(outer, ring)),
                      ),
                    ),
                  ),
                  for (var i = 0; i < items.length; i++)
                    Positioned(
                      left: outer + mid * math.cos(start + step * i) - 18,
                      top: outer + mid * math.sin(start + step * i) - 18,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _close(items[i].onTap),
                        child: Center(
                          child: Transform.rotate(
                            angle: items[i].label != null
                                ? start + step * i + math.pi / 2
                                : 0,
                            child: items[i].label != null
                                ? Text(
                                    items[i].label!,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      // Chuna hua halka safed, baaki gehre safed.
                                      color: items[i].selected
                                          ? Colors.white.withValues(alpha: 0.55)
                                          : Colors.white,
                                    ),
                                  )
                                : items[i].asset != null
                                ? Image.asset(
                                    items[i].asset!,
                                    width: 20,
                                    height: 20,
                                    color: Colors.white,
                                  )
                                : Icon(
                                    items[i].icon,
                                    color: Colors.white,
                                    size: 20,
                                    // Halki shadows se lakeer moti (bold jaisa).
                                    shadows: const [
                                      Shadow(
                                        color: Colors.white,
                                        offset: Offset(0.5, 0),
                                      ),
                                      Shadow(
                                        color: Colors.white,
                                        offset: Offset(0, 0.5),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.outer, this.ring);
  final double outer;
  final double ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      c,
      outer - ring / 2,
      Paint()
        ..color = _blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => false;
}
