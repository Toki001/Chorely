import 'package:chorely/features/sync/presentation/confirm_account_exit.dart';
import 'package:chorely/features/sync/presentation/chore_command_scope.dart';
import 'package:chorely/features/sync/domain/chore_command_outbox.dart';
import 'package:chorely/features/sync/domain/read_cache.dart';
import 'package:chorely/features/sync/presentation/sync_status_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chore_command_outbox_test.dart' show CommandMemoryStore, command;
import 'read_cache_test.dart' show CacheMemoryStore;

void main() {
  testWidgets(
    'Pending and cached banners preserve the current detail route at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final outbox = ChoreCommandOutbox(
        CommandMemoryStore(DateTime.now),
        (_) async {},
        automatic: false,
      );
      outbox.identity('device');
      final cacheStore = CacheMemoryStore(),
          cache = HouseholdReadCache(
            cacheStore,
            isDenied: (_) => false,
            isTransient: (_) => true,
          );
      cache.identity('device');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: SyncStatusFrame(outbox: outbox, cache: cache, child: child!),
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: SingleChildScrollView(child: Text('Current detail')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await outbox.enqueue(command());
      await tester.pumpAndSettle();
      expect(find.text('Current detail'), findsOneWidget);
      expect(
        find.text('1 request is waiting for server confirmation.'),
        findsOneWidget,
      );
      await cacheStore.write(
        'device',
        'home',
        'clock',
        'saved',
        DateTime.now(),
      );
      await cache.load<String>(
        householdId: 'home',
        key: 'clock',
        server: () async => throw StateError('offline'),
        encode: (v) => v,
        decode: (v) => v as String,
      );
      await tester.pumpAndSettle();
      expect(find.text('Current detail'), findsOneWidget);
      expect(
        find.text(
          'Showing saved household data. Waiting for a connection check.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      cache.dispose();
      outbox.dispose();
    },
  );
  testWidgets(
    'Leaving a pending request explains removal and can be cancelled',
    (tester) async {
      final outbox = ChoreCommandOutbox(
        CommandMemoryStore(DateTime.now),
        (_) async {},
        automatic: false,
      );
      outbox.identity('device');
      await outbox.enqueue(command());
      var left = false;
      await tester.pumpWidget(
        ChoreCommandScope(
          outbox: outbox,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => confirmAccountExit(context, () async {
                    left = true;
                  }),
                  child: const Text('Leave'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Leave with requests waiting?'), findsOneWidget);
      await tester.tap(find.text('Keep working'));
      await tester.pumpAndSettle();
      expect(left, false);
      expect(outbox.rows.single.pending, true);
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(left, true);
      await tester.pumpWidget(const SizedBox());
      outbox.dispose();
    },
  );
}
