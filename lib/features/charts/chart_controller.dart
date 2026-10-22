import 'dart:async';

import 'package:flutter/foundation.dart';

import 'chart_models.dart';
import 'chart_repository.dart';

/// Chart data state: history load, purani history (left scroll), live
/// tick se aakhri candle update / naya candle.
class ChartController extends ChangeNotifier {
  ChartController({ChartRepository repository = const ChartRepository()})
    : _repo = repository;

  final ChartRepository _repo;

  String symbol = '';
  ChartTimeframe timeframe = ChartTimeframes.of('M5');
  List<Candle> candles = const [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  String? error;
  int? digits;
  String name = '';

  /// Purane (stale) responses ignore karne ke liye.
  int _generation = 0;
  Timer? _clock;

  static const pageSize = 300;

  Future<void> load(String sym, ChartTimeframe tf) async {
    symbol = sym.toUpperCase();
    timeframe = tf;
    final gen = ++_generation;
    loading = true;
    error = null;
    candles = const [];
    hasMore = false;
    notifyListeners();
    try {
      final page = await _repo.candles(
        symbol: symbol,
        timeframe: tf.code,
        limit: pageSize,
      );
      if (gen != _generation) return;
      candles = [...page.candles];
      hasMore = page.hasMore;
      digits = page.digits ?? digits;
      if (page.name.isNotEmpty) name = page.name;
    } catch (e) {
      if (gen != _generation) return;
      error = '$e';
    } finally {
      if (gen == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> reload() => load(symbol, timeframe);

  /// Left scroll pe purane candles aage jodo.
  Future<void> loadOlder() async {
    if (loading || loadingMore || !hasMore || candles.isEmpty) return;
    final gen = _generation;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await _repo.candles(
        symbol: symbol,
        timeframe: timeframe.code,
        limit: pageSize,
        before: candles.first.t,
      );
      if (gen != _generation) return;
      final firstT = candles.first.t;
      final older = page.candles.where((c) => c.t < firstT).toList();
      candles = [...older, ...candles];
      hasMore = page.hasMore && older.isNotEmpty;
    } catch (_) {
      // Purani history na mile to bas ruk jao; chart chalta rahe.
      if (gen == _generation) hasMore = false;
    } finally {
      if (gen == _generation) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Live bid se aakhri candle update; candle ka time poora ho gaya ho
  /// to naya candle shuru.
  bool onTick(double price, DateTime time) {
    if (candles.isEmpty || price <= 0) return false;
    final last = candles.last;
    final sec = timeframe.seconds;
    final now = time.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (timeframe.intraday && now >= last.t + sec) {
      final start = now ~/ sec * sec;
      candles = [
        ...candles,
        Candle(t: start, o: price, h: price, l: price, c: price),
      ];
      return true;
    }
    if (price == last.c) return false;
    last.c = price;
    if (price > last.h) last.h = price;
    if (price < last.l) last.l = price;
    return true;
  }

  /// Chalu candle band hone me kitne second (MT5 ka countdown).
  int get secondsLeft {
    if (candles.isEmpty) return 0;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final left = candles.last.t + timeframe.seconds - now;
    return left < 0 ? 0 : left;
  }

  /// Countdown ke liye har second repaint (sirf chart dikh raha ho tab).
  void setVisible(bool visible) {
    if (visible) {
      _clock ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    } else {
      _clock?.cancel();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }
}
