import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import 'mq_widgets.dart';

/// "Login to an account" screen (MT5 style) - Accounts screen me
/// kisi dusre (non-active) account card par tap karne par khulti
/// hai. Login + password pehle se bhare hote hain, SIGN IN dabane
/// par wahi account active (logged-in) ho jata hai.
class MqAccountLoginPage extends StatefulWidget {
  const MqAccountLoginPage({super.key, required this.account});

  final Map<String, dynamic> account;

  @override
  State<MqAccountLoginPage> createState() => _MqAccountLoginPageState();
}

class _MqAccountLoginPageState extends State<MqAccountLoginPage> {
  late final TextEditingController _loginCtrl;
  late final TextEditingController _passCtrl;
  bool _savePassword = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loginCtrl = TextEditingController(
      text: '${widget.account['login_id'] ?? ''}',
    );
    _passCtrl = TextEditingController(
      text: '${widget.account['password'] ?? ''}',
    );
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signIn() async {
    final login = _loginCtrl.text.trim();
    final pass = _passCtrl.text;
    if (login.isEmpty || pass.isEmpty) {
      _snack('Enter login and password');
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = await tradingService.loginMetaQuotesDemo(
        type: 'TRADE_ACCOUNT',
        identifier: login,
        password: pass,
      );
      // Local details (naam waghera) rakho, server profile se merge.
      await tradingService.setMqAccount({
        ...widget.account,
        ...profile,
        'email': profile['email'] ?? widget.account['email'],
        'password': pass,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final server = '${widget.account['server'] ?? 'MetaQuotes-Demo'}';
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back arrow + title.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back,
                      size: 24,
                      color: MtColors.text,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Login to an account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: MtColors.text,
                    ),
                  ),
                ],
              ),
            ),
            // Broker row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icons/mt5_logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server,
                        style: TextStyle(fontSize: 17, color: MtColors.text),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'MetaQuotes Ltd.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: MtColors.line,
              indent: 16,
              endIndent: 16,
            ),
            MqFieldRow(
              label: 'Login',
              controller: _loginCtrl,
              keyboardType: TextInputType.number,
            ),
            MqFieldRow(label: 'Password', controller: _passCtrl, obscure: true),
            // Save password (neeche divider nahi - screenshot jaisa).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Save password',
                      style: TextStyle(fontSize: 16, color: MtColors.icon),
                    ),
                  ),
                  Checkbox(
                    value: _savePassword,
                    activeColor: mqBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) =>
                        setState(() => _savePassword = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const Spacer(),
            // SIGN IN - neeche fixed bada pill button.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _signIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: mqBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SIGN IN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
