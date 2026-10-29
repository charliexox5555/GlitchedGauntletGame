# Mods (abilities): first set of 9

> **Status: APPROVED set v1 (2026-10-26).** The 9 Mods and their names are locked; numbers are starting points for playtesting.
> **Build order:** base **L1 of all 9 first** (Phase 1). Paths A/B and Glitch paths come after L1 is fun (Phase 2).
> **Built (2026-10-26):** the Mod framework and **L1 of all 9 Mods**, with the finished models, stylized VFX, first- and third-person animations and **provisional** (unauditioned) sounds. How it's built: [Mod System](../04%20Tech/Mod%20System.md). Test list: [Mods Overnight Checklist](../05%20Production/Playtests/Mods%20Overnight%20Checklist.md).

> **Redesign in progress (2026-10-28):** the base abilities are being redesigned one by one in [Abilities](Abilities/00%20Abilities.md). Those notes **override the L1 sections below** (Blink → Dash, Launch Pad → Updraft, Packet → Molly, Firewall → Phoenix-style fire wall, Lag Field → Frost, Ping → Recon, Patch Up → Heal Orb, Overclock → Stim, more to come).

## How a Mod upgrades
```
            ┌─ Path A: L2 ─► L3
L1 (base) ──┼─ Path B: L2 ─► L3
            └─ GLITCH: G2 ─► G3   (rare: only appears sometimes, instead of a normal upgrade card)
```
- **L1** is what you get when you first draft the Mod.
- At **L2** you choose a path, **A or B**, and **L3** upgrades that path.
- The **Glitch path** is a rare third option (~8% chance at the L2 offer; see the draft rules in the [Game Plan](../05%20Production/Game%20Plan.md) §4). It *changes what the Mod does*, usually stronger but with a visible quirk or drawback, and it has its own G3.
- Each Mod has **7 states** (L1, A2, A3, B2, B3, G2, G3), so 9 Mods = 63 states.

## Design rules
1. **One button, no aiming menus.** Placed things go where you're looking (mobile-friendly).
2. **Readable:** every Mod has a clear look and sound for the *enemy*. Glitched Mods add magenta static.
3. **Counter-play:** every Mod has an answer (listed per Mod).
4. Cooldowns fit **50 s rounds**: 2–4 uses per round.
5. Built from shared code **building blocks**: dash, projectile, placeable, zone, self-buff, reveal, rewind.
6. Paths should be **different playstyles**, not "+10% numbers".

## Controls and activation

**Slots and keys:** 3 Mod slots. **PC: Q / E / T** (decided 2026-10-26; crouch stays on C / Left Ctrl) · **Gamepad: LB / RB / D-pad up** (the dev weapon picker moved to D-pad left) · Mobile: 3 buttons in an arc next to Fire.

There are three ways a Mod activates:
| Type | How it works | Mods (at L1) |
|---|---|---|
| **Instant** | Press → it happens right away | Blink, Ping, Overclock, Rollback |
| **Held: throw** | Press → you hold it (gun lowered) with an **arc preview**. **LMB** = throw, **RMB** = short lob | Packet, Lag Field |
| **Held: place** | Press → you hold it with a **hologram preview** where it will go (green = valid, red = invalid). **LMB** = place | Launch Pad, Firewall |
| **Held: target** (Sage-style) | Press → you hold the heal device. **LMB** = heal the teammate in your crosshair (30 studs, line of sight), **RMB** = heal yourself | Patch Up |

**Rules for held Mods:**
- Equipping takes 0.25 s (raise animation). The gun is lowered and can't fire while a Mod is held.
- **Cancel** by pressing the same key again, swapping weapons (1/2/3/scroll) or pressing another Mod key (which switches to that Mod).
- You can move, jump, sprint and slide while holding a Mod.
- **The cooldown starts on use, not on equip.** Cancelling costs nothing.
- An on-screen hint shows the controls while held (e.g. "LMB Heal ally · RMB Heal self · Q Cancel").
- **Quick-cast** setting (off by default on PC): pressing the key uses the Mod immediately (throw/place at the crosshair, heal self).
- **Mobile:** tapping a Mod button holds it, the Fire button uses it, and a context button appears for the alternate use (lob / heal self). Tap the Mod button again to cancel.
- In 1v1 there are no teammates, so Patch Up's LMB falls back to healing yourself.
- Patch Up won't heal someone already at full health: the press is refused and nothing is spent ("Full health").
- **What enemies can see (proposed overnight, confirm):** which Mods you have and when you're holding one are public (they're visible in play anyway); your cooldowns are private. Blink and Rollback are the exception: they run in the movement simulation, so their charges are visible to a determined client.

