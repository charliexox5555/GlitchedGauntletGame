# Map lineup round 2 (2026-11-21)

The rotation after OldTown4 has four regular maps (Arena, Pier, Wharf, Snowpeak; 1v1-2v2) and four large ones (Big Arena, Dockyard, Metro, Old Town; 2v2-3v3). The owner wants **five more**: four regular maps, so 2v2 is well covered, and one more large map. Decisions are from 2026-11-21 (owner's picks from my proposal).

| # | Map | Size / teams | From | Idea | Gap it fills |
|---|---|---|---|---|---|
| 1 | **Rooftops** ✅ built 2026-11-21 as [Rooftops4](Rooftops4.md), in rotation | regular, 1v1-2v2 | old Rooftops 1-3 | a city block at blue hour / night: team roofs over a sunken pit, a water-tank tower, plank bridges and catwalks, neon icon signs (no text) | night, verticality |
| 2 | **Greenhouse** ✅ built 2026-11-21 as [Greenhouse4](Greenhouse4.md), in rotation | regular, 1v1-2v2 | old Greenhouse 1-3 | a Victorian iron-and-glass conservatory: planting beds as cover, a lily pond, an iron gallery at +10. Plants are RIVALS plant meshes + LeafyGrass hedges (never low-poly trees) | green, glass interior |
| 3 | **Foundry** ✅ built 2026-11-21 as [Foundry4](Foundry4.md), in rotation | regular, 1v1-2v2 | old Foundry | a steel works at night: a glowing molten channel down the middle, a ladle cart, the furnace as the landmark, catwalks, a gantry crane | warm industrial interior |
| 4 | **Canyon Outpost** ✅ built 2026-11-21 as [CanyonOutpost](CanyonOutpost.md), in rotation | regular, 1v1-2v2 | new (2026-11-03 idea list) | a sun-baked mining outpost in a red canyon: water tower, trading post, mine-cart track; cliffs are the bounds | hot palette |
| 5 | **Castle** | large, **3v3 only** (owner) | new | a hilltop fortress: an inner courtyard, curtain walls with ramparts (high ground), a keep as the landmark, a gatehouse a side, forest past the bounds | new theme, verticality |

**Order:** Rooftops first, then one at a time. Each map gets the usual concept round before any build: layout blockout with checks, then concept-image prompts for ChatGPT, then the owner's approval, then the build.

**Rules for all five:**
- [Map Quality Standard](Map%20Quality%20Standard.md), and the Wharf / Metro4 / Snowpeak4 / OldTown4 way of building: Parts with soft MaterialVariants, Blender kits for props and heroes.
- Audits at 0 / 0 / 0, ReachCheck, nothing reachable on roofs.
- No text signs, no low-poly greenery, no placeholder bricks, no spawn nooks.
- Not too much texture (OldTown4 final check: soft variants without normal maps).
- RIVALS meshes allowed, nothing with a logo; list them in the map note.

**The old maps** (Rooftops, Greenhouse, Foundry and the rest) stay installed for ForceMap and serve as references only.

**Castle at 3v3 only:** its `Config/Match` entry gets `minTeam = 3, maxTeam = 3`.

## Owner instruction for the build run (2026-11-21, owner away)
"Get through all these maps one by one, grade it, make sure it's good, do all the checks ... once they're all done, come back to me", each map in its own fresh session. The owner waived per-map approval for this run. The concept round becomes self-reviewed:
- write layout v1 with checks;
- make a reference board / Blender preview renders instead of ChatGPT images (ChatGPT needs the owner);
- put the ChatGPT prompts in the map note for later;
- self-grade, then build.

Each map lands in rotation (`Config/Match` MAPS) only after its audits pass. Sessions run one at a time: they share the match place and the Blender bridge.

## Research for the run
**Owner verdicts on the old maps** (from [Maps v3 Review](../../05%20Production/Playtests/2026-11-05%20Maps%20v3%20Review.md), [Maps v4 Review](../../05%20Production/Playtests/2026-11-05%20Maps%20v4%20Review.md), [Rooftops2](Rooftops2.md) L216, [Overnight Run 2026-11-16](Overnight%20Run%202026-11-16.md)):
- Rooftops2 was "the weakest map, with no levels and no character". Also: "too many simple shapes", big flat roof floors, a dark pit, AC stacks blocking routes, blocky amateur signs, props not to scale, floating bits, inconsistent colours. The bar: "built by a human, not AI".
- The nine overnight maps (Rooftops3, Courtyard, Bunker3, Foundry, Snowpeak3, ModelKit, OldTown3, Metro3, Greenhouse3) were pulled 2026-11-20 for "curved shapes, plain untextured ground, no world around them, not RIVALS/Valorant-like".
- So Foundry and Greenhouse are rebuilt from scratch, using the old ones as theme references only.

**Old Rooftops numbers** ([Rooftops](Rooftops.md) §3):
- team roofs 96 x 48; pit 40 x 32 at -8 with a lift tower carrying the water tank;
- side towers +8 reached by a gangway / plank ramp; alleys 8 (jumpable) and 16 (bridge); KillDepth 24;
- first sight 1.7-2.0 s: too quick. The target is 3-5 s, like Wharf / Snowpeak4 / OldTown4.

**RIVALS flow references** (measured, [Maps and Lobby](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md) L18-46):
- **Construction** (~125 x 150, spawns 125 apart, 2-4 lanes, longest sight 75, a +22 deck): the best fit for Rooftops / Canyon Outpost.
- **Dimension** (124 x 188, small platforms over a fall);
- **Bridge** (171 x 168, 3-5 lanes);
- **Factory**: Foundry;
- **Village / Gate**: Castle;
- **Studio / Museum**: Greenhouse (glass hall).
- Study, don't copy; RIVALS meshes allowed, no logos.

**Jump:** use the [Jump Audit 2026-11-13](Jump%20Audit%202026-11-13.md) (ledges to 7.5, gaps 9 at sprint), not the older 5.6 in the Map Quality Standard. The layout tool `tools/maps/arena_layout.py` already uses it. It supports `void` (fall) and `bridge` kinds for rooftop gaps.

**How the last four maps were built** (copy this pipeline):
- [OldTown4](OldTown4.md#build-v1-2026-11-21) (newest, most complete);
- [Snowpeak4](Snowpeak4.md), [Metro4](Metro4.md), [Wharf](Wharf.md).

## Owner feedback during the run (2026-11-21, after a look at Rooftops4)
- **Railings are jumpable:** "you can't really jump over the railings like when you go up on a building, which I think should be, so it's easier to walk around." No invisible rail guards over railings or parapets; keep rails low enough to hop (3-3.5). A blocker only where a perch would put players on a roof that must stay out of play.
- **Build checks only:** "I don't really want you to do all these checks on the map like walkability and stuff, because that just takes up a lot of usage ... We're mainly just working on building. Obviously check the build." So from now on:
  - **run:** z-fight (`Audit.luau`), floating (`FloatAudit.luau`), slopes (`SlopeAudit.luau`), and captures to judge the look;
  - **skip:** ReachCheck, route / sightline sims, LockMap playtests, quality-score grading rounds. The owner tests walkability later.
- **Build in chunks (after a look at Rooftops4):** the owner found overlapping parts, gaps, misaligned trims and weak decorations (the lamps): "we kind of need to go in chunks in order for it to just look good and not have these inconsistencies, so we don't have to go ahead and fix them later". So:
  - build one area of the playable map at a time;
  - capture it close at player height from several angles;
  - fix every visible overlap, gap, misalignment, floating prop or inconsistent size before the next chunk.
  Simple decorations (lamps, posts, planters) may be Parts ("those can be built with bricks") when that reads cleaner than a Blender piece: one design per kind, reused everywhere. Textures not over the top. The background outside the bounds matters less. Rooftops4 got a chunk-by-chunk polish pass for this.
- **RIVALS look, less realism (after a look at Greenhouse4):** "a really good looking map, but there's still those inconsistencies" (a doorstep and the bench's iron handles not lining up, bushes over gaps, a bush texture "a little bit too realistic for the game", some weak models). "I don't really want too realistic in maps." For the next maps: "really take inspiration from the museum ... look how Rivals maps are built and the look of them and the feel of them and the meshes ... we're not really hitting those standards right now."
  - From Foundry on, each map starts with a written RIVALS build study: their Museum map plus a few others; mesh style, materials, colours, joins, prop scale.
  - Then build to that stylised standard. RIVALS meshes may be taken (no logos, no scripts).
  - Greenhouse4 got a polish pass for its list.
- **RIVALS textures (owner, 2026-11-21):** "Their textures are insane and really good and nice ... that's really what's I think driving their game." The owner pasted RIVALS' MaterialVariants into the match place under `MaterialService.ExtraTextures`: 241 variants, mostly weapon-skin patterns. The map ones sit on Brick, Concrete, Pavement, Slate, Wood / WoodPlanks, Metal, Grass, Ground, Sand and more.
  - New maps use the variants the RIVALS maps themselves use, checked on their parts, after a render test (permissions, folder).
  - Foundry4 goes first.
  - The four new maps (Rooftops4, Greenhouse4, OldTown4 and others) may be retextured once Foundry shows the result.
  - **Decided (owner, 2026-11-21): yes, retexture after Foundry.** Once Foundry4 shows which RIVALS variants render and look right, the built rotation maps get a RIVALS texture pass: OldTown4, Rooftops4, Greenhouse4, and Wharf / Snowpeak4 / Metro4 where it fits (Arena / Big Arena stay plain by design). It runs in its own session, before Canyon Outpost.
- **Props with purpose, skills removed (owner, after Foundry4):** "a lot of times you kind of just like place things around there without any actual use ... it's all this like mud gun. It just uses those building skills I don't really like ... Delete any skills or instructions that tell you to get those things ... we want low triangle counts, but we have to make it look good. Like look at the Rivals Museum."
  - The user-level skills set-dressing, environment-artist, roblox-map-builder and lowpoly-style moved to `~/.claude/skills-disabled/`; they are not used in map work.
  - Every prop needs a job: cover, a working part of the place, or framing a route. Nothing is placed to fill.
  - The quality bar for props: the barriers ("that kind of style looks good") and RIVALS' Museum.
  - The order now: Foundry4 final fixes + grade; a RIVALS texture pass + grade on OldTown4 (priority), Rooftops4, Greenhouse4 (and Wharf / Snowpeak4 / Metro4 where it helps); then Canyon Outpost.

## Release plan (owner, 2026-11-21)
**Castle is on hold;** Canyon Outpost is the final new map. After it:
1. **Review Canyon Outpost:** a final pass so everything is solid.
2. **Audit all release maps:** part organisation, structure, textures, overall Studio quality.
3. **Clean up legacy maps:** delete every old map that isn't in the release lineup; keep only the release ones.
4. **SFX and VFX where fitting:** sounds from our pro library or other assets, and effects on select maps for polish, depth and character. Don't overdo it; some maps need none (Arena etc.).
5. **Prep and push:** finish the maps, make everything release-ready, and push. Then the owner playtests each map and gives feedback.

**Release lineup:**
- regular (1v1-2v2): Arena, Pier, Wharf, Snowpeak4, Rooftops4, Greenhouse4, Foundry4, CanyonOutpost;
- large (2v2-3v3): BigArena, Dockyard, Metro4, OldTown4.

## RIVALS texture pass (2026-11-21)
After Foundry4, the owner had the other built maps moved onto RIVALS' map textures (`MaterialService.ExtraTextures`), OldTown4 first. Each map note has a "RIVALS texture pass" section with the variant table, captures and grade; the builders apply it as a `RIVALS_REMAP` pass before parenting.

| Map | Grade | What changed | What still holds it back |
|---|---|---|---|
| [OldTown4](OldTown4.md#rivals-texture-pass-2026-11-21) | 8.5 | OT2 stucco / ashlar / cobble / paving → Concrete-02a, Concrete-01a, StoneBlock_01a, Paver_01a/01b; Brick 2022 tower; roofs plain clay tiles; backdrop fields sunk into the valley | roofs a touch busier than the walls, pot-bush leaf texture |
| [Rooftops4](Rooftops4.md#rivals-texture-pass-2026-11-21) | 8 | RV_Brick10 brick, Concrete-01a copings and tar, ConcretePanels-02a pavers, Diamond Plate 2022, Metal 2022 | dark tar roofs flat at blue hour, plain plant boxes |
| [Greenhouse4](Greenhouse4.md#rivals-texture-pass-2026-11-21) | 8 | RV_Brick10, Concrete-01a stone, Paver_01b floors, Paver_01a aprons, Slate02c roofs, Grass_01b, Sand_01b gravel, WoodSiding_01a shed | plain lawns and gravel over big areas, smooth hedges |
| [Wharf](Wharf.md#rivals-texture-pass-2026-11-21) | 7.5 | Concrete-02a quays, Corrugated_01a sheds, Diamond Plate 2022, WoodPlank01a | mostly flat-painted containers; corrugated streaks at grazing angles |
| [Snowpeak4](Snowpeak4.md#rivals-texture-pass-2026-11-21) | 8.5 | Snow_01a, Ice_01b, WoodPlank01a_Big logs (RIVALS Village's set), Wood01a, Concrete-01a | plain stone base walls |
| [Metro4](Metro4.md#rivals-texture-pass-2026-11-21) | 8 | Concrete-01a, RV_Brick10, Diamond Plate 2022 deck (crossheads now flat paint), Corrugated_01a, Paver_01b | busy facade textures (kept) |

Audits after the pass: z-fight 0 / floating 0 / slopes 0 on all six. Next: Canyon Outpost.
