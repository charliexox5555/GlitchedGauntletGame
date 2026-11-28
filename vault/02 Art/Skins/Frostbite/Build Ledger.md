# Frostbite Skin Line — Build Ledger (Season 1 Battle Pass, Legendary)

2026-11-27. Season 1 battle pass Legendary chase line (premium tiers 15, 24, 29, plus the **Frostbite Knife** + `FROSTBITTEN` title at tier 30; covers all 14 active guns + Knife; excluded from cases).

- **Blender instance used:** `127.0.0.1:9100` (PID `18288`, Blender `5.2.2`, owner's live Blender window, `Vandal_Frostbite_v10.blend` left open); temporary bridges `9881` & `9883` used for parallel builds/portraits and closed afterward.
- **Pipeline scripts:** [tools/blender/frostbite/](../../../../tools/blender/frostbite/frost_lib.py) (`frost_lib.py`, `10_vandal.py`, `11_phantom.py`–`25_knife.py`, `49_audit.py`, `20_review.py`, `21_review_*.py`, `53_export.py`, `30_sheet.py`, `sheet_*.json`, `40_portraits.py`), [tools/render/frostbite_emblem.py](../../../../tools/render/frostbite_emblem.py), and [tools/audio/design_frostbite.py](../../../../tools/audio/design_frostbite.py).

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

---

## Full Line Inventory (All 14 Active Guns + Tier 30 Knife — INSTALLED & VERIFIED)

All 15 models passed contract equality (`locators/bones/actions`, plus `lenses` on `Operator`/`Marshal`), `<= 1.5x` triangle budget, `0` non-lens `Glass` parts, `0` animated part overlaps across all clips, `0` Studio 5-ray ADS hits, and clean backface-culled flat-FBX reimports (`ServerStorage.WeaponSkins.Frostbite.<Item>`, tagged `GauntletAuthoredData` + `GGAsset_LobbySkins_279..293`):

| Item | Version | Tris / Stock (Ratio) | Open Cloud Model ID | AssetData Row | Portrait Image ID | Side Icon Image ID |
|---|---|---|---|---|---|---|
| `Vandal` | `v10x` | `7,518` / `5,171` (`1.45×`) | `83152238474766` | `GGAsset_LobbySkins_279` | `105378818541316` | `99356685685691` |
| `Bucky` | `v02x` | `3,770` / `3,030` (`1.24×`) | `114676935223533` | `GGAsset_LobbySkins_280` | `116900213708648` | `132771995946428` |
| `Bulldog` | `v03x` | `5,172` / `3,640` (`1.42×`) | `94192220887072` | `GGAsset_LobbySkins_281` | `87475781525763` | `114649192368623` |
| `Classic` | `v02x` | `3,332` / `2,334` (`1.43×`) | `74912678424755` | `GGAsset_LobbySkins_282` | `89798767746151` | `76961069175996` |
| `Ghost` | `v02x` | `3,618` / `2,964` (`1.22×`) | `70540582170670` | `GGAsset_LobbySkins_283` | `109030735865890` | `110262014703043` |
| `Guardian` | `v02x` | `5,690` / `4,374` (`1.30×`) | `123132701986098` | `GGAsset_LobbySkins_284` | `82783225027271` | `79681792967528` |
| `Knife` | `v02x` | `1,088` / `1,404` (`0.77×`) | `135803176205156` | `GGAsset_LobbySkins_285` | `87582292983474` | `121514182568620` |
| `Marshal` | `v02x` | `5,977` / `4,407` (`1.36×`) | `89527238902700` | `GGAsset_LobbySkins_286` | `135417370995110` | `120107730093252` |
| `Odin` | `v02x` | `6,152` / `4,528` (`1.36×`) | `83346335930988` | `GGAsset_LobbySkins_287` | `95199311972622` | `84823960432810` |
| `Operator` | `v02x` | `6,474` / `4,950` (`1.31×`) | `132650812263876` | `GGAsset_LobbySkins_288` | `78698182476920` | `110046127168690` |
| `Phantom` | `v04x` | `6,470` / `4,724` (`1.37×`) | `140452957222525` | `GGAsset_LobbySkins_289` | `123387913029275` | `117280578070514` |
| `Sheriff` | `v02x` | `4,186` / `3,066` (`1.37×`) | `112367899700602` | `GGAsset_LobbySkins_290` | `99473999044496` | `112549673002806` |
| `Shorty` | `v02x` | `3,334` / `2,734` (`1.22×`) | `120853207046013` | `GGAsset_LobbySkins_291` | `138141879896435` | `126309960577801` |
| `Spectre` | `v02x` | `4,873` / `3,389` (`1.44×`) | `82793920076665` | `GGAsset_LobbySkins_292` | `84571646618951` | `72558499253489` |
| `Stinger` | `v02x` | `4,028` / `3,134` (`1.29×`) | `136412465765800` | `GGAsset_LobbySkins_293` | `136762692058567` | `131593366714260` |

- **Collection Emblem (`Locker.EMBLEMS.Frostbite`):** `rbxassetid://80542340615450` (Decal `104823838837973`, generated via `tools/render/frostbite_emblem.py`).
- **Battle Pass Tier 30 Portrait (`BattlePassController.luau`):** Updated fixed-gun Battle Pass reward rendering to prefer `SkinArt.portrait(r.gun, r.line)` with `WHITE` tinting (falling back to silhouette only if missing), so Tier 30 **Frostbite Knife** renders its full-color portrait directly alongside Tier 15/24/29 random-gun Frostbite reels.

### Full Line Audio Cues (`src/shared/Config/FrostbiteAudio.luau`)
20 cues total (48 kHz PCM_16 WAVs generated via `tools/audio/design_frostbite.py`):
- **Shared Inspect & Kill:** `inspect_grow` (`85469900133060`), `inspect_settle` (`125723564872150`), `kill_shatter` (`134870399149985`).
- **Knife Handling:** `knife_draw` (`114498235438507`, `0.25 s`), `knife_slash` (`86794888288327`, `0.16 s`), `knife_heavy` (`86270873692721`, `0.242 s`).
- **Per-Gun Fire Layers:** `Vandal` (`132065486262242`), `Phantom` (`129012931030871`), `Spectre` (`92162594659990`), `Guardian` (`112733224449782`), `Bulldog` (`99395370172603`), `Odin` (`139007484454034`), `Operator` (`79113774701130`), `Marshal` (`128380714358799`), `Bucky` (`108636919852465`), `Stinger` (`126131211057802`), `Classic` (`71753048785037`), `Sheriff` (`90169411370806`), `Shorty` (`112130139897964`), `Ghost` (`116831528681637`).

### Knife VFX (`src/client/Util/FrostbiteKnife.luau` + `KnifeSwipeFx.luau` + `ViewmodelController.luau`)
- Rest: twin razor-thin icy edge `Beam`s along cutting edge & fuller (`VFX.FROST_VAPOR`), crossguard `PointLight`, `FROST_MIST_2x2` vapor + `MOD_SPARKLE` glints, and `2.4 s` shimmer on `FBCoreHeart`/`FBKnifeGlow`/`FBKnifePommel`.
- Draw & Inspect: 3D Cryo Halo ring (`makeHalo`) sweeping guard→tip on draw and inspect; staggered 3-stage `FBGrowRear`/`Mid`/`Front` blade crystal eruption (`0.12..0.72`), chip bursts, and `Grow`/`Settle` audio events.
- Swings & Kill: dual cryo blade `Trail`s + icy `#ECFDFF`/`#2A88C8` `KnifeSwipeFx` streak + `FrostbiteSlash`/`FrostbiteHeavy` SFX; melee kills trigger `FrostbiteKnife.onKill` (`FBShard1..4` outward fracture + `LocalHide` fade + refreeze), `FrostbiteAudio.kill`, and `EffectsController.frostbiteKill`.

## Verification Summary (Full Line)
- **Lint & Build:** `stylua --check` clean on all 10 touched/created `.luau` files; `selene src` passed (`0 errors, 0 warnings, 0 parse errors`); `rojo build default.project.json` clean.
- **Studio Play (`PlaceId 71551303511506`):**
  - `[SkinStore] 254 skins in the manifest`: verified `SkinStore.has`, `Locker.valid`, `ItemPortraits.get`, `ItemIcons.get`, `Locker.EMBLEMS.Frostbite`, VFX config, and audio cues for all `15/15` items, and verified `Frostbite` absent from `SkinCases` (`Apex` & `Knife`).
  - **Battle Pass (`BattlePassTest = true`):** visually verified Tier 15 & Tier 29 `FROSTBITE SKIN` reels and Tier 30 `FROSTBITE KNIFE` rendering `rbxassetid://87582292983474` with `ImageColor3 = (1, 1, 1)` (`WHITE`).
  - **Range:** verified `Vandal`, `Phantom`, `Operator`, `Bucky`, `Shorty`, `Sheriff`, `Classic` (`7` `FrostbiteMotion` Motor6Ds, `12` flank ribbon Beams, `2` lights; ADS suppression confirmed on `Phantom`, `Operator`, `Sheriff`) and **Tier 30 Frostbite Knife** (`7` Motor6Ds, `2` edge Beams, `1` light, heavy `2` Trails, inspect crystal growth, and live `RangeBot` kill triggering `Workspace.FrostbiteKillBurst` + `FBShard1..4` shatter). **0 Frostbite console errors.**
- **Owner Action:** **Save** the open Roblox Studio place (`71551303511506`) so all 15 `ServerStorage.WeaponSkins.Frostbite.*` models persist to Roblox.
