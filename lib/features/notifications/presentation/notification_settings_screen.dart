import 'device_reminder_scope.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/page_frame.dart';
import '../../chores/domain/chore_repository.dart';
import '../../family/domain/family_repository.dart';
import '../../households/domain/household_repository.dart';
import '../domain/notifications_repository.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    required this.home,
    required this.actor,
    required this.repository,
    required this.family,
    super.key,
  });
  final Household home;
  final ChoreActor actor;
  final NotificationsRepository repository;
  final FamilyRepository family;
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final _people = widget.family.watchPeople(widget.home.id);
  late String _target = widget.actor.id;
  NotificationSettings? _settings;
  NotificationPreferences? _draft, _submitted;
  String? _command, _error;
  bool _loading = true, _busy = false, _blocked = false;
  bool get _locked => _busy || _submitted != null;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _settings = null;
      _error = null;
      _submitted = null;
      _command = null;
      _blocked = false;
    });
    try {
      final value = await widget.repository.load(
        widget.home.id,
        actorId: _target,
      );
      if (mounted) {
        setState(() {
          _settings = value;
          _draft = value.preferences;
        });
      }
    } on NotificationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Couldn’t load notification settings. Check your connection and access.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_draft!.quietStart == _draft!.quietEnd) {
      setState(
        () => _error = 'Choose different quiet-hour start and end times.',
      );
      return;
    }
    _submitted ??= _draft;
    _command ??= const Uuid().v4();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        widget.home.id,
        _command!,
        _settings!,
        _submitted!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification preferences saved.')),
        );
        Navigator.of(context).pop();
      }
    } on NotificationFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _blocked = !e.retryable || e.conflict;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t confirm your settings. Retry the same request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime(bool start) async {
    final text = start ? _draft!.quietStart : _draft!.quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(text.substring(0, 2)),
        minute: int.parse(text.substring(3)),
      ),
    );
    if (picked != null && mounted) {
      final value =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(
        () => _draft = start
            ? _draft!.copyWith(quietStart: value)
            : _draft!.copyWith(quietEnd: value),
      );
    }
  }

  Widget _toggle(String label, bool value, void Function(bool) onChange) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: !_settings!.canEdit || _locked
            ? null
            : (v) => setState(() => onChange(v)),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification preferences')),
    body: PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A gentle heads-up.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'In-app updates stay available without device alerts. Quiet hours apply to optional device alerts.',
          ),
          const SizedBox(height: 20),
          if (widget.actor.guardian)
            StreamBuilder<List<FamilyPerson>>(
              key: const ValueKey('notification-target-roster'),
              stream: _people,
              builder: (context, people) => DropdownButtonFormField<String>(
                key: ValueKey('notification-target-$_target'),
                initialValue: _target,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Settings for'),
                items: [
                  DropdownMenuItem(
                    value: widget.actor.id,
                    child: const Text('Me'),
                  ),
                  for (final p in people.data ?? <FamilyPerson>[])
                    if (p.active && p.role == 'child')
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.nickname,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  if (_target != widget.actor.id &&
                      !(people.data ?? <FamilyPerson>[]).any(
                        (p) => p.id == _target && p.active && p.role == 'child',
                      ))
                    DropdownMenuItem(
                      value: _target,
                      child: const Text('Profile unavailable'),
                    ),
                ],
                onChanged: _locked || _loading
                    ? null
                    : (v) {
                        _target = v!;
                        _load();
                      },
              ),
            ),
          const SizedBox(height: 12),
          if (_error != null) InlineError(_error!),
          if (_loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading notification settings',
            ),
          if (!_loading && _settings == null)
            TextButton(onPressed: _load, child: const Text('Reload settings')),
          if (_settings != null) ...[
            if (_target == widget.actor.id &&
                DeviceReminderScope.maybeOf(context) != null)
              ListenableBuilder(
                listenable: DeviceReminderScope.maybeOf(context)!,
                builder: (context, _) {
                  final controller = DeviceReminderScope.maybeOf(context)!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(controller.status),
                      const Text(
                        'Alerts follow this home while it is open. Leaving or signing out clears them.',
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow alerts on this device'),
                        value: controller.optedIn,
                        onChanged: (v) => controller.setEnabled(v),
                      ),
                      TextButton(
                        onPressed: controller.refresh,
                        child: const Text('Refresh device reminders'),
                      ),
                    ],
                  );
                },
              ),
            DropdownButtonFormField<String>(
              key: ValueKey('notification-channel-$_target-${_draft!.channel}'),
              initialValue: _draft!.channel,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reminder channel'),
              items: [
                const DropdownMenuItem(
                  value: 'in_app',
                  child: Text('In-app updates'),
                ),
                const DropdownMenuItem(
                  value: 'local',
                  child: Text('Device reminders'),
                ),
                if (_draft!.channel == 'push')
                  const DropdownMenuItem(
                    value: 'push',
                    child: Text('Remote alerts'),
                  ),
              ],
              onChanged: !_settings!.canEdit || _locked
                  ? null
                  : (v) =>
                        setState(() => _draft = _draft!.copyWith(channel: v)),
            ),
            Text('Household timezone: ${_settings!.timezone}'),
            if (!_settings!.canEdit)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Your guardian manages these settings. Device permission can still be turned off in system settings.',
                ),
              ),
            _toggle(
              'Household updates',
              _draft!.enabled,
              (v) => _draft = _draft!.copyWith(enabled: v),
            ),
            _toggle(
              'New assignments',
              _draft!.assignment,
              (v) => _draft = _draft!.copyWith(assignment: v),
            ),
            _toggle(
              'Due reminders',
              _draft!.due,
              (v) => _draft = _draft!.copyWith(due: v),
            ),
            _toggle(
              'One gentle overdue reminder',
              _draft!.overdue,
              (v) => _draft = _draft!.copyWith(overdue: v),
            ),
            _toggle(
              'Review updates',
              _draft!.review,
              (v) => _draft = _draft!.copyWith(review: v),
            ),
            _toggle(
              'Help updates',
              _draft!.help,
              (v) => _draft = _draft!.copyWith(help: v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _draft!.reminderMinutes,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Advance reminder'),
              items: [
                for (final minutes in [0, 5, 15, 30, 60])
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(
                      minutes == 0
                          ? 'No advance reminder'
                          : '$minutes minutes before',
                    ),
                  ),
              ],
              onChanged: !_settings!.canEdit || _locked
                  ? null
                  : (v) => setState(
                      () => _draft = _draft!.copyWith(reminderMinutes: v),
                    ),
            ),
            _toggle(
              'Quiet hours for device alerts',
              _draft!.quietEnabled,
              (v) => _draft = _draft!.copyWith(quietEnabled: v),
            ),
            OutlinedButton(
              onPressed: !_settings!.canEdit || _locked
                  ? null
                  : () => _pickTime(true),
              child: Text('Quiet hours start · ${_draft!.quietStart}'),
            ),
            OutlinedButton(
              onPressed: !_settings!.canEdit || _locked
                  ? null
                  : () => _pickTime(false),
              child: Text('Quiet hours end · ${_draft!.quietEnd}'),
            ),
            const SizedBox(height: 20),
            if (_settings!.canEdit && !_blocked)
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? 'Saving settings…'
                      : _submitted == null
                      ? 'Save preferences'
                      : 'Retry same settings',
                ),
              ),
            if (_blocked)
              TextButton(
                onPressed: _load,
                child: const Text('Reload settings'),
              ),
          ],
        ],
      ),
    ),
  );
}
