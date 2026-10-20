import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import '../quotes/quote_data.dart';

class NewOrderPage extends StatefulWidget {
  const NewOrderPage({super.key, required this.symbol});

  final String symbol;

  @override
  State<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  late String _symbol;
  String _type = 'MARKET';
  double _volume = 0.01;
  double? _sl;
  double? _tp;
  double? _price;
  double? _limitPrice;
  String _fillPolicy = 'Fill or Kill';
  bool _busy = false;

  static const _types = <(String, String)>[
    ('MARKET', 'Market Execution'),
    ('BUY_LIMIT', 'Buy Limit'),
    ('SELL_LIMIT', 'Sell Limit'),
    ('BUY_STOP', 'Buy Stop'),
    ('SELL_STOP', 'Sell Stop'),
    ('BUY_STOP_LIMIT', 'Buy Stop Limit'),
    ('SELL_STOP_LIMIT', 'Sell Stop Limit'),
  ];

  static const _fillPolicies = [
    'Fill or Kill',
    'Immediate or Cancel',
    'Return',
  ];

  bool get _isPending => _type != 'MARKET';
  bool get _isStopLimit => _type.contains('STOP_LIMIT');
  bool get _isBuyType => _type.startsWith('BUY');

  @override
  void initState() {
    super.initState();
    _symbol = widget.symbol;
    tradingService.subscribe(_symbol);
  }

  List<String> get _symbols {
    final fromWatch = tradingService.watchlist.map((w) => w.code).toList();
    final base = fromWatch.isNotEmpty
        ? fromWatch
        : quotes.map((q) => q.symbol).toList();
    if (!base.contains(_symbol)) return [_symbol, ...base];
    return base;
  }

  String get _description {
    for (final w in tradingService.watchlist) {
      if (w.code == _symbol && w.name.isNotEmpty && w.name != w.code) {
        return w.name;
      }
    }
    return '';
  }

  String get _typeLabel =>
      _types.firstWhere((t) => t.$1 == _type, orElse: () => _types.first).$2;

  double _point(int digits) => math.pow(10, -digits).toDouble();
  double _step(int digits) => _point(digits) * 10;

  double _roundTo(double v, int digits) {
    final f = math.pow(10, digits).toDouble();
    return (v * f).round() / f;
  }

  void _initPendingPrices() {
    final q = tradingService.quotes[_symbol];
    final bid = q?.bid ?? 0;
    final ask = q?.ask ?? 0;
    if (bid <= 0 || ask <= 0) {
      _price = null;
      _limitPrice = null;
      return;
    }
    final digits = q?.digits ?? digitsFor(_symbol, bid);
    final off = _step(digits) * 10;
    switch (_type) {
      case 'BUY_LIMIT':
        _price = _roundTo(bid - off, digits);
      case 'SELL_STOP':
        _price = _roundTo(bid - off, digits);
      case 'SELL_LIMIT':
        _price = _roundTo(ask + off, digits);
      case 'BUY_STOP':
        _price = _roundTo(ask + off, digits);
      case 'BUY_STOP_LIMIT':
        _price = _roundTo(ask + off, digits);
        _limitPrice = _roundTo(_price! - off / 2, digits);
      case 'SELL_STOP_LIMIT':
        _price = _roundTo(bid - off, digits);
        _limitPrice = _roundTo(_price! + off / 2, digits);
      default:
        _price = null;
    }
  }

  void _selectType(String type) {
    setState(() {
      _type = type;
      if (_isPending) {
        _initPendingPrices();
      } else {
        _price = null;
        _limitPrice = null;
      }
    });
  }

  void _selectSymbol(String symbol) {
    if (symbol == _symbol) return;
    setState(() {
      _symbol = symbol;
      _sl = null;
      _tp = null;
      _price = null;
      _limitPrice = null;
      if (_isPending) _initPendingPrices();
    });
    tradingService.subscribe(symbol);
  }

