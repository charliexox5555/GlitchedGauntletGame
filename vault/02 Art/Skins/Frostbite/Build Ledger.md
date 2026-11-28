# Frostbite Skin Line — Build Ledger (Season 1 Battle Pass, Legendary)

2026-11-27. Season 1 battle pass Legendary chase line (premium tiers 15, 24, 29, plus the **Frostbite Knife** + `FROSTBITTEN` title at tier 30; covers all 14 active guns + Knife; excluded from cases).

- **Blender instance used:** `127.0.0.1:9881`, PID `48580`, Blender `5.2.2` (dedicated window via `tools/blender/start_bridge.py`; port `9876` held `ThunderOrb.blend` and was untouched).
- **Pipeline scripts:** [tools/blender/frostbite/](../../../../tools/blender/frostbite/frost_lib.py) (`frost_lib.py`, `10_vandal.py`, `49_audit.py`, `20_review.py`, `21_review_vandal.py`, `53_export.py`, `30_sheet.py`, `sheet_vandal.json`).

## Palette (flat-shaded, zero Glass)

| Role | Blender Name | Hex | Roughness | Metallic | Emission | Roblox Material |
|---|---|---|---|---|---|---|
| Obsidian | `FB Obsidian` | `121720` | 0.50 | 0.30 | — | `SmoothPlastic` |
| Armor | `FB Armor` | `1E2634` | 0.42 | 0.58 | — | `Metal` |
| FrostSteel | `FB FrostSteel` | `586F8C` | 0.32 | 0.72 | — | `Metal` |
| Grip | `FB Grip` | `171C26` | 0.76 | 0.00 | — | `SmoothPlastic` |
| IceDeep | `FB IceDeep` | `1D588A` | 0.24 | 0.08 | — | `SmoothPlastic` (refl `0.05`) |
| IceMid | `FB IceMid` | `52B6E8` | 0.20 | 0.04 | — | `SmoothPlastic` (refl `0.05`) |
| IceBright | `FB IceBright` | `BBEBFF` | 0.16 | 0.00 | — | `SmoothPlastic` (refl `0.12`) |
| CryoGlow | `FB CryoGlow` | `9EEFFF` | 0.25 | 0.00 | 1.25 | `Neon` |
| GlowWhite | `FB GlowWhite` | `E4FAFF` | 0.25 | 0.00 | 1.45 | `Neon` |

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
| `SK_Mag_FBMagGlow` | `Mag` | `CryoGlow` | Recessed vertical magazine frost gauge (rides `Mag` bone) |

---

### Vandal (Havoc) — **PENDING OWNER APPROVAL**

- **Master:** [Vandal_Frostbite_v06.blend](../../../../art-source/weapons/Skins/Frostbite/Vandal/v06/Vandal_Frostbite_v06.blend)
- **Export:** [Vandal_Frostbite_RobloxFlat.fbx](../../../../art-source/weapons/Skins/Frostbite/Vandal/v06x/Vandal_Frostbite_RobloxFlat.fbx) + [manifest_flat.json](../../../../art-source/weapons/Skins/Frostbite/Vandal/v06x/manifest_flat.json)
- **Review Sheet:** [Vandal_v06_review.png](out/Vandal_v06_review.png)
- **Triangles:** `6,850` vs `5,171` stock (`1.32×`, cap `7,756` = `1.5×`).

