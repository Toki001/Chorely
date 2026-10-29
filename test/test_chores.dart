import 'package:chorely/features/chores/domain/chore_repository.dart';

class TestChores implements ChoreRepository {
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
}
