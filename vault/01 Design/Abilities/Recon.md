# Recon (was Ping)

**Status:** spec locked 2026-10-29 · built 2026-10-29 (built overnight; waiting for the user's Studio test)
**Inspiration:** Sova's Recon Bolt (Valorant), **without the bow**. You fire a sensor dart from a **compact dart launcher**; it sticks, pulses twice, and reveals enemies the dart can see.
**Remove from the old Ping:** the instant reveal pulse around yourself.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Ready | Press the key → the gun lowers, the **dart launcher** comes up and a dart is loaded. Press again or swap weapons to cancel (costs nothing) |
| Charge | **Hold LMB to charge** the shot distance (~1 s to full); release to fire. A quick tap = a short shot |
| Bounces | **RMB (before firing) cycles 0 / 1 / 2 wall bounces.** Bounce physics are shared with the Molly/Frost projectile code |
| Flight | A fast dart with a slight arc. After its bounces it **sticks to the next surface** it hits (walls, floor, ceiling) |
| Pulses | Once stuck: **2 pulses, 1.5 s apart** (first pulse ~0.5 s after sticking), then it goes dead |
| Reveal | Each pulse reveals **enemies within 40 studs that the dart has line of sight to** (hiding behind cover beats it) |
| Revealed look | A **live outline** that follows them, **visible through walls to the caster's team, for 2 s** |
| Warning | Revealed players get a **distinct pulse sound + a brief red screen-edge flash and "Revealed" cue** |
| Destroyable | **1 hit from any bullet destroys the dart** (stops further pulses) |
| Charges | **1 charge, 30 s cooldown** (starts each round ready; usually 1, sometimes 2 uses per round). Unlimited in test mode |

## Server
- The server simulates the dart (charge power, bounces, stick point), runs the pulses and the line-of-sight checks, and decides who's revealed.
- **Only the caster's team receives the outline data**: never send revealed positions to anyone else.
- The dart is a hittable target for the weapon system (1 HP).
- Validates: holding Recon, a charge ready, the origin near the head, finite direction and charge values, bounce count 0–2, rate limits.

## First person
- **Launcher out + load dart:** the gun lowers, the launcher comes up and a dart slides in.
- **Charge:** while holding LMB, the launcher hums and a charge light fills. RMB clicks a **bounce counter** (0/1/2 small lights on the launcher).
- **Fire:** a solid thump and recoil kick, then the launcher drops and the gun comes back.
- **Charge meter (placeholder HUD, Valorant-style):** under the crosshair while the launcher is up: a POWER bar with ticks at 25/50/75% and the percent (MAX, flickering, at full), and BOUNCES pips for the RMB pick.

## Look (Blender)
- **Dart launcher:** a compact, chunky flare-gun-style launcher with a charge light and a 3-light bounce counter, in the current tactical style (matte, PBR). It goes through the gun pipeline.
- **Dart:** a slim sensor dart with a small blinking light; it embeds where it sticks.
- **In flight:** a faint light trail.
- **Pulse:** an expanding scan ring/sphere from the dart (visible to everyone, so enemies know where it is); the dart's light flashes on each pulse.
- **Revealed enemies:** a clean outline/highlight in the enemy colour for 2 s.
- **Destroyed:** sparks and the light dies.

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Recon_Equip` | Launcher out + dart load |
| `Recon_Charge` | Charge hum (rises) |
| `Recon_BounceSelect` | Bounce counter click |
| `Recon_Fire` | Launcher thump |
| `Recon_Flight` | Dart whistle (3D) |
| `Recon_Bounce` | Ricochet tick (3D) |
| `Recon_Stick` | Dart embeds (3D) |
| `Recon_Pulse` | Scan pulse (3D, ~60 studs: everyone hears it) |
| `Recon_Revealed` | Cue for the player who got revealed (2D) |
| `Recon_Destroyed` | Dart shot down (3D) |

### Placeholder sounds (in `Config/ModSounds` → `Recon`; unauditioned, swap the id)
All ProSoundEffects library audio (public, no upload). Search terms that worked: `"Crossbow Movement"`, `"Power Up"`, `"Selector Switch"`, `"Launcher" Pro Sound Effects`, `"Arrow Pass"`, `"Ricochet"`, `"Arrow"`, `"Spaceship Sonar"`, `"Radar Bleeps"`, `"Alarm"`, `"Electricity"`, `"Light Bulb"`.
| Hook | Id | Name (start / cut) | Volume / pitch | Alternatives |
|---|---|---|---|---|
| `Recon_Equip` | 9114004483 | Crossbow Movement Latches 13 (from 0.18, 1.6 s) | 0.5 / 1.1 | 9116973855, 9114004334 |
| `Recon_Charge` | 9117882920 | Power Up Accelerating Motors 1 (from 0.25, loops to 2 s, pitched up by code) | 0.5 | 9117882918, 9118327718 |
| `Recon_BounceSelect` | 9118727210 | Rotary Selector Switch Twisting 9 (from 0.2, 0.15 s) | 0.6 / 1.1 | 9118726753, 9118727189 |
| `Recon_Fire` | 9114659666 | Grenade Launcher 2 (one thoonk, 0.22 s) | 0.7 / 1.1 | 9114659685, 9117052716 |
| `Recon_Flight` | 9125363711 | Arrow Pass Bys Zooming Past Distant Landing 7 (loops 0.8–1.5 s) | 0.6 / 1.15 | 9113168250, 9113166206 |
| `Recon_Bounce` | 9118168962 | Ricochet Metal 5 (from 0.14, 0.3 s) | 0.5 / 1.3 | 9118168612, 9118168610 |
| `Recon_Stick` | 9113162981 | Arrow In And Hit 6 (from 0.5) | 0.6 / 0.95 | 9113161857, 9113160887 |
| `Recon_Pulse` | 9125981390 | Spaceship Sonar Low And High Pitch Tonal Throbs 1 (1.5 s; 60 studs). A library recording but synth-like: if too synthetic, try 9112776779 (Vintage Radar Bleeps) | 0.9 | 9125984483, 9112776779 |
| `Recon_Revealed` | 9113719080 | Car Alarm Chirp 1 (from 0.14, 0.35 s) | 0.5 / 1.05 | 9113719083, 9118777141 |
| `Recon_Destroyed` | 9119594871 + 9116264240 | Static Zap Body Two Buzzy Impacts 2 + Light Bulb 1 | 0.6 + 0.4 | 9114247527, 9114249288 |

## Build notes (2026-10-29)
- **Removed:** the Ping's instant pulse. `ReplicatedStorage.Abilities` has no Ping model.
- **New use type `HeldCharge`:** hold the Mod (the launcher comes up), hold LMB to charge (`chargeTime` 1 s; the charge light fills, the hum rises), release to fire; RMB before firing cycles 0 / 1 / 2 bounces (the launcher's two bounce lights, and the hint shows "Bounces: n"). `ModUse` carries the charge and bounces; the server caps the charge to how long it saw the hold, and the bounces to 0–2.
- **Rules:** `Mods/Recon`: speed 45 (tap) to 130 (full), a slight arc; the shared projectile code bounces it then it sticks to the next surface. Stuck, it's a 1-HP Mod object (`ModEntities`; any bullet destroys it through the existing object-hit path). Pulses at 0.5 s and 2 s after sticking: enemies within 40 studs the dart can see are revealed to your team only (`ModReveal`, outline through walls, 2 s); revealed players get the cue, a red edge flash and "REVEALED". Measured in Studio: the dart stuck 0.18 s after the shot, two pulses 1.5 s apart, each revealed the enemy dummy and a range dummy.
- **Models:** Blender `tools/blender/build_mod_recon.py` (launcher, handheld, 2.9K tris, `Charge_Energy`, `Bounce1/2_Energy`, the loaded `Dart_*` hidden when fired) and `build_mod_recondart.py` (sensor dart, 1.3K tris, `Light_Energy` blinks and flashes on pulses), uploaded (101313572671047, 116053167550293) and built into **`ReplicatedStorage.Abilities.Recon` / `ReconDart`** (backups in `art-source/abilities/Studio/`). Preview `02 Art/References/abilities/recon/recon_model.jpg`.
- **Effects:** Blender-rendered textures (`tools/vfx/make_recon_vfx.py`, `Config/VfxTextures RECON_*`): the scan ring on each pulse (plus the ground scan wave), the dart's glow trail in flight. The launcher kicks on fire (`ITEM_ACTIONS.LauncherFire`).
- **Icon:** still the Ping's. The Look section mentions a 3-light bounce counter; the model has 2 (0 / 1 / 2 needs only two).


## Changes from the user's feedback (2026-10-29)
- **Charge meter:** `ModController.chargeState()` feeds a meter in `ModHudController` (fades in with the launcher, the fill eases to the charge). Temporary until the HUD rework.
- **The dart reads in flight:** a bright light streak behind it (a camera-facing `Trail` with the `RECON_TRAIL` texture, white to team colour, 0.3 s) and a small team-coloured light on it, both off when it sticks; bigger glow particles (`ModFxController` `streakOf`).

## Mobile
Tap the Recon button to ready it. **Hold Fire** to charge, release to shoot. A **Bounce** context button cycles 0/1/2. Tap the Recon button again to cancel.

## Counter-play
Hear it land and **shoot the dart** (1 hit), or break line of sight before the pulse. When you're revealed, move: the outline only lasts 2 s.

## Upgrades (L2/L3)
Decided 2026-11-03 in [Upgrade Paths](Upgrade%20Paths.md) → "6. Recon" (the source of truth for the numbers). Built 2026-11-03, **waiting for the hub's Studio playtest**. Numbers in `Config/Mods` → `Recon.levels`.

| Level | What it does in the game |
|---|---|
| **A2 Recharge** | Back 20 s after use (was 30). |
| **A3 Recharge** | Back 12 s after use. |
| **B2 More Pulses** | 3 pulses, 1.5 s apart (at 0.5, 2 and 3.5 s after sticking). The dart stays up 4.1 s. |
| **B3 More Pulses** | 5 pulses (up to 6.5 s); the dart stays up 7.1 s, so it's a bigger target to shoot down. |
| **G2 Ping Spike** ⚡ | One big pulse 0.5 s after sticking: **every enemy within 60 studs, through walls** (no line-of-sight check), revealed to your team for 4 s. The dart can still be shot down in that 0.5 s. No drawback. |
| **G3 Ping Spike** ⚡ | As G2, and **you deal +20% damage** (guns and Mods) to the enemies it revealed, for the 4 s. |

### How it's built
- **A and B are numbers only.** The dart's life is `pulseDelay + pulseGap × (pulses − 1) + 0.6`, already computed from the stats, and every pulse is drawn on its own (`ReconPulse`), so nothing on the client assumed 2 pulses. Recon has no HUD "active" bar.
- **G2** (`Mods/Recon`, `behaviour = "Spike"`, `pulses = 1`): the spike uses `Reveal.enemiesNear` without `Target.visible`, calls `ctx.reveal(seen, 4, "Spike")` and sends `ReconPulse` with `spike = true`.
- **G3** (`bonusDamage = 0.2`): the spike records `marks[caster][victim] = { untilT, bonus }` (server time). `Recon.module.server` registers an `api.modifier` that multiplies the caster's damage to a marked victim until `untilT` (an expired mark is dropped when it's next looked up or the caster spikes again). Marks are cleared at round start (`api.onRefill`) and when the caster leaves (and a leaving victim's character is dropped from every caster's marks). Victims are character models, so a respawned enemy isn't marked.
- **Reveal style (small shared change):** `ctx.reveal` takes an optional `style`. With one, `ModReveal` carries a 3rd argument `{ style, caster, id, level }` to the caster's team, and the revealed player's `Revealed` ModFx carries `style`. `ModFxController.onReveal` hands a styled reveal to `UpgradeFx.onFx("Reveal", …)` first.

### Look and sound (client, `Util/UpgradeFx/Recon.luau`)
Theme: a corrupted network ping, over the magenta glitch static (`COLORS.glitch`), team colour cyan / orange-red as usual. Everything is built in code (parts, `ModVfx` quads, existing `RECON_*` / `MOD_*` textures); no new assets.
- **Arming (stuck, before the spike):** dead pixels (small neon slabs, magenta / team colour / white) crackle around the dart and spread as the spike nears; a rising whine. This is the shoot-it-down window.
- **The spike:** replaces the clean L1 scan. A ring of 36 torn pixel slabs and a ForceField shimmer shell sweep out to 60 studs in **stepped, jittered frames** (14 fps, dropouts, colour tearing). The slab ring has an AlwaysOnTop `Highlight`, so **everyone in range sees the wave front through walls**. Also: magenta and team-coloured glitch rings at three heights spinning against each other, a magenta ground scan, a static burst at the dart, a small camera thump within range, and a **screen tear** (magenta bars) as the wave passes you. Sound: the sonar throb pitched down into a boom plus a static layer (`Recon.spike`, `spikeStatic`).
- **Revealed enemies (caster's team):** a glitched outline that tears between magenta, the enemy colour and white (the outline never drops out, so they stay tracked; the fill flickers). At **G3, the caster** sees a jittering **"+20%"** tag over each marked enemy (it sometimes scrambles, e.g. "+2#%") for as long as the bonus lasts. Teammates see the outline only (the bonus is the caster's).
- **The revealed player:** the usual warning (cue, red edge flash, "REVEALED") plus magenta screen tears and a static burst (`Recon.spikeRevealed`).
- **Sound hooks (placeholders, reusing ids already in the lists above, retuned; audition later):** `Recon_SpikeArm` ("Power Up Accelerating Motors 3", fast), `Recon_Spike` (the sonar at pitch 0.62, ~120 studs), its static layer ("Static Many Various Length Bursts 24"), `Recon_SpikeRevealed`.

### Name and card text proposals (not applied: the names match Upgrade Paths)
Card text is applied in `Config/Mods` (`note`, ≤ 72 chars). Names to consider:
| Path | Now | Proposal | Why |
|---|---|---|---|
| A | Recharge | keep (alt: **Quick Relay**) | "Recharge" is also Molly's A; the same word for the same effect reads fastest in a draft. |
| B | More Pulses | **Long Watch** (alt: **Echo**) | Says what you get (the dart keeps watching longer) instead of a count. |
| G | Ping Spike | keep (alt: **Lag Spike**) | Fits the glitch theme (a network spike), and players know "ping". |

### Studio playtest checklist (for the hub)
1. **A2/A3:** use Recon in the dev panel at A2 / A3: the slot comes back after 20 / 12 s (unlimited test mode off).
2. **B2/B3:** 3 / 5 pulses, 1.5 s apart, each revealing the dummy in sight; the dart blinks and flashes on each; shooting it stops the rest.
3. **G2:** a dummy behind a wall within 60 studs is revealed (glitched outline, 4 s); one beyond 60 isn't; the wave front shows through walls and stutters; the dart arms with dead pixels and a whine; shooting it within 0.5 s cancels the spike (no reveal).
4. **G3:** shoot a revealed dummy: damage numbers / hit confirm are ×1.2 for 4 s, then back to normal; "+20%" shows only for the caster. A teammate's damage isn't boosted.
5. **Two-player:** the revealed player gets the normal warning plus the magenta tear; a viewer the wave passes gets a short tear; nobody on the enemy side sees outlines.
6. Output: no errors from `UpgradeFx` / the damage modifier; `ReconUpgradeFx` in Workspace is empty after the effects end.