#### Versions & Changes
- **v01 (`7,006` tris):** Initial Slipframe-inspired build replacing `Handguard`, `Stock`, `Barrel`, `Neon`. `0` new faults/floaters/coplanar/ADS hits/animated intersections, but visual inspection showed thin pencil-like crystal spikes, receiver-top clipping at `x = 0.85..1.10`, and a corner gap at the stock crystal butt join.
- **v02 (`6,976` tris):** Replaced pencil spikes in the cryo-core and fore-end bays with sculpted `crystal_blade` glacier slabs; raised `FB_ReceiverMantle` (`z_top = 0.434`) to clear `Vandal_Receiver` cleanly; extended `FB_StockCrystal` `0.04` into `FB_StockButt` (closing the culled butt join gap); sculpted `FB_MuzzleIce`, `FB_MagCrystal`, `FB_GripIce`. (`8` coplanar pairs flagged.)
- **v03 (`6,850` tris):** Replaced remaining dorsal dart needles (`FBGrow*`) with sculpted `crest_fin` glacier crest ridges; tucked fore-end glacier slabs (`y <= 0.120`) for a razor-clean ADS edge; offset `FB_BridgeCheek` below the mantle shoulder. (`5` coplanar pairs.)
- **v04 (`6,850` tris):** Terminated `FB_BridgeCheek` at `x = 1.125` (clearing `FB_ReceiverMantle` front cap) and offset `FB_CoreFissure` (`0.081..0.090`) off `Vandal_Pins`. (`2` coplanar pairs left on `FBGrowRear` vs `FB_MantlePlate`.)
- **v05 (`6,850` tris):** Shifted `FBGrowRear` to `y = 0.082..0.115`, `z - 0.003` (`coplanar: 0`!) and brought `FB_CoreHeart_Left` slightly proud inside the left cryo-core bay. Export assertion caught multi-material `flat_group`s (`FBGrow*`, `FBShard*`, `FBCoreHeart`).
- **v06 (`6,850` tris, final):** Made every `flat_group` single-material (`FBCoreHeart` -> `GlowWhite`, `FBGrow*` -> `IceMid`, `FBShard*` -> `IceBright`), keeping multi-tone `IceDeep`/`IceMid`/`IceBright` on all static crystal beds.

#### Audit & Gate Summary (`v06` + `v06x`)
- **Gap sweep (carried + verified on culled magenta renders from left, right, below):** trigger guard post (`+0.031` fwd/up), trigger guard rear (`-0.024`), rail spine (`-0.025`), gas tube (`+0.020`), barrel end (`+0.012`), front/rear sight towers (`-0.018`), stock frame buried `0.073` inside receiver, stock crystal buried `0.04` inside butt pad. Zero magenta leaks in any join close-up.
- **Audit (`Vandal_v06_views/audit.json`):** `new_faults = 0`, `new_floating = 0`, `coplanar = 0`, `ads_eye_segment_hits = [[], [], [], [], []]`, `contract_equal = {locators: true, bones: true, actions: true}`, `animated_intersections = {}`.
- **Flat export (`Vandal_v06x_flat_check/reimport.json`):** `39` MeshParts (`SK_Root_Sight_*` separated), `flipped_islands = {}`, `coplanar_lifted = []`, `crossed_faces_fixed = {}`, `crossed_faces_left = {}`, `inside_out = []`.

#### Self-Grade (`v06`) — **9/10** (lowest area: 9)
| Area | Score | Notes |
|---|---|---|
| Silhouette | 9/10 | Swept Slipframe-style upper mantle, angled fore-end shroud, skeleton crystal stock, fang muzzle crown, sculpted mag sleeve. |
| Crispness | 9/10 | 100% flat-shaded planar facets, 1-segment bevels, zero smooth blobs, zero Glass. |
| Layering | 9/10 | Recessed `Obsidian` bays, `FrostSteel` armor jaws, layered `IceDeep`/`IceMid`/`IceBright` slabs, distinct `FBShard`/`FBGrow` planes. |
| Connections | 9/10 | All joins buried `0.02+`, zero gaps across culled magenta left/right/underside close-ups, zero coplanar faces. |
| ADS | 10/10 | Stock `RearSight`/`FrontSight` preserved, `0` ray hits, crisp unobstructed sight window. |
| Palette | 9/10 | Dark cold-forged slate + icy titanium + 3-tier glacial blue-white crystal + small restrained cold `Neon` veins. |
| Budget | 9/10 | `6,850` tris (`1.32×` stock `5,171`, under `7,756` cap). |
| Contract | 10/10 | Every bone, locator (`CharmPoint`, `AimPoint`, `Muzzle`, grips, sockets), action, and `CharmLoop` 100% unchanged. |

---

## Post-Approval Plan: Effects & Sounds (DO NOT BUILD UNTIL APPROVED)

