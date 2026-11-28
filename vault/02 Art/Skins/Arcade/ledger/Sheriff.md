# Arcade Sheriff (Sheriff)

2026-11-27. Built in Blender only, from `art-source/weapons/RemasterV2/Sheriff/Sheriff_RemasterV2_v05.blend`. Nothing was installed, uploaded or committed.

**Final: v03, self-grade 9/10.** Review sheet: [Sheriff_v03_review.png](../out/Sheriff_v03_review.png)

## Files
- Build script: `tools/blender/arcade/22_sheriff.py`. Its docstring holds the stock measurements.
- Review stations: `tools/blender/arcade/21_review_sheriff.py`.
- Sheet list: `tools/blender/arcade/sheet_sheriff.json`.
- Masters:
  - `art-source/weapons/Skins/Arcade/Sheriff/v01/Sheriff_Arcade_v01.blend` (superseded)
  - `art-source/weapons/Skins/Arcade/Sheriff/v02/Sheriff_Arcade_v02.blend` (superseded)
  - `art-source/weapons/Skins/Arcade/Sheriff/v03/Sheriff_Arcade_v03.blend`
- Export:
  - `art-source/weapons/Skins/Arcade/Sheriff/v03x/` (`Sheriff_Arcade_v03x.blend`, `Sheriff_Arcade_RobloxFlat.fbx`, `manifest_flat.json`)
  - flat check in `out/Sheriff_v03x_flat_check/`
- Evidence: `out/Sheriff_v03_views/` (audit.json, `wb_*`, `culled_*`, `finish_*`, `pose_*`, `stock_*`).

## Stock facts that shaped it
- **Moving parts:** Crane, Cylinder, EjectorRod, Rounds, Speedloader, Hammer, Trigger, CylinderRelease (Root and Charm also animate).
  - The crane swings the cylinder out to +y on Inspect and both reloads.
  - Swept over every frame of every clip: on the reloads the rounds and the speedloader pass within y .04-.07 of the **whole +y frame behind the cylinder** (x -.1 to .30), and of the right frame above z .21. Nothing new can sit there without an animated intersection.
  - Never reached: the barrel and underlug (x > .78, both sides) and the right frame under the hammer (x .06-.30, z < .20).
- **Player-facing side:** +y. No `Cam_Hip`, `Cam_Side` or `Cam_ADS` in the file (only `Sheriff_FP_*` cameras); the review's first-person view is a stand-in at (-0.55, 0.30, 0.50), 70 degrees.
- **ADS:** Config/Weapons Sheriff `adsDistance = 0.42`; AimPoint (.26, 0, .418). In the sight picture the top strap and cylinder hide everything below about z .36 on the barrel; the front ring's top sets a line of about z .36 at the muzzle.
- **No magazine** (speedloader), so **no mag stripe**; no stock, so no cabinet stock end.
- Charm point (.68, .0658, -.0277) on the lower left front; not a moved-charm gun, so the CharmLoop is refinished like the rest. Every Arcade part is 0.15+ away from it.

## Versions
**v01: the full build.**
- **Deck (Root, on the barrel):** one raised violet plate over the left side of the barrel (.068) and its underlug (.046), back buried at y .040, face .080, x .836-1.248, z .124-.300.
  - Joystick at the rear, then three faceted buttons in collars rising toward the muzzle (cyan, yellow, magenta), all low (z .15-.18) so the cylinder hides them in ADS.
  - Pixel screen in a bezel above them (ship, two shots, stars, blip), cyan light pipe on the deck's top edge.
  - Scaled to about 0.65 of the Bucky's.
- **Coin door:** right frame under the hammer, behind the cylinder window (x .150-.296, z .082-.200): two lilac coin entries with lit yellow slots and a magenta stripe.
- **Barrel right:** recessed violet side-art field (band, cyan line, starburst, pixel trail) and a magenta T-molding seated in the barrel's lower chamfer, both ends buried (in the front ring and the collar).
- **Muzzle collar:** a stepped eight-sided sleeve that follows the barrel's chamfered box over its last 0.07, with a cyan light ring in a groove; it swallows the front sight's front foot (no slit), top kept at .355 for the sight picture; the bore leaves a 0.008 mouth where the Muzzle locator sits.
- **Recolour only:** cylinder, crane, ejector, hammer, trigger, release, rounds, speedloader keep their stock geometry. Frame and barrel take the cabinet purple.
- **Gap sweep (stock joins under 0.02, now 0.02+):** trigger-guard posts up 0.020 into the frame bottom (were 0.006-0.008: the Bulldog-style trigger-front gap); rear and front sight feet down 0.020 / 0.016 (were 0.001 / 0.004); underlug top up 0.012 into the barrel (was 0.009); frame front end 0.013 forward into the front ring (was 0.012).
- Audit: 0 new faults, 0 coplanar, 0 floating, 0 animated pairs, contract equal. The lug's rear nudge missed (its filter used the pre-nudge height).
- Review: the solid light ring capped the barrel's bore, showing a cyan disc in the muzzle.

**v02:** light ring rebuilt as a band with a bore; lug rear nudge fixed (lower rear edge 0.020 back into the frame, was 0.003). Audit: 1 coplanar pair (ring bore matched the collar bore).

**v03:** ring bore 0.003 inside the collar's. All gates pass.

## Results (v03)
- Triangles: **4432** against stock **3066** (1.45x, under the 1.5x budget).
- Audit: 18 faults, all stock open islands with the same names and open-edge counts as stock (0 new); 0 coplanar; 0 floating; 0 animated intersections over Draw, Fire, Inspect, Reload and ReloadEmpty; contract equal (locators, bones, actions).
- ADS: eye-segment rays clear (same as stock); the build's own check found 0 new vertices visible from the ADS eye or the audit's four offsets; the ADS render shows nothing new.
- Flat export: 31 parts, 0 inside-out, 0 flipped islands, 0 coplanar lifts, 0 crossed faces; clean one-sided magenta re-import.
- Gap sweep: culled close-ups of the deck (all sides and below), coin door, barrel art, trim, collar, trigger guard (both sides, below), grip (both sides, below), hammer, both sights, front ring (both sides), underlug (below, rear), cylinder window (both sides), release and charm loop. No gaps left.

## Grade
| Area | Grade | Note |
|---|---|---|
| Silhouette | 9 | stock revolver outline; deck panel, collar and coin door read as the Arcade line |
| Crispness | 9 | flat-shaded, faceted prisms, 1-segment chamfers |
| Layering | 9 | deck, bezel, screen, pixels and buttons each on their own lift |
| Connections | 9 | everything buried; stock joins brought to 0.02+ |
| ADS | 10 | nothing new in the sight picture |
| Palette | 9 | purple body, violet fields, small neon accents |
| Budget | 9 | 1.45x stock |
| Contract | 10 | all bones, locators, actions and the charm mount kept |

## For the owner
- **Deck on the barrel, not the frame.** The reload sweep (rounds and speedloader) passes through the whole frame area behind the cylinder on the player's side, so the deck sits on the barrel and underlug's left side instead. It is still on Root (fixed) and clear of every moving part.
- **Three buttons** fit (scaled to about 0.65).
- The first-person stand-in camera is a guess (no `Cam_Hip` in the file); check the deck's read in the real viewmodel when it is installed.
