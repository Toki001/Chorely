import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/chores/domain/recurrence_repository.dart';

class TestRecurrence implements RecurrenceRepository {
  RecurrenceConfiguration? configuration;
  ChoreFailure? failure;
  int previews = 0;
  final saves = <({String id, Map<String, Object?> rule, int baseVersion})>[];
  @override
  Stream<RecurrenceConfiguration?> watchConfiguration(
    String householdId,
    String templateId,
  ) => Stream.value(configuration);
  @override
  Future<RecurrencePreview> preview({
    required String householdId,
    required String templateId,
    required String fromDate,
    required bool paused,
    required Map<String, Object?> rule,
  }) async {
    previews++;
    return RecurrencePreview(
      timezone: 'Asia/Manila',
      paused: paused,
      turns: paused
          ? []
          : [
              PreviewTurn(
                date: fromDate,
                plannedActorId: 'child',
                assignedActorIds: const ['child'],
                status: 'scheduled',
                reason: null,
                timeAdjusted: false,
              ),
            ],
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
    saves.add((id: commandId, rule: rule, baseVersion: baseRuleVersion));
    if (failure != null) throw failure!;
  }
}
