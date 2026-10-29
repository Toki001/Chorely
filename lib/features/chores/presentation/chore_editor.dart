import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/page_frame.dart';
import '../../family/domain/family_repository.dart';
import '../../households/domain/household_repository.dart';
import '../../dashboard/domain/calendar_dates.dart';
import '../domain/chore_repository.dart';

class ChoreEditor extends StatefulWidget {
  const ChoreEditor({
    required this.home,
    required this.repository,
    required this.family,
    this.base,
    this.initialDate,
    super.key,
  });
  final Household home;
  final ChoreRepository repository;
  final FamilyRepository family;
  final ChoreOccurrence? base;
  final String? initialDate;
  @override
  State<ChoreEditor> createState() => _ChoreEditorState();
}

class _ChoreEditorState extends State<ChoreEditor> {
  final _form = GlobalKey<FormState>();
  final _commandId = const Uuid().v4();
  late final _people = widget.family.watchPeople(widget.home.id);
  late final _title = TextEditingController(text: widget.base?.draft.title);
  late final _description = TextEditingController(
    text: widget.base?.draft.description,
  );
  late final _room = TextEditingController(text: widget.base?.draft.room);
  late final _steps = TextEditingController(
    text: widget.base?.draft.steps.join('\n'),
  );
  late final _date = TextEditingController(
    text: widget.base?.draft.schedule['date'] as String? ?? widget.initialDate,
  );
  late final _at = TextEditingController(
    text: widget.base?.draft.schedule['at'] as String? ?? '18:00',
  );
  late final _start = TextEditingController(
    text: widget.base?.draft.schedule['startLocal'] as String?,
  );
  late final _end = TextEditingController(
    text: widget.base?.draft.schedule['endLocal'] as String?,
  );
  late String _category = widget.base?.draft.category ?? 'household';
  late String _kind = widget.base?.draft.schedule['kind'] as String? ?? 'none';
  late String _policy =
      widget.base?.draft.completionPolicy ?? 'any_one_completes';
  late String _review = widget.base?.draft.reviewMode ?? 'none';
  late bool _illustrated =
      widget.base?.draft.instructionIllustrationKey == 'assign';
  late final _assigned = {...?widget.base?.draft.assignedActorIds};
  ChoreDraft? _submitted;
  bool _busy = false;
  bool _conflict = false;
  String? _error;
  bool get _locked => _busy || _submitted != null;
  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _room,
      _steps,
      _date,
      _at,
      _start,
      _end,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validDate(String value) {
    if (!RegExp(r'^20\d{2}-\d{2}-\d{2}$|^2100-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final date = DateTime.tryParse('${value}T00:00:00Z');
    return date != null && date.toIso8601String().startsWith('${value}T');
  }

  bool _validLocal(String value) =>
      value.length == 16 &&
      _validDate(value.substring(0, 10)) &&
      value[10] == 'T' &&
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value.substring(11));
  Future<void> _save() async {
    if (_submitted == null) {
      if (!_form.currentState!.validate()) return;
      if (_assigned.isEmpty || _assigned.length > 6) {
        setState(() => _error = 'Choose one to six assignees.');
        return;
      }
      _submitted = ChoreDraft(
        title: _title.text.trim(),
        category: _category,
        description: _description.text.trim(),
        room: _room.text.trim(),
        steps: _steps.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        assignedActorIds: _assigned.toList()..sort(),
        completionPolicy: _policy,
        reviewMode: _review,
        instructionIllustrationKey: _illustrated ? 'assign' : null,
        schedule: {
          'kind': _kind,
          'date': _date.text.trim(),
          if (_kind == 'time' || _kind == 'deadline') 'at': _at.text.trim(),
          if (_kind == 'range') ...{
            'startLocal': _start.text.trim(),
            'endLocal': _end.text.trim(),
          },
        },
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.write(
        householdId: widget.home.id,
        commandId: _commandId,
        action: widget.base == null ? 'create' : 'edit',
        draft: _submitted,
        base: widget.base,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ChoreFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _conflict = e.conflict;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Couldn’t confirm this chore. Check your connection and retry this request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.base == null ? 'A little teamwork' : 'Edit chore'),
    ),
    body: PageFrame(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.base == null ? 'What needs doing?' : 'Make it clear.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Dates and times use your household timezone: ${widget.home.timezone}.',
            ),
            const SizedBox(height: 20),
            if (widget.base == null) ...[
              const Text('Start with a title'),
              Wrap(
                spacing: 8,
                children: [
                  for (final preset in const [
                    ('Cook rice', 'dinner'),
                    ('Wash dishes', 'kitchen'),
                    ('Tidy a room', 'rooms'),
                    ('Refill supplies', 'supplies'),
                  ])
                    ActionChip(
                      label: Text(preset.$1),
                      onPressed: _locked
                          ? null
                          : () => setState(() {
                              _title.text = preset.$1;
                              _category = preset.$2;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) InlineError(_error!),
            TextFormField(
              key: const ValueKey('chore-title'),
              controller: _title,
              enabled: !_locked,
              decoration: const InputDecoration(labelText: 'Chore title'),
              maxLength: 100,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Give this chore a title.'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('category-$_category'),
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in [
                  'dinner',
                  'kitchen',
                  'pets',
                  'rooms',
                  'household',
                  'supplies',
                ])
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: _locked ? null : (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _room,
              enabled: !_locked,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Room (optional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              enabled: !_locked,
              maxLength: 2000,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Household instructions (optional)',
                helperText: 'Choose a task and instructions suitable for each assignee.',
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('chore-steps'),
              controller: _steps,
              enabled: !_locked,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Steps (optional)',
                helperText:
                    'One per line · Up to 12 steps, 200 characters each',
                helperMaxLines: 3,
              ),
              validator: (v) {
                final lines = (v ?? '')
                    .split('\n')
                    .where((s) => s.trim().isNotEmpty);
                return lines.length > 12 ||
                        lines.any((s) => s.trim().length > 200)
                    ? 'Use up to 12 steps, 200 characters each.'
                    : null;
              },
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add a teamwork illustration'),
              subtitle: const Text(
                'An original Chorely scene alongside your instructions.',
              ),
              value: _illustrated,
              onChanged: _locked
                  ? null
                  : (v) => setState(() => _illustrated = v),
            ),
            const SizedBox(height: 16),
            Text('Who’s on it?', style: Theme.of(context).textTheme.titleLarge),
            StreamBuilder<List<FamilyPerson>>(
              key: const ValueKey('chore-assignee-roster'),
              stream: _people,
              builder: (context, s) {
                if (s.hasError) {
                  return const InlineError(
                    'Couldn’t load assignees. Return to your home and try again.',
                  );
                }
                if (!s.hasData) {
                  return const LinearProgressIndicator(
                    semanticsLabel: 'Loading assignees',
                  );
                }
                return Column(
                  children: [
                    for (final p in s.data!.where((p) => p.active))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.nickname),
                        subtitle: Text(p.role),
                        value: _assigned.contains(p.id),
                        onChanged: _locked
                            ? null
                            : (v) => setState(() {
                                v!
                                    ? _assigned.add(p.id)
                                    : _assigned.remove(p.id);
                              }),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Everyone does their part'),
              subtitle: Text(
                _policy == 'all_members_complete'
                    ? 'Each assignee completes their own part.'
                    : 'One assignee completes for the whole team.',
              ),
              value: _policy == 'all_members_complete',
              onChanged: _locked
                  ? null
                  : (v) => setState(
                      () => _policy = v
                          ? 'all_members_complete'
                          : 'any_one_completes',
                    ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Guardian review'),
              subtitle: const Text(
                'Needs a guardian who is not assigned to this chore.',
              ),
              value: _review == 'guardian',
              onChanged: _locked
                  ? null
                  : (v) => setState(() => _review = v ? 'guardian' : 'none'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('chore-date'),
              controller: _date,
              enabled: !_locked,
              decoration: InputDecoration(
                labelText: 'Household date',
                hintText: 'YYYY-MM-DD',
                suffixIcon: IconButton(
                  tooltip: 'Pick household date',
                  onPressed: _locked
                      ? null
                      : () async {
                          final current = _validDate(_date.text)
                              ? parseCivilDate(_date.text)
                              : null;
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: current,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100, 12, 31),
                            helpText: 'Choose a household date',
                          );
                          if (picked != null && mounted) {
                            _date.text = civilDate(picked);
                          }
                        },
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ),
              validator: (v) => _validDate(v?.trim() ?? '')
                  ? null
                  : 'Enter a valid date: YYYY-MM-DD.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Timing'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Any time')),
                DropdownMenuItem(value: 'time', child: Text('At a time')),
                DropdownMenuItem(value: 'deadline', child: Text('Deadline')),
                DropdownMenuItem(value: 'range', child: Text('Time window')),
              ],
              onChanged: _locked ? null : (v) => setState(() => _kind = v!),
            ),
            if (_kind == 'time' || _kind == 'deadline') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _at,
                enabled: !_locked,
                decoration: const InputDecoration(
                  labelText: 'Household time (24-hour)',
                  hintText: '18:00',
                ),
                validator: (v) =>
                    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Use HH:mm, for example 18:00.',
              ),
            ],
            if (_kind == 'range') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _start,
                enabled: !_locked,
                decoration: const InputDecoration(
                  labelText: 'Window starts',
                  hintText: 'YYYY-MM-DDTHH:mm',
                ),
                validator: (v) =>
                    _validLocal(v?.trim() ?? '') &&
                        v!.trim().startsWith('${_date.text.trim()}T')
                    ? null
                    : 'Use the household date and a time: YYYY-MM-DDTHH:mm.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _end,
                enabled: !_locked,
                decoration: const InputDecoration(
                  labelText: 'Window ends',
                  hintText: 'YYYY-MM-DDTHH:mm',
                ),
                validator: (v) => _validLocal(v?.trim() ?? '') ? null : 'Use YYYY-MM-DDTHH:mm. End must follow start, within seven days.',
              ),
            ],
            const SizedBox(height: 28),
            if (_submitted != null && !_busy && !_conflict)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Retry keeps the same details and prevents duplicate chores. Return to your list to check an uncertain save.',
                ),
              ),
            FilledButton(
              onPressed: _busy || _conflict ? null : _save,
              child: Text(
                _busy
                    ? 'Confirming chore…'
                    : _submitted != null
                    ? 'Retry save'
                    : 'Save chore',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
