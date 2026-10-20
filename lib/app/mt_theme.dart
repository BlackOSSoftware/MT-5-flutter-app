import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mt_colors.dart';

abstract final class MtTheme {
  static ThemeData get light => _build(false);

  static ThemeData get dark => _build(true);

  static ThemeData _build(bool isDark) {
    final scheme = (isDark ? ColorScheme.dark() : ColorScheme.light()).copyWith(
      primary: MtColors.accent,
      onPrimary: MtColors.foreground,
      secondary: MtColors.accent,
      surface: MtColors.white,
      onSurface: MtColors.text,
      surfaceTint: Colors.transparent,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'Roboto Condensed',
      colorScheme: scheme,
      scaffoldBackgroundColor: MtColors.white,
      canvasColor: MtColors.white,
      splashFactory: InkRipple.splashFactory,
      dividerColor: MtColors.line,
      appBarTheme: AppBarTheme(
        backgroundColor: MtColors.white,
        foregroundColor: MtColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark ? Color(0xFF121212) : Colors.white,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: MtColors.white,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto Condensed',
          color: MtColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: MtColors.iconDark),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: MtColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(),
        elevation: 16,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MtColors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
