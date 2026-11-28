# Arcade Bucky (Pump)

2026-11-27. Built in Blender only, from `art-source/weapons/RemasterV2/Bucky/Bucky_RemasterV2_v05.blend`. Nothing was installed, uploaded or committed.

**Final: v02, self-grade 9/10.** Review sheet: [Bucky_v02_review.png](../out/Bucky_v02_review.png)

## Files
- Build script: `tools/blender/arcade/18_bucky.py`. Its docstring holds the stock measurements.
- Review stations: `tools/blender/arcade/21_review_bucky.py`.
- Sheet list: `tools/blender/arcade/sheet_bucky.json`.
- Masters:
  - `art-source/weapons/Skins/Arcade/Bucky/v01/Bucky_Arcade_v01.blend` (superseded)
  - `art-source/weapons/Skins/Arcade/Bucky/v02/Bucky_Arcade_v02.blend`
- Export:
  - `art-source/weapons/Skins/Arcade/Bucky/v02x/` (`Bucky_Arcade_v02x.blend`, `Bucky_Arcade_RobloxFlat.fbx`, `manifest_flat.json`)
  - flat check in `out/Bucky_v02x_flat_check/`
- Evidence: `out/Bucky_v02_views/` (audit.json, `wb_*`, `culled_*`, `finish_*`, `pose_*`, `stock_*`).

## Stock facts that shaped it
- **Moving parts:**
  - The Pump and Bolt travel -0.26 in x (Draw, Fire, ReloadEmpty) and -0.104 (Inspect).
  - At full stroke the forend's rear comes to x .979, 0.010 ahead of the receiver (.969).
  - The bolt runs back to x .187 on the right, at z .262-.348.
- **Player-facing side:** +y. `Bucky_FP_Hip` sits at (-0.85, 0.6, 0.5).
- **Missing stock pieces:** the stock file has no `AimPoint`, `Cam_Hip` or `Cam_ADS`.
- **No ADS:** Config/Weapons Bucky has `noAds = true` and no `adsDistance`.
  - The audit ran with `ADS_DISTANCE = None`.
  - The review used an unsaved AimPoint stand-in over the rear notch (0.25, 0, 0.474) with 0.36. That gives a notch-to-bead picture.
  - The build also casts its own notch-to-bead rays.
- **No magazine:** the gun is tube fed, so there is **no mag stripe**.

## Versions
**v01: the full build.**
- **Deck:** in the receiver's left recess panel (floor .073, on Root).
  - Joystick at the rear, then three faceted buttons in collars (cyan, yellow, magenta), then a pixel screen in a bezel.
  - A cyan light pipe runs along the deck's top edge.
- **Coin door:** on the lower right receiver band, under the ejection port and clear of the bolt's stroke.
- **Forend:** a new faceted sleeve on the `Pump` bone.
  - Eight-sided bore around the tube; it clears the tube and stays 0.004 under the barrel.
  - Four grip grooves, plus a side-art field on both sides (band, line, starburst, pixel trail).
  - Magenta trim seated in the lower chamfer.
- **Stock:** stock-frame art on the top bar, and a cabinet butt with marquee lights, fields, stripe and line.
- **Muzzle:** a stepped eight-sided muzzle collar with the cyan light ring. The Muzzle locator (2.832) sits in the bore mouth (2.834).

Audit problems in v01:
- **Tris over budget:** 4716 tris, over the 1.5× budget of 4545.
- **False animated hits:** copying the action bars and barrel to `AR_` names put their stock slide into the receiver and onto the tube into the animated check.
- **Wrist nudge:** the wrist's rear nudge never ran.

**v02: fixes.**
- **Bars and barrel:** kept on the stock objects. The stock bar-into-receiver slide and the stock shell-into-tube contact (Reload f23-24, ReloadInsert f12-13, checked in the untouched stock file) are stock pairs again.
- **Tube rear:** no longer moved, so it can't change the shell contact.
- **Tris:** removed the bevel modifier from the forend (the chamfers are in its sections), cut five grooves to four, and dropped the butt stars.
- **Wrist:** fixed the wrist-rear nudge.

## Gap sweep (stock joins buried under 0.02, now 0.02+)
- **Barrel rear:** 0.019 into the receiver front. It moves to x .938.
- **Tube front:** 0.010 into its cap. It moves to 2.750.
- **Rear sight and front bead:** their base corners sat proud of the chamfered and round tops (0.002 / 0.005). Both feet move down 0.018.
- **Wrist tube:** 0.006 into the receiver's rear and 0.019 over the stock body. The front moves +0.016 and the rear -0.008.
- **Action bars:** 0.006 into the forend's rear. They move +0.020.
- **Barrel end:** moved 2.832 → 2.790 so it is buried in the new collar.
- **Culled close-ups** from left, right and below found no other gaps. They cover the receiver front, charm, trigger guard, receiver underside, grip, wrist, band, both sights, forend rear, front and underside, butt and its join, collar and muzzle.

## Audit (v02)
| Check | Result |
|---|---|
| Tris | **4316** against stock **3030** (1.42×; budget 4545) |
| Faults in new geometry | **0**. The 13 listed are the stock open islands with the same open-edge counts as stock: Neon ×5, Pins ×2, trigger guard, grip, both sights, tube, wrist. The removed muzzle ring was one more. |
| Coplanar pairs | 0 |
| Floating parts | 0 |
| Animated intersections | 0 over all eight clips, the pump stroke included |
| Contract | locators, bones and actions all equal |
| Sight line | notch-to-bead rays hit no new part; the review's ADS render is clear |
| Flat export | 0 flipped islands, 0 lifts, 0 crossed faces. The one-sided magenta re-import is clean from both sides. |
| Inside-out flags | The check flags `SK_Root_03` and `SK_Shell_02`. Both are stock geometry: the stock Neon strips are open boxes (signed volume -0.00068 in the untouched stock file) and the stock brass is half of the shell's one island (-0.0025; the whole shell is positive). The new cyan parts merged into `SK_Root_03` are closed and positive. |

## Grade (v02)
| Area | Grade | Note |
|---|---|---|
| Silhouette | 9 | Stock pump-gun outline. The faceted forend, cabinet butt and stepped collar are the shape changes. |
| Crispness | 9 | Flat facets and 1-segment chamfers. |
| Layering | 9 | The deck is seated in the stock recess. Bezel, screen and pixels each have their own lift. |
| Connections | 9 | Gap sweep clean. Every plate is buried. |
| ADS | 9 | noAds gun. The notch and bead picture is untouched. |
| Palette | 9 | Arcade roles; small yellow accents. |
| Budget | 9 | 1.42× stock. |
| Contract | 10 | Everything equal. CharmLoop kept; nothing near the charm. |

## Owner decisions
- **No mag stripe:** the gun is tube fed, so it has no magazine and no mag stripe.
- **No in-game ADS:** `noAds = true`, so the ADS check is a notch-to-bead check only.
- **Forend replaced:** the grooved stock forend is replaced by a new faceted forend on the `Pump` bone. All forend art rides that bone and stays clear through the full stroke.
