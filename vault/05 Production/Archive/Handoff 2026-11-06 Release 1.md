# Handoff: Release 1, a fully functional game (2026-11-06)

This is for a new Claude chat starting the **Release 1 functionality** phase. Read it once, then **wait for the user's instructions**. The user says where to start and how each system should work. Don't pick a system and start building on your own.

## 1. The game
- A Roblox competitive shooter: RIVALS-style run-and-gun duels (1v1 up to 4v4).
- Every round, players **draft abilities ("Mods")**, and each round opens a shared **weapon tier**.
- Built with Rojo and strict Luau by a solo developer (the user) working with Claude.
- Two places in one experience:

  | Place | PlaceId |
  |---|---|
  | Lobby | 71551303511506 |
  | Match | 133387545285290 |
- The design is locked in [Game Plan](../Game%20Plan.md) §1. The match rules are in [Match Flow](../../01%20Design/Match%20Flow.md), [Gunplay](../../01%20Design/Gunplay.md) and [Weapons](../../01%20Design/Weapons.md).

## 2. The goal of this phase
**Get a complete, working game that's good enough for release 1. Professional polish comes after.**

Map art, UI looks, avatar holds and extra polish are **parked**. The user works in phases: only what the user picks gets done now, and other ideas go into [Bugs & Ideas](../Bugs%20%26%20Ideas.md).

## 3. How to work (mandatory, every task and every agent brief)
1. **Read [CLAUDE.md](../../../CLAUDE.md)** for the code rules:
   - strict Luau, server-authoritative;
   - validated, rate-limited remotes;
   - numbers live in `src/shared/Config`;
   - no `_G` or `wait()`;
   - services and controllers follow the same pattern.
2. **Load the `gauntlet-vault` skill** (`.claude/skills/gauntlet-vault/SKILL.md`) before any task. It maps each task to the right notes.
3. **Check LihFolk before non-trivial Roblox work:**
   - the `lihfolk` router skill or the `lihfolk-lookup` agent, plus the specialist skills: `roblox-system-builder`, `roblox-secure-remotes`, `roblox-datastore-safety`, `roblox-ui-builder`, `lihfolk-tutorial` and others;
   - the notes are in `vault/LihFolk/`.

   Project notes and measured numbers win over general advice. Cite the notes you used.
4. **Plans, specs and results go into the vault**, before and after the work. Afterwards, update [Home](../../00%20Home.md) → Status.
5. **Run a security review** on anything that touches remotes, using `roblox-secure-remotes` or the `roblox-dev:roblox-reviewer` agent.
6. **Put these rules in any agent or session brief you write.**

## 4. Where things stand (read [Home](../../00%20Home.md) → Status for detail)
**Working:**
- Gunplay: client-detected and server-validated hitscan, with lag compensation, recoil patterns, and a crosshair that shows the real spread.
- Weapons and tiers, the knife, the Mods and draft system, and the round loop.
- AI bots, plus bot fill in the Lobby queue.
- Lobby queue and teleport. The PlaceId bug is fixed.
- The match HUD (v1 look), the match avatar (standard blocky R15), and real-recording gun sounds.

**Maps:**
- All 7 maps were rebuilt overnight as `<Map>2` versions. They're ForceMap only: set the Workspace attribute `ForceMap` to the id. The old maps and the pool are untouched.
- The spec is [Map Quality Standard](../../01%20Design/Maps/Map%20Quality%20Standard.md). Scores are in [Overnight Maps Approval](../Playtests/2026-11-06%20Overnight%20Maps%20Approval.md); Rooftops2 is best at 8.3. **The maps are parked**, and the release map pool is the user's call.

**Missing for release 1** (from [Game Plan](../Game%20Plan.md) §8 "Public beta" and [LihFolk Gap Review 2026-11-05](../LihFolk%20Gap%20Review%202026-11-05.md)):

| Item | What's missing |
|---|---|
| Saved player data and settings | There's no DataStore yet, so nothing survives a rejoin |
| Match end loop | No summary, no Rematch or Back to Lobby; the match server just starts a new match |
| Death recap and spectate | Recap of the kill, then watch teammates in 2v2 and 3v3 |
| Leavers and reconnects | A bot takes over the leaver's slot |
| First session | A new player in a bot fight within about 20 s, with one-line tips |
| Teammate markers | Hard to tell friend from foe in team modes |
| Settings menu | Sensitivity, hold or toggle for ADS and sprint, audio sliders, ping |
| Simple progression | XP and a level. Shop and season pass are Season 1 |
| Analytics funnel | Join → first match → second match, plus pick rates |
| Shadow anti-cheat signals | Flag only, never act |
| Two-client, lag and real-phone test pass | Needs the user in Studio |

The **user decides the order** and how each one works. This list is context, not a to-do you start on your own.

## 5. Practical rules and gotchas
**Git:**
- Commit small, working steps on `main` with path-limited adds: `git add "<exact paths>"`.
- **Never `git add -A` or `git add vault`.** The vault holds third-party screenshots and the repo is public.
- Don't commit `.rbxl`, `Packages/` or secrets.
- Don't touch the user's uncommitted `art-source/weapons/GunTest.blend` or `tools/studio/maps/Snowpeak/Art.luau`.
- Push at the end of a session.

**Studio:**
- Pick the instance by content (`ServerScriptService.Server` for the match, `LobbyServer` for the Lobby), not by its label. Confirm with `game.PlaceId`.
- **Never `require` server modules over the Studio MCP.** It breaks the remotes. Drive tests through remotes and attributes.
- If other sessions share Studio, take `.claude-locks/match-studio.lock` (or `lobby-studio.lock`) in windows of about 15 minutes. Re-read the lock before each write.
- **Never publish.** Saving is Ctrl+S, which is Save to Roblox only; confirm "Saved new changes" in Output.
- Remind the user to save after Studio-side changes.

**Rojo:**
- Rojo owns `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets`, `ServerScriptService.Server` and `StarterPlayerScripts.Client`. Change files, never those instances in Studio.
- Guns live in the Studio-owned `ReplicatedStorage.Weapons`.

**Checks:**
- `stylua --check src`, `selene src`, and `rojo build -o build.rbxl` as a build check.

**The user:**
- **Never type credentials**; the user signs in themselves.
- Keep usage lean: tight agent briefs and no wasted screenshots.
- No rounded, "AI-looking" UI. New screens use the current v1 style until the user picks a UI direction.

**Codex:**
- The user's ChatGPT/Codex desktop app is a collaborator for images and Blender models. It isn't needed for functionality work.
- Rules are in [Codex Collaboration](../../04%20Tech/Codex%20Collaboration.md).

## 6. First move in the new chat
1. Load `gauntlet-vault`.
2. Skim Home → Status, [Architecture](../../04%20Tech/Architecture.md), [Match Flow](../../01%20Design/Match%20Flow.md) and this note.
3. Tell the user in a few lines that you're up to speed.
4. **Wait for their instructions.**
