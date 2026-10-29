import 'package:chorely/app/theme.dart';
import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/chores/domain/recurrence_repository.dart';
import 'package:chorely/features/chores/presentation/chore_panel.dart';
import 'package:chorely/features/chores/presentation/recurrence_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chores_test.dart' show home, chore, family;
import 'test_chores.dart';
import 'test_recurrence.dart';

void main() {
  testWidgets(
    'Preview is required and edits invalidate it; uncertain save keeps the same request',
    (tester) async {
      final repo = TestRecurrence()
        ..failure = const ChoreFailure('Connection interrupted. Retry.');
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: RecurrenceBuilder(
            home: home,
            base: chore(),
            repository: repo,
            family: family(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('repeat-effective')),
        '2026-11-01',
      );
      await tester.ensureVisible(find.text('Preview next 14 days'));
      await tester.tap(find.text('Preview next 14 days'));
      await tester.pumpAndSettle();
      expect(repo.previews, 1);
      expect(find.text('Your upcoming turns'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('repeat-start')),
        '2026-10-29',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Preview next 14 days'));
      await tester.tap(find.text('Preview next 14 days'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save repeat settings'));
      await tester.tap(find.text('Save repeat settings'));
      await tester.pumpAndSettle();
      expect(repo.saves.length, 1);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('repeat-start')))
            .enabled,
        isFalse,
      );
      await tester.ensureVisible(find.text('Retry repeat save'));
      await tester.tap(find.text('Retry repeat save'));
      await tester.pumpAndSettle();
      expect(repo.saves.length, 2);
      expect(repo.saves.map((s) => s.id).toSet().length, 1);
      expect(identical(repo.saves.first.rule, repo.saves.last.rule), isTrue);
    },
  );
  testWidgets(
    'Repeat builder validates at 320dp and 200% text without clipped controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TestRecurrence();
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: RecurrenceBuilder(
            home: home,
            base: chore(),
            repository: repo,
            family: family(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview next 14 days'));
      await tester.tap(find.text('Preview next 14 days'));
      await tester.pumpAndSettle();
      expect(repo.previews, 0);
      expect(tester.takeException(), isNull);
      expect(find.text('Use a valid YYYY-MM-DD date.'), findsOneWidget);
    },
  );
  testWidgets(
    'Recurring detail offers future rule settings and hides one-off edit/cancel',
    (tester) async {
      final repo = TestChores()..chores = [chore()];
      repo.recurrence.configuration = const RecurrenceConfiguration(
        version: 2,
        templateVersion: 4,
        effectiveFrom: '2026-11-01',
        paused: false,
        rule: {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: ChoreDetail(
            home: home,
            occurrenceId: 'occurrence',
            uid: 'guardian',
            repository: repo,
            family: family(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Repeat settings'), findsOneWidget);
      expect(find.text('Edit chore'), findsNothing);
      expect(find.text('Cancel chore'), findsNothing);
    },
  );
  testWidgets(
    'One-off detail retains edit/cancel and can start repeat settings',
    (tester) async {
      final repo = TestChores()..chores = [chore()];
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: ChoreDetail(
            home: home,
            occurrenceId: 'occurrence',
            uid: 'guardian',
            repository: repo,
            family: family(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit chore'), findsOneWidget);
      expect(find.text('Cancel chore'), findsOneWidget);
      expect(find.text('Repeat this chore'), findsOneWidget);
    },
  );
}
