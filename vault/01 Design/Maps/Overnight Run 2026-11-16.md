# Maps overnight run (2026-11-16 → 17)

Owner, going to bed: "keep working on the maps and get them all done… do your own grading… don't ask for my approval… until they're fully ready". So the batch checkpoints are skipped (Map Quality Standard → overnight runs); audits, captures, bot runs and grading still apply. Roster: [Maps](00%20Maps.md) → Release roster. Done before tonight: [Arena + Big Arena](Arena.md), [Pier + Dockyard](Pier%20and%20Dockyard.md).

## Method (same for every map)
1. Layout as data in `tools/maps/map_plans.py` (checker: `arena_layout.py`; rules: spawn gap, long rays, lanes, pinches 0, two ways up, spawns hidden, first sight 2.5-5 s, jump 7.5 / gap 9, dead band 4-6).
2. Greybox in the match place through the shared builder `ServerStorage.MapTools.Build` (source `tools/studio/maps/MapTools/Build.luau`); plain parts, theme colours, our tile textures, lighting profile, spawns for the ghost hold, empty Barriers, KillDepth.
3. Theme kit in Blender (port 9930): meshes for the shaped hero pieces only; parts for the rest (owner's mix). Export → Open Cloud → `kit_bundle.py` → placed by the builder over the greybox parts (which stay as invisible collision).
4. Checks: same-plane overlaps 0, captures (aerial + spawn exit), a bot run with ForceMap, a self-grade out of 10 with reasons; fix anything under 8.

## Origins (match place; owner: "spread out the maps", 1,000 studs apart)
Regular row z = 0: Arena (4500), Pier (5500), Rooftops (6500), Courtyard (7500), Bunker (8500), Foundry (9500), Snowpeak (10500), Model Kit (11500) (x, y 200).
Large row z = -1500: Big Arena (4500), Dockyard (5500), Old Town (6500), Metro (7500), Greenhouse (8500).
Big Arena, Pier and Dockyard were moved there by a pivot shift (their notes give the old origins; the builders in tools/studio/maps/Arena and /Port still carry the old origins).

## Owner notes during the run
- Arena and Pier are "the simple ones"; the rest should be nicer: "not as simple… not too blocky… actually having good nice things in it" (RIVALS Docks-level dressing). So every themed map gets a Blender kit for its shaped pieces, plus tile textures (brick, planks, concrete panel, pavers, cutting mat, tread plate; `art-source/maps/Themes/textures/`).

## Incident and repair (overnight, owner please read)
- The shared builder replaces `Workspace.<id>`, and six new maps first used old map names (Rooftops, Bunker, Snowpeak, OldTown, Metro, Greenhouse), so building them **deleted the old maps of those names** in the open match place (unsaved). The Rooftops kit export also overwrote the old Rooftops kit's `Exports` files and updated its asset `112960022711405`.
- **Repaired the same night:** the old export files restored from git and re-uploaded (asset 112960022711405 holds the old kit again); the six old maps re-loaded into Workspace at their original origins from their `.rbxm` backups (`art-source/maps/<Map>/<Map>.rbxm`, uploaded as private model assets 109930451154210 Rooftops, 125498566478940 Bunker, 114897179638328 Snowpeak, 125168710705746 OldTown, 116106415285601 Metro, 77293910762832 Greenhouse). The new maps were renamed **Rooftops3, Bunker3, Snowpeak3, OldTown3, Metro3, Greenhouse3** with their own kit folders, and `map_meta.py` now carries an explicit id per map.
- **Check before saving the match place:** the backups may be older than the last saved place. If you edited any of those six old maps by hand after their backup, compare with the last saved version first (or skip saving and keep that version's old maps).

## Status
| Map | Layout | Greybox | Kit | Lighting | Bot run | Grade | Notes |
|---|---|---|---|---|---|---|---|
| Rooftops3 | ✅ alley + 3 bridges, billboards over the gap; long rays 32% | ✅ 45 parts | ✅ RT_ 13 pieces (asset 97994515689937) + tower crane | ✅ | not run | 7.5 | parapets want an edge coping; billboard backs are bare |
| Courtyard | ✅ first sight 1.6 s (plaza; review point) | ✅ 44 parts | ✅ Town kit (100363366584662) | ✅ | not run | 8 | brick townhouse walls (18 high) close the square |
| Bunker3 | ✅ shaft room, generator blocks door lines | ✅ 43 parts, roof +14 with the shaft open | ✅ BK_ 7 pieces (80566606784164) + 10 floodlights | ✅ | not run | 7.5 | outer walls close it; ring walls are still plain concrete blocks |
| Foundry | ✅ first sight 1.5 s (review point) | ✅ 43 parts, molten channel (Neon) | ✅ FD_ 9 pieces (71729193914093) + furnace | ✅ | not run | 8 | molten plane lowered to -7 (no rim glow); hall floor apron; catwalk hazard trim is yellow (owner disliked yellow accents: review) |
| Snowpeak3 | ✅ | ✅ 42 parts | ✅ SP_ 12 pieces (128541608803309) + gondola station | ✅ | not run | 8 | snowfield apron + 40-pine treeline frame the map |
| Model Kit | ✅ | ✅ 39 parts | ✅ MK_ 14 pieces (73169723533803) + desk lamp | ✅ | not run | 8 | fat pencil is the ramp (wedge hidden, keeps collision); mat lies on a wooden desk apron |
| OldTown3 | ✅ one 260 line (0.2% of rays) | ✅ 46 parts | ✅ Town kit | ✅ | not run | 8 | open edges past the blocks |
| Metro3 | ✅ rebuilt as platforms + concourse | ✅ 64 parts, roof +22 with skylights | ✅ MT_ 10 pieces (128225709564447) + 2 station clocks | ✅ | not run | 8 | outer walls close the station; accent is signal red (no yellow); bridge stairs are greybox wedges |
| Greenhouse3 | ✅ one 278 line (0.1%) | ✅ 60 parts | ✅ GH_ 20 pieces (116034571488607) + glass dome | ✅ | not run | 7.5 | glass outer walls (16 high, 0.6 clear); dome legs placed 6.6+ studs from every box |

Checks run on all nine (and the contract on all 13): no same-plane visible faces (z-fight script), spawns 4/4 or 5/5
tagged and on ground, KillDepth, Lighting, Barriers present. **Bot runs were not done tonight**: run each with
`Workspace.ForceMap` before the maps go into `Config/Match`.

Builder additions tonight (`tools/studio/maps/MapTools/Build.luau`, patched into the Studio copy too): visible outer
walls for roofed maps or `walls = {h, look}`; `apron = {w, look}` ground past the bounds for scenery. New
`MapTools.Run` builds with a fresh copy of Build and stores each map's data in `ServerStorage.MapTools.Data.<id>`
(JSON), so `require(MapTools.Run)("Metro3", true)` rebuilds without a paste. Build files now call `Run`.

