# Spectate and Final-Kill Replay: Prioritized Fix Plan

Owner's ask (2026-11-16): spectating and the final-kill replay are laggy and don't work well; they don't show the player's skin, animations, hitmarkers; weird animations and jittery aim; "should show everything perfect and amazing". Source: a 74-agent study (7 readers, a skeptic per finding: 61 confirmed, 5 refuted, 2026-11-16); per-area findings in the study transcript. RIVALS references: [Rivals Reference](../03%20Research/Rivals%20Reference/00%20Rivals%20Reference.md).

## How the owner's complaints map to causes

| Complaint | Main causes (finding ids) | Workstream |
|---|---|---|
| Jittery or laggy aim | 1. Pitch reaches the spectator at most 10 times a second and only after moving 0.03 rad. 2. Yaw comes from the body's facing, on a different delay. 3. The camera sits on the animated Head. 4. Yaw and pitch use different filters. 5. Bots publish their spring look, not where the gun points. (`pitch-10hz-deadband`, `yaw-pos-pitch-shot-desync`, `look-stream-missing`, `eye-from-lagged-animated-head`, `camera-on-animated-head`, `bot-look-not-gun-look`, `no-shot-aim-correction`) | B (stopgaps in A) |
| Player's skin not shown | The replay's viewmodel subject is a body copy, so `GetPlayerFromCharacter` returns nil and the gun is built stock. Surface skins are lost too. (`replay-gun-always-stock`) | A |
| Animations wrong | Draw replays at about 2x speed; melee swing chain lost; wrong reload clip; no held-Mod item; the replay viewmodel is frozen; the shot kick is only approximated; ADS zoom differs; landing feel is weak; no inspect. | A, D, E |
| No hitmarkers | `HitConfirm` goes only to the attacker. The replay records no hits and hides the CombatHud. The kill pop only fires for your own kills. | C, E |
| Laggy replay | Slow motion only slows the bodies. The fall plays at 1x and spikes on its clone. 30 Hz samples are joined by straight lines. The gun is built on the first frame. | F, H |

## Workstream order

1. **Phase 0: measure.** One short playtest, no code change.
2. **A: quick wins.** All S effort, client-heavy, biggest visible gain per hour.
3. **B: smooth aim pipeline.** The Look stream. This is the real fix for jitter and the base for the replay.
4. **C: spectator HUD and hit feedback relay.**
5. **D: spectated viewmodel fidelity**, the deeper items.
6. **E: replay recording and playback rebuild.** Needs B and C.
7. **F: replay time and bodies.**
8. **G: camera feel under the override.**
9. **H: performance tidy-ups**, plus the parked investigation.

Every workstream touching remotes gets a `roblox-secure-remotes` / security review. All new numbers go in `src/shared/Config`. Everything is `--!strict`.

---

## Phase 0: Measure first (no code)

In a Studio playtest (one client plus BotMatch bots), log the following on the spectator. Drive it through remotes and attributes, never by requiring server modules.
- The interval between root CFrame changes of the watched body.
- When `AimPitch` changes arrive compared with root yaw changes.
- One MicroProfiler capture while spectating and one during the replay.

This sets the interpolation delay for B and checks that the lag is not frame time. Also log in one frame whether the `BodySkinController` PreRender connection runs before or after the `GGCamera` bind.

---

## A: Quick wins (one coherent change, about S x 12)

**Goal:** remove the most visible wrongness without new architecture.

1. **Replay skin owner.** `ViewmodelController.setSubject(body: Model?, owner: Player?)`.
   - Store `subjectOwner = owner or GetPlayerFromCharacter(body)`.
   - Use it in `buildGun` (~:861), `onSkinPick` (~:2776) and the observe in `setSubject` (~:2804). Update the comment at :859-860.
   - In `ReplayController`, take the owner when the copy is made (~:448), because `GetPlayerFromCharacter` fails on an old character after a respawn. Resolve `killers[victim]`: if it is a Player use it; if it is a Model use `GetPlayerFromCharacter`. Pass it at :615.
   - Bots stay stock.
