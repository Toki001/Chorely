import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/device_reminders.dart';
import '../domain/notifications_repository.dart';

/// Demo builds never register with FCM/APNs. Remote-tap parsing is ready for an
/// authorized live configuration; data-only notifications cannot execute actions.
class NativeNotificationDevice
    implements ReminderDevice, NotificationLaunchSource {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<NotificationLink>.broadcast();
  NotificationLink? _launch;
  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _receive(response.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _launch = NotificationLink.parse(launch?.notificationResponse?.payload);
    }
    // Reading launch data does not register this demo installation or enable auto-init.
    final remote = await FirebaseMessaging.instance.getInitialMessage();
    _launch ??= NotificationLink.parse(remote?.data['chorely'] as String?);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = message.data['chorely'];
      if (payload is String) _receive(payload);
    });
  }

  void _receive(String? payload) {
    final link = NotificationLink.parse(payload);
    if (link != null) _taps.add(link);
  }

  @override
  Future<NotificationLink?> initial() async {
    final value = _launch;
    _launch = null;
    return value;
  }

  @override
  Stream<NotificationLink> get taps => _taps.stream;
  @override
  Future<bool> permission({bool request = false}) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      if (request) await android.requestNotificationsPermission();
      return await android.areNotificationsEnabled() == true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios == null) return false;
    if (request) await ios.requestPermissions(alert: true, sound: true);
    final result = await ios.checkPermissions();
    return result?.isEnabled == true && result?.isAlertEnabled == true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'household_reminders',
      'Household reminders',
      channelDescription: 'Optional gentle chore reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: NotificationVisibility.private,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    ),
  );
  @override
  Future<void> cancelAll() => _plugin.cancelAll();
  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
  @override
  Future<void> schedule(int id, DeviceReminder reminder) =>
      _plugin.zonedSchedule(
        id: id,
        title: reminder.title,
        body: reminder.body,
        payload: reminder.payload,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
  @override
  Future<void> show(int id, DeviceReminder reminder) => _plugin.show(
    id: id,
    title: reminder.title,
    body: reminder.body,
    payload: reminder.payload,
    notificationDetails: _details,
  );
}
