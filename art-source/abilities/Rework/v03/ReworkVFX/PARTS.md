# ReworkVFX parts

Built by `vfx_kit.py` (live Blender MCP, scene `RW_VFX`, collection `ReworkVFX`) to the mesh list in [Ability VFX Direction](../../../../../vault/02%20Art/Ability%20VFX%20Direction.md). Export: `../Exports/ReworkVFX.fbx` + `.json` (prefix `ReworkVFX_` stripped). Longest side 1 stud; code scales in studs. Roblox size = Blender (x, y, z) -> (y, z, x).

Double-sided pieces are single open sheets (or the one-surface shell) with `fx_doubleSided = True`: set `MeshPart.DoubleSided` in Studio. Their triangle count here is one side; the note's budget counts both sides.

| Mesh | Element | Anchor | Size Blender (x y z) | Size Roblox (x y z) | Tris | Note budget | Double-sided |
|---|---|---|---|---|---|---|---|
| `FX_Stroke` | Wind, strips, bolt | Head tip (+X end), tail to -X | 1.000 x 0.080 x 0.045 | 0.080 x 0.045 x 1.000 | 8 | 12 | no |
| `FX_Ring` | Footprints, gust, impact | Centre, floor plane | 1.000 x 1.000 x 0.000 | 1.000 x 0.000 x 1.000 | 40 | 64 | yes |
| `FX_FloorStar` | Ice front, impact crack | Centre, floor plane | 1.000 x 0.860 x 0.000 | 0.860 x 0.000 x 1.000 | 22 | 40 | yes |
| `Fire_TongueA` | Fire | Base centre | 0.809 x 0.149 x 1.000 | 0.149 x 1.000 x 0.809 | 30 | 28 | no |
| `Fire_TongueB` | Fire | Base centre | 0.822 x 0.160 x 1.000 | 0.160 x 1.000 x 0.822 | 26 | 24 | no |
| `Fire_TongueC` | Fire | Base centre | 0.943 x 0.231 x 1.000 | 0.231 x 1.000 x 0.943 | 14 | 14 | no |
| `Ice_PlateA` | Ice | Base centre | 0.459 x 0.277 x 1.000 | 0.277 x 1.000 x 0.459 | 28 | 28 | no |
| `Ice_PlateB` | Ice | Base centre | 0.984 x 0.163 x 1.000 | 0.163 x 1.000 x 0.984 | 24 | 24 | no |
| `Ice_PlateC` | Ice, shards, hand | Base centre | 0.208 x 0.135 x 1.000 | 0.135 x 1.000 x 0.208 | 10 | 12 | no |
| `Ice_Cap` | Ice | Base centre | 1.000 x 0.923 x 0.293 | 0.923 x 0.293 x 1.000 | 20 | 20 | no |
| `Heal_Leaf` | Healing | Base tip, grows +Z | 0.390 x 0.070 x 1.000 | 0.070 x 1.000 x 0.390 | 4 | 8 | yes |
| `Heal_Crown` | Healing | Centre, floor plane | 1.000 x 1.000 x 0.076 | 1.000 x 0.076 x 1.000 | 48 | 96 | yes |
| `Stim_Chevron` | Stim | Centre, faces +X | 0.000 x 1.000 x 0.460 | 1.000 x 0.460 x 0.000 | 5 | 12 | yes |
| `Tele_Fold` | Teleport | Centre, faces +X | 0.000 x 0.640 x 1.000 | 0.640 x 1.000 x 0.000 | 4 | 8 | yes |
| `Tele_Ring` | Teleport | Centre, flat (XY) | 1.000 x 1.000 x 0.000 | 1.000 x 0.000 x 1.000 | 20 | 48 | yes |
| `Scan_Shell` | Scan | Centre | 1.000 x 1.000 x 1.000 | 1.000 x 1.000 x 1.000 | 80 | 160 | yes |
| `Impact_ChunkA` | Impact | Base centre | 1.000 x 0.863 x 0.526 | 0.863 x 0.526 x 1.000 | 16 | 16 | no |
| `Impact_ChunkB` | Impact | Base centre | 1.000 x 0.674 x 0.444 | 0.674 x 0.444 x 1.000 | 12 | 12 | no |
| `Shield_Plate` | Shield | Centre, faces +X | 0.000 x 0.866 x 1.000 | 0.866 x 1.000 x 0.000 | 4 | 8 | yes |
| **Total** | | | | | **415** | 634 | |

## Audit (`rw_audit("ReworkVFX_")`)

- objects 19, tris 415
- style: none
- open_edges (open sheets only): ReworkVFX_FX_FloorStar: 24, ReworkVFX_FX_Ring: 48, ReworkVFX_Heal_Crown: 48, ReworkVFX_Heal_Leaf: 6, ReworkVFX_Shield_Plate: 6, ReworkVFX_Stim_Chevron: 7, ReworkVFX_Tele_Fold: 6, ReworkVFX_Tele_Ring: 24
- overlap / coplanar / floating: ignored (every kit mesh sits at the origin; 121 / 27 / 0 listed)

Texture made here: `../Textures/T_FlameSheet.png` (1024 px, 4x4, frame 1 top left, RGBA: three flat greys on transparent; tongue A dark at the back, B mid, C light in front; each tongue grows and curls, then its tip breaks off and rises).

Renders: `../Renders/VFX_kit_sheet.jpg`, `../Renders/VFX_kit_silhouette.jpg`.
