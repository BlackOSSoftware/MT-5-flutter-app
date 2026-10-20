import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Session {
  const Session({
    required this.token,
    required this.accountId,
    required this.accountNumber,
    required this.accountType,
    required this.sessionType,
    this.name = '',
  });

  final String token;
  final String accountId;
  final String accountNumber;
  final String accountType;
  final String sessionType;

  /// Account holder ka naam (sidebar me number ki jagah dikhta hai).
  final String name;

  Map<String, dynamic> toJson() => {
    'token': token,
    'accountId': accountId,
    'accountNumber': accountNumber,
    'accountType': accountType,
    'sessionType': sessionType,
    'name': name,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    token: j['token'] as String,
    accountId: j['accountId'] as String,
    accountNumber: j['accountNumber'] as String? ?? '',
    accountType: j['accountType'] as String? ?? '',
    sessionType: j['sessionType'] as String? ?? 'TRADE',
    name: j['name'] as String? ?? '',
  );
}

int digitsFor(String symbol, double price) {
  final s = symbol.toUpperCase();
  if (s.contains('JPY') || s.contains('RUB')) return 3;
  if (s.contains('XAU') || s.contains('GOLD')) return 2;
  if (s.contains('XAG') || s.contains('SILVER')) return 3;
  return 5;
}

class LiveQuote {
  LiveQuote(this.symbol);
  final String symbol;
  double bid = 0;
  double ask = 0;
  double prevBid = 0;
  double dayOpen = 0;
  double dayHigh = 0;
  double dayLow = 0;
  double dayClose = 0;
  DateTime? time;

  int get digits => digitsFor(symbol, bid);
  bool get hasPrice => bid > 0 && ask > 0;
  bool get priceUp => bid >= prevBid;

  double get _ref => dayClose > 0 ? dayClose : dayOpen;
  int get changePoints =>
      _ref > 0 ? ((bid - _ref) * _pow10(digits)).round() : 0;
  double get changePct => _ref > 0 ? (bid - _ref) / _ref * 100 : 0;
  bool get changeUp => changePoints >= 0;
  int get spreadPoints => hasPrice ? ((ask - bid) * _pow10(digits)).round() : 0;

  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}

class LivePosition {
  const LivePosition({
    required this.positionId,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.openPrice,
    required this.currentPrice,
    required this.floatingPnL,
    required this.openTime,
    this.stopLoss,
    this.takeProfit,
    this.swap = 0,
    this.commission = 0,
  });

  final String positionId;
  final String symbol;
  final String side; // BUY / SELL
  final double volume;
  final double openPrice;
  final double currentPrice;
  final double floatingPnL;
  final DateTime? openTime;
  final double? stopLoss;
  final double? takeProfit;
  final double swap;
  final double commission;

  bool get isBuy => side == 'BUY';

  factory LivePosition.fromWs(Map<String, dynamic> j) => LivePosition(
    positionId: '${j['positionId'] ?? j['orderId'] ?? ''}',
    symbol: '${j['symbol'] ?? ''}',
    side: '${j['side'] ?? 'BUY'}',
    volume: _d(j['volume'] ?? j['qty']),
    openPrice: _d(j['openPrice']),
    currentPrice: _d(j['currentPrice'] ?? j['closePrice'] ?? j['openPrice']),
    floatingPnL: _d(j['floatingPnL'] ?? j['profitLoss'] ?? j['profit']),
    openTime: _date(j['openTime']),
    stopLoss: j['stopLoss'] == null ? null : _d(j['stopLoss']),
    takeProfit: j['takeProfit'] == null ? null : _d(j['takeProfit']),
    swap: _d(j['swap']),
    commission: _d(j['commission']),
  );
}

class PendingOrder {
  const PendingOrder({
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.orderType,
    required this.volume,
    required this.price,
    this.stopLoss,
    this.takeProfit,
  });

  final String orderId;
  final String symbol;
  final String side;
  final String orderType;
  final double volume;
  final double price;
  final double? stopLoss;
  final double? takeProfit;

  factory PendingOrder.fromWs(Map<String, dynamic> j) => PendingOrder(
    orderId: '${j['orderId'] ?? j['positionId'] ?? ''}',
    symbol: '${j['symbol'] ?? ''}',
    side: '${j['side'] ?? 'BUY'}',
    orderType: '${j['orderType'] ?? ''}',
    volume: _d(j['volume'] ?? j['qty']),
    price: _d(j['price'] ?? j['openPrice']),
    stopLoss: j['stopLoss'] == null ? null : _d(j['stopLoss']),
    takeProfit: j['takeProfit'] == null ? null : _d(j['takeProfit']),
  );
}

