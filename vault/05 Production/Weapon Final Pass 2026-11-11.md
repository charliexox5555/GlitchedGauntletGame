# Weapon final pass (2026-11-11)

The owner's ask before skins: a last pass on the 17 guns and the Knife. Aim-down-sights "look odd and not professional ... certain guns are hard to see through"; the charm spot "looks odd"; no glitched or floating parts; the Phantom suppressor's back is invisible and its front sight floats; the Stinger is see-through while aiming; the Operator's rounds show through the magazine; the blue actions should go; and a folder of renders to use as the base when generating skins.

Follows [Weapon RemasterV2](Weapon%20RemasterV2.md). Built in the owner's unsaved Blender session through the MCP bridge (the map file's session was not touched). **Nothing is committed. Save the match place in Studio.**

## What changed

### Sights: one family, every gun its own window
The old rear sights were small thick blocks: the window was about 8% of the screen height at the game's aiming eye. The references (`vault/02 Art/References/ads-refs`) are about 20% with thin walls. Every rear sight is now a thin plate with a big window the eye looks through, sized from the gun's own `adsDistance` and `adsFov`, standing in a base that runs 0.006 into the gun. Low sight lines get an arch: the frame's legs run down into the receiver shoulders and the window's bottom is the gun's top.

| Gun | Rear window | Front |
|---|---|---|
| Vandal | round ring on a stem | AK tower, ears, post with a lit dot |
| Phantom | rounded square on a short neck | post in a box hood, lit dot; its pad now runs into the rail |
| Bulldog | round arch | post in a ring hood, lit dot |
| Guardian | hexagon arch (the carry-handle tunnel is gone) | post between winged guards, lit dot |
| Spectre | octagon arch with two adjuster knobs | post in a ring hood, lit dot |
| Stinger | open-top cradle (two horns) | neon bead |
| Ares | wide slot on a ramp | post, lit dot |
| Odin | tall ladder frame (the slider bar is gone) | post in a box hood, lit dot |
| Sheriff | notch blade, two dots (unchanged) | ramp, neon top |

Kit: `_Library/sights_final.py`. `AimPoint` did not move on any gun, so `adsDistance`, `adsFov` and the hip offsets in `Config/Weapons.luau` are unchanged.

### Why the Stinger was see-through while aiming
`ViewmodelController.findOccluders` casts five rays from the aiming eye to `AimPoint` and hides every part on that line whose name has no "Sight" in it. Parts are merged per material, so the Stinger's front bead put the whole `Neon` mesh on the line: every neon strip vanished while aiming and the pockets under them were open. Sight neon now belongs to the sight part (`Sights_Neon`, `FrontSight_Neon`) on every gun. Checked two ways: `final_pass.sightline(gun)` in Blender, and the game's own rays on the built models in Studio (`tools/studio/AdsSightLine.luau`, new): **the game hides nothing on any of the nine iron-sight guns.** The camera's near plane slices nothing either. The code was not changed.

### See-through and floating parts
Roblox draws faces one-sided, so an open border or a flipped face shows as a hole. New test `_Library/final_geo.py`:
- `backfaces(gun)` renders the gun from 18 directions with back faces painted red and counts patches at least 2 px thick (a 1 px line is two touching or edge-on surfaces, which Roblox never shows).
- `seal(gun)` gives exposed border loops their faces back; `fix_normals(gun)` turns closed islands outward; `snap_floating(gun)` seats islands that stood 0.002 off their surface; `zfight(gun)` lists coplanar overlaps of different materials.

Found and fixed: the Phantom suppressor's open back (seen in first person) and a flipped ring on its muzzle face; a gap in the Outlaw's barrel web; exposed borders on 16 guns (6 to 160 faces each); hovering pieces on Vandal, Phantom, Odin, Shorty and Bucky. **Result: all 18 clean** (no see-through patch in any of the 18 views, nothing floating, no z-fight). The only flag left is the Marshal's loading round, sealed inside the receiver at rest.

### Charm mount
The hanging dog-tag plate (0.07 x 0.10 studs) is replaced on 15 guns by a small screwed plate on the receiver side with a ring under it. `CharmPoint` and the `Charm` bone moved to the ring's inner bottom (the only rig change; every other bone, locator and clip is identical to the last export). Phantom and Spectre moved onto the handguard edge (their old spot hung off a corner). Classic and Shorty keep their studs.

