# Greenhouse

A medium-large map for 2v2 to 4v4 (playable 1v1): **the Conservatory**, a Victorian botanical glasshouse complex on a bright day. White cast-iron frames, glass roofs that let the sun straight in, jungle beds and palms, a gallery and a bridge over the middle, potting sheds and a service corridor down one flank, an outdoor garden terrace down the other. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** concept. Layout, greybox, kit, art and lighting follow in this note as they're built (§3 onward).

**Map id** `Greenhouse` · **World origin** (1500, 200, -1500) · **Modes** 2v2, 3v3, 4v4, playable 1v1.

---

## 1. One line
Sunlight through a glass roof: a white iron dome over a fountain, palms reaching for the glass, a gallery to fight from, and shaded brick sheds to sneak through.

### What it should feel like
- **Bright, green, clean.** The brightest map in the set, and the only green one. Every other map is stone, concrete or steel; this one is white iron, glass, leaves and water.
- **Readable at a glance.** Three lanes you can name: the **Sheds** (brick, shaded, close range), the **Glasshouse** middle (bright, beds and palms, the dome), the **Terrace** (outdoors, gravel and hedges). Shade and roof type tell you where you are.
- **Foliage that never cheats.** The real cover is masonry: raised beds, planters, tubs, rockeries, hedges in boxes. Leaves live **above head height** (palm and tree-fern crowns) or as **low borders** on top of beds. Nothing at chest-to-head height hides a player.
- **A place, not a box.** One hero shot: standing on the gallery, the fountain below, palms rising into the dome, sunlight striping the floor through the iron ribs.
- **Fair.** 180° rotation. Each team has the Sheds on its left and the Terrace on its right, its own stair to the gallery, its own Fern House and Orangery.

### Not this
A ruined or overgrown greenhouse (no broken glass, weeds, grime), a jungle maze where you can't see players, foliage cards at head height, glass you can see enemies through but not shoot, invisible walls, neon, a copy of any game's layout.

---

## 2. References
Other games' screenshots and photos stay out of the public repo (`References/maps/greenhouse/third-party/` is git-ignored); the sources are linked here. **Nothing has been downloaded yet:** saving the images needs the user's go-ahead (see the hand-off report).

