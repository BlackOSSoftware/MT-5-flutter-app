import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/mt_colors.dart';
import '../../core/trade_sound.dart';
import '../../core/trading_service.dart';
import '../quotes/quote_data.dart';
import '../quotes/selected_symbols_page.dart';

part 'position_action_page.dart';

class NewOrderPage extends StatefulWidget {
  const NewOrderPage({super.key, required this.symbol, this.onOrderPlaced});

  final String symbol;
  final VoidCallback? onOrderPlaced;

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

  // Pending order expiration: GTC / TODAY / SPECIFIED /
  // SPECIFIED_DAY (backend expireType/expireAt bhejega).
  String _expireType = 'GTC';
  DateTime? _expireAt;
  final _expirationKey = GlobalKey();
  final _fillKey = GlobalKey();
  final _typeKey = GlobalKey();

  // Smoothness: tick dusre symbol ka aaye ya price same ho to
  // chart/price widget cache se reuse hoga, rebuild nahi hoga.
  Widget? _chartCache;
  String _chartCacheKey = '';
  Widget? _bigCache;
  String _bigCacheKey = '';

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

  static double _point(int digits) => math.pow(10, -digits).toDouble();
  static double _step(int digits) => _point(digits) * 10;

  static double _roundTo(double v, int digits) {
    final f = math.pow(10, digits).toDouble();
    return (v * f).round() / f;
  }

  void _selectType(String type) {
    setState(() {
      _type = type;
      // MT5 jaisa: pending type select karne pe Price 0.00000
      // se shuru hoga, auto price nahi bharega.
      _price = null;
      _limitPrice = null;
      _expireType = 'GTC';
      _expireAt = null;
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
    });
    tradingService.subscribe(symbol);
  }

  final _volumeCtrl = TextEditingController(text: '0.01');
  final _volumeFocus = FocusNode();

  /// Qty me sirf digits + ek decimal point (max 2 decimal) -
  /// minus/plus/space type hi nahi hoga (fraud-safe input).
  static final _qtyFormat = TextInputFormatter.withFunction((oldV, newV) {
    if (newV.text.isEmpty) return newV;
    return RegExp(r'^\d{1,3}(\.\d{0,2})?$').hasMatch(newV.text) ? newV : oldV;
  });

