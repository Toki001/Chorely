import '../domain/read_cache.dart';

import 'package:flutter/widgets.dart';

import '../domain/chore_command_outbox.dart';

class ChoreCommandScope extends InheritedWidget {
  const ChoreCommandScope({
    required this.outbox,
    this.readCache,
    required super.child,
    super.key,
  });
  final ChoreCommandOutbox outbox;
  final HouseholdReadCache? readCache;
  static HouseholdReadCache? cacheOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChoreCommandScope>()
      ?.readCache;
  static ChoreCommandOutbox? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChoreCommandScope>()?.outbox;
  @override
  bool updateShouldNotify(ChoreCommandScope oldWidget) =>
      oldWidget.outbox != outbox;
}
