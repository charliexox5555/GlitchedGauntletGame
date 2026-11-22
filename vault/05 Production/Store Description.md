# Store Description (Roblox)

Draft of the Roblox experience description for **Draft Duels** (2026-11-22). Lists only features already in the game. About 900 characters (the Roblox limit is 1,000).

Facts from: [Match Flow](../01%20Design/Match%20Flow.md), [Release Plan 2026-11-22](Release%20Plan%202026-11-22.md), [Skin Lines at Launch](../01%20Design/Skin%20Lines%20at%20Launch.md), `src/shared/Config/Settings.luau` (default binds).

## Current draft

```
Welcome to DRAFT DUELS, the shooter where every round is a new loadout! Draft a gun and an ability every round, build your combo, and outplay your rivals. First team to 5 rounds wins!

🃏 Every round, pick 1 of 3 guns and 1 of 3 ability cards
⚡ 12 abilities: Dash, Updraft, Molly, Firewall, Frost, Recon, Heal Orb, Stim, Recall, Flash, Shock Dart & Roller
⬆️ Draft the same ability again to upgrade it and pick its path
🔥 Watch out for rare Glitch cards!
🔫 Guns get stronger as the match goes on, from sidearms to elite rifles
⚔️ 1v1, 2v2 & 3v3: step on a duel pad or queue from the menu
🗳️ Vote on the map: 12 maps, from docks to snowy peaks
🏃 Slide, sprint and dash to stay alive
📦 Earn Coins and open cases for weapon and knife skins
🏆 Build your win streak

🖥️ PC: Shoot M1 · Aim M2 · Reload R · Slide C/Ctrl · Abilities Q/E/T · Melee V
🎮 Controller: Shoot R2 · Aim L2 · Reload X · Slide B · Abilities L1/R1/D-Up
⚙️ Every control can be rebound

👍 Like and favorite for updates!
```

## Left out on purpose

- **Gun names.** Vandal, Phantom, Sheriff, Operator and so on are Valorant's names. Keep them out of store text, and rename them before a public launch.
- **"Cosmetic only / no pay-to-win."** Paid Mod packs still need a pay-to-win check.
- **Not built yet:** 4v4, ranked, leaderboards, battle pass, Robux bundles, Castle map.
- **Mobile line.** The phone and controller UI hasn't been tested on a device. Once it has, add `📱 Play on PC, phones, tablets & controller!`

## Before a public launch

- Add a short anti-cheat and fair-play warning.
- Add the credits line the Release Plan requires.
- Update the controls if the default binds change (`Settings.luau`).
