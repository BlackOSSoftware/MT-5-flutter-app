import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/widgets/mt_header.dart';
import '../account/brokers_page.dart';

/// Body shown while no trading account is logged in:
/// circle-plus icon, "No trading accounts to show", Add Trading Account
/// (opens the Brokers screen).
class NoAccountsBody extends StatelessWidget {
  const NoAccountsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MtColors.accent, width: 1.3),
            ),
            child: Icon(Icons.add, color: MtColors.accent, size: 23),
          ),
          const SizedBox(height: 18),
          Text(
            'No trading accounts to show',
            style: TextStyle(fontSize: 15, color: MtColors.icon),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BrokersPage()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: MtColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Add Trading Account',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full page variant (own header + [NoAccountsBody]).
class NoAccountsView extends StatelessWidget {
  const NoAccountsView({
    super.key,
    required this.onMenu,
    required this.title,
    this.subtitle,
  });

  final VoidCallback onMenu;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(title: title, subtitle: subtitle, onMenu: onMenu),
          const Expanded(child: NoAccountsBody()),
        ],
      ),
    );
  }
}
