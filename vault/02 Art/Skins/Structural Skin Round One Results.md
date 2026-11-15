# Structural skin round one: results (Blender)

**2026-11-14 overnight (Claude).** The owner approved the Moltframe v04 direction, asked for a much higher grade, then for every line and item in the [round-one handoff](Structural%20Skin%20Round%20One%20Handoff.md) to be finished and graded, **Blender only, Studio later**. All **36** queued items are built, checked and saved. Nothing is installed in Studio or committed to Git as binary art yet.

## Grades (round-one rubric, evidence only)

The rubric: look 30, fit 25, ADS/animation 20, craft 15, evidence 10. **Blender-scope** leaves out the 6 points that only a Studio pass can earn (live ADS and hand contact 4, Studio texture load 1, Studio captures 1) and scales the rest to 100. Per-item reasons are in each line's ledger.

| Line | Items (grade full / Blender-scope) | Ledger |
| --- | --- | --- |
| Moltframe | Vandal **v05** 89/95 · Spectre 88/94 · Ares 87/93 · Dagger 86/92 | [ledger](Moltframe/Build%20Ledger.md) |
| Slipframe | Guardian 89/95 · Operator 89/95 · Classic 88/94 · Spectre 88/94 · Vandal 88/94 · Dagger 87/93 | [ledger](Slipframe/Build%20Ledger.md) |
| Giltfold | Vandal 87/93 · Marshal 86/91 · Stinger 87/93 · Ghost 86/91 · Classic 86/91 · Fan 84/89 | [ledger](Giltfold/Build%20Ledger.md) |
| Inkshift | Odin 87/93 · Phantom 87/93 · Vandal 87/93 · Stinger 86/91 · Shorty 87/93 · Blade 85/90 | [ledger](Inkshift/Build%20Ledger.md) |
| Sealwork | Marshal 86/91 · Vandal 86/91 · Guardian 85/90 · Shorty 86/91 · Sheriff 83/88 · Dagger 84/89 | [ledger](Sealwork/Build%20Ledger.md) |
| Payload | Bulldog 87/93 · Ghost 86/91 · Vandal 87/93 · Operator 86/91 · Ares 85/90 · Odin 86/91 · Classic 86/91 · Stinger 86/91 | [ledger](Payload/Build%20Ledger.md) |

Honest reading: the two lines built as full new shells (Moltframe, Slipframe) score highest. The four lines built as plates over the stock geometry (Giltfold, Inkshift, Sealwork, Payload) score a few points lower on look: they read clearly at gameplay size, but the stock silhouette and channel bands carry more of the shape. **None reaches 90 on the full rubric until the Studio pass earns its 6 points**; on the Blender-scope grade every gun is 88-95.

## What every item passed in Blender

- **Moving parts:** 0 new intersections between the skin parts and every animated stock part (charging handles, bolts, triggers, selectors, bolt catches, slides, hammers, levers, shells, break-open barrels, latches, cylinders, magazines, the Odin feed cover, belt and ammo box) over Fire, Inspect, Reload and ReloadEmpty. Movers are found automatically from the rig. One exception sits in the stock clip itself: the Sheriff's Reload drives the speedloader and rounds through the stock frame and grip. The Sealwork seal band still crosses that path in 13 frames, flagged in its ledger.
- **Fit:** stock grip, AimPoint, LeftGrip, Muzzle, Eject and magazine pivots unchanged; widths at stock or within about 6% (exceptions per ledger); sight pictures rendered from the stock AimPoint (the Classic and Ghost have none in their stock files, so the review uses a rear-notch-height aim point).
- **Geometry for Studio:** flat-shaded, mirrored where the brief allows, no smoothing, no modifiers, nothing new floating, no open edges on the new shells. Failed booleans now roll themselves back (`cut()` in `tools/blender/model_moltframe_vandal_v04.py`). Each item exports a Roblox FBX: one Body mesh and one Chamber mesh per bone, triangulated, degenerate triangles removed, UVs inside 0-1. Every mesh is far under the 20k-triangle MeshPart limit (the largest, the Moltframe Vandal body, is 6,280).
- **Maps:** each item has a 1024 atlas (colour with baked AO, roughness, metalness) and a chamber map. The bake routes base colour and metal through Emission, since Cycles' diffuse pass is black on metal, and keeps the buffers linear to avoid double sRGB.


## Round two (2026-11-14): full sculpts, owner-checked Vandals

