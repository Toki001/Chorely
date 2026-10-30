import '../../chores/domain/chore_repository.dart';
import '../../households/domain/household_repository.dart';
import '../../family/domain/family_repository.dart';

Map<String, dynamic> objectMap(Object? value) =>
    Map<String, dynamic>.from(value! as Map);
List<T> objectList<T>(Object? value, T Function(Object?) read) =>
    (value! as List).map(read).toList();
DateTime? _date(Object? value) => value == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
Map<String, Object?> saveChore(ChoreOccurrence c) => {
  'schema': 1,
  'id': c.id,
  'templateId': c.templateId,
  'version': c.version,
  'templateVersion': c.templateVersion,
  'status': c.status,
  'postponed': c.postponed,
  'timezone': c.timezone,
  'timeAdjusted': c.timeAdjusted,
  'effectiveDueLocal': c.effectiveDueLocal,
  'effectiveStartLocal': c.effectiveStartLocal,
  'schedulingReason': c.schedulingReason,
  'due': c.dueAtUtc?.millisecondsSinceEpoch,
  'start': c.windowStartAtUtc?.millisecondsSinceEpoch,
  'revision': c.completionRevision,
  'reviewNote': c.reviewNote,
  'draft': c.draft.toMap(),
  'contributions': [
    for (final p in c.contributions)
      {
        'id': p.actorId,
        'at': p.acceptedAt.millisecondsSinceEpoch,
        'revision': p.completionRevision,
      },
  ],
  'help': [
    for (final h in c.helpRequests)
      {'id': h.actorId, 'request': h.requestId, 'status': h.status},
  ],
};
ChoreOccurrence readChore(Object? value) {
  final m = objectMap(value), d = objectMap(m['draft']);
  if (m['schema'] != 1) throw const FormatException('Unsupported saved chore');
  return ChoreOccurrence(
    id: m['id'] as String,
    templateId: m['templateId'] as String,
    version: m['version'] as int,
    templateVersion: m['templateVersion'] as int,
    status: m['status'] as String,
    postponed: m['postponed'] == true,
    timezone: m['timezone'] as String,
    timeAdjusted: m['timeAdjusted'] == true,
    effectiveDueLocal: m['effectiveDueLocal'] as String?,
    effectiveStartLocal: m['effectiveStartLocal'] as String?,
    schedulingReason: m['schedulingReason'] as String?,
    dueAtUtc: _date(m['due']),
    windowStartAtUtc: _date(m['start']),
    completionRevision: m['revision'] as int,
    reviewNote: m['reviewNote'] as String?,
    contributions: objectList(m['contributions'], (v) {
      final c = objectMap(v);
      return ChoreContribution(
        actorId: c['id'] as String,
        acceptedAt: _date(c['at'])!,
        completionRevision: c['revision'] as int,
      );
    }),
    helpRequests: objectList(m['help'], (v) {
      final h = objectMap(v);
      return ChoreHelp(
        actorId: h['id'] as String,
        requestId: h['request'] as String,
        status: h['status'] as String,
      );
    }),
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
      schedule: Map<String, Object?>.from(d['schedule'] as Map),
    ),
  );
}

Map<String, Object?> saveClock(HouseholdClock c) => {
  'today': c.today,
  'timezone': c.timezone,
  'serverNow': c.serverNow.millisecondsSinceEpoch,
  'nextMidnight': c.nextMidnight.millisecondsSinceEpoch,
  'actor': saveActor(c.actor),
};
HouseholdClock readClock(Object? value) {
  final c = objectMap(value);
  return HouseholdClock(
    today: c['today'] as String,
    timezone: c['timezone'] as String,
    serverNow: _date(c['serverNow'])!,
    nextMidnight: _date(c['nextMidnight'])!,
    actor: readActor(c['actor']),
  );
}

Map<String, Object?> saveActor(ChoreActor a) => {
  'id': a.id,
  'role': a.role,
  'canManage': a.canManage,
};
ChoreActor readActor(Object? value) {
  final a = objectMap(value);
  return ChoreActor(
    id: a['id'] as String,
    role: a['role'] as String,
    canManage: a['canManage'] == true,
  );
}

Map<String, Object?> saveHome(Household h) => {
  'id': h.id,
  'name': h.name,
  'timezone': h.timezone,
};
Household readHome(Object? value) {
  final h = objectMap(value);
  return Household(
    id: h['id'] as String,
    name: h['name'] as String,
    timezone: h['timezone'] as String,
  );
}

Map<String, Object?> savePerson(FamilyPerson p) => {
  'id': p.id,
  'nickname': p.nickname,
  'role': p.role,
  'active': p.active,
};
FamilyPerson readPerson(Object? value) {
  final p = objectMap(value);
  return FamilyPerson(
    id: p['id'] as String,
    nickname: p['nickname'] as String,
    role: p['role'] as String,
    active: p['active'] == true,
  );
}
