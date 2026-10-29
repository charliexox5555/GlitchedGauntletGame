# Heal Orb (was Patch Up)

**Status:** spec locked 2026-10-29 · not built
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

## Mobile (provisional: full mobile pass later)
Tap Heal Orb to hold it. **Fire** heals the teammate in your crosshair (or you, if none). A **Self** context button heals you.

## Counter-play
The heal is slow and visible (the glow is on the target), so focus the healing player and kill them before it finishes. It's one per round.
