import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import 'demo_register_page.dart';
import 'mq_widgets.dart';

/// MetaQuotes Ltd. screen (from Brokers): open demo / real account and
/// "Login to an existing account" for MetaQuotes demo accounts.
/// These accounts trade LOCALly in the app - the server only stores
/// the registration (separate Mongo collection).
class MetaQuotesPage extends StatefulWidget {
  const MetaQuotesPage({super.key});

  @override
  State<MetaQuotesPage> createState() => _MetaQuotesPageState();
}

class _MetaQuotesPageState extends State<MetaQuotesPage> {
  String _type = 'Client ID';
  String _server = 'MetaQuotes-Demo';
  bool _savePassword = true;
  bool _busy = false;
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = _idCtrl.text.trim();
    final pass = _passCtrl.text;
    if (id.isEmpty || pass.isEmpty) {
      _snack('Enter login and password');
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = await tradingService.loginMetaQuotesDemo(
        type: _type == 'Client ID' ? 'CLIENT_ID' : 'TRADE_ACCOUNT',
        identifier: id,
        password: pass,
      );
      if (mounted) {
        // Login ke saath is MQ account ka apna trading session chalu ho
        // chuka hai (trades isi account pe jayenge).
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: MtColors.white,
            title: Text(
              'Login successful',
              style: TextStyle(fontSize: 19, color: MtColors.text),
            ),
            content: Text(
              'Account ${profile['login_id']} (${profile['email']})\n'
              'Server: ${profile['server']}\n'
              'Balance: ${profile['balance']} ${profile['currency']}',
              style: TextStyle(fontSize: 15, color: MtColors.text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: mqBlue, fontSize: 15),
                ),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _forgot() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MtColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text(
          'Forgot password?',
          style: TextStyle(fontSize: 20, color: MtColors.text),
        ),
        content: Text(
          'Unfortunately, the password cannot be recovered. Please open a new demo account.',
          style: TextStyle(fontSize: 15, color: MtColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Skip',
              style: TextStyle(color: mqBlue, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const MqPageHeader(
              title: 'MetaQuotes Ltd.',
              titleWeight: FontWeight.w400,
            ),
            _openRow(
              icon: Icons.school,
              iconBg: mqBlue,
              imageAsset: 'assets/icons/demo_cap.png',
              title: 'Open a demo account',
              subtitle: 'To learn trading and to test your strategies',
              dimmed: false,
              bottomBorder: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DemoRegisterPage(),
                ),
              ),
            ),
            _openRow(
              icon: Icons.show_chart,
              iconBg: const Color(0xFF90CAF9),
              title: 'Open a real account',
              subtitle:
                  'For live trading, additional identification is required',
              dimmed: true,
              bottomBorder: true,
              onTap: () =>
                  _snack('Opening a real account is not available yet'),
            ),
            // Header + dono rows upar FIXED; sirf login wala
            // hissa scroll hota hai (keyboard khulne par bhi
            // overflow nahi hoga).
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Login to an existing account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: MtColors.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, thickness: 1, color: MtColors.line),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (rowCtx) => MqDropdownRow(
                      label: 'Type',
                      value: _type,
                      onTap: () async {
                        final v = await showMqMenu(rowCtx, const [
                          'Trade account',
                          'Client ID',
                        ]);
                        if (v != null) setState(() => _type = v);
                      },
                    ),
                  ),
                  MqFieldRow(
                    label: _type == 'Client ID' ? 'Client ID' : 'Trade account',
                    controller: _idCtrl,
                    keyboardType: _type == 'Client ID'
                        ? TextInputType.emailAddress
                        : TextInputType.number,
                  ),
                  MqFieldRow(
                    label: 'Password',
                    controller: _passCtrl,
                    obscure: true,
                  ),
                  Builder(
                    builder: (rowCtx) => MqDropdownRow(
                      label: 'Server',
                      value: _server,
                      onTap: () async {
                        final v = await showMqMenu(rowCtx, const [
                          'MetaQuotes-Demo',
                        ]);
                        if (v != null) setState(() => _server = v);
                      },
                    ),
                  ),
                  MqCheckboxRow(
                    label: 'Save password',
                    value: _savePassword,
                    onChanged: (v) => setState(() => _savePassword = v),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: TextButton(
                      onPressed: _forgot,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: mqBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  MqPrimaryButton(label: 'LOGIN', busy: _busy, onTap: _login),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _openRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool dimmed,
    required VoidCallback onTap,
    String? imageAsset,
    bool bottomBorder = false,
  }) {
    final titleColor = dimmed ? MtColors.textSecondary : MtColors.text;
    // Real account stays light (MetaQuotes par sirf demo banta hai,
    // live trading nahi hota) - demo row dark, real row light gray.
    final subColor = dimmed ? MtColors.textSecondary : MtColors.icon;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: bottomBorder
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: MtColors.line, width: 1),
                ),
              )
            : null,
        child: Row(
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset,
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 17, color: titleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: subColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 24, color: subColor),
          ],
        ),
      ),
    );
  }
}
