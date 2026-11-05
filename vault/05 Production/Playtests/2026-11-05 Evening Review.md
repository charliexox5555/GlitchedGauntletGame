# Evening review (2026-11-05)

The user played the day's work ([Day Plan 2026-11-05](../Day%20Plan%202026-11-05.md)) after school. Their verdicts and the decisions that came out of them.

## Verdicts
- **Maps, the main verdict: too simple.**
  - The style is better than the old maps, but the models look "unprofessional and dull", like "smooth plastic circles and blocks thrown together".
  - There's no depth and no character.
  - [Rooftops2](../../01%20Design/Maps/Rooftops2.md) is the worst: no levels and no character.
  - [Dockyard2](../../01%20Design/Maps/Dockyard2.md) is better. The crates work because they have texture and meaning; there's still room to improve.
  - Map life: the birds look blocky and bad.
- **Sounds:** good for now. The user will customize them later if needed.
- **Match HUD:** **revert to v1.** The v2 rounded corners "look too AI looking and not professional". v1 also needs improvement, but later.
- **Knife:** good for now, much better. The third-person 5.7 doesn't need a hand-keyed pass now.
- **Lobby:** the overall structure is good. The user has comments for later. The game and its maps come first.

## Decisions (answers to the core chat's questions)
- **Concept first, then build.** No more building blind.
  - First, reference boards and ChatGPT concept images: hero views, a layout or overview, a structure and prop kit sheet, and material swatches.
  - The user approves the concepts before modelling starts.
- **Style target:** Valorant-level detail with RIVALS clarity.
  - Detail: worn materials, trims, panel lines, real silhouettes, a clear place identity, and height levels.
  - Clarity: clean sightlines and bold colour per zone.
- **Maps first:** Rooftops and Dockyard.
- **Surfaces:** custom tileable textures and trim sheets, from the concepts via ChatGPT and Blender, applied as SurfaceAppearance or MaterialVariants within a phone budget.
- **References:** the lane collects screenshots from RIVALS, Valorant, Overwatch, CS2 and Krunker, plus real-world photos. They go into `vault/02 Art/References/maps/<map>/third-party/` and are **never committed**. The user can add their own.
- **Claude Design vs ChatGPT:**
  - ChatGPT image generation for map concepts, structures and texture swatches.
  - Claude Design is for page and UI layouts, not 3D environment concepts. Consider it for the UI pass later.

## Actions
- Lane E (`lobby-ui-2`): revert the match screens to the v1 look. Keep the inset, clearance and phone-layout fixes where they work under v1.
- Lane G (`map-redesign`): concept pass for Rooftops and Dockyard. Plan and results in the map notes, then the user reviews.
