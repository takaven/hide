# Phase-2 Studio build record

## Scope and source of truth

This branch implements one playable source-generated map: **Ravinala Noir**, a fictional resort near a Le-Morne-inspired coast during a cyclone blackout. `default.project.json` and repository Luau remain authoritative. `WorldBuilder` creates the map before the tagged world registry binds gameplay; no critical gameplay code was authored only in Studio.

The map targets eight players. Studio uses a one-player minimum solely for local validation; production remains configured for two players.

## Automation setup

- Roblox Studio: local Windows installation, authenticated by the founder.
- Rojo: `7.7.0`, pinned by Rokit; Studio plugin installed, source place builds successfully, and a localhost serve probe returned HTTP 200.
- Studio bridge: BloxForge `4.4.0`, inspected at commit `ef98c370b6e0dd93273eae245485b547b09aca53`, with localhost binding and a narrow testing capability profile.
- Development HTTP: enabled only for the loopback Studio bridge; HIDE gameplay code makes no HTTP request and the setting must be reassessed before production publication.
- Asset policy: no Creator Store models, paid assets, private property layouts, proprietary logos, or unverified audio IDs were imported. MVP storm audio uses only Roblox's packaged `rbxasset://sounds` files.

## Implemented world

- Arrival/reception, guest wing, restaurant/lounge, kitchen/service, laundry/maintenance, generator room, covered walkway, and cyclone evacuation gate.
- Ten server-registered hiding locations with capacities from one to three. Every location has a hidden placement point and accessible Listener inspection point.
- Three server-leased physical service doors and eight patrol points.
- Server-generated Listener rig using original primitive geometry.
- Le-Morne-inspired silhouette, storm-facing Indian Ocean, palms, volcanic stone, timber, four-stripe Mauritius flags, bilingual evacuation wording, and explicit Le Morne/Mauritius resort signage.
- Storm grading, emergency lighting, visual rain, low storm wind, thunder-synchronised lightning, and visibility bright enough for mobile navigation.

## Runtime integration

- Responsive round/objective HUD and Shared Silence state/meter.
- Mobile, keyboard, and controller bindings for hide/exit, Let Me In, doors, rescue, decoy, and extraction.
- Server concealment, immobilisation, collision suppression, and safe reveal for hiding avatars.
- Server-observed movement noise with floor-material multipliers.
- Physical door opening bound to an expiring server lease; lease loss closes the door.
- Hold-to-rescue prompt bound to the tested rescue lifecycle and cancellation rules.
- One-use storm-clicker decoy using the same evidence ledger as real noise.
- Forced reveal/ejection at extraction, fixed spectator camera, repeat-round reset, and Roblox-native analytics provider.

## Studio evidence

The following has been exercised through automated Studio sessions rather than inferred from static source:

- Map boot and registry: ten hiding tags, ten inspection points, three doors, one extraction, one Listener, Mauritius flags, Le Morne silhouette, and visual rain present.
- Client startup: the initial snapshot handshake restored active presentation even when the server's first event preceded client HUD subscription.
- Hiding presentation: server concealment attribute set, root immobilised, parts made transparent/non-queryable, nameplate disabled, Shared Silence HUD displayed, and a conflict-free exit binding restored the full character state.
- Hold the Door: an actual prompt created the lease, moved the panel by more than four studs, removed collision, and exposed the release action.
- Extraction/reset: a concealed player was server-revealed and no stale concealment survived the following round.
- Two-client startup: server and two clients joined the same Studio test and advanced out of Lobby.
- Mobile: Samsung Galaxy A06 landscape simulation kept the round HUD in bounds and exposed the contextual decoy touch action without covering the default movement stick.
- Navigation: The Listener moved 25.58 studs during a four-second native-pathing sample on the built map.
- Performance snapshot: Scene Analysis reported 165 Parts, 7,222 opaque triangles, 15 opaque draw calls, and 821 total runtime instances including Roblox/Core UI content. This is a greybox measurement, not a lower-end device frame-time result.
- Roblox analytics calls emitted in Studio logs.
- No HIDE-owned runtime exception was observed; Studio's test clients produced a Roblox CoreScript ChatScript `SetCore` warning unrelated to this repository.

Screenshots and raw bridge output are kept outside the public repository because generated place binaries and machine-local test artifacts are intentionally ignored.

## Remaining validation and risks

- The environment is an intentional gameplay greybox, not production art. Le Morne is a readable stylised silhouette rather than geospatial terrain.
- Multi-client Let Me In and rescue interactions require a stable long-running Studio multi-client session before release acceptance. A later StudioTestService retry launched a dedicated server but failed to attach its requested clients; this bridge failure was ended cleanly and is not counted as gameplay evidence.
- Native pathfinding, doors, stairs/corners, chase persistence, and inspection fairness need longer eight-player soak tests on lower-end mobile hardware.
- MVP sound is limited to Roblox-packaged wind/thunder and default character audio. Bespoke door, hiding, tension, and Listener cues still need an original/licensed upload pipeline before public release.
- Roblox custom-event dashboard delivery cannot be verified until a staging experience is published.
- No production place was published and no Open Cloud credential was created.

## Gate state

This document records the Phase-2 implementation and current Studio evidence. It does not by itself approve publication, merge, or production release.
