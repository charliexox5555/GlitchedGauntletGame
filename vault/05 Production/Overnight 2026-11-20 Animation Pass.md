# Overnight 2026-11-20: animation pass (third person + first person)

The owner asked for this before bed on 2026-11-20. The goal is to clean up and perfect every animation, in third person and first person, until the whole of gunplay feels seamless and top quality. Each item gets a grade, and the target is **9-10**. The main chat coordinates three lane sessions, and each lane writes its results into its own section below.

## The owner's request (summary of his words)
1. **Third person.** "Mainly good". Clean everything up so it works nicely, using the new animation skills (the `rbx-*` measured checks), and fix anything that doesn't look right. Then study the RIVALS starter character body in the open RIVALS file (its animations are private, so study the structure only) and see where ours can improve. "RIVALS is the top standard". Redoing animations is fine.
2. **First person.**
   - Improve every first-person animation so it is seamless and as high quality as possible: gun animations, inspects, ADS, transitions, gunplay as a whole.
   - Some knives have their own animations, and the **Ruin-Blighted** line has its own animations for nearly everything. Both are in this pass. The Ruin-Blighted knife (**Ruined Reaver**) "is too clunky and does not feel good".
   - **Slide:** the slide now rolls the crosshair and the screen a little. The viewmodel must follow that roll so it looks seamless.
   - **ADS:** smoother, and it should tilt with the crosshair too (sniper ADS as well).
   - **Sniper scope bug:** in ADS, a part of the scope that is not fully transparent and looks reflective shows in the middle of the view. Fix it so it never happens.
   - **Melee:** the base knife is good, so polish it like the rest. The **Bat**, **Fan** and **Reaver** must look much better and feel nicer.
   - **Mods:** the Mod animations should look better (the **bow** is named), all brought up to the same quality.

## The owner's answers (2026-11-20, before bed)
- **RIVALS body:** prototype the RIVALS approach behind a **toggle**: their own-R15 IK hands driven from the viewmodel grips (see [Body, Viewmodel, Guns and VFX](../03%20Research/Rivals%20Reference/Body,%20Viewmodel,%20Guns%20and%20VFX.md)). Grade it against our current clips from the dummy angle. **Don't remove what exists.** He picks in the morning.
- **Git:** each lane **commits small working steps locally on main**, staging exact paths only (never `git add -A` or `vault`). **No push**; the owner pushes.
- **Lanes:** three sessions at once, sharing Studio through a lock file (rules below).
- **What's clunky on the knife and Reaver:** **stiff, posed keys** (pose-to-pose holds and turns that look staged), **camera and screen feel** (not enough lead, punch or follow-through), and **hold and framing** (where the blade sits on screen and how the arms frame it). Speed and wind-up were *not* named.

## Grade system (every lane uses this)
Grade each item 0-10 from evidence only. A feel item gets a provisional grade until the owner plays it.

| Grade | Means |
|---|---|
| 10 | Matches RIVALS / Valorant at gameplay speed. Every measured check passes: no seam jump, easing as intended with deliberate overshoot only, no clipping, no foot slide, no pop at transitions |
| 9 | Pro quality, one small nit left that a player would barely notice |
| 7-8 | Good, but a visible issue remains (a staged hold, a small pop, a wrong frame) |
| 5-6 | Works, but stiff, linear, janky or off-model |
| <5 | Broken or clearly wrong |

For each item, record: **Before → After**, the **evidence** (the `rbx-*` checker JSON, numbers, a capture described in words), and **what is not verified**. Score built animation with `lihfolk:quality-score` (minimum 8.5) where it fits. Keep going on an item until it reaches 9, or write down exactly what blocks it.

**Measured-check skills to use** (`vault/04 Tech/Measured Check Skills.md`): `rbx-motion-breakdown`, `rbx-curve-easing-audit`, `rbx-animation-loop-seam`, `rbx-animation-layer-conflicts`, `rbx-rig-channel-coverage`, `rbx-foot-plant-drift`, `rbx-locomotion-rate-fit`, `rbx-camera-handoff-audit`, `rbx-effect-window-audit`, `rbx-dual-rig-contact`. Capture real data and run each checker. If a skill gives a wrong or useless result on our rig, **fix the skill** (`.claude/skills/rbx-*/`) and write down what changed. The owner asked to "perfect" them.

