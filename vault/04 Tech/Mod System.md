# Mod System: architecture (Stage 0 proposal)

> **Status:** proposal, 2026-10-26, waiting for approval. Design source of truth: [Mods](../01%20Design/Mods.md). Code rules: [Architecture](Architecture.md).
> Scope: the framework plus **L1 of all 9 Mods**. Paths A/B and Glitch plug in later without a rewrite (see "Levels and paths").

## What exists today (surveyed 2026-10-26)
- **Server Authority is on.** Movement runs in `shared/Simulation/Movement.luau` (`BindToSimulation`, 60 Hz, both sides), reads `PlayContext` InputActions and moves the character only through `Humanoid.WalkSpeed` × the player attributes `MoveMult` / `AdsMult`. State lives in character attributes (`MoveState`, `SlideStart`, …). Poses are a second simulation module.
- **Inputs:** `Config/Input` → `InputContextService` builds one `PlayContext` per player (under the Player, so the server receives it). `InputController` has `onPressed` / `isDown` / `bindTouchButtons`.
- **Weapons:** `WeaponController` (client) / `WeaponService` (server). Fire rate goes through `Util/FireRate.interval` on both sides. Any queryable part that isn't a combatant blocks shots (`ThinWall` tag aside). Damage goes through a local `applyDamage` (sets `LastAttacker`), with `onDamage` / `onShot` hooks. **No heal API, no holster API, no non-gun held item.**
- **Remotes:** `shared/Net.luau` name lists. The token-bucket rate limiter and the `finiteVector` checks are local to `WeaponService` (to be pulled into a shared helper).
- **Missing:** no teams (Teams service empty), no rounds, no Mod code. `Assets.Abilities` exists in Studio and is empty.
- **Key clashes:** C was crouch. **Decided 2026-10-26: Mod 3 is T** (PC slots **Q / E / T**; crouch stays C / Left Ctrl). Gamepad D-pad up is the weapon picker, so the picker moves to **D-pad left**.

## The core split: predicted vs requested
Server Authority only predicts what happens inside the simulation, and the only client data the simulation trusts is InputActions. So Mods split in two:

| Kind | Mods | How it runs |
|---|---|---|
| **Predicted (in the simulation)** | Blink, Rollback, the Launch Pad *launch*, Lag Field *slow* | `shared/Simulation/Abilities.luau`, bound with `BindToSimulation` just before Movement. Reads the `Mod1/2/3` InputActions, writes cast state and cooldowns as character attributes. Client predicts, server's run is the truth, no remote involved. |
| **Requested (remote + server)** | Packet, Lag Field (throw), Launch Pad (place), Firewall, Ping, Patch Up, Overclock | Client sends `ModUse`. `ModService` validates and applies. The client plays predicted cosmetics only (throw anim, sound), never the result. |

Movement effects that the server decides (the Lag Field slow) reach the simulation as a server-written **player attribute** (`ModSpeedMult`), the same way `MoveMult` already works. Overclock reaches `FireRate.interval` as `FireRateMult` (server-written, read on both sides).

