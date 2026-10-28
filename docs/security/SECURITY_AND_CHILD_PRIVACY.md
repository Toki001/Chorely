# Security, Family Privacy, and Child Safety Requirements

## Security posture
The app stores household membership, family nicknames, chore assignments and histories. It is privacy-sensitive even without financial or health data. Build per-tenant authorization, minimize collection, avoid exposing minors and ensure the app can be used in families safely.

## Roles (enforce on server)
- **Guardian/Admin:** can create households, invite/revoke, approve child profile/device access, manage schedules/rules, configure approvals, export/delete authorized household data.
- **Adult Member:** read own/household permitted data; perform own tasks; create/assign only with explicit capability; cannot grant themselves admin rights.
- **Supervised Child:** can read assigned and age-appropriate shared chores, complete/request assistance, see limited household roster, but cannot join arbitrary households, elevate roles, spend money, obtain others' sensitive info or change system permissions.
- Multi-guardian rights must be explicitly established; don't assume owner sole authority in all family structures.

## Threat model and mandatory controls
| Threat | Control and validation |
|---|---|
| guessed household ID | Firestore rules and backend authorization; deny all default |
| child manipulates client role | trusted membership record; never trust client flags |
| leaked QR invite | short TTL, single use, hashed nonce, revocation, rate limiting |
| shared-device cross-profile access | secure profile switch + guardian gate for privileged operations; server actor binding |
| stolen paired child device | revoke device and sessions; no broad account data |
| double completion / spam | idempotency keys, status transitions, rate limits |
| offline after revoked access | backend deny; clear cached data and inform user on reconnection |
| cross-household path write | test emulator policy, only scoped authorized routes |
| inadvertent child photos | no required proof photos, clear consent, storage retention and deletion |
| analytic tracking leaks | disable invasive child analytics, no targeted ads and minimal logs |
| image/push sensitive content | redact lock-screen body; never embed token or detailed child info |

## Parent/child onboarding
Adults authenticate with available supported providers (email link/Apple/Google etc according to platform). Child profiles **do not require email or phone**. Pair a child device with a guardian-confirmed one-use QR token and secure scoped backend identity; this is an architectural requirement, not a claim that Firebase provides it automatically. A numeric PIN may help switch supervised profiles locally but **must not be sole tenant authentication**. Guardians approve privileges and can revoke pairing.

## Privacy and compliance considerations
- Validate applicable Philippine Data Privacy Act and NPC guidance; child-focused apps require special care. Also review Google Play Families and Apple Kids Category policies based on actual target audience, not an assumed exemption.
- Do not collect exact birthdates, GPS, contacts, microphones, photos or advertising IDs by default. For child safety, no unrestricted public profiles/social or stranger chat.
- Privacy policy and in-app disclosure explain data types, processing purpose, household visibility, guardianship, permissions, retention, deletion, support contact, and account deletion.
- Account deletion and data-export flows should be implemented and tested in addition to app-store metadata. Distinguish leaving a household from deleting the guardian account, and guard against orphaned household administration.
- Handle multi-device notification tokens and remove stale tokens on unlink/delete. Protect Firebase API/admin secrets; Firebase client config is not authorization.
- Use consented beta metrics only where permitted; avoid habitual tracking that feels like judging children.

## Mandatory server tests
Household A cannot read/write Household B; child cannot escalate/admin/approve; adult cannot assign beyond capability; removed member denied and cache purged; reused invite denied; stale token denied; parent-approved pairing single use; data deletion revokes access; rate limits; ability to create/complete tasks under allowed child scope; server audit actor accurate.

## Legal/product decisions requiring review
Kids Category positioning, target-age cohorts, guardian legal consent flows across release countries, data processing agreements, privacy policy, subscriptions/gated purchase controls, content retention. The docs are engineering requirements, **not legal advice or certification of compliance**.
