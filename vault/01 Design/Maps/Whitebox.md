# Whitebox

The first map: a clean white test arena floating above the clouds, built mostly from Roblox Parts. It takes the look of RIVALS' Arena and the layout discipline of Valorant's Skirmish maps. See [Maps](00%20Maps.md) for the rest of the roster.

**Status (2026-11-02):** plan approved, and the arena is **built as a Studio model at `Workspace.Whitebox`**, with textures and lighting. **The user approved the layout on 2026-11-02** and is fixing some overlapping parts and refining it by hand in Studio, so the Studio model now wins over `tools/maps/whitebox_layout.py` and the backup `.rbxm` until it's re-saved. Next: map loading, then rounds. "Whitebox" is a working name.

![Whitebox at eye level](../../02%20Art/References/maps/white-arena/whitebox-eye-level.jpg)
![Whitebox in game](../../02%20Art/References/maps/white-arena/whitebox-in-game.jpg)
![Whitebox from the perch](../../02%20Art/References/maps/white-arena/whitebox-from-perch.jpg)

### As built
- **What it is:** a plain Model of anchored Parts, saved in the gauntletgame place, with no runtime script building it. Edit it in Studio directly. Backup: `art-source/maps/Whitebox.rbxm`.
- **Where:** floor top at Y = 200, centred over the Baseplate, so it stays clear of the practice yard at Z = 500. The Baseplate still sits below; you can't see it from inside.
- **Collisions:** box Parts collide exactly, and the ramps are WedgeParts. No Blender meshes were needed.
- **Size:** 74 parts (46 solid), 178 textures, no lights.
- **Scale:** a player stands 5.44 studs tall here. Tested in a playtest: [first walk](../../05%20Production/Playtests/2026-11-02%20Whitebox%20First%20Walk.md).
- **To walk it:** press Play. The Workspace attribute `TestMap` = `Whitebox` spawns you in the Blue alcove. Clear the attribute to spawn in the practice yard again. **Clear it, or decide to keep it, before publishing for testers.**
- **Changed from the plan:**
  - **Texture:** Roblox's default Baseplate grid turned out to be a busy checker, so we made one simple panel texture (`tools/textures/make_whitebox_panel.py`, Decal 115771155467964, image 104451231800023). It's an overlay on each face (Texture objects, 8-stud panels), not a MaterialVariant, and centred on each face so panels sit evenly. If phones struggle, baking it into a MaterialVariant would remove the 178 instances.
  - **Sky:** the existing sky plus Roblox's built-in clouds (`Terrain.Clouds`), so no Blender render was needed.
  - **Slabs:** 13.6 long, which clears the 6-stud gap rule.
  - **Frame posts:** 12 tall, so the lintel is 3 thick (from 9 up).
- **Lighting is place-wide for now**, until `MapService` sets it per map. It was ClockTime 14.5, Brightness 3, Ambient and OutdoorAmbient 70 grey, environment scales 1, no ColorShift. It is now ClockTime 13.3, Brightness 2, Ambient (136,138,150), OutdoorAmbient (150,152,166), ColorShift_Top (255,244,230), EnvironmentDiffuseScale 0.25, EnvironmentSpecularScale 0.2.

---

## 1. One line
A bright, empty proving ground: white panels, hard shadows, a deep blue sky, and nothing on screen except cover and your enemy.

### What it should feel like
- **Instantly readable.** No clutter and no props. Every shape on screen is something you can hide behind, climb or shoot past.
- **Fast.** You reach the middle in about 2.5 seconds, and every lane has room to slide.
- **Fair.** Both ends play identically.
- **Memorable from one shot.** Four tall pillars around a diamond, under a huge sky.

### Not this
Sci-fi neon, decoration that catches bullets, pure #FFFFFF, a copy of RIVALS' exact layout, invisible walls.

---

## 2. References
The images are saved locally in `02 Art/References/maps/white-arena/third-party/` so they show here in Obsidian. They are other games' screenshots and the repo is public, so that folder is git-ignored; the source pages are linked below.

