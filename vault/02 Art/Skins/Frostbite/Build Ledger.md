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

### Visual Effects (`src/client/Util/FrostbiteEffects.luau`, `FrostbiteFx.luau`, `MuzzleFx.luau`, `EffectsController.luau`, `Config/Frostbite.luau`)
Upgraded to compare with top-tier Legendary skins (`Riftforge` / `TempestStrike` / `Slipframe`) across every first-person and world touchpoint (client-only, cleaned on unequip, ADS-clean):
1. **Rest Cryo Reactor:** Dual paired volumetric flank `Beam` ribbons (`VFX.FROST_VAPOR` + `VFX.TEMPEST_GLOW_BAND`), 3 cryo fracture `STIM_BOLT` lightning arcs, cascading sub-zero vapor (`FROST_MIST_2x2` at core and fore-end), diamond snow glints (`MOD_SPARKLE`), dual `PointLight`s, and `2.6 s` breathing shimmer across `FBCoreHeart`, seams, and `FBMagGlow`. All lights, mist, sparkles, arcs, halo, and ribbons cleanly turn off/fade out in ADS (`adsAlpha >= 0.25`).
2. **Draw & Reload:** `Draw` sweeps a 12-segment 3D Cryo Halo ring (`makeHalo`) stock -> muzzle with diamond sparkle bursts; `Reload` drains emissives cool dark and vents frost vapor (`FrostbiteMagMist`) from the magwell while the mag is out, then slams a 3D halo sweep + `FROST_BURST_2x2` pop down the barrel on `MagIn`.
3. **Inspect Ice Growth (`Vandal_Inspect`):** 2× amplified crystal eruption (`FBGrowRear` -> `Mid` -> `Front`, `~0.062–0.072` unscaled studs along flank cleavage) with frosted `#ECFDFF` paint shift, trailing 3D cryo halo wave, rapid fracture arcs, `T_CHIP` shard puffs, and `FROST_BURST_2x2` settle pop.
4. **Fire, Muzzle Flash, Tracers & Impacts:** Reuses Slipframe's icy `SlipframeFlashCore` + twin `SlipframeFlashEdge` muzzle flash (and suppressed icy puff) plus custom `FrostbiteMuzzleShards` (`VFX.FROST_SHARD`), launches a travelling `T_RING` cryo pulse down the barrel per shot with sequential seam light waves, fires icy cyan tracers (`#A6F2FF` + `TEMPEST_WATER_TRACER` wake), and spawns `FrostbiteFx.splash` on wall impacts (`FROST_BURST_2x2`, `T_RING`, flying `T_CHIP`/`FROST_SHARD` splinters, `FROST_MIST_2x2`, fading `FROST_GROUND` frost-feather decal, cold `PointLight`).
5. **Kill Cryo Shatter:** `0.07 s` flash -> radial 3D halo shockwave, sympathetic crystal crest shudder, `22` `T_CHIP` bursts, `FBShard1..4` outward fracture (`0.26–0.28` unscaled studs) with tumble & `LocalHide` fade, AND `FrostbiteFx.killBurst` world cryo nova at the eliminated target (`FROST_BURST_2x2`, `T_RING` nova, `22` 3D shards/chips, mist cloud, sparkles, light) -> `0.90 s` refreeze sweep back to rest.

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
  - Camera viewmodel loaded all `14` `_FB*` MeshParts, `7` `FrostbiteMotion` Motor6Ds, `4` `Sight` parts, `FrostbiteRibbon*` (`6` outer + `6` core Beams), `FrostbiteHaloBeam*`/`FrostbiteHaloCore*` (`12` segments), `FrostbiteArc*` (`3`), `FrostbiteCoreLight`, `FrostbiteForeLight`, `FrostbiteMistCore`, `FrostbiteMistFore`, `FrostbiteMagMist`, `FrostbiteSparkles`, `FrostbiteShards`, `FrostbiteBurst`, `FrostbiteMuzzlePop`, and `FrostbitePulseRing`.
  - ADS (`DevAim`) suppressed lights, mist, sparkles, arcs, halo, and ribbons cleanly (`Enabled = false`), restoring on hip (`coreL=0.48`, `foreL=0.25`, `Enabled = true`) — verified visually in [Hip VFX](out/Vandal_v10_Range_Hip_VFX.jpg) and [ADS VFX](out/Vandal_v10_Range_ADS_VFX.jpg).
  - Fire spawned Slipframe's `SlipframeFlashCore` + twin `SlipframeFlashEdge` + `FrostbiteMuzzleShards` and `Workspace.FrostbiteSplash` + `FrostbiteImpactMark`.
  - Live kill of a `RangeBot` (`killed = true`, `0.61 s`) spawned `Workspace.FrostbiteKillBurst` and triggered `FBShard1..4` outward shatter (`pos = 0.0318 -> 0.1928`, `LTM = 0 -> 0.82 -> 1.00`, `haloOn = true`) and clean refreeze (`pos = 0.0000`, `LTM = 0.00`).
  - **0 console errors** from Frostbite code, VFX, geometry, or audio.
- **Owner Action:** Save the Studio place (`71551303511506`) to persist `ServerStorage.WeaponSkins.Frostbite.Vandal`.
