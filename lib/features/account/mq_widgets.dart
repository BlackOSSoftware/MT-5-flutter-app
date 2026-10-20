import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';

/// Bright blue used by the MetaQuotes account screens (buttons, links).
const mqBlue = Color(0xFF1E8CF8);

class MqSectionHeader extends StatelessWidget {
  const MqSectionHeader(
    this.text, {
    super.key,
    this.center = false,
    this.fontSize = 11,
  });

  final String text;

  /// Center the text instead of the default left alignment.
  final bool center;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: fontSize,
          letterSpacing: 0.4,
          color: MtColors.textSecondary,
        ),
      ),
    );
  }
}

/// Label on the left, right-aligned input on the right, divider below
/// (MetaQuotes form style).
class MqFieldRow extends StatelessWidget {
  const MqFieldRow({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscure = false,
    this.readOnly = false,
    this.onTap,
    this.hint,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, color: MtColors.icon),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscure,
                  readOnly: readOnly,
                  onTap: onTap,
                  onChanged: onChanged,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 16, color: MtColors.text),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: MtColors.textSecondary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: errorText != null ? MtColors.ask : MtColors.line,
          indent: 16,
          endIndent: 16,
        ),
        if (errorText != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
              child: Text(
                errorText!,
                style: TextStyle(fontSize: 13, color: MtColors.ask),
              ),
            ),
          ),
      ],
    );
  }
}

class MqDropdownRow extends StatelessWidget {
  const MqDropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.boldValue = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool boldValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 16, color: MtColors.icon),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: boldValue ? FontWeight.w700 : FontWeight.w400,
                      color: MtColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down, size: 22, color: MtColors.icon),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: MtColors.line,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }
}

class MqCheckboxRow extends StatelessWidget {
  const MqCheckboxRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showErrorIcon = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// When true, a red warning icon appears before the label
  /// (e.g. REGISTER pressed without accepting the agreement).
  final bool showErrorIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, color: MtColors.icon),
                ),
              ),
              // Red warning icon just before the checkbox (no
              // background - outline style only).
              if (showErrorIcon) ...[
                Icon(Icons.error_outline, size: 22, color: MtColors.ask),
                const SizedBox(width: 6),
              ],
              Checkbox(
                value: value,
                activeColor: mqBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: MtColors.line,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }
}

class MqPrimaryButton extends StatelessWidget {
  const MqPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: SizedBox(
        width: double.infinity,
        height: 36,
        child: FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: mqBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Small page header: back arrow + title (optional subtitle).
class MqPageHeader extends StatelessWidget {
  const MqPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWeight = FontWeight.w600,
    this.titleFontSize = 19,
  });

  final String title;
  final String? subtitle;
  final FontWeight titleWeight;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, size: 26, color: MtColors.text),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: titleWeight,
                  color: MtColors.text,
                ),
              ),
              if (subtitle != null)
                Transform.translate(
                  offset: const Offset(0, -2),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF757575),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the MT5-style selector card: a white elevated rectangle that
/// opens under the tapped row, almost full width, with the options
/// right-aligned (Trade account / Client ID style).
Future<String?> showMqMenu(BuildContext context, List<String> values) {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return Future.value(null);
  // The card starts at the TOP of the tapped row (covering the row
  // itself, like MT5), not from the row's bottom edge. Each option is
  // as tall as the tapped row, so with two options the card reaches
  // down to the border of the input below the row.
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final itemHeight = box.size.height.clamp(46.0, 56.0);
  // Direction: short menus open DOWNWARD from the tapped row's top
  // (covering the row, like MT5). Long menus (e.g. Deposit with 9
  // values) do not fit below, so they open UPWARD - the card's bottom
  // sits on the tapped row's top and grows up (MT5 behaviour).
  // Either way the card is height-capped and scrollable, so every
  // option stays reachable.
  final screenH = overlay.size.height;
  final desiredH = itemHeight * values.length;
  final spaceBelow = screenH - topLeft.dy - 8;
  final spaceAbove = topLeft.dy - 8;
  final openUp = desiredH > spaceBelow && spaceAbove > spaceBelow;
  final cardTop = openUp
      ? (topLeft.dy - desiredH).clamp(8.0, screenH)
      : topLeft.dy;
  final cardMaxH = openUp ? spaceAbove : spaceBelow;
  // Custom overlay card (not the stock popup menu) so the geometry
  // matches MT5 exactly: almost full-width white card, right-aligned
  // options, ~48px tall rows.
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'mq-menu',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, _) {
      return Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: cardTop.toDouble(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: cardMaxH),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final v in values)
                          InkWell(
                            onTap: () => Navigator.of(ctx).pop(v),
                            child: SizedBox(
                              height: itemHeight,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Text(
                                    v,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: MtColors.text,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
