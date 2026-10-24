# Weapons: Roster, Tiers and Mechanics

All numbers are **starting values for playtesting**, not final balance. Every player has **100 HP** per round. "TTK" means time-to-kill on body shots at close range, with every shot hitting.

This replaces the 5-gun table in `GAME_PLAN.md` section 4. The round format changes from "one shared class per round" to **shared weapon tiers per round** (below).

---

## 1. How weapons work in a match

### Loadout slots
| Slot | What goes in it | When |
|---|---|---|
| **Primary** | Any gun from the round's tier pool | Picked on the draft screen before each round |
| **Secondary** | A sidearm | Picked in round 1, kept all match; can be swapped during any draft |
| **Melee** | Cutter (energy blade) | Always carried |

### Weapon tiers
Like Valorant's price levels, but with no money: **the round decides which tier is open, and both sides get the same pool.** A round opens its own tier **and every tier below it**, so your favourite shotgun is still available in a Heavy round.

| Tier | Name | What's in it | Feel |
|---|---|---|---|
| **T1** | **Sidearm round** | Sidearms only (no primary) | Aim duels, headshots matter |
| **T2** | **Light round** | SMGs, shotguns, burst/semi rifles, light sniper | Close fights, first real loadouts |
| **T3** | **Heavy round** | Full rifles, heavy snipers, machine guns | The "real" fights |
| **T4** | **Wildcard round** | One random exotic weapon, the **same for everyone** | Chaos, highlight clips |

### Example round mix (to be tuned, not final)
| Round | 1 | 2 | 3 | 4 | 5–8 | 9 (deciding) |
|---|---|---|---|---|---|---|
| Tier | T1 | T2 | T2 | T3 | T3 | T4 |

Gauntlet uses the same tiers by stage: stage 1 = T1, stages 2–3 = T2, stages 4–5 = T3, final duel = T4.

**Optional comeback lever (playtest it, it may be too strong):** the round loser may take one gun from the *next* tier up.

### Picking guns on the draft screen
The draft screen has two parts: the **Mod cards** (ability draft) and a **weapon strip** showing the open pool. Default selection = the gun you used last round, so a player who only drafts a Mod still has a sensible gun. Both choices share the same 12 s timer.

---

## 2. The full roster (22 guns + melee)

Names follow the "broken simulation / computer" theme. All are original; none are Valorant or RIVALS names.

### Sidearms (T1, also the Secondary slot)
| Gun | Role | Fire | Dmg body / head | Fire interval | Mag | TTK | Special |
|---|---|---|---|---|---|---|---|
| **Byte** | Default pistol (free) | Semi | 25 / 50 | 0.16 s | 12 | 0.48 s | Accurate first shot |
| **Splinter** | Pocket shotgun | 2-shot | 9 pellets × 9 | 0.30 s | 2 | 1–2 shots up close | Useless past ~15 studs |
| **Flicker** | Machine pistol | Auto | 18 / 36 | 0.09 s | 15 | 0.45 s | Big spread while moving |
| **Mute** | Suppressed precision pistol | Semi | 28 / 62 | 0.18 s | 14 | 0.54 s | No tracer, quiet shots |
| **Root** | Heavy revolver | Semi | 50 / 105 | 0.45 s | 6 | 0.45 s | One-tap headshot within 25 studs |

### SMGs (T2)
| Gun | Role | Fire | Dmg body / head | Fire interval | Mag | TTK | Special |
|---|---|---|---|---|---|---|---|
| **Burst Buffer** | Burst SMG | 3-round burst | 20 / 40 | 0.06 s in burst, 0.30 s between | 24 | ~0.42 s | Very accurate bursts |
| **Bandwidth** | Run-and-gun SMG | Auto | 20 / 45 | 0.075 s | 30 | 0.30 s | Damage drops to 16 after 25 studs; fast movement |

### Shotguns (T2)
| Gun | Role | Fire | Dmg | Fire interval | Mag | Special |
|---|---|---|---|---|---|---|
| **Hard Reset** | Pump shotgun | Pump | 10 pellets × 11 | 0.85 s | 5 | One-shot up close; falls off after 10 studs |
| **Crash** | Auto drum shotgun (Judge-type) | Auto | 8 pellets × 8 | 0.28 s | 8 | Two quick shots up close; falls off after 8 studs |

### Rifles (T2 and T3)
| Gun | Tier | Role | Fire | Dmg body / head | Fire interval | Mag | TTK | Special |
|---|---|---|---|---|---|---|---|---|
| **Pulse** | T2 | Burst rifle | 3-round burst | 22 / 50 | 0.08 s in burst, 0.32 s between | 24 | ~0.40 s | Zoomed ADS fires single shots |
| **Checksum** | T2 | Marksman rifle (DMR) | Semi | 45 / 110 | 0.22 s | 10 | 0.44 s | 1.5× zoom; one-tap headshot |
| **Bitrate** | T3 | Precise auto rifle | Auto | 22 / 48 | 0.095 s | 30 | 0.38 s | Suppressed, easy recoil, small falloff |
| **Overwrite** | T3 | Heavy auto rifle | Auto | 27 / 100 | 0.115 s | 25 | 0.35 s | **One-tap headshot at any range**, hard recoil |

