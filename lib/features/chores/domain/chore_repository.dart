class ChoreDraft {
  const ChoreDraft({
    required this.title,
    required this.category,
    required this.description,
    required this.room,
    required this.steps,
    required this.assignedActorIds,
    required this.completionPolicy,
    required this.reviewMode,
    required this.schedule,
    this.instructionIllustrationKey,
  });
  final String title;
  final String category;
  final String description;
  final String room;
  final List<String> steps;
  final List<String> assignedActorIds;
  final String completionPolicy;
  final String reviewMode;
  final Map<String, Object?> schedule;
  final String? instructionIllustrationKey;
  Map<String, Object?> toMap() => {
    'title': title,
    'category': category,
    'description': description,
    'room': room,
    'steps': steps,
    'assignedActorIds': assignedActorIds,
    'completionPolicy': completionPolicy,
    'reviewMode': reviewMode,
    'schedule': schedule,
    'instructionIllustrationKey': instructionIllustrationKey,
  };
}

class ChoreOccurrence {
  const ChoreOccurrence({
    required this.id,
    required this.templateId,
    required this.version,
    required this.templateVersion,
    required this.status,
    required this.draft,
    required this.timezone,
    required this.timeAdjusted,
    this.effectiveDueLocal,
    this.effectiveStartLocal,
  });
  final String id;
  final String templateId;
  final int version;
  final int templateVersion;
  final String status;
  final ChoreDraft draft;
  final String timezone;
  final bool timeAdjusted;
  final String? effectiveDueLocal;
  final String? effectiveStartLocal;
  bool get editable => status == 'scheduled';
  String get timingLabel {
    final date = draft.schedule['date'];
    return switch (draft.schedule['kind']) {
      'none' => '$date · Any time',
      'time' => '$date at ${draft.schedule['at']}',
      'deadline' => '$date · By ${draft.schedule['at']}',
      _ => '${draft.schedule['startLocal']} – ${draft.schedule['endLocal']}',
    };
  }
}

class ChoreFailure implements Exception {
  const ChoreFailure(this.message, {this.conflict = false});
  final String message;
  final bool conflict;
}

abstract interface class ChoreRepository {
  Stream<bool> watchCanManage(String householdId, String uid);
  Stream<List<ChoreOccurrence>> watchChores(
    String householdId, {
    String? actorId,
  });
  Stream<ChoreOccurrence?> watchChore(String householdId, String occurrenceId);
  Future<void> write({
    required String householdId,
    required String commandId,
    required String action,
    ChoreDraft? draft,
    ChoreOccurrence? base,
  });
}