The owner rejected the four plate lines (Giltfold, Inkshift, Sealwork, Payload) as reskins and asked for the Moltframe full-sculpt vibe at the quality of each line's Valorant reference (original designs), checked one Vandal at a time, then carried through each line.

| Item | Version | Grade (full / Blender-scope) | Owner check |
| --- | --- | --- | --- |
| Giltfold Vandal | v02 (origami shell) | 87 / 92 | approved ("passable", round trim added after) |
| Sealwork Vandal | v02 (black jade, gold talons, looped stock) | 87 / 92 | approved |
| Payload Vandal | v02 (flight hardware: foil pillow, quilted magazine, carbon) | 87 / 92 | approved |
| Inkshift Vandal | v02 (comic mecha, inverted-hull ink outlines) | 87 / 92 | built while the owner was away; owner asked for intricate anime pop art |
| Sealwork Dagger | v02 (Ruin-style talon blade, gem pommel) | 86 / 91 | — |

**Method.** `tools/blender/model_vandal_shell_base.py` hides the stock Vandal body and keeps the fit: receiver core with the magazine well and trigger slot, the open charging / ejection channel, stock barrel, sights and moving parts, trigger guard, magazine catch, the magazine's feed lips and top round, plus a magwell collar. Any-gun helpers rebuild stock body parts from their own side outlines (`hull_solid`, `vandal_grip_outline` seats grips into the receiver), cut outlines into bands (`clip_poly`), seat trim lines on surfaces (`inlay_line`) and swap kept-part finishes (`gun_set_skin_factory`). Every build runs the clearance check (every moving part and the magazine over Fire, Inspect, Reload, ReloadEmpty and any extra clips) and a floating-part check before it is shown.

**Lessons from the owner checks.** Flat glossy faces mirror the bright review sky and read hollow or see-through (grips are matte, jewels satin); grips must seat into the receiver (an earlier outline helper folded over itself and left holes); stock struts must start inside the part they join; grip texture never crosses an edge; magazine joints get a collar; ink outlines only on outward faces so they never bulge into channels.

### Studio pass plan for round two (ready, not run)

Studio is connected (match place 133387545285290, Edit) and the Open Cloud key is set, but the pass changes the live game, so it waits for the owner.
1. **Code:** add `line` to `tools/studio/InstallMoltframeSkin.luau` (folder `WeaponSkins/<Line>`, attribute `SkinLine`, waypoint name; today it is hard-wired to Moltframe) and add Giltfold, Inkshift, Sealwork, Payload (and Slipframe) to `Config/SkinPreview.LINES`; selene and the roblox-reviewer pass.
2. **Per item uploads** (`tools/opencloud/upload_asset.py --group 11116787`): `textures/<Item>_Atlas_{Color,Rough,Metal}.png` and `<Item>_Chamber_Color.png` as Decals, the line's solid finish for kept stock parts (one 4x4 colour / rough / metal set per line, still to make), and `<Item>_<Line>_Roblox.fbx` as a Model. Ids land in `art-source/uploads.json`.
3. **Install** with the manifest's `roblox_parts` and `replaced_stock_prefixes`, then the owner saves the place.
4. **Checks:** live ADS on every sight and optic, hands on grips and handguards (left-hand contact on the rebuilt handguards), reload / inspect with the arms, texture load, Inkshift ink outline thickness (`INK_T`) read in game, the long Inkshift Blade in the viewmodel.

### Studio pass, round two Vandals (2026-11-14, run with the owner)

