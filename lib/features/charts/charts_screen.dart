import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_header.dart';
import '../quotes/quote_data.dart';
import '../shell/no_accounts_view.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key, required this.onMenu, required this.symbol});

  final VoidCallback onMenu;
  final String symbol;

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  static const _frames = [
    'M1',
    'M5',
    'M15',
    'M30',
    'H1',
    'H4',
    'D1',
    'W1',
    'MN',
  ];
  String _frame = 'H1';
  late List<_Candle> _candles;

  static const _minutes = {
    'M1': 1,
    'M5': 5,
    'M15': 15,
    'M30': 30,
    'H1': 60,
    'H4': 240,
    'D1': 1440,
    'W1': 10080,
    'MN': 43200,
  };

  void _onLive() {
    if (!mounted) return;
    // Ye tab chhupa ho (IndexedStack) to chart rebuild mat karo -
    // warna har tick par peeche chart banta rehta hai aur Quotes
    // ka scroll atakata hai. Tab khulte hi shell rebuild se fresh
    // chart ban jata hai.
    final shell = ShellScope.maybeOf(context);
    if (shell != null && shell.tab != 1) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _candles = _buildCandles(widget.symbol, _frame);
    tradingService.subscribe(widget.symbol);
    tradingService.addListener(_onLive);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onLive);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChartsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _candles = _buildCandles(widget.symbol, _frame);
      tradingService.subscribe(widget.symbol);
    }
  }

  void _selectFrame(String frame) {
    setState(() {
      _frame = frame;
      _candles = _buildCandles(widget.symbol, frame);
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = quoteBySymbol(widget.symbol);
    final liveQuote = tradingService.quotes[widget.symbol];
    final liveCandles = tradingService.candlesFor(
      widget.symbol,
      _minutes[_frame] ?? 60,
    );
    final candles = liveCandles.isNotEmpty
        ? [for (final c in liveCandles) _Candle(c.o, c.h, c.l, c.c)]
        : _candles;
    final digits = liveQuote?.digits ?? quote?.digits ?? 5;
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(
            title: widget.symbol,
            subtitle: _frame,
            onMenu: widget.onMenu,
          ),
          SizedBox(
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: MtColors.line)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _frames.length,
                itemBuilder: (context, index) {
                  final frame = _frames[index];
                  final selected = frame == _frame;
                  return InkWell(
                    onTap: () => _selectFrame(frame),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: Text(
                          frame,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected ? MtColors.accent : MtColors.icon,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (liveQuote != null && liveQuote.hasPrice)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Row(
                children: [
                  Text(
                    'Bid  ${liveQuote.bid.toStringAsFixed(digits)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MtColors.bid,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'Ask  ${liveQuote.ask.toStringAsFixed(digits)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MtColors.ask,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: !tradingService.hasAnyAccount
                ? const NoAccountsBody()
                : RepaintBoundary(
                    child: CustomPaint(
                      painter: _ChartPainter(candles: candles, digits: digits),
                      child: const SizedBox.expand(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Candle {
  const _Candle(this.open, this.high, this.low, this.close);

  final double open;
  final double high;
  final double low;
  final double close;
}

List<_Candle> _buildCandles(String symbol, String frame) {
  final quote = quoteBySymbol(symbol);
  var price = quote?.base ?? 1.0;
  final digits = quote?.digits ?? 5;
  final step = math.pow(10, -digits).toDouble() * 6;
  var seed = frame.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  seed = symbol.codeUnits.fold<int>(seed + 17, (sum, unit) => sum * 3 + unit);
  final candles = <_Candle>[];
  for (var i = 0; i < 56; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final delta = ((seed % 21) - 10) * step;
    final open = price;
    final close = price + delta;
    final high = math.max(open, close) + step * 0.85;
    final low = math.min(open, close) - step * 0.7;
    candles.add(_Candle(open, high, low, close));
    price = close;
  }
  return candles;
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.candles, required this.digits});

  final List<_Candle> candles;
  final int digits;

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || size.width <= 0 || size.height <= 0) return;
    var minPrice = candles.first.low;
    var maxPrice = candles.first.high;
    for (final candle in candles) {
      minPrice = math.min(minPrice, candle.low);
      maxPrice = math.max(maxPrice, candle.high);
    }
    final span = math.max(
      maxPrice - minPrice,
      math.pow(10, -digits).toDouble(),
    );
    const topPad = 16.0;
    const bottomPad = 12.0;
    const rightPad = 8.0;
    final plotHeight = size.height - topPad - bottomPad;
    final plotWidth = size.width - rightPad;

    final grid = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = topPad + plotHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i <= 4; i++) {
      final x = plotWidth * i / 4;
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, size.height - bottomPad),
        grid,
      );
    }

    double yOf(double price) {
      final t = (price - minPrice) / span;
      return topPad + plotHeight * (1 - t);
    }

    final slot = plotWidth / candles.length;
    final bodyWidth = math.max(2.0, slot * 0.55);
    for (var i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final up = candle.close >= candle.open;
      final color = up ? MtColors.priceUp : MtColors.priceDown;
      final x = slot * i + slot / 2;
      final wick = Paint()
        ..color = color
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(x, yOf(candle.high)),
        Offset(x, yOf(candle.low)),
        wick,
      );
      final top = yOf(math.max(candle.open, candle.close));
      final bottom = yOf(math.min(candle.open, candle.close));
      final bodyHeight = math.max(1.0, bottom - top);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, top + bodyHeight / 2),
          width: bodyWidth,
          height: bodyHeight,
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.digits != digits;
  }
}
