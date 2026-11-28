# Power sounds: Smoke and Electric Shock (2026-11-27)

New cues for the two battle pass powers, replacing the generic library placeholders the owner didn't like. Built by `tools/audio/design_powers.py` the Arcade way: licensed recordings (ProPack, Sonniss GDC 2016; royalty-free for the game, never redistributed) layered with our own synthesis. 48 kHz mono, normalized to -0.8 dBFS (loops -3 dBFS). Outputs `art-source/audio/powers/` (git-ignored); audition `_Reel.wav` + `_Reel.txt` (loops play twice so the seam can be heard). Uploaded to group 11116787; ids also in `art-source/audio/powers/ids.json`. **Unauditioned by the owner.**

## Smoke
| Cue | Length | Layers | Asset id |
|---|---|---|---|
| smoke_equip | 0.25 s | ProPack gear grab, metal tick, a tiny valve hiss | 101935654980168 |
| smoke_pin | 0.23 s | ProPack metal pull + a two-tone ring | 79594259801062 |
| smoke_throw | 0.40 s | SoundBits rod whoosh, pitched up | 106804208488163 |
| smoke_bounce | 0.25 s | ProPack sheet-metal clink (tight decay) + canister ring | 110046631197699 |
| smoke_pop | 1.40 s | aerosol "pfsshh" (Kevin Durr hairspray), an air chuff (JC Sound), a synth noise burst, a sub whump, an airy bloom tail | 104298404322375 |
| smoke_loop | 4.00 s loop | filtered noise in slow rolling swells, crossfaded seamless | 99862269286591 |
| smoke_fade | 1.20 s | a soft dissipating exhale (filtered noise) | 71521032542266 |

## Electric Shock (the legendary smite)
| Cue | Length | Layers | Asset id |
|---|---|---|---|
| shock_equip | 0.50 s | ShapingWaves electric buzz sped up as it arms, noise riser, crackle, a snap at the top | 97739926489588 |
| shock_throw | 0.45 s | rod whoosh + SoundMorph energy-gun zap + crackle tail | 75507586897589 |
| shock_flight | 2.00 s loop | electric buzz + modulated hum + crackle | 130377876115693 |
| shock_beacon | 2.00 s loop | the same, lower and slower: a charged hum | 98083541993391 |
| shock_latch | 0.64 s | a hard synth crack, energy hit, rising two-tone whine, crackle | 90182350448197 |
| shock_warning | 0.70 s | for the marked player: a rising sky drone, static build, rising tone, crackle, all swelling | 104640240744110 |
| shock_charge | 0.90 s | the storm gathering: low rumble + crackle + rising sweep, building to its end (play it 0.9 s before the strike) | 123995347013332 |
| shock_strike | 3.60 s | THE SMITE: two synth thunder cracks (razor transients), a sub sweep 85→28 Hz + thump, SoundMorph INTERVENTION explosive sweetener, Bottle Rocket distorted boom, SIGNUM sci-fi impact, a dense sizzle, Kopeikin vaporizing crackle, rolling thunder (synth rumble + MatiasMacSD thunder drum) with two late rolls; soft-limited | 104561703314523 |
| shock_chain | 0.60 s | a crack, a dense arc crackle, a pitched-up energy zap | 114941522983814 |
| shock_storm_bolt | 1.50 s | a smaller crack + sub + rumble + SIGNUM, bit-crushed and stuttered (glitched) | 83468006084538 |
| shock_fizzle | 0.60 s | thinning sparks + a falling pop | 99436252023193 |
