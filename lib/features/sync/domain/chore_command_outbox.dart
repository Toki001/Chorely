import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../chores/domain/chore_repository.dart';

/// Immutable wire intent. Neither retry nor cache refresh may advance its base.
class ChoreCommand {
  ChoreCommand({
    required this.id,
    required this.uid,
    required this.householdId,
    required this.occurrenceId,
    required this.action,
    required this.baseVersion,
    this.note = '',
    this.targetActorId,
  }) {
    final validId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (![id, uid, householdId, occurrenceId].every(validId.hasMatch) ||
        baseVersion < 1 ||
        !const [
          'complete',
          'undo',
          'help',
          'approve',
          'redo',
          'resolve_help',
        ].contains(action) ||
        note.length > 500 ||
        (targetActorId != null && !validId.hasMatch(targetActorId!))) {
      throw const FormatException('Invalid local chore request');
    }
  }
  final String id, uid, householdId, occurrenceId, action, note;
  final int baseVersion;
  final String? targetActorId;
  Map<String, Object?> toMap() => {
    'id': id,
    'uid': uid,
    'householdId': householdId,
    'occurrenceId': occurrenceId,
    'action': action,
    'baseVersion': baseVersion,
    'note': note,
    'targetActorId': targetActorId,
  };
  String get canonical => jsonEncode(toMap());
  factory ChoreCommand.fromMap(Map<String, dynamic> d) => ChoreCommand(
    id: d['id'] as String,
    uid: d['uid'] as String,
    householdId: d['householdId'] as String,
    occurrenceId: d['occurrenceId'] as String,
    action: d['action'] as String,
    baseVersion: d['baseVersion'] as int,
    note: d['note'] as String,
    targetActorId: d['targetActorId'] as String?,
  );
}

class StoredChoreCommand {
  const StoredChoreCommand({
    required this.command,
    required this.state,
    required this.attempts,
    required this.nextAttempt,
    this.message,
  });
  final ChoreCommand command;
  final String state;
  final int attempts;
  final DateTime nextAttempt;
  final String? message;
  bool get pending => state == 'pending';
  bool get blocked => state == 'conflict' || state == 'rejected';
}

class OutboxFailure implements Exception {
  const OutboxFailure(this.message);
  final String message;
}

abstract interface class ChoreCommandStore {
  Future<void> retainIdentity(String? uid);
  Future<void> enqueue(ChoreCommand command);
  Future<List<StoredChoreCommand>> read(String uid);
  Future<void> update(
    String uid,
    String id, {
    required String state,
    required int attempts,
    required DateTime nextAttempt,
    String? message,
  });
  Future<void> remove(String uid, String id);
  Future<void> purgeHousehold(String uid, String householdId);
}

typedef ChoreCommandSender = Future<void> Function(ChoreCommand command);

/// Persist first, then send. Only a trusted acknowledgement changes local receipt
/// state; actual chore status/counts always come from stored server occurrences.
class ChoreCommandOutbox extends ChangeNotifier {
  ChoreCommandOutbox(
    this.store,
    this.send, {
    DateTime Function()? now,
    this.automatic = true,
  }) : now = now ?? DateTime.now;
  final ChoreCommandStore store;
  final ChoreCommandSender send;
  final DateTime Function() now;
  final bool automatic;
  String? _uid;
  int _generation = 0;
  bool _draining = false, _disposed = false;
  Timer? _timer;
  Future<void> _identityReady = Future.value();
  List<StoredChoreCommand> _rows = [];
  final _revokedHouseholds = <String>{};
  String? storageError;
  List<StoredChoreCommand> get rows => List.unmodifiable(_rows);
  StoredChoreCommand? forOccurrence(
    String hid,
    String oid,
    int currentVersion,
  ) {
    final matches = _rows
        .where(
          (r) => r.command.householdId == hid && r.command.occurrenceId == oid,
        )
        .toList();
    return matches.where((r) => r.pending || r.blocked).firstOrNull ??
        matches
            .where(
              (r) =>
                  r.state == 'accepted' &&
                  r.command.baseVersion >= currentVersion,
            )
            .lastOrNull;
  }

  Future<void> recover() async {
    await _identityReady;
    try {
      await store.retainIdentity(_uid);
      await _reload(_generation);
      await drain();
    } catch (_) {
      _storageFailure();
    }
  }

  bool _suspended = false;
  void suspend() {
    if (_suspended) return;
    _suspended = true;
    _uid = null;
    _generation++;
    _rows = [];
    _timer?.cancel();
    // An auth restoration/error is not evidence of logout. Keep durable data
    // isolated until an actual authenticated identity or signed-out state arrives.
  }

