# Gameplay systems

## Breath prototype (current test build)

The current test build validates `MOVE -> SHELTER -> SHARE / REFUSE -> PRESSURE -> BREAK -> RUN -> SHELTER AGAIN`. Shelter danger is presented as **Breath**, not as the earlier Shared Silence/heat HUD. Every occupied shelter accumulates server-owned Breath. The configured base rate is `0.014/second`; occupancy multipliers for one through four occupants are `1.0`, `1.6`, `2.2`, and `2.8`. Entering adds a small occupancy-scaled pressure pulse. Warning begins at `0.55`, Critical at `0.8`, and `1.0` breaks the shelter and makes its occupants locally inspectable. Empty shelters reset Breath; a voluntary exit gives remaining occupants `0.22` relief.

When The Listener comes within the configured 30-stud room proxy of an occupied shelter, it may perform **The Stop** from patrol, search, return, or investigation (never chase or an active Draw commitment). It cancels navigation, freezes and orients its still-unanchored Humanoid, plays a distinct spatial cue, and applies a `3x` Breath multiplier for six seconds (validated within the configurable 4–8 second range). The client receives the Stop transition immediately and changes the paired-lung pulse to **IT IS LISTENING** with a countdown. If Breath breaks, the existing server evidence path leads The Listener to the shelter approach point; it does not gain map-wide occupant knowledge.

The paired lung shapes intensify, pulse faster, and change from green through amber to red. They replace the generic progress-bar presentation for the prototype. Context text becomes **MORE PEOPLE = LESS TIME**, **SHHH — OR RUN**, and **BREAK — LEAVE NOW**. Let Me In remains a server-owned **LET IN / REFUSE** decision. Shelter exit is labelled **VOLUNTEER OUT** and is recorded separately. `Evict` is implemented and validated through the normal action gateway but unavailable while `Prototype.EvictEnabled = false` (the default blind-test setting).

**The Draw** replaces the inventory-like decoy control. An exposed player can press **DISTRACT** to create the strongest current server-owned evidence and commit The Listener toward that position for five seconds. It has no item or inventory state, is rate-limited, and tells the player **IT HEARD YOU — RUN**. A stationary exposed player first receives a visible border and **THE WIND IS FINDING YOU** at six seconds, reinforced by the existing storm ambience. At twelve seconds this becomes **MOVE — THIS SPOT IS EXPOSED** and bounded server-owned storm evidence begins every six seconds. Moving clears the cue. This is the single prototype countermeasure to indefinite freeform hiding; its final fiction and fairness remain blind-test questions.

Prototype flags disable AI guests, Movie Moments, decoy items, and social award overlays without deleting their rollback-safe source. Results instead display a five-line maximum telemetry recap covering admissions, refusals, volunteering, forced exits (when enabled), Draw use, first shelter break, escapes, and players left behind. `VoicePressureEnabled` exists and defaults off; there is no transcription, recording, raw audio collection, or production amplitude binding in this proof.

The deterministic 1/2/3/4-occupant curve and a controlled six-second Stop pass source tests. Authored map shelters retain their existing capacities (one, two, or three); no artificial four-person shelter was added merely to demonstrate the curve. This is not a substitute for a blind Studio session: perceived clarity, survivable post-break routing, and the first-minute movement gate remain runtime validation requirements.

## Round flow

Results offers large **PLAY AGAIN** and **INVITE A FRIEND — BRING SOMEONE YOU TRUST** actions. A rematch request can shorten the Results wait but never bypasses round cleanup. The invite button uses Roblox `SocialService`; HIDE does not implement custom messages or expose contact data.

Low-population Development/Staging sessions use up to three visibly labelled **AI RESORT GUESTS** to reach four total participants. Their intentionally simple loop is `SEEK_SAFETY → HIDE → RELOCATE → RESCUE → ESCAPE`. They use normal occupancy, heat, noise, rescue timing, capture, and extraction checks. R6-style Humanoid rigs remain server-owned; native paths are followed waypoint-by-waypoint, stalled paths are replanned, and repeatedly unreachable targets are temporarily suppressed instead of bypassing walls. They do not receive the Listener's evidence target or teleport to objectives, and are reconciled only between rounds as humans arrive. Human-only testing disables them through the environment profile.

