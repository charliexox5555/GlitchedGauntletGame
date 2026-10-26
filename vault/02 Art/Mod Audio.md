# Mod Audio: L1 sound shortlist

> **Status: PROPOSAL, waiting for the user's approval (2026-10-26).** Nothing is uploaded or wired in. Audition the candidate ids in Studio's Toolbox (Creator Store → Audio, paste the id), pick per cue, then the code session wires the approved ones into `Config` and the synth cues go into the next sound atlas.
> Design: [Mods](../01%20Design/Mods.md) · audio rules: [Art Direction](Art%20Direction.md) → Audio · synth presets: `tools/audio/mod_sfx.py`

## Rules this list follows
- **Only Roblox-licensed sources:** ProSoundEffects (PSE, user 7462895450), Audioscape (group 34159607) and Roblox's own uploads (user 1). Every id below was checked on 2026-10-26 against the Creator Store API (`toolbox-service` item details): it exists, is free, the creator is one of those three and the title matches. PSE lengths are exact (from the asset description); Roblox and Audioscape only report whole seconds, so those show "~". **No id was auditioned by ear** (Claude can't listen): that's the user's step.
- No gunshots from other uploaders, no layered synth gunshots (both banned). Synth is used only for crisp digital cues: UI pings, Ping, Overclock, Rollback, fuse beeps and loops.
- **Valorant-style readability:** each Mod has its own sound family, so an enemy can name it by ear:

| Mod | Sound family (what makes it recognisable) |
|---|---|
| Blink | Airy digital **zip** |
| Launch Pad | Low **air blast** + rising hiss |
| Packet | Metal **clink**, accelerating **beeps**, boom |
| Firewall | Glassy **power-up**, force-field hum, glass shatter |
| Lag Field | **Pitch dropping**, warbly slowed-tape drone |
| Ping | Pure **sonar** sine ping |
| Patch Up | Bright **major-chord** sparkle |
| Overclock | Buzzing **saw whine** with fast vibrato |
| Rollback | **VHS rewind** chirps + crushed digital snap |

- **Who hears what:** "You" = the caster (2D). "All 3D" = played at the source for everyone in range (enemies hear it positioned, with the Enemy SoundGroup EQ, the same way gun `_Far` works). "Enemy 2D" = a separate warning clip only for the enemy it targets, so caster and victim never hear the same thing.
- **Synth** rows name an atlas slice (`ModReady`, …) made by `tools/audio/mod_sfx.py`; a library alternative is listed for each in case the user prefers a recording.
- Long library clips (the 18–36 s "Constant" ones) are loops: play them `Looped` and fade out. For clips with tails longer than the cue, the player uses a `PlaybackRegion` or fades early.

---

## 1. Blink (instant dash)
| Cue | Heard by | Intent | Search terms | Candidates (id: title, length) | Top pick |
|---|---|---|---|---|---|
| Use (dash) | All 3D | Short airy digital zip, reads as "blinked" from behind cover | `zip by`, `whoosh up`, `synth zip`, `magic zoom` | **9117161625**: Oowhup Beeps Whirring Zip Bys 1, 0.8 s · 9125648149: Magic Zoom Up Sharp Tubular Whoosh Fast Hiss, 0.7 s · 9126089814: Synth Zip Short High Pitch Ascending Bursts, 1.4 s | 9117161625 |
| Arrive (optional tail) | All 3D | Reverse-suck "pop in" at the landing spot | `reversed whoosh`, `swish suck` | **9120984892**: Zap High Pitch Glassy Reversed Whoosh 9, 1.2 s · 9119707097: Swish Suck Reversed Metallic Swoosh Impact 1, 1.2 s | 9120984892 |

No enemy-only variant needed: the dash itself is the tell.

