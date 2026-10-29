# Updraft (was Launch Pad)

**Status:** spec locked 2026-10-28 · not built
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
| Shooting | **Gun stays up, you can shoot**, with the **normal in-air spread** penalty (no bonus) |
| Charges | **2 per round, no recharge, no cooldown** (unlimited in test mode) |
| Combos | Works with Dash (e.g. Updraft, then Dash forward in the air) |

## First person
- **Hand gesture:** the free hand flicks/pushes downward as you launch, Jett-style; the gun tilts slightly but stays ready.
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

## Mobile
Tapping the Updraft button launches you.

## Counter-play
You're in the air on a predictable arc with air spread: shoot the jumper.
