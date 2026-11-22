---
name: gauntlet-model-joins
description: How every multi-part model in GlitchedGauntletGame must connect (owner 2026-11-21, "things aren't connecting well ... it's gotta look professional"). Load with gauntlet-build-style before modelling, exporting or reviewing any Blender kit piece, prop, vehicle, weapon or Part-built object made of several parts (carts, wagons, wheels, towers, frames, railings, buildings). Covers union-before-bevel, how details must seat into the body, triangle budget (spend tris where joins need them), and the close-up join review that every piece must pass before export.
---

# Model joins: every part connects

**The owner's complaint (2026-11-21, Canyon kit):** "the sides of the carts don't connect well ... they're using the bevel thing ... the wagon sides, the wheels ... the wood and wood-dark connection don't look good. All these things need to connect well." Earlier (Foundry4): "curved boxes", parts that "don't align well, don't flush well". A piece made of blocks that each look finished on their own, touching other blocks, reads as **AI-made**. A professional piece reads as **one object**.

## 1. The cause and the fix (Blender kit pieces)
- **Cause:** a bevel modifier on a mesh of overlapping closed shells bevels every shell's own edges, so each join shows a chamfer groove: ribs, rims, boards, stakes, spokes read as separate blocks stuck on.
- **Fix: union first, then bevel.** Each piece is one solid: build the shells, then a Boolean modifier (UNION, EXACT, `use_self = True`, operand_type COLLECTION with an empty collection), then the bevel modifier (1 segment, angle limit ~40). The join becomes a real merged corner with a small fillet. Materials survive per face. Reference implementation: `obj()` in `tools/blender/maps_canyon/canyon_pieces.py`. Check: the piece is 1 shell (or one per truly separate part), 0 non-manifold edges.
- Union also deletes the hidden inner faces, so it removes the z-fight sources inside a piece.

## 2. Design the join, don't just overlap
- **Seat, don't stick.** A detail sits *into* its body: ribs follow the body's slope and run into the rim; spokes run into hub and felloe; stakes overlap the boards they hold; bands follow the taper (revolve one profile). Nothing hovers 0.02 off a face and nothing touches at a single edge.
- **One face, one plane.** Two boards meant to read as one panel are the same depth (they union into one face); a seam is shown by a deliberate proud rail or a cut groove, never by a 0.03 accidental step.
- **Same facet count, same rotation** for every ring on a round body (hoops, chimes, collars), so they wrap it evenly.
- **Ends are designed:** cut, capped or let into another part (gauntlet-build-style: no blunt cutoffs).
- **Colour changes happen at a real edge** (where one part meets another), not across a flat face.

## 3. Triangles
Low counts are fine, never at the cost of looks (owner). Spend triangles where they buy connection and silhouette: wheels 16-20 facets, hubs 12, round bodies 12-16, union fillets. Typical prop 1-3k tris, a vehicle or tower 8-12k.

## 4. Review before export (every piece, every time)
1. Render close-ups of **every join type** (body/rim, rib/body, spoke/hub/rim, board/stake, post/beam/brace, roof/wall) at 35 mm from 3-6 studs: `tools/blender/maps_canyon/render_closeups.py` is the template.
2. Ask of each: does it read as one built object? Any groove, gap, floating bit, step, mismatched facet count or colour seam mid-face? Fix and re-render.
3. Then the Studio capture at player height. Parts built in Studio (railings, decks, buildings) follow the same rules: overlap 0.05+, never two faces in one plane, trims stepped at distinct depths (0.03+), every member runs into what carries it.