2. **Aim send interim.** In `WeaponController` ~1182-1195:
   - Send rate 20-30 Hz, deadband about 0.005 rad.
   - A settle packet about 0.1 s after the aim stops changing, plus a keepalive every 0.5 s (also fixes a stuck `Aiming`/`MoveState` after a dropped packet).
   - New config entries `SPECTATE.aimSendHz / aimDeadband / aimSettle / aimKeepalive`.
   - Raise `Combat.luau:135` `Aim = {20,30}` to `{40,60}`.
   - In `WeaponService.onAim`, also reject ±inf.
3. **Bot gun look.** `Brain.publishAim` publishes `gy/gp = yaw/pitch + aimError + recoil`. Leave `missBy` out.
   - Write `AimPitch` and a new `AimYaw`.
   - Move `AIM_SEND_EVERY/DELTA` into Config (1/30 s, 0.002 rad).
   - `SpectateController.watchStep` reads `AimYaw` when present, else root yaw.
4. **Eye from root, not Head.** New shared pure helper `src/shared/CameraDrop.luau`: the crouch/slide spring from `Movement.CAMERA_STIFFNESS / DAMPING_RATIO / CROUCH_CAMERA_DROP / SLIDE_CAMERA_DROP`, driven by `MoveState`.
   - `MovementController` uses it too.
   - In `SpectateController.watchStep` (:349-366): eye = root position + `EYE_HEIGHT` − drop. Delete the `headRate` lerp.
   - One shared ease rate for yaw and pitch (`SPECTATE.aimRate` about 18).
5. **Swing chain.** `SpectateController` watches `SwingAt`, using the same pattern as `ReloadAt`, with a baseline set in `watch()`.
   - Call `swing(if SwingHeavy then "HeavyStab" else "Slash"..clamp(SwingStep,1,3))`.
   - `onSpectatedShot` falls back to `swing("Slash1")` only for holders with no `SwingAt`.
6. **Draw.** `ViewmodelController.equip(weapon, duration, opts {instant})`. Instant returns before the Draw clip, track or bump and leaves the guns at idle.
   - Use it for the first equip after `watch()`, for the replay's equips, and for the `onSkinPick` re-equip.
   - Real spectated swaps use `config.drawTime or equipTime` and play the returned beats through GunSounds, as `WeaponController` :478-488 does.
7. **Kick scale.** Both hooks multiply by `config.viewmodelKick or 1`.
8. **ADS.** In both controllers:
   - `setZoom(ViewmodelController.adsZoom())`.
   - `adsAlpha >= VM.SCOPE_AT`.
   - `HudController.setAim(adsBlend())`.
   - aimIn/aimOut sounds when `Aiming` changes.
   - Reset to 0 on stop.
9. **Grounded for a subject.** Use `Humanoid.FloorMaterial ~= Air`, the same check as `Poses.luau:735`. Keep `MoveState` for Sprint, Slide and Crouch.
10. **Kill pop for the watched player.** New tiny `Util/Watched` (set/get, pushed by `SpectateController`).
    - `KillFeedController.onKilled` (:317) and `KillFeed` (:297) treat "the watched holder is the killer" as mine, with a per-target ladder counter.
    - Kill marker, not the pop: C covers it.
11. **Mod row stopgap.** `BottomHud.setModsVisible`: `r.mods.Visible = any and not spectating`, plus the legacy bar in `ModHudController` :802.
12. **Crosshair while spectating.** Per-target `heat/lastShotAt` with `Accuracy.cool(config, heat, since)`.
    - Each frame: `setSpread(Accuracy.cone(...) + pelletSpread*0.6)`, `setCrosshairState(slide, air, ads)`.
    - On a shot: `crosshairShot(max(recoil.up, SHOT_FEEL.upFloor))`, plus `scopeShot()` when scoped.
    - Reset on target or gun change.

**Risks:** the instant equip must not leave the gun stuck mid-draw. The `CameraDrop` refactor touches the player's own camera, so retest crouch and slide on your own character.

