# Dockyard2 (redesign of Dockyard)

The 2026-11-05 redesign of [Dockyard](Dockyard.md) in the new environment style ([Lobby Style Guide](../../02%20Art/Lobby%20Style%20Guide.md), [Art Direction](../../02%20Art/Art%20Direction.md) → direction change 2026-11-04). Same idea: a container pier with three lanes, a gantry crane over the middle and a Shed on each flank, for 1v1 to 4v4. Built next to the old map, which stays untouched. **Not in the match rotation** until the user approves the swap; in Studio set the Workspace attribute `ForceMap = "Dockyard2"`. Lane G of the [Day Plan 2026-11-05](../../05%20Production/Day%20Plan%202026-11-05.md).

**Map id** `Dockyard2`. **World origin (-3000, 200, 0).** These origins are already taken: Whitebox (0, 200, 0), Big Whitebox (0, 200, -1500), Dockyard (-1500, 200, 0), Metro (1500, 200, 0), Old Town (0, 200, 1500), Greenhouse (1500, 200, -1500), Rooftops (1500, 200, 1500), Bunker (-1500, 200, 1500) and Snowpeak (-1500, 200, -1500).

**Status (2026-11-05, lane G):** all 8 phases done.
- Built in the match place: greybox, kit (asset 127619569582290, 26 pieces), art and lighting.
- **Audit 0** (0 z-fighting pairs over 1,940 visible parts).
- **Blind score 8.75 / 10** (3 reviewers, medians; first draft 5.4, 3 fix rounds).
- Playable with `Workspace.ForceMap = "Dockyard2"`, and not in the rotation (`Config/Match` has a one-line comment only).
- ⚠ **The match place is not saved yet.** Computer use for Studio was denied, so whoever holds the match Studio must press **Ctrl+S (Save to Roblox)**. The `.rbxm` backups are also not made: MCP code can't reach localhost, so use Studio's Save to File.

![Dockyard2 from the B spawn](../../02%20Art/References/maps/dockyard2/r3-b-spawn.jpg)
![The middle from a container top](../../02%20Art/References/maps/dockyard2/r3-middle-high-lane.jpg)

---

## 1. What's wrong with the old Dockyard
These come from its renders, its note and a rerun of `tools/maps/dockyard_layout.py`.

| Problem | Evidence | Fix in Dockyard2 |
|---|---|---|
| **Too dark and too realistic.** Dusk (orange to violet), corrugated realistic containers, sodium lamps. The blue and green containers go muddy in shade, and the user called the maps "too tactical and realistic". | [From the B spawn](../../02%20Art/References/maps/dockyard/dockyard-preview-from-b-spawn.jpg); the note had to raise the ambient after the first test | Bright afternoon and a stylized kit, with lighting that does the contrast (§4) |
| **A dominant hot seat.** The 2-high Crane stack (top at 16, Updraft only) sees **61%** of the floor. LihFolk: "a single high ledge with a view over the whole map becomes the only place anyone stands". | layout script, high-lane table | 1-high stack climbed from two crates; it sees 40% (change 1) |
| **First sight at 3.8 s** sprinting: a 73-stud diagonal from your own apron into the enemy Shed alley | `first_sight` | Closed. The first look is now across the middle at ~42 studs, at 4.3 s (change 2) |
| **A Shed sees out of its roller door all the way up the far apron, and the apron sees in** | the Shed screen covered only part of the door | Roller door moved behind the screen (change 3) |
| **The open quay.** Two 3.5 crates on a 114-stud line; worst distance to full cover was 17.9 | cover spread | One full-cover Quay stack with a 6-wide quay walk beside it (change 4) |
| **A 138-stud lateral line** across the middle band | longest lines | Apron box moved into the band; the line is now 122 and threads five gaps (change 4) |
| **Flank routes 1 s slower than the middle** (248 vs 226) | routes | Now 247 vs 237, within 0.5 s (change 5) |
| Visual noise: 7-high multicoloured end walls and a high-contrast corrugation on every box | renders | Calm, lighter backdrop stacks in desaturated tones; broad, few ribs on the containers (§4) |

What the old map gets right, and Dockyard2 keeps: lane colour as a callout language (red, blue, green), two heights of fight (ground and stack tops at 8), the middle band as the lane-rotation route, spawns out of every sightline (0%), and closing the ends with containers out of reach instead of invisible walls.

## 2. References
Images of other games stay out of the repo. Sources were checked on 2026-11-05.

