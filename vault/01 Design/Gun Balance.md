# Gun Balance

Health, shields and every gun's damage. The user set the goal on 2026-11-02: **sit between RIVALS and Valorant.** Kills should come easily, but rounds should last a good while, and it shouldn't be one or two headshots and you're dead. Some guns can be better than others, but the levels should sit close together. **Status: second set of numbers (2026-11-12).** The owner played the first set and said guns "do a little too much damage... Rivals has lower gun damages... more fun if players are able to play longer", with one fixed rule: **the Operator kills in one shot wherever it lands**, except through a wall. So every gun but the Operator and the Outlaw lost about a quarter of its damage and kills take about 30% longer. Damage was checked in play on the test range (Vandal 18, Operator kills); the feel of a whole round is not tested yet.

## Health and shield
- **Health:** always 100. No regen; heals come from abilities and only restore health.
- **Shield:** sits on top of health and takes damage first. It lasts the round and doesn't come back.
- **Sidearm and Light phases (rounds 1–3):** the gun you choose decides your shield. The stronger the gun, the less shield. That's the real choice in those rounds: a Sheriff hits hardest but you have 100 total, a Classic hits softest but you have 150.
- **Heavy and Elite phases (round 4 on):** everyone gets 50, so the guns are the only difference.
- **Damage order:** every source goes through one function (`WeaponService.hurt`), so guns, abilities and the test opponent can't skip the shield.
- **If the clock runs out:** health plus shield decides the round.

| Shield | Sidearm phase | Light phase |
|---|---|---|
| **50** (150 total) | Classic | (none since the Akimbo was removed, 2026-11-12) |
| **25** (125 total) | Ghost, Shorty | Stinger, Spectre, Bulldog, Judge, Bucky |
| **0** (100 total) | Sheriff | Marshal |

## Targets
| Thing | Target | Why |
|---|---|---|
| Body kill against 150 | **0.75–0.9 s** for primary guns (was 0.5–0.75 s until 2026-11-12) | The owner wanted longer fights, nearer RIVALS (about a second by our estimate) than Valorant (Vandal 0.31 s). LihFolk: 0.4–0.8 s suits Roblox arena play, so this sits at its top edge |
| Sidearms | Up to about 1.3 s (was 1 s) | They're the warm-up round |
| Head multiplier | **About 1.6×** (sidearms and machine guns 1.5–1.6×) | Valorant is 3.5–4×, RIVALS' Assault Rifle is 1.25×, LihFolk suggests 1.5–2× |
| Headshots to kill at 150 | **3–5** on anything not a sniper | So aim is rewarded without ending the fight instantly |
| One-shot headshots | **Snipers only**, and the Marshal only against no shield | Sniper fantasy: RIVALS' Sniper one-shots a head too |
| One-shot body | **The Operator only** (150 everywhere, legs too; owner 2026-11-12: "should be one shot, no matter what really") | The Elite sniper is the one gun that ends a fight in a shot. Through a wall it does 105 (one wall) or 74 (two), so a wall-bang only kills a player with no shield |
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
Fights the numbers intend, with both players hitting every body shot (2026-11-12 numbers):

| Fight | Time to kill | Reading |
|---|---|---|
| Classic (150) vs Sheriff (100) | 0.89 s vs 0.75 s | The Sheriff is a little faster, if you can control its kick |
| Classic (150) vs Ghost (125) | 1.04 s vs 1.18 s | The Classic's shield just wins a straight trade; the Ghost is more accurate |
| Stinger (125) vs Spectre (125) | 0.60 s vs 0.75 s | Stinger up close, Spectre further out with a steadier gun and a bigger mag |
| Stinger (125) vs Bulldog (125) | 0.60 s vs 0.77 s | Stinger wins close, the Bulldog has no falloff and shoots through thin cover |
| Vandal vs Phantom (both 150) | 0.82 s vs 0.82 s | Even on body. Head favours the Vandal, ease of use the Phantom |
| Vandal vs Guardian (both 150) | 0.82 s vs 0.76 s | The Guardian must land 5 separate shots; misses cost far more |
| Odin vs Operator (both 150) | 0.75 s vs one shot | The Operator wins any fight it sees first; the Odin wins the ones that last |

## Wall penetration (2026-11-12)
The owner: "wall penetration isn't really good, not on the maps", "the Odin can penetrate through the walls an infinite". It used to need a `ThinWall` tag on the part (no built map has one) or be `"All"`, which ignored every wall. Now it is measured on the wall itself (`Util/Penetration`, numbers in `Config/Combat` `PENETRATION`): each round has a budget of wall it can pass, along its own line, and loses damage per wall.

| Class | Guns | Wall it gets through | Damage left |
|---|---|---|---|
| None | Classic, Ghost, Shorty, Stinger, Spectre, Judge, Bucky, Knife | Nothing | |
| Light | Vandal, Phantom, Bulldog, Guardian, Ares, Sheriff, Marshal, Outlaw | 1.6 studs, one wall | 60% |
| Heavy | Operator, Odin | 4.5 studs in total, up to two walls | 70%, then 49% |

