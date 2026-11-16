# Gunplay Feel Pass 2 (2026-11-10)

Owner's ask (2026-11-10, three messages):
- First-person hand animation "better, smoother, nicer"; more feedback from the guns; everything should look like a professional game.
- Rifle placement is good where it is. **Secondary guns** should sit closer to the body and fill more of the screen.
- **Sprint:** more movement, a side-to-side sway.
- **Aimed strafing:** A tilts the gun a little left, D a little right.
- **Slide:** look and feel much better; a tap on C does the full slide, jump cancels it.
- **Much better tracers, muzzle flash and shot VFX** (ChatGPT images allowed).

## What was there (measured before changing)
- Test range, Studio, FOV 80. Vandal hip: sight line at (0.57, -0.25, -0.345) from the eye; Classic grip at (0.47, -0.71, -1.27), so the pistol read small and near the centre.
- Arms are rigid with the gun (`holdWith`: hand offset and arm direction in gun space), so every kick, sway and pose turned gun and arms as one stiff piece.
- Sprint loop: 0.85 loops/s, 0.034 studs sideways. Aimed strafe: 0.0026 rad per stud/s, leaning *against* the motion (about 1.5°).
- Slide ended the moment C was released (`Simulation/Movement` line 128), so a tap gave a stub of a slide. Viewmodel: one static pose.
- Tracer: two plain Beams with a gradient texture. Flash: 2x2 procedural flipbooks.

## Plan
1. **Sidearm hold** (`Config/Weapons` `SIDEARM_VM`): closer, a little right and higher. Tuned live with the `VmOffset` attribute. ADS untouched (it has its own frame).
2. **Motion** (`Util/ViewmodelMotion`, `Config/Viewmodel`):
   - Sprint loop with a real side-to-side swing (position, yaw, roll) and a fore-aft push, at step cadence.
   - Aimed strafe lean *into* the strafe, around the sight line, soft-limited.
   - Fore-aft inertia (start / stop) so the gun has weight when you move off and stop.
3. **Arms follow-through** (`ViewmodelController.holdWith`): the hand stays exactly on the grip; the arm's direction follows on a critically damped spring in camera space, so recoil, sway and poses make the wrists and forearms give instead of turning as one block.
4. **Slide** (`Simulation/Movement`, `Config/Movement`, `MovementController`, `Config/Viewmodel`): a tap commits the full slide (jump still cancels into a slide-jump; C held at the end stays crouched); viewmodel entry kick, a scrape chatter during, a settle on exit; camera lunge on entry.
5. **Shot VFX** (`Util/TracerFx`, `Util/MuzzleFx`, `Config/VfxTextures`, `tools/vfx/`): new tracer (hot head, tapered tail, a faint smoke line), new flash sheets.
6. Check: `selene`, `stylua --check`, `rojo build`, Studio playtest screenshots per gun class.

## LihFolk notes used
- *Springs Damping and Smoothing* (exact spring step; sway 4-8 Hz, zeta 0.6-0.8; critical settles in 0.93 / f).
- *First-Person Viewmodels - Arms Rig, Sway and Camera Binding* (bind after the camera; near plane 0.1-0.5 by platform).
- *Camera Shake and Camera FX* / *Layering Camera Feedback on the Default Camera* (caps: FOV 12°, roll 4°, offset 1.6 studs; never turn the look).
- *Projectile VFX - Muzzle, Travel and Impact* (flash 1-2 frames; tracer length = speed x lifetime, 12-30 studs; width tapers to 0).
- *Juice on a Budget*, *Particle Emitters In Depth* (pool emitters, never destroy right after Emit).

## Results (built and checked in Studio, test range, 2026-11-11 00:20)
`selene` 0 errors / 0 warnings, `stylua --check` clean, `rojo build` OK, no errors in Output. Checked by script and screenshot; **the owner has not played it yet**.

