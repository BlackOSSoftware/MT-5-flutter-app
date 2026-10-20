import 'package:shared_preferences/shared_preferences.dart';

/// Backend server address (host:port of the trading-backend).
/// Default is this PC's LAN IP so the physical phone on the same Wi-Fi
/// can reach the backend running on port 4000. Editable in Settings.
abstract final class ApiConfig {
  static const String defaultHost = '172.30.72.20:4000';
  static const String _key = 'server_host';

  /// Default demo account used for auto-login (seeded in the backend).
  static const String defaultAccountNumber = '114347705';
  static const String defaultPassword = 'Trader@123';

  /// Broker ka server naam jo UI me dikhta hai (IP/host nahi) -
  /// jaise MetaTrader me "114347705 - FPTrades-Demo" aata hai.
  /// Demo account par -Demo, live account par -Live lagta hai.
  static String serverNameFor(String accountType) =>
      accountType.toLowerCase().contains('demo')
      ? 'FPTrades-Demo'
      : 'FPTrades-Live';

  static String host = defaultHost;

  static String get httpBase => 'http://$host/api';
  static String get wsUrl => 'ws://$host/ws/market';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    host = prefs.getString(_key) ?? defaultHost;
  }

  static Future<void> save(String value) async {
    host = value.trim().isEmpty ? defaultHost : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, host);
  }
}
