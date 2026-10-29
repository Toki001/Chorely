import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wait_for.dart';

Future<void> tapHubControl(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openHubTab(WidgetTester tester, int index) async {
  final tab = find.byKey(ValueKey('hub-tab-$index'));
  await waitFor(tester, tab);
  await tapHubControl(tester, tab);
}

Future<void> openTomorrow(WidgetTester tester) async {
  await openHubTab(tester, 2);
  await waitFor(tester, find.text('Day'));
  await tapHubControl(tester, find.text('Day'));
  await tapHubControl(tester, find.byTooltip('Next day'));
}
