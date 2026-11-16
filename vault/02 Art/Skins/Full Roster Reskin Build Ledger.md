# Full roster reskin build ledger

**Revision v04 · 2026-11-15 · Studio installation verified**

All 51 skins are installed in the lobby Locker and match skin selection. The saved Team Create versions are match 558 and lobby 541. The next review item is a Studio playtest of Oilwake Phantom from Locker equip through match hip and aim views. Live publication is pending.

## Revision history

| Revision | Decision |
| --- | --- |
| v01 | Misprint Bulldog v03 baked and reviewed. Waiting for owner look approval before the next build. Stock Stinger handguard repaired in a shared versioned source. |
| v02 | Owner approved the Misprint Bulldog look and authorized the rest of the roster. |
| v03 | Completed and reviewed all three 17-gun lines. Closed the Blender-only queue and indexed the final versions. |
| v04 | Added the three lines to the match selector and lobby Locker. Verified the 51 variants in each place and saved both places to Roblox. |

## Studio installation

| Place | Place ID | Saved version | Verified skins |
| --- | --- | --- | --- |
| gauntletgame | `133387545285290` | 558 | 51 |
| Lobby \| gauntletgame | `71551303511506` | 541 | 51 |

- Each place has 17 Oilwake, 17 Misprint, and 17 Faultline variants. Studio Edit checks exercised the Locker’s available choices and saved choice validation, the match selector’s template resolution, and the match’s geometry swap for the 27 variants that need it. All 204 baked images preloaded in each place. The rig joints matched the stock models.
- Twelve corrected meshes are used across the nine affected guns in each line. The stock templates retain their original mesh IDs. Oilwake uses the baked PBR finish in Roblox. The Locker uses its existing lettered emblems with a swatch for each new line.
- The next playtest covers the rendered Locker card, equipment transfer, and held and aim appearance before any live publication. [Validation and save records](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Studio/install-validation-v01.json) · [Versions, texture IDs, and replacement meshes](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Studio/install-jobs-v01.json)

## Blender connection and pipeline

- A read-only query on `127.0.0.1:9999` reached Blender 5.2.2 LTS, PID 42336, with an unsaved startup scene. A recovery copy was saved before loading the stock sources. The connector used a session-local port override for build and review.
- Used `gauntlet-vault`, `gauntlet-build-style`, the existing `build_skin_roster.py` and `bake_textures.py` path, the stock model sheet cameras, and the project’s dry-run coplanarity and crossed-face checks. See [geometry checks](Reskin%20Geometry%20Regression%20Checks.md), [skin build pitfalls](Skin%20Build%20Pitfalls.md), and [Blender review workflow](Blender%20Review.md).

## Misprint Bulldog

| Version | Result |
| --- | --- |
| v01 | Superseded. The 1K bake exposed dark texture bleed on the left muzzle where the barrel's metal side and dark vent faces shared atlas pixels. |
| v02 | Superseded. The two UV fragments were corrected and baked at 2K. The initial 0.003-stud bolt offset reached the cheek insert at the peak of the Fire action. |
| **v03** | **Owner approved.** The final 0.0015-stud bolt correction clears the receiver and stays behind the cheek insert during movement. Four packed 2K maps match the on-disk PNGs byte for byte after reopening. |

- [Misprint Bulldog v03 Blender asset](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/Bulldog_Misprint_v03.blend) · [Manifest and map hashes](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/manifest.json) · [Hero render](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/review/hero-finish.png)
- [Matched profiles, held view, hip, aim and top](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/review/matched-views.png) · [Receiver at the screenshot-facing and grazing angles](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/review/receiver-regression.png) · [Backface-culling comparison](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/review/backface-culling.png)
- [Grazing sweep](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/review/receiver-orbit.gif) · [Fire action scrub](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/review/receiver-fire.gif) · [Motion audit](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/review/motion-coplanarity.json) · [Muzzle bake before and after](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/review/muzzle-uv.png)

### Review evidence

