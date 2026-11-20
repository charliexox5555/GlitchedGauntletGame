# Gun Balance

The balance target is enough time to react while keeping a clear advantage for aim, range and higher weapon tiers. This pass reviews all 17 firearms, tunes 11, and replaces the earlier one-shot body rule for the Operator.

## Health and shield
- **Health:** always 100. No regen; heals come from abilities and only restore health.
- **Shield:** sits on top of health and takes damage first. It lasts the round and doesn't come back.
- **Sidearm and Light phases (rounds 1–3):** the gun you draft decides your shield. Round-one Sheriff has 100 total. Round-two Sheriff has 150 total and gives up the primary slot for that round.
- **Heavy and Elite phases (round 4 on):** everyone gets 50, so the guns are the only difference.
- **Damage order:** every source goes through one function (`WeaponService.hurt`), so guns, abilities and the test opponent can't skip the shield.
- **If the clock runs out:** health plus shield decides the round.

| Shield | Sidearm phase | Light phase |
|---|---|---|
| **50** (150 total) | Classic | Sheriff in round 2 |
| **25** (125 total) | Ghost, Shorty | Stinger, Spectre, Bulldog, Judge, Bucky |
| **0** (100 total) | Sheriff | Marshal |

## Targets
| Thing | Target | Why |
|---|---|---|
| Body kill against 150 | **0.75–0.9 s** for primary guns (was 0.5–0.75 s until 2026-11-12) | The owner wanted longer fights, nearer RIVALS (about a second by our estimate) than Valorant (Vandal 0.31 s). LihFolk: 0.4–0.8 s suits Roblox arena play, so this sits at its top edge |
| Sidearms | Up to about 1.3 s (was 1 s) | They're the warm-up round |
| Head multiplier | **About 1.6×** (sidearms and machine guns 1.5–1.6×) | Valorant is 3.5–4×, RIVALS' Assault Rifle is 1.25×, LihFolk suggests 1.5–2× |
| Headshots to kill at 150 | **3–5** on anything not a sniper | So aim is rewarded without ending the fight instantly |
| One-shot headshots | Operator at 150. Marshal at 100. Outlaw at 125, below its standard phase's 150. | Reward precision and let shields matter |
| Single body shot at full health | A full-health fighter survives every gun's body hit. Operator deals 95, 76 to legs. | A body hit leaves a chance to break sight or fight back |
| Shotguns | Strong up close with steep falloff. Ideal pellet volleys are listed below. | Position and pellet placement drive their advantage |

