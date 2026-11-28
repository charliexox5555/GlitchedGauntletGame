### Operator (Deadeye)

2026-11-27. Built in Blender only. Final: **v03, self-grade 9/10**. Not installed.

**Files**
- Build script: `tools/blender/arcade/16_operator.py` (stock measurements are in its docstring)
- Review stations: `tools/blender/arcade/21_review_operator.py`
- Sheet list: `tools/blender/arcade/sheet_operator.json`
- Master: `art-source/weapons/Skins/Arcade/Operator/v03/Operator_Arcade_v03.blend`
- Export: `art-source/weapons/Skins/Arcade/Operator/v03x/` (`Operator_Arcade_v03x.blend`, `Operator_Arcade_RobloxFlat.fbx`, `manifest_flat.json`)
- Captures: `vault/02 Art/Skins/Arcade/out/Operator_v03_views/`. This folder also holds `audit.json`.
- Flat check: `vault/02 Art/Skins/Arcade/out/Operator_v03x_flat_check/`
- Review sheet: [Operator_v03_review.png](../out/Operator_v03_review.png)

**Versions**
- **v01:** the first build. Audit: the brake and its light floated, and there was 1 coplanar pair.
  - The stock barrel collar is an open-ended band, so the brake (r .070) sat loose inside it.
  - The scope ring bases shared side planes with the rail teeth.
- **v02:** the brake's rear grows to r .074. It starts 0.020 inside the collar and cuts through the collar's front chamfer, which closes the band's mouth. This fixed the floating parts.
  - It also tried tapering the ring-base feet, but that still left 1 coplanar pair.
- **v03:** the ring bases now widen 0.002 on each side (y ±.038), clear of the teeth (±.036). Their feet sit at .446, 0.004 under the teeth's feet (.450). Result: 0 coplanar pairs. **Final.**

**The look**
- **Left receiver face, under the bolt window:** a tall cabinet deck (x .14–.76).
  - A joystick at the rear, then three buttons in collars rising toward the muzzle: cyan, yellow, magenta.
  - A pixel screen in a bezel, with a cyan light pipe along the top edge.
  - The deck covers the removed stock Neon and its seat.
- **Right receiver face:** a coin door under the bolt handle.
- **Handguard:** a new handguard with a raked cabinet nose.
  - Faceted vents behind the support hand.
  - A side-art field ahead of the hand, on both sides.
  - A magenta T-molding trim along each lower chamfer, sloped to follow the stock line.
- **Stock frame:** band, line and pixel-trail art.
- **Butt:** a cabinet butt with a raked cyan marquee and side-art fields.
- **Muzzle:** a stepped eight-sided brake with a cyan light ring and three through-ports.
- **Magazine:** a magenta stripe on the inset, on both sides.
- **Bones:**
  - All deck, screen and button parts are on `Root`.
  - Only the mag stripe rides `Mag`.
  - The CharmLoop is kept (this is not a moved-charm gun). The deck ends 0.17 behind it.

**Gap sweep (stock joins closed, each buried 0.02+ unless noted)**

| Join | Problem in stock | Fix |
|---|---|---|
| Grip under the stock tube | A 0.013 see-through slot | Grip top .137 → .170 |
| Trigger guard to receiver | Met flush at .133 | Guard top → .155 |
| Magwell to receiver | Only 0.007 overlap | Magwell top → .156 |
| Tube to receiver | Only 0.008 overlap | Tube front → .082 |
| Tube to frame | Met flush at -.333 | Tube rear → -.355 |
| Cheek-riser posts | 0.005 into the riser, 0.015 into the frame | Posts now .280 to .355 |
| Rail base on receiver | Only 0.002 overlap | Rail foot → .430. **Buried 0.018, not 0.02:** the bolt's top (.428) runs under it |
| Rail teeth on rail | Only 0.001 overlap | Teeth feet → .450 |
| Scope ring bases | Stood on the teeth, floated 0.008 over the rail between teeth | Feet → .446 (0.024 into the rail); widened 0.002 a side. The lens and the scope body above the bases are untouched |
| Barrel tube in collar | Only 0.012 overlap | Tube → 3.132 (0.024 into the collar) |
| Handguard into receiver | Only 0.013 overlap | New handguard starts at 1.070 (0.025 in) |
| Butt to frame | — | The new butt swallows the frame's rear member by 0.025 |

- The culled magenta close-ups cover the left, right and below of every join: handguard and receiver, nose and barrel, trigger guard, grip, magwell, tube, tube and frame, riser posts, butt, rail and scope, collar and brake.
- **No gaps are left.**

**Audit (v03)**
- **Triangles:** 6938 against 4950 stock, which is **1.40×** (the budget is 1.5×).
- **Faults:** 0 in new geometry.
  - The 19 listed faults are the unchanged stock open islands: Receiver, Barrel and Scope. They have the same open-edge counts as stock.
  - The moved stock islands kept their topology.
- **Other checks:** 0 coplanar pairs, 0 floating parts, 0 animated intersections.
- **Contract:** equal for locators, bones, actions and lenses.
- **ADS:**
  - `ADS_DISTANCE` is 0.70. The Operator has no `adsDistance`, so it falls back to the Viewmodel default.
  - The eye-segment rays are clear.
  - The post rays hit only the stock Scope and ScopeLens.
- **Flat export:**
  - 0 lifts, 0 flips, 0 crossed faces, and a one-sided re-import with 0 inside-out parts.
  - The ScopeLens exports untouched.

**ADS note**
- The scope picture (the lens) is clear.
- In the ADS render, the joystick ball and the rear button collar's edge peek out left of the receiver, just above the cheek riser. They sit where the stock bolt knob peeks out on the right.
- The scope overlay covers this once scoped in, so it only shows during the 0.38 s scope-in.
- Hiding it fully would mean moving the joystick off the rear of the deck. That breaks the line's layout, so it was left as is: **owner's call.**

**Grade (lowest area = the gun's grade)**

| Area | Grade | Note |
|---|---|---|
| Silhouette | 9 | Still reads as the Operator. The raked nose, cabinet butt and stepped brake make it the Arcade line |
| Crispness | 9 | Flat facets, 1-segment chamfers |
| Layering | 9 | The deck, bezel, screen, pixels, buttons and fields each have their own lift |
| Connections | 9 | 0 floating parts or gaps. The rail is buried 0.018 (limited by the bolt) |
| ADS | 9 | The lens is clear. Small joystick peek during the scope-in (see above) |
| Palette | 9 | The line's roles, small accents |
| Budget | 10 | 1.40× |
| Contract | 10 | All equal |
| **Gun** | **9** | |
