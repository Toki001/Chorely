#!/usr/bin/env bash
set -euo pipefail
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
npm run format:check
npm run build
npm run test:backend
npm audit --omit=dev --audit-level=moderate
python3 scripts/audit_repository.py
git diff --check
