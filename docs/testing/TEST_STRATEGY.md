# Test Strategy & Quality Gates

## Test pyramid
- Unit/domain: 100% of critical recurrence/rotation/role/transition/price-free domain invariants tested using deterministic clock and timezone fixtures; boundary and property-based cases where useful.
- Widget: critical flows for parent and child, accessible labels, notifications permission denied, offline/pending conflict, empty and error states, golden baselines after approved design.
- Integration/emulator: Firebase security rules, Functions, invites, child device pairing, cross-tenant abuse, cloud job scheduling, multi-user sync, duplicate events.
- Mobile E2E: fresh install adult setup, invite, child pairing, schedule, completion, review, offline, foreground/background notification, restart, deletion, on available real Android and iOS testing.
- Platform: Android debug/release builds, iOS simulator build, iOS device where accessible; hot/cold start, low connectivity, large text, screen reader, reduced motion, keyboard and back gesture.

## Mandatory CI commands (adjust to actual project)
```bash
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
# additionally run security rules/functions emulator test suite
# integration_test on real/emulated devices as available
flutter build apk --release       # if Android signing/config supports it
flutter build ios --no-codesign   # on macOS with Xcode, if applicable
```
Record exact executed commands, exit statuses, test counts, skipped cases, environment, date and reference artifacts. Do not claim success for commands not executed.

## Release blocking gates
1. P0 core flows and real sync work end-to-end; no mock production screens.
2. No known critical/high exploitable authorization flaws or data leakage.
3. Cross-household rules/emulator tests pass; parent/child privileges tested.
4. Recurrence across monthly/DST boundaries and rotations deterministic.
5. Completion, approval, offline outbox idempotence, duplicate notifications verified.
6. No high-severity crashes, dead-ended flows, unlabeled buttons, or persistent inaccessible navigation.
7. Golden/screenshot comparisons evaluated for small Android, contemporary iPhone, tablet (where supported).
8. App cold/restart/persistence and account deletion verified; app build both platforms as available.
9. Store compliance/privacy, licenses, secrets, dependency risks audited, no unlicensed reference images in app assets.
10. External blockers labeled, release candidate withheld if any required gate unverified.

## Performance goals (targets, not asserted results)
- Startup and interactive transitions feel responsive on midrange Android; establish baseline and profile actual frames, memory and long lists.
- Avoid loading all household history; paginate, lazy-load, cache and cap queries.
- Limit read/write cost; avoid one listener per chore where grouped queries suffice.
- Maintain low noise: 1 logical reminder per event/member, avoid duplicate FCM/local alerts.
- Accessibility: minimum 48dp target and verified contrast; scalable text and screen readers; honor reduce motion.

## Test artifacts
`docs/verification/M00.md`... `M18.md` with environment, screenshots, audit, logs, commands, pass/fail counts, known issues, commit SHA. Store local screenshots and video evidence without exposing real children's information.
