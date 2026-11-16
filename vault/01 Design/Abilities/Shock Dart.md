# Shock Dart (free pack)

**Status: built 2026-11-17, every level checked in Play** ([playtest](../../05%20Production/Playtests/2026-11-17%20Free%20Pack%20Build.md)). Spec: [2026-11-17 New Abilities (Free Pack)](../../04%20Tech/Prompts/2026-11-17%20New%20Abilities%20(Free%20Pack).md).

Damage, Projectile. **E** (slot 2), like Recon: the same bow, so you never hold both.

## How it works
Recon's bow and controls exactly: hold LMB to charge (1 s to full: 45 → 130 studs/s), RMB picks 0 / 1 / 2 wall bounces, release to fire. The bolt flies Recon's path (`Recon.launch` / `Recon.options`), and **explodes where it comes to rest** (or where its 3 s flight runs out). Everyone within the radius the impact can see takes damage falling from the centre to the edge. None to you; 50% (`FRIENDLY_FIRE`) to your team. Mod objects in the blast (an enemy Recon dart, a Roller) take the centre damage.

| | L1 |
|---|---|
| Charges | 1 per round, no recharge |
| Blast | 50 at the centre → 25 at 5 studs, line of sight from the impact (pulled 0.4 studs off the surface) |
| Distance | the nearer of the chest and the root to the impact |

| Level | Effect |
|---|---|
| A2 Recharge | back 15 s after use |
| A3 Recharge | back 6 s after use |
| B2 More Darts | 2 darts, 42 → 21 |
| B3 More Darts | 4 darts, 36 → 18 |
| G2 Static ⚡ | no damage: Hinder 2 s on everyone in the radius but you; recharges in 15 s |
| G3 Static ⚡ | Hinder 3 s in a 7-stud radius |

## Built
- Server: `src/shared/Mods/ShockDart.luau` (validate clamps the charge to the server's hold time, like Recon). Blast data: ModFx `ShockThrow` (the path) and `ShockBurst` (`at`, surface `normal`, `radius`, `static`, `hits`).
- First person: `ITEM_HOLDS.ShockDart` = Recon's hold; the bow rig (`VM.BOW`) draws it. Sounds per bow Mod (`ModController.bowSounds`).
- Model: `ReplicatedStorage.Abilities.ShockDart` (Recon's bow with an amber `Charge_Energy`, `OwnColour = true`, and a shock head: four splayed prongs with amber tips and a diamond coil, all `Dart_*` so they slide with the nock) and `Abilities.ShockBolt` (the flying bolt, same head). Built in Studio from Recon's installed models (2026-11-17); no Blender source yet.
- Look (`Util/BlastFx.shock`): beat 1 a white `FX_FloorStar` flat on the surface it hit, a four-point sparkle and a light; beat 2 six jagged `FX_Stroke` arcs (light electric blue) snapping to new paths 24 times a second; beat 3 an `FX_Ring` and a `MOD_RING` in team colour at the edge, sparks. Static: ice-white arcs, dashed ring, the arcs' first two frames magenta (the glitch accent).

## Sound (placeholders, unauditioned: `Config/ModSounds` → `ShockDart`)
Bow cues are Recon's ids, pitched up a little. `burst` "Static Zap Blast 2", `burstCrack` "Lightning Flashes Quick Electrical Bursts 56", `static` (G) "Static Zap Mix Reverberant Bursts 3".

## Bots
`BotMods`: in a fight, 10-60 studs, half the time: fired straight at their feet.

## Counter-play
Watch for the amber bow; the bolt is fast but visible (its streak); step out of 5 studs or put a wall between you and the impact.