## Lanes
| Lane | Session | Owns (only edit these) |
|---|---|---|
| **TP: third person** | `anim-tp` | `tools/anim/tp_*.py`, the third-person clip ids in `Config/Animations.luau`, `Controllers/BodySkinController.luau`, `Controllers/PoseController.luau`, `shared/MatchBody*`, `Simulation/Poses.luau`, the new IK prototype module and its `Config` toggle. RIVALS file: read-only |
| **FP: guns, ADS, slide, scope** | `anim-fp-guns` | `Config/Viewmodel.luau`, `Controllers/ViewmodelController.luau` (gun parts only, not the melee/Mod blocks), `Util/ViewmodelMotion.luau`, `shared/WeaponAnimations/*` (not `Knife.luau`), `Util/ShadowMist*.luau`, `Config/RuinBlightedPresentation.luau` (gun parts), `Util/Crosshair.luau`, `Config/Crosshair.luau`, `Util/ScopeOverlay.luau`, `Config/Scope.luau`, `Controllers/CameraController.luau` (slide/ADS roll only), and the sniper scope parts in Studio `ReplicatedStorage.Weapons` (plus the `.rbxm` backup) |
| **MELEE + MODS** | `anim-melee-mods` | `shared/WeaponAnimations/Knife.luau`, `tools/studio/knife_fp_keys.py`, `Util/PopCircuitBat.luau`, `Util/FanMotion.luau`, `Util/RuinedReaver.luau`, `Util/KnifeSwipeFx.luau`, `Config/MeleeSkins.luau`, the knife/bat/fan/Reaver and Mod blocks in `ViewmodelController.luau`, the Mod first-person parts in `Controllers/ModController.luau`, `Controllers/ModFeelController.luau`, the Mod entries in `Config/Viewmodel.luau` and `Config/Animations.luau` |

`ViewmodelController.luau` (3,074 lines) and `Config/Viewmodel.luau` are shared by FP and MELEE. Use small `Edit`s inside your own blocks, never a rewrite. Re-read the range just before you edit it, because the other lane may have changed the file. Run `stylua` on that file only, and only after the other lane's work there is committed or untouched.

## Shared rules (all lanes)
- **The vault rule:** load the `gauntlet-vault` skill first. Look things up in LihFolk before non-trivial work (`lihfolk-lookup` agent; `08 Animation`, `47 Game Feel and Juice`, `18 Rigs and Skeletons`). Query notes, don't load them whole (CLAUDE.md → Read lean). Cite the notes you used.
- **The owner's taste** (don't argue it again): memories `animation-oomph` (coil, ~60 ms snap, brake, overshoot, settle; PCHIP splines; holds keep moving), `viewmodel-arms-style`, `third-person-body-taste`, `improve-not-replace-vfx`, `weapon-art-bar`. Research: [Animation Flow and Feel Research](../03%20Research/Animation%20Flow%20and%20Feel%20Research%20(2026-11-14).md) and its checklist. Past state: [Feel Polish handoff](Handoff%20-%20Feel%20Polish%20(Fable).md), [Third Person Overhaul](../01%20Design/Third%20Person%20Overhaul.md) (read by section).
- **Studio:** the match place is PlaceId 133387545285290. Pick the instance by `list_roblox_studios`. The RIVALS file is **read-only**: never play it, save it or require its modules, and never copy its assets or scripts. Leave the Lobby Studio alone (the owner left it in Play).
- **Studio lock:** before `start_stop_play` or any edit in the match place, check `C:\Users\charl\Documents\GauntletGame\studio-lock.txt`. If it is empty, or missing, or older than 25 minutes, write `<lane> <ISO time>` into it. Otherwise do non-Studio work and check again later (no tight polling loop). Clear the file when you're done. Keep each hold under about 20 minutes, and stop your playtest before you release. Inspecting the RIVALS file needs no lock.
- **Playtests:** drive them from the Client datamodel through remotes and attributes. Never `require` server modules (memory `mcp-require-breaks-remotes`). Testing the stock knife needs `PreviewSkinLine("Prism")` first (memory `knife-test-needs-flat-skin-line`); put it back to "Stock" after. Don't change the saved `Skin_*` attributes.
- **Blender MCP** is on port **9897**. Only one lane at a time: use the same lock idea with `C:\Users\charl\Documents\GauntletGame\blender-lock.txt`.
- **Code rules:** `--!strict`, numbers in `Config`, clean up connections. Run `selene src` and `rojo build -o build.rbxl` before each commit.
- **Commits:** small, working, local on main, staging exact paths only. Use the Co-Authored-By line. **No push.** Never stage `third-party/` or reference screenshots.
- **Usage:** Opus 5.5 for everything (memory `token-efficiency`). Keep subagents lean with tight briefs. Take only the screenshots you need. Don't poll in loops.
- **Write-up:** results go in your lane's section below, plus a playtest note `05 Production/Playtests/2026-11-21 <Lane>.md` with a "what to test" list for the owner. Asset Tracker rows if assets changed. The main chat updates Home.

## Lane results
### TP: third person
_(anim-tp writes here: grade table before → after, RIVALS body findings, IK toggle prototype and how to switch it, what's not verified)_

### FP: guns, ADS, slide, scope
_(anim-fp-guns writes here)_

### MELEE + MODS
_(anim-melee-mods writes here)_
