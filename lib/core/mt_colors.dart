import 'package:flutter/material.dart';

/// App palette. The values below are the light (white) theme by default;
/// [applyDark] swaps them for the dark (black) theme.
abstract final class MtColors {
  static const accent = Color(0xFF0066FF);
  static const bid = Color(0xFF0066FF);
  static const ask = Color(0xFFC81E1E);
  static const priceUp = bid;
  static const priceDown = ask;
  static const demo = Color(0xFF43A047);
  static const badge = Color(0xFFE53935);
  static const foreground = Color(0xFFFFFFFF);

  static bool isDark = false;

  static Color text = const Color(0xFF212121);
  static Color textSecondary = const Color(0xFF9E9E9E);
  static Color icon = const Color(0xFF616161);
  static Color iconDark = const Color(0xFF424242);
  static Color line = const Color(0xFFE6E6E6);
  static Color dot = const Color(0xFFBDBDBD);
  static Color empty = const Color(0xFFDCDCDC);
  static Color emptyText = const Color(0xFFBDBDBD);
  static Color white = const Color(0xFFFFFFFF);

  static void applyDark(bool dark) {
    isDark = dark;
    if (dark) {
      text = const Color(0xFFF5F5F5);
      textSecondary = const Color(0xFF9E9E9E);
      icon = const Color(0xFFBDBDBD);
      iconDark = const Color(0xFFE0E0E0);
      line = const Color(0xFF2C2C2C);
      dot = const Color(0xFF616161);
      empty = const Color(0xFF2C2C2C);
      emptyText = const Color(0xFF757575);
      white = const Color(0xFF121212);
    } else {
      text = const Color(0xFF212121);
      textSecondary = const Color(0xFF9E9E9E);
      icon = const Color(0xFF616161);
      iconDark = const Color(0xFF424242);
      line = const Color(0xFFE6E6E6);
      dot = const Color(0xFFBDBDBD);
      empty = const Color(0xFFDCDCDC);
      emptyText = const Color(0xFFBDBDBD);
      white = const Color(0xFFFFFFFF);
    }
  }
}
