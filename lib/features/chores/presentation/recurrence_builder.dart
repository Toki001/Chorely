import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/page_frame.dart';
import '../../family/domain/family_repository.dart';
import '../../households/domain/household_repository.dart';
import '../domain/chore_repository.dart';
import '../domain/recurrence_repository.dart';

class RecurrenceBuilder extends StatefulWidget {
  const RecurrenceBuilder({
    required this.home,
    required this.base,
    required this.repository,
    required this.family,
    this.configuration,
    super.key,
  });
  final Household home;
  final ChoreOccurrence base;
  final RecurrenceRepository repository;
  final FamilyRepository family;
  final RecurrenceConfiguration? configuration;
  @override
  State<RecurrenceBuilder> createState() => _RecurrenceBuilderState();
}

class _RecurrenceBuilderState extends State<RecurrenceBuilder> {
  final _form = GlobalKey<FormState>();
  final _commandId = const Uuid().v4();
  late final _people = widget.family.watchPeople(widget.home.id);
  Map<String, Object?> get _initial => widget.configuration?.rule ?? {};
  Map<String, Object?> get _initialTiming =>
      Map<String, Object?>.from(_initial['timing'] as Map? ?? {});
  Map<String, Object?> get _initialRotation =>
      Map<String, Object?>.from(_initial['rotation'] as Map? ?? {});
  String _baseTime(String key, String fallback) {
    final value = widget.base.draft.schedule[key] as String?;
    return value != null && value.length == 16 ? value.substring(11) : fallback;
  }

  int get _baseEndOffset {
    final start = widget.base.draft.schedule['startLocal'] as String?;
    final end = widget.base.draft.schedule['endLocal'] as String?;
    if (start == null || end == null) return 0;
    return DateTime.parse('${end.substring(0, 10)}T00:00:00Z')
        .difference(DateTime.parse('${start.substring(0, 10)}T00:00:00Z'))
        .inDays;
  }

