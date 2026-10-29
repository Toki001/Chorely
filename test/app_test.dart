import 'test_notifications.dart';
import 'test_chores.dart';

import 'dart:async';

import 'test_households.dart';
import 'test_family.dart';

import 'package:chorely/app/chorely_app.dart';
import 'package:chorely/app/theme.dart';
import 'package:chorely/features/auth/domain/auth_repository.dart';
import 'package:chorely/features/auth/presentation/auth_screen.dart';
import 'package:chorely/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAuth implements AuthRepository {
  final sessions = StreamController<AccountSession?>.broadcast();
  int attempts = 0;
  bool fail = false;
  @override
  Stream<AccountSession?> watchSession() => sessions.stream;
  @override
  Future<void> signIn(String email, String password) async {
    attempts++;
    if (fail) {
      throw const AccountFailure(
        'Couldn’t connect. Check your connection and try again.',
      );
    }
    sessions.add(
      AccountSession(uid: 'fictional', email: email, verified: false),
    );
  }

  @override
  Future<void> register(String email, String password) =>
      signIn(email, password);
  @override
  Future<void> signOut() async {
    sessions.add(null);
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> sendVerification() async {}
}

void main() {
  testWidgets('Onboarding remains scrollable at 320dp and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: chorelyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: OnboardingScreen(onFinish: () => finished = true),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Let’s begin'));
      await tester.tap(find.text('Let’s begin'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text('Set up your home'));
    await tester.tap(find.text('Set up your home'));
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid form never calls auth backend', (tester) async {
    final auth = TestAuth();
    addTearDown(auth.sessions.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: chorelyTheme(),
        home: AuthScreen(repository: auth),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(auth.attempts, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('Connection failure is actionable and allows retry', (
    tester,
  ) async {
    final auth = TestAuth()..fail = true;
    addTearDown(auth.sessions.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: chorelyTheme(),
        home: AuthScreen(repository: auth),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'guardian@example.test',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'fictional-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(auth.attempts, 1);
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'Unverified account stays in verification flow and can sign out',
    (tester) async {
      final auth = TestAuth();
      addTearDown(auth.sessions.close);
      await tester.pumpWidget(
        ChorelyApp(
          notifications: TestNotifications(),
          chores: TestChores(),
          auth: auth,
          households: TestHouseholds(),
          family: TestFamily(),
        ),
      );
      auth.sessions.add(
        const AccountSession(
          uid: 'fictional',
          email: 'adult@example.test',
          verified: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Check your inbox.'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('One home.\nOne team.'), findsOneWidget);
    },
  );

  testWidgets('Onboarding controls meet touch target and labeling guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: chorelyTheme(),
        home: OnboardingScreen(onFinish: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
