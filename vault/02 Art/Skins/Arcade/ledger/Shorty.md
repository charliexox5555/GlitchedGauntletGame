# Arcade Shorty (Shorty)

2026-11-27. Built in Blender only, from `art-source/weapons/RemasterV2/Shorty/Shorty_RemasterV2_v05.blend`. Nothing was installed, uploaded or committed.

**Final: v03, self-grade 9/10.** Review sheet: [Shorty_v03_review.png](../out/Shorty_v03_review.png)

## Files
- Build script: `tools/blender/arcade/23_shorty.py`. Its docstring holds the stock measurements.
- Review stations: `tools/blender/arcade/21_review_shorty.py`.
- Sheet list: `tools/blender/arcade/sheet_shorty.json`.
- Masters:
  - `art-source/weapons/Skins/Arcade/Shorty/v01/Shorty_Arcade_v01.blend` (superseded)
  - `art-source/weapons/Skins/Arcade/Shorty/v02/Shorty_Arcade_v02.blend` (superseded)
  - `art-source/weapons/Skins/Arcade/Shorty/v03/Shorty_Arcade_v03.blend`
- Export:
  - `art-source/weapons/Skins/Arcade/Shorty/v03x/` (`Shorty_Arcade_v03x.blend`, `Shorty_Arcade_RobloxFlat.fbx`, `manifest_flat.json`)
  - flat check in `out/Shorty_v03x_flat_check/`
- Evidence: `out/Shorty_v03_views/` (audit.json, `wb_*`, `culled_*`, `finish_*`, `pose_*`, `stock_*`).

## Stock facts that shaped it
- **Moving parts:** the `Barrels` bone (hinge x .546, z .114) breaks about 36° muzzle-down against the frame in Reload and ReloadEmpty, and 27° in Inspect. `BreechLatch` is its own bone on the left frame. Both shells load *through* the frame interior out to |y| .082 (Reload frames 30-37, ReloadEmpty 44-47).
- **Player-facing side:** +y. `Shorty_Cam_Hip` is at (-1.18, 0.38, 0.69).
- **Barrels:** side by side at y ±.05, z .26. Muzzle and MuzzleLower are at x 1.4482.
- **No ADS:** Config/Weapons Shorty has `noAds = true` and no `adsDistance`, and the file has no `AimPoint`.
  - The audit ran with `ADS_DISTANCE = None`.
  - The review used an unsaved AimPoint stand-in over the rear notch (0.03, 0, 0.356) with 0.36.
  - The build casts its own notch-to-bead rays: 0 Arcade hits.
- **No magazine,** so there is **no mag stripe**.

## Moved charm point (owner, 2026-11-27)
- The owner moved the charm point in Studio to Blender (0.74, 0.116, 0.215), on the left side at the barrel block / forend seam. The v05 `CharmPoint` locator and Charm bone are unchanged (contract equal).
- `Shorty_CharmLoop` is **not dressed**: stock materials, visible, not hidden. The manifest lists it under `untouched_stock`, so the Studio install keeps the owner's moved ring.
- No Arcade part sits near it. The left forend art and trim start at x .87, and the nearest Arcade surface to the point (and to 0.09 below it) is 0.141 away (`AR_ForendPixel_Left_3`).

## What it is
- **Cabinet deck** (Root) on the frame's left face over the latch recess: raked rear, joystick (washer, thin shaft, faceted ball), **three buttons** in collars rising toward the muzzle (cyan, yellow, magenta), a pixel screen in a bezel, and a cyan light pipe on the top edge. The stock left Neon strip, which the deck covers, was dropped.
- **Coin door** (Root) in the frame's right recess: two lilac coin entries with lit yellow slots and a magenta stripe. The stock right Neon strip stays above it.
- **Forend art** (Barrels) on both stock forend fields, which are now violet: a raked magenta band, a cyan line, a yellow starburst and a magenta pixel trail, plus a magenta **T-molding trim** seated in each forend lower edge.
- **Binocular muzzle block** (Barrels): one stepped, eight-sided block round both barrel ends with two eight-sided bores. It carries the cyan **light ring** (`ARBrakeLight`) in a groove and replaces the two thin muzzle tips.
- The body is cabinet purple (frame, breech, barrel block and forend), the band is violet, and the tubes are metal.

## Versions
- **v01:** the first build.
  - The audit found 3 animated intersections: the stock shells' loading path crossed the backs of the deck, light pipe and coin door inside the frame.
  - It also found 1 stock coplanar pair: the rib's and web's front faces lay in the tube-front plane at x 1.36.
- **v02:**
  - The backs of the deck, light pipe and coin door moved to |y| .0835. They are still seated (the deck is 0.0065 into the frame face), and the shells clear them by 0.0015.
  - The rib and web front ends moved 0.010 forward. They are buried 0.032 in the muzzle block, clear of the bores.
  - The joystick got a slimmer, visible shaft and a smaller ball, so it reads as a stick rather than a fourth button.
  - The audit then found the light pipe's back sharing the deck's back plane (1 coplanar pair).
- **v03:** the light pipe's back moved to .085. All gates pass.

## Gap sweep
- Every new and stock join was checked in culled close-ups from both sides and from below: deck, joystick, screen, coin door, forend art and trim, muzzle block, trigger guard, grip and grip cap, breech, latch, forend underside, band, both sights and the CharmLoop. **No gaps were found.**
- Two stock joins are seated by less than 0.02, but neither shows a gap, so they were left alone: the trigger-guard posts are 0.008 into the frame, and the grip cap overlaps the grip by 0.006.
- Note: the perspective culled coin close-up shows thin diagonal dark lines across the right frame face. They don't appear in the two-sided or finish renders, or in the flat re-import, and the Frame mesh was only re-materialised, so it looks like a Workbench culling artefact of the stock Frame tessellation.

## Results (v03)
- **Triangles:** 3802 against stock 2734 (1.39×).
- **Audit:** 0 new faults (all 10 listed are unchanged stock open islands), 0 coplanar, 0 floating, 0 animated intersections, contract equal (locators, bones, actions).
- **Sight line:** 0 Arcade hits. In the stand-in ADS view, only the joystick ball's tip shows at the frame's left edge, the same way the stock CharmLoop shows.
- **Flat export:**
  - 0 flipped islands, 0 coplanar lifts, 0 crossed faces, `untouched_stock: ["CharmLoop"]`.
  - The one-sided re-import shows no magenta holes.
  - `inside_out` lists SK_Barrels_03 (the bore walls, an open inward tube, so its signed volume is negative by construction) and the stock shell brass rims (as on the Bucky and Marshal).

| Area | Grade | Notes |
|---|---|---|
| Silhouette | 9 | Still the Shorty; the muzzle block and deck read as the Arcade line |
| Crispness | 9 | Flat-shaded, 1-segment chamfers, faceted prisms |
| Layering | 9 | Deck, screen, buttons and art each have their own lift |
| Connections | 9 | No gaps; deck seating is limited to 0.0065 by the shell-loading path |
| ADS | 9 | noAds; the sight line is clear |
| Palette | 9 | The line's roles, small accents |
| Budget | 10 | 1.39× |
| Contract | 10 | All equal; CharmLoop untouched |

## For the owner
- **Three buttons fit.** The deck, screen and buttons are all on Root (the fixed frame); nothing Arcade-fixed rides the Barrels bone except the forend art, trim and muzzle block.
- **Deck seating:** the deck sits 0.0065 into the frame, not 0.02. The stock shells load through the frame out to |y| .082, so a deeper back would intersect them.
- **The left forend art is front-weighted** (x .87+) to leave the moved charm room. The right side matches for symmetry.
