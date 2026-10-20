import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/mt_colors.dart';
import 'accounts_page.dart';
import 'mq_widgets.dart';

/// "NEW ACCOUNT SUCCESSFULLY CREATED" screen shown right after a
/// MetaQuotes demo account is registered (MT5 layout): summary of
/// the entered data, then Login / Password / Investor credentials,
/// a desktop-version promo box and a DONE button.
class AccountCreatedPage extends StatelessWidget {
  const AccountCreatedPage({
    super.key,
    required this.firstName,
    required this.secondName,
    required this.accountType,
    required this.deposit,
    required this.loginId,
    required this.password,
    required this.investorPassword,
  });

  final String firstName;
  final String secondName;
  final String accountType;
  final int deposit;
  final String loginId;
  final String password;
  final String investorPassword;

  void _copyDetails(BuildContext context) {
    Clipboard.setData(
      ClipboardData(
        text:
            'MetaQuotes-Demo account\n'
            'Login: $loginId\n'
            'Password: $password\n'
            'Investor: $investorPassword\n'
            'Server: MetaQuotes-Demo',
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account details copied')));
  }

  Widget _row(String label, String value, {bool boldValue = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16, color: Color(0xFF757575)),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: boldValue ? FontWeight.w600 : FontWeight.w400,
                  color: MtColors.text,
                ),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: menu icon + title + copy-details icon.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Menu',
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    icon: Icon(Icons.menu, size: 26, color: MtColors.text),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Open a demo account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: MtColors.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copy account details',
                    onPressed: () => _copyDetails(context),
                    icon: Image.asset(
                      'assets/icons/copy_docs.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
            // Broker row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icons/mt5_logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MetaQuotes-Demo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: MtColors.text,
                        ),
                      ),
                      Text(
                        'MetaQuotes Ltd.',
                        style: TextStyle(fontSize: 14, color: MtColors.text),
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
            _row('Name', firstName),
            _row('Second name', secondName),
            _row('Account type', accountType),
            _row('Deposit', '$deposit'),
            const MqSectionHeader(
              'NEW ACCOUNT SUCCESSFULLY CREATED',
              center: true,
              fontSize: 13,
            ),
            _row('Login', loginId, boldValue: true),
            _row('Password', password),
            _row('Investor', investorPassword),
            // Desktop version promo box.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Desktop version is not available yet'),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/icons/desktop_monitor.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'DOWNLOAD THE DESKTOP VERSION WITH ENHANCED\nFEATURES',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: MtColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            MqPrimaryButton(
              label: 'DONE',
              // Account login ho chuka hai - seedha Accounts screen
              // par le jao jahan nayi account card dikhegi.
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const AccountsPage()),
                (r) => r.isFirst,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
