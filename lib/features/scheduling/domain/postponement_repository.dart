class PostponementRequest {
  PostponementRequest({
    required this.householdId,
    required this.occurrenceId,
    required this.commandId,
    required this.baseVersion,
    required Map<String, Object?> schedule,
  }) : schedule = Map.unmodifiable(schedule);
  final String householdId, occurrenceId, commandId;
  final int baseVersion;
  final Map<String, Object?> schedule;
  Map<String, Object?> toMap() => {
    'householdId': householdId,
    'occurrenceId': occurrenceId,
    'commandId': commandId,
    'baseVersion': baseVersion,
    'schedule': schedule,
  };
}

abstract interface class PostponementRepository {
  Future<void> postpone(PostponementRequest request);
  Future<void> refresh(String householdId, String occurrenceId);
}
