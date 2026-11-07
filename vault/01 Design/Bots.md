# Bots

AI players for matches: they fill empty team slots (1v1 to 3v3), draft, fight, use Mods and count for every result. Lane C of [Overnight 2026-11-04](../05%20Production/Archive/Overnight%202026-11-04.md). **Status (2026-11-04 night): built and playtested in Studio (1v1, 2v2, 3v3, a full match to 5). See "Build log".**

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
| reaction (s; never under 0.15) | 0.55 | 0.36 | 0.24 |
| aimSmooth (s, spring) | 0.26 | 0.16 | 0.10 |
| aim error start / floor (deg) | 9 / 3.2 | 7 / 2.0 | 4.5 / 1.2 |
| error settle (s) | 0.6 | 0.42 | 0.28 |
| trackLag (s behind the target) | 0.35 | 0.2 | 0.12 |
| firstMisses (fair misses on a new target) | 2 | 1 | 0 |
| maxHitsPerSec (one target, from bots) | 1 | 2 | 3 |
| easeLowHealth (error × on a target under 30%) | 1.6 | 1.3 | 1 |
| headChance | 0.06 | 0.15 | 0.3 |
| recoil control | 0.4 | 0.65 | 0.85 |
| aggression | 0.35 | 0.55 | 0.75 |
| hearing (studs) | 35 | 50 | 65 |
| memory (s) | 3 | 5 | 8 |
| abilityUse | 0.35 | 0.6 | 0.85 |

Other knobs in the same file: think rate (10 Hz), rays per think (3), range bands per gun class, strafe timing, slide range, team spacing, path recompute limits, burst sizes, trigger delay, names, team shirt colours, join grace. In Studio the Workspace attribute `BotDifficulty` (`Easy`, `Normal` or `Hard`) overrides the difficulty.

