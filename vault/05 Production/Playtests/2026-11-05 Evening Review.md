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
- **Lobby UI v2:** the fonts and some of the effects are good, but the rounded, circular look is "very AI looking". It should look like professional games. Next: reference board, then ChatGPT concept screens, then Figma frames, for the Lobby UI and the match HUD. The user approves them before any Roblox build.
- **Lobby world:** the overall structure is good. The user has comments for later. The game and its maps come first.

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

- **LihFolk gap review:** the user likes the whole list, but it waits. The work goes in phases, and the current phase is only what the user picks: maps and UI concepts. The list is parked in [Bugs & Ideas](../Bugs%20%26%20Ideas.md).
- **ChatGPT:** the user uses the ChatGPT/Codex desktop app, not chatgpt.com in a browser.

- **Codex concepts (20 images):** the user says they "look pretty good".
  - They are quality references, **not one-to-one blueprints**: take the quality, silhouettes, materials, height and identity from them, and keep our own layouts and measured numbers.
  - The map rebuild starts, Rooftops first.
  - The UI images go into the §10 board for the user's pick.
- **Match avatar:** a standard avatar in matches only, like RIVALS and Hypershot (blocky, smoother, slimmer arms without a visible elbow/wrist split, built to fit the weapons). The Lobby keeps players' own avatars. **Accessories in matches: hair only** (user's decision). Plan: [Match Avatar](../../01%20Design/Match%20Avatar.md).
- **Bug found and fixed:** the Lobby teleported to its own PlaceId. The match place is 133387545285290 and the Lobby is 71551303511506 (`6e9b6fb`). Research, then a plan in `01 Design/Match Avatar.md`, then the build with per-weapon holds (session `anim-knife`).

## Actions
- Lane E (`lobby-ui-2`): revert the match screens to the v1 look. Keep the inset, clearance and phone-layout fixes where they work under v1.
- Lane E, after that: UI concept pass (reference board, ChatGPT screens, Figma). Results go in [Lobby UI and Queue](../../01%20Design/Lobby%20UI%20and%20Queue.md).
- Lane G (`map-redesign`): concept pass for Rooftops and Dockyard. Plan and results in the map notes, then the user reviews.
