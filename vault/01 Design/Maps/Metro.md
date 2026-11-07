# Metro

A large indoor map for 2v2 to 4v4 (playable 1v1): **Meridian**, an underground metro station. Two side platforms, a sunken track lane between them with two parked trains, a concourse terrace over each end of the hall, service corridors behind the walls. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** built in Studio by the hub and playtested; the user liked it. **Audit pass (same day):** the Studio z-fight audit found 335 (then 142 visible) pairs and the trains read as "train buses". Fixed in the source: every z-fight rule below applied in the kit, layout and art, a new offline check (`tools/studio/maps/zfight_check.py`) now reports **0 pairs**, and the trains are rebuilt as one 52-long two-section unit with an open gangway. Kit re-uploaded (same asset `107161243155344`, new version). Waiting for the hub to rebuild in Studio and re-run `Audit.luau` (run order in §5).

![Metro layout](../../02%20Art/References/maps/metro/metro-layout.svg)

---

## 1. One line
A clean, bright station at rush hour with nobody in it: white tile, a coffered "underground sky", a lit departure board over the middle, and two trains you can run through, under and over.

### What it should feel like
- **Readable at a glance.** Three lanes you can name from your spawn: *West platform*, *Trench*, *East platform*, plus the *Terrace* above and the *Service* corridors behind the walls.
- **Real but not grimy.** Tactical-realistic like Valorant's maps: honest materials, crisp edges, colour used for wayfinding. No litter, graffiti, water stains or flicker overload; it has to sit next to stylised abilities.
- **A place, not a box.** One hero shot: standing on your terrace, the hall in front of you, the departure board glowing amber under the coffers, your train's headlights below you.
- **Big but fast.** About 5 s to the middle, first contact at 5 to 7 s, and a 50 s round still has room for a flank.

