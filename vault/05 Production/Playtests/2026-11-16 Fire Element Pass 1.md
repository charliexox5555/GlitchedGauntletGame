# Fire element, pass 1 (2026-11-16)

Step 1 of [Handoff - Ability Rework (Opus)](../Handoff%20-%20Ability%20Rework%20(Opus).md) → "Effects, one element at a time, fire first". Spec: [Ability VFX Direction](../../02%20Art/Ability%20VFX%20Direction.md) (F1-F7, Per Mod → Molly / Fork Fire). Code: `src/client/Util/ReworkVfx.luau` (the kit), `src/client/Util/FireFx.luau` (fire), wired from `MollyFx.ignite` / `step` / `stepBurning` and `UpgradeFx/Molly.onFork`. The old FireKit / particle looks stay as the fallback when the kit is missing.

**Superseded by pass 2 below:** the owner judged the shard patch "horrible", worse than the old fire. The old mesh fire is the base again, improved.

## Pass 2: back to the old fire, improved (2026-11-16)
Owner: "the visual effects look horrible, the ones before were better". Side by side (captures 5 and 6 vs 3):

| | Old fire (FireKit) | Rework shards (pass 1) |
|---|---|---|
| Body | A glowing pool disc ties it into one shape: the floor is burning | 14 separate shards on bare floor: reads as props |
| Density, scale | Two continuous crown rings of many small knee-high points | A few tall pieces up to 7 studs: plants or claws |
| Heat | Glows from a hot core | One flat colour per piece; dark red reads cold; LightEmission -1 particles go muddy |
| Motion | Smooth flicker, crowns turning | 12 Hz held poses: choppy, near frozen |
| Weak points | Nearly all one blown-out yellow (Neon brightens colours); flat like a pie | Cyan team ring fights the fire colours |

**How the old one is made:** `Util/FireKit` (Blender `FireVFX` meshes, `tools/blender/build_mod_firevfx.py`) drawn by `MollyFx.meshFire` / `placeMesh`: pool disc at 0.15 transparency, a hot edge ring, two crown rings turning opposite ways with a noise flicker, tongues over the inner 72% facing you, flickering, leaning and swapping variants; the burst grows the rings from 35% to full radius in 0.3 s with ember sparks.

**Pass 2 changes (`MollyFx`):** the rework patch is off (`REWORK_PATCH = false`; `FireFx` kept for reference). Colour depth instead of one yellow, using darker values because Neon draws a step brighter: deep red-orange pool `A8300A`, orange outer crown `C8430E`, yellow inner crown `D9922A`, hot yellow edge kept. The inner 40% of the tongues are hot yellow, outer ones orange with a deep red every third. The tongues stand 1.5x taller in the middle, down to 0.75x at the edge (a mound, not a disc). Capture 6. My grade: old about 6.5, pass 1 about 3, pass 2 about 8.

Still from pass 1 and live: Fork Fire's split accent (`FireFx.split`) and burning bodies (`FireFx.setBurning`), neither seen in Play yet. No team ring on the fire now (the spec wants one; a cyan neon ring fought the fire).

