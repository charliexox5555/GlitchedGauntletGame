# Lobby V5 Plan (2026-11-20): new concept, Parts first

Status: **study and plan only. Nothing built.** Round 2 concepts (indoor, fun, no Gauntlet theme) wait on the owner's pick (§4).

Replaces the direction of [Lobby V4 Plan](Lobby%20V4%20Plan.md) / [Lobby V4 Theme](Lobby%20V4%20Theme.md). V4 stays in `Workspace.LobbyV4Staging` as the live fallback until V5 is approved.

## 1. What the owner wants changed (2026-11-20)
1. **Stop copying RIVALS.** Restart from a new concept that fits our game, above all the duels area.
2. **Too much Blender.** Almost every part was modelled in Blender, which makes the lobby hard to edit. The owner's own Studio builds (`Workspace.NewQueueArea`, `Workspace.PathNew`) look cleaner and more professional.
3. **Merged imports.** Wall runs, panels and trims came in as long merged meshes, so one panel can't be moved or deleted.
4. **Rounded "AI" look** still shows on wall panels and the duels area.
5. **No texture.** Use the MaterialService variants the owner added (the ones RIVALS uses).
6. **Overlaps and glitched parts** that the owner can't fix because of how the meshes were imported.

## 2. What the RIVALS lobby actually does (measured 2026-11-20, `Workspace.LobbyRivals`, read-only)
| | RIVALS lobby | Our V4 |
|---|---|---|
| BaseParts | 2,995 | 3,213 |
| Plain Parts / Wedges | 1,517 (1,300 blocks, 181 wedges, 6 corner wedges) | 1,297 |
| MeshParts | 1,467, from **491 unique meshes** (3x reuse) | 1,915, from **1,373 unique meshes** (1.4x reuse) |
| Parts with a MaterialVariant | **696** | 7 |
| MeshParts with a variant or SurfaceAppearance | **420** | 69 |
| Texture instances | 283 | ~0 |
| Main materials | Metal 749, Plastic 620, Neon 563, Concrete 559 | SmoothPlastic 2,304 |
| Top variants | Concrete-02a (621), Corrugated_02a (106), Pearlescent_01a/b (126), Concrete-01a (52), Wood01a (48), ConcretePanels-02a (32) | Pearlescent_01a (36) |

What that means:
- **Blender is used where Parts can't do the job**: the big angled hallway shells (`PadHallway_02b`, 108x90x36, with Corrugated_02a), door arches, bay doors, and **kit props** repeated many times (TV arms x96, spotlights x42, wall lights x42, pipes x34, crates, signs, support beams, vents). Each is small, named, and used again and again.
- **Everything flat or boxy is Parts**: floors, ledges, steps, pads, trims, panels. Edges are cut with WedgeParts, not rounded.
- **Texture comes from Roblox, not from Blender**: one concrete variant on 621 pieces, tinted per piece with `Color`. Meshes get the same variants (they're UV'd for it), so meshes and Parts match.
- **Textures add the detail**: stripes, hazard chevrons, grates and panel lines are `Texture` instances on Parts (most at 20 studs per tile; light overlays at Transparency 0.75-0.9).
- **A queue pad** (`Queue Pad #1`, 116 instances): 10 blocks + 8 wedges in Metal with Concrete-02a, 10 Plastic blocks, 9 Neon strips, 8 Textures, 15 neon MeshParts (ring icon), a SurfaceGui label. All loose parts in a Model, so any piece can be changed.

What our V4 does wrong (measured): `Duels/Wall_9` is one 162-stud `V_Wall` mesh with full-length `V_Trim` and `V_Low` meshes laid over it, all SmoothPlastic. That's why panels can't be moved, why textures can't be added, and where the overlaps come from.

The owner's own builds confirm the method: `NewQueueArea` is 24 Parts (Concrete-02a walls 24x10x1, Metal panels 11x9.5x1 with Textures, Neon strips, dark pad) and reads better than the Blender bays.

