import 'dart:convert';
import 'dart:io';

import '../../core/api_config.dart';
import 'chart_models.dart';

class ChartException implements Exception {
  const ChartException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Backend chart module (GET /v1/chart/candles) se candles.
class ChartRepository {
  const ChartRepository();

  Future<CandlePage> candles({
    required String symbol,
    required String timeframe,
    int limit = 300,
    int? before,
  }) async {
    final uri = Uri.parse('${ApiConfig.httpBase}/v1/chart/candles').replace(
      queryParameters: {
        'symbol': symbol,
        'timeframe': timeframe,
        'limit': '$limit',
        if (before != null) 'before': '$before',
      },
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 40));
      final text = await resp.transform(utf8.decoder).join();
      final body = jsonDecode(text);
      if (resp.statusCode >= 400 || body is! Map<String, dynamic>) {
        throw ChartException(
          body is Map<String, dynamic> && body['message'] is String
              ? body['message'] as String
              : 'Failed to load chart (${resp.statusCode})',
        );
      }
      final data = body['data'] as Map<String, dynamic>? ?? const {};
      final list = data['candles'] as List? ?? const [];
      return CandlePage(
        candles: [
          for (final c in list)
            if (c is Map<String, dynamic>) Candle.fromJson(c),
        ],
        hasMore: data['hasMore'] == true,
        digits: (data['digits'] as num?)?.toInt(),
        name: '${data['name'] ?? ''}',
      );
    } on SocketException {
      throw ChartException('Server not reachable: ${ApiConfig.host}');
    } on FormatException {
      throw const ChartException('Invalid chart data');
    } finally {
      client.close();
    }
  }
}