**Firewall (same night, captures 7-10):** the same fix. The wall (FireKit sheet, core licks, tongues) blew out to pale yellow with glowing edges and washed the floor pink: darker Neon tones (`WallFx` `WALL_SHEET B8360C`, `WALL_CORE D9922A`, `WALL_TONGUE C8430E`, `WALL_TIP 9A2208`) give a red-orange body, saturated yellow licks and red tips; the light is 1.2 / range 10 (was 2.5 / 14). Grade ~5 → ~8. The hand flame (yours and others') was the realistic Molly flipbook: now our faceted flame sheet in flat fire colours, ~14 fps, half size, slow rise (`ViewmodelHeldMods.flameEmitter`, `WallFx.handFlame`). Grade ~4 → ~6.5.

**Waiting on the owner:** play the Molly and the Firewall and say if this fire is the one to keep.

## Captures (`2026-11-16 fire captures/`)
| File | What |
|---|---|
| `1 first pass grey (claws).jpg` | First layout, as the spec reads literally: tall A tongues on the rim. Read as dark claws round a hollow middle, not fire |
| `2 Molly held grey.jpg` | Pass 2, observer, frozen in the held state (~0.5 s after ignite) |
| `3 Molly held colour.jpg` | Same frame in colour |
| `4 Molly caster view grey (live).jpg` | First person, live (not frozen) |

My read of 2 and 3: the ring and the jagged crown of upward points read as fire in colour; in grey it reads as "a burning patch" mostly from the shape mass, about 6/10. The A tongue mesh is the weak part: its tip curls over and down like a cane, so a lone A reads as a branch or hood. Captures 2-4 predate two small fixes (ignite blooms flattened like the licks, light range R x 2); not re-captured.

## Built
- **Kit module** `ReworkVfx`: pools, placement in kit axes (`take` / `give` / `place` / `flush`), `now()` on a clock slowed and frozen by Studio's `Workspace.VfxTimeScale`, the spec's curves (`curve`, `sequence`, `snap`).
- **Textures:** `T_FlameSheet` uploaded (image 78155163253287). The other six are **stand-ins** from `tools/vfx/make_rework_standins.py` (Pillow), uploaded and keyed in `Config/VfxTextures` as `T_*`. Swap in the owner's ChatGPT picks with the same file names.
- **Molly patch** (F1-F6 + team ring): 14 tongues at L1 (count by area, 5 to 30), 60% on the rim, 0.12 s Snap, 4 held poses at 12 Hz with a third changing per step, 0.3 s sink; licks, embers, pall; ignite spikes, blooms and embers (+0.075 s); one light; distance tiers 60 / 120 studs.
- **Fork Fire:** each bomblet runs the same patch at its radius (5 minimum tongues); the split is `FireFx.split` (two-frame doubled C-tongue fan with the `FF3DCB` copy 0.3 studs off, four spikes).
- **Burning (F7):** licks and embers on the torso of other burning players; none on your own body, which gets two flame-sheet frames in the bottom corners at 12 fps.

## Changes from the locked spec (need the owner's OK)
| What | Spec | Now | Why |
|---|---|---|---|
| Tongue layout | Tall A tongues listed first, "60% on the rim" | Rim = B and C (the burning edge), middle = A and some B; hooks turned to curl away from the middle | Capture 1: tall hooks on the rim read as claws |
| Mesh colours | A `C2260A`, B `FF6A1F`, C `FFD98A` | `8A1606`, `C8430E`, `D49A3A` (particles keep the spec colours) | Neon draws a step brighter: B showed yellow, C white. The spec already allows darkening |
| Licks and ignite blooms | LightEmission -1, Brightness 5 | 0 / 1.2 | -1 drew them muddy olive / a dark smudge over a lit floor |
| Light | Brightness 3, Range 27 | 1.5, R x 2 (18 at L1) | 3 at 27 studs washed the grey floor pink |
| Tongue width | none set | 0.65 x height | Wider read as blobs |
| Ignite bloom drag | none set | 14 | At 6 they flew ~16 studs up and hung there |

## Proposed next (owner's call)
- **A tongue mesh:** reshape the tip to curl up and out, not over and down (live Blender MCP, `ReworkVFX/vfx_kit.py`, then re-upload). This is the main thing keeping the grey read under 7.
- Then the rest of fire: Firewall curtain and hand flame on the same tongues.

## Not checked yet
- Fork Fire split and small patches, and burning bodies / screen corners, have not been seen in Play.
- Captures of the ignite beat (frozen at ~0.05 s).

## How to capture (for the next pass)
The MCP kills a script's spawned threads when the call returns, so a "freeze when it appears" watcher does not work. Instead: set `Workspace.VfxTimeScale` to 0.25 (effects only; the canister still flies at full speed), throw, then in the next call set it to 0 and pin the camera with a `BindToRenderStep` at `RenderPriority.Last + 50` (it must run after the game camera), hiding ScreenGuis and the viewmodel. Greyscale: a `ColorCorrectionEffect` with Saturation -1 in Lighting. Molly is thrown with E (hold), then LMB (throw) or RMB (lob).