**VFX colour by viewer (readability):** a Mod's effects are **cyan `#00E5FF`** to the caster and their teammates, and **orange-red `#FF5A36`** to enemies. Glitched Mods add **magenta `#FF3DCB`** static and flicker. Each client recolours effects locally based on team.

**Assets needed per Mod (L1):**
| Mod | Models (Blender) | VFX |
|---|---|---|
| Blink | — | Speed lines, afterimage trail, whoosh |
| Launch Pad | Hex pad with arrow lights | Charge glow, launch burst, landing puff |
| Packet | Grenade | Arc preview, fuse blink, explosion + shockwave ring, danger ring |
| Firewall | Wall frame + energy panel | Deploy build-up, bullet impacts, break shatter |
| Lag Field | Orb | Zone dome/ring, slow particles on affected players |
| Ping | — | Expanding scan ring, enemy outline highlight |
| Patch Up | **Handheld heal device** (viewmodel) | Heal beam to target, heal particles, +HP numbers |
| Overclock | — | Gun glow, heat shimmer, hum |
| Rollback | — | Ghost trail of the last 3 s, rewind snap, a "VHS rewind" screen effect for the caster |

## Overview
| # | Mod | Role | Block | L1 in one line | Path A | Path B | Glitch |
|---|---|---|---|---|---|---|---|
| 1 | **Blink** | Mobility | dash | Quick dash | **Burst** (chain dashes, reload) | **Ghost** (dodge bullets, vanish) | **Desync** |
| 2 | **Launch Pad** | Mobility | placeable | Jump pad | **Jump Grid** (more pads, speed) | **Air Strike** (aerial aim, slam) | **Zero-G** |
| 3 | **Packet** | Damage | projectile | Grenade | **Payload** (more boom, burn) | **Sticky** (stick, silence Mods) | **Fork Bomb** |
| 4 | **Firewall** | Defense | placeable | Bullet-blocking wall | **Rampart** (tough, one-way) | **Burn Wall** (fire curtain, pushes) | **Mirror Wall** |
| 5 | **Lag Field** | Control | zone | Slowing zone | **Latency** (debuffs) | **Buffer** (bigger, traps) | **Freeze Frame** |
| 6 | **Ping** | Info | reveal | Wallhack pulse | **Traceroute** (mark targets) | **Sonar** (sensor, see cooldowns) | **Ping Spike** |
| 7 | **Patch Up** | Sustain | self-buff | Heal | **Hotfix** (instant heal, shield) | **Support Patch** (heal zone) | **Corrupted Patch** |
| 8 | **Overclock** | Weapon buff | self-buff | Faster firing | **Turbo** (reload, kill chains) | **Precision** (no spread, headshots) | **Overheat** |
| 9 | **Rollback** | Escape | rewind | Rewind 3 s | **Undo** (restore HP) | **Save State** (manual checkpoint) | **Crash Recovery** |

---

## 1. Blink: Mobility (dash)
| Level | Effect |
|---|---|
| **L1** | Dash 12 studs in your move direction. 7 s cooldown. |
| **A2 Burst** | 2 charges. |
| **A3 Burst** | Each dash also reloads 50% of your magazine. |
| **B2 Ghost** | Bullets pass through you during the dash (0.3 s). |
| **B3 Ghost** | After dashing you turn nearly invisible for 1 s (a shimmer is visible within 10 studs). |
| **G2 Desync** ⚡ | Dash leaves a **decoy afterimage** that keeps running in your old direction for 1.5 s and looks exactly like you. *Quirk:* you can't shoot for 0.3 s after dashing. |
| **G3 Desync** ⚡ | The decoy also fires blanks (tracers and sound) at the nearest enemy; you're invisible while it runs. |

