# Movement Feel 2026-11-27

Wave 2 of [Launch Hardening 2026-11-27](../05%20Production/Launch%20Hardening%202026-11-27.md). Owner: "continue working on movement and game functionality, as well, just make it more satisfying."

Sources: [Gunplay](Gunplay.md) §1, §5, §6; LihFolk "Camera Shake and Camera FX", "Motion Sensitivity and Camera Comfort", "Juice on a Budget - Mobile and Low-End", "Dash VFX Presentation on an R15 Rig"; the [Code Audit](../04%20Tech/Code%20Audit%202026-11-27.md) client P3 list. All numbers below were measured in Studio bot matches (1v1) unless marked.

**First minutes (new players):** the run is automatic, so almost every jump a new player makes is a running jump, and those had no landing, no air crosshair and no air FOV. They now get a takeoff coil, a landing dip and the air crosshair, in the lobby and in match 1, on phone and PC.

## Audit, ranked (worst first)

| # | What felt flat or bad (measured) | Change | Status |
|---|---|---|---|
| 1 | **A jump out of the run stayed `Sprint` the whole way up and down.** Logged: vy +41.6 → −53.5 with `MoveState = Sprint` throughout. So a running jump had no landing dip, no air FOV kick, no air crosshair, the sprint spread instead of the air spread and no landing spread. The run is automatic, so this was most jumps. | `Air` while airborne. The run's speed carries through the air (it used to be kept only because the state stayed Sprint). `Simulation/Movement`, `Config/Movement AIR_RISE / AIR_GRACE` | Built |
| 2 | Air began about 60 ms after takeoff (Roblox's floor reading lags), and jumping against a crate flickered Air → Sprint → Air for a frame. | Air also from the Humanoid's Jumping / Freefall state while rising past `AIR_RISE` | Built |
| 3 | Walking off a stair step briefly read as Air (the crosshair opened and the landing spread applied on every step). | A drop shorter than `AIR_GRACE` (0.1 s; a run down a 1-stud step is ~0.08 s off the floor) stays on the ground. A jump is still Air at once. | Built |
| 4 | A jump started dead: no coil, only a 1.5° FOV drift. | Takeoff coil: the eye trails the body on the crouch/landing spring (`Juice JUMP.takeoffDip` 0.12 → measured peak 0.07–0.08 studs). LihFolk's 0.35-stud lag is for bigger jumps. | Built |
| 5 | Phone: a light stick push walks slowly, but a jump went to full walk speed (a lurch). | A plain jump's speed is scaled by the stick push too (not a slide-jump's carry). | Built |
| 6 | **Dash Ghost afterimages** (code audit P3): each image cloned the whole visible body (36 parts on a client), one every 0.06 s over the 0.35 s dodge window: ~600 parts/s, ~216 per dash, every dash. `setAlpha` walked `GetDescendants` (447 instances) every frame: 79 µs per ghosted dasher. | Pooled per dasher, moved with `BulkMoveTo`, hidden (not destroyed) when done, freed 3 s after the last image; a global cap of 12 live images; setAlpha targets cached (rebuilt only on DescendantAdded). `Config/Mods DASH_FEEL.ghostTrail` | Built |
| 7 | A late slide-jump barely pays: 28.4 × 0.8 = 22.5 studs/s vs the 22 run (an early one gives ~24). | `SLIDE_JUMP_KEEP` 0.8 → 0.9 (late ≈ 25.6) | **Owner call** (balance), not built |
| 8 | Sprint FOV kick is +4° (LihFolk range +6–10) and eases in at rate 8 (~0.3 s to 90%; LihFolk: player-caused FOV changes under 0.15 s). | Try +6 and rate 14 | Taste, owner call, not built |
| 9 | `ModFeelController.stepCharacters` steps every player (code audit P2). | Measured: 1.7 µs per player per frame on desktop (≈ 50 µs in a 30-player lobby; maybe 4× on a phone). Not worth the stale-replay risk of filtering. | Closed, no change |

