# Valorant gun mechanics (research, 2026-10-25)

**Why:** the user wants **precise gunplay** like Valorant, but **not** as restrictive about moving ("it won't be as restrictive as Valorant in how moving makes it impossible to shoot"). It should still be fun, like RIVALS. This note records how Valorant's guns really work, what RIVALS does differently, and what we take from each. The proposal it leads to is in [Gunplay](../01%20Design/Gunplay.md) → *v2: precise run-and-gun*.

Sources: the Valorant Wiki (Fandom) weapon pages and patch histories, read 2026-10-25 ([Weapons](https://valorant.fandom.com/wiki/Weapons), [Vandal](https://valorant.fandom.com/wiki/Vandal) and each gun's page); [Dexerto](https://www.dexerto.com/valorant/valorant-run-gun-accuracy-nerfed-episode-3-1598481/) and [Upcomer](https://upcomer.com/riot-addresses-running-and-gunning-in-latest-ask-valorant/) on Riot's run-and-gun changes; [Pro Game Guides](https://progameguides.com/roblox/all-weapons-and-how-to-get-them-in-roblox-rivals/) for RIVALS weapon stats (July 2024). Numbers move with patches; treat them as a reference, not gospel. Unit note: Valorant uses metres; in Roblox 1 m ≈ 3.6 studs.

---

## 1. How Valorant gunplay works

| Mechanic | How it works |
|---|---|
| **Damage** | Each gun has a body damage per range band (e.g. 0–30 m, 30–50 m). Head and leg damage are multipliers on it: head ×2.5–4 (rifles ×4, Vandal/Phantom one-tap), legs ×0.85 (Guardian ×0.75, Operator ×0.8). Decimals round down. 100 HP plus up to 50 armour. |
| **Falloff** | Steps, not curves: a fixed multiplier per band (Phantom ×0.897 after 20 m, Spectre ×0.846 / ×0.769). **Vandal, Bulldog, Guardian and the snipers have no falloff.** |
| **First-shot spread** | Almost every gun's first bullet has a tiny random cone: Phantom 0.2°, Vandal 0.25°, Guardian 0.1°, Ghost 0.3°, Classic 0.4°. Only the snipers and Guardian are perfect, and only when scoped/ADS. |
| **Spread growth** | Each further shot adds spread up to a per-gun **max** (Vandal 1°, Phantom 0.9°, Classic 1.8°). **Tap efficiency** sets how fast it grows if you re-fire early. **Gun recovery time** (~0.375 s on the Vandal) brings it back to first-shot accuracy. That's why tapping and short bursts are accurate. The Ares is the reverse: it gets *more* accurate while firing. |
| **Crouch** | Spread ×0.75–0.85 (machine guns ×0.6). |
| **ADS / alt-fire** | 1.15–1.5× zoom (snipers 2.5–5×). Lower spread (Vandal 0.25° → 0.157°), slightly slower fire rate (90%), 76% move speed, and the crosshair follows recoil. |
| **Movement penalty** | Added on top of spread, and it **scales with your actual speed** as you accelerate or slow down. Rifles: crouch-walk +0.8°, walk +3°, run +6°, air +10°. SMGs: walk +1°, run +2.5°. Sidearms: about +1–1.2° walk, +2.3–3° run. Snipers: +7.5 / 10 / 15 / 20° (useless on the move). Shotguns barely care (walk +1°). Shared per class, except sidearms. |
| **Deadzone** | Below **27.5% of max speed** you count as standing still. That's why counter-strafing works: tap the opposite key, drop under the threshold, and shoot with full accuracy. |
| **Landing** | +7° for 0.225 s after any landing (binary since v1.09). |
| **Spread shape** | Since v6.11, shots fired **while moving** are uniformly random inside the cone. Standing still, they're biased towards the centre. |
| **Recoil** | Rifles climb **vertically** first (a set number of "protected" bullets, 6 on the Vandal since v11.08), then sway **sideways**, with a chance to switch direction (10% on the Vandal; switches at least 0.6 s apart). Crouching cuts horizontal recoil by 15%. Running multiplies vertical recoil (×1.8). Hip fire: the bullets climb above the crosshair, which mostly stays put. ADS: the crosshair follows the recoil. |
| **Tagging** | Getting hit slows you 72.5% for a moment (shotgun pellets beyond 10 m: 30%). It punishes the player who keeps running after being shot. |
| **Wall penetration** | Low / Medium / High per gun (sidearms mostly Low, rifles Medium, Guardian/Sheriff/snipers/machine guns High). |
| **Equip** | Sidearms and SMGs 0.75 s, rifles and shotguns 1.0 s, snipers and machine guns 1.25 s (Operator 1.5 s). Skins can't change it, so the draw/cocking animation fits inside it. |
| **Reload** | Sidearms 1.5–2.25 s, rifles 2.5 s, snipers 2.3–3.7 s, Ares 3.25 s, Odin 5 s. |

**Riot's design philosophy:** moving while shooting is allowed and meant to be "powerful in certain situations". Riot has still repeatedly tightened it ("tag into accuracy", walk 2 → 3, run 5 → 6 in v9.10) so that **stopping before you shoot** is rewarded. That's the part that feels restrictive, and the part we soften.

## 2. Every Valorant gun (current values)

Damage = body / head / legs at the closest band (→ later bands). Spread is the first shot standing, hip (→ ADS); max = maximum spread. Movement = walk / run / air penalty.

### Sidearms
| Gun | Fire | Rate (/s) | Mag | Reload | Damage | Spread first → max | Movement | Identity |
|---|---|---|---|---|---|---|---|---|
| **Classic** | Semi (alt: 3-pellet burst) | 6.75 | 12 | 1.75 s | 26/78/22 → 22/66/18 (30 m+) | 0.4° → 1.8° | 1.1 / 2.3 / 7 | Free pistol; the alt-fire is a close-range mini-shotgun |
| **Shorty** | Semi, 15 pellets | 3.0 | 2 | 1.75 s | 11/22/9 per pellet (7–15 m ×0.55, 15 m+ ×0.27) | 4° cone | 1 / 2 / 4 | Pocket shotgun, one-shot up close |
| **Frenzy** | Auto | 10 | 13 | 1.5 s | 26/78/22 → 21/63/17 (20 m+) | 0.65° → 1.7° | 0.8 / 2 / 7 | Machine pistol |
| **Ghost** | Semi, silenced | 6.75 | 13 | 1.5 s | 30/105/25 → 25/87/21 | 0.3° → 1.65° | 1.1 / 2.3 / 7 | Accurate; one-taps an unarmoured head |
| **Bandit** | Semi | 5.1 | 8 | 1.5 s | 39/152/33 → 39/128 → 34/112 | 0.275° → 1.97° | 1.2 / 2.7 / 7 | Head-tap pistol (×3.9 up close) |
| **Sheriff** | Semi revolver | 4.0 | 6 | 2.25 s | 55/159/46 → 50/145/42 | 0.25° → 2.75° | 1.2 / 3 / 7 | One-tap headshot, high penetration |

### SMGs
| Gun | Fire | Rate | Mag | Reload | Damage | Spread | Movement | Identity |
|---|---|---|---|---|---|---|---|---|
| **Stinger** | Auto (ADS: 4-round burst) | 16 | 20 | 2.25 s | 27/67/22 → 23/57/19 (15 m+) | 0.65° → 1.5° (ADS 0.35°) | 1 / 2.5 / 10 | Shred up close |
| **Spectre** | Auto, silenced | 13.33 | 30 | 2.25 s | 26/78/22 → 22/66 → 20/60 | 0.4° → 1.4° (ADS 0.25°) | 1 / 2.5 / 10 | Run-and-gun SMG |

### Shotguns
| Gun | Fire | Rate | Mag | Reload | Damage per pellet | Spread | Identity |
|---|---|---|---|---|---|---|---|
| **Bucky** | Pump, 15 pellets (alt: air-burst canister) | 1.1 | 5 | 2.5 s (0.5 s/shell) | 17/34/14 (8–12 m ×0.65, 12 m+ ×0.45) | 3° cone, barely affected by moving (run +0.2°) | One-shot to 8 m |
| **Judge** | Auto, 12 pellets | 3.5 | 7 | 2.2 s | 17/34/14 (10–15 m ×0.59, 15 m+ ×0.41) | 2.5° → 4° | Fast auto shotgun |

### Rifles
| Gun | Fire | Rate | Mag | Reload | Damage | Spread | Movement | Identity |
|---|---|---|---|---|---|---|---|---|
| **Bulldog** | Auto (ADS: 3-round burst) | 10 | 24 | 2.5 s | 35/115/29, no falloff | 0.3° → 1.25° (ADS burst 0.1°) | 3 / 6 / 10 | Budget rifle |
| **Guardian** | Semi | 5.25 | 12 | 2.5 s | 65/195/49, no falloff | 0.1° (ADS 0°) → 1.58° | 3 / 6 / 10 | DMR: one-tap head, 2 body |
| **Phantom** | Auto, silenced | 11 | 30 | 2.5 s | 39/156/33 → 35/140/29 (20 m+) | 0.2° → 0.9° (ADS 0.11°) | 3 / 6 / 10 | Faster and steadier, falloff |
| **Vandal** | Auto | 9.75 | 25 | 2.5 s | 40/160/34, **no falloff** | 0.25° → 1° (ADS 0.157°) | 3 / 6 / 10 | **One-tap headshot at any range**; harder recoil |

### Snipers
| Gun | Fire | Rate | Mag | Reload | Damage | Spread | Identity |
|---|---|---|---|---|---|---|---|
| **Marshal** | Bolt | 1.5 | 5 | 2.5 s | 101/202/85 | hip 1°, scoped 0° (3.5×) | Cheap one-shot head |
| **Outlaw** | Double-barrel | 2.75 | 2 | 2.3 / 3.8 s | 140/238/119 | hip 3.5°, scoped 0° (3.5×) | Two quick big shots |
| **Operator** | Bolt | 0.6 | 5 | 3.7 s | 150/255/120 | hip 5°, scoped 0° (2.5× / 5×) | One-shot body; slow while scoped |

### Machine guns
| Gun | Fire | Rate | Mag | Reload | Damage | Spread | Identity |
|---|---|---|---|---|---|---|---|
| **Ares** | Auto | 13 | 50 | 3.25 s | 30/75/25 → 28/70/23 | 1° → **0.7° min** (gets more accurate) | Spray and hold the line |
| **Odin** | Auto, spins up | 12 → 15.6 | 100 | 5 s | 38/95/32 → 31/77/26 | 0.8° → 1.3° | Wall-spam, high penetration |

**Melee:** front 50 / 75 (heavy), back 100 / 150, 2 m reach.

## 3. RIVALS (the "fun" reference)
- **Low damage per bullet, small headshot bonus:** Assault Rifle 13 damage every 0.10 s, crit ×1.5 (about 8 body shots or 6 heads, so 0.5–0.7 s to kill). Handgun 12 / 0.10 s; Revolver 35 / 0.40 s; Sniper 70, crit ×2.14 (head 150).
- **Weight changes speed:** rifles −10%, sniper −15%, RPG −20%, minigun −25%; sidearms normal.
- **Accurate enough on the move** that strafe-shooting and jump-shooting are normal play. Moving costs some accuracy, but never makes it a coin flip, which is what makes it fun on a phone.
- **Long-ish fights.** The skill is tracking and staying on target more than one-tap reactions.

## 4. What we take
| From Valorant (precision) | From RIVALS (fun) |
|---|---|
| Tiny first-shot spread; a standing tap goes where you aim | Moving costs a **little** accuracy, never a lot |
| Spread grows per shot and fully recovers after a short pause (tap and burst control) | Strafe-shooting, slide-shooting and ADS-strafing are real tactics |
| Learnable recoil: a set vertical climb, then sideways sway | No counter-strafe tax: a gentle deadzone, not a hard rule |
| Big headshot reward, per-gun identity (one-tap guns are rare) | Readable, satisfying feedback; short, punchy fights |
| Step falloff per gun; some guns (Vandal-type) have none | Weight slows heavy guns a little |
| Per-class movement penalties; snipers really need to stop | |
| Equip, reload and ADS times per class, with animations that fit inside them | |
