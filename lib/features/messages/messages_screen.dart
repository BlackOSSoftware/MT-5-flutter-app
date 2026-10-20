import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_header.dart';
import '../shell/no_accounts_view.dart';

class MessagesScreen extends StatelessWidget {
  MessagesScreen({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(title: 'Messages', onMenu: onMenu),
          Expanded(
            child: !tradingService.hasAnyAccount
                ? const NoAccountsBody()
                : ListView.separated(
                    itemCount: _mails.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: MtColors.line,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final mail = _mails[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    mail.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: MtColors.text,
                                      fontSize: 15,
                                      fontWeight: mail.unread
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  mail.time,
                                  style: TextStyle(
                                    color: MtColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3),
                            Text(
                              mail.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MtColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Mail {
  const _Mail({
    required this.title,
    required this.body,
    required this.time,
    this.unread = false,
  });

  final String title;
  final String body;
  final String time;
  final bool unread;
}

const _mails = <_Mail>[
  _Mail(
    title: 'Account registered',
    body: 'Demo account 5057040464 is ready.',
    time: '10:39',
    unread: true,
  ),
  _Mail(
    title: 'Deposit',
    body: 'Balance operation 100 000.00 completed.',
    time: '10:39',
    unread: true,
  ),
  _Mail(
    title: 'Market open',
    body: 'Quotes are updating for the current session.',
    time: '09:05',
  ),
  _Mail(title: 'Margin', body: 'Free margin is 100 000.00.', time: '09:05'),
  _Mail(title: 'Server', body: 'Connected to MetaQuotes-Demo.', time: '08:12'),
  _Mail(title: 'Session', body: 'Trading session started.', time: '08:00'),
  _Mail(
    title: 'Quotes list',
    body: 'Default symbols were added to Quotes.',
    time: 'Yesterday',
  ),
  _Mail(title: 'Welcome', body: 'Mailbox is ready.', time: 'Yesterday'),
];
