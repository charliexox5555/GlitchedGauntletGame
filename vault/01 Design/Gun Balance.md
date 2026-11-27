# Gun Balance

**Current pass: the loadout sidegrade pass (2026-11-27).** Weapon tiers are gone ([Loadout and Power Deck](Loadout%20and%20Power%20Deck.md)): every player picks a primary and a secondary in the Locker, round 1 is secondaries only and every later round gives both. So no gun may be a straight upgrade: each of the 14 active guns (10 primaries, 4 secondaries) wins a different fight and pays for it somewhere else. Owner decisions (2026-11-27): Hornet and Scout come back, buffed; TwinShot (Outlaw) is removed; Buckshot (Judge) and Barrage (Ares) stay parked (their data stays in `Config/Weapons`). Gun levels with stat upgrades come later and must keep these breakpoints (Launch plan step 6).

## Health and shield
- **Health:** always 100. No regen; heals come from abilities and only restore health.
- **Shield:** sits on top of health and takes damage first. It lasts the round and doesn't come back.
- **Round 1 (sidearms only):** your secondary decides your shield (`shield` in `Config/Weapons`): Classic 50 (150 total), Hush and Shorty 25 (125), Sheriff 0 (100).
- **Rounds 2+ (full loadout):** everyone gets a flat 50 (`Config/Match` PHASES), so every primary fights at **150**. The `shield` field on primaries is unused now.
- **Damage order:** every source goes through one function (`WeaponService.hurt`), so guns, abilities and the test opponent can't skip the shield.
- **If the clock runs out:** health plus shield decides the round.

