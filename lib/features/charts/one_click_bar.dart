import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/mt_colors.dart';
import '../../core/widgets/mt_dialogs.dart';
import 'chart_painter.dart';

const _blue = Color(0xFF168BE1);

/// MT5 one-click trading patti: SELL (bid) | ˅ volume ˄ | BUY (ask).
/// SELL / BUY dabate hi market order chala jata hai.
class OneClickBar extends StatefulWidget {
  const OneClickBar({
    super.key,
    required this.digits,
    required this.bid,
    required this.ask,
    this.bidUp = true,
    this.askUp = true,
    required this.volume,
    required this.busy,
    required this.onVolume,
    required this.onTrade,
  });

  final int digits;
  final double? bid;
  final double? ask;

  /// Pichhle tick se upar gaya (blue) ya neeche (red) - MT5 jaisa.
  final bool bidUp;
  final bool askUp;
  final double volume;
  final bool busy;
  final ValueChanged<double> onVolume;
  final ValueChanged<String> onTrade;

  @override
  State<OneClickBar> createState() => _OneClickBarState();
}

class _OneClickBarState extends State<OneClickBar> {
  static const _minLots = 0.01;
  static const _maxLots = 100.0;

  final _volumeKey = GlobalKey();

  /// Khula menu: true = ˄ (plus), false = ˅ (minus), null = band.
  final _menu = ValueNotifier<bool?>(null);

  /// Menu khula ho tab bhi naya volume turant dikhe.
  late final _live = ValueNotifier<double>(widget.volume);

  double get volume => widget.volume;

