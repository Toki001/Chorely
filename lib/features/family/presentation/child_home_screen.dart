import 'package:flutter/material.dart';

import '../../../shared/widgets/page_frame.dart';
import '../../auth/domain/auth_repository.dart';
import '../../households/domain/household_repository.dart';
import '../domain/family_repository.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({
    required this.session,
    required this.auth,
    required this.households,
    required this.family,
    super.key,
  });
  final AccountSession session;
  final AuthRepository auth;
  final HouseholdRepository households;
  final FamilyRepository family;
  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  late final _role = widget.family.watchRole(
    widget.session.householdId!,
    widget.session.uid,
  );
  late final _home = widget.households.watchHousehold(
    widget.session.householdId!,
  );
  late final _people = widget.family.watchPeople(widget.session.householdId!);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My home')),
    body: PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<String?>(
            stream: _role,
            builder: (context, role) {
              if (role.hasError ||
                  (role.connectionState != ConnectionState.waiting &&
                      role.data != 'child')) {
                return const InlineError(
                  'This device no longer has supervised access. Ask a guardian to approve a new code.',
                );
              }
              if (!role.hasData) {
                return const LinearProgressIndicator(
                  semanticsLabel: 'Checking supervised access',
                );
              }
              return StreamBuilder<Household?>(
                stream: _home,
                builder: (context, home) {
                  if (home.hasError) {
                    return const InlineError(
                      'Your home is unavailable. Ask a guardian to check this device’s access.',
                    );
                  }
                  if (!home.hasData) {
                    return const LinearProgressIndicator(
                      semanticsLabel: 'Loading your home',
                    );
                  }
                  return StreamBuilder<List<FamilyPerson>>(
                    stream: _people,
                    builder: (context, people) {
                      if (people.hasError) {
                        return const InlineError(
                          'Your profile is unavailable. Ask a guardian for help.',
                        );
                      }
                      final own = people.data
                          ?.where(
                            (p) => p.id == widget.session.profileId && p.active,
                          )
                          .firstOrNull;
                      if (own == null) {
                        return const LinearProgressIndicator(
                          semanticsLabel: 'Loading your profile',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'app/assets/illustrations/assign.png',
                            height: 210,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Hi, ${own.nickname}.',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You’re part of ${home.data!.name}.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This is your supervised space. Your guardian manages household members and device access.',
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: widget.auth.signOut,
            child: const Text('Leave supervised mode'),
          ),
          const SizedBox(height: 8),
          const Text('A guardian must sign in again to open adult controls.'),
        ],
      ),
    ),
  );
}
