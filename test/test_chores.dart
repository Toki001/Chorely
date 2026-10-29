import 'test_recurrence.dart';

import 'package:chorely/features/chores/domain/chore_repository.dart';

class TestChores implements ChoreRepository {
  @override
  final TestRecurrence recurrence = TestRecurrence();
  bool canManage = true;
  ChoreFailure? failure;
  final writes =
      <
        ({String id, ChoreDraft? draft, ChoreOccurrence? base, String action})
      >[];
  List<ChoreOccurrence> chores = [];
  @override
  Stream<bool> watchCanManage(String householdId, String uid) =>
      Stream.value(canManage);
  @override
  Stream<List<ChoreOccurrence>> watchChores(
    String householdId, {
    String? actorId,
  }) => Stream.value(
    chores
        .where(
          (c) => actorId == null || c.draft.assignedActorIds.contains(actorId),
        )
        .toList(),
  );
  @override
  Stream<ChoreOccurrence?> watchChore(
    String householdId,
    String occurrenceId,
  ) => Stream.value(chores.where((c) => c.id == occurrenceId).firstOrNull);
  @override
  Future<void> write({
    required String householdId,
    required String commandId,
    required String action,
    ChoreDraft? draft,
    ChoreOccurrence? base,
  }) async {
    writes.add((id: commandId, draft: draft, base: base, action: action));
    if (failure != null) throw failure!;
  }

  ChoreActor? actor;
  ChoreFailure? actionFailure;
  List<ChoreActivity> activity = [];
  final help = <String, HelpRequest>{};
  final helpWatches = <String>[];
  int activityWatches = 0;
  final actions =
      <
        ({String id, String action, int version, String note, String? target})
      >[];
  @override
  Stream<ChoreActor?> watchActor(String householdId, String uid) =>
      Stream.value(
        actor ??
            ChoreActor(
              id: uid,
              role: canManage ? 'guardian' : 'adult',
              canManage: canManage,
            ),
      );
  @override
  Stream<HelpRequest?> watchHelp(String householdId, String requestId) {
    helpWatches.add(requestId);
    return Stream.value(help[requestId]);
  }

  @override
  Stream<List<ChoreActivity>> watchActivity(
    String householdId,
    String occurrenceId,
  ) {
    activityWatches++;
    return Stream.value(activity);
  }

  @override
  Future<void> refresh(String householdId, String occurrenceId) async {}
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
    actions.add((
      id: commandId,
      action: action,
      version: baseVersion,
      note: note,
      target: targetActorId,
    ));
    if (actionFailure != null) throw actionFailure!;
  }

  @override
  Future<HouseholdClock> loadClock(String householdId) async {
    if (clockFailure) throw const ChoreFailure('Clock unavailable');
    return clock ??
        HouseholdClock(
          today: '2026-10-29',
          timezone: 'Asia/Manila',
          serverNow: DateTime.utc(2026, 10, 29, 4),
          nextMidnight: DateTime.utc(2026, 10, 29, 16),
          actor:
              actor ??
              ChoreActor(
                id: 'guardian',
                role: canManage ? 'guardian' : 'adult',
                canManage: canManage,
              ),
        );
  }

  bool clockFailure = false;
  HouseholdClock? clock;
  final ranges = <({String from, String through, String? actor})>[];
  @override
  Stream<List<ChoreOccurrence>> watchRange(
    String householdId,
    String fromDate,
    String throughDate, {
    String? actorId,
  }) {
    ranges.add((from: fromDate, through: throughDate, actor: actorId));
    return Stream.value(
      chores
          .where(
            (c) =>
                c.localDate.compareTo(fromDate) >= 0 &&
                c.localDate.compareTo(throughDate) <= 0 &&
                (actorId == null || c.draft.assignedActorIds.contains(actorId)),
          )
          .toList(),
    );
  }
}
