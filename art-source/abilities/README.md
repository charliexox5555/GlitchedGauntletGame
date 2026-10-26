# Mod props: build into Studio

Models for the Mods (approved 2026-10-26), uploaded to Open Cloud, ready to build into the Studio-owned
**`ReplicatedStorage.Abilities`**. The design and parts list is in [Mod Props](../../vault/02%20Art/Mod%20Props.md).
The `Icons/` folder belongs to the icon pipeline (`tools/icons/`), not to these models.

## What is where
| Path | What |
|---|---|
| `<Mod>/<Mod>.blend`, `VFX/ModVFX.blend` | Blender sources, rebuilt by `tools/blender/build_mod_<name>.py` (never edit by hand) |
| `Exports/<Mod>.fbx`, `<Mod>.json` | Export (`tools/blender/export_mods.py`): meshes, parts, locators |
| `Exports/assets.json` | Open Cloud model asset ids (group 11116787) |
| `Exports/textures.json` | Decal ids (the Firewall grid) |
| `Textures/FirewallGrid.png` | The grid texture (`tools/vfx/make_mod_textures.py`) |
| `Studio/<Mod>.rbxm` | Backups of the built models (written by the build; empty until then) |
| `tools/studio/abilities/` | `AbilityBuilder.luau` + `BuildData/<Mod>.json` (`tools/studio/make_ability_build_data.py`) |

## Asset ids (uploaded 2026-10-26, group 11116787)
| Model id | Asset | Kind |
|---|---|---|
| `PatchUp` | 113169378873162 | handheld (viewmodel item) |
| `Packet` | 137524485912802 | thrown |
| `LaunchPad` | 82834892217235 | placed |
| `Firewall` | 91482638324310 | placed |
| `LagField` | 134077650766119 | thrown |
| `ModVFX` | 130699290674585 | VFX meshes (4 parts) |
| Firewall grid decal | 74639457803541 (Decal; the builder looks up its image) | texture |

## Build steps (code session, Stage 3)
1. In a terminal at the repo root: `python tools/studio/make_ability_build_data.py` (already run; only needed after a re-export).
2. Copy `tools/studio/abilities/` to `src/server/AbilityBuild/` (temporary and gitignored; the server bootstrap only loads `Services/`, so it stays inert). Rojo syncs it to `ServerScriptService.Server.AbilityBuild`.
3. For the `.rbxm` backups: `python tools/studio/receive_server.py` (listens on 127.0.0.1:34999; Studio needs HTTP requests allowed).
4. Make sure `ServerStorage.ImportStaging` exists. In Studio (Command Bar, edit mode, not playing):
   ```lua
   local B = require(game.ServerScriptService.Server.AbilityBuild.AbilityBuilder)
   print(table.concat(B.publishAll(), "\n"))
   ```
   For each Mod it inserts the upload as `ImportStaging.Raw_<Id>`, builds `ImportStaging.<Id>`, installs a copy as `ReplicatedStorage.Abilities.<Id>` and saves `art-source/abilities/Studio/<Id>.rbxm`. `B.publish("Firewall")` does one.
5. Check every model: no `MissingParts` attribute (a mesh name the upload didn't have); if a model has `SetDoubleSidedByHand`, tick `DoubleSided` in Properties on those parts. Look at them side by side with the renders in `vault/02 Art/References/mods/` (the forward direction is -Z; if the meshes come out turned, rebuild with `B.publish(id)` after setting `B.DEFAULT_AXES` to `"I"`, `"X"` or `"Z"`, as the guns needed `"Y"`).
6. **Save the place.** Delete `src/server/AbilityBuild/` and the `Raw_*` and staged models in `ImportStaging`.
7. Tick the row in `vault/06 Assets/Asset Tracker.md` and commit the `.rbxm` backups.

To restore by hand: right-click `ReplicatedStorage.Abilities` → **Insert from File** → `art-source/abilities/Studio/<Id>.rbxm`.

## The built models (names the code should use)
Every Model: `PrimaryPart = Root` (invisible 0.2 part, pivot at the Blender origin, `WorldPivot` = identity), forward = **-Z**, up = +Y, 1 stud = 1 Blender unit. Attributes `AbilityId`, `Kind`, `SourceAsset`, `Tris`. Every part is **Anchored**, `CanCollide`/`CanQuery`/`CanTouch` off, `Massless`, and welded to `Root` with a classic `Weld` (unanchor `Root` if you ever want physics). Shadows only on the solid parts of placed props. Shell parts are SmoothPlastic / Metal in fixed colours.

**Energy parts:** every part named **`*_Energy`** is Neon in the ally colour (`#00E5FF`) with the attribute **`Energy = true`**. Recolour them per viewer (`ModProps.get` already recolours Neon parts). The Firewall panel also has two Decals, **`GridFront`** / **`GridBack`**: set their `Color3` to the same colour.

**Attachments** (all on `Root`, axis-aligned with the model):
| Model | Pivot | Attachments | Parts that move or are driven by code |
|---|---|---|---|
| `PatchUp` | the grip | `Handle` + `RightGrip` (grip), `LeftGrip` (pistol support hand), **`Emitter`** (front of the core; its LookVector is forward: start the heal beam here) | `Core_Energy`, `Vial_Energy` (charge read-out), `Cross_Energy` |
| `Packet` | the centre | `Handle` + `RightGrip`, **`Fuse`** (top of the fuse light) | **`Fuse_Energy`** (blink it before the blast), `Windows_Energy`, `Lever` and `Pin` (fly off on the throw); `HoldOffset` attribute like the placeholder |
| `LaunchPad` | floor centre (launch direction -Z) | **`Top`** (plate centre: launch burst, stand point) | `Plate` (pop it up on a launch), **`Arrow1_Energy`, `Arrow2_Energy`, `Arrow3_Energy`** (back to front: chase them), `Rim_Energy`, `Side_Energy` |
| `Firewall` | floor centre (faces -Z; spans X -4..4, 6 tall) | **`Center`** (middle of the panel: hits, shatter) | **`Panel_Energy`** (build-up, hit flicker, shatter), `Frame_Energy` |
| `LagField` | the centre | `Handle` + `RightGrip` | **`Spinner_Energy`** (spin it about the model's Y axis while the zone is up), `Core_Energy`; `HoldOffset` attribute |
| `ModVFX` | each mesh at the origin | none | `Shockwave_Energy` (flat ring r 0.7 → 1), `Dome_Energy` (hemisphere r 1), `Sphere_Energy` (r 1), `ScanRing_Energy` (vertical band r 1, 0.25 tall): clone and scale; U wraps around, V runs along the effect |

**Firewall panel standard (handler, 2026-10-26):** L1 blocks bullets, **not vision**, so the panel is see-through: Neon at **Transparency 0.5** with the tinted grid Decals reading on top (white lines and a glowing rim on transparent, `FirewallGrid.png`). It is `CanQuery = false` in the template: the server's bullet blocking should use its own hitbox, not this mesh. B2 Burn Wall is the variant that blocks vision (make it opaque in code, not a separate model).

## Rebuilding after a model change
`blender --background --factory-startup --python tools/blender/build_mod_<name>.py -- --render` → `blender --background --factory-startup --python tools/blender/export_mods.py -- <Mod>` → `python tools/opencloud/upload_models.py --abilities --group 11116787 <Mod>` (adds a new version to the same asset) → `python tools/studio/make_ability_build_data.py <Mod>` → steps 2–7 above.
