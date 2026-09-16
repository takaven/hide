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

- `Config.luau` is the single balance surface for players, phases, proximity, Breath, The Stop, noise, heat, doors, rescue, The Draw, extraction, The Listener, prototype flags, and remote controls.
- `ConfigValidator.luau` rejects missing, non-finite, negative, or contradictory settings at server startup and in tests.
- `RemoteProtocol.luau` and `ActionValidator.luau` declare and validate the only accepted client action shapes.

Shared code contains contracts, not authority. A client knowing a threshold cannot grant itself an outcome.

### `src/server/domain`

These modules avoid Roblox services so Lune can test their rules directly:

- state machines for rounds, players, and The Listener;
- authoritative character lifecycle cleanup across hiding, doors, rescue, and capture;
- occupancy-scaled Breath calculation and stationary freeform pressure;
- hiding occupancy, Let Me In requests, acceptance/refusal, heat, and exposure-or-heat inspection eligibility;
- noise creation, validation, decay, and evidence projection;
- Hold the Door leases;
- rescue attempts, ownership, cancellation, range grace, and completion expiry;
- decoy allocation and false evidence;
- extraction availability;
- rate limiting, replay protection, payload validation;
- provider-neutral analytics.

### `src/server/runtime`

- `WorldBuilder` creates the compact fictional Le Morne resort, enclosed gameplay rooms and corridors, authored interaction/peek/inspection points, patrol network, two extraction routes, storm presentation, and original primitive Listener from repository code before world discovery.
- `WorldRegistry` reads server-visible CollectionService tags and validates IDs, capacities, and positions.
- `InteractionBinder` creates native ProximityPrompts for hiding, doors, and extraction. Prompt events re-enter the same validated gateway as explicit remotes.
- `RemoteGateway` rejects malformed, unknown, replayed, or excessive requests before dispatch.
- `ActionService` re-checks round/player state, server-derived distance, occupancy, ownership, time, and availability before mutating a domain.
- `RoundService`, `CaptureService`, `RescueMonitor`, `RescueInteractionService`, `DownedEvidenceService`, and `SilenceMonitor` own time-dependent transitions and contextual presentation. `SilenceMonitor` treats suspicion-tier changes as snapshot boundaries instead of waiting for an unrelated risk delta.
- `PlayerLifecycleService` translates character creation, death/reset, and player removal into one tested cleanup coordinator. `RoundPlayerReset` defines the fail-closed terminal reset plan; `PlayerStatePresentationService` executes it by relocating a secured live rig to `ArrivalSpawn` or reloading a dead/missing character before the new round.
- `HunterService` feeds visual, noise, heat, and broken-Breath evidence into `HunterBrain`, performs The Stop only near occupied shelters, honours a bounded Draw commitment, inspects only locally reached discoverable hiding spots, requests movement through a navigation provider, and resets both brain and physical rig to the authored start between rounds.
- `NativeNavigationProvider` uses PathfindingService with cancellation, stuck detection, bounded replanning, and status reporting.
- `CharacterPresentationService` conceals and immobilises hiding avatars on the server. `PlayerStatePresentationService` immobilises downed players, shows a bounded rescue marker, and makes eliminated/escaped/spectating characters non-physical and non-queryable. `DoorPresentationService` turns a server lease into a physical brace: the door is held shut while the helper is immobilised and exposed. `ExtractionRuntimeService` ejects hiders when extraction begins.
- `MovementNoiseService` samples server-observed assembly velocity and floor material. `StationaryExposureService` adds the one fair anti-freeform-camping pressure after a server-observed stationary grace period. `RobloxAnalyticsProvider` maps the allow-listed analytics bus to server-side `AnalyticsService` custom events without PII fields.
- `AudioPresentationService` supplies spatial Listener, hiding, door, rescue, decoy, phone, and extraction cues using redistribution-safe Roblox packaged sounds. `MovieMomentDirector` selects at most two bounded authored events per round. `SoakMetricsService` records occupancy, evidence-ledger peak, and event counts for Studio diagnostics.
- `Remotes` creates a fixed set of remotes with class checks.

### `src/client`

