import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_header.dart';
import '../../core/widgets/quote_price.dart';
import '../shell/no_accounts_view.dart';
import '../shell/simple_page.dart';
import '../trade/new_order_page.dart';
import 'quote_data.dart';
import 'selected_symbols_page.dart';

String _fmt(double v, int digits) => v.toStringAsFixed(digits);

(String, String) _split(double v, int digits) {
  final s = _fmt(v, digits);
  if (s.length <= 1) return (s, '');
  return (s.substring(0, s.length - 1), s.substring(s.length - 1));
}

String _timeStr(DateTime? t) {
  if (t == null) return '--:--:--';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Build display quotes: live WS prices when available, static fallback.
List<Quote> liveDisplayQuotes() {
  final symbols = tradingService.watchlist.isNotEmpty
      ? tradingService.watchlist.map((w) => w.code).toList()
      : quotes.map((q) => q.symbol).toList();
  return [for (final sym in symbols) _displayQuote(sym)];
}

Quote _displayQuote(String symbol) {
  final fallback = quoteBySymbol(symbol);
  final live = tradingService.quotes[symbol];
  if (live == null || !live.hasPrice) {
    return fallback ??
        Quote(
          symbol: symbol,
          change: '0 0.00%',
          changeUp: true,
          time: '--:--:--',
          spread: '0',
          bidHead: '0.00',
          bidTail: '0',
          askHead: '0.00',
          askTail: '0',
          low: '0',
          high: '0',
          priceUp: true,
          digits: 5,
        );
  }
  final d = live.digits;
  final (bidHead, bidTail) = _split(live.bid, d);
  final (askHead, askTail) = _split(live.ask, d);
  final pct = live.changePct;
  final points = live.changePoints;
  return Quote(
    symbol: symbol,
    change:
        '${points > 0 ? '+' : ''}$points ${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
    changeUp: live.changeUp,
    time: _timeStr(live.time),
    spread: '${live.spreadPoints}',
    bidHead: bidHead,
    bidTail: bidTail,
    askHead: askHead,
    askTail: askTail,
    low: _fmt(live.dayLow > 0 ? live.dayLow : live.bid, d),
    high: _fmt(live.dayHigh > 0 ? live.dayHigh : live.bid, d),
    priceUp: live.priceUp,
    digits: d,
  );
}

class QuotesScreen extends StatefulWidget {
  QuotesScreen({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  bool _simpleView = false;

  @override
  void initState() {
    super.initState();
    for (final q in quotes) {
      tradingService.subscribe(q.symbol);
    }
    tradingService.refreshWatchlist();
  }

  @override
  Widget build(BuildContext context) {
    // Header static rehta hai - live ticks par sirf list rebuild
    // hoti hai, warna har tick par poori screen rebuild hone se
    // scroll atakata tha.
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(
            title: 'Quotes',
            titleFontSize: 14,
            titleFontFamily: 'Roboto Condensed',
            // titleLetterSpacing:-0.3,
            titleHeightScale: 1.2,
            onMenu: widget.onMenu,
            actions: [
              MtIconButton(
                tooltip: 'Add',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AddSymbolsPage(),
                  ),
                ),
                icon: CustomPaint(
                  size: Size(28, 28),
                  painter: _ThinAddIconPainter(MtColors.iconDark),
                ),
              ),
              MtIconButton(
                tooltip: 'Edit',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SelectedSymbolsPage(),
                  ),
                ),
                icon: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    MtColors.iconDark,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/icons/header_edit.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: _QuotesLiveArea(
              simpleView: _simpleView,
              onToggleSimple: (v) => setState(() => _simpleView = v),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quotes list area: live ticks par refresh hoti hai, LEKIN scroll
/// ke dauraan rebuild bilkul nahi hoti - finger/fling chalte waqt
/// ek bhi frame nahi rukta, isiliye scroll hamesha smooth rehta
/// hai. Scroll rukte hi fresh prices ek baar me aa jate hain.
class _QuotesLiveArea extends StatefulWidget {
  const _QuotesLiveArea({
    required this.simpleView,
    required this.onToggleSimple,
  });

  final bool simpleView;
  final ValueChanged<bool> onToggleSimple;

  @override
  State<_QuotesLiveArea> createState() => _QuotesLiveAreaState();
}

class _QuotesLiveAreaState extends State<_QuotesLiveArea> {
  bool _scrolling = false;
  bool _dirtyWhileScrolling = false;

  @override
  void initState() {
    super.initState();
    tradingService.addListener(_onService);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onService);
    super.dispose();
  }

  void _onService() {
    if (!mounted) return;
    if (_scrolling) {
      // Scroll ke beech me rebuild = jank. Bas yaad rakho ke
      // naya data aaya hai; rukte hi refresh kar denge.
      _dirtyWhileScrolling = true;
      return;
    }
    setState(() {});
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _scrolling = true;
    } else if (n is ScrollEndNotification) {
      _scrolling = false;
      if (_dirtyWhileScrolling) {
        _dirtyWhileScrolling = false;
        setState(() {});
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!tradingService.hasAnyAccount) return const NoAccountsBody();
    final display = liveDisplayQuotes();
    final Widget list = widget.simpleView
        ? _SimpleQuotesView(
            displayQuotes: display,
            onToggleViewMode: () => widget.onToggleSimple(false),
          )
        : ListView.builder(
            // Neeche ek card jitni khaali jagah - last wala
            // (EURUSD) bottom nav ke upar pura dikhta hai.
            padding: const EdgeInsets.only(top: 2, bottom: 88),
            // Aage ke tiles pehle se bane rahen - scroll smooth.
            cacheExtent: 500,
            itemCount: display.length,
            itemBuilder: (context, index) {
              final quote = display[index];
              return _QuoteTile(
                key: ValueKey(quote.symbol),
                quote: quote,
                simpleView: false,
                onToggleViewMode: () => widget.onToggleSimple(true),
              );
            },
          );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: list,
    );
  }
}

String _symbolDescription(String symbol) {
  const descriptions = <String, String>{
    'EURUSD': 'Euro vs US Dollar',
    'GBPUSD': 'British Pound vs US Dollar',
    'USDCHF': 'US Dollar vs Swiss Franc',
    'USDJPY': 'US Dollar vs Japanese Yen',
    'USDCNH': 'US Dollar vs Chinese Yuan',
    'USDRUB': 'US Dollar vs Russian Ruble',
    'AUDUSD': 'Australian Dollar vs US Dollar',
    'NZDUSD': 'New Zealand Dollar vs US Dollar',
    'USDCAD': 'US Dollar vs Canadian Dollar',
    'USDSEK': 'US Dollar vs Swedish Krona',
  };
  return descriptions[symbol] ?? symbol;
}

void _showQuoteMenu(
  BuildContext context,
  Quote quote, {
  required bool simpleView,
  required VoidCallback onToggleViewMode,
}) {
  final shell = ShellScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: MtColors.white,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    shape: RoundedRectangleBorder(),
    builder: (sheetContext) {
      void close() => Navigator.of(sheetContext).pop();
      final items = <(String, VoidCallback)>[
        ('${quote.symbol}: ${_symbolDescription(quote.symbol)}', close),
        (
          'New Order',
          () {
            close();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NewOrderPage(
                  symbol: quote.symbol,
                  onOrderPlaced: () => shell.openTab(2),
                ),
              ),
            );
          },
        ),
        (
          'Chart',
          () {
            close();
            shell.openChart(quote.symbol);
          },
        ),
        (
          'Properties',
          () {
            close();
            _openSymbolInfo(context, quote, statistics: false);
          },
        ),
        (
          'Depth Of Market',
          () {
            close();
            _openDepth(context, quote);
          },
        ),
        (
          'Market Statistics',
          () {
            close();
            _openSymbolInfo(context, quote, statistics: true);
          },
        ),
        (
          simpleView ? 'Advanced view mode' : 'Simple view mode',
          () {
            close();
            onToggleViewMode();
          },
        ),
      ];
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              InkWell(
                onTap: items[i].$2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Text(
                    items[i].$1,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: i == 0 ? MtColors.icon : MtColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 15, color: MtColors.icon),
          ),
        ),
        Text(value, style: TextStyle(fontSize: 15, color: MtColors.text)),
      ],
    ),
  );
}

