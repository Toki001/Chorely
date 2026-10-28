# CHORELY — STITCH MASTER UI/UX DESIGN PROMPT

You are a senior mobile consumer product designer. Design a cohesive high-fidelity Flutter-ready UI/UX system for **Chorely**, a shared **family household chores** app. The purpose is to help guardians/adults assign cooking, dishes, feeding pets, sweeping and other appropriate household responsibilities to themselves or children; members see their own chores, schedules, rotations, and mark them complete. The app also supports notifications, simple calendar, and later grocery/supply coordination. It is NOT a workplace project tracker, generic habit tracker, children-only game, or banking app.

## Required visual references
I will attach seven design screenshots in this order; examine all. Reference 01: calm lavender hero cards, family/avatar row and task navigation; 02: crisp coral action/navigation and compact status tiles; 03: charcoal dark option with pastel cards; 04: **highest priority** illustrated welcome scene with playful editorial person carrying large pencil, spacious white intro screen and prominent CTA — draw NEW ORIGINAL household/team illustrations with this level of personality, NOT the same character/pose/pencil; 05: coherent task screen family and detailed day timeline; 06: airy pastel card grid and colored calendar tasks; 07: mint minimal task list and readable details.

## Style direction
Original identity: CHORELY. Primary violet #675CE8, near-white #F8F9FC, white #FFFFFF, ink #171923, soft lavender #EEE9FF, mint #E0F6EB, apricot #FFEDD9, sky #E4F3FF; coral only sparingly where meaningful. Expressive editorial typography; 20–24px gutters; rounded 18–28px cards; clear family avatars; clean task list. Illustrations should use warm 2D flat vector characters / family chore scenes with simple geometric motifs. No web dashboard look, no fake 3D stock illustrations, no rainbow clutter, no heavily blurred glass effect, no copies of other product brands.

## Mandatory screens
1. Onboarding illustrated welcome with original household collaboration scene and a single meaningful CTA.
2. Onboarding: assign chores (original fridge checklist illustration), rotate tasks (family handoff illustration), finish together (positive celebration illustration).
3. Adult authentication and create household; approachable form, privacy explanation.
4. Add child supervised profile (nickname/avatar only), guardian-confirmed device pairing, family member invite screens.
5. Parent Today: greeting, 2–4 family avatar chips, real progress overview, primary next chore card, today's tasks with due times and members.
6. Child Today: large personal chore cards, friendly illustration, one-tap done, request help and postpone actions, no billing or administrative controls.
7. Chores: My chores/All chores, ongoing/pending/done, search/filter, add action and completion.
8. Create/edit chore: title, illustrated preset, assignee, category/room, steps, due time/window, repeat, reminder, review toggle, save, validation errors.
9. Rotation editor: member selection, daily/weekday pattern, 14-day assignee preview, skip/away explanation.
10. Chore detail: steps, assigned person, scheduled occurrence, checklist, comments/notes if needed, completion history, optional guardian approval.
11. Calendar: week strip + day agenda and month switch, task cards colored softly by family member; task status in text not color alone.
12. Family: cards with member avatars, role, inviting, permissions, supervised child accounts, revoking paired access.
13. Lists: real shared grocery list with quantities / who added / checked, empty state, supply screen (P1 design, not fake implemented features).
14. Inbox / request flows: new assignment, due reminder, help request, swap, review pending, notifications preferences, quiet hours.
15. Settings: language, notification preferences, privacy/data access, theme, sign-out, account deletion.
16. Required empty, loading, offline, sync-pending, permission denial, conflict resolution, and error states.

## Specific interaction flows
A parent creates 'Cook rice for dinner' at 5:30 PM and assigns it to a child → child gets assignment → sees Today → taps Done → parent sees completed state. Create rotating 'Wash dishes after dinner' for two siblings → display next 2 weeks of turns, and handle swap/postpone. Pet-feeding card must display last verified completion time to avoid duplicate feeding. Unreviewed and offline changes must not appear as fully verified successes.

## Required deliverables
- Separate high-fidelity screen designs at small Android, modern iPhone, and tablet / landscape adaptations where meaningful.
- Design-system page including type, colors, tokens, components, variants, bottom nav, buttons, fields, chips, cards, avatars, notification styles, diagrams.
- Clickable flow or screen mapping, all button behavior annotated. No dead-end design.
- **Original family illustration concepts** for hero/onboarding, no copied characters from references. Include illustration specs and asset export needs (SVG/transparent PNG/WebP).
- Both parent and child mode, with high-contrast accessible states and good text scaling.
- Prefer light theme first; optional dark theme consistent with Chorely branding.
- Use real household-friendly example content (cook rice, feed cat, wash dishes, sweep floor). Avoid business meetings, client projects, fake charts, irrelevant accounts, or subscription purchase UI in child mode.

## Quality bar
Avoid UI drift across screens. Use same font families, colors, corner radii, nav and spacing; meaningful interactions; never rely on illustration alone; no accidental tiny text. Do not generate an 'all features in a single messy shot' collage as the only deliverable. Organize screens and components for Flutter handoff. Report what was designed vs requested, with gaps.
