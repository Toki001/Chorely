class RecurrenceConfiguration {
  const RecurrenceConfiguration({
    required this.version,
    required this.templateVersion,
    required this.effectiveFrom,
    required this.paused,
    required this.rule,
  });
  final int version;
  final int templateVersion;
  final String effectiveFrom;
  final bool paused;
  final Map<String, Object?> rule;
}

class PreviewTurn {
  const PreviewTurn({
    required this.date,
    required this.plannedActorId,
    required this.assignedActorIds,
    required this.status,
    required this.reason,
    required this.timeAdjusted,
  });
  final String date;
  final String plannedActorId;
  final List<String> assignedActorIds;
  final String status;
  final String? reason;
  final bool timeAdjusted;
}

class RecurrencePreview {
  const RecurrencePreview({
    required this.timezone,
    required this.turns,
    required this.paused,
  });
  final String timezone;
  final List<PreviewTurn> turns;
  final bool paused;
}

abstract interface class RecurrenceRepository {
  Stream<RecurrenceConfiguration?> watchConfiguration(
    String householdId,
    String templateId,
  );
  Future<RecurrencePreview> preview({
    required String householdId,
    required String templateId,
    required String fromDate,
    required bool paused,
    required Map<String, Object?> rule,
  });
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
  });
}

String recurrenceReasonLabel(String? reason) => switch (reason) {
  'unavailable_assignee' => 'Scheduled person unavailable',
  'reviewer_unavailable' => 'Separate guardian reviewer unavailable',
  'clock_change_window' => 'Window unavailable after a clock change',
  'substitute' => 'Next available person takes this turn',
  _ => '',
};
