# Overnight maps: approval summary (2026-11-06)

The user asked for every map to be rebuilt overnight to a AAA, front-page bar, and to get an approval summary in the morning. The spec is [Map Quality Standard](../../01%20Design/Maps/Map%20Quality%20Standard.md). The user's notes: [v3 review](2026-11-05%20Maps%20v3%20Review.md), [v4 review](2026-11-05%20Maps%20v4%20Review.md).

**How to test:** in the match place, set the Workspace attribute `ForceMap` to the map id, then Play. Every new map is ForceMap only; the old maps and the map pool are untouched.

## Verdict (final, 05:35)
- **Ready for an eye-test: Rooftops2 (8.3)** (`ForceMap = "Rooftops2"`). Best shots: `vault/02 Art/References/maps/rooftops2/v5-r8-overview.jpg`, `v5-r8-a-roof-tank.jpg`, `v5-r8-side-by-side.jpg`.
- **Not ready, all stopped by the rule:** Dockyard2 7.5, Metro2 6.7, OldTown2 6.3, Bunker2 6.25, Snowpeak2 5.0, Greenhouse2 5.0. Each is still a clear step up from its old version: real modelled kits, no part-built text, no floating parts, one palette, brighter light.
- **The user's calls:**
  1. Approve or comment on Rooftops2.
  2. The layout asks: Bunker2 stair, Snowpeak2 lanes and portals, Metro2 gantry columns, OldTown2 gate arch.
  3. The Greenhouse2 design pass.
  4. Whether to spend Codex on the hero pieces of the other maps. The night's clearest finding is that this is what moves scores.

## Status per map
| Map (id) | Origin | Best blind score (bar 8.5) | Rounds | Ready for approval? | Main gap the reviewers named |
|---|---|---|---|---|---|
| Rooftops2 | (3000, 200, 0) | **8.3** (20/24; 8.5 needs 21; the reviewers' own totals were 9.2, 8.3, 8.8) | v3 7.92 → v4 6.3 → v5 5.8, 7.1, 6.7, 7.1 → r5 8.3, r6 7.9, r7 8.3 → r8 8.3 (AC cover volumes became plant enclosures) | **Yes, for an eye-test.** It's the one map at the bar's edge | The bare spawn strip, repeated enclosures, a flat grey street plane, plain skyline towers. **Core chat saw a floating blue slab top-left in the overview** (likely a water or sky plane): check it |
| Dockyard2 | (-3000, 200, 0) | 7.5 | v5 7.5, 6.3, 6.7 | Not yet | Flat deck fields, lane read |
| Bunker2 | (-3000, 200, 1500) | 6.25 | 4.17, 5.83, 5.00, 6.25 | Not yet | Primitive props; a visible stair from sunwell to ring (**layout change, the user decides**) |
| Snowpeak2 | (-3000, 200, -1500) | 5.00 | 5.00, 4.58, 4.58 → with Codex snowcat, boulders and drifts, a faceted cliff backdrop and golden sun: 4.58, 5.00 (stopped) | Not yet | The flat field needs lanes and cover, spawn portals and an open spawn view (**layout, the user decides**); grey stations; window glow reads flat |
| Metro2 | (3000, 200, 1500) | 6.7 | v1 5.4, 6.7, 6.7, 6.7 → v2 with Codex train 6.7, 6.7 (stopped) | Not yet | The train needs its own trim sheet and bellows instead of the black gangway; flat light; sparse ticket hall. Gantry on platform columns (**layout, the user decides**) |
| OldTown2 | (3000, 200, -1500) | 6.3 | 6.3, 6.3, 6.3 (stopped) | Not yet | Perimeter blocks are tall flat slabs with a repeated window grid (need lower, varied facades); mixed prop finish; flat midday light. The spawn faces a solid wall: a gate arch (**layout, the user decides**) |
| Greenhouse2 | (0, 200, 3000) | 5.0 | 5.0, 5.0, 5.0 → kit v2 (Codex iron bays, arcade walls, planting, lanterns, reflective glass, warm sun) 5.0 | Not yet; **parked for the user** | Reviewers judge glass halls against a garden-heavy concept. The next step is a design pass (outside garden ring, cream iron, Orangery spawn): the user decides |

Whitebox and Big Whitebox are abstract by design and were left as they are.

## What the night showed
- **Audits work.** Every map is at 0 floating and 0 z-fighting. Part-built text and blank signs are gone.
- **The modelling is the ceiling.** Kits modelled headless by the Claude lanes plateau at about 5 to 7. Codex's Blender props were rated better every time they were compared: the Rooftops2 AC cabinet, planter and crates, and the Greenhouse2 IronBay with real filigree.
- **Recommendation:** Codex (or a human modeller) makes the hero pieces of each map from its concept. The lanes build, light and audit around them. The constraint is Codex's Plus budget.
- **Layout asks for the user:** three gaps need layout changes, which are the user's call:
  - Bunker2: a sunwell stair.
  - Snowpeak2: spawn portals.
  - Metro2: gantry columns.

## Housekeeping overnight
- [Map Quality Standard](../../01%20Design/Maps/Map%20Quality%20Standard.md) written.
- Bug 4 fixed: 65,536 empty `LightingPreset` values deleted from the match place.
- Map tools assert the real match PlaceId.
- The Studio lock rule now applies to all lanes.
- The match place is saved to Roblox after each batch.