Installed in the match place: `ReplicatedStorage.WeaponSkins.{Giltfold,Sealwork,Payload,Inkshift}.Vandal` (SkinVersion `v02-flat`); `Config/SkinPreview.LINES` lists the four lines (Rojo-synced), so the in-game preview panel can show them.
- **First try (baked 1024 atlas)** read soft and seamy in Studio (owner: "hand drawn", "lines don't line up"); the Giltfold body read flat grey because its many small origami islands bled into the black margins at Roblox's lower mip levels (`tools/textures/pad_atlas.py` pads atlases, kept for other uses).
- **Fix, matching the game's own guns** (one MeshPart per material, flat Color + Roblox Material, no texture): `tools/blender/export_roblox_flat.py` exports one MeshPart per (bone, material) with a `manifest_flat.json` (colour, SmoothPlastic / Metal / Neon, reflectance); patterns are small transparent tiles (`tools/textures/make_skin_tiles.py`: Giltfold waves, Payload carbon and foil crinkle, Sealwork ruby veins) applied as tiled Textures over the part colour; Neon parts are darkened 40 % so cyan and blue keep their hue; kept stock parts take the line's flat finish (the sight's neon dot stays stock). Installer: `tools/studio/InstallFlatSkin.luau` (Open Cloud Models arrive x100 in size; parts are sized from the manifest). 13-21 parts per Vandal, largest part 6,352 triangles.
- **Magazine glitches** (Sealwork back edge, Giltfold strip) were near-coplanar overlapping faces flickering in Roblox: the Sealwork crystal narrowed so the gold spine and shoe stand 0.01 studs proud and the spine's back edge moved out; the Giltfold strip stands clear and stops below the receiver panels. Clearance re-checked.
- Uploaded to group 11116787; ids in `art-source/uploads.json`. **The owner saves the place.** Open: in-game viewmodel check (ADS, hands, reload) per line; the line items use the same flat export when installed.

- **Owner check 2 (same day):** reload magazines fell as the wrong mesh and the Inkshift reload crashed (`MagDrop:183 attempt to index nil with 'Size'`): `src/client/Util/MagDrop.luau` pooled dropped-mag copies per gun only and reused another skin's copy (or one with fewer parts). Pools now key on the gun plus the mag's meshes, and a copy whose part count differs is never reused. Giltfold: the magazine's wave strip was two mirrored slabs that left a see-through slot past the front edge (now one solid strip); the cool slate and pewter greys are now a warm ivory shadow (`C2B49A`) and champagne pewter (`A89A7E`). Payload: the foil pillow overlapped its frame's cut corner (now inside the window). Giltfold and Payload re-exported and reinstalled (`v02-flat-b`). Reload in play still to be confirmed by the owner (simulated input did not reach the gun).

- **Owner check 3 (same day):** the Giltfold magazine was see-through: some solids are built open (inner face deleted) and mirrored shut, and their normals were recalculated while open, so they came out inside-out; Blender shows both sides, Roblox culls back faces. `export_roblox_flat.py` now flips every closed island with a negative signed volume to face outward (ink-outline hulls and open stock pieces are skipped); it flipped the Giltfold magazine body and grip wrap and the Payload crown teeth. Payload: the foil pillow's edges sat on the frame face (.066) and flickered; they now stand at .074. Sealwork: dropped magazines lost their pattern Textures (MagDrop kept only meshes and appearances; it now keeps Textures too) and the ruby veins were toned down. **Moltframe Vandal v05** exported flat (14 parts, violet chambers with the Moltframe flow tile tagged `MoltframeFlowLayer` for ChamberFlow) and installed. All five Vandals reinstalled (`flat-c`). Next pass (owner): more design work on the Giltfold Vandal and the reload look.

### Studio pass 2: every line item, knives, casings (2026-11-14, owner away)

Owner's brief: shells should look like each skin's round; finish polishing; get the textures nice; get all the other guns and the knives in; animate the knives; fix the Moltframe gap at the back.
- **Moltframe gap:** the lower stock strut (`MF4_StockLow`) stopped 0.05 short of the rear cowl. Its front now seats inside the cowl (all 8 front vertices inside, ray-tested; builder `p0` moved to (-.135, 0, .254) in `model_moltframe_vandal_v04_parts.py`). Re-exported and reinstalled (`flat-d`, Model 130207485261159).
- **All line items installed** (26 jobs, 0 failures): Giltfold Marshal, Stinger, Ghost, Classic, Fan; Inkshift Odin, Phantom, Shorty, Stinger, Blade; Sealwork Guardian, Marshal, Shorty, Sheriff, Dagger; Payload Ares, Bulldog, Classic, Ghost, Odin, Operator, Stinger; Moltframe Ares, Spectre, Dagger (+ the Moltframe Vandal). Knives go in as `WeaponSkins/<Line>/Knife` with `SkinItem` = Fan / Blade / Dagger. SkinVersion `flat-d`; Model ids in `art-source/weapons/Skins/flat_install_ids.json`.
  - Exporter `tools/blender/export_skin_items_flat.py`: exports the skin collection plus every stock object re-coloured in Blender (so Studio matches the review renders); the hidden and re-coloured stock prefixes are removed in Studio, stock parts still on stock slot materials (scope lenses, loaded rounds, feed belts) stay as they are. Each line takes its colours from its owner-approved Vandal (the item blends predate the warm Giltfold fix). Exports at the rig's rest pose. A skinned mesh (the Fan's leaf) is split by dominant bone so each pleat half rides its rib.
  - Installer `tools/studio/InstallFlatSkin.luau` now adds rig joints the stock rig lacks (the Fan's Rib_00..10 Motor6Ds, C0 = the bone's rest frame) and reports kept stock parts; jobs staged through Rojo with `tools/studio/make_flat_install_jobs.py` (temporary `src/shared/_SkinInstall`, removed afterwards).
  - Checked: every line side by side and close-ups of six items (no missing, floating or see-through parts). A three-quarter capture that looked hollow was the mesh still loading (preload before capturing). `export_roblox_flat.py` gained an open-plate orientation vote (rays along and against each face; islands facing into the gun are flipped); a dry run found none in any item.
