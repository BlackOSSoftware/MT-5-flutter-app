import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/mt_colors.dart';

const _blue = Color(0xFF168BE1);
const _gray = Color(0xFF616161);

const _months = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

/// MT5 style "Custom period" dialog: calendar (range select), year grid
/// aur Start/End date typing - teeno ek hi dialog me.
Future<DateTimeRange?> showCustomPeriodDialog(
  BuildContext context, {
  DateTimeRange? initial,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _CustomPeriodDialog(initial: initial),
  );
}

enum _Mode { calendar, year, input }

class _CustomPeriodDialog extends StatefulWidget {
  const _CustomPeriodDialog({this.initial});

  final DateTimeRange? initial;

  @override
  State<_CustomPeriodDialog> createState() => _CustomPeriodDialogState();
}

class _CustomPeriodDialogState extends State<_CustomPeriodDialog> {
  static final _firstDate = DateTime(2010);
  late final DateTime _lastDate = _day(DateTime.now());

  _Mode _mode = _Mode.calendar;
  late DateTime? _start = widget.initial?.start ?? _lastDate;
  late DateTime? _end = widget.initial?.end ?? _lastDate;
  late DateTime _month = DateTime(
    (_end ?? _lastDate).year,
    (_end ?? _lastDate).month,
  );

  late final _startCtrl = TextEditingController(text: _fmt(_start));
  late final _endCtrl = TextEditingController(text: _fmt(_end));
  String? _startError;
  String? _endError;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _fmt(DateTime? d) => d == null
      ? ''
      : '${d.month.toString().padLeft(2, '0')}/'
            '${d.day.toString().padLeft(2, '0')}/${d.year}';

