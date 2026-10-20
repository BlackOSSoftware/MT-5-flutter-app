import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';

class SimplePage extends StatelessWidget {
  const SimplePage({super.key, required this.title, this.child});

  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MtColors.white,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: child ?? const SizedBox.shrink(),
    );
  }
}