**Verify:** die in a BotMatch 2v2 and watch the bot teammate, then the killer at RoundEnd. Check:
- the crosshair stays on target with no stair-steps;
- no bob from the walk cycle;
- the knife chain shows Slash1/2/3 and heavy;
- no redraw when you switch watch target;
- ADS zoom and vignette;
- kill pop and tone when the bot kills;
- your own Mod row is hidden.

Win a match on a final kill and check that the replay gun shows your Locker skin. Also check that the `SkinPreview.allowed()` gate is on in that place.

---

## B: Smooth aim pipeline, the Look stream (L)

**Goal:** yaw, pitch and eye on one timestamped timeline, interpolated. It replaces the exponential chase and is the source of truth for the replay.

**Client send (`WeaponController`, or a new `LookController`):**
- A render bind after GGCamera (Camera+4) samples the aim look from a new `CameraController.aimLook()`. That is the camera minus shake, view punch and roll, with recoil included.
- Sends unreliable `Look` at `LOOK_RATE` 30 Hz during Live/SuddenDeath.
- Packet: f64 `GetServerTimeNow`, yaw u16, pitch i16, eye offset from root 3×i16 at 1/256 stud, flags u8 (aiming, MoveState). About 19 B.
- Keep the `Aim` remote for `Aiming`/`MoveState`/`AimPitch`, which Poses, Mods and Flash still use.

**Server (`WeaponService`, or a small `LookService`):**
- Validation:
  - buffer type and exact length;
  - finite values;
  - `t` within `[now-1, now+0.25]`;
  - pitch clamped ±1.5 and yaw wrapped;
  - eye offset ≤ 4 studs;
  - `RateLimit {40,60}`.
- Store in a per-fighter ring (about 6 s).
- Relay at once, unreliable, only to `SpectateService.watchersOf(fighter)`.
  - Add a reverse index target → spectators, kept up in `onSpectate`, `clearFocus` and PlayerRemoving.
- Bots: each Heartbeat, Brain writes the gun look, root eye and server time into the same ring and relay.

**ShotFx:** add the server fire time `t` and the validated unit `aim` (`p.direction`), plus the `flags` from D. It stays cosmetic. `BotGun` and `Dummies` send matching args.

**Spectator (`SpectateController`):**
- A sample buffer, rendered at `GetServerTimeNow() - INTERP_DELAY`. Start at about 0.1 s and size it from the Phase 0 numbers.
- Hermite / Catmull-Rom on unwrapped yaw, pitch and eye.
- Extrapolate at most 50 ms, then hold. Snap when the eye jumps more than 8 studs.
- Spectated shots are queued and played when `renderTime >= shot.t`.
- Fallback with no samples: the A path.
- An optional aim-key correction toward `aim`: a decaying offset over about 0.2 s, never a hard set.

**Config:** new `src/shared/Config/Spectate.luau` (or `Juice.SPECTATE`) with `LOOK_RATE`, `INTERP_DELAY`, `EXTRAP_MAX`, `SNAP_DIST`, `EYE_HEIGHT`, `AIM_KEY_DECAY`.

**Budget:** about 1 KB/s up per client, about 1 KB/s down per watched fighter per spectator, worst case about 8 KB/s server out in 4v4.

**Risks:** clock skew in `GetServerTimeNow`; the delay feels late if set too high.

**Verify:** watch a bot. Log render time minus newest sample time and the buffer depth. Flick a bot diagonally and check the path is not L-shaped. Tracers should leave the crosshair. Watching a player needs Studio's two-client local server test.

---

## C: Spectator HUD and hit feedback relay (M)

**Server:**
- Extend `Damage.onHit`/`tellHit` (Damage.luau:48-57) with an info table `{zone, at, blocked, source}`. Pass it from `apply` and from `damageBy`, so bot attackers are covered.
- `SpectateService` subscribes and sends a new reliable server-to-client `SpectateFeed` to the watchers of the attacker:
  - `kind="hit"`: `{target, damage, zone, killed, position, blocked, victim}`.
- Also to the watchers of the victim:
  - `kind="hurt"`: `{target, from = attacker root, amount}`, only when dealt > 0. Bot victims are included.
- `Hits.luau:326` (Mod objects) gets its own relay call.
- No client input means no new trust surface. The cost is bounded by the validated fire rate times 1-3 spectators.

