# Handoff: ability rework, continue in a pure Opus chat (2026-11-16)

For a new chat on **Opus 5.5**. The previous parent chat ran on Fable and used too much. Everything you need is here and in the notes it links: do not re-explore.

**Paste this to start the new chat:**
> Continue the ability rework. Read `CLAUDE.md`, then `vault/05 Production/Handoff - Ability Rework (Opus).md`, and carry on from its "What is left" list in order. Opus for everything; follow its usage rules.

## Rules for this work (owner, 2026-11-16)
- **Opus 5.5 for everything**, this chat and every agent or session (`model: "opus"`). Haiku / Sonnet for lookups and bookkeeping. **Fable only once more:** the final consistency review before handing back (one agent, tight brief).
- **Lean:** one or two workers at a time, never a crowd. Briefs name the files owned and the stop condition. Grep plus ranged reads. Captures only when judging. No polling Studio: check state once, do other work, try later.
- **Never call `get_console_output`** (it returns a huge dump). For errors, run a Client snippet that returns the last few error messages from `LogService:GetLogHistory()`.
- **Live Blender MCP is the only Blender path.** Open file must be `art-source/abilities/Rework/v03/AbilityRework_v03.blend`; one scene per prop (`RW_MollyFrost`, `RW_Recon`, `RW_Stim`, `RW_Recall`, `RW_VFX`); every call starts by exec-ing `tools/blender/rework/rw_core.py`. If Blender was restarted the scenes are gone: rebuild from each prop's script (`Rework/v03/<Mod>/<mod>_build.py`, `ReworkVFX/vfx_kit.py`) through the live MCP.
- **RIVALS:** numbers and recipes only (skill `rivals-reference`). Never its textures, meshes, sounds or scripts.
- Brief and follow-up: [2026-11-15 Ability Rework](../04%20Tech/Prompts/2026-11-15%20Ability%20Rework.md), [2026-11-16 Follow-up](../04%20Tech/Prompts/2026-11-16%20Ability%20Rework%20Follow-up.md).

## Read these, nothing else to start
| Note | What it gives you |
|---|---|
| [Ability Rework 2026-11-15](Ability%20Rework%202026-11-15.md) | Plan, everything done so far with measurements, prop table with captures |
| [Ability VFX Direction](../02%20Art/Ability%20VFX%20Direction.md) | The **locked** effects spec: layer kits, per-Mod beats, mesh list, texture set with ChatGPT prompts |
| [Ability Effects Map](../04%20Tech/Ability%20Effects%20Map.md) | File and function for every Mod's effect |
| [Ability VFX Numbers](../03%20Research/Rivals%20Reference/Ability%20VFX%20Numbers.md) | Measured RIVALS layers and numbers per Mod |

## Where things stand
- **Git:** `b937dd10` (day 1) and `c0c0f57e` (day 2) on main, **not pushed**. Shared files in those commits also carry other sessions' edits.
- **Not committed, unverified:** the interrupted skinned-body pass left partial edits in `src/client/Controllers/ModFxController.luau`, `src/client/Util/UpgradeFx/Recon.luau`, `src/client/Util/BodyClone.luau` (check `git diff --stat` on them first). Lint and build pass.
- **Studio match place** (`studio_id 7e67897b-58ba-433d-8063-55e547fe65cd`): **not saved.** `ReplicatedStorage.Abilities` holds the new `Molly`, `Frost`, `Recon`, `ReconDart`, `Stim`, `Recall` and the kit `ReworkVFX`. The old models are in `ServerStorage.ImportStaging` as `<Id>_Baseline` (use them for before / after captures). `.rbxm` backups are not written. `src/server/AbilityBuild/` (temporary, git-ignored) is still there for the builder.
- **Asset ids:** `art-source/abilities/Exports/assets.json` (`ReworkVFX` = 139137930819171). Wind stroke texture `rbxassetid://118728636893673`.

