import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trade_sound.dart';
import '../../core/trading_service.dart';
import '../shell/no_accounts_view.dart';
import 'chart_controller.dart';
import 'chart_icons.dart';
import 'chart_models.dart';
import 'chart_painter.dart';
import 'one_click_bar.dart';
import 'order_panel.dart';
import 'radial_menu.dart';
import 'timeframe_dialog.dart';

const _chartsTabIndex = 1;
const _blue = Color(0xFF168BE1);

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key, required this.onMenu, required this.symbol});

  final VoidCallback onMenu;
  final String symbol;

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  static const _tfKey = 'chart_timeframe';
  static const _favKey = 'chart_tf_favorites';

  final _ctrl = ChartController();
  ChartTimeframe _tf = ChartTimeframes.of('M5');
  Set<String> _favorites = {...ChartTimeframes.defaultFavorites};

  /// Viewport: candle chaudai (px) aur right se scroll (candles).
  double _spacing = 9;
  double _scroll = 0;
  double _startSpacing = 9;
  double _startScroll = 0;
  Offset _startFocal = Offset.zero;
  Size _chartSize = Size.zero;

  /// Price scale (right) pe drag = vertical zoom (1 = auto fit).
  double _vZoom = 1;
  double _startVZoom = 1;
  bool _axisDrag = false;

  /// Neeche time scale pe drag = horizontal zoom (candle chaudai).
  bool _timeAxisDrag = false;

  bool _crossMode = false;
  Offset? _cross;
  bool _tfRow = false;
  int _revision = 0;

  ShellController? _shell;
  bool _visible = false;

  /// One-click trading patti + uska volume.
  bool _oneClick = false;
  double _oneClickVolume = 0.01;

  /// Neeche wala order panel + chart pe kheenchne wali draft lines.
  bool _panel = false;
  final _draft = OrderDraft();
  String? _dragId;
  ChartScale? _dragScale;
  bool _busy = false;

  /// Long-press ka gol menu (chart-local center).
  Offset? _radial;

  @override
  void initState() {
    super.initState();
    tradingService.subscribe(widget.symbol);
    tradingService.addListener(_onLive);
    _ctrl.addListener(_onCtrl);
    _restorePrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = ShellScope.maybeOf(context);
    if (shell != _shell) {
      _shell?.removeListener(_onShell);
      _shell = shell?..addListener(_onShell);
      _onShell();
    }
  }

  @override
  void didUpdateWidget(covariant ChartsScreen old) {
    super.didUpdateWidget(old);
    if (old.symbol != widget.symbol) {
      tradingService.subscribe(widget.symbol);
      _resetView();
      _ctrl.load(widget.symbol, _tf);
    }
  }

  @override
  void dispose() {
    _shell?.removeListener(_onShell);
    tradingService.removeListener(_onLive);
    _ctrl
      ..removeListener(_onCtrl)
      ..dispose();
    super.dispose();
  }

  Future<void> _restorePrefs() async {
    final p = await SharedPreferences.getInstance();
    final tf = p.getString(_tfKey);
    final fav = p.getStringList(_favKey);
    if (!mounted) return;
    setState(() {
      if (tf != null) _tf = ChartTimeframes.of(tf);
      if (fav != null) _favorites = _normalizeFavorites(fav);
    });
    // Purane (seema se pehle ke) zyada favourites theek karke save.
    if (fav != null && fav.length != _favorites.length) {
      await p.setStringList(_favKey, _favorites.toList());
    }
    _ctrl.load(widget.symbol, _tf);
  }

  /// Chart sirf Charts tab khula ho tab live update + countdown chalaye.
  void _onShell() {
    final visible = (_shell?.tab ?? _chartsTabIndex) == _chartsTabIndex;
    if (visible == _visible) return;
    _visible = visible;
    _ctrl.setVisible(visible);
    if (visible && mounted) setState(() {});
  }

  void _onCtrl() {
    if (mounted && _visible) setState(() {});
  }

  void _onLive() {
    if (!mounted || !_visible) return;
    final q = tradingService.quotes[widget.symbol.toUpperCase()];
    if (q == null || !q.hasPrice) return;
    if (_ctrl.onTick(q.bid, q.time ?? DateTime.now())) _revision++;
    // Bid / Ask pichhle tick se upar (blue) ya neeche (red); same ho to
    // pichhla rang rehne do.
    if (_lastBid != null && q.bid != _lastBid) _bidUp = q.bid > _lastBid!;
    if (_lastAsk != null && q.ask != _lastAsk) _askUp = q.ask > _lastAsk!;
    _lastBid = q.bid;
    _lastAsk = q.ask;
    setState(() {});
  }

  double? _lastBid;
  double? _lastAsk;
  bool _bidUp = true;
  bool _askUp = true;

  void _resetView() {
    _scroll = 0;
    _cross = null;
  }

  Future<void> _selectTimeframe(String code) async {
    final tf = ChartTimeframes.of(code);
    setState(() {
      _tf = tf;
      _tfRow = false;
      _resetView();
    });
    _ctrl.load(widget.symbol, tf);
    final p = await SharedPreferences.getInstance();
    await p.setString(_tfKey, code);
  }

  /// Saved favourites 3..9 me: zyada hon to timeframe order me pehle 9,
  /// kam hon to MT5 default.
  static Set<String> _normalizeFavorites(List<String> saved) {
    final valid = [
      for (final tf in ChartTimeframes.all)
        if (saved.contains(tf.code)) tf.code,
    ];
    if (valid.length < minFavoriteTimeframes) {
      return {...ChartTimeframes.defaultFavorites};
    }
    return valid.take(maxFavoriteTimeframes).toSet();
  }

  Future<void> _toggleFavorite(String code) async {
    final isFav = _favorites.contains(code);
    // Dialog pehle hi rok deta hai; yahan bhi 3..9 ki seema pakki.
    if (isFav && _favorites.length - 1 < minFavoriteTimeframes) return;
    if (!isFav && _favorites.length + 1 > maxFavoriteTimeframes) return;
    setState(() => isFav ? _favorites.remove(code) : _favorites.add(code));
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_favKey, _favorites.toList());
  }

  Future<void> _openTimeframes() async {
    final picked = await showTimeframeDialog(
      context,
      selected: _tf.code,
      favorites: _favorites,
      onToggleFavorite: _toggleFavorite,
    );
    if (picked != null) await _selectTimeframe(picked);
  }

  /* ---------------- gestures ---------------- */

  ChartLayout get _layout => ChartLayout(
    size: _chartSize,
    count: _ctrl.candles.length,
    spacing: _spacing,
    scroll: _scroll,
  );

  double _clampScroll(double s) {
    final n = _ctrl.candles.length;
    final visible = _layout.plotWidth / _spacing;
    final minS = -math.max(0.0, visible / 2 - ChartLayout.rightMargin);
    final maxS = math.max(0.0, n - 5.0);
    return s.clamp(minS, maxS);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startSpacing = _spacing;
    _startScroll = _scroll;
    _startFocal = d.localFocalPoint;
    _startVZoom = _vZoom;
    _dragId = null;
    _axisDrag = d.pointerCount == 1 && d.localFocalPoint.dx > _layout.plotWidth;
    _timeAxisDrag =
        !_axisDrag &&
        d.pointerCount == 1 &&
        d.localFocalPoint.dy > _layout.plotBottom;
    if (_axisDrag || _timeAxisDrag) return;
    // Order panel khula ho to draft line (price / SL / TP) pakdo.
    if (_panel && d.pointerCount == 1) {
      final scale = _scale;
      if (scale == null) return;
      String? best;
      var bestDist = 22.0;
      for (final lv in _draftLevels()) {
        final dist = (scale.yOf(lv.price) - d.localFocalPoint.dy).abs();
        if (dist < bestDist) {
          bestDist = dist;
          best = lv.id;
        }
      }
      if (best != null) {
        _dragId = best;
        _dragScale = scale;
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_axisDrag) {
      // Neeche kheencho = range badi (candles chhote), upar = candles bade.
      final dy = d.localFocalPoint.dy - _startFocal.dy;
      setState(() {
        _vZoom = (_startVZoom * math.exp(dy / 180)).clamp(0.15, 8.0);
      });
      return;
    }
    if (_timeAxisDrag) {
      // Right kheencho = candles chaude, left = patle (zyada candles).
      final dx = d.localFocalPoint.dx - _startFocal.dx;
      setState(() {
        _spacing = (_startSpacing * math.exp(dx / 160)).clamp(2.0, 40.0);
        _scroll = _clampScroll(_scroll);
      });
      final (first, _) = _layout.visibleRange;
      if (first < 30) _ctrl.loadOlder();
      return;
    }
    final dragScale = _dragScale;
    if (_dragId != null && dragScale != null) {
      final price = _roundPrice(dragScale.priceAt(d.localFocalPoint.dy));
      setState(() {
        switch (_dragId) {
          case 'draft':
            _draft.price = price;
          case 'draft_sl':
            _draft.sl = price;
          case 'draft_tp':
            _draft.tp = price;
        }
      });
      return;
    }
    if (_crossMode && d.pointerCount == 1) {
      setState(() => _cross = d.localFocalPoint);
      return;
    }
    setState(() {
      _spacing = (_startSpacing * d.horizontalScale).clamp(2.0, 40.0);
      final dx = d.localFocalPoint.dx - _startFocal.dx;
      _scroll = _clampScroll(_startScroll + dx / _spacing);
    });
    final (first, _) = _layout.visibleRange;
    if (first < 30) _ctrl.loadOlder();
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _dragId = null;
    _dragScale = null;
    _axisDrag = false;
    _timeAxisDrag = false;
  }

  /* ---------------- levels (chart lines) ---------------- */

  int get _digits {
    final q = tradingService.quotes[widget.symbol.toUpperCase()];
    return _ctrl.digits ?? q?.digits ?? 5;
  }

  double _roundPrice(double p) {
    final f = math.pow(10, _digits).toDouble();
    return (p * f).round() / f;
  }

  ChartScale? get _scale {
    final q = tradingService.quotes[widget.symbol.toUpperCase()];
    return ChartScale.compute(
      candles: _ctrl.candles,
      layout: _layout,
      digits: _digits,
      bid: q != null && q.hasPrice ? q.bid : null,
      extra: [for (final l in _levels()) l.price],
      zoom: _vZoom,
    );
  }

  static String _lots(double v) => v.toStringAsFixed(2);

  /// Is symbol ki khuli positions, pending orders aur unke SL / TP.
  List<ChartLevel> _tradeLevels() {
    final sym = widget.symbol.toUpperCase();
    final out = <ChartLevel>[];
    for (final p in tradingService.positions.values) {
      if (p.symbol.toUpperCase() != sym) continue;
      out.add(
        ChartLevel(
          id: 'pos_${p.positionId}',
          price: p.openPrice,
          label: '${p.isBuy ? 'BUY' : 'SELL'} ${_lots(p.volume)}',
          color: p.isBuy ? _blue : chartDownColor,
        ),
      );
      if ((p.stopLoss ?? 0) > 0) {
        out.add(
          ChartLevel(
            id: 'pos_sl_${p.positionId}',
            price: p.stopLoss!,
            label: 'SL',
            color: chartDownColor,
            dashed: true,
          ),
        );
      }
      if ((p.takeProfit ?? 0) > 0) {
        out.add(
          ChartLevel(
            id: 'pos_tp_${p.positionId}',
            price: p.takeProfit!,
            label: 'TP',
            color: const Color(0xFF2E9E3F),
            dashed: true,
          ),
        );
      }
    }
    for (final o in tradingService.pendings.values) {
      if (o.symbol.toUpperCase() != sym) continue;
      out.add(
        ChartLevel(
          id: 'ord_${o.orderId}',
          price: o.price,
          label: '${o.orderType.replaceAll('_', ' ')} ${_lots(o.volume)}',
          color: o.isBuy ? _blue : chartDownColor,
        ),
      );
    }
    return out;
  }

  /// Order panel ki kheenchne wali lines.
  List<ChartLevel> _draftLevels() {
    if (!_panel) return const [];
    final out = <ChartLevel>[];
    final color = _draft.pending && !_draft.isBuy ? chartDownColor : _blue;
    if (_draft.pending && _draft.price != null) {
      out.add(
        ChartLevel(
          id: 'draft',
          price: _draft.price!,
          label: '${_draft.type.replaceAll('_', ' ')} ${_lots(_draft.volume)}',
          color: color,
          draggable: true,
        ),
      );
    }
    if (_draft.sl != null) {
      out.add(
        ChartLevel(
          id: 'draft_sl',
          price: _draft.sl!,
          label: 'SL',
          color: chartDownColor,
          dashed: true,
          draggable: true,
        ),
      );
    }
    if (_draft.tp != null) {
      out.add(
        ChartLevel(
          id: 'draft_tp',
          price: _draft.tp!,
          label: 'TP',
          color: const Color(0xFF2E9E3F),
          dashed: true,
          draggable: true,
        ),
      );
    }
    return out;
  }

  /// Khuli positions / pending orders ki lines abhi chart par nahi.
  static const _showTradeLines = false;

  List<ChartLevel> _levels() => [
    if (_showTradeLines) ..._tradeLevels(),
    ..._draftLevels(),
  ];

  /* ---------------- order panel / one click ---------------- */

  /// Draft line ke liye default doori: dikh rahe range ka ~15%.
  double get _offset {
    final candles = _ctrl.candles;
    if (candles.isEmpty) return math.pow(10, -_digits).toDouble() * 200;
    final scale = ChartScale.compute(
      candles: candles,
      layout: _layout,
      digits: _digits,
    );
    return (scale?.range ?? 0) * 0.15;
  }

  ({double bid, double ask})? get _prices {
    final q = tradingService.quotes[widget.symbol.toUpperCase()];
    if (q != null && q.hasPrice) return (bid: q.bid, ask: q.ask);
    final c = _ctrl.candles.isEmpty ? null : _ctrl.candles.last.c;
    return c == null ? null : (bid: c, ask: c);
  }

  void _selectOrderType(String type) {
    final px = _prices;
    final off = _offset;
    setState(() {
      _draft.type = type;
      _draft.sl = null;
      _draft.tp = null;
      if (px == null || type == 'MARKET') {
        _draft.price = null;
        return;
      }
      _draft.price = _roundPrice(switch (type) {
        'BUY_LIMIT' => px.ask - off,
        'SELL_LIMIT' => px.bid + off,
        'BUY_STOP' => px.ask + off,
        _ => px.bid - off,
      });
    });
  }

  /// SL / TP on-off. Market pe BUY ke hisaab se (SL neeche, TP upar).
  void _toggleLevel({required bool sl}) {
    final px = _prices;
    if (px == null) return;
    final entry = _draft.price ?? (_draft.isBuy ? px.ask : px.bid);
    final buy = !_draft.pending || _draft.isBuy;
    final off = _offset;
    setState(() {
      if (sl) {
        _draft.sl = _draft.sl != null
            ? null
            : _roundPrice(buy ? entry - off : entry + off);
      } else {
        _draft.tp = _draft.tp != null
            ? null
            : _roundPrice(buy ? entry + off : entry - off);
      }
    });
  }

  void _result(bool ok, String message) {
    unawaited(ok ? TradeSound.ok() : TradeSound.error());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _ticketOf(Map<String, dynamic> data) {
    final t = data['ticket'];
    return t is num ? ' #${t.toInt()}' : '';
  }

  Future<void> _marketOrder(
    String side,
    double volume, {
    double? sl,
    double? tp,
  }) async {
    if (_busy) return;
    if (!await tradingService.ensureSession()) {
      _result(false, 'Not logged in. Please login to your account.');
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await tradingService.placeMarketOrder(
        symbol: widget.symbol,
        side: side,
        volume: volume,
        stopLoss: sl,
        takeProfit: tp,
      );
      final price = double.tryParse('${data['openPrice'] ?? ''}');
      _result(
        true,
        '$side ${_lots(volume)} ${widget.symbol}'
        '${price != null ? ' at ${price.toStringAsFixed(_digits)}' : ''}'
        '${_ticketOf(data)} done',
      );
      if (sl != null || tp != null) {
        setState(() {
          _draft.sl = null;
          _draft.tp = null;
        });
      }
    } catch (e) {
      _result(false, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _placePending() async {
    final price = _draft.price;
    if (_busy || price == null) return;
    if (!await tradingService.ensureSession()) {
      _result(false, 'Not logged in. Please login to your account.');
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await tradingService.placePendingOrder(
        symbol: widget.symbol,
        side: _draft.side,
        orderType: _draft.type,
        price: price,
        volume: _draft.volume,
        stopLoss: _draft.sl,
        takeProfit: _draft.tp,
      );
      _result(
        true,
        '${_draft.type.replaceAll('_', ' ')} ${_lots(_draft.volume)} '
        '${widget.symbol} at ${price.toStringAsFixed(_digits)}'
        '${_ticketOf(data)} placed',
      );
      setState(() {
        _draft.sl = null;
        _draft.tp = null;
      });
    } catch (e) {
      _result(false, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _togglePanel() {
    setState(() {
      _panel = !_panel;
      if (_panel) {
        _crossMode = false;
        _cross = null;
      }
    });
    if (_panel && _draft.pending && _draft.price == null) {
      _selectOrderType(_draft.type);
    }
  }

  /* ---------------- radial menu ---------------- */

  /// Chart pe tap: crosshair mode me crosshair wahan, warna gol menu.
  void _onChartTap(TapUpDetails d) {
    if (_crossMode) {
      setState(() => _cross = d.localPosition);
      return;
    }
    if (_dragId != null) return;
    const r = RadialMenu.outer;
    final w = _chartSize.width;
    final h = _chartSize.height;
    setState(() {
      _radial = Offset(
        w < 2 * r ? w / 2 : d.localPosition.dx.clamp(r, w - r),
        h < 2 * r ? h / 2 : d.localPosition.dy.clamp(r, h - r),
      );
    });
  }

  List<RadialItem> _radialItems() => [
    for (final tf in ChartTimeframes.all)
      if (_favorites.contains(tf.code))
        RadialItem(
          label: tf.code,
          selected: tf.code == _tf.code,
          onTap: () => _selectTimeframe(tf.code),
        ),
    // MT5 order (clockwise, MN ke baad): indicators, crosshair, settings,
    // objects, windows - app ke apne icons, ring pe safed.
    RadialItem(
      asset: ChartToolIcon.indicators,
      onTap: () => _soon('Indicators'),
    ),
    RadialItem(
      asset: _crossMode ? ChartToolIcon.move : ChartToolIcon.crosshair,
      onTap: _toggleCross,
    ),
    RadialItem(asset: ChartToolIcon.sliders, onTap: _openTimeframes),
    RadialItem(asset: ChartToolIcon.objects, onTap: () => _soon('Objects')),
    RadialItem(asset: ChartToolIcon.windows, onTap: _openSymbolList),
  ];

  void _toggleCross() {
    setState(() {
      _crossMode = !_crossMode;
      _cross = _crossMode
          ? Offset(_layout.plotWidth / 2, _chartSize.height / 2)
          : null;
    });
  }

  /* ---------------- symbol picker ---------------- */

  void _soon(String what) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$what coming soon')));

  /// Gol menu ka "windows" icon: chart ke upar-left se symbol list.
  void _openSymbolList() {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    _showSymbolList(origin + const Offset(0, 60));
  }

  Future<void> _pickSymbol(BuildContext anchor) async {
    final box = anchor.findRenderObject() as RenderBox;
    await _showSymbolList(box.localToGlobal(Offset.zero));
  }

  Future<void> _showSymbolList(Offset pos) async {
    final symbols = [
      for (final w in tradingService.watchlist) w.code,
      if (!tradingService.watchlist.any((w) => w.code == widget.symbol))
        widget.symbol,
    ];
    final screen = MediaQuery.of(context).size;
    final padTop = MediaQuery.of(context).padding.top;
    // Neeche (order panel) se khola to list anchor ke UPAR khule.
    final upward = pos.dy > screen.height / 2;
    final maxH = upward ? pos.dy - padTop - 8 : screen.height - pos.dy - 16;
    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'chart-symbols',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          Positioned(
            left: 16,
            top: upward ? null : pos.dy,
            bottom: upward ? screen.height - pos.dy + 4 : null,
            child: Material(
              color: MtColors.isDark ? MtColors.white : const Color(0xFFF7F7F7),
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: math.min(560, maxH)),
                child: IntrinsicWidth(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in symbols)
                          InkWell(
                            onTap: () => Navigator.of(ctx).pop(s),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                14,
                                28,
                                14,
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: MtColors.text,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
    if (picked == null || picked == widget.symbol || !mounted) return;
    _shell?.openChart(picked);
  }

  /* ---------------- build ---------------- */

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          _toolbar(),
          // One-click patti khulte / band hote smooth slide (pop nahi).
          // Patti hamesha bani rehti hai; band pe upar slide hoke chhupti hai
          // (khulne aur band hone dono pe animation).
          if (tradingService.hasAnyAccount)
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                heightFactor: _oneClick ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_oneClick,
                  child: _oneClickBar(),
                ),
              ),
            ),
          Expanded(
            child: !tradingService.hasAnyAccount
                ? const NoAccountsBody()
                : _chartArea(),
          ),
          if (_panel && tradingService.hasAnyAccount) _orderPanel(),
        ],
      ),
    );
  }

  Widget _oneClickBar() {
    final px = _prices;
    return OneClickBar(
      digits: _digits,
      bid: px?.bid,
      ask: px?.ask,
      bidUp: _bidUp,
      askUp: _askUp,
      volume: _oneClickVolume,
      busy: _busy,
      onVolume: (v) => setState(() => _oneClickVolume = v),
      onTrade: (side) => _marketOrder(side, _oneClickVolume),
    );
  }

  Widget _orderPanel() {
    return OrderPanel(
      symbol: widget.symbol,
      draft: _draft,
      digits: _digits,
      busy: _busy,
      onType: _selectOrderType,
      onVolume: (v) => setState(() => _draft.volume = v),
      onToggleSl: () => _toggleLevel(sl: true),
      onToggleTp: () => _toggleLevel(sl: false),
      onPlacePending: _placePending,
      onMarket: (side) =>
          _marketOrder(side, _draft.volume, sl: _draft.sl, tp: _draft.tp),
      onSymbol: _pickSymbol,
      onClose: () => setState(() => _panel = false),
    );
  }

  Widget _toolbar() {
    return SizedBox(
      height: 56,
      child: _tfRow
          ? Row(
              children: [
                // Favourites (3..9) poori row me barabar baante - kam hon
                // to ek kinare nahi chipakte.
                const SizedBox(width: 4),
                for (final tf in ChartTimeframes.all)
                  if (_favorites.contains(tf.code))
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTimeframe(tf.code),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tf.code,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: tf.code == _tf.code
                                    ? _blue
                                    : MtColors.icon,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                IconButton(
                  onPressed: _openTimeframes,
                  icon: const ChartToolIcon(ChartToolIcon.gear, tint: true),
                ),
              ],
            )
          : Row(
              children: [
                IconButton(
                  onPressed: widget.onMenu,
                  icon: Icon(Icons.menu, size: 23, color: MtColors.text),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Crosshair',
                  onPressed: _toggleCross,
                  icon: ChartToolIcon(
                    _crossMode ? ChartToolIcon.move : ChartToolIcon.crosshair,
                    tint: true,
                  ),
                ),
                IconButton(
                  tooltip: 'Indicators',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Indicators coming soon')),
                  ),
                  icon: const ChartToolIcon(
                    ChartToolIcon.indicators,
                    tint: true,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _tfRow = true),
                  onLongPress: _openTimeframes,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        _tf.code,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: MtColors.isDark
                              ? MtColors.icon
                              : const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Trade',
                  onPressed: _togglePanel,
                  icon: ChartToolIcon(ChartToolIcon.trade, active: _panel),
                ),
                IconButton(
                  tooltip: 'One-click trading',
                  onPressed: () => setState(() => _oneClick = !_oneClick),
                  icon: ChartToolIcon(
                    ChartToolIcon.oneClick,
                    active: _oneClick,
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
    );
  }

  Widget _chartArea() {
    final q = tradingService.quotes[widget.symbol.toUpperCase()];
    final digits = _ctrl.digits ?? q?.digits ?? 5;
    final candles = _ctrl.candles;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              _chartSize = box.biggest;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                // Double tap nahi - warna har tap pe ~300ms ruk ke menu khulta.
                onTapUp: _onChartTap,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: box.biggest,
                    painter: ChartPainter(
                      levels: _levels(),
                      vZoom: _vZoom,
                      candles: candles,
                      timeframe: _tf,
                      digits: digits,
                      spacing: _spacing,
                      scroll: _scroll,
                      bid: q != null && q.hasPrice ? q.bid : null,
                      ask: q != null && q.hasPrice ? q.ask : null,
                      secondsLeft: _ctrl.secondsLeft,
                      crosshair: _crossMode ? _cross : null,
                      revision: _revision,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(left: 6, top: 4, child: _info(candles, digits)),
        // MT5 jaisa: upar beech me "Processing chart data..." jab tak load.
        if (_ctrl.loading)
          Positioned(
            top: 6,
            left: 0,
            right: ChartLayout.axisWidth,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MtColors.icon,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Processing chart data...',
                    style: TextStyle(fontSize: 13, color: MtColors.text),
                  ),
                ],
              ),
            ),
          ),
        if (_ctrl.loadingMore)
          const Positioned(
            left: 8,
            top: 70,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_ctrl.error != null && candles.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _ctrl.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MtColors.icon, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: _ctrl.reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        if (_radial != null)
          Positioned.fill(
            child: RadialMenu(
              center: _radial!,
              items: _radialItems(),
              onClose: () => setState(() => _radial = null),
            ),
          ),
      ],
    );
  }

  /// Upar left: "USDJPY ▾ M5", naam, aur OHLC (crosshair wala ya last).
  Widget _info(List<Candle> candles, int digits) {
    Candle? k;
    if (candles.isNotEmpty) {
      if (_crossMode && _cross != null) {
        k = candles[_layout.indexAt(_cross!.dx).clamp(0, candles.length - 1)];
      } else {
        k = candles.last;
      }
    }
    String f(double v) => v.toStringAsFixed(digits);
    final name = _ctrl.name.isNotEmpty
        ? _ctrl.name
        : tradingService.watchlist
                  .where((w) => w.code == widget.symbol)
                  .firstOrNull
                  ?.name ??
              '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (anchor) => GestureDetector(
            onTap: () => _pickSymbol(anchor),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.symbol,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    letterSpacing: -0.4,
                    fontWeight: FontWeight.w600,
                    color: _blue,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 14, color: _blue),
                Text(
                  _tf.code,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    letterSpacing: -0.4,
                    color: MtColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (name.isNotEmpty)
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              height: 1.1,
              letterSpacing: -0.4,
              color: MtColors.text,
            ),
          ),
        if (k != null)
          Text(
            '${f(k.o)} ${f(k.h)} ${f(k.l)} ${f(k.c)}',
            style: TextStyle(
              fontSize: 12,
              height: 1.1,
              letterSpacing: -0.4,
              color: MtColors.text,
            ),
          ),
      ],
    );
  }
}
