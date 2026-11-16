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
- Look v2 (`Util/BlastFx.shock`, 2026-11-17, owner: "it doesn't look like there's a radius... have fun animations"): beat 1 **a bolt cracks down from 9 studs above** onto the impact, a white `FX_FloorStar` on the surface (the server now sends the surface normal), a sparkle and a light; beat 2 **the area at its true size, held about 0.5 s**: an electric dome (`Scan_Shell`) and a lit floor disc filling the radius, the edge ring in team colour, arcs crawling over the whole area on held frames, **an arc jumping to everyone it hit** (`struck` positions in the ModFx); beat 3 sparks. Static: ice-white, dashed edge, magenta first two frames.
- Bow v2 (2026-11-17): the owner's Sova reference (playtest note, round 2): big, canted, right of centre, the draw pulling down-right; thin light strings and a steel shaft; the bolt head glows and sparks as it's drawn.

## Sound (placeholders, unauditioned: `Config/ModSounds` → `ShockDart`)
Bow cues are Recon's ids, pitched up a little. The blast (2026-11-17): `burstCrack` "Synth Thunder Cracks Individual Explosion Booms 5" pitched up (the strike) + `burst` "Static Zap Blast 2" + `crackle` "Tesla Coil 2" (the field); `static` (G) "Static Zap Mix Reverberant Bursts 3".

## Bots
`BotMods`: in a fight, 10-60 studs, half the time: fired straight at their feet.

## Counter-play
Watch for the amber bow; the bolt is fast but visible (its streak); step out of 5 studs or put a wall between you and the impact.
