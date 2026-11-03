# Stim (was Overclock)

**Status:** spec locked 2026-10-29 · **built 2026-10-29** (overnight, waiting for the user's test)
**Inspiration:** Brimstone's Stim Beacon (Valorant). You drop a beacon; **teammates (and you) who step into its zone get a combat stim** that boosts fire rate, movement speed, weapon swapping and reloading. **Team only:** it never affects enemies.
**Remove from the old Overclock:** the instant self-only fire-rate buff.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Activation | **Instant on press:** you **toss the beacon underhand** and it lands **5 studs ahead** (short of a wall; Brimstone-style, changed 2026-10-29). It leaves the hand 0.3 s after the press, flies 0.4 s, and the zone switches on 0.25 s after it lands |
| Zone | **10-stud radius**, lasts **8 s** |
| Who | **You and your teammates only.** Enemies are never affected |
| Buff | **Stimmed** while inside the zone **and for 4 s after leaving** (re-entering refreshes it) |
| Destroyable | **No:** it lasts the full 8 s |
| Charges | **1 per round, no recharge** (unlimited in test mode) |

## Stimmed (a shared status effect, like Hinder)
| Stat | While stimmed |
|---|---|
| Fire rate | **+15%** |
| Move speed | **+15%** |
| Weapon swap / equip | **30% faster** |
| Reload | **15% faster** |

- Server-authoritative, with an expiry time on the character (e.g. `StimmedUntil`), built on the same status-effect system as [Frost](Frost.md)'s Hinder. The server enforces fire rate, swap and reload times.
- **Combining with Hinder:** the effects multiply (a stimmed and hindered player is roughly back to normal speed). All numbers are in config.

## First person
- **Pull beacon from belt + toss:** the gun dips, your free hand brings the beacon up from the belt, dips back and tosses it underhand a few steps ahead; the beacon leaves your hand and arcs (tumbling over) to the floor, hops, then snaps open, and the gun comes right back.
- **Deploy:** the beacon snaps open and **crackles with yellow electricity**, and the zone ring spreads out.

## Screen (for a stimmed player)
- An **electric-yellow screen-edge pulse**: subtle, pulsing gently while stimmed.
- **Placeholder HUD:** a simple "Stimmed" label + countdown (the HUD gets reworked later).

## Look (Blender + VFX)
- **Beacon:** a rugged tactical unit that pops open with a small light mast, **crackling electric yellow**, made in Blender in the current tactical style.
- **Zone:** an electric-yellow ring/dome on the ground with small arcs and sparks along the edge.
- **Stimmed players:** yellow electric crackle over their body, so **enemies can see who's stimmed** (and the zone too).

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Stim_Grab` | Beacon off the belt |
| `Stim_Drop` | Slam on the ground |
| `Stim_Deploy` | Snap open + electric crackle (3D) |
| `Stim_ZoneLoop` | Electric hum while active (3D, ~40 studs) |
| `Stim_Gained` | You became stimmed |
| `Stim_Ending` | Your stim is about to run out / ends |

### Placeholder sounds (ProSoundEffects, unauditioned)
Real recordings, all in `Config/ModSounds.luau` → `Stim`; swap the ids there. The library has no velcro, so the grab is a nylon rip.

| Hook | Id | Recording | Use |
|---|---|---|---|
| `Stim_Grab` | 9113835765 | Cloth Rip Violent 14 | from 0.03 s, cut 0.4 s, pitch 1.1 |
| `Stim_Drop` | 9116539107 | Metal Case Impact 1 | cut 0.3 s (the slam), 3D 40 studs |
| `Stim_Deploy` | 9113808115 + 9119992532 | Circuit Breaker 1 (snap) + Tesla Coil 3 (crackle) | breaker from 0.14 s cut 0.3; coil cut 1.1 s; 3D 50 studs |
| `Stim_ZoneLoop` | 9119993024 | Tesla Coil 2 (stuttered buzzing) | loop 1–19.5 s, 3D 40 studs |
| (zone end) | 9119595114 | Static Zap Mix Reverberant Bursts 3 | from 0.4 s, cut 0.8 s, 3D |
| `Stim_Gained` | 9119594571 | Static Zap Blast 2 (build into a zap) | from 0.7 s, cut 0.65 s |
| `Stim_Ending` | 9119595114 | Static Zap Mix Reverberant Bursts 3 | from 0.4 s, pitch 0.9 |

Alternates the search found: Grab: Cloth Rip Zippy 3 (9113836527), Cloth Rip Rapid 7 (9113828720). Drop: Metal Case Impact 3 (9116539240), Metal Case Drop 2 (9116538885). Deploy: Briefcase Opening And Closing 4 (9113590871) + Static Zap Body Two Buzzy Impacts 1 (9119594718); Power Up Sweeteners 12 (9117886252). Zone loop: Electrical Zap Room Constant Sparking Arcing 3 (9125516674), Electric Hum 1 (9114245063). Gained: Static Zap Mix Reverberant Bursts 2 (9119595110). Ending: Power Down 1 (9117871125), Switches Video Monitors On Off Electric Hum 1 (9126027558).

## Build notes (2026-10-29)
- **Code:** `Mods/Stim.luau` (replaces Overclock), `Config/Mods.luau` → `Stim` (`radius` 10, `height` 8, `duration` 8, `linger` 4, `deployTime` 0.25, `tick` 0.1, 1 charge). Instant: the server drops it on the floor under you (refused with no floor within 12 studs below, nothing spent; the client checks first). Every 0.1 s the zone puts **Stimmed** on you and teammates inside (players and ally dummies) for 4 s, so it lasts 4 s after leaving. Enemies never get it. Nothing to shoot: the zone is server timers and the beacon is drawn by clients.
- **Stimmed** is a shared status effect in `Config/StatusEffects` (`StimmedUntil`): fire rate ×1.15, move ×1.15, equip speed ×1/0.7 (swaps take 70% of the time), reload speed ×1/0.85 (reloads take 85%). It multiplies with Hinder through `Mods/Status`, enforced by the same weapon and movement code.
- **Model:** Blender beacon (`tools/blender/build_mod_stim.py`): octagonal body, four opened feet with hazard stripes, light mast with a yellow coil, 2,385 tris. Upload 138862550658396; `ReplicatedStorage.Abilities.Stim`, backup `art-source/abilities/Studio/Stim.rbxm`. Drawn at 1.5× (`StimFx` `BEACON_SCALE`). The coil (`Coil_Yellow`) keeps its yellow (`ModProps.tint` skips `*_Yellow`); the status light takes the caster's team colour.
- **Effects:** `Util/StimFx.luau`: the beacon falls and pops open, a ring spreads to the zone edge and holds (flickering), arcs crackle along the edge, bolts jump from the mast, sparks off the coil; stimmed players and dummies crackle yellow (everyone sees it); your screen edge pulses yellow; HUD "STIMMED 3.1". Blender textures from `tools/vfx/make_stim_vfx.py` (`STIM_*` in `Config/VfxTextures`).
- **Hands / poses:** gun dips (`STIM_DIP`) while the free hand comes up and slams the beacon down (`StimSlam` gesture), small camera dip; third person plays the Place clip (`useKind`). The beacon isn't shown in the hand yet.
- **Verified (playtest):** the ally dummy is stimmed, the enemy dummy isn't; walk speed 15.2 → 17.5 (×1.15); the HUD counts down from 4.0 after leaving; the ring, beacon and screen edge show.


## Changes from the user's feedback (2026-10-29)
- **Brimstone-style toss** instead of dropping it at your feet. `Mods/Stim.landing` (shared by the client's check and the server): `tossDistance` 5 studs ahead along your flat look at waist height, short of a wall, onto the floor below; else the floor under you; refused with neither ("No ground"). `Config/Mods` Stim L1: `tossDistance` 5, `tossRelease` 0.3, `tossTime` 0.4, `deployTime` 0.25; the zone's pulses start after all three.
- **First person:** new free-hand gesture `StimToss` (`Config/Viewmodel MOD_GESTURES`) carrying the beacon (`ModProps`, hand size) until its release; `ViewmodelController.gesture` takes an optional prop. Our world beacon starts from our first-person hand at the release, so the hand-off is seamless. Third person: the Lob clip (`useKind = "Lob"`).
- **World:** `Util/StimFx` flies the beacon on an arc from the hand (1.4 studs high, pitching over to land upright), plays the drop sound and a few sparks on landing, a small hop, then deploys as before.
- **Verified (playtest):** in the hand for 0.3 s, out of the hand at the release point, landed 5.0 studs ahead at ~0.73 s, zone on and STIMMED shown.

## Mobile (provisional)
Tap the Stim button to drop it.

## Counter-play
Enemies can see the zone and who's stimmed, so back off or fight outside the zone. The stim only lasts 4 s after leaving it, and it's one per round. The toss is short and readable: you see where it will land.

## Upgrades (L2/L3), built 2026-11-03
Paths and numbers: [Upgrade Paths → 8. Stim](Upgrade%20Paths.md#8-stim-decided-2026-11-03) (decided by the user). Built on its own branch, **not playtested yet** (the hub tests in Studio).

| Level | What it does in game |
|---|---|
| **A2 Quick Stims** | 2 charges; each zone lasts 4 s and you stay Stimmed 2 s after leaving. Numbers only (`Config/Mods` A2). Two zones at once each run their own beacon, ring and server timers. |
| **A3 Quick Stims** | 4 charges, same 4 s zone. |
| **B2 Strong Stim** | The zone gives **StimStrong** (`Config/StatusEffects`: +25% move and fire rate, reloads 25% and swaps 45% shorter) instead of Stimmed. Never both: a strong zone ends a Stimmed from another zone, and a plain zone leaves a StimStrong alone. |
| **B3 Strong Stim** | The zone lasts 16 s (you still stay stimmed 4 s after leaving). |
| **G2 Heal Zone** ⚡ | No stim. You and your team inside heal 7.5 HP/s (0.75 every 0.1 s tick, 60 HP over the full 8 s) through `ctx.restore`, so a Heal Orb heal over time on the same person keeps running. Enemies never. |
| **G3 Heal Zone** ⚡ | 2 charges. |

### How it's built
- **Server** (`Mods/Stim.luau`): each tick, `touch` either restores HP (`behaviour = "Heal"`) or applies `stats.status` (L1 default `"Stimmed"`, B2 sets `"StimStrong"`). Ending a Stimmed early re-applies it for 0.001 s (`StatusService.apply` ignores 0).
- **Client looks** (`Util/StimFx.luau`): a drop can carry a `Look` (colours, ring texture, edge and mast emitters, bolts, coil colour, hum and deploy sounds, plus `onDeploy` / `onStep` / `onFade` / `onRemove` hooks). `Util/UpgradeFx/Stim.luau` picks the look from the drop's level (`Mods.stats("Stim", data.level)`) and draws it; L1 and path A keep the plain look.
- **Strong Stim look:** white-hot-to-gold (`FFC21F`) arcs, bigger and three times as many along the edge, bolts twice as often and thicker, a white-hot coil, a dashed ring spinning just inside the edge, the zone hum pitched up. Stimmed bodies crackle hotter and bigger with sparks spitting up; your screen edge goes gold and pulses deeper and faster; the HUD says **STRONG STIM 3.1**.
- **Heal Zone look (glitched):** the Heal Orb's green-teal (`5CFFC8`) halo ring (`HEALORB_RING`), a soft glowing floor, wisps rising along the edge, motes and heal crosses rising across the floor and off the mast, the coil green-teal, the Heal Orb's chimes as a soft hum. The glitch on top: a dashed magenta rim flickering just outside the halo, magenta static pixels popping on the rim and inside (~32 a second), thin scanlines tearing across, and every 1.2–3 s a glitch moment (the halo blinks, the coil flashes magenta, the beacon jumps a few tenths of a stud, sometimes a quiet static blip). It dies out with the static fizzle.
- **People being healed** (anyone inside whose health goes up, so only what the server healed shows): green-teal motes and crosses rising off the body, "+N" over their head every second, and for you a soft green-teal screen edge that flicks magenta now and then.
- The Heal Zone is green-teal for every viewer, like the Heal Orb; whose it is shows on the beacon's status light (team colour).

### Playtest checklist (hub)
- [ ] A2: two Stims down at once: two beacons, two rings, each ends after 4 s; stimmed time after leaving is 2 s. A3 starts the round with 4.
- [ ] B2: walk speed ×1.25 (e.g. 15.2 → 19), HUD says STRONG STIM, gold crackle and screen. Standing in an L1 zone and a B2 zone together: only StimStrong (speed ×1.25, not ×1.44).
- [ ] B3: zone lasts 16 s, stim lasts 4 s after leaving.
- [ ] G2: hurt yourself (dev panel "Hurt me"), stand in it: +60 HP over 8 s, "+N" on an ally dummy, nothing on the enemy dummy, no Stimmed. Heal Orb on yourself inside: both heals land.
- [ ] G2 look: green-teal halo and motes with magenta static and flicker, beacon jitters, gentle chime hum, not too noisy.
- [ ] G3: 2 charges.

### Name and card text proposals (not applied; the names stay as decided)
| Path | Now | Proposal | Why |
|---|---|---|---|
| A | Quick Stims | **Microdose** | Says "smaller, more often" in one word; fits the stim theme. |
| B | Strong Stim | **Overdrive** | Reads as a bigger buff; "Strong Stim" is also the status name, so the card and the HUD wouldn't repeat it. |
| G ⚡ | Heal Zone | **Restore Point** | A computer-glitch name like Recall's Crash Recovery: the beacon turns into a system restore that heals. |
