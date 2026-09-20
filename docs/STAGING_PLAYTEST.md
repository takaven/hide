# Private staging playtest

## Configuration

Set the workspace attribute `HideEnvironment` to `Staging` in the private/unlisted staging place. Use `Development` for local Studio work. Use `Production` only after the public-release gate; its default policy disables AI fill. Set `HideHumanOnlyTest = true` for a formal human-only staging run; the server derives a cloned AI-off profile without changing IDs or gameplay code. Remove the attribute or set it to `false` to restore the selected environment profile.

Build the exact private-staging place with `rojo build staging.project.json --output build/hide-staging.rbxlx`. The staging project records `HideEnvironment = Staging`, `HideHumanOnlyTest = false`, and the non-secret build label `phase2-staging-1`. Publish that generated place through Studio to the private/unlisted TAKAVEN staging experience. Record the Git SHA separately; do not encode credentials, universe IDs, or place IDs in the project file.

Required future publishing values remain external placeholders: `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`, and `ROBLOX_PLACE_ID`. Do not commit them.

## Cohort and session protocol

Invite 8–20 friends to the private/unlisted experience. Ask each tester to play several rounds before feedback. Do not combine AI activity with human engagement in analysis; use `participantKind` and the environment profile.

- Session A — AI-assisted: 1–2 humans, `HideHumanOnlyTest = false`, AI fill on.
- Session B — human-heavy: 4 humans, `HideHumanOnlyTest = true`, AI fill off.
- Session C — target: 8 humans, `HideHumanOnlyTest = true`, AI fill off.

Review unique humans, sessions, human rounds/session, first-round onboarding progression, rematch requests/starts, invite CTA shown/initiated/friend co-play, Let Me In requests and decisions, shared hiding and silence breaks, heat inspections, captures, rescues, door holds, highlights, near misses, extraction/escape, quits by phase/state, and client FPS/performance.

## Feedback questions

After several rounds, ask:

1. Was it clear what to do?
2. Was The Listener too easy, too hard, or fair?
3. Was hiding tense?
4. Did you use Let Me In?
5. Did anything make you laugh?
6. Did anything feel unfair?
7. Did Mauritius feel recognisable?
8. Would you play another round?
9. Would you invite a friend?
10. What was the most memorable moment?

## Marketing capture recipe

Record actual gameplay from a clean client viewport with developer panels, selection outlines, bridge UI, and cursor hidden. Use only packaged/licensed-safe audio.

- Vertical trailer target: 1080×1920, 20–30 seconds. Establish Mauritius/Le Morne/flag and HIDE!, then scramble, Let Me In, HOT suspicion, Listener/peek, blackout, door/rescue/chase, extraction, and `HIDE! by TAKAVEN — WOULD YOU LET THEM IN?`.
- Raw gameplay target: 1920×1080, 60–90 seconds. Preserve an uninterrupted sequence containing movement, one hiding interaction, Shared Silence/heat, one cooperation action, Listener pressure, and extraction.
- Capture from the same Rojo-built SHA reported with the files. Record duration, resolution, source SHA, and any missing beat. A slideshow or synthetic render is not acceptable evidence of gameplay.

### Repeatable capture sequence

For the native 29-second trailer, open a clean play client, enable the repository's `EnableMarketingCapture` attribute, and set `MarketingCaptureCommand` to `Trailer`. The Studio-only controller hides the ordinary HUD, switches to a scripted cinematic camera, and automatically moves through Le Morne/flag, the scramble, Let Me In, HOT suspicion, peek/Listener pressure, blackout, door cooperation, extraction, and the end card before stopping capture and restoring the player camera. Approve Roblox's capture-gallery permission and save the MP4. Target output is 1080×1920 (9:16), H.264 MP4.

Roblox's native recorder cannot produce the required uninterrupted 60–90-second clip. For raw gameplay, start OBS display/game capture at 1920×1080 and 30 or 60 fps, press Record once, run one uninterrupted prepared round containing movement, hiding, Shared Silence/heat, cooperation, Listener pressure, and extraction, then press Stop. Export H.264 MP4 with game audio only. No commercial music or external animation is permitted.

### Visual-remediation OBS route

Record one uninterrupted comparison route with the ordinary gameplay camera and HUD:

1. Begin in the normal lobby. Hold on the reception feature wall, warm practicals, Le Morne signage, and exterior storm view.
2. Walk through the primary guest shelter corridor. Show suite wayfinding, exits, Breath placement, and warm/cool separation.
3. Trigger or stage The Stop in the Listener encounter space. Keep both shelter context and Listener silhouette visible without a spotlight.
4. Cross the pool/exterior route. Frame wet ground, pool response, flags or planting, and the cool storm background against a warm resort edge light.
5. Enter blackout and continue to the fuse. Show main practicals switching off, emergency/navigation lights remaining, readable movement to the fuse, and intermittent lightning if it occurs.

Capture the same route at desktop/standard phone, Galaxy A06 emulation, and tablet. The acceptance gate is visual: shelter exits, Listener, Breath, fuse, and blackout navigation must remain readable, while blackout must still be an unmistakable contrast event.

### One-key Studio QA runner

Build and open `capture.project.json`, then start a normal solo Play session. The dedicated capture place enables `EnableQACaptureRunner`; default and staging projects do not. When **READY TO RECORD — PRESS F8 TO START** appears, begin OBS recording and press F8 once. The runner waits three seconds, then drives the establishing view, lobby, shelter corridor, real occupied-shelter Listener Stop, visible Breath pressure, pool/exterior, real blackout, automatic fuse completion through the production completion handler, and a real visual-acquisition chase. It restores the player and shows **CAPTURE COMPLETE** after approximately 53 seconds.

The runner disables Roblox CoreGui during the take but keeps `HideHUD` and all real player-facing gameplay presentation active. It does not start or save a native Roblox recording. OBS remains founder-controlled, and Studio dock widgets such as BloxForge must be outside the captured game source or closed before recording. Capture controls are created only when both `RunService:IsStudio()` and the capture-project attribute are true.

On the current validation host the native recorder started successfully and saved a genuine 29.112-second, 1936×1088 runtime MP4 after the founder clicked **Save** and **Allow**. File integrity and metadata passed, but visual QA rejected the clip because the 3D viewport rendered blank white while CoreGui and the repository's cue overlays remained visible. The file is preserved as capture-pipeline evidence, not as shareable marketing footage. Roblox's recorder also ignored the portrait device simulation and encoded landscape. A clean Studio restart plus one OBS Record/Stop pair is the reliable remaining capture path; use the prepared sequence above and reject any take with a blank viewport or developer UI.

## Local tooling limitation

StudioTestService successfully ran the 1-human + 3-AI case. Controlled 2-human and 4-human retries created the server role but no connected client roles or players before timeout. Source reconciliation tests still cover 1→3, 2→2, 3→1, and 4→0 AI fill. Treat the missing scenarios as **LOCAL TOOLING LIMITATION — TO BE VALIDATED IN PRIVATE STAGING**, not as evidence that they passed.
