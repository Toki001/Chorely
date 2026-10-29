import 'dart:convert';

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.channel = 'in_app',
    this.assignment = true,
    this.due = true,
    this.overdue = true,
    this.review = true,
    this.help = true,
    this.reminderMinutes = 15,
    this.quietEnabled = true,
    this.quietStart = '20:00',
    this.quietEnd = '08:00',
  });
  final bool enabled, assignment, due, overdue, review, help, quietEnabled;
  final String channel, quietStart, quietEnd;
  final int reminderMinutes;
  Map<String, Object?> toMap() => {
    'enabled': enabled,
    'channel': channel,
    'assignment': assignment,
    'due': due,
    'overdue': overdue,
    'review': review,
    'help': help,
    'reminderMinutes': reminderMinutes,
    'quietHours': {
      'enabled': quietEnabled,
      'start': quietStart,
      'end': quietEnd,
    },
  };
  NotificationPreferences copyWith({
    bool? enabled,
    String? channel,
    bool? assignment,
    bool? due,
    bool? overdue,
    bool? review,
    bool? help,
    int? reminderMinutes,
    bool? quietEnabled,
    String? quietStart,
    String? quietEnd,
  }) => NotificationPreferences(
    enabled: enabled ?? this.enabled,
    channel: channel ?? this.channel,
    assignment: assignment ?? this.assignment,
    due: due ?? this.due,
    overdue: overdue ?? this.overdue,
    review: review ?? this.review,
    help: help ?? this.help,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
  );
}

class NotificationSettings {
  const NotificationSettings({
    required this.actorId,
    required this.version,
    required this.timezone,
    required this.canEdit,
    required this.preferences,
  });
  final String actorId, timezone;
  final int version;
  final bool canEdit;
  final NotificationPreferences preferences;
}

class HouseholdUpdate {
  const HouseholdUpdate({
    required this.id,
    required this.occurrenceId,
    required this.title,
    required this.body,
    required this.publishedAt,
    required this.unread,
  });
  final String id, occurrenceId, title, body;
  final DateTime publishedAt;
  final bool unread;
}

class NotificationDestination {
  const NotificationDestination({
    required this.householdId,
    required this.occurrenceId,
    required this.actorId,
  });
  final String householdId, occurrenceId, actorId;
}

class NotificationFailure implements Exception {
  const NotificationFailure(
    this.message, {
    this.conflict = false,
    this.retryable = true,
  });
  final String message;
  final bool conflict, retryable;
}

abstract interface class NotificationsRepository {
  Future<NotificationSettings> load(String householdId, {String? actorId});
  Future<void> save(
    String householdId,
    String commandId,
    NotificationSettings base,
    NotificationPreferences preferences,
  );
  Stream<List<HouseholdUpdate>> watchInbox(String householdId, String actorId);
  Future<NotificationDestination?> open(
    String householdId,
    String notificationId,
  );
}

abstract interface class NotificationLaunchSource {
  Future<NotificationLink?> initial();
  Stream<NotificationLink> get taps;
}

/// A link carries opaque IDs only. It grants no authority and cannot mutate a chore.
class NotificationLink {
  const NotificationLink({
    required this.householdId,
    required this.notificationId,
    required this.actorId,
  });
  final String householdId, notificationId, actorId;
  String encode() => jsonEncode({
    'v': 1,
    'householdId': householdId,
    'notificationId': notificationId,
    'actorId': actorId,
  });
  static NotificationLink? parse(String? value) {
    if (value == null || value.length > 2048) return null;
    try {
      final data = jsonDecode(value);
      final id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
      if (data is! Map<String, dynamic> ||
          data['v'] != 1 ||
          data['householdId'] is! String ||
          !id.hasMatch(data['householdId'] as String) ||
          data['actorId'] is! String ||
          !id.hasMatch(data['actorId'] as String) ||
          data['notificationId'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$')
              .hasMatch(data['notificationId'] as String)) {
        return null;
      }
      return NotificationLink(
        householdId: data['householdId'] as String,
        notificationId: data['notificationId'] as String,
        actorId: data['actorId'] as String,
      );
    } on FormatException {
      return null;
    }
  }
}
