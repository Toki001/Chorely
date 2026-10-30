import 'dart:async';

import 'package:flutter/foundation.dart';

class SavedRead {
  const SavedRead(this.value, this.confirmedAt);
  final Object? value;
  final DateTime confirmedAt;
}

class CacheAccessLost implements Exception {
  const CacheAccessLost();
}

abstract interface class ReadCacheStore {
  Future<void> retainIdentity(String? uid);
  Future<SavedRead?> read(String uid, String householdId, String key);
  Future<void> write(
    String uid,
    String householdId,
    String key,
    Object? value,
    DateTime confirmedAt,
  );
  Future<void> purgeHousehold(String uid, String householdId);
}

class _ReadSource {
  _ReadSource(this.householdId, this.key, this.cached, this.at);
  final String householdId, key;
  bool cached;
  DateTime? at;
}

/// Cache bytes never grant authority. Only this UID's previously confirmed reads
/// are visible while checking connectivity; current denial invalidates the home.
class HouseholdReadCache extends ChangeNotifier {
  HouseholdReadCache(
    this.store, {
    required this.isDenied,
    required this.isTransient,
    this.onRevoke,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final ReadCacheStore store;
  final bool Function(Object error) isDenied, isTransient;
  final Future<void> Function(String householdId)? onRevoke;
  final DateTime Function() now;
  String? _uid;
  String? supervisedHouseholdId, supervisedActorId;
  int _generation = 0, _sequence = 0;
  Future<void> _ready = Future.value();
  final _sources = <int, _ReadSource>{};
  final _loads = <String, _ReadSource>{};
  Iterable<_ReadSource> get _allSources => [
    ..._sources.values,
    ..._loads.values,
  ];
  final _revocations = StreamController<String>.broadcast();
  final _blocked = <String>{};
  bool _suspended = false, _disposed = false;
  void suspend() {
    if (_suspended) return;
    _suspended = true;
    _uid = null;
    _generation++;
    _sources.clear();
    _loads.clear();
  }

  void identity(String? uid, {String? householdId, String? actorId}) {
    if (!_suspended &&
        _uid == uid &&
        supervisedHouseholdId == householdId &&
        supervisedActorId == actorId &&
        _generation != 0) {
      return;
    }
    supervisedHouseholdId = householdId;
    supervisedActorId = actorId;
    _suspended = false;
    _uid = uid;
    _generation++;
    _sources.clear();
    _loads.clear();
    _blocked.clear();
    _ready = _ready
        .catchError((Object _) {})
        .then((_) => store.retainIdentity(uid));
    // Consumers await this future; attach a handler now to avoid an unobserved
    // startup disk error when no household view is open yet.
    unawaited(_ready.then((_) {}, onError: (Object _) {}));
  }

  bool get hasSavedReads => _allSources.any((s) => s.cached);
  bool stale(String hid) =>
      _allSources.any((s) => s.householdId == hid && s.cached);
  DateTime? oldest(String hid) {
    final dates =
        _allSources
            .where((s) => s.householdId == hid && s.cached && s.at != null)
            .map((s) => s.at!)
            .toList()
          ..sort();
    return dates.firstOrNull;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _valid(int generation, String uid, String hid) =>
      !_disposed &&
      generation == _generation &&
      uid == _uid &&
      (supervisedHouseholdId == null || supervisedHouseholdId == hid) &&
      !_blocked.contains(hid);
  String _storageKey(String key) =>
      supervisedActorId == null ? key : 'profile:$supervisedActorId/$key';
  void unconfirmed(String hid, {String? key}) {
    for (final s in _allSources.where(
      (s) => s.householdId == hid && (key == null || s.key == key),
    )) {
      s.cached = true;
    }
    _notify();
  }

  Future<void> reconcileHomeIndex(
    String uid,
    Iterable<String> currentIds,
  ) async {
    final generation = _generation;
    await _ready;
    if (_uid != uid || generation != _generation) return;
    final previous = await store.read(uid, '_account', 'homes');
    if (previous?.value is! List || _uid != uid || generation != _generation) {
      return;
    }
    final current = currentIds.toSet();
    for (final old in previous!.value! as List) {
      if (old is Map && old['id'] is String && !current.contains(old['id'])) {
        await revoke(old['id'] as String);
      }
    }
  }

  Future<void> revoke(String hid) async {
    final uid = _uid, generation = _generation;
    if (uid == null || _blocked.contains(hid)) return;
    _blocked.add(hid);
    _revocations.add(hid);
    _sources.removeWhere((_, s) => s.householdId == hid);
    _notify();
    _loads.removeWhere((_, s) => s.householdId == hid);
    try {
      await store.purgeHousehold(uid, hid);
    } finally {
      if (uid == _uid && generation == _generation) await onRevoke?.call(hid);
    }
  }

  Future<void> _removeLateWrite(String uid, String hid) async {
    if ((!_suspended && uid != _uid) ||
        (uid == _uid && _blocked.contains(hid))) {
      await store.purgeHousehold(uid, hid);
    }
  }

  Stream<T> watch<T>({
    required String householdId,
    required String key,
    required Stream<T> server,
    required Object? Function(T value) encode,
    required T Function(Object? value) decode,
    bool Function(T value)? authorized,
  }) => Stream<T>.multi((events) {
    final uid = _uid, generation = _generation, sourceId = ++_sequence;
    final storageKey = _storageKey(key);
    bool cancelled = false, serverSeen = false, hasValue = false;
    StreamSubscription<T>? remote;
    StreamSubscription<String>? revoked;
    Future<void> serial = Future.value();
    void fail(Object error, StackTrace stack) {
      serial = serial
          .then((_) async {
            if (uid == null ||
                !_valid(generation, uid, householdId) ||
                cancelled) {
              return;
            }
            if (isDenied(error)) {
              await revoke(householdId);
            } else if (isTransient(error) && hasValue) {
              unconfirmed(householdId, key: key);
              return;
            }
            events.addError(error, stack);
          })
          .catchError((Object error, StackTrace stack) {
            if (!cancelled) events.addError(error, stack);
          });
    }

    events.onCancel = () async {
      cancelled = true;
      await remote?.cancel();
      await revoked?.cancel();
      _sources.remove(sourceId);
      _notify();
    };
    unawaited(() async {
      try {
        await _ready;
        if (uid == null || !_valid(generation, uid, householdId) || cancelled) {
          events.addError(const CacheAccessLost());
          return;
        }
        revoked = _revocations.stream.where((hid) => hid == householdId).listen(
          (_) {
            if (!cancelled) events.addError(const CacheAccessLost());
          },
        );
        remote = server.listen((value) {
          serverSeen = true;
          serial = serial
              .then((_) async {
                if (!_valid(generation, uid, householdId) || cancelled) return;
                if (authorized != null && !authorized(value)) {
                  await revoke(householdId);
                  return;
                }
                final confirmed = now();
                try {
                  await store.write(
                    uid,
                    householdId,
                    storageKey,
                    encode(value),
                    confirmed,
                  );
                } catch (_) {
                  // A disk problem cannot hide current server data. The view has no
                  // durable cache guarantee until a later successful write.
                }
                if (!_valid(generation, uid, householdId) || cancelled) {
                  await _removeLateWrite(uid, householdId);
                  return;
                }
                _sources[sourceId] = _ReadSource(
                  householdId,
                  key,
                  false,
                  confirmed,
                );
                hasValue = true;
                _notify();
                events.add(value);
              })
              .catchError((Object error, StackTrace stack) {
                if (!cancelled) events.addError(error, stack);
              });
        }, onError: fail);
        final saved = await store.read(uid, householdId, storageKey);
        if (saved != null &&
            !_disposed &&
            !serverSeen &&
            !cancelled &&
            _valid(generation, uid, householdId)) {
          final value = decode(saved.value);
          _sources[sourceId] = _ReadSource(
            householdId,
            key,
            true,
            saved.confirmedAt,
          );
          hasValue = true;
          _notify();
          events.add(value);
        }
      } catch (error, stack) {
        if (!cancelled) events.addError(error, stack);
      }
    }());
  });
  Future<T> load<T>({
    required String householdId,
    required String key,
    required Future<T> Function() server,
    required Object? Function(T value) encode,
    required T Function(Object? value) decode,
  }) async {
    final uid = _uid, generation = _generation, storageKey = _storageKey(key);
    await _ready;
    if (uid == null || !_valid(generation, uid, householdId)) {
      throw const CacheAccessLost();
    }
    try {
      final value = await server();
      if (!_valid(generation, uid, householdId)) throw const CacheAccessLost();
      final confirmed = now();
      try {
        await store.write(
          uid,
          householdId,
          storageKey,
          encode(value),
          confirmed,
        );
      } catch (_) {}
      if (!_valid(generation, uid, householdId)) {
        await _removeLateWrite(uid, householdId);
        throw const CacheAccessLost();
      }
      _loads.remove('$householdId/$key');
      _notify();
      return value;
    } catch (error) {
      if (isDenied(error)) {
        await revoke(householdId);
        rethrow;
      }
      if (!isTransient(error) || !_valid(generation, uid, householdId)) rethrow;
      final saved = await store.read(uid, householdId, storageKey);
      if (saved == null || !_valid(generation, uid, householdId)) rethrow;
      _loads['$householdId/$key'] = _ReadSource(
        householdId,
        key,
        true,
        saved.confirmedAt,
      );
      _notify();
      return decode(saved.value);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _revocations.close();
    super.dispose();
  }
}