## 2. Launch Pad (held: place)
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Raise | You | Shared Mod raise | — | Synth `ModRaise` (shared cues) | `ModRaise` |
| Place | All 3D | Mechanical clunk + servo, "something got built here" | `servo`, `mechanical`, `pneumatic` | **9125925576**: Servo Shut Off Giant Machine Mechanical Quick 4, 2.4 s · 9118941667: Servo Motor 1, 0.5 s · 16480551414: Roblox_Pinball_Startup_Mechanical_01 (Roblox), ~1 s | 9125925576 |
| Idle (15 s, optional) | All 3D, quiet | Soft electric throb so a hidden pad can be found | `power throb`, `hum` | **9125784811**: Power Throb Tonal Hum Slow Pulse Electrical 3, 4.3 s (loop) | 9125784811 |
| Launch | All 3D | Big low air blast + rising hiss: "someone is airborne, look up" | `air blast`, `thruster`, `rising whoosh` | **9125577419**: Giant Air Blast Low Bursts Pound Many Versions 7, 2.1 s · 9120009360: Thruster Blast 8, 2.3 s · 9120629100: Web Shoot Short Juicy Launch 1, 1.0 s; layer 9125805579: Rising Whoosh Hissing Build Up Ascending Swoosh 2, 1.1 s | 9125577419 + 9125805579 |
| Land (optional) | All 3D | Heavy thump on landing | `landing thud`, `meaty thud` | **9116488211**: Meaty Thud 7, 1.8 s | 9116488211 |
| Pad destroyed | All 3D | Power-down with static | `power down`, `static burst` | **9117869243**: Power Down 1, 1.4 s · 9126160991: Video Static Distortion Short And Long Bursts 2, 1.7 s | 9117869243 |

## 3. Packet (held: throw grenade)
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Raise | You | Mod raise + pin pull | `grenade pull pin` | `ModRaise` + **9114659833**: Grenade Pull Pin 2, 0.5 s · 9114659662: Grenade Pull Pin 1, 1.4 s | `ModRaise` + 9114659833 |
| Throw | All 3D | Quick arm swish | `throw whoosh`, `whoosh fast swish` | **9126229700**: Whoosh By Fast Airy Swooshing Whipping Thuds 5, 1.1 s · 9120711313: Whoosh Fast Swish By 6, 1.2 s | 9126229700 |
| Bounce | All 3D | Small metal clink (first hit of the clip only) | `metal drop`, `grenade across floor` | **9116617140**: Metal Drops Clanking Impacts On Concrete 12, 2.0 s · 9114659492: Grenade Across Floor 1, 2.7 s · 9116612484: Metal Drop 1, 3.0 s | 9116617140 |
| Fuse (1.2 s) | Caster + team, 3D | Beeps that speed up to the blast | `scanner beeps`, `timer` | Synth `ModPacketFuse` · alt 9118777437: Scanner Beeps 10, 0.8 s | `ModPacketFuse` |
| **Danger** | **Enemy 2D** (inside the red ring) | Same rhythm, higher and harsher: "get out" | — | Synth `ModPacketDanger` | `ModPacketDanger` |
| Explode | All 3D | Punchy close blast with a bright digital crackle on top | `small explosion`, `pyro explosion`, `energy bursts` | **9119236749**: Small Explosion 1, 2.9 s · 9117982449: Pyro Explosion 1, 2.2 s · 9114589178: Glass Boom 6, 3.8 s; layer 9125625388: Layered Rips High End Short Energy Bursts Spark 3, 1.1 s | 9119236749 + 9125625388 |