Captures (this session, Studio MCP): RIVALS duels hall, RIVALS pad close-up, RIVALS centre, NewQueueArea in V4.

## 3. The new build method (applies to every V5 piece)
1. **Studio first, Parts first.** Floors, walls, columns, ledges, steps, pads, trims, frames and panels are Parts / WedgeParts / CornerWedgeParts on a **1-stud grid with 4-stud wall bays** (walls 1 stud thick).
2. **One wall bay = one Model** (`WallBay_A_01`, ...): its panel, trim and lamp are separate Parts inside it. Any bay can be moved, swapped or deleted by hand. No piece longer than one bay.
3. **Texture through MaterialService.** Base variants: `Concrete-02a`, `ConcretePanels-02a`, `Concrete-01a`, `Corrugated_01a/02a`, `Wood01a`, `Wood03a/b`, `Diamond Plate`, `Metal`; colour by `Part.Color`. Detail through `Texture` instances (stripes, grates, panel lines). The final palette is picked from the variants already in MaterialService. No new uploads unless a gap shows.
4. **Blender only where Parts can't do it:** angled shells and arches, the hero landmark, and **kit props** (lamps, vents, crates, signs, rails, consoles). Rules for those:
   - One Model per prop and one MeshPart per material, under ~2k triangles. Never merge a run of walls or several props into one mesh.
   - Box-projected UVs at real scale so MaterialVariants work on them, then use the same variants as the Parts.
   - Built in the live Blender MCP session (port 9897 this time), hard-surface / box modelling, flat facets with one chamfer. **No sculpting for lobby pieces** (see §6).
   - Each prop is reused at least 3 times, or it isn't worth a mesh.
5. **Shape rules stay:** no round curves or spheres (angled plates), no blunt cut-offs (wedge-cut ends), no pill or round-bevel panels (`gauntlet-build-style`).
6. **Built by hand-style placement, not a regenerate script.** Pieces go into the place through the Studio MCP once and then belong to the place. No Build module that wipes and rebuilds the lobby, so the owner's edits are never overwritten. Each finished zone is saved as a backup `.rbxm` in `art-source/lobby/v5/`.
7. **Checks after every zone:** a Studio script lists overlapping coplanar faces (z-fighting), Parts inside Parts, and floating props (`rbx-map-kit-audit`, `rbx-prop-support-audit`), plus captures from player height.

## 4. Concept options, round 2 (owner 2026-11-20)
Owner's brief for round 2: **the game is not a Gauntlet any more**, so nothing is themed around a gauntlet, trophy or tournament. The lobby is **indoors** and **fun**. Some of the RIVALS structure stays, but not the repeated four-part bays with nearly the same look. (Round 1's A / B / C are dropped: A was Gauntlet-themed, B was outdoors.)

### What we keep from RIVALS, and what we drop
**Keep (structure and build craft):**
- One compact hub you spawn in, facing the duels area, with every room a short walk away (first station under 15 s).
- Chunky concrete shells with Concrete-02a / Corrugated variants, tinted per piece.
- Ledges and steps with wedge-cut edges.
- Inset queue pads with team-colour edge strips and hazard-stripe Textures.
- One big readable sign over each room's entrance.
- Detailed ceilings: beams, ducts, light fixtures.
- Small props reused in clusters (crates, cases, vents).

**Drop:**
- The long sci-fi hallway with pads down both sides.
- Rows of identical bays (wall panel + trim + low strip + lamp, repeated).
- The dark violet bunker, white bar lamps and glowing word plates.
- Any layout that reads as a RIVALS room.

The three concepts below all keep that structure. They differ in where you are and what the duels area is.