### Visual Effects (`src/client/Util/FrostbiteEffects.luau` + `src/shared/Config/Frostbite.luau`)
Patterned directly after `Util/ArcadeEffects.luau` + `Config/Arcade.luau` (client-only on camera viewmodel clone, Motor6D `Transform` + `LocalHide`-safe opacity/material tweaks, auto-cleaned on unequip):
1. **Rest Cold Shimmer (continuous):**
   - Smooth `2.6 s` sine pulse gently modulates `FBCoreHeart`, `FBCoreFissure`, `FBUpperSeam`, `FBForeSeam`, `FBMuzzleGlow`, `FBStockGlow`, `FBMagGlow` (`Color3` brightness breath between cool cyan `#7CDFFF` and ice-white `#E4FAFF`, low `PointLight` range `1.6 * scale` on `FBCoreHeart` off during ADS).
   - Subtle cold frost-mote `ParticleEmitter` attached to `FBCoreHeart` (tiny soft falling ice motes, low rate `4/s`, auto-disabled when ADS alpha > `0.25` so sight picture stays 100% clean).
2. **Inspect Ice Growth (`Vandal_Inspect` = `2.75 s` / `67` frames at `24 fps`):**
   - `FBGrowRear` (`0.18..0.42`), `FBGrowMid` (`0.36..0.60`), `FBGrowFront` (`0.54..0.78`) Motor6Ds translate smoothly outward `+0.030..+0.036` studs along their flank-up normal (`outBack`-style overshoot then lock), while `FBUpperSeam`/`FBForeSeam` sweep bright ice-white behind the wave. Hold locked until inspect ends, then smoothly retract back to rest (`0.84..0.98`).
3. **Kill Crack & Shed (`onKill` trigger from `ViewmodelController`):**
   - `0.00–0.06 s`: `FBCoreHeart` + seams flash crisp ice-white (`#E4FAFF`); `FBShard1..4` jolt outward `+0.012` studs.
   - `0.06–0.44 s`: `FBShard1..4` detach via their Motor6D `Transform` (spinning + drifting outward/downward as `Transparency` fades `0 -> 1`) alongside a short burst (`12` particles) of flat cyan-white ice chip particles from `FBCoreHeart` & `FBForeSeam`.
   - `0.44–1.34 s`: Shards snap back to buried root (`-0.024` inside bed) and smoothly grow/refreeze back to rest (`0.90 s` ease-out).
4. **Fire & Mag-Seat Micro-Feedback:**
   - Each shot gives `FBCoreHeart` + `FBMuzzleGlow` a crisp `0.09 s` cryo pulse; magazine seat flares `FBMagGlow` + `FBCoreFissure` (`0.22 s`).

### Sounds (`tools/audio/design_frostbite.py` + `src/shared/Config/FrostbiteAudio.luau` + `AudioController` `frostbite` bank)
Patterned after `tools/audio/design_arcade.py` + `Config/ArcadeAudio.luau` (private 48 kHz WAVs built from licensed ProPack + clean synthesis, quiet tactile layers sitting on top of stock gun foley):
- **`vandal_fire` (`0.13 s`, layered over stock Vandal shot at `0.18` vol):** sharp ProPack transient snap + high-passed glassy crystal harmonic ping (`2.1 kHz` + `3.4 kHz` inharmonic FM decay `55 ms`) + short cold pressurized ice-air tail (`80 ms`).
- **`inspect_grow` (`0.24 s`, triggered per stage Rear → Mid → Front at climbing pitches `0.94`, `1.04`, `1.16`):** crisp dry ice-creak / crystalline crackle (ProPack `wood_block` / `switch` micro-transients high-passed + resonant chime ping) as each crystal ridge locks out.
- **`inspect_settle` (`0.28 s`, triggered at wave apex):** cold resonant crystalline triad shimmer (`E6 + B6 + F#7` soft sine/bell decay) as all ridges lock.
- **`kill_shatter` (`0.38 s`, triggered on kill):** punchy cryo crack transient (ProPack impact + `metal_small_movement` snap) into a cascading 4-note glassy ice-shard scatter chime (`2.4–4.8 kHz`) and faint cold sub-air exhale.
