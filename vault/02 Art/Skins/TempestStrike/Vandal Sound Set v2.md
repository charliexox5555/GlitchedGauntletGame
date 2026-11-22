# Tempest-Strike Vandal: sound set v2 (audition)

2026-11-22. The owner's brief: "I honestly couldn't get a good Vandal shot sound, so using the Pro Sound library, layer sounds together well … work on Vandal sounds for all the sounds I need to create, and then if I approve them, then we can move on to the other guns." They also allowed downloading new sounds.

**Status (2026-11-22):** the owner approved the audition ("I like the sounds … get it in the game"). It's uploaded and wired in; the owner checks it in game next.

## Files
- **Builder:** `tools/audio/design_tempest_vandal.py`. Run it with `python -I tools/audio/design_tempest_vandal.py`.
- **Output:** `art-source/audio/tempest/vandal_v2/`. This folder is git-ignored because it's built from licensed library recordings, and the repo is public.
- **Reel:** `_reel.wav` (34 s), with `_reel.txt` timings.
- **Levels:** `_levels.json`.

## How each sound is built
The rules come from the [Vandal Sound Guide](Vandal%20Sound%20Guide.md) and the project's gun-audio rule: real recordings only, Valorant-style designed punch, no synth, no reverb on shots or clicks.

Every shot stacks five layers. Each layer is aligned to the core's onset, 0–1.2 ms after it:

