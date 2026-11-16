# Roller (free pack)

**Status: built 2026-11-17, every level checked in Play** ([playtest](../../05%20Production/Playtests/2026-11-17%20Free%20Pack%20Build.md)). Spec: [2026-11-17 New Abilities (Free Pack)](../../04%20Tech/Prompts/2026-11-17%20New%20Abilities%20(Free%20Pack).md).

Damage, Placeable. **T** (slot 3).

## How it works
Hold T to take the bot out; LMB sets it down up to 9 studs ahead (the Placeable hologram, like Recall's) facing your aim, and it rolls off. It **turns at walls** (its heading reflects off the wall), climbs steps up to 1.6 studs and turns back from drops deeper than 6. Every 0.1 s it looks for the nearest enemy in sight within 25 studs inside a 60° cone ahead; found, it **locks on** (its eye lights, a chirp) and chases at the lock speed, turning up to 540°/s. Within 4 studs of them (or 2.5 s after the lock) it **warns** for 0.4 s (fast beeps, the eye blinks), stopping at their feet, then **explodes**: 60 at the centre → 30 at 6 studs, line of sight, none to you, 50% to your team, and Mod objects in the blast take 60. Nobody locked by the end of its time: it fizzles. It has 25 HP: shot down by the other team (its own team can't hurt it), it breaks with no blast. Because it moves, shots on it get 3 studs of extra slack on its box (`Combat.MOVING_OBJECT_TOLERANCE`, the part's `Moving` attribute): the shooter sees it a ping behind the server.

| | L1 |
|---|---|
| Charges | 1 per round, no recharge |
| Speed | 14 studs/s, 22 locked |
| Rolls | 5 s |
| Lock-on | 25 studs, 60° cone, line of sight |
| Blast | 60 → 30 over 6 studs |
| HP | 25 |

| Level | Effect |
|---|---|
| A2 More Bots | 2 a round (2 out at once) |
| A3 More Bots | 4 a round (2 out at once) |
| B2 Faster | 17.5 studs/s (27.5 locked), 7 s |
| B3 Faster | 21 studs/s (33 locked), 10 s |
| G2 Remote ⚡ | press T again while it rolls: it blows up there (no charge spent); it still seeks on its own |
| G3 Remote ⚡ | + recharges in 7 s, 17.5 studs/s, 7 s |

**Two calls made in the build (2026-11-17), not in the spec:** the spec's "0.4 s warning after lock-on" would blow up ~16 studs short of a target 25 studs away, so the warning starts within `trigger` (4) studs of the target or `chase` (2.5) s after the lock; and it stops at their feet (it used to roll through them before the blast).

## Built
- Server: `src/shared/Mods/Roller.luau`. The bot is an anchored, queryable Mod object (`ModEntities`, Kind `Roller`, its own end decides: the object's life is only a backstop) moved every Heartbeat by the module (one connection, `module.server`). Attributes on the part: `LockedAt`, `WarnAt` (server time), `Remote`. ModFx `RollerPlaced`, `RollerLock`, `RollerBoom` (`at`, `radius`, `hits`), `RollerFizzle`; a shot-down bot is ObjectGone `Broken`.
- Remote: a new remote **`ModTrigger(slot)`** (ModService `onTrigger`: rate 4/s burst 6, slot integer, a built Mod with a `trigger` hook, Mods on, alive, not stunned). The Mod's `trigger` acts only on the bots the server is tracking for that player. The client sends it on a press of the Roller's key while one of its Rollers is in `ModObjects` and the level is Remote.
- Client (`Util/RollerFx`): the finished model follows the server part (eased at 22/s, leading by a frame of its speed); wheels turn with the distance drawn; the eye dim → lit → blinking; its own looping hum. Placed parts with Kind `Roller` go there instead of the static dressing (`ModFxController.colourObject`).
- Blast look v2 (`Util/BlastFx.roller`, 2026-11-17, owner: "like the Boom Bot... like fire"): **a fireball**: a hot gold-white star and glow, a crown of twelve fire tongues from the rework kit (hot gold inside standing tall, orange-red outside leaning out) bursting up and falling back, the Shockwave over the floor, the team ring at the true radius, embers.
- Model v2 (2026-11-17, owner's interview picks "two big wheels", "charcoal + fire glow"): Blender, `tools/blender/freepack/fp_roller.py`, source `art-source/abilities/FreePack/v01/Roller.blend`, asset 104263335929579, 2,128 tris, audit clean (0 overlap, floating or coplanar). A cheeky bot slung between two big 12-facet wheels (tyres with raised lugs, stepped hubs, caps): a faceted charcoal pod, a dark visor with two slanted **fire eyes** (`Eye*_Fire`, keep their orange), fire vents on top, a yellow and black hazard chin and back panel, an antenna with the **team light** on top (`Light_Energy`). `RollerFx` turns each wheel's parts about its own axle. Held small on the palm (`ITEM_HOLDS.Roller`).

## Sound (placeholders: `Config/ModSounds` → `Roller`)
`equip`, `place`, `roll` (loop), `lock` ("Car Alarm Chirp 1"), `warn` (the chirp faster), `boom` "Dirt Explosion 1" (sharp bang) + `boomBlast` "Gas Fire Explosion 2" (the fireball, 2026-11-17), `fizzle`, `destroyed` / `destroyedBreak`.

## Bots
`BotMods`: in a fight, or at where an enemy was last seen, 8-35 studs, half the time: set down 35° below the flat line toward them. Bots don't shoot Rollers yet (they only target characters): Bugs & Ideas.

## Counter-play
It's loud and its eye lights when it locks: shoot it (25 HP), break line of sight, or step back out of 6 studs while it beeps.
