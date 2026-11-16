# Handoff: build the three new free Mods (2026-11-17)

**Status: done 2026-11-17** (the owner said "when I get back I want all of the powers to be done"). What was built and what is left: [playtest](Playtests/2026-11-17%20Free%20Pack%20Build.md). Left for the owner: save the match place, the 2-client test, ChatGPT icons, Blender props if wanted.

For a new chat on **Opus 5.5**, once Studio is free. The spec is locked; this note is how to build it without re-exploring.

**Paste this to start the new chat:**
> Build the three new free abilities (Roller, Flash, Shock Dart). Read `CLAUDE.md`, then `vault/05 Production/Handoff - New Abilities.md`, and work through its phases in order. The spec is locked in `vault/04 Tech/Prompts/2026-11-17 New Abilities (Free Pack).md`. Opus for everything; follow the handoff's usage rules.

## The spec (read it first, it's small)
[2026-11-17 New Abilities (Free Pack)](../04%20Tech/Prompts/2026-11-17%20New%20Abilities%20(Free%20Pack).md): every level's numbers, the owner's 8 decisions, the per-Mod build steps and the done criteria. Nothing in it is still open.

| Mod | Key | Activation | L1 in one line | Glitch path |
|---|---|---|---|---|
| **Roller** | T (slot 3) | Hold, LMB to set down (new: a placed mover) | A bot rolls 14 studs/s for 5 s, turns at walls, locks on to enemies in a 60° cone within 25 studs, explodes 60 → 30 over 6 studs; 25 HP | Remote: press again to blow it up |
| **Flash** | Q (slot 1) | `HeldThrow` (LMB throw, RMB quick pop) | Pops 0.9 s after the throw; blinds everyone facing it within 30 studs, up to 1.75 s | Exposure: reveals instead of blinding |
| **Shock Dart** | E (slot 2) | `HeldCharge`, Recon's bow | Recon's flight and bounces; explodes on impact 50 → 25 over 5 studs | Static: Hinders instead of damage |

All three: 1 charge per round, no recharge at L1. 50% damage to your own team (`FRIENDLY_FIRE`). Free: in everyone's draft.

## Rules for this work
- **Opus 5.5 for everything** (`model: "opus"` for any agent). Haiku or Sonnet only for lookups and bookkeeping.
- **Lean:** one or two workers at a time; briefs name the files owned and the stop condition. Grep plus ranged reads; the [Code Map](../04%20Tech/Code%20Map.md) and [Ability Effects Map](../04%20Tech/Ability%20Effects%20Map.md) say which file owns what. Captures only when judging.
- **Never call `get_console_output`.** For errors, run a Client snippet that returns the last few errors from `LogService:GetLogHistory()`.
- **Live Blender MCP only** for models. New file: `art-source/abilities/FreePack/v01/FreePack_v01.blend`, one scene per prop (`FP_Roller`, `FP_Flash`, `FP_ShockBolt`); every call starts by exec-ing `tools/blender/rework/rw_core.py`; build style `gauntlet-build-style` (no round curves or spheres, carved ends).
- **RIVALS:** numbers and recipes only (skill `rivals-reference`). Never its assets.
- **Effects:** the locked [Ability VFX Direction](../02%20Art/Ability%20VFX%20Direction.md). Judge a grey and a colour capture of each effect before calling it done (the fire pass showed a literal spec build can look worse; memory "improve, don't replace"). Glitch magenta only as a two-frame accent on the glitch path's key moment.
- **One writer per file.** Several files carry other sessions' uncommitted work (for example the skinned-limb edits in `UpgradeFx/Recon.luau` and `UpgradeFx/DashDecoy.luau`, and `Simulation/Movement.luau`). Check `git diff --stat` before editing a shared file, and stage only your own hunks (stage-from-HEAD, as done for those two files on 2026-11-17). Stage exact paths, never `git add vault` or `-A`.

## Phases (each finished and checked in Play before the next)
**Phase 0: setup (short).** `git pull`; `git status` (note others' uncommitted files); `rojo serve` running; Studio match place (`list_roblox_studios`, the instance whose placeId is the match place) in Edit. Add the three entries to `Config/Mods.luau` (data first, with every level's `note` and `card` text) so the draft and dev panel can see them early.

**Phase 1: Shock Dart** (reuses the most).
- Server: copy the shape of `shared/Mods/Recon.luau` (charge, flight, bounces, `hp`), but on impact: radius damage with line of sight, no self damage. G2: Hinder via `StatusService` instead of damage. Damage path like Crash Down's `slamLanded` in `shared/Mods/Updraft.luau`.
- Client: the Recon bow hold and draw are data-driven (`ITEM_HOLDS.Recon`, `BOW`): give Shock Dart the same entries, a different bolt head part and an amber `Charge_Energy`. The burst is an electric impact (white-blue arcs, one flash, a flat team-coloured ring).
- Prop: a bolt head only (`FP_ShockBolt`); the bow model is a copy of `Abilities.Recon` with that head swapped in.
- Done: every level in Play with dummies; damage numbers checked against `HP`; Hinder at G2 / G3.

