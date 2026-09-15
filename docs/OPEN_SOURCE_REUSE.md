# Open-source audit and reuse record

Audit performed 2026-09-15 before core implementation. The production strategy is a clean original TAKAVEN repository with selective pattern harvesting. No audited source file was copied or adapted.

| Repository | License | Decision | Reused Code? | Reused Pattern? | Why | Files/Areas Used | Attribution Needed? |
|---|---|---|---|---|---|---|---|
| `oh-ashen-one/roblox-infected` | Unverifiable; repository returned GitHub 404 | REJECT | No | No | The named repository was unavailable through both Git and GitHub API; owner search did not expose a renamed public equivalent. Architecture, tests, CI, security, bots, maps, and publishing therefore could not be responsibly audited. | None | No |
| `princeofscale/bloxforge` @ `ef98c370` | MIT | PATTERN ONLY | No | Yes | Strong Phase-2 bridge: local MCP-to-Studio transport, Rojo-aware source ownership, plan/apply mutations, playtest/log/screenshot tools, provenance, rollback, and capability boundaries. Too large and Studio-dependent for the Phase-1 runtime. | `README.md`, `docs/architecture.md`, `docs/known-limitations.md`, toolchain and safety architecture | No; no code copied |
| `Roblox/resources` @ `0b1ea8ec` | MIT, Roblox Corporation | PATTERN ONLY | No | Yes | Official examples demonstrate server-side type/proximity validation, prompt debouncing, input-aware touch UI, Rojo packaging, and simple state composition. Native Roblox conventions are preferred over a gameplay framework. | laser-tag validation/touch/prompt examples; NPC state-machine example; experience project layouts | No; no code copied |
| `nsawill1405/Pathfinding-Plus` @ `99c33ad0` | MIT, William North | PATTERN ONLY | No | Yes | Useful concepts include cancellable navigation, stuck/blocked replanning, moving-goal thresholds, shared compute budgets, bounded retries, normalized results, and unit-testable policies. One hunter does not justify a dependency before native PathfindingService is measured. | `src/Planner`, `src/Navigator`, `src/Coordinator`, `test/specs`, public API | No; no code copied |
| `takoyakisoft/roblox-rojo-wally-template` @ `abdf2d7a` | MIT | PATTERN ONLY | No | Yes | Current, compact Rojo/Rokit/Wally/Selene/StyLua/Lune CI layout. Tool pins were independently checked against current upstream releases rather than copied unchanged. | `rokit.toml`, `wally.toml`, `selene.toml`, `.github/workflows/ci.yml`, test runner shape | No; no code copied |
| `Ranoobaba/rblx_dev` @ `3ce05883` | MIT, Ranoobaba | PATTERN ONLY | No | Yes | Confirms a simple build/check/publish sequence, explicit environment selection, numeric ID validation, API-key environment loading, and retry handling. Its genre templates, deploy wrapper, and auto-deploy assumptions add unnecessary scope. | base template, `src/commands/{build,check,deploy}.rs`, `src/cloud/publish.rs` | No; no code copied |
| `dnouri/roblox-pi-template` @ `b1b25e5` | No license found | REFERENCE ONLY | No | No | Demonstrates an AI-first local-source workflow and a Studio bridge, but absent licensing blocks reuse and the broad in-Studio module invocation bridge is unsuitable for a security-sensitive runtime. | README, Makefile, verification scripts, MCP bridge | No; no code copied |
| `froggered/roblox-template` @ `a2edcbcf` | No license found | REFERENCE ONLY | No | Yes | Clean single-entry server and central config ideas are useful. Persistence, leaderboards, marketplace code, economy, and dynamic remotes are out of scope; no-license status blocks copying. | layout, server entry point, configuration/remotes concepts | No; no code copied |

## Audit conclusions

- **Production base:** original `takaven/hide`; no fork history and no third-party game base.
- **Runtime dependencies:** none for Phase 1. This keeps the validation surface small.
- **Navigation:** native `PathfindingService` behind `NavigationProvider`; evaluate Pathfinding-Plus only after measured failure in a real map.
- **Automation:** use Rojo as source authority. Recommend BloxForge as an optional Phase-2 bridge after reviewing its current version and operating it locally with a restricted profile.
- **Security:** remote schemas, state checks, server-derived proximity, per-action rate limiting, replay protection, and server-owned outcomes are original HIDE! implementations.
- **Unavailable primary reference:** this is a documented audit limitation, not permission to infer or reproduce its design.

## Tool compatibility verification

Upstream latest releases checked on 2026-09-15: Rojo 7.7.0, Rokit 1.2.0, Wally 0.3.2, Selene 0.31.0, StyLua 2.5.2, Lune 0.10.5, and luau-lsp 1.69.0. The repository pins those versions except Rokit itself, which is installed by the CI setup action.
