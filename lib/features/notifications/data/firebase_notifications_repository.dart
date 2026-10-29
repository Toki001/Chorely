import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/notifications_repository.dart';
import '../domain/device_reminders.dart';

class FirebaseNotificationsRepository
    implements NotificationsRepository, ReminderPlanRepository {
  FirebaseNotificationsRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  NotificationFailure _failure(FirebaseFunctionsException e) =>
      NotificationFailure(
        e.code == 'aborted'
            ? 'Settings or household time changed. Reload before saving.'
            : e.code == 'permission-denied' || e.code == 'unauthenticated'
            ? 'This update is unavailable for your current access.'
            : e.code == 'resource-exhausted'
            ? 'Update limit reached. Try again later or use your calendar.'
            : 'Couldn’t confirm this update. Check your connection and retry.',
        conflict: e.code == 'aborted',
        retryable: [
          'unavailable',
          'deadline-exceeded',
          'internal',
          'unknown',
        ].contains(e.code),
      );
  @override
  Future<NotificationSettings> load(
    String householdId, {
    String? actorId,
  }) async {
    try {
      final data =
          (await _functions
                  .httpsCallable('getNotificationPreferences')
                  .call<Map<String, dynamic>>({
                    'householdId': householdId,
                    'actorId': ?actorId,
                  }))
              .data;
      final p = Map<String, dynamic>.from(data['preferences'] as Map),
          quiet = Map<String, dynamic>.from(p['quietHours'] as Map);
      return NotificationSettings(
        actorId: data['actorId'] as String,
        version: (data['version'] as num).toInt(),
        timezone: data['timezoneIana'] as String,
        canEdit: data['canEdit'] == true,
        preferences: NotificationPreferences(
          enabled: p['enabled'] == true,
          channel: p['channel'] as String,
          assignment: p['assignment'] == true,
          due: p['due'] == true,
          overdue: p['overdue'] == true,
          review: p['review'] == true,
          help: p['help'] == true,
          reminderMinutes: (p['reminderMinutes'] as num).toInt(),
          quietEnabled: quiet['enabled'] == true,
          quietStart: quiet['start'] as String,
          quietEnd: quiet['end'] as String,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> save(
    String householdId,
    String commandId,
    NotificationSettings base,
    NotificationPreferences preferences,
  ) async {
    try {
      await _functions
          .httpsCallable('saveNotificationPreferences')
          .call<Object?>({
            'householdId': householdId,
            'commandId': commandId,
            'actorId': base.actorId,
            'baseVersion': base.version,
            'expectedTimezone': base.timezone,
            'preferences': preferences.toMap(),
          });
    } on FirebaseFunctionsException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Stream<List<HouseholdUpdate>> watchInbox(
    String householdId,
    String actorId,
  ) => _db
      .collection('households/$householdId/notificationInbox')
      .where('actorId', isEqualTo: actorId)
      .where('active', isEqualTo: true)
      .orderBy('publishedAt', descending: true)
      .limit(50)
      .snapshots(includeMetadataChanges: true)
      .where((s) => !s.metadata.isFromCache)
      .map(
        (s) => s.docs.map((doc) {
          final d = doc.data();
          return HouseholdUpdate(
            id: doc.id,
            occurrenceId: d['occurrenceId'] as String,
            title: d['title'] as String,
            body: d['body'] as String,
            publishedAt: (d['publishedAt'] as Timestamp).toDate().toUtc(),
            unread: d['readAt'] == null,
          );
        }).toList(),
      );
  @override
  Future<NotificationDestination?> open(
    String householdId,
    String notificationId,
  ) async {
    try {
      final data =
          (await _functions
                  .httpsCallable('openNotification')
                  .call<Map<String, dynamic>>({
                    'householdId': householdId,
                    'notificationId': notificationId,
                  }))
              .data;
      return data['available'] == true
          ? NotificationDestination(
              householdId: data['householdId'] as String,
              occurrenceId: data['occurrenceId'] as String,
              actorId: data['actorId'] as String,
            )
          : null;
    } on FirebaseFunctionsException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Stream<void> watchPlan(String householdId, String actorId) =>
      Stream<void>.multi((events) {
        final subscriptions = [
          for (final collection in [
            'reminderPlanSignals',
            'notificationPreferences',
          ])
            _db
                .doc('households/$householdId/$collection/$actorId')
                .snapshots(includeMetadataChanges: true)
                .where((s) => !s.metadata.isFromCache)
                .listen((_) => events.add(null), onError: events.addError),
        ];
        events.onCancel = () async {
          for (final s in subscriptions) {
            await s.cancel();
          }
        };
      });
  @override
  Future<LocalReminderPlan> localPlan(String householdId) async {
    try {
      final d =
          (await _functions
                  .httpsCallable('getLocalNotificationPlan')
                  .call<Map<String, dynamic>>({'householdId': householdId}))
              .data;
      return LocalReminderPlan(
        actorId: d['actorId'] as String,
        enabled: d['policyEnabled'] == true,
        serverNow: DateTime.fromMillisecondsSinceEpoch(
          (d['serverNowMillis'] as num).toInt(),
          isUtc: true,
        ),
        hasMore: d['hasMore'] == true,
        reminders: (d['reminders'] as List).map((value) {
          final r = Map<String, dynamic>.from(value as Map);
          return DeviceReminder(
            id: r['id'] as String,
            title: r['title'] as String,
            body: r['body'] as String,
            payload: r['payload'] as String,
            at: DateTime.fromMillisecondsSinceEpoch(
              (r['notifyAtMillis'] as num).toInt(),
              isUtc: true,
            ),
            expires: DateTime.fromMillisecondsSinceEpoch(
              (r['expiresAtMillis'] as num).toInt(),
              isUtc: true,
            ),
          );
        }).toList(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw _failure(e);
    }
  }
}
