import 'package:chorely/features/notifications/domain/notifications_repository.dart';

class TestNotifications implements NotificationsRepository {
  List<HouseholdUpdate> updates = [];
  bool canEdit = true;
  NotificationFailure? failure;
  NotificationPreferences preferences = const NotificationPreferences();
  NotificationDestination? destination;
  final watches = <String>[];
  final loads = <String?>[];
  final opened = <String>[];
  final saves =
      <
        ({
          String id,
          NotificationSettings base,
          NotificationPreferences preferences,
        })
      >[];
  @override
  Future<NotificationSettings> load(
    String householdId, {
    String? actorId,
  }) async {
    loads.add(actorId);
    return NotificationSettings(
      actorId: actorId ?? 'guardian',
      version: 1,
      timezone: 'Asia/Manila',
      canEdit: canEdit,
      preferences: preferences,
    );
  }

  @override
  Future<void> save(
    String householdId,
    String commandId,
    NotificationSettings base,
    NotificationPreferences preferences,
  ) async {
    saves.add((id: commandId, base: base, preferences: preferences));
    if (failure != null) throw failure!;
    this.preferences = preferences;
  }

  @override
  Stream<List<HouseholdUpdate>> watchInbox(String householdId, String actorId) {
    watches.add(actorId);
    return Stream.value(updates);
  }

  @override
  Future<NotificationDestination?> open(
    String householdId,
    String notificationId,
  ) async {
    opened.add(notificationId);
    return destination;
  }
}
