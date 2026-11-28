# Smoke (battle pass power, free tier 10)

Owner spec 2026-11-26 ([Battle Pass Season 1 Contents](../Battle%20Pass%20Season%201%20Contents.md) → Powers); built 2026-11-27; made bigger and solid the same day (owner: "much larger ... Valorant style ... not see-through"). Numbers live in `src/shared/Config/Mods.luau` → `Smoke`.

## L1
- **Held throw like the Molly:** LMB throws overhand (long), RMB lobs underhand (short). Same flight rules (walls bounce it; it stops on the first floor; drops after 1.3 s in the air).
- Where it lands it **pops after 0.3 s** into a **big solid smoke dome, 22 studs across (radius 11)**, about a Valorant smoke at our scale, that stands **14 s**: it bursts out over 0.8 s and thins out over its last 1.5 s.
- **Blocks sight both ways:** you can't see through it, into it or out of it (inside, your screen is solid smoke). **Bullets still pass through.** It also stops **bot vision**, **aim assist** and **auto shoot** through it (`Mods/Blocks/Smoke.blocks`, read by bot `Perception` and `AimAssistController`).
- Lands in the air (still flying after 4 s): it fizzles, no smoke.
- **1 charge per round**, no recharge. Role **Control**.

## Upgrade paths (redone 2026-11-27)
| Path | L2 | L3 |
|---|---|---|
| **A: Double Smoke** | 2 smokes a round | 3 smokes a round |
| **B: Long Smoke** | stands 20 s | stands 26 s, 26 studs across |
| **G: Toxic Cloud** ⚡ (glitched) | a sick green cloud with magenta glitch static: enemies inside are Hindered and take 10 damage/s | 18 damage/s, and **your team sees enemies inside** (you see in, they can't see out) |

## Look and sound
- Blender canister (`ReplicatedStorage.Abilities.Smoke`, vent on top, a pin that flies off) and the smoke kit (`SmokeVFX`: faceted puffs and a dome shell). `client/Util/SmokeFx` draws them **unlit** (lit faceted grey read as a rock pile), heaps puffs round the base and over a 1.2× tall dome, and rolls `SMOKE_2x2` wisps off the whole surface.
- **Opening (2026-11-27):** a jet of smoke shoots up out of the canister, then the puffs burst out one after another with a small overshoot and the shell swells in behind them.
- Sounds: designed cues (`tools/audio/design_powers.py`, [Power Sounds](../../02%20Art/Power%20Sounds%20-%20Smoke%20and%20Electric%20Shock.md)): a pressurised pfsshh burst with a low whump, a soft rolling hiss while it stands, an exhale as it thins.
- **Icon / draft card art:** ChatGPT (in; [UI Art Brief (ChatGPT)](../../02%20Art/UI%20Art%20Brief%20%28ChatGPT%29.md)).
