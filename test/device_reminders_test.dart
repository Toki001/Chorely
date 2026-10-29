import 'dart:async';

import 'package:chorely/features/notifications/domain/device_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 10, 29, 12);
DeviceReminder reminder(String id, int minute) => DeviceReminder(
  id: id,
  at: now.add(Duration(minutes: minute)),
  expires: now.add(const Duration(hours: 1)),
  title: 'Your household',
  body: 'A chore is ready.',
  payload: id,
);

class Plans implements ReminderPlanRepository {
  final signals = StreamController<void>.broadcast();
  List<DeviceReminder> rows = [];
  bool enabled = true;
  Completer<LocalReminderPlan>? delayed;
  @override
  Future<LocalReminderPlan> localPlan(String householdId) async =>
      delayed?.future ??
      LocalReminderPlan(
        actorId: 'child',
        enabled: enabled,
        serverNow: now,
        reminders: rows,
      );
  @override
  Stream<void> watchPlan(String householdId, String actorId) => signals.stream;
}

class Ledger implements ReminderLedger {
  bool enabled = true;
  final records =
      <String, ({int id, bool attempted, DateTime at, bool pending})>{};
  int next = 0;
  @override
  Future<bool> optedIn(String scope) async => enabled;
  @override
  Future<void> optIn(String scope, bool value) async {
    enabled = value;
  }

  @override
  Future<({int id, bool attempt})> claim(
    DeviceReminder reminder,
    DateTime time,
  ) async {
    final old = records[reminder.id];
    final already = old != null && (old.attempted || !old.at.isAfter(time));
    final id = old?.id ?? ++next;
    records[reminder.id] = (
      id: id,
      attempted: already || !reminder.at.isAfter(time),
      at: reminder.at,
      pending: true,
    );
    return (id: id, attempt: !already);
  }

  @override
  Future<Map<String, int>> pending() async => {
    for (final r in records.entries)
      if (r.value.pending) r.key: r.value.id,
  };
  @override
  Future<void> cancelled(String id) async {
    final r = records[id]!;
    records[id] = (id: r.id, attempted: r.attempted, at: r.at, pending: false);
  }
}

class Device implements ReminderDevice {
  bool allowed = true;
  int prompts = 0, clears = 0;
  final scheduled = <int, DeviceReminder>{};
  final shown = <int>[];
  final cancelled = <int>[];
  @override
  Future<bool> permission({bool request = false}) async {
    if (request) prompts++;
    return allowed;
  }

  @override
  Future<void> cancelAll() async {
    clears++;
    scheduled.clear();
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<void> schedule(int id, DeviceReminder r) async {
    scheduled[id] = r;
  }

  @override
  Future<void> show(int id, DeviceReminder r) async {
    shown.add(id);
  }
}

void main() {
  late Plans plans;
  late Ledger ledger;
  late Device device;
  late DeviceReminderController controller;
  setUp(() {
    plans = Plans();
    ledger = Ledger();
    device = Device();
    controller = DeviceReminderController(plans, ledger, device);
  });
  tearDown(() async {
    controller.dispose();
    await plans.signals.close();
  });
  Future<void> bind() async {
    controller.bind('device', 'home', 'child');
    await controller.refresh();
  }

  test('Permission denial keeps in-app fallback and never schedules', () async {
    ledger.enabled = false;
    device.allowed = false;
    plans.rows = [reminder('due', 10)];
    await bind();
    expect(device.prompts, 0);
    await controller.setEnabled(true);
    expect(device.prompts, 1);
    expect(ledger.enabled, false);
    expect(device.scheduled, isEmpty);
    expect(controller.status, contains('in-app'));
  });
  test('Startup suppresses old alerts, repeated plans replace future IDs, new events alert once', () async {
    plans.rows = [reminder('old', -1), reminder('due', 10)];
    await bind();
    expect(device.shown, isEmpty);
    expect(device.scheduled.length, 1);
    final id = device.scheduled.keys.single;
    await controller.refresh();
    expect(device.scheduled.keys.single, id);
    plans.rows = [...plans.rows, reminder('new', 0)];
    await controller.refresh();
    await controller.refresh();
    expect(device.shown.length, 1);
  });
  test(
    'Durable attempt survives a controller restart without replaying the alert',
    () async {
      await bind();
      plans.rows = [reminder('new', 0)];
      await controller.refresh();
      expect(device.shown.length, 1);
      controller.dispose();
      controller = DeviceReminderController(plans, ledger, device);
      await bind();
      await controller.refresh();
      expect(device.shown.length, 1);
    },
  );
  test('Completion cancellation removes pending OS alarm', () async {
    plans.rows = [reminder('due', 10)];
    await bind();
    plans.rows = [];
    await controller.refresh();
    expect(device.cancelled.length, 1);
    expect(device.scheduled, isEmpty);
  });
  test('Disabling profile policy or OS permission removes alarms', () async {
    plans.rows = [reminder('due', 10)];
    await bind();
    plans.enabled = false;
    await controller.refresh();
    expect(device.scheduled, isEmpty);
    plans.enabled = true;
    await controller.refresh();
    expect(device.scheduled.length, 1);
    device.allowed = false;
    await controller.refresh();
    expect(device.scheduled, isEmpty);
  });
  test(
    'Logout invalidates a delayed plan before it can show or schedule',
    () async {
      plans.rows = [reminder('due', 10)];
      await bind();
      plans.delayed = Completer();
      final pending = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      controller.identity(null);
      plans.delayed!.complete(
        LocalReminderPlan(
          actorId: 'child',
          enabled: true,
          serverNow: now,
          reminders: plans.rows,
        ),
      );
      await pending;
      await controller.refresh();
      expect(device.scheduled, isEmpty);
    },
  );
  test('Plan signal errors revoke local scope and cancel alarms', () async {
    plans.rows = [reminder('due', 10)];
    await bind();
    plans.signals.addError(StateError('revoked'));
    await Future<void>.delayed(Duration.zero);
    await controller.refresh();
    expect(device.scheduled, isEmpty);
    expect(controller.optedIn, false);
  });
  test('Global plan is capped at 60 pending alerts', () async {
    plans.rows = List.generate(75, (i) => reminder('alert$i', i + 1));
    await bind();
    expect(device.scheduled.length, 60);
  });
  test('A quiet-hour preference edit cannot reschedule an already attempted logical alert', () async {
    await bind();
    plans.rows = [reminder('new', 0)];
    await controller.refresh();
    expect(device.shown.length, 1);
    plans.rows = [reminder('new', 30)];
    await controller.refresh();
    expect(device.scheduled, isEmpty);
    expect(device.shown.length, 1);
  });
}