| Layer | Source | Level | Band |
|---|---|---|---|
| Core | ProPack `gun_semi_auto_rifle_shot_0N` (the Vandal's current shot) | 0 dB | full |
| Crack | Pole Position AKM 7.62×39, 1 m mic (the Vandal's real-world gun), pitched 0.96–0.97 | −5.5 dB | 110 Hz–9 kHz |
| Action | Pole Position HK416 on-gun mic | −12 dB | high-passed 1.2 kHz |
| Water | one of the 10 loudest hits of the CC0 "Water Splashes" take, 85 ms | −11 dB | high-passed 650 Hz |
| Electric | one of 8 discharge snaps from CC0 "Electricity", 45 ms | −13 dB (every other take −19) | high-passed 2.5 kHz |

**Glue:**
1. A body-forward EQ: +6.5 dB low shelf at 90 Hz, a −5.5 dB dip at 1.3 kHz against honk, +3 dB presence at 3.3 kHz, +3.5 dB air.
2. Transient lift.
3. 4:1 compression.
4. Light saturation.
5. A tail hold.
6. Levelled to the stock shot's loudest 100 ms plus 0.8 dB, with a −1 dBTP ceiling.

**Measured against the stock shot:**
- **Band balance (shares of energy):** lows 0, low-mids −1.6, mids 0, presence +0.7, air −1 dB.
- **Attack:** 2 ms (stock: 6.8 ms).
- **Length:** a little longer.

The first build was 6 dB thin in the low-mids; that was fixed in the glue.

| Cue | Takes | Recipe |
|---|---|---|
| fire | 8 | as above |
| fireFirst | 1 | stock first shot, with a heavier, longer water layer and the snap on |
| fireLast | 1 | stock last-with-tail plus a quiet power-down under the tail (crackle fizzling, reversed-gather water draining) |
| tail | 1 | stock tail plus a faint static shimmer (−22 dB, high-passed 3.5 kHz) |
| fireFar | 4 | the finished shot with its skin layers pulled back, low-passed to 5 kHz, 2 dB down |
| dryFire | 3 | stock dry-fire click plus a tiny zap |
| magOut | 3 | stock unload click, a water burst on the same frame, a short static fizz tail |
| magForm | 1 | a reversed liquid gather rising into a bubble pop |
| magIn | 3 | stock seat click, a metal slide-lock clack, a wet splat, a stun-gun zap tail |
| rack | 3 | stock charging handle plus an electric chirp on the forward stroke |
| draw | 1 | a water swish, pipe-whoosh air, a short blade shing |
| drawLock | 1 | a metal click, a zap, a tiny splash |
| inspect / inspectRoll / inspectCatch | 1 each | a swirl with a safety-switch tick and a thread of static; a water woosh with crackle; a squish with a click and a spark |
| aimIn | 1 | a quiet high water swish |
| reloadSpin | 1 | a quick water woosh over an electric hum |
| impact | 4 | a tiny splash plus a zap, quiet (under the surface sound) |

**Handling levels:** each handling cue is levelled to the stock slice it replaces. Designed cues sit about 1 dB over theirs; pure skin cues sit near the earlier Tempest cue levels.

## Sources and licences
- **Sonniss GDC 2016 bundle:** Pole Position AKM and HK416. Free for commercial games, no attribution (licence v2.0). Kept in `art-source/audio/library/`, never committed.
- **ProPack:** the game's own pro gun pack.
- **CC0 recordings:** all from Freesound, each licence checked on its sound page by `tools/audio/fetch_audio.py`. They're listed in [Tempest Audio](Tempest%20Audio.md) → Sources, including 15 new ones added on 2026-11-22.

## Audition (owner)
Play `_reel.wav` and follow `_reel.txt`. It runs in this order:
1. Stock taps, then new taps.
2. A stock 10-round spray, then a new one at the Vandal's fire rate.
3. The last round and a dry fire.
4. The far version.
5. Every handling cue.

For feedback, say per cue: keep, louder or quieter, more or less water, more or less electric, or more weight.

**After approval:**
1. Upload each file solo; no atlases.
2. Route the Tempest Vandal's shots and handling through `Config/TempestAudio` and `GunSounds`, the same way Ruin-Blighted's own shots are routed.
3. Build the same set for Stinger, Marshal, Bucky and Sheriff.

## In the game (2026-11-22)
The owner said the first shot "just sounds like the regular shot". Before upload, the skin layers were raised a little:
- water: −9 dB (was −11);
- electric snap: −11.5 dB, or −15 dB on alternate takes (was −13 / −19);
- the first shot's water: −6 dB.

**Uploads:** every file is its own Audio asset (39 uploads, no atlases). The IDs are in `Config/TempestAudio` (`takes`) and `art-source/uploads.json`.

**Routing:**

| What | Where | Sound |
|---|---|---|
| Own shots (2D) | `Util/GunAudio` `tempest` option, from `WeaponController` when the camera gun wears the line (`ViewmodelController.hasTempest`) | `vFire` 8 takes, `vFireFirst`, `vFireLast` with its own tail, `vTail` faded by the next shot |
| Other players' shots (3D) | `EffectsController` reads their gun model's SkinLine (`skinLineOf`) | `vFireFar` plus the stock tail |
| Handling | `WeaponController.playGun` overrides the gun sounds | `vMagOut`, `vMagIn`, `vRack`, `vDryFire`; each already holds the stock click, so the old Tempest `magOut` / `magSeat` cues are off for the Vandal (`TempestProfiles` `ownFoley`) |
| Skin cues | `TempestIdle` / `TempestKatana` | `draw`, `drawLock`, `aimIn`, `inspect`, `inspectRoll`, `inspectCatch`, `magForm`, `reloadSpin` (v2 files) |
| Own wall hits | `EffectsController.localWallImpact` | `vImpact`, quiet, under the surface sound |

**Levels** follow the stock Vandal's:
- report 1.34;
- tail 2.14;
- far 1.21;
- foley 0.91.

All tunable in `Config/TempestAudio`.

## Inspect: now electric and on the move's moments (2026-11-22)
The owner said the set was "solid, except for the inspect": replace the water with electric, and line the cues up with the animation. The v2 water inspect cues are replaced by the electric set, which plays on the tempestInspect timeline.

See [Line Sound Sets](Line%20Sound%20Sets.md) for the cues and their times.

