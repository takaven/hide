# Phase-2 Studio build record

## Scope and source of truth

This branch implements one playable source-generated map: **Ravinala Noir**, a fictional resort near a Le-Morne-inspired coast during a cyclone blackout. `default.project.json` and repository Luau remain authoritative. `WorldBuilder` creates the map before the tagged world registry binds gameplay; no critical gameplay code was authored only in Studio.

The map targets eight players. Studio uses a one-player minimum solely for local validation; production remains configured for two players.

## Automation setup

- Roblox Studio: local Windows installation, authenticated by the founder.
- Rojo: `7.7.0`, pinned by Rokit; Studio plugin installed, source place builds successfully, and a localhost serve probe returned HTTP 200.
- Studio bridge: BloxForge `4.4.0`, inspected at commit `ef98c370b6e0dd93273eae245485b547b09aca53`, with localhost binding and a narrow testing capability profile.
- Development HTTP: disabled in `default.project.json`. An ignored `.codex-temp` project overlay enables it only for the loopback Studio bridge; HIDE gameplay code makes no HTTP request.
- Asset policy: no Creator Store models, paid assets, private property layouts, proprietary logos, or unverified audio IDs were imported. MVP storm audio uses only Roblox's packaged `rbxasset://sounds` files.

## Implemented world

- Arrival/reception, guest wing, restaurant/lounge, kitchen/service, laundry/maintenance, generator room, covered walkway, ceilings, intersecting corridors, sightline breaks, and two evacuation routes.
- Six server-registered hiding locations with ten total slots for eight target players. Every location has hidden placement, risky peek, and accessible Listener inspection points.
- Three server-leased brace doors physically occupy the guest-wing wall gap, kitchen-service wall gap, and sole generator approach. The generator's alternate opening is sealed. Eight patrol points remain shuffled each round.
- Server-generated Listener rig using original primitive geometry.
- Le-Morne-inspired stepped basalt silhouette and front ridges, storm-facing Indian Ocean, filaos, ravenala/traveller's palms, volcanic stone, timber, sugar chimney, four-stripe Mauritius flags, `SORTIE / EXIT / SORTI`, bus-stop and dodo cues, and explicit Le Morne/Mauritius resort signage.
- Storm grading, emergency lighting, visual rain, low storm wind, thunder-synchronised lightning, and visibility bright enough for mobile navigation.

## Runtime integration

- Responsive round/objective HUD with separate immediate **NOISE** and persistent **SUSPICION** states.
- Mobile, keyboard, and controller bindings for hide/exit, Let Me In, doors, rescue, decoy, and extraction.
- Server concealment, immobilisation, collision suppression, and safe reveal for hiding avatars.
- Server-observed movement noise with floor-material multipliers.
- Risky server-authorised hiding peek with an authored viewpoint, cooldown, and noise cost.
- Physical door bracing bound to an expiring server lease: each panel gates a real passage and is held shut while the helper is immobilised and exposed.
- Hold-to-rescue prompt bound to the tested rescue lifecycle and cancellation rules.
- One-use storm-clicker decoy using the same evidence ledger as real noise.
- Forced reveal/ejection at extraction, two alternating routes with a final gate-jam switch, safe spectator cycling, repeat-round reset, and Roblox-native analytics provider.
- Spatial Listener/hiding/door/decoy/rescue/extraction audio and five bounded movie moments. Hunt timing and weighted selection vary, immediate repeats are suppressed, and the extraction jam is probabilistic.

## Studio evidence

The following has been exercised through automated Studio sessions rather than inferred from static source:

