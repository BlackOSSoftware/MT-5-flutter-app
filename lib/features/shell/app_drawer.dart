import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_config.dart';
import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_bottom_nav.dart';
import '../account/account_data.dart';
import '../account/accounts_page.dart';
import 'settings_page.dart';
import 'simple_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    final width = (screen - 56).clamp(280.0, 360.0);
    final viewTop =
        View.of(context).padding.top / View.of(context).devicePixelRatio;
    final mediaTop = MediaQuery.viewPaddingOf(context).top;
    final paddingTop = MediaQuery.paddingOf(context).top;
    var topInset = viewTop;
    if (mediaTop > topInset) topInset = mediaTop;
    if (paddingTop > topInset) topInset = paddingTop;
    if (topInset < 24) topInset = 32;
    return Drawer(
      width: width,
      backgroundColor: MtColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(),
      child: ColoredBox(
        color: MtColors.white,
        child: Column(
          children: [
            SizedBox(height: topInset > 10 ? topInset - 10 : topInset),
            Stack(
              children: [
                const _Header(),
                Positioned(
                  top: 0,
                  right: 0,
                  child: ListenableBuilder(
                    listenable: tradingService,
                    builder: (context, _) => tradingService.hasAnyAccount
                        ? const CustomPaint(
                            size: Size(56, 56),
                            painter: _DemoRibbonPainter(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(top: 6, bottom: 16),
                children: [
                  _Entry(
                    icon: TradeNavIcon(color: MtColors.icon, size: 22),
                    label: 'Trade',
                    onTap: () => _openTab(context, 2),
                  ),
                  _Entry(
                    icon: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        MtColors.icon,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/icons/news_paper.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                    ),
                    label: 'News',
                    labelFontSize: 14,
                    onTap: () => _openTab(context, 5),
                  ),
                  _Entry(
                    icon: Icon(
                      Icons.mail_outline,
                      color: MtColors.icon,
                      size: 22,
                    ),
                    label: 'Mailbox',
                    // badge: '${demoAccount.mailCount}',
                    onTap: () => _openTab(context, 4),
                  ),
                  _Entry(
                    icon: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        MtColors.icon,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/icons/journal_book.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                    ),
                    label: 'Journal',
                    onTap: () => _openPage(
                      context,
                      SimplePage(
                        title: 'Journal',
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            for (final line in _journalLines())
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  6,
                                  16,
                                  6,
                                ),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: MtColors.text,
                                    fontFamily: 'Roboto Mono',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _Entry(
                    icon: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        MtColors.iconDark,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/icons/settings_gear.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                    ),
                    label: 'Settings',
                    onTap: () => _openPage(context, SettingsPage()),
                  ),
                  _Entry(
                    icon: Icon(
                      Icons.calendar_today_outlined,
                      color: MtColors.icon,
                      size: 22,
                    ),
                    label: 'Economic calendar',
                    chip: 'Ads',
                    onTap: () => _openEconomicCalendar(context),
                  ),
                  _Entry(
                    icon: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        MtColors.icon,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/icons/traders_community.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                    ),
                    label: 'Traders Community',
                    onTap: () => _openPage(
                      context,
                      SimplePage(title: 'Traders Community'),
                    ),
                  ),
                  _Entry(
                    icon: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        MtColors.iconDark,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/icons/mql5_plane.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                    ),
                    label: 'MQL5 Algo Trading',
                    onTap: () => _openExternal(context, 'https://t.me/mql5dev'),
                  ),
                  _Entry(
                    icon: Icon(
                      Icons.help_outline,
                      color: MtColors.icon,
                      size: 22,
                    ),
                    label: 'User guide',
                    onTap: () => _openExternal(
                      context,
                      'https://www.metatrader5.com/en/mobile-trading/android/help?utm_medium=app&utm_uniq=5188403438348840093&utm_codepage=1033&utm_campaign=mt5android&utm_source=metaquotes.mt5.android&utm_link=7777FFFFFF22FFFFFFFF6EFF64FF7B62',
                    ),
                  ),
                  _Entry(
                    icon: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        MtColors.icon,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/icons/about_info.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                    ),
                    label: 'About',
                    onTap: () => _openPage(
                      context,
                      SimplePage(
                        title: 'About',
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.show_chart,
                                size: 72,
                                color: MtColors.accent,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'MetaTrader 5',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: MtColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Version 1.0.0',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: MtColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                tradingService.session != null
                                    ? 'Account: ${tradingService.session!.accountNumber}\nServer: ${ApiConfig.host}'
                                    : 'Server: ${ApiConfig.host}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: MtColors.icon,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTab(BuildContext context, int index) {
    final shell = ShellScope.of(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    // When the drawer sits on a pushed page (e.g. Accounts), go back
    // to the main shell first so the selected tab becomes visible.
    navigator.popUntil((r) => r.isFirst);
    shell.openTab(index);
  }

  void _openExternal(BuildContext context, String url) {
    Navigator.of(context).pop();
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _openEconomicCalendar(BuildContext context) {
    _openExternal(
      context,
      'https://play.google.com/store/apps/details?id=net.metaquotes.economiccalendar',
    );
  }

  void _openPage(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

List<String> _journalLines() {
  final now = DateTime.now();
  String t(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  final s = tradingService.session;
  return [
    '${t(now)}  Network: ${tradingService.wsConnected ? 'connected' : 'connecting'} to ${ApiConfig.host}',
    if (s != null)
      '${t(now)}  Authorized: account ${s.accountNumber} (${s.sessionType})',
    '${t(now)}  Server: ${ApiConfig.host}',
    '${t(now)}  Watchlist: ${tradingService.watchlist.length} symbols',
    '${t(now)}  Quotes: ${tradingService.quotes.length} symbols subscribed',
    '${t(now)}  Positions: ${tradingService.positions.length} open',
  ];
}

class _DemoRibbonPainter extends CustomPainter {
  const _DemoRibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final w = size.width;
    // Diagonal band across the corner only: from the top edge to the right edge.
    final a = w * 0.42;
    final b = w * 0.98;
    final band = Path()
      ..moveTo(w - b, 0)
      ..lineTo(w - a, 0)
      ..lineTo(w, a)
      ..lineTo(w, b)
      ..close();
    canvas.drawPath(band, Paint()..color = const Color(0xFF46A81E));
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Demo',
        style: TextStyle(
          fontFamily: 'Roboto',
          color: MtColors.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          shadows: [
            Shadow(
              color: Color(0xE61B5E20),
              offset: Offset(1.5, 0),
              blurRadius: 3,
            ),
            Shadow(
              color: Color(0xE61B5E20),
              offset: Offset(-1.5, 0),
              blurRadius: 3,
            ),
            Shadow(
              color: Color(0xE61B5E20),
              offset: Offset(0, 1.5),
              blurRadius: 3,
            ),
            Shadow(
              color: Color(0xE61B5E20),
              offset: Offset(0, -1.5),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final center = Offset(w - (a + b) / 4, (a + b) / 4);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.785398);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Header shown when no account is logged in (MT5 style):
/// blue profile icon, hint text and a "Get started" button which
/// signs in with the default account.
class _LoggedOutHeader extends StatefulWidget {
  const _LoggedOutHeader();

  @override
  State<_LoggedOutHeader> createState() => _LoggedOutHeaderState();
}

class _LoggedOutHeaderState extends State<_LoggedOutHeader> {
  void _getStarted() {
    final navigator = Navigator.of(context);
    final shell = ShellScope.maybeOf(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AccountsPage(shellController: shell),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/icons/profile_add.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      'Login to existing account or\nopen demo account',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        color: MtColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: FilledButton(
                  onPressed: _getStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: MtColors.accent,
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Get started',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: MtColors.line),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tradingService,
      builder: (context, _) {
        // Jo account sabse LAST me login hua hai wahi upar
        // dikhega (FP Trades session ya MetaQuotes demo).
        final mq = tradingService.mqAccount;
        if (tradingService.activeSource == 'server' &&
            tradingService.isLoggedIn) {
          return _loggedIn(context);
        }
        if (mq != null) return _mqLoggedIn(context, mq);
        if (!tradingService.isLoggedIn) {
          return const _LoggedOutHeader();
        }
        return _loggedIn(context);
      },
    );
  }

  Widget _mqLoggedIn(BuildContext context, Map<String, dynamic> mq) {
    final first = '${mq['first_name'] ?? ''}'.trim();
    final second = '${mq['second_name'] ?? ''}'.trim();
    final name = [first, second].where((e) => e.isNotEmpty).join(' ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/icons/mt5_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '${mq['login_id']}' : name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: MtColors.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${mq['login_id']} - ${mq['server']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: MtColors.icon,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _ManageLink(),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Manage accounts ke neeche halki border.
        Divider(height: 1, thickness: 1, color: MtColors.line),
      ],
    );
  }

  Widget _loggedIn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/icons/mt5_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListenableBuilder(
                      listenable: tradingService,
                      builder: (context, _) {
                        final s = tradingService.session;
                        // Upar account holder ka NAAM aayega,
                        // number nahi (number neeche wali line me).
                        final holder = (s?.name ?? '').trim();
                        return Text(
                          holder.isNotEmpty
                              ? holder
                              : (s?.accountNumber ?? demoAccount.name),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: MtColors.text,
                            height: 1.2,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 2),
                    Text(
                      tradingService.session != null
                          ? '${tradingService.session!.accountNumber} - ${ApiConfig.serverNameFor(tradingService.session!.accountType)}'
                          : demoAccount.loginLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: MtColors.icon,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _ManageLink(),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Manage accounts ke neeche halki border.
        Divider(height: 1, thickness: 1, color: MtColors.line),
      ],
    );
  }
}

class _ManageLink extends StatelessWidget {
  const _ManageLink();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final navigator = Navigator.of(context);
        final shell = ShellScope.maybeOf(context);
        navigator.pop();
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => AccountsPage(shellController: shell),
          ),
        );
      },
      child: const Text(
        'Manage accounts',
        style: TextStyle(
          color: MtColors.accent,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.chip,
    this.labelFontSize = 16,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final String? chip;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SizedBox(width: 24, height: 24, child: Center(child: icon)),
              SizedBox(width: 28),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: labelFontSize,
                          color: MtColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (chip != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MtColors.accent),
                        ),
                        child: Text(
                          chip!,
                          style: const TextStyle(
                            color: MtColors.accent,
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: MtColors.badge,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: MtColors.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1,
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
