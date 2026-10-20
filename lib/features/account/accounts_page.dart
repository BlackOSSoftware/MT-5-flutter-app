import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_config.dart';
import '../../core/format.dart';
import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_bottom_nav.dart';
import '../shell/app_drawer.dart';
import '../shell/no_accounts_view.dart';
import 'account_data.dart';
import 'brokers_page.dart';
import 'fp_trades_page.dart';
import 'mq_account_login_page.dart';
import 'mq_widgets.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, this.shellController});

  final ShellController? shellController;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  /// Saare locally saved MetaQuotes demo accounts - har ek ki card
  /// ek ke neeche ek dikhti hai. Jo account login (active) hai
  /// woh sabse upar aata hai.
  List<Map<String, dynamic>> _mqAccounts = const [];
  String? _activeLoginId;

  @override
  void initState() {
    super.initState();
    _loadMqAccounts();
  }

  Future<void> _loadMqAccounts() async {
    final p = await SharedPreferences.getInstance();
    final parsed = <Map<String, dynamic>>[];
    for (final raw in p.getStringList('mq_created_accounts') ?? const []) {
      try {
        final d = jsonDecode(raw);
        if (d is Map<String, dynamic>) parsed.add(d);
      } catch (_) {
        // Corrupted entry - skip it.
      }
    }
    String? activeId;
    final activeRaw = p.getString('mq_active_account');
    if (activeRaw != null) {
      try {
        final d = jsonDecode(activeRaw);
        if (d is Map<String, dynamic>) activeId = '${d['login_id']}';
      } catch (_) {}
    }
    // Active account sabse upar.
    parsed.sort(
      (a, b) => ('${a['login_id']}' == activeId ? 0 : 1).compareTo(
        '${b['login_id']}' == activeId ? 0 : 1,
      ),
    );
    if (!mounted) return;
    setState(() {
      _mqAccounts = parsed;
      _activeLoginId = activeId;
    });
  }

  Future<void> _mqLogout() async {
    // Service state clear karne se poori app (sidebar, screens)
    // wapas logged-out ho jati hai.
    await tradingService.setMqAccount(null);
    await _loadMqAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: MtColors.white,
      drawer: const AppDrawer(),
      // Accounts alag screen hai, phir bhi neeche wahi bottom
      // navigation dikhti hai (MT5 ki tarah). Koi tab dabane par
      // wapas main shell ke usi tab par le jata hai.
      bottomNavigationBar: MtBottomNav(
        index: -1,
        onChanged: (i) {
          final shell = widget.shellController;
          final nav = Navigator.of(context);
          if (shell != null) {
            nav.pop();
            shell.openTab(i);
          } else {
            nav.popUntil((r) => r.isFirst);
          }
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Builder(
              builder: (headerContext) => _AccountsHeader(
                onMenu: () => Scaffold.of(headerContext).openDrawer(),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: tradingService,
                builder: (context, _) {
                  final s = tradingService.session;
                  // FP Trades sabse last login hua hai to uska
                  // bada card sabse upar, MQ accounts neeche.
                  final fpActive =
                      tradingService.activeSource == 'server' && s != null;
                  if (_mqAccounts.isNotEmpty || fpActive) {
                    return ListView(
                      children: [
                        if (fpActive)
                          _FpAccountCard(onTap: () => _showFpActions()),
                        // Login (active) account = bada card, baaki
                        // accounts ki chhoti compact cards ek ke
                        // neeche ek (MT5 style).
                        for (final a in _mqAccounts)
                          if (!fpActive && '${a['login_id']}' == _activeLoginId)
                            _MqAccountCard(
                              account: a,
                              onTap: () => _showMqActions(a),
                            )
                          else
                            _MqAccountCompactCard(
                              account: a,
                              onTap: () => _openMqLogin(a),
                            ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  if (s == null) {
                    return const NoAccountsBody();
                  }
                  return ListView(
                    children: [
                      const _AccountTile(),
                      Divider(
                        height: 1,
                        color: MtColors.line,
                        indent: 16,
                        endIndent: 16,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Balance: ${formatMoney(tradingService.account.balance)}'
                          '   Equity: ${formatMoney(tradingService.account.equity)}',
                          style: TextStyle(fontSize: 13, color: MtColors.icon),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'Server: ${ApiConfig.serverNameFor(s.accountType)}  •  Session: ${s.sessionType}',
                          style: TextStyle(fontSize: 13, color: MtColors.icon),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          'Auto login: ON (default account)',
                          style: TextStyle(fontSize: 13, color: MtColors.demo),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.logout, color: MtColors.ask),
                        title: const Text('Logout'),
                        onTap: () async {
                          await tradingService.logout();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    final controller = widget.shellController;
    if (controller != null) {
      return ShellScope(controller: controller, child: scaffold);
    }
    return scaffold;
  }

  /// Dusre account ki compact card par tap -> "Login to an
  /// account" screen (screenshot wali). Wapas aane par list
  /// refresh takki naya active account bada card ban jaye.
  Future<void> _openMqLogin(Map<String, dynamic> a) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MqAccountLoginPage(account: a)),
    );
    await _loadMqAccounts();
  }

  void _showFpActions() {
    final s = tradingService.session;
    if (s == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MtColors.white,
        title: Text(
          s.accountNumber,
          style: TextStyle(fontSize: 18, color: MtColors.text),
        ),
        content: Text(
          'FP Trades\n${s.name}\n${ApiConfig.serverNameFor(s.accountType)}\nCurrently logged in',
          style: TextStyle(fontSize: 14, color: MtColors.icon),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: mqBlue, fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await tradingService.logout();
              await _loadMqAccounts();
            },
            child: Text(
              'Logout',
              style: TextStyle(color: MtColors.ask, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showMqActions(Map<String, dynamic> a) {
    final isActive = '${a['login_id']}' == _activeLoginId;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MtColors.white,
        title: Text(
          '${a['login_id']}',
          style: TextStyle(fontSize: 18, color: MtColors.text),
        ),
        content: Text(
          '${a['server']}\n${a['email']}${isActive ? '\nCurrently logged in' : ''}',
          style: TextStyle(fontSize: 14, color: MtColors.icon),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: mqBlue, fontSize: 15),
            ),
          ),
          if (isActive)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _mqLogout();
              },
              child: Text(
                'Logout',
                style: TextStyle(color: MtColors.ask, fontSize: 15),
              ),
            )
          else
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                // Is account ko active (logged-in) bana do.
                await tradingService.setMqAccount(a);
                await _loadMqAccounts();
              },
              child: const Text(
                'Login',
                style: TextStyle(color: mqBlue, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }
}

/// Accounts screen header (MT5 style): menu icon, "Accounts"
/// title, then shield / settings / add / more actions.
class _AccountsHeader extends StatelessWidget {
  const _AccountsHeader({required this.onMenu});

  final VoidCallback onMenu;

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This option is not available yet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = MtColors.iconDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            onPressed: onMenu,
            icon: Icon(Icons.menu, size: 24, color: color),
          ),
          const SizedBox(width: 2),
          Text(
            'Accounts',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Roboto Condensed',
              fontWeight: FontWeight.w400,
              color: MtColors.text,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Security',
            onPressed: () => _soon(context),
            icon: Image.asset(
              'assets/icons/shield_keyhole.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
          IconButton(
            tooltip: 'Certificates',
            onPressed: () => _soon(context),
            icon: Image.asset(
              'assets/icons/medal_badge.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
          IconButton(
            tooltip: 'Add account',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BrokersPage()),
            ),
            icon: Icon(Icons.add, size: 26, color: color),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: () => _soon(context),
            icon: Icon(Icons.more_vert, size: 24, color: color),
          ),
        ],
      ),
    );
  }
}

/// MetaQuotes demo account card (MT5 Accounts layout): Demo chip,
/// broker logo, holder name, company, login - server line, access
/// point line and the balance row with QR / bell icons.
class _MqAccountCard extends StatelessWidget {
  const _MqAccountCard({required this.account, required this.onTap});

  final Map<String, dynamic> account;
  final VoidCallback onTap;

  static String _money(num v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(' ');
      buf.write(intPart[i]);
    }
    return '${buf.toString()}.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final first = '${account['first_name'] ?? ''}'.trim();
    final second = '${account['second_name'] ?? ''}'.trim();
    var name = [first, second].where((e) => e.isNotEmpty).join(' ');
    if (name.isEmpty) name = '${account['email'] ?? account['login_id'] ?? ''}';
    final balance = (account['balance'] as num?) ?? 0;
    final currency = '${account['currency'] ?? 'USD'}';
    final hedge = account['hedge'] != false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          border: Border.all(color: const Color(0xFFEDEDED), width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  // Upar right me Demo chip, uske NEECHE beech me logo.
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F4E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Demo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Image.asset(
                    'assets/icons/mt5_logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MtColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'MetaQuotes Ltd.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: mqBlue),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${account['login_id']} — ${account['server']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF757575),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Access Point EU 0, ${hedge ? 'Hedge' : 'Netting'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/qr_code.png',
                        width: 12,
                        height: 12,
                        fit: BoxFit.contain,
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _money(balance),
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w400,
                                  color: MtColors.text,
                                ),
                              ),
                              TextSpan(
                                text: ' $currency',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Icon(
                        Icons.notifications_none,
                        size: 16,
                        color: Color(0xFF757575),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FP Trades (server session) account ka bada card - jab FP
/// login sabse last me hua ho to Accounts me sabse upar aata hai.
class _FpAccountCard extends StatelessWidget {
  const _FpAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = tradingService.session;
    if (s == null) return const SizedBox.shrink();
    final name = s.name.trim().isNotEmpty ? s.name.trim() : s.accountNumber;
    final balance = tradingService.account.balance;
    final isDemo = s.accountType.toLowerCase().contains('demo');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          border: Border.all(color: const Color(0xFFEDEDED), width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  if (isDemo)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F4E5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Demo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const FpLogo(size: 36),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MtColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'FP Trades',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: mqBlue),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${s.accountNumber} — ${ApiConfig.serverNameFor(s.accountType)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF757575),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/qr_code.png',
                        width: 12,
                        height: 12,
                        fit: BoxFit.contain,
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _MqAccountCard._money(balance),
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w400,
                                  color: MtColors.text,
                                ),
                              ),
                              const TextSpan(
                                text: ' USD',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Icon(
                        Icons.notifications_none,
                        size: 16,
                        color: Color(0xFF757575),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dusre (non-active) accounts ki chhoti card: logo left, naam +
/// login + balance lines, right par Demo chip aur QR icon.
class _MqAccountCompactCard extends StatelessWidget {
  const _MqAccountCompactCard({required this.account, required this.onTap});

  final Map<String, dynamic> account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = '${account['first_name'] ?? ''}'.trim();
    final second = '${account['second_name'] ?? ''}'.trim();
    var name = [first, second].where((e) => e.isNotEmpty).join(' ');
    if (name.isEmpty) name = '${account['email'] ?? account['login_id'] ?? ''}';
    final balance = (account['balance'] as num?) ?? 0;
    final currency = '${account['currency'] ?? 'USD'}';
    final hedge = account['hedge'] != false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          border: Border.all(color: const Color(0xFFEDEDED), width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/icons/mt5_logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: MtColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${account['login_id']} — ${account['server']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Color(0xFF757575),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_MqAccountCard._money(balance)} $currency, ${hedge ? 'Hedging' : 'Netting'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F4E5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Demo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Image.asset(
                        'assets/icons/qr_code.png',
                        width: 12,
                        height: 12,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context) {
    final s = tradingService.session;
    final isDemo =
        (s?.accountType.toLowerCase().contains('demo') ?? demoAccount.demo);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s?.accountNumber ?? demoAccount.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MtColors.text,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  s != null
                      ? '${s.accountNumber} - ${ApiConfig.serverNameFor(s.accountType)}'
                      : demoAccount.loginLine,
                  style: TextStyle(fontSize: 13, color: MtColors.textSecondary),
                ),
              ],
            ),
          ),
          if (isDemo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MtColors.demo,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'Demo',
                style: TextStyle(
                  color: MtColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
