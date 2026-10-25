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

## VFX
All shot effects live in `EffectsController` and use one texture set in the same neon style (cyan `#00E5FF`, magenta `#FF3DCB` for wildcards, gold for metal sparks and headshots).
- **Textures:** `blender --background --factory-startup --python tools/vfx/make_vfx_textures.py -- [names] [--preview out.png]` renders them with Cycles (emission shaders / flat emission geometry on a transparent film, straight-alpha PNG) into `art-source/vfx/`. White textures are tinted in game; the bullet hole is baked dark. `_2x2` sheets are flipbooks (each particle keeps one random frame).
- **Upload:** `python tools/opencloud/upload_asset.py --group 11116787 --type Decal <png> "GG VFX <name>"` returns a *Decal* id; particles, beams and images need the *Image* id behind it (Studio: `InsertService:LoadAsset(id)` → the Decal's `Texture`). Store that in `Config/VfxTextures`.
- **Rules:** keep beams readable on a bright sky (textured strands at `LightEmission` 0.6, thin at the muzzle); first person shows the front star only (a side flame seen down the barrel is a sliver); fast guns pop a dimmer light; pool anything an automatic gun fires (tracers, shells, holes, burst emitters).
- **Screenshots:** in Studio set `Workspace` attribute `VfxTimeScale` (0 freezes, 0.05 is slow motion); Studio runs at ~15 fps unfocused, so a tracer otherwise lasts under a frame.

To restore a gun by hand: right-click `ReplicatedStorage.Weapons` → **Insert from File** → `art-source/weapons/Studio/<Id>.rbxm`.

## First-person arms
- One long bevelled block per arm (RIVALS style, references in `References/rivals-viewmodel/`), generated by `tools/blender/make_arm_mesh.py` → `art-source/viewmodel/Arms.fbx` (ArmRight / ArmLeft, 1 × 5 × 1, smooth shading). UVs map each side onto that arm's region of the classic shirt template; the 2 studs nearest the hand carry the template's full arm height, like an R6 arm.
- Upload: `python tools/opencloud/upload_asset.py --group 11116787 --type Model art-source/viewmodel/Arms.fbx "GG Viewmodel Arms"`, then in Studio `InsertService:LoadAsset(id)` → each MeshPart's `MeshId` goes in `Config/Viewmodel` `ARM_MESH`.
