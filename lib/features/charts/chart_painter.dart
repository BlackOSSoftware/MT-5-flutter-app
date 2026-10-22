import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_models.dart';

const chartUpColor = Color(0xFF26A69A);
const chartDownColor = Color(0xFFEF5350);
const _gridColor = Color(0xFFE6E6E6);
const _borderColor = Color(0xFFD6D6D6);
const _axisText = Color(0xFF1A1A1A);
const _crossColor = Color(0xFF616161);

/// Chart geometry (painter + gestures dono yahi use karte hain).
class ChartLayout {
  const ChartLayout({
    required this.size,
    required this.count,
    required this.spacing,
    required this.scroll,
  });

  final Size size;
  final int count;

  /// Ek candle ki chaudai (px).
  final double spacing;

  /// Kitne candles right se history ki taraf scroll (0 = latest).
  final double scroll;

  static const axisWidth = 64.0;
  static const timeAxisHeight = 22.0;
  static const topPad = 8.0;

  /// Latest candle ke right me khali jagah (candles me).
  static const rightMargin = 3.0;

  double get plotWidth => math.max(0, size.width - axisWidth);
  double get plotHeight => math.max(0, size.height - timeAxisHeight - topPad);
  double get plotBottom => topPad + plotHeight;

  double xOf(int index) =>
      plotWidth - (count - 1 - index - scroll + rightMargin + 0.5) * spacing;

  /// x position par kaunsa candle (index, clamp nahi).
  int indexAt(double x) =>
      (count - 1 - ((plotWidth - x) / spacing - rightMargin - 0.5 + scroll))
          .round();

  (int, int) get visibleRange {
    final maxI = math.max(0, count - 1);
    // Left edge = purana (chhota index), right edge = naya.
    final first = indexAt(-spacing).clamp(0, maxI).toInt();
    final last = indexAt(plotWidth + spacing).clamp(0, maxI).toInt();
    return (first, last);
  }
}

/// Price <-> y mapping (dikh rahe candles + bid + lines se auto-fit).
class ChartScale {
  const ChartScale(this.lo, this.hi, this.top, this.height);

  final double lo;
  final double hi;
  final double top;
  final double height;

  double get range => hi - lo;
  double yOf(double p) => top + (hi - p) / range * height;
  double priceAt(double y) => hi - (y - top) / height * range;

  static ChartScale? compute({
    required List<Candle> candles,
    required ChartLayout layout,
    required int digits,
    double? bid,
    Iterable<double> extra = const [],
    double zoom = 1,
  }) {
    if (candles.isEmpty) return null;
    final (first, last) = layout.visibleRange;
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (var i = first; i <= last; i++) {
      lo = math.min(lo, candles[i].l);
      hi = math.max(hi, candles[i].h);
    }
    if (last == candles.length - 1 && bid != null) {
      lo = math.min(lo, bid);
      hi = math.max(hi, bid);
    }
    if (!lo.isFinite || !hi.isFinite) return null;
    // Order / SL / TP lines thodi door hon to bhi dikh jayein (2x range tak).
    final span0 = hi - lo;
    for (final p in extra) {
      if ((p - lo).abs() <= span0 * 2 || (p - hi).abs() <= span0 * 2) {
        lo = math.min(lo, p);
        hi = math.max(hi, p);
      }
    }
    final point = math.pow(10, -digits).toDouble();
    final range = math.max(hi - lo, point * 10);
    // Price scale drag: zoom > 1 = zyada range (candles chhote), < 1 = bade.
    final mid = (lo + hi) / 2;
    final half = range * 1.16 / 2 * zoom;
    return ChartScale(
      mid - half,
      mid + half,
      ChartLayout.topPad,
      layout.plotHeight,
    );
  }
}

/// Chart pe horizontal line: position, pending order, SL/TP, draft order.
class ChartLevel {
  const ChartLevel({
    required this.id,
    required this.price,
    required this.label,
    required this.color,
    this.dashed = false,
    this.draggable = false,
  });

  final String id;
  final double price;
  final String label;
  final Color color;
  final bool dashed;
  final bool draggable;
}

class ChartPainter extends CustomPainter {
  ChartPainter({
    this.levels = const [],
    this.vZoom = 1,
    required this.candles,
    required this.timeframe,
    required this.digits,
    required this.spacing,
    required this.scroll,
    required this.bid,
    required this.ask,
    required this.secondsLeft,
    required this.crosshair,
    required this.revision,
  });

  final List<ChartLevel> levels;

  /// Price scale ka vertical zoom (1 = auto fit).
  final double vZoom;
  final List<Candle> candles;
  final ChartTimeframe timeframe;
  final int digits;
  final double spacing;
  final double scroll;
  final double? bid;
  final double? ask;
  final int secondsLeft;
  final Offset? crosshair;

  /// Live tick pe candle object wahi rehta hai - repaint ke liye counter.
  final int revision;

  static String _two(int v) => v.toString().padLeft(2, '0');
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _timeLabel(DateTime d) => timeframe.intraday
      ? '${d.day} ${_months[d.month - 1]} ${_two(d.hour)}:${_two(d.minute)}'
      : '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String crosshairTime(DateTime d) =>
      '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]} '
      '${d.day} ${_months[d.month - 1]} \'${_two(d.year % 100)} '
      '${_two(d.hour)}:${_two(d.minute)}';

