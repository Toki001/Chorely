import '../../sync/domain/read_cache.dart';
import '../../sync/data/cached_models.dart';
import '../../scheduling/domain/postponement_repository.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/chore_repository.dart';
import '../domain/recurrence_repository.dart';
import 'firebase_recurrence_repository.dart';

class FirebaseChoreRepository
    implements ChoreRepository, PostponementRepository {
  FirebaseChoreRepository(this._db, this._functions, {this.readCache});
  final HouseholdReadCache? readCache;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  @override
  Future<void> postpone(PostponementRequest request) async {
    try {
      await _functions
          .httpsCallable(
            'postponeOccurrence',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
          )
          .call<Object?>(request.toMap());
    } on FirebaseFunctionsException catch (e) {
      throw ChoreFailure(
        switch (e.code) {
          'aborted' =>
            'This chore changed on another device. Reload before postponing.',
          'permission-denied' =>
            'Only a current guardian can postpone this occurrence.',
          'invalid-argument' => 'Choose a later deadline within the next 30 household days. Untimed chores move to a later day.',
          'failed-precondition' => 'This chore has recorded work or is no longer available to postpone.',
          'not-found' => 'This chore is no longer available.',
          'resource-exhausted' =>
            'The daily postponement limit was reached. Try again later.',
          'already-exists' => 'This request was already used. Reload to check the saved deadline.',
          'unauthenticated' => 'Sign in again before changing the deadline.',
          _ => 'Couldn’t confirm the new deadline. Retry the same request.',
        },
        conflict: e.code == 'aborted',
        retryable: ![
          'aborted',
          'permission-denied',
          'invalid-argument',
          'failed-precondition',
          'not-found',
          'resource-exhausted',
          'already-exists',
          'unauthenticated',
        ].contains(e.code),
      );
    }
    await refresh(request.householdId, request.occurrenceId);
  }

  @override
  late final RecurrenceRepository recurrence = FirebaseRecurrenceRepository(
    _db,
    _functions,
  );
  @override
  Stream<bool> watchCanManage(String householdId, String uid) =>
      watchActor(householdId, uid).map((a) => a?.canManage == true);
  ChoreOccurrence _read(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data()!;
    return ChoreOccurrence(
      id: s.id,
      templateId: d['templateId'] as String,
      version: (d['version'] as num).toInt(),
      templateVersion: (d['templateVersion'] as num).toInt(),
      status: d['status'] as String,
      timezone: d['timezoneIana'] as String,
      timeAdjusted: d['timeAdjusted'] == true,
      effectiveDueLocal: d['effectiveDueLocal'] as String?,
      effectiveStartLocal: d['effectiveStartLocal'] as String?,
      schedulingReason: d['reason'] as String?,
      postponed: (d['scheduleOverride'] as Map?)?['kind'] == 'postpone',
      dueAtUtc: (d['dueAtUtc'] as Timestamp?)?.toDate(),
      windowStartAtUtc: (d['windowStartAtUtc'] as Timestamp?)?.toDate(),
      completionRevision: (d['completionRevision'] as num?)?.toInt() ?? 0,
      reviewNote: d['reviewNote'] as String?,
      contributions: Map<String, dynamic>.from(d['contributions'] as Map? ?? {})
          .entries
          .map((entry) {
            final c = Map<String, dynamic>.from(entry.value as Map);
            return ChoreContribution(
              actorId: entry.key,
              acceptedAt: (c['acceptedAt'] as Timestamp).toDate(),
              completionRevision: (c['completionRevision'] as num).toInt(),
            );
          })
          .toList(),
      helpRequests: Map<String, dynamic>.from(d['helpRequests'] as Map? ?? {})
          .entries
          .map((entry) {
            final h = Map<String, dynamic>.from(entry.value as Map);
            return ChoreHelp(
              actorId: entry.key,
              requestId: h['requestId'] as String,
              status: h['status'] as String,
            );
          })
          .toList(),
      draft: ChoreDraft(
        title: d['title'] as String,
        category: d['category'] as String,
        description: d['description'] as String,
        room: d['room'] as String,
        steps: List<String>.from(d['steps'] as List),
        assignedActorIds: List<String>.from(d['assignedActorIds'] as List),
        completionPolicy: d['completionPolicy'] as String,
        reviewMode: d['reviewMode'] as String,
        instructionIllustrationKey: d['instructionIllustrationKey'] as String?,
        schedule: Map<String, Object?>.from(d['requestedSchedule'] as Map),
      ),
    );
  }

  Stream<List<ChoreOccurrence>> _serverwatchChores(
    String householdId, {
    String? actorId,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(
      'households/$householdId/occurrences',
    );
    if (actorId != null) {
      query = query.where('assignedActorIds', arrayContains: actorId);
    }
    return query
        .snapshots(includeMetadataChanges: true)
        .where((s) {
          if (s.metadata.isFromCache) {
            readCache?.unconfirmed(
              householdId,
              key: 'chores/${actorId == null ? 'all' : 'member:$actorId'}',
            );
            return false;
          }
          return true;
        })
        .map((s) {
          final chores = s.docs.map(_read).toList();
          chores.sort((a, b) => a.timingLabel.compareTo(b.timingLabel));
          return chores;
        });
  }

  Stream<ChoreOccurrence?> _serverwatchChore(
    String householdId,
    String occurrenceId,
  ) => _db
      .doc('households/$householdId/occurrences/$occurrenceId')
      .snapshots(includeMetadataChanges: true)
      .where((s) {
        if (s.metadata.isFromCache) {
          readCache?.unconfirmed(householdId, key: 'chore/$occurrenceId');
          return false;
        }
        return true;
      })
      .map((s) => s.exists ? _read(s) : null);
  @override
  Future<void> write({
    required String householdId,
    required String commandId,
    required String action,
    ChoreDraft? draft,
    ChoreOccurrence? base,
  }) async {
    try {
      await _functions.httpsCallable('writeOneOffChore').call<Object?>({
        'householdId': householdId,
        'commandId': commandId,
        'action': action,
        if (draft != null) ...draft.toMap(),
        if (base != null) ...{
          'templateId': base.templateId,
          'occurrenceId': base.id,
          'baseTemplateVersion': base.templateVersion,
          'baseOccurrenceVersion': base.version,
        },
      });
      await _db
          .collection('households/$householdId/occurrences')
          .get(const GetOptions(source: Source.server));
    } on FirebaseFunctionsException catch (e) {
      throw ChoreFailure(switch (e.code) {
        'aborted' => 'Someone changed this chore. Go back to its details, then reopen the editor to use the latest version.',
        'permission-denied' => 'Your account can’t manage chores in this household. Ask a guardian to check your access.',
        'unauthenticated' => 'Sign in again before saving this chore.',
        'invalid-argument' => 'Check the chore details, assignees and household times, then try again.',
        'failed-precondition' => 'This chore can’t be changed. Review also needs a guardian who is not assigned.',
        'already-exists' => 'This request was already used with different details. Return to the chore list to check what was saved.',
        'resource-exhausted' =>
          'The daily chore limit was reached. Please try again later.',
        'not-found' => 'This one-off chore is no longer available.',
        _ => 'Couldn’t confirm this change. Check your connection and retry the same request.',
      }, conflict: e.code == 'aborted');
    } on FirebaseException {
      throw const ChoreFailure(
        'Couldn’t refresh the saved chore. Check your connection and retry the same request.',
      );
    }
  }

  Stream<ChoreActor?> _serverwatchActor(String householdId, String uid) => _db
      .doc('households/$householdId/members/$uid')
      .snapshots(includeMetadataChanges: true)
      .where((s) {
        if (s.metadata.isFromCache) {
          readCache?.unconfirmed(householdId, key: 'actor/$uid');
          return false;
        }
        return true;
      })
      .map((s) {
        final d = s.data();
        if (d?['status'] != 'active') return null;
        final role = d?['role'] as String?;
        if (!['guardian', 'adult', 'child'].contains(role)) return null;
        final id = role == 'child' ? (d?['actorId'] as String?) : uid;
        return id == null
            ? null
            : ChoreActor(
                id: id,
                role: role!,
                canManage:
                    role == 'guardian' ||
                    (role == 'adult' && d?['canAssign'] == true),
              );
      });
  @override
  Stream<HelpRequest?> watchHelp(String householdId, String requestId) => _db
      .doc('households/$householdId/helpRequests/$requestId')
      .snapshots(includeMetadataChanges: true)
      .where((s) {
        if (s.metadata.isFromCache) {
          return false;
        }
        return true;
      })
      .map((s) {
        final d = s.data();
        return d == null
            ? null
            : HelpRequest(
                id: s.id,
                actorId: d['actorId'] as String,
                note: d['note'] as String,
                status: d['status'] as String,
                responseNote: d['responseNote'] as String?,
              );
      });
  @override
  Stream<List<ChoreActivity>> watchActivity(
    String householdId,
    String occurrenceId,
  ) => _db
      .collection('households/$householdId/activity')
      .where('entityId', isEqualTo: occurrenceId)
      .orderBy('toVersion', descending: true)
      .limit(30)
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
          return ChoreActivity(
            id: d.id,
            actorId: v['actorId'] as String,
            action: v['action'] as String,
            serverAt: (v['serverAt'] as Timestamp).toDate(),
            toStatus: v['toStatus'] as String?,
            system: v['actorType'] == 'system',
            reviewNote: v['reviewNote'] as String?,
          );
        }).toList(),
      );
  @override
  Future<void> refresh(String householdId, String occurrenceId) async {
    try {
      await _db
          .doc('households/$householdId/occurrences/$occurrenceId')
          .get(const GetOptions(source: Source.server));
    } on FirebaseException {
      throw const ChoreFailure(
        'Couldn’t reload this chore. Check your connection and access.',
      );
    }
  }

  @override
  Future<void> act({
    required String householdId,
    required String occurrenceId,
    required String commandId,
    required String action,
    required int baseVersion,
    String note = '',
    String? targetActorId,
  }) async {
    try {
      await _functions
          .httpsCallable(
            'actOnOccurrence',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
          )
          .call<Object?>({
            'householdId': householdId,
            'occurrenceId': occurrenceId,
            'commandId': commandId,
            'action': action,
            'baseVersion': baseVersion,
            'note': note,
            'targetActorId': ?targetActorId,
          });
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map
          ? Map<String, dynamic>.from(e.details as Map)
          : <String, dynamic>{};
      throw ChoreFailure(
        switch (e.code) {
          'aborted' => 'This chore changed on another device. Reload its latest state before trying again.',
          'permission-denied' => 'This action isn’t available to your profile. Ask a guardian to check the task and your access.',
          'unauthenticated' => 'Sign in again before changing this chore.',
          'failed-precondition' =>
            details['reason'] == 'undo_unavailable'
                ? 'Undo is no longer available. It lasts five minutes and ends after a later completion or review.'
                : 'This action is no longer available. Reload the chore to see its latest state.',
          'invalid-argument' =>
            'Check your note and reload the current chore before saving.',
          'already-exists' => 'This request was already used. Reload the chore to check its saved state.',
          'resource-exhausted' =>
            'The daily action limit was reached. Try again later.',
          _ => 'Couldn’t confirm this action. Check your connection and retry the same request.',
        },
        conflict: e.code == 'aborted',
        retryable: ![
          'aborted',
          'permission-denied',
          'unauthenticated',
          'failed-precondition',
          'invalid-argument',
          'already-exists',
          'resource-exhausted',
        ].contains(e.code),
      );
    }
    await refresh(householdId, occurrenceId);
  }

  Future<HouseholdClock> _serverClock(String hid) async {
    final data =
        (await _functions
                .httpsCallable(
                  'getHouseholdClock',
                  options: HttpsCallableOptions(
                    timeout: const Duration(seconds: 5),
                  ),
                )
                .call<Map<String, dynamic>>({'householdId': hid}))
            .data;
    return HouseholdClock(
      today: data['today'] as String,
      timezone: data['timezoneIana'] as String,
      serverNow: DateTime.fromMillisecondsSinceEpoch(
        (data['serverNowMillis'] as num).toInt(),
        isUtc: true,
      ),
      nextMidnight: DateTime.fromMillisecondsSinceEpoch(
        (data['nextMidnightMillis'] as num).toInt(),
        isUtc: true,
      ),
      actor: ChoreActor(
        id: data['actorId'] as String,
        role: data['role'] as String,
        canManage: data['canManage'] == true,
      ),
    );
  }

  @override
  Future<HouseholdClock> loadClock(String householdId) =>
      readCache?.load(
        householdId: householdId,
        key: 'clock',
        server: () => _serverClock(householdId),
        encode: saveClock,
        decode: readClock,
      ) ??
      _serverClock(householdId);

  Stream<List<ChoreOccurrence>> _serverwatchRange(
    String householdId,
    String fromDate,
    String throughDate, {
    String? actorId,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('households/$householdId/occurrences')
        .where('localDate', isGreaterThanOrEqualTo: fromDate)
        .where('localDate', isLessThanOrEqualTo: throughDate);
    if (actorId != null) {
      query = query.where('assignedActorIds', arrayContains: actorId);
    }
    // An empty local cache is not evidence that a household has zero chores.
    // The identity-scoped disk cache separately labels saved data. Memory-only
    // snapshots cannot establish fresh counts or access.
    return query
        .snapshots(includeMetadataChanges: true)
        .where((s) {
          if (s.metadata.isFromCache) {
            readCache?.unconfirmed(
              householdId,
              key:
                  'range/$fromDate/$throughDate/${actorId == null ? 'all' : 'member:$actorId'}',
            );
            return false;
          }
          return true;
        })
        .map((s) {
          final rows = s.docs.map(_read).toList();
          rows.sort((a, b) {
            final date = a.localDate.compareTo(b.localDate);
            if (date != 0) return date;
            return a.timingLabel.compareTo(b.timingLabel);
          });
          return rows;
        });
  }

  @override
  Stream<ChoreActor?> watchActor(String hid, String uid) {
    final server = _serverwatchActor(hid, uid);
    return readCache?.watch<ChoreActor?>(
          householdId: hid,
          key: 'actor/$uid',
          server: server,
          encode: (a) => a == null ? null : saveActor(a),
          decode: (v) => v == null ? null : readActor(v),
          authorized: (a) => a != null,
        ) ??
        server;
  }

  @override
  Stream<ChoreOccurrence?> watchChore(String hid, String oid) {
    final server = _serverwatchChore(hid, oid);
    return readCache?.watch<ChoreOccurrence?>(
          householdId: hid,
          key: 'chore/$oid',
          server: server,
          encode: (c) => c == null ? null : saveChore(c),
          decode: (v) => v == null ? null : readChore(v),
        ) ??
        server;
  }

  @override
  Stream<List<ChoreOccurrence>> watchChores(String hid, {String? actorId}) {
    final server = _serverwatchChores(hid, actorId: actorId);
    return readCache?.watch(
          householdId: hid,
          key: 'chores/${actorId == null ? 'all' : 'member:$actorId'}',
          server: server,
          encode: (rows) => rows.map(saveChore).toList(),
          decode: (v) => objectList(v, readChore),
        ) ??
        server;
  }

  @override
  Stream<List<ChoreOccurrence>> watchRange(
    String hid,
    String from,
    String through, {
    String? actorId,
  }) {
    final server = _serverwatchRange(hid, from, through, actorId: actorId);
    return readCache?.watch(
          householdId: hid,
          key:
              'range/$from/$through/${actorId == null ? 'all' : 'member:$actorId'}',
          server: server,
          encode: (rows) => rows.map(saveChore).toList(),
          decode: (v) => objectList(v, readChore),
        ) ??
        server;
  }
}
