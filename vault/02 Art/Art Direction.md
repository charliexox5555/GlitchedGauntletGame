# Art Direction: Style B "Stylized Neon"

**Master reference:** the finished **Bitrate** rifle. Every asset should look like it was made by the same artist, for the same game.

![Bitrate master](References/bitrate_master.webp)

---

## Style rules (from Bitrate)
- Stylized hard-surface, chunky but clean. Rounded bevels on every edge, angular chamfered cuts, big readable shapes. **No** greebles, grime, scratches or logos.
- **Two-tone:** slate blue-grey upper panels with a subtle cyan circuit-trace pattern; near-black lower parts, grips, mags, barrels and buttpads.
- **Cyan neon** (`#00E5FF`) only as long thin lines, rounded "pill" vents, segmented mag bars and a muzzle ring.
- **Gold** only on the trigger and one small lever.
- **Magenta** (`#FF3DCB`) only on optic lenses and **wildcard energy parts**.
- Shared kit: the same black notched rail, flip-up ring sights, trigger and grip on every gun.
- **Charm loop** at the back of every gun (cosmetic charms later).
- **Silhouette rule:** every gun is recognisable from its black outline alone, on a phone.
- **No blood.** Hits spark and deaths dissolve into pixels (keeps the "Mild" content label).

## Palette
| Name | Hex | Use |
|---|---|---|
| Body Panel | `#56607C` | Upper panels (with circuit trace) |
| Body Dark | `#1C2030` | Lower parts, grips, mags |
| Metal | `#14161D` | Barrels, inner parts |
| Neon | `#00E5FF` | Glow strips (Roblox `Neon` material) |
| Accent | `#FFC83D` | Trigger, one lever |
| Lens / Exotic | `#FF3DCB` | Optic lenses, wildcard energy |

## Model standard (needed for the code to work)
Every weapon is a `Model` named **exactly** like its config ID (e.g. `Bitrate`, `HardReset`) in **`ReplicatedStorage.Weapons`**:
- **`Handle`**: PrimaryPart, invisible, at the pistol grip (Blender origin). Carries the `RightGrip` attachment.
- **`Rig`** folder: one invisible joint part per Blender bone (`Root`, `Mag`, `Slide`, `Bolt`, `Pump`, `Cylinder`, `Barrels`, `Rotor`, `Core`, `Orb`, `Trigger`, `Flash`, `Charm`), built in the bone's own axes. **`Rig.Motors`** holds a Motor6D per bone (Handle → Root → Mag …) with C0 at the bone head, so the Blender Fire/Reload animations play straight onto `Motor6D.Transform`.
- **Attachments** `Muzzle`, `LeftGrip`, `AimPoint`, `Eject`, `CharmPoint` sit on the joint part of the bone they ride on (Root for most; `Slide` for pistol AimPoint/Eject, `Barrels` for break-actions, `Orb` for Null). Find them with `FindFirstChild(name, true)`.
- **Mesh parts** keep the Blender names. Multi-material meshes are split as `<Part>_<Material>` (`Body_Panel`, `Body_Dark`, `Body_Metal`, `Body_Accent`, `Mag_Dark`…). Each is welded to its bone's joint part with a classic **`Weld`** (not WeldConstraint: its offset gets recomputed wrongly on clients).
- **Neon parts are separate MeshParts** with `Material = Neon`, so skins can recolour them. Lens parts are Neon `#FF3DCB`, optic glass at 0.25 transparency.
- Attachment and skin geometry (`Muzzle_Compensator_*`, `Sight_Holo_*`, `Skin_*`) has an `Option` attribute; options that are off in Blender are invisible.
- Every part: `Anchored = false`, `CanCollide/CanQuery/CanTouch = false`, `Massless = true`, `CastShadow = false`.
- Barrel along the Handle's **−Z** axis (Roblox forward), up = +Y.
- Size: Bitrate = **3.8–3.9 studs** (1 Blender unit = 1 stud).
- Triangles: sidearms ≤ 3K, primaries ≤ 5K, machine guns/wildcards ≤ 6K.

Check any time with `tools/studio/ValidateWeapons.luau` (paste into the Command Bar, or ask Claude to run it).

## Import pipeline (Blender → Roblox, scripted)
Rojo **can't** live-sync MeshParts (it leaves `MeshId` empty), so finished guns live in the Studio-owned `ReplicatedStorage.Weapons` folder and are saved with the place. Each gun also has a versioned backup in the repo.

1. **Source:** `art-source/weapons/GunTest.blend` (all guns, one collection each).
2. **Export:** `blender --background art-source/weapons/GunTest.blend --python tools/blender/export_weapons.py -- [Gun ...]` writes `art-source/weapons/Exports/<Id>.fbx` + `<Id>.json` (bones, locators, part centres, Fire/Reload keyframes). It runs on a background copy, so the .blend is never changed.
3. **Upload:** `python tools/opencloud/upload_models.py --group 11116787 [Id ...]` (key in the `ROBLOX_ASSETS_KEY` environment variable). Asset IDs go in `Exports/assets.json`; re-uploads add a new version to the same asset.
4. **Build:** `python tools/studio/make_build_data.py`, copy `tools/studio/rojo/` to `src/server/WeaponBuild/` (temporary, gitignored), run `tools/studio/receive_server.py`, then in Studio `require(WeaponBuilder).publish("<Id>")`. It inserts the upload into `ServerStorage.ImportStaging`, builds the gun to the standard, installs it in `ReplicatedStorage.Weapons` and saves `art-source/weapons/Studio/<Id>.rbxm`.
5. **Animations:** `python tools/make_weapon_anims.py` regenerates `src/shared/WeaponAnimations/<Id>.luau` from the exports.
6. **Save the place** in Studio, run the validator, tick the [Asset Tracker](../06%20Assets/Asset%20Tracker.md).

To restore a gun by hand: right-click `ReplicatedStorage.Weapons` → **Insert from File** → `art-source/weapons/Studio/<Id>.rbxm`.
