# Gameplay systems

## Round flow

`Lobby -> Prepare -> Hunt -> Relocation -> Hunt -> Extraction -> Results`

Durations and minimum players are configured centrally. Invalid skips are rejected by the round transition graph. The second Hunt proceeds to Extraction, which forces survivors to leave hiding.

## Player states

Supported states are Active, Hiding, Downed, Rescued, Eliminated, Escaped, and Spectating. The server transition graph rejects illegal recovery, escape, or re-entry. Eliminated, escaped, and spectating players are blocked at the action dispatcher.

The first configured capture downs a player. Rescue requires a different eligible player to remain within range for the full duration. The downed timer or capture limit eliminates the target. Successful rescue leaves the target in Rescued, an eligible recovery state that can act, hide, escape, or be captured. Leaving a hiding spot later normalises that state to Active.

## Shared Silence

Each hiding spot combines five server-owned inputs:

1. base occupancy risk;
2. risk for every additional occupant;
3. recent local noise;
4. server-observed occupant movement;
5. decaying hiding heat.

The result is clamped to 0–1 and classified as Safe, Warning, Unstable, or Broken. Entering, exiting, refusing entry, moving, and remaining crowded affect risk. A transition into Broken emits a FailedSilence event into the same noise ledger heard by The Listener.

## Let Me In

An empty spot admits an eligible nearby survivor immediately. An occupied non-full spot creates a short-lived request. Current occupants receive large accept/refuse actions. Only an occupant may resolve the request; capacity and requester state are rechecked at resolution time. Acceptance creates entry noise and additional occupancy risk. Refusal creates a small configurable noise.

## Hold the Door

Tagged doors expose a one-tap prompt. A successful request creates a timed server lease with `heldBy`, `heldUntil`, and `exposedUntil`, emits door noise, prevents another survivor from stealing the lease, and enforces a cooldown. Phase 2 must connect the lease to the physical door animation/collision and validate the intended cooperative transition in playtests.

## Noise, heat, and decoys

Noise events contain origin, magnitude, category, timestamp, decay, source IDs, hunter relevance, and a false-evidence flag. Magnitudes decay linearly and expire from memory. Categories weight hunter relevance.

Repeated or prolonged hiding increases heat; heat cools over time. A decoy consumes a server-owned per-round use and enters the normal noise ledger as false evidence. The hunter decision path deliberately receives no privileged truth bit: false and real noises use the same scoring path.

## The Listener

The Listener is an understandable state machine:

`PATROL -> INVESTIGATE -> SEARCH -> CHASE -> RETURN`

Priority is direct server raycast visibility, then weighted fresh noise, then hiding heat, then patrol. Hiding players are excluded from direct visual acquisition; they can still expose their hiding place through evidence. Native PathfindingService is wrapped by a replaceable provider with cancellation, bounded replans, and stuck detection.

## Extraction and spectator foundation

Extraction opens only in the Extraction phase and validates eligible state, point ID, server position, and distance. Escape transitions the player out of gameplay.

Spectators have no action path: the shared dispatcher rejects all gameplay requests before target-specific code. Phase 2 still needs a spectator camera and must ensure it reveals no hidden-player information.

## Analytics

The provider-neutral server bus accepts only the declared Phase-1 event vocabulary. With no provider configured, events remain in an in-memory buffer. No third-party analytics package, secret, or network endpoint is included.
