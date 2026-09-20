# Vertical Slice Asset Audit

## Listener foundation decision

The vertical slice retains an original, source-built TAKAVEN rig. No Creator Store model,
script, mesh, texture, animation, or audio was copied into the production build.

| Candidate | Creator / ID | Finding | Decision |
| --- | --- | --- | --- |
| Six-Seven Monster | `@roachRoblox8` / `80887480776940` | Recognisable meme/analog-horror identity; five scripts; high IP and backdoor-review burden. | Reject |
| R6 Dummy Template Rig | `@acere4l` / `74277992167275` | Generic avatar silhouette, one script and one decal; adds no HIDE! identity. | Reject |
| R6 Rig | `@Paficent` / `9983142905` | Common community dummy; visually generic and unnecessary because Studio provides rig generation. | Reject |
| Roblox Rig Generator | Roblox Studio built-in | Trusted rigging reference, but a standard avatar silhouette would read as temporary. | Pattern only |
| Existing HIDE! procedural rig | TAKAVEN / repository source | No external scripts, loaders, meshes, textures, or permissions; can be made distinctive and kept in Git. | Selected |

The selected rig is articulated with source-authored `Motor6D` joints. Its faceless slate veil,
elongated wet limbs, listening fins, posture language, and procedural state poses are original to
HIDE!. The build does not call external `require()` functions or load third-party character code.

## Audio provenance

The slice uses only Roblox-packaged engine sounds under `rbxasset://sounds/`, transformed at
runtime with pitch, equalisation, layering, roll-off, and reverb. No Creator Store audio, film/game
sample, commercial music, or separately licensed recording is included. The treatment is an
interim safe vertical-slice language; bespoke TAKAVEN recordings remain preferable before public
release.

## Security procedure for future imports

Any later Creator Store candidate must be inserted into an isolated inspection place, have every
script disabled and reviewed, reject external loader calls, and record its creator, asset ID,
dependency permissions, and licence before any geometry is harvested.
