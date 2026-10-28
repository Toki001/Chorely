# M02 threat model and verification ownership

Only fictional fixtures are used in local emulators. Trust boundary is verified
Firebase identity → transactional server authorization → tenant documents.

| Attack | Control | Current evidence / remaining gate |
|---|---|---|
| Guess another household path | default-deny rules, active member lookup | backend-tests/rules.test.mjs AUTH-01 |
| Child reads whole task collection | assignedActorIds query restriction | rules positive/negative query tests |
| Role claim/client field manipulation | server membership source, no direct writes | rules AUTH-02; function checks required M05/M06 |
| Revoked member with valid old token | active membership checked on each read/command | rules SYNC-03; device/cache purge M06/M12 |
| Invite/pairing token theft/replay | hash, short TTL, single consumption, rate limit | ADR-002 contract; M06 tests required |
| Double completion or altered replay | payload-bound receipt + version transaction | M09 concurrency tests required |
| Shared-device guardian leak | separate child identity + reauthentication | M06 device tests required |
| Notification exposes child info | generic content, authorized deep link | M11 tests required |
| Admin SDK bypasses rules | function authorization and adversarial tests | M05 onward; rules suite alone is insufficient |
| Credentials in source | ignored secret files, no live config | dependency/secret scan per milestone |
| Unlicensed reference art ships | explicit production asset manifest only | M03/M04 bundle audit |

Rules support only implemented read collections. Future feature collections remain
denied until corresponding authorization tests are added. No public collection
group membership query. Users have server-owned household index documents under
users/{uid}/households/{hid}; index read still checks active membership.