## Done
| Area | State | Checked in Play? |
|---|---|---|
| Crash Down on a second Updraft press, 16 studs/s carry | In | Yes, one client |
| ModSim report path (Server Authority off: slam damage, Ghost window, mirrors to other clients), security review fixed | In | Slam damage and fake reports yes; Ghost and mirrors no (need 2 clients) |
| Dash L1 16 / A2 22 / A3 28 | In | Measured; needs the owner's feel check |
| `Bodies` collision group | In | Group applied; walk-through not tested |
| Ability hits: marker only, nothing on hidden victims | In | No |
| HEALING and DETECTED statuses | In | No |
| Recon bounces cycle during the draw | In | Yes |
| Wind strokes for Dash, slide, Updraft, Ghost cue | In | Mostly; final 7-stroke Updraft and the cloak cue not seen |
| Six props + bolt, built, uploaded, installed | In | In hand / placed, yes |
| First-person holds, Molly / Frost moving parts, throws, Stim toss 8 studs, Recall twist, Firewall push | In | Yes except Firewall's push |
| Recon bow: canted hold, charge-driven draw, release twang, pips | In | Yes (agent's grade 7/10) |
| VFX mesh kit (19 meshes) + `T_FlameSheet.png` | Built, staged in Studio | Not used by any effect yet |

## What is left, in order
**Progress (2026-11-16, Opus):** step 1 started. Kit module `ReworkVfx`, fire module `FireFx`, `T_FlameSheet` uploaded, six texture **stand-ins** uploaded. Molly patch, Fork Fire split and burning bodies built; Owner judged the shard patch worse than the old fire, so pass 2 went back to the old `FireKit` mesh fire and improved it (colour depth, hot middle, a mound) → [Fire Element Pass 1](Playtests/2026-11-16%20Fire%20Element%20Pass%201.md) → Pass 2. **Lesson for every element:** start from the existing look that works and improve it; don't swap it for a literal build of the spec. **Waiting on the owner:** OK pass 2. Firewall not started.

1. **Effects, one element at a time, fire first** (the owner signs off a greyscale capture per element before the next starts).
   - Write one small client kit module for `Abilities.ReworkVFX` (same pattern as `client/Util/GlitchVfx.luau`: `ready`, `take`, `give`, `piece`).
   - Upload `art-source/abilities/Rework/v03/Textures/T_FlameSheet.png` with `tools/opencloud/upload_asset.py` and add its key to `Config/VfxTextures.luau`.
   - Six textures come from the owner's ChatGPT runs (prompts in the spec's "Texture set"). Until they arrive, make plain stand-ins with Pillow under `Rework/v03/Textures/` and say so.
   - Order: fire (Molly patch, burning licks, Fork Fire split, Firewall curtain and hand flame), ice (Frost impact, Frost Wall, Freeze Frame shell), impact (Crash Down), scan (Recon pulse, Ping Spike), healing (Heal Orb hold and cue, Heal Zone), teleport (Recall, Crash Recovery), shield (Barrier), then what other players see of Dash and Updraft. Keep Stim's existing yellow `FFD23F` (the spec says amber `FFC83D`; the owner has not asked for the change).
2. **Skinned-body fix.** The skinned limbs (`GGSkinLimb` in `Workspace.GGBodyLimbs`) are outside the character Model. Recon's outline is one Highlight on the Model, so limbs are missed; `DashDecoy.copyOf` never re-attaches limbs (`BodyClone.copy` does, via `MatchBody.attachLimb`). Finish or redo the partial diff, then check Freeze Frame's box and Crash Recovery's ghost for the same gap.
3. **Polish found by the passes:** Recon bow (the block arms hide too much; bolt head sits by the charge meter); Firewall push not confirmed by eye; Molly latch opens 45° (brief wanted 60°+; it hid behind the fist at 65°); back-dash stroke tails start at the aim-area edge.
4. **Third person:** poses and clips for the new holds and the bow (`tools/anim/tp_clips.py`, `shared/Simulation/Poses.luau`, `Config/Animations.luau`).
5. **Gameplay still open in the brief:** Crash Down 8 vs 10 stud radius and the damage trial; Crash Down anticipation and landing pose; Barrier world shield; Recall Crash Recovery beat; anything in the brief's per-Mod list not in the Done table.
6. **Studio wrap-up (after the owner's yes on the props):** run `receive_server.py`, `B.publish(<Id>)` for each prop to write the `.rbxm` backups, delete `ImportStaging` leftovers and `src/server/AbilityBuild/`, remind the owner to save the place.
7. **Two-client verification.** The MCP cannot start it: ask the owner to run Test → Clients and Servers with 2 players, then drive both. Cover the Play-unchecked rows above, every Mod at L1 and each distinct upgrade, re-equip and respawn cleanup. Before / after captures per Mod, a review note in `05 Production/Playtests/`.
8. **Vault and git:** Home status, Asset Tracker rows, Code Map lines for `WindStrokes` and the new viewmodel calls; stale text in `01 Design/Abilities/Updraft.md` (still says C / crouch near lines 97 and 112) and the "150% / 200%" Dash line in Upgrade Paths; push.
9. **One Fable agent:** the final consistency review of all nine Mods against the locked spec.

## Things that cost time once already
- Health is on the Humanoid as attributes `HP` / `MaxHP`, not `Humanoid.Health`.
- The Edit datamodel is not available while Studio is in Play; stage models between playtests.
- Drive tests with real key presses and the dev remote from the Client datamodel: `game.ReplicatedStorage.Remotes.DevMod:FireServer("SetSlot", slot, id, level)`, `("UnlimitedCharges", bool)`, `("RefillCharges")`, `("SpawnDummy", "Enemy" | "Ally")`, `("HurtSelf")`. Never `require` server modules from MCP code.
- The Studio builder keeps only the **position** of locators and puts them on `Root`: they do not rotate or move with parts. Compute hinge axes and moved tips in code.
- Uploads: `python tools/opencloud/upload_models.py --abilities --group 11116787 <Id>` (key is in the environment). A first try can fail with "Unknown Error": retry once. Then `python tools/studio/make_ability_build_data.py <Id>`, copy `tools/studio/abilities/*` to `src/server/AbilityBuild/`, and in Edit mode `require(...AbilityBuild.AbilityBuilder).stage("<Id>")`.
- Two sessions writing the same big file is how the gesture pass broke held items: one writer per file, and after any interrupted worker check Play before building on it.
