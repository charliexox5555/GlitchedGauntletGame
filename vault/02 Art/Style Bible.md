# Style Bible

**The one page on how GlitchedGauntletGame looks, sounds and feels.** Read it, or load the matching skill, before building or designing anything players see or hear. It points to the detailed notes and doesn't replace them. Where a detailed note is newer, the newer note wins; fix this page when that happens.

Last updated 2026-11-12. Skills that enforce it:
- `gauntlet-build-style`: models, maps, lobby, props
- `gauntlet-ui-style`: UI, HUD, menus, boards

**Game in one line:** RIVALS-style run-and-gun duels (1v1 → 4v4) where you draft abilities (Mods) every round and every round opens a new weapon tier (Sidearm → Light → Heavy → Elite). Scheduled 16-player Gauntlet events come later. Working title; the final name is TBD. The digital/glitch theme is shelved (plain names); glitch appears only as a rare accent ([Home](../00%20Home.md) → Locked decisions).

## 1. Pillars of the look and feel
1. **Readable first.** Clear silhouettes, fixed HUD slots, one meaning per colour. You always know who, where, and what's ready.
2. **Tactical, not cute; stylised, not photoreal.** Valorant's precision and restraint with RIVALS' chunky energy. Our own design, never a copy.
3. **Faceted, carved, human-made.** Forms are built from flat angled faces: no smooth blobs, no plain boxes, no "AI-made" rounded parts.
4. **Punch on every action.** A shot, hit, kill, pick or round win lands with layered sound, a crisp visual and motion. Exaggerated, but in a controlled way.
5. **One accent at a time.** Neutral base everywhere; gold for "act now" in UI, one accent colour per room, team colours only on team things.

## 2. Models and world (skill `gauntlet-build-style`)
- **No round curves, no spheres.** Curves are made of angled plates (6-12 flat facets), domes are faceted caps, tubes are 6- or 8-sided prisms. No subdivision, no smooth bevels.
- **No harsh corners, no blunt cutoffs.** Ends are tapered, chamfered, notched or carved, while staying blocky. The chamfers are big enough to read in game.
- The owner's brief: models built from many faces of non-curved shapes, between realistic and blocky, never pixelated or cubic.
- Nothing is a plain upright box. Every joint has a transition (plinth, collar, flange, shadow gap). Build things the way they would be made.
- Textures faint (about ±4% value), matte, low specular. Neutral structure, one accent per room. No blue-teal steel (lobby).
- Maps: concept and references approved before building; Valorant detail with RIVALS clarity; a 65/25/10 shape hierarchy; a trim sheet plus a few variants ([Map Quality Standard](../01%20Design/Maps/Map%20Quality%20Standard.md)).
- New styles start with the **reference interview** ([Model Style Interview](Model%20Style%20Interview.md)): the owner's screenshots, questions with suggested answers, then a written design method and a test piece before the full build.

## 3. Guns and first person ([Art Direction](Art%20Direction.md), [Gunplay](../01%20Design/Gunplay.md))
- Guns: tactical matte charcoal with a neutral base; RemasterV2 colour roles (body, panel, brass, glass, a small neon). Self-grade 9-10. Nothing floats or is see-through. **ADS = a big, clear sight window** per gun.
- Arms: RIVALS-style sharp blocks with a hairline outline (skin only without a shirt); guns held straight ahead, pistols two-handed.
- Feel: Valorant-tight first shot plus RIVALS movement (slide is the core move). Recoil is camera-only. Feedback may roll the camera a little but never turns it. Body time-to-kill 0.5-0.75 s at 150 HP, headshot about ×1.6.

## 4. Hit feedback, VFX and death
- Hit marker: white X; headshot red X with a white core; kill bigger red/white X with a ring. Damage numbers (Sarpanch) stack and arc off (red on headshot). The body you hit flashes white then red with a slash; a headshot flashes fire orange and pops a quick muzzle-flash-style burst from the head (2026-11-13, `Config/HitFx`). Flinch, **no hit-stop**.
- Muzzle flash, tracers (core + glow + 0.28 s wake) and impacts are **stylised like Valorant**: never photoreal, never full cartoon. Surface-aware impacts: sparks on metal, dust on concrete, splinters on wood.
- Ability VFX: shapes over particles, opaque mesh-first walls, team colours (ally cyan, enemy orange-red), magenta only for glitches. Sprites stay under the Bloom threshold.
- Death: a still copy crumples, tips over and fades with dust.

## 5. Sound ([Gun Sound Packs](../03%20Research/Gun%20Sound%20Packs%20(Valorant-style).md))
- **Real recordings only, designed and layered like Valorant**, never synth, never ripped from the Creator Store. Audition before shipping.
- Per gun class: punch + mechanics + tail, spray climb. Hits: a short body thwack, a bright headshot "tink", and a kill tone that climbs per kill (with pips on the pop-up).
- UI sounds: short, soft, tonal; one confirm sound family for PLAY / LOCK IN.

## 6. UI (skill `gauntlet-ui-style`, [UI Theme Soft Edge](UI%20Theme%20v4%20Soft%20Edge.md))
- **The theme is a direction, not final UI**; the owner redesigns the screens from it.
- Plates: radius 8 with **one cut corner** and a lit top edge.
- **The HUD floats on dark fades, not boxes.**
- **Circles with rings** for anything that turns, fills or is touched.
- A **slash** and the **» chevron** as brand marks.
- Fonts: **Sarpanch** for display and numbers, **Titillium Web** for labels and body. Never Montserrat / Inter / Oswald, the generic look.
- Gold `FFC83D` is the one act-now colour; ally `2FD3E6` / enemy `FF5A4E`.
- Motion: snappy taps, smooth 0.24 s entrances, faster exits, banners with a slash wipe and a small overshoot.
- **Fixed slots:** scorebug + timer top-centre, one banner slot, kill feed top-right, health bottom-left, Mods bottom-centre (circles), ammo bottom-right. Phone: circles, a right-thumb cluster, a layout editor.
- No pills, no hard boxes everywhere, no glow halos, no glossy gradients.

## 7. Lobby and menus in the world
- Lobby: a stylised hub in third person (Sunwell Works). It has faceted architecture, real fixtures that make light pools, SurfaceGui boards in the UI theme, and equal duel pads in mode order. One accent per room.
- **Changed 2026-11-13 (owner, with friends' notes):** a **clean modern tactical facility, not steampunk, not dull**.
  - Structure: light grey walls, a slate wainscot and charcoal trim.
  - Colour: gold only as an accent. White lamp light.
  - Avoid: brass and ochre pipes, valve hand wheels, wood tops, and brown or sepia palettes.

## 8. Before calling anything done
1. Load the skill for the job and check this page's pillars.
2. Close-up and in-context captures (or Figma screenshots), and a self-review against the "never" lists.
3. Write the result, captures and open questions into the vault note for that area, and update [Home](../00%20Home.md) Status.

## Change log
- 2026-11-12: created. Folds in the owner's modelling rules (no curves or spheres, no blunt cutoffs, reference interview) and the UI theme v4.1 direction. The locked Art decision's "rounded bevels, smooth materials" was replaced by the faceted rule.
