import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';
import 'support/hub.dart';

String civilDate(DateTime value) => value.toIso8601String().substring(0, 10);
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Guardian previews fourteen deterministic turns and saves a real shared recurrence',
    (tester) async {
      final tomorrow = DateTime.now().toUtc().add(
        const Duration(hours: 8, days: 1),
      );
      await app.main();
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('I already have an account'));
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'native-guardian@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'fictional-only-password-42',
      );
      await ensureReady(tester, find.widgetWithText(FilledButton, 'Sign in'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await waitFor(tester, find.text('Native fictional home'));
      await tester.tap(find.text('Native fictional home'));
      await waitFor(tester, find.text('Add a chore'));
      await ensureReady(tester, find.text('Add a chore'));
      await tester.tap(find.text('Add a chore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cook rice'));
      await tester.enterText(
        find.byKey(const ValueKey('chore-date')),
        civilDate(tomorrow),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Fictional Sam'));
      await tester.tap(find.text('Fictional Sam'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Fictional Sam'),
            )
            .value,
        isTrue,
      );
      await ensureReady(tester, find.text('Save chore'));
      await tester.tap(find.text('Save chore'));
      await waitUntilAbsent(tester, find.text('What needs doing?'));
      await openTomorrow(tester);
      await waitFor(tester, find.text('Cook rice'));
      await ensureReady(tester, find.text('Cook rice'));
      await tester.tap(find.text('Cook rice'));
      await waitFor(tester, find.text('Repeat this chore'));
      await ensureReady(tester, find.text('Repeat this chore'));
      await tester.tap(find.text('Repeat this chore'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('repeat-start')),
        civilDate(tomorrow),
      );
      await tester.enterText(
        find.byKey(const ValueKey('repeat-effective')),
        civilDate(tomorrow),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Fictional Sam'));
      await tester.tap(find.text('Fictional Sam'));
      await tester.pumpAndSettle();
      for (final name in ['Alex', 'Fictional Sam', 'Fictional Lee']) {
        await ensureReady(tester, find.text(name));
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      expect(find.text('1. Alex'), findsOneWidget);
      expect(find.text('2. Fictional Sam'), findsOneWidget);
      expect(find.text('3. Fictional Lee'), findsOneWidget);
      await ensureReady(tester, find.text('Preview next 14 days'));
      await tester.tap(find.text('Preview next 14 days'));
      await waitFor(tester, find.text('Your upcoming turns'));
      for (var i = 0; i < 14; i++) {
        final row = tester.widget<ListTile>(
          find.widgetWithText(
            ListTile,
            civilDate(tomorrow.add(Duration(days: i))),
          ),
        );
        expect(
          (row.subtitle! as Text).data,
          const ['Alex', 'Fictional Sam', 'Fictional Lee'][i % 3],
        );
      }
      await ensureReady(tester, find.text('Your upcoming turns'));
      await tester.pumpAndSettle();
      debugPrint('Chorely M08 rotation preview ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await ensureReady(tester, find.text('Save repeat settings'));
      await tester.tap(find.text('Save repeat settings'));
      await waitUntilAbsent(tester, find.text('A rhythm for your home.'));
      await waitFor(tester, find.text('Chores to share'));
      await tester.pumpAndSettle();
      final assigned = find
          .ancestor(of: find.text('Assigned'), matching: find.byType(Card))
          .first;
      await ensureReady(tester, assigned);
      await tester.tap(assigned);
      await waitFor(tester, find.text('Repeat settings'));
      expect(find.text('Edit chore'), findsNothing);
      expect(find.text('Cancel chore'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
