import '../../notifications/domain/notifications_repository.dart';

import 'package:flutter/material.dart';

import '../../chores/domain/chore_repository.dart';
import '../../dashboard/presentation/household_hub.dart';
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
    required this.notifications,
    required this.chores,
    super.key,
  });
  final AccountSession session;
  final AuthRepository auth;
  final HouseholdRepository households;
  final FamilyRepository family;
  final NotificationsRepository notifications;
  final ChoreRepository chores;
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
  Widget _unavailable(String? error) => Scaffold(
    appBar: AppBar(title: const Text('My home')),
    body: PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            InlineError(error)
          else
            const LinearProgressIndicator(
              semanticsLabel: 'Checking supervised access',
            ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: widget.auth.signOut,
            child: const Text('Leave supervised mode'),
          ),
          const Text('A guardian must sign in again to open adult controls.'),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
    stream: _role,
    builder: (context, role) {
      if (role.hasError ||
          (role.connectionState != ConnectionState.waiting &&
              role.data != 'child')) {
        return _unavailable(
          'This device no longer has supervised access. Ask a guardian to approve a new code.',
        );
      }
      if (!role.hasData) return _unavailable(null);
      return StreamBuilder<Household?>(
        stream: _home,
        builder: (context, home) {
          if (home.hasError ||
              (home.connectionState != ConnectionState.waiting &&
                  home.data == null)) {
            return _unavailable(
              'Your home is unavailable. Ask a guardian to check this device’s access.',
            );
          }
          if (!home.hasData) return _unavailable(null);
          return HouseholdHub(
            home: home.data!,
            uid: widget.session.uid,
            repository: widget.chores,
            family: widget.family,
            notifications: widget.notifications,
            supervisedActorId: widget.session.profileId!,
            onExit: widget.auth.signOut,
          );
        },
      );
    },
  );
}