## Known gaps / next
- **Cover and peeking** (LihFolk *Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking*): bots still strafe in the open and Retreat runs 25 studs away. The note's model needs authored `Cover` points per map (a ~32-stud grid scored on protection, peek line, range band and travel cost; hide 1–3 s, peek, shoot, return, alternate sides). It's the biggest remaining gap and a map task: tag cover points when the maps are redone.
- **Squad roles** (LihFolk *Squad AI - Attack Tokens, Flanking and Attacker Limits*): done so far are the cap of 2 bots on one target and the flank lane offset. Not done: pinner, flanker and waiter roles with flank points scored by angle and occupancy.
- **Path.Blocked** isn't used: one Path object is shared by all bots (the waypoints are copied out right after each compute), so a Blocked signal can't be tied to one bot. The progress-based stuck ladder covers it (LihFolk *Pathfinding Edge Cases and Fallbacks* calls Blocked "a hint; the stuck detector is the real net").
- **Debug gizmos:** there's a text label, but no path lines or perception cones (client HandleAdornments over an unreliable remote, Studio only), and no goal transition trace.
- **Firewall and Recall** aren't cast by bots (ModWalls and ModRecall are Player-keyed). Bots avoid drafting them.
- **No knife:** bots never swap to melee.
- **Damage modifiers** (Ping Spike-style bonuses) skip bot attackers. Bots get no HitConfirm (they don't need one).
- **Heal ribbon FX** from a bot healer is missing (the client draws it from a Player caster). The heal itself works.
- **Players who leave mid-match** aren't replaced by bots yet.
- **Mod use may be a little busy:** most bots throw 1–3 times a round. Lower `abilityUse` if it feels spammy.
- **Tracking lag isn't proven against strafing yet:** see the 2026-11-05 test below. It needs a hand test.
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

- **LihFolk review-and-improve pass (2026-11-05):** read the notes listed under "LihFolk notes this leans on" and the skills `roblox-system-builder` and `roblox-performance-audit`, then fixed:
  - **Aim:** aim at where the target was `trackLag` ago (a 1.2 s position trail per enemy) instead of leading it; fair first-shot misses on a new target; a per-target hit budget across all bots; aim eases on a target under 30%; error numbers raised toward the note's (Normal floor 1.1 → 2.0, start 5.5 → 7); head chance lowered; reaction never under 0.15 s (the halved re-acquire reaction on Hard was 0.12).
  - **Targeting:** no more than 2 bots on one enemy; a third looks elsewhere.
  - **Navigation:** a path goal is where the target last stood on the ground (paths to someone mid-jump fail); a failed path drops that goal (Hunt forgets the spot, Roam picks another point) instead of walking into a wall; recompute when the goal moved 3 studs or 20% of the distance left; stuck now means "no closer to the waypoint in 1.5 s" as well as "not moving", and the ladder is jump, skip the waypoint, sidestep, new path.
  - **Humanoid:** Climbing, Seated, FallingDown, Ragdoll and Flying disabled on bots.
  - **Budget and tooling:** MicroProfiler labels `BotThink` and `BotAct`; in Studio, `StepMsAvg` / `StepMsMax` / `BotCount` on `ServerStorage.BotOwners` every 120 frames and a warning past `Config/Bots BUDGET_MS` (1 ms for all bots together); `Config/Bots` is asserted at server start; Workspace attribute `BotDebug` puts a label over each bot (name, goal > target, health, hits/shots).
  - **Bug found by the pass:** `BotService.worldFor` used the patrol list before it was declared, so patrol roaming had been reading nil (a bot reaching a patrol point would have errored). Fixed.
  - **3v3 (5 bots + AFK player):** no errors. Bot cost **0.08–0.17 ms average per Heartbeat, worst 0.75 ms, one spike of 3.0 ms** (probably a Molly throw being aimed: 5 flight simulations). Hit rates came down to **32–41%** (from 36–75%). Team 2 won rounds 1 and 2.
  - **1v1 strafe check:** the test player strafed ADAD from the client in round 3 and stood still in round 2, with the same gun (Akimbo): **9/18 hits strafing vs 9/27 standing**. One round each at different ranges isn't enough to show the tracking lag working; it needs a hand test with a ranged gun.
  - Lint, format and `rojo build` pass. Studio attributes restored.

### TeleportData: what stops each attack (LihFolk system builder: exploits table)
| Attack | What stops it |
|---|---|
| A client edits its TeleportData (another mode, extra teams, bots on) | Only taken from a joining player the data lists; the first valid plan wins and later joiners can't change it; the match place is a reserved server, so only the teleported party can join |
| Wrong types, NaN or huge userIds, duplicates, team bigger than the mode | `MatchPlan.validate`: `v == 1`, `matchId` string 1–64, `mode` in Config/Bots MODES, two teams of integer userIds in (0, 2^53], no duplicates, team size ≤ mode size, `bots` boolean; anything else is no plan |
| A player listed but never arriving | Grace (8 s, 3 s in Studio), then bots fill when `bots = true` |
| An unlisted player joining | Not in the plan: keeps the join-order team (the reserved server keeps strangers out) |
Not stopped on its own: a listed player choosing which listed team they're on is up to the Lobby (it writes the teams).

## LihFolk notes this leans on
- `09 Gameplay Systems/AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses.md`: reaction floor, error numbers, track lag, fair misses, hit budget, low-health ease.
- `09 Gameplay Systems/Behaviour Trees Utility AI and State Machines for NPCs.md` and `NPC AI and Behaviour.md`: utility goals with hysteresis and a commit time, staggered think.
- `09 Gameplay Systems/Pathfinding.md` and `Pathfinding Edge Cases and Fallbacks.md`: grounded goals, failure fallbacks, relative repath, progress-based stuck ladder, shared Path copy rule.
- `09 Gameplay Systems/Squad AI - Attack Tokens, Flanking and Attacker Limits.md`: two attackers per target.
- `09 Gameplay Systems/Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking.md`: the cover and peek plan (not built yet).
- `09 Gameplay Systems/Visual AI Debugging - State Labels, Path Lines and Perception Gizmos.md`: the BotDebug label.
- `12 Performance Testing and Debugging/Script Performance.md`, `Physics Performance.md`, `MicroProfiler Guide.md`: profiler labels, the per-step budget, disabled humanoid states.
- `24 Worked Builds/Weekend Build - Arena Shooter with Server-Checked Hits.md` and `32 Case Studies of Top Roblox Games/Case Study - Rivals.md`: background (server re-raycasts hits, which BotGun does).

## What the user should test tomorrow
1. **1v1 against a bot:** untick Workspace `TestMode`, add the Workspace string attribute `BotMatch` = `1v1`, and Play. Fight it for a few rounds on Normal. Does it feel fair, too sharp or too dumb? Try `BotDifficulty` = `Easy` and `Hard`.
2. **2v2 and 3v3:** `BotMatch` = `2v2` or `3v3` gives you bot teammates. Watch them spread out, focus targets, throw Mollies at where you hid and heal.
3. **Animations on bots** (lane D's poses): running, sliding, reloading, throwing, the flinch when hit.
4. **Kill feed, top bar and round results** with bot names; a match to 5 and the next match starting.
5. **Solo Studio with no `BotMatch`:** one bot still joins the other side after 3 s (the old test opponent's job).
6. **Lobby → Match with bots,** once lane B's queue teleports: a party with `bots = true` should get bots in the empty slots after about 8 s.
7. **Strafe against a bot** with a rifle or pistol at 20–40 studs: strafing should make it miss more than standing still. Turn on the Workspace attribute `BotDebug` to see what each bot is doing and its hits/shots.
8. Tell me what feels off (aim, Mod spam, movement) and I'll tune `Config/Bots.luau`.
9. After testing, turn `TestMode` back on and clear `BotMatch` if you want the test range again.
