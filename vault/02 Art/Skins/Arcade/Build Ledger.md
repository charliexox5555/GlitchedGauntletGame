# Arcade build ledger (Season 1 battle pass, Rare)

The Arcade line, built one gun at a time from [Arcade and Frostbite Handoff](../Arcade%20and%20Frostbite%20Handoff.md). Each gun is built in Blender on its stock RemasterV2 v05 rig, audited, self-graded, and shown to the owner before it goes on. Method, gates and rubric are copied from the [Rare Line Rework Handoff](../Rare%20Line%20Rework%20Handoff.md) and the [Slipframe rework ledger](../Slipframe/Rework%20Ledger.md). The checks are from [Skin Build Pitfalls](../Skin%20Build%20Pitfalls.md).

## Line language (from the owner's ChatGPT concept, 2026-11-27)
- **Cabinet body**: deep purple with a violet side-art field. Bold flat stripes (magenta band plus cyan line, raked about 30°) and a yellow eight-point starburst. Pixel steps cut into the field corners.
- **Signature parts** (shape changes):
  - a cabinet control deck on the player-facing side, with a pixel screen in a bezel and three faceted buttons in collars;
  - a joystick ball on the charging knob;
  - a coin door on the ejection side;
  - a cabinet-profile butt with a marquee light;
  - a stepped octagonal brake with a light ring.
- **Kept from stock, on owner direction:**
  - The ADS and charm mount are the same family across every gun. The concept's top joystick, sight shape and charm ring are not copied.
  - The stock rear ring, front post, `CharmLoop` and `CharmPoint` are unchanged.

### Palette (roles, `mf_hex`)
| Role | Hex | Roblox |
|---|---|---|
| AR Body | `2A1745` | SmoothPlastic |
| AR Panel | `3D2569` | SmoothPlastic |
| AR Dark | `17121F` | SmoothPlastic |
| AR Grip | `1E1929` | SmoothPlastic |
| AR Metal | `2D3040` | Metal |
| AR Accent | `6F6890` | SmoothPlastic |
| AR Screen | `0B1424` | SmoothPlastic (never Glass) |
| AR Magenta / Cyan / Yellow | `E01E8C` / `14C8DC` / `F5C518` | Neon (tune brightness in Studio) |
| AR BtnMagenta / BtnCyan / BtnYellow | `E8338F` / `1FB8D2` / `F2C230` | SmoothPlastic |

### Scripts (`tools/blender/arcade/`)
- `arcade_lib.py`: the shared kit (loft, fold, recess, `prism_along`, `pixel_solid`, star plates, `dress`).
- `10_vandal.py`: the build.
- `49_audit.py`: the Slipframe audit, ported.
- `20_review.py` + `21_review_vandal.py`: the captures.
- `53_export.py`: the flat export and the re-import check.
- `30_sheet.py`: the review sheet.

## Vandal (Havoc), hero gun

| Version | What changed |
|---|---|
| v01 | First build. Neon renders washed out; buttons and joystick too small. |
| v02 | Buttons r 0.024 in r 0.030 collars; bigger joystick; cyan light pipe on the deck; purple butt. Audit found 2 flush faces (light strip against a recess wall, barrel cap against handguard cap). |
| v03 | Both flush faces fixed. Full review. The mag stripe didn't line up with the stock cyan strip. |
| v04 | Mag stripe realigned, but it clipped the magwell on 1 reload frame. |
| **v05** | Mag stripe top lowered to z 0.052. **Candidate shown to the owner.** |

**v05 results**
- Master: `art-source/weapons/Skins/Arcade/Vandal/v05/Vandal_Arcade_v05.blend`. Export copy: `v05x/` (`Vandal_Arcade_RobloxFlat.fbx`, `manifest_flat.json`, 32 parts).
- **Triangles:** 6,673 against 5,171 for the stock gun (1.29×, inside the 1.5-2× Rare budget). It is above the Art Direction 5K primary guide.
- **Audit** (`out/Vandal_v05_views/audit.json`):
  - 0 faults in new geometry. The 37 open-border islands are the stock gun's own, inherited unchanged.
  - 0 coplanar pairs.
  - Floating: only the charging handle group, which the stock gun has too. The joystick seats on its knob.
  - Bones, locators and actions are identical to the stock.
  - 0 animated intersections across the Draw, Fire, Inspect, Reload and ReloadEmpty clips.
