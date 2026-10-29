import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/page_frame.dart';
import '../../family/domain/family_repository.dart';
import '../../households/domain/household_repository.dart';
import '../domain/chore_repository.dart';
import 'chore_editor.dart';
import 'chore_actions.dart';
import 'recurrence_builder.dart';
import '../domain/recurrence_repository.dart';

class ChorePanel extends StatefulWidget {
  const ChorePanel({
    required this.home,
    required this.uid,
    required this.repository,
    required this.family,
    this.actorId,
    super.key,
  });
  final Household home;
  final String uid;
  final String? actorId;
  final ChoreRepository repository;
  final FamilyRepository family;
  @override
  State<ChorePanel> createState() => _ChorePanelState();
}

class _ChorePanelState extends State<ChorePanel> {
  late final _permission = widget.repository.watchCanManage(
    widget.home.id,
    widget.uid,
  );
  late Stream<List<ChoreOccurrence>> _chores = _watch();
  Stream<List<ChoreOccurrence>> _watch() =>
      widget.repository.watchChores(widget.home.id, actorId: widget.actorId);
  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() => _chores = _watch());
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: _permission,
    builder: (context, permission) {
      final canManage =
          widget.actorId == null &&
          !permission.hasError &&
          permission.data == true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.actorId == null ? 'Chores to share' : 'Your chores',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ChoreOccurrence>>(
            stream: _chores,
            builder: (context, s) {
              if (s.hasError) {
                return Column(
                  children: [
                    const InlineError(
                      'Couldn’t load chores. Check your connection or ask a guardian about access.',
                    ),
                    TextButton(
                      onPressed: () => setState(() => _chores = _watch()),
                      child: const Text('Reload chores'),
                    ),
                  ],
                );
              }
              if (!s.hasData) {
                return const LinearProgressIndicator(
                  semanticsLabel: 'Loading chores',
                );
              }
              if (s.data!.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    widget.actorId == null
                        ? 'A little teamwork starts with one chore.'
                        : 'No chores assigned yet. Your guardian will add them here.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final chore in s.data!)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Icon(switch (chore.status) {
                          'completed' ||
                          'approved' => Icons.check_circle_rounded,
                          'pending_review' => Icons.hourglass_top_rounded,
                          'needs_redo' => Icons.refresh_rounded,
                          'cancelled' || 'skipped' => Icons.event_busy_rounded,
                          _ => Icons.radio_button_unchecked_rounded,
                        }),
                        title: Text(chore.draft.title),
                        subtitle: Text(
                          '${chore.timingLabel}\n${chore.timezone}\n${chore.statusLabel}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _open(
                          ChoreDetail(
                            home: widget.home,
                            occurrenceId: chore.id,
                            uid: widget.uid,
                            supervised: widget.actorId != null,
                            repository: widget.repository,
                            family: widget.family,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (canManage) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a chore'),
              onPressed: () => _open(
                ChoreEditor(
                  home: widget.home,
                  repository: widget.repository,
                  family: widget.family,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class ChoreDetail extends StatefulWidget {
  const ChoreDetail({
    required this.home,
    required this.occurrenceId,
    required this.uid,
    required this.repository,
    required this.family,
    this.supervised = false,
    super.key,
  });
  final Household home;
  final String occurrenceId;
  final String uid;
  final ChoreRepository repository;
  final FamilyRepository family;
  final bool supervised;
  @override
  State<ChoreDetail> createState() => _ChoreDetailState();
}

class _ChoreDetailState extends State<ChoreDetail> {
  late Stream<ChoreOccurrence?> _chore = _watch();
  late final _permission = widget.repository.watchCanManage(
    widget.home.id,
    widget.uid,
  );
  late final _people = widget.family.watchPeople(widget.home.id);
  Stream<RecurrenceConfiguration?>? _configuration;
  String? _error;
  ChoreOccurrence? _archiveBase;
  String? _archiveCommand;
  bool _busy = false;
  Stream<ChoreOccurrence?> _watch() =>
      widget.repository.watchChore(widget.home.id, widget.occurrenceId);
  Future<void> _archive(ChoreOccurrence base) async {
    if (_archiveCommand == null) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel this chore?'),
          content: const Text(
            'The assignment will be cancelled. Its stored history stays available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep chore'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel assignment'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      _archiveBase = base;
      _archiveCommand = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.write(
        householdId: widget.home.id,
        commandId: _archiveCommand!,
        action: 'archive',
        base: _archiveBase,
      );
      if (mounted) {
        setState(() {
          _chore = _watch();
          _archiveCommand = null;
          _archiveBase = null;
        });
      }
    } on ChoreFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          if (e.conflict) {
            _archiveCommand = null;
            _archiveBase = null;
            _chore = _watch();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Couldn’t confirm cancellation. Retry the same request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chore details')),
    body: PageFrame(
      child: StreamBuilder<ChoreOccurrence?>(
        stream: _chore,
        builder: (context, s) {
          if (s.hasError) {
            return Column(
              children: [
                const InlineError(
                  'This chore is unavailable. Your access or connection may have changed.',
                ),
                TextButton(
                  onPressed: () => setState(() => _chore = _watch()),
                  child: const Text('Reload chore'),
                ),
              ],
            );
          }
          if (!s.hasData) {
            return s.connectionState == ConnectionState.waiting
                ? const LinearProgressIndicator(semanticsLabel: 'Loading chore')
                : const InlineError('This chore no longer exists.');
          }
          final chore = s.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                chore.draft.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                '${chore.draft.category}${chore.draft.room.isEmpty ? '' : ' · ${chore.draft.room}'}',
              ),
              const SizedBox(height: 16),
              Text(chore.timingLabel),
              Text(chore.timezone),
              if (chore.schedulingReason != null)
                Text(recurrenceReasonLabel(chore.schedulingReason)),
              if (chore.timeAdjusted)
                Text(
                  'Clock change: the valid window is ${chore.effectiveStartLocal ?? '—'} to ${chore.effectiveDueLocal}. Your requested times are shown above.',
                ),
              const SizedBox(height: 20),
              StreamBuilder<List<FamilyPerson>>(
                key: const ValueKey('chore-detail-roster'),
                stream: _people,
                builder: (context, people) {
                  if (people.hasError) {
                    return const InlineError('Couldn’t load assignee names.');
                  }
                  final names = {
                    for (final p in people.data ?? <FamilyPerson>[])
                      p.id: p.nickname,
                  };
                  return Text(
                    'Assigned to: ${chore.draft.assignedActorIds.map((id) => names[id] ?? 'Household member').join(', ')}',
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                chore.draft.completionPolicy == 'all_members_complete'
                    ? 'Every assignee completes their part.'
                    : 'One assignee completes for the team.',
              ),
              Text(
                chore.draft.reviewMode == 'guardian'
                    ? 'A separate guardian reviews this chore.'
                    : 'No guardian review required.',
              ),
              const SizedBox(height: 24),
              if (chore.draft.instructionIllustrationKey == 'assign') ...[
                Image.asset(
                  'app/assets/illustrations/assign.png',
                  height: 160,
                  semanticLabel: 'Illustration of household teamwork.',
                ),
                const SizedBox(height: 16),
              ],
              if (chore.draft.description.isNotEmpty) ...[
                Text(
                  'Household instructions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(chore.draft.description),
                const SizedBox(height: 20),
              ],
              if (chore.draft.steps.isNotEmpty) ...[
                Text(
                  'Step by step',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < chore.draft.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${i + 1}. ${chore.draft.steps[i]}'),
                  ),
              ],
              ChoreActions(
                key: ValueKey('actions-${chore.id}-${widget.uid}'),
                householdId: widget.home.id,
                uid: widget.uid,
                chore: chore,
                repository: widget.repository,
                family: widget.family,
                supervised: widget.supervised,
                onReload: () => setState(() => _chore = _watch()),
              ),
              if (chore.status == 'cancelled')
                const Text('This assignment was cancelled.'),
              if (_error != null) InlineError(_error!),
              StreamBuilder<bool>(
                key: const ValueKey('chore-detail-permission'),
                stream: _permission,
                builder: (context, permission) {
                  if (widget.supervised ||
                      permission.hasError ||
                      permission.data != true) {
                    return const SizedBox.shrink();
                  }
                  _configuration ??= widget.repository.recurrence
                      .watchConfiguration(widget.home.id, chore.templateId);
                  return StreamBuilder<RecurrenceConfiguration?>(
                    key: const ValueKey('chore-repeat-settings'),
                    stream: _configuration,
                    builder: (context, configuration) {
                      if (configuration.hasError) {
                        return Column(
                          children: [
                            const InlineError('Couldn’t load repeat settings.'),
                            TextButton(
                              onPressed: () => setState(
                                () => _configuration = widget
                                    .repository
                                    .recurrence
                                    .watchConfiguration(
                                      widget.home.id,
                                      chore.templateId,
                                    ),
                              ),
                              child: const Text('Reload repeat settings'),
                            ),
                          ],
                        );
                      }
                      if (configuration.connectionState ==
                          ConnectionState.waiting) {
                        return const LinearProgressIndicator(
                          semanticsLabel: 'Loading repeat settings',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          if (![
                                'cancelled',
                                'skipped',
                              ].contains(chore.status) ||
                              configuration.data != null)
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final saved = await Navigator.of(context)
                                          .push<bool>(
                                            MaterialPageRoute(
                                              builder: (_) => RecurrenceBuilder(
                                                home: widget.home,
                                                base: chore,
                                                repository: widget
                                                    .repository
                                                    .recurrence,
                                                family: widget.family,
                                                configuration:
                                                    configuration.data,
                                              ),
                                            ),
                                          );
                                      if (mounted && context.mounted) {
                                        if (saved == true) {
                                          Navigator.of(context).pop(true);
                                        } else {
                                          setState(() => _chore = _watch());
                                        }
                                      }
                                    },
                              child: Text(
                                configuration.data == null
                                    ? 'Repeat this chore'
                                    : 'Repeat settings',
                              ),
                            ),

                          if (configuration.data == null && chore.editable)
                            OutlinedButton(
                              onPressed: _busy || _archiveCommand != null
                                  ? null
                                  : () async {
                                      await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => ChoreEditor(
                                            home: widget.home,
                                            repository: widget.repository,
                                            family: widget.family,
                                            base: chore,
                                          ),
                                        ),
                                      );
                                      if (mounted) {
                                        setState(() => _chore = _watch());
                                      }
                                    },
                              child: const Text('Edit chore'),
                            ),
                          if (configuration.data == null && chore.cancellable)
                            TextButton(
                              onPressed: _busy ? null : () => _archive(chore),
                              child: Text(
                                _busy
                                    ? 'Confirming cancellation…'
                                    : _archiveCommand == null
                                    ? 'Cancel chore'
                                    : 'Retry cancellation',
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}
