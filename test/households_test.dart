import 'package:chorely/app/theme.dart';
import 'package:chorely/features/households/presentation/households_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_households.dart';

void main() {
  testWidgets(
    'Creation validates input, retries the same command, and confirms only server success',
    (tester) async {
      final repository = TestHouseholds()..fail = true;
      String? created;
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: CreateHouseholdScreen(
            repository: repository,
            onBack: () {},
            onCreated: (id) => created = id,
          ),
        ),
      );
      await tester.ensureVisible(find.text('Create household'));
      await tester.tap(find.text('Create household'));
      await tester.pumpAndSettle();
      expect(repository.attempts, isEmpty);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Our fictional home',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Alex');
      await tester.ensureVisible(find.text('Create household'));
      await tester.tap(find.text('Create household'));
      await tester.pumpAndSettle();
      expect(created, isNull);
      expect(find.textContaining('Connection interrupted'), findsOneWidget);
      repository.fail = false;
      await tester.ensureVisible(find.text('Create household'));
      await tester.tap(find.text('Create household'));
      await tester.pumpAndSettle();
      expect(created, 'fictional-home');
      expect(repository.attempts.length, 2);
      expect(repository.attempts.toSet().length, 1);
    },
  );

  testWidgets('Household setup supports 320dp with 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: chorelyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: CreateHouseholdScreen(
          repository: TestHouseholds(),
          onBack: () {},
          onCreated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create household'));
    await tester.tap(find.text('Create household'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Give your household a name.'), findsOneWidget);
  });
}
