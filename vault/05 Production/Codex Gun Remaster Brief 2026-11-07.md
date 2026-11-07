# Codex brief: gun and knife remaster (2026-11-07)

**For Codex** (the user's ChatGPT/Codex desktop app, with the Blender MCP), working in the GlitchedGauntletGame folder. The user is away for a while, so **use your best judgement and keep going without waiting for approval**. The user approves each finished gun later, from your renders. Claude then brings the approved guns into Roblox Studio.

## 1. Goal
Remaster **every gun and the knife** to A++, professional-game quality: a **mix of Valorant detail and RIVALS clarity**. The user's complaints about the current guns:
- **The textures have blemishes and inconsistencies.** They try to look realistic and don't look good.
- **Some guns look too thin.**
- **The iron sights are blocky, too big, and identical on every gun.**
- Overall the guns "don't look professional enough".

**Akimbo is being removed. Skip it.**

## 2. The guns (ids, class, tier)
Source: `src/shared/Config/Weapons.luau`. Ignore the roster in `vault/01 Design/Weapons.md`, which is outdated.

| Class | Guns |
|---|---|
| Sidearm (T1) | Classic (the default sidearm), Shorty, Ghost, Sheriff |
| SMG (T2) | Stinger, Spectre |
| Shotgun (T2) | Judge, Bucky |
| Rifle | Bulldog (T2), Vandal (T3, the default primary), Phantom (T3), Guardian (T3) |
| Sniper | Marshal (T2), Outlaw (T3), Operator (T4) |
| Machine gun | Ares (T3), Odin (T4) |
| Melee | Knife |

**The current files, which you read but never overwrite:**
- `art-source/weapons/<Id>.blend`
- the build scripts `tools/blender/build_<id>.py` and their animations `tools/blender/anim_<id>.py`
- the shared helper `tools/blender/gunkit.py`
- the textures in `art-source/weapons/Textures/`

**Never touch `art-source/weapons/GunTest.blend`**: it has the user's unsaved work.

## 3. Where your work goes
For each gun, a new folder `art-source/weapons/Remaster/<Id>/`:
- `concept.png`: the image you generate first (section 5).
- `<Id>.blend`: the remastered model, rig and animations. Start from a **copy** of the current file, or build fresh.
- `renders/`: the review renders (section 9).

The shared style work goes in `art-source/weapons/Remaster/_Library/`: `Library.blend` (materials, trim sheet, round models, the arms reference) and `style-sheet.png`.

- **Don't export** FBX, GLB or JSON, and don't open Roblox Studio. Claude handles export and import after the user approves.
- **No git.** Touch only the paths named here.
- Take `.claude-locks/blender.lock` while you use the interactive Blender, and delete it when you finish or stop.

## 4. Style rules (every gun)
1. **Stylised, not realistic.** Chunky, readable silhouettes with slightly exaggerated proportions. Thicken the thin guns: bodies, grips, magazines and handguards should read at a glance in first person. Think hero-shooter craft: crisp chamfers, a 1-segment bevel on every hard edge, shallow panel lines, and a clear split between big, medium and small shapes. No plain boxes or cylinders left as-is.
2. **Clean surfaces. This fixes the blemishes.**
   - No photo grime, noise, smudges or random scratches.
   - Wear shows only as subtle edge highlights.
   - Use flat or softly graded colour blocks plus a little roughness variation.
   - One shared material library for every gun, so they all look like one family: same metal, same polymer, same grip texture, same accent rules.
   - A distinct accent colour and silhouette per gun is fine.
3. **Original designs.** Our guns share Valorant's names, but **don't copy Valorant's, RIVALS' or any real gun's design**. No real brands, logos or text.
4. **Consistency.** Every gun has the same finish level, bevel size, panel-line depth and texel density. Nothing should look unfinished next to its neighbour.

## 5. Process per gun
1. **Concept image first.** Use image generation to make one sheet per gun: side view, 3/4 view, and the sight picture as seen when aiming down the sights. Use the style rules above and our class. Save it as `Remaster/<Id>/concept.png`. The user is away, so choose the best direction yourself.
2. **Do the style pilot first: Vandal, then Classic.**
   - Build `_Library` (the materials, the trim sheet and a style sheet render) from these two.
   - Then do the rest by class: rifles, SMGs, pistols, shotguns, snipers, machine guns, then the Knife.
3. **Model, then texture, then rig, then animate, then render.** Record each gun in the results table (section 10).

## 6. The rig and the code contract
The game's code depends on these. Read `vault/02 Art/Art Direction.md` lines 24–57; it wins over Game Plan §6.

- **Orientation and scale:**
  - Match the current `<Id>.blend` exactly: the same origin at the grip, the same barrel direction and up axis, 1 unit = 1 stud.
  - Code maps Blender to Roblox as G(x,y,z) = (−y, z, −x).
  - Compare against the old file and keep the overall size within about ±10%. Thicker is fine.
- **Armature:**
  - One bone per moving part: slide or bolt, magazine, trigger, charging handle, hammer or cylinder, pump, lever, cover, and so on.
  - The root bone is at the grip. Each bone's head sits at its pivot.
  - Name the bones like the current file does, so existing animation markers and code still match.
  - Split meshes per material as `<Part>_<Role>` (for example `Body_Panel`, `Mag_Dark`). Neon parts are separate objects.
- **Empties or attachment points, with exact names:**
  - Required: `Muzzle`, `RightGrip`, `LeftGrip`, `AimPoint`, `Eject`, `CharmPoint`.
  - Keep the extras the current file has: `MuzzleLower`, `EjectLower`, `ChamberUpper`/`ChamberLower`, `ScopeAxis`, `ForeGrip`, `BeltFeedPoint`, `LoadPoint`, `ShellLoadPoint`, and for the Knife `BladeBase`/`BladeTip`.
- **The muzzle and its fire burst** (what the user called "an area for the fire burst"):
  - `Muzzle` sits exactly at the bore exit, pointing down the barrel, and is where the muzzle flash spawns.
  - Model a clean muzzle face or flash hider there.
  - Add `Socket_Muzzle`, `Socket_Optic` and `Socket_Under` empties for future attachments.
- **Triangle budgets:**

  | Class | Budget |
  |---|---|
  | Sidearms | ≤ 3,000 |
  | Primaries | ≤ 5,000 |
  | Machine guns | ≤ 6,000 |
  | Operator | ≤ 6,000 (it's the hero sniper) |
- **Skin-ready, for the base template:**
  - Materials named by role: `Body`, `Panel`, `Dark`, `Metal`, `Grip`, `Accent`, `Neon`.
  - Clean, non-overlapping UVs on the main shells, with room for skin artwork.
  - The default look is skin "Default". Future skins swap materials and textures by role and may add `Skin_*` geometry, so keep the main shells as clean surfaces.

## 7. Sights and aiming
- **Not every gun gets the same irons.** Pick per gun from its role and concept:
  - pistols: a low notch-and-post;
  - SMGs and rifles: a slim aperture, a compact reflex or red dot, or a holo;
  - machine guns: a holo or a big reflex;
  - shotguns: a bead or a low rib;
  - snipers: a scope. Marshal and Outlaw are 3.5×, Operator is 2.5× and should look the most premium.
- Sights should be **slim, small and clean**: they frame the target and don't block it.
- `AimPoint` sits on the sight line at the centre of the sight. Nothing may come within **0.16 studs of the eye** at the aim distance (default 0.7, open irons 0.3), or it gets cut off.
- **Render the sight picture** for every gun.

## 8. Rounds, reloads, holds and animations
- **Every gun gets its own round.** Reusing one inside a class is fine, but the size must match the gun.
  - pistol rounds, rifle rounds, shotgun shells, a machine-gun belt;
  - **sniper rounds that are clearly bigger, with Operator's the biggest.**

  Keep them in `_Library` as `Round_<Type>` and `Casing_<Type>`. Use them in the visible magazines, the chambers and the reload props.
- **Reloads must read clearly**, especially on the snipers (Operator first) and the shotguns: you should see the round go in, or the mag come out and go in.
- **Animations** go into the gun's `.blend` as Actions on its armature.
  - Clips: `Fire`, `Reload`, `ReloadEmpty`, `Draw`, `Inspect`.
  - Variants where the gun has them: `ReloadStart`/`ReloadInsert`/`ReloadEnd` for Bucky and Marshal, `DryFire`, and for the Knife `Slash1`–`3` and `HeavyStab`.
  - Keep the timeline markers the current files use, such as `MagOut`, `MagIn` and `ShellIn`. Read `anim_<id>.py` for the existing timings.
  - Make them snappier and more readable than the current ones, but keep roughly the same lengths, since the reload times are gameplay.
- **Hold check:**
  - Put a **reference pair of first-person arms** in `_Library`: RIVALS-style blocky arms, guns held straight ahead, pistols held with two hands.
  - Pose them on each gun at `RightGrip` and `LeftGrip`, to prove the grips and the foregrip work.
  - Render a "held" view. This is only a reference, not for export.

## 9. Renders for the user's approval (per gun, in `renders/`)
1. 3/4 hero view.
2. Clean side view.
3. Top view.
4. The aim-down-sights view.
5. The held view with the reference arms.
6. A rig view: moving parts offset, attachment empties shown.
7. Three key frames of the reload.

Use a neutral grey background, soft studio light, and the same camera and light for every gun. After all the guns, render one **lineup image** of every gun side by side at the same scale, as `Remaster/_Library/lineup.png`.

## 10. Results (Codex fills this in)
Add one row per gun as you finish it. If your usage limit gets close, finish the current gun, update this table and stop cleanly.

| Gun | Concept | Tris | Sight type | Round | Anims done | Renders | Notes |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

## After this (Claude, not Codex)
1. The user approves the guns from the renders.
2. Claude exports each approved gun through the pipeline (`export_weapons.py`, `make_weapon_anims.py`, Open Cloud upload, WeaponBuilder, then ValidateWeapons).
3. Claude retunes the ADS distances and hold offsets in code, removes Akimbo from the code, and asks the user to save the place.
