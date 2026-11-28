### Marshal (Scout)

2026-11-27. Arcade line, Blender only (nothing installed, uploaded or committed). Final: **v04, self-grade 9/10.** Review sheet: [Marshal_v04_review.png](../out/Marshal_v04_review.png) (v03 sheet: [Marshal_v03_review.png](../out/Marshal_v03_review.png)).

**Script:** `tools/blender/arcade/17_marshal.py` (stations: `21_review_marshal.py`, sheet list: `sheet_marshal.json`). Built on `art-source/weapons/RemasterV2/Marshal/Marshal_RemasterV2_v05.blend` in a dedicated live Blender (port 9882).

**ADS distance:** Config/Weapons has no `adsDistance` for the Marshal (it is scoped), so the audit and review use Viewmodel `ADS_DISTANCE` 0.70: eye at x -.687, z .3333. The scope, `ScopeLens` and the stock barrel's front sight have unchanged geometry; the lens is not dressed at all.

#### Versions
| Version | What changed | Result |
|---|---|---|
| v01 | First build: deck, coin door, fore-end field (a boolean cut on a copy of the stock fore-end), stock art, cabinet butt, muzzle sleeve. | The stock fore-end recess (floor .064) covers nearly the whole flat side (z .02-.175), so the field cut left .064 strips: 2 coplanar pairs with the stripes. Copying the stock body, barrel and neon as `AR_` objects made the audit count the stock lever, bolt and hammer passing through the stock wrist, and the shell passing the stock neon, as Arcade intersections. |
| v02 | The fore-end is rebuilt as one closed loft on the stock envelope: it runs 0.022 into the receiver (stock: a flush butt joint at x .888), and its front rakes up under the magazine tube and narrows (y .052) to end 0.022 into the barrel band. The stock body, barrel and neon are dressed in place (stock objects, stock clips). | One coplanar pair: the light ring's rear cap against the barrel's bore floor (x 3.1377). The review showed cyan down the bore (the solid light ring) and a grey stock body. |
| v03 | The light ring is a hollow ring whose bore (r .036) lies inside the barrel wall. The stock crown ring (buried in the sleeve) is removed. The stock body's polymer (Grip) faces are cabinet purple. The cabinet butt is longer (it swallows 0.084 of the body, was 0.049), with its marquee and field moved forward. | All gates pass. (I rebuilt v03 once before reviewing it, to add the hollow ring and remove the crown ring; that first try was never reviewed or exported.) The orchestrator's review found two problems: the stock still read charcoal, and the joystick ball showed as a pink dot in the ADS render. |
| v04 | Orchestrator fixes. **Stock:** the stock's Dark faces are AR Body purple and its recessed polymer panels (Grip) are AR Panel violet, matching the line's other stocks. **ADS:** I ray-cast the 68° review frustum from the 0.70 eye. In v03 it saw the joystick and also buttons 1–2, the deck's top edge, the light pipe and the coin door's rear and top edge. I then mapped how far a part may stand off each receiver side and stay hidden behind the receiver: about .069 at x .15, .083 at .30, .100 at .50, .110 at .66 (z .06–.14), and only .072–.094 above z .16. The deck is now 0.010 proud (face .076). Its rear rakes into the receiver (.0675 at x .150 to .076 at .270), and its top slopes back like a cabinet control panel (.076 at z .150 to .068 at .192), with the light pipe lying on the slope. The controls sit where the receiver hides them, in the same order: joystick at x .500 (tip y .097, a squat ball on a short shaft), buttons at .560 / .612 / .664 (tips .092), then the screen at .698–.820. The raked rear carries a magenta band, a cyan line and a pixel trail. The coin door moves forward and lower (x .30–.64, z .092–.164, face -.076), and its coin entries move to x .44 / .54. | All gates pass. In ADS the frustum hits no new part: the only Arcade object it reaches is the fore-end's top chamfer (2 rays), on exactly the rays where the stock fore-end shows the same envelope. |

#### Parts
- **Control deck, left (player side; v03 form, v04 changes are in the table):** a raised PANEL plate over the whole left receiver panel recess. Its back is at y .057 (buried in the recess floor .061 and the .066 face), its face at .082. It hides the stock left neon and the rear-top pin. On it, rear to front: a joystick (washer, shaft, faceted magenta ball), then three faceted buttons in collars (cyan, yellow, magenta) rising toward the muzzle, then a pixel screen in a bezel (ship, shot, stars, blip) and a cyan light pipe along the top edge. All of it is on `Root`.
- **Coin door, right (v03 form; v04 moves it, see the table):** a metal slab above the loading gate (frame top .068) and the shell's whole reload path (z ≤ .064, measured relative to Root over every clip). It has two lilac coin entries with lit yellow slots and a magenta stripe. The stock right neon bar stays in its groove below the door.
- **Fore-end:** a pixel-cornered violet field is cut 0.008 into each side, with lips 0.013 to the chamfers. Inside it: a raked magenta band and a cyan line with buried ends, a yellow starburst and a magenta pixel trail. A magenta T-molding trim bar sits on each lower 45° chamfer.
- **Stock body:** purple (v04: AR Body with AR Panel fields), with a raked band, a line and a pixel trail on the .062 band (lift 0.0045).
- **Cabinet butt:** replaces the butt plate. It has a raked marquee top with a cyan marquee light in a dark seat, a stepped rear, and a recessed violet field with a band, a line and a star on each side. It is 0.010 wider than the body, with lips 0.016 over the top and 0.018 under.
- **Muzzle sleeve:** a stepped eight-sided ring with a through bore (r .030). Its rear collar is 0.007 over the front sight's ramp tail. A cyan light ring sits in a groove, with its ends buried 0.006 and 0.003 in the groove walls. The Muzzle locator (x 3.1977) sits 0.014 inside the mouth.
- **No mag stripe:** the gun is tube-fed and has no `Mag` bone.
- **Bones:** every new part is on `Root`. Nothing sits on the Lever, Bolt, Hammer, Trigger or Shell.

