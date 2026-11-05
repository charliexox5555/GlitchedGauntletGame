# Dockyard2 (redesign of Dockyard)

The 2026-11-05 redesign of [Dockyard](Dockyard.md) in the new environment style ([Lobby Style Guide](../../02%20Art/Lobby%20Style%20Guide.md), [Art Direction](../../02%20Art/Art%20Direction.md) → direction change 2026-11-04). Same idea: a container pier with three lanes, a gantry crane over the middle and a Shed on each flank, for 1v1 to 4v4. Built next to the old map, which stays untouched. **Not in the match rotation** until the user approves the swap; in Studio set the Workspace attribute `ForceMap = "Dockyard2"`. Lane G of the [Day Plan 2026-11-05](../../05%20Production/Day%20Plan%202026-11-05.md).

**Map id** `Dockyard2`. **World origin (-3000, 200, 0).** These origins are already taken: Whitebox (0, 200, 0), Big Whitebox (0, 200, -1500), Dockyard (-1500, 200, 0), Metro (1500, 200, 0), Old Town (0, 200, 1500), Greenhouse (1500, 200, -1500), Rooftops (1500, 200, 1500), Bunker (-1500, 200, 1500) and Snowpeak (-1500, 200, -1500).

**Status:** phase 1 (plan) and phase 2 (layout check) are done. Phases 3 to 8 follow below as they're done.

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
3. Greybox in Studio (`tools/studio/maps/Dockyard2/Greybox.luau`). Walk it in play mode with screenshots, then critique.
4. Blender kit (`tools/blender/build_map_kit_dockyard2.py`, on the Lobby kit helpers) with a contact sheet. Coplanar audit at 0, then export, upload and install.
5. Art pass (`Art.luau`), lighting (`Lighting.luau`) and set dressing.
6. `tools/studio/maps/Audit.luau` reports 0.
7. Screenshots from each spawn, the middle and an overview.
8. Blind scoring (`lihfolk:quality-score`, world rubric, min 8.5), then fix rounds.

## 7. Build and run order
(Filled in as the build goes.)