| Reference | Body / head | Head × |
|---|---|---|
| [RIVALS Assault Rifle](https://robloxrivals.fandom.com/wiki/Assault_Rifle) | 12 / 15 | 1.25 |
| [RIVALS Burst Rifle](https://robloxrivals.fandom.com/wiki/Burst_Rifle) | 20 / 25 | 1.25 |
| [RIVALS Shotgun](https://robloxrivals.fandom.com/wiki/Shotgun) | 8 / 12 × 10 pellets | 1.5 |
| [RIVALS Sniper](https://robloxrivals.fandom.com/wiki/Sniper) | 50 / 150 | 3 |
| [Valorant Vandal](../03%20Research/Valorant%20Gun%20Mechanics.md) | 40 / 160 | 4 |

## Who beats who
Close-range body shots with full accuracy and fresh weapons:

| Fight | Time to kill | Reading |
|---|---|---|
| Classic (150) vs Sheriff (100) | 0.89 s vs 0.75 s | The Sheriff is a little faster, if you can control its kick |
| Classic (150) vs Ghost (125) | 1.04 s vs 1.04 s | Classic has more shield. Ghost has better head breakpoints against full shield |
| Stinger (125) vs Spectre (125) | 0.67 s vs 0.75 s | Stinger gets the point-blank edge. Spectre keeps damage and control farther out |
| Stinger (125) vs Bulldog (125) | 0.67 s vs 0.77 s | Bulldog retains its damage and can penetrate thin cover |
| Vandal vs Phantom (both 150) | 0.82 s vs 0.82 s | Even on body. Head favours the Vandal, ease of use the Phantom |
| Vandal vs Guardian (both 150) | 0.82 s vs 0.76 s | The Guardian must land 5 separate shots; misses cost far more |
| Odin vs Vandal (both 150) | 1.01 s vs 0.82 s | From a fresh burst the rifle is faster. A fully spun-up Odin reaches 0.83 s and can sustain pressure from its 75-round magazine |
| Outlaw vs Operator (both 150) | 4.22 s vs 1.45 s | Outlaw's two fast body shots leave 14 HP. It benefits from prior damage or a sidearm finish. A clean Operator headshot still kills immediately |

## Wall penetration (2026-11-12)
The owner: "wall penetration isn't really good, not on the maps", "the Odin can penetrate through the walls an infinite". It used to need a `ThinWall` tag on the part (no built map has one) or be `"All"`, which ignored every wall. Now it is measured on the wall itself (`Util/Penetration`, numbers in `Config/Combat` `PENETRATION`): each round has a budget of wall it can pass, along its own line, and loses damage per wall.

| Class | Guns | Wall it gets through | Damage left |
|---|---|---|---|
| None | Classic, Ghost, Shorty, Stinger, Spectre, Judge, Bucky, Knife | Nothing | |
| Light | Vandal, Phantom, Bulldog, Guardian, Ares, Odin, Sheriff, Marshal, Outlaw | 1.6 studs, one wall | 60% |
| Heavy | Operator | 4.5 studs in total, up to two walls | 70%, then 49% |

- A wall hit at a shallow angle counts as thicker, because the round travels further through it. Terrain stops everything. Parts tagged `ThinWall` (the range's plywood) count as 0.5 studs.
- Current one-wall body damage before rounding is 10.8 for Vandal, 7.8 for Odin and 66.5 for Operator. Penetration still depends on the actual distance through the part.
- The same rule runs in three places: the shooter's client, the server's check of each hit, and the bots' own shots.

## The numbers
Generated from `Config/Weapons` by `tools/balance/gun_table.py`. Each cell shows shots to kill and ideal elapsed time from the first shot, including spin-up and empty reloads. Shotguns assume every pellet hits. The table uses base damage before falloff, recoil and movement. Sidearm shields show the round-one rules.

<!-- table:start -->
### Sidearm phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Classic** | Sidearm | 50 | 16 / 26 | 6.8/s | 12 | 7 (0.89s) · 8 (1.04s) · 10 (1.33s) | 4 (0.44s) · 5 (0.59s) · 6 (0.74s) |
| **Ghost** | Sidearm | 25 | 19 / 30 | 6.8/s | 13 | 6 (0.74s) · 7 (0.89s) · 8 (1.04s) | 4 (0.44s) · 5 (0.59s) · 5 (0.59s) |
| **Sheriff** | Sidearm | 0 | 38 / 60 | 4.0/s | 6 | 3 (0.50s) · 4 (0.75s) · 4 (0.75s) | 2 (0.25s) · 3 (0.50s) · 3 (0.50s) |
| **Shorty** | Sidearm | 25 | 5 / 6 × 15 pellets | 3.0/s | 2 | 2 (0.33s) · 2 (0.33s) · 2 (0.33s) | 2 (0.33s) · 2 (0.33s) · 2 (0.33s) |

### Light phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Bulldog** | Rifle | 25 | 17 / 27 | 9.1/s | 24 | 6 (0.55s) · 8 (0.77s) · 9 (0.88s) | 4 (0.33s) · 5 (0.44s) · 6 (0.55s) |
| **Spectre** | SMG | 25 | 12 / 19 | 13.3/s | 30 | 9 (0.60s) · 11 (0.75s) · 13 (0.90s) | 6 (0.38s) · 7 (0.45s) · 8 (0.53s) |
| **Stinger** | SMG | 25 | 13 / 21 | 13.3/s | 20 | 8 (0.53s) · 10 (0.67s) · 12 (0.82s) | 5 (0.30s) · 6 (0.38s) · 8 (0.53s) |
| **Bucky** | Shotgun | 25 | 6 / 8 × 15 pellets | 1.1/s | 5 | 2 (0.91s) · 2 (0.91s) · 2 (0.91s) | 1 (0.00s) · 2 (0.91s) · 2 (0.91s) |
| **Judge** | Shotgun | 25 | 4 / 7 × 12 pellets | 3.5/s | 7 | 3 (0.57s) · 3 (0.57s) · 4 (0.86s) | 2 (0.29s) · 2 (0.29s) · 2 (0.29s) |
| **Marshal** | Sniper | 0 | 52 / 110 | 1.5/s | 5 | 2 (0.67s) · 3 (1.33s) · 3 (1.33s) | 1 (0.00s) · 2 (0.67s) · 2 (0.67s) |

### Heavy phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Ares** | MachineGun | 50 | 13 / 20 | 13.0/s | 50 | 8 (0.54s) · 10 (0.69s) · 12 (0.85s) | 5 (0.31s) · 7 (0.46s) · 8 (0.54s) |
| **Guardian** | Rifle | 50 | 36 / 58 | 5.3/s | 12 | 3 (0.38s) · 4 (0.57s) · 5 (0.76s) | 2 (0.19s) · 3 (0.38s) · 3 (0.38s) |
| **Phantom** | Rifle | 50 | 16 / 26 | 11.0/s | 30 | 7 (0.55s) · 8 (0.64s) · 10 (0.82s) | 4 (0.27s) · 5 (0.36s) · 6 (0.45s) |
| **Vandal** | Rifle | 50 | 18 / 30 | 9.7/s | 25 | 6 (0.52s) · 7 (0.62s) · 9 (0.82s) | 4 (0.31s) · 5 (0.41s) · 5 (0.41s) |
| **Outlaw** | Sniper | 50 | 68 / 130 | 2.4/s | 2 | 2 (0.42s) · 2 (0.42s) · 3 (4.22s) | 1 (0.00s) · 1 (0.00s) · 2 (0.42s) |

### Elite phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Odin** | MachineGun | 50 | 13 / 20 | 9.5–13.3/s | 75 | 8 (0.67s) · 10 (0.85s) · 12 (1.01s) | 5 (0.40s) · 7 (0.58s) · 8 (0.67s) |
| **Operator** | Sniper | 50 | 95 / 155 | 0.7/s | 5 | 2 (1.45s) · 2 (1.45s) · 2 (1.45s) | 1 (0.00s) · 1 (0.00s) · 1 (0.00s) |
<!-- table:end -->

**Knife, unchanged:** front 50, heavy 75, backstab 100 (so it is relatively stronger than before: two heavy stabs still kill 150).

**Removed 2026-11-12: the Akimbo** (owner: "we're getting rid of that"). Its block is out of `Config/Weapons`, so no draft or picker offers it; its clips and punch entry are gone too. Its model, art source and sound slices are left in place.

## How to tune this
Think in **breakpoints**, not damage: what matters is the number of shots. Against 150, 24 damage takes 7 shots and 25 takes 6, while 25 and 29 both take 6. So one small change can remove a whole shot and a bigger one can do nothing. Change a gun in `Config/Weapons`, rerun the script, and it warns about anything that leaves the targets.
