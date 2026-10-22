/// Ek candle (t = candle start, unix seconds UTC).
class Candle {
  Candle({
    required this.t,
    required this.o,
    required this.h,
    required this.l,
    required this.c,
    this.v = 0,
  });

  final int t;
  double o;
  double h;
  double l;
  double c;
  double v;

  bool get up => c >= o;

  DateTime get time =>
      DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true).toLocal();

  factory Candle.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => v is num ? v.toDouble() : double.parse('$v');
    return Candle(
      t: (j['t'] as num).toInt(),
      o: d(j['o']),
      h: d(j['h']),
      l: d(j['l']),
      c: d(j['c']),
      v: j['v'] is num ? (j['v'] as num).toDouble() : 0,
    );
  }
}

/// MT5 timeframes (backend /v1/chart/timeframes jaise hi).
class ChartTimeframe {
  const ChartTimeframe(this.code, this.seconds);

  final String code;
  final int seconds;

  bool get intraday => seconds < 86400;
}

abstract final class ChartTimeframes {
  static const minutes = [
    ChartTimeframe('M1', 60),
    ChartTimeframe('M2', 120),
    ChartTimeframe('M3', 180),
    ChartTimeframe('M4', 240),
    ChartTimeframe('M5', 300),
    ChartTimeframe('M6', 360),
    ChartTimeframe('M10', 600),
    ChartTimeframe('M12', 720),
    ChartTimeframe('M15', 900),
    ChartTimeframe('M20', 1200),
    ChartTimeframe('M30', 1800),
  ];

  static const hours = [
    ChartTimeframe('H1', 3600),
    ChartTimeframe('H2', 7200),
    ChartTimeframe('H3', 10800),
    ChartTimeframe('H4', 14400),
    ChartTimeframe('H6', 21600),
    ChartTimeframe('H8', 28800),
    ChartTimeframe('H12', 43200),
  ];

  static const days = [
    ChartTimeframe('D1', 86400),
    ChartTimeframe('W1', 604800),
    ChartTimeframe('MN', 2592000),
  ];

  static const all = [...minutes, ...hours, ...days];

  /// MT5 default favourites (chart menu me dikhne wale).
  static const defaultFavorites = [
    'M1',
    'M5',
    'M15',
    'M30',
    'H1',
    'H4',
    'D1',
    'W1',
    'MN',
  ];

  static ChartTimeframe of(String code) =>
      all.firstWhere((t) => t.code == code, orElse: () => all[4]);
}

/// Backend /v1/chart/candles ka jawab.
class CandlePage {
  const CandlePage({
    required this.candles,
    required this.hasMore,
    this.digits,
    this.name = '',
  });

  final List<Candle> candles;
  final bool hasMore;
  final int? digits;
  final String name;
}
