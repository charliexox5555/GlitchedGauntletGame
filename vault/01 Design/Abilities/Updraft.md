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
| Charges | **2 per round, no recharge, no cooldown** (unlimited in test mode) |
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