**Counter:** pre-aim the landing spot; decoys take no damage from hits, and a hit marker doesn't appear on them.

## 2. Launch Pad: Mobility (placeable)
| Level | Effect |
|---|---|
| **L1** | Place a pad where you look. Stepping on it launches you ~25 studs up and forward. Lasts 15 s, teammates can use it. 12 s cooldown. |
| **A2 Jump Grid** | 2 pads at once. |
| **A3 Jump Grid** | Landing gives +30% move speed for 2 s. |
| **B2 Air Strike** | No airborne spread penalty for 2 s after launching. |
| **B3 Air Strike** | Landing slams the ground: 40 damage in 8 studs. |
| **G2 Zero-G** ⚡ | Instead of a pad, creates a 14-stud **low-gravity zone** for 5 s. *Everyone* inside jumps higher and falls slowly (and gets airborne spread). |
| **G3 Zero-G** ⚡ | You're immune to your own zone's spread penalty, and enemies inside are revealed. |

**Counter:** shoot people in the air (predictable arcs); destroy the pad (50 HP).
*Built L1:* teammates (and you) only; the launch keeps its arc until you land (about 24 studs up, 29 forward).

## 3. Packet: Damage (projectile)
| Level | Effect |
|---|---|
| **L1** | Throw a grenade that bounces once and explodes after 1.2 s: 50 damage at the center, 20 at the 8-stud edge. 14 s cooldown. |
| **A2 Payload** | 2 charges. |
| **A3 Payload** | Bigger blast (11 studs) and leaves a 3 s burning zone (10 damage/s). |
| **B2 Sticky** | Sticks to the first surface or player it hits and explodes after 0.8 s. |
| **B3 Sticky** | Enemies hit get **"Packet Loss"**: their Mods are disabled for 2.5 s. |
| **G2 Fork Bomb** ⚡ | Splits into 3 mini-bombs on impact (25 damage each) that scatter. *Quirk:* the scatter is random and **can hurt you**. |
| **G3 Fork Bomb** ⚡ | 5 mini-bombs that bounce twice. |

**Counter:** a red danger ring shows the blast area; Blink or Firewall out of it.

## 4. Firewall: Defense (placeable)
| Level | Effect |
|---|---|
| **L1** | Deploy an 8×6-stud wall in front of you. Blocks bullets both ways. 150 HP, lasts 6 s. 15 s cooldown. |
| **A2 Rampart** | 250 HP, lasts 10 s. |
| **A3 Rampart** | **One-way:** you and teammates can shoot out through it; enemies can't shoot in. |
| **B2 Burn Wall** | The wall becomes a fire curtain: it blocks bullets and vision, but people can walk through. Enemies who do take 30 damage and are slowed 1.5 s. |
| **B3 Burn Wall** | The curtain moves forward 10 studs over 4 s, pushing the fight. |
| **G2 Mirror Wall** ⚡ | Thin glass wall (80 HP) that **reflects 25% of bullet damage back at the shooter**. *Quirk:* it reflects your team's bullets too. |
| **G3 Mirror Wall** ⚡ | 50% reflection and 2 charges. |

**Counter:** Packet and Flood (wall-piercing) break walls; flank around.

## 5. Lag Field: Control (zone)
| Level | Effect |
|---|---|
| **L1** | Throw an orb that creates a 10-stud zone for 4 s; enemies inside are slowed 40%. 16 s cooldown. |
| **A2 Latency** | Enemies inside also fire and reload 30% slower. |
| **A3 Latency** | Enemies inside take +15% damage. |
| **B2 Buffer** | Zone is 14 studs and lasts 7 s. |
| **B3 Buffer** | The first time an enemy tries to leave the zone, they're pulled back to its center. |
| **G2 Freeze Frame** ⚡ | A stasis bubble: **everything inside freezes for 1.5 s**: enemies, teammates, bullets in flight, and you if you're in it. |
| **G3 Freeze Frame** ⚡ | 2.5 s, and frozen enemies take +20% damage when it ends. |

**Counter:** stay out of the clear zone edge; Blink out; Rollback.

