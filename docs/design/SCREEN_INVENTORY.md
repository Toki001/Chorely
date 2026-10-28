# Screen Inventory / Required Design States

## Guest / onboarding
S01 Splash/launch; S02 illustrated 3-step onboarding (welcome, assign, celebrate); S03 adult sign-in/sign-up; S04 create household (name/timezone); S05 adult invite/join; S06 child profile creation; S07 secure child device pairing (guardian approval and QR expiration); S08 notifications rationale.

## Main tab flows
S09 Today parent: greeting, family avatar row, actual personal count, next chore highlight, today tasks, optional household summary; S10 Today child: larger personal tasks, steps, tap done/help, no administrative clutter; S11 Chores (mine / all authorized) filters; S12 chore creation bottom sheet/flow; S13 preset gallery; S14 chore detail+subtasks+history; S15 repeat and rotation builder with next two-week preview; S16 routine builder (P1); S17 weekly/day/month calendar with member filters; S18 day detail / occurrence quick action; S19 Lists with actual shared shopping (P1); S20 supply inventory (P1); S21 Family members + invites; S22 member detail with permissions; S23 Settings (notifications, privacy, theme, account/delete).

## Supporting and edge screens
S24 inbox/activity; S25 notifications inbox; S26 review completion / approve / reject; S27 request help/postpone; S28 swap proposal P1; S29 household change/leave; S30 data export/deletion; S31 offline/pending sync; S32 conflict resolve; S33 no permission; S34 empty chores; S35 empty household calendar; S36 full-screen error retry; S37 loading skeletons; S38 child large-font variant; S39 optional rewards P2.

## Per-screen specification checklist
- Clear purpose and intended role; persistent real data fields; primary and secondary CTAs; valid navigation; permission gating; empty/loading/offline/error/success; accessibility semantics and localization; responsive smallest phone/large phone/tablet; illustration requirement and rights; automated golden/widget tests.

## Design patterns
- Today: single warm original illustration card only when it helps explain or celebrate; never dominate actionable tasks.
- Chore cards: icon/mini-illustration, task title, assignee, due time, status and prominent completion.
- Calendar: horizontal day strip + stacked occurrence cards, not 24-hour fake corporate meeting schedule.
- Details: readable instruction steps, timerange, due and repeat, who completes/reviews, actions, history.
- Parent onboarding: calm confidence; Child: simple choices and encouraging wording; Invite: secure status and expiration.
- Analytics: no fabricated counts, never shame individual household members.
