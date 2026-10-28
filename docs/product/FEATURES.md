# Feature Catalogue — Chorely

Each feature must have discoverable entry point, actionable screen, stored data, permissions, notifications (if any), empty/error/offline states, and tests.

| ID | Feature | Priority | Behavior and edge conditions |
|---|---|---|---|
| H01 | Household create / rename / archive | P0 | Guardian provisions; archived households retain privacy export/delete path. |
| H02 | Adult invite / accept / revoke | P0 | Short-lived single-use invite; prevent unauthorized join, expiration/replay, no public household IDs. |
| H03 | Supervised child profiles | P0 | Nickname/avatar only; guardian-owned; approved pairing to second device, local shared-device picker. |
| H04 | Role/permission management | P0 | Guardian/admin, adult, supervised child; backend enforced. |
| C01 | Chore template creation | P0 | Title, description, category, icon, safety-appropriate assignee eligibility. |
| C02 | Occurrence assignment | P0 | Individual or team; deliberate completion semantics; reassignment history. |
| C03 | One-off schedule & due windows | P0 | Local household timezone, time-only, deadline, no-time, or range. |
| C04 | Recurrence rules | P0 | Daily, weekdays, weekly, monthly, start/end, paused state. |
| C05 | Rotations | P0 | Deterministic eligible roster; opt-out/absence exceptions; visible future previews. |
| C06 | Complete / undo / ask for help | P0 | Idempotent state machine, authorized transitions, short reversible undo policy. |
| C07 | Optional review of completion | P0 | Requested/pending/approved/rejected with reason, no default surveillance. |
| C08 | Chore steps / instruction images | P0 | Text+optional licensed media; accessibility labels. |
| C09 | Chore swap / postpone | P1 | Request, consent, optional guardian approval, history. |
| C10 | Routines / bundles | P1 | Dinner and morning routine templates; tasks remain independent occurrences. |
| C11 | Room-based boards | P1 | Filter task by kitchen, bath, living areas; no location tracking. |
| N01 | Local/push reminders | P0 | New assignment, advance reminder, due/overdue, completion approval; no spam. |
| N02 | Quiet hours & preferences | P0 | Per profile and household defaults; override only if lawful and requested. |
| V01 | Today dashboard | P0 | Personal responsibilities, upcoming, household summary, empty state. |
| V02 | Chores workspace | P0 | Own/household tabs, filter status, list and detail actions. |
| V03 | Calendar | P0 | Week/day/month, per-member filter, scheduled instance drill-down. |
| V04 | Family directory | P0 | Profiles, roles, invite/cancel, permissions, supervised mode. |
| V05 | Activity timeline | P0 | Membership-safe, accurate events, filters, deletion retention policy. |
| L01 | Shared shopping checklist | P1 | Add, edit, check, quantity/unit, member attribution, concurrent sync. |
| L02 | Household supply stock | P1 | Approximate quantity and low-stock reminders, optional photos. |
| L03 | Meal-duty planning | P1 | Cooking responsibility, not nutritional advice. |
| L04 | Pet-care duties | P1 | Who fed pet and when, don't duplicate; no medical/veterinary prescription. |
| R01 | Optional positive rewards | P2 | Guardian-approved, no punitive public leaderboards or currency promises. |
| R02 | Weekly recap | P1 | Count only actual occurrences; fairness indicators are contextual, not judgmental. |
| I01 | Localization | P2 | EN baseline, Tagalog/Bisaya after validated translations. |
| I02 | Visual onboarding illustrations | P0 | Original licensed art; SVG/vector/Rive/Lottie only with verified rights and reduced motion. |

**Business rules:** Safe/age-appropriate chore choice belongs to guardians. Household tasks do not become employer labor contracts. Assigned children can request help and skip rather than being forced to falsely mark complete.
