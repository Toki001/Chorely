import 'test_notifications.dart';

import 'dart:async';

import 'package:chorely/app/theme.dart';
import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/dashboard/domain/chore_progress.dart';
import 'package:chorely/features/dashboard/presentation/household_hub.dart';
import 'package:chorely/features/family/domain/family_repository.dart';
import 'package:chorely/features/households/domain/household_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_chores.dart';
import 'test_family.dart';

const home = Household(
  id: 'home',
  name: 'Our fictional home',
  timezone: 'Asia/Manila',
);
const childActor = ChoreActor(id: 'child', role: 'child', canManage: false);
const roster = [
  FamilyPerson(
    id: 'guardian',
    nickname: 'Alex',
    role: 'guardian',
    active: true,
  ),
  FamilyPerson(
    id: 'child',
    nickname: 'Fictional child',
    role: 'child',
    active: true,
  ),
];
ChoreOccurrence occurrence(
  String id, {
  String status = 'scheduled',
  String date = '2026-10-29',
  List<String> assigned = const ['child'],
  List<ChoreContribution> parts = const [],
  String timezone = 'Asia/Manila',
}) => ChoreOccurrence(
  id: id,
  templateId: 'template-$id',
  version: 1,
  templateVersion: 1,
  status: status,
  timezone: timezone,
  timeAdjusted: false,
  contributions: parts,
  dueAtUtc: DateTime.utc(2026, 10, 29, 3),
  draft: ChoreDraft(
    title: id,
    category: 'household',
    description: '',
    room: '',
    steps: const [],
    assignedActorIds: assigned,
    completionPolicy: 'all_members_complete',
    reviewMode: 'none',
    schedule: {'kind': 'deadline', 'date': date, 'at': '11:00'},
  ),
);

Future<void> mount(
  WidgetTester tester,
  TestChores repo, {
  bool child = false,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(
    width,
    width <= 320 ? 568 : (width < 400 ? 844 : 1024),
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: chorelyTheme(),
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: widget!,
      ),
      home: HouseholdHub(
        notifications: TestNotifications(),
        home: home,
        uid: child ? 'device' : 'guardian',
        repository: repo,
        family: TestFamily()..people = roster,
        supervisedActorId: child ? 'child' : null,
        onExit: () {},
      ),
    ),
  );
  if (repo is LiveActorChores) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class LiveActorChores extends TestChores {
  final live = StreamController<ChoreActor?>.broadcast();
  @override
  Stream<ChoreActor?> watchActor(String hid, String uid) => live.stream;
}

