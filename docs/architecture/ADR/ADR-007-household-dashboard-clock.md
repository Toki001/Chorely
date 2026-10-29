# ADR-007 — Household dates, scoped calendars and stored progress

Status: accepted for local M10 implementation. Production rollout remains gated.

Today is the household civil date, not the device date. An authenticated callable
reuses the completion participant authorization (current household, membership,
account and profile), resolves the stored IANA zone and returns server time, the
current date and next valid midnight. Forged body clocks/roles/zones have no
authority. The client uses monotonic elapsed time between refreshes; refreshes on
resume, timezone change, manual retry and within thirty seconds of the boundary.
The displayed past-due hint never changes occurrence state or authorizes a command.
Completion/undo policies continue to use the server clock.

Civil date arithmetic and picker results preserve year/month/day fields. They do
not convert local midnight through UTC. Day/week/month queries use inclusive
`localDate` bounds. These are scheduled slot dates: a cross-midnight occurrence
keeps its original slot, rather than acquiring a second identity on the next day.
The week begins Monday. Month navigation clamps the selected day, with years
2000–2100 matching the domain. Dates outside the loaded month show no invented
counts. Empty dates remain selectable and offer actual permitted next actions.

Guardians/adults can filter Everyone, Just me or an active member. Supervised
devices always query `assignedActorIds array-contains stableProfileId`; the
control cannot widen to Everyone. Rules enforce this independently. A compound
index accompanies that query. Live membership guards hide loaded cards and
management controls on revocation; child Family shows the minimal permitted
roster, while guardian Family retains the actual invite/pair/revoke workflows.

Finished means stored `completed` or `approved`. Review is counted separately;
partial contributions do not finish an all-member occurrence. Cancelled/skipped
slots do not enter the denominator. The selected day or visible Chores range
defines the denominator, before status filtering. Unknown/loading/error states
do not display fabricated zero progress. Card labels expose member names, status,
timing and individual contribution counts; color is never the only signal.
The initial summary waits for a server-confirmed snapshot, since an empty local
cache does not establish that a household has no chores. A stored occurrence
whose recorded timezone differs from the current household zone labels that
zone explicitly; detail continues to show its preserved timing snapshot.

Phone navigation adapts to two rows with large text; tablet navigation uses a side
column. Calendar weeks wrap at large text sizes to retain >=48dp targets. Detail,
complete/help, guardian review and creation use the existing actual repositories.
Lists stays hidden until M14. No dormant navigation destination is added.

Read limits: a query loads one day/week/month, and cards render in batches of
twenty with a working Show more action. This is a bounded date horizon, not a
claim of backend count pagination. Large-household load and server projections
remain M17 performance gates. Activity retains its existing thirty-action limit.
Online clock loading is required here; cached clock/outbox reconciliation is M12.
No device hardware, live index deployment, FCM/APNs or release approval follows
from these local gates.
