---
name: gauntlet-build-style
description: The owner's build style for GlitchedGauntletGame, learned on the Sunwell Works lobby. Load before modelling or building anything players see (maps, lobby rooms, walls, props, fixtures, signs, pads, displays) in Blender or Studio, and before reviewing such work. Covers the shape language (faceted, tapered, never rounded-bevel boxes), how parts must join, texture and lighting levels, colour rules, overlap checks, and the list of things the owner has rejected as "AI-made".
---

# Gauntlet build style

How things must look in this game. The owner's words for the failure case: **"it looks AI"**, "simple rounded parts", "the joints aren't fluid", "no character", "not human made". Reference target: the RIVALS lobby and Valorant environments (chunky, faceted, readable), tactical rather than cute. Our own design, not a copy.

History, captures and the code that implements this: `vault/02 Art/Sunwell Works Build.md`. Builder helpers: `tools/blender/sunwell_p1/sw_core.py` (`wall_seg`, `cham_rect`, `cut_rect`, `taper_y`, `ring_prism`, `u_frame`, `add_text`), fixtures in `sw_doors.py` (`sconce`, `display`). Reuse them; do not start from plain boxes.

## 1. Shape language
1. **Facets, not rounded boxes.** A box softened by a bevel modifier is the number one tell. Silhouettes come from planar cuts, tapers and leans.
2. **Edges:** one-segment bevels only, 0.035 to 0.12 studs (about 2 to 4% of the part's small dimension), with weighted normals so flat faces stay flat. Round forms only where the object is really round (a lathe: rings, pipes, a collar).
3. **Nothing is a plain upright box.**
   - Walls: a battered wainscot (0.45 to 0.6 proud at the foot, leaning back to the wall face), a sloped belt ledge, a facet crown.
   - Piers and pilasters: flared foot, straight shaft, flared head, a steel shoe.
   - Frames and casings: chamfered or trapezoid outlines, cut corners.
   - Furniture and equipment: leaning fronts, cut top edges, end cheeks one size up.
4. **Big, medium, small.** One clear silhouette, a few secondary forms, small detail last. Keep panel middles quiet; put detail at edges, joints and eye level and above.
5. **Slight asymmetry inside an ordered whole**: one corner cut bigger, a leaning plate. The room stays balanced; the object is not a mirror image.

## 2. How parts join (the owner checks this up close)
1. **Every junction has a transition**: plinth, collar, flange, bracket, gland, or a recessed shadow gap. Never two boxes of different depth butted together.
2. Parts that meet either **share one plane** (split by a 0.1 to 0.15 shadow gap) or are **clearly stepped** (0.1 or more). No near-misses.
3. **One real part = one piece of geometry.** A frame's sill, cheeks and header are one ring (`ring_prism`), not four boxes.
4. **Build it the way it would be made.** Lamp: mount plate with fixings → housing → bezel → lens set back → guard fins → conduit through a gland to a junction box. Pad: floor flange → tray → light channel → deck → clamps → cable duct.
5. Bolts and fixings only where something is actually fixed, on a real corner or mid-side, never on a cut corner.
6. Trim must end cleanly: no stubs of rail, skirting or wall poking out between two larger pieces. If a strip is narrower than about 1.5 studs, let the neighbouring pier or frame fill it.

## 3. Fixtures, props and gameplay objects
- **No plain boxes** for lamps, boards, vents, cabinets, consoles. Each needs a designed silhouette and visible construction.
- Gameplay objects must look **human made and carry meaning**: team letter, one pip per player, footlights that match the pad colour, a status lamp.
- **Queue pads: all the same size, in mode order** along the wall (1v1, 1v1, 2v2, 3v3, 4v4), clear of floor lines.
- **Screens are SurfaceGui** (like RIVALS), never mesh "holograms". Square corners in the UI, no rounded "AI" panels.
- Frames around screens stay quiet: one even case, a bezel, small chamfers. No extra rails, gussets or big decorative cuts.
- Signs: real depth, a backing plate and a mount; letters sunk 0.05 into the plate; nothing floating.

## 4. Colour, texture, light
- **Structure is neutral.** Warm light walls, darker wainscot, dark base, gunmetal steel. **No blue-teal steel**, no colour on walls.
- **One accent per room**, used in the sign, small lamps and floor cues only. Team orange and blue only on duel equipment.
- **Textures: faint.** Flat colour with soft low-frequency variation, about ±4% value, no visible bump, matte (`tools/textures/make_sunwell_textures.py`). Photoreal PBR packs read "too realistic". No fine grain.
- **Lighting:** low specular (about 0.08), soft shadows, real fixtures that make warm pools, a real light beside every glowing lens. If things look too real, check the lighting before the models.
- 3 to 5 value bands per room; interactables are the brightest or most saturated thing in view.

## 5. Overlap and alignment (the owner spots these fast)
- No interpenetrating parts without a deliberate seat; no coplanar faces; nothing floating. Run the geometry audit (`sw_run.audit()`): 0 leaks, 0 floating, and read the coplanar list.
- **Check sightlines, not only geometry**: a beam right above a sign, a hanging sign crossing labels behind it from the doorway, a pad lying over a floor line all count as overlap.
- **The outside matters too**: no two walls sharing a corner block or a face, no collider slabs sticking out. Only the wall running into a corner continues behind the next one.
- Things line up on shared axes: piers frame openings and carry the beams and the lamps; trim heights are the same round a room.

## 6. Before calling it done
1. Close-up captures of every new fixture and every junction, not only wide shots. (Move `workspace.CurrentCamera` into the room first, or screens and lights capture black.)
2. Walk it in play mode. A humanoid steps up anything lower than about 2 studs, so a proud skirting or battered foot needs an invisible stop in front of it.
3. Ask of each piece: is the silhouette more than a box? Does every joint have a transition? Would someone have built it this way? Is anything there only as decoration with no reason?
4. Write the result and the captures into the vault note for the area.

## 7. Rejected so far (do not repeat)
Rounded-bevel boxes · box lamps and flat black boards · concrete or PBR realism on walls · bare block walls · blue-teal structure · mixed accent colours in one room · mesh holograms · pads of mixed sizes or shuffled modes · a rail and gussets round a screen · trim stubs between a pier and a recess · anything half hidden, retracted or poking out of a wall · thin neon tube letters and sign pictograms.
