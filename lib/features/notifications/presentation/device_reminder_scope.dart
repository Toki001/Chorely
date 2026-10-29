import 'package:flutter/widgets.dart';

import '../domain/device_reminders.dart';

class DeviceReminderScope extends InheritedWidget {
  const DeviceReminderScope({
    required this.controller,
    required super.child,
    super.key,
  });
  final DeviceReminderController controller;
  static DeviceReminderController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DeviceReminderScope>()
      ?.controller;
  @override
  bool updateShouldNotify(DeviceReminderScope oldWidget) =>
      oldWidget.controller != controller;
}