void _openSymbolInfo(
  BuildContext context,
  Quote quote, {
  required bool statistics,
}) {
  final live = tradingService.quotes[quote.symbol];
  final d = live?.digits ?? quote.digits;
  String fmt(double v) => v > 0 ? v.toStringAsFixed(d) : '--';
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SimplePage(
        title: statistics ? 'Market Statistics' : 'Properties',
        child: ListView(
          children: [
            _infoRow('Symbol', quote.symbol),
            _infoRow('Description', _symbolDescription(quote.symbol)),
            if (!statistics) ...[
              _infoRow('Digits', '$d'),
              _infoRow(
                'Spread',
                live != null ? '${live.spreadPoints} points' : quote.spread,
              ),
              _infoRow('Bid', fmt(live?.bid ?? 0)),
              _infoRow('Ask', fmt(live?.ask ?? 0)),
            ] else ...[
              _infoRow('Day Open', fmt(live?.dayOpen ?? 0)),
              _infoRow('Day High', fmt(live?.dayHigh ?? 0)),
              _infoRow('Day Low', fmt(live?.dayLow ?? 0)),
              _infoRow('Day Close', fmt(live?.dayClose ?? 0)),
              _infoRow(
                'Change',
                live != null
                    ? '${live.changePoints} (${live.changePct.toStringAsFixed(2)}%)'
                    : quote.change,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

void _openDepth(BuildContext context, Quote quote) {
  final live = tradingService.quotes[quote.symbol];
  final d = live?.digits ?? quote.digits;
  var step = 1.0;
  for (var i = 0; i < d; i++) {
    step /= 10;
  }
  final bid =
      live?.bid ?? double.tryParse('${quote.bidHead}${quote.bidTail}') ?? 0;
  final ask =
      live?.ask ?? double.tryParse('${quote.askHead}${quote.askTail}') ?? bid;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SimplePage(
        title: 'Depth Of Market',
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (var i = 5; i >= 1; i--)
              _depthRow(ask + step * i, d, MtColors.ask),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Spread: ${live?.spreadPoints ?? quote.spread}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: MtColors.icon),
              ),
            ),
            for (var i = 1; i <= 5; i++)
              _depthRow(bid - step * (i - 1), d, MtColors.bid),
          ],
        ),
      ),
    ),
  );
}

