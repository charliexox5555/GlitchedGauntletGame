# Lobby V5 Plan (2026-11-20): new concept, Parts first

Status: **study and plan only. Nothing built.** Waiting on the owner's concept pick (below).

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

## 4. Concept options (owner picks one, or mixes)
The game: short run-and-gun duels, a draft of Mods every round, a weapon tier that climbs, and later scheduled 16-player **Gauntlet** events. Glitch theme was shelved on 2026-10-28 ("classic gun game"). The V3/V4 lore was an underground training bunker.

**A. The Gauntlet tournament (stadium backstage).** The lobby is the contenders' side of a televised tournament: a locker-room concourse, player tunnels that lead out to the "stage", scoreboards and camera rigs. **Duels area = a row of contender gates**: each gate is a tunnel mouth with a scoreboard and a mode sign (1v1, 2v2, 3v3, 4v4) above it; you queue by standing in the gate, and the match starts as if you walked out of the tunnel. Materials: concrete, painted steel, rubber floor, team-colour tape lines, broadcast lights. Fits the Gauntlet event name, rounds and rising stakes. Different from RIVALS' sci-fi hallway. Risk: must not drift into THE FINALS' game-show look; we keep it as sports backstage, not TV glitz.

**B. Proving grounds (outdoor training compound).** A daylight or dusk compound: shipping containers, concrete barriers, a shoot-house, catwalks. **Duels area = a yard of open-top fighting rings** made of concrete barriers and chain-link panels, with team-colour floor paint, a judge tower in the middle. Bright, readable, very different from RIVALS. Risk: closer to generic military shooters; needs one strong landmark.

**C. Underground fight club / arcade hall.** A converted industrial hall (brick, corrugated metal, wood floor) where duels are a sport: raised square rings with posts and ropes made from angled plates, bleachers, a big tournament bracket wall that shows live matches. Warm lights, more personality. Risk: furthest from the old lore; brick and wood need care to stay clean.

**My pick: A**, with B's outdoor sky glimpsed through the tunnel ends. It ties the lobby to the game's name and rounds, gives the duels area a clear "walk out to fight" moment, and is built almost entirely from Parts (tunnels, gates, benches, lockers) with a few Blender props (lights, camera rigs, scoreboard frames).

## 5. Phases
1. **Concept board (now).** Owner picks A / B / C. References in §7. Then the reference interview from [Model Style Interview](Model%20Style%20Interview.md) on 4-6 picked images.
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
**Tournament / backstage (concept A)**
- [THE FINALS wiki: Arenas](https://www.thefinals.wiki/wiki/Arenas) (opened): every space is a venue in one show. Take the framing, not the TV-glitz look.
- [SVG: Inside OGN Super Arena](https://www.sportsvideo.org/2019/06/13/inside-ogn-super-arena-the-first-esports-venue-in-north-america-designed-specifically-for-battle-royale/) (opened): an LED walkout tunnel, and each player's station shows their name and stats. Take: a board over each gate showing who is queued.
- [Populous: Etihad Tunnel Club](https://populous.com/project/etihad-stadium-expansion/): a glass wall looking onto the players' tunnel. Take: the lobby watches players walk out.
- [Gladiators (2024 UK)](https://www.wikipedia.org/wiki/Gladiators_(2024_British_TV_series)): a bright arena inside a dark surround, red and blue sides.
- [Snøhetta: Ullevaal Stadion](https://old.snohetta.com/projects/600-ullevaal-stadion): colour-coded industrial floor coating in the tunnel, used for wayfinding.
- [Core77: NBA locker room design](https://www.core77.com/posts/138228/A-Look-at-NBA-Locker-Room-Design) and [AHMM: NBA Performance Center](https://www.ahmm.co.uk/projects/americas/nba-professional-performance-center/): locker ring around one centre point; shop, locker and briefing as separate rooms.
- [THE FINALS wiki: Sponsors](https://www.thefinals.wiki/wiki/Sponsors): fictional sponsors give rooms an identity (shop / locker branding).

**Training compound (concept B)**
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