**Client:**
- Move the presentation half of `WeaponController.onHitConfirm` (:1335-1377) into a shared presenter, e.g. `Util/HitFeedback.present(confirm, opts)`. Your own hits keep the predicted-hit dedupe; relayed hits skip it.
- `SpectateController` handles `SpectateFeed` only when `payload.target == current holder`, and type-checks every field.
- Hurt: `HudController.damageFrom(from)`. `flinch(from, amount, subjectHumanoid)`. Move the hitPulse decay and vignette out of `if humanoid` so they work while you are dead.

**Health and shield:**
- `HudController.setSubject(body)`, then `subject or player.Character` at :533. Reset `shownHealth`/`chipFrac` when the subject changes.
- `BottomHud` keeps health visible while spectating.

**Ammo and loadout:**
- `WeaponService` sets the player attributes `Ammo`, `MagSize`, `EquippedSlot` and the loadout ids after the decrement, the reload and the equip. `BotGun` sets the same on bot models.
- Do not count `ShotFx` (unreliable).
- Feed `BottomHud.setLoadout/setWeapon/setAmmo` from the subject.

**Mods:**
- `ModHudController` gets a subject. Ids and levels come from public `Mod<n>Id/Level` and `ModHeld`.
- Charges, rechargeAt and activeUntil come through `SpectateFeed kind="mods"` from `ModService.publishSlot`, with a full snapshot when a watcher registers. Check the bot `ModHeld` path (BotMods.luau:363).

**Optional:** a `Spectators` count attribute set by `SpectateService`, shown as an eye and the number (gauntlet-ui-style).

**Verify:** watch the bot teammate and check:
- hitmarkers, damage numbers and head sound on its hits;
- the kill marker on a kill;
- the damage arc when it is shot;
- its HP and shield;
- its ammo counting down and refilling on reload;
- its Mod slots.

---

## D: Spectated viewmodel fidelity, deeper (M)

Build one shared `Util/SubjectView` that turns a holder and body into viewmodel calls. `SpectateController` and `ReplayController` both use it.

1. **Reloads.**
   - Server `onReload` sets `ReloadKind` (Tactical/Empty/Shell) and `ReloadShells` before `ReloadAt`. On a shell stop it sets `ReloadStopAt`. These are cleared on a swap.
   - Move WeaponController's shell schedule (:342-409) into `Util/ShellReloadPlayer` and use it from both paths.
   - Empty calls `reload(d, true)`.
   - Joining mid-reload plays the remaining part.
   - Beats go to GunSounds.
2. **Shot flags.** The ShotFx `flags` int (bit0 alt fire, bit1 last round). `EffectsController.onShotFx` validates 0..3 and forwards. Apply ×1.6 for alt and pass `empty` (lock open).
   - The lean comes from the subject's yaw velocity.
   - For the owner's replay, `ShotLog` records alt, empty and lean.
3. **Held Mods.**
   - Split the view-only half of `ModController` into `Util/ModViewmodel(holder, body)`:
     - `holdItem` / `itemParts` / pin pull at `MOLLY_PIN_AT`, or `setFreeHand("FirewallReady")` for HeldSteer;
     - release on a new `ModUseAt`, keyed by `ModUseKind`;
     - Dash, Updraft, Recall and Stim gestures from body marks, with `last*` seeded at watch start.
   - The bow charge has no replicated value; show only the raised pose and the release.
4. **Inspect.**
   - New reliable `Inspect` remote, no args. Rate limit about 3-4/s with a small burst, because spamming must restart it.
   - The server requires a live, equipped holder that is not reloading, then sets `InspectAt`.
   - The subject view plays `inspect()` plus the sounds and knife flips.

