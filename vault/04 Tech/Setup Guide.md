# Setup guide for Glitched Gauntlet

Use the repository root for Codex, your editor and PowerShell. Open its `vault/` subfolder as the Obsidian vault. Both places live in this one checkout. See the [Developer Handoff](Developer%20Handoff.md) for the game walkthrough and edit map.

## 1. Get the checkout and toolchain

For a new machine, clone the existing repository and open the folder it creates. On this machine the checkout and tools are already present.

```powershell
git clone https://github.com/charliexox5555/GlitchedGauntletGame.git
Set-Location GlitchedGauntletGame
rokit install
rojo plugin install
rojo --version
```

`rokit.toml` pins Rojo 7.4.4, Wally 0.3.2, Selene 0.27.1 and StyLua 0.20.0. The VS Code Luau Language Server extension is optional. Use Roblox Studio for scenes and Blender for the source models.

## 2. Connect the right place

Open the existing Lobby and Match places from experience `10772880160`. Use one PowerShell terminal per server from the repo root.

| Place | Place ID | PowerShell | Address in the Studio Rojo plugin |
|---|---|---|---|
| The game (lobby + match, one place since 2026-11-21) | `71551303511506` | `rojo serve` (`default.project.json`) | `127.0.0.1:34873` |
| ~~Match~~ (retired; project in `archive/`) | `133387545285290` | none | none |

In each window select **Plugins → Rojo → Connect**, confirm the project name and review the proposed sync. For Match, check `ServerScriptService.Server`, `StarterPlayerScripts.Client` and `ReplicatedFirst.Loading.LoadingScreen`. For Lobby, check `LobbyServer`, `LobbyClient` and `ReplicatedStorage.Lobby`. Both should have `ReplicatedStorage.Shared`.

There are separate connections for live editing and inspection. **Rojo** streams mapped files to Studio. **Roblox Studio MCP** queries the open place or runs a deliberate Studio action. The MCP server responded for both places in the audit. If a name is blank or seems ambiguous, query `game.PlaceId` and the DataModel mode. Reopen or reconnect the intended Studio instance if it is missing. Use Edit for the currently open scene and Client/Server when examining a running test.

The scene lives in Studio. Use the proper source, builder and Studio templates for geometry, GUI instances, guns, skin models and ability meshes. Review extra children inside mapped trees before changing the sync. The open Match held Studio-only weapon build data under its mapped Server root.

## 3. Use Obsidian and Codex together

1. In Obsidian, select **Open folder as vault** and choose `GlitchedGauntletGame/vault`. This vault was registered and open at audit time. The parent GauntletGame folder also has a separate Obsidian config.
2. Open **00 Home** for current status and decisions. Use **INDEX** for notes and **04 Tech/Code Map** for implementation. Project notes are normal Markdown files. Saving them in Obsidian edits the same files that Git and Codex use.
3. Templates are configured under `Templates/`. Daily notes go to `05 Production/Daily Log` using the Daily Log template. Keep third-party captures and the local LihFolk reference out of commits.
4. Start Codex at the repository root so it sees `AGENTS.md` and the skills under `.agents/skills/`. See [Codex workflow](Codex%20Collaboration.md) for the old-to-new workflow map. For a manual task, start with a small question such as **“Which Studio template and controller do I edit for the Match top bar?”**.

## 4. Verify and release

Run source checks before sharing changes.

```powershell
stylua --check src
selene src
rojo build default.project.json -o "$env:TEMP/gauntlet-check.rbxl"
```

- **Git.** Start with `git status --short --branch`, inspect `git diff` and `git diff --cached`, and use `git fetch origin` to refresh the remote refs when needed. Compare with `git log --left-right --oneline HEAD...origin/main`. Stage only the agreed paths. Coordinate integration of remote changes when there is local work. Use `git pull --ff-only` when a clean checkout can fast-forward. Push the intended commit or branch when agreed. CI checks formatting, lint and both code-only Rojo trees.
- **Local playtest.** Lobby Studio logs the teleport payload in Output. In Match toggle `TestMode` under Workspace Properties → Attributes before Play. Set team size and map in `Config/AssetData/MatchSettings`. Clear `ForceMap` to exercise voting. Test real teleport in a published experience when release testing is authorized. [Studio settings](State%20Values%20and%20Asset%20Data.md#editing-active-assets)
- **Studio save.** Save the intended place after a scene or template edit and retain recoverable source/backups for Studio-only data. The temporary Rojo build contains the repo-backed tree alone.
- **Publish.** Confirm the intended place and version in Studio before publishing. The owner chose Lobby V4 after cleanup. Remove/isolate third-party material and staging props from the release copy and verify its spawn, rooms, pads and templates. Match needs its own release check, including loading GUI and map vote. Treat [Bugs & Ideas](../05%20Production/Bugs%20%26%20Ideas.md) as an open issue list.

For the current Git/Studio differences and local verification results, see the [audit snapshot](Developer%20Handoff.md#6-audit-snapshot-and-release-handoff).
