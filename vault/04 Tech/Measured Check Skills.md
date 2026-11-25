# Measured checks (rbx-*)

Installed 2026-11-20 from `roblox-development-skills.zip` (55; 38 kept). **Moved 2026-11-25 from `.claude/skills/rbx-*` to `tools/checks/rbx-*`** (cleanup: as skills they put 38 lines into every chat's prompt and were almost never invoked; `tools/anim/tp_measure.py` is the only caller). Each folder has `README.md` (the recipe), `references/example.json` and `scripts/check.py`.

Use: capture real numbers from Studio or a playtest into a JSON file shaped like the example, run `python -I tools/checks/<name>/scripts/check.py capture.json`; it returns 0 (clean), 1 (findings) or 2 (bad input). They **measure**; they don't build. Our measured numbers and the Style Bible still win.

## Security scan (2026-11-20)
- The Python uses only the standard library, plus Pillow (texture preflight) and `bpy` (hair sampler, not installed). No network, shell, eval, env or credential access. Files are written only to the report path you pass in.
- Studio snippets in references only read transforms or markers and print JSON.
- No hidden Unicode, no prompt-injection text, no `allowed-tools` or hooks in the frontmatter.
- One note: `rbx-vfx-texture-preflight` suggests installing the free "VFX Studio" Creator Store plugin *if authorized*. Ask the owner first; never install it on its own.
- All fixtures run (Python 3.12, Pillow 12.3). `rbx-map-kit-audit` has no fixture; it takes a Studio snapshot.

## Which to use
| Area | Skills |
|---|---|
| Maps, lobby | `rbx-reference-coverage` (concept/RIVALS ref vs build), `rbx-map-kit-audit` (5-stud module seams), `rbx-route-clearance`, `rbx-spawn-travel-balance`, `rbx-prop-support-audit` (floating props), `rbx-streaming-reentry` (lobby prompts under StreamingEnabled) |
| Gun/Mod VFX | `rbx-impact-grounding`, `rbx-beam-span-continuity` (tracers, beams), `rbx-vfx-screen-overlap` (muzzle flash vs target), `rbx-vfx-cue-legibility` (low graphics), `rbx-particle-peak-budget`, `rbx-effect-window-audit` (FX left on after death/cancel), `rbx-vfx-texture-preflight` |
| Gameplay | `rbx-hit-feedback-agreement` (hitmarker vs server hit), `rbx-round-transition-audit`, `rbx-interaction-cardinality` (draft picks, buys), `rbx-replication-audience`, `rbx-character-resource-lifetime`, `rbx-camera-handoff-audit` (spectate/replay), `rbx-movement-course`, `rbx-npc-stuck-recovery` (bots) |
| Animation | `rbx-motion-breakdown` (start here), `rbx-curve-easing-audit` (oomph: snap/overshoot/settle), `rbx-animation-layer-conflicts`, `rbx-animation-loop-seam`, `rbx-foot-plant-drift`, `rbx-locomotion-rate-fit`, `rbx-rig-channel-coverage`, `rbx-dual-rig-contact` (hands staying on the gun) |
| Models, assets | `rbx-import-calibration` (Blender → Studio scale/facing), `rbx-asset-access-matrix` (Open Cloud assets that fail for players) |
| UI, audio | `rbx-ui-hit-bounds` (mobile safe area), `rbx-gamepad-focus-paths`, `rbx-ui-contrast-audit`, `rbx-audio-peak-audit` (layered gun audio), `rbx-spatial-audio-range` (gunshot falloff) |
| Performance | `rbx-frame-time-regression`, `rbx-instance-retention-audit` |

## Left out (17)
Hair (3), wearable clearance, cutscene/shot/screen-direction/prop-handoff (no cutscenes), checkpoints and gated routes (no obby), localized text (no localization), landmark sightlines, stair profile, UV texel density and material bindings (untextured faceted style), pivot sweep, phase retime. The ZIP stays in Downloads if any are needed later.
