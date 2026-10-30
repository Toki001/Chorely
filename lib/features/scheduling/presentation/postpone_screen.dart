import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/page_frame.dart';
import '../../chores/domain/chore_repository.dart';
import '../../dashboard/domain/calendar_dates.dart';
import '../domain/postponement_repository.dart';

class PostponeScreen extends StatefulWidget {
  const PostponeScreen({
    required this.householdId,
    required this.base,
    required this.repository,
    super.key,
  });
  final String householdId;
  final ChoreOccurrence base;
  final PostponementRepository repository;
  @override
  State<PostponeScreen> createState() => _PostponeScreenState();
}

class _PostponeScreenState extends State<PostponeScreen> {
  final _form = GlobalKey<FormState>();
  late final _date = TextEditingController(
    text: civilDate(
      parseCivilDate(widget.base.localDate).add(const Duration(days: 1)),
    ),
  );
  late final _time = TextEditingController(
    text: widget.base.effectiveDueLocal?.substring(11, 16) ?? '18:00',
  );
  PostponementRequest? _request;
  bool _busy = false, _review = false;
  String? _error;
  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _review || !_form.currentState!.validate()) return;
    _request ??= PostponementRequest(
      householdId: widget.householdId,
      occurrenceId: widget.base.id,
      commandId: const Uuid().v4(),
      baseVersion: widget.base.version,
      schedule: {
        'kind': 'deadline',
        'date': _date.text.trim(),
        'at': _time.text.trim(),
      },
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.postpone(_request!);
      if (mounted) Navigator.of(context).pop(true);
    } on ChoreFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _review = e.conflict || !e.retryable;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t confirm the new deadline. Retry the same request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      await widget.repository.refresh(widget.householdId, widget.base.id);
      if (mounted) Navigator.of(context).pop(false);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Postpone this occurrence')),
    body: PageFrame(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.base.draft.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Current: ${widget.base.timingLabel}\n${widget.base.timezone}',
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose a later deadline within the next 30 household days. This occurrence keeps its identity and history. Other turns keep their schedule.',
            ),
            const SizedBox(height: 12),
            const Text(
              'A time window becomes the single deadline you choose here. An untimed chore must move to a later day.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const ValueKey('postpone-date'),
              controller: _date,
              enabled: _request == null && !_busy,
              decoration: const InputDecoration(
                labelText: 'New date (YYYY-MM-DD)',
                errorMaxLines: 3,
              ),
              keyboardType: TextInputType.datetime,
              validator: (v) {
                try {
                  parseCivilDate(v?.trim() ?? '');
                  return null;
                } catch (_) {
                  return 'Enter a valid calendar date.';
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('postpone-time'),
              controller: _time,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              enabled: _request == null && !_busy,
              decoration: const InputDecoration(
                labelText: 'New deadline (HH:MM)',
                errorMaxLines: 3,
              ),
              keyboardType: TextInputType.datetime,
              validator: (v) =>
                  RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Use a time from 00:00 to 23:59.',
            ),
            const SizedBox(height: 24),
            if (_error != null) InlineError(_error!),
            if (_request != null && !_review)
              const Text(
                'This change is waiting for confirmation. Retry keeps its date, time and request ID unchanged.',
              ),
            if (_review)
              TextButton(
                onPressed: _busy ? null : _reload,
                child: const Text('Reload current chore'),
              )
            else
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? 'Confirming deadline…'
                      : _request == null
                      ? 'Confirm later deadline'
                      : 'Retry same request',
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