## 4. Firewall (held: place)
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Raise | You | Shared Mod raise | — | `ModRaise` | `ModRaise` |
| Deploy | All 3D | Glassy build-up that lands solid | `charge up`, `power up`, `decloak` | **9125981170**: Spaceship Pre Blast Electric Charge Up Glassy 3, 1.8 s · 9119816546: Synth Power Up Multi Tone Wind Ups Rise 2, 2.7 s · 9125484235: Decloak Reversed Synth Bursts Low Pitch Growly 1, 2.0 s; slam layer 9125819216: Robot Impact Miscellaneous Metal Clangs Clunks 4, 1.4 s | 9125981170 + 9125819216 |
| Hum (6 s) | All 3D, quiet | Force field you can locate | `force field` | **9114524164**: Force Field Constant Sci Fi 1, 18.0 s · 9125566528: Force Field Drone Constant Sci Fi Pulsing Hum 1, 27.0 s | 9114524164 |
| Bullet hit | All 3D | Short electric crackle per hit, different from a wall impact | `shield impacts`, `static zap` | Synth `ModWallHit` (2 variants) · alt 9119073329: Shield Impacts 8, 0.2 s · 9114247527: Electricity Static 23, 0.4 s · 9119594871: Static Zap Body Two Buzzy Impacts 2, 1.0 s | `ModWallHit` |
| Break | All 3D | Glass shatter + boom: "the wall is gone, push" | `glass boom`, `glass breaks` | **9114589190**: Glass Boom 8, 3.1 s · 9114592117: Glass Breaks 1, 2.5 s | 9114589190 |
| Expire | All 3D | Gentle power-down, unlike the break | `power down` | **9117872887**: Power Down 4, 3.2 s | 9117872887 |

## 5. Lag Field (held: throw orb)
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Raise | You | Shared Mod raise | — | `ModRaise` | `ModRaise` |
| Throw | All 3D | Swish, a different take from Packet's | `whoosh fast swish` | **9120712091**: Whoosh Fast Swish By 2, 1.2 s | 9120712091 |
| Zone opens | All 3D | Pitch-dropping ripple: time just slowed | `time wave`, `time slow`, `descending synth` | **9120059083**: Time Wave Intense Fluttering Slow Down 2, 1.2 s · 9120061266: Time Wave Ripple Slow 2, 1.2 s · 9114055470: Descending Synth Burst Tonal Light Phasing 2, 3.3 s | 9120059083 |
| Zone hum (4 s) | All 3D | Warbly slowed-tape drone at the zone | `warble`, `pulsing hum` | Synth `ModLagLoop` · alt 9125636597: Magic Glow Constant Pulsing Warbled Hum Ringing 1, 27.0 s | `ModLagLoop` |
| **Slowed** | **Enemy 2D** (on entering) | Tape-slowdown dive: "you're slowed" | `slow down` | Synth `ModLagSlowed` · alt 9120059060: Time Wave Intense Fluttering Slow Down 1, 2.7 s | `ModLagSlowed` |
| Expire | All 3D | Hum fades + a soft poof | `magic poofs` | **9125640290**: Magic Poofs Short Breathy Bursts Wheezy Punchy 2, 1.5 s | 9125640290 |

## 6. Ping (instant reveal)
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Cast | You | Rising scan sweep into a clean sonar ping with echo | `sonar`, `scanner` | Synth `ModPingCast` · alt 9125981410: Spaceship Sonar Low And High Pitch Tonal Throbs 4, 2.4 s · 9126138068: Transmission Breakup Sonar Or Tracker Tones 2, 0.5 s | `ModPingCast` |
| **Pulse** | **All 3D** (heard by enemies near it) | Lower, harder sonar "pwomm": a scan just went out, move | `sonar` | Synth `ModPingPulse` · alt 9125984762: Spaceship Sonar Low And Mid Pitch Tonal Throbs 31, 2.5 s | `ModPingPulse` |
| **Revealed** | **Enemy 2D** (only the revealed) | Two sharp alert chirps: "you're spotted" | `scanner beeps` | Synth `ModPingRevealed` · alt 9118777239: Scanner Beeps 5, 0.9 s | `ModPingRevealed` |

