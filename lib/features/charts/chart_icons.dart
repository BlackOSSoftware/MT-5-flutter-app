import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';

/// Chart toolbar ke image icons (assets/icons/chart_*.png).
/// [tint] diya to icon us rang me (gray icons), warna asli rang
/// (red-blue icons) - hamesha poore rang me.
class ChartToolIcon extends StatelessWidget {
  const ChartToolIcon(
    this.asset, {
    super.key,
    this.active = true,
    this.tint = false,
    this.size = 20,
  });

  final String asset;
  final bool active;
  final bool tint;
  final double size;

  static const crosshair = 'assets/icons/chart_crosshair.png';
  static const move = 'assets/icons/chart_move.png';
  static const indicators = 'assets/icons/chart_indicators.png';
  static const trade = 'assets/icons/chart_trade.png';
  static const oneClick = 'assets/icons/chart_one_click.png';
  static const sliders = 'assets/icons/chart_sliders.png';
  static const objects = 'assets/icons/chart_objects.png';
  static const windows = 'assets/icons/chart_windows.png';
  static const gear = 'assets/icons/settings_gear.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: tint
          ? (MtColors.isDark ? MtColors.iconDark : const Color(0xFF1F1F1F))
          : null,
    );
  }
}
