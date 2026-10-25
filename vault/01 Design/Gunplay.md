# Gunplay

**Feel target:** RIVALS-style run-and-gun, plus a sliding move set borrowed from Hypershot. **Not** Valorant: you never have to stand still to shoot accurately.

**Why:** most Roblox players are on phones, and the draft plus Mods already give players a lot to learn, so shooting must be easy to pick up and satisfying. Base movement stays moderate so **drafted mobility Mods (Blink, Launch Pad) feel like real upgrades**. Background: [Design Research Report](../03%20Research/Design%20Research%20Report.md).

All numbers are **starting values**. They live in `src/shared/Config/` so they can be tuned without new code.

---

## 1. Movement
| Action | Value | Notes |
|---|---|---|
| Walk | 16 studs/s | |
| Sprint | 22 studs/s | Toggle or hold (setting). Pressing fire **cancels sprint instantly** |
| Crouch | 9 studs/s | Tighter spread |
| Jump | ~7 studs high | Standard Roblox jump. No fall damage |
| **Slide** | Sprint + crouch → 30 studs/s burst, slowing to crouch speed over 0.7 s | 0.6 s cooldown. You can shoot while sliding |
| **Slide-jump** | Jumping out of a slide keeps 80% of the speed | The "Hypershot" flavour. No other advanced tech |
| ADS move speed | ×0.75 (snipers scoped ×0.55) | |
| Heavy guns | ×0.85 (Overflow), ×0.75 (Flood) | From [Weapons](Weapons.md) |
| Not in base kit | Double jump, wall-run, dash | **Only from Mods**, so drafting mobility matters |

## 2. Shooting
- **Fire on press**, never on release.
- **Accurate while moving.** Spread is added on top of each gun's base spread:
  | State | Extra spread |
  |---|---|
  | Standing / crouching | 0 |
  | Walking | +0.4° |
  | Sprinting (first shot) | +0.6° |
  | Sliding | +0.8° |
  | In the air | +2.5° (snipers unscoped: huge) |
- **Hip fire is real** for sidearms, SMGs and shotguns. **ADS** = spread ×0.35, zoom, slower movement. It matters most for rifles and snipers.
- **Base hip spread by class:** sidearm 0.8°, SMG 1.2°, rifle 1.4°, machine gun 2.0°, shotgun pellet cone 5°, sniper unscoped 4° (scoped 0°).
- **Bloom:** +0.15° per shot up to a per-gun cap; recovers at 6°/s after you stop firing.
- **Recoil:** mostly **vertical** camera kick (rifle ≈ 0.35° per shot) with a small random sideways jitter (±0.12°). About 70% recovers automatically when you stop. **No spray patterns to memorise.**
- **Swaps and reloads:** weapon swap 0.3 s (sidearms 0.2 s); swapping cancels a reload; empty reloads take longer than tactical ones.

## 3. Damage
| Rule | Value |
|---|---|
| Health | 100 per round, **no natural regen** (heals come from Mods) |
| Headshot | **×1.5** by default |
| Legs | ×0.85 |
| One-shot headshot guns | Only **Root** (≤25 studs), **Checksum** and the snipers. It's their identity |
| Target time-to-kill | **0.35–0.6 s** for main guns. That leaves just enough time to react with a Mod |
| Falloff | Per gun (start and end distance, minimum damage) |

## 4. Aim assist (touch and gamepad only, never mouse)
- **Slowdown:** aim sensitivity drops to 60% within ~3° of an enemy.
- **Light magnetism:** gentle pull (≈15%) toward the target **only while ADS** and moving the aim.
- **No snap-to-target.** Use Roblox's official Aim Assist module as the base.
- Ranked will split pools by input type. Never give stat buffs by device (device detection can be spoofed).

## 5. Feedback ("juice")
This is a big part of why RIVALS feels good. Build it alongside the very first gun.
- **Hit marker:** white for body, **gold for headshots**. Instant on the client, confirmed by the server.
- **Sounds:** distinct body-hit tick, headshot "ding", **kill sound** (cyan X marker).
- **Damage numbers** that stack while you keep hitting.
- **Victim:** directional hit indicator, red low-HP vignette, a short death recap showing **the killer's gun and Mods** (teaches the draft).
- Kill feed, a round-win stinger, a slow-mo kill cam on the deciding round.
- Muzzle flash, tracer (none for suppressed guns), shell ejection, impact sparks; enemies **dissolve into pixels** on death (no blood).

## 6. Camera and controls
- **First person.** FOV 80 by default (setting 70–100), with ADS FOV set per gun.

| Action | PC | Gamepad | Mobile |
|---|---|---|---|
| Fire | LMB | RT | Fire button (+ optional left fire) |
| ADS | RMB (hold or toggle) | LT | ADS button |
| Reload | R | X | Reload button |
| Jump | Space | A | Jump button |
| Sprint | Shift | L3 | Auto-sprint when the stick is pushed fully forward |
| Crouch / Slide | C or Ctrl | B | Slide button (appears while sprinting) |
| Mods 1/2/3 | Q / E / F | LB / RB / D-pad up | 3 Mod buttons in an arc |
| Primary / secondary / melee | 1 / 2 / 3, scroll | Y cycles | Weapon tabs |
| Melee quick-swing | V | R3 | Melee button |

All mobile buttons can be moved and resized in settings.

---

## Build order
1. ✅ Movement (walk, sprint, crouch, slide, slide-jump), using the Input Action System.
2. ✅ Byte: fire, server validation, damage + head/legs, hit marker + sounds.
3. ✅ Spread and bloom + recoil + ADS.
4. ✅ Bitrate (auto) → Hard Reset (pellets) → Long Poll (scope) → the rest of wave 1 (Root, Bandwidth, Flood spin-up + ThinWall, Ray Trace charge, Cutter).
5. ⬜ Aim assist on touch and gamepad. Test on a real phone.

Status 2026-10-25: steps 1–4 work against dummies in Studio; all numbers are first guesses in `Config/` and need a 2-player feel pass. Not built yet: tactical/empty reload difference beyond timing, hit indicator for the victim beyond direction, kill cam, death recap, mobile layout tuning.
