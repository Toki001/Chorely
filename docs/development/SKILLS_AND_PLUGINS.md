# Skills and plugin discovery — 2026-10-29

Discovery used the session skill catalog and `rg --files --hidden` over
`~/.agents/skills`, `~/.codex/skills` and `~/.codex/plugins` for SKILL.md.
Read the actual Find Skills and Plugin Management SKILL.md files. Find Skills
is guidance for the `npx skills` ecosystem, not an installed `find_skills` API.
Local inventory is the equivalent discovery mechanism; no remote skills installed.

Plugin Management `search_plugins` was called separately for all eight targets.
No exact named result was returned. Search is not an exhaustive plugin directory.
No plugin was installed, connected, granted permissions or used for app behavior.

| Target | Observed availability | Substitution / limits |
|---|---|---|
| find_skills | Installed `find-skills` SKILL.md | Read instructions; used installed catalog/filesystem inventory |
| Plugin Management | Installed skill + callable search | Read docs and performed read-only discovery |
| headless | No local skill or exact plugin result; search returned Wix/Data | Flutter integration_test, widget/golden tests, simctl; Wix Headless is unrelated |
| graphify | No local skill; plugin search empty | Native dependency tooling + architecture docs |
| ponytail | No local skill; plugin search empty | No assumed capability; native tools only |
| ui-ux-pro-max | No local skill or exact result; MagicPath/Figma/Product Design returned uninstalled | Native Flutter design review using canonical docs |
| web-design-guidelines | No local skill or exact result; unrelated design/browser plugins uninstalled | Flutter semantics/contrast/responsive review |
| shadcn | No local skill; plugin search empty | Flutter Material components; no React pasted into Flutter |
| hallmark | No local skill; plugin search empty | Manual visual QA and goldens |
| emil-design-eng | No local skill or exact result; unrelated design plugins uninstalled | Flutter reduced-motion + interaction review |
| apple-design | Installed, actual SKILL.md reviewed | Guidance targets web/CSS motion; no web APIs used as Flutter code |
| imagegen | Installed system skill; built-in tool callable | Original illustration generation; no API-key CLI use or external account connection |

Installed alternatives also include mobile-native (web-specific), break-ui,
review-animations, prototype, find-animation-opportunities and pick-ui-library.
These are not claimed as used. No separate MCP tools named headless/graphify/
ponytail discovered. Built-in shell, image viewing, image generation and official
web docs are available. All roles above are observed descriptions, not promises
of feature completion.

Skill documentation locations:
- `/Users/jameskierdoliguez/.agents/skills/find-skills/SKILL.md`
- `/Users/jameskierdoliguez/.codex/plugins/cache/openai-curated-remote/plugin-management/0.1.0/skills/plugin-management/SKILL.md`
- `/Users/jameskierdoliguez/.agents/skills/apple-design/SKILL.md`
- `/Users/jameskierdoliguez/.codex/skills/.system/imagegen/SKILL.md`

Official documentation opened during M00/M02 discovery:
- https://docs.flutter.dev/app-architecture/guide — view/viewmodel/repository/service boundaries
- https://docs.flutter.dev/testing/integration-tests — native integration_test workflow
- https://firebase.google.com/docs/rules/unit-tests — rules-unit-testing emulator suite
- https://firebase.google.com/docs/emulator-suite/connect_auth — demo project emulator authentication

Local test/emulator setup will use fictional data only. External services and
store actions still require user authorization. No connected service needed for
the first development slices, so no connection was requested.
