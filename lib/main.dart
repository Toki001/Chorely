import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

void mountApplication() => runApp(
  ChorelyApp(
    auth: FirebaseAuthRepository(FirebaseAuth.instance),
    family: FirebaseFamilyRepository(
      FirebaseFirestore.instance,
      FirebaseFunctions.instance,
      FirebaseAuth.instance,
    ),
    households: FirebaseHouseholdRepository(
      FirebaseFirestore.instance,
      FirebaseFunctions.instance,
    ),
  ),
);

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
  if (kDebugMode) debugPrint('Chorely: data emulators configured');
}
