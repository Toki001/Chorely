# Chorely Design System v1 — Friendly Household Clarity

## Concept
Light-first premium family productivity, **not** corporate SaaS. Welcoming, comfortable and practical, with delightful but restrained illustrations. Rounded forms like references 01, 04, 06, 07. Professional typographic hierarchy; no excessive glossy gradients, generic AI glassmorphism, fake bar charts, gamified overload or vague CTA labels.

## Brand identity
- **Name:** Chorely; wordmark rounded yet legible; do not derive from supplied app brands.
- **Voice:** warm, supportive, practical; phrases such as "Your turn to feed the pets" and "Nice work — dinner is ready". Never scold children or assign negative personality labels.
- **Tagline:** One home. One team. Everyone plays their part.
- **Illustration:** original flat editorial art: family teamwork, playful geometric forms, chunky friendly shapes, limited palette; essential instructions never depend on art.

## Proposed tokens (starting point, check contrast & test)
| Token | Light | Dark (optional) | Usage |
|---|---|---|---|
| Primary | `#675CE8` | `#A79BFF` | primary CTA, active nav, selected state |
| Background | `#F8F9FC` | `#12141C` | app background |
| Surface | `#FFFFFF` | `#222630` | cards/panels |
| Surface soft | `#F0EEFF` | `#302B4E` | gentle highlights |
| Text primary | `#171923` | `#FAFAFF` | headings and content |
| Text secondary | `#596174` | `#C1C7D3` | supporting text |
| Border | `#E6E9F0` | `#3B414E` | separators, controls |
| Success | `#19856A` | `#71D7B0` | completion, only when semantic |
| Attention | `#B66A11` | `#F5C777` | approaching deadline |
| Error | `#C54550` | `#F49DA8` | real errors, not routine overdue shame |
| Lavender | `#EEE9FF` | `#40385E` | illustration/card accent |
| Mint | `#E0F6EB` | `#28483D` | illustration/card accent |
| Apricot | `#FFEDD9` | `#543E2B` | illustration/card accent |
| Sky | `#E4F3FF` | `#294459` | illustration/card accent |

Treat colors as a design hypothesis: check WCAG contrast at real UI sizes. Avoid text directly on pale accent unless contrast passes. Token definitions also supplied in `tokens.json`.

## Typography
- Use a licensed, installable typeface (e.g., Manrope or Plus Jakarta Sans if verified). Do not bundle proprietary fonts or copy from screenshots. System fallback must work.
- Large editorial greeting 30–34sp, section headers 20–24sp, card titles 16–18sp, body 14–16sp, labels ≥12sp. Respect textScaleFactor / new Flutter text scaling and local script lengths.
- Consistent weights 400/500/600/700 and 1.25–1.45 line height for body. Avoid cramped child-task cards.

## Layout
- Spacing base 4dp: `4, 8, 12, 16, 20, 24, 32, 40, 48`.
- Mobile horizontal padding 20–24dp, list row gaps 10–12dp, section gaps 24–32dp, card radii 18–28dp, buttons 14–18dp.
- Tap targets ≥48×48dp; use safe areas and keyboard-aware bottom actions.
- Floating add action may be prominent but must not hide bottom content. Nav labels remain visible.
- Use soft/no shadows; rely on white surfaces, subtle outlines and spacing. Max 1–2 accent panels per screen.
- At 320dp width, system large text, landscape and tablet, no clipped buttons or horizontal scrolling for core tasks.

## Interaction
- One-tap check gives immediate visual feedback; if pending offline clearly indicate "Waiting to sync". Approvals show pending status rather than falsely "Verified".
- Use animated completion check (subtle ~150–250ms) respecting reduced motion; gentle screen transitions; **no distracting confetti for overdue chores or penalizing children**.
- Use icons with labels, not color alone. Meaningful empty, loading, error, offline, sync conflict and permission-denied states.
- Calendar colored by household member with patterns/labels accessible to color-blind users.
- Children: large task action, simple vocabulary, optional explanatory illustration, never lead to payment pages.

## Components
`AppScaffold`, `ChorelyBottomNav`, `FamilyAvatar`, `MemberPicker`, `ChoreCard`, `TaskChecklist`, `DueTimeChip`, `RotationPreview`, `RoutineCard`, `ProgressSummary`, `CalendarStrip`, `NotificationTile`, `PendingSyncBadge`, `EmptyIllustratedState`, `TaskActionSheet`, `GuardianApprovalSheet`, `ErrorRetry`, `SkeletonCard`.

## Navigation
Primary: **Today / Chores / Calendar / Lists / Family**. Lists can show "Coming next" only in dev roadmap—not inert nav in release. For P0 release either deliver functional basic shared list or temporarily hide that tab; **never ship an inert Lists tab**. Role-aware controls but shared IA as appropriate.

## Screen design audit rubric
Original illustration rights? consistent tokens? child mode? dark theme? touch targets? text scaling? actual data? empty and failure states? offline status? permission clarity? cross-platform nav? screenshot on small and large screens? screenshot comparison with user refs *principle-level* not pixel copying?
