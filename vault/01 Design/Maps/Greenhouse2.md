# Greenhouse2

The rebuild of [Greenhouse](Greenhouse.md) to the [Map Quality Standard](Map%20Quality%20Standard.md). It's a new map version: the old Greenhouse (its files, its Studio model, its Config rows) stays untouched (§7).

**Map id** `Greenhouse2` · **World origin** (0, 200, 3000). That spot is free: on 2026-11-06 there were 0 parts in a 320 × 300 × 440 box round it in the match place, and the nearest map is OldTown, which ends at z ≈ 1650. · **Modes** 2v2–4v4, playable 1v1 · **Lane** G (map-redesign) · **Status:** round 1 built overnight (2026-11-06). Following the overnight rule, the user approves the finished map instead of the concept board.

**Mandatory for every lane and every agent brief:** load `.claude/skills/gauntlet-vault/SKILL.md`. Read [00 Home](../../00%20Home.md), the [Map Quality Standard](Map%20Quality%20Standard.md) and this note. Use the LihFolk notes linked below and the `lihfolk-worldbuilding` and `roblox-blender-modeling` skills.

## Plan (Map Quality Standard §2, in order)
| # | Step | State |
|---|---|---|
| 1 | Reference board, identity brief, Codex concepts in `art-source/maps/Greenhouse2/concepts/` | Identity brief below. **Concepts: Greenhouse is last in Codex's queue.** Third-party shots, if anyone collects them, go in `vault/02 Art/References/maps/greenhouse2/third-party/`, never committed. **No modelling before the user approves the board.** |
| 2 | Layout kept | **Done.** [greenhouse2_layout.py](../../../tools/maps/greenhouse2_layout.py) writes the Greenhouse layout (solids, spawns, barriers, checks) under the new id and origin. The Greenhouse checks all hold (below). The collision boxes don't move from here. |
| 3 | Palette table | **Done**, below. It goes into `tools/maps/greenhouse2_style.py` with the kit. |
| 4 | Kit in Blender | Waits for step 1. It goes in `tools/blender/build_map_kit_greenhouse2.py`, one `Map_<Piece>` per piece, with a contact sheet beside an R15 proxy and coplanar 0. |
| 5 | Trim sheet and textures | Waits for Codex's material sheet: one 1024 trim sheet plus ≤ 6 variants at 512. |
| 6 | Build | Greybox: **done** (`tools/studio/maps/Greenhouse2/Greybox.luau`, installed). `Art.luau`, `Lighting.luau` and `Life.luau` come with the kit. |
| 7 | Audits | Run on the greybox; results below. Rerun on every install: `Audit.luau` and `FloatAudit.luau` must both be at 0. |
| 8 | Fixed cameras | Picked on the greybox, in [evidence_cameras.json](../../../tools/maps/evidence_cameras.json) under `Greenhouse2`. |
| 9 | Blind score | 3 reviewers, the median, the stop rule (§6). Not scored on the greybox: no scoring before the kit. |
| 10 | The user's approval | Approval summary (§6). Only then does it go into `Config/Match` MAPS; until then, `ForceMap = "Greenhouse2"`. |

## Identity brief (step 1)
**One sentence:** a sunlit Victorian palm house, with a white iron dome over a fountain, palms rising into the glass, a gallery and a bridge to fight from, and shaded brick potting sheds to sneak through.

- **Landmark:** the glass dome with its lantern and gilt finial over the fountain. It's the tallest thing (about 80, twice the 40 halls), seen through the roof glass from every hall and over the walls from the Terrace.
- **Height structure:** the ground (beds, paths, the fountain basin), the gallery and bridge at +12, and the dome above. The Sheds roof at 14 is collision, not a perch.
- **Zone colour:** green on the beds and palms, white iron, mint glass. Each end gets a door tone: B (+Z) cool slate-blue and A (−Z) warm terracotta. No team cyan or orange-red, and no second yellow next to the gilt finial.
- **Story groups (2–3):**
  1. **A potting bench mid-repotting:** an upturned tub, a sack of compost, a trowel, a stack of terracotta pots, a watering can (Sheds).
  2. **The gardener's barrow by the lily pond:** a barrow with cut fronds and a coiled hose run off a standpipe (Terrace).
  3. **The fountain's maintenance:** one panel of the basin rail off and leaning on a bench, a toolbox (Dome, at the wall, out of the lanes).
