import 'package:flutter/material.dart';

import '../../core/mt_colors.dart';
import 'chart_painter.dart';

const _blue = Color(0xFF168BE1);
const _green = Color(0xFF2E9E3F);

/// Chart order panel ka draft (price / SL / TP chart pe line kheench ke).
class OrderDraft {
  OrderDraft({
    this.type = 'MARKET',
    this.volume = 0.01,
    this.price,
    this.sl,
    this.tp,
  });

  /// MARKET | BUY_LIMIT | SELL_LIMIT | BUY_STOP | SELL_STOP
  String type;
  double volume;
  double? price;
  double? sl;
  double? tp;

  bool get pending => type != 'MARKET';
  bool get isBuy => type.startsWith('BUY');
  String get side => isBuy ? 'BUY' : 'SELL';
}

const orderTypes = <(String, String)>[
  ('MARKET', 'Market Execution'),
  ('BUY_LIMIT', 'Buy Limit'),
  ('SELL_LIMIT', 'Sell Limit'),
  ('BUY_STOP', 'Buy Stop'),
  ('SELL_STOP', 'Sell Stop'),
];

/// MT5 chart ka neeche wala order panel: symbol, SL / TP toggle, order
/// type tabs, volume. Pending price aur SL/TP chart pe drag hote hain.
class OrderPanel extends StatelessWidget {
  const OrderPanel({
    super.key,
    required this.symbol,
    required this.draft,
    required this.digits,
    required this.busy,
    required this.onType,
    required this.onVolume,
    required this.onToggleSl,
    required this.onToggleTp,
    required this.onPlacePending,
    required this.onMarket,
    required this.onSymbol,
    required this.onClose,
  });

  final String symbol;
  final OrderDraft draft;
  final int digits;
  final bool busy;
  final ValueChanged<String> onType;
  final ValueChanged<double> onVolume;
  final VoidCallback onToggleSl;
  final VoidCallback onToggleTp;
  final VoidCallback onPlacePending;
  final ValueChanged<String> onMarket;
  final void Function(BuildContext anchor) onSymbol;
  final VoidCallback onClose;

  static double _round(double v) => (v * 100).round() / 100;

  Color get _typeColor => !draft.pending
      ? _blue
      : draft.isBuy
      ? _blue
      : chartDownColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MtColors.white,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 200) onClose();
              },
              onTap: onClose,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D0D0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  Builder(
                    builder: (anchor) => InkWell(
                      onTap: () => onSymbol(anchor),
                      child: Row(
                        children: [
                          Text(
                            symbol,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _blue,
                            ),
                          ),
                          const Icon(Icons.unfold_more, color: _blue),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _circle('SL', chartDownColor, draft.sl != null, onToggleSl),
                  const SizedBox(width: 12),
                  _circle('TP', _green, draft.tp != null, onToggleTp),
                  if (draft.pending)
                    IconButton(
                      onPressed: busy ? null : onPlacePending,
                      icon: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.arrow_forward,
                              color: _blue,
                              size: 28,
                            ),
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final (code, label) in orderTypes)
                    InkWell(
                      onTap: () => onType(code),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: code == draft.type
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: code == draft.type
                                  ? _typeColor
                                  : const Color(0xFF8A8A8A),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  Text(
                    'Volume',
                    style: TextStyle(fontSize: 15, color: MtColors.icon),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: draft.volume > 0.01
                        ? () => onVolume(_round(draft.volume - 0.01))
                        : null,
                    icon: const Icon(Icons.remove, color: _blue),
                  ),
                  Text(
                    draft.volume.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MtColors.text,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onVolume(_round(draft.volume + 0.01)),
                    icon: const Icon(Icons.add, color: _blue),
                  ),
                  Text(
                    'Lots',
                    style: TextStyle(fontSize: 14, color: MtColors.icon),
                  ),
                ],
              ),
            ),
            if (draft.pending)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Drag the lines on the chart to set price'
                  '${draft.sl != null || draft.tp != null ? ', SL and TP' : ''}'
                  '${draft.price != null ? '  •  ${draft.price!.toStringAsFixed(digits)}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(child: _marketButton('SELL', chartDownColor)),
                    const SizedBox(width: 10),
                    Expanded(child: _marketButton('BUY', _blue)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _marketButton(String side, Color color) {
    return SizedBox(
      height: 42,
      child: FilledButton(
        onPressed: busy ? null : () => onMarket(side),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          '$side BY MARKET',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _circle(String label, Color color, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: on ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
