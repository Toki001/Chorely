import 'test_chores.dart';

import 'dart:async';

import 'package:chorely/app/chorely_app.dart';
import 'package:chorely/app/theme.dart';
import 'package:chorely/features/auth/domain/auth_repository.dart';
import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/family/domain/access_code.dart';
import 'package:chorely/features/family/domain/family_repository.dart';
import 'package:chorely/features/family/presentation/family_panel.dart';
import 'package:chorely/features/family/presentation/join_screen.dart';
import 'package:chorely/features/households/domain/household_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show TestAuth;
import 'test_family.dart';
import 'test_households.dart';

class LiveFamily extends TestFamily {
  final devices = StreamController<List<FamilyAccess>>.broadcast();
  bool removed = false;
  @override
  Stream<List<FamilyAccess>> watchAccess(String householdId, String kind) =>
      kind == 'device' && !removed ? devices.stream : Stream.value([]);
  @override
  Future<void> revoke({
    required String householdId,
    required String targetId,
    required String kind,
  }) async {
    removed = true;
    devices.add([]);
  }
}

void main() {
  testWidgets(
    'Confirmed device removal disappears when authoritative stream updates',
    (tester) async {
      final family = LiveFamily();
      addTearDown(family.devices.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FamilyPanel(
                householdId: 'home',
                uid: 'guardian',
                repository: family,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      family.devices.add([
        const FamilyAccess(
          id: 'fictional-device',
          kind: 'device',
          status: 'active',
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Revoke access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke access'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove access'));
      await tester.pumpAndSettle();
      expect(find.text('Linked child device'), findsNothing);
    },
  );

  test('One-use codes preserve 256-bit bytes and reject malformed input', () {
    final codes = List.generate(50, (_) => newAccessCode());
    expect(codes.toSet().length, 50);
    for (final code in codes) {
      expect(code.length, 43);
      expect(parseAccessCode(code), code);
    }
    for (final code in [
      '',
      '123456',
      'a' * 43,
      'https://untrusted.example',
      '😀',
    ]) {
      expect(parseAccessCode(code), isNull);
    }
  });
  testWidgets('Adult member sees roster without guardian mutation controls', (
    tester,
  ) async {
    final family = TestFamily()
      ..role = 'adult'
      ..people = [
        const FamilyPerson(
          id: 'member',
          nickname: 'Sam',
          role: 'adult',
          active: true,
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: chorelyTheme(),
        home: Scaffold(
          body: FamilyPanel(
            householdId: 'home',
            uid: 'member',
            repository: family,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Invite an adult'), findsNothing);
    expect(find.text('Add a child profile'), findsNothing);
    expect(find.text('Access controls'), findsNothing);
  });
  testWidgets(
    'Guardian invitation validates recipient and exposes code only after confirmation',
    (tester) async {
      final family = TestFamily();
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FamilyActionForm(
                householdId: 'home',
                repository: family,
                action: 'invite',
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Create one-use invite'));
      await tester.pumpAndSettle();
      expect(family.inviteIds, isEmpty);
      expect(find.byType(SelectableText), findsNothing);
      await tester.enterText(
        find.byType(TextFormField),
        'fictional-adult@example.test',
      );
      await tester.ensureVisible(find.text('Create one-use invite'));
      await tester.tap(find.text('Create one-use invite'));
      await tester.pumpAndSettle();
      expect(family.inviteIds.length, 1);
      expect(find.byType(SelectableText), findsOneWidget);
    },
  );
  testWidgets(
    'Child pairing requires a complete code and retries same device proof at 320dp 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final family = TestFamily()..fail = true;
      var joined = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: chorelyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: JoinScreen(
            childDevice: true,
            repository: family,
            onBack: () {},
            onJoined: (_) => joined = true,
          ),
        ),
      );
      expect(find.text('Adult email'), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.ensureVisible(find.text('Link this device'));
      await tester.tap(find.text('Link this device'));
      await tester.pumpAndSettle();
      expect(family.proofs, isEmpty);
      await tester.enterText(find.byType(TextFormField), newAccessCode());
      await tester.ensureVisible(find.text('Link this device'));
      await tester.tap(find.text('Link this device'));
      await tester.pumpAndSettle();
      expect(joined, isFalse);
      family.fail = false;
      await tester.ensureVisible(find.text('Link this device'));
      await tester.tap(find.text('Link this device'));
      await tester.pumpAndSettle();
      expect(joined, isTrue);
      expect(family.proofs.length, 2);
      expect(family.proofs.toSet().length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Supervised identity opens child mode and exiting requires adult sign-in again',
    (tester) async {
      final auth = TestAuth();
      addTearDown(auth.sessions.close);
      final family = TestFamily()
        ..role = 'child'
        ..people = [
          const FamilyPerson(
            id: 'profile',
            nickname: 'Fictional child',
            role: 'child',
            active: true,
          ),
        ];
      final homes = TestHouseholds()
        ..home = const Household(
          id: 'home',
          name: 'Fictional home',
          timezone: 'Asia/Manila',
        );
      await tester.pumpWidget(
        ChorelyApp(
          chores: TestChores()
            ..actor = const ChoreActor(
              id: 'profile',
              role: 'child',
              canManage: false,
            ),
          auth: auth,
          households: homes,
          family: family,
        ),
      );
      auth.sessions.add(
        const AccountSession(
          uid: 'device',
          email: '',
          verified: false,
          supervised: true,
          householdId: 'home',
          profileId: 'profile',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hi, Fictional child.'), findsOneWidget);
      expect(find.text('Invite an adult'), findsNothing);
      await tester.ensureVisible(find.text('Leave supervised mode'));
      await tester.tap(find.text('Leave supervised mode'));
      await tester.pumpAndSettle();
      expect(find.text('Hi, Fictional child.'), findsNothing);
      expect(find.text('One home.\nOne team.'), findsOneWidget);
      await tester.ensureVisible(find.text('I already have an account'));
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      expect(find.text('Adult email'), findsOneWidget);
      expect(find.text('Your homes'), findsNothing);
    },
  );
}
