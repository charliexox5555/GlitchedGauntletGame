# Arcade line: per-gun Blender brief

2026-11-27. How to build one more Arcade gun to the Havoc's standard. The owner approved the Arcade Havoc v07 (look, sounds and effects) and asked for the other 13 guns, **one at a time, Blender only**. **Don't touch Studio, upload or install anything:** another session owns Studio, and installs wait for the owner's go. Read the [Build Ledger](Build%20Ledger.md) (Havoc v01–v07, palette, scripts, results) first.

## Guns and order
Primaries:
1. Phantom (Spirit)
2. Spectre (Prowler)
3. Guardian (Marksman)
4. Bulldog (Lancer)
5. Odin (Mauler)
6. Operator (Deadeye)
7. Marshal (Scout)
8. Bucky (Pump)
9. Stinger (Hornet)

Secondaries:

10. Classic
11. Sheriff
12. Shorty
13. Ghost (Hush)

The in-game names are in `src/shared/Config/Weapons.luau`.

## Before modelling
- Load the skills `gauntlet-vault`, `gauntlet-build-style` and `gauntlet-model-joins` (mandatory), then `blender-director`.
- Read [Skin Build Pitfalls](../Skin%20Build%20Pitfalls.md). Its checks are the gate.
- **Blender:** the live Blender MCP on 127.0.0.1:9876 (confirm with an `os.getpid()` probe and `bpy.data.filepath`). Never use background Blender for models. Only one session drives this Blender at a time.

## Method (the same scripts as the Havoc)
1. **Measure the stock gun.** Open `art-source/weapons/RemasterV2/<Gun>/<Gun>_RemasterV2_v05.blend` (discard any unsaved scratch). List objects, islands, bones, locators and actions. Ray-cast depth maps of both sides. Render the stock `Cam_Side`, `Cam_Hip` and `Cam_ADS` to the scratchpad.
2. **Build.** Write `tools/blender/arcade/<NN>_<gun>.py` (copy the pattern of `10_vandal.py`; shared kit `arcade_lib.py`). It builds on the stock file and saves `art-source/weapons/Skins/Arcade/<Gun>/vNN/<Gun>_Arcade_vNN.blend`. Run it with `exec(..., {"VERSION": "vNN"})`. **One .blend per version; never overwrite.**
3. **Audit.** Run `49_audit.py` with `{"ADS_DISTANCE": <Config/Weapons adsDistance, or None for a gun with no ADS>}` in the exec globals. Its output is `vault/02 Art/Skins/Arcade/out/<Gun>_vNN_views/audit.json`.
4. **Review.** Write `21_review_<gun>.py` with your own `CENTER`, `WIDTH`, `ADS_DISTANCE` and `STATIONS` (a close-up of every new join and detail). Add `FINISH_EXTRA` for the best 4–5 close-ups. It runs `20_review.py`.
5. **Look** at the finish hero, first person, ADS and the close-up and culled montages. Fix and rebuild as a new version. Repeat until the self-grade is **9+**.
6. **Export.** Run `53_export.py` (it makes `vNNx/`, the flat FBX, the manifest, and the one-sided magenta re-import check).
7. **Sheet.** Write `tools/blender/arcade/sheet_<gun>.json` (up to 8 `[capture file, label]` close-ups), then run `python tools/blender/arcade/30_sheet.py <Gun> vNN <InGameName>`.