| Item | What changed | Checked |
|---|---|---|
| Sidearm hold | `SIDEARM_VM` (0.42, -0.76, -1.3) → **(0.52, -0.72, -1.0)**: 23% closer, further right, a little higher. ADS untouched | Classic, Ghost, Sheriff on screen: big, low right, both fists visible, nothing covers the crosshair |
| Sprint | The loop swings the gun side to side with the stride: ±0.085 studs, 3.4° yaw, 4.6° roll, a fore-aft oval. Walk and sprint loops now run at the **footstep cadence** (stride 5 / 6.2 studs; were 1.0 / 0.85 loops/s against 3.2 / 3.5 steps/s) | Measured sprinting at 21 studs/s: the grip travels 0.20 studs side to side, 0.12 up-down, roll 18°..31° |
| Aimed strafe | The gun leans **into** the strafe (A left, D right), about 4° at full aimed strafe, soft-capped at 4.5°, around the sight line | Screenshot aimed + A: rear ring leans left, front post still on the crosshair |
| Fore-aft weight | Moving forward settles the gun back 0.02-0.03 studs and dips the muzzle about 1°; backpedalling pushes it out | Not measured on its own |
| Arms | `ARM_FOLLOW` 34 rad/s (aimed 80): the hand stays on the grip, the forearm trails on a spring | Sheriff shot frozen at the kick: gun pitched 8.9°, fists stayed low, so it bends at the wrist |
| Slide | A **tap on C commits the full slide** (0.85 s, 30 → 12 studs/s, about 20 studs; was 0.7 s to 9, about 16, and it stopped when C was released). Jump still slide-jumps out; C held at the end stays crouched; running into something ends it. Camera leads 0.3 studs into it; the gun drops in with a kick, chatters with the scrape, settles on exit; pose canted inward | State log from one C tap: `Sprint → Slide (0.85 s) → Sprint` |
| Tracers | Core + glow + a **wake** line that hangs 0.28 s; 20 studs long (was 9), new textures | Frozen single shot and a full-speed spray: a clear line from the muzzle to the crosshair |
| Muzzle flash, impact | New **stylised** sheets (Codex, owner's direction in the chat: "Valorant, not realistic"), cut up by `tools/vfx/make_shot_vfx.py`; flash a frame longer and brighter; impacts get a spark-spike burst instead of a soft glow | Flash on screen: sharp star with spikes. **Impact burst not looked at up close** |

### Found on the way
- **Bloom white-out.** The place's Bloom starts at 2. A tracer core at Brightness 2.5 whited out the whole screen when several streaks overlapped. Shot sprites and beams stay under 2 (`coreBrightness` 1, `FLASH_BRIGHTNESS` 1.7).
- **Your own tracer is seen end-on**, so the streak is only a few pixels long on screen; the wake (muzzle → crosshair) is what you actually see of your own shots. Others' tracers show the full streak.
- Codex's first sheets were photoreal; the owner corrected the style in the chat. Saved as a memory (`gun-vfx-valorant-style`).

### Not done / not verified
- Not played by a human: the feel numbers (sprint swing size, lean angle, arm lag, slide length) are first values.
- Slide length is a **gameplay change** (about 25% further). Bots slide the full length too.
- The Akimbo hold (its own offset (0.55, -0.78, -1.3)) and the knife were **left as they are**.
- Other players' view of the new tracer (needs a second client). Mobile not checked.
- Old flash / tracer textures are still uploaded (ids in `Config/VfxTextures` comments) for a quick revert.
- The match place was not saved; `TestMode` was put back to `false`.

### What to test (owner)
1. Pistols (Classic, Ghost, Sheriff, Shorty): size and place on screen; aim to check nothing changed there.
2. Sprint with a rifle and a pistol: is the swing enough, too much?
3. Aim and strafe A / D: the lean.
4. Sprint, tap C: full slide; jump out of it; hold C to end crouched.
5. Spray at a wall and into the open: tracers, flash, impact sparks.
6. Tap-fire the Sheriff and the Vandal: do the hands feel alive or loose?

## Follow-up, 2026-11-11: Server Authority off, slide exit
Owner: the pass "looks good"; movement after a slide is "a bit off"; Server Authority was turned off (it lagged), and since then the Operator gave hit markers with no damage and ability throws were refused ("the camera isn't right"). Asked to disable that anti-cheat for now.

**What was wrong (measured in a live playtest):** with `AuthorityMode = Automatic` the server sees none of a player's inputs (every `InputAction` read false, `Player:GetCameraState` errors "requires Server Authority"). Its own movement simulation therefore had the player standing and walking (`MoveState` Walk while the client sprinted), so:
- a scoped Operator shot claimed a 0° cone and the server clamped it into its "unscoped, moving" band of 5° to 13.5°, so its rays missed what you hit;
- Mod throws failed the camera / facing check;
- the server kept writing its standing state over the client's.

**Changed** (`shared/Authority.luau` new; details in [Architecture](../../04%20Tech/Architecture.md) → Authority mode):
- Server simulates and poses bots only; clients own their characters and report their move state on the `Aim` remote.
- Spread band off (the client's cone is used, up to 45°), Mod aim check off, origin tolerance 5 → 9 studs. Damage, fire rate, ammo, range, rewind, walls and teams are still server-checked.
- **Slide exit:** the slide now slows to the speed you'll have next (sprint / walk / crouch). It used to slow to 12 and jump back to 22.

**Checked:** server prints `Server Authority is OFF (Workspace.AuthorityMode)`. Slide with the Operator: 25 → 19 studs/s, then sprint at 19, no dip. Server sees the reported `Sprint`. Owner shot a dummy with the Operator: works. `selene` / `stylua` / `rojo build` clean.

**Not checked:** an ability throw (owner to try); two real players (what each sees of the other); my reading of "a bit off" (the speed dip) is a guess, say so if it was something else.

**Known gaps while authority is off:** Dash and Updraft charges live on the client; no speed or teleport check; a client can claim any cone. Parked in [Bugs & Ideas](../Bugs%20%26%20Ideas.md).

## Follow-up 2, 2026-11-11: "more fun, more game-like" (RIVALS / Valorant feel)
Owner, three messages: the slide has too much steering (it should hold its direction, maybe a little steering); reloads and all first-person animation aren't aggressive, bouncy or fun enough, more recoil movement; hold the guns a little lower and further left; a real left-right run sway, and with a pistol the left hand swings free while the right holds the gun; no Shift to sprint (walk, then run); the jump is too high and not fun.

| Item | Change | Measured / seen |
|---|---|---|
| Slide direction | The slide's velocity is set every step along the line it started on (like the Dash); keys bend it `SLIDE_STEER` 12°/s; the camera turns freely | With 24°/s: holding D through a slide bent it 0° → 33° (the Humanoid adds some pull of its own), so it was halved to 12. **Not re-measured at 12** |
| No sprint key | `RUN_DELAY` 0.4 s of forward movement, then walk → run over `RUN_RAMP` 0.35 s. Shift does nothing | W only: Walk 15 for 0.4 s, then 16 → 21 by 0.8 s; C then slides at 28 |
| Jump | `JUMP_HEIGHT` 5.6 → 4.4, `FALL_GRAVITY` 1.3 → 1.6; the gun dips on take-off and bounces on landing; floatier Air pose | Rise measured 4.28 studs |
| Hold | `HIP_SHIFT` (0.05, 0.05, 0.035) → (-0.01, 0, 0.035): every gun 0.06 left, 0.05 lower | Vandal on screen: lower and more central-right, nothing clipped. **Other rifles not looked at** |
| Run sway | `BOB_SPRINT` sideways 0.085 → 0.125, yaw 4.6°, roll 6°; the carry pose is a lighter cant (13° / 17°, was 20° / 30°) now that running is automatic | |
| Pistol run | The support hand lets go and pumps (`PISTOL_RUN_HAND`, `PISTOL_RUN_SWING`), half a stride out of step with the gun | Classic running: left fist off the gun, swinging; then moved 0.18 further left (**not re-looked at**) |
| Handling bounce | New underdamped spring per gun (`HANDLE_BUMPS`): mag out, mag in, rack, shells, open / close, draw each kick it | Classic reload: gun height moves 0.19 studs, pitch -4.6°..13.4°. No script errors |
| Rig bounce | New springy up-down channel (`BOUNCE_*`): landing and jump | |
| Recoil | `PUNCH_SCALE` 1.5 on every shot punch, looser spring (`PUNCH_DAMPING` 33 → 25), base kick and aimed kick up about a third, turn sway gain 2.4 → 3.4, shot FOV / roll / shake up a third | Not measured |

**Not verified:** all of the feel numbers by a human; rifles other than the Vandal at the new hold (near-plane clipping at the left edge of long guns is the risk); bots with auto-run; maps' jump routes at 4.4 studs.
Unrelated Output noise seen: three map sign assets fail to load (`tools/studio/maps` Bunker2 / Rooftops2 / Snowpeak2 Art).

## Follow-up 3, 2026-11-11: Sprint key and run-up
Owner: keep a Sprint key (Shift, PC only; the automatic run is for mobile) whose only job is to cancel crouch and run; and the run-up was too slow.
- `RUN_DELAY` 0.4 → 0.05 s, `RUN_RAMP` 0.35 → 0.12 s. Measured: W down, Walk at 0.08 s, Run at 0.13 s, 22 studs/s by 0.28 s.
- Shift held while moving overrides crouch (`Simulation/Movement`: `crouchRaw` / `crouchIn`); it also skips the run delay. Measured with C and W held: Shift down → `Sprint`, Shift up → `Crouch` again, no slide.
- **Rojo:** the Studio plugin had disconnected, so these two files (`Config/Movement`, `Simulation/Movement`) were pushed into Studio by script with the same edits. **Click Connect in the Rojo plugin** so the files on disk are the source again.
