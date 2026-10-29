import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/page_frame.dart';
import '../../family/domain/family_repository.dart';
import '../domain/chore_repository.dart';

class ChoreActions extends StatefulWidget {
  const ChoreActions({
    required this.householdId,
    required this.uid,
    required this.chore,
    required this.repository,
    required this.family,
    required this.onReload,
    this.supervised = false,
    super.key,
  });
  final String householdId;
  final String uid;
  final ChoreOccurrence chore;
  final ChoreRepository repository;
  final FamilyRepository family;
  final VoidCallback onReload;
  final bool supervised;
  @override
  State<ChoreActions> createState() => _ChoreActionsState();
}

class _Intent {
  _Intent(this.action, this.version, {this.note = '', this.target})
    : id = const Uuid().v4();
  final String id, action, note;
  final int version;
  final String? target;
}

class _ChoreActionsState extends State<ChoreActions> {
  late final _actor = widget.repository.watchActor(
    widget.householdId,
    widget.uid,
  );
  _Intent? _pending;
  bool _busy = false, _blocked = false;
  String? _error;
  Future<void> _begin(String action, {String note = '', String? target}) async {
    if (_busy || _pending != null || _blocked) return;
    _pending = _Intent(
      action,
      widget.chore.version,
      note: note,
      target: target,
    );
    await _send();
  }

  Future<void> _send() async {
    final intent = _pending;
    if (intent == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.act(
        householdId: widget.householdId,
        occurrenceId: widget.chore.id,
        commandId: intent.id,
        action: intent.action,
        baseVersion: intent.version,
        note: intent.note,
        targetActorId: intent.target,
      );
      if (mounted) setState(() => _pending = null);
    } on ChoreFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          if (!e.retryable || e.conflict) {
            _pending = null;
            _blocked = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Couldn’t confirm this action. Check your connection and retry the same request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.refresh(widget.householdId, widget.chore.id);
      if (mounted) {
        setState(() {
          _pending = null;
          _blocked = false;
          _error = null;
        });
        widget.onReload();
      }
    } on ChoreFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Couldn’t reload this chore. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestNote(bool redo) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _TaskNoteDialog(redo: redo),
    );
    if (note != null && mounted) {
      await _begin(redo ? 'redo' : 'help', note: note);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ChoreActor?>(
    key: const ValueKey('chore-action-actor'),
    stream: _actor,
    builder: (context, s) {
      if (s.hasError) {
        return const InlineError(
          'Couldn’t check your chore permissions. Reload the chore or ask a guardian about access.',
        );
      }
      if (s.connectionState == ConnectionState.waiting) {
        return const LinearProgressIndicator(
          semanticsLabel: 'Checking chore actions',
        );
      }
      final actor = s.data;
      if (actor == null || (widget.supervised && actor.role != 'child')) {
        return const Text(
          'Actions are unavailable for this profile. Ask a guardian to check access.',
        );
      }
      final chore = widget.chore,
          assigned = chore.draft.assignedActorIds.contains(actor.id);
      final own = chore.contributions
          .where((c) => c.actorId == actor.id)
          .firstOrNull;
      final active = ['scheduled', 'needs_redo'].contains(chore.status);
      final canPress = !_busy && _pending == null && !_blocked;
      final ownHelp = chore.helpRequests
          .where((h) => h.actorId == actor.id)
          .firstOrNull;
      final review =
          actor.guardian &&
          !widget.supervised &&
          !assigned &&
          own == null &&
          chore.status == 'pending_review' &&
          chore.draft.reviewMode == 'guardian';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Semantics(
            liveRegion: true,
            child: Text(
              chore.statusLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (chore.reviewNote?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text('Guardian’s note: ${chore.reviewNote}'),
          ],
          if (chore.draft.completionPolicy == 'all_members_complete')
            Text(
              '${chore.contributions.length} of ${chore.draft.assignedActorIds.length} parts recorded',
            ),
          if (assigned && own != null && chore.status == 'scheduled')
            const Text(
              'Your part is recorded. Waiting for the rest of the team.',
            ),
          if (assigned && chore.status == 'pending_review')
            const Text('A separate guardian will take a look.'),
          if (assigned && active && own == null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canPress ? () => _begin('complete') : null,
              icon: const Icon(Icons.check_rounded),
              label: Text(
                chore.draft.completionPolicy == 'all_members_complete' &&
                        chore.draft.assignedActorIds.length > 1
                    ? 'Mark my part done'
                    : 'Mark done',
              ),
            ),
            if (ownHelp?.status != 'open')
              OutlinedButton(
                onPressed: canPress ? () => _requestNote(false) : null,
                child: Text(
                  ownHelp == null ? 'Ask for help' : 'Ask for help again',
                ),
              ),
          ],
          if (assigned &&
              own != null &&
              [
                'scheduled',
                'completed',
                'pending_review',
              ].contains(chore.status) &&
              own.completionRevision == chore.completionRevision) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: canPress ? () => _begin('undo') : null,
              child: const Text('Undo my part'),
            ),
            const Text(
              'Undo lasts five minutes, before another completion or review. Availability is checked when you tap.',
            ),
          ],
          if (review) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canPress ? () => _begin('approve') : null,
              child: const Text('Approve chore'),
            ),
            OutlinedButton(
              onPressed: canPress ? () => _requestNote(true) : null,
              child: const Text('Ask for another look'),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                semanticsLabel: 'Confirming chore action',
              ),
            ),
          if (_error != null) InlineError(_error!),
          if (_pending != null && !_busy) ...[
            const Text(
              'This request is waiting for confirmation. Retry keeps its details unchanged.',
            ),
            FilledButton(onPressed: _send, child: const Text('Retry action')),
          ],
          if (_error != null || _blocked)
            TextButton(
              onPressed: _busy ? null : _reload,
              child: const Text('Reload current chore'),
            ),
          if (actor.canManage && !widget.supervised) ...[
            for (final help in chore.helpRequests.where(
              (h) => h.status == 'open',
            ))
              _HelpCard(
                key: ValueKey('manager-help-${help.requestId}'),
                householdId: widget.householdId,
                requestId: help.requestId,
                repository: widget.repository,
                onAnswered: canPress
                    ? () => _begin('resolve_help', target: help.actorId)
                    : null,
                manager: true,
              ),
          ] else if (ownHelp != null)
            _HelpCard(
              key: ValueKey('own-help-${ownHelp.requestId}'),
              householdId: widget.householdId,
              requestId: ownHelp.requestId,
              repository: widget.repository,
            ),
          if (actor.role != 'child' && !widget.supervised)
            _ActivityPanel(
              key: const ValueKey('chore-activity'),
              householdId: widget.householdId,
              occurrenceId: chore.id,
              repository: widget.repository,
              family: widget.family,
            ),
        ],
      );
    },
  );
}

