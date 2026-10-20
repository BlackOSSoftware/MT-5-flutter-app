String formatMoney(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }
  buffer
    ..write('.')
    ..write(parts[1]);
  final text = buffer.toString();
  return negative ? '-$text' : text;
}

String formatDay(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = (date.year % 100).toString().padLeft(2, '0');
  return '$day/$month/$year';
}

String formatRange(DateTime from, DateTime to) {
  final start = formatDay(from);
  final end = formatDay(to);
  if (start == end) return start;
  return '$start - $end';
}

String formatDealTime(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final second = date.second.toString().padLeft(2, '0');
  return '$year.$month.$day $hour:$minute:$second';
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
