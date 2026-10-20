import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/dot_leader_row.dart';
import '../../core/widgets/mt_header.dart';
import '../shell/no_accounts_view.dart';

enum _Tab { positions, orders, deals }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Tab _tab = _Tab.positions;
  bool _loading = true;
  String? _error;
  DateTime? _from;
  DateTime? _to;

  List<dynamic> _positions = const [];
  List<dynamic> _orders = const [];
  List<dynamic> _deals = const [];
  Map<String, dynamic> _ordersSummary = const {};
  Map<String, dynamic> _dealsSummary = const {};
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        tradingService.history('positions', from: _from, to: _to),
        tradingService.history('orders', from: _from, to: _to),
        tradingService.history('deals', from: _from, to: _to),
        tradingService.summary(),
      ]);
      if (!mounted) return;
      setState(() {
        _positions = (results[0]['positions'] as List?) ?? const [];
        _orders = (results[1]['orders'] as List?) ?? const [];
        _ordersSummary =
            (results[1]['summary'] as Map<String, dynamic>?) ?? const {};
        _deals = (results[2]['deals'] as List?) ?? const [];
        _dealsSummary =
            (results[2]['summary'] as Map<String, dynamic>?) ?? const {};
        _summary = results[3];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  Future<void> _pickPeriod() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MtColors.white,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, value) in const [
              ('All history', 'all'),
              ('Today', 'today'),
              ('Last week', 'week'),
              ('Last month', 'month'),
              ('Last 3 months', '3months'),
              ('Custom range...', 'custom'),
            ])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(ctx, value),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (choice) {
      case 'all':
        _from = null;
        _to = null;
      case 'today':
        _from = today;
        _to = null;
      case 'week':
        _from = today.subtract(const Duration(days: 7));
        _to = null;
      case 'month':
        _from = DateTime(now.year, now.month - 1, now.day);
        _to = null;
      case '3months':
        _from = DateTime(now.year, now.month - 3, now.day);
        _to = null;
      case 'custom':
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2015),
          lastDate: DateTime(2030),
        );
        if (picked == null) return;
        _from = picked.start;
        _to = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(
            title: 'History',
            subtitle: 'All symbols',
            onMenu: widget.onMenu,
            actions: [
              MtIconButton(
                tooltip: 'Period',
                onPressed: _pickPeriod,
                icon: Icon(
                  Icons.calendar_month_outlined,
                  size: 26,
                  color: MtColors.text,
                ),
              ),
              MtIconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: Icon(Icons.refresh, size: 26, color: MtColors.text),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0.4,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? MtColors.text : MtColors.icon,
                  ),
                ),
              ),
              Container(
                height: 2,
                color: selected ? MtColors.accent : Colors.transparent,
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: MtColors.line)),
      ),
      child: Row(
        children: [
          tab(_Tab.positions, 'POSITIONS'),
          tab(_Tab.orders, 'ORDERS'),
          tab(_Tab.deals, 'DEALS'),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
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
    return switch (_tab) {
      _Tab.positions => _positionsTab(),
      _Tab.orders => _ordersTab(),
      _Tab.deals => _dealsTab(),
    };
  }

  Widget _summaryBlock(List<(String, String, Color?)> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          for (final r in rows)
            DotLeaderRow(
              label: r.$1,
              value: r.$2,
              valueColor: r.$3,
              fontSize: 15.5,
              verticalPadding: 3,
            ),
        ],
      ),
    );
  }

  Color _pnlColor(double v) => v >= 0 ? MtColors.bid : MtColors.ask;

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

  Widget _positionsTab() {
    final profit = _positions
        .where((p) => p['isBalanceEntry'] != true)
        .fold<double>(0, (s, p) => s + _d(p['profitLoss']));
    return Column(
      children: [
        _summaryBlock([
          (
            'Profit',
            formatMoney(
              _d(_summary['totalPnL']) != 0 ? _d(_summary['totalPnL']) : profit,
            ),
            _pnlColor(profit),
          ),
          ('Deposit', formatMoney(_d(_summary['totalDeposit'])), null),
          ('Swap', formatMoney(_d(_summary['totalSwap'])), null),
          ('Commission', formatMoney(_d(_summary['totalCommission'])), null),
          ('Balance', formatMoney(_d(_summary['balance'])), null),
        ]),
        Divider(height: 1, color: MtColors.line),
        Expanded(
          child: _positions.isEmpty
              ? _empty()
              : ListView.builder(
                  itemCount: _positions.length,
                  itemBuilder: (context, i) =>
                      _positionTile(_positions[i] as Map<String, dynamic>),
                ),
        ),
      ],
    );
  }

  Widget _positionTile(Map<String, dynamic> p) {
    if (p['isBalanceEntry'] == true) {
      final amount = _d(p['profitLoss']);
      return _tileShell(
        title: 'Balance',
        date: p['openTime'],
        line2: p['comment']?.toString() ?? '',
        right: formatMoney(amount),
        rightColor: MtColors.bid,
      );
    }
    final symbol = '${p['symbol'] ?? ''}';
    final side = '${p['side'] ?? ''}';
    final qty = _d(p['qty']);
    final profit = _d(p['profitLoss']);
    final digits = digitsFor(symbol, _d(p['openPrice']));
    String fmt(Object? v) => _d(v).toStringAsFixed(digits);
    return _tileShell(
      titleWidget: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$symbol, ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MtColors.text,
              ),
            ),
            TextSpan(
              text: '${side.toLowerCase()} ${qty.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                color: side == 'BUY' ? MtColors.bid : MtColors.ask,
              ),
            ),
          ],
        ),
      ),
      date: p['closeTime'] ?? p['openTime'],
      line2: '${fmt(p['openPrice'])} → ${fmt(p['closePrice'])}',
      right: formatMoney(profit),
      rightColor: _pnlColor(profit),
    );
  }

  Widget _ordersTab() {
    return Column(
      children: [
        _summaryBlock([
          ('Filled', '${_ordersSummary['totalFilled'] ?? 0}', null),
          ('Canceled', '${_ordersSummary['totalCancelled'] ?? 0}', null),
          ('Total', '${_ordersSummary['totalOrders'] ?? _orders.length}', null),
        ]),
        Divider(height: 1, color: MtColors.line),
        Expanded(
          child: _orders.isEmpty
              ? _empty()
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, i) {
                    final o = _orders[i] as Map<String, dynamic>;
                    final side = '${o['side'] ?? ''}';
                    return _tileShell(
                      titleWidget: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${o['symbol'] ?? ''}, ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: MtColors.text,
                              ),
                            ),
                            TextSpan(
                              text: side.toLowerCase(),
                              style: TextStyle(
                                fontSize: 15,
                                color: side == 'BUY'
                                    ? MtColors.bid
                                    : MtColors.ask,
                              ),
                            ),
                          ],
                        ),
                      ),
                      date: o['openTime'],
                      line2:
                          '${_d(o['qty']).toStringAsFixed(2)} / ${_d(o['qty']).toStringAsFixed(2)} at market',
                      right: '${o['status'] ?? ''}'.toUpperCase(),
                      rightColor: MtColors.icon,
                      rightBold: false,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _dealsTab() {
    final profit = _d(_dealsSummary['totalTradingProfit']);
    return Column(
      children: [
        _summaryBlock([
          ('Profit', formatMoney(profit), _pnlColor(profit)),
          ('Deposit', formatMoney(_d(_summary['totalDeposit'])), null),
          ('Swap', formatMoney(_d(_dealsSummary['totalSwap'])), null),
          ('Commission', formatMoney(_d(_summary['totalCommission'])), null),
          ('Balance', formatMoney(_d(_summary['balance'])), null),
        ]),
        Divider(height: 1, color: MtColors.line),
        Expanded(
          child: _deals.isEmpty
              ? _empty()
              : ListView.builder(
                  itemCount: _deals.length,
                  itemBuilder: (context, i) {
                    final d = _deals[i] as Map<String, dynamic>;
                    if (d['type'] == 'BALANCE') {
                      return _tileShell(
                        title: 'Balance',
                        date: d['date'],
                        line2: d['comment']?.toString() ?? '',
                        right: formatMoney(_d(d['profit'])),
                        rightColor: MtColors.bid,
                      );
                    }
                    final type = '${d['type'] ?? ''}'; // BUY_IN etc
                    final isBuy = type.startsWith('BUY');
                    final dir = d['direction'] == 'out' ? 'out' : 'in';
                    final symbol = '${d['symbol'] ?? ''}';
                    final digits = digitsFor(symbol, _d(d['price']));
                    return _tileShell(
                      titleWidget: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$symbol, ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: MtColors.text,
                              ),
                            ),
                            TextSpan(
                              text: '${isBuy ? 'buy' : 'sell'}, $dir',
                              style: TextStyle(
                                fontSize: 15,
                                color: isBuy ? MtColors.bid : MtColors.ask,
                              ),
                            ),
                          ],
                        ),
                      ),
                      date: d['date'],
                      line2:
                          '${_d(d['volume']).toStringAsFixed(2)} at ${_d(d['price']).toStringAsFixed(digits)}',
                      right: dir == 'out' ? formatMoney(_d(d['profit'])) : '',
                      rightColor: _pnlColor(_d(d['profit'])),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _tileShell({
    String? title,
    Widget? titleWidget,
    required Object? date,
    required String line2,
    required String right,
    required Color rightColor,
    bool rightBold = true,
  }) {
    final dt = date is String ? DateTime.tryParse(date) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    titleWidget ??
                    Text(
                      title ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MtColors.text,
                      ),
                    ),
              ),
              Text(
                dt != null ? formatDealTime(dt) : '',
                style: TextStyle(fontSize: 13, color: MtColors.icon),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  line2,
                  style: TextStyle(fontSize: 14, color: MtColors.icon),
                ),
              ),
              if (right.isNotEmpty)
                Text(
                  right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: rightBold ? FontWeight.w700 : FontWeight.w400,
                    color: rightColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: MtColors.line),
        ],
      ),
    );
  }
}
