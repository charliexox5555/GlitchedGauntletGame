# Bunker

A medium indoor map for 1v1 to 3v3: **the Sunwell Bunker's lower levels**, a board-formed concrete shelter dug under the Lobby. One tall light shaft drops a column of sun onto the middle; tight service corridors, a locker room, a control room and two pump rooms wrap around it. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** concept, checked layout and greybox script done; kit, art and lighting follow in this note's §5. **Not yet run in Studio:** the hub runs the scripts, screenshots and iterates.

![Bunker layout](../../02%20Art/References/maps/bunker/bunker-layout.svg)

---

## 1. One line
A cool concrete shelter around one hot column of sunlight: you fight through the dark to the bright middle, and whoever stands in the sun is seen by everyone.

### What it should feel like
- **The same world as the Lobby.** Board-formed concrete with tie holes, honed dark floors, black steel, warm cove light and brass, and a sun shaft through the roof like the Lobby's oculus. A player who just queued in the Lobby should think "this is downstairs".
- **Compression, then release.** Low (12-stud) corridors and rooms, then the 26-tall sunwell and its 64-stud shaft. Every lane ends in that reveal.
- **Readable at a glance.** One bright middle (*Sunwell*), a catwalk around it (*Ring*), one balcony per team (*Overlook*), and named rooms on the flanks (*Lockers*, *Control*, *Pump*). End colours tell you which half you are in.
- **Lived in, not ruined.** Lockers, consoles, server racks, pumps and supply crates in story groups ("the night shift left in a hurry"), no rubble, no gore, no flicker horror.

### Not this
A dark horror bunker, rusty grime and rubble, a maze of identical corridors, neon sci-fi, invisible walls, props sprinkled evenly.

---

## 2. References
Third-party images are stored in `02 Art/References/maps/bunker/third-party/` (git-ignored, the repo is public), so they show in Obsidian on this PC only; the source pages are linked.

![Pantheon oculus light](../../02%20Art/References/maps/bunker/third-party/pantheon-oculus-beam.jpg)
![Bruder Klaus Field Chapel, rammed concrete under the oculus](../../02%20Art/References/maps/bunker/third-party/zumthor-bruder-klaus.jpg)
![Church of the Light](../../02%20Art/References/maps/bunker/third-party/ando-church-of-light.jpg)
![Cheyenne Mountain blast door](../../02%20Art/References/maps/bunker/third-party/cheyenne-blast-door.jpg)
![Diefenbunker corridor](../../02%20Art/References/maps/bunker/third-party/diefenbunker-hallways.jpg)
![Halo 3 The Pit](../../02%20Art/References/maps/bunker/third-party/halo3-the-pit-base.jpg)
![Lobby oculus (ours)](../../02%20Art/References/lobby/final/02-spawn-dome.jpg)
![Lobby ring (ours)](../../02%20Art/References/lobby/final/03-ring.jpg)

