---
name: gauntlet-model-joins
description: Enforce professional multi-part model joins (union-before-bevel, seated details, matched facet rings, and close-up join renders) on every Blender kit piece, prop, vehicle, weapon or Part-built assembly in GlitchedGauntletGame.
---

# Model joins: every part connects

Load alongside `gauntlet-build-style` before modelling, exporting or reviewing any multi-part model (carts, wagons, wheels, towers, frames, railings, weapons, buildings). Parts that look like separate bevelled blocks stuck together read as AI-made.

- **Union first, then bevel:** combine overlapping shells with a Boolean `UNION` (`EXACT`, `use_self = True`) before applying the 1-segment bevel (~40° angle limit). Verify 1 shell (per truly separate part), 0 non-manifold edges, and no hidden inner z-fight faces. Reference: `obj()` in `tools/blender/maps_canyon/canyon_pieces.py`.
- **Seat, don't stick:** ribs follow body slopes into rims; spokes enter hubs and felloes; stakes overlap boards; bands revolve one profile; flush boards share one plane; seams are deliberate proud rails or cut grooves (never accidental 0.03 steps).
- **Consistent rings & ends:** match facet count and rotation across every ring on a round body; colour changes happen at real edges; never leave blunt cutoffs.
- **Triangles:** spend tris where joins and silhouettes need them (wheels 16–20 facets, hubs 12, typical prop 1–3k, vehicle/tower 8–12k).
- **Close-up join renders before export:** render every join type at 35 mm from 3–6 studs (`tools/blender/maps_canyon/render_closeups.py`) and fix any groove, gap, float, or step before Studio capture. Full notes: [original skill](../../../.claude/skills/gauntlet-model-joins/SKILL.md).
