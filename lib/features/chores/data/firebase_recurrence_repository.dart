import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/chore_repository.dart';
import '../domain/recurrence_repository.dart';

class FirebaseRecurrenceRepository implements RecurrenceRepository {
  FirebaseRecurrenceRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  @override
  Stream<RecurrenceConfiguration?> watchConfiguration(
    String householdId,
    String templateId,
  ) => _db
      .doc('households/$householdId/recurrenceRules/$templateId')
      .snapshots()
      .asyncMap((root) async {
        if (!root.exists) return null;
        final version = (root.get('version') as num).toInt();
        final snapshot = await root.reference
            .collection('versions')
            .doc('$version')
            .get(const GetOptions(source: Source.server));
        final d = snapshot.data();
        if (d == null) {
          throw const ChoreFailure(
            'The repeat settings are unavailable. Try again.',
          );
        }
        return RecurrenceConfiguration(
          version: version,
          templateVersion: (d['templateVersion'] as num).toInt(),
          effectiveFrom: d['effectiveFrom'] as String,
          paused: d['paused'] == true,
          rule: Map<String, Object?>.from(d['rule'] as Map),
        );
      });
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      return (await _functions
              .httpsCallable(name)
              .call<Map<String, dynamic>>(data))
          .data;
    } on FirebaseFunctionsException catch (e) {
      throw ChoreFailure(switch (e.code) {
        'aborted' => 'The chore, repeat settings or household timezone changed. Return to its details and open the settings again.',
        'permission-denied' =>
          'Your account can’t manage this household’s repeat settings.',
        'invalid-argument' => 'Check dates, times and eligible members. Changes must begin tomorrow or within the next thirty household days.',
        'failed-precondition' => 'Each turn needs an available reviewer when review is enabled. Start after any already recorded future assignment.',
        'already-exists' => 'This request was already used. Return to the chore list to check its saved settings.',
        'not-found' => 'This chore is no longer available.',
        'resource-exhausted' =>
          'The daily change limit was reached. Try again later.',
        _ => 'Couldn’t confirm these settings. Check your connection and retry the same request.',
      }, conflict: e.code == 'aborted');
    }
  }

  @override
  Future<RecurrencePreview> preview({
    required String householdId,
    required String templateId,
    required String fromDate,
    required bool paused,
    required Map<String, Object?> rule,
  }) async {
    final result = await _call('previewRecurrence', {
      'householdId': householdId,
      'templateId': templateId,
      'fromDate': fromDate,
      'rule': rule,
      'paused': paused,
    });
    return RecurrencePreview(
      timezone: result['timezoneIana'] as String,
      paused: result['paused'] == true,
      turns: (result['slots'] as List).map((raw) {
        final d = Map<String, dynamic>.from(raw as Map);
        return PreviewTurn(
          date: d['date'] as String,
          plannedActorId: d['plannedActorId'] as String,
          assignedActorIds: List<String>.from(d['assignedActorIds'] as List),
          status: d['status'] as String,
          reason: d['reason'] as String?,
          timeAdjusted: d['timeAdjusted'] == true,
        );
      }).toList(),
    );
  }

  @override
  Future<void> save({
    required String householdId,
    required String templateId,
    required String commandId,
    required int baseTemplateVersion,
    required int baseRuleVersion,
    required String effectiveFrom,
    required String expectedTimezone,
    required bool paused,
    required Map<String, Object?> rule,
  }) async {
    await _call('saveRecurrence', {
      'householdId': householdId,
      'templateId': templateId,
      'commandId': commandId,
      'baseTemplateVersion': baseTemplateVersion,
      'baseRuleVersion': baseRuleVersion,
      'effectiveFrom': effectiveFrom,
      'expectedTimezone': expectedTimezone,
      'paused': paused,
      'rule': rule,
    });
    try {
      await _db
          .collection('households/$householdId/occurrences')
          .get(const GetOptions(source: Source.server));
    } on FirebaseException {
      throw const ChoreFailure(
        'Couldn’t refresh the saved schedule. Retry the same request.',
      );
    }
  }
}