### Concept 1: Laser-tag centre ("the place you go on a Friday night to shoot your friends")
- **The idea:** an indoor laser-tag and paintball centre. It's a real kind of building, made for exactly what the game is: friends showing up to fight in teams. Bright and playful, not military, not sci-fi.
- **Spawn hub:** the centre's front hall. There's a raised check-in counter (the **Shop**) and a wall of team photos and best-player boards. A big window wall looks down onto the arena floor, so the first thing you see is where the fights happen.
- **Duels area: "the airlocks."** Along the arena window sit the entry airlocks, one per mode, each a different size: 1v1 a narrow door, 2v2 wider, 3v3 wider again, 4v4 a big double gate. Each has its own colour light over the door and a screen showing who's queued. Standing inside queues you. When the match is found, the door light turns green, the airlock lights flash and you're sent in.
  - Different sizes and colours per mode, so it's not a row of identical bays.
  - Pads are still inset floor plates with edge strips, which is the RIVALS craft we keep.
- **Locker:** the gear room, with racks of vests and blasters (our guns) on pegboard walls, benches and a mirror wall.
- **Range:** the arena floor itself, a maze of plywood barricades and painted walls with pop-up targets. You reach it through its own airlock.
- **Materials:** painted concrete walls (Concrete-02a in team colours), rubber floor tiles, plywood barricades (Wood variants), diamond-plate stairs, corrugated metal ceiling.
- **Light:** warm house lights in the hall, with colour wash (team blue / orange) on the arena side, so it's bright where people stand and colourful where they fight.
- **Fun bits:** a balcony over the arena you can run along, a scoreboard showing the server's top players, and arcade-style sign boxes.
- **Blender:** blasters on racks (we already have guns), vests, a few light fixtures and the scoreboard frame. Everything else is Parts.
- **Risk:** too much colour light makes it look like a nightclub. Keep the colour to the arena side and the airlocks.

### Concept 2: Indoor sports dome
- **The idea:** a big indoor sports complex where shooting duels are the sport.
- **Look:** high ceilings with steel trusses, daylight through high windows, wood court floors with painted lines, bleachers.
- **Spawn hub:** the centre court. A big four-sided scoreboard hangs over it (the landmark, built from angled plates) and the bleachers rise around it.
- **Duels area: "the courts."** Each mode has its own court off the main hall, sized to the mode: a small 1v1 court, a full-size 4v4 court. Each court has two team halves painted on the floor. You queue by standing in a half, and a scoreboard over the court shows the names. A court fills like a pickup game, which is fun to watch from the bleachers.
- **Shop:** the pro shop and snack bar. **Locker:** a real team locker room with benches and named lockers. **Range:** shooting lanes behind net fences.
- **Materials:** Wood floor variants, painted concrete block walls, steel trusses (Metal), rubber.
- **Light:** bright, clean daylight with big hanging fixtures.
- **Fun bits:** jump pads in the bleachers, a ball you can kick around the centre court.
- **Blender:** the scoreboard, truss pieces and the bleacher seats. Everything else is Parts.
- **Risk:** it can feel like a sports game more than a gun game. It needs gun touches: weapon displays, target art, team kit.

### Concept 3: Warehouse hangout (skate-park club)
- **The idea:** an old warehouse turned into a hangout and duel club, run by players for players.
- **Look:** corrugated metal walls (Corrugated_01a / 02a), concrete floor, wooden ramps and quarter pipes made from angled plates (a perfect fit for our faceted rule), shipping containers turned into rooms, painted murals as decals.
- **Spawn hub:** the main floor, with a skate bowl made of angled plates in the middle that you can run around while waiting.
- **Duels area: "the container yard."** A stack of painted shipping containers along one wall, one per mode, each with a roll-up door and a mode sign. Bigger modes get double containers. You queue by standing inside, and the door rolls down as the match starts. A walkway on top lets people watch.
- **Shop:** a container café-style counter. **Locker:** a container with a gun wall. **Range:** the loading bay with targets on pallets.
- **Materials:** Corrugated, Concrete, Wood, Diamond Plate; graffiti-style signs and murals as Decals.
- **Light:** work lamps and sky through roof panels, warm and gritty but clean.
- **Fun bits:** ramps and rails for movement, a rooftop walkway.
- **Blender:** containers (one mesh reused many times, with variants), ramps where Parts can't do the shape, and the roll-up doors.
- **Risk:** can look run-down or cluttered. Keep it painted and tidy, with one colour per container.

