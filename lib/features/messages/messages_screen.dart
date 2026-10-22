import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/widgets/mt_header.dart';

const _mql5RegisterUrl = 'https://www.mql5.com/en/auth_register';

/// MT5 jaisa: Messages tab me MQL5 account register / login ka web page.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(MtColors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onPageFinished: (_) => _syncCanGoBack(),
          onUrlChange: (_) => _syncCanGoBack(),
          onWebResourceError: (e) {
            // Sirf poore page ka error - andar ki image / script ka nahi.
            if (e.isForMainFrame == true && mounted) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_mql5RegisterUrl));
  }

  /// Messages tab ka index (Quotes, Chart, Trade, History, Messages, News).
  static const _tabIndex = 4;

  /// WebView me pichhla page hai to phone ka back usi me jata hai.
  bool _canGoBack = false;

  Future<void> _syncCanGoBack() async {
    final can = await _web.canGoBack();
    if (mounted && can != _canGoBack) setState(() => _canGoBack = can);
  }

  void _reload() {
    setState(() => _failed = false);
    _web.loadRequest(Uri.parse(_mql5RegisterUrl));
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack me baaki tabs khule hone par bhi ye mounted rehta hai -
    // back sirf tab rokna jab Messages tab saamne ho.
    final visible = ShellScope.maybeOf(context)?.tab == _tabIndex;
    return PopScope(
      canPop: !(visible && _canGoBack && !_failed),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _web.goBack();
        await _syncCanGoBack();
      },
      child: _body(),
    );
  }

  Widget _body() {
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(title: 'Messages', onMenu: widget.onMenu),
          if (_progress < 100 && !_failed)
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 2,
              color: const Color(0xFF168BE1),
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No connection',
                          style: TextStyle(
                            fontSize: 15,
                            color: MtColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _reload,
                          child: const Text(
                            'RETRY',
                            style: TextStyle(color: Color(0xFF168BE1)),
                          ),
                        ),
                      ],
                    ),
                  )
                : WebViewWidget(controller: _web),
          ),
        ],
      ),
    );
  }
}
