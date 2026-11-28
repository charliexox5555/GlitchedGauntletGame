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

### Gap sweep (2026-11-27): v08
The owner's "no gaps" sweep on v07: culled magenta close-ups of every join from both sides and below (`out/Vandal_v08_gapsweep/`), plus measured joins and a see-through silhouette check.
- **Gaps found:**
  - **the same trigger-area gap as the Bulldog:** the guard's front post stopped **0.010** under the lower receiver, with an 0.011 slot to the magwell lip in front of it, and the guard's rear bar ended 0.0034 short of the grip;
  - a see-through notch under the rail where the upper receiver's chamfer meets the front block;
  - the coin door's top stopped 0.003 under the stock right side box;
  - shallow joins: the buffer tube 0.004 in the rear cap; the gas tube 0.010 in the front sight block; the barrel 0.018 in the brake; the front sight tower 0.004 in its block; the rear sight post 0.004 in its base; the sling lug 0.010 and nose collar 0.015 in the handguard; the butt only 0.010 over the stock frame.
- **Fixed in `10_vandal.py`:** the guard post moves 0.031 forward into the magwell lip and 0.031 up into the receiver (top .185). The guard's rear runs to x .094. The rail spine starts at .775. The coin door's top runs 0.008 under the box. Tube, gas tube, barrel, sight feet, lug and collar are buried 0.02+ (hidden; the ADS ring and post are unchanged). Butt front at -1.078.
- **Checked, no gap:** the grip top, the magwell, the handguard to front block and its nose, the deck, the brake and the rail over the handguard (a dark reveal backed by the spine, as stock). The chamfer notches where stock blocks meet are outline notches.
- **v08 results:** master `art-source/weapons/Skins/Arcade/Vandal/v08/Vandal_Arcade_v08.blend`, export `v08x/` (38 parts). 6,977 tris (unchanged). Audit (ADS 0.36): the same 37 stock open islands as v07; 0 coplanar; floating only the stock charging handle; contract equal; 0 animated intersections; all 5 ADS rays clear (post ray: `Vandal_FrontSight` only). Flat export: 0 lifts, flips or crossed faces, clean one-sided re-import. Self-grade **9/10** (unchanged). [Review sheet](out/Vandal_v08_review.png)
- **Reinstall needed:** Studio still has the v07x install. v08x replaces it later: the guard, rail, coin door, butt, barrel and sight parts changed.

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

## Roster (2026-11-27): all 14 guns built in Blender, waiting to install
Every gun passed the [Gun Brief](Gun%20Brief.md) gates:
- 0 faults in new geometry and 0 coplanar pairs;
- no new floating parts;
- the gap sweep (culled magenta close-ups of every join, buried 0.02 or more);
- 0 animated intersections and the stock contract equal;
- a clear sight line;
- a clean flat export;
- at most 1.5× the stock triangles;
- a self-grade of 9/10.

Four guns were built in parallel in separate Blender instances (MCP 9876 and socket bridges 9881–9883). Guns built after the parallel switch keep their details in `ledger/<Gun>.md`. The Havoc v07x is the only gun in Studio so far; every other gun waits for the owner's "Studio is free".

| Gun (in game) | Final | Tris (stock) | Sheet | Notes |
|---|---|---|---|---|
| Vandal (Havoc) | v08 | 6,977 (5,171) | [sheet](out/Vandal_v08_review.png) | gap sweep fixed v07; **reinstall** over v07x |
| Phantom (Spirit) | v05 | 6,732 (4,724) | [sheet](out/Phantom_v05_review.png) | stepped suppressor can |
| Spectre (Prowler) | v07 | 5,003 (3,389) | [sheet](out/Spectre_v07_review.png) | deck behind the handle slot |
| Guardian (Marksman) | v03 | 5,950 (4,374) | [sheet](out/Guardian_v03_review.png) | rail riser fills the front-block slot |
| Bulldog (Lancer) | v03 | 5,422 (3,640) | [sheet](out/Bulldog_v03_review.png) | owner's trigger-front gap fixed; bullpup deck in the stock recess |
| Odin (Mauler) | v03 | 6,326 (4,528) | [sheet](out/Odin_v03_review.png) | **moved charm ring kept** (CharmLoop untouched) |
| Operator (Deadeye) | v03 | 6,938 (4,950) | [sheet](out/Operator_v03_review.png), [ledger](ledger/Operator.md) | scope untouched |
| Marshal (Scout) | v04 | 6,263 (4,407) | [sheet](out/Marshal_v04_review.png), [ledger](ledger/Marshal.md) | purple stock; low deck stays out of ADS |
| Bucky (Pump) | v02 | 4,316 (3,030) | [sheet](out/Bucky_v02_review.png), [ledger](ledger/Bucky.md) | new forend on the Pump bone |
| Stinger (Hornet) | v04 | 4,660 (3,134) | [sheet](out/Stinger_v04_review.png), [ledger](ledger/Stinger.md) | 11 stock joins buried |
| Classic | v03 | 3,476 (2,334) | [sheet](out/Classic_v03_review.png), [ledger](ledger/Classic.md) | **moved charm ring kept**; deck on the frame |
| Sheriff | v03 | 4,432 (3,066) | [sheet](out/Sheriff_v03_review.png), [ledger](ledger/Sheriff.md) | deck on the barrel and lug (the speedloader sweeps the frame) |
| Shorty | v03 | 3,802 (2,734) | [sheet](out/Shorty_v03_review.png), [ledger](ledger/Shorty.md) | **moved charm ring kept**; twin-bore muzzle block |
| Ghost (Hush) | v03 | 3,830 (2,964) | [sheet](out/Ghost_v03_review.png), [ledger](ledger/Ghost.md) | pixel ghost swapped for the line's star and trail |