### Real conservatories
| Reference | Take |
|---|---|
| [Palm House, Kew (Grace's Guide, 1848)](https://gracesguide.co.uk/Palm_House,_Kew_Gardens) | The template. Curved wrought-iron ribs every 12 ft 6 in (about 10 studs at our scale) on cast-iron sockets, a **spiral iron stair to a gallery**, a tall centre with lower wings. We use an **8-stud bay rhythm** with a white rib at every joint |
| [Palm House, listing](https://britishlistedbuildings.co.uk/101262670-the-palm-house-kew-ward) | 362 × 67 ft: a tall central block, wings at half height, gallery inside. Our dome block is the tall middle, the wings flank it |
| [Kew Temperate House](https://www.kew.org/about-us/press-media/greatest-glasshouse-in-the-world) | Flat-faced bays, white paint, urns and finials on the parapets: the language of our straight glass walls, the urns on the terrace |
| [Crystal Palace](https://en.wikipedia.org/wiki/The_Crystal_Palace) | **Ridge-and-furrow roof** (a zigzag of small glass gables over flat girders): our hall roofs. It reads as glass from below but is flat overall, so the collision is one plane |
| [Kibble Palace, Glasgow](https://britishlistedbuildings.co.uk/200374930-kibble-palace-botanic-gardens-703-great-western-road-glasgow-glasgow) | A ring girder on slender cast-iron columns with leafy capitals: our gallery columns |
| [Royal Greenhouses of Laeken](https://en.wikipedia.org/wiki/Royal_Greenhouses_of_Laeken) | A domed winter garden over a ring of columns: the dome over the middle |
| [Phipps Conservatory, Palm Court](https://www.phipps.conservatory.org/press-room/press-releases/victorian-architectural-elements-added-in-phipps-conservatorys-historic-palm-court-restoration) | Ridge cresting and tall finials: the dome's lantern and gilded finial, the cresting along the wall tops |
| [Kew Treetop Walkway](https://marksbarfield.com/projects/kew-treetop-walkway/) | A light, open steel deck at canopy height: the bridge over the fountain (open railings, exposed) |
| [Gardens by the Bay](https://en.wikipedia.org/wiki/Gardens_by_the_Bay) | Walkways that wrap a planted centrepiece at two heights; the scale of big glasshouse planting |
| [Barbican Conservatory](https://theculturetrip.com/articles/barbican-conservatory-a-peek-inside-londons-secret-garden) | Masonry and planting together: the brick dwarf walls under the glass and the brick potting range |

### Games
| Reference | Take |
|---|---|
| [CS:GO Biome](https://liquipedia.net/counterstrike/Biome/csgo) | A competitive map in a planted dome: proof that greenery works in a tactical layout if lanes keep sightlines clear |
| [CoD MW3: Growhouse](https://callofduty.com/guides/multiplayer-maps/call-of-duty-guides-modern-warfare-iii-multiplayer-map-guide-growhouse) | Rows of planting beds as cover lanes |
| [Overwatch: Lijiang Tower, Garden](https://dignitas.gg/articles/overwatch-maps-and-you-lijiang-tower) | A clean, stylised garden palette with flanks and one high ground |
| [Apex: Olympus, Grow Towers](https://www.dexerto.com/apex-legends/apex-legends-olympus-map-guide-all-pois-and-locations-1446009/) | Fights in and around glass farm halls, with high ground looking down through glass |
| [RIVALS](https://robloxrivals.fandom.com/wiki/Arena) and [Valorant maps](https://valorant.fandom.com/wiki/Maps) | Simple readable cover, colour for orientation, 180° rotation |

### Foliage and stylisation
| Reference | Take |
|---|---|
| [Stylized trees on Roblox (DevForum)](https://devforum.roblox.com/t/ultimate-guide-to-stylized-trees-on-roblox/1124673) | Leaf variety from a few base shapes with light/dark variants. We skip its alpha cards (see LihFolk below) and model leaves as solid low-poly blades |
| [Stylized Hanging Gardens (80.lv)](https://80.lv/articles/creating-stylized-hanging-gardens-scene-with-foliage-and-architecture) | Silhouette over leaf detail, foliage in depth layers, neutral masonry, a slightly green haze and soft bloom on glass |

### What the LihFolk notes add
- **Foliage** (Foliage Props and Scatter; Mesh Optimization for Mobile): stylised plants as **modelled leaf clumps, flat colour, no alpha cards** (overlapping cards are what kills frame rate); 3–5 base meshes per species reused with yaw and scale; trunk collides, canopy doesn't; keep foliage out of combat lanes. Budgets: bush 100–800 tris, tree 1–5k, hero 5–10k.
- **Glass** (Draw Calls; Rendering Performance): transparent surfaces sort and draw unbatched and overdraw stacks per pixel, so **one layer only**, opaque wherever possible. Our walls are whitewashed (opaque) glass; only the roofs and the dome are see-through, so you look up into sky and never through a wall at an enemy you can't shoot.
- **Water** (Water Sky and Atmosphere Art): no terrain water for a fountain; one or two flat transparent planes at most.
- **Lighting** (Stylized Lighting Recipes): the "bright" preset (Brightness ~2.5, Ambient ≤ OutdoorAmbient), bloom threshold 1.5–2 so white frames don't glow, `LightingStyle` instead of the deprecated `Technology`; check the map with shadows off (phones below quality 4) and in greyscale.
- **Composition** (Level Design Principles; World Composition): one hero per view (the dome and its lantern, seen over the roofs from the Terrace and through the roof glass from everywhere inside), framed from the spawn exits; saturation on the hero and the accents, never on the floor.

---

## 3. Layout (plan; measured numbers follow when `tools/maps/greenhouse_layout.py` runs)
**Shape:** about 152 × 240 studs inside a 40-stud glass shell. **Symmetry:** 180° rotation about the dome's centre; team B spawns at +Z (blue end), team A at −Z (yellow end).

From team B's spawn to the middle:

| Place | Size (studs) | Job |
|---|---|---|
| **Lodge** (spawn) | 32 × 14, ceiling 14 | Out of every sightline. Two side doors (barriers) into the **Vestibules**, which open into the Orangery |
| **Orangery** | 80 × 16, ceiling 20 | The cross hall in front of the spawn: citrus tubs (half cover), a Wardian case in the middle (full cover). Doors to the Terrace (2), the Fern House and the Sheds |
| **Fern House** | 48 × 40, glass to 40 | The middle approach: a long central bed of tree ferns splits it into two aisles, two rockeries as full cover. Side doors to the Terrace and the Sheds |
| **The Dome** (middle) | 80 × 80, dome to ~80 | The landmark: an octagonal iron-and-glass dome over a fountain (basin half cover, pedestal full cover), four palm beds, a **gallery** along each side wall at +12 and a **bridge** across the middle over the fountain |
| **Wings** (east and west) | 32 × 80, glass to 40 | The side lanes past the dome: beds, a lily pool, a rockery each; two doors into the dome |
| **Sheds** (B's left) | brick range, ceiling 14 | Close range: a Potting Room and a Seed Store (benches, shelf racks), a 12-wide service corridor with two boilers as a dog-leg, a boiler yard behind the Orangery |
| **Terrace** (B's right) | 48 × 40 plus a lawn, open sky | The outdoor lane: gravel paths, a lily pond, clipped hedges in boxes (full cover), cold frames (half cover), urns |

### Heights (two layers, 12 apart)
| Layer | Height | What |
|---|---|---|
| Ground | 0 | Everything |
| Gallery | 12 | The two dome galleries and the bridge between them. Each team's stair rises along its end wall of the dome; the drop is the second way off |
| (shell) | 40 | Every glass hall and the Orangery are 40 tall, so the Terrace is a walled garden nobody can climb out of (floor 3 + jump 7.2 + 28 of Updraft = 38.2) |

### Rules this follows
Game Plan §5: three lanes, half cover 3 / full cover 8, doors 8 wide, two exits per room, spawns out of sight, one long line per side at most. "What every map shares": no z-fighting (a coplanar check runs in the layout and art scripts), doors and frames generated from the same numbers as the collision so they always match.

---

## 4. Look
### Palette
| Part | Colour | Roblox material |
|---|---|---|
| Iron frames, ribs, gallery, bridge | white `#F1F1EA` | Metal |
| Wall glass (whitewashed, opaque) | pale mint `#DCE9E2` | SmoothPlastic |
| Roof and dome glass (see-through) | `#CFE6EA`, Transparency 0.55, one layer | SmoothPlastic |
| Dwarf walls, Sheds | brick `#9C5B44` | Brick |
| Copings, bed walls, urns | limestone `#D9D0BE` | Limestone |
| Glasshouse floors | York stone `#C9C1AF` | Pavement |
| Terrace paths | gravel `#CDBF9C` | Pebble |
| Lawn panels | `#7EA35A` | Grass |
| Foliage | palm `#5E8F3A`, fern `#4C8A3E`, deep `#2F6B35`, lime `#9BC24E` | SmoothPlastic / Grass |
| Soil | `#4A3A2C` | Ground |
| Pots, tubs | terracotta `#C0673F` | Brick |
| Sheds timber | `#8C6A48`, sage paint `#7F9C88` | Wood |
| Orangery | stucco cream `#EDE4D0` | Plaster |
| Water | `#5FB0B8`, Transparency 0.35 | SmoothPlastic |
| Finials | gilt `#C9A24B` | Metal |
| **Blue end** (B, +Z) / **Yellow end** (A, −Z) | `#3A6FC4` / `#E0A82E` | Orangery doors, tub bands, shed doors, signs |

Team colours (cyan, orange-red) stay reserved for players and abilities.

### Lighting mood
Bright midday, sun high (about 70°), so the iron ribs throw stripes on the floor and no spawn looks into the sun. Glass is shadowless (the sun comes through), the iron casts. The Sheds have a solid roof: shaded, warmer, the one dim lane. Bright enough on phones with shadows off: white frames, mint glass, green beds and grey stone separate by value.

### Landmarks
- **The Dome** with its lantern and gilded finial, seen through the roof glass from every hall and over the walls from the Terrace.
- **The fountain** under the bridge.
- **The Orangery** facade (cream stucco, tall arched windows) at each end, tinted blue or yellow.
