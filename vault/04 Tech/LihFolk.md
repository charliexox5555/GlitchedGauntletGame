# LihFolk

LihFolk V2 is the Roblox reference library used by the former Claude workflow. It includes 22 specialist recipes and about 1,300 notes. Codex and the owner can search the same notes in Obsidian or on disk.

**Credit:** the notes are "LihFolk Vault V2" by LihFolk, under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Full terms: [LICENSE](../LihFolk/LICENSE.md).

## What's installed (2026-11-02)
| Piece | Where | State |
|---|---|---|
| Plugin 2.5.0 | Claude Code (`lihfolk@lihfolk`) | ✅ Skills load and the note search runs |
| Notes in this vault | [`LihFolk/`](../LihFolk/000%20Home.md) | ✅ 1,329 notes, a read-only copy |
| Asset Pack (models, skies, materials) | Not installed | Optional, about 1.3 GB in total. Only worth getting if we want its skies or materials |

The `LihFolk/` folder is **git-ignored**: it's 53 MB and the plugin already has the original. On a new computer, or after a plugin update, copy it again:

```powershell
robocopy "$env:USERPROFILE\.claude\plugins\cache\lihfolk\lihfolk\2.5.0\LihFolk Vault V2" "vault\LihFolk" /E /XD .obsidian _tools
```

Change `2.5.0` to the current version. Don't edit notes inside `LihFolk/`, because the next copy overwrites them; our own notes stay in the numbered folders.

The global graph has the filter `-path:LihFolk` so it still shows the game's notes. Clear the filter to see everything.

## Use it from Codex or Obsidian

1. Start with [ROUTER](../LihFolk/ROUTER.md) for a topic, [INDEX_SLIM](../LihFolk/INDEX_SLIM.md) to find a title, and [SYMPTOMS](../LihFolk/SYMPTOMS.md) for debugging. Use Obsidian search or `rg -n --no-ignore -g '*.md' <term> vault/LihFolk`. Git ignores the directory, so basic `rg` from the repo root may skip it.
2. Read the relevant note section and follow its sources. Link the note if it informed a project decision. Verify time-sensitive API and platform details when implementing.
3. If a specialist recipe helps, read its `SKILL.md` under the installed plugin's `skills/` folder. Use the procedures that apply to Gauntlet. Claude-specific commands, subagent orchestration and asset-pack paths depend on that install.

| Task | Installed recipe or library section |
|---|---|
| Maps, rooms, props and imports | `lihfolk-worldbuilding`, `roblox-blender-modeling`, `roblox-asset-import`. Use `lihfolk-assets` only if the optional pack is available and an asset's rights are clear. |
| HUD, menu and design handoff | `roblox-ui-builder`, `lihfolk-figma`. Gauntlet supplies its own visual style; `lihfolk-ui` is the library's separate house kit. |
| Effects and sound | `lihfolk-vfx`, `lihfolk-sfx`. Use Gauntlet's existing VFX helpers, asset conventions and permitted sources. |
| Server systems and review | `roblox-system-builder`, `roblox-secure-remotes`, `roblox-anti-exploit-review` for defensive review. `lihfolk-systems` describes optional ready-made modules. |
| Persistence and monetization | `roblox-datastore-safety`, `roblox-monetization-compliance`. Match the existing data contract and current Roblox rules. |
| Debugging and measurement | `roblox-debugging`, `roblox-performance-audit`. Reuse context-specific benchmarks and existing test tools. |
| Onboarding and other design methods | `lihfolk-tutorial` for onboarding. `quality-score` is a rubric and `council-method` is a multi-reviewer process. `roblox-trend-game` serves a different genre. |

The repo skill `gauntlet-vault` replaces the mandatory Claude router and lookup-agent handoff. The project uses LihFolk on demand, so a new checkout still works before the local reference library is copied.

Our project notes win over LihFolk's general advice, and measured numbers from our game win over both.

## Where to start reading
- [Start here](../LihFolk/00%20Start%20Here.md) · [Home](../LihFolk/000%20Home.md)
- Maps: [Combat Arena and Encounter Layout](../LihFolk/33%20Level%20Design/Combat%20Arena%20and%20Encounter%20Layout.md)
