# Electric Shock (battle pass power, premium tier 20)

Owner idea, lock-on approved 2026-11-26 ([Battle Pass Season 1 Contents](../Battle%20Pass%20Season%201%20Contents.md) → Powers); built 2026-11-27. Numbers in `src/shared/Config/Mods.luau` → `ElectricShock`. Slightly better than the free powers on purpose (owner: "still needs skill, but slight ptw").

## How it differs from Shock Dart
Shock Dart is a bow bolt that explodes **where it lands**. Electric Shock **locks onto a player**.

## L1
- **Held throw:** LMB throws a fast, flat orb; RMB lobs it short. It flies like a canister (bounces off walls, stops on the floor).
- While it flies, it **latches onto the first enemy it passes within 4 studs of** (with a clear line). A **0.5 s warning ring** shows on them; then **lightning strikes them wherever they moved**: **70 damage** and **1.5 s Hinder**.
- If it reaches nobody before it comes to rest, it **fizzles** with a small zap: no damage.
- Only enemies are latched; never you or your team. **1 charge per round**, no recharge. Role **Damage**.

## Upgrade paths
| Path | L2 | L3 |
|---|---|---|
| **A: Recharge** | comes back after 30 s | comes back after 18 s |
| **B: Chain** (`behaviour = "Chain"`) | the strike jumps to 1 more enemy within 12 studs for 35 | jumps to 2 more |
| **G: Overload** (`behaviour = "Overload"`) | latch range 4 → 6 studs | the strike also hits everyone within 5 studs of the target for 35 |

## Look and sound
- Blender orb (`ReplicatedStorage.Abilities.ElectricShock`: a faceted cage around a glowing core, three prongs) and `ShockVFX` (the warning ring, a jagged bolt), dressed by `client/Util/ShockStrikeFx` with the existing arc and bolt textures (`STIM_ARC_2x2`, `STIM_BOLT`).
- Sounds (`Config/ModSounds.ElectricShock`): throw, flight crackle, the latch lock-on beep, the strike crack and thunder, the fizzle.
- **Icon / draft card art:** ChatGPT (owner).
