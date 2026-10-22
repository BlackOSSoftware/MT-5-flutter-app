import 'package:flutter/material.dart';

import 'app_update_dialog.dart';
import 'app_update_service.dart';

/// App khulte hi (aur background se wapas aane par) server se naya APK
/// check karta hai. Force update me jab tak naya build install na ho,
/// har baar dialog wapas aata hai; optional me "Later" ke baad is session
/// me dobara nahi.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _dialogOpen = false;
  int? _skippedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || _dialogOpen || !AppUpdateService.supported) return;
    _checking = true;
    try {
      final info = await AppUpdateService.check();
      if (info == null || !mounted) return;
      if (!info.force && info.versionCode == _skippedCode) return;
      _dialogOpen = true;
      await showAppUpdateDialog(context, info);
      _dialogOpen = false;
      if (!info.force) _skippedCode = info.versionCode;
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
