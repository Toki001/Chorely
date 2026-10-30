import 'package:flutter/material.dart';

import 'chore_command_scope.dart';

Future<void> confirmAccountExit(
  BuildContext context,
  Future<void> Function() leave,
) async {
  final count =
      ChoreCommandScope.maybeOf(context)?.rows.where((r) => r.pending).length ??
      0;
  if (count > 0) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave with requests waiting?'),
        content: SingleChildScrollView(
          child: Text(
            '$count ${count == 1 ? 'request is' : 'requests are'} still waiting for confirmation. Signing out removes saved requests from this device. Chores already saved in your household stay saved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep working'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  await leave();
}
