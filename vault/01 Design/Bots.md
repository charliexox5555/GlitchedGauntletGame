# Bots

AI players for matches: they fill empty team slots (1v1 to 3v3), draft, fight, use Mods and count for every result. Lane C of [Overnight 2026-11-04](../05%20Production/Overnight%202026-11-04.md). **Status: see "Build log" at the bottom.**

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
| Third-person poses | `Simulation/Poses` steps bots from the same registry; the owner carries `WeaponId`, `ReloadAt`, `HitAt`, `ModUseAt`…, the `PlayContext` carries `Aim`/`AimPitch` | **Yes** (2-line hook in lane D's file) |
| Guns | `Bots/BotGun`: the gun state (ammo, reload, shell reload, equip, fire interval, burst, spin-up, spray heat, alt-fire) with the **same** `Config/Weapons` numbers and shared utilities (`FireRate`, `Accuracy.cone`, `Spread.shot`, `Damage.compute`). Pellets are real raycasts from the head; walls and thin-wall penetration use WeaponService's own check; hits go through **WeaponService's damage path** (hook: `WeaponService.damageBy`) | Same rules and damage path; the client-claim validation layer doesn't apply (the server is the shooter) |
| Server Mods (Molly, Frost, Stim, Heal Orb, Recon) | `Bots/BotMods` builds the same `ServerCtx` ModService builds and calls the Mod module's own `validate` / `apply` | Mod code: yes. ModService's request ladder: no (it is client validation) |
| Draft | A seat in `DraftService` like the test opponent's; `Bots/BotDraft` picks a sensible gun and card from the seat's offers | Yes |
| Round results, shields, charges | `MatchService` counts bot fighters per team (health + shield), gives shields, refills charges | Yes |

**Not supported yet:** Firewall (ModWalls), Recall (ModRecall) and the HeldCharge launcher need a Player in their services; bots don't draft them while anything else is offered. Damage modifiers (Ping Spike-style bonuses) skip bot attackers.

## Brain
Per bot, a 10 Hz **think** (staggered so bots don't think on the same frame) and a cheap per-Heartbeat **act** (aim spring, move input, trigger).

1. **Perceive** (`Bots/Perception`): for each enemy, a cone + LOS raycast (head, then chest), at most 3 rays per bot per think. Memory per enemy: `seenAt`, `lastPos`, `visibleSince`. Hearing: shots within `hearRadius` set a noisy last-known position. Reaction: an enemy is **engageable** only after `reaction` seconds visible (half if seen in the last second).
2. **Choose a goal** (utility, `Bots/Brain`): Engage, Push, Hold/Peek, Retreat, Hunt (last-known position), Roam (to the map centre / objective). Each scores 0..1 from health, ammo, range band, visibility, team numbers; switching needs `+0.15` and 0.6 s commit.
3. **Act:**
   - **Move** (`Bots/Nav`): path to the goal point with PathfindingService (recompute at most every 0.8 s or when the goal moves > 6 studs), steer to waypoints, jump on jump links; stuck detection: jump → sidestep → replan. In a fight it strafes (random 0.25–0.7 s legs, pauses), keeps the gun's range band, crouches to steady long shots, sprints when travelling without a target, slides when sprinting into a fight.
   - **Aim** (`Bots/Aim`): spring on yaw/pitch toward the target point + a decaying aim error + imperfect recoil compensation. Fires when the error is under the gun's cone tolerance, with burst/tap discipline per gun class.
   - **Mods** (`Bots/BotMods`): one "when to use" rule per Mod (table below).

### Mod rules
| Mod | When a bot uses it |
|---|---|
| Dash | Close the gap with a short-range gun, or dodge when hit and low |
| Updraft | Escape when low and under fire, or take height when an enemy is far |
| Molly | Enemy out of sight but last seen within ~4 s and 15–45 studs: throw at the last-known spot |
| Frost | Enemy visible within 25 studs while the bot pushes |
| Stim | Hurt (below 60%) and nobody in sight, or at fight start when equal |
| Heal Orb | Self (or the most hurt ally in sight) below 55% and not being shot this second |
| Recon | Nobody seen for 3 s: throw toward the map centre to find people |
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
| aim error start / floor (deg) | 7 / 1.6 | 5 / 0.9 | 3.5 / 0.45 |
| error settle (s) | 0.6 | 0.42 | 0.28 |
| headChance | 0.08 | 0.2 | 0.38 |
| recoil control | 0.4 | 0.65 | 0.85 |
| aggression | 0.35 | 0.55 | 0.75 |
| hearing (studs) | 35 | 50 | 65 |
| memory (s) | 3 | 5 | 8 |
| abilityUse | 0.35 | 0.6 | 0.85 |

## Known gaps / next
- Firewall, Recall and the launcher aren't usable by bots (they need Player-keyed services).
- No precomputed per-map nav graph yet (PathfindingService only); cover choice is simple (break line of sight).
- Damage modifiers skip bot attackers.

## Build log
(filled in as the phases land)