class _TaskNoteDialog extends StatefulWidget {
  const _TaskNoteDialog({required this.redo});
  final bool redo;
  @override
  State<_TaskNoteDialog> createState() => _TaskNoteDialogState();
}

class _TaskNoteDialogState extends State<_TaskNoteDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.redo ? 'Another look' : 'Ask for help'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.redo ? 'Explain what needs another look.' : 'Your note is shared with you and household chore managers.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('task-action-note'),
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: widget.redo ? 'Feedback' : 'Note (optional)',
                errorMaxLines: 3,
              ),
              validator: (v) => widget.redo && (v?.trim().isEmpty ?? true)
                  ? 'Add a short explanation.'
                  : (v?.length ?? 0) > 500
                  ? 'Use at most 500 characters.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _note.text.trim());
          }
        },
        child: Text(
          widget.redo ? 'Send for another look' : 'Send help request',
        ),
      ),
    ],
  );
}

class _HelpCard extends StatefulWidget {
  const _HelpCard({
    required this.householdId,
    required this.requestId,
    required this.repository,
    this.manager = false,
    this.onAnswered,
    super.key,
  });
  final String householdId, requestId;
  final ChoreRepository repository;
  final bool manager;
  final VoidCallback? onAnswered;
  @override
  State<_HelpCard> createState() => _HelpCardState();
}

class _HelpCardState extends State<_HelpCard> {
  late final _request = widget.repository.watchHelp(
    widget.householdId,
    widget.requestId,
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<HelpRequest?>(
    stream: _request,
    builder: (context, s) {
      if (s.hasError) {
        return const InlineError(
          'This help request is unavailable. Your access or connection may have changed.',
        );
      }
      if (!s.hasData) {
        return const LinearProgressIndicator(
          semanticsLabel: 'Loading help request',
        );
      }
      final request = s.data!;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                request.status == 'open'
                    ? 'Help requested'
                    : 'Help request answered',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (request.note.isNotEmpty) Text(request.note),
              if (request.responseNote?.isNotEmpty ?? false)
                Text(request.responseNote!),
              if (widget.manager && request.status == 'open')
                TextButton(
                  onPressed: widget.onAnswered,
                  child: const Text('Mark request answered'),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActivityPanel extends StatefulWidget {
  const _ActivityPanel({
    required this.householdId,
    required this.occurrenceId,
    required this.repository,
    required this.family,
    super.key,
  });
  final String householdId, occurrenceId;
  final ChoreRepository repository;
  final FamilyRepository family;
  @override
  State<_ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<_ActivityPanel> {
  late final _activity = widget.repository.watchActivity(
    widget.householdId,
    widget.occurrenceId,
  );
  late final _people = widget.family.watchPeople(widget.householdId);
  @override
  Widget build(BuildContext context) => StreamBuilder<List<FamilyPerson>>(
    stream: _people,
    builder: (context, people) => StreamBuilder<List<ChoreActivity>>(
      stream: _activity,
      builder: (context, s) {
        if (s.hasError || people.hasError) {
          return const InlineError('Couldn’t load this chore’s activity.');
        }
        if (!s.hasData || !people.hasData) {
          return const LinearProgressIndicator(
            semanticsLabel: 'Loading chore activity',
          );
        }
        final names = {for (final p in people.data!) p.id: p.nickname};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Chore activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('Most recent actions · Times on this device'),
            if (s.data!.isEmpty) const Text('No recorded actions yet.'),
            for (final event in s.data!)
              Builder(
                builder: (context) {
                  final at = event.serverAt.toLocal(),
                      local = MaterialLocalizations.of(context);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(event.label),
                    subtitle: Text(
                      '${event.system ? 'Chorely' : names[event.actorId] ?? 'Former member'} · ${local.formatShortDate(at)} ${local.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat)}${event.reviewNote?.isNotEmpty ?? false ? '\n${event.reviewNote}' : ''}',
                    ),
                  );
                },
              ),
          ],
        );
      },
    ),
  );
}
