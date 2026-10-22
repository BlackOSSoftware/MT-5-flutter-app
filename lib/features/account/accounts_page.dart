import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_config.dart';
import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_bottom_nav.dart';
import '../shell/app_drawer.dart';
import '../shell/no_accounts_view.dart';
import '../../core/widgets/mt_dialogs.dart';
import 'brokers_page.dart';
import 'change_password_page.dart';
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
    _loadNotif();
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
                onMore: _showMoreMenu,
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: tradingService,
                builder: (context, _) {
                  final s = tradingService.session;
                  // Jo account sabse last chuna/login hua (sidebar wala)
                  // uska bada card upar; baaki saare saved FP + MQ
                  // accounts chhote cards me neeche - kisi aur me login
                  // karne par bhi koi card gayab nahi hota.
                  final fpActive =
                      tradingService.activeSource == 'server' &&
                      s?.source == 'server';
                  final activeMq = tradingService.mqLoggedIn
                      ? tradingService.mqAccount
                      : null;
                  final activeMqId = activeMq == null
                      ? null
                      : '${activeMq['login_id']}';
                  final fpList = tradingService.fpAccounts;
                  if (!fpActive &&
                      activeMq == null &&
                      fpList.isEmpty &&
                      _mqAccounts.isEmpty) {
                    return const NoAccountsBody();
                  }
                  return ListView(
                    children: [
                      if (fpActive && s != null)
                        _FpAccountCard(
                          onTap: _showFpActions,
                          onBell: () => _tradeNotifications(s.accountNumber),
                          bellOn: _notifOn.contains(s.accountNumber),
                        )
                      else if (activeMq != null)
                        _MqAccountCard(
                          account: activeMq,
                          onTap: () => _showMqActions(activeMq),
                          onBell: () => _tradeNotifications(activeMqId!),
                          bellOn: _notifOn.contains(activeMqId),
                        ),
                      for (final a in fpList)
                        if (!fpActive || a.accountNumber != s?.accountNumber)
                          _FpAccountCompactCard(
                            account: a,
                            connected:
                                s?.source == 'server' &&
                                s?.accountNumber == a.accountNumber,
                            onTap: () => _fpCardActions(a),
                            onLongPress: () => _fpCardActions(a),
                          ),
                      for (final a in _mqAccounts)
                        if ('${a['login_id']}' != activeMqId)
                          _MqAccountCompactCard(
                            account: a,
                            onTap: () => _mqCardActions(a),
                          ),
                      const SizedBox(height: 12),
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
    // Saved password ho to seedha server login (us MQ account ka apna
    // trading session); fail ya password na ho to login screen.
    final pass = '${a['password'] ?? ''}';
    if (pass.isNotEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Connecting to ${a['login_id']}...')),
      );
      try {
        await tradingService.loginMetaQuotesDemo(
          type: 'TRADE_ACCOUNT',
          identifier: '${a['login_id']}',
          password: pass,
        );
        messenger.hideCurrentSnackBar();
        await _loadMqAccounts();
        return;
      } catch (e) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MqAccountLoginPage(account: a)),
    );
    await _loadMqAccounts();
  }

  /// Saved FP card pe tap: wahi chalu session hai to bas use active
  /// (sidebar me upar) karo; warna saved password se seedha login,
  /// password na ho to login form (account number bhara hua).
  Future<void> _openFp(SavedFpAccount a) async {
    final s = tradingService.session;
    if (s != null &&
        s.source == 'server' &&
        s.accountNumber == a.accountNumber) {
      await tradingService.setActiveSource('server');
      return;
    }
    if (a.password.isNotEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Connecting to ${a.accountNumber}...')),
      );
      try {
        await tradingService.login(a.accountNumber, a.password);
        messenger.hideCurrentSnackBar();
        return;
      } catch (e) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => FpTradesPage(initial: a)));
  }

  /* ---------------- MT5 account actions ---------------- */

  static String _mqName(Map<String, dynamic> a) {
    final name = [
      '${a['first_name'] ?? ''}'.trim(),
      '${a['second_name'] ?? ''}'.trim(),
    ].where((e) => e.isNotEmpty).join(' ');
    return name.isEmpty ? '${a['email'] ?? a['login_id'] ?? ''}' : name;
  }

  static String _fpName(SavedFpAccount a) =>
      a.name.trim().isNotEmpty ? a.name.trim() : a.accountNumber;

  /// Chhote card pe tap: Login / Delete / Properties (MT5 sheet).
  Future<void> _mqCardActions(Map<String, dynamic> a) async {
    final id = '${a['login_id']}';
    final pick = await showMtActionSheet<String>(
      context,
      title: _mqName(a),
      options: const [
        ('Login', 'login'),
        ('Delete', 'delete'),
        ('Properties', 'props'),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case 'login':
        await _openMqLogin(a);
      case 'delete':
        await _deleteMq(id);
      case 'props':
        await showMtInfo(
          context,
          title: 'Properties',
          message:
              '$id - ${_mqName(a)}\nMetaQuotes Ltd.\n'
              '${a['currency'] ?? 'USD'} '
              '${_MqAccountCard._money((a['balance'] as num?) ?? 0)}',
        );
    }
  }

  Future<void> _fpCardActions(SavedFpAccount a) async {
    final pick = await showMtActionSheet<String>(
      context,
      title: _fpName(a),
      options: const [
        ('Login', 'login'),
        ('Delete', 'delete'),
        ('Properties', 'props'),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case 'login':
        await _openFp(a);
      case 'delete':
        await _deleteFp(a.accountNumber);
      case 'props':
        final live =
            tradingService.session?.source == 'server' &&
            tradingService.session?.accountNumber == a.accountNumber;
        await showMtInfo(
          context,
          title: 'Properties',
          message:
              '${a.accountNumber} - ${_fpName(a)}\nFP Trades\n'
              'USD ${_MqAccountCard._money(live ? tradingService.account.balance : a.balance)}',
        );
    }
  }

  Future<void> _deleteMq(String id) async {
    final ok = await showMtConfirm(
      context,
      title: 'Delete account',
      message: 'Do you really want to delete account $id?',
    );
    if (!ok) return;
    await tradingService.forgetMqAccount(id);
    await _loadMqAccounts();
  }

  Future<void> _deleteFp(String number) async {
    final ok = await showMtConfirm(
      context,
      title: 'Delete account',
      message: 'Do you really want to delete account $number?',
    );
    if (!ok) return;
    final s = tradingService.session;
    if (s?.source == 'server' && s?.accountNumber == number) {
      await tradingService.logout();
    }
    await tradingService.removeFpAccount(number);
  }

  /// Active (bada card) account: id + naam (FP ya MQ).
  (String, String)? get _activeAccount {
    final s = tradingService.session;
    if (tradingService.mqLoggedIn) {
      final mq = tradingService.mqAccount!;
      return ('${mq['login_id']}', _mqName(mq));
    }
    if (s != null && s.source == 'server') {
      return (s.accountNumber, s.name.isNotEmpty ? s.name : s.accountNumber);
    }
    return null;
  }

  /// Header ⋮ : Change password / Clear saved password / Delete account.
  Future<void> _showMoreMenu(BuildContext anchor) async {
    final active = _activeAccount;
    if (active == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to an account first')),
      );
      return;
    }
    final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox;
    final box = anchor.findRenderObject() as RenderBox;
    final topRight = box.localToGlobal(
      Offset(box.size.width, 0),
      ancestor: overlay,
    );
    final pick = await showMenu<String>(
      context: context,
      color: MtColors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      position: RelativeRect.fromLTRB(
        topRight.dx,
        topRight.dy,
        overlay.size.width - topRight.dx,
        0,
      ),
      items: [
        for (final (i, (label, value)) in const [
          ('Change password', 'change'),
          ('Clear saved password', 'clear'),
          ('Delete account', 'delete'),
        ].indexed) ...[
          if (i > 0) const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: value,
            height: 52,
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: MtColors.text),
            ),
          ),
        ],
      ],
    );
    if (!mounted || pick == null) return;
    final (id, name) = active;
    switch (pick) {
      case 'change':
        final kind = await showMtChoiceDialog<String>(context, const [
          ('Change master password', 'master'),
          ('Change investor password', 'investor'),
          ('Change trader password', 'trader'),
          ('Change money manager password', 'money_manager'),
        ]);
        if (kind == null || !mounted) return;
        if (!tradingService.isLoggedIn) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Server not reachable')));
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ChangePasswordPage(kind: kind, accountLine: '$id, $name'),
          ),
        );
      case 'clear':
        final ok = await showMtConfirm(
          context,
          title: 'Clear saved password',
          message: 'Do you really want to delete the password for account $id?',
        );
        if (!ok) return;
        await tradingService.clearSavedPassword();
        await _loadMqAccounts();
      case 'delete':
        if (tradingService.mqLoggedIn) {
          await _deleteMq(id);
        } else {
          await _deleteFp(id);
        }
    }
  }

  /// 🔔 : Trade notifications on/off (per account, phone me saved).
  Set<String> _notifOn = const {};
  static const _notifKey = 'trade_notifications_on';

  Future<void> _loadNotif() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _notifOn = (p.getStringList(_notifKey) ?? const []).toSet());
  }

  Future<void> _tradeNotifications(String id) async {
    final on = _notifOn.contains(id);
    final enable = await showMtDialog<bool>(
      context,
      title: 'Trade notifications',
      body: Text(
        'Receive notifications about trading operations performed on this '
        "account. These may include information about orders, deals, "
        "deposits and withdrawals, depending on your broker's settings.",
        style: mtDialogMessageStyle(),
      ),
      actions: [('Cancel', null), (on ? 'Disable' : 'Enable', !on)],
    );
    if (enable == null) return;
    final next = {..._notifOn};
    enable ? next.add(id) : next.remove(id);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_notifKey, next.toList());
    if (mounted) setState(() => _notifOn = next);
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
                await _openMqLogin(a);
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
  const _AccountsHeader({required this.onMenu, required this.onMore});

  final VoidCallback onMenu;
  final void Function(BuildContext anchor) onMore;

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
          Builder(
            builder: (anchor) => IconButton(
              tooltip: 'More',
              onPressed: () => onMore(anchor),
              icon: Icon(Icons.more_vert, size: 24, color: color),
            ),
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
  const _MqAccountCard({
    required this.account,
    required this.onTap,
    required this.onBell,
    required this.bellOn,
  });

  final Map<String, dynamic> account;
  final VoidCallback onTap;
  final VoidCallback onBell;
  final bool bellOn;

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
                      GestureDetector(
                        onTap: onBell,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            bellOn
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            size: 16,
                            color: bellOn
                                ? const Color(0xFF168BE1)
                                : const Color(0xFF757575),
                          ),
                        ),
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
  const _FpAccountCard({
    required this.onTap,
    required this.onBell,
    required this.bellOn,
  });

  final VoidCallback onTap;
  final VoidCallback onBell;
  final bool bellOn;

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
                      GestureDetector(
                        onTap: onBell,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            bellOn
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            size: 16,
                            color: bellOn
                                ? const Color(0xFF168BE1)
                                : const Color(0xFF757575),
                          ),
                        ),
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

/// Saved FP Trades account ki chhoti card (active nahi hai to).
/// [connected] = isi account ka server session abhi chalu hai.
class _FpAccountCompactCard extends StatelessWidget {
  const _FpAccountCompactCard({
    required this.account,
    required this.connected,
    required this.onTap,
    required this.onLongPress,
  });

  final SavedFpAccount account;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final name = account.name.trim().isNotEmpty
        ? account.name.trim()
        : account.accountNumber;
    final balance = connected
        ? tradingService.account.balance
        : account.balance;
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
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FpLogo(size: 30),
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
                        Text(
                          '${account.accountNumber} — '
                          '${ApiConfig.serverNameFor(account.accountType)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_MqAccountCard._money(balance)} USD, FP Trades',
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
                          color: account.isDemo
                              ? const Color(0xFFE3F4E5)
                              : const Color(0xFFE3EEFB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          account.isDemo ? 'Demo' : 'Real',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: account.isDemo
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF1565C0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (connected)
                        const Icon(
                          Icons.link,
                          size: 16,
                          color: Color(0xFF2E7D32),
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
