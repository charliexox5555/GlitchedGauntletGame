# New abilities for the free pack: brainstorm and build brief (2026-11-17)

**Status: spec locked 2026-11-17 (the owner accepted every proposal below). Nothing is built yet.** Studio is busy with other work; the build starts from [Handoff - New Abilities](../../05%20Production/Handoff%20-%20New%20Abilities.md). Every "proposed" number and name in this note is now the spec.

The owner wants three new Mods, free for everybody, joining the nine in [Abilities](../../01%20Design/Abilities/00%20Abilities.md): a **bot that rolls out and blows up**, a **flash**, and a **shock dart** fired from a bow like Recon's. The owner's paths are below as given, then turned into our level format (L1, A2/A3, B2/B3, G2/G3) with proposed numbers.

> **Names.** "Boom Bot" and "Kay-O" are Valorant names. We take mechanics, not names (the same rule as RIVALS: study, don't copy). Working names here: **Roller** (the bot), **Flash**, **Shock Dart**. "Flash" and "Shock Dart" are plain words, fine to keep. **Decided:** Roller, Flash, Shock Dart.

## The owner's input (2026-11-17)
| Ability | A | B | G (glitch) |
|---|---|---|---|
| Bot | Charges 1 → 2, then 2 → 4 | Speed 100 → 125% and duration 5 → 7 s; then speed 125 → 150% and duration 7 → 10 s | Reactivate to explode the bot at any time; add a 7 s recharge; speed 100 → 125%; duration 5 → 7 s |
| Flash | Charges 1 → 2, then 2 → 3 | Add a 15 s recharge, then 15 → 6 s | Reveals enemies it hits instead of blinding them (works like Recon); add a 15 s recharge |
| Shock Dart | Add a 15 s recharge, then 15 → 6 s | Charges 1 → 2 with a little less damage, then 4 charges with a little less again | Hinders instead of damaging; add a 15 s recharge |

So all three start at **1 charge per round with no recharge** (like Molly and Frost). A recharge is something you earn on a path.

## 1. Roller (the bot)
**What it does.** Hold the key to take out the bot; LMB sets it down and it rolls forward along the floor. It turns at walls. When an enemy comes into its front cone (in sight, within range) it locks on, speeds up toward them, then **explodes** after a short warning chirp. If it finds no one, it fizzles at the end of its time. It has a little health, so you can shoot it.

| | L1 |
|---|---|
| Charges | 1 per round, no recharge |
| Speed | 14 studs/s (100%), 22 studs/s once locked on |
| Active time | 5 s |
| Lock-on | Enemies in sight within 25 studs, in a 60° cone ahead |
| Explosion | 0.4 s warning after lock-on; 60 damage at the centre falling to 30 at the 6-stud edge; no damage through walls; 50% to the caster's team (the house rule) |
| Health | 25 HP (one or two rifle shots) |
| Key | **T** (slot 3; T has 2 Mods, E has 5) |

| Level | Effect |
|---|---|
| A2 More Bots | 2 charges |
| A3 More Bots | 4 charges |
| B2 Faster | 125% speed (17.5 studs/s), 7 s |
| B3 Faster | 150% speed (21 studs/s), 10 s |
| G2 Remote ⚡ | **Press the key again to blow it up at any time.** It still seeks and explodes on its own |
| G3 Remote ⚡ | + a 7 s recharge, 125% speed, 7 s active |

Reading of the owner's G line: it lists four things in one cell. Decided split: the remote blow-up at G2 (the glitch twist) and the numbers at G3. The second press uses the same pattern as Crash Down (a second press of the Mod key while the bot is out; it can't spend a charge).

**Hard parts.** A moving entity the server owns (position, turning, lock-on, damage). It should move as a server-simulated, anchored part with client-side smoothing, like the thrown canisters (`shared/Projectile` paths plus `ModFxController.onCanisterThrow`). The server checks floor and wall hits each step. Bots (`server/Bots/BotMods.luau`) need to know how to use it and how to shoot it.

## 2. Flash
**What it does.** Hold the key to take out the flash; LMB throws it (it pops 0.9 s after leaving the hand), RMB pops it from the hand after 0.3 s (a quick flash round a corner). Everyone **facing** the pop, with a clear line to it, within 30 studs, is blinded. How long depends on how directly they were looking at it.

| | L1 |
|---|---|
| Charges | 1 per round, no recharge |
| Blind | Up to 1.75 s when looking straight at it, down to 0.6 s at 90° to the side, none if it was behind you (more than 110°) or behind a wall |
| Who | Enemies and teammates. **The caster too** if they look at it (decided: everyone who looks at it) |
| What a blinded player sees | The screen goes white in a stylised way (faceted plates closing in from the edges in 0.06 s, the centre last), held, then the plates break away (0.4 s). Sound muffled. Our own look, not a photoreal glare |
| Key | **Q** (slot 1; Q has 2) |