  @override
  void didUpdateWidget(covariant OneClickBar old) {
    super.didUpdateWidget(old);
    _live.value = widget.volume;
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commitInput();
    });
  }

  @override
  void dispose() {
    _menu.dispose();
    _live.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Volume number dabane par keyboard se type.
  bool _editing = false;
  final _input = TextEditingController();
  final _focus = FocusNode();

  void _startInput() {
    _input.text = volume.toStringAsFixed(2);
    _input.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _input.text.length,
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  /// Submit ya focus hatne par: 0.01…100 ke beech hi set, warna purana
  /// volume wapas + MT5 jaisa message.
  Future<void> _commitInput() async {
    if (!_editing) return;
    setState(() => _editing = false);
    final text = _input.text.trim();
    final v = double.tryParse(text);
    if (v == null || text.isEmpty) return;
    final lots = _round(v);
    if (lots < _minLots || lots > _maxLots) {
      await showMtInfo(
        context,
        title: 'Invalid volume',
        message:
            'Volume must be from ${_fmtLots(_minLots)} to '
            '${_fmtLots(_maxLots)} lots',
      );
      return;
    }
    if (lots != volume) widget.onVolume(lots);
  }

  /// ˄ = +0.01, ˅ = -0.01 (0.01 se neeche nahi); menu khulta / us taraf
  /// badal jata hai.
  void _arrowTap(bool up) {
    if (_editing) {
      _focus.unfocus();
      return;
    }
    final next = _round(_live.value + (up ? 0.01 : -0.01));
    if (next >= _minLots && next <= _maxLots) {
      _live.value = next;
      widget.onVolume(next);
    }
    if (_menu.value == null) {
      _openVolumeMenu(up);
    } else {
      _menu.value = up;
    }
  }

  static double _round(double v) => (v * 100).round() / 100;

  /// ˄: current se upar ke 10 volume (0.01 pe 0.1 … 1 - MT5 jaisa).
  /// ˅: current se neeche jitne volume ho sakte hain (max 10).
  static List<double> _choices(double volume, bool up) {
    if (up) {
      final step = volume < 1 ? 0.1 : (volume < 10 ? 1.0 : 10.0);
      final start = (volume / step + 1e-9).floor() + 1;
      return [
        for (var i = 0; i < 10; i++) _round((start + i) * step),
      ].where((v) => v <= _maxLots).toList();
    }
    final step = volume <= 0.1
        ? 0.01
        : volume <= 1
        ? 0.1
        : (volume <= 10 ? 1.0 : 10.0);
    final below = <double>[];
    for (var k = ((volume - 1e-9) / step).floor(); k >= 1; k--) {
      final v = _round(k * step);
      if (v < _minLots) break;
      below.add(v);
      if (below.length == 10) break;
    }
    return below.reversed.toList();
  }

  Future<void> _openVolumeMenu(bool up) async {
    final box = _volumeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final top = box.localToGlobal(Offset.zero);
    final pos = top.translate(0, box.size.height + 6);
    _menu.value = up;
    final picked = await showGeneralDialog<double>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'one-click-volume',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 100),
      pageBuilder: (ctx, _, _) {
        Widget cell(String label, double? value, {Color? color}) => Expanded(
          child: InkWell(
            onTap: value == null ? null : () => Navigator.of(ctx).pop(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: value == null
                        ? const Color(0xFFBDBDBD)
                        : color ?? MtColors.text,
                  ),
                ),
              ),
            ),
          ),
        );
        Widget menu(double volume, bool up) {
          double? delta(double d) {
            final v = _round(volume + d);
            return v >= _minLots && v <= _maxLots ? v : null;
          }

          final sign = up ? '+' : '-';
          final dir = up ? 1 : -1;
          final values = _choices(volume, up);
          // 2 column, pehle left column bharta hai (0.1…0.5 | 0.6…1).
          final rows = (values.length + 1) ~/ 2;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (final d in const [0.01, 0.1, 0.5])
                    cell('$sign${_fmtLots(d)}', delta(d * dir), color: _blue),
                ],
              ),
              for (var i = 0; i < rows; i++)
                Row(
                  children: [
                    cell(_fmtLots(values[i]), values[i]),
                    if (i + rows < values.length)
                      cell(_fmtLots(values[i + rows]), values[i + rows])
                    else
                      const Spacer(),
                  ],
                ),
            ],
          );
        }

        // Dialog ka barrier patti ko dhak leta hai - ˅ / ˄ ki jagah
        // transparent tap area taaki menu khula ho tab bhi chalein.
        Widget arrowZone(bool up) => Positioned(
          left: up ? top.dx + box.size.width - _arrowWidth : top.dx,
          top: top.dy,
          width: _arrowWidth,
          height: box.size.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _arrowTap(up),
          ),
        );

        return Stack(
          children: [
            arrowZone(false),
            arrowZone(true),
            Positioned(
              left: pos.dx - _menuExtra / 2,
              top: pos.dy,
              width: box.size.width + _menuExtra,
              child: Material(
                color: MtColors.white,
                shape: const Border.fromBorderSide(
                  BorderSide(color: Color(0xFFDDDDDD)),
                ),
                child: ListenableBuilder(
                  listenable: Listenable.merge([_live, _menu]),
                  builder: (_, _) => menu(_live.value, _menu.value ?? up),
                ),
              ),
            ),
          ],
        );
      },
    );
    _menu.value = null;
    if (picked != null) widget.onVolume(picked);
  }

  static const _arrowWidth = 40.0;

  /// Volume patti se itna chauda menu (dono taraf aadha).
  static const _menuExtra = 24.0;

  Widget _arrow(bool up) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _arrowTap(up),
      child: SizedBox(
        width: _arrowWidth,
        height: double.infinity,
        child: Icon(
          up ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: MtColors.text,
        ),
      ),
    );
  }

  static String _fmtLots(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFD6D6D6))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 30,
            child: _side(
              'SELL',
              widget.bid,
              widget.bidUp ? _blue : chartDownColor,
              () => widget.onTrade('SELL'),
            ),
          ),
          Expanded(
            flex: 40,
            child: Container(
              key: _volumeKey,
              color: MtColors.white,
              child: Row(
                children: [
                  _arrow(false),
                  Expanded(
                    child: _editing
                        ? Center(
                            child: TextField(
                              controller: _input,
                              focusNode: _focus,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              // Sirf number, max 3 digit + 2 decimal.
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d{0,3}(\.\d{0,2})?'),
                                ),
                              ],
                              cursorColor: _blue,
                              cursorHeight: 16,
                              style: TextStyle(
                                fontSize: 14,
                                color: MtColors.text,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => _commitInput(),
                            ),
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _startInput,
                            child: Center(
                              child: Text(
                                volume.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: MtColors.text,
                                ),
                              ),
                            ),
                          ),
                  ),
                  _arrow(true),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 30,
            child: _side(
              'BUY',
              widget.ask,
              widget.askUp ? _blue : chartDownColor,
              () => widget.onTrade('BUY'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _side(String label, double? price, Color color, VoidCallback onTap) {
    final busy = widget.busy;
    return Material(
      color: busy ? color.withValues(alpha: 0.6) : color,
      child: InkWell(
        onTap: busy || price == null ? null : onTap,
        // Price poore dabbe ke beech me; SELL / BUY label upar-left kone me.
        child: Stack(
          children: [
            Positioned(
              left: 6,
              top: 2,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: bigPrice(price, widget.digits),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MT5 style price: shuru ka hissa chhota, aakhri 2 digit bade, aakhri
/// digit upar (superscript).
Widget bigPrice(double? value, int digits, {Color color = Colors.white}) {
  if (value == null || value <= 0) {
    return Text('--', style: TextStyle(color: color, fontSize: 18));
  }
  final s = value.toStringAsFixed(digits);
  if (s.length < 4 || digits < 2) {
    return Text(
      s,
      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w600),
    );
  }
  final head = s.substring(0, s.length - 3);
  final big = s.substring(s.length - 3, s.length - 1);
  final tail = s.substring(s.length - 1);
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: head,
          style: TextStyle(
            color: color,
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: big,
          style: TextStyle(
            color: color,
            fontSize: 20,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Text(
            tail,
            style: TextStyle(
              color: color,
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