### My pick: Concept 1 inside Concept 3's building
A laser-tag centre built inside a converted warehouse:
- Corrugated metal and concrete shell, which uses the RIVALS-style variants you added.
- Laser-tag airlocks as the duels area, sized and coloured per mode.
- Arena window as the landmark, with a balcony to run on.

It's indoors, fun, made for team shooting, and nothing about it reads as RIVALS or as a Gauntlet. It's almost all Parts; Blender is only for racks, vests, lights and the scoreboard frame.

### ChatGPT image prompts (paste one per concept to get a look image before we build)
1. *Stylised Roblox game lobby, interior of an indoor laser-tag centre built inside a converted warehouse: corrugated metal walls, painted concrete, rubber floor tiles, a big window wall looking down onto a plywood-barricade arena lit in blue and orange, a row of entry airlock doors of different sizes each with a coloured light and a small screen above, a raised check-in counter, warm house lights. Blocky faceted shapes, angled plates instead of curves, crisp cut edges, clean and bright, no text, no people, wide eye-level shot.*
2. *Stylised Roblox game lobby, interior of an indoor sports dome: wood court floors with painted team-colour lines, bleachers, steel roof trusses, daylight through high windows, a big four-sided scoreboard hanging over the centre court, smaller side courts of different sizes, each with its own scoreboard. Blocky faceted shapes, crisp cut edges, clean and bright, no text, no people, wide eye-level shot.*
3. *Stylised Roblox game lobby, interior of a warehouse hangout: corrugated metal walls, concrete floor, faceted wooden skate ramps made of flat angled plates, a stack of painted shipping containers with roll-up doors along one wall with a walkway on top, work lamps, painted murals. Blocky faceted shapes, crisp cut edges, clean, not run-down, no text, no people, wide eye-level shot.*

## 5. Phases
1. **Concept board (now).** Owner picks concept 1 / 2 / 3 (or a mix) and runs its image prompt. References in §7. Then the reference interview from [Model Style Interview](Model%20Style%20Interview.md) on 4-6 picked images.
2. **Concept images.** ChatGPT prompts for the concourse and duels area (memory: concept first, owner approves before building).
3. **Material and kit sheet in Studio.** A small test room built in Parts: the chosen variants, 3 wall bays, a floor, a trim, one gate, one pad. Owner signs off the look before any layout.
4. **Grey blockout of the layout** in Parts (spawn, duels, shop, locker, range door), walk-time checks, captures.
5. **Dress zone by zone** (duels first), Blender props only where §3.4 allows, audit after each zone.
6. **Swap in** for V4 when the owner approves; V4 stays as rollback.

## 6. Tools installed this session
- **blender-skills** (arjun988, MIT, commit in `~/.claude/skill-library/blender-skills/COMMIT.txt`). Safety check: 547 markdown files, no scripts that run, no hooks; its `.mcp.json` (a second Blender MCP on port 9876) was **not** installed. 28 skills that fit our work are in `~/.claude/skills/` (blender-director, blender-modeler, hard-surface, prop-artist, environment-artist, set-dressing, scene-assembly, procedural-modeling, geometry-nodes, lowpoly-style, stylized-style, genre-shooter, materials, texture-workflow, uv-workflow, export-pipeline, collision-proxy, asset-optimization, lod-pipeline, retopology, sculpting, references, qa-review, lighting, lookdev, animation, rigging, vfx-fx). The other 66 (anime, horror packs, Unity/Unreal export and so on) are in `~/.claude/skill-library/blender-skills/` to copy in when needed.
- **Sculpting vs scripting.** The pack's own sculpting skill says not to sculpt hard-surface panels, modular kit pieces, low-poly assets or background props. Our faceted style is hard-surface, so lobby pieces and guns are **box-modelled** (edit-mode modelling through the MCP, one chamfer). Sculpting fits organic forms only: characters, creatures, cloth, damage on hero skins. The rule we use: **always load the Blender skills (blender-director first, then the specialist) before Blender work; sculpt only organic forms.**
- **roblox-map-builder** (the zip). **Proprietary licence: no sharing or redistribution.** This repo is public, so it is installed only in `~/.claude/skills/roblox-map-builder/` and is **not** copied into the vault or git. Safety check: 115 Python, 55 Lua, 14 shell files; no network, no shell calls, no HttpService or `loadstring`; the only `eval` calls run the user's own command-line expressions in its preview tools. Its main pipeline (headless Blender builds the whole map, one GLB per prop, a generated setup module) is the approach we're moving away from, and our rule is live Blender MCP only. Useful parts for V5: `references/layout_patterns.md` and `map_archetypes.md` (layout types), `quality_checklist.md` and `bug_gallery.md` (floating / clipping checks), the "Stud / Parts mode" section (wedge-chamfer tops, framed panels, "no bare blocks", no text built from Parts, one signature edge detail repeated on every ledge).

