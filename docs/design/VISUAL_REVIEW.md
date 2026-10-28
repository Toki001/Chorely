# M03 design adoption and review

2026-10-29: adopt the proposed violet/light palette, system typography, 24dp page
gutters, 16dp controls, 24–32dp illustration surfaces, 48dp minimum touch targets.
Attention changed from #B66A11 to #955409 for normal text contrast. Measured on
white: primary 4.91, ink 17.50, secondary 6.20, success 4.56, attention 5.92,
error 4.84. Pale accents are backgrounds with ink, never pale text on white.

The first reusable Flutter primitives are PageFrame, InlineError and the theme.
Onboarding applies reference 04's generous editorial image/text hierarchy with a
new household composition. The art was generated without screenshot inputs.
The remaining production screen components will be implemented with their
features rather than adding unused widgets before real behavior exists.

No decorative animation currently runs, so reduce-motion has no motion to disable.
Keyboard dismissal, safe areas, scrollable forms and constrained tablet columns
are implemented. Widget audit exposed a 320dp/200% header overflow, now fixed.
Semantic/touch/contrast tests and baseline images are recorded in M03/M04 evidence.
No human usability approval, screen reader device session or dark-mode acceptance
is claimed. Dark theme is deferred; all product journeys still require M05 onward.
