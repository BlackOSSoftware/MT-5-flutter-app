import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/dot_leader_row.dart';
import '../../core/widgets/mt_header.dart';
import '../account/account_data.dart';
import '../shell/no_accounts_view.dart';
import 'new_order_page.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  final _expanded = <String>{};
  int _sortMode = 0; // 0 time, 1 symbol, 2 profit

  @override
  void initState() {
    super.initState();
    tradingService.refreshAccount();
  }

  List<LivePosition> get _positions {
    final list = tradingService.positions.values.toList();
    switch (_sortMode) {
      case 1:
        list.sort((a, b) => a.symbol.compareTo(b.symbol));
      case 2:
        list.sort((a, b) => b.floatingPnL.compareTo(a.floatingPnL));
      default:
        list.sort(
          (a, b) =>
              (b.openTime ?? DateTime(0)).compareTo(a.openTime ?? DateTime(0)),
        );
    }
    return list;
  }

  void _openNewOrder(BuildContext context, [String? symbol]) {
    final sym =
        symbol ??
        (tradingService.watchlist.isNotEmpty
            ? tradingService.watchlist.first.code
            : 'EURUSD');
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => NewOrderPage(symbol: sym)));
  }

  Future<void> _close(LivePosition p) async {
    try {
      await tradingService.closePosition(p.positionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Position ${p.positionId} closed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _modify(LivePosition p) async {
    final sl = TextEditingController(
      text: p.stopLoss != null && p.stopLoss! > 0 ? '${p.stopLoss}' : '',
    );
    final tp = TextEditingController(
      text: p.takeProfit != null && p.takeProfit! > 0 ? '${p.takeProfit}' : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modify position #${p.positionId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Stop Loss'),
            ),
            TextField(
              controller: tp,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Take Profit'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Modify'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await tradingService.modifyPosition(
        positionId: p.positionId,
        stopLoss: double.tryParse(sl.text.trim()),
        takeProfit: double.tryParse(tp.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Position modified')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _showPositionMenu(LivePosition p) {
    final shell = ShellScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MtColors.white,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) {
        void close() => Navigator.of(sheetContext).pop();
        Widget item(String label, VoidCallback onTap) {
          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: MtColors.text,
                  fontSize: 15,
                  height: 1.2,
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              item('Close position', () {
                close();
                _close(p);
              }),
              item('Close by', () {
                close();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Close by is not available yet'),
                  ),
                );
              }),
              item('Modify position', () {
                close();
                _modify(p);
              }),
              item('New order', () {
                close();
                _openNewOrder(context, p.symbol);
              }),
              item('Chart', () {
                close();
                shell.openChart(p.symbol);
              }),
              item('Bulk Operations...', () {
                close();
                _bulkMenu();
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _bulkMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MtColors.white,
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final all = tradingService.positions.values.toList();
                  for (final p in all) {
                    await tradingService.closePosition(p.positionId);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Text(
                    'Close all positions',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final losing = tradingService.positions.values
                      .where((p) => p.floatingPnL < 0)
                      .toList();
                  for (final p in losing) {
                    await tradingService.closePosition(p.positionId);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Text(
                    'Close losing positions',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tradingService,
      builder: (context, _) {
        final acc = tradingService.account;
        final loaded = tradingService.accountLoaded;
        final totalPnl = _positions.fold<double>(
          0,
          (sum, p) => sum + p.floatingPnL,
        );
        final pendings = tradingService.pendings.values.toList();
        return ColoredBox(
          color: MtColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MtHeader(
                title: 'Trade',
                subtitle: _positions.isEmpty
                    ? null
                    : '${totalPnl >= 0 ? '' : '-'}${formatMoney(totalPnl.abs())} USD',
                subtitleColor: totalPnl >= 0 ? MtColors.bid : MtColors.ask,
                onMenu: widget.onMenu,
                actions: [
                  MtIconButton(
                    tooltip: 'Sort',
                    onPressed: () =>
                        setState(() => _sortMode = (_sortMode + 1) % 3),
                    icon: Icon(Icons.swap_vert, size: 26, color: MtColors.text),
                  ),
                  MtIconButton(
                    tooltip: 'New order',
                    onPressed: () => _openNewOrder(context),
                    icon: Icon(
                      Icons.note_add_outlined,
                      size: 26,
                      color: MtColors.text,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: !tradingService.hasAnyAccount
                    ? const NoAccountsBody()
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DotLeaderRow(
                                  label: 'Balance',
                                  value: formatMoney(
                                    loaded ? acc.balance : demoAccount.balance,
                                  ),
                                  fontSize: 16,
                                  verticalPadding: 4,
                                ),
                                DotLeaderRow(
                                  label: 'Equity',
                                  value: formatMoney(
                                    loaded ? acc.equity : demoAccount.equity,
                                  ),
                                  fontSize: 16,
                                  verticalPadding: 4,
                                ),
                                DotLeaderRow(
                                  label: 'Margin',
                                  value: formatMoney(acc.usedMargin),
                                  fontSize: 16,
                                  verticalPadding: 4,
                                ),
                                DotLeaderRow(
                                  label: 'Free margin',
                                  value: formatMoney(
                                    loaded
                                        ? acc.freeMargin
                                        : demoAccount.freeMargin,
                                  ),
                                  fontSize: 16,
                                  verticalPadding: 4,
                                ),
                                DotLeaderRow(
                                  label: 'Margin Level (%)',
                                  value: acc.usedMargin > 0
                                      ? formatMoney(acc.marginLevel)
                                      : '0.00',
                                  fontSize: 16,
                                  verticalPadding: 4,
                                ),
                              ],
                            ),
                          ),
                          _sectionHeader('Positions'),
                          if (_positions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No positions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: MtColors.emptyText,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          for (final p in _positions) _positionTile(p),
                          if (pendings.isNotEmpty) ...[
                            _sectionHeader('Orders'),
                            for (final o in pendings) _pendingTile(o),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      color: MtColors.line.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MtColors.icon,
              ),
            ),
          ),
          Icon(Icons.more_horiz, color: MtColors.icon, size: 20),
        ],
      ),
    );
  }

  Widget _positionTile(LivePosition p) {
    final digits = digitsFor(p.symbol, p.openPrice);
    String fmt(double v) => v.toStringAsFixed(digits);
    final profitColor = p.floatingPnL >= 0 ? MtColors.bid : MtColors.ask;
    final expanded = _expanded.contains(p.positionId);
    return Material(
      color: MtColors.white,
      child: InkWell(
        onTap: () => setState(() {
          if (expanded) {
            _expanded.remove(p.positionId);
          } else {
            _expanded.add(p.positionId);
          }
        }),
        onLongPress: () => _showPositionMenu(p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${p.symbol}, ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MtColors.text,
                            ),
                          ),
                          TextSpan(
                            text:
                                '${p.isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              color: p.isBuy ? MtColors.bid : MtColors.ask,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    formatMoney(p.floatingPnL),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: profitColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${fmt(p.openPrice)} → ${fmt(p.currentPrice)}',
                style: TextStyle(fontSize: 14, color: MtColors.icon),
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${p.positionId}',
                            style: TextStyle(
                              fontSize: 13,
                              color: MtColors.icon,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _detailRow('S / L:', _slTp(p.stopLoss, digits)),
                          const SizedBox(height: 6),
                          _detailRow('T / P:', _slTp(p.takeProfit, digits)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _detailRow(
                            'Open:',
                            p.openTime != null
                                ? formatDealTime(p.openTime!)
                                : '--',
                            alignEnd: true,
                          ),
                          const SizedBox(height: 6),
                          _detailRow(
                            'Swap:',
                            formatMoney(p.swap),
                            alignEnd: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Divider(height: 1, color: MtColors.line),
            ],
          ),
        ),
      ),
    );
  }

  String _slTp(double? v, int digits) =>
      (v == null || v == 0) ? '—' : v.toStringAsFixed(digits);

  Widget _detailRow(String label, String value, {bool alignEnd = false}) {
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: MtColors.icon)),
        const SizedBox(width: 16),
        Text(value, style: TextStyle(fontSize: 13, color: MtColors.text)),
      ],
    );
  }

  Widget _pendingTile(PendingOrder o) {
    return Material(
      color: MtColors.white,
      child: InkWell(
        onLongPress: () async {
          try {
            await tradingService.cancelPending(o.orderId);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${o.symbol}, ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MtColors.text,
                      ),
                    ),
                    TextSpan(
                      text:
                          '${o.orderType.toLowerCase().replaceAll('_', ' ')} ${o.volume.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        color: o.side == 'BUY' ? MtColors.bid : MtColors.ask,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'at ${o.price}',
                style: TextStyle(fontSize: 14, color: MtColors.icon),
              ),
              const SizedBox(height: 4),
              Divider(height: 1, color: MtColors.line),
            ],
          ),
        ),
      ),
    );
  }
}