`Lobby -> Prepare -> Hunt -> Relocation -> Hunt -> Extraction -> Results`

Durations and minimum players are configured centrally. Invalid skips are rejected by the round transition graph. The second Hunt proceeds to Extraction, which forces survivors to leave hiding.

## Player states

Supported states are Active, Hiding, Downed, Rescued, Eliminated, Escaped, and Spectating. The server transition graph rejects illegal recovery, escape, or re-entry. Eliminated, escaped, and spectating players are blocked at the action dispatcher.

The first configured capture downs a player. A downed player is physically immobilised, displays a range-limited rescue marker, and emits bounded recurring server-owned evidence at magnitude `0.24`, enough to make rescue risky without overriding louder movement, doors, or decoys. Rescue requires a different eligible player to remain within range for the full duration. One rescuer owns a live attempt, but ownership is cancelled after configured range grace, disconnect, rescuer state loss, target recovery/removal, or completion-window expiry. A replacement rescuer may then start. The downed timer or capture limit eliminates the target. Successful rescue leaves the target in Rescued, an eligible recovery state that can act, hide, escape, or be captured.

## Legacy Shared Silence (retained behind the Breath prototype)

Each hiding spot combines five server-owned inputs:

1. base occupancy risk;
2. risk for every additional occupant;
3. recent local noise;
4. server-observed occupant movement;
5. decaying hiding heat.

The result is clamped to 0–1 and classified as Safe, Warning, Unstable, or Broken. Entering, exiting, refusing entry, moving, and remaining crowded affect risk. A transition into Broken emits a FailedSilence event and compromises that hiding spot for `Hiding.ExposureDuration`. Exposure is server-owned, extends monotonically on a new break, expires automatically, and clears between rounds.

The earlier NOISE/SUSPICION HUD is not shown in the current prototype. The underlying server heat and exposure rules remain available for rollback and continue to provide bounded evidence; Breath is the current player-facing shelter rule. A hiding player may still use the authored `PeekPoint` for limited perception, but each peek is rate-limited and adds server evidence.

Hiding Heat is also a discovery rule, not merely an AI-interest signal. Occupants are discoverable during a successful local inspection when the spot is exposed **or** its heat is at least `Hiding.InspectionHeatThreshold`. The initial value `0.6` is reached after roughly 30 seconds of uninterrupted solo occupancy under the current heat settings. A cold silent spot remains safe from inspection; repeatedly or continuously relying on it eventually does not. Neither path gives The Listener map-wide knowledge: it must physically reach or complete navigation near the spot's inspection point.

## Let Me In

An empty spot admits an eligible nearby survivor immediately. An occupied non-full spot creates a short-lived request. Current occupants receive large accept/refuse actions. Only an occupant may resolve the request; capacity, server proximity, player existence, and requester state are rechecked before mutation. The requester state transition is committed before occupancy, heat, noise, or accepted analytics are changed, so a stale/downed requester cannot create rollback side effects. Terminal/expired requests are pruned through a per-player pending index.

## Hold the Door

Tagged doors expose a **BRACE DOOR** prompt. A successful request creates an eight-second server lease with `heldBy`, `heldUntil`, and `exposedUntil`, emits door noise, prevents another survivor from stealing the lease, and enforces a cooldown. The physical panel becomes shut and collidable while the helper is immobilised in the exposed doorway; releasing or losing eligibility restores movement and the normal open passage. A player cannot hide while bracing a door, so the action is a bounded sacrifice rather than a permanent safety exploit.

## Noise, heat, and decoys

Noise events contain origin, magnitude, category, timestamp, decay, source IDs, hunter relevance, and a false-evidence flag. Magnitudes decay linearly and expire from memory. Categories weight hunter relevance.

Repeated or prolonged hiding increases heat; heat cools over time. Server-observed character velocity emits footsteps at a bounded interval, with carpet/fabric quieter and metal/diamond plate louder. A one-use contextual storm-clicker decoy enters the normal noise ledger as false evidence. The hunter decision path deliberately receives no privileged truth bit: false and real noises use the same scoring path.

## The Listener