- **Not this:** ruined or overgrown glass, weeds or grime, a jungle maze, foliage cards at head height, glass you can see enemies through but can't shoot, invisible walls, neon, primitive stacks, part-built letters, blank signs, team colours.

## Layout (step 2): kept from Greenhouse, measured 2026-11-06
![Layout](../../02%20Art/References/maps/greenhouse2/greenhouse2-layout.svg)

The checks are the same numbers as [Greenhouse §3](Greenhouse.md#3-layout). Rerun on 2026-11-06:
- Spawns are never seen.
- Cover spread: worst 15.0 (Dome), average 4.5.
- The gallery sees 9.2% of the spots outside the Dome.
- Updraft apex is 38.2 against 40-tall walls, with 0 reachable ledges.
- Greybox coplanar: 0.
- Heights: floor 0, gallery and bridge 12, Sheds and Lodge ceilings 14, Orangery 20, halls 40, Dome lantern 80.

Changes against the standard's numbers, for the kit and not the collision: Greenhouse's gameplay doors are 8 wide × 10 high, above the 6 × 8 minimum. Half cover 3 and full cover 8 hold.

## Palette (step 3, single table)
Every colour on the map comes from this table. The Codex props are recoloured by role. There's no Roblox `Metal` on painted iron (it mirrors the sky), so the white iron is SmoothPlastic with the trim sheet's normal map.

| Slot | Roles | Colour | Material / variant |
|---|---|---|---|
| Walls | Wall glass, whitewashed and opaque: mint `CDE2D8`. Orangery stucco cream `EDE4D0`. Sheds brick `9C5B44`. | | glass is SmoothPlastic; trim-sheet rows for stucco and brick |
| Stone and trim | Limestone copings, bed walls and urns `D9D0BE`. Iron frames white `EDEDE4`. | | trim sheet |
| Floors | York-stone paving `C9C1AF`. Terrace gravel `CDBF9C`. Lawn `7EA35A`. Soil `4A3A2C`, lifted above luminance 0.06. | | variants |
| Roofs | Roof and dome glass `CFE6EA` (Transparency 0.55, one layer). Sheds slate `6F7A86`. | | |
| Steel | Fixings and hardware charcoal `3A3F45` (small) | | SmoothPlastic |
| Machines | Boilers and pipes cast iron `5A5F64` with copper `B07650` | | |
| Accents | Foliage: palm `5E8F3A`, fern `4C8A3E`, deep `2F6B35`, lime `9BC24E` (the saturation, about 10%). Terracotta pots `C0673F`. Gilt finials `C9A24B`, the one gold. | | |
| End tones | B (+Z) slate-blue `4F7FA8`; A (−Z) terracotta `B8603F` (door frames, tub bands, shed doors) | | |
| Water | `5FB0B8`, Transparency 0.35, one plane | | |
| Glow | GlowWarm `FFC488` amber (lamp lenses only) | | Neon |
| Sign art | Codex originals (fictional nursery, seed and tea brands), decal tint `E8DCD0` | | |

## Lighting target (§3 Lighting)
- Bright midday from the Stylized Lighting Recipes "bright cartoon" row, lifted: sun high (about 70°), so the iron ribs throw stripes on the floor.
- Glass is shadowless; the iron casts shadows.
- The Sheds are the one shaded lane.
- Pass the greyscale and no-shadow tests.
- Bloom threshold about 1.1, so the white frames don't glow.

## Codex prop list (Greenhouse2)
Every row also has to follow these rules:
- the standard §3 Modelling rules and §5 delivery (`art-source/maps/Greenhouse2/props/<Prop>.glb` plus `.blend` plus `_preview.png` with a 5-stud block);
- one material per role, named by role;
- no text or logos;
- the vault-and-LihFolk rule.

| Row | Prop | Size (studs) | Tris | Roles | Notes |
|---|---|---|---|---|---|
| G1 | **Fan palm**: a curved trunk with ring scars, about 9 fronds in a crown | trunk 14–18, crown 10 across | ≤ 3,000 | Bark, Palm | The crown sits above 8 (no foliage at head height). Two variants. |
| G2 | **Tree fern**: a hairy trunk and an arching frond crown | 6–8 tall, crown 7 | ≤ 1,500 | Bark, Fern | Crown above 5. |
| G3 | **Fountain**: three tiers, a lion-mask spout, a basin rim with a coping | basin 16 across, top tier 9 high | ≤ 6,000 | Stone, Iron, Water | Fills its collision: the basin is half cover at 3, the pedestal full cover. |
| G4 | **Cast-iron column with a leafy capital**, plus a gallery bracket | 12 tall, 0.8 shaft | ≤ 800 | Iron | Repeated 16×. |
| G5 | **Wardian case**: a glass plant case on an iron stand | 4 × 2 × 4 | ≤ 1,200 | Iron, Glass, Fern | Full cover, so the glass is opaque frosted. |
| G6 | **Potting-bench story set**: bench, pot stack, sack, watering can, trowel | bench 6 × 2 × 3 | ≤ 1,500 | Wood, Pot, Cloth, Iron | Story group 1. |

## Fixed evidence cameras (step 8)
These are picked on the greybox from clearance rays and stored in `evidence_cameras.json`. Map-local, eye height = floor + 5. They're provisional: re-check them once the kit is in, so no camera sits inside a prop.

| Camera | Position | Looks at |
|---|---|---|
| overview | (110, 95, 150) | (0, 10, 0) |
| b-spawn | (−6, 5, 100) | (0, 8, 40) |
| fern-house | (−12, 5, 64) | (0, 20, 0) |
| dome-floor | (−30, 5, −20) | (0, 30, 0) |
| gallery | (−36, 17, −20) | (0, 20, 10) |
| west-wing | (−58, 5, −36) | (−58, 8, 36) |
| terrace | (−62, 5, 60) | (−62, 6, 10) |

![Greybox overview](../../02%20Art/References/maps/greenhouse2/v0-greybox-overview.jpg)

## Audits on the greybox (2026-11-06)
Installed: `Greenhouse2 greybox: 345 parts, 8 spawns, 4 barriers` at (0, 200, 3000).

On the greybox alone:
- **FloatAudit:** 3 floating groups. They are the Dome lantern's collision ring (its facets touch nothing below at the lantern height) and the bridge rails.
- **Audit:** 56 z-fighting pairs, among collision Parts: the dome facets with each other and the walls, the fountain rim, and the roof corners.

Every one of these is a Part the kit replaces and `Art.luau` hides (`look=None` in the layout), as on Greenhouse, which audited at 0 once the art was in. The gates (0 / 0) apply once the art is in. If any group is still floating then, its kit piece gets a real mount (the lantern sits on the dome ring; the bridge rails on posts).

## Results log
Rounds go here (§6).

### Round 1 (2026-11-06, about 01:55)
**Kit:** [build_map_kit_greenhouse2.py](../../../tools/blender/build_map_kit_greenhouse2.py) is forked from Greenhouse's and brought to the standard: 38 pieces, 59.7k triangles.
- **Material:** no Roblox Metal on the painted iron or gilt (SmoothPlastic), and the palette-table iron colour.
- **Glass walls:**
  - an arched head in every bay's top panel;
  - roundel bosses in the spandrels;
  - a turned finial on every rib along the cresting (the concept's kit sheet).
- **Fountain:** the concept's third tier, with its bowl and a gilt finial.
- **Palms:** a thick, knobbly 10-sided trunk with staggered leaf-base rings and an 18-frond, two-tier crown (concept 02-hero).
- **Boiler:** a cast-iron sectional boiler with copper flow and return pipes, flanges, a pressure gauge and a valve wheel.
- **Crates:** slatted, with planks, gaps and corner battens, each turned a few degrees.
- **New FlowerTub:** a staved tub with two end-tone bands and a white hydrangea, 8 a side by the Dome and Fern House doors. Placed from a clearance search: decor only, out of the lanes.

**Art and lighting:**
- [greenhouse2_art.py](../../../tools/maps/greenhouse2_art.py) reuses Greenhouse's placements on the kept layout: 267 placements, 1,025 MeshParts.
- `Greenhouse2/Lighting.luau` is lifted: Brightness 2.7, Ambient (132,138,136), OutdoorAmbient (166,174,170), exposure −0.2.

**Uploads:** Structure `130593505718441`, Garden `93873736777844`.

**Audits in Studio:**
- Float audit: 18 groups at first, then 0. Hydrangea crowns hovered 0.26 over the tubs, and a valve ring touched nothing.
- **0 floating groups, 0 z-fighting pairs** (1,112 parts).
- Offline box check: 2 pairs with a Part. These are GlassWall4 iron against the ShedPerimeter collision box; Studio's ray test says 0.

**Shots:** `vault/02 Art/References/maps/greenhouse2/v1-r1-*.jpg` and the side-by-side.

**Studio note:** when I applied my preview lighting, Metro2's PreviewLighting state (the knife-sounds lane) was still applied with no lock held. I restored it first.

**Round 1 blind score: 5.0** (reviewers 5.4, 5.0, 5.0; medians W1 1, W2 1, W3 1, W4 1, W5 1, W6 1).

Low points:
- No focal point at eye level. The dome-floor camera faced a rockery, and the fountain didn't read: a bad angle.
- The b-spawn camera faced a Wardian case against a blank wall (also a bad angle).
- A cyan wash instead of the concept's warm sun.
- The overview was a white box on a void, with timber roofs over the brick ranges.
- Flat low-poly palms against photo-textured rock.

### Round 2 (planned and built)
- **Cameras** re-picked under the standard's "no bad angles" rule (§2 step 8). This is a one-time change; from round 2 on, the same angles every round:
  - **dome-floor:** from inside the Dome's north door toward the fountain, bridge and dome;
  - **b-spawn:** out of the Lodge door toward the Fern House.
- **Light:** sun 15.6 with a warm ColorShift (255,216,168), warm atmosphere, grade tint (255,238,214), saturation 0.12. Wall glass is less teal (`DDE8E0`).
- **Roofs:** hipped slate roofs over the Sheds, Lodge and Orangery, with stone ridges, timber fascias, brick chimneys with pots, and glazed skylights. The Sheds and Lodge ceilings are now slate.
- **Parkland:** a lawn round the building and a ring of 26 broadleaf trees outside the walls (overview only, no collision).

**Round 2 blind score: 5.0** (all three reviewers 5.0; every criterion at 1). That's no gain on round 1.

What was confirmed:
- The dome floor now has a focal point (the fountain between palms, the bridge and gallery).

What still holds it back:
- **Walls:** the glass and iron read as flat pale sheets with no contrast.
- **Odd materials:** a marble-veined pedestal, a saturated blue Wardian table at the spawn, bare "sand" on the Dome floor.
- **Plants:** giant reed spikes; rock slabs instead of planters.
- **Light:** pale, not golden.

### Round 3 (the last unless it gains ≥ 0.3)
- **Wall glass** is a deeper sea-green (`9DBDB2`), so the white iron reads against it. Mullions and transoms are bolder, and every bay gets an eye-level iron arcade (the concept's arched lower lights).
- **Rockeries and the fernery** stand on brick plinths with stone copings (the concept's planters), with rocks and ferns above.
- **Pond reeds** are low iris clumps.
- **The statue pedestal** is limestone.
- **End tones** follow the palette table (B slate-blue `4F7FA8`, A terracotta `B8603F`), not the old saturated blue and yellow.
- **The Dome floor** gets the halls' paving.

**Round 3 blind score: 5.0** (the median is 5.0 from the two reviewers in at the time; every criterion at 1).

### Stopped at 5.0 (the stop rule)
Scores by round: 5.0, 5.0, 5.0. Rounds 2 and 3 each gained 0, so the map stops. **This is a draft. Don't show it for approval.** The audits are clean: 0 floating groups and 0 z-fighting pairs.

**Honest read:** the old Greenhouse kit is too far below the new concept for polish to close the gap. Every reviewer named the same core gaps:
1. **The glass halls** are flat sheets of one tint with thin lines. The concept's halls are ornate cast iron: columns with leafy capitals, filigree spandrels, arcades, and glass you see sky and garden through.
2. **The planting** is low-poly palms and faceted rock slabs. The concept has lush layered ferns, hydrangeas, potted citrus and tree ferns.
3. **The light** isn't the concept's warm golden sun on the stone floor.
4. **The spawn view** is a blank stucco wall with a Wardian case. The concept's spawn is a dressed Orangery.

**What would move it:** the hero pieces need modelling from the concept's kit sheet, which Codex can do well (the fast props job on Rooftops2 shows it):
- an iron column with a leafy capital and an arched spandrel, as one modular bay;
- a filigree arcade wall bay;
- a fern and hydrangea planting set;
- a lantern.

Then rebuild the wall kit around them and re-light the map with a lower, warmer sun and real fill. That's a v2 of the kit, not another polish round.

## Codex hero kit

**Delivered 2026-11-06 — Job G-kit.** Original standalone assets modelled through the interactive Blender MCP against [03-kit-sheet](../../../art-source/maps/Greenhouse2/concepts/03-kit-sheet.png) and [02-hero](../../../art-source/maps/Greenhouse2/concepts/02-hero.png). This is the new hero-kit brief, separate from G1–G6 above. No full-bay dimensions were specified, so both architectural bays use the requested **12-wide × 18-high** fallback. Sizes below are exact exported bounding extents rounded to 0.001 stud, **X width × Y depth × Z height**.

All six packages have 1 unit = 1 stud, Z up, shared bottom-centre origin (0,0,0), applied rotation/scale and role-named materials. Every preview is a three-quarter render beside a grey **5-stud** scale block. Preview ground, proxy, cameras and lights are excluded from GLBs.

| Prop | Tris / ceiling (strictly under) | Size (studs) | Roles | Files | Result / limitations |
|---|---:|---|---|---|---|
| IronBay | 5,924 / 6,000 | 12 × 2.100 × 18 | Iron, Stone, Charcoal | [GLB](../../../art-source/maps/Greenhouse2/props/IronBay.glb) · [Blend](../../../art-source/maps/Greenhouse2/props/IronBay.blend) · [Preview](../../../art-source/maps/Greenhouse2/props/IronBay_preview.png) | Fluted column, overlapping leafy capital, moulded base, paired arched spandrels and connected cast scrolls. |
| ArcadeWall | 4,964 / 5,000 | 12 × 1.320 × 18 | Iron, Stone, Brick, Glass | [GLB](../../../art-source/maps/Greenhouse2/props/ArcadeWall.glb) · [Blend](../../../art-source/maps/Greenhouse2/props/ArcadeWall.blend) · [Preview](../../../art-source/maps/Greenhouse2/props/ArcadeWall_preview.png) | Three lower arcades, radial lunette glazing bars, connected scroll frieze and supported coursed-brick plinth. |
| FernClump | 1,292 / 1,500 | 5.373 × 5.225 × 2.784 | Fern, Deep | [GLB](../../../art-source/maps/Greenhouse2/props/FernClump.glb) · [Blend](../../../art-source/maps/Greenhouse2/props/FernClump.blend) · [Preview](../../../art-source/maps/Greenhouse2/props/FernClump_preview.png) | 17 arching fronds with fine pinnae; solid rooted rachises; packed cutout atlas. |
| HydrangeaBush | 1,440 / 1,500 | 4.034 × 4.521 × 3.658 | Bloom, Fern, Deep | [GLB](../../../art-source/maps/Greenhouse2/props/HydrangeaBush.glb) · [Blend](../../../art-source/maps/Greenhouse2/props/HydrangeaBush.blend) · [Preview](../../../art-source/maps/Greenhouse2/props/HydrangeaBush_preview.png) | 8 varied mopheads, 96 modelled four-petal florets and 32 broad serrated leaf cards. Deliberately faceted close up. |
| PalmInTub | 1,484 / 1,500 | 11.252 × 11.526 × 16.444 | Bark, Palm, Deep, Pot, Iron, Soil | [GLB](../../../art-source/maps/Greenhouse2/props/PalmInTub.glb) · [Blend](../../../art-source/maps/Greenhouse2/props/PalmInTub.blend) · [Preview](../../../art-source/maps/Greenhouse2/props/PalmInTub_preview.png) | 22 broad fronds in three tiers, curved trunk with 24 folded leaf bases, fluted terracotta tub and two iron bands. Crown stays above 8 studs. |
| Lantern | 562 / 800 | 1.600 × 2.760 × 4.068 | Iron, Charcoal, GlowWarm | [GLB](../../../art-source/maps/Greenhouse2/props/Lantern.glb) · [Blend](../../../art-source/maps/Greenhouse2/props/Lantern.blend) · [Preview](../../../art-source/maps/Greenhouse2/props/Lantern_preview.png) | Curled cast bracket, bolted mount plate, tapered frame, hipped roof and warm lens. Mount against its +Y back face. |

**Validation:** all role meshes pass the LihFolk mesh gate (intentional foliage/floret cards allowed): no loose or degenerate geometry, inconsistent normals, within-shell self-intersections or overlapping caps. A component-contact graph found **0 floating components** across 754 shells; intended joins overlap. All six GLBs were reimported into temporary Blender scenes: triangle counts, mesh counts and dimensions matched their sources within 0.001 stud. Vertex colours and packed textures survive; no external texture dependencies or preview helpers are exported.

**Materials and placement:** use white mesh tint to retain vertex colours. Painted Iron is matte, not reflective Roblox Metal. Fern/Palm leaf cards use an original packed 1024 atlas, **binary alpha mask**, and double-sided rendering; hydrangea florets use opaque folded geometry. This follows the job's explicit permission for foliage cards. Solid roles are single-sided. Arcade glazing uses the palette roof-glass colour CFE6EA with transparency 0.55 in one layer; keep it shadowless on installation. Bark and Bloom retain the existing kit's role names. Filigree and foliage deliberately include fine details below the generic 0.2-stud thickness guideline. Keep these decorative meshes anchored, with decoration collision/touch/query disabled; use the map's separate gameplay collision.

**Visual review:** Quick council, Art Director/Skeptic lens: IronBay 16/18, ArcadeWall 16/18, FernClump 15/18, HydrangeaBush 14/18, PalmInTub 15/18, Lantern 16/18; no zero after revisions. The strongest objection changed the planting: fractured flower cards became seated modelled florets, and the sparse palm became a broad three-tier crown. The hydrangea remains angular at close range. A four-angle IronBay review also found no visible reverse-face/construction blocker. Studio appearance and installed-map quality remain untested; this does not change the map's draft/5.0 status.

**Notes used:** the map palette, “What would move it” and prop rules; Art Direction and Map Quality Standard; LihFolk *Hard-Surface Modeling*, *Shape Language and Silhouette Testing*, and *Critiquing a Model — Paintovers and Iteration*, via the worldbuilding/modeling skills. No scripts or Studio content were changed.

## Kit v2 (2026-11-06 morning): Codex hero kit
This is a fresh start under the stop rule (the core chat's call).

**Codex review:** all six pieces matched the concept's kit sheet in ornament and scale.
- The IronBay, ArcadeWall, FernClump, HydrangeaBush and Lantern are used.
- **PalmInTub is not used:** its fronds are alpha-atlas cards, and our role-colour import renders them as solid quads. It needs its atlas as a SurfaceAppearance first.
- Codex bakes shading into vertex colours, which Roblox multiplies into the part colour (the trunks came out black). The loader strips them.

**Wired in** ([build_map_kit_greenhouse2.py](../../../tools/blender/build_map_kit_greenhouse2.py) `hero()`):
- **Walls:** every 8-wide glass bay has the ArcadeWall as its lower 12 studs, decimated to 0.35 on the iron only.
- **Gallery and bridge:** IronBay columns with leafy capitals and filigree spandrels, as their own mesh, 0.6 decimated.
- **Planting:** fern clumps in the beds, ferneries and planters; hydrangeas in the flower tubs.
- **Orangery:** lanterns on its windows; flower tubs at its doors (the spawn view).
- **Light:** a low warm sun (16.7) with warm fill.
- **Size:** about 600k kit triangles placed. That's over the standard's 450k phone budget: the next pass decimates the walls further.

**Audits:** 0 floating groups, 0 z-fighting pairs (1,391 parts).

### v2 round 1: **5.0** (5.0, 5.0, 5.0)
Low points: the glass reads as opaque teal walls, the rockeries are grey slabs, the spawn table is saturated blue, and the overview is empty.

### v2 round 2: **5.0** (5.0, 5.4, 5.0)
Changes:
- brighter aqua glass;
- the rockeries, fernery and palm planters became brick planters (brick, stone bands, coping) with Codex ferns;
- muted end tones.

Low points: the glass still reads as a flat wash, and the overview is bare. The overview also shows other lanes' maps floating around it (the Snowpeak2 range, slabs): not ours, but in frame.

### v2 round 3 (the last unless it gains ≥ 0.3)
The wall glass reflects the sky: Reflectance 0.32 on the opaque frost (still no see-through walls), and EnvironmentSpecularScale 0.8.

**v2 round 3: 5.0** (5.0, 5.0, 5.0). The reflective glass reads as glazing now. Reviewers moved on to the surroundings and the washed-out whites.

### Kit v2 stopped at 5.0 (the stop rule)
Kit v2 scored 5.0, 5.0 and 5.0. Every review across 6 rounds and 18 reviewers gave each criterion 1. Fixing what one round named moved the complaint to the next item; the median never moved.

**What every v2 reviewer named:**
1. **The surroundings:** a flat green plate with lollipop trees. The concept's walled gardens, ponds, hedges and outbuildings are missing.
2. **Washed-out whites:** white iron, balustrades and glass blend into one bright mass.
3. **The spawn view:** a blank stucco wall with a Wardian case.

(Other lanes' maps float on the horizon. Snowpeak2, a slab and others are in frame from (0, 200, 3000); that's not ours, but it costs W3.)

**Honest read:** the arena is a set of enclosed glass halls, and the reviewers judge it against a concept that is mostly a garden around a glasshouse. To move it:
- model a walled garden ring (hedges, paths, ponds, outbuildings);
- tone the iron down to cream (`D8D2C2`) with darker hardware;
- dress the spawn wall as a real Orangery (citrus tubs, benches, a tiled floor).

That's a design pass, ideally with Codex concepts for the garden, not another polish round. **Not for approval.**