## Targets
| Thing | Target | Why |
|---|---|---|
| Body kill against 150, close | **0.7–0.95 s** for automatics and bursts (the script warns outside 0.65–1.2) | Longer fights, nearer RIVALS than Valorant (owner 2026-11-12). The fastest close gun (Hornet, 0.70 s) pays with kick and falloff; the slowest (Mauler, 0.93 s) gets the 75-round box |
| Sidearms | Up to about 1.3 s against 150 | Round 1 warm-up, then a backup |
| Head multiplier | **About 1.6×** (snipers up to 2.2×) | Valorant is 3.5–4×, RIVALS' Assault Rifle is 1.25×, LihFolk suggests 1.5–2× |
| Headshots to kill at 150 | **3–9** on anything not a sniper | So aim is rewarded without ending the fight instantly |
| One-shot headshots | **Deadeye only** (155 at 150). Scout: a head plus any body hit (120 + 55) | The Deadeye keeps the one-tap; the Scout is the quick one |
| Single body shot at full health | Everyone survives one body hit: 150 for primaries (the Pump's full 105 too), 100 for sidearms | A body hit leaves a chance to break sight or fight back |
| Shotguns | Strong up close with steep falloff (all pellets assumed in the table) | Position and pellet placement drive their advantage |

| Reference | Body / head | Head × |
|---|---|---|
| [RIVALS Assault Rifle](https://robloxrivals.fandom.com/wiki/Assault_Rifle) | 12 / 15 | 1.25 |
| [RIVALS Burst Rifle](https://robloxrivals.fandom.com/wiki/Burst_Rifle) | 20 / 25 | 1.25 |
| [RIVALS Shotgun](https://robloxrivals.fandom.com/wiki/Shotgun) | 8 / 12 × 10 pellets | 1.5 |
| [RIVALS Sniper](https://robloxrivals.fandom.com/wiki/Sniper) | 50 / 150 | 3 |
| [Valorant Vandal](../03%20Research/Valorant%20Gun%20Mechanics.md) | 40 / 160 | 4 |

## Identities (the 14 active guns)
What each gun is for, and what it pays. The Locker's role line (`Config/Loadout` ROLES) says the same in a few words.

| Gun (id) | Wins | Pays with |
|---|---|---|
| **Havoc** (Vandal) | The all-rounder: 0.82 s body and the best automatic head (5) at every range, no falloff | Harder kick than the Spirit, a loud tracer |
| **Spirit** (Phantom) | Easiest automatic: 11/s, light kick, silenced (no tracer for enemies), 30 rounds | A falloff step at 70 studs (0.91 s), 6 heads |
| **Lancer** (Bulldog) | **Three-round bursts** (2026-11-27, was full auto): 22 a round, tight groups, no falloff; 0.82 s body, 0.48 s head | One click per burst; a missed burst costs 0.41 s |
| **Marksman** (Guardian) | Semi-auto DMR: perfect aimed first shot, 3 heads (0.38 s) or 5 bodies (0.76 s) at any range | Every shot must land; 12 rounds, slower to move with (0.90) |
| **Prowler** (Spectre) | Steady, silenced SMG: 0.82 s body out to 70 studs (13 a round, was 12), full move speed | Mid-range falloff (0.97 s beyond 70 studs) |
| **Hornet** (Stinger) | **The fastest trigger** (17.2/s, was 13.3): 0.70 s body up close, 30 rounds (was 20) | **A ton of kick** (owner): 0.5° a shot after two, about 3× the Havoc's climb per second, with side jumps; steep falloff from 40 studs (0.93 s at 60, 1.16 s at 90) |
| **Pump** (Bucky) | Two pumps up close (7 × 15 pellets, was 6): 11 of 15 pellets still kill in two | Falloff from 29 studs, a 0.91 s pump |
| **Mauler** (Odin) | Suppression: 75-round box, light wall penetration, 14 a round (was 13): 0.93 s from a fresh trigger | Spin-up, the slowest movement (0.85), 5 s reload |
| **Scout** (Marshal) | **The quick sniper** (owner: "quicker, accuracy on non ads, faster movement speed"): the **fastest gun to move with (1.05)**, accurate from the hip (0.3°, was 1°) with a light move penalty (`Config/Combat` MOVE_PENALTY LightSniper), 0.58 s lever (was 0.67), 0.18 s scope, quicker draw and reload; head + body kills (0.58 s), 3 bodies 1.16 s | No one-shot, 55 body |
| **Deadeye** (Operator) | One headshot kills; 2 bodies; heavy wall penetration | 1.45 s bolt, 0.85 move (0.4 scoped), inaccurate from the hip |
| **Classic** | Round 1's tank: 50 shield (150 total); right click fires a 3-pellet burst | The weakest shots (16) |
| **Sheriff** | The hardest-hitting sidearm: 3 bodies at 100, 4 at 150, ADS like the rifles | No shield in round 1 (100 total), heavy kick, 6 rounds |
| **Shorty** | Two shells that kill anything close (0.33 s) | Useless past 25 studs, 2 rounds |
| **Hush** (Ghost) | Silenced and accurate: the best head breakpoints of the pistols | 25 shield, 19 a round |

Round-1 matchups (table below): Classic vs Sheriff 0.89 vs 0.75 s, Classic vs Hush even, Sheriff vs Hush even; the Shorty wins every close fight and loses every one past 25 studs.

**Studio check (2026-11-27, bot matches, Studio profile):** the Locker unlocked Hornet (600) and Scout (1,000) and equipped each (coins down 1,600); in a non-onboarding bot match round 1 handed out the Classic and round 2 the equipped primary. The Hornet emptied 19 of its 30 rounds in a ~0.9 s hold and the Scout fired 3 lever shots (5 → 2) with a 1.05 move multiplier; console clean. The Locker lists the TEMPEST-STRIKE Hornet and Scout skins. **Not felt in hand yet:** whether the Hornet's kick is "a ton" or too much, the Lancer's bursts (not fired in Studio; on touch it's one tap per burst), and the Scout's hip-fire on the move. Tune in `Config/Weapons` and rerun the script.

## Wall penetration (2026-11-12)
The owner: "wall penetration isn't really good, not on the maps", "the Odin can penetrate through the walls an infinite". It used to need a `ThinWall` tag on the part (no built map has one) or be `"All"`, which ignored every wall. Now it is measured on the wall itself (`Util/Penetration`, numbers in `Config/Combat` `PENETRATION`): each round has a budget of wall it can pass, along its own line, and loses damage per wall.

| Class | Guns | Wall it gets through | Damage left |
|---|---|---|---|
| None | Classic, Hush, Shorty, Hornet, Prowler, Pump, Knife (parked: Buckshot) | Nothing | |
| Light | Havoc, Spirit, Lancer, Marksman, Mauler, Sheriff, Scout (parked: Barrage) | 1.6 studs, one wall | 60% |
| Heavy | Deadeye | 4.5 studs in total, up to two walls | 70%, then 49% |

- A wall hit at a shallow angle counts as thicker, because the round travels further through it. Terrain stops everything. Parts tagged `ThinWall` (the range's plywood) count as 0.5 studs.
- One-wall body damage before rounding: 10.8 for Havoc, 8.4 for Mauler, 66.5 for Deadeye. Penetration still depends on the actual distance through the part.
- The same rule runs in three places: the shooter's client, the server's check of each hit, and the bots' own shots.

## The numbers (measured TTK)
Generated by `python tools/balance/gun_table.py` from `Config/Loadout` (the active set) and `Config/Weapons`. Each cell: shots to kill · ideal time from the first shot, body / head, at that distance (falloff applied). Times include spin-up, burst gaps and empty reloads; perfect accuracy, no movement or recoil; shotguns assume every pellet hits. Change a gun in `Config/Weapons`, rerun, and the script warns about anything outside the targets.

<!-- table:start -->
### Primaries at 150 (rounds 2+)
Each cell: body shots · time / head shots · time.

| Gun | Class | Damage body / head | Rate | Mag | Move | 10 studs | 35 studs | 60 studs | 90 studs | 150 studs |
|---|---|---|---|---|---|---|---|---|---|---|
| **Havoc** (Vandal) | Rifle | 18 / 30 | 9.7/s | 25 | 0.95 | 9 · 0.82s / 5 · 0.41s | 9 · 0.82s / 5 · 0.41s | 9 · 0.82s / 5 · 0.41s | 9 · 0.82s / 5 · 0.41s | 9 · 0.82s / 5 · 0.41s |
| **Prowler** (Spectre) | SMG | 13 / 21 | 13.3/s | 30 | 1.00 | 12 · 0.82s / 8 · 0.53s | 12 · 0.82s / 8 · 0.53s | 12 · 0.82s / 8 · 0.53s | 14 · 0.97s / 9 · 0.60s | 14 · 0.97s / 9 · 0.60s |
| **Hornet** (Stinger) | SMG | 12 / 19 | 17.2/s | 30 | 1.00 | 13 · 0.70s / 8 · 0.41s | 13 · 0.70s / 8 · 0.41s | 17 · 0.93s / 11 · 0.58s | 21 · 1.16s / 14 · 0.75s | 21 · 1.16s / 14 · 0.75s |
| **Pump** (Bucky) | Shotgun | 7 / 10 × 15 | 1.1/s | 5 | 0.95 | 2 · 0.91s / 1 · 0.00s | 3 · 1.82s / 2 · 0.91s | 4 · 2.73s / 3 · 1.82s | 4 · 2.73s / 3 · 1.82s | 4 · 2.73s / 3 · 1.82s |
| **Lancer** (Bulldog) | Rifle | 22 / 35 | 3-burst, 7.3/s | 24 | 0.95 | 7 · 0.82s / 5 · 0.48s | 7 · 0.82s / 5 · 0.48s | 7 · 0.82s / 5 · 0.48s | 7 · 0.82s / 5 · 0.48s | 7 · 0.82s / 5 · 0.48s |
| **Marksman** (Guardian) | Rifle | 36 / 58 | 5.3/s | 12 | 0.90 | 5 · 0.76s / 3 · 0.38s | 5 · 0.76s / 3 · 0.38s | 5 · 0.76s / 3 · 0.38s | 5 · 0.76s / 3 · 0.38s | 5 · 0.76s / 3 · 0.38s |
| **Scout** (Marshal) | Sniper | 55 / 120 | 1.7/s | 5 | 1.05 | 3 · 1.16s / 2 · 0.58s | 3 · 1.16s / 2 · 0.58s | 3 · 1.16s / 2 · 0.58s | 3 · 1.16s / 2 · 0.58s | 3 · 1.16s / 2 · 0.58s |
| **Spirit** (Phantom) | Rifle | 16 / 26 | 11.0/s | 30 | 0.97 | 10 · 0.82s / 6 · 0.45s | 10 · 0.82s / 6 · 0.45s | 10 · 0.82s / 6 · 0.45s | 11 · 0.91s / 7 · 0.55s | 11 · 0.91s / 7 · 0.55s |
| **Mauler** (Odin) | MachineGun | 14 / 22 | 9.5–13.3/s | 75 | 0.85 | 11 · 0.93s / 7 · 0.58s | 11 · 0.93s / 7 · 0.58s | 11 · 0.93s / 7 · 0.58s | 11 · 0.93s / 7 · 0.58s | 14 · 1.17s / 9 · 0.76s |
| **Deadeye** (Operator) | Sniper | 95 / 155 | 0.7/s | 5 | 0.85 | 2 · 1.45s / 1 · 0.00s | 2 · 1.45s / 1 · 0.00s | 2 · 1.45s / 1 · 0.00s | 2 · 1.45s / 1 · 0.00s | 2 · 1.45s / 1 · 0.00s |

### Secondaries
Round 1 is sidearms only, each with its own shield. Same cell format.

| Gun | Own shield | Damage body / head | Rate | Mag | vs 100 at 10 | vs 125 at 10 | vs 150 at 10 | vs 150 at 35 | vs 150 at 90 |
|---|---|---|---|---|---|---|---|---|---|
| **Classic** (Classic) | 50 (150 total) | 16 / 26 | 6.8/s | 12 | 7 · 0.89s / 4 · 0.44s | 8 · 1.04s / 5 · 0.59s | 10 · 1.33s / 6 · 0.74s | 10 · 1.33s / 6 · 0.74s | 10 · 1.33s / 6 · 0.74s |
| **Sheriff** (Sheriff) | 0 (100 total) | 38 / 60 | 4.0/s | 6 | 3 · 0.50s / 2 · 0.25s | 4 · 0.75s / 3 · 0.50s | 4 · 0.75s / 3 · 0.50s | 4 · 0.75s / 3 · 0.50s | 4 · 0.75s / 3 · 0.50s |
| **Shorty** (Shorty) | 25 (125 total) | 5 / 6 × 15 | 3.0/s | 2 | 2 · 0.33s / 2 · 0.33s | 2 · 0.33s / 2 · 0.33s | 2 · 0.33s / 2 · 0.33s | 4 · 2.57s / 4 · 2.57s | 8 · 7.03s / 7 · 6.70s |
| **Hush** (Ghost) | 25 (125 total) | 19 / 30 | 6.8/s | 13 | 6 · 0.74s / 4 · 0.44s | 7 · 0.89s / 5 · 0.59s | 8 · 1.04s / 5 · 0.59s | 8 · 1.04s / 5 · 0.59s | 8 · 1.04s / 5 · 0.59s |

| Round 1 | Body kill, each way (10 studs) | Reading |
|---|---|---|
| Classic vs Sheriff | 0.89s vs 0.75s | Sheriff |
| Classic vs Shorty | 1.04s vs 0.33s | Shorty |
| Classic vs Hush | 1.04s vs 1.04s | even |
| Sheriff vs Shorty | 0.75s vs 0.33s | Shorty |
| Sheriff vs Hush | 0.75s vs 0.74s | even |
| Shorty vs Hush | 0.33s vs 0.89s | Shorty |
<!-- table:end -->

**Knife, unchanged:** front 50, heavy 75, backstab 100 (so it is relatively stronger than before: two heavy stabs still kill 150).

**Removed 2026-11-12: the Akimbo** (owner: "we're getting rid of that"). Its block is out of `Config/Weapons`, so no draft or picker offers it; its clips and punch entry are gone too. Its model, art source and sound slices are left in place.

**Removed 2026-11-27: the TwinShot (Outlaw)** (owner). Its `Config/Weapons` block, clips (`WeaponAnimations/Outlaw`), reload track, sounds, icons, portraits and asset data are gone from the code; in Studio `ReplicatedStorage.Weapons.Outlaw`, its 10 skin models (`ServerStorage.WeaponSkins/*/Outlaw`), `LobbyKit.Trophy_Outlaw` and the two armoury `Wall_Outlaw` anchors were deleted (backup: `art-source/weapons/Studio/Outlaw.rbxm`; the skins are in the place's version history). The pass's Frostbite TwinShot is now a Frostbite **Marksman**. Saves load cleanly: an owned Outlaw skin stays in the save but nothing lists it (every Locker, case and shop view goes by the active set and the skin manifest), a Locker equip for it drops (`Locker.clean` keeps only guns in `Config/Weapons`), and a daily-shop pick for a gun no longer in `Config/Weapons` rolls that day again (`DailyShop.clean`). Whether to refund owned TwinShot skins is for the grandfathering step (Launch plan step 5).

## How to tune this
Think in **breakpoints**, not damage: what matters is the number of shots. Against 150, 24 damage takes 7 shots and 25 takes 6, while 25 and 29 both take 6. So one small change can remove a whole shot and a bigger one can do nothing. Change a gun in `Config/Weapons`, rerun the script, and it warns about anything that leaves the targets.
