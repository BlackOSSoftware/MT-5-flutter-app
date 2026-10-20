import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_bottom_nav.dart';
import '../charts/charts_screen.dart';
import '../history/history_screen.dart';
import '../messages/messages_screen.dart';
import '../news/news_screen.dart';
import '../quotes/quotes_screen.dart';
import '../trade/trade_screen.dart';
import 'app_drawer.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _controller = ShellController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _lastLoggedIn = tradingService.hasAnyAccount;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    tradingService.addListener(_onService);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Live ticks har second kai baar aate hain - shell ko un pe rebuild
  /// nahi karna, sirf login/logout badalne pe refresh karna hai.
  /// Har screen apna live data khud sunti hai.
  void _onService() {
    final now = tradingService.hasAnyAccount;
    if (now != _lastLoggedIn) {
      _lastLoggedIn = now;
      _rebuild();
    }
  }

  @override
  void dispose() {
    tradingService.removeListener(_onService);
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      controller: _controller,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: MtColors.white,
        drawer: const AppDrawer(),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _controller.tab,
            children: [
              QuotesScreen(onMenu: _openDrawer),
              ChartsScreen(
                onMenu: _openDrawer,
                symbol: _controller.chartSymbol,
              ),
              TradeScreen(onMenu: _openDrawer),
              HistoryScreen(onMenu: _openDrawer),
              MessagesScreen(onMenu: _openDrawer),
              NewsScreen(onMenu: _openDrawer),
            ],
          ),
        ),
        bottomNavigationBar: MtBottomNav(
          index: _controller.tab,
          onChanged: _controller.openTab,
        ),
      ),
    );
  }
}
