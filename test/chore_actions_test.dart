import 'package:chorely/app/theme.dart';
import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/chores/presentation/chore_actions.dart';
import 'package:chorely/shared/widgets/page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chores_test.dart' show chore, family;
import 'test_chores.dart';

ChoreOccurrence state({
  String status = 'scheduled',
  int version = 3,
  int revision = 0,
  List<String> assigned = const ['child'],
  List<ChoreContribution> contributions = const [],
  List<ChoreHelp> help = const [],
}) {
  final base = chore(), d = base.draft;
  return ChoreOccurrence(
    id: base.id,
    templateId: base.templateId,
    version: version,
    templateVersion: base.templateVersion,
    status: status,
    timezone: base.timezone,
    timeAdjusted: false,
    completionRevision: revision,
    contributions: contributions,
    helpRequests: help,
    draft: ChoreDraft(
      title: d.title,
      category: d.category,
      description: d.description,
      room: d.room,
      steps: d.steps,
      assignedActorIds: assigned,
      completionPolicy: d.completionPolicy,
      reviewMode: d.reviewMode,
      schedule: d.schedule,
    ),
  );
}

ChoreContribution contribution(String id) => ChoreContribution(
  actorId: id,
  acceptedAt: DateTime.utc(2026, 10, 29),
  completionRevision: 1,
);
Widget screen(
  TestChores repo,
  ChoreOccurrence occurrence, {
  bool supervised = true,
  VoidCallback? onReload,
  Size? unused,
}) => MaterialApp(
  theme: chorelyTheme(),
  home: Scaffold(
    body: PageFrame(
      child: ChoreActions(
        key: const ValueKey('test-actions'),
        householdId: 'home',
        uid: 'account',
        chore: occurrence,
        repository: repo,
        family: family(),
        supervised: supervised,
        onReload: onReload ?? () {},
      ),
    ),
  ),
);
void main() {
  testWidgets(
    'Uncertain completion retries the same envelope even after a newer stored version arrives',
    (tester) async {
      final repo = TestChores()
        ..actor = const ChoreActor(id: 'child', role: 'child', canManage: false)
        ..actionFailure = const ChoreFailure('Connection interrupted.');
      var reloads = 0;
      await tester.pumpWidget(screen(repo, state(), onReload: () => reloads++));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mark done'));
      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();
      expect(find.text('Assigned'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      await tester.pumpWidget(
        screen(repo, state(version: 4), onReload: () => reloads++),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry action'));
      await tester.tap(find.text('Retry action'));
      await tester.pumpAndSettle();
      expect(repo.actions.length, 2);
      expect(repo.actions.map((a) => a.id).toSet().length, 1);
      expect(repo.actions.map((a) => a.version).toSet(), {3});
      await tester.ensureVisible(find.text('Reload current chore'));
      await tester.tap(find.text('Reload current chore'));
      await tester.pumpAndSettle();
      expect(reloads, 1);
      expect(find.text('Retry action'), findsNothing);
    },
  );
  testWidgets(
    'Stored child contribution shows waiting/undo without guardian controls or private activity',
    (tester) async {
      final repo = TestChores()
        ..actor = const ChoreActor(
          id: 'child',
          role: 'child',
          canManage: false,
        );
      await tester.pumpWidget(
        screen(
          repo,
          state(
            status: 'pending_review',
            version: 4,
            revision: 1,
            contributions: [contribution('child')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Waiting for review'), findsOneWidget);
      expect(find.text('1 of 1 parts recorded'), findsOneWidget);
      expect(find.text('Undo my part'), findsOneWidget);
      expect(find.text('Mark done'), findsNothing);
      expect(find.text('Approve chore'), findsNothing);
      expect(repo.activityWatches, 0);
      repo.actionFailure = const ChoreFailure(
        'Undo is no longer available.',
        retryable: false,
      );
      await tester.ensureVisible(find.text('Undo my part'));
      await tester.tap(find.text('Undo my part'));
      await tester.pumpAndSettle();
      expect(find.text('Undo is no longer available.'), findsOneWidget);
      expect(find.text('1 of 1 parts recorded'), findsOneWidget);
      expect(find.text('Retry action'), findsNothing);
    },
  );
  testWidgets(
    'A guardian contributor cannot review their own controlled task',
    (tester) async {
      final repo = TestChores()
        ..actor = const ChoreActor(
          id: 'guardian',
          role: 'guardian',
          canManage: true,
        );
      await tester.pumpWidget(
        screen(
          repo,
          state(
            status: 'pending_review',
            revision: 1,
            assigned: ['guardian'],
            contributions: [contribution('guardian')],
          ),
          supervised: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Approve chore'), findsNothing);
      expect(find.text('Ask for another look'), findsNothing);
      expect(find.text('Undo my part'), findsOneWidget);
    },
  );
  testWidgets(
    'Separate guardian redo validates feedback and sends the displayed base version',
    (tester) async {
      final repo = TestChores()
        ..actor = const ChoreActor(
          id: 'guardian',
          role: 'guardian',
          canManage: true,
        );
      await tester.pumpWidget(
        screen(
          repo,
          state(
            status: 'pending_review',
            version: 4,
            revision: 1,
            contributions: [contribution('child')],
          ),
          supervised: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ask for another look'));
      await tester.tap(find.text('Ask for another look'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send for another look'));
      await tester.pumpAndSettle();
      expect(repo.actions, isEmpty);
      expect(find.text('Add a short explanation.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('task-action-note')),
        'Please revisit step two.',
      );
      await tester.tap(find.text('Send for another look'));
      await tester.pumpAndSettle();
      expect(repo.actions.single.action, 'redo');
      expect(repo.actions.single.version, 4);
      expect(repo.actions.single.note, 'Please revisit step two.');
      expect(
        find.text('Waiting for review'),
        findsOneWidget,
      ); // No optimistic success without stored update.
    },
  );
  testWidgets(
    'Child UI fetches only its own help note and never another actor’s note',
    (tester) async {
      final repo = TestChores()
        ..actor = const ChoreActor(
          id: 'child',
          role: 'child',
          canManage: false,
        );
      repo.help['own'] = const HelpRequest(
        id: 'own',
        actorId: 'child',
        note: 'My task question',
        status: 'open',
      );
      repo.help['other'] = const HelpRequest(
        id: 'other',
        actorId: 'guardian',
        note: 'Other private question',
        status: 'open',
      );
      await tester.pumpWidget(
        screen(
          repo,
          state(
            assigned: ['child', 'guardian'],
            help: [
              const ChoreHelp(
                actorId: 'child',
                requestId: 'own',
                status: 'open',
              ),
              const ChoreHelp(
                actorId: 'guardian',
                requestId: 'other',
                status: 'open',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My task question'), findsOneWidget);
      expect(find.text('Other private question'), findsNothing);
      expect(repo.helpWatches, ['own']);
      expect(repo.activityWatches, 0);
      expect(find.text('Mark request answered'), findsNothing);
    },
  );
  testWidgets(
    'Help dialog stays usable at 320dp and 200% text and never fakes completion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TestChores()
        ..actor = const ChoreActor(id: 'child', role: 'child', canManage: false)
        ..actionFailure = const ChoreFailure('Connection interrupted.');
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: PageFrame(
              child: ChoreActions(
                householdId: 'home',
                uid: 'device',
                chore: state(),
                repository: repo,
                family: family(),
                supervised: true,
                onReload: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ask for help'));
      await tester.tap(find.text('Ask for help'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-action-note')),
        'Please show step two.',
      );
      await tester.ensureVisible(find.text('Send help request'));
      await tester.tap(find.text('Send help request'));
      await tester.pumpAndSettle();
      expect(repo.actions.single.action, 'help');
      expect(repo.actions.single.note, 'Please show step two.');
      expect(find.text('Done'), findsNothing);
      expect(find.text('Help requested'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
