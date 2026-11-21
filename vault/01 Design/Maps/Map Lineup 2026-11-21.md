# Map lineup round 2 (2026-11-21)

The rotation after OldTown4 has four regular maps (Arena, Pier, Wharf, Snowpeak; 1v1-2v2) and four large ones (Big Arena, Dockyard, Metro, Old Town; 2v2-3v3). The owner wants **five more**: four regular maps, so 2v2 is well covered, and one more large map. Decisions are from 2026-11-21 (owner's picks from my proposal).

| # | Map | Size / teams | From | Idea | Gap it fills |
|---|---|---|---|---|---|
| 1 | **Rooftops** | regular, 1v1-2v2 | old Rooftops 1-3 | a city block at blue hour / night: team roofs over a sunken pit, a water-tank tower, plank bridges and catwalks, neon icon signs (no text) | night, verticality |
| 2 | **Greenhouse** | regular, 1v1-2v2 | old Greenhouse 1-3 | a Victorian iron-and-glass conservatory: planting beds as cover, a lily pond, an iron gallery at +10. Plants are RIVALS plant meshes + LeafyGrass hedges (never low-poly trees) | green, glass interior |
| 3 | **Foundry** | regular, 1v1-2v2 | old Foundry | a steel works at night: a glowing molten channel down the middle, a ladle cart, the furnace as the landmark, catwalks, a gantry crane | warm industrial interior |
| 4 | **Canyon Outpost** | regular, 1v1-2v2 | new (2026-11-03 idea list) | a sun-baked mining outpost in a red canyon: water tower, trading post, mine-cart track; cliffs are the bounds | hot palette |
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
