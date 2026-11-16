# Effects pass, overnight (2026-11-16)

Owner, going to bed: "improve all vfx and such … then holds and animations (grade them) … until you are satisfied with a high rank". Rule learned from fire ([Fire Element Pass 1](2026-11-16%20Fire%20Element%20Pass%201.md)): **start from the existing look that works and improve it; never swap it for a literal build of the spec.** Captures in `2026-11-16 effects captures/`. Fire and the bow have their own notes ([Recon Bow Draw](2026-11-16%20Recon%20Bow%20Draw.md)).

## Tooling
- The effect kits (`IceKit`, `ModVfx`, `GlitchVfx`, the Molly fire) now run on `ReworkVfx.now()`, so Studio's `Workspace.VfxTimeScale` slows or freezes them for captures (was only the new fire). Capture recipe: set `VfxTimeScale` 0.15 before triggering, then 0 in the next MCP call, pin the camera with `BindToRenderStep` at `RenderPriority.Last + 50`.

## Ice (Frost) — grade ~5 → ~8
| Before | After |
|---|---|
| A flat white star patch with small crystals that sank after ~1 s, so the Hinder (3 s) had no ice; a round Neon flash shell; a full-screen realistic frost-fern vignette on the victim (capture 1) | Crystals **hold for the whole Hinder, then shatter** into flying fragments (spec: "hard, still shapes"); the centre is a tall crystal growth (main cluster 4.6 x, two leaning side clusters), spikes 2.4-3.6 tall; the patch at 0.5 transparency so the floor shows; no round flash. The victim gets stylised ice plates in the two top corners (`T_FrostCorner` stand-in), snapping in over 0.1 s (captures 3, 4) |

Code: `client/Util/FrostFx.luau` (`kitBurst`, `screen`, `setHindered`). Not changed: the hindered body's crystals, Frost Wall, Freeze Frame.

## Scan (Recon pulse) — grade ~6 → ~7.5
Before: a flat floor ring plus the `ScanRing` band at full team colour, which bloomed into a soft cyan glow; nothing above the floor (capture scan 1). After: the band darker (35% toward black) and at 0.35 transparency, no bloom; a faint faceted `Scan_Shell` dome (ReworkVFX) sweeps out from the dart at a constant speed, 0.82 transparency, fading over the last 15% and kept clear while the camera is near its front (scan 2). The reveal outlines were already right. Code: `ModFxController.onReconPulse`.

## Impact (Crash Down, Updraft G2) — grade ~4 → ~7.5
Before (impact 1): a magenta hex-tile floor, magenta pixel static, magenta dashed rings, sparkles, glowing team-colour cracks and a magenta-slice pillar on the dive: it read as glitch magic, not a slam (the owner rejected "glitch static on everything"; the spec keeps glitch for four beats only). After (impact 2): the floor's own colour cracked open (dark splits, not glowing), bigger rubble chunks thrown up and landing, one white hit flash, the team-coloured shockwave and landing ring kept, dust and chips; the dive pillar is white. Code: `client/Util/UpgradeFx/Updraft.luau` (`kitImpact`, `impact`, `startDive`, `stepDive`). The earlier "Updraft doesn't rise" was a mis-read (Bugs & Ideas U1, closed).

## Healing (Heal Orb) — ~6.5, left as is
The held orb (glowing core with orbit rings above the fist) and the self-heal screen cue (soft green edges + HEALING status) both read (captures `hold Heal Orb`, `heal self screen`). Not changed tonight; the heal-on-others leaves and Heal Zone were not seen.

## First-person holds — grades
| Mod | Grade | Notes |
|---|---|---|
| Recon (bow) | 3 → 7 | Rebuilt; see [Recon Bow Draw](2026-11-16%20Recon%20Bow%20Draw.md) |
| Molly | 6 → 7 | Canister scaled 1.3 (`ITEM_HOLDS.Molly.scale`): at 1 it read small, perched on the forearm's end |
| Frost | 6 → 7 | Same, scale 1.3 |
| Firewall hand flame | 4 → 6.5 | Stylised flame sheet (fire note) |
| Heal Orb | 6 | Unchanged |
| Stim, Recall, Dash, Updraft | not graded | Stim is instant, Recall's plant and Updraft were not reached (Updraft bug U1) |

## Not done tonight
- **Third-person poses and animations** can't be judged from one client (your own body is hidden in first person and dummies don't use Mods): needs the owner's 2-client test (handoff step 7).
- Impact (Crash Down, blocked by U1), teleport (Recall), shield (Barrier), Stim, the Dash / Updraft wind seen by others.

## Morning follow-up (2026-11-17, owner: "finish all. saved")
- **Recall:** the held anchor scaled 1.3 (same reason as Molly / Frost). The plant and the teleport work; for the caster the jump is only a violet tint (~5): the spec's closing violet edge bars are still to build.
- **Barrier, Stim, wind for others:** not reviewed.
- **Skinned-body fix (handoff step 2):** finished in the working tree, **not committed**: `Util/LimbHold` (an outlined body holds its skinned limbs inside it, so one Highlight traces the whole body; used by the Recon reveal and Ping Spike), `BodyClone.copy` re-attaches limbs, and the Desync decoy (`DashDecoy.copyOf`) now gets its own limbs. It depends on the skinned-limb system (`Config/Avatar` `LIMB_LINK` / `LIMB_HOLD`, `MatchBody.attachLimb`), which is itself still uncommitted in the third-person body lane; commit them together. Freeze Frame's box and Crash Recovery's ghost use the R15 parts, so they have no gap. The decoy's limbs were not seen in Play (the Desync window wasn't hit by key presses).
- **Studio:** the ability build leftovers in `ServerStorage.ImportStaging` (`Raw_*` and the staged copies of the six props and ReworkVFX) are deleted; the `*_Baseline` models stay for the 2-client before / after review; weapon staging untouched. `src/server/AbilityBuild/` deleted. The `.rbxm` backups could not be written from the MCP (its HttpService calls to 127.0.0.1 are blocked): run `tools/studio/abilities/BackupInstalled.luau` from the Command Bar with `receive_server.py` running. **Save the place again** (ImportStaging changed).
