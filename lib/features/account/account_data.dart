/// Reference demo session shown in the history screenshots.
final DateTime demoNow = DateTime(2026, 10, 7, 10, 39, 57);

class TradingAccount {
  const TradingAccount({
    required this.name,
    required this.login,
    required this.server,
    required this.demo,
    required this.balance,
    required this.equity,
    required this.freeMargin,
    required this.mailCount,
  });

  final String name;
  final String login;
  final String server;
  final bool demo;
  final double balance;
  final double equity;
  final double freeMargin;
  final int mailCount;

  String get loginLine => '$login - $server';
}

const demoAccount = TradingAccount(
  name: 'Bss Gee',
  login: '114347705',
  server: 'MetaQuotes-Demo',
  demo: true,
  balance: 100000,
  equity: 100000,
  freeMargin: 100000,
  mailCount: 8,
);
