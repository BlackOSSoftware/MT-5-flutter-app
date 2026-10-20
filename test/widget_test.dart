import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mt5_app/app/mt_app.dart';

void main() {
  testWidgets('quotes, history menus, and drawer match the shell', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MtApp());
    await tester.pump();

    expect(find.text('EURUSD'), findsOneWidget);
    expect(find.text('Quotes'), findsWidgets);
    expect(find.text('-537 -0.48%'), findsOneWidget);

    await tester.tap(find.text('History').hitTestable());
    await tester.pump();

    expect(find.text('POSITIONS'), findsOneWidget);
    expect(find.text('100 000.00'), findsWidgets);
    expect(find.text('Deposit'), findsOneWidget);

    await tester.tap(find.byTooltip('Period').hitTestable());
    await tester.pump();
    expect(find.text('Last 3 months'), findsOneWidget);
    expect(find.text('Custom period'), findsOneWidget);
    expect(find.text('07/10/26'), findsOneWidget);

    await tester.tap(find.text('Last week'));
    await tester.pump();
    expect(find.text('Last week'), findsNothing);

    await tester.tap(find.text('ORDERS'));
    await tester.pump();
    expect(find.text('Empty history'), findsOneWidget);

    await tester.tap(find.text('POSITIONS'));
    await tester.pump();
    await tester.tap(find.byTooltip('Sort').hitTestable());
    await tester.pump();
    expect(find.text('Open time'), findsOneWidget);
    expect(find.text('Close time'), findsOneWidget);
    await tester.tap(find.text('Open time'));
    await tester.pump();

    await tester.tap(find.byTooltip('Menu').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Manage accounts'), findsOneWidget);
    expect(find.text('Hh Hh'), findsOneWidget);
    expect(find.text('MQL5 Algo Trading'), findsOneWidget);
    expect(find.text('8').hitTestable(), findsOneWidget);
  });
}