  /// Price/SL/TP me bhi sirf digits + point (max 6 decimal).
  static final _priceFormat = TextInputFormatter.withFunction((oldV, newV) {
    if (newV.text.isEmpty) return newV;
    return RegExp(r'^\d{1,9}(\.\d{0,6})?$').hasMatch(newV.text) ? newV : oldV;
  });
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _slFocus = FocusNode();
  final _tpFocus = FocusNode();
  final _priceCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _priceFocus = FocusNode();
  final _limitFocus = FocusNode();

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _volumeFocus.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    _slFocus.dispose();
    _tpFocus.dispose();
    _priceCtrl.dispose();
    _limitCtrl.dispose();
    _priceFocus.dispose();
    _limitFocus.dispose();
    super.dispose();
  }

  void _bumpVolume(double delta) {
    setState(() {
      _volume = ((_volume + delta) * 100).round() / 100;
      if (_volume < 0.01) _volume = 0.01;
      if (!_volumeFocus.hasFocus) {
        _volumeCtrl.text = _volume.toStringAsFixed(2);
      }
    });
  }

  /// Field se volume padho, limit me bandho aur text sahi karo.
  void _syncVolumeFromField() {
    final parsed = double.tryParse(_volumeCtrl.text.trim());
    var v = parsed ?? 0.01;
    v = (v * 100).round() / 100;
    if (v < 0.01) v = 0.01;
    if (v > 100) v = 100;
    _volume = v;
    _volumeCtrl.text = v.toStringAsFixed(2);
  }

  double _dataPrice(Map<String, dynamic> data) {
    for (final k in ['openPrice', 'price', 'executedPrice']) {
      final v = double.tryParse('${data[k] ?? ''}');
      if (v != null && v > 0) return v;
    }
    return 0;
  }

  String _ticketOf(Map<String, dynamic> data) {
    final ticket = data['ticket'];
    return ticket is num && ticket >= 10000000000 && ticket <= 99999999999
        ? ticket.toInt().toString()
        : '';
  }

  Future<bool?> _runExecution({
    required String side,
    required String typeLabel,
    required double? queuePrice,
    required int digits,
    required Future<Map<String, dynamic>> Function() task,
  }) {
    return Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, _, _) => _OrderResultScreen(
          side: side,
          typeLabel: typeLabel,
          volumeText: _volume.toStringAsFixed(2),
          symbol: _symbol,
          queuePrice: queuePrice,
          digits: digits,
          task: task,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _submit(String side) async {
    // Keyboard khula ho tab bhi field wala taza volume hi use ho.
    _syncVolumeFromField();
    _volumeFocus.unfocus();
    // SL/TP bhi direct fields se hi final lo.
    final slParsed = double.tryParse(_slCtrl.text.trim());
    final tpParsed = double.tryParse(_tpCtrl.text.trim());
    _sl = (slParsed != null && slParsed > 0) ? slParsed : null;
    _tp = (tpParsed != null && tpParsed > 0) ? tpParsed : null;
    _slFocus.unfocus();
    _tpFocus.unfocus();
    // Price / Stop Limit price bhi direct fields se hi final lo.
    if (_isPending) {
      final pp = double.tryParse(_priceCtrl.text.trim());
      _price = (pp != null && pp > 0) ? pp : null;
      _priceFocus.unfocus();
      if (_isStopLimit) {
        final lp = double.tryParse(_limitCtrl.text.trim());
        _limitPrice = (lp != null && lp > 0) ? lp : null;
        _limitFocus.unfocus();
      }
    }
    final q = tradingService.quotes[_symbol];
    final digits = q?.digits ?? digitsFor(_symbol, q?.bid ?? 0);
    final execSide = _type == 'MARKET' ? side : (_isBuyType ? 'BUY' : 'SELL');
    final typeLabel = _type == 'MARKET'
        ? 'MARKET EXECUTION'
        : _typeLabel.toUpperCase();

    // Logged out / session expire: trade mat bhejo, full-screen
    // error screen dikhao (sound ke saath).
    // Queue screen ki line me dikhane wala price: pending pe
    // order price, market pe BUY=ask / SELL=bid.
    final queuePrice = _isPending
        ? _price
        : (execSide == 'BUY' ? q?.ask : q?.bid);
    if (!await tradingService.ensureSession()) {
      if (!mounted) return;
      await _runExecution(
        side: execSide,
        typeLabel: typeLabel,
        queuePrice: queuePrice,
        digits: digits,
        task: () async => throw ApiException(
          tradingService.loggedOutByUser
              ? 'Not logged in. Please login with your FP Trades account.'
              : 'Server not reachable. Please check your connection and try again.',
        ),
      );
      return;
    }
    if (!mounted) return;
    if (_isPending) {
      if (_price == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter order price')));
        return;
      }
      if (_isStopLimit && _limitPrice == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter limit price')));
        return;
      }
    }
    setState(() => _busy = true);

    final Future<Map<String, dynamic>> Function() task;
    if (_type == 'MARKET') {
      task = () async {
        final data = await tradingService.placeMarketOrder(
          symbol: _symbol,
          side: side,
          volume: _volume,
          stopLoss: _sl,
          takeProfit: _tp,
        );
        final executed = _dataPrice(data);
        return {
          'price': executed > 0 ? executed : null,
          'ticket': _ticketOf(data),
        };
      };
    } else {
      task = () async {
        final data = await tradingService.placePendingOrder(
          symbol: _symbol,
          side: _isBuyType ? 'BUY' : 'SELL',
          orderType: _type,
          price: _price!,
          limitPrice: _isStopLimit ? _limitPrice : null,
          volume: _volume,
          stopLoss: _sl,
          takeProfit: _tp,
          expireType: _expireType,
          expireAt: _expireAt,
        );
        return {'price': _price, 'ticket': _ticketOf(data)};
      };
    }

    final done = await _runExecution(
      side: execSide,
      typeLabel: typeLabel,
      queuePrice: queuePrice,
      digits: digits,
      task: task,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done == true) {
      widget.onOrderPlaced?.call();
      Navigator.of(context).pop();
    }
  }

  /* ---------------- menus ---------------- */

  /// MT5 style select menu (screenshot jaisa): safed bada
  /// popup, left 16 se right edge tak full width, options
  /// right-aligned. Type / Fill policy / Expiration teeno
  /// menus isi ek style ke honge.
  Future<String?> _showRightMenu({
    required GlobalKey anchorKey,
    required List<(String, String)> items,
    String? selected,
  }) async {
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final offset = box.localToGlobal(Offset.zero);
    final screenW = MediaQuery.of(context).size.width;
    // Menu selected option ke UPAR se start hoga - selected
    // item (jaise GTC) dabai gayi row ko hi cover karega,
    // menu row ke niche se nahi khulega.
    final selectedIndex = selected == null
        ? 0
        : items.indexWhere((e) => e.$1 == selected);
    final menuTop =
        (offset.dy - (selectedIndex < 0 ? 0 : selectedIndex) * 40 - 8)
            .clamp(80.0, double.infinity)
            .toDouble();
    return showMenu<String>(
      context: context,
      color: MtColors.white,
      elevation: 8,
      shape: const RoundedRectangleBorder(),
      constraints: BoxConstraints(
        minWidth: screenW - 16,
        maxWidth: screenW - 16,
      ),
      position: RelativeRect.fromLTRB(16, menuTop, 0, 0),
      items: [
        for (final (code, label) in items)
          PopupMenuItem<String>(
            value: code,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                label,
                // Koi bold nahi - GTC samet sab normal font.
                style: TextStyle(
                  fontSize: 14,
                  color: MtColors.text,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Order type menu screenshot jaisa: type selector ke
  /// bilkul NEECHE khulne wala safed panel, dono side 16
  /// margin, saare type CENTER me, normal (bold nahi) font.
  /// Screen ke beech wala dialog nahi hai ye.
  /// (Fill/Expiration menu right-aligned hi rahega.)
  Future<void> _showTypeMenu() async {
    final box = _typeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    // showMenu apna size/position khud badal deta tha, isliye
    // ab custom panel: Market Execution wali input ko COVER
    // karke wahi se start hoga, uske niche se nahi khulega.
    final top = offset.dy;
    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'type-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            top: top,
            child: Material(
              color: MtColors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in _types)
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(t.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Text(
                            t.$2,
                            style: TextStyle(
                              fontSize: 14,
                              color: MtColors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
    if (picked != null) _selectType(picked);
  }

  Future<void> _showSymbolMenu() async {
    // Panel ki width fixed nahi - sabse lambe symbol ke text
    // ko jitni jagah chahiye, panel utna hi chauda hoga.
    var textWidth = 0.0;
    for (final s in _symbols) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: const TextStyle(fontSize: 15)),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > textWidth) textWidth = tp.width;
    }
    final panelWidth = textWidth + 30; // left 16 + right 14 padding
    // Dialog widget kam se kam 280 width zabardasti deta tha,
    // isliye panel seedha overlay pe banaya hai - ab width
    // bilkul symbol ke text jitni hi ayegi. Peeche dim nahi.
    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'symbol-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          Positioned(
            right: 0,
            top: 38,
            width: panelWidth,
            child: Material(
              color: const Color(0xFFF7F7F7),
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _symbols.length; i++) ...[
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(_symbols[i]),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                            child: Text(
                              _symbols[i],
                              // Screenshot me selected bhi bold nahi,
                              // font pure dark black ayega.
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF000000),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        if (i < _symbols.length - 1)
                          const Divider(height: 1, color: Color(0xFFE3E3E3)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
    if (picked != null) _selectSymbol(picked);
  }

  Future<void> _showFillMenu() async {
    final picked = await _showRightMenu(
      anchorKey: _fillKey,
      items: [for (final p in _fillPolicies) (p, p)],
      selected: _fillPolicy,
    );
    if (picked != null) setState(() => _fillPolicy = picked);
  }

  /// Expiration menu - screenshot jaisa right-aligned popup:
  /// GTC / Today / Specified / Specified day.
  Future<void> _showExpirationMenu() async {
    final picked = await _showRightMenu(
      anchorKey: _expirationKey,
      items: const [
        ('GTC', 'GTC'),
        ('TODAY', 'Today'),
        ('SPECIFIED', 'Specified'),
        ('SPECIFIED_DAY', 'Specified day'),
      ],
      selected: _expireType,
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'GTC':
        setState(() {
          _expireType = 'GTC';
          _expireAt = null;
        });
      case 'TODAY':
        final now = DateTime.now();
        setState(() {
          _expireType = 'TODAY';
          _expireAt = DateTime(now.year, now.month, now.day, 23, 59, 59);
        });
      case 'SPECIFIED':
      case 'SPECIFIED_DAY':
        final withTime = picked == 'SPECIFIED_DAY';
        final chosen = await showDialog<DateTime>(
          context: context,
          builder: (_) => _ExpirationPickerDialog(
            withTime: withTime,
            initial: _expireAt ?? DateTime.now(),
          ),
        );
        if (chosen == null || !mounted) return;
        setState(() {
          _expireType = picked;
          _expireAt = withTime
              ? chosen
              : DateTime(chosen.year, chosen.month, chosen.day, 23, 59, 59);
        });
    }
  }

  /* ---------------- build ---------------- */

  @override
  Widget build(BuildContext context) {
    final q0 = tradingService.quotes[_symbol];
    final digits = q0?.digits ?? digitsFor(_symbol, q0?.bid ?? 0);
    final baseBid = q0?.bid ?? 0;
    // Keyboard ki height - BUY/SELL bar iske upar ayega.
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: MtColors.white,
      // Body shrink nahi hoga (overflow patti nahi ayegi),
      // BUY/SELL bar alag se keyboard ke upar move hoga.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Keyboard khulne par poora content (chart samet) utna
          // hi upar shift hoga - chart BUY/SELL ke upar pura
          // dikhega, keyboard ke peeche nahi chhupega.
          Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: SafeArea(
              child: Column(
                children: [
                  _header(),
                  _typeSelector(),
                  _volumeRow(),
                  // MT5 order: pehle bade Bid/Ask prices, phir
                  // Price / Stop Limit price rows ayengi.
                  // Sirf bade price tick pe rebuild honge - baki page
                  // (khaas karke volume keyboard typing) slow nahi hoga.
                  ListenableBuilder(
                    listenable: tradingService,
                    builder: (context, _) {
                      final q = tradingService.quotes[_symbol];
                      final bid = q?.bid ?? 0;
                      final ask = q?.ask ?? 0;
                      return _bigPrices(bid, ask, q?.digits ?? digits);
                    },
                  ),
                  if (_isPending) ...[
                    _priceRow(
                      label: 'Price',
                      value: _price,
                      digits: digits,
                      base: baseBid,
                      onChanged: (v) => setState(() => _price = v),
                      step: _step(digits),
                      ctrl: _priceCtrl,
                      focus: _priceFocus,
                    ),
                    if (_isStopLimit)
                      _priceRow(
                        label: 'Stop Limit price',
                        value: _limitPrice,
                        digits: digits,
                        base: baseBid,
                        onChanged: (v) => setState(() => _limitPrice = v),
                        step: _step(digits),
                        ctrl: _limitCtrl,
                        focus: _limitFocus,
                      ),
                  ],
                  _slTpRow(digits, baseBid),
                  // Pending pe Expiration: GTC, Market pe Fill policy.
                  _isPending ? _expirationRow() : _fillRow(),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: tradingService,
                      builder: (context, _) {
                        final q = tradingService.quotes[_symbol];
                        return _chartArea(
                          q?.bid ?? 0,
                          q?.ask ?? 0,
                          q?.digits ?? digits,
                        );
                      },
                    ),
                  ),
                  // Attention line sirf Market Execution me
                  // ayegi, pending orders me nahi. Keyboard khula
                  // ho tab bhi hide rahegi (overflow se bachne ko).
                  if (keyboardHeight == 0 && !_isPending)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 6, 20, 8),
                      child: Text(
                        'Attention! The trade will be executed at market '
                        'conditions, difference with requested price may be '
                        'significant!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ),
                  // Fixed bottom bar ke liye jagah (keyboard khula
                  // ho to bar chart ke upar float karega, jagah
                  // ki zaroorat nahi - dono price rows dikhengi).
                  SizedBox(height: keyboardHeight == 0 ? 56 : 0),
                ],
              ),
            ),
          ),
          // BUY/SELL bar - keyboard band ho to screen bottom pe,
          // keyboard khule to uske bilkul upar aa jayega.
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardHeight,
            child: Material(
              color: MtColors.white,
              // Live quote pe PLACE ka gray/color turant update ho.
              child: SafeArea(
                top: false,
                child: ListenableBuilder(
                  listenable: tradingService,
                  builder: (context, _) => _bottomBar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sabse upar wala bar (reference jaisa): ☰ menu icon +
  /// "New Order" title, right me documents icon.
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
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: MtColors.text,
                ),
              ),
              if (_description.isNotEmpty)
                Text(
                  _description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF757575),
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
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeSelector() {
    return GestureDetector(
      key: _typeKey,
      onTap: _showTypeMenu,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              _typeLabel,
              style: TextStyle(fontSize: 15, color: MtColors.text),
            ),
          ),
          // Border SL/TP jaisi bracket style |_________| -
          // 1px, MT5 ki tarah left/right ends me space (inset).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 7,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Color(0xFFDCDCDC), width: 1),
                          right: BorderSide(color: Color(0xFFDCDCDC), width: 1),
                          bottom: BorderSide(
                            color: Color(0xFFDCDCDC),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Chhota triangle border ke UPAR baithega,
                  // niche nahi latkega.
                  Positioned(
                    right: 0,
                    bottom: 1,
                    child: CustomPaint(
                      size: const Size(8, 8),
                      painter: _CornerTrianglePainter(),
                    ),
                  ),
                ],
              ),
            ),
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
          child: Text(label, style: TextStyle(fontSize: 13, color: color)),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              step('-0.5', -0.5, MtColors.bid),
              step('-0.1', -0.1, MtColors.bid),
              step('-0.01', -0.01, MtColors.bid),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _volumeCtrl,
                  focusNode: _volumeFocus,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_qtyFormat],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MtColors.text,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim());
                    if (parsed != null) _volume = parsed;
                  },
                  onEditingComplete: _syncVolumeFromField,
                  onTapOutside: (_) {
                    _syncVolumeFromField();
                    _volumeFocus.unfocus();
                  },
                ),
              ),
              step('+0.01', 0.01, MtColors.bid),
              step('+0.1', 0.1, MtColors.bid),
              step('+0.5', 0.5, MtColors.bid),
            ],
          ),
        ),
        // Volume row ke niche border - MT5 style left/right
        // ends me space (inset) ke saath.
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 1,
          color: const Color(0xFFDCDCDC),
        ),
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
    required TextEditingController ctrl,
    required FocusNode focus,
  }) {
    // Koi modal/popup nahi - SL/TP ki tarah price bhi yahi
    // direct type hoga. Bahar se value badle to field update
    // ho, typing ke time haath nahi lagega.
    if (!focus.hasFocus) {
      final want = value != null ? value.toStringAsFixed(digits) : '';
      if (ctrl.text != want) ctrl.text = want;
    }
    // Stepper chalane pe current market price se +/- hoga.
    final stepBase = value ?? base;
    // Field ki width number ke text jitni hi - warna number
    // center ki jagah left side zyada dikhta tha.
    final numLen =
        (value != null
                ? value.toStringAsFixed(digits)
                : (0).toStringAsFixed(digits))
            .length;
    final fieldWidth = numLen * 8.2 + 4;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              IconButton(
                onPressed: stepBase > 0
                    ? () => onChanged(_roundTo(stepBase - step, digits))
                    : null,
                icon: Icon(Icons.remove, color: MtColors.bid, size: 18),
              ),
              Expanded(
                // Center me "Price: [0.00000]" - label gray,
                // value wala hissa direct TextField hai.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$label:  ',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757575),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: ctrl,
                        focusNode: focus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_priceFormat],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MtColors.text,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 1,
                          ),
                          hintText: (0).toStringAsFixed(digits),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: MtColors.text,
                          ),
                        ),
                        onChanged: (v) {
                          final p = double.tryParse(v.trim());
                          onChanged(p != null && p > 0 ? p : null);
                        },
                        onTapOutside: (_) {
                          final p = double.tryParse(ctrl.text.trim());
                          ctrl.text = (p != null && p > 0)
                              ? p.toStringAsFixed(digits)
                              : '';
                          focus.unfocus();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: stepBase > 0
                    ? () => onChanged(_roundTo(stepBase + step, digits))
                    : null,
                icon: Icon(Icons.add, color: MtColors.bid, size: 18),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 1,
          color: const Color(0xFFDCDCDC),
        ),
      ],
    );
  }

  /// MT5 style bada price: integer + shuru ke decimals chhote,
  /// uske baad ke 2 digit bade, aakhri digit superscript.
  /// BTC (2 digits) pe: 83460. + bade 64 — faltu zeros nahi.
  static Widget _bigPrice(double value, int digits, Color color) {
    if (value <= 0) {
      return Text(
        '--',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );
    }
    final s = value.toStringAsFixed(digits);
    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final dec = dot < 0 ? '' : s.substring(dot + 1);

    final TextStyle headStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: color,
    );
    final TextStyle bigStyle = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: color,
    );

    Widget result;
    if (dec.isEmpty) {
      result = Text(s, style: bigStyle);
    } else if (dec.length <= 2) {
      result = RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$intPart.', style: headStyle),
            TextSpan(text: dec, style: bigStyle),
          ],
        ),
      );
    } else {
      final normal = dec.substring(0, dec.length - 3);
      final big = dec.substring(dec.length - 3, dec.length - 1);
      final small = dec.substring(dec.length - 1);
      result = RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: normal.isEmpty ? '$intPart.' : '$intPart.$normal',
              style: headStyle,
            ),
            TextSpan(text: big, style: bigStyle),
            // Aakhri digit number ke bilkul UPAR (superscript) -
            // center ya niche nahi.
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Transform.translate(
                offset: const Offset(1, -3),
                child: Text(
                  small,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.0,
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
    // Badi कीमत (BTC 83460.64) aadhi screen me wrap na ho.
    return FittedBox(fit: BoxFit.scaleDown, child: result);
  }

  Widget _bigPrices(double bid, double ask, int digits) {
    final key = '$bid|$ask|$digits';
    if (_bigCache != null && key == _bigCacheKey) return _bigCache!;
    final w = Padding(
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
    _bigCache = w;
    _bigCacheKey = key;
    return w;
  }

  static Widget _slTpHalf({
    required String label,
    required double? value,
    required int digits,
    required double base,
    required ValueChanged<double?> onChanged,
    required double step,
    required TextEditingController ctrl,
    required FocusNode focus,
  }) {
    final shown = value ?? base;
    // Bahar se value badle (stepper/reset) to field bhi update
    // ho - lekin typing ke time bilkul haath nahi lagana.
    if (!focus.hasFocus) {
      final want = value != null ? value.toStringAsFixed(digits) : '';
      if (ctrl.text != want) ctrl.text = want;
    }
    return Row(
      children: [
        IconButton(
          onPressed: shown > 0
              ? () => onChanged(_roundTo(shown - step, digits))
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 28),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(38, 28),
            padding: EdgeInsets.zero,
          ),
          icon: const Text(
            '\u2212',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0066FF),
            ),
          ),
        ),
        Expanded(
          // Direct type hoga - koi popup/model nahi.
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_priceFormat],
            style: TextStyle(fontSize: 15, color: MtColors.text),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 1),
              hintText: label,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF757575),
              ),
            ),
            onChanged: (v) {
              final p = double.tryParse(v.trim());
              onChanged(p != null && p > 0 ? p : null);
            },
            onTapOutside: (_) {
              final p = double.tryParse(ctrl.text.trim());
              ctrl.text = (p != null && p > 0) ? p.toStringAsFixed(digits) : '';
              focus.unfocus();
            },
          ),
        ),
        IconButton(
          onPressed: shown > 0
              ? () => onChanged(_roundTo(shown + step, digits))
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 28),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(38, 28),
            padding: EdgeInsets.zero,
          ),
          icon: const Text(
            '+',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0066FF),
            ),
          ),
        ),
      ],
    );
  }

  // Sirf NEECHE bracket line |_________| (koi pura box nahi),
  // lekin puri chaudi - taake - aur + usi ke andar aaye.
  static Widget _bracketHalf(Widget half, Color borderColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        half,
        Container(
          height: 6,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor, width: 1),
              right: BorderSide(color: borderColor, width: 1),
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _slTpRow(int digits, double bid) {
    return Padding(
      // Upar (Price / Stop Limit price ke neeche) thodi margin.
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _bracketHalf(
              _slTpHalf(
                label: 'SL',
                value: _sl,
                digits: digits,
                base: bid,
                onChanged: (v) => setState(() => _sl = v),
                step: _step(digits),
                ctrl: _slCtrl,
                focus: _slFocus,
              ),
              const Color(0xFFFF7A00),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _bracketHalf(
              _slTpHalf(
                label: 'TP',
                value: _tp,
                digits: digits,
                base: bid,
                onChanged: (v) => setState(() => _tp = v),
                step: _step(digits),
                ctrl: _tpCtrl,
                focus: _tpFocus,
              ),
              const Color(0xFF43A047),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fillRow() => _bracketRow(
    label: 'Fill policy',
    value: _fillPolicy,
    onTap: _showFillMenu,
    rowKey: _fillKey,
  );

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

  String get _expirationLabel {
    final at = _expireAt;
    return switch (_expireType) {
      'TODAY' => 'Today',
      'SPECIFIED' =>
        at == null
            ? 'Specified'
            : '${at.day} ${_months[at.month - 1]} ${at.year}',
      'SPECIFIED_DAY' =>
        at == null
            ? 'Specified day'
            : '${at.day} ${_months[at.month - 1]} ${at.year} '
                  '${at.hour.toString().padLeft(2, '0')}:'
                  '${at.minute.toString().padLeft(2, '0')}',
      _ => 'GTC',
    };
  }

  // Pending orders pe MT5 jaisa "Expiration:  GTC" row - tap
  // karne pe menu khulega (GTC/Today/Specified/Specified day).
  Widget _expirationRow() => _bracketRow(
    label: 'Expiration:',
    value: _expirationLabel,
    onTap: _showExpirationMenu,
    rowKey: _expirationKey,
  );

  static Widget _bracketRow({
    required String label,
    required String value,
    required VoidCallback? onTap,
    Key? rowKey,
  }) {
    return Column(
      children: [
        // SL/TP ke neeche saaf dikhne wali khali gap.
        const SizedBox(height: 22),
        GestureDetector(
          key: rowKey,
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 6, 26, 2),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, color: MtColors.text),
                ),
              ],
            ),
          ),
        ),
        // Fill policy ke niche Market Execution jaisi bracket
        // border |_________| - right kone wala triangle border
        // ko touch karke uske upar baithega.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 7,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFDCDCDC), width: 1),
                        right: BorderSide(color: Color(0xFFDCDCDC), width: 1),
                        bottom: BorderSide(color: Color(0xFFDCDCDC), width: 1),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 1,
                  child: CustomPaint(
                    size: const Size(8, 8),
                    painter: _CornerTrianglePainter(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chartArea(double bid, double ask, int digits) {
    final pairs = tradingService.tickPairsFor(_symbol, max: 160);
    final key =
        '$_symbol|$bid|$ask|$digits|${_isPending ? _price : null}'
        '|${_isStopLimit ? _limitPrice : null}|$_sl|$_tp'
        '|${pairs.length}|${pairs.isEmpty ? 0 : pairs.last.bid}'
        '|${pairs.isEmpty ? 0 : pairs.last.ask}';
    if (_chartCache != null && key == _chartCacheKey) return _chartCache!;
    // RepaintBoundary: tick repaint sirf chart tak seemit rahega,
    // poora page dobara rasterize nahi hoga - UI smooth rahega.
    final w = RepaintBoundary(
      child: CustomPaint(
        painter: _TickChartPainter(
          pairs: pairs,
          bid: bid,
          ask: ask,
          digits: digits,
          orderPrice: _isPending ? _price : null,
          limitPrice: _isStopLimit ? _limitPrice : null,
          sl: _sl,
          tp: _tp,
        ),
        size: Size.infinite,
      ),
    );
    _chartCache = w;
    _chartCacheKey = key;
    return w;
  }

  /// MT5 jaisa PLACE tabhi active hoga jab price direction
  /// sahi ho (Buy Limit market se neeche, Buy Stop upar...).
  /// Warna PLACE gray + disabled rahega, screenshot jaisa.
  bool _placeValid() {
    final p = _price;
    if (p == null || p <= 0) return false;
    if (_isStopLimit && (_limitPrice == null || _limitPrice! <= 0)) {
      return false;
    }
    final q = tradingService.quotes[_symbol];
    final bid = q?.bid ?? 0;
    final ask = q?.ask ?? 0;
    if (bid <= 0 || ask <= 0) return true;
    return switch (_type) {
      'BUY_LIMIT' => p < ask,
      'SELL_LIMIT' => p > bid,
      'BUY_STOP' || 'BUY_STOP_LIMIT' => p > ask,
      'SELL_STOP' || 'SELL_STOP_LIMIT' => p < bid,
      _ => true,
    };
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _busy ? '...' : title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              // Sub khali ho (PLACE) to niche kuch bhi nahi ayega.
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(sub, style: TextStyle(fontSize: 9, color: color)),
              ],
            ],
          ),
        ),
      );
    }

    // Bottom bar hamesha fixed rahega - fixed height, page ke
    // content/keyboard se iski size/position nahi badlegi.
    // Upar koi border nahi (Attention text ke niche line na lage).
    return SizedBox(
      height: 56,
      child: _isPending
          ? Row(
              children: [
                action(
                  title: 'PLACE',
                  // PLACE ke niche koi text nahi ayega.
                  sub: '',
                  // Price galat/zero ho to PLACE gray + band.
                  color: _placeValid()
                      ? (_isBuyType ? MtColors.bid : MtColors.ask)
                      : const Color(0xFFBDBDBD),
                  onTap: (_busy || !_placeValid()) ? null : () => _submit(''),
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
                Container(width: 1, height: 36, color: MtColors.line),
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

/// Trade-Portal style full-screen order result: blue circle +
/// spinning ring "Order has been placed in queue...", phir green
/// circle "Done" ya red "Order Failed". Result apne aap aage badhta hai.
/// Queue -> Done/Failed screen bahar (Trade screen) se bhi chala sako,
/// jaise modify order / modify position ke liye.
Future<bool?> showTradeExecution(
  BuildContext context, {
  required String title,
  required String side,
  required String symbol,
  required int digits,
  required List<String> lines,
  required Future<void> Function() task,
}) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, _, _) => _OrderResultScreen(
        title: title,
        side: side,
        typeLabel: '',
        volumeText: '',
        symbol: symbol,
        queuePrice: null,
        digits: digits,
        lines: lines,
        task: () async {
          await task();
          return const <String, dynamic>{};
        },
      ),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _OrderResultScreen extends StatefulWidget {
  const _OrderResultScreen({
    this.title = 'New Order',
    this.lines,
    required this.side,
    required this.typeLabel,
    required this.volumeText,
    required this.symbol,
    required this.queuePrice,
    required this.digits,
    required this.task,
  });

  final String title;

  /// Set ho to queue/done/failed pe standard order lines ki jagah yahi
  /// gray lines dikhengi (modify ke liye).
  final List<String>? lines;
  final String side;
  final String typeLabel;
  final String volumeText;
  final String symbol;
  final double? queuePrice;
  final int digits;
  final Future<Map<String, dynamic>> Function() task;

  @override
  State<_OrderResultScreen> createState() => _OrderResultScreenState();
}

class _OrderResultScreenState extends State<_OrderResultScreen> {
  String _status = 'queue'; // queue | success | error
  double? _price;
  String _ticket = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final started = DateTime.now();
    // Queue screen kam se kam 3 second dikhaye, phir result par jaye.
    Future<void> minQueueWait() async {
      final elapsed = DateTime.now().difference(started);
      const minQueue = Duration(seconds: 3);
      if (elapsed < minQueue) await Future<void>.delayed(minQueue - elapsed);
    }

    try {
      final result = await widget.task();
      await minQueueWait();
      if (!mounted) return;
      setState(() {
        _status = 'success';
        final p = result['price'];
        _price = p is num ? p.toDouble() : null;
        _ticket = '${result['ticket'] ?? ''}';
      });
      unawaited(TradeSound.ok());
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      await minQueueWait();
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _error = '$e';
      });
      unawaited(TradeSound.error());
      await Future<void>.delayed(const Duration(seconds: 5));
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  String _fmt(double v) => v.toStringAsFixed(widget.digits);

  /// Queue screen ki neeche wali ek line (reference jaisi):
  /// "market BUY EURUSD at 1.12319" - market/type gray,
  /// BUY/SELL side color me bold, baaki sab gray.
  Widget _queueLine(double? price) {
    final kind = widget.typeLabel == 'MARKET EXECUTION'
        ? 'market'
        : widget.typeLabel.toLowerCase();
    const gray = TextStyle(fontSize: 13.5, color: Color(0xFF757575));
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(text: '$kind ', style: gray),
          TextSpan(
            text: widget.side,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _sideColor,
            ),
          ),
          TextSpan(
            text: price != null
                ? ' ${widget.symbol} at ${_fmt(price)}'
                : ' ${widget.symbol} by market',
            style: gray,
          ),
        ],
      ),
    );
  }

  Color get _sideColor => widget.side == 'SELL' ? MtColors.ask : MtColors.bid;

  Widget _sideLine(String rest, {double size = 18, bool grayRest = false}) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: widget.side,
            style: TextStyle(
              fontSize: size,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: _sideColor,
            ),
          ),
          TextSpan(
            text: ' $rest',
            style: grayRest
                ? TextStyle(
                    fontSize: size,
                    height: 1.15,
                    color: const Color(0xFF757575),
                  )
                : TextStyle(fontSize: size, height: 1.15, color: MtColors.text),
          ),
        ],
      ),
    );
  }

  Widget _circle() {
    if (_status == 'queue') {
      return SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                // Reference wala halka sky-blue gol icon.
                color: Color(0xFF00A6F6),
              ),
              child: const Icon(
                Icons.pending_actions,
                color: Colors.white,
                size: 44,
              ),
            ),
            const Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A6F6)),
                backgroundColor: Color(0xFFE3F2FD),
              ),
            ),
          ],
        ),
      );
    }
    final success = _status == 'success';
    // Done pe user ki di hui Green Document Check icon image.
    if (success) {
      return ClipOval(
        child: SizedBox(
          width: 88,
          height: 88,
          // Image ka apna green gola pura frame bhare.
          child: Transform.scale(
            scale: 1.28,
            child: Image.asset(
              'assets/icons/order_done.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE53935),
      ),
      child: const Icon(Icons.close, color: Colors.white, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final queue = _status == 'queue';
    final success = _status == 'success';
    final shownPrice = success ? _price : widget.queuePrice;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: MtColors.white,
        appBar: AppBar(
          backgroundColor: MtColors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.menu, color: Color(0xFF212121)),
          ),
          titleSpacing: 0,
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MtColors.text,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: Image.asset(
                'assets/icons/copy_docs.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        // Bottom me full-width halka gray HIDE bar - queue
        // screen pe ayega; result screen khud se aage badhegi.
        bottomNavigationBar: SafeArea(
          top: false,
          child: InkWell(
            onTap: queue ? null : () => Navigator.of(context).pop(success),
            child: Container(
              height: 54,
              color: const Color(0xFFF5F5F5),
              alignment: Alignment.center,
              child: Text(
                queue
                    ? 'HIDE'
                    : _status == 'error'
                    ? 'OK'
                    : 'DONE',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: queue
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF000000),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: h * (queue ? 0.08 : 0.12)),
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _circle(),
                  SizedBox(height: success ? 16 : 32),
                  Text(
                    queue
                        ? 'Order has been placed in queue...'
                        : success
                        ? 'Done'
                        : 'Order Failed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // Done/Queue title bold, reference jaisa.
                      fontSize: queue
                          ? 18
                          : success
                          ? 17
                          : 30,
                      fontWeight: FontWeight.w700,
                      color: MtColors.text,
                    ),
                  ),
                  SizedBox(height: success ? 10 : 14),
                  if (widget.lines != null) ...[
                    for (final line in widget.lines!)
                      Text(
                        line,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.25,
                          color: Color(0xFF757575),
                        ),
                      ),
                    if (_status == 'error') ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],
                  ] else if (queue) ...[
                    // Reference jaisi ek hi line, volume wali
                    // line queue screen pe nahi ayegi.
                    _queueLine(shownPrice),
                  ] else if (success) ...[
                    // Reference jaisi chhoti gray lines:
                    // "BUY 0.02 / 0.02" / "EURUSD at market"
                    // / "#11045124898"
                    _sideLine(
                      '${widget.volumeText} / ${widget.volumeText}',
                      size: 13,
                      grayRest: true,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.typeLabel == 'MARKET EXECUTION'
                          ? '${widget.symbol} at market'
                          : shownPrice != null
                          ? '${widget.symbol} at ${_fmt(shownPrice)}'
                          : '${widget.symbol} by market',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.15,
                        color: Color(0xFF757575),
                      ),
                    ),
                    if (_ticket.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        '#$_ticket',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.15,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ] else ...[
                    _sideLine(widget.typeLabel),
                    const SizedBox(height: 4),
                    Text(
                      shownPrice != null
                          ? '${widget.symbol} at ${_fmt(shownPrice)}'
                          : '${widget.symbol} by market',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// MT5 style Expiration picker: upar Month/Day/Year wheels,
/// "Specified day" pe neeche Hour/Minute wheels bhi.
/// Cancel / OK neele buttons - screenshot jaisa.
class _ExpirationPickerDialog extends StatefulWidget {
  const _ExpirationPickerDialog({
    required this.withTime,
    required this.initial,
  });

  final bool withTime;
  final DateTime initial;

  @override
  State<_ExpirationPickerDialog> createState() =>
      _ExpirationPickerDialogState();
}

class _ExpirationPickerDialogState extends State<_ExpirationPickerDialog> {
  static const _monthNames = [
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

  late int _month;
  late int _day;
  late int _year;
  late int _hour;
  late int _minute;

  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  int get _baseYear => DateTime.now().year;
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _month = i.month;
    _day = i.day;
    _year = i.year < _baseYear ? _baseYear : i.year;
    _hour = i.hour;
    _minute = i.minute;
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _yearCtrl = FixedExtentScrollController(initialItem: _year - _baseYear);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _yearCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
  }) {
    // Screenshot jaisa wheel: selected value black, upar/
    // neeche wali values halki gray, selected row ke upar
    // aur neeche patli line (har column ki alag).
    return Expanded(
      child: Stack(
        children: [
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 38,
            diameterRatio: 6,
            overAndUnderCenterOpacity: 0.25,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, i) => Center(
                child: Text(
                  label(i),
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 38,
            bottom: 38,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF424242), width: 1.8),
                    bottom: BorderSide(color: Color(0xFF424242), width: 1.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MtColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        // Screenshot jaisa uncha dialog - title upar, wheels
        // beech me, Cancel/OK sabse neeche. Andar top/bottom
        // padding zyada rakhi hai.
        height: widget.withTime ? 520 : 420,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 52, 30, 28),
          child: Column(
            children: [
              Text(
                'Expiration',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: MtColors.text,
                ),
              ),
              const SizedBox(height: 68),
              SizedBox(
                height: 114,
                child: Row(
                  children: [
                    _wheel(
                      controller: _monthCtrl,
                      count: 12,
                      label: (i) => _monthNames[i],
                      onChanged: (i) => setState(() {
                        _month = i + 1;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                    const SizedBox(width: 18),
                    _wheel(
                      controller: _dayCtrl,
                      count: _daysInMonth,
                      label: (i) => '${i + 1}',
                      onChanged: (i) => _day = i + 1,
                    ),
                    const SizedBox(width: 18),
                    _wheel(
                      controller: _yearCtrl,
                      count: 6,
                      label: (i) => '${_baseYear + i}',
                      onChanged: (i) => setState(() {
                        _year = _baseYear + i;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                  ],
                ),
              ),
              if (widget.withTime) ...[
                const SizedBox(height: 30),
                SizedBox(
                  height: 114,
                  child: Row(
                    children: [
                      const Spacer(),
                      _wheel(
                        controller: _hourCtrl,
                        count: 24,
                        label: (i) => '$i',
                        onChanged: (i) => _hour = i,
                      ),
                      const SizedBox(width: 18),
                      _wheel(
                        controller: _minuteCtrl,
                        count: 60,
                        label: (i) => '$i',
                        onChanged: (i) => _minute = i,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 14, color: Color(0xFF2196F3)),
                    ),
                  ),
                  const SizedBox(width: 26),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(DateTime(_year, _month, _day, _hour, _minute)),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontSize: 14, color: Color(0xFF2196F3)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MT5 New Order wala tick chart: halki grid + right side price
/// scale, bid ticks ki line (upar = blue, neeche = red), aur
/// bid (blue) / ask (red) horizontal lines apne price chips ke
/// saath. Pending price aur SL/TP set ho to unki lines bhi.
class _TickChartPainter extends CustomPainter {
  _TickChartPainter({
    required this.pairs,
    required this.bid,
    required this.ask,
    required this.digits,
    this.orderPrice,
    this.limitPrice,
    this.sl,
    this.tp,
  });

  final List<({double bid, double ask})> pairs;
  final double bid;
  final double ask;
  final int digits;
  final double? orderPrice;
  final double? limitPrice;
  final double? sl;
  final double? tp;

  static const double _scaleWidth = 64;

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos,
    double size,
    Color color, {
    bool bold = false,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    final dx = align == TextAlign.right ? pos.dx - tp.width : pos.dx;
    tp.paint(canvas, Offset(dx, pos.dy - tp.height / 2));
  }

  void _chip(Canvas canvas, Size size, double y, double price, Color color) {
    final text = price.toStringAsFixed(digits);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 9.5,
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 12;
    // Koi border radius nahi - pura square chip.
    final rect = Rect.fromLTWH(size.width - w, y - 9, w, 18);
    canvas.drawRect(rect, Paint()..color = color);
    tp.paint(canvas, Offset(size.width - w + 6, y - tp.height / 2));
  }

  void _hLine(
    Canvas canvas,
    Size size,
    double y,
    Color color, {
    bool dashed = false,
    double width = 1,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = width;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + 6, y), paint);
      x += 11;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final point = math.pow(10, -digits).toDouble();

    // Min/max ek hi loop me - har tick pe badi list allocations
    // nahi hongi, paint fast hoga.
    var minV = double.infinity;
    var maxV = double.negativeInfinity;
    void include(double v) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }

    for (final p in pairs) {
      include(p.bid);
      include(p.ask);
    }
    if (bid > 0) include(bid);
    if (ask > 0) include(ask);
    if (orderPrice != null) include(orderPrice!);
    if (limitPrice != null) include(limitPrice!);
    if (sl != null) include(sl!);
    if (tp != null) include(tp!);
    if (!minV.isFinite || !maxV.isFinite) return;
    var range = maxV - minV;
    final minRange = 24 * point;
    if (range < minRange) {
      final mid = (maxV + minV) / 2;
      minV = mid - minRange / 2;
      maxV = mid + minRange / 2;
      range = minRange;
    } else {
      final pad = range * 0.18;
      minV -= pad;
      maxV += pad;
      range = maxV - minV;
    }

    double yFor(double v) => size.height - (v - minV) / range * size.height;
    final plotW = size.width - _scaleWidth;

    // Grid lines + right price scale (MT5 style halki lines).
    // Sabse upar wali (i=0) line nahi - warna wo Fill policy ki
    // border jaisi chart ke andar dikhti hai.
    const rows = 7;
    final gridPaint = Paint()
      ..color = const Color(0xFFD8D8D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Neeche wali aakhri line bhi nahi - warna Attention text ke
    // upar border jaisi lagti hai. Scale lines dotted (dashed)
    // style me draw hongi.
    // Saari dotted grid lines ek hi Path me - alag-alag drawLine
    // calls se kai guna fast.
    final gridPath = Path();
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      // Scale line sirf plot area tak (price labels se pehle
      // rukegi) - puri right width me chipki nahi rahegi.
      var gx = 0.0;
      while (gx < plotW) {
        gridPath.moveTo(gx, y);
        gridPath.lineTo(math.min(gx + 5, plotW), y);
        gx += 9;
      }
    }
    canvas.drawPath(gridPath, gridPaint);
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      final price = maxV - range * i / rows;
      _drawText(
        canvas,
        price.toStringAsFixed(digits),
        Offset(size.width - 6, y),
        9.5,
        const Color(0xFF9E9E9E),
        align: TextAlign.right,
      );
    }

    // Bid (blue) aur Ask (red) ki ALAG-ALAG tick lines - poori
    // line ek Path me ek hi draw call me (pehle har segment ke
    // liye alag drawLine tha, wahi jank ki wajah tha).
    void polyline(bool useAsk, Color color) {
      if (pairs.length < 2) return;
      final n = pairs.length;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final v = useAsk ? pairs[i].ask : pairs[i].bid;
        final x = plotW * i / (n - 1);
        final y = yFor(v);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }

    polyline(true, MtColors.ask);
    polyline(false, MtColors.bid);

    // SL (red dashed) / TP (green dashed) / pending price (gray).
    if (orderPrice != null) {
      _hLine(canvas, size, yFor(orderPrice!), const Color(0xFF9E9E9E));
      _chip(
        canvas,
        size,
        yFor(orderPrice!),
        orderPrice!,
        const Color(0xFF9E9E9E),
      );
    }
    // Buy/Sell Stop Limit ki dusri (limit) price line bhi gray me.
    if (limitPrice != null) {
      _hLine(
        canvas,
        size,
        yFor(limitPrice!),
        const Color(0xFF9E9E9E),
        dashed: true,
      );
      _chip(
        canvas,
        size,
        yFor(limitPrice!),
        limitPrice!,
        const Color(0xFF9E9E9E),
      );
    }
    if (sl != null) {
      _hLine(canvas, size, yFor(sl!), MtColors.ask, dashed: true);
      _drawText(
        canvas,
        'SL',
        Offset(6, yFor(sl!) - 10),
        9.5,
        MtColors.ask,
        bold: true,
      );
    }
    if (tp != null) {
      _hLine(canvas, size, yFor(tp!), const Color(0xFF43A047), dashed: true);
      _drawText(
        canvas,
        'TP',
        Offset(6, yFor(tp!) - 10),
        9.5,
        const Color(0xFF43A047),
        bold: true,
      );
    }

    // Ask (red) upar, Bid (blue) neeche - chips ke saath (solid).
    if (ask > 0) {
      _hLine(canvas, size, yFor(ask), MtColors.ask);
      _chip(canvas, size, yFor(ask), ask, MtColors.ask);
    }
    if (bid > 0) {
      _hLine(canvas, size, yFor(bid), MtColors.bid);
      // Spread chhota ho to bid chip ask chip se takraye nahi.
      var chipY = yFor(bid);
      if (ask > 0 && (chipY - yFor(ask)).abs() < 22) chipY = yFor(ask) + 24;
      _chip(canvas, size, chipY, bid, MtColors.bid);
    }
  }

  @override
  bool shouldRepaint(covariant _TickChartPainter old) {
    return old.bid != bid ||
        old.ask != ask ||
        old.digits != digits ||
        old.orderPrice != orderPrice ||
        old.limitPrice != limitPrice ||
        old.sl != sl ||
        old.tp != tp ||
        old.pairs.length != pairs.length ||
        (pairs.isNotEmpty &&
            old.pairs.isNotEmpty &&
            (pairs.last.bid != old.pairs.last.bid ||
                pairs.last.ask != old.pairs.last.ask));
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
