import 'package:flutter/widgets.dart';

class ShellController extends ChangeNotifier {
  int tab = 0;
  String chartSymbol = 'EURUSD';

  void openTab(int index) {
    if (tab == index) return;
    tab = index;
    notifyListeners();
  }

  void openChart(String symbol) {
    chartSymbol = symbol;
    tab = 1;
    notifyListeners();
  }
}

class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.controller, required super.child});

  final ShellController controller;

  static ShellController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'ShellScope not found');
    return scope!.controller;
  }

  static ShellController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>()?.controller;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