  void _bumpVolume(double delta) {
    setState(() {
      _volume = ((_volume + delta) * 100).round() / 100;
      if (_volume < 0.01) _volume = 0.01;
    });
  }

  Future<void> _editPrice({
    required String title,
    required double? current,
    required double fallback,
    required int digits,
    required ValueChanged<double?> onSet,
  }) async {
    final ctrl = TextEditingController(
      text: (current ?? fallback) > 0
          ? (current ?? fallback).toStringAsFixed(digits)
          : '',
    );
    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MtColors.white,
        title: Text(
          title,
          style: TextStyle(fontSize: 17, color: MtColors.text),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: MtColors.text),
          decoration: const InputDecoration(border: UnderlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('CLEAR'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              Navigator.of(ctx).pop(v);
            },
            child: const Text('SET'),
          ),
        ],
      ),
    );
    if (result == null) {
      onSet(null);
    } else if (result > 0) {
      onSet(_roundTo(result, digits));
    }
  }

  Future<void> _submit(String side) async {
    setState(() => _busy = true);
    try {
      if (_type == 'MARKET') {
        await tradingService.placeMarketOrder(
          symbol: _symbol,
          side: side,
          volume: _volume,
          stopLoss: _sl,
          takeProfit: _tp,
        );
      } else {
        if (_price == null) throw ApiException('Enter order price');
        if (_isStopLimit && _limitPrice == null) {
          throw ApiException('Enter limit price');
        }
        await tradingService.placePendingOrder(
          symbol: _symbol,
          side: _isBuyType ? 'BUY' : 'SELL',
          orderType: _type,
          price: _price!,
          limitPrice: _isStopLimit ? _limitPrice : null,
          volume: _volume,
          stopLoss: _sl,
          takeProfit: _tp,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order placed: $_symbol $_type $_volume')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ---------------- menus ---------------- */

  Future<void> _showTypeMenu() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MtColors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in _types)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(t.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Center(
                    child: Text(
                      t.$2,
                      style: TextStyle(
                        fontSize: 17,
                        color: MtColors.text,
                        fontWeight: t.$1 == _type
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _selectType(picked);
  }

  Future<void> _showSymbolMenu() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 64, right: 6),
          child: Material(
            color: MtColors.white,
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 470,
                minWidth: 195,
                maxWidth: 195,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _symbols.length; i++) ...[
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(_symbols[i]),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 13, 12, 13),
                          child: Text(
                            _symbols[i],
                            style: TextStyle(
                              fontSize: 16,
                              color: MtColors.text,
                              fontWeight: _symbols[i] == _symbol
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      if (i < _symbols.length - 1)
                        Divider(height: 1, color: MtColors.line),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (picked != null) _selectSymbol(picked);
  }

  Future<void> _showFillMenu() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MtColors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in _fillPolicies)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 16,
                        color: MtColors.text,
                        fontWeight: p == _fillPolicy
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _fillPolicy = picked);
  }

  /* ---------------- build ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: tradingService,
          builder: (context, _) {
            final q = tradingService.quotes[_symbol];
            final digits = q?.digits ?? digitsFor(_symbol, q?.bid ?? 0);
            final bid = q?.bid ?? 0;
            final ask = q?.ask ?? 0;
            if (_isPending && _price == null && bid > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _price == null) {
                  setState(_initPendingPrices);
                }
              });
            }
            return Column(
              children: [
                _header(),
                _typeSelector(),
                _volumeRow(),
                if (_isPending) ...[
                  _priceRow(
                    label: 'Price',
                    value: _price,
                    digits: digits,
                    base: bid,
                    onChanged: (v) => setState(() => _price = v),
                    step: _step(digits),
                  ),
                  if (_isStopLimit)
                    _priceRow(
                      label: 'Limit price',
                      value: _limitPrice,
                      digits: digits,
                      base: bid,
                      onChanged: (v) => setState(() => _limitPrice = v),
                      step: _step(digits),
                    ),
                ],
                _bigPrices(bid, ask, digits),
                _slTpRow(digits, bid),
                _fillRow(),
                Expanded(child: _chartArea(bid, ask, digits)),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Text(
                    'Attention! The trade will be executed at market '
                    'conditions, difference with requested price may be '
                    'significant!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                  ),
                ),
                _bottomBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: MtColors.text, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _symbol,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MtColors.text,
                ),
              ),
              if (_description.isNotEmpty)
                Text(
                  _description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _showSymbolMenu,
            icon: Icon(
              Icons.currency_exchange,
              color: MtColors.iconDark,
              size: 25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeSelector() {
    return GestureDetector(
      onTap: _showTypeMenu,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              _typeLabel,
              style: TextStyle(fontSize: 18, color: MtColors.text),
            ),
          ),
          Stack(
            children: [
              Divider(height: 1, color: MtColors.line),
              Positioned(
                right: 0,
                bottom: 0,
                child: CustomPaint(
                  size: const Size(9, 9),
                  painter: _CornerTrianglePainter(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _volumeRow() {
    Widget step(String label, double delta, Color color) {
      return GestureDetector(
        onTap: () => _bumpVolume(delta),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Text(label, style: TextStyle(fontSize: 15, color: color)),
        ),
      );
    }

    const gray = Color(0xFFBDBDBD);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              step('-0.5', -0.5, gray),
              step('-0.1', -0.1, gray),
              step('-0.01', -0.01, gray),
              SizedBox(
                width: 62,
                child: Text(
                  _volume.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MtColors.text,
                  ),
                ),
              ),
              step('+0.01', 0.01, MtColors.bid),
              step('+0.1', 0.1, MtColors.bid),
              step('+0.5', 0.5, MtColors.bid),
            ],
          ),
        ),
        Divider(height: 1, color: MtColors.line),
      ],
    );
  }

  Widget _priceRow({
    required String label,
    required double? value,
    required int digits,
    required double base,
    required ValueChanged<double?> onChanged,
    required double step,
  }) {
    final shown = value ?? base;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              SizedBox(
                width: 86,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ),
              IconButton(
                onPressed: shown > 0
                    ? () => onChanged(_roundTo(shown - step, digits))
                    : null,
                icon: Icon(Icons.remove, color: MtColors.bid, size: 22),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _editPrice(
                    title: label,
                    current: value,
                    fallback: base,
                    digits: digits,
                    onSet: (v) => setState(() => onChanged(v)),
                  ),
                  child: Text(
                    shown > 0 ? shown.toStringAsFixed(digits) : '--',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: MtColors.text,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: shown > 0
                    ? () => onChanged(_roundTo(shown + step, digits))
                    : null,
                icon: Icon(Icons.add, color: MtColors.bid, size: 22),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: MtColors.line),
      ],
    );
  }

  Widget _bigPrice(double value, int digits, Color color) {
    if (value <= 0) {
      return Text(
        '--',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );
    }
    final s = value.toStringAsFixed(digits);
    final dot = s.indexOf('.');
    final headEnd = (dot + 3 <= s.length) ? dot + 3 : s.length;
    final head = s.substring(0, headEnd);
    final rest = s.substring(headEnd);
    if (rest.isEmpty) {
      return Text(
        s,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );
    }
    final mid = rest.substring(0, rest.length - 1);
    final sup = rest.substring(rest.length - 1);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: head,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (mid.isNotEmpty)
            TextSpan(
              text: mid,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Transform.translate(
              offset: const Offset(1, -2),
              child: Text(
                sup,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigPrices(double bid, double ask, int digits) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 16, 30, 6),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _bigPrice(bid, digits, MtColors.ask),
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _bigPrice(ask, digits, MtColors.bid),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slTpHalf({
    required String label,
    required double? value,
    required int digits,
    required double base,
    required ValueChanged<double?> onChanged,
    required double step,
  }) {
    final shown = value ?? base;
    return Row(
      children: [
        IconButton(
          onPressed: shown > 0
              ? () => onChanged(_roundTo(shown - step, digits))
              : null,
          icon: Icon(Icons.remove, color: MtColors.bid, size: 22),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _editPrice(
              title: label == 'SL' ? 'Stop Loss' : 'Take Profit',
              current: value,
              fallback: base,
              digits: digits,
              onSet: (v) => setState(() => onChanged(v)),
            ),
            behavior: HitTestBehavior.opaque,
            child: Text(
              value != null ? value.toStringAsFixed(digits) : label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: value != null ? 15 : 16,
                color: value != null ? MtColors.text : const Color(0xFF9E9E9E),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: shown > 0
              ? () => onChanged(_roundTo(shown + step, digits))
              : null,
          icon: Icon(Icons.add, color: MtColors.bid, size: 22),
        ),
      ],
    );
  }

  Widget _slTpRow(int digits, double bid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: _slTpHalf(
              label: 'SL',
              value: _sl,
              digits: digits,
              base: bid,
              onChanged: (v) => setState(() => _sl = v),
              step: _step(digits),
            ),
          ),
          Expanded(
            child: _slTpHalf(
              label: 'TP',
              value: _tp,
              digits: digits,
              base: bid,
              onChanged: (v) => setState(() => _tp = v),
              step: _step(digits),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fillRow() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showFillMenu,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
            child: Row(
              children: [
                const Text(
                  'Fill policy',
                  style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
                ),
                const Spacer(),
                Text(
                  _fillPolicy,
                  style: TextStyle(fontSize: 16, color: MtColors.text),
                ),
                const SizedBox(width: 6),
                CustomPaint(
                  size: const Size(9, 9),
                  painter: _CornerTrianglePainter(),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: MtColors.line),
      ],
    );
  }

  Widget _priceLine({
    required double top,
    required Color color,
    required String label,
  }) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(height: 1, color: color.withValues(alpha: 0.55)),
          Positioned(
            right: 0,
            top: -9,
            child: Container(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartArea(double bid, double ask, int digits) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        String fmt(double v) => v > 0 ? v.toStringAsFixed(digits) : '--';
        return Stack(
          children: [
            if (ask > 0)
              _priceLine(top: h * 0.10, color: MtColors.ask, label: fmt(ask)),
            if (_isPending && _price != null)
              _priceLine(
                top: h * 0.45,
                color: const Color(0xFF9E9E9E),
                label: fmt(_price!),
              ),
            if (bid > 0)
              _priceLine(top: h * 0.78, color: MtColors.bid, label: fmt(bid)),
          ],
        );
      },
    );
  }

  Widget _bottomBar() {
    Widget action({
      required String title,
      required String sub,
      required Color color,
      required VoidCallback? onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _busy ? '...' : title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(sub, style: TextStyle(fontSize: 10, color: color)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: MtColors.line)),
      ),
      child: _isPending
          ? Row(
              children: [
                action(
                  title: 'PLACE',
                  sub: _typeLabel.toUpperCase(),
                  color: _isBuyType ? MtColors.bid : MtColors.ask,
                  onTap: _busy ? null : () => _submit(''),
                ),
              ],
            )
          : Row(
              children: [
                action(
                  title: 'SELL',
                  sub: 'BY MARKET',
                  color: MtColors.ask,
                  onTap: _busy ? null : () => _submit('SELL'),
                ),
                Container(width: 1, height: 42, color: MtColors.line),
                action(
                  title: 'BUY',
                  sub: 'BY MARKET',
                  color: MtColors.bid,
                  onTap: _busy ? null : () => _submit('BUY'),
                ),
              ],
            ),
    );
  }
}

class _CornerTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFBDBDBD);
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
