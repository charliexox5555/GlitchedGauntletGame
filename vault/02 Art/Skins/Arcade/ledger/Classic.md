### Classic (Classic)

2026-11-27. Arcade line, Blender only (nothing installed, uploaded or committed). Final: **v03, self-grade 9/10.** Review sheet: [Classic_v03_review.png](../out/Classic_v03_review.png).

**Script:** `tools/blender/arcade/20_classic.py` (stations: `21_review_classic.py`, sheet list: `sheet_classic.json`). Built on `art-source/weapons/RemasterV2/Classic/Classic_RemasterV2_v05.blend` in a dedicated live Blender (port 9881).

**No ADS:** the Classic uses alt fire, so the audit ran with `ADS_DISTANCE=None` and checks the physical iron line (eye -0.565, 0, 0.509). The stock file has no `AimPoint` and no `Cam_Hip`, so `21_review_classic.py` runs a copy of `20_review.py` with `AT` = the front post's top (0.935, 0, 0.509) and `ADS_DISTANCE` 1.2, which puts the "ads" camera on the iron eye. `HIP` (-1.097, 0.580, 0.818, 80 deg) is SIDEARM_VM + HIP_SHIFT from the RightGrip (sidearms are placed by the grip), over 0.8 × viewmodelScale 1.1.

**Charm (moved point):** the owner moved the Classic's CharmPoint in Studio to Blender (0.74, 0.084, 0.205), on the left dust-cover groove. The stock `CharmLoop` is **unskinned**: not dressed, not hidden, stock materials. The flat manifest lists it under `untouched_stock`, so the Studio install keeps the owner's moved ring. Every Arcade part stays 0.09+ clear of the new point: the nearest is the slide field (0.125 away). The left dust-cover groove carries the charm, so the lit trim is on the right only.

#### Versions
| Version | What changed | Result |
|---|---|---|
| v01 | First build: deck on the frame's left band, coin door on the right grip panel, recessed fields on both slide sides, right dust-cover trim, muzzle collar and ring, magazine stripes. | 3740 tris (1.60×). The exact boolean on the whole stock slide unioned its separate sight islands into the body, so the iron ray hit nothing and the rear-sight neon floated. The baseplate (with the new stripes) floated: the magazine body stopped 0.002 above it. The collar's back face lay on the slide's counterbore floor (coplanar). |
| v02 | The slide was split for the boolean, the magazine body was buried in the baseplate, the coin slots became proud lights, and the collar moved back to x .979. | Floating and faults were clean. But the body copy was named `AR_SlideBody`, so the audit counted the stock slide-on-frame and barrel-in-slide overlaps as Arcade intersections. The collar bore matched the slide's bore radius (coplanar). Still 3748 tris. |
| v03 | `Classic_Slide` keeps the body (with the cut field); the unchanged stock sights moved to `AR_SlideSights` on the Slide bone. Collar bore r .035, ring inner .0375. Right slide field dropped for the budget. Washer, shaft, button collars and trim are six-sided; the joystick ball has three sections; coin entries have no front chamfer. | All gates pass, 3476 tris. |

#### Final build (v03)
- **Deck (fixed frame, Root):** a violet plate on the frame band's left face (back y .064 buried, face .084), between the grip top and the slide bottom (z .182–.266). It stops 0.025 ahead of the stock CharmLoop and 0.026 behind the slide catch. It carries a joystick at the rear, then **three buttons** (cyan, yellow, magenta, rising toward the muzzle), a pixel screen in a bezel (cyan ship, magenta shot, yellow stars, cyan blip) and a cyan light pipe on the top edge. The pipe's top is 0.016 under the slide.
- **Coin door (right):** a metal plate seated in the right grip panel. Its back (-.056) clears the magazine body, which leaves the grip in the reloads. Two lilac entries with yellow lit slots and a magenta stripe.
- **Slide field (left, rides the slide):** recessed 0.006 into the main slide behind the nose groove (x .30–.69): pixel-stepped corners, raked magenta band, cyan line, yellow eight-point starburst, magenta pixel trail. The cutter rides the Slide bone. **No right slide field** (budget).
- **Lit trim:** a magenta bar seated in the right dust-cover groove (x .655–.935).
- **Muzzle:** a stepped eight-sided collar on the slide nose, buried 0.021, with the cyan `ARBrakeLight` ring in its groove. The bore (r .035) clears the barrel crown (r .026). It rides the slide; the frame top is below its bottom (.320) through every clip.
- **Magazine:** magenta stripes on both baseplate sides (Mag bone).
- **flat_groups:** ARButton1–3, ARStickBall, ARScreen, ARScreenShip, ARScreenShot, ARScreenStars, ARScreenBlip, ARDeckLight, ARTrim, ARBrakeLight.

#### Gap sweep
I took culled magenta close-ups from both sides and below of: trigger guard to grip, grip to frame, baseplate to grip, slide to frame, the nose and every new part (`out/Classic_v03_views/culled_*`). No see-through gap was found at any stock or new join.
- **Fixed:** the magazine body stopped 0.002 above its baseplate, so the baseplate floated. The body's bottom now runs 0.022 down into the baseplate (hidden).
- **Left as is:** the 0.002 seam between the grip bottom and the baseplate is the magazine's parting line (it must separate in the reloads). The magazine body sits behind it, so nothing shows through.

#### Audit (v03, `out/Classic_v03_views/audit.json`)
- **Triangles:** 3476 against 2334 stock (1.49×; limit 3501).
- **Faults:** 10, all stock open islands (Barrel, Frame, Grip, Pins, CharmLoop), the same list as stock. 0 in new geometry.
- **Coplanar:** 0. **Floating:** 0. **Animated intersections:** 0.
- **Contract:** locators, bones and actions all equal.
- **Iron line:** the only hit is the stock front post, now in `AR_SlideSights` (stock: `Classic_Slide`), with unchanged geometry. Nothing new is in the line.
- **Flat export** (`art-source/weapons/Skins/Arcade/Classic/v03x/`): `Classic_Arcade_RobloxFlat.fbx` and `manifest_flat.json`. 0 flips, 0 lifts, 0 crossed faces. The one-sided re-import is clean (38 parts, none inside out). `untouched_stock: ["CharmLoop"]`. Evidence: `out/Classic_v03x_flat_check/`.

#### Grade (lowest area = 9)
| Area | Grade | Note |
|---|---|---|
| Silhouette | 9 | Stock pistol with the muzzle collar; reads as the Arcade line |
| Crispness | 9 | Flat facets, one-step chamfers |
| Layering | 9 | Deck, bezel, screen, collars and field seated with their own lifts |
| Connections | 9 | All joins buried; gap sweep clean |
| ADS / iron | 10 | Iron line unchanged |
| Palette | 9 | Line roles; right side lighter on art |
| Budget | 9 | 1.49× |
| Contract | 10 | Equal; CharmLoop untouched |

#### For the owner
- The right slide has no side-art field: the 1.5× budget on this small gun went to the deck. The right side has the coin door, the lit trim and the magazine stripe.
- The lit trim is right-only, because the moved charm hangs from the left dust-cover groove.
- The stock sights now live in `AR_SlideSights` (same geometry, Slide bone, still named *Sight*), because the field boolean would have merged them into the slide body.