- Map boot and registry: six hiding spots, ten total slots, six inspection and peek points, three doors, two extraction routes, one Listener, Mauritius flags, Le Morne silhouette, local planting/signage props, ceilings, and visual rain present.
- Client startup: the initial snapshot handshake restored authoritative presentation even when the server's first event preceded client HUD subscription. Players registering during Lobby/Prepare enter the pending round; late Hunt joins remain spectators.
- Hiding presentation: server concealment attribute set, root immobilised, parts made transparent/non-queryable, nameplate disabled, Shared Silence HUD displayed, and a conflict-free exit binding restored the full character state.
- Brace Door: an actual action created the lease, made the panel shut/collidable, set the holder's movement speed to zero, then restored movement and the open passage on release.
- Extraction/reset: a concealed player was server-revealed and no stale concealment survived the following round.
- Two-client startup: server and two clients joined the same Studio test, both entered the pending round from Lobby/Prepare, and both reached Hunt as active players.
- Let Me In: Player1 requested entry to Player2's occupied hiding place through the production remote gateway; Player2 received both accept/refuse actions, accepted within the request window, and both clients observed `2/2` Shared Silence occupancy before exiting cleanly.
- Rescue: The Listener downed Player2, the server attached a four-second hold prompt, Player1 started and completed the rescue through the production client/server action pipeline, rescue noise was returned, and Player2 independently observed `Rescued`, normal camera control, restored actions, and no stale prompt. A test-only extended downed window compensated for bridge-call latency; production rescue duration and prompt hold remained unchanged.
- Shared occupancy: a stable three-client run placed three players in the capacity-three guest linen spot through the production request/accept input path. All three reported `Hiding`; diagnostics recorded two `entry_accepted`, two `shared_hiding_started`, `silence_broken`, and a subsequent hunter investigation.
- Hiding security and peek: all three hidden rigs were anchored with zero visible/collidable/touchable/queryable parts and no replicated hiding ID/concealed attributes. A real peek changed the client camera to `Scriptable`, retained the truthful `SUSPICION • HOT` HUD, and added server evidence.
- Terminal-state physics: an eliminated avatar was relocated to the spectator area with zero visible or physical/queryable parts. A forced torso-collision re-enable was cleared on the next presentation tick, covering Roblox Humanoid collision restoration.
- Cross-round terminal reset: a Studio smoke round forced a live player to Eliminated at the safe spectator platform, then allowed the real `Results -> Lobby -> Prepare -> Hunt` sequence to run. In the next Hunt the same player was Active, health 100, had no downed marker, stood 3.50 studs from `ArrivalSpawn`, and The Listener had reset 103.80 studs away. A focused reset harness also returned capture count zero. This closes both the unsafe-unanchor path and carry-over hunter spawn camping found during adversarial validation.
- HUD/context: a server snapshot at heat `0.6` rendered `SUSPICION • HOT — MOVE SOON`. During a synthetic live Let Me In decision, LET IN and REFUSE were present while PEEK was absent.
- Lighting and passages: blackout changed six enabled house fixtures to zero while all five emergency fixtures stayed lit. Closed door coordinates align with the guest-wing gap `(-86, 4)`, kitchen-service gap `(51, -18)`, and generator approach `(0, -49)`; the alternate generator opening is sealed.
- Mobile: 20:9 Samsung Galaxy A06, 16:9 iPhone 7, and iPad 9th-generation landscape captures kept the objective HUD and large touch controls in bounds.
- Navigation: The Listener moved 25.58 studs during a four-second native-pathing sample on the built map.
- Performance snapshot: Scene Analysis reported 165 Parts, 7,222 opaque triangles, 15 opaque draw calls, and 821 total runtime instances including Roblox/Core UI content. This is a greybox measurement, not a lower-end device frame-time result.
- Roblox analytics calls emitted in Studio logs.
- Movie moments: Studio invoked cyclone blackout, reception phone, generator restart, double-take, and final escape event. Each reported its exact kind; blackout applied `0.55` vision and `1.3` movement-noise multipliers; the final event announced the alternate service exit after the configured jam.
- Listener threat: controlled runtime tests measured the configured 20-stud chase speed, closing distance and a real downed capture; spatial presence, footsteps, inspection, and chase sounds loaded. Patrol/search logic now retains last-known pursuit for 1.25 seconds and moves through up to three local search points.
- Long-session adversarial test found Roblox removing the welded Listener body because the Humanoid expected an avatar Neck. The source rig now disables neck-death and joint breaking. A fresh runtime retained all five body parts at 100 health after chase, capture, search, profiling, and an additional 45-second check.
- No HIDE-owned runtime exception was observed in the current source build; Studio's test clients produced only Roblox/Core UI messages unrelated to this repository.

