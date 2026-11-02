# LihFolk

LihFolk V2 is a Roblox knowledge plugin for Claude Code: 22 skills plus about 1,300 expert notes. Claude uses it on Roblox work; you can read the same notes here in Obsidian.

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

## How Claude uses it
- **Before non-trivial Roblox work:** look up limits, defaults, 2025–2026 changes and gotchas, usually through the small `lihfolk-lookup` agent so it doesn't fill the conversation.
- **Specialist skills:** worldbuilding for maps, secure remotes, DataStore safety, performance audits, VFX, sounds, modelling.
- **Credit in our notes:** when a decision leans on a LihFolk note, link it.

Our project notes win over LihFolk's general advice, and measured numbers from our game win over both.

## Where to start reading
- [Start here](../LihFolk/00%20Start%20Here.md) · [Home](../LihFolk/000%20Home.md)
- Maps: [Combat Arena and Encounter Layout](../LihFolk/33%20Level%20Design/Combat%20Arena%20and%20Encounter%20Layout.md)
