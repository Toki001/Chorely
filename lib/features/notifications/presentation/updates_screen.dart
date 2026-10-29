import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/page_frame.dart';
import '../../chores/domain/chore_repository.dart';
import '../../chores/presentation/chore_panel.dart';
import '../../family/domain/family_repository.dart';
import '../../households/domain/household_repository.dart';
import '../domain/notifications_repository.dart';
import 'notification_settings_screen.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({
    required this.home,
    required this.uid,
    required this.actor,
    required this.repository,
    required this.chores,
    required this.family,
    super.key,
  });
  final Household home;
  final String uid;
  final ChoreActor actor;
  final NotificationsRepository repository;
  final ChoreRepository chores;
  final FamilyRepository family;
  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  StreamSubscription<ChoreActor?>? _access;
  StreamSubscription<List<HouseholdUpdate>>? _inbox;
  ChoreActor? _actor;
  List<HouseholdUpdate>? _updates;
  bool _checking = true, _opening = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _access?.cancel();
    _inbox?.cancel();
    _inbox = null;
    _checking = true;
    _updates = null;
    _actor = null;
    _error = null;
    _access = widget.chores
        .watchActor(widget.home.id, widget.uid)
        .listen(
          (actor) {
            if (!mounted) return;
            if (actor == null || actor.id != widget.actor.id) {
              _inbox?.cancel();
              _inbox = null;
              setState(() {
                _checking = false;
                _actor = null;
                _updates = null;
                _error = 'Your updates are unavailable. Check your household access.';
              });
              return;
            }
            setState(() {
              _actor = actor;
              _checking = false;
            });
            _inbox ??= widget.repository
                .watchInbox(widget.home.id, actor.id)
                .listen(
                  (updates) {
                    if (mounted) {
                      setState(() {
                        _updates = updates;
                        _error = null;
                      });
                    }
                  },
                  onError: (Object error) {
                    if (mounted) {
                      setState(() {
                        _updates = null;
                        _error = 'Couldn’t load your updates. Check your connection and access.';
                      });
                    }
                  },
                );
          },
          onError: (Object error) {
            if (!mounted) return;
            _inbox?.cancel();
            _inbox = null;
            setState(() {
              _checking = false;
              _actor = null;
              _updates = null;
              _error =
                  'Your updates are unavailable. Check your household access.';
            });
          },
        );
  }

  @override
  void dispose() {
    _access?.cancel();
    _inbox?.cancel();
    super.dispose();
  }

  Future<void> _open(HouseholdUpdate update) async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final target = await widget.repository.open(widget.home.id, update.id);
      if (!mounted) return;
      if (target == null ||
          target.householdId != widget.home.id ||
          target.actorId != _actor?.id) {
        setState(
          () => _error = 'This update has changed or is no longer available. Your calendar has the latest chores.',
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ChoreDetail(
            home: widget.home,
            occurrenceId: target.occurrenceId,
            uid: widget.uid,
            repository: widget.chores,
            family: widget.family,
            supervised: _actor!.role == 'child',
          ),
        ),
      );
    } on NotificationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t open this update. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your updates')),
    body: PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A little teamwork.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Updates come from your saved household activity. Device alerts are optional.',
          ),
          const SizedBox(height: 16),
          if (_actor != null)
            OutlinedButton.icon(
              onPressed: _opening
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => NotificationSettingsScreen(
                          home: widget.home,
                          actor: _actor!,
                          repository: widget.repository,
                          family: widget.family,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Notification preferences'),
            ),
          if (_error != null) ...[
            InlineError(_error!),
            TextButton(
              onPressed: _opening ? null : () => setState(_watch),
              child: const Text('Reload updates'),
            ),
          ],
          if (_checking || (_updates == null && _error == null))
            const LinearProgressIndicator(
              semanticsLabel: 'Loading your updates',
            ),
          if (_opening)
            const LinearProgressIndicator(
              semanticsLabel: 'Checking this update',
            ),
          if (_updates != null) ...[
            const SizedBox(height: 16),
            Text(
              '${_updates!.where((u) => u.unread).length} unread in recent updates',
            ),
            if (_updates!.length == 50)
              const Text('Showing your most recent 50 active updates.'),
            if (_updates!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Your household updates will appear here as you share chores.',
                ),
              ),
            for (final update in _updates!)
              Card(
                child: InkWell(
                  onTap: _opening ? null : () => _open(update),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(update.unread ? 'Unread' : 'Read'),
                        Text(
                          update.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(update.body),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
