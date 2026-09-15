# Architecture

## Decision summary

HIDE! uses a small, original, service-oriented Luau architecture without a gameplay framework or runtime package dependency. Deterministic domains own rules; Roblox runtime adapters own Instances, players, remotes, pathfinding, and timing. The server owns every consequential result.

```text
mobile / keyboard / controller input
                 |
        ActionRequest RemoteEvent
                 v
  schema -> rate limit -> replay guard
                 |
        server-derived state + distance
                 v
       deterministic domain systems
                 |
   authoritative state/noise/evidence
                 v
 ActionResult + bounded StateSnapshot
```

## Repository layers

### `src/shared`

- `Config.luau` is the single balance surface for players, phases, proximity, Shared Silence, noise, heat, doors, rescue, decoys, extraction, The Listener, and remote controls.
- `ConfigValidator.luau` rejects missing, non-finite, negative, or contradictory settings at server startup and in tests.
- `RemoteProtocol.luau` declares the only accepted client action names and target fields.
- `StateDefinitions.luau` declares round, player, and hunter transition graphs.

Shared code contains contracts, not authority. A client knowing a threshold cannot grant itself an outcome.

### `src/server/domain`

These modules avoid Roblox services so Lune can test their rules directly:

- state machines for rounds, players, and The Listener;
- Shared Silence risk calculation;
- hiding occupancy, Let Me In requests, acceptance/refusal, and heat;
- noise creation, validation, decay, and evidence projection;
- Hold the Door leases;
- rescue attempts and completion timing;
- decoy allocation and false evidence;
- extraction availability;
- rate limiting, replay protection, payload validation;
- provider-neutral analytics.

### `src/server/runtime`

- `WorldRegistry` reads server-visible CollectionService tags and validates IDs, capacities, and positions.
- `InteractionBinder` creates native ProximityPrompts for hiding, doors, and extraction. Prompt events re-enter the same validated gateway as explicit remotes.
- `RemoteGateway` rejects malformed, unknown, replayed, or excessive requests before dispatch.
- `ActionService` re-checks round/player state, server-derived distance, occupancy, ownership, time, and availability before mutating a domain.
- `RoundService`, `CaptureService`, and `SilenceMonitor` own time-dependent transitions.
- `HunterService` feeds visual, noise, and heat evidence into `HunterBrain` and requests movement through a navigation provider.
- `NativeNavigationProvider` uses PathfindingService with cancellation, stuck detection, bounded replanning, and status reporting.
- `Remotes` creates a fixed set of remotes with class checks.

### `src/client`

The client presents contextual actions. Roblox native prompts provide phone, keyboard, and controller affordances for world interactions. ContextActionService supplies large touch actions for exit and the Let Me In accept/refuse decision. The client never calculates authoritative success.

## Runtime ownership

| Concern | Owner | Client responsibility |
|---|---|---|
| Round and player state | Server | Render snapshots |
| Hiding occupancy and entry decision | Server | Request and present choice |
| Noise, heat, evidence | Server | None beyond input intent |
| Door hold lease | Server | Request hold/release |
| Rescue timing and proximity | Server | Request start/complete |
| Decoy allocation | Server | Request use |
| Extraction | Server | Request escape |
| Hunter sensing and navigation | Server | Presentation only |
| Analytics | Server | None |

## World contract for Phase 2

World construction is intentionally data-driven through tags and attributes:

| Tag | Instance | Required attributes |
|---|---|---|
| `HideHidingSpot` | BasePart or Model | `HidingId: string`, `Capacity: integer >= 1` |
| `HideDoor` | BasePart or Model | `DoorId: string` |
| `HideExtraction` | BasePart or Model | `ExtractionId: string` |
| `HideHunter` | Model | Humanoid and HumanoidRootPart |
| `HidePatrolPoint` | BasePart or Model | none |

IDs are limited to 64 characters at the network boundary. Phase 2 must ensure uniqueness and create a Mauritius-inspired fictional resort greybox without embedding game logic in the place.

## Deliberate non-decisions

- No persistence, economy, shop, rewards, inventory framework, or monetisation.
- No additional hunter implementation: native navigation must first fail in measured Studio tests.
- No dynamic remote factory exposed to feature code.
- No finished map or Studio-authored scripts.
- No Open Cloud deployment in Phase 1.