Screenshots and raw bridge output are kept outside the public repository because generated place binaries and machine-local test artifacts are intentionally ignored.

## Remaining validation and risks

- The environment is a gameplay-complete enclosed greybox, not production art. Le Morne is a readable stylised silhouette rather than geospatial terrain.
- An exact eight-client StudioTestService launch was attempted twice. The local host spawned the server/eight client processes but the clients failed to register with the automation bridge before timeout and saturated Studio. The closest stable automated run was four connected clients; the verified social-mechanic interaction run used three active clients. An eight-human or cloud-device soak remains a release-readiness blocker.
- Native pathfinding, stairs/corners, chase persistence, and inspection fairness still need the full eight-player soak and lower-end device frame-time measurement. Automated client launch latency is not counted as gameplay success.
- MVP sound now covers Listener identity and primary actions using Roblox-packaged files. Bespoke authored production audio remains a quality pass, not a missing gameplay cue.
- The neck-death fix passed the focused runtime regression, but the full eight-player longevity soak remains required before release.
- Roblox custom-event dashboard delivery cannot be verified until a staging experience is published.
- No production place was published and no Open Cloud credential was created.

## Staging and launch-readiness enhancement

- Environment profiles are explicit: Development disables Roblox analytics and permits AI fill; Staging enables analytics and AI fill; Production enables analytics and is human-only by default. A workspace `HideEnvironment` attribute selects the profile, while `HideHumanOnlyTest = true` provides a server-owned, tested AI-off switch for human-only staging sessions. No place or universe ID is stored in source.
- Up to three clearly labelled AI resort guests fill below four total participants between rounds. Their state machine uses server-owned participant domains and their analytics are marked `participantKind = AI`, so they cannot inflate human engagement.
- Results supports an immediate, cleanup-safe rematch, Roblox-native friend invitation, server-derived social awards, and a moment-of-the-round summary.
- First-session guidance is contextual rather than a separate tutorial. Each surfaced step is recorded through the validated action gateway.
- `HighlightTracker` observes accepted gameplay telemetry for near misses, rescues, silence breaks, door holds, escapes, hiding duration, and bounded movie moments. It stores no replay or personal information.
- Human and AI result aggregates are independently counted. AI escapes, eliminations, and survivors cannot increment the human outcome fields consumed by retention/replay analysis.
- The intended private cohort is 8–20 invited testers. AI-assisted and human-only sessions must be analysed separately. Public release remains gated on an eight-human soak, lower-end device measurements, private-experience analytics delivery, and founder review of gameplay captures.

## Final local launch-readiness validation

