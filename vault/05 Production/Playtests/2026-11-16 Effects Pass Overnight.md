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

## Deviations from the locked spec (recorded 2026-11-17)
| Where | Spec | Now | Why |
|---|---|---|---|
| Fire (Molly, Firewall, Fork Fire patches) | F1-F7 faceted tongues, team ring | The old FireKit mesh fire, darker Neon tones, no team ring | Owner: "the ones before were better" (Fire Element Pass 1) |
| Scan (Recon pulse) | S1: 3 nested shells | The floor band (darker) + one faceted dome | One dome reads; three stacked looked like a glow |
| Ice (Frost) | I1-I6 plates, cap, star front | IceKit crystals and patch, held for the Hinder then shattered; corners stand-in | Improve the existing look |
| Crash Down impact | X1-X7 (ReworkVFX chunks, FX_FloorStar crack) | GlitchVFX cracks (floor-coloured) and rubble, white flash, team ring | Same read with the installed kit |
| Updraft / Dash wind for others | White (W1-W3) | Team-tinted (`ModFeelController` → `WindFx`) | Not changed yet |
| Heal Orb | H1-H5 leaves, crowns | Old sparkle burst + quad ring, green screen edges | Not changed yet |
| Stim | Amber `FFC83D`, chevrons | Yellow `FFD23F`, arcs and sparks | Owner had not asked for the colour change |
| Recall caster cue | Violet edge bars | A violet tint | Not built yet |

## Final review (Fable, 2026-11-17) and what was done
The base effects reworked tonight match the spec or deviate with a record. Glitch-path upgrades still carry **sustained magenta** where the spec allows only a two-frame accent on four beats. Fixed now: Fork Fire bomblets burn as normal fire (fire-coloured sparks, light, trail; the split keeps its accent), the armed Recall anchor and the Crash Recovery arrival ring are violet, and the stale magenta comments in `UpgradeFx/Updraft.luau` are gone.

**Still open (next pass, in this order):**
1. `UpgradeFx/Recon.luau` (Ping Spike): team colour for highlights, shells, label; magenta only on the wave front (`stepWaves`).
2. Sustained magenta static and flicker in `BarrierFx.luau` (`GLITCH_SCALE`), `FrostWallFx.luau`, `UpgradeFx/Frost.luau` (Freeze Frame), `UpgradeFx/Stim.luau` (Heal Zone): these get no glitch beat.
3. `RecallCrash.luau` departure and `DashDecoy` Desync exit: cut to the two-frame doubled-shape accent (no screen tears, no 0.3 s static).
4. The Crash Down prompt (`UpgradeFx/Updraft.luau` `buildPrompt`): magenta text and a round `UICorner` button, against the UI theme.

## Glitch magenta cleanup (2026-11-17, owner: "Yes, do it")
Magenta is now only the spec's four short accents. Every file below checked with lint and build; Barrier and Ping Spike seen in Play (captures `barrier 1/2`, `ping spike after`).
| Upgrade | Before | After |
|---|---|---|
| Ping Spike (`UpgradeFx/Recon`) | Highlights, bands, rings, ground scan, label, screen tint all magenta | Team colour (enemy colour on the revealed), white stutter frames and label; magenta only as a rare one-frame flick on the wave front |
| Barrier (`BarrierFx`) | A magenta static shell, magenta pixels and flickers; panels 0.62 transparency, a glaring opaque egg (4/10) | No static shell; flickers and pixels white, pixels only on a hit's flicker frames; panels 0.84 / frame 0.4, darkened Neon: a see-through hex shield with the player visible (7/10) |
| Frost Wall (`FrostWallFx`) | Each piece glitched magenta every 0.5-1.8 s | No recurring glitch; leftover accents ice white |
| Freeze Frame (`UpgradeFx/Frost`) | Magenta flickers, rings, pixels, screen bars | All of those ice white (glints) |
| Heal Zone (`UpgradeFx/Stim`) | Magenta static pixels, screen-tear scanlines, flickering coil | Pixels and tears removed; flickers pale heal green |
| Crash Recovery (`UpgradeFx/RecallCrash`) | ~1 s of tears, scatter, a blue "fatal error" screen over the centre, magenta scanlines | Tears and scatter for the two-frame accent only; no fatal-error screen or scanlines; violet otherwise; magenta sparkle burst at the departure |
| Desync exit (`UpgradeFx/DashDecoy`) | 0.3 s of magenta static, a magenta pixel pop | Two frames of magenta static, then a violet pinch (0.2 s exit) |
| Crash Down prompt (`UpgradeFx/Updraft`) | Magenta words with a cyan split, magenta ring on the touch button | White words, the touch ring in ally cyan (circles with rings are in the UI theme) |

**Note for the body lane:** `UpgradeFx/Recon.luau` and `UpgradeFx/DashDecoy.luau` were committed with only these colour hunks; their skinned-limb (`LimbHold`, `MatchBody.attachLimb`) edits are still in the working tree, waiting for the skinned-limb system.