## 7. References (web search 2026-11-20; "opened" = page read, the rest from search results)
**Walkout and venue ideas (round-1 concept A, dropped; the walkout-door idea lives on in the airlocks)**
- [THE FINALS wiki: Arenas](https://www.thefinals.wiki/wiki/Arenas) (opened): every space is a venue in one show. Take the framing, not the TV-glitz look.
- [SVG: Inside OGN Super Arena](https://www.sportsvideo.org/2019/06/13/inside-ogn-super-arena-the-first-esports-venue-in-north-america-designed-specifically-for-battle-royale/) (opened): an LED walkout tunnel, and each player's station shows their name and stats. Take: a board over each gate showing who is queued.
- [Populous: Etihad Tunnel Club](https://populous.com/project/etihad-stadium-expansion/): a glass wall looking onto the players' tunnel. Take: the lobby watches players walk out.
- [Gladiators (2024 UK)](https://www.wikipedia.org/wiki/Gladiators_(2024_British_TV_series)): a bright arena inside a dark surround, red and blue sides.
- [Snøhetta: Ullevaal Stadion](https://old.snohetta.com/projects/600-ullevaal-stadion): colour-coded industrial floor coating in the tunnel, used for wayfinding.
- [Core77: NBA locker room design](https://www.core77.com/posts/138228/A-Look-at-NBA-Locker-Room-Design) and [AHMM: NBA Performance Center](https://www.ahmm.co.uk/projects/americas/nba-professional-performance-center/): locker ring around one centre point; shop, locker and briefing as separate rooms.
- [THE FINALS wiki: Sponsors](https://www.thefinals.wiki/wiki/Sponsors): fictional sponsors give rooms an identity (shop / locker branding).

**Shooting facilities (useful for the laser-tag arena and range)**
- [Kill house](https://en.wikipedia.org/wiki/Kill_house), [Military Times: Shoot house](https://militarytimes.com/native/range-systems/2018/05/09/shoot-house-intel): observation catwalks over rooms, moving walls.
- [Officer.com: Indoor range design](https://www.officer.com/training-careers/shooting-ranges-equipment/article/21226716/indoor-range-design-considerations): plywood-faced steel baffles, rubber, a range-master booth.
- [Dexerto: Apex Firing Range overhaul](https://dexerto.com/apex-legends/apex-legends-firing-range-gets-massive-overhaul-in-season-17-with-new-map-1v1-pit-movement-practice-2128703) (opened): a dedicated 1v1 Duel Pit next to the range lanes.
- [Rainbow Six: Hereford Base rework](https://rainbowsix.fandom.com/wiki/Hereford_Base_(Rework)), [Valorant: The Range](https://valorant-lore.fandom.com/wiki/The_Range): believable training bases with a story.

**Other hubs**
- [Deadlock wiki: Sandbox](https://deadlock.wiki/Sandbox) (portal from the hub to practice), [Halo Infinite Academy](https://support.halowaypoint.com/hc/en-us/articles/30152458997652-Halo-Infinite-Academy) (drill scores saved), [Murderers vs Sheriffs](https://pixeltwelve.com/games/murderers-vs-sheriffs) (1v1 to 4v4 modes like ours).
- [BuiltByBit: Low Poly FPS Lobby](https://builtbybit.com/resources/low-poly-fps-lobby.109214/): the stock Roblox shooter-lobby layout (central spawn, range, case opening, four queue boards). **Avoid this layout.**
- [DevForum: lobby for Hyperlust](https://devforum.roblox.com/t/new-game-lobby-for-hyperlust/664112): feedback was "busy, no theme". Give players one main feature to gather around.

**Roblox build craft**
- [Roblox docs: Beyond the Dark, building architecture](https://create.roblox.com/docs/resources/beyond-the-dark/building-architecture) (opened): a modular grid and shared trim sheets.
- [Roblox docs: Materials](https://create.roblox.com/docs/parts/materials), [MaterialVariant release](https://devforum.roblox.com/t/ugc-material-variants-upgraded-built-in-materials-release/1886517), [Open Materials Showcase](https://devforum.roblox.com/t/open-materials-showcase-share-your-custom-materials/1852276).
- [Roblox docs: Assemble modular environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/modeling/assemble-modular-environments): consistent pivots and snap settings.
- [DevForum: Parts or MeshParts?](https://devforum.roblox.com/t/should-i-use-roblox-parts-or-meshparts/3753133), [MeshPart performance](https://devforum.roblox.com/t/meshpart-usage-performance-optimizations/1319217): Parts for simple shapes, meshes for repeated detail, unions cost the most.

**Duels-area layouts that aren't a hallway of pads**
1. **Contender gates (A):** short lit tunnels off the hub, one per mode, with a queued-names board above each. The doors open when the match starts, and a window lets the lobby watch.
2. **Arena pit with gates (A/B):** a sunken pit in the hub with four gates around it and a board over each. Standing in a gate bay queues you.
3. **Grid stage (A):** a raised floor of lit cells. Bigger modes take bigger blocks of cells, which light up as they fill.
4. **Facing booths (A/C):** booths face each other across a stage, each with a nameplate screen.
5. **Lift cells under a catwalk (B):** queue cells on lifts that drop away when the match starts, watched from an observation deck.

## 8. Sources used
- Studio MCP, Lobby place: `Workspace.LobbyRivals` (read-only), `Workspace.LobbyV4Staging`, `Workspace.NewQueueArea`, `Workspace.PathNew`, `MaterialService`.
- [Lobby V4 Build](Lobby%20V4%20Build.md), [Lobby V4 Theme](Lobby%20V4%20Theme.md), [Lobby](../01%20Design/Lobby.md), [Rivals Reference](../03%20Research/Rivals%20Reference/00%20Rivals%20Reference.md).
- Skills: `gauntlet-build-style`, `rivals-reference`, `lihfolk-worldbuilding`, the blender-skills pack (sculpting, hard-surface), roblox-map-builder references.
- LihFolk (plugin vault): *Parts Unions and MeshParts* (Parts for structure, MeshParts for repeated or detailed props, Unions only for 1-3 cut-outs); *Materials MaterialVariants and SurfaceAppearance* and *MaterialService and Custom Materials* (renaming a variant breaks every part on it; `Texture` with StudsPerTileU/V for trims); *Modular Environment Kits* (write grid, wall height, thickness and door size first; one pivot rule; z-fighting fix = delete the hidden face or offset 0.01-0.05; no bevels on contact edges); *Lobby and Hub Design* (first station under 15 s, exit under 20 s, spawn faces the centrepiece, blockout playtested on PC and phone before art); *Modeling in Blender for Roblox* (one mesh per piece or colour, bottom-centre pivots, clone instead of re-import).