**Verify:**
- a bot with Bucky/Marshal does a shell reload;
- a pistol empties and locks open;
- a bot throws a Molly and the pin pull and throw show;
- Firewall shows the hand flame;
- for inspect, two clients are needed (bots don't inspect).

---

## E: Replay recording and playback rebuild (M-L, after B and C)

1. **Killer view track from the server.**
   - `MatchService.playReplay` (~:567) adds a 4th and 5th `Replay` argument:
     - the killer's Look samples over `[at - before, at + after]` (about 100 samples, about 2 KB);
     - the killer's hits from a server hit ring fed by the C `onHit` info, capped at `REPLAY.hitsCap` 64.
   - Store the attacker Instance on `lastDown` when the kill happens; LastAttacker does not cover bots.
   - The client validates counts, types and finite values, shifts times by the existing kill offset (:425-430) and maps victims to their copies through `actorOf`.
   - If the payload is missing, fall back to the local recording.
2. **`killerView`.**
   - Camera at the track's eye, with Hermite on the track in recorded time `t`.
   - Delete the real-dt filters (25/20/16).
   - Shots play in the killer's time base.
   - Each hit calls the shared `HitFeedback.present`, and the kill marker plays on `killed`.
3. **Replay HUD.**
   - Add `CombatHud` to `keep` (:510) and call `setSpectating(true)`. Add a replay-driving override so your dead self's state does not leak into the HUD.
   - Drive scope, crosshair, aim vignette and bloom from the track.
   - Clear all of it in `cleanup`.
4. **Viewmodel motion.**
   - Record per slot: `moveState`, `dashing`.
   - Record as timestamped events: reload (with kind), modHeld changes, swing (step, heavy).
   - New `ViewmodelController.setSubjectMotion(velocity?, state?)`, used at :2438-2447. Velocity is the recorded root delta over time, smoothed.
   - Play the events through `SubjectView`.
   - Clear it in `setSubject` and `resetView`.
5. **Kill moment.** A local `killAt` = the killer's last shot near the victim in `[downAt-0.6, downAt]`, plus `REPLAY.killLead` 0.03. Otherwise use `serverKill`. Do not mutate `track.downAt`.
6. **Body sampling.**
   - `REPLAY.rate` 60.
   - `bracket()` returns 4 slots; Catmull-Rom on positions, slerp kept for rotation.
   - Stamp samples from one clock: `os.clock` plus a single server offset.
   - Rebuild `track.parts` when the body's children change.
7. **World gun.**
   - Record a per-fighter hidden flag.
   - When the recorded weapon id changes, rebuild the copy's `WorldWeapon`. Do it through a shared `src/shared/WorldGun.luau` moved out of `Weapon/WorldModel.luau`: grip constants, template plus SkinPreview geometry.

**Spec change (owner decision):** `Match Structure Revamp.md:67` says to hide the HUD during playback. Update it, and the matching Home Locked-decisions row, to "show the killer's crosshair, hits and scope".

**Verify:** win a match with a final kill, once by you and once by a bot. Check:
- aim is smooth in slow motion;
- the kill tracer leaves the crosshair;
- hitmarkers and numbers appear on the victim copy;
- the gun bobs while running;
- the victim falls on the shot.

---

## F: Replay time and bodies (M)

1. **`Util/EffectsClock`** (set/get/now), a runtime source that is not Studio-only. Studio's `VfxTimeScale` is one input. Point these at it:
   - `ShotFxKit.setTimeScale`;
   - `ReworkVfx` (new setter that banks `now()`);
   - the particle `TimeScale` loop in `EffectsController`;
   - `ViewmodelController` dt (:1910, :2409);
   - HitFeedback, DamageIndicator and ScopeOverlay.
2. **Eased slow motion.** `recordedAt` gets an eased speed ramp of about 0.15 s, integrated so time stays continuous. Mirror it in `MatchState.replayPlayback()`. `ReplayController` sets the clock each frame and resets it to 1 in `cleanup`, on skip and on error. Gun sound `PlaybackSpeed` goes to about 0.5-0.6 in the slow part.
3. **Fall.** `DeathFxController.playFall(body, parent, opts {timeScale, inPlace, awayFrom})`:
   - animate `actor.copy` in place (no second clone);
   - preload Death before `startAt`;
   - `AdjustSpeed(scale)` and divide the waits and tween by the scale;
   - tip away from the killer's root.
   - Raise `REPLAY.after` from 0.3 to 0.5-0.6.
4. **Skinning after pose.** `BodySkinController.skinModel(copy)` called right after `pose()`. Optional: bind the skin step at `RenderPriority.Last`.
5. **Copy limbs falling.** Parent the ReplayActors folder before the wait, with the copies hidden through LTM.

**Verify:** at the slow-motion kill, the tracer, flash, impact and fall all run at the slow speed and there is no step into slow motion.

---

## G: Camera feel under the override (M)

- `CameraController.setOverride(fn, {firstPerson=true})`:
  - shake, view punch and recoil applied as absolute offsets on the freshly placed CFrame, not frame-to-frame deltas;
  - move FOV, punchFov and roll (slide tilt, rollKick) allowed;
  - offsets reset when the override is set.
- Fix the stale comment at :99-101. `deathStep` keeps `firstPerson` off.
- Move `WeaponController` :738-753 into `ShotFeel.apply(config, ads, alt)` and call it from the spectate and replay shot hooks.
- Feed `setMoveFov`/`setRoll` from `MoveState` through a shared helper moved out of `MovementController` :116-127.
- Do not add extra kick if the Look stream already carries the recoil climb.

**Verify:** watch a sprinting, sliding bot and check FOV and tilt. A nearby explosion should wobble the view, not buzz it.

---

## H: Performance tidy-ups (S)

- **`BodySkinController.step`:** read `hide` first and skip `skinLimb` while hidden. On becoming visible, skin before writing LTM.
- **LTM loops** (Replay :700-703 and :629-631, Spectate :371-373): write only if `~= 1`.
- **Replay pre-warm:**
  - spread the body copies over Heartbeats during `R.delay`, killer and victim first;
  - gather the hide lists in that window;
  - `setSubject` and pre-equip the first window weapon while hidden, removing the `unequip` at :486.
- **Recorder:** cache root, weapon and owner per track; keep a head index for shots. Low priority.

**Parked investigation (L, needs measuring):** `pose-tree-streamed-as-track-state`. Remote bodies may receive the owner's per-tick `AdjustWeight`/`AdjustSpeed`/`TimePosition` changes bunched and late.
- Run a two-client test comparing `WeightTarget`/`TimePosition` on the viewer against the owner, with a bot as the control.
- If it confirms: interim, write only on a change of 0.05 or more (or every 0.1 s) with a 0.1-0.15 s fade, and on a speed change of 6% or more; no `TimePosition` writes.
- Full fix later: pose remote characters on each client.
- Log it in Bugs & Ideas.

---

## Decisions taken (2026-11-16, recommended defaults; the owner can change any)
1. The Look stream runs at 30 Hz in every Live / SuddenDeath fight (it also feeds the replay).
2. The replay shows the killer's crosshair, hitmarkers and scope (the owner asked for hitmarkers in the final round); Match Structure Revamp and Home Locked decisions updated.
3. Watching your killer at round end shows their full HUD.
4. Relayed hit sounds play at 0.7x your own volume.
5. Bot fair misses stay out of the shown look (crosshair on target, shots miss).
6. Desktop first; phone spectate HUD later (Bugs & Ideas).
7. Follow the kill: when the watched teammate dies, cut to their killer.
8. Spectated skins follow `SkinPreview.allowed()` as today.

## Decisions for the owner (as proposed by the study)

1. **Look stream rate:** always 30 Hz during Live/SuddenDeath (recommended: simple, feeds the replay, about 1 KB/s) or only while watched (cheaper, but the replay then needs an upload from the killer's client).
2. **Replay HUD:** show the killer's crosshair, hitmarkers and scope. This reverses spec line 67, so the spec and Locked decisions need updating.
3. **Enemy HUD at round end:** when watching your killer, show their full HUD (ammo, Mods)? The relay can follow `SpectateService`'s existing RoundEnd rule.
4. **Relayed hit sounds:** the same volume as your own, or quieter?
5. **Bot fair misses:** recommendation is to keep `missBy` out of the shown look, so the crosshair stays on target while the shots miss.
6. **Phone spectate HUD:** now, or desktop first?
7. **Follow the kill:** when the watched teammate dies, cut straight to their killer (optional, S) instead of waiting 1 s for the next teammate.
8. **Who pays for spectated skins:** live skins only show where `SkinPreview.allowed()` is true (Studio, or `Config.LIVE`). Confirm LIVE before testing skins in live servers.

## Files touched, by workstream

- **A:**
  - `ViewmodelController.luau`, `SpectateController.luau`, `ReplayController.luau`
  - `WeaponController.luau`, `WeaponService.luau`
  - `Bots/Brain.luau`, `Combat.luau`, `Juice.luau`
  - new `shared/CameraDrop.luau`, `MovementController.luau`
  - `KillFeed.luau`, `KillFeedController.luau`, new `Util/Watched.luau`
  - `BottomHud.luau`, `ModHudController.luau`, `HudController.luau`
- **B:** `Net.luau` (`Look`), `WeaponService.luau` or new `LookService.luau`, `SpectateService.luau` (`watchersOf`), `CameraController.luau` (`aimLook`), `BotService.luau`/`Brain.luau`, `BotGun.luau`, `Dummies.luau`, `EffectsController.luau`, new `Config/Spectate.luau`
- **C:** `Weapon/Damage.luau`, `Weapon/Hits.luau`, `SpectateService.luau`, `Net.luau` (`SpectateFeed`), `ModService.luau`, `Util/HitFeedback.luau`, `HudController.luau`, `BottomHud.luau`, `ModHudController.luau`
- **D:** new `Util/SubjectView.luau`, new `Util/ShellReloadPlayer.luau`, new `Util/ModViewmodel.luau`, `ModController.luau`, `Net.luau` (`Inspect`)
- **E:** `MatchService.luau`, `ReplayController.luau`, `ShotLog.luau`, `ViewmodelController.luau`, new `shared/WorldGun.luau`, `Weapon/WorldModel.luau`, `Config/Match.luau` (REPLAY: `rate 60`, `after`, `killLead`, `hitsCap`, `slowRamp`)
- **F:** new `Util/EffectsClock.luau`, `ShotFxKit.luau`, `ReworkVfx.luau`, `DeathFxController.luau`, `BodySkinController.luau`, `MatchState.luau`
- **G:** `CameraController.luau`, new `ShotFeel` helper
- **H:** `BodySkinController.luau`, `ReplayController.luau`, `SpectateController.luau`

All under `C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame\src\`.

---

### Results: A (quick wins), 2026-11-16

**Phase 0 numbers** (Studio, BotMatch 2v2, client at 60 fps, watching the bot teammate Vex; logged by an MCP probe on the client):

| Signal | Before A | After A |
|---|---|---|
| Watched root CFrame | changes every rendered frame (Roblox interpolates it): p50 16.7 ms, max 183 ms (one hitch) | same: p50 16.6 ms, max 148 ms |
| `AimPitch` arrivals | 4 / s: interval p50 117 ms, p90 249 ms, max 416 ms; step p50 0.041 rad (2.3°), p90 0.17 rad | 22 / s: p50 35 ms, p90 68 ms, max 133 ms; step p50 0.002 rad |
| `AimYaw` (new, bots) | none (yaw came from the body) | 22 / s, same timing as pitch |
| Camera vs published aim | n/a | p50 0.9°, p90 1.9°, max 6.8° (the 18/s ease) |
| Eye over root | animated Head | p50 1.50 studs, 1.39-1.77 (landing dip, pitch) |
| Frames in the air (6 s) | MoveState `Air` 19 | `FloorMaterial` Air 31: it is live on a remote bot humanoid, so the viewmodel can use it |

So the root is smooth and per-frame; the aim was the coarse signal (sized for B: a 30 Hz Look stream with about 2 send intervals of playback delay, ~70-100 ms, covers the p90 gap). Render order, one frame: every `BindToRenderStep` (GGCamera at Camera+1) runs **before** `RenderStepped` and `PreRender`, so `BodySkinController`'s PreRender runs after the camera. MicroProfiler captures were not taken (MCP can't drive it).

**What changed** (all 12 items):
1. Replay skin: `ViewmodelController.setSubject(body, owner?)` keeps `subjectOwner` (used by `buildGun`, `onSkinPick`, the skin observe). `ReplayController` stores `owner` on each track when first recorded and passes the killer (Player, or the Player of a killer Model, else the track owner). Verified: the replay's camera gun had `SkinOwnerId` = your UserId (was 0). Bots stay stock.
2. Aim send: `WeaponController` sends at up to `SPECTATE.aimSendHz` 30 when the pitch moves more than `aimDeadband` 0.004 rad, a settle send `aimSettle` 0.1 s after it stops, and a keepalive every `aimKeepalive` 0.5 s. `Combat.RATE.Aim` {40, 60}. `WeaponService.onAim` rejects ±inf and writes `AimPitch` / `Aiming` only on change. Not measured with a second real player (only bots in Studio).
3. Bot gun look: `Brain.publishAim` publishes yaw/pitch + aimError + recoil (no `missBy`) as `AimYaw` / `AimPitch` at `botAimSendHz` 30 / `botAimDeadband` 0.002 rad; `BotService` mirrors `AimYaw` onto the model (it wasn't in `MIRRORED` at first: caught in the test). Spectate uses `AimYaw` when present.
4. Eye from root: new `src/shared/CameraDrop.luau` (spring + landing dip), used by `MovementController` (behaviour kept: own crouch measured settling at -1.40 = `CROUCH_CAMERA_DROP`, damped shape unchanged), `SpectateController` and `ReplayController` (track now records `MoveState`). Eye = root + `eyeHeight` 1.5 - drop, `eyeBack` 0.5 behind along the look (measured from your own camera in Studio). `headRate` / `yawRate` / `pitchRate` replaced by one `aimRate` 18; the replay's hard-coded 25/20/16 are gone.
5. Knife chain: spectate plays `Slash1..3` / `HeavyStab` from `SwingAt` / `SwingStep` / `SwingHeavy` (baseline in `watch()`); players' melee ShotFx no longer swings (no double), bots fall back to `Slash1`. Replay swings `Slash1` until E records the step. Not seen live (bots carry guns, no second player).
6. Draw: `ViewmodelController.equip(weapon, duration, { instant = true })` skips the Draw clip, Equip track, bat/fan draw and bump; used for the first equip after `watch()`, the replay's first gun and the skin re-equip. Spectated swaps use `drawTime or equipTime` and play draw / whoosh / beat foley.
7. Kick: both hooks multiply by `config.viewmodelKick or 1`.
8. ADS: both use `ViewmodelController.adsZoom()`, `>= VM.SCOPE_AT`, `HudController.setAim(adsBlend())`, aimIn / aimOut sounds on a change (not on the first frame); reset on stop and replay cleanup; the death cam clears the vignette.
9. Grounded: a live subject uses its Humanoid `FloorMaterial` (the anchored replay copy keeps MoveState); Slide still counts as not grounded.
10. Kill pop: new `client/Util/Watched`; `KillFeedController` (pop) and `Util/KillFeed` (tone) treat the watched fighter's kills as yours, with a per-fighter ladder reset each round. Verified with two server-fired `Killed` (attacker = watched bot): pop visible both times.
11. Mod row: `BottomHud.setModsVisible` and the legacy bar stay hidden while spectating (screenshot: no Mod cells while watching Vex).
12. Crosshair: per-target heat / last shot, `Accuracy.cone` from their MoveState, speed and time since landing, `setCrosshairState`, `crosshairShot(max(recoil.up, upFloor))`, `scopeShot` when scoped; reset on target or gun change; cleared on stop.

**Checks:** `stylua --check src`, `selene src` (0/0/0), `rojo build`. Studio: three playtests in the match place, no script errors in Output (only the known `203785492` asset warning and the Studio Assistant camera-type notices from MCP calls).

**Left / not verified:** the swing chain, real swap draws, ADS sounds and a real final-kill replay won by you (the replay test was a server-fired `Replay` on a live round) need a human playtest; MicroProfiler captures; the replay camera is still slow-mo-agnostic (F). The Locked-decision tables were not changed (no decision changed).