  late final _start = TextEditingController(
    text:
        _initial['startDate'] as String? ??
        widget.base.draft.schedule['date'] as String?,
  );
  final _effective = TextEditingController();
  late final _end = TextEditingController(text: _initial['endDate'] as String?);
  late final _count = TextEditingController(
    text: _initial['count']?.toString(),
  );
  late final _monthDay = TextEditingController(
    text: _initial['monthDay']?.toString() ?? '1',
  );
  late final _at = TextEditingController(
    text:
        _initialTiming['at'] as String? ??
        widget.base.draft.schedule['at'] as String? ??
        _baseTime('startLocal', '18:00'),
  );
  late final _endAt = TextEditingController(
    text: _initialTiming['endAt'] as String? ?? _baseTime('endLocal', '19:00'),
  );
  late String _frequency = _initial['frequency'] as String? ?? 'daily';
  late String _kind =
      _initialTiming['kind'] as String? ??
      (widget.base.draft.schedule['kind'] as String? ?? 'none');
  late int _endOffset =
      (_initialTiming['endDayOffset'] as num?)?.toInt() ?? _baseEndOffset;
  late String _policy =
      _initialRotation['policy'] as String? ?? 'preserve_turn';
  late bool _paused = widget.configuration?.paused ?? false;
  late final Set<int> _weekdays = Set<int>.from(
    _initial['weekdays'] as List? ?? [1, 2, 3, 4, 5],
  );
  late final List<String> _order = List<String>.from(
    _initialRotation['order'] as List? ?? widget.base.draft.assignedActorIds,
  );
  List<FamilyPerson> _roster = [];
  RecurrencePreview? _preview;
  Map<String, Object?>? _previewRule;
  Map<String, Object?>? _submitted;
  String? _submittedDate;
  String? _submittedZone;
  String? _error;
  bool _busy = false, _conflict = false;
  bool get _locked => _busy || _submitted != null;
  List<TextEditingController> get _controllers => [
    _start,
    _effective,
    _end,
    _count,
    _monthDay,
    _at,
    _endAt,
  ];
  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted && _preview != null) {
      setState(() => _preview = null);
    }
  }

  void _change(VoidCallback action) => setState(() {
    action();
    _preview = null;
  });
  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validDate(String v) {
    if (!RegExp(r'^(20\d{2}|2100)-\d{2}-\d{2}$').hasMatch(v)) return false;
    return DateTime.tryParse('${v}T00:00:00Z')
            ?.toIso8601String()
            .startsWith('${v}T') ??
        false;
  }

  String? _dateValidator(String? value) =>
      _validDate(value?.trim() ?? '') ? null : 'Use a valid YYYY-MM-DD date.';
  String? _timeValidator(String? value) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Use 24-hour HH:mm, for example 18:00.';
  Map<String, Object?> _rule() => {
    'frequency': _frequency,
    'startDate': _start.text.trim(),
    'endDate': _end.text.trim().isEmpty ? null : _end.text.trim(),
    'count': _count.text.trim().isEmpty ? null : int.parse(_count.text.trim()),
    'weekdays': _frequency == 'weekdays'
        ? (_weekdays.toList()..sort())
        : <int>[],
    'monthDay': _frequency == 'monthly'
        ? int.parse(_monthDay.text.trim())
        : null,
    'timing': {
      'kind': _kind,
      'at': _kind == 'none' ? null : _at.text.trim(),
      'endAt': _kind == 'range' ? _endAt.text.trim() : null,
      'endDayOffset': _kind == 'range' ? _endOffset : 0,
    },
    'rotation': {'order': List<String>.from(_order), 'policy': _policy},
    'exceptions': _initial['exceptions'] ?? <Object>[],
  };
  Future<void> _loadPreview() async {
    if (!_form.currentState!.validate()) return;
    if (_order.isEmpty ||
        _order.length > 20 ||
        (_frequency == 'weekdays' && _weekdays.isEmpty)) {
      setState(
        () => _error =
            'Choose one to twenty people and at least one selected weekday.',
      );
      return;
    }
    final rule = _rule();
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final result = await widget.repository.preview(
        householdId: widget.home.id,
        templateId: widget.base.templateId,
        fromDate: _effective.text.trim(),
        paused: _paused,
        rule: rule,
      );
      if (mounted) {
        setState(() {
          _preview = result;
          _previewRule = rule;
        });
      }
    } on ChoreFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t load the preview. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_submitted == null) {
      if (_preview == null || _previewRule == null) return;
      _submitted = _previewRule;
      _submittedDate = _effective.text.trim();
      _submittedZone = _preview!.timezone;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        householdId: widget.home.id,
        templateId: widget.base.templateId,
        commandId: _commandId,
        baseTemplateVersion:
            widget.configuration?.templateVersion ??
            widget.base.templateVersion,
        baseRuleVersion: widget.configuration?.version ?? 0,
        effectiveFrom: _submittedDate!,
        expectedTimezone: _submittedZone!,
        paused: _paused,
        rule: _submitted!,
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
          () => _error =
              'Couldn’t confirm the repeat settings. Retry the same request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _name(String id) =>
      _roster.where((p) => p.id == id).firstOrNull?.nickname ??
      'Unavailable member';
  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? keyName,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: keyName == null ? null : ValueKey(keyName),
      controller: controller,
      enabled: !_locked,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorMaxLines: 4,
      ),
      validator: validator,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Repeat & take turns')),
    body: PageFrame(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A rhythm for your home.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              widget.base.draft.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (widget.configuration != null)
              Text(
                'Last saved change starts ${widget.configuration!.effectiveFrom}${widget.configuration!.paused ? ' · Paused version' : ''}.',
              ),
            Text(
              'One person takes each turn. Times follow ${_preview?.timezone ?? widget.home.timezone}.',
            ),
            const Text(
              'Monthly dates that don’t exist are skipped. When clocks change, use the first valid time; when a time repeats, use its first occurrence.',
            ),
            const SizedBox(height: 24),
            if (_error != null) InlineError(_error!),
            _field(
              _start,
              'Rotation anchor date',
              hint: 'YYYY-MM-DD',
              keyName: 'repeat-start',
              validator: _dateValidator,
            ),
            _field(
              _effective,
              'Changes begin on',
              hint: 'Future household date: YYYY-MM-DD',
              keyName: 'repeat-effective',
              validator: _dateValidator,
            ),
            const Text(
              'Choose tomorrow through the next thirty household days. Future settings from this date are replaced. Today’s chore keeps its assignment; recorded work keeps its history.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekdays', child: Text('Weekdays')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              ],
              onChanged: _locked ? null : (v) => _change(() => _frequency = v!),
            ),
            if (_frequency == 'weekdays')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 1; i <= 7; i++)
                      FilterChip(
                        label: Text(
                          const [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ][i - 1],
                        ),
                        selected: _weekdays.contains(i),
                        onSelected: _locked
                            ? null
                            : (v) => _change(() {
                                v ? _weekdays.add(i) : _weekdays.remove(i);
                              }),
                      ),
                  ],
                ),
              ),
            if (_frequency == 'weekly')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Weekly turns use the weekday of the anchor date.'),
              ),
            if (_frequency == 'monthly')
              _field(
                _monthDay,
                'Day of the month',
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n != null && n >= 1 && n <= 31
                      ? null
                      : 'Choose 1 to 31.';
                },
              ),
            const SizedBox(height: 16),
            _field(
              _end,
              'End date (optional)',
              hint: 'YYYY-MM-DD',
              validator: (v) =>
                  v?.trim().isEmpty ?? true ? null : _dateValidator(v),
            ),
            _field(
              _count,
              'Total turns (optional)',
              validator: (v) {
                if (v?.trim().isEmpty ?? true) return null;
                final n = int.tryParse(v!);
                return n != null && n >= 1 && n <= 3660
                    ? null
                    : 'Choose 1 to 3660 turns.';
              },
            ),
            const Text(
              'A count starts at the anchor date, including earlier turns.',
            ),
            const SizedBox(height: 20),
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
              onChanged: _locked ? null : (v) => _change(() => _kind = v!),
            ),
            const SizedBox(height: 16),
            if (_kind != 'none')
              _field(
                _at,
                _kind == 'range'
                    ? 'Window starts (24-hour)'
                    : 'Household time (24-hour)',
                validator: _timeValidator,
              ),
            if (_kind == 'range') ...[
              _field(
                _endAt,
                'Window ends (24-hour)',
                validator: _timeValidator,
              ),
              DropdownButtonFormField<int>(
                initialValue: _endOffset,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Window ends on'),
                items: [
                  for (var i = 0; i <= 7; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        i == 0
                            ? 'Same date'
                            : i == 1
                            ? 'Next day'
                            : '+$i days',
                      ),
                    ),
                ],
                onChanged: _locked
                    ? null
                    : (v) => _change(() => _endOffset = v!),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Choose the turn order',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            StreamBuilder<List<FamilyPerson>>(
              key: const ValueKey('repeat-roster'),
              stream: _people,
              builder: (context, s) {
                if (s.hasError) {
                  return const InlineError(
                    'Couldn’t load current household members. Return to the chore details and try again.',
                  );
                }
                if (!s.hasData) {
                  return const LinearProgressIndicator(
                    semanticsLabel: 'Loading household members',
                  );
                }
                _roster = s.data!;
                return Column(
                  children: [
                    for (final p in _roster.where((p) => p.active))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.nickname),
                        subtitle: Text(p.role),
                        value: _order.contains(p.id),
                        onChanged: _locked
                            ? null
                            : (v) => _change(() {
                                v! ? _order.add(p.id) : _order.remove(p.id);
                              }),
                      ),
                    for (var i = 0; i < _order.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${i + 1}. ${_name(_order[i])}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Move ${_name(_order[i])} earlier',
                              onPressed: _locked || i == 0
                                  ? null
                                  : () => _change(() {
                                      final id = _order.removeAt(i);
                                      _order.insert(i - 1, id);
                                    }),
                              icon: const Icon(Icons.arrow_upward_rounded),
                            ),
                            IconButton(
                              tooltip:
                                  'Remove ${_name(_order[i])} from turn order',
                              onPressed: _locked
                                  ? null
                                  : () => _change(() => _order.removeAt(i)),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use the next available person'),
              subtitle: Text(
                _policy == 'preserve_turn'
                    ? 'Keep an unavailable person’s slot empty. Later turns keep their order.'
                    : 'Substitute for that date. Later turns keep their order.',
              ),
              value: _policy == 'give_to_next_eligible',
              onChanged: _locked
                  ? null
                  : (v) => _change(
                      () => _policy = v
                          ? 'give_to_next_eligible'
                          : 'preserve_turn',
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pause from the effective date'),
              value: _paused,
              onChanged: _locked ? null : (v) => _change(() => _paused = v),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _locked ? null : _loadPreview,
              child: Text(
                _busy && _submitted == null
                    ? 'Loading preview…'
                    : 'Preview next 14 days',
              ),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 20),
              Text(
                'Your upcoming turns',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'This is a preview. Save the settings to share these turns.',
              ),
              if (!_preview!.paused && _preview!.turns.isEmpty)
                const Text(
                  'No turns in this fourteen-day window. Check the dates, count and monthly rule.',
                ),
              if (_preview!.paused)
                const Text('No turns from this version while it is paused.'),
              for (final turn in _preview!.turns)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(turn.date),
                  subtitle: Text(
                    turn.status == 'skipped'
                        ? 'Skipped · ${_name(turn.plannedActorId)} · ${recurrenceReasonLabel(turn.reason)}'
                        : '${turn.assignedActorIds.map(_name).join(', ')}${turn.reason == 'substitute' ? ' · Substitute' : ''}${turn.timeAdjusted ? ' · Clock time adjusted' : ''}',
                  ),
                ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed:
                  _busy || _conflict || (_preview == null && _submitted == null)
                  ? null
                  : _save,
              child: Text(
                _busy && _submitted != null
                    ? 'Confirming settings…'
                    : _submitted == null
                    ? 'Save repeat settings'
                    : 'Retry repeat save',
              ),
            ),
            if (_submitted != null && !_busy && !_conflict)
              const Text(
                'Retry keeps this request unchanged. Return to your chores to check an uncertain save.',
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
