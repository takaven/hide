# Gameplay systems

## Round flow

`Lobby -> Prepare -> Hunt -> Relocation -> Hunt -> Extraction -> Results`

Durations and minimum players are configured centrally. Invalid skips are rejected by the round transition graph. The second Hunt proceeds to Extraction, which forces survivors to leave hiding.

## Player states

Supported states are Active, Hiding, Downed, Rescued, Eliminated, Escaped, and Spectating. The server transition graph rejects illegal recovery, escape, or re-entry. Eliminated, escaped, and spectating players are blocked at the action dispatcher.

The first configured capture downs a player. Rescue requires a different eligible player to remain within range for the full duration. One rescuer owns a live attempt, but ownership is cancelled after configured range grace, disconnect, rescuer state loss, target recovery/removal, or completion-window expiry. A replacement rescuer may then start. The downed timer or capture limit eliminates the target. Successful rescue leaves the target in Rescued, an eligible recovery state that can act, hide, escape, or be captured.

## Shared Silence

Each hiding spot combines five server-owned inputs:

1. base occupancy risk;
2. risk for every additional occupant;
3. recent local noise;
4. server-observed occupant movement;
5. decaying hiding heat.

The result is clamped to 0–1 and classified as Safe, Warning, Unstable, or Broken. Entering, exiting, refusing entry, moving, and remaining crowded affect risk. A transition into Broken emits a FailedSilence event and compromises that hiding spot for `Hiding.ExposureDuration`. Exposure is server-owned, extends monotonically on a new break, expires automatically, and clears between rounds.

Hiding Heat is also a discovery rule, not merely an AI-interest signal. Occupants are discoverable during a successful local inspection when the spot is exposed **or** its heat is at least `Hiding.InspectionHeatThreshold`. The initial value `0.6` is reached after roughly 30 seconds of uninterrupted solo occupancy under the current heat settings. A cold silent spot remains safe from inspection; repeatedly or continuously relying on it eventually does not. Neither path gives The Listener map-wide knowledge: it must physically reach or complete navigation near the spot's inspection point.

## Let Me In

An empty spot admits an eligible nearby survivor immediately. An occupied non-full spot creates a short-lived request. Current occupants receive large accept/refuse actions. Only an occupant may resolve the request; capacity, server proximity, player existence, and requester state are rechecked before mutation. The requester state transition is committed before occupancy, heat, noise, or accepted analytics are changed, so a stale/downed requester cannot create rollback side effects. Terminal/expired requests are pruned through a per-player pending index.

## Hold the Door

Tagged doors expose a one-tap prompt. A successful request creates an eight-second server lease with `heldBy`, `heldUntil`, and `exposedUntil`, emits door noise, prevents another survivor from stealing the lease, and enforces a cooldown. The runtime opens the physical panel and removes collision only while the lease remains valid. The lease releases if the holder walks away or loses eligibility; a player cannot enter hiding while holding a door.

## Noise, heat, and decoys

Noise events contain origin, magnitude, category, timestamp, decay, source IDs, hunter relevance, and a false-evidence flag. Magnitudes decay linearly and expire from memory. Categories weight hunter relevance.

Repeated or prolonged hiding increases heat; heat cools over time. Server-observed character velocity emits footsteps at a bounded interval, with carpet/fabric quieter and metal/diamond plate louder. A one-use contextual storm-clicker decoy enters the normal noise ledger as false evidence. The hunter decision path deliberately receives no privileged truth bit: false and real noises use the same scoring path.

## The Listener

The Listener is an understandable state machine:

`PATROL -> INVESTIGATE -> SEARCH -> CHASE -> RETURN`

Priority is direct server raycast visibility, then weighted fresh noise, then hiding heat, then patrol. Hiding players are excluded from ordinary direct visual acquisition; exposure or threshold heat makes them discoverable only through a local inspection. Native PathfindingService is wrapped by a replaceable provider with cancellation, bounded replans, stuck detection, and monotonically increasing movement generations. `INVESTIGATE` accepts completion/arrival only from the generation bound to its own target, so a previous patrol's `Completed` status cannot produce a false inspection. Arrived, completed-near, completed-far, failed, cancelled, and timed-out outcomes remain explicit.

## Character lifecycle

Character creation, death/reset, and player removal invoke one server coordinator. It silently removes ghost hiding occupancy, releases door leases, cancels rescue attempts involving the player, clears stale capture/context state when appropriate, and derives an allowed player state. A downed player retains the legitimate downed deadline across character recreation; removal moves the player to Spectating before registry deletion.

## Extraction and spectator foundation

Extraction opens only in the Extraction phase and validates eligible state, point ID, server position, and distance. When the phase begins, every hider is server-ejected, made visible, and returned to an eligible active state. The arrival cyclone gate is the single extraction objective; escape transitions the player out of gameplay.

Spectators have no action path: the shared dispatcher rejects all gameplay requests before target-specific code. Their client camera is fixed to a map-wide observation point rather than following survivors. Hidden character parts are made transparent and non-collidable by the server, which prevents ordinary replication/free-camera observation from revealing an avatar; the server retains occupancy and authority.

## Analytics

The provider-neutral server bus accepts only the declared event vocabulary. The runtime provider sends bounded, server-originated Roblox `AnalyticsService` custom events with at most three non-PII fields. Studio logs confirm emission; production dashboard ingestion still requires a published experience.