| Reference | Take |
|---|---|
| **Our Lobby** ([oculus](../../02%20Art/References/lobby/final/02-spawn-dome.jpg), [ring](../../02%20Art/References/lobby/final/03-ring.jpg), [Lobby Kit](../../02%20Art/Lobby%20Kit.md)) | The palette and trims to reuse: board-formed concrete `#8E8C87` with tie holes, honed dark floor, black steel `#1C1D20`, warm cove `#FFF1DC`, brass for the one precious object, a sun shaft at ClockTime 12 with a Beam rig and a bounce light |
| [Pantheon oculus light](https://commons.wikimedia.org/wiki/File:Light_from_the_Pantheon_oculus,_Rome_(2).jpg) (CC BY 4.0) | A hard-edged sun patch moving across a dark interior: the sunlit square on the sunwell floor is the landmark, everything else stays in shade |
| [Bruder Klaus Field Chapel](https://commons.wikimedia.org/wiki/File:Bruder_Klaus_Kapelle8.jpg) (Zumthor, CC BY-SA 4.0) | A tall concrete shaft lit from the top: the light grazes the wall and shows its texture. Our shaft walls get vertical board marks and tie holes so the grazing light has something to show |
| [Church of the Light](https://commons.wikimedia.org/wiki/File:Ibaraki_Kasugaoka_Church_light_cross.jpg) (Ando, CC BY-SA 3.0) | Smooth concrete with a tie-hole grid and one cut of light: restraint. One light source per space, no decoration on the walls |
| [Kolumba](https://commons.wikimedia.org/wiki/File:Zumthor_Kolumba07.JPG) (Zumthor, public domain) | The perforated filter wall: the control room's back wall uses a vent grille band instead of plain concrete |
| [Therme Vals](https://commons.wikimedia.org/wiki/File:Therme_Vals_wall_structure,_Vals,_Graub%C3%BCnden,_Switzerland_-_20040530.jpg) (CC BY-SA 2.0) | Thin horizontal courses and deep openings: our board marks run horizontally on the low walls, door reveals are deep steel-lined slots |
| [Barbican concrete](https://commons.wikimedia.org/wiki/File:Barbican_Concrete_finish_(8085917893).jpg) (CC BY-SA 2.0) | Close-up texture: the concrete is warm grey, not blue-grey |
| [Cheyenne Mountain blast door](https://commons.wikimedia.org/wiki/File:121025-F-ZZ000-001_Cheyenne_Mountain_20-ton_blast_door_closing.jpg) (public domain) | A blast door is a thick slab with a heavy frame, bolts and hinges in plain sight: the hero prop at each gallery's back, jammed half shut |
| [Cheyenne Mountain tunnels](https://commons.wikimedia.org/wiki/File:Cheyenne_Mountain_Tunnels.jpg) (public domain) | Cage lamps and cable runs along the walls, buildings set inside the rock: light fixtures and conduits are the corridor detail |
| [Diefenbunker hallways](https://commons.wikimedia.org/wiki/File:DSC01352_-_Many_Hallways_(44662801012).jpg) (CC BY-SA 2.0) | The Cold War bunker look: two-tone painted walls, a dark skirting, heavy steel doors, striped columns. Our low walls are painted below and raw concrete above, with an end-colour line between |
| [Halo 3: The Pit](https://halo.fandom.com/wiki/The_Pit) | A training facility map: two bases, a central pit, catwalks over it and side rooms; height over the middle is earned by climbing, and the middle is exposed from above |
| [Counter-Strike 2: Nuke](https://counterstrike.fandom.com/wiki/Nuke) | Industrial facility gameplay: rooms stacked around one vertical space, pipes and vents as cover and routes, clean colour coding |
| [Valorant: Fracture](https://valorant.fandom.com/wiki/Fracture) | A research facility split by a central structure; colour and signage say which side you are on |
| [GoldenEye 007: Facility](https://goldeneye.fandom.com/wiki/Facility) | The classic: tight corridors, steel doors, tiled rooms and a few bigger halls. Corridors stay short and always end in a room |
| [RIVALS: Backrooms](https://robloxrivals.fandom.com/wiki/Backrooms) | The Roblox benchmark: an indoor RIVALS map plays fine with low ceilings and simple shapes as long as the lanes read |

### What the LihFolk vault adds
- Indoor ceilings 2 to 3 avatar heights (corridors 12 here), corridors 1.6 to 2.4 avatar heights wide (8 here), doors 7 to 8 tall (10 here, for the camera). *Modelling to the Roblox Camera and Player Scale; Level Design for Roblox.*
- One hero per zone, at least 1.5x taller than anything else; brightness follows the focal order (light the objective, not decoration). *World Composition and Set Dressing.*
- Real lights only at focal points (8 to 12 visible, 2 to 3 shadowed on phones), Bloom threshold 1.5 to 2 for combat, SunRays 0.05 to 0.15. *Stylized Lighting Recipes; Atmosphere Sky Clouds and Post-Processing.*
- Coplanar faces flicker: offset one by 0.01 to 0.05 or delete the hidden face. *Parts Unions and MeshParts.* (Our rule is stricter: 0.05 minimum, and nothing overlaps in a shared plane.)

---

## 3. Layout
Generated and checked by `tools/maps/bunker_layout.py` (the same data writes the greybox script). Change a number there and rerun it; it prints the checks below and redraws the SVG.

**Shape:** 84 × 204 studs. Spawn rooms at each end, a cross hall (*vestibule*) in front of each, then three lanes into the middle: the **gallery** (middle), a **flank corridor** on each side, and between them the side rooms. The **sunwell** is a 40 × 40 hall, 26 tall, under a 24 × 24 light shaft that rises to a skylight at +64. **Symmetry:** 180° rotation, so team A's lockers are on the west and team B's on the east.

### Levels (two, 12 apart)
| Level | Height | What's there |
|---|---|---|
| Ground | 0 | Everything you spawn into; the sun dais in the middle is a half-stud step |
| Ring and overlooks | +12 | The catwalk around the sunwell (6 clear, a 3-tall concrete parapet) and each team's overlook balcony at its gallery's front, joined to the ring through an 8-wide opening |
| Ceilings | 12 / 26 | Rooms and corridors 12; sunwell and galleries 26; the shaft goes on to the skylight at 64 |

### Pieces
| Piece | Size (studs) | Job |
|---|---|---|
| **Sun plinth** | 8 × 8, 8.5 tall on the dais | The lit landmark under the shaft, full cover, and it closes the gallery-to-gallery line (every rotated door pair's line runs through the centre) |
| **Sun dais** | 16 × 16, 0.5 step | The sunlit square; brass compass in the floor (the Lobby's spawn dais motif) |
| **Generators** | 4 × 6 × 7 (sunwell), 6 × 6 × 7 (gallery) | Full cover in the bright middle and in the gallery |
| **Consoles** | 8 × 2 × 3 | Half cover in the sunwell; the control desk in the control room |
| **Ring** | band 13..20, deck +12 | High ground over the middle that you reach from your overlook (or by Updraft over the parapet); it sees 100% of the sunwell floor but only 14% of the rest of the map |
| **Overlook + stair** | 24 × 8 deck, stair 6 × 18 | Your balcony at the gallery's front; the stair rises toward the sunwell |
| **Blast door** | 16-wide frame, one leaf jammed shut | The gallery's back: an 8-wide passage from the vestibule, the hero prop of each half |
| **Lockers** | 16 × 28 room | Lockers along the back wall, a locker island (full cover); doors to the gallery front, the corridor and the pump room |
| **Control** | 16 × 28 room | Server racks along the back wall, a desk island (half cover); doors to the gallery and the corridor |
| **Pump rooms** | 18 × 28 | The flank's middle: a pump unit (10 × 12 × 8) blocks the straight corridor line, so the flank weaves through the room; door into the sunwell |
| **Flank corridors** | 8 wide, 38 long, ceiling 12 | From the vestibule to the pump room; the tight lanes for shotguns |
| **Vestibule** | 80 × 12 | The cross hall in front of the spawn: a supply cage and a crate row break its length |
| **Spawn room** | 36 × 32 | Two 8-wide doors either side of a 20-wide baffle; barriers in the doors |

### Lanes and callouts (team B's view)
- **Middle:** B spawn → vestibule → blast door → *B Gallery* → under your overlook → the B door → *Sunwell* (around the *Plinth*) → A door.
- **High:** *B Gallery* stair → *B Overlook* → *Ring* → (across the shaft) *A Overlook*.
- **East:** vestibule → *East corridor* → *East Pump* (around the pump) → A's east corridor → A vestibule. Your *Lockers* open onto it.
- **West:** vestibule → *West corridor* → *West Pump* → A's west corridor. Your *Control* room opens onto it.
- **Into the middle from a flank:** each pump room has a door into the sunwell; your lockers open into your gallery's front.

### Measured (from the script)
| Check | Result | Target |
|---|---|---|
| Greybox volume overlaps / coplanar faces | 0 / 0 | 0 |
| Spawn sees enemy spawn | Never | Never |
| Anywhere outside a team's vestibule and spawn that sees its spawn points | 0% | 0 |
| Spawn to the middle | 97 studs: 4.4 s sprint, 6.1 s walk | 5-6 s for a medium map |
| Spawn to spawn | 195 studs walked (176 straight): 8.9 s sprint, 12.2 s walk | 150-190 straight |
| First sight | 3.4 s sprint, **4.6 s walk**: overlook to overlook across the shaft, 52 studs | 5-8 s |
| First contact | 4.4 s sprint, **6.1 s walk**, in the sunwell | ~10 s (see below) |
| Tightest gap between cover and walls | 6 or more everywhere | 6 |
| Distance to full cover | average 3.2, worst 8.7 (sunwell, beside the dais) | worst under about 15 |
| Long lines | 0.5% of spot pairs over 60 apart see each other, none over 81; the longest is from the sunwell through a gallery and its passage into that team's vestibule (81) | one long line per side |
| Ring | sees 100% of the sunwell floor, 14% of the rest | high ground that doesn't own the map |
| Shell | sealed: no standing spot outside the walls or above the ceilings | closed |
| Highest reach | ring 12 + jump 7.2 + Updraft 28 = 47 (three 14s: 61); skylight at 64 | under the skylight |

**First sight and contact** come a little earlier than the research's 5-8 s and ~10 s. That is the cost of the brief's 150-190 studs spawn to spawn: half of 195 walked studs is 6 s at walking speed. The overlook-to-overlook look (4.6 s) is a glimpse across the shaft at 52 studs, the contact is in the sunwell at 6 s. If playtests want slower openings, push the spawn rooms 8 studs back (the map has room).

The checks are 2.5D (a voxel model with eye-to-eye lines, walking, jumping up to 7 and dropping); they don't replace walking it. **Watch in play:** whether the ring is too strong (the parapet is half cover, the shaft void separates the two sides), whether the plinth top (reachable only by Updraft) becomes a camping spot, and whether the 81-stud mid-to-vestibule line matters.

### Abilities on this size
| Ability | Fit |
|---|---|
| **Dash** (12-24) | Across a corridor door, around the plinth, through the 8-wide blast-door passage |
| **Updraft** (14-28) | From the sunwell floor onto the ring over the parapet (12 + 3); onto the plinth (8.5). Ceilings stop it everywhere else |
| **Firewall** (40 × 10) | Seals a corridor (8) or the gallery (24) completely; in the sunwell it splits the room. Strong, as on every indoor map |
| **Molly / Frost** | Corridors and the blast-door passage are natural targets; mollies dropped from the ring onto the dais |
| **Recall** (40) | From the ring's corner to the gallery or a pump room: a real escape |
| **Recon** (40) | A dart in the sunwell covers the whole hall and both galleries' fronts |

### No invisible walls
Every wall, ceiling and the skylight are visible and higher than anyone can reach; the skylight is glass with steel glazing bars, collision on purpose.

---

## 4. Look
**Feel:** cool shade everywhere, one warm column of sun. The Lobby's materials, a bunker's furniture.

| Part | Colour | Roblox material |
|---|---|---|
| Upper walls, shaft, ceilings: board-formed concrete | `#8E8C87` (shaft and sunwell `#9A968F`) | Concrete |
| Lower walls (rooms, corridors): bunker paint | `#5F6863` grey-green, skirting `#2E3132` | SmoothPlastic / Concrete |
| End colour (B, blue end) | `#2F64C8` | the paint line, door frames' stripe, signs |
| End colour (A, yellow end) | `#E0A82E` | same |
| Floors: honed dark concrete (rooms), polished concrete (sunwell) | `#55565A`, `#B9B4AA` | Concrete |
| Black steel (frames, rails, doors, racks) | `#1C1D20` | Metal |
| Brushed steel (pump, pipes, lockers' trim) | `#A7ABB0` | Metal |
| Brass (sun compass, plinth cap) | `#B08D55` | Metal |
| Hazard (blast door edges) | `#E2B93B` / `#1C1D20` | SmoothPlastic |
| Light | sun `#FFE2B8`, cove `#FFF1DC`, corridor `#DDE8F2` | Neon (thin), Beams, few lights |

- **Hero:** the light shaft and the sun on the plinth (the brightest, warmest thing on the map; the brass compass and plinth cap catch it).
- **Landmarks:** each gallery's blast door (yellow-black edges, the team letter beside it), the ring's warm cove line, the pump units.
- **Wayfinding:** the paint line along the low walls is blue in B's half and yellow in A's (charcoal in the pump rooms, which are shared); signs at doors.
- **Phones:** below graphics quality 4 there are no shadows, so the sun lights the whole map evenly there. The lanes then read by value: a light polished sunwell floor, dark honed corridor floors, grey-green lower walls, pale concrete above.

### Budget (plan)
| Item | Budget |
|---|---|
| MeshParts | well under 2,000 (Old Town's 5,900 is too many) |
| Triangles | ≤ 500k in view on phones; ≤ 20k per mesh |
| Lights | under 20 local lights, all shadowless; the sun is the one shadow caster |
| CastShadow | off on pieces under 8 studs (kit_bundle.py) |

---

## 5. Build
1. **Greybox:** `python tools/maps/bunker_layout.py --luau` (then `stylua tools/studio/maps/Bunker`) writes `tools/studio/maps/Bunker/Greybox.luau`: 152 boxes and 2 ramps in sections Sunwell / Shaft / Ring / Gallery / Lockers / Pump / Control / Vestibule / Spawn / Shell, 8 spawns, 4 barriers, at origin (-1500, 200, 1500).

## 6. Decisions for the user
| Decision | Chosen | Other choice |
|---|---|---|
| Middle | A sun plinth (full cover) in the middle of the sunlit dais | An open dais: prettier light, but a 96-stud gallery-to-gallery line |
| Shaft | Square, 24 wide, skylight at 64, sun at the zenith | Round like the Lobby oculus: closer match, but curved collision |
| Levels | Two (ground, ring at +12) | A sunken pit under the shaft: a third level, but the ring would own it |
| Name | Bunker | "Sunwell", "Undercroft" |
