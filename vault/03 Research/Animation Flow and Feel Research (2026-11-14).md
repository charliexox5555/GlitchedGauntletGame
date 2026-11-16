# Animation flow and feel research (2026-11-14)

**Why:** the owner, after knife pass 2: slashes "really good", the pull-out "pretty good", but the motion is "a little blocky" and the inspect's second turn of the hand looks "staged". He asked for the research to be done **before** the work moves to a Fable session: "animations, making things look good, having good flow... what looks good, what looks bad, everything like that before we edit".

**Used by:** [Handoff - Feel Polish (Fable)](../05%20Production/Handoff%20-%20Feel%20Polish%20%28Fable%29.md) (knife polish, guns, Sheriff, Bat, headshot / crosshair / head flare). The applied checklist is §7. The project's measured numbers are in [2026-11-14 Gun and Knife Feel from Videos](../05%20Production/Playtests/2026-11-14%20Gun%20and%20Knife%20Feel%20from%20Videos.md) §1.

## 1. The owner's clip, frame by frame: why RIVALS' inspect isn't staged
Knife clip `art-source/reference/feel-videos/Knife Animations.mp4` at 60 fps (one frame is 16.7 ms).
- **Holds move.** In the flat-face "hold" (12.8-14.07 s) the knife keeps drifting: it tilts ~5° right and rolls a little over ~0.3 s. In the laid-over hold (14.3-15.73 s) it keeps tipping slowly down (~-15° → -25°). Nothing sits frozen.
- **The second turn is one overlapped wrist move of ~200 ms**, not two posed turns:
  - a roll about the blade's own length, from flat face to edge-on, in ~70 ms (14.10 → 14.17);
  - the tip-over to the left starts **before the roll ends**: ~20° at 14.23, ~35° at 14.27, ~50° at 14.30;
  - the fist barely moves; the wrist does it.
- **The exit is a flourish, not a pose-back:**
  - the wrist rolls the blade to hang point-down (~250 ms, 15.80-16.05);
  - the fist drops, then the blade swings up through a pendulum arc from lower left to upright with a streak (16.25-16.32);
  - the fist whips down out of view and back up to the hold (16.37-16.70), the free arm returning with it.
- **The slashes** (pass 2 study): the blade never stands up mid-swing; it lies over ~45° and trails behind the fist while the forearm sweeps like a wiper from a low pivot.

## 2. LihFolk (note titles in brackets)
**Principles and failure modes**
- **Robotic:** every key eased InOut (stop-start), or a Linear arm span over 0.12 s turning more than 20°. [Animation Quality Standard; Keyframes, Easing and Interpolation]
- **Mannequin / staged:** a dead hold, meaning every joint under ~4°/s for over 0.3 s. [Animation Quality Standard]
- **Weightless:** no hit-stop or flash; fix with a 40-90 ms freeze plus a 0.1 s flash. [Procedural Death Knockdown and Hit Reactions]
- **Floaty:** world gravity or slowed playback; scale gravity to the body. [Scale and Animation]
- **Corner QA:** the grip turns more than 50°, or its speed changes by more than 75%, in one 60 Hz frame while moving over 12 studs/s. [Animation Quality Standard]
- **Arcs come from joint rotation;** straight-line hands come from lerping positions. [Principles of Animation for Games]
- **Strikes accelerate into contact:** the wind-up leaves with In, the strike leaves with Out, the settle is InOut. Don't put a cubic ease-in on a big short swing (its last two frames carry 70%). [Weapon Swing Design]
- **Follow-through:** ~1 frame per link at 30 fps. Lag the waist 0.015 s, the neck 0.035 s, the free arm 0.05 s. [Principles of Animation for Games]
- **Anticipation is by pose, not time:** light 2-6 frames at 30 fps, heavy 6-15. Show *something* moving on the input frame. [Combat Animation Craft]
- **Inference worth acting on:** a monotone spline (PCHIP) gives **zero velocity at every key where the motion reverses**, so a turn that goes past and comes back stops dead at its key. That is the "staged" look in our inspect.