- A clean Rojo-built Studio session registered one human plus three visibly labelled AI resort guests. All three retained healthy Humanoids, server network ownership, and native-path movement through the resort. A blocked route caused bounded replanning and target suppression rather than teleporting, clipping through walls, falling, or remaining in an endless jitter loop.
- AI guests used normal hiding occupancy and heat. A human requested entry through the production remote and a hidden AI occupant accepted through the server-owned request lifecycle. Heat caused visible relocation without exposing the Listener's private evidence target.
- A controlled local Listener capture downed the human through the normal capture system. A nearby AI produced `rescue_attempted` and `rescue_completed` and obeyed the configured rescue duration and ownership.
- Initial extraction validation exposed `NoPath` because the target was the collidable gate pivot. Both gates now author an interior `ExtractionApproach`. The rebuilt place recorded three AI `player_escaped` events and then restored all three guests to `SEEK_SAFETY` in the following round.
- Results rendered Play Again, Roblox-native Invite Friend, server-derived awards, and a truthful moment fallback. A production rematch request advanced through legal cleanup into the next Hunt with no stale AI, hiding, rescue, award, or highlight state. `SocialService` reported invite support and accepted the Studio prompt call.
- Contextual onboarding and the Results actions were inspected at 20:9 phone, 16:9 phone, and tablet-landscape presets without a critical touch-control collision.
- The native Studio capture controller completed and saved a genuine 29.112-second, 1936×1088 runtime MP4 after the founder handled Roblox's CoreGui Save/Allow flow. Metadata and integrity passed, but visual QA rejected the take: Roblox captured a blank white 3D viewport while retaining CoreGui and the repository's cue overlays. It is preserved as capture-pipeline evidence and is not claimed as shareable footage. Native capture also ignored the portrait simulator. A clean Studio restart and one OBS Record/Stop pair remain the prepared fallback.
- Fresh StudioTestService launches requesting two and four humans both timed out before any test client registered. The final four-human attempt had an edit peer only and zero players. Population arithmetic and boundary-only reconciliation pass tests for `1+3`, `2+2`, `3+1`, and `4+0`, but the final `2+2` and `4+0` combinations do not have fresh runtime evidence on this host. This is recorded as **LOCAL TOOLING LIMITATION — TO BE VALIDATED IN PRIVATE STAGING**.

The release pass deliberately does not add progression, monetisation, a second map, a second hunter, or an external feedback platform.

## Gate state

This document records the Phase-2 implementation and current Studio evidence. It does not by itself approve publication, merge, or production release.

## Breath + The Stop proof build

The next private build is deliberately narrower than the previous staging candidate. It tests only whether Breath and The Stop create a break-and-run decision during the first minute of meaningful play.

- Breath base rate: `0.014/second`.
- Occupancy multipliers (1/2/3/4): `1.0 / 1.6 / 2.2 / 2.8`.
- Warning / Critical / Break: `0.55 / 0.8 / 1.0`.
- The Stop: six seconds, inside the validated 4–8 second range, applying `3x` Breath within a 30-stud room proxy.
- The Draw: magnitude `1.75`, five-second Listener commitment, twelve-second reuse cooldown.
- Freeform countermeasure: server-observed stationary storm evidence after twelve seconds, repeating at six-second intervals until movement resumes.
- Empty shelters reset Breath; volunteering out gives remaining occupants `0.22` relief. Eviction and voice pressure are off by default.

The source simulation produces first breaks within 60 seconds for one, two, three, and four occupants when the controlled Stop occurs. That proves the curve, not the experience. A blind player must still demonstrate that the feedback is understood, that they choose to leave, and that at least two existing resort routes/door breaks make the resulting run survivable. The current map already has two extraction routes, three physical service doors, corridor sightline breaks, and multiple room-to-corridor choices; no new art pass or objective system is included.

The blind session records shelter entry and occupancy changes, Breath snapshots/rates, Stop start/end, time to first break, voluntary/forced exits, Let In/Refuse, Draw, captures/escapes, and stationary exposure duration. Run controlled one-, two-, and four-player shelter cases, then ask without coaching:

1. What were you supposed to do?
2. Why did you leave the hiding place?
3. What happened when more players entered?
4. What did The Listener do when it stopped?
5. Did you feel like you were waiting?
6. Did you want to move?
7. What game did this remind you of?
8. What felt new?
9. What felt cheap?
10. Would you play another round now?

AI guests, Movie Moments, decoy items, award overlays, and persistent social memory are disabled through prototype flags. Voice pressure is an off-by-default interface flag only: a privacy-safe Roblox amplitude/activity feed has not been bound, and voice cannot delay the core test. The PR remains unmerged and the experience must remain non-public.
