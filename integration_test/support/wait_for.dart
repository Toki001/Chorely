import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

/// Native network callbacks use wall time; pumping test time alone can race them.
Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  if (finder.evaluate().isEmpty) {
    // Test fixtures are fictional; include visible feedback to diagnose failures.
    debugPrint(
      'Native test screen: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().join(' | ')}',
    );
  }
  expect(finder, findsOneWidget);
}
