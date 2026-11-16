# Pier + Dockyard (map redesign batch 2, 2026-11-16)

One port kit, two maps: **Pier** (regular, 1v1-2v2) and **Dockyard** (large, 2v2-3v3). Learns from RIVALS Docks ([study](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md) → Map studies → Docks); our own layouts. Roster: [Maps](00%20Maps.md) → Release roster (accent: red containers; landmark: the gantry crane). Spawns are open markers with the [Spawn Hold](../Spawn%20Hold.md), no nooks or gates.

## Owner calls (2026-11-16)
- **Meshes where shape matters, Roblox parts for the rest**, like RIVALS: Blender for containers, the gantry crane, bollards, the warehouse roof; Parts for the quay deck, plain walls, crates and steps.
- RIVALS' sizes, layouts and recipes can be followed closely; **no full copy**. Their meshes and images stay out (the file is a leaked copy; a match of the look is ours, as with the Arena grid tile).

## Layouts (`python tools/maps/port_layout.py`)
Kit module: container **10 × 10 × 30** (short 10 × 10 × 20), 10 high = full cover nobody jumps onto (ledge limit 7.5); crates 5 × 5 at **3.5** (low cover) or **7** (a step), so floor → 7 → container top 10 has no rise over 4; the gantry is the landmark (legs stand 1 stud above the beam; the beam is overhead, not walkable).

| Check | **Pier** | **Dockyard** |
|---|---|---|
| Deck | 90 × 150 pier, water both sides, bounds at the edge to +60 | 200 × 230 quay, bounds to +80 |
| Spawns | 4 a side behind a crosswise container, gap **135** | 5 a side behind a container, gap **203** |
| Longest eye-height line | 131 | 217 (≤ 250) |
| Long rays (> 0.55 × gap / > 250) | **8.2%** | 0% |
| Lanes across the middle | 2 (34-40 wide; a Firewall can close one) | 4-8 |
| Cover footprint / pieces per 1000 sq studs | 21%, 1.6 | 15%, 1.0 (**open for a port: review point**) |
| Pinch gaps < 6.5 | 0 | 0 |
| Heights | floor, crates +3.5 / +7, container-top perch +10 a side (crate steps at both ends) | floor, crates, container perch +10 (two crate steps), **warehouse roof +14** (outside stair, or crate → container → roof) |
| Enemy-half floor that sees a spawn | 0% | 2.5% |
| Sprint spawn → centre / → enemy spawn | 3.3 s / 7.3 s | 4.3 s / 10.0 s |
| First sight, head-on rush | 2.6 s | 4.0 s |

Plans: `vault/02 Art/References/maps/port/pier-layout.png`, `dockyard-layout.png` (+ SVG). Fixes made on the way: spawn exits that faced each other down one lane (crate stacks block it), containers 2.5-5.6 apart (now touching or 10+ apart), the Dockyard warehouse given real doors and two ways onto the roof, two 258-stud diagonals broken by crate stacks.

## Greybox (match place)
Builder: `tools/studio/maps/Port/Greybox.luau` → `Workspace.Pier` (4800, 200, 0) and `Workspace.Dockyard` (4800, 200, -600). Plain parts with the grid tile (deck grey, containers slate, crates tan, gantry and warehouse greys), a water plane 6 below, `KillDepth` 30, empty `Barriers`, a `Lighting` profile (Pier midday 13.5, Dockyard late afternoon 17.2). **Not built yet on 2026-11-16:** the owner was playtesting in the match place; run the file in edit mode.

## Kit test (Blender, port 9930)
`tools/blender/maps_port/port_kit.py` → `container()`: chamfered corner posts, top/bottom rails, angled-plate corrugation on the long sides and blind end, a two-leaf door end with three inset bands, four 6-sided lock bars, handle plates, hinges, corner castings. 30 × 10 × 10, **1,760 tris** (medium piece). Render: `vault/02 Art/References/maps/port/kit-test-container.png` (red and grey, one stacked, beside the R15 proxy). Next kit pieces: short container, gantry crane (truss legs, beam, trolley, hanging hook block), bollard, warehouse roof (corrugated, eaves), quay edge with a fender strip.

## Concept prompts (owner pastes into ChatGPT; RIVALS-clean, our build style)
Shared style line for every prompt: *"Stylized Roblox shooter map, clean flat colours with faint texture, chunky readable shapes with chamfered edges and no rounded or bubbly forms, bright midday light with soft shadows, grey concrete structure with one accent colour, no text or logos, no characters."*
1. **Pier, hero view:** "Eye-level view from a spawn at the end of a long concrete pier: a crosswise red shipping container ahead, rows of grey and red containers forming three lanes, a big charcoal steel gantry crane straddling the middle of the pier, wooden crates as steps up onto a container top, calm blue water on both sides, low bollards along the edge. [style line]"
2. **Pier, top-down:** "Top-down plan of a 90 by 150 concrete pier with water on both sides, containers arranged with 180-degree rotational symmetry, a gantry crane across the middle, crate steps beside two container perches. Clean game-map illustration. [style line]"
3. **Dockyard, hero view:** "Late-afternoon container yard on a wide concrete quay: a corrugated warehouse with a flat roof deck and an outside stair on one flank, stacks of grey and red containers in three lanes, a long gantry crane over the middle lane, crate stacks, warm low sun and long soft shadows. [style line]"
4. **Kit sheet:** "Game asset sheet on a plain background: a 40-foot shipping container (red and grey variants) with corrugated sides and door end, a 20-foot container, a gantry crane leg and beam, a mooring bollard made of flat facets, a wooden crate in two heights, a corrugated warehouse roof edge, a quay edge with a rubber fender strip. [style line]"
5. **Palette swatch:** "Colour swatch board for a stylized port map: concrete greys, slate container grey, one container red accent, tan crate wood, dark charcoal steel, sea blue water; flat swatches with names. No text other than colour names."

## Test list (owner, once the greybox is built)
1. Match place, edit mode: run `tools/studio/maps/Port/Greybox.luau` if `Workspace.Pier` is missing.
2. `ForceMap` = `Pier` (or `Dockyard`), `TestMode` = false, Play; put them back after.
3. Spawn hold at the container, then the lanes; climb the crate steps onto the +10 perch from both ends.
4. Dockyard: walk through the warehouse doors, up the outside stair and the crate route to the +14 roof.
5. Updraft under and around the gantry (beam at +25 / +29).
6. Say whether Dockyard needs more cover (it's lighter than RIVALS Docks).

## Next
Owner review of the layouts, the container test and the concepts; then the full port kit in Blender (export → Open Cloud → `put()` on the greybox), lighting, audits, the bot playtest, and `Config/Match` entries on approval.
