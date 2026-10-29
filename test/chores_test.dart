import 'package:chorely/app/theme.dart';
import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/chores/presentation/chore_editor.dart';
import 'package:chorely/features/chores/presentation/chore_panel.dart';
import 'package:chorely/features/family/domain/family_repository.dart';
import 'package:chorely/features/households/domain/household_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_chores.dart';
import 'test_family.dart';

const home = Household(
  id: 'home',
  name: 'Fictional home',
  timezone: 'Asia/Manila',
);
TestFamily family() => TestFamily()
  ..people = const [
    FamilyPerson(
      id: 'child',
      nickname: 'Fictional child',
      role: 'child',
      active: true,
    ),
  ];
ChoreOccurrence chore() => const ChoreOccurrence(
  id: 'occurrence',
  templateId: 'template',
  version: 3,
  templateVersion: 2,
  status: 'scheduled',
  timezone: 'Asia/Manila',
  timeAdjusted: false,
  draft: ChoreDraft(
    title: 'Cook rice',
    instructionIllustrationKey: 'assign',
    category: 'dinner',
    description: 'Household instructions',
    room: 'Kitchen',
    steps: ['Ask Alex for instructions.'],
    assignedActorIds: ['child'],
    completionPolicy: 'all_members_complete',
    reviewMode: 'guardian',
    schedule: {'kind': 'deadline', 'date': '2026-10-30', 'at': '18:00'},
  ),
);
void main() {
  testWidgets(
    'Chore form validates before saving and retries an unchanged request after uncertain failure',
    (tester) async {
      final repo = TestChores()
        ..failure = const ChoreFailure(
          'Connection interrupted. Retry this request.',
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: ChoreEditor(home: home, repository: repo, family: family()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save chore'));
      await tester.tap(find.text('Save chore'));
      await tester.pumpAndSettle();
      expect(repo.writes, isEmpty);
      expect(find.text('Give this chore a title.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('chore-title')),
        'Cook rice',
      );
      await tester.enterText(
        find.byKey(const ValueKey('chore-date')),
        '2026-10-30',
      );
      await tester.ensureVisible(find.text('Fictional child'));
      await tester.tap(find.text('Fictional child'));
      await tester.ensureVisible(find.text('Save chore'));
      await tester.tap(find.text('Save chore'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, 1);
      expect(repo.writes.single.draft!.assignedActorIds, ['child']);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('chore-title')))
            .enabled,
        isFalse,
      );
      await tester.ensureVisible(find.text('Retry save'));
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, 2);
      expect(repo.writes.map((w) => w.id).toSet().length, 1);
      expect(
        identical(repo.writes.first.draft, repo.writes.last.draft),
        isTrue,
      );
    },
  );
  testWidgets(
    'Stale edit shows conflict with exact base versions and cannot retry over newer data',
    (tester) async {
      final repo = TestChores()
        ..failure = const ChoreFailure(
          'Someone changed this chore. Reload its details.',
          conflict: true,
        );
      final base = chore();
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: ChoreEditor(
            home: home,
            repository: repo,
            family: family(),
            base: base,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save chore'));
      await tester.tap(find.text('Save chore'));
      await tester.pumpAndSettle();
      expect(repo.writes.single.base!.version, 3);
      expect(repo.writes.single.base!.templateVersion, 2);
      expect(find.textContaining('Someone changed this chore'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
  testWidgets('Chore editor remains usable at 320dp and 200% text', (
    tester,
  ) async {
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
        home: ChoreEditor(
          home: home,
          repository: TestChores(),
          family: family(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save chore'));
    await tester.tap(find.text('Save chore'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Enter a valid date: YYYY-MM-DD.'), findsOneWidget);
  });
  testWidgets(
    'Assignee detail shows stored instructions and policy without management controls',
    (tester) async {
      final repo = TestChores()
        ..canManage = false
        ..chores = [chore()];
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: ChoreDetail(
            home: home,
            occurrenceId: 'occurrence',
            uid: 'child-device',
            repository: repo,
            family: family(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cook rice'), findsOneWidget);
      expect(find.text('1. Ask Alex for instructions.'), findsOneWidget);
      expect(
        find.text('A separate guardian reviews this chore.'),
        findsOneWidget,
      );
      expect(find.text('Edit chore'), findsNothing);
      expect(find.text('Cancel chore'), findsNothing);
      expect(find.text('Assigned to: Fictional child'), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).semanticLabel,
        'Illustration of household teamwork.',
      );
    },
  );
}
