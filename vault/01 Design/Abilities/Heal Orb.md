# Heal Orb (was Patch Up)

**Status:** spec locked 2026-10-29 · **built 2026-10-29** (overnight, waiting for the user's test)
**Inspiration:** Sage's Healing Orb (Valorant), not a copy. It has the same **mystical feel**: an orb of light forms in your hand, you give it to a teammate or take it yourself, and it **heals over time** (no instant heal).
**Remove from the old Patch Up:** the handheld "remote" device and the instant/simple heal.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Ready | Press the key → the gun lowers and **the orb forms in your palm**. Press again or swap weapons to cancel (costs nothing) |
| Heal a teammate (LMB) | Aim at a teammate **within 30 studs with line of sight**; they **highlight** when targetable. LMB sends the orb to them |
| Heal yourself (RMB) | RMB pulls the orb into your chest |
| No teammate | If no teammate is targeted (always the case in 1v1), LMB heals you |
| Amount | **Teammate: 60 HP over 3 s. Yourself: half, 30 HP over 3 s** |
| Interrupt | **Keeps healing even while taking damage** |
| Full health | Refused if the target is at full HP: nothing spent ("Full health") |
| Stacking | A new Heal Orb on someone already healing replaces the rest of the old heal (it doesn't stack) |
| Charges | **1 per round, no recharge** (unlimited in test mode) |

## Server
- The server applies the heal-over-time (ticks, capped at max HP) and validates the target: a teammate, alive, within 30 studs, line of sight, not at full HP.
- It also checks the caster is holding Heal Orb, has a charge left, and respects the rate limit.

## First person (the hand animation is the heart of this one)
- **Orb forms in palm on equip:** the hand opens and the orb **gathers out of swirling light**, then settles hovering above the palm.
- **Idle:** the orb slowly spins and pulses; light trails curl around your fingers, which glow faintly.
- **Ally (LMB):** the palm **pushes the orb forward** and it streams to the teammate as a ribbon of light.
- **Self (RMB):** the hand **presses the orb into your chest** and it bursts into light around you.

## Look (Blender + VFX)
- **Orb:** a **soft green-teal** glowing orb of swirling energy with soft particles. Mystical, but clean enough for a classic gun game, and clearly different from Frost's icy blue. Use a Blender-made core mesh/texture plus particles.
- **Third person:** others see the glowing orb in the caster's hand and the push/press motion. The send is a visible light ribbon to the target.
- **Being healed:**
  - a **rising green-teal glow and particles** around the healed player for 3 s (everyone sees it)
  - their **health bar fills smoothly with small "+HP" ticks**
  - a **soft glow at the healed player's screen edges**

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `HealOrb_Form` | Orb gathering in the palm |
| `HealOrb_HeldLoop` | Soft hum while holding |
| `HealOrb_Send` | Push/stream whoosh |
| `HealOrb_Absorb` | Self: orb into chest |
| `HealOrb_HealLoop` | On the healed player while healing (3D, ~30 studs) |
| `HealOrb_Complete` | Heal finished |
| `HealOrb_Refused` | "Full health" refusal |

### Placeholder sounds (ProSoundEffects, unauditioned)
Real (acoustic) recordings picked over the library's designed "magic" tones. All in `Config/ModSounds.luau` → `HealOrb`; swap the ids there.

| Hook | Id | Recording | Use |
|---|---|---|---|
| `HealOrb_Form` | 9119447936 | Sparkle Bell Tree Wind Chimes 1 | from 0.3 s, cut 2.5 s, pitch 1.1 |
| `HealOrb_HeldLoop` | 9120750051 | Wind Chimes 1 (delicate tuned ringing) | loop 1.5–22 s, pitch 1.15, quiet |
| `HealOrb_Send` | 9120696273 | Whoosh By Airy Whomping 6 | from 0.15 s, pitch 1.15 |
| `HealOrb_Absorb` | 9113821561 | Cloth Impact 1 (the thump) | from 0.75 s, cut 0.85 s |
| `HealOrb_HealLoop` | 9120750072 | Wind Chimes 2 | 3D ~30 studs, loop 1–30.5 s |
| `HealOrb_Complete` | 9114133866 | Door Chime Single Dings 5 | from 0.2 s, cut 2.3 s, pitch 1.2 |
| `HealOrb_Refused` | 9116895615 | Metal Thunk 3 | pitch 0.75 |

## Build notes (2026-10-29)
- **Code:** `Mods/HealOrb.luau` (was PatchUp), `Config/Mods.luau` → `HealOrb` (`heal` 60, `selfHeal` 30, `duration` 3, `range` 30, `aimAngle` 12, 1 charge). Server heal ticks in `ModService` (`ctx.heal`); a new heal on a target **replaces** the old one. LMB heals the ally in the crosshair, **else you** (also when allies are alive but none is aimed at); the hint says "Heal self" then. A named ally that fails range / sight is refused, never turned into a self-heal.
- **Model:** Blender orb (`tools/blender/build_mod_healorb.py`): neon core, ForceField shell with the swirl texture, two orbiting rings, 1,264 tris. Upload 139385018522739; `ReplicatedStorage.Abilities.HealOrb`, backup `art-source/abilities/Studio/HealOrb.rbxm`. It keeps its own green-teal (`ModProps` skips the team tint for it).
- **Effects:** `Util/HealFx.luau`: ribbon of light to the ally (Beam), soft burst flipbook on a self-heal, rising motes and wisps on the healed player, halo ring at their feet, edge glow on their screen. Blender textures from `tools/vfx/make_healorb_vfx.py` (`HEALORB_*` in `Config/VfxTextures`).
- **Hands:** the orb hovers above the open palm; `Heal` (push forward, the orb leaves at full reach) and `OrbChest` (pressed into the chest) item actions in `Config/Viewmodel`.
- **Client feedback:** one heal record per target, so a replaced heal stops its loop with no "complete" chime and the +HP numbers don't double. Death cuts the loop and glow.
- **Verified (playtest):** self 50 → 80 over 3 s, ally dummy 40 → 100, hint switches between "Heal ally" and "Heal self" with the crosshair.

## Mobile (provisional: full mobile pass later)
Tap Heal Orb to hold it. **Fire** heals the teammate in your crosshair (or you, if none). A **Self** context button heals you.

## Counter-play
The heal is slow and visible (the glow is on the target), so focus the healing player and kill them before it finishes. It's one per round.