### Not this
A ruined or flooded tunnel (BF3 Operation Métro's dark rubble), neon cyberpunk, horror flicker, a maze of identical tunnels, ads and signage everywhere, invisible walls.

---

## 2. References
No third-party images are stored (the folder `02 Art/References/maps/metro/third-party/` is git-ignored if anyone adds some); the sources are linked.

| Reference | Take |
|---|---|
| [Battlefield 3: Operation Métro](https://battlefield.fandom.com/wiki/Operation_M%C3%A9tro) | The genre classic: the platform room is a big space with few pillars, signs and vending machines, and **train cars are the cover and the chokepoints**. Its escalators are the famous meat grinder: ours are sunk in a well so they don't become one |
| [Phantom Forces: Metro](https://roblox-phantom-forces.fandom.com/wiki/Metro) | The Roblox version of the same idea, and proof the theme reads on Roblox. Several routes between the spawns and a central hub |
| [Washington Metro vaults (Harry Weese)](https://docomomo-us.org/news/the-vaulted-architecture-of-the-metro-that-almost-wasn-t) | The coffered concrete ceiling lit from below so the ceiling itself glows: the "underground sky" ([GMU history](https://chnm.gmu.edu/metro/arc2.html)). Our ceiling is flat (it is the collision) but coffered and lit the same way |
| [Toronto TTC station tiles](https://transittoronto.ca/subway/5009.shtml) | Station names set into the wall tile in one bold typeface, with a station colour on the trim. Our name band and the end colours come from this ([blogTO on the colour scheme](https://www.blogto.com/city/2017/03/ttc-subway-colour-scheme/)) |
| [The "Spanish solution"](https://en.wikipedia.org/wiki/Spanish_solution) | A real layout with a platform on each side of the track and doors that open on both sides: why our trains have doors to the platform and to the track |
| [RIVALS](https://robloxrivals.fandom.com/wiki/Arena) and [Valorant maps](https://valorant.fandom.com/wiki/Maps) | Simple readable cover, colour for orientation and callouts, 180° rotation |

---

## 3. Layout
Generated and checked by `tools/maps/metro_layout.py` (the same data writes the greybox script, so plan and build can't drift). Change a number there and rerun it; it prints the checks below and redraws the SVG.

**Shape:** 100 × 228 studs. The hall is 68 wide, 96 long and 28 tall; a concourse level at +14 over each end holds a terrace (the balcony over the hall), a ticket hall and the spawn room. **Symmetry:** 180° rotation, so team A's west is team B's east.

### Levels (three, 14 apart, plus the train roofs)
| Level | Height | What's there |
|---|---|---|
| Track trench | −4 | The middle lane. Two tracks; each train fills one of them in its own half, so the open trench is an S around the trains, with a 7-wide gap between them at the middle |
| Platforms, corridors | 0 | The side lanes, the inside of the trains, the service corridors |
| Train roofs | +10 | Only by Updraft (or a drop from the side of your terrace). Open, exposed high ground |
| Concourse | +14 | Each team's terrace, ticket hall and spawn. Ceilings at 28 everywhere (corridors 12) |

### Pieces
| Piece | Size (studs) | Job |
|---|---|---|
| **Platforms** (2) | 20 × 96 | The side lanes. A column (4 × 4, to the ceiling) every 16 studs down the middle, one kiosk (6 × 6, 10 tall) each, a vending bank and a bench by the wall |
| **Trench** | 28 wide, 4 deep | The low middle lane: crouch-height cover built in. A relay box (3.5 tall) on each open track |
| **Trains** (2) | 10 × 52, one two-section unit each, roof at 10 | Team B's train stands on the east track with a cab at B's end, team A's on the west track (trains stop at the front of the platform). Platform side: 4 open doors (6 wide, every 13 studs) and two 5-wide windows you can see and shoot through. Track side: dark glass (solid) and the 2 inner doors open. An open gangway (black bellows) at the middle, three bogies. Inside: a 9-wide CQB tube |
| **Departure gantry** | full width, from 11 up | The landmark over the middle. It closes the terrace-to-terrace sightline; its clock hangs down between the trains (7 of head room over the track bed) |
| **Terrace** | 60 × 18 at +14 | Each team's perch over the hall, behind a 3-tall parapet. The station-name panel over the tunnel portal (8 tall) splits it into a west and an east perch and stops a drop straight into the trench |
| **Escalators** | 9 × 24, in a well | Two escalators and a fixed stair from the ticket hall down to the east platform (team B). Sunk in the terrace, so you come down out of sight |
| **Hall stairs** | 8 × 22 | Out in the hall on the west platform (team B): the visible way down |
| **Concourse wall** | two 10-wide portals | Between terrace and ticket hall, so the ticket hall and spawn never look out over the hall |
| **Fare gates, ticket office** | gates 3.5 tall | Half cover across the ticket hall; the office is full cover |
| **Spawn room** | 28 × 19 | Two 8-wide doors either side of a 12-wide baffle; barriers in the doors |
| **Service corridors** (2) | 12 wide, ceiling 12 | The flank: from your ticket hall down a stair, behind the hall wall, out through a door at the middle or at the enemy's end. A pump-room block in each gives it a dog-leg |

### Lanes and callouts (team B's view)
- **West:** B stairs → west platform (open track beside it) → under the gantry → the kiosk → A's escalator foot.
- **Middle:** drop into the trench from either platform → the gap between the trains → A's open track.
- **East:** B escalators → east platform along your train (or through it) → under the gantry → A's stairs.
- **High:** your terrace (two perches) and the train roofs.
- **Flank:** east service corridor (yours starts in your ticket hall) → mid door or the far door by A's stairs.

### Measured (from the script)
| Check | Result | Target |
|---|---|---|
| Spawn sees enemy spawn | Never | Never |
| Enemy half that can see a spawn point | 0% | 0 |
| Spawn to the middle, sprinting | 5.4–5.8 s (trench, platforms, corridor) | About 5 s for a big map |
| Spawn to spawn | 238 studs (10.8 s sprint, 14.9 s walk) | 200–260 |
| First sight within 70 studs | 3.9 s sprint, **5.3 s walk** (platform to the enemy's hall stairs) | 5–8 s |
| First sight at any range | 3.3 s sprint, 4.6 s walk (a terrace perch down the far open track, 102 studs) | A glimpse, not a fight |
| First contact | 5.4 s sprint, **7.4 s walk** | About 10 s |
| Tightest walking gap | 6 or more everywhere (columns 7–8 from train and wall, corridor dog-leg 6) | 6 |
| Distance to full cover, hall floor | average 4.1, worst 9.7 | Worst under about 15 |
| Long lines | 4.1% of spot pairs over 70 studs apart see each other, 0.9% over 100; longest 124 (a terrace perch to the far corner) | One long line per side |
| Terrace perch | sees 83% of its own half, 35% of the enemy half; never the other terrace | High ground that doesn't own the map |
| Shell | Sealed: no standing spot outside the walls or above the ceiling | Closed |

The checks are 2.5D (a voxel model with eye-to-eye lines and walking, jumping up to 7 and dropping), not a replacement for walking it. **Watch in play:** the terrace perches (they're the scoped-gun spots), how often people ride the train roofs, and whether the trench mid is too strong for shotguns (it's 7 wide between the trains).

### Abilities on this size
| Ability | Fit |
|---|---|
| **Dash** (12–24) | Across a platform, out of a train door, up out of the trench with a jump. Can't cross the 28-wide trench in one |
| **Updraft** (14–28) | Platform or trench to a train roof; platform to the terrace (14) is reachable with a strong one, which is a real flank: check it |
| **Firewall** (40 × 10) | Seals the trench gap or a platform's width (20) easily: strong in the middle |
| **Molly / Frost** | The trench and train interiors are natural targets; mollies dropped from the terraces |
| **Recall** (40) | Can't reach the middle from the terrace in one |
| **Recon** (40) | A dart under the gantry covers both trains' inner ends |

### No invisible walls
Every wall and ceiling is real and taller than anyone can reach; Updraft into the ceiling just stops you. The trains' dark track-side windows are solid collision on purpose (they read as dark glass).

---

## 4. Look
**Feel:** a modern station cleaned for opening day. Cool, even fluorescent light from the platform pendants and the coffers; warm amber from the departure board and the kiosks.

| Part | Colour | Roblox material |
|---|---|---|
| Wall tile field | `#E7E6E1` warm white | CeramicTiles |
| Dado and plinth tile | `#2E3440` charcoal | CeramicTiles |
| End colour (B, blue end) | `#2F64C8` | name band, portal trim, signs |
| End colour (A, yellow end) | `#E0A82E` | name band, portal trim, signs |
| Platform floor | `#A8A49C` warm grey | Granite |
| Platform edge | `#E8C547` tactile strip, `#8D8A84` coping | Plastic / Concrete |
| Trench, ballast | `#3C3D40`, sleepers `#5A524A`, rails `#9A9EA4` | Concrete / Slate / Metal |
| Coffered ceiling, upper walls, gantry beam | `#A7A49D` concrete (mid grey, so the tile reads against it); coffer panels glow `#B8C8DC` | Concrete / Neon |
| Columns | `#D8D6D0` with a brushed steel base | Concrete / Metal |
| Train body | `#C9CDD2` stainless, stripe in the end colour | Metal |
| Kiosks, vending | stainless and oak; vending fronts red `#B3262E` | Metal / Wood |
| Black steel (gantry, frames, rails) | `#22252A` | Metal |
| Light | cool `#DDE8F2`, warm `#FFB547` (board text), `#FFD9A8` (kiosks) | Neon (thin), a few real lights |

- **Wayfinding is the Valorant part:** B's end is blue, A's end is yellow (same as Whitebox): the name band tiles, the train's stripe, the portal trims and the end walls carry the colour, so you always know which way you face. Team colours (cyan, orange-red) stay reserved for players and abilities.
- **Landmarks:** the departure gantry (amber board, clock), the station-name panels over the tunnel portals (MERIDIAN in tile letters on the end colour), the two trains with their lit cabs.
- **Light plan:** coffers glow (Neon cove strips inside, no real lights), platform pendant lines are Neon tubes; real lights only at focal points (departure board, kiosks, escalator wells, cab headlights, ticket hall): 16 shadowless lights in the whole map.
- **Phones:** no shadows below quality 4, so the lanes read by value: dark trench, mid-grey platforms, white walls, bright coffers.

### Budget (as built)
| Item | Budget | Built |
|---|---|---|
| Triangles | ≤ 500k in view on phones | **51k for the whole map** (257 kit pieces of 28 kinds, 12.7k unique tris) plus 156 greybox parts |
| Per mesh | ≤ 20k | largest object 1.4k (escalator nosings); largest piece 2.4k (EscalatorBank) |
| Textures | ≤ 512 px | none: base materials and colour, no MaterialVariants needed in the match place |
| Lights | a few at focal points | 16 PointLights/SpotLights, all shadowless |
| CastShadow | off on small parts | kit_bundle.py: only pieces 8+ studs cast; greybox ceilings cast (they keep the inside dark) |

### Kit (group `Station`, asset `107161243155344`)
`tools/blender/build_map_kit_metro.py` → `art-source/maps/Metro/Kit_Metro.blend`, 28 `Map_<Piece>` collections: `WallBay8`, `WallEnd4`, `WallDoor8`, `NameSign`, `Coffer10`, `Coffer14`, `PendantLight`, `Column`, `PlatformEdge8`, `PlatformEdge8Plain` (no tactile strip, under the hall stairs), `TrackBay8`, `TrackBox`, `Train` (the whole unit), `EscalatorBank`, `HallStairs`, `CorridorStair`, `Gantry` (board, platform signs, station clock), `EndWall` (tunnel portal, buffer stop, signals, name panel, parapets, escalator mouth), `Kiosk`, `Vending`, `Bench`, `FareGateRow`, `TicketOffice`, `Portal10`, `DoorFrame8`, `PipeRun8`, `CorridorLight`, `PumpDoor`. Parts ending `_Band`, `_Stripe`, `_Trim` take the end colour in Studio (Art.luau). Signs are SurfaceGuis made by Art.luau (the text in the renders is a preview stand-in).

![Contact sheet](../../02%20Art/References/maps/metro/contact-station.jpg)
![From team B's west perch](../../02%20Art/References/maps/metro/preview-terrace.jpg)
![West platform toward B's end](../../02%20Art/References/maps/metro/preview-hall.jpg)
![The trench gap under the clock](../../02%20Art/References/maps/metro/preview-trench.jpg)
![Team B's train from the east platform](../../02%20Art/References/maps/metro/preview-train.jpg)

The previews are Blender EEVEE stand-ins for the Roblox look (no end-colour tint: both trains show blue there). Review notes from them, already applied: the ceiling concrete was darkened so the white tile reads against it, the kiosk body went stainless (it read as a black box), the column capitals were slimmed, the platform-side door leaves were removed (they covered shoot-through windows), the clock ticks were moved onto the face.

---

### No z-fighting (audit pass, 2026-11-03)
The Studio audit (`tools/studio/maps/Audit.luau`) found overlapping same-plane surfaces: layered wall bands sharing end faces (skirting behind dado, field behind the cove, rib against the upper concrete), the platform-edge cladding flush with the greybox slab, column base and skirting sharing a bottom, glows flush with their housings, frames ending exactly on greybox faces, buried bottoms and ends. The rules now built into the kit (comment block above the pieces in `build_map_kit_metro.py`):
- **Bands meet edge to edge**, never one behind another: skirting 0..0.35, dado from 0.35, field segments stop under the cove shelf and the band trims; the rib stands in front of the upper concrete.
- **Anything on a surface stands proud by ≥ 0.06** (P): platform-edge cladding off the slab face, coping and tactile strip above the floor, glows, screens, sign faces, stripes, dark glass, frames, thresholds.
- **Neighbours don't share an end plane:** platform-edge bays and pipe runs are 7.9 long (0.1 joints), escalator and stairs end 0.1 short of the top, the gantry runs 0.6 into the hall walls, stair nosings are 0.03 narrower than the treads (so whole-part bounds don't coincide either), the end-wall cladding stops short of the side walls' cladding.
- **Greybox and kit never coincide:** liners stop 0.03 short of the corridor face, the escalator-mouth post stops 0.03 short of the terrace block, the barriers sit inside the spawn door liners and under the head, the relay box moved off the track-bay joint (layout: z 29..35).
- **Layout fixes found on the way:** the terrace block now meets the escalator well (it left a 1-wide slot beside the escalators), the corridor head starts above the corridor ceiling (they shared a face), the ticket-hall north wall is 1 thick and reaches the spawn room's side walls (it left a 2 × 1 notch where the door frame floated), the spawn door frame keeps its trim on the ticket-hall face only.

**Doorways:** every frame matches its greybox opening (service doors 8 × 10 through the 2-thick hall wall, portals 10 × 10 through the 2-thick concourse wall, spawn doors 8 × 10 through the 1-thick wall), with steel liners in the reveal and the trim proud on the face. **Trains:** rebuilt from short "bus" cars (25 long, a door every 10 studs) into one 52-long unit with doors every 13, windows between, an open gangway and a Jacobs bogie under it; no part crosses another (the old dark glass even spanned an open track-side door).

**Second audit (34 pairs left):** Studio's ray audit hits a kit part's *bounds* (the kit's MeshParts have Box collision fidelity), so a part made of several separate boxes counts as one big box: the field segments' box covered the cove, the two stair sides' box spanned the treads, the frame's box spanned the barrier, the train's light strips and route signs shared a top plane. Fixed by making those parts single boxes (wall `Field`/`FieldMid`/`FieldTop`, `Cove`/`CoveLip`, `BandEdgeLow`/`BandEdgeHigh`, stair `SideL`/`SideR`, end-wall `ParapetW`/`ParapetE`, `CapW`/`CapE`) or by moving the shared plane (first/last nosing 0.03 in, escalator decks and corridor rails in from the ends, route sign to 8.2, train skirts out to ±4.75, barriers 0.1 inside the spawn doors' wall faces, product colour groups on their own planes).

**Check it offline:** `python tools/studio/maps/zfight_check.py Metro Station` bundles the map, runs it in Lune against a mock place (`tools/studio/maps/mock_place.luau`), and tests the assembled map in Blender twice (`tools/blender/check_map_zfight.py`): polygon by polygon, then with every kit part as its bounding box, the way Studio's audit sees Box-fidelity parts. Exit code 1 if either pass finds a pair. Run it after changing the layout, the kit or `Art.luau`, after re-exporting and before uploading. Result now: **0 pairs** in both passes (25,714 polygons; 7,800 bounds faces).

## 5. Build
1. **Greybox:** `python tools/maps/metro_layout.py --luau` (then `stylua` on it) writes `tools/studio/maps/Metro/Greybox.luau`: 150 boxes and 6 wedges in sections Hall / Train / Concourse / Corridor / Spawn / Shell, 8 spawns, 4 barriers; the train's side sheets are tagged `ThinWall`.
2. **Kit:** `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/build_map_kit_metro.py -- [--no-render]`, then export (`export_lobby_kit.py -- --maps Metro Station`), **check** (`python tools/studio/maps/zfight_check.py Metro Station`, must print 0 pairs) and upload (`upload_models.py --maps Metro --group 11116787 Station`).
3. **Art and light:** `tools/studio/maps/Metro/Art.luau` places the kit (each placement in team B's half and its 180° turn), hides the greybox it replaced (collision kept), finishes the rest (granite floors, tile concourse walls, concrete corridors), tints the end colours and makes the signs; `Lighting.luau` adds the map's `Lighting` Configuration (no sun: ClockTime 0, Brightness 0, cool Ambient), `LightingFx` (Atmosphere, Bloom, ColorCorrection) and 16 shadowless focal lights in `Art.Lighting`.
4. **Tested without Studio:** the full bundle (Greybox + Art + Lighting) runs clean in Lune against the mock place: 156 greybox parts, 257 pieces placed, 30 signs, 16 lights; 0 z-fighting pairs.
5. **Run order** for the hub (match place, edit mode, Studio MCP or Command Bar):
   1. `python tools/studio/maps/kit_bundle.py Metro Station -o metro_kit.luau` → run it (installs `ServerStorage.MapKit.Metro`; it removes the group's old pieces, so `TrainCarHead`, `TrainCarTail` and `TrainGangway` go). Then set CollisionFidelity Box on the kit as for the other maps, if that's the hub's habit.
   2. `python tools/studio/maps/bundle.py Metro Greybox Art Lighting -o metro.luau` → run it (re-runnable; it rebuilds `Workspace.Metro` at (1500, 200, 0): the greybox changed, so run all three).
   3. Re-run `tools/studio/maps/Audit.luau` ("Metro"): target 0 pairs.
   4. Set the Workspace attribute `ForceMap` to `Metro` and press Play to see the lighting (MapService applies it on load).
   5. Screenshots, then save the place and back up `art-source/maps/Metro/Metro.rbxm`.

### What to check in the screenshots
- **Orientation of the kit:** the trains sit on the tracks with their wheels on the rails, cabs at both ends, the gangway bellows at the middle, platform-side doors facing the platforms and lined up with the greybox door gaps; the escalator steps go up toward the ticket hall; the end wall's tunnel portal lines up with the trench and its escalator mouth with the well. If anything is mirrored or turned 180°, the axis note in `kit_bundle.py` is the place to look.
- **Signs:** MERIDIAN reads the right way round on the name panels and wall bands, the departure board's two faces each show DEPARTURES with three amber rows and PLATFORM 1 on the east side, kiosk/ticket/portal signs aren't mirrored or on the wrong face.
- **End colours:** B half blue, A half yellow (bands, column bands, train stripes, trims), charcoal on the middle door bay, amber gantry trim.
- **No gaps:** coffers tile the hall ceiling edge to edge (the greybox ceiling is invisible but still casts shadow); the wall bays meet the end walls; nothing of the void shows above the corridors or behind the portals.
- **Light:** the hall should be evenly cool with the coffer panels glowing, warm pools at the board and kiosks, the tail-cab headlights down the trench. If Neon coffers bloom too much, darken `Coffer*_Panel_Glow` colour; if the hall is too dark, raise `Ambient` in `Workspace.Metro.Lighting`.
- **Readability:** the dark trench, mid-grey platforms and white walls stay distinct with shadows off (phone quality); a player in the trench and on a train roof is easy to spot.
- **Shots:** each spawn, each terrace perch, both platforms at the gantry, the trench gap under the clock, inside a train, a service corridor, the ticket hall and a top-down overview.

## 6. Decisions for the user
| Decision | Chosen | Other choice |
|---|---|---|
| Trains | Two, staggered (one per half, each on its own track) | One centred train: simpler, but kills the open-track lane |
| Train windows | Platform side see- and shoot-through; track side dark (solid) | All open: the trains stop being cover |
| Terrace drop into the trench | Blocked by the name panel | Open: faster middle, first sight at 3 s |
| Name | Meridian | Anything you like |

## Concepts (Codex)
- [01-overview.png](../../../art-source/maps/Metro2/concepts/01-overview.png) - Initial whole-arena aerial cutaway.
- [01-overview-v2.png](../../../art-source/maps/Metro2/concepts/01-overview-v2.png) - Preferred aerial: two straight tracks and staggered trains.
- [02-hero.png](../../../art-source/maps/Metro2/concepts/02-hero.png) - Blue concourse terrace toward the gantry and trains.
- [03-kit-sheet.png](../../../art-source/maps/Metro2/concepts/03-kit-sheet.png) - Structure pieces, train, props and material swatches.
