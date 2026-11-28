# Smoke (battle pass power, free tier 10)

Owner spec 2026-11-26 ([Battle Pass Season 1 Contents](../Battle%20Pass%20Season%201%20Contents.md) → Powers); built 2026-11-27. Numbers live in `src/shared/Config/Mods.luau` → `Smoke`.

## L1
- **Held throw like the Molly:** LMB throws overhand (long), RMB lobs underhand (short). Same flight rules (walls bounce it; it stops on the first floor; drops after 1.3 s in the air).
- Where it lands it **pops after 0.35 s** into a **smoke dome 12 studs across (radius 6)** that lasts **10 s**: it grows over 0.6 s and thins out over its last second.
- **Blocks sight both ways:** you can't see through it or out of it. **Bullets still pass through** (no wall). It also stops **bot vision**, **aim assist** and **auto shoot** through it (`Mods/Blocks/Smoke.blocks`, read by bot `Perception` and `AimAssistController`).
- Lands in the air (still flying after 4 s): it fizzles, no smoke.
- **1 charge per round**, no recharge. Role **Control**.

## Upgrade paths
| Path | L2 | L3 |
|---|---|---|
| **A: Recharge** | comes back after 25 s | comes back after 15 s |
| **B: Big Smoke** | radius 7.5, 12 s | radius 9, 15 s |
| **G: Toxic** (`behaviour = "Toxic"`) | enemies inside are Hindered (refreshed every 0.5 s) | also 10 damage/s to enemies inside |

## Look and sound
- Blender canister (`ReplicatedStorage.Abilities.Smoke`, vent on top, a pin that flies off) and the smoke kit (`SmokeVFX`: faceted puffs and a dome shell), dressed by `client/Util/SmokeFx` with the existing smoke flipbook (`VfxTextures.SMOKE_2x2`).
- Sounds (`Config/ModSounds.Smoke`): throw, lob, bounce, the hiss of the pop, a soft loop while it lasts.
- **Icon / draft card art:** ChatGPT (owner). Prompts in [UI Art Brief (ChatGPT)](../../02%20Art/UI%20Art%20Brief%20%28ChatGPT%29.md).
