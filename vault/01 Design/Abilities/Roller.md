# Roller (free pack)

**Status: built 2026-11-17, every level checked in Play** ([playtest](../../05%20Production/Playtests/2026-11-17%20Free%20Pack%20Build.md)). Spec: [2026-11-17 New Abilities (Free Pack)](../../04%20Tech/Prompts/2026-11-17%20New%20Abilities%20(Free%20Pack).md).

Damage, Placeable. **T** (slot 3).

## How it works
Hold T to take the bot out; LMB sets it down up to 9 studs ahead (the Placeable hologram, like Recall's) facing your aim, and it rolls off. It **turns at walls** (its heading reflects off the wall), climbs steps up to 1.6 studs and turns back from drops deeper than 6. Every 0.1 s it looks for the nearest enemy in sight within 25 studs inside a 60° cone ahead; found, it **locks on** (its eye lights, a chirp) and chases at the lock speed, turning up to 540°/s. Within 4 studs of them (or 2.5 s after the lock) it **warns** for 0.4 s (fast beeps, the eye blinks), stopping at their feet, then **explodes**: 60 at the centre → 30 at 6 studs, line of sight, none to you, 50% to your team, and Mod objects in the blast take 60. Nobody locked by the end of its time: it fizzles. It has 25 HP: shot down, it breaks with no blast.

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
- Blast look (`Util/BlastFx.roller`): a warm sparkle and glow, a soft light, a floor `FX_FloorStar`, the Shockwave mesh, an `FX_Ring` in team colour, sparks.
- Model: `Abilities.Roller` (Kind `placed`, pivot at the floor centre, nose to -Z): a low core, an angled nose plate with the eye slab, an angled back plate and fin, side skirts with a team stripe, octagonal wheels (two boxes each) with hubs. Studio-built 2026-11-17. Held small on the palm (`ITEM_HOLDS.Roller`, scale 1.4 of the 0.45 held size).

## Sound (placeholders: `Config/ModSounds` → `Roller`)
`equip`, `place`, `roll` (loop), `lock` ("Car Alarm Chirp 1"), `warn` (the chirp faster), `boom` ("Meaty Thud 7") + `boomBlast` ("Fire Whoosh 2"), `fizzle`, `destroyed` / `destroyedBreak`.

## Bots
`BotMods`: in a fight, or at where an enemy was last seen, 8-35 studs, half the time: set down 35° below the flat line toward them. Bots don't shoot Rollers yet (they only target characters): Bugs & Ideas.

## Counter-play
It's loud and its eye lights when it locks: shoot it (25 HP), break line of sight, or step back out of 6 studs while it beeps.