| Level | Effect |
|---|---|
| A2 More Flashes | 2 charges |
| A3 More Flashes | 3 charges |
| B2 Recharge | Comes back 15 s after use |
| B3 Recharge | Comes back 6 s after use |
| G2 Exposure ⚡ | **No blind.** Every enemy who would have been blinded is **revealed** (Recon's outline for your team, DETECTED for them) for 3 s; + a 15 s recharge |
| G3 Exposure ⚡ | Reveal 5 s, and the flash works through one wall (decided 2026-11-17) |

**Server truth.** Who gets blinded is decided on the server. With Server Authority off, clients own their movement, so the server reads each player's replicated head and camera direction (the same server copy of the camera `WeaponService` uses for aim tolerance) and does the line-of-sight raycast itself. The blind is a new status, `BlindedUntil` plus a strength, in `Config/StatusEffects`, written by `StatusService` like Hinder. Bots react too: a blinded bot stops aiming.

## 3. Shock Dart
**What it does.** The Recon bow and controls exactly (hold LMB to charge, choose 0-2 bounces), but the bolt **explodes where it lands** instead of sticking and pulsing.

| | L1 |
|---|---|
| Charges | 1 per round, no recharge |
| Flight | Recon's (45-130 studs/s by charge, 2 bounces) |
| Explosion | On impact: 50 damage at the centre falling to 25 at the 5-stud edge (smaller than the Roller's 6); not through walls; 50% to your own team |
| Look | An electric burst (Stim's arcs are the nearest kit), in the effects language: white-blue arcs, one flash, a flat ring |
| Bow | Reuse the Recon bow with a different bolt head and an amber charge strip, so it reads as a different Mod |
| Key | **E**, like Recon. Then you can't hold both bows at once, so no "which bow is this?" confusion |

| Level | Effect |
|---|---|
| A2 Recharge | Comes back 15 s after use |
| A3 Recharge | Comes back 6 s after use |
| B2 More Darts | 2 charges, 42 damage at the centre (-15%) |
| B3 More Darts | 4 charges, 36 damage at the centre (-28%) |
| G2 Static ⚡ | **No damage: Hinders** everyone in the radius for 2 s (Frost's status), + a 15 s recharge |
| G3 Static ⚡ | Hinder 3 s in a 7-stud radius (decided 2026-11-17) |

## Decisions (owner, 2026-11-17: "choose the proposals for all of them")
1. **Names:** Roller, Flash, Shock Dart. Paths: Roller More Bots / Faster / Remote; Flash More Flashes / Recharge / Exposure; Shock Dart Recharge / More Darts / Static.
2. **Keys:** Roller **T** (slot 3), Flash **Q** (slot 1), Shock Dart **E** (slot 2, shares Recon's key and bow). Each key then holds: Q 3, E 6, T 3.
3. **Roller's glitch path:** G2 Remote = press the key again to blow it up any time (it still seeks); G3 = + a 7 s recharge, 125% speed, 7 s active.
4. **G3s the owner didn't give:** Flash G3 = reveal 5 s and the flash works through one wall; Shock Dart G3 = Hinder 3 s in a 7-stud radius.
5. **Flash blinds everyone who looks at it:** enemies, teammates and the caster.
6. **Shock Dart bow:** Recon's bow with its own bolt head and an amber charge strip; no new bow model.
7. **Damage as proposed:** Roller 60 → 30 over 6 studs, Shock Dart 50 → 25 over 5 studs (100 HP); a dart plus a Roller can kill a full-health player, accepted.
8. **Free pack:** all 12 Mods are in everyone's draft from the start. Any later paid Mod pack gets a pay-to-win and policy check first (`roblox-monetization-compliance`); not part of this build.

## Build brief
> Build the three new free Mods: Roller, Flash, Shock Dart. Read `CLAUDE.md`, load the `gauntlet-vault` skill, then this note: `vault/04 Tech/Prompts/2026-11-17 New Abilities (Free Pack).md`. The spec and the owner's decisions are locked (section "Decisions"). Opus for everything; one or two workers at a time, never a crowd; follow the usage rules in `vault/05 Production/Handoff - Ability Rework (Opus).md`.

**Order (cheapest first, each one finished and checked in Play before the next):**
1. **Shock Dart** (reuses Recon's bow, flight, bounces and charge HUD).
2. **Flash** (a new status and a new screen effect).
3. **Roller** (a new moving entity the server owns, and bot AI).

**Per Mod, in this order:**
1. **Spec note** `vault/01 Design/Abilities/<Name>.md` in the shape of `Recon.md` (what it does, numbers, look, sounds, upgrades, test list); add its row to `00 Abilities.md` and its section and key to `Upgrade Paths.md`.
2. **Data** in `src/shared/Config/Mods.luau` (id, slot, paths, `activation`, levels L1 to G3, `note` and `card` text, icon) and the `ORDER` list in the same file. All numbers here, none in code.
3. **Server logic** `src/shared/Mods/<Id>.luau` on the `ModModule` contract (`shared/Mods/Types.luau`); `authority = "Server"`. Reuse: Recon's dart (`shared/Mods/Recon.luau`) for Shock Dart; the throw and `Projectile` path code (Molly, Frost) for Flash and for setting the Roller down. Damage goes through the same path as Crash Down (`slamLanded` in `shared/Mods/Updraft.luau`): line of sight, no self damage, `FRIENDLY_FIRE` for the team.
4. **Remotes:** no new ones if possible. Use `ModHold` / `ModUse` (the Roller's second press like Crash Down's). Anything new: types, finite numbers, rate limits, never trust client values (CLAUDE.md rule 3). Run `roblox-secure-remotes` and a security review.
5. **Statuses:** Flash adds `Blinded` (`BlindedUntil` + strength) in `Config/StatusEffects`, written by `StatusService`, shown in the status tray (`Util/StatusTray`); G2 reuses Recon's reveal path (`ModReveal`, DETECTED). Shock Dart G2 reuses Hinder.
6. **Client effects** on the shared kits (`Util/ReworkVfx`, `GlitchVfx`, `ModVfx`) in the locked effects language ([Ability VFX Direction](../../02%20Art/Ability%20VFX%20Direction.md)): shapes first, three beats, aim area clear, team colour on gameplay lines, **magenta only as a two-frame accent** on the glitch path's key moment. Rule from the fire pass: look at a capture and judge it before calling it done; a literal spec build was rejected once. References: RIVALS `FlashbangEffect` (one glow 50 → 1 studs over ~0.5 s plus a PointLight) and `ExplosionEffect` numbers in `vault/03 Research/Rivals Reference/Ability VFX Numbers.md`. Numbers and recipes only, never their assets.
7. **Props** in live Blender MCP to `gauntlet-build-style` (no round curves or spheres, carved ends): the Roller (a faceted wedge-shaped roller with a visible "eye" that turns team colour on lock-on), the flash canister, the shock bolt head. Upload and install through the ability pipeline (handoff → "Things that cost time once already" → Uploads). **Check every installed part against its Blender render**: the Recon bow's limbs came in turned 180° (`MESH_TURN_Y` in `tools/studio/make_ability_build_data.py`).
8. **First person:** hold, raise, use and recover in `Config/Viewmodel` (`ITEM_HOLDS`, `ITEM_ACTIONS`); forearms go down out of frame, held items around 1.3 scale; the dart reuses the bow hold and draw. **Third person:** poses in `shared/Simulation/Poses.luau`.
9. **Sounds:** named hooks in `Config/ModSounds` with good placeholders (`lihfolk-sfx`); list them in the spec note.
10. **Icons:** ChatGPT prompts in the house icon style (`vault/02 Art/UI Art Brief (ChatGPT).md`); the owner runs them.
11. **Bots:** `server/Bots/BotMods.luau` can use each Mod, and bots react: they shoot the Roller, turn away from a Flash, step out of a dart's radius when they can.
12. **Checks:** lint, StyLua, `rojo build`; Play with dummies (`DevMod` `SetSlot` / `UnlimitedCharges` / `SpawnDummy`) at every level; captures in grey and colour; a 2-client test (Test → Clients and Servers) for what others see; a playtest note in `vault/05 Production/Playtests/`.

**Done when:** all three are draftable at every level, look and sound finished (not placeholder boxes), bots use them, the 2-client check passes, and the vault is updated (Home status, Asset Tracker rows, Code Map lines, INDEX).

## Sources used
- [Abilities](../../01%20Design/Abilities/00%20Abilities.md) (rules: charges per round, keys, 50% friendly fire, look and sound standard), [Upgrade Paths](../../01%20Design/Abilities/Upgrade%20Paths.md) (level format, keys per Mod), `Config/Mods.luau` (Recon's L1 numbers), `Config/StatusEffects.luau` (Hinder), `Config/Combat.luau` (100 HP), [Code Map](../Code%20Map.md) (Mod remotes).
- [Ability VFX Direction](../../02%20Art/Ability%20VFX%20Direction.md), [Effects Pass Overnight](../../05%20Production/Playtests/2026-11-16%20Effects%20Pass%20Overnight.md) (the glitch rule, held-item scale), [Recon Bow Draw](../../05%20Production/Playtests/2026-11-16%20Recon%20Bow%20Draw.md).
- RIVALS: `Body, Viewmodel, Guns and VFX.md` → Ability VFX (Flashbang, held items) and `Ability VFX Numbers.md`.
