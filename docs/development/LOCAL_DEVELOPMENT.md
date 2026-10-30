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
commands; duplicate retries reuse the command ID. M12 adds durable occurrence
actions and confirmed read caching, described below. The initial timezone picker
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

Native completion/review verification uses fresh fictional fixtures and two app
processes against the same local emulators:

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_family_fixture.mjs && node scripts/run_completion_native.mjs 11D93CA0-385A-42CB-B905-449C8439EB01'
```

The child requests help, submits, undoes and resubmits; a direct native callable
attempt confirms self-approval is denied. A separately authenticated guardian
answers help and approves. Restart verifies stored approval and version-ordered
history. Commands keep a frozen ID/base/note after uncertain failure. A known
conflict requires reload. Undo time is enforced by server acceptance, not a supplied
client clock. Private notes are readable only by their actor and chore managers;
child UI never queries other actors' notes or privileged activity. Durable
process-kill recovery is exercised by the separate M12 runner below.

M10 adds Today/Chores/Calendar/Family destinations. Today uses the server-authorized
household clock; calendar dates use the household zone, not the phone zone. Day,
week and month views query actual occurrence slots. Everyone/Just me/member and
status filters work for adults; supervised queries remain bound to their profile.
Finished counts exclude pending review, partial work and cancelled/skipped slots.
Selected dates prefill the creation form and have a date picker plus text input.

The two-device dashboard runner uses fresh fictional demo fixtures, runs the full
parent/child journey and restart on a booted tablet, then a fresh phone process
reads the same approved calendar. With the available iOS 27 simulators:

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_family_fixture.mjs && node scripts/run_dashboard_native.mjs BD4FB3AE-CAC2-4E1B-9D7A-FCE4CCA17197 11D93CA0-385A-42CB-B905-449C8439EB01'
```

Do not run emulator suites concurrently. Native test helpers wait for real query
results and settled scrolling/routes before tapping; a transition may briefly
contain both old/new text. Exact single-result assertions remain enforced.
Dashboard widgets additionally exercise 320×568dp and 800×1024dp at 200% text.
Date-range reads are bounded by one day/week/month and cards display in batches
of twenty. Large-household pagination/performance remain later gates. M12 adds
bounded confirmed read caching. These commands never deploy indexes or create live resources.

M11 adds private in-app updates, guardian-managed child policy and optional local
reminders. Start both loopback recurrence and notification workers with:

```sh
npm run emulators:household
```

The recurrence adapter checks each minute; the inbox worker checks every two
seconds. Both refuse live projects and non-loopback Firestore. `npm run emulators`
still starts the services alone; use `emulators:notifications` for just the inbox
worker or `emulators:scheduled` for just recurrence. Never run these emulator
commands concurrently. Preferences and read acknowledgements use Functions; all
client writes to preferences, inbox, plan signals and jobs are denied.

For native notification verification, with a booted simulator:

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_notification_fixture.mjs && node scripts/run_notifications_native.mjs 11D93CA0-385A-42CB-B905-449C8439EB01'
```

This uses fictional guardian/child data, real Auth/Functions/Firestore and an
opaque debug-only route injection in fresh app processes. It verifies inbox
ownership, child completion, separate guardian review, read preservation, SQLite
attempt persistence and deleted-target fallback. It does not test APNs/FCM
provider delivery. Demo remote registration/auto-init are disabled; no live
project fallback exists. Native initialization does not prompt for notification
permission. The device switch requests permission only on explicit interaction;
a guardian must also save the local reminder channel for supervised profiles.
Denied permission leaves the in-app journey available.

The local plan has at most 60 alerts in the next 24 hours. Android uses inexact
alarms and may delay them; no exact alarm permission is requested. iOS reserves
four of its 64 pending slots. Offline/terminated devices can retain an obsolete
cached generic alert until reconnect; every tap still rechecks server authority.
No delivery claim follows from a successful scheduling method. The reminder ledger contains
only opaque IDs/times/opt-in, with persistent collision-free integer OS IDs and
at-most-once immediate attempts. A crash during an uncertain OS operation can
lose an alert. See ADR 008 and M11.md for all remaining provider/device gates.

M12 native offline verification uses eight app processes with installation
preserved so SQLite survives. Start from fresh emulators:

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_offline_fixture.mjs && node scripts/run_offline_native.mjs 11D93CA0-385A-42CB-B905-449C8439EB01'
flutter test integration_test/cache_storage_test.dart -d 11D93CA0-385A-42CB-B905-449C8439EB01 --no-uninstall
```

Flutter's native integration runner normally uninstalls the app. The offline
runner passes `--no-uninstall`; Auth Keychain restoration alone cannot prove
SQLite persistence. The suite sends a real unavailable loopback command, restarts
to confirm once, restarts again without duplication, creates a competing server
revision, requires explicit conflict review, starts with Firestore networking
disabled and Functions unavailable, recovers, then applies actual member removal
and checks private cache/journal purge. All accounts are fictional. The standalone
storage test clears the sync/cache databases; run it outside any manual session.

`CHORELY_TEST_OFFLINE_DATA=true` is a debug-only test seam: it disables Firestore
networking and points Functions to unavailable loopback port 5999 before mounting
the app. It does not inject accepted state or bypass authentication. Production
mode remains closed. Native helpers wait for specific real data and advance
finite route/scroll animations; `pumpAndSettle` cannot finish while a disconnected
view has an indeterminate loading indicator.

Only completion/review/help occurrence actions use the durable outbox. Authoring
forms and notification preferences remain online. Previously visited confirmed
home/roster/role/detail/calendar/clock views may be read from the scoped cache;
unvisited views cannot promise offline data. Pending counts never add completed
chores. Reconnect reuses the frozen request; conflicts stop until current server
state has loaded and the user reviews it. Signing out with requests still waiting
explains that the device queue will be removed. Physical radios, OS process kill,
three-day token expiry, backup extraction and locked-device protection remain
separate M16–M18 gates. See ADR 009 and M12.md for exact verification.

M13's initial scheduling flow lets a current guardian choose a later deadline for
one uncompleted occurrence. It preserves the slot/history and future rule. The
form is an online authoring flow; uncertain retry freezes the same ID/base/time,
and conflicts require a current server read. A future recurrence pause preserves
that explicit moved turn; the base rotation preview does not override it. The
initial form explicitly replaces a time window with the selected single deadline.

```sh
npm run build
npx firebase emulators:exec --only auth,firestore,functions --project demo-chorely 'node scripts/seed_notification_fixture.mjs && node scripts/run_postpone_native.mjs 11D93CA0-385A-42CB-B905-449C8439EB01'
```

The runner uses two app processes, verifies the actual callable/date/activity and
checks the unchanged template/slot plus zero completion contributions. It keeps
installation for restart and refuses non-demo/non-loopback services. Routines,
consented swaps and away flow are still separate M13 work.
