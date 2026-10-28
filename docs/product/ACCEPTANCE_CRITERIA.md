# Product Acceptance Criteria (Given / When / Then)

1. Given an adult account, when creating a household, then server persists a unique tenant ID and grants only documented admin rights.
2. Given another household member, when they attempt to access an unrelated household ID by changing client requests, then the server denies access and no private details leak.
3. Given a short-lived invite, when accepted by the intended eligible user, then membership is created once; expired/replayed/revoked token is rejected.
4. Given a child profile, when guardian pairs a device, then device access is scoped; changing local PIN or profile ID cannot grant guardian privileges.
5. Given a daily recurring chore, when a family member completes today's occurrence, then tomorrow's occurrence remains incomplete and schedule definition remains intact.
6. Given a 3-member rotation, when scheduling the next 14 occurrences, then preview matches assignment order, exceptions and skip rules deterministically.
7. Given two simultaneous completion taps, when requests reach server, then only one successful terminal transition and one completion event occur.
8. Given an offline completion, when connection resumes, then the command is acknowledged once or surfaced as a conflict; the UI never labels unsynchronized action as confirmed remotely.
9. Given child attempted self-approval of review-required chore, then the server denies and logs without promoting permissions.
10. Given no notification authorization, when a chore is due, then in-app state and scheduling still work and permission rationale is graceful.
11. Given quiet hours, when nonurgent reminders are scheduled, then they are delayed/summarized per preferences; duplicates are deduplicated.
12. Given parent requests postponement, then action validates policy, updates due time and reschedules reminders without altering historical occurrence identity.
13. Given a household's first login, when no chores exist, then illustration and a working CTA teach the next step with accessible text.
14. Given large system text, small screen, or TalkBack/VoiceOver, all core flows remain navigable without clipped action buttons.
15. Given cold-start app launch, a notification tap routes to the authorized task detail or safe fallback if task is unavailable.
16. Given source images, generated release assets must be newly created/licensed and no third-party screenshot or copied illustration is included.
17. Given a child privacy deletion request, verified backend deletion/revocation path exists and documentation states retention/caveats.
18. Given release candidate, every P0 journey works on available Android and iOS environments; untested devices are labeled untested.
