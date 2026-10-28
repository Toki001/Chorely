# Notification and Reminder Engine — Chorely

## Principles
Notifications should help, never nag or shame. Store preferences per household member. A valid in-app schedule is the source of truth; notification delivery is best effort and never represents a guarantee. Local and push channels need idempotency and duplicate suppression.

## Events
| Event | Default target | Dispatch | Dedup key |
|---|---|---|---|
| assigned/new/reassigned | new assignee | near real time | household/occurrence/actor/assigned/version |
| upcoming due | assignee | configured e.g. 15m | occurrence/actor/upcoming/dueVersion |
| due now | assignee | due slot | occurrence/actor/due/dueVersion |
| overdue gentle prompt | assignee | configurable grace period | occurrence/actor/overdue/graceLevel |
| child marked done needing review | designated reviewers | near real time | occurrence/review/requestVersion |
| review approved/request redo | affected assignee | near real time | occurrence/review/resultVersion |
| help, postpone, swap | reviewer/recipient | near real time | requestId/event/revision |
| quiet daily digest | opted-in adult/member | local time chosen | household/actor/localDate/digest |

## Delivery architecture
- Cloud Functions/job scheduler materializes notifications against authoritative chore occurrences and membership; server checks current status before send.
- FCM/APNs handle remote delivery with tokens stored/rotated securely; Flutter local notifications for device-owned reminders only when permission/capability permits. Avoid duplicate local+remote messages; use shared stable logical IDs.
- On Android 13+ notification permission prompt after value demonstrated; exact alarm permission only if justified; iOS APNs configuration and permission prompts required. Tested graceful fallback when denied or unregistered.
- Notification text should minimize child PII; no full address, health info or invite secret in lock-screen notification.
- Quiet hours, timezone and sleep: delay non-urgent events; emergency escalation is not a product feature.
- Interaction deep-links handle cold start, invalid membership, deleted occurrence and authenticated transition.

## QA matrix
Permission yes/no/revoked; foreground/background/terminated; iOS simulator/APNs vs physical device; FCM token refresh; timezone changed; task rescheduled; task completed right before due; repeat occurrence; network offline; two devices for same member; duplicate scheduler retry; child profile unpaired; quiet hours at midnight; retries and dead-letter visibility.

## Observability
Count attempted, accepted by provider, app-open conversions separately; provider accepted is not user delivered/read. Maintain rate limits and notification opt-outs. No child behavioral surveillance by default.
