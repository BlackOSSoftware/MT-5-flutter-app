import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_header.dart';
import '../shell/no_accounts_view.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(title: 'News', onMenu: onMenu),
          Expanded(
            child: !tradingService.hasAnyAccount
                ? const NoAccountsBody()
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            MtColors.empty,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            'assets/icons/news_paper.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'No news',
                          style: TextStyle(
                            color: MtColors.emptyText,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
