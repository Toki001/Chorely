import 'package:chorely/app/theme.dart';
import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/notifications/domain/notifications_repository.dart';
import 'package:chorely/features/notifications/presentation/notification_settings_screen.dart';
import 'package:chorely/features/notifications/presentation/updates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:chorely/app/chorely_app.dart';
import 'package:chorely/features/auth/domain/auth_repository.dart';

import 'app_test.dart' show TestAuth;
import 'test_households.dart';

import 'chores_test.dart' show home, chore, family;
import 'test_chores.dart';
import 'test_notifications.dart';

const guardian = ChoreActor(id: 'guardian', role: 'guardian', canManage: true);
const child = ChoreActor(id: 'child', role: 'child', canManage: false);

class TestLaunches implements NotificationLaunchSource {
  NotificationLink? first;
  final events = StreamController<NotificationLink>.broadcast();
  @override
  Future<NotificationLink?> initial() async => first;
  @override
  Stream<NotificationLink> get taps => events.stream;
}

class DelayedNotifications extends TestNotifications {
  final result = Completer<NotificationDestination?>();
  @override
  Future<NotificationDestination?> open(String hid, String id) {
    opened.add(id);
    return result.future;
  }
}

Future<void> routedApp(
  WidgetTester tester,
  TestAuth auth,
  TestNotifications repo,
  TestLaunches launches,
) async {
  addTearDown(auth.sessions.close);
  addTearDown(launches.events.close);
  await tester.pumpWidget(
    ChorelyApp(
      auth: auth,
      households: TestHouseholds()..home = home,
      family: family()..role = 'child',
      chores: TestChores()
        ..actor = child
        ..chores = [chore()],
      notifications: repo,
      notificationLaunches: launches,
    ),
  );
  await tester.pump();
}

