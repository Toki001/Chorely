# Release Test Matrix — Seed Cases

| ID | Domain | Test case | Expected |
|---|---|---|---|
| AUTH-01 | Tenant | User from A queries B | Denied |
| AUTH-02 | Roles | Child attempts admin action via API | Denied |
| AUTH-03 | Roles | Adult lacks canAssign | Denied |
| AUTH-04 | Invites | Expired, replayed and revoked invites | Denied |
| AUTH-05 | Pairing | Unapproved child device pairing | Denied |
| CHORE-01 | CRUD | Create/edit/disable template | Consistent and audited |
| CHORE-02 | Occurrence | Completing today | Tomorrow remains scheduled |
| CHORE-03 | Idempotency | Repeated completion command | One transition/event |
| CHORE-04 | Review | Child completes review-required chore | Pending review, not approved |
| CHORE-05 | Schedule | Weekday only rule | No weekend occurrences |
| CHORE-06 | Schedule | Month 31 → February | Documented skip/last-day policy |
| CHORE-07 | Timezone | DST transition/timezone change | Deterministic valid instants |
| CHORE-08 | Rotation | 3 members 14 days | Predictable order |
| CHORE-09 | Exceptions | Absent member, edit rotation | Future-only adjustments |
| CHORE-10 | Teams | all/any completion mode | Correct semantics |
| SYNC-01 | Offline | Complete then force stop and reconnect | Queue recovered once |
| SYNC-02 | Conflict | Two devices complete / reassign | Authenticated result and explanation |
| SYNC-03 | Revocation | Offline client reconnects after revoke | Write denied; cache cleared |
| NOTIF-01 | Due | Assigned + due | No duplicate notifications |
| NOTIF-02 | Rescheduled | Old notification canceled | Only new due reminder fires |
| NOTIF-03 | Quiet hours | Nonurgent due during quiet hours | Delivered per preference |
| NOTIF-04 | Denied permission | Alerts blocked | In-app works |
| NOTIF-05 | Deep link | Notification opens deleted chore | Safe fallback |
| UI-01 | Accessibility | Large font 200% | No cut-off button, usable |
| UI-02 | Screen readers | Chore card/Done | Semantic labels and feedback |
| UI-03 | Visual | Parent/child screenshot golden | Approved tokens, no drift |
| UI-04 | Empty | No tasks/family | Clear illustrated CTA |
| UI-05 | Theme | Light/dark if dark shipped | Contrast and icon clarity |
| DATA-01 | Privacy | Delete guardian/household | Confirmed deletion and revoked access |
| DATA-02 | Secrets | Build artifact and Git scan | No secrets/unlicensed shots |
| LIST-01 | Groceries | Concurrent checked item | Single consistent final state (P1) |
| PERF-01 | Large household | 20 profiles/500 tasks | Paginated and responsive |

Tests marked P1 only become release blocking when those features are included in the release scope.
