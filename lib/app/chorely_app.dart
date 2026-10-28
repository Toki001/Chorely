import 'package:flutter/material.dart';

import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/account_screen.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/households/domain/household_repository.dart';
import '../features/households/presentation/households_screen.dart';
import '../shared/widgets/page_frame.dart';
import 'theme.dart';

class ChorelyApp extends StatefulWidget {
  const ChorelyApp({required this.auth, required this.households, super.key});
  final AuthRepository auth;
  final HouseholdRepository households;
  @override
  State<ChorelyApp> createState() => _ChorelyAppState();
}

class _ChorelyAppState extends State<ChorelyApp> {
  bool _introFinished = false;
  late final Stream<AccountSession?> _session = widget.auth.watchSession();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chorely',
    debugShowCheckedModeBanner: false,
    theme: chorelyTheme(),
    home: StreamBuilder<AccountSession?>(
      stream: _session,
      builder: (context, snapshot) {
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
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading account',
              ),
            ),
          );
        }
        final session = snapshot.data;
        if (session != null) {
          if (session.verified) {
            return HouseholdsScreen(
              key: ValueKey(session.uid),
              session: session,
              auth: widget.auth,
              repository: widget.households,
            );
          }
          return AccountScreen(session: session, repository: widget.auth);
        }
        if (!_introFinished) {
          return OnboardingScreen(
            onFinish: () => setState(() => _introFinished = true),
          );
        }
        return AuthScreen(repository: widget.auth);
      },
    ),
  );
}
