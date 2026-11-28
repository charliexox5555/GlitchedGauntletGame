### Stinger (Hornet)

2026-11-27. Arcade Rare on the stock `art-source/weapons/RemasterV2/Stinger/Stinger_RemasterV2_v05.blend` (Uzi-type SMG, mag in the grip). Blender only: nothing installed, uploaded or committed.

**Final: v04, self-grade 9/10.** Review sheet: [Stinger_v04_review.png](../out/Stinger_v04_review.png)

**Files**
- Build script: `tools/blender/arcade/19_stinger.py` (`exec(..., {"VERSION": "vNN"})` with the stock open)
- Review stations: `tools/blender/arcade/21_review_stinger.py` (ADS_DISTANCE 0.30); sheet list `tools/blender/arcade/sheet_stinger.json`
- Master: `art-source/weapons/Skins/Arcade/Stinger/v04/Stinger_Arcade_v04.blend`
- Export: `art-source/weapons/Skins/Arcade/Stinger/v04x/Stinger_Arcade_RobloxFlat.fbx` + `manifest_flat.json` (copy `Stinger_Arcade_v04x.blend`)
- Evidence: `out/Stinger_v04_views/` (audit.json, wb/culled/finish/pose/stock captures), `out/Stinger_v04x_flat_check/`

**Versions**
| Version | What changed | Result |
|---|---|---|
| v01 | First build | The stock keep filter (x > -1.39) dropped the stock bars (they start at -1.41/-1.40); the coin door's top-rear corner showed from the ADS eye. Discarded. |
| v02 | Keep filter -1.45; coin door top .340 with a raked rear corner | The exact boolean for the adapter-block fields deleted the bars that share its mesh, so the butt floated (9 floaters). Discarded. |
| v03 | Block and bars split into `AR_StockBlock` / `AR_StockBars`; block front-top edge drops 0.006 so its chamfer stays inside the new receiver sleeve | All gates pass except the budget: 4716 tris (1.505x). |
| v04 | Fore-end and butt chamfers limited to the square edges (angle 60) | **4660 tris, every gate passes.** |

**Layout (why the deck is at the front).** The ADS eye (adsDistance .30, eye x -.783, z .478) sees over the rear of the left receiver: above the stock block (top .384) nothing covers it. The top rail (y .052, top .429) and the rear-sight wings shadow the whole front of the left face, so the control deck sits ahead of the charging handle's furthest reach (x .283), above the fore-end box: joystick at the rear (ball top .318, low), three buttons rising toward the muzzle (cyan, yellow, magenta), the pixel screen in a bezel and the cyan light pipe on top. The fire selector (sweeps to z .263 at x ±.1) and the charging-handle knob (never below z .308) stay clear. An ADS frustum ray check on every new vertex gives 0 exposed. The trade-off is that in the held view the deck sits toward the far end, and the nearest thing is the stock-block art field.
- Coin door: rear right receiver, behind the bolt's furthest travel (x -.234).
- Fore-end box rebuilt in the stock envelope (x .465-.825, z .105-.264) with a raked cabinet front, side-art fields on both sides and a magenta T-molding (`ARTrim`) on each lower edge. The two stock fore-end pins went with the old box.
- Stock adapter block: side-art fields both sides, replacing the round stock buttons.
- Cabinet butt replaces the pad, with a raked marquee top, a cyan marquee, a stepped rear and side art. The bars run 0.025+ into it.
- Stepped eight-sided brake replaces the barrel. Its collar is 0.03 into the front cap, a cyan ring (`ARBrakeLight`) sits in a groove, and the Muzzle locator (x 1.14) sits at the bore mouth.
- Mag stripe on bone `Mag`, below the grip.
- All deck, screen and button parts are on `Root`.

**Gap sweep: stock joins closed (each now 0.02+ deep).**
- Grip top: 0.002 into the receiver. Now +0.02.
- Trigger guard top: 0.013-0.018. Now +0.01.
- Receiver rear: met the adapter block face to face at x -.51. The receiver now sleeves 0.02 back over the block, and the block's front-top edge drops 0.006.
- Front cap: 0.006 into the receiver. Its rear now runs 0.02 back inside.
- Top rail foot: 0.004. Now -0.02.
- Rear sight foot: 0.006. Now -0.015.
- Front sight base: flush on the cap. Now -0.02.
- Front sight post: foot -0.02, top +0.008. The Neon tip's foot is -0.008 and its top is kept.
- Stock bars: 0.006 into the block. Now +0.02.
- Mag body: 0.002 into the floor plate. Now -0.02.
- Barrel collar: was flush on the cap; replaced by the brake.

Culled magenta close-ups of every join from the left, the right and below (`culled_*_join*`, `*_below`, `receiver_rear*`, `bars_*`, `mag_*`, `cap_join`, plus front-step checks) show no gaps.

The pin heads (0.003 seat, 0.007 thick) and the eject-port rim are kept as stock. One thing found but not changed: the stock receiver's front end is open (its 20 open edges, unchanged). It is closed off by the front cap and fore-end, with no see-through in the culled views or the one-sided re-import.

**Audit (v04, `out/Stinger_v04_views/audit.json`)**
- Tris: 4660 against stock 3134 (1.487x, cap 4701).
- Faults: 0 in new geometry. The 14 listed are stock open islands (Neon, Receiver, Sights, Grip, Pins), with the same open-edge counts as stock.
- Coplanar: 0 (the stock has 1).
- Floating parts: 0. Animated intersections: 0 across Draw, Fire, Inspect, Reload and ReloadEmpty.
- Contract equal: locators, bones and actions all true. The stock CharmLoop is dressed, not moved.
- ADS: eye-segment rays and post rays clear. The ADS render shows only the stock sights and receiver top.
- Flat export: 35 parts; 0 coplanar lifts, flips or crossed faces; untouched stock none; re-import inside-out none; one-sided magenta views clean.

**Self-grade**
| Area | Grade | Note |
|---|---|---|
| Silhouette | 9 | Stinger outline kept; cabinet butt, stepped brake and raked fore-end front are the shape changes |
| Crispness | 9 | flat-shaded, 1-segment chamfers, eight-sided prisms |
| Layering | 9 | deck, bezel, screen, pixels, buttons and fields each have their own lift (0.004+) |
| Connections | 9 | every join 0.02+ (pins excepted, stock), culled sweep clean |
| ADS | 10 | nothing new in the sight picture (ray and render checks) |
| Palette | 9 | purple body, violet fields, magenta/cyan/yellow accents |
| Budget | 9 | 1.487x |
| Contract | 10 | all equal |
| **Gun** | **9** | |

**Owner decisions**
- The deck sits on the front half of the left receiver (ADS forces it there), so the near end of the first-person view is the stock-block art field and the plain purple rear receiver. If you want something nearer the eye, it can only go on the rear receiver below about z .30.
