# Lobby Rebuild 2026-11-04 (lane A)

**Status: plan approved by the user (2026-11-04, with the clarifications below); phase 3 blockout next.** The Lobby place is back to the bunker exactly as it was before tonight (restored from the in-place archive, 10,020 instances, original lighting). Range brainstorm: [Range Brainstorm](../01%20Design/Range%20Brainstorm.md).

## What happened tonight
1. A first rebuild went in a **bright pastel, flat-colour, open-roof hall** direction (compact, open Duels arena, 3D letter signs). The user saw it and rejected it: **too bright, no textures, dull, and not the bunker.** It is scrapped. It lives only as an archive in the Lobby place (`ServerStorage.Archive.StylizedHub_Scrapped_20261104`) and as the kit script `tools/blender/build_lobby_kit_stylized.py` (its 3D-letter sign builder and coplanar fixes are reusable).
2. Lessons kept from it: the compact plan with all activities in the first view worked; chunky 3D letters on panels read very well from spawn; spinning pad rings and light columns made the pads readable; a SurfaceGui must sit on its own part just in front of a screen mesh (on the mesh face it disappears).
3. **New direction from the user:** keep the **bunker, the same layout and the same idea** as before, just redone properly. Research first, a detailed plan, then the user approves before anything is built.

## Research findings (short)
Sources: two research passes (web summaries, not every page opened; marked where unverified).
- **RIVALS lobby:** queue pads grouped together, a Duel Zone plus a Play button, a big win-streak leaderboard, a weapons room with showcases, the range at one end ([allthings.how](https://allthings.how/roblox-rivals-jump-pad-all-jump-shard-locations-and-unlock-requirements/), [bloxodes](https://bloxodes.com/articles/rivals-beginner-guide)). Exact sizes and distances weren't verifiable.
- **Hub practice:** spawn facing the main activity, every destination with a landmark and its own light mood, zones marked by floor, light and ceiling height rather than walls; oversized hubs and long travel are the top complaint about Destiny's Tower ([GameRant](https://gamerant.com/destiny-2-tower-quality-of-life-changes-needed/), [Roblox guide-the-player wiki](https://redlib.hbubli.cc/r/RobloxDevelopers/wiki/tutorials/guide-to-guiding-players)). LihFolk: first station < 15 s walk, station to station < 10 s, one hero landmark visible from spawn.
- **Valorant look:** "illustrative" balance of realism and cel animation; environments use **tiling textures and trim sheets**, simple values without heavy contrast, detail kept above head height; a few textures do a lot ([Riot: map art](https://playvalorant.com/en-us/news/dev/the-art-of-valorant-map-environments), [Inverse](https://inverse.com/gaming/valorant-art-style-interview-moby-francke), [80.lv](https://80.lv/articles/vibrant-valorant-environment-made-with-blender-substance-3d-painter-unreal-engine)).
- **Stylized texture practice (Overwatch / Valorant-like):** paint the shape into the albedo (lighter bevel edges, darker corners, a soft vertical gradient, a few big stains), keep micro-noise low, let **lighting** carry the contrast ([80.lv Overwatch](https://80.lv/articles/overwatch-technical-overview/?amp=1), [Polycount](https://polycount.com/discussion/comment/2804875)).
- **Roblox:** MaterialVariant (colour + normal + roughness, StudsPerTile) for tiling surfaces; SurfaceAppearance follows mesh UVs and suits trim sheets and hero props; keep maps at 1024 or less (the docs disagree on the hard limit) ([texture specs](https://create.roblox.com/docs/art/modeling/texture-specifications.md), [DevForum](https://devforum.roblox.com/t/upload-custom-materials-in-the-new-material-service-beta/1583158/460)).
- **Bunkers that don't feel dull:** dim cool base plus **warm light pools** at doors, desks and pads; emissive signage; hot/cool rim light; motion (fans, screens, lifts, steam, dust) ([80.lv light and dark](https://80.lv/articles/sci-fi-environment-building-light-and-dark/)).

## User clarifications on approval (2026-11-04)
- The aim was always a **simpler, lower-poly version of the same bunker layout, made more compact**: shorter wings, **fewer things** overall.
- **Not cartoony.** A professional game look with a **tactical feel, but not fully tactical**: clean, grounded, well made.
- **Smooth rounded corners, done properly.** Criticism of the scrapped kit: corners were "one rounded box with a slightly shorter rounded box stacked on it". Every piece needs a designed profile (see Modelling standard).
- Fun, simple, made really well; good research on lobbies; looks better **and performs better**.

## The plan: "Sunwell Bunker, redone"
Same concept: an underground bunker hub, a round **spawn rotunda under a skylight sunbeam**, an outer ring you can slide around, **four wings in the same directions** (Duels north, Market west, Weapons + Locker east, Range south). What changes is **size, look and the four wing interiors**, following the user's earlier notes (too big, separated queue bays, long Market, complicated Range entry, tactical stencil signs, few effects).

### Look (stylized, textured, grounded)
| | Before (tactical) | Scrapped (pastel) | Plan |
|---|---|---|---|
| Shapes | realistic, sharp, detailed | blobby, toy, stacked rounded boxes | **lower poly, professional:** designed profiles with a bevel hierarchy, recessed seams and inset panels, rounded frames and portals, no greebles (see Modelling standard) |
| Surfaces | realistic concrete/oak textures | flat colour | **stylized textures:** painted, low-frequency, light bevel edges, darker corners, soft vertical gradients |
| Palette | grey / black, dark | white + candy | **mid-value and rich:** warm concrete, teal-slate steel, rust-ochre trims, one accent per wing |
| Light | moody, dark wings | flat daylight | **cool base + warm light pools**, the sunbeam over spawn, coloured rim light per wing |
| Signs | stencils on flat panels | candy 3D letters | **3D letters in a bold condensed face** (not a cartoon font) in beveled sign boxes with a lit edge: an industrial sign, clean and confident |
| Motion | little | spinning props | fans, screens, pad rings, light columns, steam, dust, rare glitch flickers |

**Palette (starting values, tuned under Roblox lighting at the style board):**
| Use | Hex |
|---|---|
| Concrete walls (warm) | `#9A8F82` |
| Lower panels, frames, steel (teal-slate) | `#2F4250` / `#2B3A45` |
| Trims, rails, hazard bands (rust-ochre) | `#B8672E` |
| Floors (sand concrete, large tiles) / ring floor | `#8C7F6B` / `#34404A` |
| Rock (warm and cool colour bands, big flat facets) | `#5E5751` |
| Warm lamp / cool fill / sunbeam | `#FFB45A` / `#9CC8FF` / `#FFE2B8` |
| Wing accents | Duels `#FF5A36`, Market `#F2B33D`, Armoury `#3DD9F2`, Range `#FF4757` |
| Glitch accent (under 5% of any view) | magenta `#FF3DCB` |

**Textures:** 6–8 tiling sets at 1024 or less (stylized concrete, painted steel, rock, floor tile, oak, grating, painted trim), made by script like the current lobby textures (`tools/textures/make_lobby_textures.py`, re-tuned to large painted shapes instead of photo noise) and installed as **MaterialVariants**; hero kit pieces (portals, sign boxes, pads, counters) get a shared **trim sheet** baked in Blender with a SurfaceAppearance, the way the guns are textured. Roblox `Color` tints the variants per wing, so one texture set covers every area.

### Layout (compact: the same shape, about a third of the size)
Roblox studs, floor y = 0, spawn at the centre facing north (−Z). Walk 16 studs/s.
| Area | Now | Plan |
|---|---|---|
| Spawn rotunda | R44 (88 across), dome rim 54 | **R30** (60 across), drum 26, dome rim 38, skylight R11 with the sunbeam on the spawn dais (R9) |
| Outer ring | R44–68, 24 wide, 4 rock alcoves | **R30–44**, 14 wide, ceiling 20; rock outer wall with a warm light gap; 2 small seating nooks; slide lap ≈ 230 studs |
| **Duels** (north) | 230-long dark hall, 16 separate bays, Gauntlet chamber | **one open arena** through a 40-wide portal: x −40…40, z −44…−108, ceiling 26. Pads together on one floor: **1V1 ×3** in a centre ring, **2V2 ×2** west, **3V3 ×2** east, mode-coloured rings and light columns; spectator steps and a big queue board on the back wall; a shuttered "COMING SOON" door for 4V4 / Gauntlet. Mood: darker and cooler than the hub, warm pools on each pad cluster |
| **Market** (west) | 280-long winding rock street, 6 shops, cavern | **one short hall** x −44…−84, z −22…22, ceiling 24, through a 28-wide portal: a **Shop counter** (left) and the **Battle Pass wall** (back), one featured turntable in the middle. Warm gold light |
| **Weapons + Locker** (east) | round armoury R42, 8 chapels, hero gun, Locker apse | **round room R22** at x 66: hero gun on a centre plinth, 4 gun turntables, the **Locker** apse at the back (mannequin preview). Cool cyan-white gallery light |
| **Range** (south) | ramp down, viewing gallery, scale model, two gates | **a 14-deep vestibule** behind the south portal ending in one glowing **ENTER RANGE** door (a shimmering portal surface). The real range (RangeFar) is unchanged |
| Footprint | about 550 × 600 | about **176 × 176** |

| From spawn to | Distance | Walk |
|---|---|---|
| any wing portal | ≈ 30 | 2 s |
| nearest queue pad / farthest pad | ≈ 55 / 85 | 3.5 / 5.5 s |
| Shop counter, Battle Pass wall | ≈ 70 | 4.5 s |
| Locker | ≈ 80 | 5 s |
| ENTER RANGE door | ≈ 45 | 3 s |

**First view from spawn:** the DUELS sign over the open arena portal, the pads and their light columns behind it, two leaderboards on the rotunda piers left and right. Turning: SHOP / BATTLE PASS west, WEAPONS / LOCKER east, RANGE south, each portal with its own sign box and accent light.

### Effects and motion (client-only, tag-driven, asleep when far)
Sunbeam (Beams + bright floor hot spot) with dust over spawn; ceiling fans in the ring vents; spinning pad rings, light columns and sparkles per mode; leaderboards, queue board and Battle Pass wall with moving content; hero gun and Locker turntables; steam puffs from arena floor vents; neon signs with a soft pulse and a rare magenta glitch flicker; a shimmering Range door; one slow moving landmark per wing (for example a cargo lift in the Market, a rotating gun rack in the Armoury).

### Quality rules
- **No z-fighting or visible overlaps:** the Blender coplanar audit on every kit (it now also catches overlapping triangles inside a mesh), plus a new Studio audit (`tools/studio/lobby/AuditOverlaps.luau`) over all visible parts: zero same-direction coplanar overlaps, no visible interpenetrations. Joins are hidden inside a covering piece, never on a shared face.
- Collision from simple invisible parts; decor never collides. Tags per the World → UI contract: `LobbySpawn`, `LobbyQueue` (+ `Mode`), `LobbyShop`, `LobbyBattlePass`, `LobbyLocker`, `LobbyRangeEntrance`. `RangeReturnPoint` in front of the Range door.
- Budget: about 20 local lights (2 shadowed), textures at 1024 or less, phone check.

### Phases and approval gates
1. **This plan:** the user approves or edits it.
2. **Style board (gate):** one rotunda bay, a Duels pad with its sign, the Market counter and a sign box, rendered in Blender **and** placed in Studio under the real lighting, with two sign-font options. The user approves the look before the full build.
3. **Blockout** of the compact layout in Studio (plain parts, built beside the current lobby so nothing is demolished until it passes): walk it, screenshot every area from spawn, mid and close, and **write a critique against the reference set** below in this note (what reads, what doesn't, what changes). Only then demolish and build.
   - Reference set: the user's RIVALS lobby screenshots (`01 Design/RivalsMapConcepts/`), the current bunker's final shots (`02 Art/References/lobby/final/`, what to keep from the concept), the scrapped attempt's lessons (above), and the Valorant / Overwatch texture references in the research list.
   - Checks: every wing sign readable from spawn within one camera turn; walk times in the table above; one clear focal point per view; pads readable as one group; no dead floor between areas.
4. **Kit + textures**, import, assemble area by area, screenshot and iterate.
5. **Lighting and effects pass**, audits (zero overlaps), save the place, `.rbxm` backups, notes and the test checklist.


## RIVALS reference study (2026-11-04, after approval)
Sources: the user's RIVALS lobby screenshots (`01 Design/RivalsMapConcepts/`) and frames from a RIVALS lobby walkthrough video (YouTube "All secret room in Roblox Rivals lobby").
- **Duels is a long open hall, not bays:** a central walkway with white chevrons and yellow / purple edge lines, pads set flush into the floor on **both sides** (concentric-ring graphic, coloured outline), a big framed count screen ("0/1") on the wall behind each pad, slanted "1v1" tabs hanging overhead. Nothing separates the pads, so the whole hall reads as one space.
- **Structure, not low poly:** chunky angled buttresses and frames, recessed panels, ribbed ceilings with light strips, framed doorways. Main surfaces carry a soft texture (stone, panel), many parts are just clean smooth plastic.
- **Signs:** neon-outline graphics with an icon (WEAPONS with a rifle outline, SHOOTING RANGE with a target, DUELS between two curved arrows). Bold, readable, a little playful.
- **Spawn:** a round grate platform with a glow, big leaderboards and a season banner around it, wings left and right.
- **Range interior:** bright light-grey panelled room, red / white target graphic on the floor, cove-lit ceiling.
- Light: dark-to-mid base with strong coloured accents (purple, yellow, cyan, orange) and warm practical lights.

**Change to the plan from this (user, 2026-11-04):** Duels stays a **longer hallway, but open and connected** like RIVALS (not the square arena). Not too low poly: structure and texture where it helps, clean smooth plastic elsewhere; a little more rounded and fun, professional.

## Blockout (phase 3) and critique
Built beside the lobby at x + 700 (`Workspace.LobbyBlockoutV2`, `tools/studio/lobby/Blockout_V2.luau`): rotunda R30 with 8 piers, drum and stepped dome to a R11 skylight; ring R30–44 (ceiling 22) with portals N 40 wide, W / E / S 28 wide; **Duels hall 44 × 92 × 28** (walkway 10 wide with chevrons, pads both sides: 1V1 12 × 12 at z −54 and −68, 2V2 14 × 14 at −84, 3V3 16 × 16 at −102, count screens behind, buttress + truss every 19, a 4V4 / Gauntlet "soon" wall at the end); Market hall 40 × 44; Armoury R22; Range vestibule 28 × 16 with the door. Footprint about 180 × 200 (was about 550 × 600).

Critique against the references:
- **Works:** from spawn the DUELS sign sits dead centre in the north portal and the whole hall (pads, screens, end wall) reads through it, like the RIVALS spawn → Duels view. Every pad is visible from the hall entrance. Walk: spawn → nearest pad ≈ 54 (3.4 s), farthest ≈ 105 (6.5 s); Shop / Armoury / Range ≈ 45–70.
- **Weak:** the piers (4 wide) look thin and the colonnade reads as a fence, so they need to be chunkier, with framed portals on the four axes. Market and Armoury are 90° to the side (as in the old design and in RIVALS), so floor guide lines from the dais to each portal, plus portal signs lit in the wing colour, must do the wayfinding. The ring is plain, so it needs rhythm (ribs, light slots, vents with fans). The hall needs the RIVALS details: pad screens, hanging tabs, edge lines, warm pendant lights.
- **Decision:** keep this layout for the build, with chunkier piers (6 × 6), framed axis portals and guide lines.

## Questions for the user (answered 2026-11-04: compact yes, Duels a long open hall, rest as recommended)
1. **Size:** compact as above (recommended), or keep the original sizes?
2. **Duels:** one open arena with all pads together (recommended, from your earlier feedback), or the original long hall of bays?
3. **Weapons wing:** keep a small round armoury with the Locker (recommended), or fold the Locker into the Market and drop the armoury?
4. Anything from the old build you particularly liked and want kept as it was (for example the coffered dome, the oak, the rock)?

## Notes for the other lanes
- The scrapped hub carried the World → UI tags; it's archived, so **the tags don't exist in the Lobby place until the rebuild**. The contract is unchanged.
- **Backups:** the Studio MCP blocks HTTP to localhost, so tonight's `.rbxm` export couldn't be written from Studio. The pre-rebuild Lobby is identical to `art-source/lobby/Studio/Lobby_Professional_20261104.rbxm`, and an archive copy sits in the place (`ServerStorage.Archive`, not saved to the place file yet).