Widget _depthRow(double price, int digits, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Container(height: 22, color: color.withValues(alpha: 0.12)),
        ),
        const SizedBox(width: 12),
        Text(
          price.toStringAsFixed(digits),
          style: TextStyle(fontSize: 16, color: color),
        ),
      ],
    ),
  );
}

class _SimpleQuotesView extends StatelessWidget {
  _SimpleQuotesView({
    required this.displayQuotes,
    required this.onToggleViewMode,
  });

  final List<Quote> displayQuotes;
  final VoidCallback onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontFamily: 'Roboto',
      color: MtColors.text,
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 12, 6),
          child: Row(
            children: [
              Expanded(child: Text('Symbol', style: headerStyle)),
              SizedBox(
                width: 100,
                child: Text(
                  'Bid',
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  'Ask',
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 88),
            itemCount: displayQuotes.length,
            itemBuilder: (context, index) {
              return _SimpleQuoteTile(
                quote: displayQuotes[index],
                onToggleViewMode: onToggleViewMode,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SimpleQuoteTile extends StatelessWidget {
  _SimpleQuoteTile({required this.quote, required this.onToggleViewMode});

  final Quote quote;
  final VoidCallback onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    final color = quote.priceUp ? MtColors.bid : MtColors.ask;
    return Material(
      color: MtColors.white,
      child: InkWell(
        onTap: () => _showQuoteMenu(
          context,
          quote,
          simpleView: true,
          onToggleViewMode: onToggleViewMode,
        ),
        onLongPress: () => _showQuoteMenu(
          context,
          quote,
          simpleView: true,
          onToggleViewMode: onToggleViewMode,
        ),
        splashFactory: InkRipple.splashFactory,
        splashColor: MtColors.text.withValues(alpha: 0.22),
        highlightColor: MtColors.text.withValues(alpha: 0.10),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 11, 12, 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  quote.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MtColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SimplePrice(
                    price: '${quote.bidHead}${quote.bidTail}',
                    color: color,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SimplePrice(
                    price: '${quote.askHead}${quote.askTail}',
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimplePrice extends StatelessWidget {
  _SimplePrice({required this.price, required this.color});

  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final main = price.length > 1
        ? price.substring(0, price.length - 1)
        : price;
    final last = price.length > 1 ? price.substring(price.length - 1) : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          main,
          style: TextStyle(
            fontFamily: 'Roboto Condensed',
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        if (last.isNotEmpty)
          Text(
            last,
            style: TextStyle(
              fontFamily: 'Roboto Condensed',
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
      ],
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({
    super.key,
    required this.quote,
    required this.simpleView,
    required this.onToggleViewMode,
  });

  final Quote quote;
  final bool simpleView;
  final VoidCallback onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    final changeColor = quote.changeUp ? MtColors.bid : MtColors.ask;
    return Material(
      color: MtColors.white,
      child: InkWell(
        onTap: () => _showQuoteMenu(
          context,
          quote,
          simpleView: simpleView,
          onToggleViewMode: onToggleViewMode,
        ),
        onLongPress: () => _showQuoteMenu(
          context,
          quote,
          simpleView: simpleView,
          onToggleViewMode: onToggleViewMode,
        ),
        splashFactory: InkRipple.splashFactory,
        splashColor: MtColors.text.withValues(alpha: 0.22),
        highlightColor: MtColors.text.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: quote.change.split(' ').first,
                            style: TextStyle(color: MtColors.icon),
                          ),
                          TextSpan(
                            text:
                                ' ${quote.change.split(' ').skip(1).join(' ')}',
                            style: TextStyle(color: changeColor),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.1,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      quote.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MtColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 5),
                    SizedBox(
                      height: 17,
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              quote.time,
                              style: TextStyle(
                                color: MtColors.iconDark,
                                fontSize: 14,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(width: 5),
                            ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                MtColors.iconDark,
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(
                                'assets/icons/quote_mark.png',
                                width: 12,
                                height: 11,
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              quote.spread,
                              style: TextStyle(
                                color: MtColors.iconDark,
                                fontSize: 14,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PriceColumn(
                          price: QuotePrice(
                            head: quote.bidHead,
                            tail: quote.bidTail,
                            color: MtColors.bid,
                          ),
                          label: 'L: ${quote.low}',
                        ),
                        const SizedBox(width: 16),
                        _PriceColumn(
                          price: QuotePrice(
                            head: quote.askHead,
                            tail: quote.askTail,
                            color: MtColors.ask,
                          ),
                          label: 'H: ${quote.high}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThinAddIconPainter extends CustomPainter {
  const _ThinAddIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    const arm = 9.0;
    canvas.drawLine(center.translate(-arm, 0), center.translate(arm, 0), paint);
    canvas.drawLine(center.translate(0, -arm), center.translate(0, arm), paint);
  }

  @override
  bool shouldRepaint(covariant _ThinAddIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PriceColumn extends StatelessWidget {
  _PriceColumn({required this.price, required this.label});

  final Widget price;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        price,
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: MtColors.iconDark, fontSize: 14, height: 1.1),
        ),
      ],
    );
  }
}
