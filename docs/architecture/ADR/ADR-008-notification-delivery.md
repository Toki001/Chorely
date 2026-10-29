# ADR 008 — Private updates and device-owned reminders

Status: accepted for local implementation; external provider release gates remain.

Accepted occurrence changes atomically write a durable private source outbox. The
bounded, leased worker reconciles current occurrences, active recipients and
preferences into stable jobs and a private recipient inbox. Member/device/policy
changes enqueue bounded household refreshes. Failed items back off independently;
five failures need operator attention. Source replay after inbox commit preserves
one message and its first read stamp. Completion is never inferred from alerts.

Logical identity includes event and meaningful assignment/schedule/completion
revision, rather than every help edit or preference version. Jobs cancel when
state, ownership or eligibility changes. Quiet-hour starts choose the earlier
IANA overlap, ends the later overlap; gaps choose the first valid minute. Copy is
fixed and excludes household names, child nicknames, chore titles and notes.

The default channel is in-app. Guardian-managed child policy can allow local
reminders; each installation separately opts in to OS permission. Local and push
are mutually exclusive policy channels. Push delivery is reserved in the schema,
but registration, provider dispatch and APNs entitlement rollout are not enabled
by this local implementation. No SDK method registers a remote installation in
the demo; auto-init is disabled. Reading a remote launch payload grants no access.

The local device receives up to 60 reminders in the next 24 hours, reserving four
of iOS's 64 pending slots. Android uses inexact alarms with no exact-alarm
permission. Server UTC instants encode household quiet-hour decisions. A private
plan signal, one-minute foreground refresh, resume and explicit refresh recheck
current state. No guarantee is made while the app is terminated/offline or after
permission/battery restrictions. A cached alarm may fire after an unseen remote
change; its generic copy reveals no task detail and its tap must reauthorize.

SQLite stores opaque scope IDs, opt-in, monotonically allocated integer OS IDs
and attempted/scheduled instants. It contains no notification copy or remote
registration secret. Immediate attempts are committed before calling the OS:
a crash can lose an alert, but must not replay an uncertain attempt. Replacing a
future alarm uses the same persistent OS identifier. Initial synchronization
suppresses elapsed alerts rather than replaying a backlog. Logout, profile
change, known access loss and disabled policy cancel local alarms. Local storage
is a dedup ledger, never evidence that the OS displayed or delivered anything.

Opening checks current membership, owned message and current child assignment.
If a local OS alarm precedes inbox publication, only an unexpired private local
job with matching occurrence/preference versions can create an acknowledged
inbox record. Read acknowledgements use a monotonic first server timestamp and a
quota, so the fixed message ID makes a separate UUID unnecessary. Route payloads
carry only versioned opaque IDs. Authentication restoration is awaited and an
identity change invalidates delayed results and old navigation overlays.

Native cold-start tests inject opaque IDs into the debug-only launch source and
use real persisted Auth plus Functions authorization. They do not establish
FCM/APNs cold delivery. Physical permission, reboot/battery/terminated scheduling,
provider FID registration/rotation, remote current-state dispatch rechecks, signing
and production index/scheduler/IAM deployment remain release gates.