## 7. Patch Up (held: target heal)
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Raise | You | Device foley + Mod raise | `AS_scifi_foley` | `ModRaise` + **127533251122014**: AS_scifi_foley-01 (Audioscape), under 1 s | `ModRaise` + 127533251122014 |
| Heal start | All 3D | Bright bell ding | `synth sparkle`, `magic glows` | **9126073001**: Synth Sparkle Tone High Pitch Bell Tone Ding 4, 1.2 s · 9116394545: Magic Glows Soft Clusters Of Chiming Hits 1, 2.1 s | 9126073001 |
| Heal beam (2 s) | All 3D | Shimmering major chord: enemies hear someone healing (burst them now) | `sparkle tone constant` | Synth `ModHealLoop` · alt 9125986205: Sparkle Tone Constant High End Shimmer Sparkle 1, 18.0 s | `ModHealLoop` |
| Heal done | Healer + target | Rising major arpeggio | `synth sparkle tone burst` | Synth `ModHealDone` · alt 9119834423: Synth Sparkle Tone High Pitch Tone Burst 7, 0.6 s | `ModHealDone` |

## 8. Overclock (instant self-buff)
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Activate | All 3D | Saw spin-up with a crunchy front | `spin up`, `synth power up` | Synth `ModOverclockOn` · alt 9119816546: Synth Power Up Multi Tone Wind Ups Rise 2, 2.7 s · 9114216526: Dvd Play Motor Spin Up 1, 2.6 s | `ModOverclockOn` |
| Hum (5 s) | All 3D, on the gun | Buzzing electric whine: the "gun hums" counter-play tell | `rizzy hum`, `energy spin` | Synth `ModOverclockLoop` · alt 9125808054: Rizzy Tone Undulating Constant Low Pitch Hum 2, 36.0 s · 9114344375: Energy Spin Speed Up To Fast Synth Motor 1, 17.9 s | `ModOverclockLoop` |
| End | All 3D | Falling power-down: "it's over, peek now" | `power down` | Synth `ModOverclockOff` · alt 9117869243: Power Down 1, 1.4 s | `ModOverclockOff` |

Free extra (no asset): raise the gun's shot pitch ~4% while Overclock runs, so the faster fire also *sounds* faster.

## 9. Rollback (instant rewind)
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Rewind | You | VHS rewind: fast falling chirps through a flanger, under the screen effect | `rewind`, `wind suck backwards` | Synth `ModRollbackRewind` · alt 9117880715: Power Rewind Brake Engage 1, 2.0 s · 9120768061: Wind Suck Backwards Swooshing Build Up 1, 2.2 s | `ModRollbackRewind` |
| Snap | All 3D, at **both** ends | Crushed digital glitch snap: where they left *and* where they landed | `video static distortion` | Synth `ModRollbackSnap` · alt 9120425687: Video Static Distortion Short Bursts Rizzy 2, 1.0 s · 9126160991: Video Static Distortion Short And Long Bursts 2, 1.7 s | `ModRollbackSnap` |

---

## Shared cues
| Cue | Heard by | Intent | Search terms | Candidates | Top pick |
|---|---|---|---|---|---|
| Cooldown ready | You | Soft rising two-note blip, never annoying | `notification`, `synth sparkle tone burst` | Synth `ModReady` · alt 17208361335: Roblox GUI - Notification High (Roblox), ~2 s · 9126076030: Synth Sparkle Tone High Pitch Tone Burst Ping 4, 0.9 s | `ModReady` |
| Can't use | You | Low double buzz (on cooldown, blocked, Packet Loss later) | `negative`, `malfunction beeps` | Synth `ModDenied` · alt 17208353912: Roblox GUI - Negative (Roblox), under 1 s · 9116458566: Malfunction Beeps Glitch Staticky 3, 0.4 s | `ModDenied` |
| Held-mode cancel | You | Quick falling blip | `ui click` | Synth `ModCancel` · alt 15675032796: Roblox_UI_Small_Click (Roblox), under 1 s | `ModCancel` |
| Held raise | You | Rising chirp over a soft swish; one clip, the code pitches it per Mod (Launch Pad 0.9, Packet 1.0, Firewall 0.85, Lag Field 0.8, Patch Up 1.1) | — | Synth `ModRaise` | `ModRaise` |

Glitch paths (Phase 2) add magenta static: a short bit-crushed layer on each Mod's use cue, also from `mod_sfx.py`.

---

