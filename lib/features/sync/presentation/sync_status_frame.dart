import 'package:flutter/material.dart';

import '../domain/chore_command_outbox.dart';
import '../domain/read_cache.dart';

class SyncStatusFrame extends StatelessWidget {
  const SyncStatusFrame({
    required this.outbox,
    required this.cache,
    required this.child,
    super.key,
  });
  final ChoreCommandOutbox outbox;
  final HouseholdReadCache cache;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([outbox, cache]),
    builder: (context, _) {
      final pending = outbox.rows.where((r) => r.pending).length;
      final blocked = outbox.rows.where((r) => r.blocked).length;
      if (!cache.hasSavedReads && pending == 0 && blocked == 0) return child;
      return Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.33,
            ),
            child: SingleChildScrollView(
              child: Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!,
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (cache.hasSavedReads)
                              const Text(
                                'Showing saved household data. Waiting for a connection check.',
                              ),
                            if (pending > 0)
                              Text(
                                '$pending ${pending == 1 ? 'request is' : 'requests are'} waiting for server confirmation.',
                              ),
                            if (blocked > 0)
                              Text(
                                '$blocked saved ${blocked == 1 ? 'request needs' : 'requests need'} review. Open the chore to check its current state.',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      );
    },
  );
}
