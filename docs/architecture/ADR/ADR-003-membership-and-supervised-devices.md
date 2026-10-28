# ADR-003 — Membership and supervised devices

Accepted for local emulator implementation, 2026-10-29. Deployment remains
unauthorized. Depends on M05 tenant creation and deny-by-default client writes.

Adult invitations require a current guardian and a verified adult recipient.
Guardian chooses Adult member (cannot assign/admin by default) or Guardian
(explicitly grants membership/device administration). The invite binds a normalized
recipient email hash to the guardian's selected role. Request-body role and UID
cannot change that grant. Code entropy is 256 bits from the client secure RNG;
only canonical code hashes enter Firestore. Raw codes are displayed/copied only
by deliberate action. No email is sent by the app. The local user must share the
code privately through their chosen channel. No contact integration is connected.

Codes expire ten minutes after server issuance. Issuance is bounded to twenty
invitations and twenty child approvals per guardian per UTC day. Initial limits:
fifty active memberships/devices per household and twenty child profiles. These
are abuse bounds, subject to explicit lifecycle/UX review before release. Household
creation quota remains M05's five per account. Limits are transactionally enforced.

Invitation consumption, membership, nickname profile, private discovery index,
receipt and audit event commit together. New-command replay after consumption is
denied. Retrying the same accepted command/payload returns its prior result only
while membership remains active. Revoked/expired invitations, a disabled/revoked
approving guardian and mismatched recipient are denied. Revocation atomically
removes the private discovery index; tenant reads independently require active
membership. Last active guardian cannot be removed. Rejoining cannot overwrite
previous removal audit events. No direct privilege-editing client writes exist.

Child profiles collect a nickname and fixed generic avatar, without email or DOB.
The profile has a stable actor ID. Each approved device receives a distinct custom
Firebase Auth UID whose membership references that actor ID. Multiple devices can
therefore read the same assigned profile work, and one device can be revoked
without changing assignment history or removing the child profile. Assignment
rules resolve child actor ID from current server membership, never a request field.

Guardian explicitly approves a ten-minute single-use code for a chosen profile.
A signed-out device scans or enters it and supplies its own 256-bit retry proof.
The server atomically consumes approval, binds the device proof, and creates its
child membership/device records. It then mints a custom token containing only
scopedChild/householdId/actorId routing claims. A lost response may be retried with
the SAME device proof until code expiry and only while access is active. A different
proof cannot reuse approval. No PIN acts as backend authentication.

Supervised claims are also persisted on the Auth user. Server-owned
`users/{deviceUid}.accountType = supervised_device` is checked independently when
bootstrapping a home, accepting an adult invite or exercising guardianship. Linking
an email/password provider cannot silently convert this identity to an adult, even
if a token lacks scope claims. Device classification has no client write path.

Device revocation marks current membership inactive atomically. Even an unexpired
Auth token then fails data reads and all privileged commands. Token refresh
revocation alone would not provide this guarantee: Firebase ID tokens have an
hour lifetime. Custom Auth signing permissions and abuse protections for live
endpoints require authorized production setup and M16 review; emulated unsigned
tokens are accepted only by explicitly configured local emulators.

Shared-device mode signs the guardian out before redeeming approval. Server rejects
redemption by a signed-in account. Child UI has no adult mutation controls. To
return, the user signs out of supervised mode and authenticates with adult
credentials. Auth generation guards prevent an old pending claims response from
publishing after sign-out. App identity changes reset routes/overlays and dispose
prior profile UI. Persistent Firestore disk caching remains disabled until M12.

Camera starts only after tapping Scan QR code; scans remain on-device, returnImage
is false, no photo is stored or uploaded. Code entry is always available, including
when camera permission/hardware is unavailable. Physical-camera testing belongs
to the device matrix; a simulator manual-code success cannot claim camera success.

Sources checked:
- [Firebase custom authentication](https://firebase.google.com/docs/auth/admin/create-custom-tokens)
- [Firebase session lifetime and revocation](https://firebase.google.com/docs/auth/admin/manage-sessions)
- [Local Auth emulator boundaries](https://firebase.google.com/docs/emulator-suite/connect_auth)
- [QR Flutter 4.1.0](https://pub.dev/packages/qr_flutter)
- [Mobile Scanner 7.4.2](https://pub.dev/packages/mobile_scanner)