class LiveAccount {
  const LiveAccount({
    this.balance = 0,
    this.equity = 0,
    this.usedMargin = 0,
    this.freeMargin = 0,
  });

  final double balance;
  final double equity;
  final double usedMargin;
  final double freeMargin;

  double get marginLevel => usedMargin > 0 ? equity / usedMargin * 100 : 0;

  factory LiveAccount.fromJson(Map<String, dynamic> j) => LiveAccount(
    balance: _d(j['balance']),
    equity: _d(j['equity']),
    usedMargin: _d(j['usedMargin'] ?? j['margin']),
    freeMargin: _d(j['freeMargin']),
  );
}

class WatchSymbol {
  const WatchSymbol({
    required this.code,
    required this.name,
    this.segment = '',
    this.isAdded = false,
  });
  final String code;
  final String name;
  final String segment;
  final bool isAdded;
}

/// Ek symbol category (folder) - Add Symbol screen ke liye,
/// backend ke asal counts ke saath (added/total).
class SymbolSegment {
  const SymbolSegment({
    required this.segment,
    required this.total,
    required this.added,
  });
  final String segment;
  final int total;
  final int added;
}

double _d(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return DateTime.tryParse('$v');
}

/// Central live-trading service: REST (account-auth) + market/account WS.
class TradingService extends ChangeNotifier {
  TradingService();

  Session? session;
  bool get isLoggedIn => session != null;

  // MetaQuotes demo account (Brokers -> MetaQuotes Ltd.). When set,
  // the user counts as logged in across the app (Accounts card,
  // sidebar profile, no "Add Trading Account" placeholders), even
  // though no server trading session exists for it.
  Map<String, dynamic>? mqAccount;
  bool get mqLoggedIn => mqAccount != null;
  bool get hasAnyAccount => isLoggedIn || mqLoggedIn;

  /// Sabse last me login kiya hua account source: 'server'
  /// (FP Trades session) ya 'mq' (MetaQuotes demo). Sidebar aur
  /// Accounts screen me yahi wala account upar dikhta hai -
  /// warna purana MQ account chipka rehta tha aur FP login
  /// dikhai hi nahi deta tha.
  String activeSource = '';

  final quotes = <String, LiveQuote>{};
  final positions = <String, LivePosition>{};
  final pendings = <String, PendingOrder>{};
  LiveAccount account = const LiveAccount();
  bool accountLoaded = false;
  List<WatchSymbol> watchlist = const [];
  bool wsConnected = false;
  String? lastError;

  final _subs = <String, String>{}; // symbol -> market
  final _ticks = <String, List<(DateTime, double)>>{};
  WebSocket? _ws;
  Timer? _reconnect;
  bool _closed = false;
  // WebSocket stays OFF while logged out; it connects only on login.
  bool _wsEnabled = false;
  // Tick notifications are throttled so live bid/ask updates don't
  // rebuild the whole UI on every single tick (app slow ho jata tha).
  Timer? _tickTimer;
  DateTime? _lastTickNotify;

