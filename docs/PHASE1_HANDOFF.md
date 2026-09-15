# Phase-1 handoff for Claude review

## Review target

- Repository: `https://github.com/takaven/hide`
- Branch: `phase-1/core-foundation`
- Base: `main`
- Scope: GitHub/source foundation only; do not enter Roblox Studio during this review.

## What is implemented

- Complete configurable round and player transition graphs.
- Shared Silence risk, occupancy, movement input, local noise, and hiding heat.
- Let Me In request, accept/refuse, expiry, authorization, and capacity race checks.
- Timed Hold the Door lease and exposed interval foundation.
- Validated decaying evidence ledger with decoys on the same hunter path.
- Downed/capture limit, rescue timing, start/end proximity, and timeout elimination.
- Extraction gating and spectator action denial.
- The Listener evidence/state brain, server visibility, and replaceable native navigation.
- Fixed remotes, schema validation, extra-field rejection, per-action rate limits, replay defense, state checks, and server-derived proximity.
- Provider-neutral allow-listed analytics.
- Native mobile/keyboard/controller prompts and large Let Me In decision actions.
- Pinned toolchain, CI, deterministic tests, structural validation, and Rojo build.

## Reproduce validation

```sh
rokit install
wally install
stylua --check src tests scripts
selene src tests scripts
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --platform=standard src/shared
lune run tests/run.luau
lune run scripts/validate-structure.luau
mkdir -p build
rojo build default.project.json --output build/hide.rbxlx
```

CI also rejects tracked secret-like files and binary Roblox place/model artifacts.

## Adversarial review prompts

1. Can a client create an outcome by forging action, target, accepted value, position, elapsed time, or extra reward fields?
2. Can concurrent Let Me In resolutions exceed capacity or admit an ineligible requester?
3. Can a spectator, escaped player, eliminated player, or stale contextual button influence the round?
4. Does Shared Silence actually make the second and third occupant riskier under plausible noise/heat?
5. Can decoy evidence be distinguished by The Listener's scoring path when it should not be?
6. Can navigation replan without bounds, hang on MoveToFinished, or retain blocked connections?
7. Do the tests assert behavior rather than implementation trivia?
8. Is any audited code copied without notice, or any unlicensed source reused?
9. Has a Studio-dependent claim been overstated as complete?

## Explicit Studio-dependent work

Phase 2 must:

- create one fictional Mauritius-inspired resort greybox;
- add unique tagged hiding spots, doors, extraction points, one Listener model, and patrol points using the contract in `ARCHITECTURE.md`;
- connect hiding state to character visibility/collision/position without moving authority client-side;
- connect door leases to physical door animation/collision and cooperative passage;
- provide contextual rescue and decoy affordances;
- implement a safe spectator camera that reveals no hidden locations;
- playtest touch target placement on multiple phone aspect ratios;
- tune phase lengths, silence thresholds, evidence weights, speeds, and path agent parameters;
- exercise server/client multi-player races, disconnects, respawns, and latency;
- add screenshots, logs, and measured playtest findings;
- prepare staging IDs and Open Cloud credentials outside the repository only after approval.

## Known limitations

- The named primary reference `oh-ashen-one/roblox-infected` was unavailable (GitHub 404), so it could not be audited. No claims about its internals are made.
- Phase 1 has not been executed in Roblox Studio and does not claim an end-to-end playable place.
- Hold the Door is a validated timed lease, not yet a physical door implementation.
- Rescue and decoy have server contracts but need Phase-2 contextual world/UI binding.
- Spectator enforcement exists; spectator camera presentation does not.
- The Listener uses basic raycast vision and native path defaults; map-specific tuning is intentionally deferred.
- Analytics is in-memory until a provider and privacy/retention policy are selected.
- No rewards exist; adding them would require a new server-owned and tested domain.

## Phase-2 automation recommendation

Use Rojo as the non-negotiable source-of-truth bridge. BloxForge is the recommended optional automation layer because its current public implementation supports Codex/Claude MCP clients, Instance editing, Rojo-aware source ownership, playtests, screenshots, logs, mutation plans, and rollback. Re-review the installed version before use, run locally with the narrowest appropriate capability profile, and do not let Studio changes replace repository logic.

## Remaining blockers

There are no known blockers to independent source review. Studio validation is a deliberate Phase-2 gate, not a Phase-1 completion claim.
