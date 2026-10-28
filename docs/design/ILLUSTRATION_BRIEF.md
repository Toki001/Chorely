# Chorely Original Illustration System — Asset Brief

## Why images matter
User reference **04-illustrated-onboarding.webp** prominently features a playful editorial person illustration; this is a priority design reference. Chorely should have similarly warm, expressive **original** illustrations for onboarding and selected empty/success states. References 01 and 06 suggest geometric pastel card styling, while 07 suggests quiet whitespace. **Do not copy characters or trace any screenshot.**

## Unified art direction
- 2D flat vector/editorial illustration with rounded geometry, confident outlines where needed, subtle cut-paper shapes, minimal gradients, soft shadows, lively but calm expressions.
- Limited brand palette: Chorely purple `#675CE8`, sky `#E4F3FF`, mint `#E0F6EB`, apricot `#FFEDD9`, charcoal `#171923`; optional coral small highlights.
- Inclusive family/household scenes across ages, body types, gender presentations, diverse skin tones. No stereotypes about who cooks or cleans.
- Prefer isolated transparent-background composition (SVG or high-res WebP/PNG, licensed), with flexible safe space to fit UI; no embedded text in artwork. Portrait-friendly 4:5 or 1:1 where appropriate.
- Screen readers receive equivalent text descriptions; do not rely on the image to communicate critical functionality.

## Original illustration prompts (use with a licensed image generator or illustrator)
1. **Hero / Welcome — 'One home, one team'**: original cheerful editorial flat-vector illustration of 3 family members in a modern cozy home working together on simple household chores, one carrying a small laundry basket, another watering a houseplant, another checking a clipboard. Friendly exaggerated geometric shapes, clean violet/mint/apricot palette, bright cream whitespace, no logos/no text, transparent or plain background, 4:5. *Take only the illustration energy from reference 04, not its character, pencil, layout or pose.*
2. **Create your first chore:** single expressive person pinning an illustrated checklist to a fridge with simple home motifs; violet/sky/mint accents, isolated, 1:1.
3. **All caught up:** two household members celebrating a finished cleaning session with a small sparkle/check icon, subtle joyful expression, not childish sticker art, 1:1.
4. **Family invitations:** warm family group waving from different window-like frames, showing multiple adults and a child, subtle technology/connect theme, isolated, 1:1.
5. **Dinner routine:** one adult at a stove and another family member setting a table while a child carries safe utensils; cookware silhouettes, tasteful colorful flat art, 4:5.
6. **Pet care:** family member refilling a pet's water bowl with a small dog or cat looking on, safe/non-prescriptive, 1:1.
7. **Shared groceries:** adult and teenager carrying a reusable shopping bag full of vegetables, isolated, 1:1.
8. **Sync / offline:** friendly house with dotted connection paths and small check icons, no scary error illustration, 1:1.
9. **Empty calendar:** simplified wall calendar and houseplant with gentle sunlight, isolated, 1:1.
10. **Optional rewards:** illustration of family movie night after completing household plan; supportive, never competitive leaderboard, 4:5.

## Export guidance
Produce transparent SVG or royalty-safe PNG/WebP master, mobile resolutions @1x/@2x/@3x, safe bounding boxes, alpha, no unintended face/text distortions. Verify exact license/source and attribution requirements. Optimize for Flutter assets and test image rendering under light/dark themes. For third-party illustration packs, read commercial redistribution license; do not bundle fonts/stock images without rights.

## Packaging
- `assets/design_references/*` = user screenshots; **reference-only, exclude from app bundle**.
- Proposed `app/assets/illustrations/*` = **original created** assets with accompanying `LICENSES.md`, manifest and alt-text description.
- Design and implement non-illustrated fallbacks when assets are not ready. Do not block core functionality on optional artwork.
