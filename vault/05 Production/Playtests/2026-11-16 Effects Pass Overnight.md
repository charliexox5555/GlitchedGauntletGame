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

## Impact (Crash Down) — not reviewed
Blocked: Updraft casts but the body doesn't rise in a fresh Play (Bugs & Ideas U1; another session's uncommitted `Simulation/Movement.luau`), so there is no slam to look at.