### Colour roles
- **Accent** is bright satin nickel `AEB4BC` (was steel-blue `3C66B8`): charging handles, selectors, releases, belt links. The stock gun is now neutral; the only colour is the neon.
- New role **Glass** `16202C` (Roblox `Glass`) for the three scope lenses, which were Accent.
- Shotgun shells: dark hull, brass head (the hulls were Accent).
- Nine roles now: Body, Panel, Dark, Grip, Metal, Accent, Neon, Brass, Glass (`v2kit.ROLE_SPEC`). A skin is still a role-to-colour or texture swap.

### Operator magazine
The side windows are closed with a recessed ribbed cover and the stack of rounds inside is gone. The round on the feed lips stays (seen when the magazine is out).

## Files
- Models: `art-source/weapons/RemasterV2/<Gun>/<Gun>_RemasterV2_v05.blend` (all 18; older versions untouched).
- Tools: `_Library/final_pass.py` (load, game-eye cameras, sight line, save), `final_edit.py` (in-place edits), `final_geo.py` (the geometry test), `sights_final.py`, `model_sheet.py` + `model_sheet_layout.py`; `tools/blender/export_remaster.py` (background export of one v05 file through the standard exporter); `tools/studio/AdsSightLine.luau`.
- Exports: `art-source/weapons/Exports/<Gun>.fbx/.json`, uploaded as new versions of the same assets. Previous exports, build data and animation modules: `Exports/_pre_finalpass_2026-11-11/`.
- Studio: all 18 rebuilt in `ReplicatedStorage.Weapons` with no missing parts; the previous set is in `ServerStorage.WeaponsBackup_PreFinalPass_2026-11-11`. `src/shared/WeaponAnimations` is byte-identical to before.
- **Model sheets:** `art-source/weapons/ModelSheets/<Gun>_model_sheet.png`, one page per weapon for ChatGPT: turnaround, magazine, round, sights, aim picture, charm mount, the colour roles with hex values. See its `README.md` for a prompt starter.

## Checked
- Blender: the geometry test above, `final_check.audit` on every saved v05 (triangulated, no degenerate faces, UVs in 0-1, role materials only, rig and clips present).
- Studio: validator clean (the Sheriff has no `Eject`, as before); a Play boot shows the new viewmodel with clean Output.
- **Not checked by eye in a playtest:** the sight pictures in a real match, and the charm ring in the inspect clip. Both are for the owner's F6 pass.

## What to test (owner)
1. F6 gun review, aim with each of Vandal, Phantom, Bulldog, Guardian, Spectre, Stinger, Ares, Odin, Sheriff: the window is clear, the lit dot sits on the crosshair, nothing disappears.
2. Phantom from the hip: the suppressor's back is solid and the front sight stands in the rail.
3. Operator: no rounds through the magazine. Shorty and Bucky reloads: dark shells with a brass head.
4. The nickel controls and the new charm ring on a few guns.

## Open
- Triangles over the Art Direction budget: Vandal 5,171 (5K), Outlaw 5,069 (5K), Sheriff 3,066 (3K), Bucky 3,030 (3K). The seals and the charm ring added them.
- `art-source/weapons/Studio/<Id>.rbxm` backups are still the old guns (Studio blocks the local save request).
- The Akimbo is still the old model.

## LihFolk notes used
Looked up after the build to check the decisions (plugin vault 2.5.0):
- *Exporting and Validating Models for Roblox*, *Mesh Optimization for Mobile* (`14 3D Modeling`): inverted or missing faces are invisible from outside; `DoubleSided` is for thin cards only and costs overdraw. So holes were closed with real faces, not `DoubleSided`.
- *Collision and Physics Geometry*, *Parts Unions and MeshParts* (`06 World Building and Art`): `CollisionFidelity` can't be set on a loaded MeshPart from a script. That is why `WeaponBuilder`'s `Box` line does nothing and the guns keep `Default` colliders; the sight-line check in Studio runs against those real colliders.
- *Modeling Weapons and Props*: 20,000 triangles per mesh is the hard cap; the vault has no per-class viewmodel budget, so 3K / 5K / 6K stays our own rule.
- For skins (*Materials MaterialVariants and SurfaceAppearance*, *Flat Colour vs Gradient Atlas vs Vertex Colour*): pick one colour method for the whole set; a `TextureID` wins over `Material`, so clear it; set `Color` to white under a texture; albedo under about 0.06 to 0.085 luminance loses its texture (our Dark and Grip roles are below that).
- Nothing in LihFolk on iron-sight sizing or charm mounts: those follow our own references and measurements.