Checked and left alone (already at the bar, see [Gunplay](Gunplay.md) §5): hit marker, headshot burst, kill sound and flash, damage numbers, ADS spring, recoil kick split (gun vs camera), viewmodel sway / strafe roll / land kick, slide (FOV punch, roll spring, lunge, streaks), Dash / Updraft camera feel, footsteps (Roblox's own sounds by owner choice, 2026-11-14), jump buffer and coyote time, instant ground acceleration (RIVALS-like).

## Before / after (numbers changed)

| Thing | Before | After |
|---|---|---|
| Running jump `MoveState` | Sprint throughout | Air from the takeoff frame, Sprint on landing |
| Running jump landing dip | none | 0.18–0.19 studs (fall at ~50 studs/s) |
| Running jump FOV | 84 (sprint) | 84 → 85.5 in the air, eases back after landing |
| Slide-jump landing dip | 0.3 studs (already Air) | unchanged |
| Takeoff | nothing | coil, peak 0.07–0.08 studs |
| Air speed out of the run | 22 (by accident of the Sprint state) | 22 (by design) |
| Running-jump spread (rifle) | sprint 1.5° | air 3°, plus landing 1.5° for 0.2 s (Config/Combat, unchanged numbers) |
| Dash Ghost clones per dash | ~216 (36 × 6), every dash | first dash builds the pool (measured 205 on the server copy); later dashes 0 |
| Dash Ghost per-frame cost | GetDescendants + 79 µs setAlpha per dasher, + clones | ~150 µs per ghosted dasher (Studio server copy, includes the fade writes), no clones |
| New config | — | `Movement.AIR_RISE = 8`, `AIR_GRACE = 0.1`; `Juice.JUMP.takeoffDip = 0.12`; `Mods.DASH_FEEL.ghostTrail {every 0.06, life 0.3, alpha 0.55, maxImages 12, keep 3}` |

**Gameplay side effect to know:** running jumps now get the **air spread** they were always meant to (Gunplay §2 / `Combat.MOVE_PENALTY.air`), so jump-shooting out of a run is less accurate than before. Bots' running jumps too. The server's spread check stays off (owner's authority exception, untouched).

## Tested
- **Desktop (1v1 bot match):** running jump, slide, slide-jump; states, speeds, camera offset and FOV logged per frame.
- **Phone emulator (749×381, touch on):** the touch buttons' own calls (`Humanoid.Jump` for Jump, a 0.25 s Crouch action for Slide), because the MCP mouse doesn't reach the touch buttons reliably. Jump → Air, coil −0.08, landing −0.18; slide 31.5 studs/s.
- **Lobby:** the sim runs there too (third person): run 16 → 22, jump Air at once, a step down stays Sprint.
- **Dash Ghost pool:** a server-side copy of the module stepping three fake Ghost dashes on a real character (pool built once, 0 clones on dashes 2 and 3, freed after `keep`).
- **Not tested: a real controller.** The MCP sends ButtonA / ButtonB as keyboard input, which Roblox ignores. The controller path is the same InputActions (Crouch = ButtonB) and Humanoid jump, so it should match; the owner should try A (jump) and B (slide) on a pad.
- Not seen by eye: another player's Ghost afterimages in a real 2-client test.

Commits: 50be542f, 348f6604, aa04661f, 4faf03c4.

## Lobby movement (2026-11-28)
Owner: "I just want the movement in the lobby to feel nicer." The hub runs the same movement simulation as matches: walk 16, automatic run to 22, jump 4.4, fall gravity 1.6. Those speeds stay: the hub is about 176 × 230 and the rotunda is about 3 s across at a run. What felt wrong was the Roblox Humanoid itself and the stock camera. **Hub only (PlayZone "Lobby").** The Range and matches keep the instant, RIVALS-like ground control, so match movement is unchanged.

| What felt wrong | Change |
|---|---|
| **Starts, stops and turns happen in one frame.** That is how the Humanoid works: it snaps to MoveDirection × WalkSpeed, so letting go of W stops you dead from 22 and a turn snaps. A first try that glided only in the 60 Hz simulation step was measured at ~170 fps: a stop from 22 in 20 ms, then a one-frame re-push. The Humanoid takes the raw input on the frames between steps. | **Lobby glide.** `Simulation/Movement lobbyGlideStep` is bound by MovementController as `GGLobbyGlide` and runs every rendered frame, just after Roblox's controls and the SettingsApply rebinds. On the ground the velocity eases toward where you steer: `LOBBY_ACCEL 110` studs/s² speeding up, `LOBBY_DECEL 140` slowing down, and the glide ends under `LOBBY_STOP 0.5`. The simulation step still decides the state and the target speed. |
| A straight-line chase also cut speed through a turn (13 studs/s at 90°). | Turns swing the heading at `LOBBY_TURN_RATE 600` °/s and keep the speed. A change sharper than `LOBBY_TURN_MAX 150°` brakes through a stop and sets off the other way. |
| **A light controller push ran at full speed.** The hub has no TouchController, so the push was always 1. | `MovementController` reads the left stick, rescaled past the player's STICK DEADZONE, into `MovementSim.setLobbyPush`. That push is kept apart from the match's, so it can't leak into a match. A light push walks slowly, and the run needs `TOUCH_RUN_PUSH 0.6`. **Phones:** the hub walks on Roblox's engine controls (there's no PlayerModule in PlayerScripts), and the engine thumbstick reports no push, so phones still walk and run at full speed. Fixing that would mean the match's own stick in the hub. |
| **Steps pop the camera.** Roblox's camera tracks the root exactly, so the hub's 0.6-1 stud steps moved the view the full step in one frame. | **`LobbyCameraFollow`** (lobby client, height only, Camera + 2): on the ground it soaks up whatever the root climbs beyond a low-passed climb rate and eases it home (`Config/Camera LOBBY_CLIMB_RATE 1`, `LOBBY_SETTLE_RATE 12`, `LOBBY_AIR_RATE 25`, `LOBBY_MAX_LAG 1.5`). Jumps and landings follow at once: the Humanoid's Jumping / Freefall / Landed states count as air. A first version read only the floor, which lags takeoff by ~60 ms. It soaked up 1.3-1.7 studs of every jump and then jerked to catch up. |

Left alone: speeds, jump height, fall gravity, the run's timing, the FOV (the player's setting, 80 by default, fine in third person), zoom (Classic, 0.5-128), slides, slide-jumps, the air and jump pads. The glide covers ground states only (Idle / Walk / Sprint / Crouch) and picks up from the real velocity on landing or out of a slide.

### Before / after (lobby only; measured in Studio Play at ~170 fps unless marked)
| Thing | Before | After |
|---|---|---|
| Start, 0 → run | Humanoid snaps to 16 at once, then the run ramps to 22 over 0.12 s | first frame 1.5-3.5 studs/s, smooth ramp, 22 at 0.19 s |
| Stop from the run | instant (one frame) | 22 → 0 in 0.14-0.15 s, ~1.5 studs, no re-push |
| 90° turn at a run | one frame | heading swings 0 → 90° in ~0.13 s. Speed dips to 16 for ~0.1 s: the automatic run drops while the body turns (`forward` check, same as before), then rebuilds to 22 |
| Reversal (D → A) | one frame | brakes to 0 and sets off the other way, ~0.3 s in all |
| Controller at half push | full speed | half speed, walks (run needs 0.6). Not measured: the MCP can't send a stick |
| 0.6-stud step down at a run, camera | full step in one frame | camera eases down; peak lag 0.42 studs, home in ~0.15 s |
| Jump, camera | follows exactly | follows within 0.09 studs. Landing within 0.1 |
| Largest frame-to-frame camera height change over the run + jump + step test | 0.53 studs (first camera version) | 0.16 studs |
| Simulated 1-stud step (camera) | — | 90% followed in 0.15 s, 0.05-stud overshoot. Climb 6 / settle 10 overshot 11%, a bob |

Not tested: a real phone or controller, a 2-player lobby, the stairs at the far wings (the test path had the hub's 0.6 and 1-stud steps).
