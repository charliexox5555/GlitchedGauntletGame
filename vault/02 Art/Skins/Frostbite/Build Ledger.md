# Frostbite Skin Line — Build Ledger (Season 1 Battle Pass, Legendary)

2026-11-27. Season 1 battle pass Legendary chase line (premium tiers 15, 24, 29, plus the **Frostbite Knife** + `FROSTBITTEN` title at tier 30; covers all 14 active guns + Knife; excluded from cases).

- **Blender instance used:** `127.0.0.1:9100`, PID `18288`, Blender `5.2.2` (owner's live Blender window, used with explicit owner permission after `v06` moved from the temporary `9881` window; `Vandal_Frostbite_v10.blend` left open).
- **Pipeline scripts:** [tools/blender/frostbite/](../../../../tools/blender/frostbite/frost_lib.py) (`frost_lib.py`, `10_vandal.py`, `49_audit.py`, `20_review.py`, `21_review_vandal.py`, `53_export.py`, `30_sheet.py`, `sheet_vandal.json`).

## Palette (flat-shaded, zero Glass)

| Role | Blender Name | Hex | Roughness | Metallic | Emission | Roblox Material |
|---|---|---|---|---|---|---|
| Obsidian | `FB Obsidian` | `0F1520` | 0.52 | 0.28 | — | `SmoothPlastic` |
| Armor | `FB Armor` | `1C2536` | 0.40 | 0.60 | — | `Metal` |
| FrostSteel | `FB FrostSteel` | `7A95B5` | 0.28 | 0.78 | — | `Metal` |
| Grip | `FB Grip` | `171C26` | 0.76 | 0.00 | — | `SmoothPlastic` |
| IceDeep | `FB IceDeep` | `16538A` | 0.24 | 0.08 | — | `SmoothPlastic` (refl `0.05`) |
| IceMid | `FB IceMid` | `3FB8F0` | 0.18 | 0.04 | — | `SmoothPlastic` (refl `0.05`) |
| IceBright | `FB IceBright` | `D2F3FF` | 0.15 | 0.00 | — | `SmoothPlastic` (refl `0.12`) |
| CryoGlow | `FB CryoGlow` | `A6F2FF` | 0.24 | 0.00 | 1.30 | `Neon` |
| GlowWhite | `FB GlowWhite` | `ECFDFF` | 0.24 | 0.00 | 1.50 | `Neon` |

## `flat_group` Inventory (Animated & Emissive Parts)

| MeshPart Name | Bone | Role / Material | Purpose |
|---|---|---|---|
| `SK_Root_FBGrowRear` | `Root` | `IceMid` | Inspect growth stage 1 (rear receiver upper flank crystal ridge) |
| `SK_Root_FBGrowMid` | `Root` | `IceMid` | Inspect growth stage 2 (bridge shoulder crystal ridge) |
| `SK_Root_FBGrowFront` | `Root` | `IceMid` | Inspect growth stage 3 (fore-end upper flank crystal ridge) |
| `SK_Root_FBShard1..4` | `Root` | `IceBright` | Outer breakaway glacier crust blades (crack/tumble/shed on kill, refreeze) |
| `SK_Root_FBCoreHeart` | `Root` | `GlowWhite` | Exposed diamond cryo-heart inside left receiver bay |
| `SK_Root_FBCoreFissure` | `Root` | `CryoGlow` | Recessed cryo-core energy fissure (left & right receiver bays) |
| `SK_Root_FBUpperSeam` | `Root` | `CryoGlow` | Recessed upper receiver mantle frost seam |
| `SK_Root_FBForeSeam` | `Root` | `CryoGlow` | Recessed fore-end glacier bay frost vein |
| `SK_Root_FBMuzzleGlow` | `Root` | `CryoGlow` | Recessed inner muzzle crown cryo glow ring |
| `SK_Root_FBStockGlow` | `Root` | `CryoGlow` | Recessed diagonal skeleton stock frost vein |
| `SK_Mag_FBMagGlow` | `Mag` | `CryoGlow` | Recessed diagonal curved magazine frost gauge (rides `Mag` bone) |

---

### Vandal (Havoc) — **INSTALLED & RANGE-VERIFIED, PENDING OWNER APPROVAL**

- **Master:** [Vandal_Frostbite_v10.blend](../../../../art-source/weapons/Skins/Frostbite/Vandal/v10/Vandal_Frostbite_v10.blend)
- **Export:** [Vandal_Frostbite_RobloxFlat.fbx](../../../../art-source/weapons/Skins/Frostbite/Vandal/v10x/Vandal_Frostbite_RobloxFlat.fbx) + [manifest_flat.json](../../../../art-source/weapons/Skins/Frostbite/Vandal/v10x/manifest_flat.json)
- **Review Sheet:** [Vandal_v10_review.png](out/Vandal_v10_review.png)
- **Range Captures:** [Hip](out/Vandal_v10_Range_Hip.jpg) · [ADS](out/Vandal_v10_Range_ADS.jpg) · [Inspect](out/Vandal_v10_Range_Inspect.jpg)
- **Triangles:** `7,518` vs `5,171` stock (`1.45×`, under `7,756` = `1.5×` cap).
- **Open Cloud Model Asset:** `83152238474766` (group `11116787`).
- **Studio Install:** `ServerStorage.WeaponSkins.Frostbite.Vandal` · AssetData row `GGAsset_LobbySkins_279` + tag `GauntletAuthoredData` (`Length = 3.98`, `SourceAsset = 123991644913328`). Raw attributes stripped to match `Arcade.Vandal`.

#### Versions & Redesign Log
- **v01–v06 (`6,850` tris):** First pass (`9881`), replaced pencil spikes with `crystal_blade` slabs, fixed `FB_ReceiverMantle` clearance, closed stock butt join, enforced single-material `flat_group`s (`v06`). Rejected by owner for reading too close to classic Vandal silhouette, overly geometric shapes, and awkward magazine ice shapes.
- **v07–v08 (on owner's `9100`):** Full sculptural redesign inspired by Slipframe's continuous armor transformation: `v07` (`9,464` tris) hit the cap from beveled pipe ribs and clipped `Vandal_FireSelector`; `v08` replaced pipe ribs with sculpted swept `armor_plate` wings framing the receiver, bridge, and split-jaw fore-end, chiseled `glacier_cluster` shards, curved-arc banana magazine with curved `CryoGlow` chasm + curved `FrostSteel` spine/cowl + swept floorplate, swept glacial-wing skeleton stock, and 4-fin cryo muzzle crown.
- **v09–v10 (`7,518` tris, final):** Fixed `FB_BridgeWing` start (`x = 0.798`) so `Vandal_ChargingHandle` reciprocates cleanly, removed `FB_CoreHeart_Left` vs `FB_CoreCrystals_Left` coplanarity, and seated `FB_StockWingCheek` into `FB_StockButt`. Clean across all audit & export gates.

#### Audit & Gate Summary (`v10` + `v10x`)
- **Audit (`Vandal_v10_views/audit.json`):** `7,518` tris (`1.45×`), `new_faults = 0`, `new_floating = 0`, `coplanar = 0`, `ads_eye_segment_hits = [[], [], [], [], []]`, `contract_equal = {locators: true, bones: true, actions: true}`, `animated_intersections = {}`.
- **Flat export (`Vandal_v10x_flat_check/reimport.json`):** `39` MeshParts (`SK_Root_Sight_02/03/05/11` separated), `flipped_islands = {}`, `coplanar_lifted = []`, `crossed_faces_fixed = {}`, `crossed_faces_left = {}`, `inside_out = []`.
- **Edit ADS Raycast:** `0` non-`*Sight*` occluder hits (`clone:ScaleTo(0.8)`, `distance = 0.36`, 5-ray spread), `0` `Glass` materials.

#### Self-Grade (`v10`) — **9/10** (lowest area: 9)
| Area | Score | Notes |
|---|---|---|
| Silhouette | 9/10 | Continuous swept carapace, wing plates on receiver/bridge/fore-end, swept glacial-wing skeleton stock, 4-fin cryo crown, curved banana magazine. |
| Crispness | 9/10 | 100% flat-shaded planar facets, chiseled glacier shards, zero smooth blobs, zero Glass. |
| Layering | 9/10 | Recessed `Obsidian` bays, `Armor`/`FrostSteel` wing armor, 3-tier glacial crystal facets, separated animated `FBGrow*`/`FBShard1..4` blades. |
| Connections | 9/10 | All joins buried `0.02+`, zero gaps across culled magenta left/right/underside close-ups, zero coplanar faces. |
| ADS | 10/10 | Stock `RearSight`/`FrontSight` preserved, `0` ray hits, light & frost motes disabled at ADS (`adsAlpha >= 0.25`). |
| Palette | 9/10 | Deep abyssal slate (`0F1520` / `1C2536`) + frost steel (`7A95B5`) + 3-tier ice crystal + restrained cold glow (`A6F2FF` / `ECFDFF`). |
| Budget | 9/10 | `7,518` tris (`1.45×` stock `5,171`, under `7,756` cap). |
| Contract | 10/10 | Every bone, locator (`CharmPoint`, `AimPoint`, `Muzzle`, grips, sockets), action, and `CharmLoop` 100% unchanged. |

---

## Implemented Effects & Sounds (Vandal)

### Visual Effects (`src/client/Util/FrostbiteEffects.luau` + `src/shared/Config/Frostbite.luau`)
Client-only on camera viewmodel clone; Motor6D swaps (`FrostbiteMotion`) + `LocalHide` + `PointLight` + `ParticleEmitter` (`FrostbiteMotes`, `FrostbiteChips`), auto-cleaned on unequip:
1. **Rest Cold Shimmer:** `2.6 s` sine breath across `SK_Root_FBCoreHeart`, seams (`FBCoreFissure`, `FBUpperSeam`, `FBForeSeam`, `FBMuzzleGlow`, `FBStockGlow`), and `SK_Mag_FBMagGlow`, plus `FrostbiteCoreLight` (`PointLight`) and gentle `FrostbiteMotes` (`Rate = 5`), both disabled when `adsAlpha >= 0.25`.
2. **Inspect Ice Growth (`Vandal_Inspect`):** `SK_Root_FBGrowRear` (`0.14..0.36`), `FBGrowMid` (`0.34..0.56`), `FBGrowFront` (`0.52..0.74`) stagger upward along flank cleavage with `easeOutBack` + chip emission, holding bloom until `0.84..0.98` retract.
3. **Kill Crack & Shed (`ViewmodelController.onKill`):** `0.06 s` ice-white flash -> `0.38 s` outward break/tumble + `14` `FrostbiteChips` burst + `LocalHide` fade (`FBShard1..4`) -> `0.90 s` refreeze back to rest.
4. **Fire & Mag-Seat Pulses:** `0.10 s` cryo pulse on `Fire` and `0.24 s` pulse on `MagIn`.

### Sounds (`tools/audio/design_frostbite.py` + `src/shared/Config/FrostbiteAudio.luau`)
48 kHz PCM_16 WAVs (`art-source/audio/frostbite/`, licensed ProPack transients + crystalline FM/cold air synthesis), wired via `AudioController` (`frostbite` bank), `GunAudio`, `ViewmodelController`, and `WeaponController`:

| Cue | Asset ID | Length | Trigger & Details |
|---|---|---|---|
| `vandal_fire` | `132065486262242` | `0.13 s` | Layered over stock Vandal shot (`Shots`, vol `0.20`, pitch `0.97..1.03`) |
| `inspect_grow` | `85469900133060` | `0.185 s` | Per inspect growth stage Rear -> Mid -> Front (`Foley`, vol `0.26`, pitch `0.94 / 1.04 / 1.16`) |
| `inspect_settle` | `125723564872150` | `0.28 s` | Inspect apex when all 3 crystal stages lock (`Foley`, vol `0.28`) |
| `kill_shatter` | `134870399149985` | `0.37 s` | Client kill confirm (`Feedback`, vol `0.34`, pitch `0.97..1.03`) |

## Verification Summary
- **Lint & Build:** `stylua --check` clean on all Frostbite-touched Luau files; `selene src` passed (`0 errors, 0 warnings`); `rojo build default.project.json` clean.
- **Studio Play Range (`Locker -> TRY IN THE RANGE`, `PlaceId 71551303511506`):**
  - `SkinStore.has("Frostbite", "Vandal") == true`, `[SkinStore] 240 skins in the manifest`, `Locker.valid("Vandal", "Frostbite") == true`, `Frostbite` absent from `SkinCases.all()`.
  - Camera viewmodel loaded all `14` `_FB*` MeshParts, `7` `FrostbiteMotion` Motor6Ds, `4` `Sight` parts, `FrostbiteCoreLight`, `FrostbiteMotes`, and `FrostbiteChips`.
  - ADS (`DevAim`) suppressed `FrostbiteCoreLight` and `FrostbiteMotes` cleanly (`Enabled = false`), restoring on hip (`Enabled = true`).
  - Fire pulse raised core brightness (`0.29 -> 0.63`); Inspect moved `FBGrowRear/Mid/Front` along the 3 staggered stages (`Transform` peak `~0.027..0.033`, `dPos = +0.0256` studs on `Root.Y`).
  - Live kill of a `RangeBot` (`HitConfirm` `killed = true`) triggered shard crack/shed (`pos = 0.0148 -> 0.0911 -> 0.1235`, `LTM = 0 -> 0.70 -> 1.00`) and refreeze (`pos = 0.0000`, `LTM = 0.00`).
  - **0 console errors** from Frostbite code, geometry, or audio.
- **Owner Action:** Save the Studio place (`71551303511506`) to persist `ServerStorage.WeaponSkins.Frostbite.Vandal`.
