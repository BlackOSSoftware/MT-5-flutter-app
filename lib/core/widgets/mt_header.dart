import 'package:flutter/material.dart';

import '../mt_colors.dart';

class MtHeader extends StatelessWidget {
  const MtHeader({
    super.key,
    required this.title,
    required this.onMenu,
    this.subtitle,
    this.onSubtitleTap,
    this.center,
    this.actions = const [],
    this.titleFontSize = 20,
    this.titleFontFamily,
    this.titleLetterSpacing,
    this.titleHeightScale = 1,
    this.subtitleColor,
    this.subtitleFontSize = 13,
    this.subtitleLetterSpacing,
    this.subtitleWeight = FontWeight.w400,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onMenu;
  final VoidCallback? onSubtitleTap;
  final Widget? center;
  final List<Widget> actions;
  final double titleFontSize;
  final String? titleFontFamily;
  final double? titleLetterSpacing;
  final double titleHeightScale;
  final Color? subtitleColor;
  final double subtitleFontSize;
  final double? subtitleLetterSpacing;
  final FontWeight subtitleWeight;

  @override
  Widget build(BuildContext context) {
    final twoLine = subtitle != null;
    final titleBlock = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSubtitleTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.scale(
            scaleY: titleHeightScale,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MtColors.text,
                fontFamily: titleFontFamily,
                fontSize: titleFontSize,
                letterSpacing: titleLetterSpacing,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subtitleColor ?? MtColors.textSecondary,
                fontSize: subtitleFontSize,
                letterSpacing: subtitleLetterSpacing,
                height: 1.2,
                fontWeight: subtitleWeight,
              ),
            ),
        ],
      ),
    );
    return Material(
      color: MtColors.white,
      child: SizedBox(
        height: twoLine ? 64 : 56,
        child: Row(
          children: [
            MtIconButton(
              tooltip: 'Menu',
              onPressed: onMenu,
              icon: Icon(Icons.menu, size: 23, color: MtColors.text),
            ),
            if (center == null)
              Expanded(child: titleBlock)
            else ...[
              titleBlock,
              Expanded(child: Center(child: center)),
            ],
            ...actions,
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class MtIconButton extends StatelessWidget {
  const MtIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: icon,
    );
  }
}