- **Skin casings:** `Util/ShellFx` throws the line's casing when the gun model has a `SkinLine` with an entry in `Config/SkinCasings`: an 8-sided faceted case (rim, groove, shoulder, neck) plus a band ring (`tools/blender/model_skin_casing.py`, template `ReplicatedStorage.WeaponSkins._Casing`, Studio-owned). Body = the round in that line's magazine, band = the line accent: Giltfold pewter + ivory paper, Sealwork brass + vermilion seal, Payload foil gold + mission blue, Inkshift blue-grey + cyan glow, Moltframe smoke nickel + violet glow; shotgun hulls in the line colour with a metal base. Stock guns keep the brass shell. Checked in play (Sealwork Vandal).
- **Texture polish:** Giltfold's pattern is now true overlapping wave scales (four rings per fan, 0.36 studs per tile; the first version read as a grid of separate arches), Payload's thermal foil is faceted crinkle cells with thin dark creases (the first read as soft smudges). Swapped on all installed skins (30 + 54 Textures); tiles in `make_skin_tiles.py`.
- **Knives:**
  - **Giltfold Fan:** `Util/FanMotion` + `Config/MeleeSkins.FAN`, layered on the stock knife moves: draw comes up shut and spreads open (Blender Fan_Open curve, 6 % overshoot), light slash folds a touch on the windup and flicks open at contact, heavy folds shut (Fan_Close) for the thrust and reopens on the recovery, inspect shuts and reopens to show the leaf then two fanning pulses. Shut, every rib folds onto the centre rib (a slim forward stack). First-person size 0.8 of the stock knife (`MeleeSkins.VIEWMODEL_SCALE`). Checked in play: idle, heavy (shut), inspect, the draw curve measured (-52° shut → open at 0.27 s, +3° overshoot, settle). Studio scrub: `Workspace.DevFanScrub`.
  - **Inkshift Blade:** reads as a sword upright from the fist; the stock moves suit it: its box never came closer than 0.46 studs to the camera through slash, heavy and inspect (near plane 0.1).
  - **Sealwork / Moltframe daggers:** stock moves; the talon sits right in the fist (checked in play).
- Reload with a new skin's magazine checked in play (Giltfold Classic: its 6 mag parts drop, no errors).

**Owner, please:** save the place; play each line with F7 / the preview panel (draw, swings, heavy and inspect on the Fan; reloads; ADS on the Marshal and Operator scopes); say if the Fan should be bigger or smaller, or should close to one side instead of the centre.

### Studio pass 3: the owner's notes on pass 2 (2026-11-14)

