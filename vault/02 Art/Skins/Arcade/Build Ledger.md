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
