# Updraft (was Launch Pad)

**Status:** spec locked 2026-10-28 · built 2026-10-29 (tested by the user in Studio)
**Inspiration:** Jett's Updraft (Valorant). An instant launch straight up, for yourself only. **No pad, nothing placed:** remove the Launch Pad placeable.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Activation | **Instant on press**, no wind-up |
| Effect | Launches you **straight up**, peaking **~14 studs** above where you used it (about 2× a normal jump). Derive the launch speed from `Workspace.Gravity` so the peak stays 14 studs (≈ 74 studs/s at the default 196.2) |
| Horizontal speed | Keep your current horizontal momentum (running + Updraft = an arc) |
| Mid-air | **Yes, like a double jump:** it resets your fall and launches you up again |
| After the peak | **Normal fall**. No glide, no hover |
| Shooting | **Gun goes down while you rise** (no shooting for `gunDown` 0.35 s, like Dash), then comes back up near the peak; normal in-air spread after (changed 2026-10-29, the user's feedback) |
| Charges | **1 per round, no recharge, no cooldown** (unlimited in test mode). Was 2; lowered 2026-11-03 so the upgrade path can add charges ([Upgrade Paths](Upgrade%20Paths.md)) |
| Combos | Works with Dash (e.g. Updraft, then Dash forward in the air) |

## First person
- **Hand gesture:** the free hand flicks/pushes downward as you launch, Jett-style; the gun drops out of view while you rise and swings back up near the peak (like Dash).
- **Screen edge:** wind rushing up the sides and off the bottom of the screen while you rise, fading out by the peak.
- **Camera kick + FOV:** a quick upward camera lurch and a small FOV punch, so it feels like a real launch.

## What others see
- A **wind burst at your feet** where you launched (a swirl/puff of air and dust): a clear tell for enemies.
- A **short wind trail under you while rising** (team-tinted like Dash).

## Sound
Hooks **plus placeholder sounds** (pick temporary ones from Roblox's free licensed audio so it isn't silent while testing; the user replaces them later):
| Hook | What |
|---|---|
| `Updraft_Launch` | The launch whoosh/burst (first person) |
| `Updraft_Wind` | A wind loop while rising |
| `Updraft_Land` | The landing |
| `Updraft_World` | The 3D launch sound others hear, ~40 studs |

### Placeholder sounds (in `Config/ModSounds` → `Updraft`; unauditioned, swap the id)
All ProSoundEffects library audio (public, no upload). Search terms that worked: quoted phrases such as `"Air Blast"`, `"Wind Constant"`, `"Airy Whoosh"`, `"Foot Stomp"`, `"Jump Land"`.
| Hook | Id | Name | Volume / pitch | Alternatives |
|---|---|---|---|---|
| `Updraft_Launch` | 9125577266 | Giant Air Blast Low Bursts Pound Many Versions 5 (from 0.2 s, 0.65 s long) | 0.7 / 1.05 | 9125577719, 9113080525 |
| `Updraft_Wind` | 9125742111 | Plasma Trails Constant Airy Whooshing Windy 1 (loop from 2.8 s) | 0.35 / 1.0 | 9120610020, 9116432106 |
| `Updraft_Land` | 9113472118 | Body Fall Master 10 (cut at 0.35 s) | 0.5 / 1.1 | 9113524237, 9114523636 |
| `Updraft_World` | 9125577419 | Giant Air Blast … Many Versions 7 (3D, 40 studs, from 0.2 s) | 1.0 / 0.95 | 9125577249, 9125356094 |

No steady 1–4 s wind loop exists in the library; the wind pick is a long steady file started at its steady part.

## Build notes (2026-10-29)
- **Removed:** the Launch Pad (its module, placement, pad visuals, pad sounds). `ReplicatedStorage.Abilities.LaunchPad` (Studio) is now unused.
- **Rules:** `Mods/Updraft` (predicted, like Dash). Launch speed `sqrt(2 · Gravity · peak)`, `Config/Mods` Updraft L1 `peak` 14; the rise is held for 0.2 s while the Humanoid leaves the floor. Running speed is carried through the air up to `maxCarry` 24 (a slide-jump's); a dash's speed isn't (capped to the dash's exit speed). Measured in Studio: peak 13.8 studs from the ground, +14 from a mid-air launch.
- **First person:** free-hand flick down (`Config/Viewmodel MOD_GESTURES.UpdraftDown`), a small gun tilt (`UPDRAFT_TILT`; the gun stays ready), camera lurch up + FOV +6 (`Config/Mods UPDRAFT_FEEL`).
- **Others see:** `Util/WindFx`: a gust ring flat on the ground and dust at the feet, a trail under you while rising (Dash's wind textures), and a knees-tuck clip `GG_Updraft` (ids in `Config/Animations MODS`).
- **Icon:** still the Launch Pad's until Updraft gets its own.


## Changes from the user's feedback (2026-10-29)
- **Gun down while rising:** `Config/Mods` Updraft L1 `gunDown` 0.35. The simulation writes `UpdraftGunDown`; the Dash gun gate (`Mods/Dash.stepGate`) holds shots on both sides for that long after `UpdraftAt` (no Dash Focus after it). First person: `Config/Viewmodel UPDRAFT_DIP` (replaces the small tilt). Verified: an auto rifle held on fire stops for ~0.33 s, then fires again; the gun is out of view from ~0.1 to 0.35 s.
- **Screen edge:** Blender texture `tools/vfx/make_updraft_vfx.py` → `art-source/vfx/abilities/updraft/updraft_edge.png` (`VfxTextures.UPDRAFT_EDGE`, preview in `vault/02 Art/References/abilities/updraft/`), drawn by `ModFeelController`: in over 0.06 s, sliding down the screen as you rise, gone by the peak.

## Mobile
Tapping the Updraft button launches you.

## Counter-play
You're in the air on a predictable arc with air spread: shoot the jumper.

## Upgrades (L2/L3)
Decided 2026-11-03 in [Upgrade Paths](Upgrade%20Paths.md) → 2. Updraft (the numbers there are the user's; they live in `Config/Mods` Updraft). Built 2026-11-03, **not yet playtested in Studio**.

| Level | Card text (`note`) | What the code does |
|---|---|---|
| A2 High Rise | Launch 50% higher, about 21 studs | `peak` 21: launch speed ≈ 91 studs/s at gravity 196.2 |
| A3 High Rise | Launch twice as high, about 28 studs | `peak` 28: ≈ 105 studs/s, rise ≈ 0.53 s (L1 ≈ 0.38 s) |
| B2 Second Wind | 2 Updrafts every round | `charges` 2 |
| B3 Second Wind | 3 Updrafts every round | `charges` 3 (the HUD has 3 pips) |
| G2 Crash Down ⚡ | Crouch mid-air to slam, 30 damage within 8 studs | below |
| G3 Crash Down ⚡ | 45 damage, Hinders for 1 s, 2 Updrafts a round | `slamDamage` 45, `slamHinder` 1, `charges` 2 |

**Path names** (proposed; Upgrade Paths.md still says Height / Charges / Slam): *High Rise*, *Second Wind* (an extra breath of air, the wind theme), *Crash Down* (a crash is the glitch theme: the slam is a corrupted packet hitting the floor).

### Height at 28 studs (checked in code)
- **Gun-down stays 0.35 s** at every height: it's the cost of using it, not a tax on height. At A3 the gun is back about 21 studs up, so you can shoot over cover from the top of the rise (that's the point of the path).
- The rise hold (0.2 s) still clears the floor at 105 studs/s. The screen-edge wind and the wind loop already last as long as the rise (they read `UpdraftUp / UpdraftGravity`). The camera lurch and FOV punch are fixed-time punches, so they don't need scaling.
- Running speed carried (`maxCarry` 24) over ~1.07 s of air at A3 is ~26 studs of drift (L1 ~18): still a predictable arc.

### Crash Down (the slam): how it works
- **Input:** a **new** Crouch press (C / Left Ctrl / B / the slide button) while an Updraft is in the air. Holding crouch from a slide into the launch doesn't count. A press in the first `slamArm` 0.15 s after the launch waits until then (~9 studs up at L1), so you can't slam the spot you launched from.
- **Movement:** straight down at `slamSpeed` 90 studs/s, no steering, no carried run speed (a Dash mid-slam still pushes you sideways). A second Updraft (G3 has 2) mid-slam cancels it into a new launch. No slide starts: the press is in the air, and the landing doesn't count as a new press.
- **Landing:** enemies whose root is within `slamRadius` 8 studs of yours, with a clear line from you to their chest or head, take `slamDamage` (kill feed: Updraft). G3 also Hinders them for `slamHinder` 1 s. No self or team damage.
- **Code:** `Mods/Updraft.step` (predicted in the simulation) writes `UpdraftSlamQueued`, `UpdraftSlamming`, `UpdraftSlamStart`, and on landing `UpdraftSlamPos` + `UpdraftSlamAt`. `module.server` (ModService's hook) watches every character's `UpdraftSlamAt` (the server's own simulation), re-checks the level on the server, deals the damage, then fires ModFx `UpdraftSlam` { at, radius, hits, hinder }.

### Crash Down: look and sound (`Util/UpgradeFx/Updraft`)
- **The dive (everyone):** a bright streak above you with a magenta slice that hops sideways (a tearing frame), magenta voxel static flickering round your body, and a dashed ring on the floor below you that closes in to the 8-stud radius as you fall. **Enemies see it orange-red and pulsing** (the danger read: get out of the ring); you and your team see it cyan and calm. Enemies hear a falling whoosh at you (3D, 60 studs).
- **The impact:** a small hot flash (2 frames), a shockwave ring out to the radius (plus the Blender Shockwave mesh when installed), a magenta dashed ring that jumps out in three skipped frames, a hex "corrupted floor" patch that holds 0.65 s, dust thrown out flat, chips kicked up, magenta voxel static scattered over the area, one short light. Ours draws on our own predicted landing; others' come from the server's ModFx.
- **Caster camera:** FOV push +5 on the dive; on landing a shake (0.7°), FOV squeeze −7 and a 1.2° nod down that comes back.
- **Sounds** (`Config/ModSounds` → `Updraft`, ProSoundEffects placeholders, unauditioned):

| Hook | Id | Name | Who |
|---|---|---|---|
| `Updraft_SlamDive` | 9114373678 | Fast Pass By Airy Whooshes Windy 4 (pitch 0.75, cut 0.5 s) | you |
| `Updraft_SlamDiveWorld` | 9114373678 | the same, pitch 0.7, 60 studs | everyone else, 3D |
| `Updraft_SlamImpact` | 9116488211 | Meaty Thud 7 (pitch 0.85, cut 0.9 s) | you 2D, others 3D 80 studs |
| `Updraft_SlamGlitch` | 9125625388 | Layered Rips High End Short Energy Bursts Spark 3 (cut 0.6 s) | you 2D, others 3D 60 studs |

### Playtest checklist (Studio)
- A3: peak ≈ 28 studs from the ground; gun back up before the peak; edge and wind loop last the whole rise.
- B3: 3 pips, 3 launches, empty after; refilled at round start.
- G2: Updraft, press C at the top → straight drop, 30 damage to a dummy within 8 studs, none behind a wall, none to a teammate or yourself.
- G2: hold C while sliding, press Q → no slam (needs a new press). Tap C right after Q → the slam starts ~0.15 s in, not on the spot.
- G2: landing with C still held → crouch, no slide; let go → normal.
- G3: 45 damage and Hinder 1 s; 2 charges; Updraft again mid-slam → new launch, no slam damage.
- Two clients: the enemy sees the orange-red pulsing ring under the slammer and hears the dive; the caster's impact plays at once, others' within ping.
