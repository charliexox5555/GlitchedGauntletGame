---
name: gauntlet-vault
description: Find current design, code, art, playtest and Roblox reference material when working in the GlitchedGauntletGame repo. Use for Gauntlet tasks before editing or advising.
---

# Work from the Gauntlet vault

1. Read the relevant Status and Locked decisions in `vault/00 Home.md`. Search `vault/INDEX.md` for the note and `vault/04 Tech/Code Map.md` for the implementation. Use `rg -n` and ranged reads on long notes. Check source and Studio for installed behavior, and preserve the latest owner decisions for design intent.
2. Use [the Developer Handoff](../../../vault/04%20Tech/Developer%20Handoff.md) and [Place Merge Plan](../../../vault/04%20Tech/Place%20Merge%20Plan.md) for routing inside the single merged place (`71551303511506`, Draft Duels). For queue use Lobby UI and Queue. For rounds, use Match Flow and Config/Match. For guns and Mods, use Gunplay, Weapons, Abilities, and the corresponding config.
3. For non-trivial Roblox work, query `vault/LihFolk/ROUTER.md`, `INDEX_SLIM.md` or `SYMPTOMS.md`, then read the relevant notes or specialist material as described in [LihFolk](../../../vault/04%20Tech/LihFolk.md). The git-ignored local copy is optional on another workstation. Link the notes that informed a project decision.
4. For a substantial task, record the plan and evidence in the relevant project note. File playtest results under `05 Production/Playtests`, unresolved bugs and ideas in `Bugs & Ideas.md`, and explicit end-of-day requests in the daily-log template. Update Home, index, Code Map or Asset Tracker when the corresponding status, inventory, ownership or asset changes.
