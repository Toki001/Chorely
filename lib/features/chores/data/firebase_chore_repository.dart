import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/chore_repository.dart';

class FirebaseChoreRepository implements ChoreRepository {
  FirebaseChoreRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
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
}