## Files
```
src/shared/
  Config/Mods.luau            all Mod data (below)
  Config/Input.luau           + Mod1/Mod2/Mod3 (Q/E/T · LB/RB/DPadUp · touch), picker → DPadLeft
  Mods/
    init.luau                 registry: id → Mod module, stats(id, level) resolver
    Types.luau                ModDef, ModLevel, ModStats, request/fx payload types
    Teams.luau                isAlly(a, b) from a "TeamId" attribute (players + dummies)
    Blocks/                   shared building blocks (pure, used by server and client)
      Dash.luau  Projectile.luau  Placeable.luau  Zone.luau
      SelfBuff.luau  Reveal.luau  Rewind.luau  Target.luau
    Blink.luau LaunchPad.luau Packet.luau Firewall.luau LagField.luau
    Ping.luau PatchUp.luau Overclock.luau Rollback.luau
  Simulation/Abilities.luau   predicted part (dash, launch, rewind history, slow)
  Util/RateLimit.luau         token bucket pulled out of WeaponService (shared by both services)
  Util/Validate.luau          finite numbers / vectors / enums / string lengths
src/server/Services/
  ModService.luau             loadouts, levels, cooldowns, charges, validation, effects, fx broadcast
  ModEntities.luau            server-owned world objects: projectiles, pads, walls, zones (with HP, lifetime)
  DevModService.luau          dev test panel backend (gated)
  WeaponService.luau          + holster check (no firing while a Mod is held), FireRateMult, damage to Mod objects (wall HP), heal API, ammo snapshots for Rollback
src/client/Controllers/
  ModController.luau          input, held state machine, previews, prediction, talks to WeaponController
  ModHudController.luau       3 slots, cooldown sweeps, charges, held hint, ready pulse, mobile arc + context button
  ModFxController.luau        plays Mod VFX/sound from ModFx events and simulation attributes, per-viewer colour
  DevModController.luau       dev test panel UI
  WeaponController.luau       + setHolstered(reason, on) / isHolstered()
  ViewmodelController.luau    + holdItem(model, pose) / releaseItem() for the heal device / grenade / pad in hand
src/client/Util/
  VfxPool.luau                generic pool (parts, beams, emitters, highlights): acquire/release, prewarm
  TeamColor.luau              cyan #00E5FF (you + team) / orange-red #FF5A36 (enemy) / magenta reserved
```

## Config/Mods.luau shape
```lua
Packet = {
  id = "Packet", name = "Packet", role = "Damage",
  activation = "HeldThrow",            -- Instant | HeldThrow | HeldPlace | HeldTarget
  icon = "rbxassetid://…",
  levels = {
    L1 = { cooldown = 14, charges = 1, fuse = 1.2, bounces = 1,
           damageCenter = 50, damageEdge = 20, radius = 8,
           throwSpeed = 80, lobSpeed = 40 },
    -- A2 = { charges = 2 },              filled in phase 2: each level only lists what changes
    -- A3 = { radius = 11, burn = { dps = 10, duration = 3 } },
    -- G2 = { behaviour = "ForkBomb", … }
  },
}
```
- `Mods.stats(id, level)` resolves **L1 → A2 → A3** (each level overrides the one before), cached, frozen. Code only ever reads resolved stats, never `levels.L1` directly, so paths need no code changes beyond new behaviour.
- **Behaviour switches** (`behaviour = "ForkBomb"`, `onDashEnd = "Reload"`) are how glitches change what a Mod does: each Mod module dispatches on them. L1 has none.
- A loadout entry is `{ id, level = "L1" | "A2" | … }` per slot.

## Each Mod module
A table with optional hooks; the building blocks do the work:
```lua
{
  activation = "HeldThrow",
  validate = function(ctx, req) end,   -- server: Mod-specific checks (range, placement, target)
  apply = function(ctx, req) end,      -- server: make the effect (via ModEntities / blocks)
  preview = function(ctx) end,         -- client: arc / hologram / target highlight while held
  predict = function(ctx) end,         -- client: instant cosmetic (anim, sound) on use
  fx = function(ctx, event) end,       -- client: world VFX for everyone, coloured per viewer
}
```

