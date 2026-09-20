# HIDE! by TAKAVEN

HIDE! is a social panic survival game for Roblox. Survivors share hiding places whose danger rises with occupancy, movement, door actions, and accumulated attention. The Listener hunts evidence rather than receiving hidden player locations.

The current Phase-2 branch turns the approved source foundation into a source-generated Roblox Studio MVP: one fictional Le Morne resort greybox, server-owned physical interactions, The Listener, responsive mobile HUD, storm presentation, and Roblox-native telemetry. It intentionally contains no economy, persistence, paid assets, or second map.

## Core thesis

> Every additional person in a safe space makes everyone less safe.

The MVP validates three decisions:

- **Shared Silence:** crowded hiding places become noisy and unstable.
- **Let Me In:** occupants decide whether to accept a survivor at personal risk.
- **Hold the Door:** a survivor can remain exposed to help someone else transition.

## Toolchain

The repository pins Rojo, Rokit, Wally, Selene, StyLua, Lune, and luau-lsp in `rokit.toml`. No runtime package is required for the Phase-1 foundation.

```sh
rokit install
wally install
stylua --check src tests scripts
selene src tests scripts
lune run tests/run.luau
rojo sourcemap default.project.json --output sourcemap.json
# download luau-lsp 1.69.0 globalTypes.d.luau to build/globalTypes.d.luau
luau-lsp analyze --definitions=build/globalTypes.d.luau --sourcemap=sourcemap.json src/shared src/server/domain
lune run scripts/validate-structure.luau
rojo build default.project.json -o build/hide.rbxlx
```

To format locally, run `stylua src tests scripts`.

## Source layout

```text
src/client/             mobile-first client presentation and input
src/server/domain/      deterministic server-owned gameplay rules
src/server/runtime/     Roblox service adapters and remote boundary
src/shared/             configuration, contracts, and shared types
tests/                  Lune unit and adversarial tests
docs/                   architecture, gameplay, security, audit, handoff
```

## Roblox Studio workflow

GitHub remains the source of truth. Rojo builds the place from this repository; `WorldBuilder` deterministically creates the tagged resort at server start before `WorldRegistry` binds gameplay. Studio is used for runtime validation, screenshots, and multiplayer tests—not for hidden gameplay scripts. See `docs/PHASE2_BUILD.md` for the current evidence and remaining limitations.

## Status

Phase 1 was merged to `main`. Phase 2 is under active review on `phase-2/mauritius-playable`; it is playable in Studio but has not been published to Roblox production.

## License

Original HIDE! source code is MIT licensed. No third-party gameplay code is included. See `THIRD_PARTY_NOTICES.md` and `docs/OPEN_SOURCE_REUSE.md`.
