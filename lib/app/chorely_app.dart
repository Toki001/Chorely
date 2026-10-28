import 'package:flutter/material.dart';

import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/account_screen.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/households/domain/household_repository.dart';
import '../features/households/presentation/households_screen.dart';
import '../features/family/domain/family_repository.dart';
import '../features/family/presentation/child_home_screen.dart';
import '../features/family/presentation/join_screen.dart';
import '../shared/widgets/page_frame.dart';
import 'theme.dart';

class ChorelyApp extends StatefulWidget {
  const ChorelyApp({
    required this.auth,
    required this.households,
    required this.family,
    super.key,
  });
  final AuthRepository auth;
  final HouseholdRepository households;
  final FamilyRepository family;
  @override
  State<ChorelyApp> createState() => _ChorelyAppState();
}

class _ChorelyAppState extends State<ChorelyApp> {
  bool _introFinished = false;
  bool _linkChild = false;
  late final Stream<AccountSession?> _session = widget.auth.watchSession();
  Widget _home(AsyncSnapshot<AccountSession?> snapshot) {
    if (snapshot.hasError) {
      return Scaffold(
        body: PageFrame(
          child: Column(
            children: [
              const InlineError('Couldn’t load your account.'),
              FilledButton(
                onPressed: widget.auth.refresh,
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: widget.auth.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading account'),
        ),
      );
    }
    final session = snapshot.data;
    if (session != null) {
      if (session.supervised) {
        if (session.householdId == null || session.profileId == null) {
          return Scaffold(
            body: PageFrame(
              child: Column(
                children: [
                  const InlineError('This supervised session is unavailable.'),
                  TextButton(
                    onPressed: widget.auth.signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          );
        }
        return ChildHomeScreen(
          session: session,
          auth: widget.auth,
          households: widget.households,
          family: widget.family,
        );
      }
      if (session.verified) {
        return HouseholdsScreen(
          key: ValueKey(session.uid),
          session: session,
          auth: widget.auth,
          repository: widget.households,
          family: widget.family,
        );
      }
      return AccountScreen(session: session, repository: widget.auth);
    }
    if (_linkChild) {
      return JoinScreen(
        childDevice: true,
        repository: widget.family,
        onBack: () => setState(() => _linkChild = false),
        onJoined: (_) => setState(() => _linkChild = false),
      );
    }
    if (!_introFinished) {
      return OnboardingScreen(
        onFinish: () => setState(() => _introFinished = true),
        onLinkChild: () => setState(() => _linkChild = true),
      );
    }
    return AuthScreen(
      repository: widget.auth,
      onLinkChild: () => setState(() => _linkChild = true),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AccountSession?>(
    stream: _session,
    builder: (context, snapshot) => MaterialApp(
      // Auth identity changes discard route overlays and all previous profile UI.
      key: ValueKey(snapshot.data?.uid ?? 'signed-out'),
      title: 'Chorely',
      debugShowCheckedModeBanner: false,
      theme: chorelyTheme(),
      home: _home(snapshot),
    ),
  );
}