const childSession = AccountSession(
  uid: 'device',
  email: '',
  verified: false,
  supervised: true,
  householdId: 'home',
  profileId: 'child',
);
Future<void> tap(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> settings(
  WidgetTester tester,
  TestNotifications repo, {
  ChoreActor actor = guardian,
  bool small = false,
}) async {
  if (small) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: chorelyTheme(),
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(small ? 2 : 1)),
        child: widget!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => NotificationSettingsScreen(
                  home: home,
                  actor: actor,
                  repository: repo,
                  family: family(),
                ),
              ),
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Cold-start link waits for the matching authenticated profile and duplicate taps share one route',
    (tester) async {
      final auth = TestAuth(), launches = TestLaunches();
      final link = NotificationLink(
        householdId: home.id,
        notificationId: 'a' * 64,
        actorId: 'child',
      );
      launches.first = link;
      final repo = TestNotifications()
        ..destination = NotificationDestination(
          householdId: home.id,
          occurrenceId: 'occurrence',
          actorId: 'child',
        );
      await routedApp(tester, auth, repo, launches);
      auth.sessions.add(null);
      await tester.pumpAndSettle();
      expect(repo.opened, isEmpty);
      expect(find.text('Adult email'), findsOneWidget);
      auth.sessions.add(childSession);
      await tester.pumpAndSettle();
      expect(find.text('Chore details'), findsOneWidget);
      expect(repo.opened.length, 1);
      launches.events.add(link);
      await tester.pumpAndSettle();
      expect(repo.opened.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'A cold-start payload for another actor cannot initiate a private lookup',
    (tester) async {
      final auth = TestAuth(),
          launches = TestLaunches()
            ..first = NotificationLink(
              householdId: home.id,
              notificationId: 'a' * 64,
              actorId: 'child',
            );
      final repo = TestNotifications();
      await routedApp(tester, auth, repo, launches);
      auth.sessions.add(
        const AccountSession(
          uid: 'other',
          email: 'fictional@example.test',
          verified: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.opened, isEmpty);
      expect(find.text('Chore details'), findsNothing);
      expect(
        find.textContaining('unavailable for this session'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'An identity change discards an earlier in-flight notification route',
    (tester) async {
      final auth = TestAuth(),
          launches = TestLaunches()
            ..first = NotificationLink(
              householdId: home.id,
              notificationId: 'a' * 64,
              actorId: 'child',
            );
      final repo = DelayedNotifications();
      await routedApp(tester, auth, repo, launches);
      auth.sessions.add(childSession);
      await tester.pumpAndSettle();
      expect(repo.opened.length, 1);
      auth.sessions.add(
        const AccountSession(
          uid: 'other',
          email: 'fictional@example.test',
          verified: true,
        ),
      );
      await tester.pumpAndSettle();
      repo.result.complete(
        NotificationDestination(
          householdId: home.id,
          occurrenceId: 'occurrence',
          actorId: 'child',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chore details'), findsNothing);
      expect(find.text('Your homes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('Notification payloads accept only bounded versioned opaque IDs and never URLs', () {
    final link = NotificationLink(
      householdId: 'home',
      notificationId: 'a' * 64,
      actorId: 'child',
    );
    expect(NotificationLink.parse(link.encode())!.actorId, 'child');
    for (final value in [
      null,
      '',
      'https://example.test',
      '[]',
      '{}',
      '{"v":2}',
      'a' * 2049,
      '{"v":1,"householdId":"../home","actorId":"child","notificationId":"${'a' * 64}"}',
    ]) {
      expect(NotificationLink.parse(value), isNull);
    }
  });
  testWidgets(
    'Uncertain saves freeze the same preference envelope at 320×568dp and 200% text',
    (tester) async {
      final repo = TestNotifications()
        ..failure = const NotificationFailure(
          'Connection interrupted. Retry the same request.',
        );
      await settings(tester, repo, small: true);
      await tap(tester, find.text('Due reminders'));
      await tap(tester, find.text('Save preferences'));
      expect(repo.saves.single.preferences.due, false);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'New assignments'),
            )
            .onChanged,
        isNull,
      );
      repo.failure = null;
      await tap(tester, find.text('Retry same settings'));
      expect(repo.saves.length, 2);
      expect(repo.saves.map((s) => s.id).toSet().length, 1);
      expect(
        identical(repo.saves.first.preferences, repo.saves.last.preferences),
        true,
      );
      expect(find.text('Open settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Supervised settings expose saved policy without a self-service save control',
    (tester) async {
      final repo = TestNotifications()..canEdit = false;
      await settings(tester, repo, actor: child, small: true);
      expect(repo.loads.single, 'child');
      expect(find.text('Save preferences'), findsNothing);
      expect(find.text('Settings for'), findsNothing);
      expect(find.textContaining('Your guardian manages'), findsOneWidget);
      for (final tile in tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      )) {
        expect(tile.onChanged, isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'A guardian selects a child policy while ordinary adult preferences remain private',
    (tester) async {
      final repo = TestNotifications();
      await settings(tester, repo);
      await tap(
        tester,
        find.byKey(const ValueKey('notification-target-guardian')),
      );
      await tester.tap(find.text('Fictional child').last);
      await tester.pumpAndSettle();
      expect(repo.loads.last, 'child');
      await tap(tester, find.text('Save preferences'));
      expect(repo.saves.single.base.actorId, 'child');
    },
  );
  testWidgets(
    'A known settings conflict requires reload before a fresh command can save',
    (tester) async {
      final repo = TestNotifications()
        ..failure = const NotificationFailure(
          'Settings changed. Reload.',
          conflict: true,
          retryable: false,
        );
      await settings(tester, repo);
      await tap(tester, find.text('Save preferences'));
      expect(find.text('Retry same settings'), findsNothing);
      await tap(tester, find.text('Reload settings'));
      repo.failure = null;
      await tap(tester, find.text('Save preferences'));
      expect(repo.saves.map((s) => s.id).toSet().length, 2);
    },
  );
  testWidgets(
    'Inbox counts actual recent unread rows and an unavailable tap does not invent read success',
    (tester) async {
      final repo = TestNotifications()
        ..updates = [
          HouseholdUpdate(
            id: 'update',
            occurrenceId: 'occurrence',
            title: 'A saved update',
            body: 'A chore is ready for you.',
            publishedAt: DateTime.utc(2026),
            unread: true,
          ),
        ];
      final chores = TestChores()..actor = child;
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: UpdatesScreen(
            home: home,
            uid: 'device',
            actor: child,
            repository: repo,
            chores: chores,
            family: family(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.watches, ['child']);
      expect(find.text('1 unread in recent updates'), findsOneWidget);
      await tap(tester, find.text('A saved update'));
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(find.text('1 unread in recent updates'), findsOneWidget);
      expect(find.text('Chore details'), findsNothing);
    },
  );
  testWidgets(
    'An authorized update opens the current assigned chore with supervised controls',
    (tester) async {
      final repo = TestNotifications()
        ..updates = [
          HouseholdUpdate(
            id: 'update',
            occurrenceId: 'occurrence',
            title: 'A saved update',
            body: 'A chore is ready for you.',
            publishedAt: DateTime.utc(2026),
            unread: false,
          ),
        ]
        ..destination = NotificationDestination(
          householdId: home.id,
          occurrenceId: 'occurrence',
          actorId: 'child',
        );
      final chores = TestChores()
        ..actor = child
        ..chores = [chore()];
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: UpdatesScreen(
            home: home,
            uid: 'device',
            actor: child,
            repository: repo,
            chores: chores,
            family: family(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('A saved update'));
      expect(find.text('Chore details'), findsOneWidget);
      expect(find.text('Mark done'), findsOneWidget);
      expect(find.text('Edit chore'), findsNothing);
      expect(find.text('Approve chore'), findsNothing);
    },
  );
}
