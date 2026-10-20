import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mt_colors.dart';

/// false = white theme, true = black theme.
final ValueNotifier<bool> mtDarkMode = ValueNotifier<bool>(false);

void setMtDarkMode(bool dark) {
  MtColors.applyDark(dark);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: dark ? const Color(0xFF121212) : Colors.white,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: dark ? const Color(0xFF121212) : Colors.white,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    ),
  );
  mtDarkMode.value = dark;
}
