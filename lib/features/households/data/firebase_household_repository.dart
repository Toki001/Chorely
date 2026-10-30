import '../../sync/domain/read_cache.dart';
import '../../sync/data/cached_models.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/household_repository.dart';

class FirebaseHouseholdRepository implements HouseholdRepository {
  FirebaseHouseholdRepository(this._db, this._functions, {this.readCache});
  final HouseholdReadCache? readCache;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<List<HouseholdSummary>> _serverwatchHouseholds(String uid) => _db
      .collection('users/$uid/households')
      .snapshots(includeMetadataChanges: true)
      .where((s) {
        if (s.metadata.isFromCache) {
          readCache?.unconfirmed('_account', key: 'homes');
          return false;
        }
        return true;
      })
      .map(
        (s) => s.docs
            .map(
              (d) => HouseholdSummary(
                id: d.id,
                name: d.data()['name'] as String,
                role: d.data()['role'] as String,
              ),
            )
            .toList(),
      );
  Stream<Household?> _serverwatchHousehold(String id) => _db
      .doc('households/$id')
      .snapshots(includeMetadataChanges: true)
      .where((s) {
        if (s.metadata.isFromCache) {
          readCache?.unconfirmed(id, key: 'home');
          return false;
        }
        return true;
      })
      .map((s) {
        final d = s.data();
        return d == null
            ? null
            : Household(
                id: s.id,
                name: d['name'] as String,
                timezone: d['timezoneIana'] as String,
              );
      });
  Stream<List<HouseholdProfile>> _serverwatchProfiles(String id) => _db
      .collection('households/$id/profiles')
      .snapshots(includeMetadataChanges: true)
      .where((s) {
        if (s.metadata.isFromCache) {
          readCache?.unconfirmed(id, key: 'profiles');
          return false;
        }
        return true;
      })
      .map(
        (s) => s.docs
            .map(
              (d) => HouseholdProfile(
                nickname: d.data()['nickname'] as String,
                role: d.data()['role'] as String,
              ),
            )
            .toList(),
      );
  @override
  Future<String> create({
    required String commandId,
    required String name,
    required String nickname,
    required String timezone,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('createHousehold')
          .call<Map<String, dynamic>>({
            'commandId': commandId,
            'name': name,
            'nickname': nickname,
            'timezone': timezone,
          });
      return result.data['householdId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw HouseholdFailure(switch (e.code) {
        'permission-denied' => 'Your account can’t create a household. Check that your email is verified.',
        'resource-exhausted' =>
          'Your account has reached the household creation limit.',
        'invalid-argument' =>
          'Check the household details and timezone, then try again.',
        'already-exists' => 'Your earlier request may have succeeded. Go back to your homes and check.',
        _ => 'Couldn’t confirm your household. Check your connection and try again.',
      });
    }
  }

  @override
  Stream<List<HouseholdSummary>> watchHouseholds(String uid) {
    final server = _serverwatchHouseholds(uid).asyncMap((rows) async {
      await readCache?.reconcileHomeIndex(uid, rows.map((h) => h.id));
      return rows;
    });
    return readCache?.watch(
          householdId: '_account',
          key: 'homes',
          server: server,
          encode: (rows) => [
            for (final h in rows) {'id': h.id, 'name': h.name, 'role': h.role},
          ],
          decode: (v) => objectList(v, (x) {
            final h = objectMap(x);
            return HouseholdSummary(
              id: h['id'] as String,
              name: h['name'] as String,
              role: h['role'] as String,
            );
          }),
        ) ??
        server;
  }

  @override
  Stream<Household?> watchHousehold(String hid) {
    final server = _serverwatchHousehold(hid);
    return readCache?.watch<Household?>(
          householdId: hid,
          key: 'home',
          server: server,
          encode: (v) => v == null ? null : saveHome(v),
          decode: (v) => v == null ? null : readHome(v),
          authorized: (v) => v != null,
        ) ??
        server;
  }

  @override
  Stream<List<HouseholdProfile>> watchProfiles(String hid) {
    final server = _serverwatchProfiles(hid);
    return readCache?.watch(
          householdId: hid,
          key: 'profiles',
          server: server,
          encode: (rows) => [
            for (final p in rows) {'nickname': p.nickname, 'role': p.role},
          ],
          decode: (v) => objectList(v, (x) {
            final p = objectMap(x);
            return HouseholdProfile(
              nickname: p['nickname'] as String,
              role: p['role'] as String,
            );
          }),
        ) ??
        server;
  }
}
