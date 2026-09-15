# Phase-1 handoff for Claude delta review

> Historical gate record: Phase 1 was approved and merged. Current Studio implementation evidence and remaining release risks are tracked in `docs/PHASE2_BUILD.md`.

## Review target

- Repository: `https://github.com/takaven/hide`
- Branch: `phase-1/core-foundation`
- Pull request: `#1`
- Claude-reviewed baseline: `2e7c4df2bc2bb8333836a0a94a36292eccdb52e1`
- Final-remediation baseline: `3b7441668bc1496b488bd34290b513e5b085cb10`
- Scope: review the remediation delta only. Phase 2 remains closed; do not merge or enter Roblox Studio.

## Claude gate provenance

Claude returned **PASS WITH REMEDIATION** and identified three blockers plus three mandatory material findings. This branch addresses them without adding unrelated gameplay scope.

| Finding | Remediation |
|---|---|
| B1: Broken hiding had no consequence | A Broken transition creates a timed server-owned compromise. The Listener discovers occupants only after an arrived or near-completed inspection at the spot approach point. |
| B2: rescue lockout | Live ownership now cancels on disconnect, state loss, target loss/recovery, range-grace expiry, completion-window expiry, player lifecycle cleanup, and round reset. |
| B3: INVESTIGATE deadlock | Investigation timeout and explicit Completed/Failed/Cancelled navigation outcomes always lead to SEARCH. Failed evidence receives a bounded retry suppression. |
| M1: Let Me In mutation order | Requester existence, proximity, and state are checked before the state-transition/occupancy commit. No rollback noise, heat, occupancy, or accepted analytics remain. |
| M4: character lifecycle | A tested coordinator cleans hiding, doors, rescue, capture, contextual state, and legal player-state recovery on recreation, death/reset, and removal. |
| M6: narrow static analysis | CI now analyses all shared and server-domain Luau using the Rojo sourcemap and pinned Roblox definitions. |
| Final B1: quiet solo camping remained undiscoverable | Local inspection now reveals occupants when a spot is exposed or heat reaches `Hiding.InspectionHeatThreshold`; cold spots remain protected. |
| Navigation follow-up: stale Completed status | Movement generations bind each investigation to its forced `MoveTo`; only a matching generation can authorize arrival/completion inspection. |

## Implemented foundation

- Configurable round and player transition graphs.
- Shared Silence risk, occupancy, movement input, local noise, hiding heat, timed compromise, heat-threshold discovery, and local hunter inspection.
- Let Me In request, accept/refuse, expiry/pruning, authorization, atomic admission, and capacity checks.
- Timed Hold the Door lease with lifecycle release.
- Validated decaying evidence ledger with decoys on the same evidence scoring path.
- Downed/capture limits and rescue lifecycle with reclaimable ownership.
- Extraction gating and spectator action denial.
- The Listener evidence/state brain, explicit navigation outcomes, approach points, and replaceable native navigation.
- Fixed remotes, schema validation, extra-field rejection, action limits, replay defense, state checks, and server-derived proximity.
- Provider-neutral allow-listed analytics.
- Native mobile/keyboard/controller interaction foundation.
- Pinned toolchain, expanded static analysis, behavioural tests, structural validation, and Rojo build.

## Reproduce validation

```sh
rokit install
wally install
stylua --check src tests scripts
selene src tests scripts
rojo sourcemap default.project.json --output sourcemap.json
mkdir -p build
curl -fsSL https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.d.luau -o build/globalTypes.d.luau
luau-lsp analyze --definitions=build/globalTypes.d.luau --sourcemap=sourcemap.json src/shared src/server/domain
lune run tests/run.luau
lune run scripts/validate-structure.luau
rojo build default.project.json --output build/hide.rbxlx
```

Runtime adapters are not yet included in luau-lsp analysis because their injected Roblox service shapes are intentionally dynamic. They remain subject to full formatting/lint parsing, extracted-domain tests, structural validation, and Rojo build. Formalising those shapes is preferable to suppressing diagnostics.

## Delta-review attack list

1. Keep one player still in a quiet spot, then add second/third occupants and verify risk rises.
2. Inspect a cold silent solo spot and verify no discovery; keep it occupied until heat crosses `0.6`, inspect locally, and verify discovery without a Broken state.
3. Break a separate spot, wait for The Listener to reach its `HunterApproach`, and verify exposure-based discovery still works.
4. Attempt to invent heat, discoverability, exposure immunity, or safety through remote payloads; no such client action exists.
5. Feed a previous patrol generation's `Completed` status into a new investigation and verify it remains in INVESTIGATE until its own generation completes.
6. Walk away, disconnect, become downed/eliminated, recover the target, and exceed rescue timing; verify ownership cancels and another rescuer can take over.
7. Return Failed, Cancelled, Completed-near, Completed-far, and no result from navigation; verify INVESTIGATE cannot persist beyond timeout.
8. Down the requester while Let Me In is pending; acceptance must not change occupancy, heat, noise, or analytics.
9. Recreate/remove a character while hiding, holding a door, rescuing, or downed; verify no ghost interaction state survives.
10. Introduce an obvious type error under `src/server/domain`; CI static analysis must fail.
11. Reset a round with hot/compromised spots, rescue, and investigation active; each domain must return to its clean initial state.

## Required early Phase-2 work

These are explicit gate inputs, not completed Phase-1 claims:

- **Movement noise:** connect real server-observed character movement and surface behaviour to Footstep/environment evidence.
- **Hold the Door physical consequence:** bind the lease to real collision/animation/path passage and verify the helper remains exposed longer.
- **Hidden-character information security:** prevent replicated avatar presence, spectator cameras, and exploit freecams from trivially revealing hidden players.
- **Hunter chase tuning:** implement and playtest lost-sight grace plus bounded local search/wander rather than immediate simplistic fallback.
- **Gameplay analytics:** add Studio-backed measures for shared occupancy duration, acceptance/refusal context, rescue abandonment, breach-to-discovery, door sacrifice, chase outcomes, and quit timing.
- Build one fictional Mauritius-inspired resort greybox with unique tagged hiding, door, extraction, hunter, patrol, and optional `HunterApproach` instances.
- Connect hiding/downed state to character collision, positioning, animation, and presentation without moving authority client-side.
- Provide contextual rescue/decoy actions and a safe spectator camera.
- Tune touch targets, timing, thresholds, evidence weights, speeds, and path agent settings under multiplayer latency.
- Prepare staging identifiers and Open Cloud credentials outside the repository only after Phase-2 approval.

## Known limitations and risks

- The named reference `oh-ashen-one/roblox-infected` remained unavailable (GitHub 404); no claims about its internals or licence were fabricated.
- Phase 1 has not run in Roblox Studio and is not an end-to-end playable place.
- Hold the Door remains a domain lease until physical Studio binding.
- Hidden avatar replication and spectator presentation are unresolved information-security work.
- The Listener needs map-specific path, visibility, lost-sight, and local-search tuning.
- Runtime adapters are not yet fully statically typed; shared contracts and all deterministic server domains are analysed.
- Analytics remains in memory pending a provider, privacy design, and expanded gameplay schema.

## Phase-2 automation recommendation

Rojo remains the mandatory source-of-truth bridge. BloxForge is the optional automation recommendation because its public implementation supports MCP clients, Instance editing, Rojo-aware ownership, playtests, screenshots, logs, mutation plans, and rollback. Re-audit the installed version at Phase-2 start and use the narrowest capability profile.

## Gate state

This remediation returns PR #1 for Claude delta review. It does **not** approve Phase 2, merge the PR, publish a Roblox place, or claim Studio validation.
