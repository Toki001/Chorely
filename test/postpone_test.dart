import 'dart:async';

import 'package:chorely/app/theme.dart';
import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/scheduling/domain/postponement_repository.dart';
import 'package:chorely/features/scheduling/presentation/postpone_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chores_test.dart' show chore;
import 'chore_actions_test.dart' show screen, state, contribution;
import 'test_chores.dart';

class PostponableChores extends TestChores implements PostponementRepository {
  final requests = <PostponementRequest>[];
  ChoreFailure? postponeFailure;
  Completer<void>? reply;
  bool refreshFails = false;
  int refreshes = 0;
  @override
  Future<void> postpone(PostponementRequest request) async {
    requests.add(request);
    if (postponeFailure != null) throw postponeFailure!;
    await reply?.future;
  }

  @override
  Future<void> refresh(String hid, String oid) async {
    refreshes++;
    if (refreshFails) throw const ChoreFailure('Offline');
  }
}

Future<void> open(
  WidgetTester tester,
  PostponableChores repo, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: chorelyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PostponeScreen(
                  householdId: 'home',
                  base: chore(),
                  repository: repo,
                ),
              ),
            ),
            child: const Text('Open postpone'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open postpone'));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  testWidgets(
    'A deadline is confirmed only after the repository acknowledges it',
    (tester) async {
      final repo = PostponableChores()..reply = Completer<void>();
      await open(tester, repo);
      await tap(tester, 'Confirm later deadline');
      expect(repo.requests.length, 1);
      expect(find.text('Confirming deadline…'), findsOneWidget);
      expect(find.text('Postpone this occurrence'), findsOneWidget);
      repo.reply!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open postpone'), findsOneWidget);
      expect(find.text('Postpone this occurrence'), findsNothing);
    },
  );
  testWidgets(
    'Invalid calendar/time never sends; uncertain retry freezes the original envelope',
    (tester) async {
      final repo = PostponableChores()
        ..postponeFailure = const ChoreFailure('Connection interrupted');
      await open(tester, repo);
      await tester.enterText(
        find.byKey(const ValueKey('postpone-date')),
        '2026-02-30',
      );
      await tester.enterText(
        find.byKey(const ValueKey('postpone-time')),
        '25:00',
      );
      await tap(tester, 'Confirm later deadline');
      await tester.pumpAndSettle();
      expect(repo.requests, isEmpty);
      expect(find.text('Enter a valid calendar date.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('postpone-date')),
        '2026-10-31',
      );
      await tester.enterText(
        find.byKey(const ValueKey('postpone-time')),
        '19:30',
      );
      await tap(tester, 'Confirm later deadline');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('postpone-date')))
            .enabled,
        false,
      );
      expect(repo.requests.single.baseVersion, chore().version);
      repo.postponeFailure = null;
      await tap(tester, 'Retry same request');
      await tester.pumpAndSettle();
      expect(repo.requests.length, 2);
      expect(repo.requests[0].toMap(), repo.requests[1].toMap());
    },
  );
  testWidgets(
    'Conflict stops replay and cannot reset the form without a current server read',
    (tester) async {
      final repo = PostponableChores()
        ..postponeFailure = const ChoreFailure(
          'Changed on another device',
          conflict: true,
        )
        ..refreshFails = true;
      await open(tester, repo);
      await tap(tester, 'Confirm later deadline');
      await tester.pumpAndSettle();
      expect(find.text('Retry same request'), findsNothing);
      expect(repo.requests.length, 1);
      await tap(tester, 'Reload current chore');
      await tester.pumpAndSettle();
      expect(find.text('Postpone this occurrence'), findsOneWidget);
      expect(repo.refreshes, 1);
      repo.refreshFails = false;
      await tap(tester, 'Reload current chore');
      await tester.pumpAndSettle();
      expect(find.text('Open postpone'), findsOneWidget);
      expect(repo.requests.length, 1);
    },
  );
  testWidgets('The form stays navigable at 320dp with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = PostponableChores();
    await open(tester, repo, scale: 2);
    await tap(tester, 'Confirm later deadline');
    await tester.pumpAndSettle();
    expect(repo.requests.length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Only guardian UI exposes postponement; recorded contributions disable eligibility',
    (tester) async {
      final repo = PostponableChores();
      await tester.pumpWidget(screen(repo, state(), supervised: false));
      await tester.pumpAndSettle();
      expect(find.text('Postpone this occurrence'), findsOneWidget);
      for (final role in ['adult', 'child']) {
        await tester.pumpWidget(const SizedBox());
        repo.actor = ChoreActor(id: role, role: role, canManage: true);
        await tester.pumpWidget(
          screen(repo, state(), supervised: role == 'child'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Postpone this occurrence'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
      repo.actor = null;
      await tester.pumpWidget(
        screen(
          repo,
          state(contributions: [contribution('child')]),
          supervised: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Postpone this occurrence'), findsNothing);
    },
  );
}