void main() {
  test('Progress excludes cancelled/skipped and never counts partial work or review as done', () {
    final progress = ChoreProgress([
      occurrence(
        'partial',
        parts: [
          ChoreContribution(
            actorId: 'child',
            acceptedAt: DateTime.utc(2026),
            completionRevision: 1,
          ),
        ],
      ),
      occurrence('review', status: 'pending_review'),
      occurrence('done', status: 'completed'),
      occurrence('approved', status: 'approved'),
      occurrence('cancelled', status: 'cancelled'),
      occurrence('skipped', status: 'skipped'),
    ]);
    expect(
      (progress.done, progress.total, progress.waiting, progress.fraction),
      (2, 4, 1, .5),
    );
    expect(ChoreProgress([]).fraction, 0);
  });
  for (final width in [320.0, 800.0]) {
    for (final child in [false, true]) {
      testWidgets(
        '${child ? 'Child' : 'Guardian'} essential journey at ${width}dp and 200% text',
        (tester) async {
          final repo = TestChores()
            ..actor = child ? childActor : null
            ..chores = [
              occurrence('Water the plant'),
              occurrence('Other person only', assigned: ['guardian']),
            ];
          await mount(tester, repo, child: child, width: width, scale: 2);
          expect(
            find.text(
              child
                  ? 'Hi, Fictional child.'
                  : 'A little teamwork,\na happier home.',
            ),
            findsOneWidget,
          );
          expect(
            find.text(child ? '0 of 1 finished' : '0 of 2 finished'),
            findsOneWidget,
          );
          if (child) {
            expect(find.text('Other person only'), findsNothing);
            expect(repo.ranges.every((q) => q.actor == 'child'), isTrue);
          }
          await tap(tester, find.text('Water the plant'));
          if (child) {
            await tap(tester, find.text('Mark done'));
            expect(repo.actions.single.action, 'complete');
            expect(find.text('Edit chore'), findsNothing);
          }
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tap(tester, find.byKey(const ValueKey('hub-tab-2')));
          await tap(tester, find.text('Day'));
          await tap(tester, find.text('Water the plant'));
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tap(tester, find.byKey(const ValueKey('hub-tab-3')));
          expect(find.text('Alex'), findsOneWidget);
          expect(
            find.text('Add a child profile'),
            child ? findsNothing : findsOneWidget,
          );
          await tap(tester, find.byKey(const ValueKey('hub-tab-1')));
          await tap(tester, find.byKey(const ValueKey('hub-tab-0')));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'Calendar filters stored dates and members with real empty and review states',
    (tester) async {
      final repo = TestChores()
        ..chores = [
          occurrence('Today child'),
          occurrence(
            'Tomorrow child',
            date: '2026-10-30',
            status: 'pending_review',
          ),
          occurrence(
            'Tomorrow own',
            date: '2026-10-30',
            assigned: ['guardian'],
          ),
        ];
      await mount(tester, repo);
      expect(find.text('Tomorrow child'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('hub-tab-2')));
      await tap(tester, find.byKey(const ValueKey('calendar-2026-10-30')));
      expect(find.text('Tomorrow child'), findsOneWidget);
      expect(find.text('Today child'), findsNothing);
      expect(find.textContaining('1 waiting for review'), findsOneWidget);
      await tap(tester, find.text('Review'));
      expect(find.text('Tomorrow own'), findsNothing);
      await tap(tester, find.text('All'));
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text('Just me').last);
      await tester.pumpAndSettle();
      expect(repo.ranges.last.actor, 'guardian');
      expect(find.text('Tomorrow child'), findsNothing);
      expect(find.text('Tomorrow own'), findsOneWidget);
      await tap(tester, find.text('Month'));
      await tap(tester, find.byKey(const ValueKey('calendar-2026-10-31')));
      expect(find.textContaining('Nothing scheduled here'), findsOneWidget);
      await tap(tester, find.text('Add a chore'));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('chore-date')))
            .controller!
            .text,
        '2026-10-31',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'A normal phone week fits seven accessible date targets in one row',
    (tester) async {
      await mount(tester, TestChores());
      await tap(tester, find.byKey(const ValueKey('hub-tab-2')));
      final monday = find.byKey(const ValueKey('calendar-2026-10-26'));
      final sunday = find.byKey(const ValueKey('calendar-2026-11-01'));
      expect(tester.getTopLeft(monday).dy, tester.getTopLeft(sunday).dy);
      expect(tester.getSize(monday).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(monday).height, greaterThanOrEqualTo(48));
    },
  );
  testWidgets('Clock failure shows retry without invented zero progress', (
    tester,
  ) async {
    final repo = TestChores()..clockFailure = true;
    await mount(tester, repo);
    expect(find.text('0 of 0 finished'), findsNothing);
    expect(repo.ranges, isEmpty);
    repo.clockFailure = false;
    await tap(tester, find.text('Retry household day'));
    expect(find.text('0 of 0 finished'), findsOneWidget);
  });
  testWidgets(
    'Stored occurrences keep their recorded timezone after the household zone changes',
    (tester) async {
      final repo = TestChores()
        ..chores = [occurrence('Recorded turn', timezone: 'America/New_York')];
      await mount(tester, repo);
      expect(find.text('Recorded in America/New_York'), findsOneWidget);
      expect(find.text('Household time · Asia/Manila'), findsOneWidget);
    },
  );
  testWidgets(
    'Server day changes refresh Today and preserve an explicitly selected calendar date',
    (tester) async {
      final repo = TestChores()
        ..chores = [
          occurrence('Old day'),
          occurrence('New day', date: '2026-10-30'),
        ];
      await mount(tester, repo);
      repo.clock = HouseholdClock(
        today: '2026-10-30',
        timezone: 'Asia/Manila',
        serverNow: DateTime.utc(2026, 10, 30, 4),
        nextMidnight: DateTime.utc(2026, 10, 30, 16),
        actor: childActor,
      );
      await tap(tester, find.byTooltip('Refresh household day'));
      expect(find.text('Old day'), findsNothing);
      expect(find.text('New day'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('hub-tab-2')));
      await tap(tester, find.byKey(const ValueKey('calendar-2026-10-31')));
      await tap(tester, find.text('Day'));
      expect(repo.ranges.last.from, '2026-10-31');
      repo.clockFailure = true;
      await tap(tester, find.byTooltip('Refresh household day'));
      expect(find.text('0 of 0 finished'), findsNothing);
      repo.clockFailure = false;
      repo.clock = HouseholdClock(
        today: '2026-11-01',
        timezone: 'Asia/Manila',
        serverNow: DateTime.utc(2026, 11, 1, 4),
        nextMidnight: DateTime.utc(2026, 11, 1, 16),
        actor: childActor,
      );
      await tap(tester, find.text('Retry household day'));
      expect(repo.ranges.last.from, '2026-10-31');
      await tap(tester, find.byKey(const ValueKey('hub-tab-0')));
      expect(repo.ranges.last.from, '2026-11-01');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Revocation removes loaded chore cards and guardian controls', (
    tester,
  ) async {
    final repo = LiveActorChores()..chores = [occurrence('Private chore')];
    addTearDown(repo.live.close);
    await mount(tester, repo);
    repo.live.add(
      const ChoreActor(id: 'guardian', role: 'guardian', canManage: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private chore'), findsOneWidget);
    repo.live.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Private chore'), findsNothing);
    expect(find.text('Add a chore'), findsNothing);
    expect(
      find.textContaining('Household access is unavailable'),
      findsOneWidget,
    );
    repo.live.add(
      const ChoreActor(id: 'guardian', role: 'guardian', canManage: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private chore'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
