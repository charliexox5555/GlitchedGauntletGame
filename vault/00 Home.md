# 🏠 Home

**Working title:** GlitchedGauntletGame (final name TBD: see [Game Plan](05%20Production/Game%20Plan.md) §1)
**One-liner:** RIVALS-style run-and-gun duels (1v1 → 4v4) where you **draft abilities ("Mods") every round** and every round opens a new **weapon tier**. Scheduled 16-player Gauntlet events come later.

---

## 📍 Status
> Update this block at the end of every work session (Claude does it when asked).

- **Phase:** Week 1 — "Find the fun" (prototype)
- **Done:** research · game plan · weapon roster · art style (Style B) · all gun models made in Blender · repo + Rojo scaffold · this vault · toolchain checks pass (rojo, stylua, selene, build) · `main` branch
- **Now:** importing guns into Studio → building the gun system (start with Byte)
- **Next:** rounds + tier rotation → Mods → draft → **Playtest #1**
- **Blockers:** —

---

## 🗺️ Map of the vault

### 01 Design: what the game *is*
- [Gunplay](01%20Design/Gunplay.md): movement, shooting feel, aim assist, feedback (RIVALS core + slide)
- [Weapons](01%20Design/Weapons.md): 22 guns + melee, tiers per round, build waves, gun mechanics
- Mods, Draft, Rounds and Maps: in the [Game Plan](05%20Production/Game%20Plan.md) §1, §4 and §5

### 02 Art: how it *looks*
- [Art Direction](02%20Art/Art%20Direction.md): Style B rules, palette, model standard, import pipeline
- [Gun Batch Prompt](02%20Art/Gun%20Batch%20Prompt.md) · [AI 3D Prompts](02%20Art/AI%203D%20Prompts.md)
- References: `02 Art/References/` (Bitrate master, style tests)

### 03 Research: *why* we decided things
- [Design Research Report](03%20Research/Design%20Research%20Report.md): the full report (shooters, draft design, matchmaking, tech, money, risks)
- Raw notes: `03 Research/Notes/`

### 04 Tech: how it's *built*
- [Setup Guide](04%20Tech/Setup%20Guide.md): install, Rojo, Obsidian, Claude, prompts
- [Architecture](04%20Tech/Architecture.md): folders, Rojo mapping, code rules

### 05 Production: *when* things happen
- [Game Plan](05%20Production/Game%20Plan.md): day-by-day plan → beta → Season 1
- `Daily Log/` · `Playtests/` · [Bugs & Ideas](05%20Production/Bugs%20%26%20Ideas.md)

### 06 Assets: what *exists*
- [Asset Tracker](06%20Assets/Asset%20Tracker.md): every gun/map/VFX and its status

---

## 🔒 Locked decisions
| Topic | Decision | Where |
|---|---|---|
| Gunplay | RIVALS-style run-and-gun, accurate while moving, slide is the core move, ~1.5× headshots, TTK 0.35–0.6 s | [Gunplay](01%20Design/Gunplay.md) |
| Rounds | First to 5, shared weapon tier per round (Sidearm → Light → Heavy → Wildcard) | [Weapons](01%20Design/Weapons.md) |
| Draft | 3 Mod slots, L1→L3, both sides draft, the loser gets +1 card and +1 reroll, mirrored offers in 1v1 | [Game Plan](05%20Production/Game%20Plan.md) §4 |
| Art | Style B "Stylized Neon"; Bitrate is the master reference | [Art Direction](02%20Art/Art%20Direction.md) |
| Camera | First person | [Gunplay](01%20Design/Gunplay.md) |
| Money | Cosmetics only (wraps, charms, Mod VFX), no paid random boxes | [Game Plan](05%20Production/Game%20Plan.md) §1 |
| Tech | Rojo + strict Luau, server-authoritative, Server Authority on | [Architecture](04%20Tech/Architecture.md) |
