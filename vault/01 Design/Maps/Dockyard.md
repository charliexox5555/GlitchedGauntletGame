# Dockyard

A container terminal on a pier at dusk: three lanes of stacked shipping containers, a yellow gantry crane over the middle, a corrugated shed on each flank, and the harbour on both sides. Outdoor, medium-large, built to play from 1v1 up to 4v4 (like RIVALS' Docks and Station). See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** concept, layout (checked), greybox script, Blender kit, art and lighting scripts written by a parallel map session. **Not yet run in Studio**: the hub runs the scripts, screenshots and iterates (run order at the end). Map id `Dockyard`, world origin **(-1500, 200, 0)**.

---

## 1. One line
Hold the stacks: a dusk container yard where every lane has its own colour, the crane tells you where the middle is, and the only way to the top of the yard is a ramp, a crate or an Updraft.

### What it should feel like
- **A real place, read in a second.** Containers are the cover, and their colour tells you the lane: **red west, blue middle, green east**. "Two in red, one on green high" is a full callout.
- **Two heights of fight.** The ground between the stacks (shotguns, SMGs, corners every 8–16 studs) and the stack tops at 8 (rifles, the high lane), with a few 16-high tops you only reach by Updraft.
- **Every size works.** 1v1 meets in the middle in about 5 s; 4v4 spreads over three lanes and two sheds without anyone being stuck in a corridor.
- **Dusk.** Silhouettes of cranes and stacks against an orange-to-violet sky, warm sodium lamps pooling on the deck, cool shadows between the stacks.

### Not this
Grime and rust everywhere (it's a clean, working terminal), random container colours (colour is a language here), a maze (every block is a container you can see over from the high lane), a night map you can't see enemies in, invisible walls, swimming.

---

## 2. References
Images of other games stay out of the repo (the `third-party/` folder is git-ignored); the sources are linked here.

| Reference | Take |
|---|---|
| [RIVALS: Docks](https://robloxrivals.fandom.com/wiki/Docks) (wiki, map list) | The RIVALS precedent for a port map that works at every team size: simple shapes, readable colour blocks, no clutter |
| [Call of Duty: Shipment](https://en.wikipedia.org/wiki/Shipment_(Call_of_Duty)) and [Activision's Shipment map intel](https://blog.activision.com/call-of-duty/2019-12/Modern-Warfare-Tactical-Map-Intel-Shipment) | Containers as the whole kit; three lanes; a barrel lets you mantle onto a stack. We copy the "small step up to the stack top" (our step crate), not the size: Shipment is a 6v6 meat grinder, Dockyard is three times its size |
| [critpoints: Good FPS Map Design](https://critpoints.net/2018/02/18/good-fps-map-design/) | Loops: every lane connects to its neighbours at least twice (middle band, crossings at the dividers), so nobody is funnelled |
| [Intermodal container](https://en.wikipedia.org/wiki/Intermodal_container) | Real 40 ft / 20 ft boxes: 12.2 × 2.44 × 2.59 m. At our scale (a 5.4-stud avatar) that is about 33 × 7 × 7 studs; we round to **32 × 8 × 8** and **16 × 8 × 8** so stacks land on the 8-stud layers |
| [Rubber-tyred gantry crane](https://en.wikipedia.org/wiki/Gantry_crane) and [container crane](https://en.wikipedia.org/wiki/Container_crane) | The landmark: an RTG straddles container rows on four legs (ours spans the middle lane, legs on the divider lines). The big ship-to-shore cranes stand out in the harbour as the skyline |
| Port photography at dusk (search "container terminal dusk sodium lights") | The palette: high-mast sodium lamps (~2000 K orange) against a violet sky; containers keep their colour in the lamp pools and go to silhouette elsewhere |

### What the LihFolk notes add
- Zone hue discipline: each zone one dominant hue plus neutrals, saturation on the gameplay pieces, never on the ground ([World Composition](../../LihFolk/06%20World%20Building%20and%20Art/World%20Composition%20and%20Set%20Dressing%20-%20Designed,%20Not%20Scattered.md)).
- Golden-hour / dusk preset as the starting point (ClockTime ~17.6–18.2, warm ColorShift, purple decay); real lights only at focal points, shadowless; Neon for everything else (Stylized Lighting Recipes).
- Phones below quality 4 have no shadows: the lanes must read by colour and value alone, which the lane hues do.

---

## 3. Layout
![Dockyard layout](../../02%20Art/References/maps/dockyard/dockyard-layout.svg)

Generated and checked by `tools/maps/dockyard_layout.py` (`--luau` also writes the greybox data). **Symmetry:** 180° rotation (team A at -Z, team B at +Z). **Shape:** a 136 × 184 container yard on a pier, harbour water on both long sides, a 7-high container wall at each end with the spawn alcove (36 × 18) cut into it.

### Lanes (as team B sees them; team A's are the same, rotated)
| Lane | Colour | Your half | Their half |
|---|---|---|---|
| **West** | Red containers | The **apron**: the open quay along the water. Scattered boxes, crates on the quay line, the **Tower** (2-high, Updraft only) by your spawn | Their **Shed** (Red Shed): a corrugated warehouse, close range, a roller door to the middle and two doors to the alley |
| **Middle** | Blue containers | A slalom of 20-footers alternately touching the two dividers, then the 2-high spawn baffle | The **Crane yard**: the 2-high **Crane stack** under the gantry, with a 1-high step on each side |
| **East** | Green containers | Your **Shed** (Green Shed) and the alley beside it | Their apron |

The **dividers** between the lanes are 40-footers (top at 8: the **high lane**). Your east divider has a steel stair up from the spawn side; your west divider has a step crate in its corner. Between the dividers and the crane legs, the **middle band** (the crane alley) crosses the whole yard: every lane meets it, so rotating between lanes is always one short run.

| Piece | Size (studs) | Job |
|---|---|---|
| **Crane stack** (centre) | 32 × 8, 16 tall (2-high) | Blocks the spawn-to-spawn axis; its top is an Updraft-only hot seat that sees 61% of the floor and is seen from everywhere |
| **Gantry crane** | legs at (±30, ±16), girders at 52–56 | The landmark. Legs are cover; the girders are out of reach (highest reach is 51.2) |
| **Crane boxes** | 20 ft under the crane on each divider line | Cut the long diagonals across the middle band |
| **Dividers + stair** | 40 ft, top 8; stair 8 × 16 | The high lane, one per lane boundary per half; each team's two face each other across the crane |
| **Mid boxes, post box** | 20 ft | The mid slalom: no straight line along either lane edge |
| **Sheds** | 26 × 36, walls 16, gable to 22 | The close-range rooms: rack (full cover), office, crates; three doors |
| **Shed screen** | 20 ft in front of the roller door | Stops the roller door from seeing across the whole middle |
| **Apron gate box, Apron box + Quay box** | 20 ft | Kink the line out of the enemy Shed alley and cut the quay line, so the apron has one long line (the quay) and no line out of the alley into your spawn approach |
| **Quay barrier** | 2 thick, 3 tall | Low cover along the water; stops dashes. Over it is the harbour |
| **End walls** | 7-high containers (56) | Close the ends without invisible walls: 56 is above anyone's reach |

### Measured (from the script)
| Check | Result | Target |
|---|---|---|
| Gaps under 6 studs between pieces | none | none (Game Plan: doors and gaps ≥ 6) |
| Spawn sees enemy spawn | never | never |
| Enemy-half floor / stack tops that can see a spawn | 0% / 0% | ~0 |
| Spawn to spawn | 200 straight, 226 walked (10.3 s sprint) | 170–220 straight |
| Spawn to the middle | 141 studs, 6.4 s sprint / 8.8 s walk | — |
| Both teams sprinting meet after | 5.1 s (walking 7.1 s) | contact ~10 s at walking pace with fighting on the way |
| **First sight** (both teams leave at t = 0) | **3.8 s sprinting, 5.2 s walking**: the alley mouth by your Shed and their apron | 5–8 s |
| Longest lines | the quay line per side (~114), your Shed alley line (116, ends at the gate box), one lateral diagonal across the crane alley (138) | at most one long line per side, breakable |
| Rays over 100 / over 70 studs | 0.6% / 6.5% | Whitebox: 6.4% over 70 |
| Distance to full cover | average 4.6, worst 17.9 (on the open quay) | worst under ~15 except the long lane |
| Highest reach | 16 + 7.2 jump + 28 Updraft = 51.2 | under the crane girders (52) and end walls (56) |

These are flat checks at standing eye height plus a 3D line test from every stack top. They don't replace walking it.

**Rules this bends:**
- **First sight at 3.8 s when both teams sprint flat out** (5.2 s walking). A 200-stud map can't hold everyone apart for 5 s at 22 studs/s; the first glimpse is a long diagonal (~75 studs) across the middle band, which is a reasonable opener. More cover there would close the middle band, which is the lane-rotation route.
- **The quay line (~114) and the Shed alley line (116)** run past the Game Plan's ~70. Like Whitebox's diagonals, they are the marksman lines, one family per side, and each ends at a box you can stand behind.
- **The Shed roof** (16–22) and the **Crane stack / Tower tops** (16) are Updraft-only perches above the high lane. They see a lot and are seen by everyone; the spawn baffle is 2-high so neither roof nor top sees a spawn.

### Abilities on this size
| Ability | Fit |
|---|---|
| **Dash** (12–24) | Crosses the 8-stud bays and the gap between a divider top and the next box top; can't clear the quay barrier from a standstill into the water by accident (the barrier stops a dash) |
| **Updraft** (14–28) | The only way onto the 16 tops and the Shed roofs; a 14 Updraft from the ground reaches a stack top at 8 |
| **Walls** | A Firewall (40 × 10) seals a lane between dividers (they are 52 apart centre to centre): strong in the middle band, weak on the apron |
| **Molly** | Clears a Shed doorway or the corner of a stack; the bays are a molly's natural target |
| **Recall** (anchors) | 141 studs to the middle: an anchor can't reach from spawn, so it stays a choice |

### Falling in the harbour
Over the quay barrier is open water about 9 studs below the deck. The water is a non-colliding, non-query surface, so a player who jumps or Dashes over falls through it and dies when they pass `Workspace.FallenPartsDestroyHeight` (default −500; about 2.7 s after leaving the deck at this origin). **Suggestion for the hub:** a map kill height in MapService (for example origin Y − 30) would make the fall instant and count it properly; Rooftops needs the same. No invisible walls: the barrier is real, 3 tall, and shoots like cover.

---

## 4. Look
| Part | Colour | Note |
|---|---|---|
| **West containers** | rust red `#9A3B2E` | the lane colour; slight per-box value shift (±6%) |
| **Middle containers** | cobalt blue `#2F5E9E` | |
| **East containers** | green `#3E7D4F` | |
| End walls | mixed muted containers: grey `#6E7277`, cream `#C9C2B0`, dark blue, dark red, teal | the background: lower saturation than the lane colours |
| Gantry crane | safety yellow `#E0AE2E`, black/yellow hazard bands on the legs | the landmark, the most saturated thing on the map |
| Deck | asphalt `#4A4A4C` with yellow bay lines `#D9B23A` every 16, white bay numbers | value below every container so cover always reads |
| Quay | concrete `#9C988F`, black rubber fenders, yellow-black edge | |
| Sheds | corrugated cladding blue-grey `#5C6670` on a concrete plinth, a stripe of the lane colour, "RED SHED" / "GREEN SHED" | |
| Lamps | sodium `#FFB45C` heads (Neon), PointLights at the focal points | |
| Water | deep teal-violet `#1E2A44`, slightly reflective | |

Team colours (cyan `#00E5FF`, orange-red `#FF5A36`) stay reserved for players and abilities; the red lane is a dark rust, never orange-red.

**Lighting mood:** dusk, the sun on the horizon down the X axis (across the pier, so neither team looks into it), ClockTime ~18.1, GeographicLatitude 0 (so the sun sets exactly along X: check `Lighting:GetSunDirection()` in Studio). Warm low sun and ColorShift, violet ambient and atmosphere decay, sodium lamp pools at the crane, the sheds and the stair heads. Lit faces about twice the shaded ones; enemies (players) must stay readable against containers in shade, so OutdoorAmbient stays fairly high.

### Built with
| Use | For |
|---|---|
| **Roblox Parts** (greybox) | Everything you walk on or shoot: deck, containers, dividers, walls, ramps, barrier. Hidden where the art covers them, never deleted |
| **Blender kit** (`Kit_Dockyard.blend`, one upload) | The look: 40 ft and 20 ft containers (one mesh each, tinted per instance), the stair, the gantry crane, the Shed, rack, office, crates, quay barrier and quay face, bollards, high-mast lamps, a ship-to-shore crane and a ship for the skyline |

### Budget (mobile)
≤ 500k visible triangles; ≤ 20k per mesh; reuse meshes (every container is one of two meshes); Box collision on everything; CastShadow off on small parts (kit_bundle does this under 8 studs); no textures beyond Roblox materials; ≤ 12 lights, all shadowless.

---

## 5. Build and run order
Built 2026-11-03 by a parallel map session (no Studio): the hub runs it.
1. Layout: `python tools/maps/dockyard_layout.py --luau` (prints the checks, writes the SVG and the greybox data).
2. Greybox: `python tools/studio/maps/bundle.py Dockyard Greybox -o dockyard_greybox.luau`, run in the match place (edit mode).
3. Kit: `blender --background --factory-startup --python tools/blender/build_map_kit_dockyard.py` → `art-source/maps/Dockyard/Kit_Dockyard.blend` + contact sheets; export `-- --maps Dockyard Kit`; upload `python tools/opencloud/upload_models.py --maps Dockyard --group 11116787 Kit`.
4. Install the kit: `python tools/studio/maps/kit_bundle.py Dockyard Kit -o dockyard_kit.luau`, run in the match place.
5. Art + lighting: `python tools/studio/maps/bundle.py Dockyard Art Lighting -o dockyard_art.luau`, run in the match place.
6. Check: walk it, screenshots from each spawn, the middle, a stack top and an overview; the mobile budget; save the place and back up `art-source/maps/Dockyard/Dockyard.rbxm`.