- The retained stock **3,640 triangles**, outer dimensions, sight and grip geometry, pivots, attachment hierarchy, rig, and action data were checked against v05. All **271** integer action frames produced matching part and locator transforms. The bolt geometry has one documented local exception.
- The stock aim-camera transform, field of view, near clip and 625 sampled first hits matched on reopen. The seven matched views had 100% silhouette overlap at a 50% alpha threshold. The culling views show the original sling slot and muzzle/trigger-guard openings. The contact sheet uses the stock model-sheet held angle and the stock hip and aim cameras.
- The receiver comparison uses stock v05, the previous structural Payload v02, the closest material-only reference PopCircuit v01, and the saved Misprint v03. The screenshot has no variant identifier. Isolating the bolt removed the interference in stock. The 21-step angle sweep and the Fire clip showed a stable bolt surface. The dry-run receiver/bolt/stock audit returned zero coplanar candidates across the same 271 action frames.
- The shared stock UV layout remains in use except 51 barrel UV corners on 17 Dark faces and 72 stock UV corners on 24 Grip faces. The stock fragment was scaled to 80% to seat it in free atlas space. The 2K atlas audit found zero overlap and the saved maps use six-pixel padding. The dark muzzle rectangles disappeared in the matched rebake. Static print aligns across the fixed panel seams and stops at the separate hardware.
- The approved cobalt, vermilion and purple artwork and halftone placement were retained. The crown wrap was widened around the forward portion of the fixed receiver. Graphite grip surfaces and stock sight hardware provide the quiet areas.

### Blender-only grade

| Category | Score | Reason |
| --- | ---: | --- |
| Design and finish | 33/35 | Ivory, offset ink, overprint and dot field match the study. The crown treatment extends farther beside the rail and the strongest specular angles lighten the print. |
| Stock geometry and rig fidelity | 29/30 | Measured stock fidelity with the local 0.0015-stud bolt correction. |
| Baked texture and seam quality | 18/20 | Clean joints and muzzle after the local UV correction. Close grazing crops still resolve the baked edge texels. |
| Held, aim and motion clearance | 15/15 | Matched held and aim framing, ray grid, motion transforms and receiver sweep. |
| **Total** | **95/100** | **Owner approved.** |

## Versioned source repairs

| Gun | Reproduced cause and final correction | Evidence |
| --- | --- | --- |
| Bulldog | The exterior bolt face and the receiver coincided at rest. In `BoltFix_v02`, only the 24 bolt vertices were translated by 0.0015 studs in the outward direction. The bolt profile, pivot and motion stay stock. | [Source blend](../../../art-source/weapons/Skins/Shared%20Sources/Bulldog/BoltFix_v02/Bulldog_RemasterV2_v05_BoltFix_v02.blend) · [Before and after](../../../art-source/weapons/Skins/Shared%20Sources/Bulldog/BoltFix_v02/evidence/before-after.png) · [Repair audit](../../../art-source/weapons/Skins/Shared%20Sources/Bulldog/BoltFix_v02/repair.json) |
| Stinger | The six handguard groove floors shared the receiver plane at ±0.0800. `HandguardFix_v01` moves 36 groove-floor vertices to ±0.0827 and retains the 0.0013-stud depth below the original external hand-contact surface. The join, ridges, topology, triangle count, UV atlas, rig, and actions passed review. **Use this source for all three Stinger skins.** | [Shared source blend](../../../art-source/weapons/Skins/Shared%20Sources/Stinger/HandguardFix_v01/Stinger_RemasterV2_v05_HandguardFix_v01.blend) · [Before and after, both sides and underside](../../../art-source/weapons/Skins/Shared%20Sources/Stinger/HandguardFix_v01/evidence/before-after.png) · [Earlier Inkshift reference](../../../art-source/weapons/Skins/Shared%20Sources/Stinger/HandguardFix_v01/evidence/inkshift-owner.png) · [Repair audit](../../../art-source/weapons/Skins/Shared%20Sources/Stinger/HandguardFix_v01/repair.json) |

## Roster review

[Three finish references](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/finish-references.jpg) · [Bulldog and Stinger close-ups across all lines](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/flagged-area-comparison.jpg) · [Machine-readable verification](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/roster-verification.json)

