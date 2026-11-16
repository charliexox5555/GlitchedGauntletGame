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

## Status
| Map | Layout | Greybox | Kit | Lighting | Bot run | Grade | Notes |
|---|---|---|---|---|---|---|---|
| Rooftops | ✅ alley + 3 bridges, billboards over the gap; long rays 32% | ✅ 45 parts | | | | | |
| Courtyard | ✅ first sight 1.6 s (plaza; review point) | ✅ 44 parts | | | | | |
| Bunker | ✅ shaft room, generator blocks door lines | ✅ 43 parts, roof +14 with the shaft open | | | | | |
| Foundry | ✅ first sight 1.5 s (review point) | ✅ 43 parts, molten channel (Neon) | | | | | |
| Snowpeak | ✅ | ✅ 42 parts | | | | | |
| Model Kit | ✅ | ✅ 39 parts | | | | | |
| Old Town | ✅ one 260 line (0.2% of rays) | ✅ 46 parts | | | | | |
| Metro | ✅ rebuilt as platforms + concourse | ✅ 64 parts, roof +22 with skylights | | | | | |
| Greenhouse | ✅ one 278 line (0.1%) | ✅ 60 parts | | | | | |