The client presents contextual actions. Roblox native prompts provide phone, keyboard, and controller affordances for world interactions. ContextActionService supplies large touch actions for VOLUNTEER OUT, risky peek, DISTRACT, spectator cycling, and the Let Me In accept/refuse decision. Let Me In has explicit context priority: it removes shelter controls while the decision is live, then restores them after resolution or expiry. The Breath panel uses paired pulsing lung shapes, colour, and concise pressure language rather than exposing an authoritative numeric rule. After subscribing to events, the client invokes a read-only state snapshot function so a startup race cannot strand it in stale spectator presentation. The client never calculates authoritative success.

## Runtime ownership

`EnvironmentConfig` resolves explicit Development, Staging, and Production profiles from a workspace attribute without embedding universe/place IDs. The Breath proof overrides AI fill off through `Prototype.AIGuestsEnabled = false`; no AI guest may influence the first blind result. The previous AI implementation remains source-controlled and can be re-enabled after the core thesis is decided. The existing `HideHumanOnlyTest` switch remains available for staging isolation.

`staging.project.json` is the reproducible publication input for the private test experience. It carries only non-secret environment attributes and maps the same repository-owned client, server, and shared source as the default project; the generated `.rbxlx` remains ignored.

Both Rojo projects explicitly use Roblox's modern `Soft` lighting style. This records the Compatibility-to-Voxel migration selected by Studio and prevents the lighting result from existing only as unpublished place metadata.

`HighlightTracker` observes the provider-neutral analytics bus. It derives a bounded moment-of-the-round and positive Results awards from events the server already accepted; it does not add a replay engine or client-authored scoring. `RematchCoordinator` accepts one Results-only request per player and advances through the legal Results → Lobby → Prepare transitions after a short configurable delay.

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

## World contract and current map binding

World construction is intentionally data-driven through tags and attributes:

| Tag | Instance | Required attributes |
|---|---|---|
| `HideHidingSpot` | BasePart or Model | `HidingId: string`, `Capacity: integer >= 1`; descendants named `HiddenPoint`, `HunterApproach`, and `PeekPoint` in the current map |
| `HideDoor` | BasePart or Model | `DoorId: string` |
| `HideExtraction` | BasePart or Model | `ExtractionId: string`; optional descendant `ExtractionApproach` supplies the reachable activation point |
| `HideHunter` | Model | Humanoid and HumanoidRootPart |
| `HidePatrolPoint` | BasePart or Model | none |

IDs are limited to 64 characters at the network boundary. The current `WorldBuilder` supplies six hiding spots with ten total slots, three braceable doors, two alternating extraction routes, eight patrol points, and one Listener. Every hiding spot has authored `HiddenPoint`, `HunterApproach`, and `PeekPoint` parts. Both solid extraction gates have an interior, walkable `ExtractionApproach`; pathing and distance validation use that point instead of the collidable gate pivot. The Listener uses a welded non-avatar Humanoid rig with neck-death disabled so long sessions cannot silently remove the threat. A later art pass may replace geometry while preserving these tags, attributes, and identifiers.

`HunterApproach` is the navigation-safe inspection point outside a wardrobe, bed, or cabinet. If absent, the hiding pivot is the fallback. Navigation completion, failure, cancellation, and investigation timeout are distinct brain inputs; failure never masquerades as arrival. Every movement command has a generation, and a new investigation binds the generation created for its own forced `MoveTo`. Only matching-generation arrival/completion can authorize inspection.

`HidingSystem:IsDiscoverable` is the single inspection gate: current timed exposure or heat at/above `Hiding.InspectionHeatThreshold`. The heat ledger and this decision live in server-domain code under `ServerScriptService`; no network action can set heat, discovery, exposure immunity, or safety.

## Static-analysis boundary

CI applies Luau analysis with the pinned Roblox definitions and Rojo sourcemap to all of `src/shared` and `src/server/domain`. Runtime adapters remain covered by StyLua, Selene, tests through extracted domains, and a full Rojo build. Wider runtime type analysis is deferred until the dependency-injected Roblox service shapes are formalised; pretending those dynamic adapters are fully typed would weaken rather than strengthen the gate.

## Deliberate non-decisions

- No persistence, economy, shop, rewards, inventory framework, or monetisation.
- No additional hunter implementation: native navigation must first fail in measured Studio tests.
- No dynamic remote factory exposed to feature code.
- No Studio-authored gameplay scripts or unpublished source-of-truth mutations.
- No Open Cloud deployment or production place publication in this branch.
