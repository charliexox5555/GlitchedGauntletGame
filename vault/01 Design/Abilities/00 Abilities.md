# Abilities: base redesign (one by one)

We're redesigning the **base (L1) version** of each of the 9 Mods, one at a time, Valorant-style. The specs pile up here and then **get built together in one Claude Code session**. Paths and glitches come later.

> These specs **override** the L1 sections in [Mods](../Mods.md) where they differ.
> **Theme (2026-10-28):** the digital/glitch theme is **shelved for now**. This is a classic gun game; names and looks are plain and readable. It may come back later.

## Status
| # | Ability | Was | Spec | Built |
|---|---|---|---|---|
| 1 | [Dash](Dash.md) | Blink | ✅ locked 2026-10-28 | ⬜ |
| 2 | [Updraft](Updraft.md) | Launch Pad | ✅ locked 2026-10-28 | ⬜ |
| 3 | [Molly](Molly.md) | Packet | ✅ locked 2026-10-28 | ⬜ |
| 4 | [Firewall](Firewall.md) | Firewall (cover wall) | ✅ locked 2026-10-29 | ⬜ |
| 5 | [Frost](Frost.md) | Lag Field | ✅ locked 2026-10-29 | ⬜ |
| 6 | [Recon](Recon.md) | Ping | ✅ locked 2026-10-29 | ⬜ |
| 7 | [Heal Orb](Heal%20Orb.md) | Patch Up | ✅ locked 2026-10-29 | ⬜ |
| 8 | [Stim](Stim.md) | Overclock | ✅ locked 2026-10-29 | ⬜ |
| 9 | Rollback | — | ⬜ to redesign | — |

## Rules for every base ability
- **Charges, not one cooldown rule for all.** Each ability sets its own: a number of **charges per round** (refilled at round start, no recharge) and/or a **cooldown**, like Valorant (Jett's dash vs Sova's dart). It's decided per ability below.
- **Test mode:** there's no round system yet, so the dev panel has a **"Test mode: unlimited charges"** toggle (on by default in Studio). RoundService will later call a "refill charges" function at round start.
- **Keys:** PC **Q / E / T** · gamepad LB / RB / D-pad up · mobile buttons. Instant abilities fire on press (mobile-friendly).
- **Mobile is provisional:** each spec has a basic mobile layout so it works; a full mobile controls/HUD pass comes later.
- **Status effects:** shared, server-enforced effects with an expiry time, reusable by any ability. **Hinder** (debuff, see [Frost](Frost.md)) and **Stimmed** (team buff, see [Stim](Stim.md)); they multiply when combined.
- **Friendly fire (2026-10-29):** damage from your own abilities to **you and your teammates is 50%** of the enemy damage (one config value). Exceptions are set per ability; e.g. you're immune to your own Firewall.
- **Readable for enemies:** clear look and a 3D sound others can hear.
- **Sound:** every ability gets named sound **hooks** in `Config/ModSounds` (separate slots, own volume and pitch, one ID to swap). The user does the final sound design.
- Server-authoritative; movement abilities run in the movement simulation like the current Blink.

## Bench (ideas for later powers or upgrades)
- **Barrier:** a placeable cover wall you can hide behind (the old Firewall idea).

## Build prompt (paste into Claude Code when the specs are ready)
```text
Build the abilities whose spec is "locked" and built "⬜" in vault/01 Design/Abilities/00 Abilities.md. Read CLAUDE.md, that overview and each ability's note first; the notes override vault/01 Design/Mods.md for L1. Inspect the current Mod code (src/shared/Mods, Config/Mods.luau, ModService, ModController, ModFeelController, ModFxController, ViewmodelController, ModSounds) and build on it.
Do one ability at a time, in the order of the table. For each: implement it, STOP and tell me exactly what to test in Studio, and wait for my OK. Then run stylua and selene, tick "Built" in the overview, update the ability note if any number changed, update vault/00 Home.md Status, and commit and push.
First, before any ability: add the per-ability charge system (charges per round and/or cooldown, as data in Config/Mods.luau), the "Test mode: unlimited charges" dev toggle, and a refill function for the future RoundService.
```
