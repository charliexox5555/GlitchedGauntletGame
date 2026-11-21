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
Builder: `tools/studio/maps/Port/Greybox.luau` → `Workspace.Pier` (4800, 200, 0) and `Workspace.Dockyard` (4800, 200, -600). Plain parts with the grid tile (deck grey, containers slate, crates tan, gantry and warehouse greys), a water plane 6 below, `KillDepth` 30, empty `Barriers`, a `Lighting` profile (Pier midday 13.5, Dockyard late afternoon 17.2). **Built 2026-11-16:** Pier 41 parts, Dockyard 73 parts. Same-plane check: 650 face pairs; the only overlap was each gantry beam ending flush with its legs' outer faces, fixed by shortening the beams to end inside the legs (Pier 85, Dockyard 120; builder and layout updated), so 0 now.

**Bot playtest (Pier, 2026-11-16):** `ForceMap = Pier`, `TestMode = false` for the run (put back to `true` / `OldTown2`). Player and bot spawned on the markers (±5, ±70), held through the draft and 3-2-1, then the bot ran the east lane (16,-51) → (13,-35) → our spawn with no stuck spots; the next round reset to the markers. Not played yet: Dockyard, the perches and the warehouse roof by hand, Updraft under the gantry.

## Kit test (Blender, port 9930)
`tools/blender/maps_port/port_kit.py` → `container()`: chamfered corner posts, top/bottom rails, angled-plate corrugation on the long sides and blind end, a two-leaf door end with three inset bands, four 6-sided lock bars, handle plates, hinges, corner castings. 30 × 10 × 10, **1,760 tris** (medium piece). Render: `vault/02 Art/References/maps/port/kit-test-container.png` (red and grey, one stacked, beside the R15 proxy). Next kit pieces: short container, gantry crane (truss legs, beam, trolley, hanging hook block), bollard, warehouse roof (corrugated, eaves), quay edge with a fender strip.

## Port kit v1 (built 2026-11-16)
Owner's go: "build the kit". Blender (port 9930): `tools/blender/maps_port/port_kit.py` + `port_pieces.py` (`build_all()`), run with `run_kit.py` (contact sheet `kit-sheet-v1.png`) and exported with `run_export.py` through `tools/blender/export_lobby_kit.py` → `art-source/maps/Port/Exports/Kit.fbx` (+ `Kit.json`), uploaded with `upload_models.py --maps Port` (asset **103877392135288**), installed with `kit_bundle.py Port Kit` into `ServerStorage.MapKit.Port` (11 pieces, 37 parts).

| Piece | Tris | Notes |
|---|---|---|
| ContainerGrey30 / Red30 / Grey25 / Grey20 / Red20 / Grey15 | 1,440-1,760 | the lengths the layouts use; red = the port accent |
| GantryPier / GantryDock | 1,232 / 1,400 | twin chamfered columns, ties and zigzag braces, box girder with flanges and stiffeners, red trolley, cables, hook block |
| WarehouseRoof | 508 | slab, corrugated sheet, fascia band |
| RoofStair | 680 | stringers with level-cut ends, a tread per stud of rise, posts and handrails |
| Bollard | 116 | 8-sided, decor |

**Mix (owner):** meshes for these; the quay deck, warehouse walls, crates and steps stay Roblox parts.

**Art pass:** `tools/studio/maps/Port/Art.luau` puts the kit on the greybox (Pier 11 containers + gantry + 12 bollards; Dockyard 19 containers + gantry + roof + 2 stairs + 24 bollards); the replaced greybox parts stay as invisible collision, so the play is what the bot test played. Fixes: the roof fascia shared the warehouse walls' outer faces between 11.8 and 12, so the walls are now 11.8 (layout and builder too). Captures: `pier-kit-aerial.jpg`, `pier-kit-exit.jpg`, `dockyard-kit-aerial.jpg` in `vault/02 Art/References/maps/port/`.

**Open points:** from a spawn marker the view is the spawn container 5-10 studs ahead (it hides the spawn; you step out to either side, where the gantry frames the middle). Moving it out pinches the cross container, so it's the owner's call. Not done yet: lighting pass per map, the quay edge (fender strip), crate meshes if the owner wants them, Dockyard playtest, blind score.

