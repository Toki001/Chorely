# Run Chorely locally

Use Flutter stable 3.47.5 / Dart 3.13.4 and Node 22.23.4. Lockfiles are committed.
Android/iOS app ID `dev.chorely.chorely` is provisional for development only.

```sh
npm ci --no-fund
npm run emulators
```

In another terminal:

```sh
flutter pub get
flutter run
```

Default debug configuration uses only demo-chorely emulator endpoints: Auth 9099,
Firestore 8080, Functions 5001. iOS uses 127.0.0.1; Android emulator uses 10.0.2.2.
Override with `--dart-define=CHORELY_EMULATOR_HOST=...` for a test device on the same
trusted development network, after intentionally configuring local access. No
physical device or external exposure has been configured by this session.

The dummy public SDK key is syntactically shaped for native Firebase validation;
it is not a live credential. No GoogleService-Info file or live project is bundled.
Release mode and non-emulator mode fail closed until authorized environment
configuration is implemented. No production readiness claimed.

Adult verification links and password resets appear in the local Auth emulator
console log. Use fictional addresses ending in example.test for manual tests.
Never use actual minors' information. Emulators reset unless the operator explicitly
exports/imports local fixtures. Do not run tests against an existing manual session:
test fixtures clear the demo project between cases.

`bash scripts/verify.sh` runs format/analyze, Flutter tests, real callable/service/rules tests,
runtime advisory checks, art/credential/P0 mapping guardrails. CI is configured
locally but has not run remotely. No remote/push/deployment has been configured.
Some local development-tool dependencies have moderate advisories (see M02).

Builds: `flutter build apk --debug` and
`flutter build ios --simulator --debug --no-codesign`. Native testing needs an
available booted simulator/device. iOS dependency resolution uses SwiftPM; first
fetch can take several minutes. No Android AVD was available at discovery.

Native household verification uses a fresh local fixture, then two separate native
test processes against the same emulators (replace the simulator ID if needed):

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_native_fixture.mjs && flutter test integration_test/household_test.dart -d 11D93CA0-385A-42CB-B905-449C8439EB01 && flutter test integration_test/household_restart_test.dart -d 11D93CA0-385A-42CB-B905-449C8439EB01'
```

The fixture script refuses non-emulator endpoints. Household writes are online
commands; duplicate retries reuse the command ID. Durable interrupted-write
recovery and cached offline experiences remain M12. The initial timezone picker
offers Philippines, New York, London, Sydney and UTC; the server validates IANA
zones. A broader localized picker is a later UX refinement.

Family supervision verification can run independently on fresh emulators:

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_family_fixture.mjs && node scripts/run_family_native.mjs 11D93CA0-385A-42CB-B905-449C8439EB01'
```

This exercises guardian child-profile creation, approval, code entry on a signed-out
device, actual custom-auth child session, adult reauthentication and device removal.
The runner checks the final persisted device state. Camera scanning starts only
when requested; the simulator journey uses code entry. Physical-camera scanning
and Android device runtime coverage remain unverified. Codes and device retry
proofs must never be copied into reports, issues or analytics.

One-off chore verification starts from the same fictional household fixture and
runs two separate native processes, asserting the stored server state after each:

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_family_fixture.mjs && node scripts/run_chores_native.mjs 11D93CA0-385A-42CB-B905-449C8439EB01'
```

This creates Cook rice in the real guardian form, reads steps in a paired child
session, edits as guardian, restarts, reads the persisted edit and cancels while
preserving the template, occurrence and three audit events. Text instruction
presets contain no cooking/safety guidance. Dates and times are entered explicitly
in the household timezone. Completion actions arrive in M09; an optional original bundled illustration is available with an accessible label. There are no placeholder Done buttons or progress figures.

The local recurrence timer uses the same trusted worker as the authored scheduled
function, with strict demo/loopback checks. Start fresh scheduled emulators with:

```sh
npm run emulators:scheduled
```

This runs the worker once per minute while the emulators stay open. Cloud Scheduler
is not deployed or created. A bounded worker pass can also run as
`node scripts/local_recurrence_worker.mjs --once` inside the demo emulator command
environment. Never point the local adapter at a live project.

M08 native rotation verification (recorded results and limits are in M08.md):

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_rotation_fixture.mjs && node scripts/run_rotation_native.mjs 11D93CA0-385A-42CB-B905-449C8439EB01'
```

The runner starts/stops the loopback timer, checks fourteen previewed assignments,
then uses a separate app process to read the turn order and apply a future pause.
All accounts/profile names are fictional. Preview is required again after edits;
uncertain saves retry the same frozen request. Today’s stored assignment is kept
in place; rule changes affect future household dates.
