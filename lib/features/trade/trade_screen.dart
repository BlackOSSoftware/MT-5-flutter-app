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
  int _sortMode = 0; // 0 time, 1 symbol, 2 profit, 3 order (ticket)
  bool _sortDesc = true;

  /// Naya field chunne pe uska natural order: time/profit me
  /// bada pehle, symbol A-Z aur order ticket chhota pehle.
  static bool _defaultDesc(int mode) => mode == 0 || mode == 2;

  Future<void> _showSortMenu(BuildContext anchorContext) async {
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final button = anchorContext.findRenderObject() as RenderBox;
    final topRight = button.localToGlobal(
      Offset(button.size.width, 0),
      ancestor: overlay,
    );
    // showMenu width ko 56 ke step me badha deta hai, isliye apna
    // panel: width sirf text + arrow jitni.
    final selected = await showGeneralDialog<int>(
      context: anchorContext,
      barrierDismissible: true,
      barrierLabel: 'sort-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          Positioned(
            top: topRight.dy,
            right: overlay.size.width - topRight.dx,
            child: Material(
              color: MtColors.isDark ? MtColors.white : const Color(0xFFFAFAFA),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: MtColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    for (final (i, (mode, label)) in const [
                      (3, 'Order'),
                      (0, 'Time'),
                      (1, 'Symbol'),
                      (2, 'Profit'),
                    ].indexed) ...[
                      if (i > 0) Divider(height: 1, color: MtColors.line),
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(mode),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
                          child: Row(
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: MtColors.text,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Spacer(),
                              SizedBox(
                                width: 18,
                                child: _sortMode == mode
                                    ? Transform.scale(
                                        scaleX: 0.85,
                                        scaleY: 1.35,
                                        child: Icon(
                                          _sortDesc
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          size: 20,
                                          color: const Color(0xFF168BE1),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
    if (selected == null || selected < 0 || !mounted) return;
    setState(() {
      // Wahi field dobara chuna to order ulta (asc <-> desc).
      if (selected == _sortMode) {
        _sortDesc = !_sortDesc;
      } else {
        _sortMode = selected;
        _sortDesc = _defaultDesc(selected);
      }
    });
  }

  int _applyDir(int cmp) => _sortDesc ? -cmp : cmp;

  @override
  void initState() {
    super.initState();
    tradingService.refreshAccount();
  }

  List<LivePosition> get _positions {
    final list = tradingService.positions.values.toList();
    switch (_sortMode) {
      case 1:
        list.sort((a, b) => _applyDir(a.symbol.compareTo(b.symbol)));
      case 2:
        list.sort((a, b) => _applyDir(a.floatingPnL.compareTo(b.floatingPnL)));
      case 3:
        list.sort(
          (a, b) => _applyDir((a.ticket ?? 0).compareTo(b.ticket ?? 0)),
        );
      default:
        list.sort(
          (a, b) => _applyDir(
            (a.openTime ?? DateTime(0)).compareTo(b.openTime ?? DateTime(0)),
          ),
        );
    }
    return list;
  }

  /// Pending orders me profit nahi hota, wahan profit mode pe time se.
  List<PendingOrder> get _pendings {
    final list = tradingService.pendings.values.toList();
    if (_sortMode == 1) {
      list.sort((a, b) => _applyDir(a.symbol.compareTo(b.symbol)));
    } else if (_sortMode == 3) {
      list.sort((a, b) => _applyDir((a.ticket ?? 0).compareTo(b.ticket ?? 0)));
    } else {
      list.sort(
        (a, b) => _applyDir(
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
        ),
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

  void _openPositionAction(LivePosition p, PositionAction action) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PositionActionPage(position: p, action: action),
      ),
    );
  }

  /// Long-press sheet: expanded card preview (live) on top, actions below.
  void _showItemSheet({
    required Widget Function() preview,
    required List<(String, VoidCallback)> actions,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MtColors.white,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: ListenableBuilder(
                  listenable: tradingService,
                  builder: (_, _) => preview(),
                ),
              ),
              for (final (label, onTap) in actions)
                InkWell(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onTap();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
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
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showPositionMenu(LivePosition p) {
    final shell = ShellScope.of(context);
    _showItemSheet(
      preview: () => _positionContent(
        tradingService.positions[p.positionId] ?? p,
        expanded: true,
      ),
      actions: [
        ('Close position', () => _openPositionAction(p, PositionAction.close)),
        (
          'Modify position',
          () => _openPositionAction(p, PositionAction.modify),
        ),
        ('New order', () => _openNewOrder(context, p.symbol)),
        ('Chart', () => shell.openChart(p.symbol)),
        ('Bulk Operations...', () => _positionBulkMenu(p)),
      ],
    );
  }

  /* ---------------- bulk operations ---------------- */

  /// MT5 style "Bulk Operations" sheet: title + selected item line,
  /// neeche options. Jis option me abhi koi item match na kare wo gray.
  void _showBulkSheet({
    String? subtitle,
    required List<(String, bool, VoidCallback)> options,
  }) {
    final textColor = MtColors.isDark ? MtColors.text : const Color(0xFF424242);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MtColors.isDark
          ? MtColors.white
          : const Color(0xFFEEF2F8),
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Text(
                'Bulk Operations',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: MtColors.line),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (label, enabled, run) in options)
                        InkWell(
                          onTap: enabled
                              ? () {
                                  Navigator.of(sheetContext).pop();
                                  run();
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 17,
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 16,
                                color: enabled
                                    ? textColor
                                    : const Color(0xFFBDBDBD),
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
        );
      },
    );
  }

  /// Sab tasks ek-ek karke chalao; kitne hue / kitne fail, aur pehla error.
  Future<(int, int, String?)> _runAll(
    List<Future<void> Function()> tasks,
  ) async {
    var ok = 0;
    var failed = 0;
    String? firstError;
    for (final task in tasks) {
      try {
        await task();
        ok++;
      } catch (e) {
        failed++;
        firstError ??= '$e';
      }
    }
    return (ok, failed, firstError);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  void _positionBulkMenu([LivePosition? p]) {
    final side = p == null ? '' : (p.isBuy ? 'Buy' : 'Sell');
    final filters = <(String, bool Function(LivePosition))>[
      ('Close All Positions', (_) => true),
      ('Close Profitable Positions', (x) => x.floatingPnL > 0),
      ('Close Losing Positions', (x) => x.floatingPnL < 0),
      if (p != null) ...[
        ('Close $side Positions', (x) => x.isBuy == p.isBuy),
        ('Close ${p.symbol} Positions', (x) => x.symbol == p.symbol),
        (
          'Close ${p.symbol} $side Positions',
          (x) => x.symbol == p.symbol && x.isBuy == p.isBuy,
        ),
      ],
    ];
    final all = tradingService.positions.values;
    String? subtitle;
    if (p != null) {
      final digits = digitsFor(p.symbol, p.openPrice);
      subtitle =
          '${p.ticket != null ? '#${p.ticket} ' : ''}'
          '${p.isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)} '
          '${p.symbol} ${p.openPrice.toStringAsFixed(digits)}';
    }
    _showBulkSheet(
      subtitle: subtitle,
      options: [
        for (final (label, test) in filters)
          (label, all.any(test), () => _bulkClose(label, test)),
      ],
    );
  }

  Future<void> _bulkClose(
    String label,
    bool Function(LivePosition) test,
  ) async {
    final count = tradingService.positions.values.where(test).length;
    if (count == 0) return _snack('No matching positions');
    final ok = await _confirm(
      title: label,
      message:
          '${_plural(count, 'position')} will be closed at market price. '
          'Continue?',
      confirmLabel: 'Close',
    );
    if (!ok) return;
    // Confirm ke beech price badla ho to profit/loss filter dobara lagao.
    final targets = tradingService.positions.values.where(test).toList();
    final (done, failed, error) = await _runAll([
      for (final p in targets) () => tradingService.closePosition(p.positionId),
    ]);
    _snack(
      failed == 0
          ? '${_plural(done, 'position')} closed'
          : '$done closed, $failed failed: $error',
    );
  }

  static String _pendingCategory(PendingOrder o) {
    if (o.orderType.endsWith('STOP_LIMIT')) return 'Stop Limit';
    if (o.orderType.endsWith('LIMIT')) return 'Limit';
    return 'Stop';
  }

  static String _pendingTypeLabel(PendingOrder o) => o.orderType
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');

  void _pendingBulkMenu([PendingOrder? o]) {
    final filters = <(String, bool Function(PendingOrder))>[
      ('Delete All Orders', (_) => true),
      if (o != null) ...[
        (
          'Delete ${_pendingCategory(o)} Orders',
          (x) => _pendingCategory(x) == _pendingCategory(o),
        ),
        ('Delete ${o.symbol} Orders', (x) => x.symbol == o.symbol),
        (
          'Delete ${o.symbol} ${_pendingTypeLabel(o)} Orders',
          (x) => x.symbol == o.symbol && x.orderType == o.orderType,
        ),
      ] else ...[
        ('Delete Limit Orders', (x) => _pendingCategory(x) == 'Limit'),
        ('Delete Stop Orders', (x) => _pendingCategory(x) == 'Stop'),
      ],
    ];
    final all = tradingService.pendings.values;
    String? subtitle;
    if (o != null) {
      final digits = digitsFor(o.symbol, o.price);
      subtitle =
          '${o.ticket != null ? '#${o.ticket} ' : ''}'
          '${o.orderType.toLowerCase().replaceAll('_', ' ')} '
          '${o.volume.toStringAsFixed(2)} ${o.symbol} '
          '${o.price.toStringAsFixed(digits)}';
    }
    _showBulkSheet(
      subtitle: subtitle,
      options: [
        for (final (label, test) in filters)
          (label, all.any(test), () => _bulkDelete(label, test)),
      ],
    );
  }

  Future<void> _bulkDelete(
    String label,
    bool Function(PendingOrder) test,
  ) async {
    final count = tradingService.pendings.values.where(test).length;
    if (count == 0) return _snack('No matching orders');
    final ok = await _confirm(
      title: label,
      message: '${_plural(count, 'order')} will be deleted. Continue?',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    final targets = tradingService.pendings.values.where(test).toList();
    final (done, failed, error) = await _runAll([
      for (final o in targets) () => tradingService.cancelPending(o.orderId),
    ]);
    _snack(
      failed == 0
          ? '${_plural(done, 'order')} deleted'
          : '$done deleted, $failed failed: $error',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tradingService,
      builder: (context, _) {
        final acc = tradingService.account;
        final loaded = tradingService.accountLoaded;
        final positions = _positions;
        final totalPnl = positions.fold<double>(
          0,
          (sum, p) => sum + p.floatingPnL,
        );
        final pendings = _pendings;
        return ColoredBox(
          color: MtColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MtHeader(
                title: 'Trade',
                titleFontSize: 12,
                subtitleFontSize: 17,
                subtitle: _positions.isEmpty
                    ? null
                    : '${totalPnl >= 0 ? '' : '-'}${formatMoney(totalPnl.abs())} USD',
                subtitleColor: totalPnl >= 0 ? MtColors.bid : MtColors.ask,
                onMenu: widget.onMenu,
                actions: [
                  Builder(
                    builder: (buttonContext) => MtIconButton(
                      tooltip: 'Sort',
                      onPressed: () => _showSortMenu(buttonContext),
                      icon: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          MtColors.iconDark,
                          BlendMode.srcIn,
                        ),
                        child: Transform.flip(
                          flipX: true,
                          child: Image.asset(
                            'assets/icons/quotes_arrows.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
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
                                  fontSize: 14,
                                  verticalPadding: 4,
                                ),
                                DotLeaderRow(
                                  label: 'Equity',
                                  value: formatMoney(
                                    loaded ? acc.equity : demoAccount.equity,
                                  ),
                                  fontSize: 14,
                                  verticalPadding: 4,
                                ),
                                DotLeaderRow(
                                  label: 'Margin',
                                  value: formatMoney(acc.usedMargin),
                                  fontSize: 14,
                                  verticalPadding: 4,
                                ),
                                DotLeaderRow(
                                  label: 'Free margin',
                                  value: formatMoney(
                                    loaded
                                        ? acc.freeMargin
                                        : demoAccount.freeMargin,
                                  ),
                                  fontSize: 14,
                                  verticalPadding: 4,
                                ),
                                DotLeaderRow(
                                  label: 'Margin Level (%)',
                                  value: acc.usedMargin > 0
                                      ? formatMoney(acc.marginLevel)
                                      : '0.00',
                                  fontSize: 14,
                                  verticalPadding: 4,
                                ),
                              ],
                            ),
                          ),
                          _sectionHeader(
                            'Positions',
                            onMore: positions.isEmpty
                                ? null
                                : () => _positionBulkMenu(),
                          ),
                          if (positions.isEmpty)
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
                          for (final (i, p) in positions.indexed)
                            _positionTile(
                              p,
                              flushBottom:
                                  pendings.isNotEmpty &&
                                  i == positions.length - 1,
                            ),
                          if (pendings.isNotEmpty) ...[
                            _sectionHeader(
                              'Orders',
                              onMore: () => _pendingBulkMenu(),
                            ),
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

  Widget _sectionHeader(String title, {VoidCallback? onMore}) {
    return GestureDetector(
      onTap: onMore,
      behavior: HitTestBehavior.opaque,
      child: _sectionHeaderBar(title),
    );
  }

  Widget _sectionHeaderBar(String title) {
    return Container(
      decoration: BoxDecoration(
        color: MtColors.line.withValues(alpha: 0.45),
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E5E5)),
          bottom: BorderSide(color: Color(0xFFE5E5E5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 3, 8, 3),
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

  /// Card detail khulne/band hone pe height smooth slide ho, pop na kare.
  static Widget _expandAnim(Widget child) => AnimatedSize(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeInOut,
    alignment: Alignment.topCenter,
    child: child,
  );

  Widget _positionTile(LivePosition p, {bool flushBottom = false}) {
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
          padding: EdgeInsets.fromLTRB(16, 5, 16, flushBottom ? 0 : 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _expandAnim(_positionContent(p, expanded: expanded)),
              const SizedBox(height: 2),
              if (!flushBottom) Divider(height: 1, color: MtColors.line),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positionContent(LivePosition p, {required bool expanded}) {
    final digits = digitsFor(p.symbol, p.openPrice);
    String fmt(double v) => v.toStringAsFixed(digits);
    final profitColor = p.floatingPnL >= 0 ? MtColors.bid : MtColors.ask;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${p.symbol}, ',
                          style: TextStyle(
                            fontSize: 16,
                            height: 0.9,
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w700,
                            color: MtColors.text,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${p.isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            height: 0.9,
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w400,
                            color: p.isBuy ? MtColors.bid : MtColors.ask,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fmt(p.openPrice)} → ${fmt(p.currentPrice)}',
                    style: TextStyle(
                      fontSize: 14,
                      height: 0.9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
            Text(
              formatMoney(p.floatingPnL),
              style: TextStyle(
                fontSize: 16,
                height: 0.9,
                fontWeight: FontWeight.w700,
                color: profitColor,
              ),
            ),
          ],
        ),
        if (expanded) ...[
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        p.ticket != null ? '#${p.ticket}' : '',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF757575),
                        ),
                      ),
                      const SizedBox(height: 1),
                      _detailPair(
                        'S / L:',
                        _slTp(p.stopLoss, digits),
                        valueColor: MtColors.text,
                      ),
                      const SizedBox(height: 1),
                      _detailPair(
                        'T / P:',
                        _slTp(p.takeProfit, digits),
                        valueColor: MtColors.text,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _detailPair(
                      'Open:',
                      p.openTime != null ? formatDealTime(p.openTime!) : '--',
                    ),
                    const SizedBox(height: 1),
                    _detailPair('Swap:', formatMoney(p.swap)),
                    const SizedBox(height: 1),
                    _detailPair('Commission:', formatMoney(p.commission)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _slTp(double? v, int digits) =>
      (v == null || v == 0) ? '—' : v.toStringAsFixed(digits);

  Future<void> _cancelPending(PendingOrder o) async {
    try {
      await tradingService.cancelPending(o.orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _showPendingMenu(PendingOrder o) {
    final shell = ShellScope.of(context);
    _showItemSheet(
      preview: () => _pendingContent(
        tradingService.pendings[o.orderId] ?? o,
        expanded: true,
      ),
      actions: [
        ('Delete order', () => _confirmDeletePending(o)),
        ('Modify order', () => _modifyPending(o)),
        ('New order', () => _openNewOrder(context, o.symbol)),
        ('Chart', () => shell.openChart(o.symbol)),
        ('Bulk Operations...', () => _pendingBulkMenu(o)),
      ],
    );
  }

  Future<void> _confirmDeletePending(PendingOrder o) async {
    final digits = digitsFor(o.symbol, o.price);
    final type = o.orderType.toLowerCase().replaceAll('_', ' ');
    final ticket = o.ticket != null ? '#${o.ticket} ' : '';
    final ok = await _confirm(
      title: 'Delete order',
      message:
          'Delete order: $ticket$type ${o.volume.toStringAsFixed(2)} '
          '${o.symbol} at ${o.price.toStringAsFixed(digits)}?',
      confirmLabel: 'Delete',
    );
    if (ok) await _cancelPending(o);
  }

  /// MT5 style confirm dialog: bada title, gray message, blue buttons.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    const blue = Color(0xFF168BE1);
    Widget action(String label, bool result, BuildContext ctx) {
      return TextButton(
        onPressed: () => Navigator.pop(ctx, result),
        style: TextButton.styleFrom(
          foregroundColor: blue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MtColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: MtColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: MtColors.icon,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  action('Cancel', false, ctx),
                  const SizedBox(width: 8),
                  action(confirmLabel, true, ctx),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _modifyPending(PendingOrder o) async {
    String initial(double? v) => v != null && v > 0 ? '$v' : '';
    final price = TextEditingController(text: initial(o.price));
    final sl = TextEditingController(text: initial(o.stopLoss));
    final tp = TextEditingController(text: initial(o.takeProfit));
    const numKeyboard = TextInputType.numberWithOptions(decimal: true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          o.ticket == null ? 'Modify order' : 'Modify order #${o.ticket}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: price,
              keyboardType: numKeyboard,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            TextField(
              controller: sl,
              keyboardType: numKeyboard,
              decoration: const InputDecoration(labelText: 'Stop Loss'),
            ),
            TextField(
              controller: tp,
              keyboardType: numKeyboard,
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
    final newPrice = double.tryParse(price.text.trim());
    if (newPrice == null || newPrice <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid price')));
      }
      return;
    }
    if (!mounted) return;
    final digits = digitsFor(o.symbol, newPrice);
    final newSl = double.tryParse(sl.text.trim());
    final newTp = double.tryParse(tp.text.trim());
    String fmt(double? v) =>
        v == null || v <= 0 ? '—' : v.toStringAsFixed(digits);
    await showTradeExecution(
      context,
      title: 'Modify order',
      side: o.side,
      symbol: o.symbol,
      digits: digits,
      lines: [
        'modify ${o.ticket != null ? '#${o.ticket} ' : ''}'
            '${o.orderType.toLowerCase().replaceAll('_', ' ')} '
            '${o.volume.toStringAsFixed(2)} ${o.symbol} '
            'at ${newPrice.toStringAsFixed(digits)}',
        'sl: ${fmt(newSl)}   tp: ${fmt(newTp)}',
      ],
      task: () => tradingService.modifyPending(
        orderId: o.orderId,
        price: newPrice,
        stopLoss: newSl,
        takeProfit: newTp,
      ),
    );
  }

  String _pendingMarketPrice(PendingOrder o, int digits) {
    final q = tradingService.quotes[o.symbol.toUpperCase()];
    var px = 0.0;
    if (q != null && q.hasPrice) {
      px = o.isBuy ? q.bid : q.ask;
    } else if (o.currentPrice != null) {
      px = o.currentPrice!;
    }
    if (px <= 0) return '—';
    return px.toStringAsFixed(digits);
  }

  Widget _detailPair(String label, String value, {Color? valueColor}) {
    final style = TextStyle(
      fontSize: 12,
      letterSpacing: -0.3,
      color: MtColors.icon,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(
          value,
          style: valueColor == null ? style : style.copyWith(color: valueColor),
        ),
      ],
    );
  }

  Widget _pendingTile(PendingOrder o) {
    final expanded = _expanded.contains(o.orderId);
    return Material(
      color: MtColors.white,
      child: InkWell(
        onTap: () => setState(() {
          if (expanded) {
            _expanded.remove(o.orderId);
          } else {
            _expanded.add(o.orderId);
          }
        }),
        onLongPress: () => _showPendingMenu(o),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _expandAnim(_pendingContent(o, expanded: expanded)),
              const SizedBox(height: 5),
              Divider(height: 1, color: MtColors.line),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingContent(PendingOrder o, {required bool expanded}) {
    final digits = digitsFor(o.symbol, o.price);
    final typeLabel = o.orderType.toLowerCase().replaceAll('_', ' ');
    final sideColor = o.isBuy ? MtColors.bid : MtColors.ask;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${o.symbol}, ',
                      style: TextStyle(
                        fontSize: 16,
                        height: 0.9,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w700,
                        color: MtColors.text,
                      ),
                    ),
                    TextSpan(
                      text: typeLabel,
                      style: TextStyle(
                        fontSize: 15,
                        height: 0.9,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w400,
                        color: sideColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'placed',
              style: TextStyle(
                fontSize: 15,
                height: 0.9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF616161),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${o.volume.toStringAsFixed(2)} / ${o.filledVolume.toStringAsFixed(2)} at ${o.price.toStringAsFixed(digits)}',
          style: TextStyle(
            fontSize: 14,
            height: 0.9,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF757575),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        o.ticket != null ? '#${o.ticket}' : '',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF757575),
                        ),
                      ),
                      const SizedBox(height: 1),
                      _detailPair(
                        'S / L:',
                        _slTp(o.stopLoss, digits),
                        valueColor: MtColors.text,
                      ),
                      const SizedBox(height: 1),
                      _detailPair(
                        'T / P:',
                        _slTp(o.takeProfit, digits),
                        valueColor: MtColors.text,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _detailPair(
                      'Open:',
                      o.createdAt != null ? formatDealTime(o.createdAt!) : '--',
                    ),
                    const SizedBox(height: 1),
                    _detailPair('Price:', _pendingMarketPrice(o, digits)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
