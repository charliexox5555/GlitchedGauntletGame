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
Every weapon is a `Model` named **exactly** like its config ID (e.g. `Bitrate`) in `ReplicatedStorage.Assets.Weapons`:
- **`Handle`**: PrimaryPart, invisible, non-colliding, at the pistol grip.
- **Attachments on `Handle`:** `Muzzle`, `RightGrip`, `LeftGrip`, `AimPoint`, `Eject`, `CharmPoint`.
- Parts named `Body`, `Barrel`, `Mag` (separate; it moves during reloads), `Sight`, `Neon`, `Trigger`, `Stock`.
- **Neon parts are separate MeshParts** with `Material = Neon`, so skins can recolour them.
- Everything welded to `Handle`; `Anchored = false`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Massless = true`.
- Barrel along the Handle's **−Z** axis (Roblox forward).
- Size: Bitrate = **3.8 studs**; every other gun scales from it (lineup table in [Gun Batch Prompt](Gun%20Batch%20Prompt.md)).
- Triangles: sidearms ≤ 3K, primaries ≤ 5K, machine guns/wildcards ≤ 6K.

## Import pipeline (Blender → Studio → repo)
1. **Source files** (`.blend`, `.fbx`) go in `art-source/weapons/<Gun>/`. These are the editable originals.
2. In Studio: **File → Import 3D** the FBX into a staging folder that Rojo does *not* manage (e.g. `ServerStorage.ImportStaging`).
3. Build the Model to the standard above (Claude can do the attachments and welds through the Studio MCP or a Command Bar script).
4. Right-click the finished Model → **Save to File** → `assets/Weapons/<Gun>.rbxm`.
5. Rojo syncs `assets/` into `ReplicatedStorage.Assets`, so the gun is now versioned in git.
6. Tick it off in the [Asset Tracker](../06%20Assets/Asset%20Tracker.md).

⚠️ **Don't edit guns directly inside `ReplicatedStorage.Assets` in Studio.** Rojo owns that folder and will overwrite Studio edits when it syncs. Edit in staging, then re-save the `.rbxm`.
