import 'dart:async';

import 'package:flutter/foundation.dart';

class DeviceReminder {
  const DeviceReminder({
    required this.id,
    required this.at,
    required this.expires,
    required this.title,
    required this.body,
    required this.payload,
  });
  final String id, title, body, payload;
  final DateTime at, expires;
}

class LocalReminderPlan {
  const LocalReminderPlan({
    required this.actorId,
    required this.enabled,
    required this.serverNow,
    required this.reminders,
    this.hasMore = false,
  });
  final String actorId;
  final bool enabled, hasMore;
  final DateTime serverNow;
  final List<DeviceReminder> reminders;
}

abstract interface class ReminderPlanRepository {
  Future<LocalReminderPlan> localPlan(String householdId);
  Stream<void> watchPlan(String householdId, String actorId);
}

abstract interface class ReminderDevice {
  Future<bool> permission({bool request = false});
  Future<void> cancelAll();
  Future<void> cancel(int id);
  Future<void> schedule(int id, DeviceReminder reminder);
  Future<void> show(int id, DeviceReminder reminder);
}

abstract interface class ReminderLedger {
  Future<bool> optedIn(String scope);
  Future<void> optIn(String scope, bool value);

  /// Durably claims an attempt before contacting the OS. A crash can lose an
  /// alert, but cannot replay an immediate attempt after a process restart.
  Future<({int id, bool attempt})> claim(DeviceReminder reminder, DateTime now);
  Future<Map<String, int>> pending();
  Future<void> cancelled(String id);
}

/// One active profile/household owns this installation's local alerts. All OS
/// mutations are serialized, including logout/revocation and delayed requests.
class DeviceReminderController extends ChangeNotifier {
  DeviceReminderController(this.plans, this.ledger, this.device);
  final ReminderPlanRepository plans;
  final ReminderLedger ledger;
  final ReminderDevice device;
  String? _uid, _scope, _household, _actor;
  int _generation = 0;
  bool _first = true, _optedIn = false;
  StreamSubscription<void>? _signal;
  Timer? _timer;
  Future<void> _tail = Future.value();
  String status = 'Device alerts are off. Your in-app updates are available.';
  bool get optedIn => _optedIn;
  Future<void> _enqueue(Future<void> Function() run) {
    final next = _tail.then((_) => run());
    _tail = next.catchError((Object _) {
      status =
          'Couldn’t refresh device alerts. In-app updates are still available.';
      notifyListeners();
    });
    return _tail;
  }

  void identity(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    clear();
  }

  void clear() {
    _generation++;
    _scope = _household = _actor = null;
    _optedIn = false;
    _signal?.cancel();
    _signal = null;
    _timer?.cancel();
    _timer = null;
    unawaited(
      _enqueue(() async {
        await device.cancelAll();
      }),
    );
  }

  void unbind(String household) {
    if (_household == household) clear();
  }

  void bind(String uid, String household, String actor) {
    if (_uid != uid) identity(uid);
    final scope = '$uid/$household/$actor';
    if (_scope == scope) return;
    clear();
    _scope = scope;
    _household = household;
    _actor = actor;
    _first = true;
    final generation = _generation;
    _signal = plans
        .watchPlan(household, actor)
        .listen(
          (_) => refresh(),
          onError: (Object _) {
            clear();
          },
        );
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    unawaited(
      _enqueue(() async {
        final enabled = await ledger.optedIn(scope);
        if (generation != _generation) return;
        _optedIn = enabled;
        await _sync(generation);
      }),
    );
  }

  Future<void> setEnabled(bool enabled) => _enqueue(() async {
    final scope = _scope, generation = _generation;
    if (scope == null) return;
    if (enabled && !await device.permission(request: true)) {
      if (generation == _generation) {
        status =
            'Device permission is off. You can still use your in-app updates.';
        notifyListeners();
      }
      return;
    }
    if (generation != _generation) return;
    await ledger.optIn(scope, enabled);
    if (generation != _generation) return;
    _optedIn = enabled;
    await _sync(generation);
  });
  Future<void> refresh() {
    final generation = _generation;
    return _enqueue(() => _sync(generation));
  }

  Future<void> _sync(int generation) async {
    if (generation != _generation || _scope == null) return;
    if (!_optedIn || !await device.permission()) {
      await device.cancelAll();
      if (generation == _generation) {
        status = _optedIn
            ? 'Device permission is off. In-app updates are available.'
            : 'Device alerts are off. Your in-app updates are available.';
        notifyListeners();
      }
      return;
    }
    final plan = await plans.localPlan(_household!);
    if (generation != _generation || plan.actorId != _actor) return;
    if (!plan.enabled) {
      await device.cancelAll();
      status = 'This profile uses in-app updates. A guardian can allow device reminders.';
      notifyListeners();
      return;
    }
    final reminders = plan.reminders
        .where((r) => r.expires.isAfter(plan.serverNow))
        .take(60)
        .toList();
    final ids = reminders.map((r) => r.id).toSet();
    for (final entry in (await ledger.pending()).entries) {
      if (!ids.contains(entry.key)) {
        await device.cancel(entry.value);
        await ledger.cancelled(entry.key);
      }
    }
    for (final reminder in reminders) {
      if (generation != _generation) return;
      final claim = await ledger.claim(reminder, plan.serverNow);
      if (generation != _generation) return;
      if (reminder.at.isAfter(plan.serverNow) && claim.attempt) {
        // Replacing the same OS identifier updates a pending alert, never adds a copy.
        await device.schedule(claim.id, reminder);
      } else if (!_first && claim.attempt) {
        await device.show(claim.id, reminder);
      }
    }
    _first = false;
    status = plan.hasMore
        ? 'Device reminders refreshed. More will be added as space becomes available.'
        : 'Device reminders refreshed. Delivery depends on your device and connection.';
    notifyListeners();
  }

  @override
  void dispose() {
    _signal?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
