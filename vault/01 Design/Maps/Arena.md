# Arena + Big Arena (map redesign batch 1, 2026-11-16)

The default duel map and its 3v3 twin, first batch of the [release lineup](Map%20Lineup%20Brainstorm%202026-11-16.md). Learns from the RIVALS Arena / Big Arena ([study](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md) → Map studies → Arena), our own layout. Brief: [Maps Redesign prompt](../../04%20Tech/Prompts/2026-11-16%20Maps%20Redesign%20(RIVALS-clean).md).

## Owner calls (2026-11-16)
- **Name:** keep "Arena" (ids `Arena`, `BigArena`).
- **4v4 is not in the release:** large maps are `minTeam = 2, maxTeam = 3`.
- **Built from plain Roblox Parts, like RIVALS' Arena** ("keep it simple like rivals for this one"). No Blender kit for Arena / Big Arena; the kit pipeline is for the themed maps. The faceted-model rules don't apply to these two.
- **No gold or yellow accent.** Neutral cool grey like RIVALS' Arena; the read comes from the panel grid and the shapes.
- **No spawn nooks** (the old indents at the map ends): open-floor markers behind a spawn screen, with the [Spawn Hold](../Spawn%20Hold.md) (RIVALS-style ghost hold).

## Built (match place, edit mode; ForceMap only, not in `Config/Match` MAPS) — v2, grid-snapped
Owner round 2 (2026-11-16): "keep it simple like RIVALS… the same structure and sizing of parts… there's overlapping glitching parts… use the RIVALS texture". v1 (3/9/14-stud parts, extra colours, a gold-free band/cap on the Beacon, corner posts on Big Arena) was replaced by v2:
- **Sizes on the RIVALS module:** slabs 5 thick, lengths 10 / 15 / 20, full cover 10 high, low cover 3, decks +7 (+14 tower), every unrotated edge on a multiple of 5 so the grid lines run straight across neighbouring parts (two angled slabs per map, like RIVALS' turned arches).
- **Two colours only:** structure 151,153,163 (floor, walls, decks, ramps, frames, low walls, plinth) and blocks 132,134,143 (full-cover slabs and blocks, spawn screens, the pylon). SmoothPlastic.
- **Grid tile:** a match of the RIVALS Arena overlay (5-stud tile, thin seams, a plus cross at each joint, faint grain; Texture black at 0.75 on every face but the bottom). Our own image, `art-source/maps/Arena/textures/arena_grid_tile.png` → Image `rbxassetid://99198970022758` (decal 106150007798065), not a link to RIVALS' file (CLAUDE.md: never import their assets); swapping the id is one line if the owner wants theirs.
- **No overlaps:** Arena's long walls run full length and the end walls fit between them; Big Arena's 12 walls are mitred by length and alternate tops 0.05 apart; frame posts stop under the lintel. Studio check: 1,022 same-plane face pairs, 0 overlapping.

| | Arena | Big Arena |
|---|---|---|
| Where | `Workspace.Arena`, origin (4500, 200, 0) | `Workspace.BigArena`, origin (4500, 200, -600) |
| Court | 90 × 140, walls 5 thick and 30 high, bounds to +60 | 12-sided (apothem 108), one floor piece, walls 30 high, bounds to +80 |
| Spawns | 4 a side at (±5, ±60/65), gap **125** | 5 a side round (0, ±92), gap **184** |
| Parts | 48 (175 Textures) | 90 (335 Textures) |
| Landmark | the **Beacon**: a 5 × 5 pylon, 35 high, on a 20 × 20 +3 plinth | 45 high on a 25 × 25 plinth |
| Heights | floor, +3 plinth, +7 corner deck per team (ramp or climb) | floor, +3, +7 side deck (ramp/climb), +7 step deck → **+14 tower** (stair or from the step) |

**Lighting profile** (`Lighting` Configuration): ClockTime 13.2, Brightness 3, Exposure 0.1, Ambient 128,132,142, OutdoorAmbient 168,174,188; `LightingFx` Atmosphere (density 0.26, haze 1.0). `KillDepth` 40. `Barriers` is empty on purpose (no gates; see Spawn Hold).
**Not used for these two maps:** the Blender kit. A faceted kit test piece (panel slab, `tools/blender/maps_arena/arena_kit.py`, render `vault/02 Art/References/maps/arena/kit-test-panel-slab.png`) was built in the port-9930 Blender before the owner's call; it stays as a starting point for the themed maps.

## Layout checks (`python tools/maps/arena_layout.py`)
Plans are data in `tools/maps/arena_layout.py` (Arena, Big Arena, and the RIVALS Arena measured read-only as a calibration baseline, never built). It writes `vault/02 Art/References/maps/arena/*-layout.svg/png`, and `--luau arena bigarena` writes the Studio build data to `art-source/maps/Arena/greybox_*.luau` (builder: `tools/studio/maps/Arena/Greybox.luau`).

| Check | RIVALS Arena (calibration) | **Arena** | **Big Arena** |
|---|---|---|---|
| Spawn gap | 120 | **125** | **184** |
| Longest eye-height line | 144 (wall-hugging diagonal) | 126 (deck to deck, the designed power line) | 222 (through the middle; big maps allow ≤ 250) |
| Rays longer than 0.55 × gap | 18.3% | **16.2%** | 0% over 250 |
| Lanes across the middle (z −8 / 0 / +8) | 3 / 3 / 3 | 4 / 6 / 4 | 4 / 5 / 4 (z ±12) |
| Full / low cover pieces | 22 / 4 | 21 / 4 | 37 / 8 |
| Cover footprint, pieces per 1000 sq studs | 15%, 2.2 | 18%, 2.0 | 11%, 1.2 (**a bit open: review point**) |
| Pinch gaps < 6.5 | many (RIVALS doesn't care) | **0** | **0** |
| Enemy-half floor that sees a spawn | 0% | 1.7% | 0% |
| Spawn to centre / to enemy spawn (sprint 22) | 2.6 s / 6.6 s | ~2.7 s / ~6.5 s | 4.7 s / 9.7 s |
| First sight, head-on rush | 1.8 s | 2.6 s | 4.8 s (v1 had a 188-stud spawn-exit line on x = −26; the Beacon wing now blocks it) |
| Dead band (collidable 4-6 high) | – | none (frame posts 7.5 sit under the lintel) | none |
| Jump (ledge 7.5, Jump Audit) | – | cover is 9-10 (no unplanned perch); +7 deck climbable by design | +7 decks climbable; +14 only by stair or from +7 |

**Finding for the RIVALS study:** measured the same way (longest free line on a 1-stud grid), RIVALS' Arena has a 144-stud line, not 49; "longest line ≈ half the spawn gap" doesn't hold. The comparable number is the share of long rays (~18-20%).

## Playtest (Studio, bot, 2026-11-16)
Run on v1 (same lanes and spawns; v2 moved pieces ≤ 2.5 studs). `ForceMap = "Arena"`, `TestMode = false` for the run (both put back after: `TestMode = true`, `ForceMap = "OldTown2"`). The map loaded, player and bot spawned on the markers, both held through the ~26 s draft, then the bot ran the left lane (-19,-44) → (-25,0) → (-17,30) and reached our spawn screen ~7 s after GO with no stuck spots; the round reset back to the markers. Not tested: Big Arena in play, slide runs and Updraft / Crash Down clearance by hand. The ghost hold was tested on Arena afterwards (see Spawn Hold).

## Captures (local, `tool-results`; re-shoot for the review)
v2: Arena aerial, Arena spawn view (two-tone screen with the grid lining up into the floor, Beacon above), Big Arena aerial. R15 scale dummies (5.0 studs) at spawns, Beacon, decks and tower in `Workspace.ScaleDummies` (not part of the maps; delete before publishing).

## Test list (owner)
1. Studio, match place: Workspace attribute `ForceMap` = `Arena` (or `BigArena`), `TestMode` = false, Play. Put them back after.
2. Spawn view: does the screen + Beacon read well? Way out obvious?
3. Walk every lane; slide the long runs into cover; climb the +7 deck from the floor and by the ramp.
4. Updraft / Crash Down over the middle (open sky, bounds at +60 / +80).
5. Big Arena: the +14 tower (stair and from the step deck), the divider windows, the 12-gon edge.
6. Look: grid tile strength (Texture transparency 0.75), the two colours; does it read like the RIVALS Arena?
7. Before publishing: delete `Workspace.ScaleDummies`.

## Next
- Owner review of this batch (layouts + look). Then: add `{ id = "Arena", minTeam = 1, maxTeam = 2 }` and `{ id = "BigArena", minTeam = 2, maxTeam = 3 }` to `Config/Match` MAPS, plus `Ambience` / `MapLife` entries, and retire Whitebox / BigWhitebox.
- ~~Build the Spawn Hold code~~ **done 2026-11-16** ([Spawn Hold](../Spawn%20Hold.md)): players and bots stand still and show as ghosts through the select, checked on Arena with a bot.
- Batch 2: Pier + Dockyard (Blender kit, themed).
