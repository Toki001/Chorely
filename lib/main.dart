import 'features/sync/data/sqlite_read_cache_store.dart';
import 'features/sync/data/cached_account_session_store.dart';
import 'features/sync/domain/read_cache.dart';
import 'features/sync/domain/chore_command_outbox.dart';
import 'features/sync/data/sqlite_chore_command_store.dart';
import 'features/sync/presentation/chore_command_scope.dart';
import 'features/notifications/domain/notifications_repository.dart';
import 'features/notifications/data/native_notification_device.dart';
import 'features/notifications/data/sqlite_reminder_ledger.dart';
import 'features/notifications/domain/device_reminders.dart';
import 'features/notifications/presentation/device_reminder_scope.dart';
import 'features/notifications/data/firebase_notifications_repository.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'features/chores/data/firebase_chore_repository.dart';
import 'app/chorely_app.dart';
import 'app/theme.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/households/data/firebase_household_repository.dart';
import 'features/family/data/firebase_family_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kDebugMode) debugPrint('Chorely: initializing local backend');
    await initializeDevelopmentBackend();
    if (kDebugMode) debugPrint('Chorely: backend configured');
    mountApplication();
  } catch (_) {
    runApp(
      MaterialApp(
        theme: chorelyTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 56),
                    const SizedBox(height: 20),
                    const Text(
                      'Chorely couldn’t start. Please close the app and try again.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void mountApplication() {
  final notifications = FirebaseNotificationsRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
  );
  final cacheStore = SqliteReadCacheStore();
  late final ChoreCommandOutbox outbox;
  final cache = HouseholdReadCache(
    cacheStore,
    isDenied: (e) =>
        e is FirebaseException &&
        ['permission-denied', 'unauthenticated'].contains(e.code),
    isTransient: (e) =>
        e is FirebaseException &&
        [
          'unavailable',
          'deadline-exceeded',
          'network-request-failed',
          'internal',
          'unknown',
        ].contains(e.code),
    onRevoke: (hid) => outbox.purgeHousehold(hid),
  );
  final chores = FirebaseChoreRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
    readCache: cache,
  );
  outbox = ChoreCommandOutbox(
    SqliteChoreCommandStore(),
    (command) => chores.act(
      householdId: command.householdId,
      occurrenceId: command.occurrenceId,
      commandId: command.id,
      action: command.action,
      baseVersion: command.baseVersion,
      note: command.note,
      targetActorId: command.targetActorId,
    ),
  );
  final device = NativeNotificationDevice();
  final controller = DeviceReminderController(
    notifications,
    SqliteReminderLedger(),
    device,
  );
  // Notification initialization failure cannot prevent access to household chores.
  final ready = device.initialize().catchError((Object _) {});
  runApp(
    ChoreCommandScope(
      outbox: outbox,
      readCache: cache,
      child: DeviceReminderScope(
        controller: controller,
        child: ChorelyApp(
          auth: FirebaseAuthRepository(
            FirebaseAuth.instance,
            sessionStore: CachedAccountSessionStore(
              cacheStore,
              currentUid: () => FirebaseAuth.instance.currentUser?.uid,
            ),
          ),
          notifications: notifications,
          notificationLaunches: _ReadyNotificationLaunches(device, ready),
          chores: chores,
          family: FirebaseFamilyRepository(
            FirebaseFirestore.instance,
            FirebaseFunctions.instance,
            FirebaseAuth.instance,
            readCache: cache,
          ),
          households: FirebaseHouseholdRepository(
            FirebaseFirestore.instance,
            FirebaseFunctions.instance,
            readCache: cache,
          ),
        ),
      ),
    ),
  );
}

class _ReadyNotificationLaunches implements NotificationLaunchSource {
  _ReadyNotificationLaunches(this.source, this.ready);
  final NativeNotificationDevice source;
  final Future<void> ready;
  @override
  Future<NotificationLink?> initial() async {
    await ready;
    const injected = String.fromEnvironment('CHORELY_TEST_NOTIFICATION');
    // Native cold-process tests inject only an opaque route, never authority.
    return (kDebugMode ? NotificationLink.parse(injected) : null) ??
        await source.initial();
  }

  @override
  Stream<NotificationLink> get taps => source.taps;
}

Future<void> initializeDevelopmentBackend() async {
  // No live project fallback. An authorized staging/prod configuration is a
  // separate gate. Release builds must never accept emulator credentials.
  const emulatorMode = bool.fromEnvironment(
    'CHORELY_EMULATORS',
    defaultValue: true,
  );
  if (kReleaseMode || !emulatorMode) {
    throw StateError('Authorized live configuration required');
  }
  const overrideHost = String.fromEnvironment('CHORELY_EMULATOR_HOST');
  final host = overrideHost.isNotEmpty
      ? overrideHost
      : defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'A00000000000000000000000000000000000000',
      appId: '1:1234567890:ios:0123456789abcdef',
      messagingSenderId: '1234567890',
      projectId: 'demo-chorely',
    ),
  );
  if (kDebugMode) debugPrint('Chorely: Firebase initialized');
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  if (kDebugMode) debugPrint('Chorely: Auth emulator configured');
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  const offlineReadTest = bool.fromEnvironment('CHORELY_TEST_OFFLINE_DATA');
  if (kDebugMode && offlineReadTest) {
    await FirebaseFirestore.instance.disableNetwork();
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5999);
  }
  if (kDebugMode) debugPrint('Chorely: data emulators configured');
}
