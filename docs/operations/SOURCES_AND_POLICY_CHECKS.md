# Official Sources to Recheck During Implementation

These sources informed the kit as of October 2026. Platform policies and SDK contracts change; Codex must open current official docs before final implementation or release.

1. Flutter application architecture guide: https://docs.flutter.dev/app-architecture/guide — separation of views/viewmodels/repositories/services.
2. Firestore offline persistence: https://firebase.google.com/docs/firestore/manage-data/enable-offline — offline cache and last-write-wins behavior.
3. Firebase Cloud Messaging setup for Flutter: https://firebase.google.com/docs/cloud-messaging/flutter/get-started — iOS APNs and platform setup.
4. Firebase receiving messages in Flutter: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages — background/foreground behavior.
5. Google Play Families policies: https://support.google.com/googleplay/android-developer/answer/9893335?hl=en — requirements when target audience includes children.
6. Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/ — Kids Category, privacy, account deletion and rights to screenshots/assets.

This is an engineering reading list, not a claim that Chorely is already compliant. Document verification dates and decisions in release evidence.
