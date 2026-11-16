# Gunplay overhaul, pass 1: ADS, sniper scope, tracers, hit numbers, pull-outs (2026-11-15)

**Owner's ask (2026-11-15):** "go over and improve everything to be better and feel better": first-person animations, third-person animations, hits and headshots, "tracers for some guns, like actual ones", "revamp the ADS for snipers, make all ADS feel better", using the reference videos and the earlier skills.

**This pass did:** ADS for every gun, the sniper scope, tracers, the damage number, and per-class gun pull-outs; then a first third-person round (§6: the rifle reload and the look-down hold re-keyed, body-recoil options tested). **Not done yet:** the third-person body recoil, the Sheriff's reload beats (the knife was done in §7, the Sheriff's shot and inspect and the Bat in §8) from the [feel handoff](../Handoff%20-%20Feel%20Polish%20%28Fable%29.md) (queue in §5).

**Built in the match place, measured in a Studio playtest. Nothing committed.** Lint, format and build are clean; the client Output shows no new errors.

Leans on: [2026-11-14 Gun and Knife Feel from Videos](2026-11-14%20Gun%20and%20Knife%20Feel%20from%20Videos.md) §1 (the clips' shot numbers), [Animation Flow and Feel Research](../../03%20Research/Animation%20Flow%20and%20Feel%20Research%20%282026-11-14%29.md) §5-7 (LihFolk and published sources on gun feel, hit markers, flares, damage numbers; the checklist), [Hit Feedback Pass](2026-11-13%20Hit%20Feedback%20Pass.md).

---

## 1. What the clips show (new measurements, 60 fps)

The 2026-11-14 study skipped ADS, the scope and tracers. A frame study filled that in (clips in `art-source/reference/feel-videos/`, new frames `ads_*`, `scope_*`, `tracer_*` in `frames/`; third-party, never commit). Times are from the first moving frame; px at 1920x1080.

### ADS
| | Rifle | Large SMG | Small SMG | Pistol |
|---|---|---|---|---|
| Gun on the sights | 170 ms | ~120 ms | ~100 ms | ~100 ms |
| Path | straight diagonal, no dip, roll or overshoot | same | same | same |
| Zoom | 3.1x | 2.4x | 2.3x | 2.2x |
| Zoom timing | starts with the gun, ease-out; 90% at 235 ms, done ~330 ms | 90% at 170 ms | 90% at 130 ms | 90% at 215 ms |
| Corners darken | 40%, in ~120 ms | 49% | 48% | 51% |
| Out | gun 100 ms, zoom gone ~280 ms | ~130 ms | ~250 ms | ~310 ms |

- Crosshair ticks contract and fade, gone by ~100 ms.
- Aimed shots move only the gun (back ~8%, home in 85-100 ms); no FOV pulse, no blur.

### Sniper scope
- A full-screen black overlay with a **feathered** round window: fully clear out to 0.72 of the screen height, half dark at 0.84, black at 0.97.
- The gun rises for 250 ms, then a one-frame cut to the overlay. The window **opens from where the eyepiece was** (half size, down and right of centre) and reaches the centre in ~200 ms. The zoom is ~76% done at the cut and finishes over the next ~400 ms.
- Reticle: two thin black lines (~36% solid) across the window and a red dot (#FF3233, ~10 px).
- No sway while standing. A scoped shot drops straight out of the scope with the gun kicked up; the zoom is gone in ~180 ms.

### Tracers
| Gun | On screen (length x width) | Frames |
|---|---|---|
| Rifle | 41 x 5 px | 3 |
| Pistol | 31 x 5 px | 2 |
| Small SMG | ~58 x 8 px | 3 |
| Large SMG | 27-53 x 10 px | 3 |
| Revolver | 74-93 x 10-13 px | 2 |
| Sniper (hip) | 152-189 x 10 px, thick head, thin tail | 4 |

- A tracer is a **short bright dart near the aim point**, never a line from the muzzle. Its head is on the hit point from the first frame and its tail shrinks into it.
- Near-white core (#FBF8E7) in a pale yellow glow (#FAF2CA).

### What the clips don't show
Revolver ADS, moving while aimed or scoped, a manual unscope, tracer speed.

---

## 2. What ours did before (measured in play)

| Thing | Before |
|---|---|
| ADS | a smootherstep along a straight line over `adsTime`, the zoom locked to it; no darkening |
| Scope | a hard-edged black mask that popped on at 85% aim; plain lines |
| Own tracer | **never visible**: a 0.085-stud streak is 1.4 px wide at 40 studs, it runs straight away from the eye, and it started inside the muzzle flash; the trail (0.09 wide) did not show in any frozen frame |
| Damage number | 30 px, held 0.9 s, flew off to a random side |
| Gun pull-out | one track for every gun, always from low right |

---

## 3. What changed

### ADS, every gun (`Config/Viewmodel ADS_FEEL`, `ViewmodelController`, `WeaponController`)
- The aim alpha stays a straight ramp over `adsTime` (the server runs the same one). The gun is now **drawn** at that ramp's goal through a spring: it leaves at once, is on the sight line at ~0.85 x `adsTime`, lands ~1% past it and settles, and a half-finished aim turns round carrying its speed.
- **The zoom trails the gun** on its own spring, and lets go faster on the way out, like the clips.
- **The corners darken ~47% while aimed** (`Util/AimVignette`, `Config/Scope AIM_VIGNETTE`).
- Ours, not the clips': a 1.6° cant into the move and a 0.01-stud dip under the straight line. Both are zero at rest. Set `cant` and `dip` to 0 for the clip's straight slide.

Measured (Vandal, `adsTime` 0.2, Studio at 15 fps so ±67 ms):

| | Ours now | Clip (rifle) |
|---|---|---|
| Gun on the sights | ~160 ms | 170 ms |
| Past the pose | 0.8%, once | none |
| Zoom 90% | ~220 ms | 235 ms |
| Zoom done | ~430 ms | ~330 ms |

### Sniper scope (`Util/ScopeOverlay`, `Config/Scope`)
- Feathered window (28 rings of thinning black; clear to ~0.72 of the height, black at 0.97).
- **Opens from the eyepiece**: half size, right and down, to the centre in 0.2 s, under a short blur.
- Thin see-through cross and a red dot, like the clip.
- Ours, not the clip's: the black surround lags the turn of the view a little (max 30 px) and springs back; the reticle never leaves the screen centre. A scoped shot jolts the window up and blurs for the frames before it drops out. `Scope.LAG.lag = 0` turns the lag off.
- Captures: `scope_opening_60ms`, `scope_settled_v2` (Studio capture ids, this session).

### Tracers (`Util/TracerFx`, `Config/Juice TRACER`)
Two looks now:
- **Your own shot: the dart.** Head on the hit point from the first frame, tail from a few studs ahead of the muzzle running into the hit. Drawn a fixed width **on screen** whatever the range. Per class: width, start, how long it lasts.
- **Everyone else's: a flying streak** about twice as wide as before, with the trail it leaves; the trail now dissolves from the gun end outward.
- Per class (`class`, `gun`): rifle; pistol (shorter, quicker); SMG (fatter, quick); MG; shotgun pellets (small, quick); **sniper lance** (long, thin tail, a vapour trail that hangs 0.6 s for others); **Sheriff** (the fattest dart); Guardian.
- Colour: pale yellow FAEBB4 round a white core (was FFD9A0).

Measured (Vandal dart, slow motion): 39 px long at the first frame, 5 px head, 2.3 px tail; 27, 18, 11, 6, 3 px on the next frames (clip: 41 x 5 px, 3 frames). The config width is 10 px: the beam's texture is brightest down its middle, so about half of it reads.

### Damage number (`Util/HitFeedback`, `Config/HitFx NUMBER`)
- 42 px (was 30), head red E01F35 with a dark red edge.
- Holds 0.28 s after the last hit, then **tips over clockwise** (118°), drops 44 px and shrinks over 0.3 s.
- A new hit on the same target within 0.9 s **snaps it upright and keeps adding**, even mid-fall.

### Gun pull-outs (`Config/Viewmodel TRACKS`, `DRAW_TRACK`)
The same raise, rack and settle; only where the gun comes in from differs:
- **pistols**: up from the bottom right, muzzle tipped up-left ~45°;
- **SMGs**: straight up;
- **rifles, MGs, shotguns, snipers**: swept in from the bottom left, rolled ~60°.

Draw times are unchanged (the owner slowed them on 2026-11-08).

---

## 4. Test list for the owner

Flip `Workspace.TestMode` on for the range (I put it back to off).

1. **ADS, any rifle:** tap and hold aim. Does it snap to the sights and settle? Is the darkening at the corners right, too much, too little? Do you want the small cant or a dead-straight slide like the clips?
2. **Quick-scope:** tap aim on and off fast: the gun should turn round smoothly, no pop.
3. **Operator / Marshal / Outlaw:** scope in. The window should open from the lower right into the centre. Turn the mouse fast: the black surround lags a little. Fire: it jolts and drops out.
4. **Tracers:** fire each class at a wall 40-80 studs away. You should see a bright dart at the crosshair on every shot; the Sheriff's and the sniper's are the big ones. Stand beside the range Shooter to see other players' tracers.
5. **Damage numbers:** spray a dummy (one number adds up), stop (it tips over and drops), tap again inside a second (it snaps upright).
6. **Pull-outs:** swap pistol → rifle → SMG and watch where each comes in from.

---

## 5. Open, for the next pass

**Owner calls:**
- **ADS zoom.** The clips zoom 2.2-3.1x on every gun; ours is 1.15-1.5x (snipers 2.5-3.5x). Bigger zoom changes recoil control and move speed while aimed, so it needs a balance pass. Keep ours, or go toward the clips?
- **Tracer size.** Sized to the clips. Bigger, or a visible line from the muzzle as well?
- **Scope lag:** keep the small lag, or none like the clip?

**Not done this pass (owner's list):**
1. **Third-person animations.** Reload, look-down hold and body recoil done (§6). Still open: a second player's view of all of it, the rifle hold seen from the front, the draw, the pistol reload.
2. **First-person animation polish** from the handoff: knife "a little blocky" / inspect "staged" (spring layer, moving holds, the second turn), Sheriff inspect twirl and reload beats, the Bat.
3. **Headshot flare.** Looked at in play (ring, flame, red body, red number); left as the owner's ChatGPT flare. The clip's fan of rays is still the target if he wants it changed.
4. **Muzzle flash life by class and the pink wall light** (clip: every shot lights nearby walls ~130 ms), revolver smoke wisp.
5. Crosshair: ticks contract as you aim (clip: gone by ~100 ms); ours fades.

**Known gaps in the checks:** Studio ran at ~15 fps, so timings are ±67 ms. Tracers were checked on the Vandal and by config for the other classes. Spectating and replays still zoom on their own curve (not the new spring). Phones were not tested.

---

## 6. Third-person round (same day, after the owner picked it)

Full record: [Third Person Overhaul](../../01%20Design/Third%20Person%20Overhaul.md) §22.

- **Seen from outside:** mid-reload the rifle stood up over the head with the right forearm across the face. Re-keyed as a low-ready swap (gun down at the belly, canted, head looking down at it, face clear); uploaded as `GG Reload v7`.
- **Look-down rifle hold:** the right forearm sat inside the chest on every frame; the gun now goes out as it drops (`GG AimDown v7`).
- **Shooting:** only the gun moves in two still fists; the body doesn't react. Two code-only fixes were tested in play and rejected with numbers (joint writes don't stick; an arm IK jumped 2.5 studs in a frame). What was left was a set of 12 recoil pose clips driven by a spring: **built the same day** ([Third Person Overhaul](../../01%20Design/Third%20Person%20Overhaul.md) §23). On the range's shooting dummy a rifle shot now moves the muzzle up 3.3 degrees, the chest back 2.2 and the right hand back 0.13 studs with the gun, with no frame jump over 0.125 studs; a sniper shot is about three times that.
- **Test:** on the range, stand beside the Shooter dummy and watch it fire; reload a rifle and watch a bot or a second player do it; look down while holding a rifle. Tune the recoil per class in `Config/Juice BODY_KICK`.

---

## 7. Knife polish (same day, after the owner picked it)

From the [feel handoff](../Handoff%20-%20Feel%20Polish%20%28Fable%29.md) queue A. Owner on the knife: the motion is "a little blocky"; the inspect "weirds me out, especially on the second turn of the hand... too blocky and staged". Checklist used: [Animation Flow and Feel Research](../../03%20Research/Animation%20Flow%20and%20Feel%20Research%20%282026-11-14%29.md) §7 (items 1, 2, 3, 4, 6).

### The second turn, watched again (clip 14.05-14.40 s, 60 fps)
- The wrist **rolls** the blade about its own length to edge-on while it still stands upright: ~100 ms.
- Then it **whips over** to the left, pivoting on a fist that barely moves: ~130 ms, 30-40 degrees a frame. It lands pointing left, ~15 degrees below level.
- It keeps tipping slowly through the hold (to ~25 degrees below level).
- Ours did the roll and the tip together, in two even turns (72 then 47 degrees) over 0.37 s, then held almost still (10 degrees in 0.65 s). The end pose was already right; the way there was not.

### Changed
- **Second turn re-keyed** (`tools/studio/knife_fp_keys.py`, a new key kind `"split"`: a share of the roll about the blade and a share of the blade's swing, set apart). Roll first (0.555-0.59 of the 3.4 s), then the swing (0.59-0.63); the hold after it tips a further ~14 degrees. Written into `Config/Viewmodel InspectMelee` with `--write`.
- **A spring follower on every knife track** (`Util/ViewmodelTracks`, `Config/Viewmodel SCREEN_FOLLOW`). The keys are poses and the spline between them is monotone, so the knife stopped dead on each one. It is now drawn chasing the keyed pose through an underdamped spring (8.5 Hz, damping 0.62; the turn 7.5 Hz, 0.58): a stop has a little give, a turn carries through. An attack is exact on its keys up to contact and the spring comes in over 0.08 s after it; every track lets go of it over its last 8%, so it ends on the hold.
- **Cut-ins carry speed:** a move that cuts into another keeps the follower and its velocity (on top of the 0.09 s blend).
- **Holds keep moving:** the knife's idle drift (`MELEE_IDLE`) now runs through the inspect and the pull-out too, and eases out for a swing instead of switching off.

### Measured (Studio play, stock knife model, real time at ~15 fps)
| | Result | Clip |
|---|---|---|
| Roll to edge-on, blade still up | 1.80-1.94 s: face-on share 0.97 → 0.40 while the blade stays at 38-59 degrees | ~100 ms |
| Whip over | 1.94-2.07 s: blade 59 → 109 degrees | ~130 ms |
| Laid-over hold | 110 → 121 degrees over 0.6 s, 11-23 degrees/s | keeps tipping ~10 degrees |
| Longest stretch under 4 degrees/s between 0.4 and 3.2 s | **0.00 s** | none (research: a dead hold is 0.3 s or more under 4 degrees/s) |
| Slash and heavy end on the hold | within 0.7 / 2.3 degrees and 0.02 studs (the idle drift) | |
| Key check (`--check`) | every key: forearm from below (-53 to -83 degrees), eye clearance 0.84 or more, no step over 39 degrees | |

Capture: `knife_inspect_turn_mid` (Studio, this session): mid-roll, blade edge-on and still up, handle in the fist.

### Not verified / open
- **Studio ran at ~15 fps**, so the spring's give after a slash (tens of ms) could not be measured or seen frame by frame. Its size is from the numbers, not from a look. The owner's eye at full frame rate decides; `SCREEN_FOLLOW` damping up = less give, frequency up = tighter.
- No "before" recording of the knife inspect was taken in play this session; the before numbers are from the old keys.
- Tested on the stock knife model under a flat skin line. The saved locker loadout has the PopCircuit Bat in the knife slot, which has its own motion and was not touched.
- Not done from the handoff: the inspect's exit as a flourish (the clip rolls the blade point-down, swings it up and whips the fist out of view; ours lowers back), the free forearm's roll, the heavy's cocked pose, the Sheriff, the Bat.

---

## 8. Sheriff and the PopCircuit Bat (same day, after the owner picked them)

From the [feel handoff](../Handoff%20-%20Feel%20Polish%20%28Fable%29.md) queues C and D.

### Sheriff
| Thing | Before | Now | Clip |
|---|---|---|---|
| Shot: size of the flip (with the gun's own Fire clip) | 52 degrees (measured this session, once the peak was held) | **45 degrees** | ~45 |
| Shot: held near the peak | not held: two exponentials rise and fall at once | within 10% of the peak from 29 to 60 ms | ~50 ms |
| Shot: coming home | | half-way at 120 ms (19 degrees), within 10% of rest at 233 ms | back by 120 ms, settled 220 ms |
| Inspect | the generic turn-over (one side, then the other), the cylinder rolling | **the same, with a twirl between the two sides**: the gun hops out of the fist and turns twice end over end about its trigger guard in ~0.56 s, landing as the hand turns it over | a twirl of about two turns in ~0.6 s between the sides |

- The hold is a new `hold` on `SHOT_SNAP.gun` (`Config/Viewmodel`): the kick stays at full for that long, then comes home (Sheriff: hold 0.06, decay 0.035; rise 16 → 13 so the total stays ~45 degrees).
- The twirl is a `toss` on a Sheriff copy of the Inspect track (`TRACKS.InspectSheriff`, picked by `INSPECT_TRACK`). Block fists have no finger to spin a gun on, so it is a low toss, as the handoff asked. Measured in play: the gun turned ~400 degrees between 1.27 and 1.53 s. Capture `sheriff_twirl_mid`.
- **Not done:** the reload's beats (open, eject, speedloader, a flick closed to the right). That clip comes from Blender (`tools/blender`, `shared/WeaponAnimations/Sheriff.luau`); the slow tail of the shot (still 19 degrees at 120 ms) is that same Fire clip's own move.

### PopCircuit Bat
The bat already had what the knife just got (a rigid fist, spline keys, springs on the fist and the barrel, a toss-and-catch inspect). Measured and read, its gaps were different:

| Thing | Before | Now |
|---|---|---|
| **Hit-stop** | never happened: the stop only reached the knife's tracks, the bat moves on its own system | the bat holds its frame on a hit, 1.4 times as long as the knife (measured: completely still for 0.100 s at contact) |
| **Which side it swings** | took turns on its own, so after a pause or a three-swing chain it could swing backhand while the view's lead, the streak and the wall mark played a forehand | follows the combo step like the knife (measured: left, right, left, then after a pause left, right) |
| **Idle** | 0-1 degrees a second: a frozen hold | a slow roll and lean, 3.5 degrees a second on average at the first setting; then raised by a third (not re-measured) |
| **Coming home** | every move eased straight back to the idle | swings, the smash and the inspect's catch come home a little past the idle and settle |

Files: `Util/PopCircuitBat` (`DRIFT`, `STOP_SCALE`, `Bat.hitStop`, the new settle keys), `ViewmodelController` (`swing`, `hitStop`).

### Not verified / open
- Studio at ~15 fps again: the settles and the twirl were measured by numbers and one frozen frame, not watched at full speed.
- The owner's "new ideas" for the bat were never written down; this fixed what measured wrong. The handoff's question to him is still open.
- The twirl's pivot (0.15 up, 0.22 forward of the grip) is by eye from one frame; it may want moving onto the trigger guard exactly.
- The bat's idle after the last tweak, and the smash's settle, were not re-measured.

---

## 9. Tracer colours, hit markers, headshot and kill sound candidates (same day)

Owner: "nice tracers, with colour, for the ones with a muzzle flash and snipers"; "improve the hit markers, nicer and like RIVALS"; "find a better kill and headshot sound".

**State: built; lint, format and build clean. NOT seen in play yet:** Studio was in a playtest that was not mine when this was finished, and I left it alone. That playtest was running older code (checked read-only).

### Tracer colours (`Config/Juice TRACER.color`, `Util/TracerFx`)
Every gun that has a muzzle flash takes its class's colour; suppressed guns (Phantom, Ghost, Spectre) keep the pale round. The glow and the trail are the colour, the core is white tinted 40% toward it.

| Class | Colour |
|---|---|
| Sidearm | gold FFC94D (Sheriff orange FF7A3D) |
| SMG | yellow FFDC2E |
| Rifle | amber FFAA2B (Guardian FF962E) |
| Machine gun | orange FF8A1F |
| Shotgun | orange-red FF6A2A |
| Sniper | violet B57BFF |

The warm family runs light-and-fast to heavy; the snipers' violet stays clear of both team colours (cyan allies, orange-red enemies). The dart's glow is wider and more solid so the colour reads (3x the core, was 2.4x). **Owner call:** the palette is my pick; it is one table.

### Hit markers (`Config/HitFx MARKER`)
Re-measured on the clip's frames (`hits_strip_hitmarker_contract`, `hits_close_body_hitmarker`): RIVALS' wedges sit OUTSIDE the crosshair and frame it, coming in from about 40 px out to about 23 px (their centres) over ~100 ms while fading.

| | Before | Now |
|---|---|---|
| Wedge length | 8 px | 12 px (headshot 14) |
| Tips from the centre, at rest | 5 px (on top of the crosshair's ticks) | 17 px (outside them) |
| Slide in from | 12 px | 34 px (headshot 36) |
| Slide time | 70 ms | 100 ms |
| Starts to fade | 100 ms | 50 ms (headshot 100): it fades as it closes |

Colours, the one-pop-per-hit rule and "no marker on a kill" (owner, 2026-11-13) are unchanged.

### Headshot and kill sounds: candidates to listen to, nothing wired
The rule is to listen before an upload (memory `gun-audio-real-recordings`), and three headshot attempts have missed by ear before, so this stops at an audition.

- `python tools/audio/hit_candidates.py` renders them into `art-source/audio/ProPack/audition/2026-11-15 headshot and kill/` (git-ignored): each as a WAV, plus `Headshot reel.wav` and `Kill reel.wav` (the live sound twice, then each candidate twice).
- All real recordings, layered: the Sonniss GDC 2016 bundle (whip, drum hit, punches, a toy pop, a wine glass, two game pickup / notification sounds) and the pro pack's punches and wood block. No synthesis.
- **Correction (same day):** the first table here said the live headshot was "almost all bass (87% under 250 Hz)". That was a fault in my measurement (one window over the whole sound, which fades out its start, where the strike is). Measured properly the live headshot has 36% of its energy under 250 Hz and its centre at 1,478 Hz. Batch 1 was built on the wrong reading: I high-passed the candidates to "clear the bass", so three of the four came out thin (1-10% under 250 Hz) and bright. The owner passed on all of batch 1.

| Sound (batch 1, re-measured) | Length | Centre | Above 3 kHz | Below 250 Hz |
|---|---|---|---|---|
| Live headshot | 122 ms | 1,478 Hz | 2.3% | 36% |
| H1 whip crack over a thud | 97 ms | 2,728 Hz | 25.9% | 4% |
| H2 wood thock on a drum | 156 ms | 1,829 Hz | 0.5% | 1% |
| H3 punch and crunch | 97 ms | 2,072 Hz | 24.8% | 3% |
| H4 whip crack on a heavy punch | 97 ms | 2,224 Hz | 16.0% | 10% |
| Live kill | 112 ms | 860 Hz | 1.8% | 11% |
| K1 pickup chime over a thump | 224 ms | 1,829 Hz | 13.6% | 5% |
| K2 notification over a thump | 423 ms | 1,024 Hz | 6.6% | 7% |
| K3 toy pop with a low glass ring | 115 ms | 747 Hz | 7.1% | 70% |
| K4 low glass ring on a drum | 233 ms | 1,577 Hz | 17.6% | 37% |

- I can't hear them: the table is how they differ, not which is good. **Owner: listen to the two reels and name a letter for each** (or say what is wrong with all of them). Then: upload the pick (three takes for the headshot), put the ids in `GunSoundAssets`, and build the headshot-kill version from the two picks.

### Seen in passing
The playtest's Output had `Failed to load sound atlas:UiClick: Temp read failed` five times. Not from this work (an asset fetch that failed); noted in Bugs & Ideas.

---

## 10. Headshot and kill sounds, batch 2: measured on the owner's clip

The owner passed on all of batch 1 ("None, try again"). This time the target was measured instead of guessed: the audio track of his hits clip (`Hit Markers, Headshot, Damage Numbers, Player Highlight on Hit.mp4`, 30 s), 95 onsets, their spectra and the tones that stay put.

### What RIVALS' sounds are, in numbers
| Sound in the clip | What it is |
|---|---|
| The heavy hit (9 clear instances, after single shots at 2.7-5.8 s and 13.7-15.4 s) | A deep **sub thump** (peak ~35 Hz, 20 dB down in 165-260 ms) under a **clean bell-like ding**: partials at 3,094, 5,027 and 6,539 Hz (ratios 1 : 1.625 : 2.11), the 5 kHz one strongest, 20 dB down in ~200 ms. The whole ding is moved a few % in pitch from hit to hit (5,027 down to 4,441 Hz). About 10% of the energy is above 3 kHz, 70-85% under 250 Hz |
| The light hit (after automatic fire, 6.3-10.7 s and 18.4-21.4 s) | A short tick with almost no bass (5-8% under 250 Hz), most of it at 250 Hz to 1 kHz with a steady tone near 305 Hz, and a fifth of it above 6 kHz; ~40 ms |

- I can't tell from the audio alone whether the heavy one is the headshot, the target going down, or both together (the clip is an aim trainer). It is the sound the owner pointed at either way.
- **What this changes:** his earlier headshots that he called "too metallic, too sharp" and "too high pitched and annoying" were a sword's ring, sped up: a noisy, broadband sound. The clip's is high too (5 kHz) but it is a clean tone, short, and it sits on a deep thump. None of our takes so far had that shape; batch 1 had no ding at all.

### Batch 2
`python tools/audio/hit_candidates.py 2` → `art-source/audio/ProPack/audition/2026-11-15 headshot and kill, batch 2/` (git-ignored). Real recordings again: a wine glass struck (its strongest partial is 3,316 Hz and it decays at the clip's rate) and a glass clink, played faster or slower so their partials land on the clip's, over a drum hit low-passed to a sub thump. The ding's level is set by energy (10% of the sound, as measured), not by peak.

| Sound | Length | Centre | Above 3 kHz | Below 250 Hz |
|---|---|---|---|---|
| Clip's heavy hit | ~200 ms ding | — | ~10% | 70-85% |
| H5 thump and glass ding, the clip's pitch (5,027 + 3,094 Hz) | 279 ms | 887 Hz | 12.9% | 87% |
| H6 the same, a fourth lower (3,770 + 2,320 Hz) | 279 ms | 726 Hz | 11.0% | 87% |
| H7 the same, an octave lower (2,514 + 1,547 Hz) | 279 ms | 540 Hz | 4.3% | 87% |
| H8 thump and a short glass clink | 279 ms | 803 Hz | 13.8% | 84% |
| K5 two rising glass notes on a thump | 279 ms | 801 Hz | 10.1% | 80% |
| K6 one low glass ding on a thump | 279 ms | 652 Hz | 6.7% | 81% |
| K7 chime on a thump | 329 ms | 651 Hz | 6.9% | 82% |
| K8 pickup pop with a glass ding | 279 ms | 1,521 Hz | 11.5% | 22% |

- The clip has no separate kill sound to measure, so K5-K8 are the same family made "positive" (a rising pair, a lower single note, a chime, a pop).
- Not copied from the clip: nothing of its audio is used, only its measurements.
- **Open:** the owner's ear. If a ding is right but its pitch is not, H5 / H6 / H7 are the same sound at three pitches, so the answer is a pitch. If none fits, the next thing to know is what is wrong (too long, too boomy, too glassy).

---

## 11. The owner's picks wired in (H5, K5), and the regular hit sound made audible

### Headshot and kill: "H5 and K5"
- `python tools/audio/hit_candidates.py final` renders the picks as game cues into `art-source/audio/ProPack/standalone/` and its queue:
  - `hit_head_E`: H5, three takes a few % apart in pitch (1.0, 0.955, 0.91), as the clip's ding moves between hits;
  - `kill_E`: K5 (the game still climbs its pitch per kill, `Audio.KILL_LADDER`);
  - `kill_head_E`: K5 with H5's ding on top.
- Uploaded with `tools/audio/migrate_gun_sounds.py upload --cue ...` (five private group audio assets: 94138463215930, 137953928688305, 101910343791588, 114491554780707, 88129809341861), then `generate`. `Config/GunSoundAssets` gained only those three cues (diffed against the copy from before).
- `Config/Sounds`: `HitHead = "gun:hit_head_E"`, `Kill = "gun:kill_E"`, `KillHead = "gun:kill_head_E"` (were `hit_head_A`, `kill_C`, `kill_head_C`: still in the table, so going back is those three names).
- These cues are not in the atlas. Their queue entries are marked `standalone`, and `migrate_gun_sounds.py export` now keeps such entries (it would have failed on them).
- **Checked in play:** all five assets load in Studio (0.304 s and 0.375 s). A headshot played the new takes and a headshot kill played `kill_head_E`. The plain kill sound was not triggered. **Not checked:** how they sit in the mix by ear.

### The regular hit sound (owner: "if it is playing I can't really hear it")
| | Found | Now |
|---|---|---|
| Does it play? | yes, on every predicted hit | — |
| Volume | 0.42, against the shot's two layers at 1.26 and 1.99 | **0.8** (`Audio.HIT_VOLUME`) |
| When | 13 ms after the trigger: on the frame of the shot, under its crack (the sound is a 66 ms click) | **~50 ms later** (`Audio.HIT_DELAY`; measured +81 ms at Studio's 15 fps) |

- His RIVALS clip has the tick 80-150 ms after the shot, which is why it reads there.
- The headshot sound is delayed by the same amount. The late confirm path (a hit the client did not predict) is unchanged.
- **Open:** if it is still hard to hear, the next lever is ducking the shot under it, not more volume.

### Tracer colours and hit markers: seen in play now
- Operator: the dart's glow is B57BFF and its core E1CAFF (read from the beams) and shows violet in capture `tracer_sniper_violet_2`. Only the sniper was looked at; the other classes are by config.
- Body hit marker: the wedges show round the crosshair in capture `hitmarker_body_new` (55 ms after the hit). At capture size I can confirm they are there and outside the ticks, not how they look in motion.

---

## 12. Owner's round after playing: knife hit, hit markers, crosshair, damage direction, sounds again

Owner (2026-11-15, later): the knife hit "kind of just stops... it seems choppy"; hit markers "should tween inwards: it starts a bit bigger and then gets smaller"; "I still don't like the headshot and kill sound effect"; the crosshair "won't disappear when you are running... it should still be there but be dynamic" (default one; customisation comes later); the damage notification should look like RIVALS' red arc (screenshot), turn as you move to show where you got hit from, and grow / shrink with the distance.

### Knife and bat: the hit drags the swing, it no longer stops it
- **Was:** a hit-stop that held the swing on one frame for 66-100 ms (the bat: 92-140 ms, which I had switched on earlier the same day; the owner's knife slot is the bat), then carried on at full speed.
- **Now:** the swing's speed dips to a floor and eases back (`Config/Viewmodel HIT_DRAG`: floor 0.35 of normal speed, lasting the attack's `stop` x 2, the dip reached over the first 22%). It never holds a frame. A light slash: 132 ms of drag that eats about 43 ms (the stop ate 66 ms). The bat has its own numbers in `Util/PopCircuitBat` (`STOP_*`: floor 0.4, stretch 1.6: about 148 ms, eating about 44 ms).
- Code: `ViewmodelMotion.dragRate / dragTime`, `ViewmodelTracks.step` (the track's time advances at that rate), `ViewmodelController.hitStop`, `PopCircuitBat.hitStop`.
- **Checked:** a swing on a dummy lands, the marker shows, no errors. **Not checked:** how it feels. Studio runs at about 15 fps here, so a 130 ms dip is two frames: this one is the owner's hands. If it should go further, `floor = 1` removes it (the view punch, roll and the small shake after the hit stay); the shake (`KNIFE_FEEL.hitShake`, 0.25 deg, 66-100 ms after contact) is the next thing that could read as choppy.

### Hit markers: start bigger, shrink onto the crosshair
- **Was:** the wedges slid in from twice their gap in 100 ms at their final size, most of the way in the first frame.
- **Now:** the whole marker (wedges and gaps) starts at `scale` times its size and shrinks over `punch` (body 1.5x over 150 ms, head 1.7x over 170 ms; quadratic ease-out), the tips coming in a little further on top (`from` 1.4 / 1.45), fading in over the first third so the big first frame is not a flash. A hit while the last marker is still coming in starts at half that extra size (`HitFx.MARKER_REPOP`), so automatic fire pulses.
- **Measured in play** (15 fps): 67 ms after the hit the marker is at 1.16x (wedge centres 26 px out, 23 at rest), 1.01x at 131 ms, fading from there. At 60 fps that is 1.40, 1.30, 1.22, 1.15 over the first four frames.

### Crosshair: stays up on a sprint, and opens
- It was hidden while sprinting (`WeaponController`). Now it stays; the gap already follows the real spread cone (which grows with speed) and opens `sprintGap` (8 px) more on a sprint (`Config/Crosshair`, a field a later settings screen can expose).
- **Measured in play:** standing 7 px, running at 20.9 studs/s 29 px, visible throughout. It still fades for ADS.

### Damage direction: a red arc with an arrowhead, live
- New `Util/DamageIndicator` + `Config/DamageIndicator`; the shape is one image (`tools/vfx/make_damage_indicator.py` → `art-source/vfx/hit/damage_arc.png`, decal 121870947037186, image 105976537709544): a 20 px band, 68 degrees of a circle 285 px round the crosshair (at 1080p), with a triangle on its outside pointing at the shooter. Flat red FF1F2D.
- It **follows the shooter's position every frame** (it turns as you turn and move), and its **size follows the distance**, live: 1.2x at 12 studs or closer down to 0.7x at 110 or more. One arc per shooter (a hit from within 10 studs of an arc's source renews it with a small pulse), up to 4 at once. Pop: 1.3x shrinking over 140 ms, holds 0.85 s, fades over 0.4 s.
- **Bug found and fixed:** the old indicator's angle had its sign flipped, so it showed the **mirror side** (a shooter on your right showed on the left). Checked in play: a source 80 studs to the right gives rotation 90 (right side), scale 0.85.
- Studio only: Workspace attribute `DevDamageFrom` (Vector3) shows an arc for a hit from that spot (no damage).
- **Not checked:** a real hit from a bot or player (only the dev attribute), several arcs at once, phones.

### Headshot and kill sounds, batch 3 (nothing wired)
- The owner picked H5 / K5 by ear, then did not like them in the game. They did not say what is wrong. What the numbers show: 80-88% of their energy is a sub thump under 250 Hz, the ding sits above 3 kHz, and between 500 Hz and 2 kHz there is next to nothing (-41 dB in the headshot's loudest 100 ms). On speakers with little bass that is a thin ting.
- `python tools/audio/hit_candidates.py 3` → `art-source/audio/ProPack/audition/2026-11-15 headshot and kill, batch 3/` (git-ignored): no sub, a short dry knock with the ring carrying 40-50% of the energy. 2-4 dB more above 2 kHz than H5 / K5 and 11-22 dB more in the middle. Real recordings (pro pack knocks, the wine glass, a glass clink, a chime).
- **New:** each one is also written after a rifle shot (`in a fight/`), the way it plays in the game, with the live H5 / K5 the same way for comparison. Batches 1 and 2 were judged alone.

| Sound | Length | Above 3 kHz | Below 250 Hz |
|---|---|---|---|
| Live headshot (H5) | 283 ms | 11% | 88% |
| H9 slap and a bright glass ding | 140 ms | 70% | 2% |
| H10 metal tick and a glass clink (a dink) | 64 ms | 43% | 0% |
| H11 wood knock and a lower glass ding | 160 ms | 38% | 0% |
| H12 glass ding with a soft punch under it | 173 ms | 56% | 33% |
| Live kill (K5) | 300 ms | 9% | 81% |
| K9 punch and two rising glass notes | 236 ms | 30% | 36% |
| K10 punch and a chime | 329 ms | 20% | 42% |
| K11 slap and a low glass ding | 218 ms | 45% | 1% |
| K12 wood knock and two rising glass notes | 227 ms | 26% | 0% |

- **Open:** the owner's ear, and one sentence on what is wrong with H5 / K5 in the game (too quiet, too boomy, too long, wrong character) would aim the next step better than another batch.

---

## 13. Headshot and kill sounds, batch 4: a soft shing, a subtle kill (nothing wired)

Owner (2026-11-15, after batch 3, by voice): the headshot in RIVALS "has like a shing... a nice one"; "a lot of these have a really high pitched ding, which is annoying and doesn't feel good"; the kill should be "subtle enough where subconsciously the player likes it... nothing annoying and nothing over the top".

- **So the target is a shing, not a ding, and low.** Batches 2 and 3 were dings (a struck glass, a clean tone at 3-5 kHz). The shings of 2026-11-13/14 that they called "too metallic, too sharp" and "too high pitched" were sword draws played 1.25-1.5x faster.
- **Measured on the blade recordings we have** (CC0, `art-source/audio/downloads`): most sword draws already sit at 6-9 kHz as recorded (64-95% of their energy above 5 kHz), so speeding them up made them pierce. Two are low by nature: an unsheathe whose ring is at 2.9 kHz (freesound 107589, 9% above 5 kHz) and a light blade clang at 1.8 kHz (351372).
- **Batch 4** (`python tools/audio/hit_candidates.py 4` → `art-source/audio/ProPack/audition/2026-11-15 headshot and kill, batch 4/`, git-ignored; each also in `in a fight/` after a rifle shot): those low blades as recorded or slowed, a bright draw slowed to 0.55x, all low-passed at 4-5 kHz, eased in over 5-12 ms (the "sh"), on a quiet soft body thud. The kills are short, low and levelled 3 dB under the old kill: a soft pop or a warm low note on a muffled thud.

| Sound | Length | Centre | Above 3 kHz | Above 5 kHz |
|---|---|---|---|---|
| Live headshot (H5) | 283 ms | 775 Hz | 11% | 9.3% |
| H13 soft shing (a sword unsheathed, as recorded) | 200 ms | 2,653 Hz | 39% | 2.2% |
| H14 lower shing (the same, slowed) | 199 ms | 2,173 Hz | 31% | 0.4% |
| H15 long smooth shing (a bright draw, slowed a lot) | 230 ms | 2,446 Hz | 46% | 2.6% |
| H16 soft ring (a light blade clang) | 196 ms | 1,810 Hz | 26% | 2.4% |
| H17 short shing (a small sword, slowed) | 157 ms | 1,727 Hz | 13% | 3.5% |
| Live kill (K5) | 300 ms | 735 Hz | 9% | 3.4% |
| K13 soft bubble pop on a thud | 108 ms | 720 Hz | 0.3% | 0% |
| K14 soft two-note pop | 223 ms | 1,100 Hz | 1.6% | 0.3% |
| K15 warm low note on a knock | 258 ms | 549 Hz | 0.1% | 0% |
| K16 muffled thud with a bowl's low hum | 268 ms | 460 Hz | 0.6% | 0% |
| K17 thud with a faint low shing | 203 ms | 1,176 Hz | 16% | 0.2% |

- Not heard by me: these are built to the owner's words and to measurements. **Open:** their ear. Useful answers: a pick, or "the shing is right but lower / shorter / quieter".

---

## 14. K13 wired as the kill sound; headshots: batch 4 passed on, batch 5 rendered

Owner (2026-11-15, after batch 4): the headshots, "I don't like all of them. They're all either too dull, and the shings are just too metallic and kind of annoying, like nails on the chalkboard... not satisfying. I like K13. We'll go with K13."

### Kill: K13 is live
- `python tools/audio/hit_candidates.py final-kill` renders it as the cue `kill_F` (only that file is written; the other standalone cues stay byte for byte), `migrate_gun_sounds.py upload --cue kill_F` (one private group audio asset, 97850971640091), `generate` (`Config/GunSoundAssets` gained only `kill_F`).
- `Config/Sounds`: `Kill` and `KillHead` are both `gun:kill_F` (were `kill_E` / `kill_head_E`, still in the table). The headshot kill plays the same sound until a headshot is picked.
- K13 is a softer take of the old `kill_C`'s bubble pop (slowed to 0.9x, low-passed at 3 kHz, on a muffled thud), levelled 3 dB under the old kills. `Audio.KILL_VOLUME` 0.36 → 0.5 makes up for that, so it plays about as loud as the old kills did. The pitch still climbs per kill (`KILL_LADDER`).
- **Checked:** the asset loads in Studio (0.200 s) and the three config files are synced. **Not checked:** a kill in play, and how loud it sits (in the audition's "in a fight" file it was louder against the shot than the game plays it).

### Headshot: what they have turned down so far, and batch 5
| Tried | Their words |
|---|---|
| Sword rings sped up (11-13/14) | "too metallic, too sharp", "too high pitched and annoying" |
| Glass dings (batches 2, 3; H5 was live) | "a really high pitched ding, which is annoying" |
| Low blade shings (batch 4) | "too dull", "too metallic... nails on the chalkboard" |
| Liked | K13, a soft round pop |

- So: no metal, no high clean tone, not low-passed until dull; a round pop is the one thing that landed.
- **Batch 5** (`python tools/audio/hit_candidates.py 5` → `audition/2026-11-15 headshot and kill, batch 5/`, with `in a fight/`): K13's family made crisper and higher. H18 bright pop with a dry crack; H19 pop and crack at K13's pitch; H20 two quick rising pops; H21 wood tock on a pop; H22 a higher two-note pop. 76-170 ms, centres 1.0-2.0 kHz, 1-12% above 3 kHz, no ring.
- H5 stays the live headshot until they pick one.
- **Open (their call):** our rule is real recordings only, never synth. RIVALS' headshot may well be a designed (synthesised) tone; if batch 5 misses too, the two ways forward are (a) they find a sound they like (Studio's Toolbox audio, or any file) and I level and wire it, or (b) the rule is relaxed for hit-confirm sounds only.

---

## 15. H18 wired as the headshot; both picks heard in play

Owner (2026-11-15, after batch 5): "H18".

- `python tools/audio/hit_candidates.py final-head` → the cue `hit_head_F`: H18 (a bright bubble pop with a short dry crack on its front, on a quiet thud; 180 ms, centre 1.2 kHz, 3.6% above 3 kHz), three takes: as they heard it and 3% lower and higher. Uploaded (106431154366392, 102555807166896, 83235246233124); `Config/GunSoundAssets` gained only `hit_head_F`.
- `Config/Sounds`: `HitHead = "gun:hit_head_F"` (was `hit_head_E`, H5, still in the table). `Kill` and `KillHead` stay `gun:kill_F` (K13): a headshot kill plays the headshot pop and then the kill pop, the same family.
- **Checked in a Studio playtest** (15 headshots on two range dummies): H18 played on every headshot, 52-101 ms after the shot, volume 0.51, all three takes seen; K13 played on both kills at volume 0.52, its pitch climbing (1.26x, then 1.34x on the next kill). None of the old sounds (H5, K5) played.
- **Not checked:** how they sit in the mix by ear (the owner's), and the plain body-hit tick next to them (it plays with the headshot, 0.80).
- The headshot question from §14 (real recordings only vs a designed tone) is closed for now: their picks are both real recordings.

---

## 16. Hit marker brought in closer, and a final sweep of every gun

Owner (2026-11-15, after playing): the hit marker "doesn't get small enough... doesn't get close enough in"; then "one final thing on the gunplay, just making sure it's all good", after which the work moves on to the abilities.

### Hit marker
- The wedges' tips now rest **8 px** from the centre (were 17, outside the crosshair's bars), in the gaps between the bars. They start further out to keep the travel: body 1.6x size with tips at 1.6x the gap (about 20 px out, coming in to 8), head 1.8x and 1.65x. `Config/HitFx MARKER`.
- **Measured in play:** tips at rest 7-8 px on every gun.

### Sweep (Studio playtest, every gun in `Config/Weapons`: 17 guns and the melee slot)
Each gun: picked with the range's weapon picker, three shots at a range dummy, aim, reload.

| Check | Result |
|---|---|
| Hit marker on a hit | every gun (snipers and the Shorty showed fewer than 3 only because my shots came faster than they can fire) |
| Aim zoom | rifles 80 → 68 (Guardian 58), SMGs 72, machine guns 70, Sheriff 68, Marshal 27, Outlaw 27, Operator 37; shotguns, Classic and Ghost have no zoom by config (`adsFov = 80`) |
| Tracer colours | rifle FFAA2B, Guardian FF962E, SMG FFDC2E, machine gun FF8A1F, shotgun FF6A2A, sidearm FFC94D, Sheriff FF7A3D, sniper B57BFF; Phantom and Spectre pale (suppressed), as designed |
| Melee (the bat, the owner's loadout) | swings land with the lighter drag, no errors |
| Errors in the log | none from our code (one content warning for asset 203785492, not referenced in `src` or `tools`) |

- `Akimbo` has a model in `ReplicatedStorage.Weapons` but no config entry: not a gun yet, skipped.
- **Could not be checked on the range:** the damage direction arc from a real hit. The range's shooter dummy never deals damage by design (`TestRange.SHOOTER`), so the arc is only tested through `DevDamageFrom`; the `Damaged` remote path is the old one with the new module behind it. First real check: a bot match.
- **Left for the owner's hands** (Studio runs at about 15 fps here): the feel of the knife / bat drag, the marker's shrink in motion, how the sounds sit.
- **Still open from earlier passes:** the Sheriff's reload beats (a Blender clip), the knife inspect's exit flourish, a second player's view of the third-person work.