## 6. Ping: Info (reveal)
| Level | Effect |
|---|---|
| **L1** | A pulse that reveals enemies within 30 studs through walls for 2 s. 14 s cooldown. |
| **A2 Traceroute** | Revealed enemies stay marked for 4 s, visible to your whole team. |
| **A3 Traceroute** | Marked enemies take +10% damage. |
| **B2 Sonar** | Radius 50 studs, and leaves a sensor that pulses every 3 s for 9 s. |
| **B3 Sonar** | The sensor also shows the revealed enemies' **Mod cooldowns** ("Blink ready"). |
| **G2 Ping Spike** ⚡ | Reveal **everyone** within 60 studs for 4 s, but **you're revealed to them too**. |
| **G3 Ping Spike** ⚡ | You deal +20% damage to enemies you've revealed. |

**Counter:** the pulse is visible and audible; shoot the sensor (30 HP); move after you hear it.

## 7. Patch Up: Sustain (self-buff)
| Level | Effect |
|---|---|
| **L1** | Heal 40 HP over 2 s; you can move and shoot. 18 s cooldown. |
| **A2 Hotfix** | The 40 HP heal is instant. |
| **A3 Hotfix** | It also removes slows and debuffs and gives +25 overshield. |
| **B2 Support Patch** | Throw a heal pad (8 studs) that heals everyone on your team 15 HP/s for 4 s. |
| **B3 Support Patch** | The pad also gives 20% damage reduction. |
| **G2 Corrupted Patch** ⚡ | **Instant full heal**, then you lose 4 HP/s for 6 s. |
| **G3 Corrupted Patch** ⚡ | Overheal becomes overshield (up to +50), and the drain stops if you get a kill. |

**Counter:** burst them before the heal finishes; Packet Loss (Sticky) blocks the heal.

## 8. Overclock: Weapon buff (self-buff)
| Level | Effect |
|---|---|
| **L1** | For 5 s: +25% fire rate. 18 s cooldown. |
| **A2 Turbo** | Also +40% reload speed. |
| **A3 Turbo** | Kills during Overclock extend it by 3 s. |
| **B2 Precision** | Instead of fire rate: **no spread or bloom** for 5 s. |
| **B3 Precision** | Headshots deal ×2 instead of ×1.5 during Overclock. |
| **G2 Overheat** ⚡ | +60% fire rate and no ammo use for 4 s, but you **lose 8 HP/s**. |
| **G3 Overheat** ⚡ | Bullets also pierce Firewalls and players. |

**Counter:** the gun glows and hums; back off or block until it ends.

## 9. Rollback: Escape (rewind)
| Level | Effect |
|---|---|
| **L1** | Snap back to where you were 3 s ago, with the ammo you had then. 22 s cooldown. |
| **A2 Undo** | Also restores your HP to what it was 3 s ago. |
| **A3 Undo** | 15 s cooldown, and 30% damage reduction for 2 s after rewinding. |
| **B2 Save State** | First press drops a checkpoint (lasts 10 s); press again to return to it. |
| **B3 Save State** | Returning leaves a shockwave at the spot you left (30 damage), punishing chasers. |
| **G2 Crash Recovery** ⚡ | **Passive:** the first time you'd die this round, you auto-rewind 3 s instead. Your max HP drops to 60 for the rest of the round. |
| **G3 Crash Recovery** ⚡ | Enemies who damaged you in those 3 s are revealed for 4 s. |

**Counter:** a ghost trail shows where they'll return to; camp the checkpoint; Packet Loss blocks it.

---

## Bench (good ideas for the next set)
| Mod | Idea |
|---|---|
| **Honeypot** | Trap mine that tethers and reveals the first enemy to step near it |
| **Daemon** | Small auto-turret |
| **Proxy** | A hologram decoy you place |
| **Hyperlink** | Grapple to surfaces |
| **Incognito** | Short cloak |
| **Cache** | Store a second "loadout": swap gun instantly with a full mag |

## Open questions
- Should glitch paths be offered at L2 only, or also replace an L3 upgrade?
- Overclock B (Precision) + Root or Checksum might be too strong. Watch it in playtests.
- Crash Recovery could feel unfair in 1v1. Option: ranked bans it, or it reveals itself (a glowing magenta outline) the whole round.