- **ADS:** all five `findOccluders` rays are clear. The post ray hits only `Vandal_FrontSight`, and the sights export as `SK_Root_Sight_*`. The joystick ball shows outside the ring at the lower left, nowhere near the window.
- **Flat export:**
  - 0 coplanar lifts needed, 0 flipped islands, 0 crossed faces.
  - The one-sided magenta re-import shows no holes (`out/Vandal_v05x_flat_check/`).
- **Review sheet:** [Vandal_v05_review.png](out/Vandal_v05_review.png) (local, git-ignored). It has hero, sides, top, first person, ADS, join close-ups, the Studio check and the stock comparison.
- **Self-grade** (handoff rubric; the gun's grade is its lowest score). Overall **9/10**.

| Area | Grade |
|---|---|
| Silhouette | 9 |
| Crispness | 9 |
| Layering | 9 |
| Connections | 9 |
| ADS | 9 |
| Palette | 9 |
| Budget | 9 |
| Contract | 10 |

**Owner review (2026-11-27):** "looks really good". Wanted:
- a bit more pop, so it reads as more than a reskin;
- the joystick out of the ADS view;
- small in-game effects (buttons and screen);
- the final check, then install it.


### Vandal v06 to v07: final touches
**What changed**
- **Joystick on the deck.** It moved off the charging knob to the rear of the deck, left of the buttons, like a real control panel. It no longer shows in ADS.
- **Buttons reordered** to cyan, yellow, magenta, so the ball isn't next to a same-colour button. Buttons are r 0.022 in r 0.028 collars.
- **Lit edge trim.** A magenta T-molding bar is seated into each lower handguard corner.
- **Pixel speed trails** behind the handguard and stock stripes.
- **Screen glows.** The screen floor is Neon `12234A`.
- **Brighter colours.** Side-art field `47297C`, body `2C1650`.
- **Separate parts for the effects.** These carry `flat_group` names and export as their own parts:
  - `ARButton1-3`, `ARStickBall`
  - `ARScreen`, `ARScreenShip`, `ARScreenShot`, `ARScreenStars`, `ARScreenBlip`
  - `ARDeckLight`, `ARTrim`, `ARBrakeLight`

**v07 results**
- **Master:** `art-source/weapons/Skins/Arcade/Vandal/v07/Vandal_Arcade_v07.blend`. Export: `v07x/` (38 parts).
- **Triangles:** 6,977.
- **Audit:**
  - 0 faults in new geometry, 0 coplanar pairs.
  - Floating: only the stock charging handle.
  - Bones, locators and actions are identical to the stock.
  - 0 animated intersections.
  - All 5 ADS rays are clear, and nothing new shows in the ADS view.
- **Flat export:** 0 lifts, flips or crossed faces. The one-sided magenta re-import is clean.
- **Self-grade:** 9/10. [Review sheet](out/Vandal_v07_review.png)

## Studio install (2026-11-27, place 71551303511506)

**Install**
1. Uploaded `Vandal_Arcade_RobloxFlat.fbx` as group model **122087200971885**.
2. Ran `make_flat_install_jobs.py` with `--version v07x`, then `InstallFlatSkin`. 38 MeshParts came in.
   - `KEPT` is now optional for Vandal installs that replace every stock part.
3. Moved the model to `ServerStorage.WeaponSkins.Arcade.Vandal` and tagged it `GGAsset_LobbySkins_265` + `GauntletAuthoredData`. The row is in `Config/AssetData/LobbySkins.luau`; the attributes were removed.
4. Removed the staging folder.

**Registration**
- `Config/Skins` has `Arcade = { tier = "Rare", kind = "shape", pass = true }`. The new `pass` flag keeps a line out of `SkinCases.allPairs`, so it never appears in cases or the daily shop.
- Arcade is added to `Config/SkinPreview` lines and `Locker.COLORS` (`D6339C`).
- The Locker hint for an unowned pass skin says "from the battle pass".
- `Lobby/SeasonRewards.rollGun` only rolls guns that have the line's model (`Locker.hasSkin`). Until more Arcade guns are built, every Arcade tier rolls the Havoc, and a player who already owns it gets `Season.SKIN_FALLBACK_COINS`.
- `export_skin_items_flat.VANDAL_VER["Arcade"] = "v07x"`, so the other guns take the Havoc's palette.

**Effects** (`Config/Arcade`, `client/Util/ArcadeEffects`, hooked into `ViewmodelController`). All local to the player's first-person view.
- **Each shot:** presses the next button in by 0.006, lights it Neon, and flashes the deck light in that button's colour. The pixel shot then steps 4 pixels toward the muzzle.
- **Idle:** the ship bobs one pixel every 0.55 s, and the stars and blip blink.
- **Inspect:** a button chase, with the deck light following and the ship cruising.
- **Mag seats (`MagIn`):** all three buttons flash.
- **Cleanup:** the parts live in the camera clone and are destroyed with it.

**Tests** (Studio Play, Lobby role)
- **Server:**
  - `SkinStore.has("Arcade", "Vandal")` is true.
  - The Havoc's Locker lines include Arcade.
  - Arcade is not in the case pool.
  - `rollGun` gives the Havoc, then coins once it's owned.
- **Locker:** admin grant, then equip. The ARCADE tile shows as RARE and EQUIPPED, and the 3D preview is correct.
- **Range:**
  - The viewmodel loads all 12 AR parts and 5 motors.
  - Over 4 shots the buttons cycle 1, 2, 3, 1 (Neon, pressed −0.0048 at viewmodel scale 0.8), the shot steps −0.0068 then −0.0204, and the deck light cycles `1FB8D2`, `F2C230`, `E8338F`.
  - Inspect shows the chase on screen.
- **Lint and build:** stylua, selene and the Rojo build are clean.

## Sounds (2026-11-27)
The owner asked for "an extra little sound on the inspect with the lights and the reload". The shot sound is unchanged.

**How the cues are made** (`tools/audio/design_arcade.py`):
- Each layers a real recording from the licensed ProPack (a button click or a coin clunk) under a soft synthesized 8-bit blip.
- The blip is a square wave, low-passed so it stays round, never harsh. Measured brightness centre is about 2.4 kHz, with under 0.2% of the energy above 6 kHz.
- The WAVs and audition reel are in `art-source/audio/arcade/`, which is git-ignored because it holds licensed material.

| Cue | Asset | Length | Plays |
|---|---|---|---|
| chase | 92623653287895 | 0.12 s | each inspect chase step (button click and blip), pitch 1 / 1.122 / 1.26 per button so it climbs |
| win | 118852986845022 | 0.27 s | the inspect finale: a three-note rising chime as all three buttons light |
| coin | 83881971671794 | 0.23 s | the mag seats (`MagIn`): coin drop, click, two credit notes |

**Code**
- **`Config/ArcadeAudio`:** the takes, volumes (0.22 / 0.30 / 0.30) and chase pitches.
- **`AudioController`:** the `arcade` bank.
- **`ViewmodelController`:**
  - warms the three cues when the Arcade gun is built;
  - plays the events that `ArcadeEffects.step` returns;
  - plays the coin on `MagIn`.
- **Inspect timing:** the chase is now fixed to the inspect's progress (`Config/Arcade`). 9 steps run from 0.16 to 0.60 of the clip (about 0.135 s each), then all three are lit from 0.62 to 0.78.

**Range test** (Studio Play)
- All 9 chase blips play, from the first inspect (with the cues warmed), at the climbing pitches.
- The win chime plays as the three buttons light (about 1.74 s in).
- The coin plays as the mag seats, about 1.1 s into the reload.
- **Caveat:** an inspect started in the first second after equipping can miss the win chime while it loads.

**Left to do**
- The Locker portrait (`ItemPortraits["Vandal/Arcade"]`) and the Arcade line emblem. The tile shows the stock picture until then.
- The other 13 Arcade guns, one at a time, with the same checks.
- **Owner:** save the place.

## Phantom (Spirit)
Built 2026-11-27 from the [Gun Brief](Gun%20Brief.md), Blender only (live MCP, PID-checked). Scripts: `11_phantom.py` (build), `21_review_phantom.py` (stations), `sheet_phantom.json`.

**Stock measured** (ray-cast depth maps, both sides):
- Receiver side face y .080, a side recess (floor .075) at x .04-.42 behind the fire selector lever (x .087-.136, turns 14°). The lower receiver stops at x .912; the upper receiver and the charging handle's nose reach x .934-.935.
- Handguard y .088, keel .238, shoulder .405, plus a separate nose cap. Skeleton stock face y .066, butt pad x -.98 to -1.098. Round suppressor can, r .077-.084.
- The stock file has no `Cam_Hip`. `20_review.py` now takes `HIP` for such guns: the Havoc's Cam_Hip raised 0.011/0.8 for the Phantom's lower `viewmodelOffset`.

| Version | What changed |
|---|---|
| v01 | First build. The audit found the charging handle running through the new handguard on every frame, and the marquee light's top face sharing a plane with the butt top (near-parallel rake). The stock receiver also has one flush pair (rear cap underside, Panel on Body). |
| v02 | Handguard rear seated 0.03 into the upper receiver, with a chamfered collar filling the stock seam at x .912-.938. The handle slot runs on into the handguard (a notch to x .946). The marquee light's top is raked 2° flatter. The stock rear-cap underside is lifted 0.004 in the build (the lift the export would make). The deck light pipe was shortened to run over the screen only, so it no longer doubles the stock cyan strip above the buttons. |
| v03 | Buttons and screen moved 0.01 forward, away from the joystick. Full review. |
| **v04** | Pixel trail on the stock frame moved next to its stripes, away from the stock sling square. The suppressor gets a stepped end cap. **Candidate.** |

**What the Arcade Spirit has**
- **Control deck** (left, Root) in the receiver's side recess, behind the fire selector: a joystick at the rear, then three buttons in collars rising toward the muzzle (cyan, yellow, magenta), a pixel screen in a bezel, and a cyan light pipe over the screen.
- **Coin door** (right): two lilac coin entries with yellow lit slots and a magenta stripe.
- **Handguard** on the stock envelope:
  - a cabinet kick under the middle (bottom .184);
  - the nose tapered into the stock cap;
  - recessed violet fields on both sides (pixel-stepped corner, magenta band, cyan line, starburst, pixel trail);
  - a magenta T-molding trim along each lower chamfer.
- **Cabinet butt**: raked marquee top with a cyan light, a stepped rear, and a recessed side-art field on both sides (starburst, band and line). The stock frame carries a raked band and line and a pixel trail.
- **Suppressor**: an eight-sided stepped can (rear section, light-ring groove with the cyan ring, the main can, a stepped end cap and a bore). The Muzzle locator sits in the bore.
- **Mag stripe**: magenta, bone `Mag`, top at z -.005, clear of the magwell.
- All 12 `flat_group` names are on Root parts: `ARButton1-3`, `ARStickBall`, `ARScreen*`, `ARDeckLight`, `ARTrim`, `ARBrakeLight`.

**v04 results**
- **Master:** `art-source/weapons/Skins/Arcade/Phantom/v04/Phantom_Arcade_v04.blend`. **Export:** `v04x/` (`Phantom_Arcade_RobloxFlat.fbx`, `manifest_flat.json`, 36 parts, all 12 AR groups as their own parts).
- **Triangles:** 6,740 against 4,724 for the stock gun (1.43×, inside the 1.5× budget).
- **Audit** (`out/Phantom_v04_views/audit.json`, ADS distance 0.42 from `Config/Weapons`):
  - 0 faults in new geometry. The only faults are the stock's own open islands, inherited unchanged: the buffer tube (`AR_StockFrame:0`) and the barrel stub (`AR_BarrelStub:0`).
  - 0 coplanar pairs.
  - Floating: only the stock charging handle. It rides 0.002 off its slot floor, as in the stock gun; the stock audit links it only because it passes through the stock handguard.
  - Bones, locators and actions are identical to the stock.
  - 0 animated intersections across Draw, Fire, Inspect, Reload and ReloadEmpty.
  - All 5 ADS rays are clear. The post ray hits only `Phantom_Sights`, and nothing new shows in the ADS render.
- **Flat export:** 0 coplanar lifts, 0 flipped islands, 0 crossed faces. The one-sided magenta re-import is clean (`out/Phantom_v04x_flat_check/`).
- **Review sheet:** [Phantom_v04_review.png](out/Phantom_v04_review.png)
- **Self-grade:** 9/10 (the gun's grade is its lowest area).

| Area | Grade |
|---|---|
| Silhouette | 9 |
| Crispness | 9 |
| Layering | 9 |
| Connections | 9 |
| ADS | 9 |
| Palette | 9 |
| Budget | 9 |
| Contract | 10 |

**For the owner**
- Three buttons fit; nothing sits on a moving bone.
- The stock receiver's rear-cap underside was lifted 0.004 in the master to clear the stock's one flush pair.
- In first person, the joystick ball slightly overlaps the cyan button, the same as the approved Havoc.
- Not installed: the Studio upload and install wait for your go.

## Spectre (Prowler)
Built 2026-11-27 from the [Gun Brief](Gun%20Brief.md), Blender only (live MCP, PID 40136 checked). Scripts: `12_spectre.py` (build), `21_review_spectre.py` (stations; the stock file has its own `Cam_Hip`), `sheet_spectre.json`. No shared script was changed.

**Stock measured** (ray-cast depth maps, both sides, and every clip swept):
- Upper receiver side face y .082 (z .277-.417) with the charging-handle slot (floor .068, x .16-.56, z .374-.404). The knob rests at x .59-.70 and never comes behind x .45; in Draw and the reloads it swings inward and forward to x .725.
- Lower receiver face .078 (x -.18 to .685, z .14-.265). The fire selector lever sweeps up to z .287 at x .13 and .294 at x .21 in Reload.
- A stock Neon square (x -.162 to -.095) sits in a shallow receiver pocket (z .288-.325).
- Right side: ejection port above z .36 (bolt back to x .107), mag release at x .39-.43.
- Handguard x .697-1.14, y .090, bottom .23, top .473; CharmLoop on its lower-left chamfer (x .784-.816); front sight base on top (x .969-1.064).
- Barrel stub r .065 (x 1.137-1.262), round can r .091 to x 1.904, Muzzle x 1.901. Stock frame face .066, butt pad x -.955 to -1.067. Magazine face .056 with a raked recessed panel (.052).
- ADS: adsDistance 0.37 (`Config/Weapons`), eye x -.5155, z .524; the game's adsFov is 72.

| Version | What changed |
|---|---|
| v01 | First build, 5,280 tris (1.56×). The audit found the charging handle running through the new handguard on every clip, 3 open edges at the handguard's rear (a 0.003 chamfer ring under a 0.004 bevel), and the stock fire selector's one flush pair. |
| v02 | Budget pass: deck, coin door and coin entries are front-chamfered slabs (their backs are buried, so the bevel there was wasted); tapered button collars and washer; a 4-ring joystick ball. The handguard starts at the receiver's front face (.697, as stock) with a knob slot in its rear-left and a hidden pocket for the handle's inward swing. The selector's flush Metal face is lifted 0.004 in the build. Audit clean, 5,009 tris. Review: the joystick ball and the deck light pipe showed in ADS. |
| v03 | Deck moved behind the handle slot, joystick far back and low so it falls below the ADS view at 72°; every deck part is under the receiver's top-left edge as seen from the eye ((.524 - z) > 1.325 y). A 72° ADS check showed the deck's top-rear corner (behind the receiver's end, nothing hides it). |
| v04 | Deck's top-rear corner raked away. Review: the stock Neon-square pocket showed as a dark slot under the deck. |
| v05 | Deck bottom lowered to .282 to cover the pocket, raked up ahead of x .10 to clear the selector lever. |
| **v06** | Stock-frame pixel trail reordered to grow away from the band, as on the Havoc and Spirit. **Candidate.** |

**What the Arcade Prowler has**
- **Control deck** (left, Root) on the upper receiver behind the handle slot, with a raked rear corner and a raked front: a joystick at the rear, three buttons (r .020 in r .026 collars, scaled down for the SMG) rising toward the muzzle (cyan, yellow, magenta), a pixel screen in a bezel, and a cyan light pipe on the deck's top edge over the screen.
- **Coin door** (right) on the lower receiver behind the mag release: two lilac coin entries with yellow lit slots and a magenta stripe.
- **Handguard** on the stock envelope with a raked cabinet nose under the barrel stub, recessed violet fields on both sides (pixel-stepped corner, magenta band, cyan line, starburst, pixel trail), a magenta T-molding trim along each lower chamfer ahead of the charm loop, and a slot where the charging-handle knob runs in.
- **Stock frame art**: raked band and line with a pixel trail on the top bar (the big first-person surface).
- **Cabinet butt** replacing the pad: raked marquee top with a cyan light, a stepped rear, and a recessed side-art field on both sides (starburst, band and line).
- **Suppressor**: an eight-sided stepped can (rear section, light-ring groove with the cyan ring, main can, stepped end cap, bore with the Muzzle locator).
- **Mag stripe**: magenta, bone `Mag`, raked along the magazine's front band between the recessed panel and the front edge, top at z -.07.
- All 12 `flat_group` names are on Root parts: `ARButton1-3`, `ARStickBall`, `ARScreen*`, `ARDeckLight`, `ARTrim`, `ARBrakeLight`. The screen pixel is 0.0085, the same as the Havoc and Spirit.

**v06 results**
- **Master:** `art-source/weapons/Skins/Arcade/Spectre/v06/Spectre_Arcade_v06.blend`. **Export:** `v06x/` (`Spectre_Arcade_RobloxFlat.fbx`, `manifest_flat.json`, 35 parts, all 12 AR groups as their own parts).
- **Triangles:** 5,003 against 3,389 for the stock gun (1.48×, inside the 1.5× budget).
- **Audit** (`out/Spectre_v06_views/audit.json`, ADS distance 0.37):
  - 0 faults in new geometry. The only faults are the stock's own open islands, inherited unchanged: the receiver's, sights', grip's, pins' and selector's, plus the dressed copies of the buffer mount (`AR_StockFrame:0`), barrel stub (`AR_BarrelStub:0`) and front-sight Neon strips (`AR_SightNeon:0-1`), with bounds identical to the stock's.
  - 0 coplanar pairs.
  - Floating: only the stock magazine group (it floats in the stock audit too); the mag stripes ride on it, buried 0.003 in its face.
  - Bones, locators and actions are identical to the stock.
  - 0 animated intersections across Draw, Fire, Inspect, Reload and ReloadEmpty.
  - All 5 ADS rays are clear. The post ray hits only `Spectre_Sights`. Nothing new shows in the ADS render at 68° or in an extra check at the game's 72° (16:9 and 21:9).
- **Flat export:** 0 coplanar lifts, 0 flipped islands, 0 crossed faces. The one-sided magenta re-import shows no holes (`out/Spectre_v06x_flat_check/`). Its volume test lists `SK_Mag_05`: the stock magazine's brass cartridge faces, which are open once split from their Metal faces and sit inside the magwell. The Slipframe Spectre r02x export lists the same part.
- **Review sheet:** [Spectre_v06_review.png](out/Spectre_v06_review.png)
- **Self-grade:** 9/10 (the gun's grade is its lowest area).

| Area | Grade |
|---|---|
| Silhouette | 9 |
| Crispness | 9 |
| Layering | 9 |
| Connections | 9 |
| ADS | 9 |
| Palette | 9 |
| Budget | 9 |
| Contract | 10 |

**For the owner**
- Three buttons fit (scaled down); nothing sits on a moving bone.
- The deck sits at the rear of the receiver, not centred: the handle slot takes the front half, and the ADS view rules out anything taller or further forward. The stock receiver's vertical panel line at x -.25 shows above and below the deck.
- The stock Neon square under the deck was removed (the front-sight Neon strips are kept). The stock fire selector's one flush face was lifted 0.004 in the master.
- Not installed: the Studio upload and install wait for your go.
