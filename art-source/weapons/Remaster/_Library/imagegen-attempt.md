# Concept image-generation attempt

Mode: built-in `image_gen.imagegen`, not CLI. No API fallback was used.

Result: HTTP 400 `moderation_blocked`, category `violence`, input stage. Request ID: `31011556-9359-42cd-b077-5cf92ebf8d30`. No raster output was generated. The model construction continued with Blender-rendered concept sheets rather than attempting to evade the image-generation filter.

Original prompt:

> Create a professional 3D game weapon concept sheet for an ORIGINAL stylised assault rifle called Vandal. Neutral light grey background, three consistent views of THE SAME gun: full clean side orthographic, large 3/4 view, and a small aim-down-sights eye view. Hero shooter craft, Valorant-level detail with RIVALS readability, but absolutely original design not their guns or real weapons. Muzzle points right in side view. Overall short-stroke visual design with broad faceted wedge receiver, stock with angular open triangular negative space, short sturdy handguard with three angled inset vents, slightly forward-curved magazine with clear exposed brass top round, chunky grip. 3.9 unit length, grip origin, +X forward +Z up. Slate blue-grey upper (56607C), near black polymer (1C2030), satin dark steel, one tiny warm gold safety, thin muted cyan accent inset. Clean colour blocks and softly graded panels only, NO grime, noise, scratches, logos or text. Every hard edge crisp one-segment bevel, medium chamfers, shallow panel lines, disciplined large/medium/small hierarchy. Compact SLIM reflex sight: two narrow supports with completely open centre, tiny cyan dot, no giant sight blocks. Physically plausible separated bolt, charging handle, trigger, detachable mag and clean hollow muzzle face. Polished high-end low-poly game art, modelable shapes, clear silhouette, no excessive tiny greebles. Output a single landscape concept.png sheet.

The per-weapon Blender concept design specifications and shared finish are in `remaster.py` (`DESIGNS` and `PALETTE`). The actual delivered concept sheets are the `concept.png` files in each weapon folder. The final palette was refined during the pilot and is shown in `style-sheet.png`.