| Reference | What to take |
|---|---|
| [Valorant Icebox breakdown (ONE Esports)](https://www.oneesports.gg/valorant/full-breakdown-of-icebox-valorants-act-iii-map/), [Icebox guide (Beebom)](https://beebom.com/valorant-icebox-map-guide) | The closest style target: stylized containers with clean bevels and painted colour, yellow cranes, a short mid. **Colour-named callouts** ("Green", "Yellow", "Orange") are exactly our lane language. |
| Splatoon *Port Mackerel* ([Inkipedia](https://splatoonwiki.org/wiki/Port_Mackerel); the page blocks bots) | A bright stylized container yard with three paths through a grid of containers and **three cross links through the centre**; climbable boxes. Our middle band plus the crossings at the dividers do the same job. |
| [RIVALS Docks (wiki)](https://robloxrivals.fandom.com/wiki/Docks), [Legacy Docks](https://robloxrivals.fandom.com/wiki/Legacy_Docks) | The RIVALS port map: a concrete pier ringed by water, climbable buildings, an out-of-bounds crane and terminal as the skyline. RIVALS also **redesigned** its Docks, a precedent for a v2 next to the old one. |
| [Overwatch 2 map design (Blizzard)](https://news.blizzard.com/en-us/article/23785339/uniting-gameplay-and-style-behind-overwatch-2-s-complex-map-design), [Oasis design (Game Developer)](https://gamedeveloper.com/design/learn-how-blizzard-designed-i-overwatch-s-i-oasis-map) | Art guides players to the objective. Symmetric maps tell their sides apart with colour and signage (our two Sheds: a red one and a green one). An "arena in an arena" with a ring around it spreads fights (the crane court with the lanes around it). |
| [RTG crane](https://en.wikipedia.org/wiki/Rubber_tyred_gantry_crane), [container crane](https://en.wikipedia.org/wiki/Container_crane), [Commons: gantry cranes](https://commons.wikimedia.org/wiki/Category:Gantry_cranes), [Belfast terminal](https://commons.wikimedia.org/wiki/File:Belfast_Container_Terminal,_April_2019.jpg), [Commons: container terminals](https://commons.wikimedia.org/wiki/Category:Container_terminals) | Real shapes in a sunny palette: the RTG portal (four legs on bogies, a box girder, a cab and a spreader), the ship-to-shore crane silhouette for the skyline, stack rhythm and lane widths. |
| [Intermodal container](https://en.wikipedia.org/wiki/Intermodal_container) | Proportions: 20 / 40 ft × 8 × 8.5 ft, 32 × 8 × 8 and 16 × 8 × 8 studs at our scale (kept). The corner castings and posts become the bevel and trim detail. |
| [Lobby Style Guide](../../02%20Art/Lobby%20Style%20Guide.md) and its renders ([spawn](../../02%20Art/References/lobby/rebuild-20261104/01-spawn.jpg), [Duels hall](../../02%20Art/References/lobby/rebuild-20261104/02-duels-hall.jpg), [kit sheet](../../02%20Art/References/lobby/rebuild-20261104/bunker2-sheet-a.jpg)) | The kit language: designed profiles, stepped plinths and collars, picture-frame openings, a bevel hierarchy, layering, clean SmoothPlastic trims, calm textures on big surfaces, Montserrat Black signs. |
| Counter-example: [a realistic container port (80.lv)](https://80.lv/articles/have-a-look-at-this-detailed-and-realistic-container-port) | What not to do: rain, rust and realism. Used for yard layout only. |

### What the LihFolk notes add (cited)
- **Layout.** Three lanes: fast and exposed, slow and covered, and vertical or interior. Mirror the long sightlines. Keep no single dominant perch. Cover is 2.5–3.5 (low) or 7+ (full), never 4–6. Spawns face a landmark. Keep route times within ~1 s. (*Combat Arena and Encounter Layout* §2 and §6, *Objective Mode Maps*, *Spawn Points Safe Zones and Respawn Flow*, *Genre Playbook - Shooters FPS and TPS*, all in `LihFolk/33 Level Design` and `10 Game Design and Genres`.)
- **Landmark.** One global landmark that covers 3–5° of view, has a unique black silhouette and is seen in the first frame after spawning. The crane is that landmark; its girders (52–56) are out of reach (*Level Design Principles - Flow Sightlines and Landmarks*).
- **Modelling.** Bevels of 1–6% of the form, ~0.15–0.3 at 40 studs. Above 6–8% looks inflated and toy-like. Primary, secondary and tertiary masses differ by 2–3×. Spend triangles on silhouettes. A trim must be ≥ d/170 thick to survive distance. (*Bevels Chamfers and Edge Highlights Without Textures*, *Shape Language and Silhouette Testing*, *Proportion Exaggeration and Gameplay Distance*, *Spending Triangles Where the Camera Looks*, in `54 Untextured Stylised Modelling` and `55 Modelling Nuance and Readability`.)
- **Colour and value.** 3–5 value bands at about 60/30/10. The ground is mid to dark-mid (V 35–60%). Structures sit one band away. Characters must separate from both. One dominant hue plus neutrals plus one small accent. Check in greyscale. (*Colour Scripts and Value Structure for Untextured Art*, *Environment Art Styles*, `44 Materials and Surfaces` / `06 World Building and Art`.)
- **Light.** The "Bright cartoon" recipe (§3.1) is the base. The sun sits 30–50° up at a quarter angle. Lit faces are 1.5–2.5× the shade. Bloom threshold ≥ 1.2. Local lights are shadowless, and we raise their range, not their brightness. (*Stylized Lighting Recipes*, *Lighting Untextured Art in Roblox*, *Atmosphere Sky Clouds and Post-Processing*, *Light Sources and Shadows*, `07 Lighting VFX and Audio`.)
- **Craft.** One shared palette and material set, light as wayfinding, an identity you can read from one frame, budgets set first (*What Craft Looks Like on Roblox - Lessons from Top Studios*, `60 High-Craft Game Teardowns`; *Teardown - Phantom Forces*: simple world geometry, strong silhouettes).

## 3. Layout (checked)
![Dockyard2 layout](../../02%20Art/References/maps/dockyard2/dockyard2-layout.svg)

`python tools/maps/dockyard2_layout.py [--luau]` holds the plan as data, prints the checks, writes the SVG and, with `--luau`, the greybox data. Its docstring lists every change. Symmetry: 180° rotation (team A at -Z, B at +Z). Size: the same 136 × 184 pier and 36 × 18 spawn alcoves, because it already plays from 1v1 to 4v4.

| Check | Dockyard | **Dockyard2** | Target |
|---|---|---|---|
| Spawn sees spawn; enemy floor or tops that see a spawn | never; 0% / 0% | never; 0% / 0% | ~0 |
| First sight, sprinting / walking | 3.8 s / 5.2 s (73-stud diagonal into a Shed alley) | **4.3 s / 5.9 s** (across the middle, ~42 studs) | as late as the 5.1 s meet allows |
| Best perch (share of the floor it sees) | Crane stack 61% (Updraft only) | Shed roof 55% (Updraft only, the old value); Crane stack **40%** (anyone can climb it) | no single dominant perch |
| Rays over 100 / over 70 studs | 0.6% / 6.5% | **0.4% / 5.2%** | Whitebox 6.4% over 70 |
| Longest lines | quay 114, Shed alley 116, lateral 138 | quay 124 (from deep in your own Shed out of the roller door up the far quay), Shed alley 116, lateral **122** (threads five gaps) | one marksman family per side |
| Distance to full cover: average / worst | 4.6 / 17.9 | **4.4 / 16.0** | worst under ~15 except the long lane |
| Route via flank vs middle | 248 vs 226 (+1.0 s) | **247 vs 237 (+0.5 s)** | within ~1 s |
| Spawn to the middle; meet | 141 studs (6.4 s); 5.1 s | 142 studs (6.4 s); 5.1 s | — |
| Gaps under 6 studs | none | none | none |
| Highest reach (16 + 7.2 jump + 28 Updraft) | 51.2, under the girders (52) and the end walls (56) | same | out of reach |

The five changes:
1. **Crane stack 2-high → 1-high**, climbed from a crate at each end. Anyone can reach and contest the middle. It isn't an Updraft-only hot seat any more.
2. **Crane legs 3 → 4 square** (the chunkier stylized gantry). The **Crane box** moves 2 in from the leg line, so the **Shed screen** can sit 2 further west without a pinch gap. Together they close the old first-sight diagonal.
3. **The Shed roller door moves 4 west** (x 46–56), behind the screen. No line runs from the enemy apron into a Shed.
4. **Quay crates → one Quay stack** (20 ft, 6 clear of the barrier) for full cover mid-quay, and **the Apron box moves into the middle band** (44, 6) to cut its lateral lines.
5. Together these bring the **flank routes within 0.5 s of the middle**.
6. **Stepped spawn baffle** (added in scoring round 2): a 1-high 40-footer with a 20-footer on its west half. Still 0% of enemy floor and tops see a spawn, and the spawn view opens over the low half to the crane.

Callouts stay what the old map taught: **Red / Blue / Green** lanes, **Crane** (the stack), **High** (divider tops), **Red Shed / Green Shed**, **Apron**, **Quay**, **Tower**.

## 4. Look (style frame)
![Dockyard2 palette](../../02%20Art/References/maps/dockyard2/dockyard2-palette.svg)

**Identity: a sunny harbour.** A warm sand-grey deck. Lane-coloured containers (terracotta, harbour blue, sea green, all one value band). A **signal-yellow gantry crane** as the landmark and the map's single accent. White and charcoal port trims. A teal harbour under a clear afternoon sky. The Lobby is a dark warm-concrete bunker with teal-slate structure and one accent per wing. Dockyard2 is outdoors, lighter and cooler, with one warm accent, so the two never read as the same place. The team colours (cyan, orange-red) and glitch magenta are kept off the map.

- **Value structure** (LihFolk *Colour Scripts*):
  - The deck is the ground band (V ~49%).
  - Containers and cladding sit one band up.
  - Trims are charcoal (dark accents) or white (cab, signs, bay numbers).
  - The crane yellow is the 10% spike, with nothing else in its band.
  - Players (Roblox avatars) separate from a mid ground and mid structures.
- **Kit language** (Lobby Style Guide, applied to a port):
  - **Containers:** a body with broad proud ribs (five per 16, chamfered, instead of the old fine corrugation). Rounded corner posts and rails with castings in a darker step of the lane colour. A door end with a picture-frame ring and recessed locking bars. A charcoal kick strip.
  - **Crane:** notched box-section legs on stepped bogies, a chamfered box girder, a white cab with a picture-frame window, a spreader, and tiny signal beacons.
  - **Shed:** a stepped concrete plinth, framed cladding panels with a lane-coloured band, picture-frame door surrounds, a deep eave (1.5–2 overhang for a strong shadow line) and a sign plate with Montserrat Black letters.
  - **Quay:** a coping with a bullnose lip, fenders and bollards.
  - **Lamp masts:** a stepped plinth, a tapered pole and a framed head.
- **Bevel hierarchy:** primary 0.45 (2 segments), secondary 0.14, tertiary 0.05. These are the Lobby's numbers nudged up for outdoor distances of 25–80 studs.
- **Surfaces:** the Lobby's painted textures (near-neutral greys, tinted by `Color`) go on the big surfaces only: deck slabs (`Dock2_Deck`), concrete (`Dock2_Concrete`), container bodies, cladding and roofs (`Dock2_Metal`), and stair treads (`Dock2_Grate`). Everything else is clean SmoothPlastic. Neon only on lamp heads and crane beacons.
- **Light:** a bright afternoon (ClockTime 15, latitude 0, so the sun rakes across the pier at ~45° and neither team looks into it). Warm sun, cool ambient, Atmosphere density 0.28, bloom threshold 1.4. A few shadowless lamps at the Sheds and masts for the warm practical touch.
- The style frame proper is the kit's first render (phase 4 gate). It's checked against this note before the rest of the kit is built.

## 5. Restyle parameters (cheap to change)
Everything lives in **`tools/maps/dockyard2_style.py`**:

| Parameter | Controls | To apply a change |
|---|---|---|
| `PALETTE` | Every role's colour, Roblox material and MaterialVariant (deck, concrete, cladding, crane, trims, glows, water) | `python tools/maps/dockyard2_style.py --luau`, then rerun the Art + Lighting bundle in Studio (no Blender, no upload) |
| `LANE`, `FRAME_SHADE`, `BACKDROP` | The three lane colours, the frame shade and the far-stack colours | same |
| `VARIANTS` | Which textures the Dock2_* MaterialVariants use, and their tile size | same |
| `LIGHTING`, `FX`, `LAMP` | Sun, ambient, atmosphere, bloom, grade and lamp colour | same (Lighting block) |
| `BEVEL`, `SEGMENTS` | Bevel sizes of the kit | Blender rebuild → export → upload → kit install (see §7) |

## 6. Plan (phases)
1. ✅ Plan with references (this note).
2. ✅ Layout check script and SVG (`tools/maps/dockyard2_layout.py`).
3. ✅ Greybox in Studio (`tools/studio/maps/Dockyard2/Greybox.luau`). Walk it in play mode with screenshots, then critique.
4. ✅ Blender kit (`tools/blender/build_map_kit_dockyard2.py`, on the Lobby kit helpers) with a contact sheet. Coplanar audit at 0, then export, upload and install.
5. ✅ Art pass (`Art.luau`), lighting (`Lighting.luau`) and set dressing.
6. ✅ `tools/studio/maps/Audit.luau` reports 0.
7. ✅ Screenshots from each spawn, the middle and an overview.
8. ✅ Blind scoring (`lihfolk:quality-score`, world rubric, min 8.5), then fix rounds: **8.75**.

## Kit (phase 4)
`tools/blender/build_map_kit_dockyard2.py` builds the kit on the Lobby helpers (`lobbykit`, `build_lobby_kit_stylized`, `build_lobby_kit_bunker2`), into `art-source/maps/Dockyard2/Kit_Dockyard2.blend`. That's 19 pieces, 22.7k triangles for the whole kit. **Coplanar audit: 0** (`art-source/maps/Dockyard2/coplanar.json`, the Lobby audit run on the `Map_` collections). Uploaded as group `Kit`, **asset 127619569582290**.

![Kit contact sheet A](../../02%20Art/References/maps/dockyard2/kit-contact-a.jpg)
![Kit contact sheet B](../../02%20Art/References/maps/dockyard2/kit-contact-b.jpg)

| Piece | Tris | Design |
|---|---|---|
| `C20` / `C40` | 1,504 / 1,624 | A body with broad chamfered ribs (5 per 16 studs), three shallow roof panels and rear-end ribs (Lane role). Corner posts and rails in a darker step of the lane colour (LaneFrame). Door leaves 0.13 proud with a rib each, and charcoal locking bars with handles. Everything sits ≥ 0.03 inside the 8 × 8 × L envelope. |
| `C20Lo` / `C40Lo` | 668 / 740 | The background version: 3 ribs per 16, no roof panels, bars or bottom rails. Used for the end walls above eye level, the ships and the far stacks. |
| `Crane` | 4,968 | Notched octagonal legs on stepped bogies with tyres, two charcoal bands per leg, chamfered box girders, portal beams, the trolley and a white machinery house, a white cab with glass and visor, a spreader over the Crane stack (26–29, clear of anyone on the stack), and four tiny signal beacons. |
| `Shed` | 4,108 | A stepped concrete plinth, cladding walls with charcoal pilasters, a lane-coloured band, picture-frame door surrounds with rounded inner corners, cornices, gables, a roof whose top follows the greybox roof with a 1.1 eave, a white fascia, barge boards and ridge cap, inside portal frames clear of the doors, a roller drum, pendant lamps and a floor slab 0.06 proud. |
| `ShedSign1/2` | ~1,450 | A framed white plate over the roller door with "SHED 01" / "SHED 02" in Montserrat Black. Numbers, not colour names, so a lane restyle never contradicts the sign. |
| `Stair` | 1,384 | Grate treads 0.03 under the greybox slope with hazard nosings, charcoal stringers and white rails. |
| `Rack`, `Office`, `Crate` | 1,588 / 1,096 / 240 | A pallet rack packed full (it's full cover) with hazard beams; a white site cabin with framed windows and a hazard door; a wooden crate on a pallet with charcoal bands. |
| `QuayBarrier8` / `Short`, `QuayFace8`, `Bollard`, `LampMast` | 88 / 88 / 136 / 500 / 580 | A wall with a bullnose cap, a hazard band and a dark kick (cores stop 0.02 short, so neighbours show a hairline joint instead of a coplanar end). The deck edge with a chamfered coping 0.06 over the deck and a rubber fender. A lathed bollard. A mast with a stepped plinth, a tapered white pole and a twin head with warm lenses. |
| `StsCrane`, `Ship` | 352 / 144 | Skyline silhouettes in white, charcoal and slate, kept off the yellow so the RTG stays the one landmark. |

**Style frames** (Blender stand-in for the Roblox light; Roblox will be flatter and warmer):
![From the B spawn](../../02%20Art/References/maps/dockyard2/style-frame-from-b-spawn.jpg)
![Overview](../../02%20Art/References/maps/dockyard2/style-frame-overview.jpg)

Critique of the first frame, now fixed: everything read blue (a cool backdrop behind the blue lane). The backdrop palette now leans warm (sand, cream, faded terracotta, sage, mustard, slate), and the blue lane is calmer (`3E6C9C`). The crane reads as the landmark from every frame. The Shed's white walls and lane band read at a glance.

## Studio build (phases 3, 5, 6)
**Greybox** built and walked in play mode with `ForceMap = "Dockyard2"` against a bot: deck plus 93 parts, 4 + 4 spawns, 2 barriers.

![Greybox overview](../../02%20Art/References/maps/dockyard2/greybox-overview.jpg)
![Greybox, play mode from the A spawn](../../02%20Art/References/maps/dockyard2/greybox-play-a-spawn.jpg)

Greybox critique:
- The lanes read by colour from every spot.
- 8-high boxes are clearly full cover.
- The crane is the landmark: its yellow legs show over every stack, and its top shows over the spawn baffle.
- In play the bot found us across the middle first, as the layout script predicted.
- The 2-high baffle fills the spawn view. Flagged, and the reviewers flagged it too (fixed in round 1).

**Kit installed** (`ServerStorage.MapKit.Dockyard2`). The **art pass** made 402 kit placements and 124 art parts, hid 93 greybox parts and reported "all kit pieces found". **`Audit.luau`: 0 z-fighting pairs over 1,676 visible parts.**

Studio passes, each measured in Studio:
| Pass | Seen | Change (all in `dockyard2_style.py`) |
|---|---|---|
| Sun | `GetSunDirection` was (-0.65, 0.65, **-0.40**) at latitude 0, so team B half-faced the sun | Latitude **23.5** gives (-0.71, 0.71, 0.00): 45° up, across the pier |
| Colour 1 | Containers came out royal blue and very saturated, though their colours were right | Roblox **Metal** mirrors the blue sky. Painted surfaces moved off Metal and the lanes went a step calmer |
| Colour 2 | Shaded faces still went deep blue | A more neutral ambient: OutdoorAmbient (146,148,156), EnvironmentDiffuseScale 0.2 |
| Water | A loud cyan | `#2A6878` |
| Water overlap | The 2048-wide water would overlap the old Dockyard's water plane between the maps | 1000 wide, 0.1 lower |

## Scoring (phase 8, `lihfolk:quality-score`, world rubric, 3 blind reviewers)
**Round 0: 5.4 / 10** (medians: W1 1, W2 1, W3 1, W4 1, W5 1, W6 2). Hard gates pass: audit 0, decor non-colliding, spawns safe, 275k triangles for the whole map (211k without the skyline), 4 lights. Reviewer scores were 5.0, 5.4 and 5.4 (recomputed with the right weight total, 12).

All three named the same problems:
1. **The spawn view is a blank container wall** with no visible route and no team identity (W1, W2).
2. **Smeared textures** on the containers and Shed walls (W3, W5).
3. **Raw grey slabs** of the end walls from outside, and a flat tan "beach" (W3).
4. **Plain lighting**, with crushed shadows and a murky Shed inside (W4).

Fix round 1 (all four at once, since each is independent and parameter-cheap):
- A framed **spawn sign** on the baffle ("DOCK A / DOCK B", with "◄ RED" and "GREEN ►" in the lane colours, showing which lane lies each way round it) and **white chevrons** on the deck leading out round both sides. These are new kit pieces `SpawnSignA/B` and `Chevron`.
- **Clean SmoothPlastic paint** on the containers and cladding (the ribs, rails and doors carry the detail). The roof is calm concrete.
- **End-wall backs** dressed with light containers. Far quays darker.
- **Light:** a brighter neutral ambient (no crush), warmer ColorShift, haze 1.1 for depth, lower grade contrast, and Shed lamps at 2.4.

Fix round 2 (+1.3, to 6.7):
- **Stepped spawn baffle:** a 1-high 40-footer with a 20-footer on its west half. Spawn safety is unchanged (0% / 0%), and the spawn now looks over the low half to the crane. The sign was resized onto the high half (layout change 6).
- **White reefers** for the Crane stack and its steps, a ground-level centre landmark.
- **Lane words painted on the deck** where each lane leaves the spawn end.
- A lighter Shed inside and surround. Ships get a lighter hull, the far quays get deck tiles, and the STS crane frames are grey.

Fix round 3 (+2.05, to **8.75**):
- A framed **"CRANE" plate** on each long side of the reefers.
- The flank lane words again in the middle band. Bug fixed on the way: the A half's words had been mirrored into the wrong lanes. They now take their lane from where they land.
- Warm light strips under the Shed tie beams, which show even where PointLights don't render.
- A warmer sun against cooler shade, haze 1.6, sun rays 0.08, a less pastel backdrop, the reefers toned down from overexposed white.

| Round | W1 (3) | W2 (3) | W3 (2) | W4 (2) | W5 (1) | W6 (1) | Score (median) | Reviewers |
|---|---|---|---|---|---|---|---|---|
| 0 | 1 | 1 | 1 | 1 | 1 | 2 | 5.4 | 5.0 / 5.4 / 5.4 |
| 1 | 1 | 1 | 1 | 1 | 1 | 2 | 5.4 | 5.0 / 5.4 / 5.4 |
| 2 | 2 | 1 | 1 | 1 | 1 | 2 | 6.7 | 6.7 / 7.5 / 6.7 |
| **3** | **2** | **2** | **2** | **1** | **1** | **2** | **8.75** | 6.7 / 8.75 / 8.75 |

**Lowest criteria:** W4 lighting (all three called it "tuned, not striking") and W5 density (big flat container faces, a bare Shed inside). One reviewer still read the lanes as "a maze of same-coloured walls" (W2 1). The scores are logged in `.lihfolk/ledger.jsonl`.

Final screenshots (`References/maps/dockyard2/r3-*.jpg`). Captures are edit mode with the map's lighting applied; Shed PointLights don't render in them.

| Spawn A | Spawn B | Middle (ground) |
|---|---|---|
| ![](../../02%20Art/References/maps/dockyard2/r3-a-spawn.jpg) | ![](../../02%20Art/References/maps/dockyard2/r3-b-spawn.jpg) | ![](../../02%20Art/References/maps/dockyard2/r3-middle-crane-court.jpg) |

| Mid lane | Red lane (apron) | Overview |
|---|---|---|
| ![](../../02%20Art/References/maps/dockyard2/r3-mid-lane-word.jpg) | ![](../../02%20Art/References/maps/dockyard2/r3-apron.jpg) | ![](../../02%20Art/References/maps/dockyard2/r3-overview.jpg) |

## What the user should check tonight
1. **Save first.** In the match Studio (the one with `ServerScriptService.Server`), press **Ctrl+S** (Save to Roblox). Dockyard2 is built in it but unsaved.
2. **Play it.** Set the Workspace attribute `ForceMap` to `Dockyard2`, press Play, and walk from your spawn. Is the "DOCK A/B" sign readable, and do RED / GREEN point the right way? Does the crane over the low half of the baffle pull you to the middle?
3. **The look against the Lobby.** Bright harbour, clean painted boxes, signal-yellow crane. Too bright, too toy-like, or not enough? Every colour, the sun and the haze are one edit in `tools/maps/dockyard2_style.py` (§5) and need no Blender.
4. **Lane colours.** Terracotta / harbour blue / sea green, plus the white reefers in the middle. Do they read at a glance in play? Is the blue too dark in shade?
5. **The Shed inside** in play mode, where the lamps do render. Reviewers only saw it without lights and called it murky.
6. **Feel.** Middle contact at ~4.3 s sprinting, the 1-high centre stack, the quay walk beside the new Quay stack. Does any spot feel like a camping perch?
7. Decide whether Dockyard2 should replace Dockyard in the rotation (then add `{ id = "Dockyard2", minTeam = 1, maxTeam = 4 }` and drop `Dockyard`).

## Known issues and follow-ups
- **Other maps are visible on the horizon.** Snowpeak's mountains and the old Dockyard's cranes show from Dockyard2, because all maps sit in Workspace at 1,500-stud spacing. This is project-wide, not specific to Dockyard2. A fix belongs in MapService (park the inactive maps in ServerStorage) or in more spacing.
- **Studio place IDs are swapped against our notes (2026-11-05).** The match content (maps, `Server`) is the instance with PlaceId **133387545285290**, and the Lobby content (`LobbyServer`) is **71551303511506**. `MapKit.luau` and `kit_bundle.py` assert 71551303511506, so lane G swapped that assert for a content check in its temporary bundles only. The core chat should verify which is right, then fix the memory note `place-ids` and those asserts.
- **Background:** the end walls' water-side faces show a grey backfill strip. The STS cranes are simple silhouettes.
- **Budget:** 1,815 MeshParts and ~300k triangles for the whole map, of which ~230k in the playable yard. That's over the old Dockyard's 192k; the light `Lo` containers carry the end walls.

## 7. Build and run order
1. Layout (rerun after any change): `python tools/maps/dockyard2_layout.py --luau` prints the checks and writes the SVG, the greybox LAYOUT block and the ART block (from `tools/maps/dockyard2_art.py`).
2. Style: `python tools/maps/dockyard2_style.py --luau --svg` writes the STYLE block of `Art.luau`, the LIGHT block of `Lighting.luau` and the palette board.
3. Kit: `blender --background --factory-startup --python tools/blender/build_map_kit_dockyard2.py -- [--render] [--preview]` (prints `COPLANAR 0`). Export: `blender --background --factory-startup art-source/maps/Dockyard2/Kit_Dockyard2.blend --python tools/blender/export_lobby_kit.py -- --maps Dockyard2 Kit`. Upload: `python tools/opencloud/upload_models.py --maps Dockyard2 --group 11116787 Kit` (updates asset 127619569582290).
4. In the match place, edit mode: `python tools/studio/maps/bundle.py Dockyard2 Greybox`, then `python tools/studio/maps/kit_bundle.py Dockyard2 Kit`, then `python tools/studio/maps/bundle.py Dockyard2 Art Lighting`; run each.
5. Check: `tools/studio/maps/Audit.luau` with argument `"Dockyard2"` (target 0). Then screenshots, saving the place and the backups `art-source/maps/Dockyard2/Dockyard2.rbxm` / `MapKit_Dockyard2.rbxm`.

## Concept pass 2026-11-05
Status: **in progress.** Brief: [Evening Review](../../05%20Production/Playtests/2026-11-05%20Evening%20Review.md).
- The user's verdict: better than the old map but "too simple": smooth plastic blocks, no depth, no levels. The crates work because they have texture and meaning.
- Target: Valorant-level detail with RIVALS clarity. The user approves the concepts before any modelling.
- Skills and notes used:
  - `gauntlet-vault`;
  - `lihfolk-worldbuilding`: focal hierarchy, three reads, materials at three scales, hero ≥ 1.5× taller;
  - `roblox-blender-modeling`;
  - LihFolk notes: *Modular Environment Kits*, *Trim Sheets Atlases and Vertex Colors*, *Textures Decals and Texture Memory*, *Materials MaterialVariants and SurfaceAppearance*, *Art Budgets - Triangles Draw Calls Memory*, *Combat Arena and Encounter Layout*, *Level Design Principles - Flow Sightlines and Landmarks*.

### What's wrong now (in-play evidence)
Screenshots:
- [spawn A in play](../../02%20Art/References/maps/dockyard2/whats-wrong/play-spawnA.jpg)
- [spawn A exit](../../02%20Art/References/maps/dockyard2/whats-wrong/play-spawnA-exit.jpg)
- [quay stacks](../../02%20Art/References/maps/dockyard2/whats-wrong/edit-quay-stacks.jpg)
- the round 3 set (`r3-*.jpg`)

1. **Silhouettes are boxes.** Every container, shed and wall is a rectangle with a thin bevel. Nothing breaks the skyline except the crane legs. There are no overhangs, diagonal bracing, cantilevers or stepped roofs.
2. **No height.** The whole map plays on one floor (y 0):
   - the crane is scenery;
   - the sheds have no upper floor;
   - the stacks can't be climbed;
   - there are no drops, ledges or catwalks, so a fight plays the same everywhere.
3. **Flat surfaces.** Container sides are one colour with moulded ribs. There's no rust, chipped edges, streaks, stencilled numbers or dirt. The quay deck is a clean grid of square tiles with no expansion joints, tyre marks or stains. SmoothPlastic everywhere reads as a toy.
4. **Missing trims and edges.**
   - Containers: corner castings and door hardware are token at best.
   - Sheds: no flashing, gutters, downpipes or roller-door frames.
   - Quay: no edge capping, kerb or fender line.
5. **The landmark is weak.** The crane is a yellow frame (two legs and a beam) about as tall as the stacks behind it, so it doesn't own the skyline. The backdrop ship and the STS crane are flat and far away.
6. **No place identity.** Apart from the "DOCK A" sign, nothing says which port this is. There's no terminal name, bay numbers, livery, reefer plugs, lashing gear, pallets or ropes.
7. **What works:**
   - the coloured container lanes;
   - the signs naming the lanes;
   - the yellow crane as the middle marker.

   Keep all three.

### Direction (keep the layout: 3 lanes, crane in the middle, sheds on the flanks)
- **Height levels (new).** Cover heights follow *Combat Arena and Encounter Layout*: low 2.5–3.5, full 7+ studs, no chest-high middle band. Jump height is about 7 studs. The levels stay rotationally symmetric so neither side gets a longer view.
  - **Crane gantry catwalk:** a grated walkway about 12 studs up between the crane legs, reached by caged ladders on each team's side. An exposed power spot over the middle lane.
  - **Shed mezzanines:** an office floor with a window strip over each flank lane, reached by an inside stair. A drop from the window ledge onto a container is the fast exit.
  - **Climbable stacks:** 2-high stacks with a top route and a grated bridge between two stacks.
  - **Lower jetty:** a timber walkway about 4 studs below the quay edge as a flank under-route, with ladders back up.
- **Landmark:** a large ship-to-shore gantry crane with a container hanging from its spreader over the middle.
  - At least 1.5× taller than anything else, and 3–5° of view from both spawns.
  - The docked ship's hull is the backdrop wall.
- **Identity:** a fictional terminal ("Port Halden, Terminal 7"; the names are ours) with painted bay numbers and a terminal livery. Props:
  - reefer containers with cables;
  - lashing bars;
  - bollards with mooring ropes;
  - tyre fenders;
  - light masts;
  - pallets and oil drums;
  - hazard stripes.
- **Zone colour (RIVALS clarity):**
  - A side: warm orange and red containers.
  - B side: cool teal and blue.
  - Middle: the yellow crane.
  - The deck stays neutral concrete grey.
- **Materials:**
  - corrugated painted steel with chipped edges and rust streaks;
  - stencilled lettering;
  - concrete with expansion joints, tyre marks and paint lines;
  - galvanised grating;
  - weathered timber;
  - ribbed sheet-metal cladding with flashing;
  - rusty iron bollards.

### Prompts (ChatGPT image generation)
Shared style block, appended to every prompt:
> Original stylized competitive FPS map concept art, 3D game environment with the detail level of a polished AAA hero shooter: worn painted materials, chamfered edges, panel lines, decals and grime, but clean readable shapes and strong colour zoning for gameplay clarity. Bright late-afternoon sun from the side, soft blue sky, crisp shadows. No people, no real brands or logos, only short fictional signage. Not a copy of any existing game map.

1. **Hero, middle:**
   > Player eye height, 24 mm lens, standing in the middle lane of a container-terminal pier looking along the lane. Ahead, a towering yellow ship-to-shore gantry crane straddles the lane, with a grated catwalk 12 ft up between its legs, caged ladders and a red container hanging from its spreader. Left: orange and rust-red 40 ft containers stacked two high, with a grated bridge between two stacks. Right: teal and blue containers. Concrete quay deck with expansion joints, yellow lane lines and tyre marks. A docked cargo ship hull forms the far wall.
2. **Hero, spawn A:**
   > Eye height, 24 mm, looking out from the warm-side spawn: a corrugated metal shed with a roller door and an upstairs office with a long window strip, an orange container stack with a ladder, a painted bay number "A7" on the ground, a light mast, and the yellow gantry crane rising in the middle distance.
3. **Hero, spawn B:** the same for the cool side.
   > A teal container stack, the shed mezzanine on the right, a timber jetty stair dropping off the quay edge to the left with tyre fenders and bollards, and the crane ahead.
4. **Overview:**
   > High three-quarter aerial view of a compact arena shooter map on a container pier with 180-degree rotational symmetry. Three parallel lanes: the left lane runs through a long metal shed with a mezzanine office, the middle lane passes under a giant yellow gantry crane with a catwalk, and the right lane runs along the quay edge with a lower timber jetty. Spawns are at the two short ends. Orange containers on one half, teal on the other. Water around the pier, a cargo ship moored alongside.
5. **Kit sheet:**
   > Environment kit sheet on a neutral grey background, three-quarter views, numbered only:
   > - 20 ft and 40 ft shipping containers (doors, corner castings, ribs, chipped paint);
   > - a reefer container with a cable;
   > - a gantry crane leg segment and a catwalk section with railings;
   > - a caged ladder;
   > - a corrugated shed wall module with a roller door and a window strip;
   > - a mezzanine stair;
   > - a timber jetty section with tyre fenders;
   > - a bollard with rope;
   > - a light mast;
   > - a pallet stack and oil drums;
   > - a lashing-bar rack;
   > - a concrete barrier with hazard stripes.
6. **Material sheet:**
   > Material and trim swatch sheet, flat square tiles in a grid, stylized hand-painted PBR look, tileable:
   > - corrugated container steel in orange, teal and blue, with chipped edges and rust streaks;
   > - a stencilled lettering strip;
   > - galvanised steel grating;
   > - weathered timber planks;
   > - concrete quay with expansion joints and tyre marks;
   > - ribbed shed cladding;
   > - a hazard-stripe trim;
   > - a rusty iron trim strip;
   > - a rubber fender.

### Birds (map life)
The current gulls are boxy (the verdict: "blocky and bad").

**Recommendation:** remove them until there's a proper replacement. The replacement:
- a modelled low-poly gull with a real silhouette: tapered wings bent at the elbow, a tail fan, a beak, two-tone paint;
- a flap animation instead of rotating plates;
- about 300–500 tris;
- over the water only, never in a sightline.

This is lane F's area (map life), so it's a recommendation only.
