# Product Requirements Document — Chorely

## Vision / positioning
**Chorely**: *One home. One team. Everyone plays their part.* A supportive, collaborative home operations companion where adults and kids know who is doing what, when, and what is finished. Primary use: daily household chores and routines. Secondary: household shopping, supplies, and schedules. Prioritize collaboration and simplicity over corporate project management.

## Problem
Households rely on verbal reminders or busy group chats. Tasks are forgotten, completion is ambiguous, responsibilities feel unfair, and parents repeatedly coordinate basics. Generic task apps make scheduling and turn-taking cumbersome. Parents need control without heavy surveillance; kids need clear, age-appropriate actions rather than administrative complexity.

## Target personas / access model
- **Guardian/Admin:** creates household, owns configuration, invites people, assigns/adapts tasks and reviews optional approvals.
- **Adult Member:** completes own tasks, may create tasks / routines if authorized, accesses shared views, requests changes.
- **Supervised Child Profile:** sees only appropriate family information and assignments, checks done/needs help/ask to postpone, no independent guardian-level permissions. No email/phone required by default. Parent provisions device access or shared-device profile.
- **Extended family/caregiver:** adult member by invitation with expressly granted privileges; never silently gets administrator access.
- **Mixed homes:** no assumption about two-parent households; role selection reflects household membership rather than a specific family structure.

## Primary jobs to be done
1. As an adult, I want to create a week's cooking/cleaning/pet chores quickly so I do not repeat instructions.
2. As a family member, I want to know today's assigned tasks and due windows in seconds.
3. As a child, I want a clear way to finish a chore or ask for help, without needing email.
4. As an adult, I want rotating duty schedules that remain fair and support exceptions.
5. As anyone, I want reminders without constant nagging.
6. As a household, I want a single source of truth when someone has actually completed a responsibility.
7. As a household, I want shared shopping/supply lists without rebuilding a finance app.

## Scope and release waves
### P0 / Core release candidate
- Guardian sign-up/authentication, household create/join and invitation acceptance/revocation.
- Supervised child profiles and secure parent-approved device access; adult membership and roles.
- Chore templates, categories, optional image/icon, instructions and subtasks, one or multiple assignees as explicit choice.
- One-off and repeating rules: daily, selected weekdays, weekly, monthly by date, plus manual rotation eligible set.
- Concrete chore occurrences, due time/windows, timezone and exceptions, request help/snooze, status and optional approval.
- Notification preferences: assignment, upcoming, overdue, completion approval; actionable app deep links.
- Today feed, Chores list, Week Calendar, Family view, completion and activity.
- Real shared persistence with authorization, synchronized updates, local cache, offline behavior and conflict recovery.
- Accessibility, child privacy, empty/loading/error states, graceful notification denial.

### P1 / Next release
- Routine bundles (dinner, morning, Saturday cleanup), shared shopping list, inventory/supply reminders, chore swaps/reassignments, away/sick day, basic weekly recap.
- Pet care as safe household scheduling/logging; no advice on dosing or veterinary care.
- Room-based household chore boards and flexible time windows.

### P2 / Optional after validation
- User-selected positive rewards (guardian-controlled, not public ranking), meal responsibility planner, suggestion templates, widgets, multilingual English/Tagalog/Bisaya, shared wall-display mode.
- Optional lightweight household expense *status* only; no bank integration/payment transfers at launch.

## Explicitly out of scope for v1
Family GPS monitoring, public social feeds, AI parenting advice, always-on mic/camera, full accounting, payments, child-targeted advertising, punitive chore rankings, complex messaging, mandatory photo proof, facial recognition, auto-generated unsafe chores, fake intelligence, third-party contractor marketplace.

## Key UX principles
- Assignment flow for a simple chore in ~30 seconds after household setup; complete own chore in ≤2 taps (design target to validate, not a measured result).
- Visual styles warm, modern, original flat illustrated motifs, restrained colored cards, prominent daily header and personalized task list.
- No forced gamification, guilt or public humiliation for missed chores. Celebrate cooperation without pressure.
- Nontechnical adults can manage with a few screens; children can operate in a simplified interface.

## Functional success indicators (hypotheses, measure after consented beta)
- First household setup and first assigned chore completion; households inviting a second member; repeat usage across four weeks; timely completion; parent-perceived fewer verbal reminders.
- Monitor notification opt-outs, privacy complaints, task-conflict incidents, task creation friction and account deletion requests.
- Do NOT populate UI with fabricated benchmark metrics or analytic charts before real data exists.

## Business model
Free core household, assignments, alerts and completion; optional modest paid convenience features such as advanced routines, templates, extended history, wall mode or extra analytics **subject to ethical child-family design review**. Avoid feature locks that disrupt essential family coordination. Never put ads in child mode by default.

## Decisions to validate
- Single vs multiple household memberships per adult; choice of guardian approvals; supported languages; default recurring cadence; retention policies; paid tier; applicability of store Kids Category. Document in ADRs and verify during product testing.
