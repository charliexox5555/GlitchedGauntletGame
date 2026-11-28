# Mod props: Smoke and Electric Shock (2026-11-27)

Blender models for the two battle pass powers (Smoke: free tier 10; Electric Shock: premium tier 20) and their VFX mesh kits. Built in a separate Blender bridge (port 9882) on the `rw_core` kit (`tools/blender/rework/rw_core.py`) with its work folder pointed at `art-source/abilities`, so the exports sit next to the other Mods. Not yet in Studio: the main session builds them into `ReplicatedStorage.Abilities` with the AbilityBuilder (README steps 2–7).

## Files
| Model | Build script | Source (latest + versions) | Export | Asset id (Model, group 11116787) | Tris |
|---|---|---|---|---|---|
| `Smoke` | `tools/blender/build_mod_smoke.py` | `art-source/abilities/Smoke/Smoke.blend` (+ `_v01`, `_v02`) | `Exports/Smoke.fbx/.json` | 136650199866066 | 890 |
| `ElectricShock` | `tools/blender/build_mod_electricshock.py` | `art-source/abilities/ElectricShock/ElectricShock.blend` (+ `_v01`, `_v02`) | `Exports/ElectricShock.fbx/.json` | 125616995746265 | 696 |
| `SmokeVFX` | `tools/blender/build_mod_smokevfx.py` | `art-source/abilities/SmokeVFX/SmokeVFX.blend` (+ `_v01`) | `Exports/SmokeVFX.fbx/.json` | 74689281543379 | 204 |
| `ShockVFX` | `tools/blender/build_mod_shockvfx.py` | `art-source/abilities/ShockVFX/ShockVFX.blend` (+ `_v01`) | `Exports/ShockVFX.fbx/.json` | 101353952165026 | 496 |

Build data: `tools/studio/abilities/BuildData/{Smoke,ElectricShock,SmokeVFX,ShockVFX}.json` (`make_ability_build_data.py`: HoldOffset for the two props, `Dome` DoubleSided). Icon references for the ChatGPT icons: `art-source/abilities/Icons/ref_Smoke.png`, `ref_ElectricShock.png` (512², transparent, 3/4 view). Review renders: `vault/02 Art/References/mods/smoke_v02_*.jpg`, `electricshock_v02_*.jpg`, `smokevfx_v01_*.jpg`, `shockvfx_v01_*.jpg`.

## Smoke (thrown, origin = centre, 0.30 × 0.30 × 0.63)
A squat 8-facet smoke canister: matte charcoal body, a pale-grey label band (reads as smoke, not fire), two rubber grip rings, a chamfered shoulder up to a steel cap with four vent slots over a dark vent plate, a fuse collar and striker, a spoon lever down the +X side, and a pull pin and ring on the +Y side.
- **Parts:** `Foot`, `Body`, `Label`, `Grip0`, `Grip1`, `Band_Energy` (team light), `VentPlate`, `Cap`, `Fuse`, `Striker`, `Lever`, `PinLug`, `Pin` (pin and ring in one part: flies off on the throw).
- **Locators:** `Handle` (centre; the builder adds `RightGrip`), `Vent` (top of the cap, +Z: where the smoke pours out). HoldOffset 0, 0.32, −0.12 (like the Frost).
- **Versions:** v01 (lever ended in a blunt square foot; one coplanar face where the lever hook met the fuse); v02 carved, angled lever foot tucked into the grip ring, hook buried deeper. Audit v02: 0 overlaps outside declared seats, 0 coplanar, 0 floating, 0 open edges, no smooth faces.

## Electric Shock (thrown, origin = centre, 0.32 × 0.31 × 0.39)
A caged core: two chamfered octagon caps joined by six bowed ribs (three straight segments each), all unioned into one `Cage`; a dark `Belt` ring ties the ribs below the equator; a faceted `Core_Energy` crystal inside; three tapered steel `Prongs` under the bottom cap (it latches on); a small `Node` on top.
- **Parts:** `Cage`, `Belt`, `Core_Energy` (team light), `Node`, `Prongs`.
- **Locators:** `Handle` (centre; the builder adds `RightGrip`), `Zap` (the core centre: start the strike's arcs here). HoldOffset 0, 0.28, −0.12.
- **Versions:** v01 (the belt at the equator hid the core's widest facets); v02 belt lowered under the equator so the core reads. Audit v02 clean.

## SmokeVFX (kind "vfx", every part on the origin)
- `Puff1` (round), `Puff2` (long), `Puff3` (flat): faceted convex cloud lumps about 1 stud across (35–43 faces each), centred on the origin.
- `Dome`: faceted hemisphere shell, radius 1, 48 faces, open bottom, normals out, floor centre at the origin (its box is 2 × 1 × 2, so a MeshPart's CFrame sits 0.5 above the floor). DoubleSided (seen from inside). Its 12 open edges are the open bottom, on purpose.
- The colour in the file is a review grey (`FxSmoke` #8E949C): code colours, scales and fades them.

## ShockVFX (kind "vfx", every part on the origin)
- `Ring`: the warning ring, a flat faceted band (outer radius 1, inner 0.86, 0.04 thick, 20 facets), flat on Blender XY = Roblox XZ, centred on the origin.
- `Bolt`: a jagged faceted lightning bolt, 1 stud tall along Blender +Z = Roblox +Y, base at the origin (box centre 0.5 up), six kinks and one short fork, tapering from 0.05 to a point. Scale Y for the strike height.
- Review colour `FxShock` #CFEBFF Neon; code colours them.

## Grade (build style, lowest area counts)
| Area | Smoke | Electric Shock | VFX kits |
|---|---|---|---|
| Silhouette | 9: reads as a smoke can at a glance | 9: caged core + claws, unlike every other prop | 9 |
| Crispness (facets, no smooth) | 9 | 9 | 9 |
| Joins (seated, unioned, nothing floating) | 9 | 9 (cage unioned) | 9 (bolt unioned) |
| Ends (no blunt cut-offs) | 9 (v02 lever foot) | 9 | 9 |
| Palette (shared roles, team light only on `*_Energy`) | 9 | 9 | n/a |
| Budget | 890 tris | 696 tris | 204 / 496 |
| **Grade** | **9** | **9** | **9** |