## Synth presets (`tools/audio/mod_sfx.py`)
sfxr parameters in real units (Hz, seconds, octaves/s), so a jsfxr sound can be copied over by ear. Each cue layers 1–4 voices. Written and smoke-tested in a temp folder (all 20 clips render cleanly, no clipping); **not added to the atlas yet.** To audition them:

```
python -I tools/audio/mod_sfx.py
```

This writes one WAV per cue plus `_Reel.wav` (loops play 3 times so the seam can be heard) to `art-source/audio/ModSfx/` (gitignored).

| Slice | Length | Recipe in short |
|---|---|---|
| `ModReady` | 0.21 s | Square E6 → B6 arpeggio + sine an octave down, small room |
| `ModDenied` | 0.18 s | 150 Hz pulse ×2 (repeat 85 ms), low-passed, 5-bit |
| `ModCancel` | 0.10 s | Square 1.1 kHz sliding down 4 oct/s |
| `ModRaise` | 0.20 s | Noise swish (opening low-pass) + rising square chirp |
| `ModPingCast` | 1.04 s | Resonant saw scan sweep → sine C6 + triangle C5 sonar, long room |
| `ModPingPulse` | 0.82 s | Sine F#5 + 4-bit square grit, room |
| `ModPingRevealed` | 0.22 s | Square B6 chirp ×2 |
| `ModOverclockOn` | 0.45 s | Saw 180 Hz rising 3.2 oct/s through an opening resonant filter + crushed kick |
| `ModOverclockLoop` | 1.00 s loop | Saw 110 Hz (9 Hz vibrato) + sine whine 1.48 kHz (18 Hz vibrato) |
| `ModOverclockOff` | 0.45 s | Saw 900 Hz falling 3.5 oct/s, closing filter |
| `ModRollbackRewind` | 0.48 s | Saw chirps falling 14 oct/s every 50 ms, flanger, 6-bit + decimated tape noise |
| `ModRollbackSnap` | 0.20 s | 3-bit decimated noise burst + sine drop |
| `ModPacketFuse` | 1.22 s | Square G6 beeps at 0, 0.34, 0.60, 0.80, 0.94, 1.04, 1.11, 1.16 s |
| `ModPacketDanger` | 1.22 s | Same timing, D7, thin 15% pulse, brighter |
| `ModLagLoop` | 1.00 s loop | Saw E2 with 4 Hz deep vibrato, resonant LP, 6-bit + decimated air |
| `ModLagSlowed` | 0.42 s | Saw 700 Hz diving 2.5 oct/s, crushed and decimated |
| `ModHealLoop` | 1.00 s loop | Sine C-major chord (C5 E5 G5 C6) with 6 Hz shimmer + air |
| `ModHealDone` | 0.40 s | Sine C6-E6-G6 arpeggio, room |
| `ModWallHit` ×2 | 0.07 s | 4-bit noise crackle + falling square tick |

## Atlas and upload budget
Open Cloud allows **10 audio uploads a month** (no ID verification), so:

| What | Uploads | How |
|---|---|---|
| 19 synth slices (20 clips, ~11 s of audio) | **1** | `build_sound_atlas.py` adds `mod_sfx.build_mod_clips()` to its clip list; the atlas is rebuilt as **v3** and uploaded once (same command as in [Art Direction](Art%20Direction.md) → Audio), then `ATLAS` in `Config/Sounds` changes. Loops (`…Loop`) need a looping atlas voice in `AudioController` (`PlaybackRegion` + `LoopRegion`, `Looped = true`); it has none today (every voice is one-shot; the old `BeamHum` slice lost its gun), so the code session adds one. |
| Every library sound (PSE, Audioscape, Roblox) | **0** | Played straight by asset id; Roblox-licensed for any experience. |
| Spare | 9 left this month | Kept for gun-atlas fixes and Glitch-path sounds. |

The atlas grows from ~gunshots + feedback to that plus ~11 s (roughly +1 MB FLAC); one upload covers every synth Mod cue. If the user rejects a synth cue, its library alternative costs nothing extra.