**Phase 2: Flash.**
- New status `Blinded` (`BlindedUntil`, strength 0..1) in `Config/StatusEffects`, written only by `StatusService`; a tray entry in `Util/StatusTray`.
- Server decides who is blinded: line-of-sight raycast from each player's head to the pop point, and the angle between the pop and their look direction (the server's copy of the camera that `WeaponService` uses for aim tolerance; Server Authority is off). Duration from the angle (1.75 s straight on, 0.6 s at 90°, none past 110°).
- Victim screen: our own stylised white-out (angled plates closing from the edges in 0.06 s, held, breaking away over 0.4 s), audio muffled. G2: the Recon reveal path (`ModReveal`, DETECTED) instead of a blind; G3: 5 s, through one wall.
- Prop `FP_Flash`: a faceted canister in hand (Molly-style hold, scale 1.3); throw and quick-pop use `ITEM_ACTIONS.Throw` / `Lob`.
- Done: blind from the front, the side and behind checked; teammates and the caster blinded when looking; bots stop aiming while blinded.

**Phase 3: Roller.**
- The server owns the bot: an anchored part stepped on the server (move, turn at walls by raycast, a floor check, lock-on cone with line of sight, a 0.4 s warning, explosion), replicated to clients that smooth it (like the thrown canisters: `shared/Projectile`, `ModFxController.onCanisterThrow`). It has 25 HP and can be shot (the weapon hit path must count it as a target).
- G2 Remote: a second press of the Roller's key while one is out blows it up (the Crash Down pattern: no charge spent).
- Prop `FP_Roller`: a faceted, wedge-shaped roller with an "eye" that turns team colour on lock-on; held and set down from the right hand.
- Bots (`server/Bots/BotMods.luau`): use it and shoot it.
- Done: turns at walls, locks on through the cone only, explodes with line of sight, can be shot down, every level checked.

**Phase 4: finish.** Sounds (`Config/ModSounds` hooks, placeholders listed in each spec note), icons (ChatGPT prompts for the owner, `vault/02 Art/UI Art Brief (ChatGPT).md`), third-person poses (`shared/Simulation/Poses.luau`), a security review of anything touching remotes, then the **2-client test** (ask the owner to start Test → Clients and Servers with 2 players). Vault: a spec note per Mod in `01 Design/Abilities/`, rows in `00 Abilities.md` and `Upgrade Paths.md`, Home status, Asset Tracker, Code Map, INDEX, a playtest note. Commit small steps, push at the end.

## Things that cost time before
- Health is the Humanoid attributes `HP` / `MaxHP`, not `Humanoid.Health`.
- The Edit datamodel isn't there while Studio is in Play: stage models between playtests.
- Drive tests from the Client datamodel: `game.ReplicatedStorage.Remotes.DevMod:FireServer("SetSlot", slot, id, level)` (it can take two tries; check the `Mod<n>Id` attribute), `("UnlimitedCharges", true)`, `("SpawnDummy", "Enemy")`, `("HurtSelf")`. Held Mods: press the key to raise, then LMB / RMB. Never `require` server modules from MCP code.
- **Captures:** the MCP ends a script's threads when the call returns, so "freeze when it appears" watchers fail. Set `Workspace.VfxTimeScale` to 0.15-0.3 before triggering (effects on `ReworkVfx.now()` slow down), then 0 in the next call, and pin the camera with `BindToRenderStep` at `RenderPriority.Last + 50`. Read positions within the same call: a check a few seconds later reads after the landing (the overnight "Updraft doesn't rise" scare was this).
- Uploads: `python tools/opencloud/upload_models.py --abilities --group 11116787 <Id>` (retry once on "Unknown Error"), then `python tools/studio/make_ability_build_data.py <Id>`, copy `tools/studio/abilities/*` to `src/server/AbilityBuild/` (git-ignored, delete after), and in Edit mode `require(...AbilityBuild.AbilityBuilder).stage("<Id>")`. **Compare the installed model with its Blender render**: the Recon limbs came in turned 180° (fix with `MESH_TURN_Y`).
- `.rbxm` backups can't be written from the MCP (its HttpService calls to 127.0.0.1 are blocked): the owner runs `tools/studio/abilities/BackupInstalled.luau` from the Command Bar with `receive_server.py` running (add the new ids to its list).
- Held items: forearms go down out of the frame; a block forearm pointed at the camera fills the screen. Scale items ~1.3 rather than bringing them closer.
- Neon draws a step brighter than its colour: darken Neon colours until they stop blooming.
- Remind the owner to **save the place** after any Studio change.