### Snipers (T2 and T3)
| Gun | Tier | Role | Fire | Dmg body / head | Fire interval | Mag | Special |
|---|---|---|---|---|---|---|---|
| **Long Poll** | T2 | Light bolt sniper | Bolt | 75 / 150 | 1.1 s | 5 | 2.5× zoom; fast scope-in |
| **Handshake** | T3 | Double-shot sniper | 2 shots, then reload | 90 / 180 | 0.20 s between the 2 shots | 2 | Two body hits in a row kill |
| **Kernel** | T3 | Heavy one-shot sniper | Bolt | 150 / 255 (legs 110) | 1.5 s | 5 | One-shot to the body; 3.5× zoom; slow while scoped |

### Machine guns (T3)
| Gun | Role | Fire | Dmg body / head | Fire interval | Mag | TTK | Special |
|---|---|---|---|---|---|---|---|
| **Overflow** | Light machine gun | Auto | 24 / 55 | 0.09 s | 50 | 0.36 s | Steadier while crouched; 0.85× move speed |
| **Flood** | Heavy machine gun (Odin-type) | Auto, spins up | 28 / 70 | 0.12 s → 0.06 s over 1.2 s | 100 | ~0.36 s | **Shoots through thin walls**; 0.75× move speed |

### Wildcards (T4)
| Gun | What it does |
|---|---|
| **Ray Trace** | Railgun. Hold to charge (0.5 s), then 100 / 200 damage that **goes through walls and players**. 4 shots. The beam shows where you fired from. |
| **Loopback** | Disc launcher. Discs bounce off walls twice, 40 damage per hit. 8 discs. |
| **Dual Boot** | Twin pistols firing alternately, 20 / 40 each, very fast, no ADS. Accurate while moving. |
| **Null** | Beam gun. Damage ramps from 60 to 180 per second while it stays on the same target. 5 s battery that recharges. |

### Melee (always carried)
| Weapon | Dmg front / back | Swing | Special |
|---|---|---|---|
| **Cutter** | 40 / 100 | 0.6 s | Lunges 6 studs on hit |

---

## 3. Build waves (don't make all 22 at once)

| Wave | When | Guns | Why these |
|---|---|---|---|
| **Wave 1** | Public beta | Byte, Root · Bandwidth, Hard Reset, Long Poll · Bitrate, Flood · Ray Trace · Cutter | At least one gun per tier and every core mechanic: semi, auto, pellets, bolt, spin-up, wall penetration, charge |
| **Wave 2** | Before Season 1 | Splinter, Flicker, Mute · Burst Buffer, Crash, Pulse, Checksum · Overwrite, Handshake, Kernel, Overflow | Fills every tier with real choices |
| **Wave 3** | Season updates (one new gun every 1–2 weeks) | Loopback, Dual Boot, Null, then new ones | New guns are the easiest regular update hook |

---

## 4. Gun mechanics to build (one framework, all data)

Every gun is a table in `src/shared/Config/Weapons.luau`. The framework supports these features, and each gun just switches them on:

| Mechanic | Used by | Notes |
|---|---|---|
| **Fire modes:** semi, auto, burst, pump/bolt cycle | All | Fire on press; the server enforces the interval |
| **Hitscan** with server validation + rewound hitboxes | Most guns | See the gun-system section of the research report |
| **Pellets** (several rays per shot, seeded spread) | Splinter, Hard Reset, Crash | Seeded so the server can recompute the spread |
| **Damage falloff** (distance curve) | All | Per-gun start and end distance and minimum damage |
| **Hit zones:** head, body, legs multipliers | All | Body = 1.0, legs = 0.85 by default |
| **Spread and bloom:** first-shot accuracy, spread grows while firing, moving or jumping | All | Mobile aim assist goes on top of this |
| **Recoil pattern:** vertical climb, then sideways drift | Autos | Spring-driven camera kick |
| **ADS** (aim down sights) with zoom level and slower movement | All; snipers scope in | Snipers get a scope overlay |
| **Charge** (hold to power up) | Ray Trace | Release to fire |
| **Spin-up** (fire rate ramps up) | Flood | Spin-down after you stop |
| **Wall penetration** | Flood, Ray Trace | Only through parts tagged `ThinWall` |
| **Projectiles** (travel time, bounce) | Loopback, Mod grenades | Server-simulated |
| **Beam** (continuous damage tick) | Null | Server ticks damage |
| **Reload:** tactical vs empty (empty is slower), cancel by switching | All | |
| **Equip / swap time** | All | Sidearms are fastest |
| **Movement speed multiplier** | Heavy guns slower | |
| **Suppressed** (no tracer, quieter) | Mute, Bitrate | |

**Build order for the mechanics:**
1. Byte (semi hitscan, falloff, hit zones, recoil, ADS)
2. Bitrate (auto fire, spread and bloom)
3. Hard Reset (pellets, pump)
4. Long Poll (bolt, scope)
5. Root (heavy semi; just new data)
6. Bandwidth (data)
7. Flood (spin-up, wall penetration)
8. Ray Trace (charge, piercing)

---

## 5. Looks: silhouette rules

Players must be able to tell a gun's class **from its outline alone**, especially on a phone.

| Class | Silhouette rule |
|---|---|
| Sidearms | Small, one hand, ~1.5 studs long |
| SMGs | Short and boxy, stubby barrel, vertical front grip |
| Shotguns | Thick barrel, visible pump or big drum |
| Rifles | Long, balanced, clear stock and mag, ~3.5–4 studs |
| Snipers | Longest, big scope on top, thin long barrel |
| Machine guns | Bulky, box or belt mag, carry handle, ~4.5 studs |
| Wildcards | Weird shapes, extra glow, no real-world silhouette |

**Art style:** being decided. See the style test renders in `docs/art/style-test/`.