### RIVALS: the look
![RIVALS Arena, first person](../../02%20Art/References/maps/white-arena/third-party/rivals-arena-yt-yfSPM8bE78Y.jpg)
![RIVALS Arena, side view](../../02%20Art/References/maps/white-arena/third-party/rivals-arena-side.jpg)
![RIVALS Arena, top view](../../02%20Art/References/maps/white-arena/third-party/rivals-arena-layout.jpg)
![RIVALS Big Arena](../../02%20Art/References/maps/white-arena/third-party/rivals-big-arena-side.jpg)
![RIVALS Shooting Range](../../02%20Art/References/maps/white-arena/third-party/rivals-shooting-range.jpg)

### Valorant: the layout
![Skirmish A minimap](../../02%20Art/References/maps/white-arena/third-party/val-skirmish-a-minimap.jpg)
![Skirmish C minimap](../../02%20Art/References/maps/white-arena/third-party/val-skirmish-c-minimap.jpg)
![Skirmish in game](../../02%20Art/References/maps/white-arena/third-party/val-skirmish-splash.jpg)

### Other look references
![Mirror's Edge city](../../02%20Art/References/maps/white-arena/third-party/mirrors-edge-city.jpg)
![Portal test chamber](../../02%20Art/References/maps/white-arena/third-party/portal-test-chamber.jpg)

| Reference | Take |
|---|---|
| [RIVALS: Arena](https://robloxrivals.fandom.com/wiki/Arena) | Pale lilac-grey panels with a small + at each corner, a walled box in the sky, angled blocks. Their wiki says it began as a test map made in 5 minutes and is still the most picked: simple is enough |
| [RIVALS: Arena gameplay](https://www.youtube.com/watch?v=yfSPM8bE78Y) | First-person check: walls about three times the height of the cover, shadows give the shape, the sky fills half the screen |
| [RIVALS: Big Arena](https://robloxrivals.fandom.com/wiki/Big_Arena) | The same kit scaled up for 3v3 and larger. We can do the same later |
| [RIVALS: Shooting Range](https://robloxrivals.fandom.com/wiki/Shooting_Range) | Large white pillars as landmarks you can see from anywhere |
| [Valorant: Skirmish maps](https://valorant.fandom.com/wiki/Maps) | Spawn alcoves behind a narrow neck, a centre block, boxes staggered along the walls, tilted double boxes. The minimaps for A and C are 180° rotations, not mirrors |
| [Valorant: Skirmish mode](https://www.thespike.gg/valorant/maps/skirmish) | Same shell with different cover in each variant, which gives us cheap extra maps later |
| [Mirror's Edge: The City](https://mirrorsedge.fandom.com/wiki/The_City) | White against deep blue, with colour saved for one job |
| [Portal: test chambers](https://half-life.fandom.com/wiki/GLaDOS'_testing_track_(Portal)) | Painted signs and floor markings that feel part of the room |

**Gap:** nobody publishes RIVALS' sizes in studs. From the avatar in the top view, its Arena floor is roughly 90 × 150 studs. That's one rough estimate, so use it only as a sanity check.

### What the vault's LihFolk notes add
- Low cover 2.5–3.5 studs, full cover 7+, avoid 4–6 ([Combat Arena and Encounter Layout](../../LihFolk/33%20Level%20Design/Combat%20Arena%20and%20Encounter%20Layout.md)).
- Three lanes, spawns in alcoves out of the main sightlines, and every long sightline needs a matching one on the other side.
- A single high ledge becomes the only spot anyone wants, so the two perches face each other.
- Phones below quality level 4 have no shadows, so the shapes must read from colour alone.

---

## 3. Layout
![Whitebox layout](../../02%20Art/References/maps/white-arena/whitebox-layout.svg)

Generated and checked by `tools/maps/whitebox_layout.py`. Change a number there, rerun it, and it prints the checks below again.

**Shape:** an 80 × 112 room with a 30 × 16 spawn alcove at each end, 144 studs end to end. **Symmetry:** 180° rotation.

| Piece | Size (studs) | Job |
|---|---|---|
| **Diamond** (centre) | 16 × 16, 14 tall, turned 45° | Blocks the straight line between spawns; a four-way peek in the middle |
| **Pillars** (4) | 6 × 6, 48 tall | The landmark; tight peeks around the centre |
| **Side blocks** (2) | 8 × 10, 8 tall | Split the middle into three lanes |
| **Mid walls** (2) | 12 × 3, 8 tall, with a 7 × 3 low wall on one side | Shield each end's approach to the centre; crouch fights on the low side |
| **Perches** (2) | 24 × 20, 7 tall, with a 10-wide ramp | Height advantage, each overlooked by the other team's. Jumpable as well as by ramp |
| **Frames** (2) | Two posts and a low sill between them, a lintel from 9 up | A window to shoot and hop through. The pocket behind it has two exits |
| **Angled slabs** (2) | 14 × 4, 8 tall, turned 28° | The RIVALS angle. Breaks straight lines and takes bullets from wall-penetrating guns (`ThinWall` tag, so they look different) |
| **Wall boxes, corner cubes** | 6 × 10 and 8 × 8, 8 tall | Break up the long wall lanes |
| **Spawn baffles** (2) | 16 × 3, 10 tall | Spawn alcove exits left or right, never straight into fire |
| **Outer walls** | 48 tall | The map edge |

### Measured (from the script)
| Check | Result | Target |
|---|---|---|
| Spawn sees enemy spawn | Never | Never |
| Enemy-half floor that can see a spawn point | 1.0% | Close to 0 |
| Spawn to centre, sprinting | 2.5 s | 2–3 s |
| Spawn to enemy spawn, sprinting | 6.4 s | Under 8 s |
| Tightest walking gap | 6.1 studs (slab beside pillar and wall) | Game Plan says 6 |
| Average / worst distance to full cover | 5.2 / 12.6 studs | Worst under about 15 |
| Longest sightline | **94 studs**, corner to corner, 6.4% of sampled rays are over 70 | Game Plan says about 70 |
| Highest a player can reach | 43.2 studs (8 cover + 7.2 jump + two 14 Updrafts) | Under the 48 walls |

These are flat 2D checks at standing eye height. They don't replace walking it.

**The one rule this breaks:** the long diagonals run past the 70-stud limit. I kept them because the Operator and other scoped guns need a line, and because each side has exactly one, which is what LihFolk recommends. If the greybox shows they dominate, a wider mid wall cuts them.

### Abilities on this size
| Ability | Fit |
|---|---|
| **Firewall** (40 × 10) | Covers half the room's width: strong but not a full seal |
| **Molly / Frost** (9 / 10 radius) | A burst fills any lane gap, which is what we want. Both can be thrown over the walls and are lost, so check that they clean up |
| **Recon** (40-stud reveal) | Flat walls bounce predictably; a dart in the middle reaches most of the room, but cover limits what it sees |
| **Updraft** | Reaches the top of the Diamond; test whether standing there is a fun risk or a problem |
| **Recall** (40 studs) | Can't cross from spawn to the middle (56 studs), which keeps the anchor a real choice |

### No invisible walls
`WeaponService` treats any part a ray hits as blocking, so an invisible wall would swallow bullets and put impacts in mid-air. The walls are taller than anyone can reach instead (48 vs 43.2), and the map stays free of the invisible-wall bugs. A kill plane under the map stays as the safety net.

---

## 4. Look
| Part | Colour (starting point) | Note |
|---|---|---|
| Floor panels | `#DDE0E8` | Lightest surface, never pure white. RIVALS' floor renders about `#C7C9D5` |
| Walls and blocks | `#CFD2DC` | A step darker than the floor |
| Pillars, Diamond | `#B4B9C8` | A step darker again, so they read from far away |
| Panel lines | `#A6A9B8` | Thin, with a + at each corner, on a 16-stud grid |
| Blue end paint | `#3D6FD6` | Wall band and big letter |
| Yellow end paint | `#E0AE2E` | Wall band and big letter |
| Sky | Deep blue, about `#3B88C0` at the top | Big white clouds, the only busy thing on screen |

Colours get re-sampled under real lighting in Studio. The team colours (cyan `#00E5FF`, orange-red `#FF5A36`) stay reserved for players and abilities, so the paint avoids them.

- **The Valorant part:** paint gives orientation and callouts. One end is blue and the other yellow, with big letters (**B** / **Y**) and short names for places (Perch, Frame, Slab, Diamond, Long) that work in 2v2 comms. In a rotated map, this is how you know which end you're looking at.
- **Texture:** one original panel texture, overlaid on each visible face (see As built).
- **Lighting:** a high sun (about 70°) running along the X axis, so wall shadows hit both teams equally and stay short. Warm sun, cool ambient. Bloom stays at threshold 2 or higher so the white doesn't blow out. Lit faces about twice as bright as shaded ones.
- **Avatars on white:** the RIVALS wiki notes players pick white clothes to camouflage. We'll test a white avatar against the walls early, and if it's a real problem, we'll darken the walls first and add an enemy outline last.
- **Event recolours, later:** RIVALS turns Arena black for Halloween. Ours is a colour and sky swap, so it costs almost nothing.

### Parts or Blender
| Use | For |
|---|---|
| **Roblox Parts** | Everything you walk on or shoot: floor, walls, cover, ramps. Sharp boxes are the style |
| **Python** | The panel texture. Blender wasn't needed, and only comes in if a later review asks for a custom sky or special shape |

---

## 5. Build plan
**The user approved the plan on 2026-11-02 and asked for the arena to be built as a Studio model with textures, then reviewed before any game functionality.** Steps 1 and 4 and most of 5 are done (see As built above). Steps 2 and 3 wait for that review, and the model moves from Workspace to `ServerStorage.Maps` in step 2.

1. **Greybox.** Places the layout in the gauntletgame place at the correct sizes. **Stop: you walk it.**
2. **Map loading.** A small `MapService` and `Config/Maps`: clones `ServerStorage.Maps.Whitebox` into `workspace.ActiveMap`, spawn parts tagged `ArenaSpawn_A` / `ArenaSpawn_B`, the map set to stream whole (Persistent) so an enemy never unloads mid-fight, and a test-mode switch to load it in place of the practice yard. No new remotes. Round and draft logic stays out of this: that's the next system after the map.
3. **Play and tune.** Every gun class and all 9 abilities, against dummies and then in a 2-player test. Results go in `05 Production/Playtests/`. Move cover, not art. **Stop: you confirm it plays well.**
4. **Look pass.** Panel texture and MaterialVariant, colour steps, end paint and letters, sky, per-map lighting in `Config/Maps`. Greyscale and no-shadow checks on a phone view. **Stop: you confirm the look.**
5. **Finish.** LihFolk `budgetReport` and `auditWorld`, under 150 parts and no extra lights. Save the place, back up to `art-source/maps/Whitebox.rbxm`, update Asset Tracker and Home.

**After that:** "Big Whitebox" for 3v3 and 4v4 with the same kit (a second map, as RIVALS did), and cover-swap variants of the same shell (as Skirmish did).

---

## 6. Decisions
The user approved these defaults on 2026-11-02.

| Decision | Chosen | Other choice |
|---|---|---|
| **Symmetry** | 180° rotation, like the Skirmish minimaps (RIVALS' Arena top view looks the same, though its wiki calls Big Arena mirrored) | Mirror, the old Game Plan rule |
| **Setting** | Open sky above the clouds | A roofed white hall with skylights: moodier, but loses the sky and limits Updraft |
| **Size** | 1v1 and 2v2 first, the 3v3/4v4 version after | Build one larger map for every mode |
| **Long diagonals** | Keep them, cut them if they dominate | Cut to 70 now, which hurts the scoped-gun rounds |
| **Name** | Whitebox | Anything you like |
