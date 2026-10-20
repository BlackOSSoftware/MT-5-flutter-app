import 'package:flutter/material.dart';

import '../core/theme_controller.dart';
import '../features/shell/main_shell.dart';
import 'mt_theme.dart';

/// MT5-style scrolling: no overscroll bounce/stretch - when you pull
/// at the top or bottom with a finger the UI stays put instead of
/// moving/rubber-banding.
class MtScrollBehavior extends MaterialScrollBehavior {
  const MtScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class MtApp extends StatelessWidget {
  const MtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: mtDarkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'MT5',
          debugShowCheckedModeBanner: false,
          theme: MtTheme.light,
          darkTheme: MtTheme.dark,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          scrollBehavior: const MtScrollBehavior(),
          home: MainShell(key: ValueKey(isDark)),
        );
      },
    );
  }
}
