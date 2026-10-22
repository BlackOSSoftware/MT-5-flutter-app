import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import '../../core/widgets/mt_dialogs.dart';
import 'chart_models.dart';

const _blue = Color(0xFF168BE1);

/// Chart menu me kitne favourite timeframes ho sakte hain (MT5 jaisa).
const minFavoriteTimeframes = 3;
const maxFavoriteTimeframes = 9;

/// MT5 timeframe picker: Minutes / Hours / Days grid (4 per line). Tap =
/// select, long-press = chart menu favourites me add/remove (3 se 9).
Future<String?> showTimeframeDialog(
  BuildContext context, {
  required String selected,
  required Set<String> favorites,
  required ValueChanged<String> onToggleFavorite,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TimeframeDialog(
      selected: selected,
      favorites: favorites,
      onToggleFavorite: onToggleFavorite,
    ),
  );
}

class _TimeframeDialog extends StatefulWidget {
  const _TimeframeDialog({
    required this.selected,
    required this.favorites,
    required this.onToggleFavorite,
  });

  final String selected;
  final Set<String> favorites;
  final ValueChanged<String> onToggleFavorite;

  @override
  State<_TimeframeDialog> createState() => _TimeframeDialogState();
}

class _TimeframeDialogState extends State<_TimeframeDialog> {
  late final Set<String> _fav = {...widget.favorites};

  static const _perRow = 4;
  static const _gap = 16.0;

  Future<void> _toggle(String code) async {
    final isFav = _fav.contains(code);
    // Hatana: bas 3 se neeche nahi. Jodna: 9 se upar nahi.
    final blocked = isFav
        ? _fav.length - 1 < minFavoriteTimeframes
        : _fav.length + 1 > maxFavoriteTimeframes;
    if (blocked) {
      await showMtInfo(
        context,
        title: 'Favorite timeframes',
        message:
            'You can add $minFavoriteTimeframes to $maxFavoriteTimeframes '
            'timeframes to the chart menu',
      );
      return;
    }
    setState(() => isFav ? _fav.remove(code) : _fav.add(code));
    widget.onToggleFavorite(code);
  }

  /// Ek section: title + 4-4 ki lines. [center] = Days jaisa beech me.
  Widget _section(
    String title,
    List<ChartTimeframe> items,
    double chipW, {
    bool center = false,
  }) {
    final rows = <List<ChartTimeframe>>[
      for (var i = 0; i < items.length; i += _perRow)
        items.sublist(i, math.min(i + _perRow, items.length)),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 14),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MtColors.text,
            ),
          ),
        ),
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: _gap),
          Row(
            mainAxisAlignment: center
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              for (final (i, tf) in row.indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                _chip(tf.code, chipW),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(String code, double width) {
    final selected = code == widget.selected;
    final fav = _fav.contains(code);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(code),
      onLongPress: () => _toggle(code),
      child: Container(
        width: width,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _blue
              : (MtColors.isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFEDEDED)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: fav && !selected ? _blue : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          code,
          style: TextStyle(
            fontSize: 15,
            color: selected ? Colors.white : MtColors.text,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MtColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: LayoutBuilder(
        builder: (context, box) {
          // 4 chips + 3 gaps dialog ki chaudai me fit (chhote phone pe bhi).
          final inner = box.maxWidth - 40;
          final chipW = ((inner - _gap * (_perRow - 1)) / _perRow).clamp(
            48.0,
            66.0,
          );
          final gridW = chipW * _perRow + _gap * (_perRow - 1);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: SizedBox(
                    width: gridW,
                    child: Column(
                      children: [
                        _section('Minutes', ChartTimeframes.minutes, chipW),
                        _section('Hours', ChartTimeframes.hours, chipW),
                        _section(
                          'Days',
                          ChartTimeframes.days,
                          chipW,
                          center: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, color: _blue, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Long-press a timeframe to add or remove it from '
                          'the chart menu',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: MtColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
