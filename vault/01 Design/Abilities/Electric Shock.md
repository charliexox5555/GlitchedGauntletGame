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

## Look and sound
- Blender orb (`ReplicatedStorage.Abilities.ElectricShock`: a faceted cage round a glowing core, three prongs) and `ShockVFX` (the ring, a jagged bolt). `client/Util/ShockStrikeFx`: latch zap, marked ring, sky beam, the smite (a 90-stud bolt flickering through three shapes, two forks, crackling beams, flash, two shockwaves, sparks, dust, arcs on the target, scorch), chain arcs, Storm Call's violet bolts with magenta static, and the charged beacon.
- Sounds (`Config/ModSounds.ElectricShock`, ProSoundEffects, unauditioned): the smite is four layers at once: a thunder crack, a heavy boom, a rolling rumble and an electric sizzle. Plus the arming snap, the tesla-coil crackle in flight and on the beacon, the lock-on sear, the target's warning whine and the fizzle.
- **Icon / draft card art:** ChatGPT (owner).
