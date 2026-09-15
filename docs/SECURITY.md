# Security and exploit model

## Trust boundary

Clients communicate intent only. The server owns round state, player state, positions used for validation, occupancy, entry resolution, door leases, rescue timing, decoy allocation, extraction, capture, hunter evidence, and analytics. There is no reward or economy system in Phase 1; any future reward path must be server-only.

## Remote controls

Every gameplay request passes these controls in order:

1. the payload must be a table;
2. action must be on the fixed allow-list;
3. request and target IDs must be bounded and character-restricted;
4. action-specific fields must have exact types;
5. unknown fields are rejected;
6. per-player, per-action sliding-window rate limits apply;
7. request IDs are replay-protected for a configured window;
8. current round and player state are checked;
9. target existence, ownership/occupancy, capacity, timing, and availability are checked;
10. distance is calculated from the server character pivot, never accepted from the payload;
11. only the server mutates state and emits the result.

Native ProximityPrompt events do not bypass this boundary; `InteractionBinder` submits them through the same gateway.

`GetStateSnapshot` is a read-only RemoteFunction used after client HUD subscription. It returns only the caller's current player state, the public round phase/deadline, and that caller's own hiding exit context. It accepts no client-supplied identity or target.

## Threat table

| Threat | Control | Residual risk / Phase-2 validation |
|---|---|---|
| Remote spam | Per-action limits and bounded IDs | Tune limits under real latency and mobile double taps |
| Replay | Per-player request-ID window | A new unique malicious request is still subject to state, range, and rate checks |
| Forged target or action | Fixed schemas and server registries | Phase 2 must keep tag IDs unique |
| Teleport/proximity spoof | Server reads character pivot at action time | Roblox movement ownership still permits movement exploits; add displacement heuristics only after measuring false positives |
| Occupancy race / stale requester | Existence, proximity, state, authorization, and capacity are rechecked before an atomic state/occupancy commit | Roblox server callbacks are serialized between yields; domain mutation functions do not yield |
| Fake rescue / rescue lockout | Target state, owner, range, time, disconnect, and completion expiry are checked continuously; lifecycle cleanup cancels attempts | Phase 2 must tune grace under real latency |
| Fake decoy/reward | Server-owned use count; no client reward input | Inventory ownership is intentionally absent in MVP |
| Spectator grief | Spectator-only states rejected before dispatch; spectator camera is fixed rather than survivor-following | A determined exploiter can inspect replicated world structure, but hidden character parts are server-transparent and non-collidable |
| Hunter oracle or fake exposure | No exposure remote exists; the server creates breach state and permits discovery only on a reached/near completed inspection | Tuning must ensure authored approach points do not create unfair through-wall captures |
| Respawn ghost state | One lifecycle coordinator clears occupancy, door leases, rescue attempts, capture/context references | Phase 2 must test Roblox respawn settings and latency |
| Remote replacement | Fixed folder/name/class assertions | Studio must not author conflicting remotes |
| Analytics injection | Server-only allow-list | In-memory provider is non-durable by design |
| Secret exposure | `.gitignore`, placeholders, read-only CI permissions, no deploy job | Repository history must still be reviewed before visibility changes |

## Denial-of-service considerations

Input sizes are bounded. Unknown keys fail closed. Noise magnitude and category are validated. Pathfinding is limited to one hunter, a configured replan interval, stuck timeout, maximum retries, and an investigation deadline. Failed evidence is ignored for the local search interval, preventing immediate infinite retry. Hiding requests are indexed one-per-requester and removed on terminal/expiry paths. Rescue attempts expire and are cleared each round.

## Data and privacy

No credentials, personal data, third-party endpoints, persistence, voice, or user-generated text are stored. Analytics currently uses Roblox user IDs in server memory; a future external provider should pseudonymise them and define retention before activation.

## Secrets and deployment

Only placeholder names appear in `.env.example`: `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`, and `ROBLOX_PLACE_ID`. CI has read-only repository contents permission and no deployment or Roblox secrets. Open Cloud publication remains deferred.

The Rojo place enables `HttpService.HttpEnabled` so the Studio automation plugin can communicate with its loopback bridge during development. No HIDE runtime module issues HTTP requests, and BloxForge was bound to localhost. Reassess and disable the place setting before production publication unless a reviewed runtime HTTP integration is added.

## Runtime security validation priorities

- Try concurrent accept/refuse requests against the last hiding slot.
- Try changing player state or position between rescue start and completion, then verify a second rescuer can take over.
- Try resetting, respawning, or disconnecting while hiding, holding a door, rescuing, or downed.
- Verify a Broken spot is discoverable only after local hunter arrival and resets across rounds.
- Verify a hidden or eliminated player cannot retain an old contextual action.
- Verify prompt-trigger spam enters the same limiter as remote spam.
- Exercise navigation cancellation and path blockage without accumulating connections.
- Confirm physical doors and hiding transitions cannot desynchronise from server leases/state under packet delay and rapid prompt use.
- Attempt to reveal concealed characters through spectator mode, camera changes, collisions, accessories, particles, and nameplates on multiple clients.
- Verify Roblox movement ownership cannot create arbitrary footstep evidence or impossible proximity actions without server position checks rejecting consequential actions.
