# Greenhouse2

The rebuild of [Greenhouse](Greenhouse.md) to the [Map Quality Standard](Map%20Quality%20Standard.md). It's a new map version: the old Greenhouse (its files, its Studio model, its Config rows) stays untouched (§7).

**Map id** `Greenhouse2` · **World origin** (0, 200, 3000). That spot is free: on 2026-11-06 there were 0 parts in a 320 × 300 × 440 box round it in the match place, and the nearest map is OldTown, which ends at z ≈ 1650. · **Modes** 2v2–4v4, playable 1v1 · **Lane** G (map-redesign) · **Status:** planned, greybox installed. **Modelling is waiting for step 1:** Codex's concepts and the user's approval of the board.

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
| sheds | (−62, 5, 60) | (−62, 6, 10) |

![Greybox overview](../../02%20Art/References/maps/greenhouse2/v0-greybox-overview.jpg)

## Audits on the greybox (2026-11-06)
Installed: `Greenhouse2 greybox: 345 parts, 8 spawns, 4 barriers` at (0, 200, 3000).

On the greybox alone:
- **FloatAudit:** 3 floating groups. They are the Dome lantern's collision ring (its facets touch nothing below at the lantern height) and the bridge rails.
- **Audit:** 56 z-fighting pairs, among collision Parts: the dome facets with each other and the walls, the fountain rim, and the roof corners.

Every one of these is a Part the kit replaces and `Art.luau` hides (`look=None` in the layout), as on Greenhouse, which audited at 0 once the art was in. The gates (0 / 0) apply once the art is in. If any group is still floating then, its kit piece gets a real mount (the lantern sits on the dome ring; the bridge rails on posts).

## Results log
Rounds go here (§6).