  DateTime? _parse(String text) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text.trim());
    if (m == null) return null;
    final month = int.parse(m[1]!);
    final day = int.parse(m[2]!);
    final year = int.parse(m[3]!);
    final d = DateTime(year, month, day);
    if (d.month != month || d.day != day) return null;
    if (d.isBefore(_firstDate) || d.isAfter(_lastDate)) return null;
    return d;
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  /* ---------------- actions ---------------- */

  void _toggleInput() {
    setState(() {
      if (_mode == _Mode.input) {
        _readInput();
        _mode = _Mode.calendar;
      } else {
        _startCtrl.text = _fmt(_start);
        _endCtrl.text = _fmt(_end);
        _startError = null;
        _endError = null;
        _mode = _Mode.input;
      }
    });
  }

  /// Typed dates padho; galat ho to error dikhao aur false do.
  bool _readInput() {
    final s = _parse(_startCtrl.text);
    final e = _endCtrl.text.trim().isEmpty ? s : _parse(_endCtrl.text);
    _startError = s == null ? 'Invalid format.' : null;
    _endError = e == null
        ? 'Invalid format.'
        : (s != null && e.isBefore(s) ? 'Invalid range.' : null);
    if (_startError != null || _endError != null) return false;
    _start = s;
    _end = e;
    _month = DateTime(e!.year, e.month);
    return true;
  }

  void _onOk() {
    if (_mode == _Mode.input && !_readInput()) {
      setState(() {});
      return;
    }
    final s = _start;
    if (s == null) return;
    Navigator.of(context).pop(DateTimeRange(start: s, end: _end ?? s));
  }

  void _tapDay(DateTime d) {
    setState(() {
      if (_start == null || _end != null) {
        _start = d;
        _end = null;
      } else if (d.isBefore(_start!)) {
        _start = d;
      } else {
        _end = d;
      }
    });
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isBefore(DateTime(_firstDate.year, _firstDate.month))) return;
    if (next.isAfter(DateTime(_lastDate.year, _lastDate.month))) return;
    setState(() => _month = next);
  }

  /* ---------------- build ---------------- */

  @override
  Widget build(BuildContext context) {
    final bg = MtColors.isDark ? MtColors.white : const Color(0xFFFAFAFA);
    return Dialog(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 38, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _toggleInput,
                icon: Icon(
                  _mode == _Mode.input
                      ? Icons.calendar_today_outlined
                      : Icons.edit,
                  color: _blue,
                  size: 26,
                ),
              ),
            ),
            if (_mode == _Mode.input) _inputBody() else _calendarBody(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _button('CANCEL', () => Navigator.of(context).pop()),
                const SizedBox(width: 8),
                _button('OK', _onOk),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: _blue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
      ),
    ),
  );

  /* ---------------- input mode ---------------- */

  Widget _inputBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          _dateField('Start date', _startCtrl, _startError, autofocus: true),
          const SizedBox(height: 16),
          _dateField('End date', _endCtrl, _endError),
        ],
      ),
    );
  }

  Widget _dateField(
    String label,
    TextEditingController ctrl,
    String? error, {
    bool autofocus = false,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
        LengthLimitingTextInputFormatter(10),
      ],
      style: TextStyle(fontSize: 16, color: MtColors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'mm/dd/yyyy',
        errorText: error,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(color: _gray),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.focused) ? _blue : _gray,
          ),
        ),
        filled: true,
        fillColor: MtColors.isDark ? MtColors.white : const Color(0xFFF2F2F2),
        enabledBorder: border(const Color(0xFFE0E0E0)),
        focusedBorder: border(_blue, 2),
        errorBorder: border(MtColors.ask),
        focusedErrorBorder: border(MtColors.ask, 2),
      ),
      onChanged: (_) {
        if (_startError != null || _endError != null) {
          setState(() {
            _startError = null;
            _endError = null;
          });
        }
      },
    );
  }

  /* ---------------- calendar / year mode ---------------- */

  Widget _calendarBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(
                  () =>
                      _mode = _mode == _Mode.year ? _Mode.calendar : _Mode.year,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_months[_month.month - 1]} ${_month.year}',
                        style: const TextStyle(
                          fontSize: 15,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                          color: _gray,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _mode == _Mode.year
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: _gray,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_mode == _Mode.calendar) ...[
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left, color: _gray),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right, color: _gray),
                ),
              ],
            ],
          ),
        ),
        if (_mode == _Mode.year) _yearGrid() else _monthGrid(),
      ],
    );
  }

  Widget _yearGrid() {
    final years = [for (var y = _firstDate.year; y <= _lastDate.year; y++) y];
    final selectedIndex = years.indexOf(_month.year);
    final controller = ScrollController(
      initialScrollOffset: (selectedIndex ~/ 3 - 2).clamp(0, 999) * 61.0,
    );
    return SizedBox(
      height: 61.0 * 6,
      child: GridView.builder(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 61,
        ),
        itemCount: years.length,
        itemBuilder: (context, i) {
          final y = years[i];
          final selected = y == _month.year;
          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                final month =
                    y == _lastDate.year && _month.month > _lastDate.month
                    ? _lastDate.month
                    : _month.month;
                _month = DateTime(y, month);
                _mode = _Mode.calendar;
              }),
              child: Container(
                width: 72,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$y',
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? Colors.white : MtColors.text,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = first.weekday % 7; // Sunday pehle
    final cells = offset + daysInMonth;
    final rows = (cells / 7).ceil();
    const cell = 46.0;
    final start = _start;
    final end = _end;

    Widget dayCell(int index) {
      final dayNum = index - offset + 1;
      if (dayNum < 1 || dayNum > daysInMonth) {
        return const SizedBox(height: cell);
      }
      final d = DateTime(_month.year, _month.month, dayNum);
      final disabled = d.isAfter(_lastDate) || d.isBefore(_firstDate);
      final isStart = start != null && d == start;
      final isEnd = end != null && d == end;
      final selected = isStart || isEnd;
      final inRange =
          start != null &&
          end != null &&
          !d.isBefore(start) &&
          !d.isAfter(end) &&
          start != end;
      final isToday = d == _lastDate;
      // Range patti: start pe right half, end pe left half, beech me full.
      final band = !inRange
          ? null
          : isStart
          ? const BorderRadius.horizontal(left: Radius.circular(cell / 2))
          : isEnd
          ? const BorderRadius.horizontal(right: Radius.circular(cell / 2))
          : BorderRadius.zero;
      return SizedBox(
        height: cell,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (band != null)
              Positioned.fill(
                top: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.16),
                    borderRadius: band,
                  ),
                ),
              ),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: disabled ? null : () => _tapDay(d),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _blue : Colors.transparent,
                  border: isToday && !selected
                      ? Border.all(color: _blue)
                      : null,
                ),
                child: Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 14,
                    color: selected
                        ? Colors.white
                        : disabled
                        ? const Color(0xFFBDBDBD)
                        : MtColors.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Cells Expanded - dialog jitna chauda ho utne me 7 barabar hisse,
    // chhoti screen pe right overflow nahi.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(fontSize: 13, color: MtColors.text),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++) Expanded(child: dayCell(r * 7 + c)),
              ],
            ),
        ],
      ),
    );
  }
}