## The Arcade look (the line language, from the Havoc)
- **Palette:** the AR roles in `arcade_lib.PALETTE` and the ledger. Body is deep purple, side-art fields violet. The neon is magenta, cyan and small touches of yellow. Buttons are cyan, yellow and magenta plastic. The screen is a glowing dark blue. Never use Glass.
- **Rare = shape change:** each gun keeps its stock silhouette and changes shape in parts. The signature parts:
  - **Control deck** on the player-facing side (+Y, the left side; check the stock `Cam_Hip` to see what the player sees). It is a raised plate seated in a stock recess or panel. On it: a **joystick** (washer, shaft, faceted ball) at the rear, **three faceted buttons in collars** rising toward the muzzle (rear to front: cyan, yellow, magenta), and a **pixel screen** in a bezel (cyan ship, magenta shot, yellow stars, cyan blip). A **cyan light pipe** runs along the deck's top edge. On small guns, scale everything down; two buttons are fine if three don't fit, but say so.
  - **Coin door** on the other side: a metal plate with two coin entries (lilac blocks, yellow lit slots) and a magenta stripe.
  - **Side-art fields** on the fore-end or handguard and the stock: recessed violet fields with pixel-stepped corners holding a raked magenta band, a thin cyan line, a yellow eight-point starburst and a magenta pixel trail.
  - **Lit edge trim:** a magenta T-molding bar seated into a lower edge of the fore-end.
  - **Light ring:** a cyan ring on the muzzle or brake, in a groove on a stepped eight-sided brake or a reshaped muzzle part.
  - **Cabinet stock end** (guns with a stock): a raked marquee top with a cyan marquee light, a stepped rear.
  - **Mag stripe:** a magenta stripe on the magazine, bone `Mag`, clear of the magwell through the whole reload.
- **flat_group names:** keep them identical so `Util/ArcadeEffects` works on every gun without new art names:
  - `ARButton1`–`ARButton3`, `ARStickBall`
  - `ARScreen`, `ARScreenShip`, `ARScreenShot`, `ARScreenStars`, `ARScreenBlip`
  - `ARDeckLight`, `ARTrim`, `ARBrakeLight`
- **Bones:** put the deck, screen and buttons on `Root` (or the fixed frame). Never put them on a moving part (`Slide`, `Bolt`, `Pump`, `Cylinder`, `Barrels`). If a gun has no fixed surface the player sees, report it rather than guess.

## Rules (the owner checks these first)
- **Faceted and crisp:** no round curves, spheres or smooth cylinders (6–12 facet prisms); 1–2 segment flat chamfers; no blunt cut-off ends.
- **Seated and connected:**
  - plates sit in recesses or overlap the walls they meet;
  - nothing floats, is flush or coplanar, or pokes through;
  - joins are buried 0.02+;
  - every decorative layer has its own lift, at least 0.004 apart.
- **Stock contract:** keep the stock rig, bones, locators (`Muzzle`, `AimPoint`, grips, `Eject`, `CharmPoint`) and actions, and the stock `CharmLoop` (charms are the same on every gun). The audit's `contract_equal` must be all true.
- **ADS:** keep the stock sights (named `*Sight*`). Scope lenses are untouched. Nothing new may sit in the sight picture: check the ADS render, not only the rays.
- **Budget:** about 1.5× the stock triangles at most.
- **Gate:**
  - 0 faults in new geometry (stock open islands that are unchanged don't count);
  - 0 coplanar pairs;
  - no new floating parts;
  - 0 animated intersections;
  - ADS rays clear;
  - the flat export shows 0 lifts, flips and crossed faces and a clean one-sided re-import.

## Self-grade (the gun's grade is its lowest area)
| Area | 9-10 looks like |
|---|---|
| Silhouette | reads as that gun; clearly the Arcade line next to the Havoc; not a recolour |
| Crispness | flat-shaded, sharp, 1-2 segment chamfers |
| Layering | the deck, screen, buttons and fields seated with thickness |
| Connections | nothing floating, flush or poking; joins buried; both sides right |
| ADS | big clear window; nothing new in the sight picture |
| Palette | the line's roles; small accents |
| Budget | within budget |
| Contract | every stock bone, locator, action and the charm mount kept |

## Report and bookkeeping
- Append a `### <Gun> (<InGameName>)` section to the [Build Ledger](Build%20Ledger.md): versions and what changed, the master and export paths, tris against stock, the audit summary, the grade table and the review sheet link.
- Don't commit (the orchestrating session commits with exact paths). Don't touch Studio, uploads, `src/` or other notes.
- **Final message:**
  - the gun, final version and grade;
  - tris (and stock tris);
  - the review sheet path;
  - anything the owner should decide, such as a part that had to sit on a moving bone, or two buttons instead of three.