**Secondary motion**
- **Spring:** x'' = ω²(T − x) − 2ζω·x', ω = 2πf. ζ 0.72 overshoots 3.8%, ζ 0.5 overshoots 16.3%; settles in ~4/(ζω). Use the exact analytic update (dt-independent), clamp dt, guard NaN. [Springs Damping and Smoothing; Springs That Survive Long Frames]
- **Tuning:** weapon sway 4-8 Hz, ζ 0.6-0.8; root recoil 6 Hz, ζ 0.5; look-at ζ 1.
- **Kicks:** add an impulse to *velocity*, never jump the position; keep the rest target fixed.
- **Smoothing:** 1 − exp(−k·dt), never a per-frame lerp.
- **Viewmodel:** bind after the camera; sway from camera rotation change, not mouse delta; scale sway by 1 − 0.7·ADS. [First-Person Viewmodels]
- **Camera:** roll is safe; undo pitch and yaw offsets; FOV is absolute (`FOV +=` per frame accumulates). [Layering Camera Feedback on the Default Camera]
- **Blends:** 0.05 s for combat, 0.2 s for locomotion. Euler channels need wrapped deltas, and no key-to-key turn should be exactly 180°. [Animation Data Hygiene]

**Viewmodel moves**
- **Draw / inspect:** ~3 s. Anticipation → move → follow-through → hero pose → **end exactly on the rest pose** (no snap into idle). Cancel on any action. [Equip Draw and Flourish Systems]
- **Idle:** breathing on a 3-5 s cycle; fidgets after 10 s, then every 16-26 s, never twice the same. [Idle Breathing and Secondary Motion]

**Melee** [Locomotion and Melee Reference Numbers; Weapon Swing Design; Combat Animation Craft]
- **Light swing** at 30 fps: windup 3-5 frames, strike 2, active 2-3, follow 3-4, recovery 6-10.
- **Heavy swing** at 30 fps: windup 10-16, strike 2-3, active 3-5, follow 6-8, recovery 15-25.
- **Combos:** vary the planes (flat, diagonal, vertical finisher), and start each swing from the last one's pose. Cancel window near 70% of the recovery.
- **Trails / smears:** only between TrailOn and TrailOff; smears last 2-4 frames.
- **Blade vs blunt:** the blade's edge must lead. A bat has no edge: its face leads, and heavy weapons are driven from the hips and shoulders.
- **Hit-stop:** runtime only. Light 30-60 ms, heavy 80-150 ms; under 66 ms is unreliable on phones.

**Guns and hits**
- **First shots:** the first five shots must feel crisp (sound, recoil, marker). [Teardown - Phantom Forces]
- **Recoil:** pattern steps with jitter under 20%; recovery 0.6 of the pitch over 0.2-0.4 s. [Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]
- **Hit sound:** 0-30 ms after the visual; 20 ms early reads wrong, 80-150 ms late is mushy. [Feedback Timing - Sound Visual and Haptic Sync]
- **Damage numbers:** merge hits within 0.15 s, cap ~12 on screen; crits by size and colour. [Comfort Toggles]
- **Flashes:** at most 3 full-screen flashes a second; a hit-flash pool of up to 8 Highlights, 0.1 s fade. [Impact Frames; Hit Reactions Stagger and Hit-Stop]
- **Headshot:** a distinct marker and sound. [Gore Policy and Kid-Friendly Hit Feedback]
- **Not in the vault:** crosshair animation springs, head flare visuals, inertialization, camera-vs-weapon ratio.

## 3. First-person animation craft (web; [S] sourced, [I] inference, *weak* = forum or vendor)
The best primary source is Matt Boehm's GDC 2017 Overwatch first-person talk (full transcript read).

**Flow**
- **Gameplay first:** no visual noise, stay responsive, never cover the reticle [Boehm S].
- **All third-person craft applies:** overlap, overshoot, squash and stretch, snappy timing [Boehm S].
- **Don't start or arrive together:** the torso leads, the arm lags then snaps [Cooper, *12 principles in games* S]. Overshoot the extreme pose, hold key poses slightly longer, give each arm different timing (symmetry looks stiff) [Overwatch talk summary S]. Mirrored pose or timing ("twinning") reads "stiff and robotic" [Animation Mentor, moving hold S].
- **Readability** (Richard Lico, ex-Bungie) [80.lv S]:
  - a pose needs 5-8 frames at 30 fps (~170-270 ms) to be *seen*, but players feel motion as short as 2 frames;
  - use 2-3 strong key poses linked by moving holds, with a small jitter for emphasis;
  - **the barrel tip and the weapon's centre of mass paint arcs on screen: watch those.**
