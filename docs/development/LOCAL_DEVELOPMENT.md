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