- A wall hit at a shallow angle counts as thicker, because the round travels further through it. Terrain stops everything. Parts tagged `ThinWall` (the range's plywood) count as 0.5 studs.
- **Measured on the range:** Vandal 18 in the open, **11** through a 1-stud wall, stopped by 3 studs. Operator kills in the open and through 3 studs, stopped by 6.
- **Measured on the maps** (wall-sized collidable parts by their thinnest side): Bunker 41 of 132 are 1.6 studs or thinner and 72 more are 3 or thinner; Greenhouse 95 and 142 of 276; Metro 48 and 42 of 122; Old Town 18 and 90 of 236; Rooftops and Dockyard about 13–20 thin, most of the rest thicker than 4.5. So rifles go through thin cover, the Operator and Odin through most ordinary walls, and nothing through the thick blocks.
- The same rule runs in three places: the shooter's client, the server's check of each hit, and the bots' own shots.

## The numbers
Generated from `Config/Weapons` by `tools/balance/gun_table.py`: rerun it after changing a gun. Each cell is shots to kill (time). Shotguns assume every pellet hits. Falloff, moving spread and recoil aren't counted.

<!-- table:start -->
### Sidearm phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Classic** | Sidearm | 50 | 16 / 26 | 6.8/s | 12 | 7 (0.89s) · 8 (1.04s) · 10 (1.33s) | 4 (0.44s) · 5 (0.59s) · 6 (0.74s) |
| **Ghost** | Sidearm | 25 | 18 / 29 | 6.8/s | 13 | 6 (0.74s) · 7 (0.89s) · 9 (1.18s) | 4 (0.44s) · 5 (0.59s) · 6 (0.74s) |
| **Sheriff** | Sidearm | 0 | 38 / 60 | 4.0/s | 6 | 3 (0.50s) · 4 (0.75s) · 4 (0.75s) | 2 (0.25s) · 3 (0.50s) · 3 (0.50s) |
| **Shorty** | Sidearm | 25 | 5 / 8 × 15 pellets | 3.0/s | 2 | 2 (0.33s) · 2 (0.33s) · 2 (0.33s) | 1 (0.00s) · 2 (0.33s) · 2 (0.33s) |

### Light phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Bulldog** | Rifle | 25 | 17 / 27 | 9.1/s | 24 | 6 (0.55s) · 8 (0.77s) · 9 (0.88s) | 4 (0.33s) · 5 (0.44s) · 6 (0.55s) |
| **Spectre** | SMG | 25 | 12 / 19 | 13.3/s | 30 | 9 (0.60s) · 11 (0.75s) · 13 (0.90s) | 6 (0.38s) · 7 (0.45s) · 8 (0.53s) |
| **Stinger** | SMG | 25 | 14 / 22 | 13.3/s | 20 | 8 (0.53s) · 9 (0.60s) · 11 (0.75s) | 5 (0.30s) · 6 (0.38s) · 7 (0.45s) |
| **Bucky** | Shotgun | 25 | 6 / 9 × 15 pellets | 1.1/s | 5 | 2 (0.91s) · 2 (0.91s) · 2 (0.91s) | 1 (0.00s) · 1 (0.00s) · 2 (0.91s) |
| **Judge** | Shotgun | 25 | 5 / 8 × 12 pellets | 3.5/s | 7 | 2 (0.29s) · 3 (0.57s) · 3 (0.57s) | 2 (0.29s) · 2 (0.29s) · 2 (0.29s) |
| **Marshal** | Sniper | 0 | 55 / 105 | 1.5/s | 5 | 2 (0.67s) · 3 (1.33s) · 3 (1.33s) | 1 (0.00s) · 2 (0.67s) · 2 (0.67s) |

### Heavy phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Ares** | MachineGun | 50 | 14 / 21 | 13.0/s | 50 | 8 (0.54s) · 9 (0.62s) · 11 (0.77s) | 5 (0.31s) · 6 (0.39s) · 8 (0.54s) |
| **Guardian** | Rifle | 50 | 36 / 58 | 5.3/s | 12 | 3 (0.38s) · 4 (0.57s) · 5 (0.76s) | 2 (0.19s) · 3 (0.38s) · 3 (0.38s) |
| **Phantom** | Rifle | 50 | 16 / 26 | 11.0/s | 30 | 7 (0.55s) · 8 (0.64s) · 10 (0.82s) | 4 (0.27s) · 5 (0.36s) · 6 (0.45s) |
| **Vandal** | Rifle | 50 | 18 / 29 | 9.7/s | 25 | 6 (0.52s) · 7 (0.62s) · 9 (0.82s) | 4 (0.31s) · 5 (0.41s) · 6 (0.52s) |
| **Outlaw** | Sniper | 50 | 75 / 150 | 2.7/s | 2 | 2 (0.36s) · 2 (0.36s) · 2 (0.36s) | 1 (0.00s) · 1 (0.00s) · 1 (0.00s) |

### Elite phase
| Gun | Class | Shield | Damage body / head | Rate | Mag | Body shots at 100 / 125 / 150 | Head shots at 100 / 125 / 150 |
|---|---|---|---|---|---|---|---|
| **Odin** | MachineGun | 50 | 15 / 23 | 12.0/s | 100 | 7 (0.50s) · 9 (0.66s) · 10 (0.75s) | 5 (0.33s) · 6 (0.42s) · 7 (0.50s) |
| **Operator** | Sniper | 50 | 150 / 300 | 0.6/s | 5 | 1 (0.00s) · 1 (0.00s) · 1 (0.00s) | 1 (0.00s) · 1 (0.00s) · 1 (0.00s) |
<!-- table:end -->

**Knife, unchanged:** front 50, heavy 75, backstab 100 (so it is relatively stronger than before: two heavy stabs still kill 150).

**Removed 2026-11-12: the Akimbo** (owner: "we're getting rid of that"). Its block is out of `Config/Weapons`, so no draft or picker offers it; its clips and punch entry are gone too. Its model, art source and sound slices are left in place.

## How to tune this
Think in **breakpoints**, not damage: what matters is the number of shots. Against 150, 24 damage takes 7 shots and 25 takes 6, while 25 and 29 both take 6. So one small change can remove a whole shot and a bigger one can do nothing. Change a gun in `Config/Weapons`, rerun the script, and it warns about anything that leaves the targets.
