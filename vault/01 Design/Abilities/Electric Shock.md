# Electric Shock (battle pass power, premium tier 20: the LEGENDARY power)

Owner idea, lock-on approved 2026-11-26 ([Battle Pass Season 1 Contents](../Battle%20Pass%20Season%201%20Contents.md) → Powers); built 2026-11-27 and turned into a smite the same day. Owner: "a big lightning strike down, like a smite ... really cool sound effects ... an OP utility, but it's fine." Numbers in `src/shared/Config/Mods.luau` → `ElectricShock`.

## How it differs from Shock Dart
Shock Dart is a bow bolt that explodes **where it lands**. Electric Shock **locks onto a player** and calls lightning down on them.

## L1
- **Held throw:** LMB throws a fast, flat orb; RMB lobs it short. It flies like a canister (bounces off walls, stops on the floor).
- **It hunts:** in flight it latches onto the first enemy it passes within **7 studs** of (with a clear line). If it lands without one, it sits **charged for 2 s** and latches the first enemy who comes within **9 studs**.
- **Marked:** for **0.6 s** a ring follows the target's feet and a beam of light comes down on them from the sky (they hear it).
- **The smite:** lightning cracks down on them wherever they moved: **90 damage**, **2 s Hinder**, and **40** to every other enemy within **6 studs**. A white flash for anyone close, a big shake, shockwave rings, a scorch mark.
- Nobody comes near: it fizzles. Only enemies; never you or your team. **1 charge per round**, no recharge. Role **Damage**.

## Upgrade paths (redone 2026-11-27)
| Path | L2 | L3 |
|---|---|---|
| **A: Recharge** | comes back after 35 s | comes back after 20 s |
| **B: Chain Lightning** | the smite arcs to 1 more enemy within 16 studs for 60 | arcs to 2 more |
| **G: Storm Call** ⚡ (glitched) | a glitched violet storm stays over the smite: 3 more bolts around the target over 3 s, 35 each within 4 studs | 5 bolts over 4 s, 45 each |

## Look and sound (legendary pass, 2026-11-27)
Owner: "it doesn't look legendary ... high level, high animation". `client/Util/ShockStrikeFx` plays it in three acts:
1. **Latch:** the orb zaps onto the target; a **storm gathers** 28 studs over them (dark faceted cloud puffs swirling in, lit by lightning flickering inside); a beam of light comes down and a marked ring follows their feet; the world **dims and cools** for anyone within 90 studs; the target hears a warning.
2. **The smite:** **procedural forked lightning** (midpoint-displaced jagged bolts of glowing faceted segments, white-hot core in a coloured glow, 4 branches, re-forking three times in its first frames) plus a second bolt; a blinding **grade pop** and white flash, a light pillar, two shockwaves, glowing **ground cracks**, rock **debris**, sparks, dust and a scorch.
3. **Electrocution** (1.4 s): the target flickers white and blue, arcs jump between their limbs, sparks pour off them; their own screen flickers.
- **Your HUD:** a red hit marker and the damage number (90), kill marker on a kill; chain, splash and Storm Call hits show their numbers too.
- **Sounds:** designed cues (`tools/audio/design_powers.py`, [Power Sounds](../../02%20Art/Power%20Sounds%20-%20Smoke%20and%20Electric%20Shock.md)): the smite is one 3.6 s file (close thunder crack, sub boom, sizzle, rolling tail); a 0.9 s storm charge ends on the crack.
- **Icon / card art:** ChatGPT (in).
