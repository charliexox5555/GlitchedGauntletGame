# Gun Balance

Health, shields and every gun's damage. The user set the goal on 2026-11-02: **sit between RIVALS and Valorant.** Kills should come easily, but rounds should last a good while, and it shouldn't be one or two headshots and you're dead. Some guns can be better than others, but the levels should sit close together. **Status: numbers set on paper by the targets below. Nobody has played them yet, so expect to tune them.**

## Health and shield
- **Health:** always 100. No regen; heals come from abilities and only restore health.
- **Shield:** sits on top of health and takes damage first. It lasts the round and doesn't come back.
- **Sidearm and Light phases (rounds 1–3):** the gun you choose decides your shield. The stronger the gun, the less shield. That's the real choice in those rounds: a Sheriff hits hardest but you have 100 total, a Classic hits softest but you have 150.
- **Heavy and Elite phases (round 4 on):** everyone gets 50, so the guns are the only difference.
- **Damage order:** every source goes through one function (`WeaponService.hurt`), so guns, abilities and the test opponent can't skip the shield.
- **If the clock runs out:** health plus shield decides the round.

| Shield | Sidearm phase | Light phase |
|---|---|---|
| **50** (150 total) | Classic | Akimbo |
| **25** (125 total) | Ghost, Shorty | Stinger, Spectre, Bulldog, Judge, Bucky |
| **0** (100 total) | Sheriff | Marshal |

## Targets
| Thing | Target | Why |
|---|---|---|
| Body kill against 150 | **0.5–0.75 s** for primary guns | LihFolk: 0.4–0.8 s suits Roblox arena play. Valorant's Vandal is 0.31 s. RIVALS is about a second by our estimate |
| Sidearms | Up to about 1 s | They're the warm-up round |
| Head multiplier | **About 1.6×** (sidearms and machine guns 1.5–1.6×) | Valorant is 3.5–4×, RIVALS' Assault Rifle is 1.25×, LihFolk suggests 1.5–2× |
| Headshots to kill at 150 | **3–5** on anything not a sniper | So aim is rewarded without ending the fight instantly |
| One-shot headshots | **Snipers only**, and the Marshal only against no shield | Sniper fantasy: RIVALS' Sniper one-shots a head too |
| One-shot body | **Nothing** | |
| Shotguns | Two or three shots up close against 125–150, and fall off hard with range | Point-blank power without instant kills |

