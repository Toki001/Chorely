# Developer Bootstrap — Chorely

## Before app scaffolding
1. Install/inspect Flutter stable and Dart, Android Studio/SDK, emulator/device; on macOS install Xcode/CocoaPods for iOS and verify `flutter doctor -v`.
2. Inspect existing repository and installed versions; do not blindly force upgrades. Read `AGENTS.md`, `CODEX.md`, all docs and roadmap.
3. Validate access to Firebase development project or use Emulator Suite for initial backend tests. Use distinct projects for development/staging/production; never embed service-account credentials in mobile app.
4. Copy user-supplied references into `assets/design_references`, and **exclude this path from Flutter's `pubspec.yaml` asset declarations and release bundles**.
5. Proposed initial commands if no app exists (only after checking directory): `flutter create --project-name chorely --org <owned.reverse.domain> .`, `flutter pub get`, `flutter doctor -v`, `flutter analyze`, `flutter test`.
6. Configure proper version-pinned Flutter/Firebase packages based on actual supported matrix; don't blindly use versions in a prompt.

## Suggested structure
```text
chorely/
  AGENTS.md, AGENT.md, CODEX.md, MASTER_PROMPT.md, README.md
  pubspec.yaml, pubspec.lock
  lib/
    main.dart
    app/{bootstrap,router,theme,localization}/
    core/{error,clock,secure_storage,outbox,network}/
    features/{auth,households,family_members,chores,rotations,routines,
              calendar,notifications,shopping,supplies,activity,settings}/
    shared/widgets/
  functions/src/
  firestore.rules, firestore.indexes.json
  android/, ios/, test/, integration_test/
  app/assets/illustrations/  # new original rights-cleared artwork only
  assets/design_references/ # REFERENCE-ONLY never shipped
  docs/{product,design,architecture,security,development,testing,operations,roadmap,verification}/
  .github/workflows/        # later actual CI
```

## Minimum contributor workflows
`flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`, platform build if configured. Backend emulator security tests must be separately executable. Add reproducible `make verify`/`melos` only when complexity justifies.

## Environment setup check
Document Java/JDK version, Gradle/AGP, min/target SDK, Apple deployment target, Xcode, CocoaPods, Flutter channel/version, Firebase project IDs, development app IDs, APNs setup, emulator versions, actual tested Android and iOS devices. Store no secrets in docs or Git. Use secret manager or ignored environment files.