| Line | Finish comparisons | Held and sight comparisons |
| --- | --- | --- |
| Oilwake | [01](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/finish-01.jpg) · [02](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/finish-02.jpg) · [03](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/finish-03.jpg) · [04](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/finish-04.jpg) · [05](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/finish-05.jpg) | [01](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/held-and-aim-01.jpg) · [02](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/held-and-aim-02.jpg) · [03](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/held-and-aim-03.jpg) · [04](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/held-and-aim-04.jpg) · [05](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/held-and-aim-05.jpg) |
| Misprint | [01](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/finish-01.jpg) · [02](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/finish-02.jpg) · [03](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/finish-03.jpg) · [04](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/finish-04.jpg) · [05](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/finish-05.jpg) | [01](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/held-and-aim-01.jpg) · [02](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/held-and-aim-02.jpg) · [03](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/held-and-aim-03.jpg) · [04](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/held-and-aim-04.jpg) · [05](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Misprint/held-and-aim-05.jpg) |
| Faultline | [01](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/finish-01.jpg) · [02](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/finish-02.jpg) · [03](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/finish-03.jpg) · [04](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/finish-04.jpg) · [05](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/finish-05.jpg) | [01](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/held-and-aim-01.jpg) · [02](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/held-and-aim-02.jpg) · [03](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/held-and-aim-03.jpg) · [04](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/held-and-aim-04.jpg) · [05](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/held-and-aim-05.jpg) |

- Each final asset was baked, saved, reopened through Blender MCP on port 9999, and rendered with its packed maps. The baseline comparisons include both profiles, held, top, and the stock aim camera where present. The remaining stock files use their model-sheet three-quarter sight inspection.
- The stock hierarchy, pivots, locators, rig, action data, and triangle counts match the selected sources. The source exceptions are Bulldog BoltFix v02 and Stinger HandguardFix v01. All three Stinger entries use the shared repaired source. The two flagged guns have zero coplanar candidates in the reopened geometry audit.
- Six gun atlases needed local UV changes to remove stock overlap. The manifests identify each changed face or UV fragment. The final 204 external PNGs match the packed maps. The 2K maps are used for the heroes and all Bulldog variants. The other bakes use 1536 pixels per side for Blender review.
- Eight other guns retain the same dry-run coplanarity candidates as their stock Blender sources. The matched captures and manifests record the inherited conditions. Studio appearance, live ADS, scope hiding, and magazine visibility remain for the later Studio pass.
- Oilwake uses the Blender view-angle coating over the baked PBR base. Its maps also carry a static petrol-to-amber treatment for the later platform check.

### Blender-only hero grades

| Hero | Design /35 | Geometry /30 | Bake /20 | Held, aim and motion /15 | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Misprint Bulldog v03 | 33 | 29 | 18 | 15 | **95** |
| Oilwake Phantom v01 | 34 | 29 | 18 | 14 | **95** |
| Faultline Sheriff v01 | 34 | 30 | 18 | 14 | **96** |

- **Oilwake Phantom.** The inset shifts from petrol to warm amber while its rim and secondary inset stay readable. The baked fallback has a shallower colour range. The stock suppressor/receiver audit flags are documented. [Hero review](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Oilwake/Phantom-hero-review.jpg)
- **Faultline Sheriff.** The v02 concept's three ash values, single branch and copper repair sit on the fixed shroud and frame. Close crops still resolve small bake-edge texels. [Hero review](../../../art-source/weapons/Skins/Review/Oilwake-Misprint-Faultline/Faultline/Sheriff-hero-review.jpg)

### Placement revisions

- Oilwake Vandal, Bulldog, Shorty, Judge, Marshal, and Outlaw v02 seat their coatings inside the existing insets or clear of adjacent hardware.
- Misprint Vandal, Guardian, and Sheriff v02 improve crown registration. Ghost adds the small suppressor echo and Marshal moves the print onto the fixed fore-end inset.
- Faultline Marshal v02 carries the fracture across the fore-end recess. Bulldog v02 routes its copper below the stock cheek insert.