**Installed (2026-11-27, place 71551303511506):**
- **Assets and rows:** all 14 are in `ServerStorage.WeaponSkins.Arcade`, tagged with LobbySkins AssetData rows 265 (Vandal, now v08x) and 266–278.
- **Asset ids** (group models):

| Gun | Asset | Gun | Asset |
|---|---|---|---|
| Vandal | 76510125410456 | Phantom | 140711719229902 |
| Spectre | 117022017898506 | Guardian | 118478035525752 |
| Bulldog | 125698388063660 | Odin | 86448263980386 |
| Operator | 128517010185291 | Marshal | 130992152671215 |
| Bucky | 131828992394762 | Stinger | 93826700988080 |
| Classic | 80931021686474 | Sheriff | 78921864577029 |
| Shorty | 83929323541644 | Ghost | 129632228652851 |

- **Kept stock parts:** the Odin, Classic and Shorty keep the owner's moved `CharmLoop` parts. The scoped guns keep their `ScopeLens`. The Bulldog keeps its Studio-only `GG_Bulldog_FrontSightSeat`.
- **Effects:** `Config/Arcade` has a profile for every gun (each gun's screen pixel size).
- **Tests** (Studio Play):
  - `SkinStore.has` holds on all 14.
  - The Locker lists Arcade on all 14.
  - No Arcade pair is in the case pools.
  - In the Range, both the Hornet and the Classic load all 12 AR parts and 5 motors, and the buttons cycle on shots; the Classic inspect was checked on screen.
  - No console errors.

**Install steps (for reference):**
1. **Upload and install.** Upload each `vNNx/<Gun>_Arcade_RobloxFlat.fbx`. Run `make_flat_install_jobs.py --version vNNx` per gun (versions differ, so one job file per version) and run `InstallFlatSkin`.
2. **Move and tag.** Move each model to `ServerStorage.WeaponSkins.Arcade`, add a `LobbySkins` AssetData row, and tag it.
3. **Effects.** Add a `Config/Arcade` profile per gun. The flat_group names are the same, so the profile entry is copied from the Vandal (check `pixel` and `bone`).
4. **Test** in the Locker and the Range.

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

### Gap sweep (2026-11-27): v05
The owner's "no gaps" sweep on v04: culled magenta close-ups of every join from both sides and below (`out/Phantom_v05_gapsweep/`), plus measured joins and a see-through silhouette check.
- **Gaps found (all stock except the rail tip):**
  - the trigger guard's rear bar ended **0.015** short of the grip; its front post only reached the receiver's underside (0.002), and the grip's top sat exactly on it;
  - the rail's tip hung over the handguard's tapered nose: a daylight wedge up to 0.02;
  - the front sight base floated **0.012** over the rail on its clamp, with hairline slots at both ends; its hood and blade sat 0.002-0.005 in the base, the rear sight block 0.004 and its base 0.006;
  - the barrel stub sat 0.002 in the nose cap; the buffer tube and castle ring 0.008 / 0.014 in the rear cap; the butt 0.018 over the frame, with a sliver under the lower brace.
- **Fixed in `11_phantom.py`:** guard bar to x .145 and post top to .184 (0.02+ in), grip top raised 0.02. The handguard nose keeps its top (.431) to x 1.626, 0.007 past the rail end, then steps down to the cap. Sight feet buried 0.02 (hidden; the rear ring and front hood above the bases are unchanged). Stub rear to 1.615, tube front to -.150, ring 0.007 forward, butt front at -0.950.
- **Checked, no gap:** the magwell and its rib notches, the coin door and deck, the handguard to receiver collar, the can mount, the charm loop. The rear ring stands on its block as stock. The pins 0.006 ahead of the deck's front are a spacing, not a join.
- **v05 results:** master `art-source/weapons/Skins/Arcade/Phantom/v05/Phantom_Arcade_v05.blend`, export `v05x/` (36 parts). 6,732 tris (1.43x). Audit (ADS 0.42): the same stock-only open islands as v04; 0 coplanar; floating only the stock charging handle; contract equal; 0 animated intersections; all 5 ADS rays clear (post ray: `Phantom_Sights` only). Flat export: 0 lifts, flips or crossed faces, clean one-sided re-import. Self-grade **9/10** (unchanged). [Review sheet](out/Phantom_v05_review.png)

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

### Gap sweep (2026-11-27): v07
The owner's "no gaps" sweep on v06: culled magenta close-ups of every join from both sides and below (`out/Spectre_v07_gapsweep/`), plus measured joins and a see-through silhouette check.
- **Gaps found (all stock):**
  - lower receiver to handguard: the lower receiver stops at x .683, the handguard started at .697, leaving a **0.014** see-through slot under the upper receiver;
  - a daylight notch under the rail base at the upper receiver's chamfered front-top corner, and a 0.003 hairline between the upper receiver's front face and the handguard;
  - the grip's front-top corner stood **0.004** off the trigger guard's rear member, and its open top was only 0.0036 into the receiver;
  - the buffer mount sat 0.008 in the receiver and the barrel stub 0.009 in the handguard nose;
  - the front sight base and post sat 0.003-0.004 deep, and the hood wings' outer feet hung 0.006 over the handguard; the rear sight post was 0.013 in the receiver.
- **Fixed in `12_spectre.py`:** the handguard now starts at x .650, a sleeve 0.047 over the upper and 0.033 over the lower receiver. The knob slot and pocket start at .637. The last rail tooth and the two pins beside it run 0.004 into the sleeve's wall. The grip's top rises 0.02 and its front-top corner runs 0.022 into the guard member. Mount front to -.308, stub rear to 1.107, sight feet buried 0.02 (hidden), wing feet reach the handguard.
- **Checked, no gap:** the trigger guard (one piece with the lower receiver), the magwell, the coin door and deck, the butt, the handguard nose, the can mount. The wedge under the grip-to-guard contact and the stock frame's window corners are outline notches.
- **v07 results:** master `art-source/weapons/Skins/Arcade/Spectre/v07/Spectre_Arcade_v07.blend`, export `v07x/` (35 parts). 5,003 tris (1.48x). Audit (ADS 0.37): the same stock-only open islands as v06; 0 coplanar; floating only the stock magazine group, as before; contract equal; 0 animated intersections (the knob runs clear in the longer slot); all 5 ADS rays clear (post ray: `Spectre_Sights` only). Flat export: 0 lifts, flips or crossed faces; clean re-import, with the same `SK_Mag_05` cartridge note as v06. Self-grade **9/10** (unchanged). [Review sheet](out/Spectre_v07_review.png)

## Guardian (Marksman)
Built 2026-11-27 from the [Gun Brief](Gun%20Brief.md), Blender only (live MCP, PID 40136 checked). Scripts: `13_guardian.py` (build), `21_review_guardian.py` (stations; the stock file has its own `Cam_Hip`), `sheet_guardian.json`. No shared script was changed.

**Stock measured** (ray-cast depth maps, both sides, and every clip swept relative to Root):
- Upper receiver side face y .086 (x -.013 to .89, z .2336-.416), panel lines at x .10 and .83, and the charging channel on the left (floor .070, x .30-.79, z .326-.366). The handle knob (y .112-.136, z .318-.375) rests at x .688-.767 and comes back to x .48 in Draw. A stock Neon strip sat at x .353-.557, z .282-.296.
- Lower receiver face .080 with a side recess (floor .075, x -.05 to .14, z .15-.215) on both sides. Left: the fire selector (x .09-.173, up to z .243 in Draw) and the bolt catch (x .404-.47, top .235). Right: the ejection port above z .268; the bolt runs back to x .193. Pins at x .21/.37, z .19 on both sides.
- Front block x .877-1.136 (y .092). Handguard x 1.123-2.355 (y .088, bottom .189, keel .223, shoulder .41, top .432) with two rows of six round-ended slots; CharmLoop on its rear lower-left (x 1.165-1.197, z .206-.248); front sight on the rail at x 2.214-2.301. The rail base's front face shares the handguard's front plane (x 2.355): the stock's one coplanar pair.
- Barrel r .04 (12 facets) x 2.34-2.79; round-ported brake r .058 x 2.78-2.998; Muzzle x 2.9984. Stock body face .070, cheek riser x -.553/-.98, butt pad x -1.08/-1.245. Magazine face .060 below its PANEL band.
- No scope: open hex ring and hooded post (`Guardian_Sights`). ADS: adsDistance 0.33 (`Config/Weapons`), adsFov 58, eye x -.275, z .4984.

| Version | What changed |
|---|---|
| v01 | First build, 5,934 tris (1.36×). Audit: 0 faults in new geometry, 0 floating, contract equal, 0 animated intersections, ADS rays clear. One coplanar pair: the new handguard's front face on the rail base's front face (x 2.355), inherited from the stock layout. Review: the joystick ball overlaps the cyan button in first person. |
| **v02** | Handguard nose extended to x 2.362 (0.007 past the rail end); buttons moved 0.002-0.006 forward, away from the joystick. Audit clean. **Candidate.** |

**What the Arcade Marksman has**
- **Control deck** (left, Root): a long, low panel on the upper receiver under the charging channel (x .20-.70, z .24-.316, raked ends), ahead of the fire selector and above the bolt catch. Rear to front: a joystick, three buttons in collars rising toward the muzzle (cyan, yellow, magenta; r .020 in r .026 collars, as the Prowler), a pixel screen in a bezel, and a cyan light pipe on the deck's top edge over the screen (it sits between the deck top and the channel). It covers the stock Neon strip, which was removed.
- **Coin door** (right) on the lower receiver over the stock side recess, behind the magwell: two lilac coin entries with yellow lit slots and a magenta stripe. The two right-side pins it covers were removed.
- **Handguard** on the stock envelope: three-by-two faceted vents (pointed ends) behind the support hand keep the Marksman's read; a recessed violet field ahead of it on both sides (pixel-stepped corner, magenta band, cyan line, starburst, pixel trail); a magenta T-molding trim along each lower chamfer from just ahead of the charm loop; a raked cabinet nose under the barrel.
- **Stock frame art**: raked band and line with a pixel trail on the top bar ahead of the window (the first-person side).
- **Cabinet butt** replacing the pad: raked marquee top with a cyan light, a stepped rear, and a recessed side-art field on both sides (starburst, band and line). It swallows the body's rear member by 0.03.
- **Brake**: an eight-sided stepped brake (rear collar, light-ring groove with the cyan ring, a ported main section with two faceted through-ports per side, a stepped nose and a bore with the Muzzle locator).
- **Mag stripe**: magenta, bone `Mag`, raked on the plain lower face between the PANEL band and the base plate (top z -.082), far below the magwell.
- All 12 `flat_group` names are on Root parts: `ARButton1-3`, `ARStickBall`, `ARScreen*`, `ARDeckLight`, `ARTrim`, `ARBrakeLight`. The screen pixel is 0.0085, as on the other guns.

**v02 results**
- **Master:** `art-source/weapons/Skins/Arcade/Guardian/v02/Guardian_Arcade_v02.blend`. **Export:** `v02x/` (`Guardian_Arcade_RobloxFlat.fbx`, `manifest_flat.json`, 36 parts, all 12 AR groups as their own parts, the sights as `SK_Root_Sight_*`).
- **Triangles:** 5,934 against 4,374 for the stock gun (1.36×, inside the 1.5× budget).
- **Audit** (`out/Guardian_v02_views/audit.json`, ADS distance 0.33):
  - 0 faults in new geometry. The only faults are the stock's own open islands, inherited unchanged: receiver, rail teeth, sights, grip, pins, bolt catch and selector, plus the dressed copies of the stock tube and ring (`AR_StockFrame:0-1`) and the barrel tube (`AR_BarrelTube:0`), with bounds identical to the stock's.
  - 0 coplanar pairs (the stock's one pair is gone).
  - 0 floating parts.
  - Bones, locators and actions are identical to the stock.
  - 0 animated intersections across Draw, Fire, Inspect, Reload and ReloadEmpty.
  - All 5 ADS rays are clear. The post ray hits only `Guardian_Sights`. Nothing new shows in the ADS render at 68°, at the game's 58°, or in an extra check at 72° (16:9 and 21:9): the receiver's rear end hides the joystick.
- **Flat export:** 0 coplanar lifts, 0 flipped islands, 0 crossed faces. The one-sided magenta re-import shows no holes (`out/Guardian_v02x_flat_check/`); the magenta seen through the brake is its through-ports, as on the stock brake.
- **Review sheet:** [Guardian_v02_review.png](out/Guardian_v02_review.png)
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
- The deck is long and low (under the charging channel), not a tall plate: the channel and the knob take the receiver's upper half, and a taller deck would show in ADS. Its ends leave the stock panel lines at x .10 and .83 showing.
- The stock receiver Neon strip under the deck and the two right-side lower pins under the coin door were removed.
- The stock handguard's round-ended slots are kept as faceted vents (three by two, behind the support hand) rather than replaced by a second art field.
- In first person the joystick ball still slightly overlaps the cyan button, as on the approved Havoc and Spirit.
- Not installed: the Studio upload and install wait for your go.

### Gap sweep (2026-11-27): v03
The owner's "no gaps" sweep on v02: culled magenta close-ups of every join from both sides and below (`out/Guardian_v03_gapsweep/`), plus measured joins (island near-misses, air between facing surfaces, how deep each end sits) and a see-through silhouette check.
- **Gaps found (all stock):**
  - the rail bridged **0.020** over the front block (top .394), from the receiver (x .89) to the handguard: a see-through slot under the rail;
  - the front sight base sat only 0.002 on the rail, its post 0.004 in the base; the rear sight base 0.006 in the receiver;
  - the castle ring and buffer tube sat 0.010 / 0.007 in the receiver's rear; the barrel 0.020 in the brake collar;
  - the handguard ran 0.013 over the front block; the butt 0.018 over the stock's rear member.
- **Fixed in `13_guardian.py`:** a dark `AR_RailRiser` (y ±.022, under the ±.03 rail) carries the rail, 0.02 into the block, rail, receiver and handguard. Sight feet buried 0.02 (hidden; the ADS ring, hood and post above the base are unchanged). Ring forward 0.012, tube to x .010, barrel end to 2.800. Handguard from x 1.115, butt front at -1.045.
- **Checked, no gap:** the trigger guard and grip (one piece with the receiver; the grip is 0.03+ into it), the magwell, the coin door and deck edges, the handguard nose and the brake. The chamfer notches where stock blocks meet and the stock frame's window corners are outline notches, not gaps.
- **v03 results:** master `art-source/weapons/Skins/Arcade/Guardian/v03/Guardian_Arcade_v03.blend`, export `v03x/` (36 parts). 5,950 tris (1.36x). Audit (ADS 0.33): the same stock-only open islands as v02, 0 coplanar, 0 floating, contract equal, 0 animated intersections, all 5 ADS rays clear (post ray: `Guardian_Sights` only). Flat export: 0 lifts, flips or crossed faces, clean one-sided re-import. Self-grade **9/10** (unchanged). [Review sheet](out/Guardian_v03_review.png)

## Bulldog (Lancer)
Built 2026-11-27 from the [Gun Brief](Gun%20Brief.md), Blender only (live MCP, PID 40136 checked). Scripts: `14_bulldog.py` (build), `21_review_bulldog.py` (stations; the stock file has its own `Cam_Hip`), `sheet_bulldog.json`. No shared script was changed.

**Stock measured** (ray-cast depth maps, both sides, and every clip swept relative to Root):
- A bullpup: the stock body (one closed island) runs x -1.227/-.473, side face y .088, top .476 falling to .43 at the rear, bottom -.134. It has a side recess on both sides (floor .083, x -1.05/-.524, z .28-.41, raked front edge) and a sling slot through it at x -1.21/-1.185. The magwell is a separate open island; the butt pad is x -1.459/-1.219.
- Receiver: upper face y .084 (top .476), lower face .080, a violet panel with two Neon bars at x -.159/.044. A side box (x .343-.611, y .092, bottom .177) carries the CharmLoop on its lower left. The charging-handle knob (left, z .372-.435) runs back to x .20 in Draw. The bolt runs back inside the stock body to x -.568.
- Handguard x .575-1.074 (y .086, bottom .156, keel .186, top .291 under the receiver). Barrel r .034 to x 1.255, round ported brake to 1.438, Muzzle x 1.4378. Magazine face y .056 with five grooves (.052).
- ADS: adsDistance .38, adsFov 68 (`Config/Weapons`); eye x -.6726, z .5838. The whole stock-body recess is behind or beside the eye. `Cam_Hip` sees the stock body ahead of x -.80.

| Version | What changed |
|---|---|
| v01 | First build, 5,710 tris (1.57x). The audit listed the magazine and bolt crossing the stock body on every clip (stock behaviour, but the body was a renamed `AR_` copy), the two stock handguard pins floating over the new handguard field, and the stock's one flush pair (a Bolt face on the Receiver). |
| v02 | The stock body and magwell stay in place under their stock name (pad removed), so only new geometry is checked against the moving parts. Handguard pins removed; the Bolt's flush face lifted 0.004 in the build. Budget pass: the butt gets a flat 0.006 side chamfer instead of a bevel modifier, no speaker grille, no coin-return pocket, one step less on the brake nose. Audit clean, 5,414 tris. Review: the joystick ball sat close to the cyan button. |
| **v03** | **Owner note: "a gap in the trigger area that meets the body at the front".** A culled magenta sweep of every join found three stock gaps, all fixed: the trigger guard's front post stopped 0.013 under the side box (now 0.024 into it); the front sight base floated 0.011 over the rail and 0.027 over the receiver top (its foot now runs straight down 0.02 into the receiver; the part the ADS eye sees, above the rail teeth, is unchanged); the barrel tube ran only 0.015 into the receiver (now 0.035). The cabinet butt's foot now rakes forward under the body's chamfered lower-rear corner, which had left a notch. Joystick and buttons spaced 0.004-0.005 further apart; coin door made shorter. **Candidate.** |

**What the Arcade Lancer has**
- **Control deck** (left, Root): a raised plate in the stock body's side recess, 0.008 inside its walls so a dark reveal runs round it. Rear to front: a joystick, three buttons rising toward the muzzle (cyan, yellow, magenta; Havoc size, r .022 in r .028 collars), and the pixel screen at the front, where the held camera sees it, with a cyan light pipe along the deck's top edge over the screen.
- **Stock side art:** a violet field with a pixel-stepped corner cut into the right recess (a dark reveal round it), and a big field cut into the plain lower body on the left, under the deck. Each has a raked magenta band, a cyan line, a yellow starburst and a pixel trail.
- **Coin door** (right) on the lower stock body behind the magwell: two lilac coin entries with yellow lit slots and a magenta stripe.
- **Handguard** on the stock envelope:
  - the top tucks in and runs 0.015 up into the receiver, and the rear is buried in the side box;
  - a raked cabinet nose;
  - a recessed violet field on both sides (pixel-stepped corner, band, line, starburst, pixel trail);
  - a magenta T-molding trim along each lower chamfer, ahead of the charm loop.
- **Cabinet butt** replacing the pad: a raked marquee hood with a cyan light on both sides, a stepped rear, and a foot that rakes forward under the body's corner. It swallows the body's rear end and the sling slot.
- **Brake:** eight-sided and stepped (rear collar, light-ring groove with the cyan ring, a ported main section with two faceted through-ports per side, a stepped nose, a bore with the Muzzle locator).
- **Mag stripe:** magenta, bone `Mag`, raked across the ribbed face (top z -.012, far below the magwell).
- All 12 `flat_group` names are on Root parts: `ARButton1-3`, `ARStickBall`, `ARScreen*`, `ARDeckLight`, `ARTrim`, `ARBrakeLight`. The screen pixel is 0.0085, as on the other guns.

**v03 results**
- **Master:** `art-source/weapons/Skins/Arcade/Bulldog/v03/Bulldog_Arcade_v03.blend`. **Export:** `v03x/` (`Bulldog_Arcade_RobloxFlat.fbx`, `manifest_flat.json`, 35 parts, all 12 AR groups as their own parts, the sights as `SK_Root_Sight_*`).
- **Triangles:** 5,422 against 3,640 for the stock gun (1.49x, inside the 1.5x budget).
- **Audit** (`out/Bulldog_v03_views/audit.json`, ADS distance 0.38):
  - 0 faults in new geometry. The only faults are the stock's own open islands, inherited with the same open edges: receiver, Neon bars, sights, grip, pins, selector and magwell. Two of them moved but keep their topology: the trigger guard (its open edges are at its rear top, buried in the receiver) and the barrel tube copy `AR_BarrelTube:0` (open ends buried in the receiver and the brake).
  - 0 coplanar pairs (the stock's one pair is gone).
  - 0 floating parts. The stock floats its front sight assembly; it is now seated.
  - Bones, locators and actions are identical to the stock.
  - 0 animated intersections across Draw, Fire, Inspect, Reload and ReloadEmpty.
  - All 5 ADS rays are clear. The post ray hits only `Bulldog_Sights`. Nothing new shows in the ADS render at 68 degrees (the game's adsFov), in 16:9 or 21:9.
- **Gap check:** culled magenta close-ups found no gaps left at any of these joins:
  - the trigger guard (both sides and from below) and the grip;
  - the front sight;
  - the receiver-to-stock seam, the magwell and the charging handle;
  - the handguard to the side box, and the handguard nose;
  - the barrel, the brake and the butt join.
- **Flat export:** 0 coplanar lifts, 0 flipped islands, 0 crossed faces. The one-sided magenta re-import shows no holes (`out/Bulldog_v03x_flat_check/`).
- **Review sheet:** [Bulldog_v03_review.png](out/Bulldog_v03_review.png)
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
- Three buttons fit (Havoc size); nothing sits on a moving bone.
- The deck sits in the bullpup's stock recess, the gun's big first-person surface. The held camera shows the screen and light pipe large, with the magenta button at the edge. The joystick and the other two buttons are behind the view; they show in third person and Inspect.
- Stock geometry changed to close gaps: the trigger guard's front post, the front sight base's foot (hidden from the ADS eye) and the barrel tube's rear end.
- Four stock pins were removed: the two at the lower rear of the stock (under the new art and the coin door) and the two on the handguard. The Bolt's flush face was lifted 0.004 in the master.
- The butt is plain apart from the marquee: the speaker grille was cut to stay inside the triangle budget.
- Not installed: the Studio upload and install wait for your go.

## Odin (Mauler)
Built 2026-11-27 from the [Gun Brief](Gun%20Brief.md), Blender only (live MCP on 9876, PID 40136 checked). Scripts: `15_odin.py` (build; `DRY=True` builds without saving), `21_review_odin.py` (stations; the stock file has no `Cam_Hip`, so it passes `HIP`), `sheet_odin.json`. No shared script was changed.

**Stock measured** (ray-cast depth maps, both sides, and every clip swept relative to Root):
- Main receiver (closed) x -.168/.788, left face y .100 (z .166-.546), a panel-line groove at z .414-.424 and a top groove at .492-.518. Charging slot (left) x -.116/.35, z .306-.364; the knob (y to .158) runs back to x -.07 in Draw. Ejection port (right) x .34-.59.
- Feed section (closed) x .788-1.452, z .133-.49, with the belt window on the left (x .79-1.06). Stock side plates (x 1.102-1.855, y .114) with Neon chevrons. Handguard (closed) x 1.44-2.272, face .100, a 45 degree lower chamfer (.175-.196), a dark pocket x 1.856-2.10. CharmLoop (stock position) x 2.119-2.151, z .178-.22.
- Barrel r .08 at z .371 to x 3.03; front sight block x 2.349-2.496; muzzle device x 3.027-3.364 (Muzzle 3.3635). Stock body face .072, its top bar falling from z .45 (x -.38) to .395 (x -.89) over a through-window; butt pad x -1.2425/-.9625.
- Ammo box (bone `AmmoBox`) x .577-1.312, y .156 with recessed X panels (.148), lid to z .122, handle (left) y to .173. In the reloads it drops straight down (pitch up to 4 degrees) and overshoots +.007 on the way back; the belt reaches y .104. The feed cover opens 77 degrees.
- ADS: adsDistance .39, adsFov 70 (`Config/Weapons`); eye x -.4665, z .6503 (= `Odin_FP_ADS`). The hip camera is the Havoc's Cam_Hip at the same offset from the AimPoint, raised 0.034/0.8 for the Odin's lower `viewmodelOffset` (RIFLE_VM).
- Stock 4,528 tris, so the budget is 6,792.

| Version | What changed |
|---|---|
| v01 | First build, 6,350 tris. The main receiver was copied out as `AR_Receiver` for the deck-seat cut, so the audit counted the stock bolt, trigger, handle and feed cover touching it on every clip (stock behaviour). The screen invader had cells meeting at a corner (4 non-manifold edges), and the stock's flush pairs (belt links, feed cover) remained. |
| v02 | The main receiver keeps its stock name (the seat is cut into `Odin_Receiver`; its open stock islands come through unchanged). Invader redrawn; the belt and feed cover flush faces lifted 0.004 in the build; the rear cap's front set to -.147 so it clears the deck seat. Audit clean, 6,326 tris. Review: the stock-frame band and line ran 0.015 over the stock's falling top edge. |
| **v03** | Stock-frame art moved inside the bar (0.018+ from its top and the window). **Candidate.** |

**What the Arcade Mauler has**
- **Control deck** (left, Root): an L-shaped plate in a seat cut 0.012 into the receiver's left face, 0.008 inside the seat walls so a dark reveal runs round it. A strip over the charging slot carries the joystick and three buttons rising toward the muzzle (cyan, yellow, magenta; Havoc size, r .022 in r .028 collars), where the held camera sees them large. Ahead of it, a screen block whose rear edge rakes down clear of the slot holds a big pixel screen (ship and shot low left, a cyan invader as the blip, three yellow stars) with a cyan light pipe over it.
- **Coin door** (right) on the feed section: two lilac coin entries with yellow lit slots and a magenta stripe.
- **Handguard** (`AR_Handguard`, the stock handguard copied out for the cuts): a recessed violet field on both sides (pixel-stepped rear corner, a raked front corner that keeps clear of the stock charm loop; magenta band, cyan line, starburst, pixel trail). The field swallows the stock dark pocket. A magenta T-molding trim is half-buried along each 45 degree lower chamfer.
- **Ammo box** (bone `AmmoBox`): a violet field plate over each recessed side panel (pixel-stepped corner; the stock handle stands through it) with the band (the "mag stripe"), line, starburst and pixel trail below the handle. A dark flange stands on the lid 0.008 outside the receiver's sides (plus a rear wall), so the stock box-to-gun running clearance no longer shows from the side.
- **Stock frame art**: raked band and line with a pixel trail on the top bar, both sides.
- **Cabinet butt** replacing the pad: a raked marquee top with a cyan light in a seat on both sides, a stepped rear, swallowing the stock body's rear end by 0.047.
- **Brake**: eight-sided and stepped (rear collar 0.025 over the barrel, light-ring groove with the cyan ring, a ported main section with two faceted through-ports per side, a stepped nose, a bore with the Muzzle locator).
- All 12 `flat_group` names are on Root parts: `ARButton1-3`, `ARStickBall`, `ARScreen*`, `ARDeckLight`, `ARTrim`, `ARBrakeLight`. The screen pixel is 0.0085, as on the other guns.

**Moved charm point (owner, 2026-11-27).** The stock `CharmLoop` is **not dressed or hidden**: it keeps its stock materials, so the export lists it under `untouched_stock` (the only entry) and the Studio install keeps the owner's moved ring. Blender's `CharmPoint` locator stays at its v05 position (contract equal). Every new Root part is at least **0.23** from the moved point (1.18, 0.126, 0.435), measured to a 0.09 sphere plus the column below it: the deck ends at x .76 and the handguard fields start at x 1.48, so the left feed section under the point is plain stock body. The fields also stop short of the stock loop's Blender position.

**Gap sweep (2026-11-27).** Culled magenta close-ups of every join from both sides and below (the `culled_*` stations in `out/Odin_v03_views/`), plus measured joins (island near-misses and overlap depths) and a see-through check. Stock joins fixed in `15_odin.py`, each now 0.02+ deep:
- the trigger guard sat **0.003** into the receiver's underside (now 0.023); the grip top 0.007 (0.027);
- the feed section only touched the main receiver (0.000; now 0.02 in), and the handguard ran 0.012 over the feed section (0.032);
- the rail sat 0.001 on the receiver top and its teeth 0.001 on the rail (now 0.021 / 0.02); the rear sight ring's feet 0.007 (0.027);
- the rear cap 0.011 over the receiver (0.021); the stock adapter 0.007 in the stock body and in the rear cap (0.027 / 0.030); the cap's Neon squares 0.0005 off their pocket floor (backs 0.0075 in);
- the barrel 0.012 in the handguard (0.032); the barrel ring only touched the front sight block (0.02 in); the front sight base 0.002 on the block, its hood 0.002 and post 0.003 in the base (0.02 deeper, hidden; what the ADS eye sees is unchanged); the post's Neon dot 0.001 on the post (0.007);
- the lug under the handguard 0.004 (0.024); all retained pins 0.003 in their faces (0.023).
- **Checked, no gap:** the deck, coin door and art seats (measured: every plate's back is buried 0.002-0.014 and nothing overhangs), the butt join, the brake mount, the box field and handle, the feed cover and charging handle (moving, as stock), the ejection-port trim on the right.
- **Moving-part clearance kept:** the ammo box hangs 0.011 under the feed section and 0.035 under the main receiver, and rises 0.007 in the reload, so it cannot be buried. The box-borne flange hides that slot from both sides; seen straight from ahead or behind under the gun it is a dark shadow line.

**v03 results**
- **Master:** `art-source/weapons/Skins/Arcade/Odin/v03/Odin_Arcade_v03.blend`. **Export:** `v03x/` (`Odin_Arcade_RobloxFlat.fbx`, `manifest_flat.json`, 41 parts, all 12 AR groups as their own parts, the sights as `SK_Root_Sight_*`, `untouched_stock: ["CharmLoop"]`).
- **Triangles:** 6,326 against 4,528 for the stock gun (1.40x, inside the 1.5x budget).
- **Audit** (`out/Odin_v03_views/audit.json`, ADS distance 0.39):
  - 0 faults in new geometry. The 18 faults are the stock's own open islands with the same open-edge counts (Neon squares, lug, rear cap, trigger guard, ejection trim, rail, barrel tube, front sight parts, grip, adapter, pins); some moved for the gap fixes but keep their topology.
  - 0 coplanar pairs (the stock's three are gone: two lifted, the butt pad's removed).
  - Floating: only the stock ammo box group (it floats in the stock audit too, on its running clearance) and the new box parts riding on it, buried 0.002-0.010 in its faces, as the Prowler's mag stripes ride its floating magazine.
  - Bones, locators and actions are identical to the stock.
  - 0 animated intersections across Draw, Fire, Inspect, Reload and ReloadEmpty.
  - All 5 ADS rays are clear. The post ray hits only `Odin_Sights`. Nothing new shows in the ADS render at 68 degrees or in a check at the game's 70 degrees: the rear cap hides the joystick.
- **Flat export:** 0 coplanar lifts, 0 flipped islands, 0 crossed faces. The one-sided magenta re-import shows no holes (`out/Odin_v03x_flat_check/`); the magenta seen through the brake is its through-ports.
- **Review sheet:** [Odin_v03_review.png](out/Odin_v03_review.png)
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
- Three buttons fit (Havoc size); nothing sits on a moving bone. The deck is L-shaped: the buttons and joystick ride a strip over the charging slot (the big near surface in first person) and the screen sits ahead of it, rather than one rectangular plate.
- The ammo box carries side art and a flange on its own bone. It never touches the gun (stock running clearance), so the audit lists it as floating, as the stock does.
- `CharmLoop` is unskinned and every Arcade part keeps clear of the moved charm point; the plain left feed section under it is stock body in Arcade purple.
- Stock geometry changed to close gaps (listed above). Removed: the two side plates with their Neon chevrons, the left pin under the deck, the muzzle device and the butt pad. The belt's and feed cover's flush faces were lifted 0.004.
- Not installed: the Studio upload and install wait for your go.
