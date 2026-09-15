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
- Three server-leased brace doors and eight shuffled patrol points.
- Server-generated Listener rig using original primitive geometry.
- Le-Morne-inspired stepped basalt silhouette and front ridges, storm-facing Indian Ocean, filaos, ravenala/traveller's palms, volcanic stone, timber, sugar chimney, four-stripe Mauritius flags, `SORTIE / EXIT / SORTI`, bus-stop and dodo cues, and explicit Le Morne/Mauritius resort signage.
- Storm grading, emergency lighting, visual rain, low storm wind, thunder-synchronised lightning, and visibility bright enough for mobile navigation.

## Runtime integration

- Responsive round/objective HUD with separate immediate **NOISE** and persistent **SUSPICION** states.
- Mobile, keyboard, and controller bindings for hide/exit, Let Me In, doors, rescue, decoy, and extraction.
- Server concealment, immobilisation, collision suppression, and safe reveal for hiding avatars.
- Server-observed movement noise with floor-material multipliers.
- Risky server-authorised hiding peek with an authored viewpoint, cooldown, and noise cost.
- Physical door bracing bound to an expiring server lease: the passage is held shut while the helper is immobilised and exposed.
- Hold-to-rescue prompt bound to the tested rescue lifecycle and cancellation rules.
- One-use storm-clicker decoy using the same evidence ledger as real noise.
- Forced reveal/ejection at extraction, two alternating routes with a final gate-jam switch, safe spectator cycling, repeat-round reset, and Roblox-native analytics provider.
- Spatial Listener/hiding/door/decoy/rescue/extraction audio and five bounded movie moments, with at most two selected per round.

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

## Gate state

This document records the Phase-2 implementation and current Studio evidence. It does not by itself approve publication, merge, or production release.