  void identity(String? uid) {
    if (!_suspended && _uid == uid && _generation != 0) return;
    _suspended = false;
    _uid = uid;
    final generation = ++_generation;
    _rows = [];
    storageError = null;
    _revokedHouseholds.clear();
    _timer?.cancel();
    _identityReady = _identityReady
        .then((_) async {
          // Startup also purges another identity's unfinished data after process kill.
          await store.retainIdentity(uid);
          if (uid != null && generation == _generation) {
            await _reload(generation);
          }
        })
        .catchError((Object _) {
          if (generation == _generation) _storageFailure();
        });
    if (uid != null && automatic) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => drain());
      unawaited(_identityReady.then((_) => drain()));
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _storageFailure() {
    storageError = 'Couldn’t save or restore pending requests on this device. Keep the app open and try again.';
    if (!_disposed) notifyListeners();
  }

  Future<void> _reload(int generation) async {
    final uid = _uid;
    if (uid == null || !_current(generation)) return;
    final values = await store.read(uid);
    if (_current(generation)) {
      _rows = values
          .where((r) => !_revokedHouseholds.contains(r.command.householdId))
          .toList();
      storageError = null;
      notifyListeners();
    }
  }

  Future<void> enqueue(ChoreCommand command) async {
    final generation = _generation;
    await _identityReady;
    if (!_current(generation) ||
        command.uid != _uid ||
        _revokedHouseholds.contains(command.householdId)) {
      throw const OutboxFailure(
        'Sign in to the same profile before saving this request.',
      );
    }
    try {
      await store.enqueue(command);
      if (!_current(generation) ||
          command.uid != _uid ||
          _revokedHouseholds.contains(command.householdId)) {
        // A durable insert racing logout must not survive its already queued purge.
        await store.remove(command.uid, command.id);
        throw const OutboxFailure(
          'Your account changed before this request was saved.',
        );
      }
      await _reload(generation);
    } on OutboxFailure {
      rethrow;
    } catch (_) {
      _storageFailure();
      throw const OutboxFailure(
        'This request was not saved on your device. Try again before leaving.',
      );
    }
    if (automatic) unawaited(drain());
  }

  Future<void> retry(String id) async {
    await _identityReady;
    final row = _rows.where((r) => r.command.id == id && r.pending).firstOrNull;
    if (row == null || _uid == null) return;
    await store.update(
      _uid!,
      id,
      state: 'pending',
      attempts: row.attempts,
      nextAttempt: now(),
    );
    await _reload(_generation);
    await drain();
  }

  /// Call only after successfully loading current server state for an explicit
  /// conflict/rejection. An uncertain pending command cannot be silently dropped.
  Future<void> resolve(String id) async {
    final row = _rows.where((r) => r.command.id == id && r.blocked).firstOrNull;
    if (row == null || _uid == null) return;
    await store.remove(_uid!, id);
    await _reload(_generation);
  }

  Future<void> purgeHousehold(String hid) async {
    final uid = _uid, generation = _generation;
    if (uid == null) return;
    _revokedHouseholds.add(hid);
    await _identityReady;
    await store.purgeHousehold(uid, hid);
    await _reload(generation);
  }

  Future<void> drain() async {
    await _identityReady;
    if (_draining || _uid == null || _disposed || storageError != null) return;
    _draining = true;
    final uid = _uid!, generation = _generation;
    try {
      await _reload(generation);
      final due = _rows
          .where((r) => r.pending && !r.nextAttempt.isAfter(now()))
          .take(5)
          .toList();
      for (final row in due) {
        if (!_current(generation)) break;
        if (_revokedHouseholds.contains(row.command.householdId)) continue;
        final attempt = row.attempts + 1;
        final next = now().add(
          Duration(
            seconds: math.min(
              300,
              10 * math.pow(2, math.min(attempt - 1, 5)).toInt(),
            ),
          ),
        );
        // A crash before or after the network call keeps the same immutable UUID.
        await store.update(
          uid,
          row.command.id,
          state: 'pending',
          attempts: attempt,
          nextAttempt: next,
        );
        if (!_current(generation)) break;
        if (_revokedHouseholds.contains(row.command.householdId)) continue;
        try {
          await send(row.command);
          if (!_current(generation)) break;
          await store.update(
            uid,
            row.command.id,
            state: 'accepted',
            attempts: attempt,
            nextAttempt: now(),
          );
        } on ChoreFailure catch (e) {
          if (!_current(generation)) break;
          await store.update(
            uid,
            row.command.id,
            state: e.conflict
                ? 'conflict'
                : e.retryable
                ? 'pending'
                : 'rejected',
            attempts: attempt,
            nextAttempt: next,
            message: e.message,
          );
        } catch (_) {
          if (!_current(generation)) break;
          await store.update(
            uid,
            row.command.id,
            state: 'pending',
            attempts: attempt,
            nextAttempt: next,
            message: 'Waiting for confirmation. The same saved request will be retried.',
          );
        }
        await _reload(generation);
      }
    } catch (_) {
      if (_current(generation)) _storageFailure();
    } finally {
      _draining = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
