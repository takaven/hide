# HIDE! by TAKAVEN

HIDE! is a social panic survival game for Roblox. Survivors share hiding places whose danger rises with occupancy, movement, door actions, and accumulated attention. The Listener hunts evidence rather than receiving hidden player locations.

Phase 1 is a source-first technical MVP. It contains deterministic gameplay domains, server-authoritative runtime boundaries, mobile-friendly interaction contracts, tests, and a Rojo build. It intentionally contains no finished map, art, production place, economy, or persistence.

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

## Roblox Studio boundary

GitHub is the source of truth. Phase 2 may sync this repository into Studio with Rojo and construct tagged world instances, but it must not replace the source modules with Studio-only logic. See `docs/PHASE1_HANDOFF.md` for the exact Studio-dependent work.

## Status

Phase 1 is prepared on `phase-1/core-foundation` and is not a playable production experience until the documented Studio bindings and map are completed in Phase 2.

## License

Original HIDE! source code is MIT licensed. No third-party gameplay code is included. See `THIRD_PARTY_NOTICES.md` and `docs/OPEN_SOURCE_REUSE.md`.
