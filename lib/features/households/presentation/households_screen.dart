import '../../sync/presentation/confirm_account_exit.dart';
import '../../notifications/domain/notifications_repository.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../chores/domain/chore_repository.dart';
import '../../dashboard/presentation/household_hub.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/household_repository.dart';
import '../../family/domain/family_repository.dart';
import '../../family/presentation/join_screen.dart';

class HouseholdsScreen extends StatefulWidget {
  const HouseholdsScreen({
    required this.family,
    required this.notifications,
    required this.chores,
    required this.session,
    required this.auth,
    required this.repository,
    super.key,
  });
  final FamilyRepository family;
  final NotificationsRepository notifications;
  final ChoreRepository chores;
  final AccountSession session;
  final AuthRepository auth;
  final HouseholdRepository repository;
  @override
  State<HouseholdsScreen> createState() => _HouseholdsScreenState();
}

class _HouseholdsScreenState extends State<HouseholdsScreen> {
  late Stream<List<HouseholdSummary>> _homes = widget.repository
      .watchHouseholds(widget.session.uid);
  String? _selected;
  bool _creating = false;
  bool _joining = false;
  @override
  Widget build(BuildContext context) {
    if (_joining) {
      return JoinScreen(
        childDevice: false,
        repository: widget.family,
        onBack: () => setState(() => _joining = false),
        onJoined: (id) => setState(() {
          _joining = false;
          _selected = id;
        }),
      );
    }
    if (_creating) {
      return CreateHouseholdScreen(
        repository: widget.repository,
        onBack: () => setState(() => _creating = false),
        onCreated: (id) => setState(() {
          _creating = false;
          _selected = id;
        }),
      );
    }
    if (_selected != null) {
      return _HouseholdScreen(
        key: ValueKey(_selected),
        id: _selected!,
        uid: widget.session.uid,
        family: widget.family,
        notifications: widget.notifications,
        chores: widget.chores,
        repository: widget.repository,
        onBack: () => setState(() => _selected = null),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your homes'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => confirmAccountExit(context, widget.auth.signOut),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A place for\neveryone.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Keep the little things in sync, so there’s more time for the good things.',
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<HouseholdSummary>>(
              stream: _homes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const InlineError(
                        'Couldn’t load your homes. Your access or connection may have changed.',
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _homes = widget.repository.watchHouseholds(
                            widget.session.uid,
                          ),
                        ),
                        child: const Text('Try again'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading homes',
                    ),
                  );
                }
                final homes = snapshot.data!;
                if (homes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        Image.asset(
                          'app/assets/illustrations/invite.png',
                          height: 180,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your household starts here. Choose a name and invite everyone in when you’re ready.',
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: homes
                      .map(
                        (home) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(20),
                              leading: const CircleAvatar(
                                backgroundColor: ChorelyColors.lavender,
                                child: Icon(
                                  Icons.cottage_outlined,
                                  color: ChorelyColors.primary,
                                ),
                              ),
                              title: Text(home.name),
                              subtitle: Text(home.role),
                              trailing: const Icon(Icons.arrow_forward_rounded),
                              onTap: () => setState(() => _selected = home.id),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => setState(() => _creating = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a household'),
            ),
            TextButton(
              onPressed: () => setState(() => _joining = true),
              child: const Text('Join a household'),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateHouseholdScreen extends StatefulWidget {
  const CreateHouseholdScreen({
    required this.repository,
    required this.onBack,
    required this.onCreated,
    super.key,
  });
  final HouseholdRepository repository;
  final VoidCallback onBack;
  final ValueChanged<String> onCreated;
  @override
  State<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends State<CreateHouseholdScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _commandId = const Uuid().v4();
  String _timezone = 'Asia/Manila';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.repository.create(
        commandId: _commandId,
        name: _name.text.trim(),
        nickname: _nickname.text.trim(),
        timezone: _timezone,
      );
      if (mounted) widget.onCreated(id);
    } on HouseholdFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Couldn’t confirm your household. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back to your homes',
        onPressed: _busy ? null : widget.onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('A fresh start'),
    ),
    body: PageFrame(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Make yourself\nat home.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'A shared space for your household’s everyday teamwork.',
            ),
            const SizedBox(height: 28),
            if (_error != null) InlineError(_error!),
            TextFormField(
              controller: _name,
              enabled: !_busy,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Household name',
                hintText: 'Our home',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Give your household a name.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nickname,
              enabled: !_busy,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Your nickname',
                helperText: 'How your household will see you',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your nickname.' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _timezone,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Household timezone',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Asia/Manila',
                  child: Text('Philippines'),
                ),
                DropdownMenuItem(
                  value: 'America/New_York',
                  child: Text('New York'),
                ),
                DropdownMenuItem(value: 'Europe/London', child: Text('London')),
                DropdownMenuItem(
                  value: 'Australia/Sydney',
                  child: Text('Sydney'),
                ),
                DropdownMenuItem(value: 'Etc/UTC', child: Text('UTC')),
              ],
              onChanged: _busy ? null : (v) => setState(() => _timezone = v!),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Creating your home…' : 'Create household'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HouseholdScreen extends StatefulWidget {
  const _HouseholdScreen({
    required this.uid,
    required this.family,
    required this.notifications,
    required this.chores,
    required this.id,
    required this.repository,
    required this.onBack,
    super.key,
  });
  final String id;
  final String uid;
  final FamilyRepository family;
  final NotificationsRepository notifications;
  final ChoreRepository chores;
  final HouseholdRepository repository;
  final VoidCallback onBack;
  @override
  State<_HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<_HouseholdScreen> {
  late Stream<Household?> _home = widget.repository.watchHousehold(widget.id);
  @override
  Widget build(BuildContext context) => StreamBuilder<Household?>(
    stream: _home,
    builder: (context, snapshot) {
      if (snapshot.hasData && !snapshot.hasError) {
        return HouseholdHub(
          home: snapshot.data!,
          uid: widget.uid,
          repository: widget.chores,
          family: widget.family,
          notifications: widget.notifications,
          onExit: widget.onBack,
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Our household'),
          leading: IconButton(
            tooltip: 'Back to your homes',
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: PageFrame(
          child: Column(
            children: [
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasError)
                const LinearProgressIndicator(
                  semanticsLabel: 'Loading household',
                )
              else ...[
                const InlineError(
                  'This household is unavailable. Check your connection or ask a guardian about access.',
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _home = widget.repository.watchHousehold(widget.id),
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