  TextPainter _text(String s, Color color, {double size = 12.5}) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(color: color, fontSize: size, height: 1.1),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _dashH(Canvas c, double y, double x0, double x1, Paint p) {
    for (var x = x0; x < x1; x += 7) {
      c.drawLine(Offset(x, y), Offset(math.min(x + 4, x1), y), p);
    }
  }

  void _dashV(Canvas c, double x, double y0, double y1, Paint p) {
    for (var y = y0; y < y1; y += 7) {
      c.drawLine(Offset(x, y), Offset(x, math.min(y + 4, y1)), p);
    }
  }

  static double _niceStep(double raw) {
    if (raw <= 0 || !raw.isFinite) return 1;
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = f < 1.5
        ? 1
        : f < 3
        ? 2
        : f < 7
        ? 5
        : 10;
    return nice * exp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || size.width <= 0 || size.height <= 0) return;
    final layout = ChartLayout(
      size: size,
      count: candles.length,
      spacing: spacing,
      scroll: scroll,
    );
    final plotW = layout.plotWidth;
    final plotH = layout.plotHeight;
    final top = ChartLayout.topPad;
    final bottom = layout.plotBottom;
    final (first, last) = layout.visibleRange;

    // ---- price range (dikh rahe candles + lines) ----
    final scale = ChartScale.compute(
      candles: candles,
      layout: layout,
      digits: digits,
      bid: bid,
      extra: [for (final l in levels) l.price],
      zoom: vZoom,
    );
    if (scale == null) return;
    final lo = scale.lo;
    final hi = scale.hi;
    final range = scale.range;
    double yOf(double p) => scale.yOf(p);

    final grid = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;