#### Paths
- Masters: `art-source/weapons/Skins/Arcade/Marshal/v01/`, `v02/`, `v03/`, `v04/Marshal_Arcade_v04.blend`
- Export (final): `art-source/weapons/Skins/Arcade/Marshal/v04x/Marshal_Arcade_v04x.blend`, `Marshal_Arcade_RobloxFlat.fbx`, `manifest_flat.json` (v03x is superseded)
- Evidence: `vault/02 Art/Skins/Arcade/out/Marshal_v04_views/` (audit.json, wb/culled/finish/pose/stock captures), `out/Marshal_v04x_flat_check/` (v03 equivalents kept)

#### Triangles
v04 has **6263 triangles against 4407 stock (1.42×)**; v03 had 6185; the budget is 6610 (1.5×).

#### Audit (v04, `49_audit.py` with ADS_DISTANCE 0.70; v03 gave the same results)
- **Faults:** 0 in new geometry. The only listed faults are unchanged stock islands, with the same open counts as the stock:
  - the receiver rail slots;
  - the scope's open caps;
  - the pins;
  - the barrel tubes (28 / 18 / 8);
  - the stock body (10);
  - the hammer's own stock self-intersections.
- **Coplanar pairs:** 0. The stock had 1: the flush fore-end/receiver joint, now buried.
- **Floating parts:** 0.
- **Animated intersections:** 0 in all 8 clips.
- **Contract:** equal on all four keys (locators, bones, actions, lenses). The stock `CharmLoop` is kept and dressed. The CharmPoint (z -.060) has 0.018+ clearance under the deck.
- **ADS:** all five eye-segment rays are clear, the same as stock. The post ray hits only `Marshal_Scope` and `Marshal_ScopeLens`, the same as stock. v04: the ADS render shows nothing new. The ray-cast frustum check reaches no Arcade part except the fore-end top chamfer, on the same 2 rays where the stock fore-end shows.
- **Flat export (v04x):** 27 parts. No lifts, no flips, no crossed faces fixed or left. The one-sided magenta re-import renders show no holes. The re-import's signed-volume test lists `SK_Shell_01`. That piece is the stock round's 8-face primer cap: an open fragment of the closed, outward-facing shell (the whole shell's volume is +0.00022). The fragment's volume about the origin comes out negative, so this is a false positive on stock geometry the skin doesn't change.

#### Gap sweep
Culled magenta close-ups from the side and from below cover these joins:
- the fore-end to the receiver, both sides;
- the fore-end to the barrel band;
- the fore-end underside;
- the trigger and lever loop, both sides and from below;
- the stock wrist, both sides;
- the loading gate;
- the scope mounts on the rail;
- the front band and magazine-tube cap;
- the butt join and its underside;
- the muzzle sleeve's collar over the sight ramp, and the muzzle front.

**Fixed:** the stock fore-end met the receiver in a flush butt joint at x .888 (it is now buried 0.022). The fore-end's front is now buried 0.022 in the barrel band; the stock met it flush at 1.904. No other see-through gaps.

#### Grade
| Area | Grade | Note |
|---|---|---|
| Silhouette | 9 | Still reads as the lever-action Scout. New shape in the deck, the raked fore-end front, the cabinet butt and the stepped sleeve. |
| Crispness | 9 | Flat shaded, eight-sided prisms, 1-segment chamfers. |
| Layering | 9 | The deck, bezel, screen, pixels, buttons and fields each have their own lift (0.004+). v04: the joystick is short (0.021 over the deck) to stay out of the ADS frame, so it reads close to a fourth button. |
| Connections | 9 | Joins buried 0.02+, nothing floating. |
| ADS | 10 | v04: nothing new in the ADS frame (checked by ray-cast frustum). |
| Palette | 9 | Line roles. v04: the stock is AR Body purple with AR Panel violet fields. |
| Budget | 10 | 1.40× stock. |
| Contract | 10 | Every bone, locator, action, the lens and the CharmLoop are equal to stock. |
| **Gun** | **9** | |

#### For the owner
- The flat check lists the stock shell's primer cap (`SK_Shell_01`) as inside-out. I believe this is a false positive (see the audit).
- v04: to stay out of the ADS frame, the joystick is short and sits at x .50, with the deck's raked rear (band and line) behind it. If you want a taller stick, it has to move further forward (about x .66+).
- The Marshal has no `adsDistance`, so the review used the Viewmodel default of 0.70.
- The crown ring is removed from the stock barrel. It sat entirely inside the new sleeve.
