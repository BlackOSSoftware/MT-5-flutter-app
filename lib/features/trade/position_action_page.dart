part of 'new_order_page.dart';

enum PositionAction { close, modify }

/// MT5 style "Close position #ticket" / "Modify position #ticket" screen.
class PositionActionPage extends StatefulWidget {
  const PositionActionPage({
    super.key,
    required this.position,
    required this.action,
  });

  final LivePosition position;
  final PositionAction action;

  @override
  State<PositionActionPage> createState() => _PositionActionPageState();
}

class _PositionActionPageState extends State<PositionActionPage> {
  static const _orange = Color(0xFFF5A623);
  static const _disabled = Color(0xFFBDBDBD);
  static const _fillPolicies = ['Fill or Kill', 'Immediate or Cancel'];

  // Volume integer lots*100 me - 0.04 + 0.01 jaisa float error nahi.
  late int _volCents = (widget.position.volume * 100).round();
  double get _volume => _volCents / 100;
  int get _maxCents => (_pos.volume * 100).round();
  late final _volumeCtrl = TextEditingController(
    text: _volume.toStringAsFixed(2),
  );
  final _volumeFocus = FocusNode();

  /// Sirf digits + ek point (max 2 decimal), aur position ke
  /// volume se zyada type hi nahi hoga.
  late final _qtyFormat = TextInputFormatter.withFunction((oldV, newV) {
    final t = newV.text;
    if (t.isEmpty) return newV;
    if (!RegExp(r'^\d{1,3}(\.\d{0,2})?$').hasMatch(t)) return oldV;
    final v = double.tryParse(t);
    if (v != null && (v * 100).round() > _maxCents) return oldV;
    return newV;
  });
  late final double? _initialSl = _positive(widget.position.stopLoss);
  late final double? _initialTp = _positive(widget.position.takeProfit);
  late double? _sl = _initialSl;
  late double? _tp = _initialTp;
  String _fillPolicy = _fillPolicies.first;
  bool _busy = false;
  String _error = '';

  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _slFocus = FocusNode();
  final _tpFocus = FocusNode();
  final _fillKey = GlobalKey();

  static double? _positive(double? v) => v != null && v > 0 ? v : null;

  bool get _isClose => widget.action == PositionAction.close;
  String get _symbol => widget.position.symbol;
  LivePosition get _pos =>
      tradingService.positions[widget.position.positionId] ?? widget.position;

