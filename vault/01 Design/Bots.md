# Bots

AI players for matches: they fill empty team slots (1v1 to 3v3), draft, fight, use Mods and count for every result. Lane C of [Overnight 2026-11-04](../05%20Production/Overnight%202026-11-04.md). **Status (2026-11-04 night): built and playtested in Studio (1v1, 2v2, 3v3, a full match to 5). See "Build log".**

## Goals
- Fight like a **decent human**, not an aimbot: a reaction delay, aim that settles onto you, misses, recoil they only partly control, strafing, peeking, sprinting between fights, sliding in.
- **Same rules as players.** Same rig, same movement simulation, same gun numbers, same damage path (shield, guards like Barrier and Ghost, kill feed), same draft seats, same Mod code. Nothing faked (the old test opponent faked hits with a dice roll; it is replaced).
- **Cheap:** 10 Hz decisions, staggered across bots, a few raycasts per tick, no per-frame allocations, everything cleaned on despawn.
- **Easy to improve:** each behaviour is a scorer plus an action; difficulty is data in `Config/Bots.luau`.

## Research summary
Full report and sources from the research pass (2026-11-04):
- **Architecture.** Shipped shooters used behaviour trees/DAGs (Halo 2, CS:GO bots), FSM + GOAP planning (F.E.A.R.), and data-driven skill profiles (Counter-Strike `botprofile.db`). For small arena duels a **flat utility selector** is the simplest structure that stays extendable: each goal scores itself, the best wins, with hysteresis (a switch needs a clearly better score and a minimum commit time) so bots don't dither. Sources: [Halo 2 AI, GDC 2005](https://gamedeveloper.com/programming/gdc-2005-proceeding-handling-complexity-in-the-i-halo-2-i-ai), [F.E.A.R. GOAP](https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf), [Killzone 2 MP bots](https://www.guerrilla-games.com/media/News/Files/VUA07_Verweij_Hierarchically-Layered-MP-Bot_System.pdf), [BT vs utility](https://gamedeveloper.com/programming/are-behavior-trees-a-thing-of-the-past-), [Valve BT bots](https://developer.valvesoftware.com/wiki/Mp_bot_ai_bt).
- **Perception.** Each bot keeps a memory per enemy (last seen position and time, first seen time). Sight = vision cone + line-of-sight raycast; a newly seen enemy only becomes a target after a **reaction time** (Valve's CS tiers run 1.0 s easy down to 0.22 s expert); re-acquiring someone seen a moment ago is faster. Gunshots are heard and give a rough position. Memory fades to a search, then is forgotten. ([CS bot profiles](https://gist.github.com/so0k/7505931))
- **Aim.** A critically damped spring toward the aim point (lag that feels like a hand), plus an **aim error** that starts large on a new target and decays toward a floor while tracking (CS's AimFocus does the same), re-inflated when the target changes direction. Recoil is compensated only partly. Chest by default, head by chance. ([UE critically damped smoothing](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Core/FMath/CriticallyDampedSmoothing))
- **Movement.** Random-length ADAD strafes (never a rhythm), a preferred range per gun class, retreat when low, slide into fights, team spacing so bots don't clump, different angles per teammate.
- **Navigation.** Roblox PathfindingService is fine for small arenas if paths are recomputed sparingly and followed by steering (no waiting on MoveToFinished); stuck detection escalates jump → strafe → replan. A hand or build-step waypoint graph per map is the upgrade path. ([Roblox pathfinding](https://create.roblox.com/docs/characters/pathfinding))

## How bots plug into the game
The codebase is Player-keyed almost everywhere. Making every service accept a non-Player is a big refactor of shared files during a night with four lanes, so bots plug in where the code is already generic and through **small, named hooks** elsewhere:

| System | How a bot uses it | Same code as players? |
|---|---|---|
| Rig | `Players:CreateHumanoidModelFromDescription` R15, `CharacterService.prepare` + `useOurAnimations` (Health, hitbox history, regen off) | Yes |
| Where it lives | `Workspace.Dummies` with `TeamId`; the client already treats Dummies as combatants (FX, HUD team bars, kill feed by model name) | Yes |
| Movement (walk, sprint, crouch, slide, slide-jump, jump, gravity) | Each bot has an **owner** instance (a `Configuration`, server-only) holding the attributes a Player holds and a cloned `PlayContext`. The shared movement simulation steps bots from a registry (`Simulation/Pawns`) and reads the bot's virtual inputs | **Yes**: `Simulation/Movement` |
| Predicted Mods (Dash, Updraft) | Same simulation reads the owner's `Mod<n>Id/Level` and the Mod input | **Yes**: `Simulation/Abilities` |
| Third-person poses | `Simulation/Poses` steps bots from the same registry; the owner carries `WeaponId`, `ReloadAt`, `HitAt`, `ModUseAt`…, the `PlayContext` carries `Aim`/`AimPitch` | **Yes** (5-line hook in lane D's file) |
| Guns | `Bots/BotGun`: the gun state (ammo, reload, shell reload, equip, fire interval, burst, spin-up, spray heat, alt-fire) with the **same** `Config/Weapons` numbers and shared utilities (`FireRate`, `Accuracy.cone`, `Spread.shot`, `Damage.compute`). Pellets are real raycasts from the head; walls and thin-wall penetration use WeaponService's own check; hits go through **WeaponService's damage path** (hook: `WeaponService.damageBy`) | Same rules and damage path; the client-claim validation layer doesn't apply (the server is the shooter) |
| Server Mods (Molly, Frost, Stim, Heal Orb, Recon) | `Bots/BotMods` builds the same `ServerCtx` ModService builds and calls the Mod module's own `validate` / `apply`; the bot's character model is the caster (`Teams.characterOf`), charges use the same `Mods/Charges` rules | Mod code: yes. ModService's request ladder: no (it is client validation) |
| Draft | A seat in `DraftService` like the test opponent's; `Bots/BotDraft` picks a sensible gun and card from the seat's offers | Yes |
| Round results, shields, charges | `MatchService` counts bot fighters per team (health + shield), gives shields, refills charges | Yes |

**Not supported yet:** Firewall (ModWalls) and Recall (ModRecall) need a Player in their services; bots don't draft them while anything else is offered. Damage modifiers (Ping Spike-style bonuses) skip bot attackers.

**The hooks outside lane C's own files** (all small, commits 7493454 and b998b69):
- `Simulation/Movement` and `Simulation/Poses`: the server step also loops `Simulation/Pawns`.
- `WeaponService.damageBy` (damage from a bot model: guards, shield, health, Damaged, Killed) and `WeaponService.wallBlocked`.
- `Mods/Teams.characterOf`, used by five `caster.Character` reads in Stim, Molly, HealOrb, Blocks/Reveal and Blocks/Target.
- `ModEntities.place`: `OwnerId` is 0 for a bot owner.
- `MatchService`: bots instead of the test opponent (seats, teams, spawns, round results, shields, charges, draft, waiting and bot fill, MatchPlan teams). `TestOpponent.luau` and `Config/Match.TEST_OPPONENT` are gone.

## Brain
Per bot, a 10 Hz **think** (staggered so bots don't think on the same frame) and a cheap per-Heartbeat **act** (aim spring, move input, trigger).

1. **Perceive** (`Bots/Perception`): for each enemy, a cone + LOS raycast (head, then chest), at most 3 rays per bot per think. Memory per enemy: `seenAt`, `lastPos`, `visibleSince`. Hearing: shots within `hearRadius` set a noisy last-known position. Reaction: an enemy is **engageable** only after `reaction` seconds visible (half if seen in the last second).
2. **Choose a goal** (utility, `Bots/Brain`): Engage (a target it has reacted to), Retreat (low health + shield; less likely when aggressive or the enemy is lower), Hunt (last-known position, a flank offset per teammate), Hold (hurt and cautious: crouch and wait), Roam (the enemy spawn first, then patrol points: both spawns, the middle, both flanks; it never parks). Switching needs `+0.15` and a 0.6 s commit.
3. **Act:**
   - **Move** (`Bots/Nav`): a path to the goal with PathfindingService (one shared Path object, one compute at a time across bots; recomputed at most every 0.8 s or when the goal moves > 6 studs), steering to waypoints, jumping on jump links. Stuck detection: jump, then sidestep, then a new path (a Roam point it can't reach is swapped). In a fight it strafes (random 0.25–0.7 s legs, with pauses), keeps the gun's range band, crouches now and then at long range and jumps sometimes. It sprints when travelling and slides when sprinting to within 10–26 studs of a target (Hard bots sometimes slide-jump). Teammates push apart under 8 studs.
   - **Aim** (`Bots/Aim`): a critically damped spring on yaw and pitch toward the target point (60 ms lead), plus an aim error that starts at `errorStart` on a new target, settles to a drifting wobble at `errorFloor` and grows when the bot is hit, plus recoil it only partly pulls back. The trigger goes when its *intended* aim is on target (it doesn't know its error), after a 40–120 ms trigger delay. Auto guns past 45 studs fire 3–6 shot bursts; semi-auto guns get a finger's gap. It aims down sights past 14 studs. The body turns with an `AlignOrientation`; `AimPitch` poses the upper body.
   - **Mods** (`Bots/BotMods`): one "when to use" rule per Mod (table below).

### Mod rules
| Mod | When a bot uses it |
|---|---|
| Dash | Close the gap with a shotgun or SMG when the target is 12–32 studs away (a dash goes where the bot faces) |
| Updraft | Escape when low and under fire, or take height when an enemy is far |
| Molly | Enemy out of sight, last seen under 4 s ago, 12–45 studs away: throw at the last-known spot. Sometimes into a 10–28 stud fight. Throws are aimed by simulating the Mod's own flight at 5 pitches |
| Frost | Enemy visible within 25 studs while the bot pushes |
| Stim | Hurt (below 60%) and nobody in sight |
| Heal Orb | Self below 55% and not hit in the last 0.6 s; else the most hurt ally (below 50%) within 40 studs |
| Recon | Nothing seen or remembered: launch toward the enemy side. A reveal tells every bot on the team where the targets are |
Plus a per-difficulty `abilityUse` chance and a short random delay, so they don't cast the instant a rule is true.

## Match integration
- **Lobby → Match TeleportData** (`Bots/MatchPlan`): read from the first joining player, validated exactly per the Overnight contract (`v = 1`, `matchId` string ≤ 64, `mode` in 1v1/2v2/3v3, two teams of integer userIds with each team ≤ mode size, no duplicates, `bots` boolean). Listed players are placed on their listed team; after a grace of `Config/Bots.JOIN_GRACE` (8 s, 3 s in Studio) any empty slot fills with a bot when `bots = true`. Unlisted joiners are ignored for teams (they go where there's room). Bad data → no plan (old join-order behaviour, no bots).
- **Studio dev path:** Workspace attribute **`BotMatch`** = `"1v1"`, `"2v2"` or `"3v3"` (Studio only) acts like a plan with you on team 1 and `bots = true`. Also needs `TestMode` unticked. `BotDifficulty` (`"Easy"`/`"Normal"`/`"Hard"`) overrides the difficulty. Without `BotMatch` a solo Studio playtest still gets one bot opponent (replaces the old test opponent).
- **MatchService hooks** (small): seats, teams and round results include bots; shields/charges/draft hand-outs go to bots via `BotService`; bots fight only while the round is live.

## Tuning knobs (`src/shared/Config/Bots.luau`)
Difficulty profiles (Easy / Normal / Hard), starting values from the research table, tune in playtests:

| Knob | Easy | Normal | Hard |
|---|---|---|---|
| reaction (s) | 0.55 | 0.36 | 0.24 |
| aimSmooth (s, spring) | 0.26 | 0.16 | 0.10 |
| aim error start / floor (deg) | 7 / 1.6 | 5.5 / 1.1 | 3.5 / 0.45 |
| error settle (s) | 0.6 | 0.42 | 0.28 |
| headChance | 0.08 | 0.2 | 0.38 |
| recoil control | 0.4 | 0.65 | 0.85 |
| aggression | 0.35 | 0.55 | 0.75 |
| hearing (studs) | 35 | 50 | 65 |
| memory (s) | 3 | 5 | 8 |
| abilityUse | 0.35 | 0.6 | 0.85 |

Other knobs in the same file: think rate (10 Hz), rays per think (3), range bands per gun class, strafe timing, slide range, team spacing, path recompute limits, burst sizes, trigger delay, names, team shirt colours, join grace. In Studio the Workspace attribute `BotDifficulty` (`Easy`, `Normal` or `Hard`) overrides the difficulty.

## Known gaps / next
- **Firewall and Recall** aren't cast by bots (ModWalls and ModRecall are Player-keyed). Bots avoid drafting them.
- **No knife:** bots never swap to melee.
- **No real peeking or cover choice yet:** in a fight bots strafe in the open, and Retreat runs 25 studs away from the enemy. Next: score nav points for cover (line of sight to the last-known position) and add jiggle peeks.
- **No precomputed nav graph:** paths come from PathfindingService on the fly. That is fine on the current maps; a per-map waypoint graph with cover and peek tags is the upgrade path.
- **Damage modifiers** (Ping Spike-style bonuses) skip bot attackers. Bots get no HitConfirm (they don't need one).
- **Heal ribbon FX** from a bot healer is missing (the client draws it from a Player caster). The heal itself works.
- **Players who leave mid-match** aren't replaced by bots yet.
- **Mod use may be a little busy:** most bots throw 1–3 times a round. Lower `abilityUse` if it feels spammy.
- The pinned StyLua 0.20 binary is blocked by Windows Application Control on this machine. Lane C formatted with StyLua 2.6.0 (same `stylua.toml`). Worth unblocking or re-pinning.

## Build log
- **Phase 1 (plan):** the research pass (sources above) and this design. The key finding in the code: the shared simulations (Movement, Abilities, Poses) only read attributes and `PlayContext` InputActions off a Player, and `InputAction:Fire` works on the server (tested). So a server-only owner stand-in lets bots run the exact same movement, Dash/Updraft and pose code. Guns and server Mods are Player-keyed services, so bots use their shared rules and damage paths through small hooks.
- **Phase 2 (prototype, 1v1 on Whitebox):** the bot drafted (Stim + Frost, the Bucky in round 2), sprinted across the map on a path, found the AFK player and killed them. The round loop, the kill feed ("PATCH [Bucky] YOU") and the score bar showed it by name, and poses played (aim hold, direction-blended run). Critique: the aim needed numbers, Mods didn't cast yet, and there was no way to see what a bot was doing.
- **Phase 3 (full build):** Mods with rules, Recon reveals, patrol roaming, and Studio tuning attributes on each owner (`BotGoal`, `BotTarget`, `BotShots`, `BotHits`).
  - **2v2 test:** Molly, Frost and Stim throws, kills both ways, hit rates 36–64%. Found: after the first kills the last two bots roamed to each other's spawns and idled for 30 s. Fixed with patrol points.
  - **3v3 test (5 bots and the AFK player):** sprints, slides, heals and throws; both teams won rounds (team 1 took round 4). Found: Recon darts errored in `ModEntities.place` (`owner.UserId`), fixed. Every bot took the same SMG in one round, so the draft got more randomness. SMG hit rates were 65–75%, so Normal aim was loosened (error 5 → 5.5, floor 0.9 → 1.1).
  - **1v1 full match (another map, Ghost pistol):** 5 of 19 shots hit at range. 5 rounds, MatchEnd 0–5, and the next match started with the same bot.
  - **Dash check:** pressing the bot's own `Mod2` input with Dash in the slot cast it through `Simulation/Abilities` (Dashing, charge spent, moved 28.8 studs).
- Lint (`selene`), format (StyLua 2.6.0) and `rojo build` pass. No new remotes. TeleportData is the only client-sourced input; it is validated (types, mode, team sizes, integer userIds, no duplicates) and only accepted from a player it lists.
- Studio: the Workspace attributes used for testing are back as they were (`TestMode` on, no `BotMatch`). Nothing else changed in the place, so there was nothing to save.

## What the user should test tomorrow
1. **1v1 against a bot:** untick Workspace `TestMode`, add the Workspace string attribute `BotMatch` = `1v1`, and Play. Fight it for a few rounds on Normal. Does it feel fair, too sharp or too dumb? Try `BotDifficulty` = `Easy` and `Hard`.
2. **2v2 and 3v3:** `BotMatch` = `2v2` or `3v3` gives you bot teammates. Watch them spread out, focus targets, throw Mollies at where you hid and heal.
3. **Animations on bots** (lane D's poses): running, sliding, reloading, throwing, the flinch when hit.
4. **Kill feed, top bar and round results** with bot names; a match to 5 and the next match starting.
5. **Solo Studio with no `BotMatch`:** one bot still joins the other side after 3 s (the old test opponent's job).
6. **Lobby → Match with bots,** once lane B's queue teleports: a party with `bots = true` should get bots in the empty slots after about 8 s.
7. Tell me what feels off (aim, Mod spam, movement) and I'll tune `Config/Bots.luau`.
8. After testing, turn `TestMode` back on and clear `BotMatch` if you want the test range again.
