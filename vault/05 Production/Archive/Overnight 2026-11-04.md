# Overnight 2026-11-04: lanes, contracts and rules

The user's brief for the night (summarised): make the game feel **fun, clean and professional**. Four lanes run as separate Claude sessions in the **same checkout**, coordinated from the core chat. Each lane writes its own result note; the core chat updates [Home](../../00%20Home.md) and the [Asset Tracker](../../06%20Assets/Asset%20Tracker.md) at the end.

## Art direction change (user, 2026-11-04)
- **Stylized and grounded, lower poly.** Rounded corners and bevels, simple readable shapes, smooth materials, a brighter and more saturated palette. Less tactical / realistic than now; not as toy-smooth as RIVALS. Valorant is a fair "detail level" reference (Valorant is lower-poly than the game is now).
- The game has moved away from heavy glitch / neon. Keep that theme only as a **subtle** accent.
- Signs and entrance text: **fun, bold, 3D**, not tactical stencils.
- Later (last task, not tonight unless everything else is done): redesign the same match maps with this style and new models. Map polish / lighting work is **on hold** until then.

## Lanes
| Lane | Session | Place / tools | Owns (write only these) |
|---|---|---|---|
| A. Lobby rebuild | `lobby-art` | Lobby Studio (edit mode), Blender | `art-source/lobby/**`, `tools/blender/*lobby*`, `tools/studio/lobby/**`, `vault/01 Design/Lobby*.md`, `vault/02 Art/Lobby*`, new Range brainstorm note |
| B. Lobby UI + queue | `lobby-ui` | Lobby Studio (play mode), Rojo 34873, Chrome (ChatGPT images), Figma | `src/lobby/**`, `lobby.project.json`, `assets/ui/lobby/**`, `vault/01 Design/Lobby UI*.md`, `vault/01 Design/Queue*.md` |
| C. AI bots | `bots` | Match Studio, Rojo 34872 | new `src/server/Services/Bot*.luau`, `src/server/Bots/**`, `src/shared/Config/Bots.luau`, match-side `TeleportData` reader, `vault/01 Design/Bots.md`. Minimal hooks in `MatchService` / `TestOpponent` |
| D. Animations + knife | `anim-knife` | Match Studio, Blender | `PoseController`, `CharacterFxController`, `src/shared/WeaponAnimations/**`, `Config/Animations.luau`, knife bits of `WeaponService` / `ViewmodelController` / `Config/Weapons.luau`, `GunSounds` knife entries, `art-source/animations/**` |

Shared files (`Net.luau`, `Types.luau`, `MatchService.luau`, `Config/Weapons.luau`): make the smallest edit possible, re-read the file right before editing, never reformat the whole file.

## Contracts between lanes
**World → UI (A → B).** Lobby art tags interactables with CollectionService; UI hooks them (ProximityPrompt or touch zone added by lane B's code, not by hand):
- `LobbyQueue` (attribute `Mode` optional: `"1v1"`, `"2v2"`, `"3v3"`): opens the queue menu.
- `LobbyShop`, `LobbyBattlePass`, `LobbyLocker`: open those panels (placeholders are fine).
- `LobbyRangeEntrance`: the Range doorway.
- `LobbySpawn`: spawn points.

**Lobby → Match (B → C).** Lobby teleports a party into a reserved Match server (`TeleportService:TeleportAsync` with `TeleportOptions.ReservedServerAccessCode`) with this `TeleportData` on every player:
```lua
{ v = 1, matchId = string, mode = "1v1" | "2v2" | "3v3", teams = { { number }, { number } }, -- userIds per team
  bots = boolean } -- true: fill missing slots in each team with bots
```
The match reads it from the first joining player (`Player:GetJoinData().TeleportData`), validates it (types, mode in the allowed set, team sizes ≤ mode size, userIds are numbers), waits a short grace for the listed players, then fills empty slots with bots. In Studio (no teleport) a dev attribute / Config value picks the mode and bot fill.
**Bot fill rule:** a player waiting longer than `Config.botFillAfter` (default 30 s; 5 s in Studio) gets a match with bots filling the slots.

**Bots ↔ Animations (C ↔ D).** Bots are NPC R15 rigs driven by the server through the **same** combat, movement and Mod code paths as players (server-authoritative). Third-person animation must play on bots too: lane D keys its pose system off the character model (attributes on the model or an `Owner` that can be a bot), lane C sets the same attributes the player path sets. If one lane needs the other's file, add a small hook and say so in the lane note.

## Rules for every lane
- **Vault and LihFolk first (user, 2026-11-05):** load `.claude/skills/gauntlet-vault/SKILL.md`, use the LihFolk notes and skills for your lane, and cite them in your lane note. See CLAUDE.md → "Work from the vault, not from memory".
- **User's quality rule:** don't be lazy or cut corners; research, use references, think it through, make it the best it can be. **Work in phases:** (1) plan with references, written in your note; (2) quick layout / blockout / prototype, screenshot or test it and critique it against the references; (3) then the full build and polish. Never go in blind.
- **Studio locks.** Two lanes share each Studio. Before **play mode** or a big build in a Studio, create `.claude-locks/<lobby|match>-studio.lock` containing your lane name and time; delete it when done (keep holds under ~15 min). If it exists and is younger than 20 min, work on something else and retry. Same for Blender: `.claude-locks/blender.lock`. Pick the Studio instance by placeId (Lobby 133387545285290, match 71551303511506).
- **Rojo.** Main game on port 34872, Lobby on 34873, both already serving. If Studio isn't connected (`ServerScriptService.Server` / `LobbyServer` missing), connect through the Rojo plugin with computer use, or note it for the user.
- **Never** `require` server modules through MCP (it breaks remotes); drive tests through remotes and attributes.
- **Git.** Commit small working steps on `main` with `git commit -m "..." -- <exact paths>` (path-limited, so another lane's staged files never ride along; for new files run `git add <exact paths>` first). Never `git add -A` / `git add vault`. Don't push; the core chat pushes. Don't commit `.rbxl`, `Packages/`, `.claude-locks/`, or third-party screenshots.
- **Quality bar.** `--!strict`, `selene` and `stylua --check` on the files you touched (format only your files), `rojo build` passes. Server-authoritative, validated remotes. Run a security review on anything with remotes.
- **Save the place** after Studio changes (Lobby and match), keep `.rbxm` backups as before; never publish.
- **Don't edit** `vault/00 Home.md` or `vault/06 Assets/Asset Tracker.md`; put your results in your lane note, ending with a short **"What the user should test tomorrow"** checklist.
- Use sub-agents for research (a lighter model is fine) and keep context lean.

## Lane notes
- A: [Lobby Rebuild 2026-11-04](../../02%20Art/Lobby%20Rebuild%202026-11-04.md)
- B: [Lobby UI and Queue](../../01%20Design/Lobby%20UI%20and%20Queue.md)
- C: [Bots](../../01%20Design/Bots.md)
- D: [Third-person Animation and Knife Pass](../Playtests/2026-11-04%20Animation%20and%20Knife%20Pass.md)