## ModService (server decides)
- Per player: 3 slots `{ id, level }`, per-slot `readyAt` and `charges` (server clock), `held` slot, alive flag.
- Replicates loadout and cooldowns as **player attributes** (`Mod1Id`, `Mod1Level`, `Mod1ReadyAt`, `Mod1Charges`, `ModHeld`), so the HUD and the simulation read the same values. The simulation-owned cooldowns (Blink, Rollback) are character attributes written only inside the simulation.
- **Remotes** (all in `Net`): `ModHold(slot | 0)`: equip/cancel, so others see it and the server blocks firing · `ModUse(slot, mode, aim)`: mode = Primary/Alt, aim = camera origin + direction (checked against `Player:GetCameraState()` within a tolerance; the server recomputes the throw/placement from its own head position) · `ModFx` (server → clients): cast/impact/expire events with server time · `ModReveal` (server → the caster's team only, so enemy positions never leak to everyone) · `DevMod` (gated).
- **Every request:** rate limit (token bucket per remote) → types, finite, enums, lengths → alive, in a round (or test mode), owns the Mod in that slot, held when the type needs it, off cooldown/has a charge, not Packet-Lossed (later) → Mod `validate` (range, line of sight from the server head, placement on walkable ground and not inside geometry or players, target is a live ally within 30 studs with LOS and near the server's crosshair ray) → start cooldown → `apply` → `ModFx`.
- Cooldowns start on use, not on equip. Cancelling costs nothing.
- Clean-up on death, respawn, round end and `PlayerRemoving`: entities owned by the player expire, buffs end, attributes reset.

## The 9 Mods at L1: how each is built
| Mod | Block | Authority | Notes |
|---|---|---|---|
| **Blink** | Dash | Simulation | Flat `MoveDirection` (look direction if still), `Spherecast` 12 studs to stop short of walls, ~0.15 s of `AssemblyLinearVelocity`, keeps vertical speed. Client camera lunge + FOV kick. |
| **Launch Pad** | Placeable + launch in the simulation | Place: server. Launch: simulation | Server places an anchored pad in `workspace.ModObjects` (`Owner`, `TeamId`, `ExpiresAt`, 50 HP). Each simulation step checks the feet with `GetPartBoundsInBox` (not `Touched`), then `Freefall` + ~99 studs/s up + forward, carried like `SlideJumpSpeed`. Works for teammates for free. |
| **Packet** | Projectile | Server | Deterministic fixed-step arc with raycasts (one bounce, 1.2 s fuse), computed by the server from its own head position. Clients replay the same maths from the `ModFx` spawn event, so visuals match. Explosion: 50 → 20 over 8 studs, LOS from the blast to each body, no self or team damage at L1. Red danger ring for enemies. |
| **Firewall** | Placeable | Server | An 8×6 queryable part in `ModObjects` blocks shots both ways through the existing wall check. WeaponService routes hits on it to its 150 HP. 6 s life. |
| **Lag Field** | Projectile → Zone | Server (slow via attribute) | Orb lands and makes a 10-stud zone for 4 s. The server checks who's inside on Heartbeat and sets `ModSpeedMult = 0.6` on enemies; the simulation multiplies it in. |
| **Ping** | Reveal | Server | 30 studs, 2 s. Server picks the enemies and sends `ModReveal` only to the caster's team. The client adds a pooled `Highlight` (AlwaysOnTop). Everyone sees and hears the pulse ring. |
| **Patch Up** | Target + SelfBuff | Server | LMB: ally under the crosshair (30 studs, LOS), RMB: self, and in 1v1 LMB falls back to self. 40 HP over 2 s as server ticks. You go back to the gun right after the cast, so you can move and shoot during the heal. Beam to the target, +HP numbers. |
| **Overclock** | SelfBuff | Server | `FireRateMult = 1.25` for 5 s. Both sides read it in `FireRate.interval`. Gun glow and hum. |
| **Rollback** | Rewind | Simulation (position), server (ammo) | Ring buffer of root CFrames keyed by simulation `time()`, trimmed on `RunService.Rollback`. `PivotTo` the 3 s-old sample and zero the velocity inside the simulation. WeaponService keeps 3 s of ammo snapshots and restores them. Ghost trail of the last 3 s, VHS screen effect. |

## Client: ModController
- **Input:** `Mod1/2/3` actions (Q/E/T, LB/RB/D-pad up, touch). While a Mod is held, the existing **Fire** and **Aim** actions become Primary/Alt use (LMB/RMB, triggers, touch Fire + context button), and the weapon reads `WeaponController.isHolstered()` and ignores them.
- **State machine:** `Idle → Equipping (0.25 s raise) → Held → Using → Cooldown`. Cancel with the same key, a weapon key (1/2/3/scroll) or another Mod key (switches to it). Instant Mods go straight to Using.
- **Previews (pooled, rebuilt never):** throw arc (beam segments from `Blocks/Projectile`, landing ring), placement hologram (green/red from the same `Blocks/Placeable.check` the server runs), heal-target outline.
- **Quick-cast** setting (off by default on PC). Stored as a player setting later; a toggle in the dev panel for now.
- **Feel:** gun lowers with a spring, held item raises in the viewmodel, wind-up/release, place push, Blink lunge, Rollback rewind effect (placeholders in Stage 1, polish in Stage 4).

## Teams (minimal, until MatchService exists)
A `TeamId` attribute on each Player and dummy. `Teams.isAlly(a, b)` everywhere (damage, heals, reveal, colours). Solo Studio: you are team 1. The dev panel can spawn a **dummy teammate** (team 1) and a **dummy enemy** (team 2), both prepared like players, so heals, damage and slows go through the same paths. MatchService takes over `TeamId` later.

## Dev test panel
Opens on **F8** (Studio/owner only; no gamepad binding). Server-gated in `DevModService`: allowed only when `RunService:IsStudio()` or the player owns the game (group 11116787 rank 255). Every request is rate-limited and validated. Actions: set any Mod/level in any slot, reset cooldowns, toggle no-cooldown, toggle quick-cast, spawn/clear a dummy enemy and a dummy teammate.

## Art: the Mod look (decided 2026-10-26)
**Valorant-style split:** the guns stay tactical and realistic, but **abilities are stylized and colourful**: cleaner, chunkier, slightly cartoony shapes with bold readable silhouettes, big bright energy parts and generous VFX. Think Valorant ability props (Sage orb, Raze grenade, Killjoy gadgets): a matte charcoal tactical shell, with large emissive/neon areas in the **team colour** (recoloured per viewer: cyan `#00E5FF` ally, orange-red `#FF5A36` enemy; magenta reserved for glitches), soft gradients, no grime. The VFX carry most of the personality: stylized shapes (rings, domes, chevrons, hex patterns), not realistic smoke. Cartoony gun skins come later and should sit next to these comfortably.

## Art: where the models live
Rojo can't live-sync MeshParts (it leaves `MeshId` empty), even on 7.7.1. So Mod models follow the gun pipeline: a Studio-owned **`ReplicatedStorage.Abilities`** folder saved with the place, with `.rbxm` backups in `art-source/abilities/Studio/<Name>.rbxm` (not `assets/Abilities/`). Sources: `art-source/abilities/<Mod>/`.

## How the work is split (delegation)
One **code session** owns `src/` and Studio (Stages 1 → 2 → VFX hookup → 4 code). Art runs in parallel sessions that never touch `src/` or Studio:
| Session | Owns | Starts |
|---|---|---|
| Code: framework + 9 Mods | `src/`, `vault/01 Design/Mods.md`, `Gunplay.md`, this note, Studio MCP | After approval |
| Art: Mod models in Blender | `art-source/abilities/`, `tools/blender/build_mod_*.py`, renders in `vault/02 Art/References/mods/`, Blender MCP | After approval (renders first, no import yet) |
| Art: 9 Mod icons | `tools/icons/`, `art-source/abilities/Icons/` | After approval |
| Audio shortlist | `vault/02 Art/Mod Audio.md` (search terms, candidate ids, jsfxr presets) | After approval |
| Later: import + VFX meshes, animations, juice, mobile pass, security/perf review | (scheduled by the handler as stages finish) | |
Each session commits only its own paths and never pushes; the handler checks the results and pushes.
