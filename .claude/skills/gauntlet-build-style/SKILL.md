---
name: gauntlet-build-style
description: The owner's build and modelling style for GlitchedGauntletGame. Load before modelling or building anything players see (maps, lobby rooms, walls, props, fixtures, signs, pads, displays, weapons, characters, ability props) in Blender or Studio, and before reviewing such work. Covers the hard rules (no round curves or spheres: curves are built from angled plates; no harsh corners or blunt cutoffs: carved and angled ends), the reference-screenshot interview that turns the owner's references into a design method, the shape language, how parts must join, texture and lighting levels, colour rules, overlap checks, and the list of things the owner has rejected as "AI-made".
---

# Gauntlet build style

How things must look in this game. The owner's words for the failure case: **"it looks AI"**, "simple rounded parts", "the joints aren't fluid", "no character", "not human made". Reference target: the RIVALS lobby and Valorant environments (chunky, faceted, readable), tactical rather than cute. Our own design, not a copy.

**The owner's brief (2026-11-12):** models are built from **many faces of non-curved shapes**. That balances the look of a realistic model and avoids the pixelated, cubic look of plain blocks. Blocky in spirit, never boxy in execution.

## 0. Hard rules (every model, every time, unless the owner says otherwise for that piece)
1. **No round curves in Blender. No UV spheres, no cylinders with smooth shading, no subdivision surface, no smooth bevels.** A curve is **replicated with angled plates**: a "round" form gets 6 to 12 flat facets (fewer for small parts, more for hero parts), each facet a visible plane with flat shading. A dome is a stepped, faceted cap. A tube is a 6- or 8-sided prism. A rounded corner is 2 or 3 chamfer facets.
2. **No harsh corners and no blunt cutoffs.** A part never just stops with a square end. End it with an **angled or carved shape**: a chamfer, a taper, a bevelled step, a wedge, a notch, a cut-back face. Corners get one to three flat chamfers, never a radius.
3. **Keep it blocky.** The chamfers and facets are big enough to read at game distance (about 3 to 12% of the part's small dimension). This is not a smooth model with tiny bevels; the facets *are* the style.
4. Facet count follows importance: big silhouette facets first, then secondary cuts, and small detail last (see §1.4). Don't facet everything to the same density.
5. Shading: flat or weighted normals so every plane reads as a plane. Auto-smooth only inside a single facet group, never across a chamfer.
6. Check before export: no object with a Subdivision modifier, no mesh whose name or data says sphere / cylinder with smooth shading, no face with more than about 30° normal change smoothed over. Log the check in the vault note.

## 0.5 Reference interview (turn the owner's screenshots into a design method)
When the owner sends reference screenshots for a new style, kind of model or area (the first set is 6 screenshots of models they like):
1. Look at each image and write one line on what you see: silhouette, facet size, edge treatment, proportion, colour/value, detail density, materials.
2. **Interview the owner thoroughly before modelling.** Ask in rounds of 3 or 4 questions with `AskUserQuestion`, **always with suggested options** (your best guess first, marked Recommended) so they never have to invent answers. The question bank is in `vault/02 Art/Model Style Interview.md`. Ask about: what they like in each image, the purpose (hero prop, background, weapon, map kit), facet density, edge treatment, proportions (chunky vs slim), colour and material, detail level, what to avoid, and how close the player sees it.
3. End with the owner's short style brief in their own words (like the brief above), confirmed.
4. Write the **design method** into `vault/02 Art/Model Style Interview.md` → "Design methods": the rules for that style (facet counts, chamfer sizes, typical shapes, a build order, do/don't, which reference shows what). Add the Blender helpers it needs.
5. Build one small test piece, capture it beside the references, and get a yes before the full build.

History, captures and the code that implements this: `vault/02 Art/Sunwell Works Build.md`. Builder helpers: `tools/blender/sunwell_p1/sw_core.py` (`wall_seg`, `cham_rect`, `cut_rect`, `taper_y`, `ring_prism`, `u_frame`, `add_text`), fixtures in `sw_doors.py` (`sconce`, `display`). Reuse them; do not start from plain boxes. **Every object is its own piece:** build it inside `with S.grp("Name", frame, inst=True):` so it becomes a standalone Model in Studio (its meshes, colliders and lights together), and identical pieces share one mesh. Never merge unrelated objects into one mesh.

## 1. Shape language
1. **Facets, not rounded boxes.** A box softened by a bevel modifier is the number one tell. Silhouettes come from planar cuts, tapers and leans.
2. **Edges:** flat chamfers only (one to three segments, never a smooth radius), with weighted normals so flat faces stay flat. Size them to read: 0.035 to 0.12 studs on small trim, up to about 10% of the small dimension on hero parts. Things that are really round (rings, pipes, collars, barrels) are faceted prisms (6 to 12 sides), not smooth cylinders (§0).
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
- **Screens are SurfaceGui** (like RIVALS), never mesh "holograms". Their UI follows the `gauntlet-ui-style` skill (plates with a cut corner, no pills).
- Frames around screens stay quiet: one even case, a bezel, small chamfers. No extra rails, gussets or big decorative cuts.
- Signs: real depth, a backing plate and a mount; letters sunk 0.05 into the plate; nothing floating.

## 4. Colour, texture, light
- **Structure is neutral.** Warm light walls, darker wainscot, dark base, gunmetal steel. **No blue-teal steel**, no colour on walls.
- **One accent per room**, used in the sign, small lamps and floor cues only. Team orange and blue only on duel equipment.
- **Textures: faint.** Flat colour with soft low-frequency variation, about ±4% value, no visible bump, matte (`tools/textures/make_sunwell_textures.py`). Photoreal PBR packs read "too realistic". No fine grain.
- **Lighting:** low specular (about 0.08), soft shadows, real fixtures that make warm pools, a real light beside every glowing lens. If things look too real, check the lighting before the models.
- 3 to 5 value bands per room; interactables are the brightest or most saturated thing in view.

### Lighting in Roblox, learned the hard way (Sunwell hub, 2026-11-13)
- **Local lights usually decide an interior, not the Lighting service.** If changing Ambient or Brightness barely moves a capture, turn every light off and look. Wide point lights (range 30+) flood every surface with the same warm wash, so the room reads as one value band.
- **Pools, not washes:** ceiling fixtures are SpotLights pointing down (angle 70-90, range 18-22), wall lamps are short warm points (range 12-14). Fills are cool and tight. The sun through openings is the key light.
- **Neon clips.** A Neon lens lighter than about `#8C877F` renders pure white; lenses sit around `#7E7870`, and warm glows around `#9C8666`-`#B09270`. Glowing colours look more saturated than their hex: test in Studio, not in a colour picker.
- Cool shade (Ambient about 46,52,64, OutdoorAmbient about 84,94,116) against warm lamps gives depth; a warm ColorShift_Top lights the sunlit tops.
- Rooms with flat slab ceilings read unfinished: a **dropped soffit with a lit cove** (`S.soffit`) or beams fixes it cheaply.
- Lighter Shop/Locker-style wings need the same value steps as the hall: dark base, mid wainscot, lighter wall, darker ceiling.

### Review method that works
- Shoot evidence from the **player's real camera** (inside the spawn alcove, eye height), plus close-ups of every joint, plus **R15 stand-ins (5.5 studs)** for scale; remove the stand-ins afterwards.
- Grade with **three blind reviewers** (different lenses) and use the median; my own grade ran 2-3 points high. Give reviewers the owner's decisions, or they mark them down (wing accents, placeholders).
- Fix the shared notes first; change one thing at a time when the cause is unclear.

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
Spheres and smooth cylinders · subdivision-smoothed parts · square blunt ends on bars, rails and barrels · Rounded-bevel boxes · box lamps and flat black boards · concrete or PBR realism on walls · bare block walls · blue-teal structure · mixed accent colours in one room · mesh holograms · pads of mixed sizes or shuffled modes · a rail and gussets round a screen · trim stubs between a pier and a recess · anything half hidden, retracted or poking out of a wall · thin neon tube letters and sign pictograms. · merged meshes across unrelated objects (every object is its own piece) · flat white Neon panels · trim surfaces that share a plane with the next part (seams; step them 0.06+ or inset them) · bare recesses (line them as one piece)