    // Chart window ka top, right aur bottom border (scales se pehle).
    final border = Paint()
      ..color = _borderColor
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, 0.5), Offset(plotW, 0.5), border);
    canvas.drawLine(
      Offset(plotW - 0.5, 0),
      Offset(plotW - 0.5, bottom),
      border,
    );
    canvas.drawLine(
      Offset(0, bottom - 0.5),
      Offset(plotW, bottom - 0.5),
      border,
    );

    // ---- price grid + right axis labels ----
    final step = _niceStep(range / math.max(1, plotH / 34));
    final start = (lo / step).ceil() * step;
    for (var p = start; p <= hi; p += step) {
      final y = yOf(p);
      if (y < top || y > bottom) continue;
      _dashH(canvas, y, 0, plotW, grid);
      final t = _text(p.toStringAsFixed(digits), _axisText);
      t.paint(canvas, Offset(plotW + 4, y - t.height / 2));
    }

    // ---- time grid + labels ----
    // Vertical grid ~36px pe, label har teesri line pe (~108px).
    final gridEvery = math.max(1, (36 / spacing).ceil());
    final labelEvery = gridEvery * 3;
    final sec = timeframe.seconds;
    for (var i = first; i <= last; i++) {
      final idx = timeframe.intraday ? candles[i].t ~/ sec : i;
      if (idx % gridEvery != 0) continue;
      final x = layout.xOf(i);
      if (x < 0 || x > plotW) continue;
      _dashV(canvas, x, top, bottom, grid);
      if (idx % labelEvery != 0) continue;
      final t = _text(_timeLabel(candles[i].time), _axisText);
      final lx = (x - t.width / 2).clamp(0.0, plotW - t.width);
      t.paint(canvas, Offset(lx, bottom + 4));
    }
    // Latest candle ke right wali khali jagah me bhi grid (price scale tak),
    // aage ke candles ke time ke hisaab se.
    final lastIdx = candles.length - 1;
    for (var j = lastIdx + 1; ; j++) {
      final x = layout.xOf(j);
      if (x > plotW) break;
      final idx = timeframe.intraday
          ? candles[lastIdx].t ~/ sec + (j - lastIdx)
          : j;
      if (x >= 0 && idx % gridEvery == 0) {
        _dashV(canvas, x, top, bottom, grid);
      }
    }

    // ---- candles ----
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plotW, bottom));
    final body = math.max(1.0, spacing * 0.7);
    final up = Paint()..color = chartUpColor;
    final down = Paint()..color = chartDownColor;
    final wickW = spacing < 4 ? 1.0 : 1.2;
    for (var i = first; i <= last; i++) {
      final k = candles[i];
      final x = layout.xOf(i);
      final paint = k.up ? up : down;
      canvas.drawLine(
        Offset(x, yOf(k.h)),
        Offset(x, yOf(k.l)),
        paint..strokeWidth = wickW,
      );
      if (spacing >= 3) {
        final yo = yOf(k.o);
        final yc = yOf(k.c);
        canvas.drawRect(
          Rect.fromLTRB(
            x - body / 2,
            math.min(yo, yc),
            x + body / 2,
            math.max(math.max(yo, yc), math.min(yo, yc) + 1),
          ),
          paint,
        );
      }
    }

    // ---- bid / ask lines ----
    if (ask != null) {
      canvas.drawLine(
        Offset(0, yOf(ask!)),
        Offset(plotW, yOf(ask!)),
        Paint()
          ..color = chartDownColor.withValues(alpha: 0.8)
          ..strokeWidth = 0.8,
      );
    }
    if (bid != null) {
      canvas.drawLine(
        Offset(0, yOf(bid!)),
        Offset(plotW, yOf(bid!)),
        Paint()
          ..color = chartUpColor.withValues(alpha: 0.9)
          ..strokeWidth = 0.8,
      );
    }

    // ---- positions / orders / SL / TP lines ----
    for (final lv in levels) {
      final y = yOf(lv.price);
      if (y < top || y > bottom) continue;
      final p = Paint()
        ..color = lv.color
        ..strokeWidth = 1;
      if (lv.dashed) {
        _dashH(canvas, y, 0, plotW, p);
      } else {
        canvas.drawLine(Offset(0, y), Offset(plotW, y), p);
      }
      final t = _text(lv.label, lv.color, size: 12);
      t.paint(canvas, Offset(6, y - t.height - 1));
      if (lv.draggable) {
        // Kheenchne wala handle (MT5 jaisa chhota gola).
        final c = Offset(plotW / 2, y);
        canvas.drawCircle(c, 5, Paint()..color = Colors.white);
        canvas.drawCircle(
          c,
          5,
          Paint()
            ..color = lv.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    canvas.restore();

    // Line ka price right axis pe border wale chip me.
    for (final lv in levels) {
      final y = yOf(lv.price);
      if (y < top || y > bottom) continue;
      final t = _text(lv.price.toStringAsFixed(digits), lv.color);
      final r = Rect.fromLTWH(
        plotW + 1,
        y - t.height / 2 - 2,
        size.width - plotW - 2,
        t.height + 4,
      );
      canvas.drawRect(r, Paint()..color = Colors.white);
      canvas.drawRect(
        r,
        Paint()
          ..color = lv.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      t.paint(canvas, Offset(plotW + 4, r.top + 2));
    }

    // ---- current price label + candle countdown ----
    final current = bid ?? candles.last.c;
    final cy = yOf(current).clamp(top, bottom);
    final price = _text(current.toStringAsFixed(digits), Colors.white);
    final left = secondsLeft;
    final countdown = _text(
      left >= 3600
          ? '${left ~/ 3600}:${_two(left % 3600 ~/ 60)}:${_two(left % 60)}'
          : '${_two(left ~/ 60)}:${_two(left % 60)}',
      Colors.white,
    );
    final boxH = price.height + countdown.height + 4;
    final box = Rect.fromLTWH(
      plotW,
      cy - price.height / 2 - 2,
      size.width - plotW,
      boxH,
    );
    canvas.drawRect(
      box,
      Paint()..color = candles.last.up ? chartUpColor : chartDownColor,
    );
    price.paint(canvas, Offset(plotW + 4, box.top + 2));
    countdown.paint(canvas, Offset(plotW + 4, box.top + 2 + price.height));

    // ---- crosshair ----
    final cross = crosshair;
    if (cross != null) {
      final cx = cross.dx.clamp(0.0, plotW);
      final cyy = cross.dy.clamp(top, bottom);
      final p = Paint()
        ..color = _crossColor
        ..strokeWidth = 0.8;
      _dashH(canvas, cyy, 0, plotW, p);
      _dashV(canvas, cx, top, bottom, p);
      final blue = Paint()
        ..color = const Color(0xFF168BE1)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(cx - 7, cyy), Offset(cx + 7, cyy), blue);
      canvas.drawLine(Offset(cx, cyy - 7), Offset(cx, cyy + 7), blue);

      final priceAt = hi - (cyy - top) / plotH * range;
      final pt = _text(priceAt.toStringAsFixed(digits), Colors.white);
      final pr = Rect.fromLTWH(
        plotW,
        cyy - pt.height / 2 - 2,
        size.width - plotW,
        pt.height + 4,
      );
      canvas.drawRect(pr, Paint()..color = const Color(0xFF424242));
      pt.paint(canvas, Offset(plotW + 4, pr.top + 2));

      final i = layout.indexAt(cx).clamp(0, candles.length - 1);
      final tt = _text(crosshairTime(candles[i].time), Colors.white);
      final tx = (cx - tt.width / 2 - 3).clamp(0.0, plotW - tt.width - 6);
      final tr = Rect.fromLTWH(tx, bottom + 2, tt.width + 6, tt.height + 4);
      canvas.drawRect(tr, Paint()..color = const Color(0xFF424242));
      tt.paint(canvas, Offset(tr.left + 3, tr.top + 2));
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter old) =>
      old.levels != levels ||
      old.vZoom != vZoom ||
      old.candles != candles ||
      old.revision != revision ||
      old.spacing != spacing ||
      old.scroll != scroll ||
      old.bid != bid ||
      old.ask != ask ||
      old.secondsLeft != secondsLeft ||
      old.crosshair != crosshair ||
      old.digits != digits ||
      old.timeframe != timeframe;
}