- **Arcs:** clean arcs read polished, but *all*-perfect arcs read floaty; break one on purpose for snap [Cooper S].
- **Camera:**
  - mostly translation from the root, with a small accent; avoid heavy roll (sickness) [Boehm S];
  - it **leads in melee and lags when firing** [Lico S]; save big camera moves for moments the player can't aim anyway (reload, melee, sprint) and use it as punctuation (a jolt when the mag seats) [Duffin GDC13 S].
- **Character:**
  - Overwatch tunes its spring sway per hero: McCree tight and leading, Zenyatta "flows and snaps", Roadhog loose [Boehm S];
  - heavier weapons move stiffer [Activision MW 2019 S];
  - never leave the hands static: shift the grip [80.lv S].

**Inspects and fidgets**
- **Structure:** a flavour idle that runs from the idle pose back to the idle pose [Halo 2 docs S]. Have several variants (CS:GO's butterfly knife has 3, *weak*), cancellable at any time.
- **Flips:** Respawn's animator filmed himself flipping a kunai with a phone in his mouth for first-person reference, then added "oomph" [Game Developer S]. In the air **the centre of mass follows a parabola while the object spins at a steady rate about it** [Rutgers physics S]. So a tossed knife leaves the hand with speed, spins about its balance point (not the grip) at a constant rate, and lands on the arc's end [I].
- **Catch:** the hand meets the knife moving its way, gives a little, overshoots, then settles in order: upper arm, forearm, hand. Stopping dead on the contact frame reads robotic [*weak*].
- **Show the blade** by turning its broad side ("adding English") [God of War animator, 80.lv S].
- **Why the second turn looks staged** [I], consistent with §1 and §4:
  - a dead hold before it; every part arriving on the same frame; one axis turning at a constant speed about the wrist; an end pose flat to the camera like a product shot.
  - Fixes: start with a forearm roll and let the knife follow 1-2 frames later; a small counter-turn first; ease into a ¾ angle, overshoot 5-10° and settle; keep drifting in the hold; nudge the camera toward the knife; give the second beat a different speed from the first (a slow look, then a quick flick), or motivate it with a toss.

**Melee: blade vs bat**
- **Attack anatomy** [Aztez S]: short wind-up; the swing itself ≤ 6 frames at 60 fps (~100 ms); attacker and target freeze a few frames on contact; then follow-through for weight. Long anticipation feels unresponsive; give control back before the follow-through ends [Cooper S].
- **Overwatch first-person melee** [Boehm S]: the weapon is off screen on frame 1, the hand comes on, **stretches on the contact frame (the 4th)**, snaps back, small hold; pushing the camera forward sells the impact.
- **Combos** [Halo 2 S]: hit 1 ends on a hold, hit 2 starts from that pose, hit 3 is the biggest and returns to idle; each hit has a quick return in case the chain breaks.
- **Body mechanics** [Cascadeur S]: wind up slowly, nearly stop, pass the energy into a fast weapon, recover slowly; or counter-rotate the body during the strike.
- **Blade:** light, snappy, few frames; hold the follow-through a little longer for weight [Slynyrd S]; the edge leads.
- **Bat (blunt):**
  - slower anticipation and recovery with held frames; too much recovery feels "sticky" [Slynyrd S];
  - baseball mechanics: the knob leads, the barrel lags then whips as the wrists uncock, the wrists roll over after contact, the finish is high over the shoulder [coaching sources];
  - in first person [I]: the bat head arrives late from the side, a longer hit-stop than the knife, a long follow-through off screen, the camera leading.

**Draw, equip, reload**
- Equip comes from off screen into the idle pose [Halo 2 S]. Valorant gives each gun a 2-3 beat equip and reload rhythm that tells you when you can fire ("see, but also listen"), handled like a trained professional [Riot S].
- **Reload:** one continuous move with empty and tactical versions [Activision S]; it may cheat in front of the face [Duffin S].
- **Revolver (Overwatch McCree)** [Boehm S]: the idle frame isn't exported; the first fire frame is stretched forward with the barrel scaled up, snaps back next frame, then rocks up. "A plain upward bang looks awkward." The recoil pulls back toward the player before kicking up [4Gamer S]. Reload beats [I]: flick the cylinder open → eject and speedloader → wrist-flick it shut and cock the hammer.

Sources:
- Boehm GDC 2017 (YouTube 7t0hLZd_8Z4)
- Wolfire GDC13 Animation Bootcamp summary (Duffin)
- 80.lv: "Animation in games: function and automation" (Lico); God of War attack tips; "Building crazy battle animations"
- Game Developer: Apex mouth cameras; Cooper, *12 principles of animation in video games*
- babel.speldesign.uu.se: Overwatch talk summary
- Microsoft: Halo 2 first-person animation docs
- Activision: MW 2019 animation blog
- aztez.com: "Anatomy of a successful attack"
- cascadeur.com: separation and compensation
- Animation Mentor: moving hold
- Rutgers: physics demo 268
- slynyrd.com: melee pixelblog
- playvalorant.com: arsenal dev post
- 4gamer.net: Overwatch interview
- invenglobal.com: Overwatch first-person animation

Gaps: nothing published on CS2 or Valorant knife-inspect craft, or on RIVALS / Arsenal / Phantom Forces viewmodels.

## 4. Smooth flow: springs, layers, curves, blending (web; [S] sourced, [I] inference)
**The main cause of "blocky / staged" in our build** [S Wikipedia "Monotone cubic interpolation"; I, high confidence]: PCHIP (Fritsch-Carlson) sets the tangent to **zero wherever a channel peaks at a key**. Every key that is an extreme becomes a dead stop, so motion goes stop-go-stop and reads pose-to-pose. Our keys are mostly poses (extremes), so this is the knife inspect's problem, and partly the slashes' recoveries.

**Fixes, best first:**
1. **Key the in-betweens, not the extremes,** and let overshoot come from a spring or a curve setting. Rosen (*Receiver*, GDC 2014) moves between 2-3-key stages with a spring-damper, because linear "continues to look bad", and keeps every transition interruptible. [S]
2. **Kochanek-Bartels tangents** [S Wikipedia]: tension, continuity and bias all 0 is Catmull-Rom. Bias > 0 overshoots past the key (follow-through), tension < 0 adds slack, continuity ≠ 0 makes a deliberate corner. Use [I]: snap keys (the strike's contact, a slam) monotone or continuity −0.3 to −0.6; breakdown keys bias +0.2 to +0.4.
3. **Holden's milder monotone rule** [S]: zero only where the signs differ, else clamp to 3× the smaller difference. It still stops at true extremes.
4. **Use the real time gaps** when computing tangents (ours already does). Centripetal Catmull-Rom (α 0.5) avoids cusps on spatial paths [S].
5. **Rotations:** spline in log space (`r(x) = exp(w1·d + w2·v0 + w3·v1)·r0`, `d = log(r1·r0⁻¹)`), always taking the short way (`quat_abs`); SQUAD isn't needed [S Holden "Cubic interpolation of quaternions"]. Ours already splines rotation vectors relative to each key. Euler per-axis is only acceptable for small turns.

**Moving holds** [S AnimSchool for the principle; I for the recipe built on Holden's extrapolation]
- **The principle:** a frozen hold reads dead and too much reads floaty. Drift follows the direction of the last momentum, with one position shift and one rotation shift.
- **Drift:** take the velocity from 2-3 frames before the end key (PCHIP makes the velocity at the key itself 0). Through the hold, add `x += (v/y)(1 − e^(−y·dt))`, `v *= e^(−y·dt)`, with `y = ln2/halflife` and a half-life of 0.08-0.15 s. Total drift = v·halflife/ln2. Let it spring back at ζ ≈ 0.7.
- **Idle noise:** 2-3 sines at frequencies that don't line up (e.g. 0.13, 0.31, 0.57 Hz) or Perlin; hip 0.2-0.4° and 0.003-0.008 studs, ×0.25 aimed. Breathing ~0.25 Hz, mostly pitch, 0.15-0.3°. Opsive puts Perlin on both weapon and camera [S].
- **Variety:** ±5-10% amplitude and ±1 frame timing per instance, so no two moves are identical [I].

**Layer stack** (each adds to the one below):
1. base keyed pose;
2. **inertialization** at cuts (before any additive or IK; Unreal users report bad blends when it runs after them [S]);
3. **secondary springs** on the final pose (Opsive keeps a primary movement spring separate from an impulse spring [S]);
4. noise and breathing (scaled down when aimed);
5. reactive kicks, as an impulse into their own spring;
6. the camera: separate and smaller (trauma² or ³ × Perlin [S Eiserloh]).

**Spring starting points** [I unless marked]:

| Spring | f | ζ | Notes |
|---|---|---|---|
| Aim sway | 1.5-2.5 Hz | 0.5-0.6 | clamp 4-6° |
| Strafe roll | 1-2 Hz | 0.7 | |
| Land | 3-5 Hz | 0.45 | |
| Kick recovery | 6-9 Hz | 0.35-0.5 | one visible overshoot |
| Arm follow | 5-8 Hz | 0.7-0.8 | |

- Smoothing half-life: 0.03-0.06 s on input, 0.05-0.08 s on ADS.
- **CryEngine recoil:** a spring-damper "like a car's suspension", force over 0.05 s, first shot 3.0 vs 0.5 after, randomness 0.1 [S].
- **Holden's conversions** [S]: damping = 4·ln2/halflife, stiffness = (2πf)², ζ = d/(2√s); frame-rate-safe damper `lerp(x, g, 1 − 2^(−dt/halflife))`; use the exact solutions, not Euler integration.

**Overlap without breaking contact timing** [I unless marked]
- Follow springs go only on *free* channels: blade-tip pitch and roll, the off-hand wrist. Contact channels (hand on handle, mag) stay keyed or locked.
- Lag rotation 1-3 frames behind position, and the tip behind the root.
- A spring tracking a moving goal lags ~2ζ/ω: about 37 ms at 6 Hz, ζ 0.7. Push the goal ahead by `v_goal × lag` (Holden's timed spring [S]), or fade the spring's weight to 0 over the 2-3 frames before a contact key.
- Holden's "perfect tracking spring" follows clean input exactly and only smooths jumps [S].

**Blending and cancelling**
- **Spring inertialization** [S Holden "Spring roll call"]: on a cut, `off_x = (src_x + off_x) − dst_x`, `off_v = (src_v + off_v) − dst_v`; each frame, decay the offset with the half-life spring and output `out = in + off`. Half-life 0.05-0.1 s [I]. It carries *velocity* through the cut; our `TRACK_BLEND` lerp does not.
- **Gears of War 4** (Bollo, SIGGRAPH 2017 / GDC 2018) [S]: a fifth-order curve matching the offset and its velocity, landing on zero with its starting acceleration capped so it can't overshoot. It cost 12 µs, against 30 µs for a normal crossfade.
- **Dead blending** [S]: extrapolate the old motion with decaying velocity and smoothstep to the new one over ~0.2 s.
- Every move must start from a valid pose [S].

**Other causes and fixes** [I]
- Every channel hits its key on the same frame: stagger channels 1-3 frames.
- Every move starts from rest: inertialize starts and cancels.
- The kick envelope is identical every shot with no settle: use an impulse into an underdamped spring, a bigger first shot, ±10% randomness.
- Frame-rate-dependent lerps: replace them with half-life dampers.
- Springs on everything: floaty; keep springs on secondary channels.
- No smear on fast moves: Roblox has no per-object motion blur; use a 1-2 frame stretch or a short Trail on the blade tip.

Sources:
- theorangeduck.com: spring-roll-call, dead-blending, cubic-interpolation-quaternions, perfect-tracking-springs, inertial-easing, propagating-velocities
- Bollo SIGGRAPH 2017 slides (history.siggraph.org)
- Unreal forums: inertialization
- Rosen, GDC 2014 (YouTube transcript)
- CryEngine recoil docs
- Opsive springs docs
- sreitich.github.io/fpp-animation
- AnimSchool blog (moving holds)
- Wikipedia: monotone cubic, Kochanek-Bartels, centripetal Catmull-Rom
- Eiserloh, GDC vault 1023146

Gaps: the Gears GDC 2018 slides and the Overwatch first-person talk (GDC Vault) couldn't be read.

## 5. Gun feel and hit feedback (web; [S] sourced, [I] inference)
**Shot feel**
- **Muzzle flash:**
  - each gun gets its own flash, matching its shape, use and power, with separate first-person and third-person versions [S Riot "How the VALORANT arsenal was built"];
  - a real flash lasts 1-2 frames, and short is punchier;
  - vary it: 4-8 random textures, optional layers (a flame on ~50% of shots), a random size step; mix a flash on the muzzle with a short-lived one left in the world; add a small light [S realtimevfx.com thread].
- **Timing:** tracers and flash appear on the first frame after the input and the shot is never delayed; hit effects wait for the server [S Riot "The state of hit registration"].
- **Camera shake:** trauma 0-1 that decays, visible shake = trauma² or ³ through Perlin noise, so small hits barely move the view [S Eiserloh GDC "Juicing your cameras"]. CS2 cut recoil camera shake back to CS:GO levels [S]. That matches the owner's still-camera clips.
- **Sound:** CS2 trimmed the start of the AK sound so back-to-back shots stay distinct, and ducks gunfire under body-hit sounds [S]. A study found hit-stop, matching sound and camera control mattered most for impact feel [S arXiv 2208.06155].
- **Readability:** quality settings must never change what players can read [S Riot "VALORANT shaders and gameplay clarity"].
- **Starting points per class** [I]:

| Class | Flash | Kick home |
|---|---|---|
| Pistol | 1 frame | ~110 ms |
| Revolver | 2 frames | ~200 ms, slight overshoot |
| Rifle | 1 frame, random textures | ~130 ms |
| SMG | 1 frame, smaller | ~90 ms |
| Sniper | 2 frames + a 300-500 ms smoke wisp | ~210 ms |
| Shotgun | 2-frame wide cone | ~180 ms |

- **Rule** [I]: a semi-auto's kick must be home before its next shot. Autos may stack, with a cap so the sight stays in its window.

**Hit markers and crosshair**
- **Size:** Overwatch scales its cross by the health actually taken, and players found that misleading (a killing headshot on a low-health target shows a small cross) [S Blizzard forums]. So keep markers a fixed size.
- **Valorant:** no crosshair marker at all, only in-world effects and sound, kept minimal so they don't distract [S].
- **Pros** turn off crosshair bloom and the fade while firing [S guides]. CS2's follow-recoil crosshair is off by default [S].
- **Marker recipe** [I]:
  - show it on server confirm;
  - pop to 1.2×, settle to 1.0 over ~50 ms, hold ~80 ms, fade ~120 ms (~250 ms total);
  - a new hit restarts it, never stacks;
  - headshot: a warm colour plus its own sound; kill: a different *shape* (thicker, or a ring ~400 ms).
- **Bloom** [I]: spread lines follow the real spread and recovery, with an ease-out; offer a static option.

**Headshot flare**
- **Valorant patch 1.07** [S]: a small client spark appears instantly at the hit point; the confirmed effect stays attached to the body part; the headshot effect was scaled down so players can track the target through it, especially at range.
- **A known misread** [S]: a body-shot effect just above a crouched head looked like a headshot.
- **Red is taken:** Riot's enemy highlight is red [S], so the flare shouldn't be.
- **Instant effects:** no wind-up, start at peak intensity, then fall off [S Jason Keyser, VFX Apprentice].
- **Flare recipe** [I], fitting the owner's 270 ms fan of rays:
  - frame 0: white-hot core;
  - 0-40 ms: the rays scale out;
  - 40-150 ms: white → yellow → orange;
  - 150-270 ms: the rays thin and fade.
  - Shapes: angled wedge rays, not blobs.
  - Size: clamped in pixels, with a minimum for range and a maximum of ~1.5× the head's width up close, so it never hides the next shot.
  - No red. A distinct headshot sound carries more than the visual.

**Damage numbers**
- **Apex** offers Stacking / Floating / Both, with gold or yellow headshots. **Fortnite** offers Cumulative / List, with yellow crits [S].
- **Accessibility** [S Xbox Accessibility Guidelines 103]: never colour alone, outlined high-contrast text.
- **Recipe** [I], matching the owner's clip (one adding-up number, then it tips over):
  - one counter per target, reset 1.0-1.2 s after the last hit or on the kill;
  - each hit pops it 1.0 → 1.3 → 1.0 in ~100 ms with a quick count-up;
  - on release it tilts 15-25° and falls with gravity, fading over 400-600 ms;
  - a headshot gets a bigger pop, orange, and a small mark beside it (so it isn't colour alone);
  - Sarpanch with a dark outline, beside the head, never on it;
  - settings: Off / Stacked / Per-hit.

Sources:
- playvalorant.com dev posts: "how-the-valorant-arsenal-was-built", "the-state-of-hit-registration", "patch notes 1.07"
- riotgames.com "VALORANT shaders and gameplay clarity"
- leagueoflegends.com "Clarity in League"
- realtimevfx.com muzzle-flash thread
- GDC vault 1023146 (Eiserloh, juicing cameras)
- Kotaku: the Overwatch hit sound
- Blizzard forums: hit-marker scaling
- Xbox Accessibility Guidelines 103
- arXiv 2208.06155
- vfxapprentice.com: timing in VFX

Pages that failed: PC Gamer's hit-marker pieces, Fortnite patch notes, CS2 shake news.

## 6. Looks good / looks bad (all four tracks agree)
| Looks good | Looks bad |
|---|---|
| Moving holds: drift, breath, a small jitter | Dead holds (everything under ~4°/s for 0.3 s or more): "mannequin", "staged" |
| Overlap: rotation trails position, the tip trails the fist, parts arrive 1-3 frames apart | Every part starting and arriving on the same frame (twinning) |
| Speed with a shape: a coil, a fast strike, a braking follow-through, overshoot and settle | Constant speed, or an ease into a full stop at every key (InOut chains, monotone splines through pose keys) |
| Clean arcs at the tip and the centre of mass, with one broken for snap | Straight-line moves between keys; *all*-perfect arcs (floaty) |
| Strong poses held ~170-270 ms, linked by fast moves | Poses held dead still, or too brief to read (< 2 frames) |
| The camera leads melee and lags fire, small, mostly translation | Heavy camera roll or shake every shot; the weapon bolted to the camera |
| A toss: a parabola, a constant spin about the balance point, a catch with give | Knife turning inside a closed fist; spinning about the grip; a dead stop on the catch |
| Cut-ins that carry velocity (inertialization) | Pops at transitions; every move starting from rest |
| Flashes of 1-2 frames, varied; markers a fixed size, restarting per hit; headshots and kills a different *shape*, not only colour | Long or laser flashes; markers that grow with damage or stack; colour-only cues; red flares clashing with the enemy colour |
| Sound on the frame (or 0-30 ms after) | Sound early, or 80-150 ms late (mushy) |

## 7. Checklist for this game (apply before every animation change)
1. **Key the in-betweens, not the poses.** Through `knife_fp_keys.py` and `ViewmodelTracks` `smooth`, a key that is an extreme stops dead (PCHIP). Put keys *through* the moment of passing, and let overshoot come from a spring layer or Kochanek-Bartels bias, or replace PCHIP's zero-at-extremes rule with Holden's clamp (§4). Re-run the speed-profile check: no dead stop unless intended.
2. **No hold is still.** In every hold (inspect, settle, idle), drift from the last momentum (half-life 0.08-0.15 s), then noise: 2-3 off-ratio sines, 0.2-0.4°, breathing ~0.25 Hz. Measure: the hold's angular speed should never sit under ~4°/s for 0.3 s or more.
3. **Overlap:** the fist leads, the knife's turn trails 1-3 frames (`SCREEN_LAG`), the free arm 0.05 s; roll before tilt (the RIVALS second turn, §1); never all channels on one frame.
4. **Contact stays exact:** follow springs only on free channels; fade them to 0 over the 2-3 frames before `hit`; hit-stop runtime only.
5. **A toss is physics:** a parabola for the balance point, a constant spin about it, the fist gives and settles on the catch (upper arm → forearm → fist).
6. **Cut-ins carry velocity:** replace the `TRACK_BLEND` lerp with spring inertialization (half-life 0.05-0.1 s).
7. **Melee:** coil → strike ≤ 6 frames at 60 fps → contact (stretch and hit-stop) → braking follow-through → settle past the hold. Vary the planes in a combo; each swing starts from the last one's pose. Bat: slower wind-up, a whip at the end, longer hit-stop and follow-through, the camera leading.
8. **Camera:** leads melee, lags fire, small; FOV punches tracked, not accumulated.
9. **Guns:** a 1-frame snap and a home inside the fire interval for semi-autos; a bigger first shot; ±10% variation; a 1-2 frame varied flash; the revolver's peak held ~50 ms with a pull back before the kick.
10. **Hits:** a fixed-size marker on confirm (pop 1.2× → 1.0, ~250 ms, restarts per hit); a different shape for headshot and kill; the head flare starts at its peak (white core), warms to orange by ~150 ms, gone by ~270 ms, clamped in size, never red, never hiding the head; an adding-up damage number that tips over and falls; sound 0-30 ms after the visual.
11. **Measure before showing:** speed profiles per frame, turn per step, arcs of the tip; a capture beside the clip's frame.