The Listener is an understandable state machine:

`PATROL -> INVESTIGATE -> SEARCH -> CHASE -> RETURN`

Priority is direct server raycast visibility, then weighted fresh noise, then hiding heat, then patrol. Hiding players are excluded from ordinary direct visual acquisition; exposure or threshold heat makes them discoverable only through a local inspection. Patrol order is shuffled each round, and the Listener returns to its authored start so a previous chase cannot camp the next-round arrival spawn. CHASE runs at 20 studs/second, retains the last-known position for 1.25 seconds after line of sight breaks, then searches the last-known point, a nearby hiding approach, and a bounded local random point before returning. A low-frequency double-take can send the search back toward its previous target. Native PathfindingService is wrapped by a replaceable provider with cancellation, bounded replans, stuck detection, and monotonically increasing movement generations. `INVESTIGATE` accepts completion/arrival only from the generation bound to its own target, so a previous patrol's `Completed` status cannot produce a false inspection. Arrived, completed-near, completed-far, failed, cancelled, and timed-out outcomes remain explicit.

## Movie moments and sound

At most two authored moments occur in a round: one weighted event at a random configured point in the first Hunt and a probabilistic extraction escalation. Immediate repeats are excluded. A Double Take is announced only after the Listener accepts the request, and the evacuation gate no longer jams every round. The exact event set is cyclone blackout, reception phone, generator restart, Listener double-take, and final escape-route jam. They alter evidence, visibility/noise multipliers, hunter search, or the active route through server-owned state; none is a client-only cutscene.

Spatial audio identifies Listener footsteps, presence, inspection, and chase, plus hiding rustle, door brace, decoy, rescue, extraction alarm, and reception phone. The MVP uses Roblox-packaged sounds only; bespoke licensed production audio remains an art pass, not a gameplay dependency.

## Character lifecycle

Character creation, death/reset, and player removal invoke one server coordinator. It silently removes ghost hiding occupancy, releases door leases, cancels rescue attempts involving the player, clears stale capture/context state when appropriate, and derives an allowed player state. At Prepare, terminal rigs remain secured while being placed at `ArrivalSpawn`, then presentation is restored; dead or missing rigs are authoritatively reloaded. Capture counters and state reset to Active, preventing prior spectator positioning from producing a new-round Downed state. A downed player retains the legitimate downed deadline across character recreation; removal moves the player to Spectating before registry deletion.

## Extraction and spectator foundation

Extraction opens only in the Extraction phase and validates eligible state, active route ID, server position, and distance. When the phase begins, every hider is server-ejected, made visible, and returned to an eligible active state. One of two routes is active per round; the final jam moment switches to the alternate route after a short warning. Each solid gate supplies a walkable interior `ExtractionApproach`; AI navigation and proximity validation target that point instead of the collidable gate pivot. Escape transitions the player out of gameplay.

Spectators have no action path: the shared dispatcher rejects all gameplay requests before target-specific code. They may cycle only eligible living/revealed characters; hidden players are omitted. Hidden character parts are made transparent, non-collidable, non-touchable, and non-queryable by the server, and replicated player attributes do not disclose the spot ID or concealed flag. Eliminated and escaped avatars are also removed from physical/query participation. The server retains occupancy and authority.

## Analytics

First-session teaching is contextual and non-blocking: **HIDE BEFORE IT HEARS YOU**, **MORE PEOPLE = MORE NOISE**, **HOT SPOTS GET CHECKED**, **LET THEM IN?**, **PEEK — BUT IT MAKES NOISE**, **RESCUE THEM BEFORE IT RETURNS**, and **GET OUT NOW** appear only when the corresponding server state or action becomes relevant.

Results shows a telemetry-derived **MOMENT OF THE ROUND** plus positive recognition such as Best Rescue, Door Hero, Longest Hidden, and Final Escape when the supporting accepted event exists. These are social summaries only: no XP, currency, progression, or economy is attached.

The provider-neutral server bus accepts only the declared event vocabulary. The runtime provider sends bounded, server-originated Roblox `AnalyticsService` custom events with at most three non-PII fields. Studio logs confirm emission; production dashboard ingestion still requires a published experience.