  // ---------------- session ----------------

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    // MetaQuotes demo login state (local) - independent of the
    // server trading session below.
    final mqRaw = prefs.getString('mq_active_account');
    if (mqRaw != null) {
      try {
        final decoded = jsonDecode(mqRaw);
        if (decoded is Map<String, dynamic>) mqAccount = decoded;
      } catch (_) {}
    }
    activeSource =
        prefs.getString('active_source') ?? (mqAccount != null ? 'mq' : '');
    final raw = prefs.getString('session');
    if (raw != null) {
      try {
        session = Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    if (session != null) {
      // Purane saved session me naam nahi hota tha - profile
      // API se bhar lo (sidebar me number ki jagah naam ke liye).
      if (session!.name.isEmpty) unawaited(_fillSessionName());
      connectWs();
      unawaited(refreshAccount());
      unawaited(refreshWatchlist());
    } else {
      // No login screen: silently sign in with the default account.
      // Ye auto-login hai - last-active source nahi badlega.
      try {
        await login(
          ApiConfig.defaultAccountNumber,
          ApiConfig.defaultPassword,
          activate: false,
        );
      } catch (e) {
        lastError = '$e';
      }
    }
    notifyListeners();
  }

  Future<void> login(
    String accountNumber,
    String password, {
    bool activate = true,
  }) async {
    final data = await _request(
      'POST',
      '/v1/account-auth/login',
      auth: false,
      body: {'account_number': accountNumber.trim(), 'password': password},
    );
    final token = data['tradeToken'] as String?;
    if (token == null) throw ApiException('Login failed: no token');
    session = Session(
      token: token,
      accountId: '${data['accountId'] ?? ''}',
      accountNumber: '${data['account_number'] ?? accountNumber}',
      accountType: '${data['account_type'] ?? ''}',
      sessionType: '${data['sessionType'] ?? 'TRADE'}',
      name: '${data['name'] ?? ''}',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session', jsonEncode(session!.toJson()));
    if (activate) {
      // FP Trades login ab sabse upar wala (active) account hai.
      activeSource = 'server';
      await prefs.setString('active_source', activeSource);
    }
    notifyListeners();
    // WebSocket connects only now that we are logged in.
    connectWs();
    _identify();
    unawaited(refreshAccount());
    unawaited(refreshWatchlist());
  }

  /// Session me account holder ka naam profile API se bharo
  /// (purane sessions jinme naam save nahi hua tha).
  Future<void> _fillSessionName() async {
    final s = session;
    if (s == null) return;
    try {
      final data = await _request('GET', '/v1/account-auth/me');
      final name = '${data['name'] ?? ''}'.trim();
      if (name.isEmpty || session == null) return;
      session = Session(
        token: s.token,
        accountId: s.accountId,
        accountNumber: s.accountNumber,
        accountType: s.accountType,
        sessionType: s.sessionType,
        name: name,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session', jsonEncode(session!.toJson()));
      notifyListeners();
    } catch (_) {
      // Naam na mile to sidebar number hi dikhayega - koi baat nahi.
    }
  }

  Future<void> logout() async {
    session = null;
    // Logged out: WebSocket band - koi live feed connection nahi.
    disconnectWs();
    positions.clear();
    pendings.clear();
    account = const LiveAccount();
    accountLoaded = false;
    watchlist = const [];
    activeSource = mqAccount != null ? 'mq' : '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session');
    await prefs.setString('active_source', activeSource);
    notifyListeners();
  }

  // ---------------- MetaQuotes demo (local) ----------------

  Future<Map<String, dynamic>> registerMetaQuotesDemo(
    Map<String, dynamic> body,
  ) =>
      _request('POST', '/v1/metaquotes/demo/register', auth: false, body: body);

  Future<Map<String, dynamic>> loginMetaQuotesDemo({
    required String type,
    required String identifier,
    required String password,
  }) async {
    final profile = await _request(
      'POST',
      '/v1/metaquotes/demo/login',
      auth: false,
      body: {'type': type, 'identifier': identifier, 'password': password},
    );
    // Successful MQ login activates the account across the app.
    await setMqAccount({
      ...profile,
      'email': profile['email'] ?? identifier,
      'password': password,
    });
    return profile;
  }

  /// Sets (or clears, with null) the active MetaQuotes account and
  /// persists it locally; listeners rebuild (sidebar, screens).
  Future<void> setMqAccount(Map<String, dynamic>? account) async {
    mqAccount = account;
    // MQ account active kiya to wahi upar wala account banega;
    // hataya to server session (agar hai) upar aa jayega.
    activeSource = account != null ? 'mq' : (session != null ? 'server' : '');
    final prefs = await SharedPreferences.getInstance();
    if (account == null) {
      await prefs.remove('mq_active_account');
    } else {
      await prefs.setString('mq_active_account', jsonEncode(account));
    }
    await prefs.setString('active_source', activeSource);
    notifyListeners();
  }

  // ---------------- REST ----------------

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.httpBase}$path',
    ).replace(queryParameters: query);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.openUrl(method, uri);
      req.headers.contentType = ContentType.json;
      if (auth && session != null) {
        req.headers.set('Authorization', 'Bearer ${session!.token}');
      }
      if (body != null) req.write(jsonEncode(body));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      if (resp.statusCode >= 400) {
        throw ApiException(
          data['message'] as String? ?? 'Request failed (${resp.statusCode})',
        );
      }
      return data;
    } on SocketException {
      throw ApiException('Server not reachable: ${ApiConfig.host}');
    } finally {
      client.close();
    }
  }

  Future<void> refreshAccount() async {
    if (!isLoggedIn) return;
    try {
      final res = await _request('GET', '/v1/trade/account');
      final data = res['data'];
      if (data is Map<String, dynamic>) {
        account = LiveAccount.fromJson(data);
        accountLoaded = true;
        notifyListeners();
      }
      final pos = await _request(
        'GET',
        '/v1/trade/positions',
        query: {'status': 'OPEN', 'limit': '100'},
      );
      final list = pos['positions'];
      if (list is List) {
        positions.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final p = LivePosition.fromWs(item);
            if (p.positionId.isNotEmpty) positions[p.positionId] = p;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      lastError = '$e';
    }
  }

  Future<void> refreshWatchlist() async {
    if (!isLoggedIn) return;
    try {
      final res = await _request('GET', '/v1/watchlist');
      final list = res['data'];
      if (list is List) {
        watchlist = [
          for (final item in list)
            if (item is Map<String, dynamic>)
              WatchSymbol(
                code: '${item['code'] ?? item['symbol'] ?? ''}',
                name: '${item['name'] ?? ''}',
                segment: '${item['segment'] ?? ''}',
              ),
        ].where((w) => w.code.isNotEmpty).toList();
        for (final w in watchlist) {
          subscribe(w.code, market: _marketFor(w));
        }
        notifyListeners();
      }
    } catch (e) {
      lastError = '$e';
    }
  }

  String _marketFor(WatchSymbol w) {
    final seg = w.segment.toUpperCase();
    if (seg.contains('STOCK') || seg.contains('EQUIT')) return 'stock';
    if (seg.isNotEmpty) return seg.toLowerCase();
    return 'crypto';
  }

  Future<Map<String, dynamic>> history(
    String kind, {
    DateTime? from,
    DateTime? to,
  }) async {
    final path = switch (kind) {
      'orders' => '/v1/trade/orders',
      'deals' => '/v1/trade/deals',
      _ => '/v1/trade/positions',
    };
    final query = <String, String>{'limit': '100', 'page': '1'};
    if (kind == 'positions') query['status'] = 'CLOSED';
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();
    return _request('GET', path, query: query);
  }

  Future<Map<String, dynamic>> summary() =>
      _request('GET', '/v1/trade/summary');

  Future<void> placeMarketOrder({
    required String symbol,
    required String side,
    required double volume,
    double? stopLoss,
    double? takeProfit,
  }) async {
    await _request(
      'POST',
      '/v1/trade/market',
      body: {
        'symbol': symbol,
        'side': side,
        'volume': volume,
        if (stopLoss != null) 'stopLoss': stopLoss,
        if (takeProfit != null) 'takeProfit': takeProfit,
      },
    );
    unawaited(refreshAccount());
  }

  Future<void> placePendingOrder({
    required String symbol,
    required String side,
    required String orderType,
    required double price,
    double? limitPrice,
    required double volume,
    double? stopLoss,
    double? takeProfit,
  }) async {
    await _request(
      'POST',
      '/v1/trade/pending',
      body: {
        'symbol': symbol,
        'side': side,
        'orderType': orderType,
        'price': price,
        if (limitPrice != null) 'limitPrice': limitPrice,
        'volume': volume,
        if (stopLoss != null) 'stopLoss': stopLoss,
        if (takeProfit != null) 'takeProfit': takeProfit,
      },
    );
  }

  Future<void> closePosition(String positionId) async {
    await _request(
      'POST',
      '/v1/trade/position/close',
      body: {'positionId': positionId},
    );
    positions.remove(positionId);
    notifyListeners();
    unawaited(refreshAccount());
  }

  Future<void> modifyPosition({
    required String positionId,
    double? stopLoss,
    double? takeProfit,
  }) async {
    await _request(
      'PATCH',
      '/v1/trade/position/modify',
      body: {
        'positionId': positionId,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
      },
    );
  }

  Future<void> cancelPending(String orderId) async {
    await _request(
      'POST',
      '/v1/trade/pending/cancel',
      body: {'orderId': orderId},
    );
    pendings.remove(orderId);
    notifyListeners();
  }

  Future<void> addWatchlist(String code, String name) async {
    await _request(
      'POST',
      '/v1/watchlist/add',
      body: {'code': code, 'name': name},
    );
    unawaited(refreshWatchlist());
  }

  /// Drag karke badli hui watchlist order backend par save karo,
  /// taaki app dobara khulne par bhi wahi position mile.
  Future<void> reorderWatchlist(List<String> codes) async {
    await _request('PUT', '/v1/watchlist/reorder', body: {'codes': codes});
    final byCode = {for (final w in watchlist) w.code: w};
    watchlist = [
      for (final c in codes)
        if (byCode[c] != null) byCode[c]!,
      for (final w in watchlist)
        if (!codes.contains(w.code)) w,
    ];
    notifyListeners();
  }

  Future<void> removeWatchlist(String code) async {
    await _request('DELETE', '/v1/watchlist/remove/$code');
    watchlist = watchlist.where((w) => w.code != code).toList();
    notifyListeners();
  }

  Future<List<WatchSymbol>> searchInstruments(String q) async {
    final res = await _request(
      'GET',
      '/v1/watchlist/search/instruments',
      query: {'q': q, 'limit': '200'},
    );
    final list = res['data'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          WatchSymbol(
            code: '${item['code'] ?? ''}',
            name: '${item['name'] ?? ''}',
            segment: '${item['segment'] ?? ''}',
          ),
    ].where((w) => w.code.isNotEmpty).toList();
  }

  /// Add Symbol screen ke folders: har segment ka total aur
  /// watchlist me added count (backend se live).
  Future<List<SymbolSegment>> symbolSegments() async {
    final res = await _request('GET', '/v1/watchlist/segments');
    final list = res['data'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          SymbolSegment(
            segment: '${item['segment'] ?? ''}',
            total: (item['total'] as num?)?.toInt() ?? 0,
            added: (item['added'] as num?)?.toInt() ?? 0,
          ),
    ].where((s) => s.segment.isNotEmpty && s.total > 0).toList();
  }

  /// Ek segment (folder) ke saare symbols, isAdded status ke saath.
  Future<List<WatchSymbol>> segmentInstruments(String segment) async {
    final res = await _request(
      'GET',
      '/v1/watchlist/segment/$segment',
      query: {'limit': '200'},
    );
    final list = res['data'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          WatchSymbol(
            code: '${item['code'] ?? ''}',
            name: '${item['name'] ?? ''}',
            segment: '${item['segment'] ?? ''}',
            isAdded: item['isAdded'] == true,
          ),
    ].where((w) => w.code.isNotEmpty).toList();
  }

  // ---------------- WebSocket ----------------

  void subscribe(String symbol, {String market = 'crypto'}) {
    final sym = symbol.toUpperCase();
    _subs[sym] = market;
    quotes.putIfAbsent(sym, () => LiveQuote(sym));
    _send({'type': 'subscribe', 'market': market, 'symbol': sym});
  }

  void connectWs() {
    _wsEnabled = true;
    if (_ws != null || _closed) return;
    unawaited(_connect());
  }

  /// Logout pe WebSocket puri tarah band (koi reconnect nahi).
  void disconnectWs() {
    _wsEnabled = false;
    _reconnect?.cancel();
    _tickTimer?.cancel();
    _tickTimer = null;
    final old = _ws;
    _ws = null;
    wsConnected = false;
    try {
      old?.close();
    } catch (_) {}
  }

  void reconnectWs() {
    if (!_wsEnabled) return;
    _reconnect?.cancel();
    final old = _ws;
    _ws = null;
    wsConnected = false;
    try {
      old?.close();
    } catch (_) {}
    unawaited(_connect());
  }

  /// Max ~6 updates/sec to the UI, no matter how fast ticks arrive.
  void _notifyTick() {
    final now = DateTime.now();
    final last = _lastTickNotify;
    if (last == null || now.difference(last).inMilliseconds >= 160) {
      _lastTickNotify = now;
      notifyListeners();
      return;
    }
    _tickTimer ??= Timer(const Duration(milliseconds: 160), () {
      _tickTimer = null;
      _lastTickNotify = DateTime.now();
      notifyListeners();
    });
  }

  Future<void> _connect() async {
    try {
      final ws = await WebSocket.connect(ApiConfig.wsUrl);
      _ws = ws;
      wsConnected = true;
      notifyListeners();
      _identify();
      for (final e in _subs.entries) {
        _send({'type': 'subscribe', 'market': e.value, 'symbol': e.key});
      }
      ws.listen(
        _onMessage,
        onDone: _onDrop,
        onError: (_) => _onDrop(),
        cancelOnError: true,
      );
    } catch (_) {
      _onDrop();
    }
  }

  void _onDrop() {
    _ws = null;
    if (wsConnected) {
      wsConnected = false;
      notifyListeners();
    }
    _reconnect?.cancel();
    if (!_closed && _wsEnabled) {
      _reconnect = Timer(
        const Duration(seconds: 3),
        () => unawaited(_connect()),
      );
    }
  }

  void _identify() {
    final s = session;
    if (s == null) return;
    _send({'type': 'join', 'route': 'account'});
    _send({'type': 'identify', 'accountId': s.accountId});
  }

  void _send(Map<String, dynamic> msg) {
    try {
      if (session != null && msg['type'] == 'subscribe') {
        msg.putIfAbsent('accountId', () => session!.accountId);
      }
      _ws?.add(jsonEncode(msg));
    } catch (_) {}
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode('$raw') as Map<String, dynamic>;
      final type = msg['type'] as String?;
      if (type == 'orderbook') {
        final data = msg['data'] as Map<String, dynamic>?;
        if (data == null) return;
        final code = '${data['code'] ?? ''}'
            .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
            .toUpperCase();
        if (code.isEmpty) return;
        final q = quotes.putIfAbsent(code, () => LiveQuote(code));
        final bid = _d(data['bids']?[0]?['price']);
        final ask = _d(data['asks']?[0]?['price']);
        if (bid <= 0 || ask <= 0) return;
        q.prevBid = q.bid == 0 ? bid : q.bid;
        q.bid = bid;
        q.ask = ask;
        final t = _date(data['tick_time']);
        q.time = t ?? DateTime.now();
        if (q.dayHigh > 0) q.dayHigh = q.dayHigh < bid ? bid : q.dayHigh;
        if (q.dayLow > 0) q.dayLow = q.dayLow > bid ? bid : q.dayLow;
        final list = _ticks.putIfAbsent(code, () => []);
        list.add((q.time!, bid));
        if (list.length > 4000) list.removeRange(0, list.length - 4000);
        _notifyTick();
        return;
      }
      if (msg['status'] == 'subscribed') {
        final sym = '${msg['symbol'] ?? ''}'.toUpperCase();
        final q = quotes.putIfAbsent(sym, () => LiveQuote(sym));
        q.dayOpen = _d(msg['dayOpen']);
        q.dayHigh = _d(msg['dayHigh']);
        q.dayLow = _d(msg['dayLow']);
        q.dayClose = _d(msg['dayClose']);
        notifyListeners();
        return;
      }
      final data = msg['data'];
      if (data is! Map<String, dynamic>) return;
      switch (type) {
        case 'live_account':
          account = LiveAccount.fromJson(data);
          accountLoaded = true;
          notifyListeners();
        case 'live_position':
          final p = LivePosition.fromWs(data);
          if (p.positionId.isNotEmpty) {
            positions[p.positionId] = p;
            notifyListeners();
          }
        case 'live_position_closed':
          positions.remove('${data['positionId'] ?? ''}');
          notifyListeners();
          unawaited(refreshAccount());
        case 'live_pending':
          final o = PendingOrder.fromWs(data);
          if (o.orderId.isNotEmpty) {
            pendings[o.orderId] = o;
            notifyListeners();
          }
        case 'live_pending_cancel':
        case 'live_pending_execute':
          pendings.remove('${data['orderId'] ?? data['positionId'] ?? ''}');
          notifyListeners();
          unawaited(refreshAccount());
      }
    } catch (_) {}
  }

  /// Build OHLC candles from collected ticks. [frameMinutes] e.g. 1,5,15,60.
  List<({DateTime t, double o, double h, double l, double c})> candlesFor(
    String symbol,
    int frameMinutes, {
    int count = 120,
  }) {
    final ticks = _ticks[symbol.toUpperCase()] ?? const [];
    if (ticks.isEmpty) return const [];
    final buckets = <int, List<double>>{};
    final order = <int>[];
    for (final (time, price) in ticks) {
      final key = time.millisecondsSinceEpoch ~/ (frameMinutes * 60000);
      if (!buckets.containsKey(key)) {
        buckets[key] = [];
        order.add(key);
      }
      buckets[key]!.add(price);
    }
    order.sort();
    final result = [
      for (final key in order)
        (
          t: DateTime.fromMillisecondsSinceEpoch(key * frameMinutes * 60000),
          o: buckets[key]!.first,
          h: buckets[key]!.reduce((a, b) => a > b ? a : b),
          l: buckets[key]!.reduce((a, b) => a < b ? a : b),
          c: buckets[key]!.last,
        ),
    ];
    return result.length > count
        ? result.sublist(result.length - count)
        : result;
  }

  @override
  void dispose() {
    _closed = true;
    _reconnect?.cancel();
    _tickTimer?.cancel();
    _ws?.close();
    super.dispose();
  }
}

/// Global app-wide instance.
final tradingService = TradingService();

void unawaited(Future<void> f) {
  f.catchError((_) {});
}
