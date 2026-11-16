# Map lineup brainstorm (2026-11-16)

A brainstorm for redesigning every map, built on the [RIVALS map study](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md) (measured numbers for ~25 maps) and our own concepts ([Maps hub](00%20Maps.md)). Nothing is decided yet: the owner picks the list and answers the questions at the bottom, and then a maps session gets its prompt.

## Why RIVALS maps work
1. **One idea per map, readable in a second.** Docks, Construction, Chess, Backrooms, Iceberg, Splash: the theme is one word. The structure is grey with **one accent colour** on cover and landmarks (red containers, orange beams). Saturated maps make the silhouette the whole look.
2. **Duel size and Big size of the same map.** Arena / Big Arena, Splash / Big Splash, Backrooms, Station, Graveyard and Onyx each come in two sizes. One kit makes two maps, so content is cheap and players learn the theme once.
3. **Fast contact.** Duel maps put spawns **120-160 apart** (about 4-5 s to first sight at 16 studs/s). Mid maps 180-200, 4v4 maps 220-380.
4. **Sightlines are short on purpose.** The longest one is about **half the spawn gap** on small maps (Arena 49 vs 121, Construction 75 vs 125). Big maps allow 130-250 on one or two marked lines.
5. **Cover is mostly full cover.** About 25-35% of the eye-height area on duel maps, roughly one piece per 400-600 sq studs, and Arena has 22 full pieces to 4 low. You peek, you don't stand behind waist-high walls.
6. **Mostly flat with a few height levels.** 85-90% of the area is floor. Steps +3 to +5, platforms +9/+10, and one or two decks +15 to +25. Height is a reward spot, not a maze.
7. **3-5 open lanes across the middle.** Fewer than 2 turns into a corridor fight.
8. **Cheap to build, cheap to run.** Arena is 68 parts. Docks is 1,042 MeshParts but only 98 unique meshes, sorted in category folders. Edges are raw blocks; the read comes from colour and shape, not detail.
9. **Gimmick maps keep it fresh.** Chess (giant board), Playground (toy scale), Dimension (portals), Onyx (lava arena), Backrooms (liminal).
10. **Lighting is a profile, not baked into the map.** Each map has a sky + atmosphere profile, plus match-point and sudden-death variants.

**What this means for us:** our earlier maps went for heavy detail (worn Valorant-level materials) and stalled waiting for approval. RIVALS shows that **clarity, size discipline and kit reuse** carry a map, and detail is a bonus. Our faceted rules (no round shapes, carved ends) still apply on top.

## Our game's extra needs
- **Slide is the core move:** give each map long flat runs, about 20+ studs (a slide covers ~20 at 30 studs/s over 0.85 s), into cover.
- **Mods:**
  - Updraft and Crash Down need open sky or ceilings 30+ high over the middle;
  - Firewall and Frost Wall need lanes wider than the wall;
  - Recall and Dash want flank loops.
- **Jumping:** ledges at most 7.5, gaps at most 9 ([Jump Audit](Jump%20Audit%202026-11-13.md)).
- **Symmetry:** 180° rotational, not mirrored. Spawns are out of sight. Two exits per room.

## Proposed lineup
Each line pairs one of our concepts or a new one with the RIVALS map it learns from. **D** = duel size (1v1-2v2), **B** = big size (3v3-4v4).

| # | Map | Sizes | Learns from | Idea and our twist | Accent |
|---|---|---|---|---|---|
| 1 | **Proving Grounds** (Whitebox v2) | D + B | Arena / Big Arena | The default and tutorial map: faceted panel arena under open sky, 22 full-cover blocks, one grid trim. 100×140 → ~200 for B. Fastest to build. | gold |
| 2 | **Dockyard** | B + D cut ("Pier") | Docks | Container port at dusk. A container kit (one mesh, many colours) and a gantry crane over the middle. The Pier is the duel slice of the same map. | red containers |
| 3 | **Rooftops** | D | Construction | Two team roofs over a Pit with a water tower, a building site with a crane deck at +15-22. Our vertical duel map, for Updraft and Crash Down. | orange |
| 4 | **Metro** | B | Station | Station with two platforms, a sunken track lane with parked trains as cover, and a terrace over each end. | yellow line |
| 5 | **Snowpeak** | D + B | Village / Iceberg | Ski lodge in a snowy saddle with gondola stations on the flanks. D = lodge and yard, B = adds the slopes. | red lodge trim |
| 6 | **Greenhouse** | B | Museum / Dimension (interiors) | Glass halls, a dome over a fountain, gallery and bridge. Our most unique theme: keep it. | green glass |
| 7 | **Old Town** | B | Westown / Village | Stone plaza with arcades, alleys and a clock-tower landmark. A long marked sightline down the main street. | terracotta |
| 8 | **Bunker** | D | Backrooms / Gate | Tight concrete corridors around a light shaft. The close-range shotgun map, and it ties to the lobby's bunker look. | white light |
| 9 | **Foundry** (new) | D + B | Factory + Onyx | Steel works with a **molten channel** as a kill hazard (the InstakillOOB convention), catwalks at +10/+20, and amber light. | molten orange |
| 10 | **Gallery** (new) | B | Museum | Art museum after hours: marble halls, glass cases, skylights, 3 spawn groups. Rewards flank loops (Recall, Dash). | deep red banners |
| 11 | **Quarry** (new) | B | Crossroads / Iceberg | Open pit with stepped plateaus and haul trucks as cover: the long-range 4v4 map, with marked sniper lines. | yellow machines |
| 12 | **Model Kit** (new gimmick) | D | Playground / Chess (scale gimmick) | Giant scale: players fight on a hobby workbench (glue pots, sprue frames, cutting mat grid). Bright, the fun one. | cutting-mat green |

**Suggested launch set (6):** Proving Grounds D+B, Dockyard (+ Pier), Rooftops, Metro, Snowpeak, Foundry. That covers every mode and size, two theme kits that make two maps each, and one hazard map. Greenhouse, Old Town, Bunker, Gallery, Quarry and Model Kit come after.

## How a maps session would build them
1. **Study:** in the RIVALS file (`ServerStorage.Maps`, read-only), the matching map for each of ours: spawn view, lanes, cover rhythm, heights and the accent. Numbers go in the study note.
2. **Layout:** a layout script prints spawn gap, sightlines, lane count and route times against the rules above. Then a greybox and a play test with bots.
3. **Concept:** ChatGPT concepts for each map, approved by the owner (concept-first lock).
4. **Build:** a kit per theme (Blender MCP, faceted, standalone meshes), reused for the D and B sizes, plus a lighting profile per map.
5. **Check:** the Map Quality Standard audit (z-fighting, floating, mesh cap), score 9+, and the owner approves.

## Questions for the owner
1. ~~**Detail level.**~~ **Answered 2026-11-16: RIVALS-clean.** The Maps lock (2026-11-05) says Valorant-level worn detail. The lobby just moved to the RIVALS look (2026-11-16). Do maps follow: **RIVALS-clean** (flat colours, clear shapes, faint textures; fast to build) or keep **Valorant detail**?
2. **Two sizes per theme** (duel + big from one kit)?
3. **The list:** which of the 12 to keep, cut or add? Is the launch set of 6 right?
4. **Old builds:** start fresh from the layouts, or reuse any built v2 map (Dockyard2, Metro2, Snowpeak2…)?
