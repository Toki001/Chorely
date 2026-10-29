import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

/// Wait for real query data and lay out scroll changes before a native tap.
Future<void> ensureReady(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

/// Native network callbacks use wall time; pumping test time alone can race them.
Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (finder.evaluate().length != 1 && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (finder.evaluate().isEmpty) {
    // Test fixtures are fictional; include visible feedback to diagnose failures.
    debugPrint(
      'Native test screen: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().join(' | ')}',
    );
  }
  expect(finder, findsOneWidget);
}

Future<void> waitUntilAbsent(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (finder.evaluate().isNotEmpty) {
    debugPrint(
      'Native test screen: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().join(' | ')}',
    );
  }
  expect(finder, findsNothing);
}