## Container fix: see-through ends (2026-11-20)
Owner: "the shipping containers are slightly see-through". **Cause:** in `tools/blender/maps_port/port_kit.py` the blind end was five separate rib prisms with a 0.16-stud slit between each (open from post to post, rail to rail), so daylight showed through every container end, plainly from inside (`container-fix-before-inside.jpg`). Not normals, transparency or a texture: each shell was closed, the gaps were between shells. The door leaves also left a 0.08 gap onto the hollow inside.
**Fix at the source:** the blind end is now one closed corrugated prism (`corrugated_end()`, same profile as the long sides); a door seal plate sits behind both leaves (its ends 0.05 inside the leaves and into the rails, so no shared faces). Checked in Blender with rays on a 400 × 5 grid through each end and 1,200 × 3 through the sides and roof of all six sizes: **0 misses** (before: 5 slits per end). Re-exported, re-uploaded (same asset 103877392135288, new version), reinstalled in `ServerStorage.MapKit.Port`, and all 30 placed containers swapped in place (Pier 11, Dockyard 19). Captures in `vault/02 Art/References/maps/port/`: `container-fix-before-end.jpg`, `-before-inside.jpg`, `-after-end.jpg`, `-after-inside.jpg`, `-after-door.jpg`, `-after-dockyard.jpg`. The door's faint horizontal lines in `-after-door` are its panel bands (they stay with shadows off), not gaps. Wharf (2026-11-20) uses the same fixed kit; its z-fight audit reads 0 with them.

## Concept prompts (owner pastes into ChatGPT; RIVALS-clean, our build style)
Shared style line for every prompt: *"Stylized Roblox shooter map, clean flat colours with faint texture, chunky readable shapes with chamfered edges and no rounded or bubbly forms, bright midday light with soft shadows, grey concrete structure with one accent colour, no text or logos, no characters."*
1. **Pier, hero view:** "Eye-level view from a spawn at the end of a long concrete pier: a crosswise red shipping container ahead, rows of grey and red containers forming three lanes, a big charcoal steel gantry crane straddling the middle of the pier, wooden crates as steps up onto a container top, calm blue water on both sides, low bollards along the edge. [style line]"
2. **Pier, top-down:** "Top-down plan of a 90 by 150 concrete pier with water on both sides, containers arranged with 180-degree rotational symmetry, a gantry crane across the middle, crate steps beside two container perches. Clean game-map illustration. [style line]"
3. **Dockyard, hero view:** "Late-afternoon container yard on a wide concrete quay: a corrugated warehouse with a flat roof deck and an outside stair on one flank, stacks of grey and red containers in three lanes, a long gantry crane over the middle lane, crate stacks, warm low sun and long soft shadows. [style line]"
4. **Kit sheet:** "Game asset sheet on a plain background: a 40-foot shipping container (red and grey variants) with corrugated sides and door end, a 20-foot container, a gantry crane leg and beam, a mooring bollard made of flat facets, a wooden crate in two heights, a corrugated warehouse roof edge, a quay edge with a rubber fender strip. [style line]"
5. **Palette swatch:** "Colour swatch board for a stylized port map: concrete greys, slate container grey, one container red accent, tan crate wood, dark charcoal steel, sea blue water; flat swatches with names. No text other than colour names."

## Test list (owner, once the greybox is built)
1. Both greyboxes are in the match place (`Workspace.Pier`, `Workspace.Dockyard`); save the place.
2. `ForceMap` = `Pier` (or `Dockyard`), `TestMode` = false, Play; put them back after.
3. Spawn hold at the container, then the lanes; climb the crate steps onto the +10 perch from both ends.
4. Dockyard: walk through the warehouse doors, up the outside stair and the crate route to the +14 roof.
5. Updraft under and around the gantry (beam at +25 / +29).
6. Say whether Dockyard needs more cover (it's lighter than RIVALS Docks).

## Next
Owner review of the dressed maps; then lighting, the Dockyard playtest, the blind score, and `Config/Match` entries on approval.
