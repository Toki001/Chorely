import 'recurrence_repository.dart';
import 'chore_actions.dart';
export 'chore_actions.dart';

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
    this.schedulingReason,
    this.contributions = const [],
    this.helpRequests = const [],
    this.completionRevision = 0,
    this.reviewNote,
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
  final String? schedulingReason;
  String get statusLabel => switch (status) {
    'scheduled' => 'Assigned',
    'skipped' => 'Skipped',
    'cancelled' => 'Cancelled',
    'completed' => 'Done',
    'approved' => 'Approved',
    'pending_review' => 'Waiting for review',
    'needs_redo' => 'Try again',
    _ => 'Status unavailable',
  };
  final List<ChoreContribution> contributions;
  final List<ChoreHelp> helpRequests;
  final int completionRevision;
  final String? reviewNote;
  bool get cancellable => status == 'scheduled';
  bool get editable => cancellable && contributions.isEmpty;
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
  const ChoreFailure(
    this.message, {
    this.conflict = false,
    this.retryable = true,
  });
  final String message;
  final bool conflict;
  final bool retryable;
}

abstract interface class ChoreRepository {
  RecurrenceRepository get recurrence;
  Stream<ChoreActor?> watchActor(String householdId, String uid);
  Stream<HelpRequest?> watchHelp(String householdId, String requestId);
  Stream<List<ChoreActivity>> watchActivity(
    String householdId,
    String occurrenceId,
  );
  Future<void> refresh(String householdId, String occurrenceId);
  Future<void> act({
    required String householdId,
    required String occurrenceId,
    required String commandId,
    required String action,
    required int baseVersion,
    String note = '',
    String? targetActorId,
  });
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
