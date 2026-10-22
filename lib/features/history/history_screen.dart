import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/dot_leader_row.dart';
import '../../core/widgets/mt_header.dart';
import '../shell/no_accounts_view.dart';
import '../trade/new_order_page.dart';
import 'custom_period_dialog.dart';

enum _Tab { positions, orders, deals }

enum _Period { today, week, month, threeMonths, custom }

enum _SortField { symbol, ticket, type, volume, openTime, closeTime, profit }

const _historyTabIndex = 3;
const _gray = Color(0xFF757575);
const _blue = Color(0xFF168BE1);
const _sheetBg = Color(0xFFEEF2F8);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Tab _tab = _Tab.positions;
  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  _Period _period = _Period.today;
  DateTimeRange? _custom;
  String? _symbol;
  _SortField _sortField = _SortField.closeTime;
  bool _sortDesc = true;
  final _expanded = <String>{};

  List<Map<String, dynamic>> _positions = const [];
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _deals = const [];

  ShellController? _shell;
  int _lastShellTab = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = ShellScope.maybeOf(context);
    if (shell != _shell) {
      _shell?.removeListener(_onShellChanged);
      _shell = shell?..addListener(_onShellChanged);
      _lastShellTab = shell?.tab ?? -1;
    }
  }

  @override
  void dispose() {
    _shell?.removeListener(_onShellChanged);
    super.dispose();
  }

  /// History tab khulte hi taza data (naye band trades) lao.
  void _onShellChanged() {
    final tab = _shell?.tab ?? -1;
    if (tab == _historyTabIndex && _lastShellTab != _historyTabIndex) _load();
    _lastShellTab = tab;
  }

  /* ---------------- period ---------------- */

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTimeRange _rangeFor(_Period p) {
    final today = _day(DateTime.now());
    return switch (p) {
      _Period.today => DateTimeRange(start: today, end: today),
      _Period.week => DateTimeRange(
        start: today.subtract(const Duration(days: 7)),
        end: today,
      ),
      _Period.month => DateTimeRange(
        start: DateTime(today.year, today.month - 1, today.day),
        end: today,
      ),
      _Period.threeMonths => DateTimeRange(
        start: DateTime(today.year, today.month - 3, today.day),
        end: today,
      ),
      _Period.custom => _custom ?? DateTimeRange(start: today, end: today),
    };
  }

  static String _short(DateTime d) =>
      '${d.month}/${d.day}/${(d.year % 100).toString().padLeft(2, '0')}';

  String _rangeLabel(_Period p) {
    final r = _rangeFor(p);
    if (p == _Period.today) return _short(r.start);
    return '${_short(r.start)} - ${_short(r.end)}';
  }

  /* ---------------- data ---------------- */

  Future<void> _load() async {
    if (!await tradingService.ensureSession()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = _rangeFor(_period);
    final from = r.start;
    final to = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
    try {
      final results = await Future.wait([
        tradingService.history('positions', from: from, to: to),
        tradingService.history('orders', from: from, to: to),
        tradingService.history('deals', from: from, to: to),
      ]);
      if (!mounted) return;
      List<Map<String, dynamic>> list(Object? v) => [
        if (v is List)
          for (final e in v)
            if (e is Map<String, dynamic>) e,
      ];
      setState(() {
        _positions = list(results[0]['positions']);
        _orders = list(results[1]['orders']);
        _deals = list(results[2]['deals']);
        _loading = false;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  static double _d(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  static DateTime? _date(Object? v) =>
      v is DateTime ? v : DateTime.tryParse('${v ?? ''}');

  static String _time(Object? v) {
    final d = _date(v);
    return d == null ? '' : formatDealTime(d);
  }

  static bool _isBalance(Map<String, dynamic> m) =>
      m['isBalanceEntry'] == true || m['type'] == 'BALANCE';

  bool _symbolOk(Map<String, dynamic> m) {
    if (_symbol == null) return true;
    return m['symbol'] == _symbol;
  }

  List<String> get _allSymbols {
    final set = <String>{};
    for (final m in [..._positions, ..._orders, ..._deals]) {
      final s = '${m['symbol'] ?? ''}';
      if (s.isNotEmpty) set.add(s);
    }
    return set.toList()..sort();
  }

  /* ---------------- sorting ---------------- */

  Comparable<Object?>? _sortValue(Map<String, dynamic> m) {
    switch (_tab) {
      case _Tab.positions:
        return switch (_sortField) {
          _SortField.symbol => '${m['symbol'] ?? ''}',
          _SortField.ticket => _d(m['ticket']),
          _SortField.type => '${m['side'] ?? ''}',
          _SortField.volume => _d(m['qty']),
          _SortField.openTime => _date(m['openTime']),
          _SortField.closeTime => _date(m['closeTime'] ?? m['openTime']),
          _SortField.profit => _d(m['grossProfit'] ?? m['profitLoss']),
        };
      case _Tab.orders:
        return switch (_sortField) {
          _SortField.symbol => '${m['symbol'] ?? ''}',
          _SortField.ticket => _d(m['ticket']),
          _SortField.type => '${m['orderType']}${m['side']}',
          _SortField.volume => _d(m['qty']),
          _SortField.openTime => _date(m['openTime'] ?? m['time']),
          _ => _date(m['time']),
        };
      case _Tab.deals:
        return switch (_sortField) {
          _SortField.symbol => '${m['symbol'] ?? ''}',
          _SortField.ticket => _d(m['deal'] ?? m['order']),
          _SortField.type => '${m['type'] ?? ''}',
          _SortField.volume => _d(m['volume']),
          _SortField.profit => _d(m['profit']),
          _ => _date(m['date']),
        };
    }
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> src) {
    final list = src.where(_symbolOk).toList();
    list.sort((a, b) {
      final va = _sortValue(a);
      final vb = _sortValue(b);
      int cmp;
      if (va == null && vb == null) {
        cmp = 0;
      } else if (va == null) {
        cmp = -1;
      } else if (vb == null) {
        cmp = 1;
      } else {
        cmp = va.compareTo(vb);
      }
      return _sortDesc ? -cmp : cmp;
    });
    return list;
  }

  /* ---------------- menus ---------------- */

  /// Header icon ke upar se khulne wala MT5 style rounded panel.
  Future<T?> _showPanel<T>(
    BuildContext anchorContext,
    List<Widget> Function(BuildContext ctx) children, {
    double? width,
    double raise = 0,
    double radius = 18,
  }) {
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final button = anchorContext.findRenderObject() as RenderBox;
    final anchor = button.localToGlobal(
      Offset(button.size.width, 0),
      ancestor: overlay,
    );
    final minTop = MediaQuery.of(anchorContext).padding.top;
    final topRight = Offset(
      anchor.dx,
      (anchor.dy - raise).clamp(minTop, double.infinity),
    );
    return showGeneralDialog<T>(
      context: anchorContext,
      barrierDismissible: true,
      barrierLabel: 'history-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) {
        Widget panel = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children(ctx),
        );
        panel = width != null
            ? SizedBox(width: width, child: panel)
            : IntrinsicWidth(child: panel);
        return Stack(
          children: [
            Positioned(
              top: topRight.dy,
              right: overlay.size.width - topRight.dx,
              child: Material(
                color: MtColors.isDark
                    ? MtColors.white
                    : const Color(0xFFFAFAFA),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                  side: BorderSide(color: MtColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: overlay.size.height - topRight.dy - 24,
                  ),
                  child: SingleChildScrollView(child: panel),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  Widget _menuRow(BuildContext ctx, Object value, Widget child) {
    return InkWell(
      onTap: () => Navigator.of(ctx).pop(value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: child,
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> rows) => [
    for (var i = 0; i < rows.length; i++) ...[
      if (i > 0) Divider(height: 1, color: MtColors.line),
      rows[i],
    ],
  ];

  Future<void> _showSymbolMenu(BuildContext anchor) async {
    final symbols = _allSymbols;
    final picked = await _showPanel<String>(
      anchor,
      (ctx) => _withDividers([
        for (final s in ['', ...symbols])
          _menuRow(
            ctx,
            s,
            Text(
              s.isEmpty ? 'All symbols' : s,
              style: TextStyle(fontSize: 15, color: MtColors.text),
            ),
          ),
      ]),
    );
    if (picked == null || !mounted) return;
    setState(() => _symbol = picked.isEmpty ? null : picked);
  }

  static const _sortLabels = {
    _SortField.symbol: 'Symbol',
    _SortField.ticket: 'Ticket',
    _SortField.type: 'Type',
    _SortField.volume: 'Volume',
    _SortField.openTime: 'Open time',
    _SortField.closeTime: 'Close time',
    _SortField.profit: 'Profit',
  };

  static bool _defaultDesc(_SortField f) =>
      f != _SortField.symbol && f != _SortField.type;

  Future<void> _showSortMenu(BuildContext anchor) async {
    final picked = await _showPanel<_SortField>(
      anchor,
      (ctx) => _withDividers([
        for (final f in _SortField.values)
          _menuRow(
            ctx,
            f,
            Row(
              children: [
                Text(
                  _sortLabels[f]!,
                  style: TextStyle(fontSize: 15, color: MtColors.text),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                SizedBox(
                  width: 18,
                  child: _sortField == f
                      ? Transform.scale(
                          scaleX: 0.85,
                          scaleY: 1.35,
                          child: Icon(
                            _sortDesc
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 20,
                            color: _blue,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
      ]),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked == _sortField) {
        _sortDesc = !_sortDesc;
      } else {
        _sortField = picked;
        _sortDesc = _defaultDesc(picked);
      }
    });
  }

  Widget _periodIcon(_Period p) {
    final asset = switch (p) {
      _Period.today => 'assets/icons/period_today.png',
      _Period.week => 'assets/icons/period_week.png',
      _Period.month => 'assets/icons/period_month.png',
      _Period.threeMonths => 'assets/icons/period_3months.png',
      _Period.custom => 'assets/icons/period_custom.png',
    };
    final color = MtColors.isDark ? MtColors.iconDark : const Color(0xFF424242);
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Image.asset(asset, width: 20, height: 20, color: color),
      ),
    );
  }

  Future<void> _showPeriodMenu(BuildContext anchor) async {
    const labels = {
      _Period.today: 'Today',
      _Period.week: 'Last week',
      _Period.month: 'Last month',
      _Period.threeMonths: 'Last 3 months',
      _Period.custom: 'Custom period',
    };
    final picked = await _showPanel<_Period>(
      anchor,
      raise: 10,
      radius: 10,
      (ctx) => _withDividers([
        for (final p in _Period.values)
          InkWell(
            onTap: () => Navigator.of(ctx).pop(p),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              child: Row(
                children: [
                  _periodIcon(p),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labels[p]!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.1,
                            letterSpacing: -0.4,
                            fontWeight: FontWeight.w500,
                            color: MtColors.text,
                          ),
                        ),
                        Text(
                          _rangeLabel(p),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.1,
                            letterSpacing: -0.3,
                            color: _gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 24,
                    child: _period == p
                        ? const Icon(Icons.check, color: _blue, size: 24)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
    if (picked == null || !mounted) return;
    if (picked == _Period.custom) {
      final range = await showCustomPeriodDialog(context, initial: _custom);
      if (range == null || !mounted) return;
      _custom = DateTimeRange(start: _day(range.start), end: _day(range.end));
    }
    setState(() => _period = picked);
    _load();
  }

  /* ---------------- build ---------------- */

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(
            title: 'History',
            titleFontSize: 12,
            subtitle: _symbol ?? 'All symbols',
            subtitleFontSize: 15,
            subtitleLetterSpacing: -0.4,
            subtitleWeight: FontWeight.w500,
            subtitleColor: MtColors.isDark
                ? MtColors.textSecondary
                : const Color(0xFF6E6E6E),
            onMenu: widget.onMenu,
            actions: [
              Builder(
                builder: (c) => MtIconButton(
                  tooltip: 'Symbol',
                  onPressed: () => _showSymbolMenu(c),
                  icon: Icon(
                    Icons.currency_exchange,
                    size: 21,
                    color: MtColors.iconDark,
                  ),
                ),
              ),
              Builder(
                builder: (c) => MtIconButton(
                  tooltip: 'Sort',
                  onPressed: () => _showSortMenu(c),
                  icon: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      MtColors.iconDark,
                      BlendMode.srcIn,
                    ),
                    child: Transform.flip(
                      flipX: true,
                      child: Image.asset(
                        'assets/icons/quotes_arrows.png',
                        width: 21,
                        height: 21,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Builder(
                builder: (c) => MtIconButton(
                  tooltip: 'Period',
                  onPressed: () => _showPeriodMenu(c),
                  icon: Image.asset(
                    'assets/icons/period_today.png',
                    width: 21,
                    height: 21,
                    color: MtColors.iconDark,
                  ),
                ),
              ),
            ],
          ),
          if (tradingService.hasAnyAccount) _tabs(),
          Expanded(
            child: tradingService.hasAnyAccount
                ? _body()
                : const NoAccountsBody(),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(_Tab t, String label) {
      final selected = _tab == t;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tab = t),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w500,
                    color: selected ? MtColors.text : _gray,
                  ),
                ),
              ),
              Container(
                height: 2,
                color: selected ? _blue : Colors.transparent,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(_Tab.positions, 'POSITIONS'),
        tab(_Tab.orders, 'ORDERS'),
        tab(_Tab.deals, 'DEALS'),
      ],
    );
  }

  Widget _body() {
    if (_loading && !_loadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && !_loadedOnce) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: MtColors.ask, fontSize: 15),
          ),
        ),
      );
    }
    final (summary, rows, tile) = switch (_tab) {
      _Tab.positions => (
        _positionsSummary(),
        _sorted(_positions),
        _positionTile,
      ),
      _Tab.orders => (_ordersSummary(), _sorted(_orders), _orderTile),
      _Tab.deals => (_dealsSummary(), _sorted(_deals), _dealTile),
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.isEmpty ? 2 : rows.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return summary;
          if (rows.isEmpty) return _empty();
          return tile(rows[i - 1]);
        },
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 96, color: MtColors.empty),
          const SizedBox(height: 18),
          Text(
            'Empty history',
            style: TextStyle(color: MtColors.emptyText, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /* ---------------- summaries ---------------- */

  Widget _summaryBlock(List<(String, String, Color?)> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: MtColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          for (final r in rows)
            DotLeaderRow(
              label: r.$1,
              value: r.$2,
              valueColor: r.$3,
              fontSize: 14.5,
              verticalPadding: 3,
            ),
        ],
      ),
    );
  }

  Color _pnlColor(double v) => v >= 0 ? MtColors.bid : MtColors.ask;

  /// Profit / Deposit / (Withdrawal) / Swap / Commission / Balance -
  /// Balance = period ka net (MT5 jaisa), account balance nahi.
  Widget _moneySummary({
    required double profit,
    required double deposit,
    required double withdrawal,
    required double swap,
    required double commission,
  }) {
    final balance = profit + deposit - withdrawal + swap + commission;
    return _summaryBlock([
      (
        'Profit',
        formatMoney(profit),
        profit < 0
            ? MtColors.ask
            : profit > 0
            ? MtColors.bid
            : null,
      ),
      ('Deposit', formatMoney(deposit), null),
      if (withdrawal != 0) ('Withdrawal', formatMoney(-withdrawal), null),
      ('Swap', formatMoney(swap), null),
      ('Commission', formatMoney(commission), null),
      ('Balance', formatMoney(balance), null),
    ]);
  }

  Widget _positionsSummary() {
    var profit = 0.0, deposit = 0.0, withdrawal = 0.0;
    var swap = 0.0, commission = 0.0;
    for (final p in _positions.where(_symbolOk)) {
      if (_isBalance(p)) {
        final a = _d(p['profitLoss']);
        a >= 0 ? deposit += a : withdrawal += -a;
        continue;
      }
      profit += _d(p['grossProfit'] ?? p['profitLoss']);
      swap -= _d(p['swap']);
      commission -= _d(p['commission']);
    }
    return _moneySummary(
      profit: profit,
      deposit: deposit,
      withdrawal: withdrawal,
      swap: swap,
      commission: commission,
    );
  }

  Widget _dealsSummary() {
    var profit = 0.0, deposit = 0.0, withdrawal = 0.0;
    var swap = 0.0, commission = 0.0;
    for (final d in _deals.where(_symbolOk)) {
      if (_isBalance(d)) {
        final a = _d(d['profit']);
        a >= 0 ? deposit += a : withdrawal += -a;
        continue;
      }
      profit += _d(d['profit']);
      swap -= _d(d['swap']);
      commission -= _d(d['commission']);
    }
    return _moneySummary(
      profit: profit,
      deposit: deposit,
      withdrawal: withdrawal,
      swap: swap,
      commission: commission,
    );
  }

  Widget _ordersSummary() {
    final list = _orders.where(_symbolOk).toList();
    final filled = list.where((o) => o['status'] == 'FILLED').length;
    final canceled = list
        .where((o) => o['status'] == 'CANCELED' || o['status'] == 'EXPIRED')
        .length;
    return _summaryBlock([
      ('Filled', '$filled', null),
      ('Canceled', '$canceled', null),
      ('Total', '${list.length}', null),
    ]);
  }

  /* ---------------- shared row pieces ---------------- */

  Widget _title(String symbol, String rest, bool isBuy) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$symbol, ',
            style: TextStyle(
              fontSize: 16,
              height: 0.9,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w700,
              color: MtColors.text,
            ),
          ),
          TextSpan(
            text: rest,
            style: TextStyle(
              fontSize: 15,
              height: 0.9,
              letterSpacing: -0.3,
              color: isBuy ? MtColors.bid : MtColors.ask,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line2(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      height: 0.9,
      fontWeight: FontWeight.w800,
      color: _gray,
    ),
  );

  Widget _timeText(Object? v) => Text(
    _time(v),
    style: const TextStyle(
      fontSize: 12.5,
      height: 0.9,
      letterSpacing: -0.7,
      color: _gray,
    ),
  );

  /// Right side profit / amount - Trade card jaisa tight line.
  Widget _amount(double v) => Text(
    formatMoney(v),
    style: TextStyle(
      fontSize: 14,
      height: 0.9,
      fontWeight: FontWeight.w700,
      color: _pnlColor(v),
    ),
  );

  Widget _pair(String label, String value) {
    final style = TextStyle(
      fontSize: 12,
      letterSpacing: -0.3,
      color: MtColors.icon,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }

  /// Expanded detail: left aur right column (label left, value right).
  Widget _details(List<Widget> left, List<Widget> right) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: left,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketText(Object? ticket) => Text(
    ticket == null ? '' : '#$ticket',
    style: TextStyle(
      fontSize: 12,
      letterSpacing: -0.3,
      fontWeight: FontWeight.w500,
      color: MtColors.icon,
    ),
  );

  String _price(Object? v, String symbol) {
    final x = _d(v);
    return x == 0 ? '—' : x.toStringAsFixed(digitsFor(symbol, x));
  }

  /// Row shell: tap = expand, long press = Chart/Trade sheet.
  /// [bar] = left colored patti (TP green / SL red).
  Widget _rowShell({
    required String key,
    required Widget Function(bool expanded) content,
    String? symbol,
    Color? bar,
  }) {
    final expanded = _expanded.contains(key);
    return Material(
      color: MtColors.white,
      child: InkWell(
        onTap: () => setState(() {
          expanded ? _expanded.remove(key) : _expanded.add(key);
        }),
        onLongPress: symbol == null || symbol.isEmpty
            ? null
            : () => _showRowSheet(symbol, content, bar),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: bar ?? Colors.transparent, width: 4),
              bottom: BorderSide(color: MtColors.line),
            ),
          ),
          // Trade card jaisa: divider se agla title 10, line2 se divider 7.
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 7),
          // Detail khulne/band hone pe height smooth slide, pop nahi.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: content(expanded),
          ),
        ),
      ),
    );
  }

  void _showRowSheet(
    String symbol,
    Widget Function(bool expanded) content,
    Color? bar,
  ) {
    final shell = ShellScope.maybeOf(context);
    final textColor = MtColors.isDark ? MtColors.text : const Color(0xFF424242);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MtColors.isDark ? MtColors.white : _sheetBg,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        Widget item(String label, VoidCallback onTap) => InkWell(
          onTap: () {
            Navigator.of(sheetContext).pop();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: textColor),
            ),
          ),
        );
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: bar ?? Colors.transparent,
                      width: 4,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 14, 16, 6),
                child: content(true),
              ),
              item('Chart', () => shell?.openChart(symbol)),
              item(
                'Trade',
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NewOrderPage(symbol: symbol),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _balanceTile(String key, Object? time, String comment, double amount) {
    return _rowShell(
      key: key,
      content: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Balance',
                  style: TextStyle(
                    fontSize: 16,
                    height: 0.9,
                    letterSpacing: -0.3,
                    fontWeight: FontWeight.w700,
                    color: MtColors.text,
                  ),
                ),
              ),
              _timeText(time),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  comment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 0.9,
                    color: _gray,
                  ),
                ),
              ),
              _amount(amount),
            ],
          ),
        ],
      ),
    );
  }

  /* ---------------- positions ---------------- */

  Widget _positionTile(Map<String, dynamic> p) {
    if (_isBalance(p)) {
      return _balanceTile(
        'pb${p['openTime']}${p['profitLoss']}',
        p['openTime'],
        '${p['comment'] ?? ''}',
        _d(p['profitLoss']),
      );
    }
    final symbol = '${p['symbol'] ?? ''}';
    final isBuy = p['side'] == 'BUY';
    final profit = _d(p['grossProfit'] ?? p['profitLoss']);
    final bar = switch (p['closeReason']) {
      'TAKE_PROFIT' => const Color(0xFF2E9E3F),
      'STOP_LOSS' || 'STOP_OUT' => MtColors.ask,
      _ => null,
    };
    return _rowShell(
      key: 'p${p['positionId'] ?? p['ticket']}',
      symbol: symbol,
      bar: bar,
      content: (expanded) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _title(
                  symbol,
                  '${isBuy ? 'buy' : 'sell'} ${_d(p['qty']).toStringAsFixed(2)}',
                  isBuy,
                ),
              ),
              _timeText(p['closeTime']),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _line2(
                  '${_price(p['openPrice'], symbol)} → '
                  '${_price(p['closePrice'], symbol)}',
                ),
              ),
              _amount(profit),
            ],
          ),
          if (expanded)
            _details(
              [
                _ticketText(p['ticket']),
                _pair('S / L:', _price(p['stopLoss'], symbol)),
                _pair('T / P:', _price(p['takeProfit'], symbol)),
              ],
              [
                _pair('Open:', _time(p['openTime'])),
                _pair('Swap:', formatMoney(-_d(p['swap']))),
                _pair('Commission:', formatMoney(-_d(p['commission']))),
              ],
            ),
        ],
      ),
    );
  }

  /* ---------------- orders ---------------- */

  Widget _orderTile(Map<String, dynamic> o) {
    final symbol = '${o['symbol'] ?? ''}';
    final isBuy = o['side'] == 'BUY';
    final orderType = '${o['orderType'] ?? 'MARKET'}';
    final type = orderType == 'MARKET'
        ? (isBuy ? 'buy' : 'sell')
        : orderType.toLowerCase().replaceAll('_', ' ');
    final qty = _d(o['qty']).toStringAsFixed(2);
    final filled = _d(o['filledQty'] ?? o['qty']).toStringAsFixed(2);
    final at = o['atMarket'] == true || orderType == 'MARKET'
        ? 'at market'
        : 'at ${_price(o['price'], symbol)}';
    final comment = '${o['comment'] ?? ''}';
    return _rowShell(
      key: 'o${o['ticket']}${o['time']}',
      symbol: symbol,
      content: (expanded) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _title(symbol, type, isBuy)),
              _timeText(o['time']),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _line2('$qty / $filled $at')),
              Text(
                '${o['status'] ?? ''}',
                style: const TextStyle(
                  fontSize: 13,
                  height: 0.9,
                  fontWeight: FontWeight.w700,
                  color: _gray,
                ),
              ),
            ],
          ),
          if (expanded)
            _details([
              _ticketText(o['ticket']),
              _pair('S / L:', _price(o['stopLoss'], symbol)),
              _pair('T / P:', _price(o['takeProfit'], symbol)),
              if (comment.isNotEmpty) _comment(comment),
            ], const []),
        ],
      ),
    );
  }

  Widget _comment(String comment) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Text(
      'Comment:  $comment',
      style: TextStyle(fontSize: 12, letterSpacing: -0.3, color: MtColors.icon),
    ),
  );

  /* ---------------- deals ---------------- */

  Widget _dealTile(Map<String, dynamic> d) {
    if (_isBalance(d)) {
      return _balanceTile(
        'db${d['date']}${d['profit']}',
        d['date'],
        '${d['comment'] ?? ''}',
        _d(d['profit']),
      );
    }
    final symbol = '${d['symbol'] ?? ''}';
    final type = '${d['type'] ?? ''}';
    final isBuy = type.startsWith('BUY');
    final out = d['direction'] == 'out';
    final profit = _d(d['profit']);
    final comment = '${d['comment'] ?? ''}';
    String id(Object? v) => v == null ? '—' : '$v';
    return _rowShell(
      key: 'd${d['deal'] ?? d['order']}${d['direction']}',
      symbol: symbol,
      content: (expanded) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _title(
                  symbol,
                  '${isBuy ? 'buy' : 'sell'}, ${out ? 'out' : 'in'}',
                  isBuy,
                ),
              ),
              _timeText(d['date']),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _line2(
                  '${_d(d['volume']).toStringAsFixed(2)} at '
                  '${_price(d['price'], symbol)}',
                ),
              ),
              if (out) _amount(profit),
            ],
          ),
          if (expanded) ...[
            _details(
              [
                _pair('Deal:', id(d['deal'])),
                _pair('Order:', id(d['order'])),
                _pair('Position:', id(d['positionId'] ?? d['tradeId'])),
              ],
              [
                _pair('Swap:', formatMoney(-_d(d['swap']))),
                _pair('Charges:', formatMoney(-_d(d['commission']))),
              ],
            ),
            if (comment.isNotEmpty) _comment(comment),
          ],
        ],
      ),
    );
  }
}
