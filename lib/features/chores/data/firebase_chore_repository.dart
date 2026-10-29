import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/chore_repository.dart';
import '../domain/recurrence_repository.dart';
import 'firebase_recurrence_repository.dart';

class FirebaseChoreRepository implements ChoreRepository {
  FirebaseChoreRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  @override
  late final RecurrenceRepository recurrence = FirebaseRecurrenceRepository(
    _db,
    _functions,
  );
  @override
  Stream<bool> watchCanManage(String householdId, String uid) =>
      _db.doc('households/$householdId/members/$uid').snapshots().map((s) {
        final d = s.data();
        return d?['status'] == 'active' &&
            (d?['role'] == 'guardian' ||
                (d?['role'] == 'adult' && d?['canAssign'] == true));
      });
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

  @override
  Stream<List<ChoreOccurrence>> watchChores(
    String householdId, {
    String? actorId,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(
      'households/$householdId/occurrences',
    );
    if (actorId != null) {
      query = query.where('assignedActorIds', arrayContains: actorId);
    }
    return query.snapshots().map((s) {
      final chores = s.docs.map(_read).toList();
      chores.sort((a, b) => a.timingLabel.compareTo(b.timingLabel));
      return chores;
    });
  }

  @override
  Stream<ChoreOccurrence?> watchChore(
    String householdId,
    String occurrenceId,
  ) => _db
      .doc('households/$householdId/occurrences/$occurrenceId')
      .snapshots()
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

  @override
  Stream<ChoreActor?> watchActor(String householdId, String uid) =>
      _db.doc('households/$householdId/members/$uid').snapshots().map((s) {
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
      .snapshots()
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
      .snapshots()
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
      await _functions.httpsCallable('actOnOccurrence').call<Object?>({
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
}
