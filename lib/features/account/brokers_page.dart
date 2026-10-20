import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import 'fp_trades_page.dart';
import 'metaquotes_page.dart';

/// Brokers screen shown after tapping "Add Trading Account":
/// search field, MetaQuotes Ltd. row and the search hint in the middle.
class BrokersPage extends StatefulWidget {
  const BrokersPage({super.key});

  @override
  State<BrokersPage> createState() => _BrokersPageState();
}

class _BrokersPageState extends State<BrokersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final showBroker = q.isEmpty || 'metaquotes ltd.'.contains(q);
    final showFp =
        q.isEmpty || 'fp trades'.contains(q) || 'fptrades'.contains(q);
    return Scaffold(
      backgroundColor: MtColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back,
                      size: 26,
                      color: MtColors.text,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Brokers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: MtColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Scan',
                    onPressed: () {},
                    icon: Image.asset(
                      'assets/icons/qr_code.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.search, size: 28, color: MtColors.icon),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(fontSize: 18, color: MtColors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Find broker',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: MtColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: MtColors.line),
            if (showBroker) ...[
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MetaQuotesPage(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/mt5_logo.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MetaQuotes Ltd.',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: MtColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'MetaQuotes',
                              style: TextStyle(
                                fontSize: 15,
                                color: MtColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.info_outline, size: 26, color: MtColors.icon),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: MtColors.line),
            ],
            if (showFp) ...[
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const FpTradesPage()),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      const FpLogo(size: 42),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FP Trades',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: MtColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'fptrades.com',
                              style: TextStyle(
                                fontSize: 15,
                                color: MtColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.info_outline, size: 26, color: MtColors.icon),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: MtColors.line),
            ],
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.manage_search,
                        size: 120,
                        color: MtColors.line,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Use search to find a company',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          color: MtColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'This application may feature brokerage companies which\n'
                        'may not be regulated in your country. Exercise caution and\n'
                        'responsibility before opening an account with any brokerage\n'
                        'company.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: MtColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Contact details are provided for each company. Use them\n'
                        'to further research their regulatory status and services.\n'
                        'MetaQuotes may not possess complete and updated\n'
                        'information about the regulation status of brokerage\n'
                        'companies in particular countries and does not guarantee\n'
                        'their reliability or reputation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: MtColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFFF2F2F2),
              padding: EdgeInsets.only(
                top: 18,
                bottom: 18 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Text(
                "CAN'T FIND YOUR BROKER?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MtColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