Owner's notes: Moltframe Spectre and Ares stock gaps, Moltframe Dagger gap and "weird spines"; sights vanish on ADS (Moltframe Spectre, Giltfold Stinger, Inkshift Stinger and Odin, Sealwork Guardian, Payload Ares and Odin); glitched parts on the Inkshift Odin and Payload Bulldog; Inkshift Blade tip not sharp; Operator scope and every reload showing skin Textures. "Fix all of these, do final checks, log all problems." Every cause, fix and check is logged in [Skin Build Pitfalls](Skin%20Build%20Pitfalls.md).
- **Gaps:** Spectre and Ares lower struts run into the receiver core (all 8 front corners inside). Dagger: the blade builder collapsed the blade base (station lookup fell through to the tip height), leaving a gap in front of the guard and a fin out of its top; fixed, the horn now rests on the spine and the spine fang is gone. Dagger rebuilt (`model_moltframe_dagger_parts.py`, v01 blend re-saved).
- **Sights on ADS:** the viewmodel's sight-line fade only spares parts named "Sight"; the export merged the sights into material parts. `export_roblox_flat.py` now keeps `*Sight*` objects as `SK_<Bone>_Sight_NN`. Simulated beforehand: exactly the 7 guns the owner listed hit a skin part, the other 46 skinned guns were clear.
- **Glitched parts:** z-fighting (coplanar faces). An audit over all 31 items found visible flush overlaps on 24; `resolve_coplanar()` lifts one side by 0.004 studs at export (listed per item in `manifest_flat.json` → `coplanar_lifted`); a second pass finds none.
- **Blade tip:** the ink outline tapers to 6 % over the last 0.2 studs (`ink_outline(taper=)`).
- **Textures through hidden parts:** new `client/Util/LocalHide` hides a part with its Textures; every viewmodel hide uses it, and dropped mags fade their Textures.
- All 30 models re-exported (25 items + 5 Vandals; the Vandals rebuilt from their builders: same triangles and colours as approved, only the sight parts split out and the lifts).
- **Blender final check** (owner asked while Studio was busy): fresh three-view sheets of every item, then geometry audits and a render of each exported FBX re-imported one-sided on magenta (what Studio draws). Found and fixed:
  - Half see-through grips on 9 items: Blender 5.2's `convex_hull_2d` returned broken outlines for the stock Odin, Phantom, Shorty, Ares, Bulldog and Vandal grips, a piece of the Odin receiver and the Ghost frame. Replaced by `convex_hull_xz`; Giltfold Ghost, Inkshift Odin / Phantom / Shorty, Sealwork Shorty, Payload Ares / Bulldog / Ghost / Odin rebuilt (`fin2_*` finals).
  - Self-crossing faces on 7 items (blade tips, grip plates, the Moltframe Ares upper shell, the Operator handguard frame): repaired at export, none left.
  - Sealwork Sheriff grip seated into the frame.
  - Checked and left as designed: the Giltfold Classic slide points (`GFC_Point`), and four see-through spots the stock guns share (Bulldog sling slot, Guardian rail bridge, Sheriff cylinder gap, Classic grip seam).
  - Every enclosed see-through patch in the 90 one-sided renders is now a real opening (trigger guards, stock frames, scope mounts, muzzle slots, the Fan's rib gaps).
- Uploaded as `flat r4` and **installed** (`flat-e`, 30 jobs, 0 failures; ids in `art-source/weapons/Skins/flat_install_ids.json`).
- **Checked in Studio:** the ADS sight-line simulation on all 53 skinned guns finds no non-sight part on the sight line; magenta-backdrop captures of the Moltframe Spectre and Ares stocks (struts into the receiver), the Moltframe Dagger guard, the Inkshift Odin and Payload Bulldog grips (solid), the Sheriff grip and the Inkshift Blade tip (sharp). In play: the Payload Operator scoped hides all 12 skin Textures with the gun (clean scope); a Payload Vandal reload hides the mag's Textures with it (0 left showing) and the dropped mag's Textures fade with its parts; the Moltframe Dagger and Inkshift Blade in first person. Output: no skin errors. A `Source` provenance attribute on `WeaponSkins._Casing` was rejected by Roblox at play start and removed (provenance stays in this note).

**Owner (2026-11-14):** saved the match place; "looks good".

## Open: the Studio pass (owner's call, later)

1. ~~Upload and install~~ (done in Studio pass 2 with the flat installer).
2. Live ADS on every optic and iron sight, viewmodel hand contact on the rebuilt handguards, world-model read at range (world models keep stock geometry and shells).
3. Motion: Moltframe chamber flow and the Slipframe and Inkshift glints via `src/client/Util/ChamberFlow.luau` (camera guns only; config `Config/SkinPreview` → `CHAMBER_FLOW`). Static maps are the fallback everywhere.
4. Melee: the Fan is animated (above); Sealwork Dagger custom moves still wait for the owner's Ruin Dagger video; the Slipframe line is not in the preview list.
5. Stock animation note: the Sheriff Reload clips the speedloader and rounds through the stock frame.

## Pipeline (rerunnable, Blender MCP)

Shared helpers `tools/blender/model_moltframe_vandal_v04.py` (+ helper half of `model_moltframe_vandal_v04_parts.py`); line kits `model_slipframe_kit.py`, `model_giltfold_kit.py`, `model_inkshift_kit.py`, `model_sealwork_kit.py`, `model_payload_kit.py`; item builders `model_<line>_<item>.py` / `model_<line>_guns.py`; Moltframe items `model_moltframe_{spectre,ares,dagger}_parts.py`; Giltfold Fan `model_giltfold_fan.py`; bake + Roblox export `bake_moltframe_line.py`; review renders `review_moltframe_item.py` (melee mode for the Knife slot); sheets `moltframe_sheet.py`. Outputs: `art-source/weapons/Skins/<Line>/<Item>/<version>/` (blend, Roblox FBX, manifest with part specs, textures, review renders, matched sheet).