  @override
  void initState() {
    super.initState();
    tradingService.subscribe(_symbol);
    tradingService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onServiceChanged);
    _volumeCtrl.dispose();
    _volumeFocus.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    _slFocus.dispose();
    _tpFocus.dispose();
    super.dispose();
  }

  /// Position SL/TP/stop-out se band ho jaye to screen bhi band.
  void _onServiceChanged() {
    if (!mounted || _busy) return;
    if (!tradingService.positions.containsKey(widget.position.positionId)) {
      Navigator.of(context).maybePop();
    }
  }

  int get _digits {
    final q = tradingService.quotes[_symbol];
    return q?.digits ?? digitsFor(_symbol, widget.position.openPrice);
  }

  void _readSlTpFields() {
    double? parse(TextEditingController c) {
      final v = double.tryParse(c.text.trim());
      return v != null && v > 0 ? v : null;
    }

    _sl = parse(_slCtrl);
    _tp = parse(_tpCtrl);
    _slFocus.unfocus();
    _tpFocus.unfocus();
  }

  bool _same(double? a, double? b) {
    if (a == null || b == null) return a == b;
    return (a - b).abs() < math.pow(10, -_digits) / 2;
  }

  bool get _slTpChanged => !_same(_sl, _initialSl) || !_same(_tp, _initialTp);

  bool get _slTpValid {
    final q = tradingService.quotes[_symbol];
    final p = _pos;
    final bid = q?.bid ?? p.currentPrice;
    final ask = q?.ask ?? p.currentPrice;
    if (bid <= 0 || ask <= 0) return true;
    if (p.isBuy) {
      return (_sl == null || _sl! < bid) && (_tp == null || _tp! > bid);
    }
    return (_sl == null || _sl! > ask) && (_tp == null || _tp! < ask);
  }

  /* ---------------- actions ---------------- */

  bool _canStep(int deltaCents) {
    final next = _volCents + deltaCents;
    return next >= 1 && next <= _maxCents;
  }

  void _bumpVolume(int deltaCents) {
    if (!_canStep(deltaCents)) return;
    _volumeFocus.unfocus();
    setState(() {
      _volCents += deltaCents;
      _volumeCtrl.text = _volume.toStringAsFixed(2);
    });
  }

  /// Field se volume padho, 0.01..position volume me bandho.
  void _syncVolumeFromField() {
    final v = double.tryParse(_volumeCtrl.text.trim());
    final cents = v == null ? _volCents : (v * 100).round();
    setState(() {
      _volCents = cents.clamp(1, _maxCents);
      _volumeCtrl.text = _volume.toStringAsFixed(2);
    });
  }

  Future<void> _submitClose() async {
    _syncVolumeFromField();
    _volumeFocus.unfocus();
    final p = _pos;
    if (_volCents < _maxCents) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partial close is not supported yet')),
      );
      return;
    }
    _readSlTpFields();
    final q = tradingService.quotes[_symbol];
    final closePrice = p.isBuy ? q?.bid : q?.ask;
    final digits = _digits;
    setState(() => _busy = true);
    final done = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, _, _) => _OrderResultScreen(
          title: 'Close position',
          side: p.isBuy ? 'SELL' : 'BUY',
          typeLabel: 'MARKET EXECUTION',
          volumeText: _volume.toStringAsFixed(2),
          symbol: _symbol,
          queuePrice: closePrice,
          digits: digits,
          task: () async {
            final data = await tradingService.closePosition(p.positionId);
            final closeTicket = data['closeTicket'];
            return {
              'price': closePrice,
              'ticket': closeTicket is num ? '${closeTicket.toInt()}' : '',
            };
          },
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done == true) Navigator.of(context).pop();
  }

  Future<void> _submitModify() async {
    _readSlTpFields();
    if (!_slTpValid) {
      setState(() => _error = 'Invalid S/L or T/P');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final p = _pos;
    final digits = _digits;
    String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(digits);
    final sl = _sl;
    final tp = _tp;
    final done = await showTradeExecution(
      context,
      title: 'Modify position',
      side: p.isBuy ? 'BUY' : 'SELL',
      symbol: _symbol,
      digits: digits,
      lines: [
        'modify ${p.ticket != null ? '#${p.ticket} ' : ''}'
            '${p.isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)} '
            '$_symbol',
        'sl: ${fmt(sl)}   tp: ${fmt(tp)}',
      ],
      task: () => tradingService.modifyPosition(
        positionId: p.positionId,
        stopLoss: sl,
        takeProfit: tp,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done == true) Navigator.of(context).pop();
  }

  Future<void> _showFillMenu() async {
    final box = _fillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final screenW = MediaQuery.of(context).size.width;
    final selected = _fillPolicies.indexOf(_fillPolicy);
    final picked = await showMenu<String>(
      context: context,
      color: MtColors.white,
      elevation: 8,
      shape: const RoundedRectangleBorder(),
      constraints: BoxConstraints(
        minWidth: screenW - 16,
        maxWidth: screenW - 16,
      ),
      position: RelativeRect.fromLTRB(
        16,
        (offset.dy - selected * 40 - 8).clamp(80.0, double.infinity),
        0,
        0,
      ),
      items: [
        for (final p in _fillPolicies)
          PopupMenuItem<String>(
            value: p,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                p,
                style: TextStyle(fontSize: 14, color: MtColors.text),
              ),
            ),
          ),
      ],
    );
    if (picked != null) setState(() => _fillPolicy = picked);
  }

  /* ---------------- build ---------------- */

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final digits = _digits;
    return Scaffold(
      backgroundColor: MtColors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: SafeArea(
              child: Column(
                children: [
                  _header(digits),
                  if (_isClose) _volumeRow(),
                  ListenableBuilder(
                    listenable: tradingService,
                    builder: (context, _) => _bigPrices(),
                  ),
                  _slTpRow(digits),
                  if (_isClose)
                    _NewOrderPageState._bracketRow(
                      label: 'Fill policy',
                      value: _fillPolicy,
                      onTap: _showFillMenu,
                      rowKey: _fillKey,
                    )
                  else
                    const SizedBox(height: 22),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: tradingService,
                      builder: (context, _) => _chart(),
                    ),
                  ),
                  if (keyboardHeight == 0 && _isClose)
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
                  SizedBox(height: keyboardHeight == 0 ? 56 : 0),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardHeight,
            child: Material(
              color: MtColors.white,
              child: SafeArea(
                top: false,
                child: ListenableBuilder(
                  listenable: tradingService,
                  builder: (context, _) =>
                      _isClose ? _closeBar() : _modifyBar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(int digits) {
    final p = widget.position;
    final title =
        '${_isClose ? 'Close' : 'Modify'} position'
        '${p.ticket != null ? ' #${p.ticket}' : ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: MtColors.text, size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w400,
                    color: MtColors.text,
                  ),
                ),
                Text(
                  '${p.isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)} '
                  '${p.symbol} at ${p.openPrice.toStringAsFixed(digits)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Step size position ke volume ke hisaab se: 10 lot pe
  /// 10/1/0.1, 1+ lot pe 1/0.1/0.01, chhote pe 0.5/0.1/0.01.
  List<int> get _stepCents {
    final max = _maxCents;
    if (max >= 1000) return const [1000, 100, 10];
    if (max >= 100) return const [100, 10, 1];
    return const [50, 10, 1];
  }

  static String _stepLabel(int cents) {
    final v = cents / 100;
    return v == v.roundToDouble() ? '${v.toInt()}' : '$v';
  }

  Widget _volumeRow() {
    Widget step(int deltaCents) {
      final enabled = _canStep(deltaCents);
      final label =
          '${deltaCents < 0 ? '-' : '+'}'
          '${_stepLabel(deltaCents.abs())}';
      return GestureDetector(
        onTap: enabled ? () => _bumpVolume(deltaCents) : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: enabled ? MtColors.bid : _disabled,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final s in _stepCents) step(-s),
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
                    fontSize: 17,
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
                    if (parsed == null) return;
                    final cents = (parsed * 100).round();
                    if (cents >= 1) setState(() => _volCents = cents);
                  },
                  onEditingComplete: () {
                    _syncVolumeFromField();
                    _volumeFocus.unfocus();
                  },
                  onTapOutside: (_) {
                    if (!_volumeFocus.hasFocus) return;
                    _syncVolumeFromField();
                    _volumeFocus.unfocus();
                  },
                ),
              ),
              for (final s in _stepCents.reversed) step(s),
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

  Widget _bigPrices() {
    final q = tradingService.quotes[_symbol];
    final bid = q?.bid ?? 0;
    final ask = q?.ask ?? 0;
    final digits = q?.digits ?? _digits;
    final color = (q?.priceUp ?? true) ? MtColors.bid : MtColors.ask;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 16, 30, 6),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _NewOrderPageState._bigPrice(bid, digits, color),
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _NewOrderPageState._bigPrice(ask, digits, color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slTpRow(int digits) {
    final q = tradingService.quotes[_symbol];
    final base = q?.bid ?? _pos.currentPrice;
    final step = _NewOrderPageState._step(digits);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _NewOrderPageState._bracketHalf(
              _NewOrderPageState._slTpHalf(
                label: 'SL',
                value: _sl,
                digits: digits,
                base: base,
                onChanged: (v) => setState(() {
                  _sl = v;
                  _error = '';
                }),
                step: step,
                ctrl: _slCtrl,
                focus: _slFocus,
              ),
              const Color(0xFFFF7A00),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _NewOrderPageState._bracketHalf(
              _NewOrderPageState._slTpHalf(
                label: 'TP',
                value: _tp,
                digits: digits,
                base: base,
                onChanged: (v) => setState(() {
                  _tp = v;
                  _error = '';
                }),
                step: step,
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

  Widget _chart() {
    final q = tradingService.quotes[_symbol];
    return RepaintBoundary(
      child: CustomPaint(
        painter: _TickChartPainter(
          pairs: tradingService.tickPairsFor(_symbol, max: 160),
          bid: q?.bid ?? 0,
          ask: q?.ask ?? 0,
          digits: q?.digits ?? _digits,
          sl: _sl,
          tp: _tp,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _closeBar() {
    final p = _pos;
    final pnl = p.volume > 0 ? p.floatingPnL * _volume / p.volume : 0.0;
    final profit = pnl >= 0;
    return SizedBox(
      height: 56,
      child: InkWell(
        onTap: _busy ? null : _submitClose,
        child: Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: profit ? 'CLOSE WITH PROFIT ' : 'CLOSE WITH LOSS ',
                  style: const TextStyle(color: _orange),
                ),
                TextSpan(
                  text: formatMoney(pnl),
                  style: TextStyle(color: profit ? MtColors.bid : MtColors.ask),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _modifyBar() {
    final connected = tradingService.wsConnected;
    final message = !connected
        ? 'No connection'
        : _error.isNotEmpty
        ? _error
        : '';
    final enabled = connected && !_busy && _slTpChanged && _slTpValid;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: MtColors.ask),
            ),
          ),
        SizedBox(
          height: 56,
          child: InkWell(
            onTap: enabled ? _submitModify : null,
            child: Center(
              child: Text(
                _busy ? '...' : 'MODIFY',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? _orange : _disabled,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
