class ChoreActor {
  const ChoreActor({
    required this.id,
    required this.role,
    required this.canManage,
  });
  final String id;
  final String role;
  final bool canManage;
  bool get guardian => role == 'guardian';
}

class ChoreContribution {
  const ChoreContribution({
    required this.actorId,
    required this.acceptedAt,
    required this.completionRevision,
  });
  final String actorId;
  final DateTime acceptedAt;
  final int completionRevision;
}

class ChoreHelp {
  const ChoreHelp({
    required this.actorId,
    required this.requestId,
    required this.status,
  });
  final String actorId;
  final String requestId;
  final String status;
}

class HelpRequest {
  const HelpRequest({
    required this.id,
    required this.actorId,
    required this.note,
    required this.status,
    this.responseNote,
  });
  final String id;
  final String actorId;
  final String note;
  final String status;
  final String? responseNote;
}

class ChoreActivity {
  const ChoreActivity({
    required this.id,
    required this.actorId,
    required this.action,
    required this.serverAt,
    required this.toStatus,
    this.system = false,
    this.reviewNote,
  });
  final String id;
  final String actorId;
  final String action;
  final String? toStatus;
  final DateTime serverAt;
  final bool system;
  final String? reviewNote;
  String get label => switch (action) {
    'occurrence_complete' =>
      toStatus == 'scheduled'
          ? 'Recorded their part'
          : toStatus == 'pending_review'
          ? 'Marked done · Waiting for review'
          : 'Marked done',
    'occurrence_undo' => 'Undid their part',
    'occurrence_approve' => 'Approved the chore',
    'occurrence_redo' => 'Asked for another look',
    'occurrence_help' => 'Asked for help',
    'occurrence_help_resolved' => 'Marked a help request answered',
    'chore_create' => 'Created this chore',
    'chore_edit' => 'Updated this chore',
    'chore_archive' => 'Cancelled this chore',
    'recurrence_materialized' => 'Scheduled this turn',
    'recurrence_revised' => 'Changed this future turn',
    'recurrence_cancelled' => 'Cancelled this future turn',
    _ => 'Updated this chore',
  };
}

class HouseholdClock {
  const HouseholdClock({
    required this.today,
    required this.timezone,
    required this.serverNow,
    required this.nextMidnight,
    required this.actor,
  });
  final String today, timezone;
  final DateTime serverNow, nextMidnight;
  final ChoreActor actor;
}
