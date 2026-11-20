# Codex workflow

On 2026-11-17 the owner moved to manual work with Codex support. Codex works directly in the repo with the owner across code, assets, Studio and documentation. The earlier Claude-led workflow used Codex for concepts, review and occasional Blender work.

## Migration map

| Former workflow | Current workflow |
|---|---|
| `CLAUDE.md` on each new Claude chat | Root `AGENTS.md` for current project rules. `CLAUDE.md` remains the Claude-era record. |
| `.claude/skills` | Four project skills under `.agents/skills` for vault lookup, modeling, UI and RIVALS research. Use current runtime UI notes and Lobby V4 direction when the old skills describe earlier looks. |
| Claude `vault-lookup` / `lihfolk-lookup` agents | Search the project index, the Code Map and LihFolk locally with `rg -n`. Read relevant sections. Use subagents only when requested or required by the task's applicable instructions. |
| LihFolk Claude plugin and agent workflows | Use the local [LihFolk library](LihFolk.md) and matching specialist reference. The 22 installed recipes were inventoried. The Claude agents, hooks, commands and unrelated specialization are kept in the installed plugin. |
| Claude Studio window selection and locks | Codex Roblox Studio MCP can address each open instance by ID. Verify the place and DataModel, and coordinate with the owner or another editing session before mutating one. The former `.claude-locks` convention only mattered when several sessions shared a live tool. |
| Claude Blend and Studio builds | Use Blender MCP or the build scripts when required. Preserve generated source and import contracts. The [Art Direction](../02%20Art/Art%20Direction.md) and area notes document exact pipelines. |
| Git worktrees and session-end pushes | Inspect the working tree and remote, isolate scoped work when appropriate, and coordinate commits, integration and pushes with the owner. Git does not update the published Roblox experience. |
| Local video-analyzer MCP registration | The old registration was scoped to Claude. Use the [Video Analyzer](Video%20Analyzer.md) CLI when a task actually needs transcript or frame extraction. |
| Claude issuing prompts to the Codex desktop UI | The owner works directly with Codex in the repository. Send a note link or describe the task, desired result and place as needed. |

The incoming Git checkout tracks `origin/main`. Its remote-tracking reflog shows repeated updates by push, consistent with Claude's frequent end-of-session pushes. Use [the audit snapshot](Developer%20Handoff.md#6-audit-snapshot-and-release-handoff) to see what still sat locally at the transition.

On this workstation, the enabled Studio MCP entry is `Roblox_Studio`. The older misspelled `roblox_strudio` entry is already disabled. The enabled entry returned both Studio places. Blender MCP is configured as a separate connection and was outside the runtime audit. The older Claude setup guide did not establish a reusable Roblox MCP configuration in the repo.

## Session routine

- Read [Home](../00%20Home.md), the relevant project decision and the implementation. The [Developer Handoff](Developer%20Handoff.md) covers both places.
- Keep a small, reversible edit in the proper source. For a runtime question, observe the right Studio place and record its test settings. Document meaningful results in the vault.
- Follow the [Setup Guide](Setup%20Guide.md) for Rojo, Obsidian, Git and release. The current decision is to keep Lobby and Match separate and prepare V4 after cleanup.
