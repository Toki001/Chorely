import 'dart:async';

import 'package:chorely/features/sync/domain/read_cache.dart';
import 'package:chorely/features/sync/data/cached_models.dart';
import 'package:chorely/features/sync/data/cached_account_session_store.dart';
import 'package:chorely/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chores_test.dart' show chore;

class CacheMemoryStore implements ReadCacheStore {
  final values = <String, SavedRead>{};
  String key(String uid, String hid, String name) => '$uid/$hid/$name';
  @override
  Future<void> retainIdentity(String? uid) async {
    values.removeWhere((k, _) => uid == null || !k.startsWith('$uid/'));
  }

  @override
  Future<SavedRead?> read(String uid, String householdId, String name) async =>
      values[key(uid, householdId, name)];
  @override
  Future<void> write(
    String uid,
    String householdId,
    String name,
    Object? value,
    DateTime at,
  ) async {
    values[key(uid, householdId, name)] = SavedRead(value, at);
  }

  @override
  Future<void> purgeHousehold(String uid, String hid) async {
    values.removeWhere((k, _) => k.startsWith('$uid/$hid/'));
  }
}

void main() {
  late CacheMemoryStore store;
  late HouseholdReadCache cache;
  late StreamController<String> server;
  late List<String> values;
  late List<Object> errors;
  late StreamSubscription<String> sub;
  setUp(() async {
    store = CacheMemoryStore();
    server = StreamController();
    values = [];
    errors = [];
    cache = HouseholdReadCache(
      store,
      isDenied: (e) => e == 'denied',
      isTransient: (e) => e == 'offline',
    );
    await store.write('uid', 'home', 'list', 'saved', DateTime.utc(2026));
    cache.identity('uid');
    sub = cache
        .watch<String>(
          householdId: 'home',
          key: 'list',
          server: server.stream,
          encode: (s) => s,
          decode: (v) => v as String,
        )
        .listen(values.add, onError: errors.add);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    await sub.cancel();
    await server.close();
    cache.dispose();
  });
  test('Previously confirmed data is visibly cached until a real server result arrives', () async {
    expect(values, ['saved']);
    expect(cache.stale('home'), true);
    server.add('current');
    await Future<void>.delayed(Duration.zero);
    expect(values, ['saved', 'current']);
    expect(cache.stale('home'), false);
    server.addError('offline');
    await Future<void>.delayed(Duration.zero);
    expect(values.last, 'current');
    expect(cache.stale('home'), true);
    expect(errors, isEmpty);
  });
  test('Known access denial invalidates cached data and later responses cannot restore it', () async {
    server.addError('denied');
    await Future<void>.delayed(Duration.zero);
    expect(store.values, isEmpty);
    expect(errors.whereType<CacheAccessLost>().length, 1);
    server.add('stale response');
    await Future<void>.delayed(Duration.zero);
    expect(values, ['saved']);
  });
  test('Cached state from a different identity is purged and late responses are discarded', () async {
    cache.identity('different');
    await Future<void>.delayed(Duration.zero);
    server.add('old account');
    await Future<void>.delayed(Duration.zero);
    expect(values, ['saved']);
    expect(store.values, isEmpty);
  });
  test('Restoration suspension retains bytes but emits no old scope until real identity returns', () async {
    cache.suspend();
    server.add('ignored');
    await Future<void>.delayed(Duration.zero);
    expect(values, ['saved']);
    expect(store.values.length, 1);
    cache.identity('uid');
    await Future<void>.delayed(Duration.zero);
    expect(store.values.length, 1);
  });
  test('A future load falls back only on a transient error, never on current denial', () async {
    final old = await cache.load<String>(
      householdId: 'home',
      key: 'list',
      server: () async => throw 'offline',
      encode: (v) => v,
      decode: (v) => v as String,
    );
    expect(old, 'saved');
    expect(cache.stale('home'), true);
    await expectLater(
      cache.load<String>(
        householdId: 'home',
        key: 'list',
        server: () async => throw 'denied',
        encode: (v) => v,
        decode: (v) => v as String,
      ),
      throwsA('denied'),
    );
    expect(store.values, isEmpty);
  });
  test('Chore snapshots keep instructions, scheduling, roles and immutable occurrence versions', () {
    final original = chore(), restored = readChore(saveChore(original));
    expect(restored.id, original.id);
    expect(restored.version, original.version);
    expect(restored.draft.toMap(), original.draft.toMap());
    expect(restored.status, original.status);
    expect(restored.timezone, original.timezone);
  });
  test('Session cache contains no email or token and cannot restore another SDK UID', () async {
    final sessions = CachedAccountSessionStore(store);
    await sessions.save(
      const AccountSession(
        uid: 'uid',
        email: 'fictional@example.test',
        verified: false,
        supervised: true,
        householdId: 'home',
        profileId: 'child',
      ),
    );
    final restored = await sessions.read('uid');
    expect(restored?.profileId, 'child');
    expect(restored?.email, '');
    expect(await sessions.read('foreign'), isNull);
    expect(store.values.values.last.value.toString(), isNot(contains('@')));
  });
  test('A newly unconfirmed query cannot relabel an unrelated live query as saved data', () async {
    server.add('current');
    await Future<void>.delayed(Duration.zero);
    final detail = StreamController<String>();
    final detailSub = cache
        .watch<String>(
          householdId: 'home',
          key: 'detail',
          server: detail.stream,
          encode: (v) => v,
          decode: (v) => v as String,
        )
        .listen((_) {});
    await Future<void>.delayed(Duration.zero);
    detail.add('detail current');
    await Future<void>.delayed(Duration.zero);
    cache.unconfirmed('home', key: 'detail');
    expect(cache.stale('home'), true);
    await detailSub.cancel();
    await detail.close();
    expect(cache.stale('home'), false);
  });
  test(
    'Supervised cached reads stay inside the current household and profile',
    () async {
      cache.identity('uid', householdId: 'home', actorId: 'child-one');
      Future<String> load(String hid, Future<String> Function() remote) =>
          cache.load<String>(
            householdId: hid,
            key: 'detail',
            server: remote,
            encode: (v) => v,
            decode: (v) => v as String,
          );
      expect(
        await load('home', () async => 'child one data'),
        'child one data',
      );
      expect(await load('home', () async => throw 'offline'), 'child one data');
      cache.identity('uid', householdId: 'home', actorId: 'child-two');
      await expectLater(
        load('home', () async => throw 'offline'),
        throwsA('offline'),
      );
      var foreignCalled = false;
      await expectLater(
        load('foreign-home', () async {
          foreignCalled = true;
          return 'foreign';
        }),
        throwsA(isA<CacheAccessLost>()),
      );
      expect(foreignCalled, false);
    },
  );
  test(
    'A confirmed supervised scope change purges the previous household copy',
    () async {
      final sessions = CachedAccountSessionStore(store);
      AccountSession scope(String profile) => AccountSession(
        uid: 'uid',
        email: '',
        verified: false,
        supervised: true,
        householdId: 'home',
        profileId: profile,
      );
      await sessions.save(scope('child-one'));
      await store.write(
        'uid',
        'home',
        'detail',
        'private old profile data',
        DateTime.now(),
      );
      await sessions.save(scope('child-two'));
      expect(await store.read('uid', 'home', 'detail'), isNull);
      expect((await sessions.read('uid'))?.profileId, 'child-two');
    },
  );
}
