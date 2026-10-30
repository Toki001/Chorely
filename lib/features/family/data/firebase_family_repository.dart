import '../../sync/domain/read_cache.dart';
import '../../sync/data/cached_models.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/family_repository.dart';

class FirebaseFamilyRepository implements FamilyRepository {
  FirebaseFamilyRepository(
    this._db,
    this._functions,
    this._auth, {
    this.readCache,
  });
  final HouseholdReadCache? readCache;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  Stream<List<FamilyPerson>> _serverPeople(String householdId) => _db
      .collection('households/$householdId/profiles')
      .snapshots(includeMetadataChanges: true)
      .where((s) {
        if (s.metadata.isFromCache) {
          readCache?.unconfirmed(householdId, key: 'people');
          return false;
        }
        return true;
      })
      .map(
        (s) => s.docs
            .map(
              (d) => FamilyPerson(
                id: d.id,
                nickname: d.get('nickname') as String,
                role: d.get('role') as String,
                active:
                    d.data()['status'] == null ||
                    d.data()['status'] == 'active',
              ),
            )
            .toList(),
      );
  Stream<String?> _serverRole(String householdId, String uid) => _db
      .doc('households/$householdId/members/$uid')
      .snapshots(includeMetadataChanges: true)
      .where((s) {
        if (s.metadata.isFromCache) {
          readCache?.unconfirmed(householdId, key: 'role/$uid');
          return false;
        }
        return true;
      })
      .map(
        (s) => s.data()?['status'] == 'active'
            ? (s.data()?['role'] as String?)
            : null,
      );
  @override
  Stream<List<FamilyAccess>> watchAccess(String householdId, String kind) {
    final path = switch (kind) {
      'invite' => 'invitations',
      'pairing' => 'pairings',
      'device' => 'devices',
      _ => throw ArgumentError('Invalid access kind'),
    };
    return _db
        .collection('households/$householdId/$path')
        .snapshots(includeMetadataChanges: true)
        .where((s) {
          if (s.metadata.isFromCache) {
            return false;
          }
          return true;
        })
        .map(
          (s) => s.docs.map((d) {
            final v = d.data();
            return FamilyAccess(
              id: d.id,
              kind: kind,
              status: v['status'] as String,
              profileId: v['profileId'] as String?,
              role: v['role'] as String?,
              expiresAt: (v['expiresAt'] as Timestamp?)?.toDate(),
            );
          }).toList(),
        );
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object> input,
  ) async {
    try {
      return (await _functions
              .httpsCallable(name)
              .call<Map<String, dynamic>>(input))
          .data;
    } on FirebaseFunctionsException catch (e) {
      throw FamilyFailure(switch (e.code) {
        'permission-denied' => 'This account or code doesn’t have access. Ask a guardian for a new code.',
        'unauthenticated' => 'Sign in to your adult account first.',
        'failed-precondition' => 'This action is no longer available. The code may be used, expired or revoked. Keep at least one guardian in your home.',
        'already-exists' => 'The earlier request may have succeeded. Check your household before trying new details.',
        'resource-exhausted' =>
          'The household or daily access limit was reached. Try again later.',
        'invalid-argument' =>
          'Check the nickname, email or code, then try again.',
        _ => 'Couldn’t confirm this change. Check your connection and retry the same request.',
      });
    }
  }

  @override
  Future<DateTime> invite({
    required String householdId,
    required String nonce,
    required String recipientEmail,
    required String role,
    required String commandId,
  }) async {
    final result = await _call('issueInvite', {
      'householdId': householdId,
      'nonce': nonce,
      'recipientEmail': recipientEmail,
      'role': role,
      'commandId': commandId,
    });
    return DateTime.fromMillisecondsSinceEpoch(
      (result['expiresAt'] as num).toInt(),
    );
  }

  @override
  Future<String> accept({
    required String nonce,
    required String nickname,
    required String commandId,
  }) async =>
      (await _call('acceptInvite', {
            'nonce': nonce,
            'nickname': nickname,
            'commandId': commandId,
          }))['householdId']
          as String;
  @override
  Future<String> addChild({
    required String householdId,
    required String nickname,
    required String commandId,
  }) async =>
      (await _call('addChildProfile', {
            'householdId': householdId,
            'nickname': nickname,
            'commandId': commandId,
          }))['profileId']
          as String;
  @override
  Future<DateTime> approvePairing({
    required String householdId,
    required String profileId,
    required String nonce,
  }) async {
    final result = await _call('issueChildPairing', {
      'householdId': householdId,
      'profileId': profileId,
      'nonce': nonce,
    });
    return DateTime.fromMillisecondsSinceEpoch(
      (result['expiresAt'] as num).toInt(),
    );
  }

  @override
  Future<void> pairDevice({
    required String nonce,
    required String deviceSecret,
  }) async {
    if (_auth.currentUser != null) {
      throw const FamilyFailure('Sign out before linking a supervised device.');
    }
    final result = await _call('redeemChildPairing', {
      'nonce': nonce,
      'deviceSecret': deviceSecret,
    });
    try {
      await _auth.signInWithCustomToken(result['customToken'] as String);
    } on FirebaseAuthException {
      throw const FamilyFailure(
        'Couldn’t finish linking. Retry the same code on this device.',
      );
    }
  }

  @override
  Future<void> revoke({
    required String householdId,
    required String targetId,
    required String kind,
  }) async {
    if (kind == 'invite') {
      await _call('revokeInvite', {
        'householdId': householdId,
        'inviteId': targetId,
      });
    } else if (kind == 'member') {
      await _call('revokeMember', {
        'householdId': householdId,
        'memberUid': targetId,
      });
    } else {
      await _call('revokeChildAccess', {
        'householdId': householdId,
        'targetId': targetId,
        'kind': kind,
      });
    }
    // Acknowledgement is authoritative, but native query listeners can retain
    // a prior snapshot after switching auth identities. Refresh server state
    // before the UI replaces its access subscriptions.
    if (kind != 'member') {
      final path = switch (kind) {
        'invite' => 'invitations',
        'pairing' => 'pairings',
        _ => 'devices',
      };
      await _db
          .collection('households/$householdId/$path')
          .get(const GetOptions(source: Source.server));
    }
  }

  @override
  Stream<List<FamilyPerson>> watchPeople(String hid) {
    final server = _serverPeople(hid);
    return readCache?.watch(
          householdId: hid,
          key: 'people',
          server: server,
          encode: (rows) => rows.map(savePerson).toList(),
          decode: (v) => objectList(v, readPerson),
          authorized: (rows) =>
              readCache?.supervisedHouseholdId != hid ||
              rows.any((p) => p.id == readCache?.supervisedActorId && p.active),
        ) ??
        server;
  }

  @override
  Stream<String?> watchRole(String hid, String uid) {
    final server = _serverRole(hid, uid);
    return readCache?.watch<String?>(
          householdId: hid,
          key: 'role/$uid',
          server: server,
          encode: (v) => v,
          decode: (v) => v as String?,
          authorized: (v) => v != null,
        ) ??
        server;
  }
}