| Reference | Body / head | Head × |
|---|---|---|
| [RIVALS Assault Rifle](https://robloxrivals.fandom.com/wiki/Assault_Rifle) | 12 / 15 | 1.25 |
| [RIVALS Burst Rifle](https://robloxrivals.fandom.com/wiki/Burst_Rifle) | 20 / 25 | 1.25 |
| [RIVALS Shotgun](https://robloxrivals.fandom.com/wiki/Shotgun) | 8 / 12 × 10 pellets | 1.5 |
| [RIVALS Sniper](https://robloxrivals.fandom.com/wiki/Sniper) | 50 / 150 | 3 |
| [Valorant Vandal](../03%20Research/Valorant%20Gun%20Mechanics.md) | 40 / 160 | 4 |

**Gaps:** RIVALS' fire rates and health weren't in what I read, so its time-to-kill is an estimate. No source says how Gauntlet: Glitched gives out shields (a gameplay screenshot shows 50 shield and 100 health at one stage), so **the shield rule is our own design** from the user's description. Its [wiki](https://wiki.playvalorant.com/en-us/Gauntlet:_Glitched) does list three weapon categories per stage. We could copy that so a draft always offers three different roles; ours deals three at random from the tier.

## Who beats who
Fights the numbers intend, with both players hitting every body shot:

| Fight | Time to kill | Reading |
|---|---|---|
| Classic (150) vs Sheriff (100) | 0.59 s vs 0.50 s | The Sheriff is a little faster, if you can control its kick |
| Classic (150) vs Ghost (125) | 0.89 s vs 0.89 s | Even. The Ghost is more accurate; the Classic has a close burst |
| Stinger (125) vs Spectre (125) | 0.45 s vs 0.53 s | Stinger up close, Spectre further out with a steadier gun and a bigger mag |
| Stinger (125) vs Akimbo (150) | 0.53 s vs 0.64 s | Akimbo has more shield and ammo but hip fire only |
| Stinger (125) vs Bulldog (125) | 0.45 s vs 0.55 s | Stinger wins close, the Bulldog has no falloff |
| Vandal vs Phantom (both 150) | 0.62 s vs 0.64 s | Even on body. Head favours the Vandal, ease of use the Phantom |
| Vandal vs Guardian (both 150) | 0.62 s vs 0.57 s | The Guardian must land 4 separate shots; misses cost far more |

## The numbers
Generated from `Config/Weapons` by `tools/balance/gun_table.py`: rerun it after changing a gun. Each cell is shots to kill (time). Shotguns assume every pellet hits. Falloff, moving spread and recoil aren't counted.

<!-- table:start -->
### Sidearm phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Classic** | Sidearm | 50 | 20 / 32 | 6.8/s | 12 | 5 (0.59s) · 7 (0.89s) · 8 (1.04s) | 4 (0.44s) · 4 (0.44s) · 5 (0.59s) |
| **Ghost** | Sidearm | 25 | 23 / 37 | 6.8/s | 13 | 5 (0.59s) · 6 (0.74s) · 7 (0.89s) | 3 (0.30s) · 4 (0.44s) · 5 (0.59s) |
| **Sheriff** | Sidearm | 0 | 50 / 74 | 4.0/s | 6 | 2 (0.25s) · 3 (0.50s) · 3 (0.50s) | 2 (0.25s) · 2 (0.25s) · 3 (0.50s) |
| **Shorty** | Sidearm | 25 | 6 / 9 × 15 pellets | 3.0/s | 2 | 2 (0.33s) · 2 (0.33s) · 2 (0.33s) | 1 (0.00s) · 1 (0.00s) · 2 (0.33s) |

### Light phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Bulldog** | Rifle | 25 | 22 / 36 | 9.1/s | 24 | 5 (0.44s) · 6 (0.55s) · 7 (0.66s) | 3 (0.22s) · 4 (0.33s) · 5 (0.44s) |
| **Akimbo** | SMG | 50 | 15 / 23 | 12.5/s | 36 | 7 (0.48s) · 9 (0.64s) · 10 (0.72s) | 5 (0.32s) · 6 (0.40s) · 7 (0.48s) |
| **Spectre** | SMG | 25 | 16 / 26 | 13.3/s | 30 | 7 (0.45s) · 8 (0.53s) · 10 (0.67s) | 4 (0.22s) · 5 (0.30s) · 6 (0.38s) |
| **Stinger** | SMG | 25 | 19 / 30 | 13.3/s | 20 | 6 (0.38s) · 7 (0.45s) · 8 (0.53s) | 4 (0.22s) · 5 (0.30s) · 5 (0.30s) |
| **Bucky** | Shotgun | 25 | 8 / 12 × 15 pellets | 1.1/s | 5 | 1 (0.00s) · 2 (0.91s) · 2 (0.91s) | 1 (0.00s) · 1 (0.00s) · 1 (0.00s) |
| **Judge** | Shotgun | 25 | 6 / 9 × 12 pellets | 3.5/s | 7 | 2 (0.29s) · 2 (0.29s) · 3 (0.57s) | 1 (0.00s) · 2 (0.29s) · 2 (0.29s) |
| **Marshal** | Sniper | 0 | 60 / 120 | 1.5/s | 5 | 2 (0.67s) · 3 (1.33s) · 3 (1.33s) | 1 (0.00s) · 2 (0.67s) · 2 (0.67s) |

### Heavy phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Ares** | MachineGun | 50 | 18 / 27 | 13.0/s | 50 | 6 (0.39s) · 7 (0.46s) · 9 (0.62s) | 4 (0.23s) · 5 (0.31s) · 6 (0.39s) |
| **Guardian** | Rifle | 50 | 46 / 74 | 5.3/s | 12 | 3 (0.38s) · 3 (0.38s) · 4 (0.57s) | 2 (0.19s) · 2 (0.19s) · 3 (0.38s) |
| **Phantom** | Rifle | 50 | 21 / 34 | 11.0/s | 30 | 5 (0.36s) · 6 (0.45s) · 8 (0.64s) | 3 (0.18s) · 4 (0.27s) · 5 (0.36s) |
| **Vandal** | Rifle | 50 | 24 / 40 | 9.7/s | 25 | 5 (0.41s) · 6 (0.52s) · 7 (0.62s) | 3 (0.21s) · 4 (0.31s) · 4 (0.31s) |
| **Outlaw** | Sniper | 50 | 75 / 160 | 2.7/s | 2 | 2 (0.36s) · 2 (0.36s) · 2 (0.36s) | 1 (0.00s) · 1 (0.00s) · 1 (0.00s) |

### Elite phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Odin** | MachineGun | 50 | 20 / 30 | 12.0/s | 100 | 5 (0.33s) · 7 (0.50s) · 8 (0.58s) | 4 (0.25s) · 5 (0.33s) · 5 (0.33s) |
| **Operator** | Sniper | 50 | 125 / 250 | 0.6/s | 5 | 1 (0.00s) · 1 (0.00s) · 2 (1.67s) | 1 (0.00s) · 1 (0.00s) · 1 (0.00s) |
<!-- table:end -->

**Knife, unchanged:** front 50, heavy 75, backstab 100.

## How to tune this
Think in **breakpoints**, not damage: what matters is the number of shots. Against 150, 24 damage takes 7 shots and 25 takes 6, while 25 and 29 both take 6. So one small change can remove a whole shot and a bigger one can do nothing. Change a gun in `Config/Weapons`, rerun the script, and it warns about anything that leaves the targets.
