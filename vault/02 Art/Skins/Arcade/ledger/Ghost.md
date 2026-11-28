### Ghost (Hush)

2026-11-27. Built in Blender only: no Studio work, no uploads, not installed. Script: `tools/blender/arcade/24_ghost.py`. Review: `21_review_ghost.py`. Sheet list: `sheet_ghost.json`.

**Final: v03, self-grade 9/10.**
- Master: `art-source/weapons/Skins/Arcade/Ghost/v03/Ghost_Arcade_v03.blend`
- Export: `art-source/weapons/Skins/Arcade/Ghost/v03x/Ghost_Arcade_RobloxFlat.fbx` (+ `manifest_flat.json`)
- Review sheet: [Ghost_v03_review.png](../out/Ghost_v03_review.png)
- Triangles: 3830 against 2964 stock (1.29×)

**Stock measurements.** The stock file has no Cam_Side, Cam_Hip or Cam_ADS. The hip camera is the Classic's derived one: same SIDEARM_VM and scale, RightGrip at the origin. The Ghost has `noAds`, so ADS_DISTANCE=None. I checked the iron line myself with rays from (-0.458, 0, 0.424), behind the rear sight, to the front post top (z .424). The script's docstring has the full measurements. The Suppressor sits on **Root**, and its object also holds the barrel and the chamber block.

**Versions**
- **v01:**
  - deck (the Classic deck scaled 0.88 onto the left frame band, z .141-.215, x -.091/.272) with a joystick, **three buttons** (they fit), the pixel screen and the light pipe;
  - coin door sheared to the rake of the right grip recess;
  - left slide side-art field (recessed 0.006) with the band, line, star, pixel trail and a cyan pixel ghost;
  - magenta trim in the right dust-cover groove;
  - stepped eight-sided can (apothem = the stock radius, so the silhouette is the same) on Root with a cyan ring buried into its groove walls;
  - raked magenta baseplate stripe on both sides, buried into the band and the groove (no slot shows under it);
  - stock CharmLoop dressed.

  Audit: 1 coplanar pair. It was already in stock: the SlideNeon strips sat flush with the front serration faces.
- **v02:**
  - SlideNeon serration faces lifted 0.004 (coplanar 0);
  - the ghost glyph redrawn as a wisp with a trailing tail, so it reads less like a Pac-Man ghost;
  - band and line stripes added on both flat faces of the can near the front step.
- **v03 (orchestrator review of v02):** the pixel ghost read too close to a well-known arcade character, and the line must be original. It is replaced, in the same spot, by the line's own motif: a yellow 5×5 pixel plus-star (x .185-.235) with a short magenta pixel trail behind it (three squares, .009/.007/.005). The 0.003 parting seam between the slide nose and the can is accepted. Nothing else changed.

**Gap sweep (culled close-ups, both sides and below):** can join, trigger guard front and rear, under the guard, grip to frame, baseplate join, slide to frame, under the dust cover. No gaps found.
- **Fix:** the stock barrel ended at x 1.13, and the stock collar used to cover it. Its front end was nudged 0.035 forward so it buries in the new can.
- **Kept on purpose:** a 0.003 parting line between the slide nose (1.126) and the can's rear face (1.129). It keeps the moving slide off the can. The stock collar overlapped the slide here, which would fail the animated-intersection gate.

**Audit v03 (same as v02):**
- faults 9, all stock open islands: Frame:1, Frame:2, Grip:0, Mag:0, Pins:0-3 and the stock barrel tube (12 open edges, the same as stock `Suppressor:5`; it was only lengthened, and both rims are hidden). No new faults;
- 0 floating, 0 coplanar, 0 animated intersections;
- contract equal (locators, bones, actions);
- iron rays the same as stock (only the sights; the sights moved to `AR_SlideSights`).

**Flat export (v03x):** 36 parts. 0 coplanar lifts, 0 flips, 0 crossed faces, 0 inside-out, and a clean one-sided re-import.

**Charm:** the Ghost's charm point was not moved. The stock CharmLoop (left dust-cover groove) is dressed in the line's colours, and the right-only trim and the deck stay 0.09+ clear of (0.86, 0.064, 0.16).

| Area | Grade | Note |
|---|---|---|
| Silhouette | 9 | stock outline; can recut as a stepped octagon |
| Crispness | 9 | flat facets, 1-segment chamfers |
| Layering | 9 | deck, screen, buttons and field decor seated with 0.004+ lifts |
| Connections | 9 | barrel buried in the can; 0.003 slide/can parting line by design |
| ADS / iron line | 9 | sight picture as stock |
| Palette | 9 | purple slide and can, violet fields, small neon |
| Budget | 10 | 1.29× |
| Contract | 10 | all equal; stock charm loop kept |

**Owner to decide:** nothing open. The pixel ghost was replaced in v03 and the parting seam was accepted.