## 51-variant queue

| Gun | Oilwake | Misprint | Faultline |
| --- | --- | --- | --- |
| Vandal | [`v02`](../../../art-source/weapons/Skins/Oilwake/Vandal/v02/manifest.json) · Reviewed | [`v02`](../../../art-source/weapons/Skins/Misprint/Vandal/v02/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Vandal/v01/manifest.json) · Reviewed |
| Phantom | [`v01`](../../../art-source/weapons/Skins/Oilwake/Phantom/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Phantom/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Phantom/v01/manifest.json) · Reviewed |
| Bulldog | [`v02`](../../../art-source/weapons/Skins/Oilwake/Bulldog/v02/manifest.json) · Reviewed | [`v03`](../../../art-source/weapons/Skins/Misprint/Bulldog/v03/manifest.json) · Owner approved | [`v02`](../../../art-source/weapons/Skins/Faultline/Bulldog/v02/manifest.json) · Reviewed |
| Guardian | [`v01`](../../../art-source/weapons/Skins/Oilwake/Guardian/v01/manifest.json) · Reviewed | [`v02`](../../../art-source/weapons/Skins/Misprint/Guardian/v02/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Guardian/v01/manifest.json) · Reviewed |
| Spectre | [`v01`](../../../art-source/weapons/Skins/Oilwake/Spectre/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Spectre/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Spectre/v01/manifest.json) · Reviewed |
| Stinger | [`v01`](../../../art-source/weapons/Skins/Oilwake/Stinger/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Stinger/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Stinger/v01/manifest.json) · Reviewed |
| Ares | [`v01`](../../../art-source/weapons/Skins/Oilwake/Ares/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Ares/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Ares/v01/manifest.json) · Reviewed |
| Odin | [`v01`](../../../art-source/weapons/Skins/Oilwake/Odin/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Odin/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Odin/v01/manifest.json) · Reviewed |
| Sheriff | [`v01`](../../../art-source/weapons/Skins/Oilwake/Sheriff/v01/manifest.json) · Reviewed | [`v02`](../../../art-source/weapons/Skins/Misprint/Sheriff/v02/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Sheriff/v01/manifest.json) · Reviewed |
| Classic | [`v01`](../../../art-source/weapons/Skins/Oilwake/Classic/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Classic/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Classic/v01/manifest.json) · Reviewed |
| Ghost | [`v01`](../../../art-source/weapons/Skins/Oilwake/Ghost/v01/manifest.json) · Reviewed | [`v02`](../../../art-source/weapons/Skins/Misprint/Ghost/v02/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Ghost/v01/manifest.json) · Reviewed |
| Shorty | [`v02`](../../../art-source/weapons/Skins/Oilwake/Shorty/v02/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Shorty/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Shorty/v01/manifest.json) · Reviewed |
| Bucky | [`v01`](../../../art-source/weapons/Skins/Oilwake/Bucky/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Bucky/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Bucky/v01/manifest.json) · Reviewed |
| Judge | [`v02`](../../../art-source/weapons/Skins/Oilwake/Judge/v02/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Judge/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Judge/v01/manifest.json) · Reviewed |
| Marshal | [`v02`](../../../art-source/weapons/Skins/Oilwake/Marshal/v02/manifest.json) · Reviewed | [`v02`](../../../art-source/weapons/Skins/Misprint/Marshal/v02/manifest.json) · Reviewed | [`v02`](../../../art-source/weapons/Skins/Faultline/Marshal/v02/manifest.json) · Reviewed |
| Outlaw | [`v02`](../../../art-source/weapons/Skins/Oilwake/Outlaw/v02/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Outlaw/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Outlaw/v01/manifest.json) · Reviewed |
| Operator | [`v01`](../../../art-source/weapons/Skins/Oilwake/Operator/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Misprint/Operator/v01/manifest.json) · Reviewed | [`v01`](../../../art-source/weapons/Skins/Faultline/Operator/v01/manifest.json) · Reviewed |
