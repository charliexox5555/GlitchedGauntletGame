# 2026-11-08 Gun Sound Overhaul

**Ask (owner):** some guns are too quiet and some "don't sound like guns". Use the free gun SFX library added to `vault/06 Assets/GunSoundEffectLibrary`, give every gun its own sound personality, put a sound on every action, and level-match the lot.

**Status (2026-11-09):** the owner OK'd the reel; the gun atlas is uploaded (**asset 124785078830341**, "GG Gun Atlas v1", group 11116787) and set as `Config/Sounds GUN_ATLAS`. Play-tested in Studio with sound (below). **Waiting on the owner:** play it in-game and name any gun or action that needs a change. Nothing committed.

Rules followed: real recordings only, polished, never synthesised or layered (the owner's standing rule since the rejected synth test of 2026-10-25); audition before upload; LihFolk `lihfolk-sfx` (one-shots at one loudness, the mix in `volume`, -1 dBTP, under 20 MB / 7 min per audio asset, round-robin takes, beats on the clip marker) and `07 Lighting VFX and Audio` (Combat Sound Design and Feedback: own gun loudest, enemies duller, ambience ducked).

## The library (catalogue)

**"Snake's SECOND Authentic Gun Sounds Pack"** by SnakeF8 / F8 Studios (itch.io, `f8studios.itch.io/snakes-second-authentic-gun-sounds-pack`). **Licence:** the page says all sounds "can be used commercially, and credit is not needed"; the author answered "It's public domain!" in the comments. No licence file in the download. Checked 2026-11-08. 44.1 kHz stereo 16-bit WAV (+ MP3 copies). Not committed (raw library files stay out of the public repo).

| Folder | What | Character (measured) |
|---|---|---|
| Full Sounds / 9mm | Single, Double Tap, Burst (3), Slow Burst (3), Spray (5) | close, bright crack (centroid ~2 kHz), punchy; 12 separate shot takes; bursts ~8 rds/s |
| Full Sounds / .308 (7.62x51) | same five patterns | the biggest crack; a strong slap 70 ms after each shot; 9 takes; Spray is real auto (~8 rds/s) |
| Full Sounds / 20 Gauge | same five patterns | wide boom, semi-auto shotgun; 7 takes |
| Isolated / (same) | the same shots with the outdoor tail gated off | not used: we trim tails ourselves |
| & More / Pistol (9mm) | dry fire, rack (full / pull / release), slide lock, slide release, chamber check, mag out ("Reload 1"), mag in ("Reload 2") | clean, close, metallic |
| & More / Revolver / 32 SW Long | open (full / parts), close, hammer cock / decock, rotate cylinder, eject one casing, single load | light, bright revolver |
| & More / Revolver / 44 Magnum | open, close, cock, decock, eject (empty / full / with floor impact), single load | heavy revolver; casings hitting the floor |
| & More / Mag Pack | rounds into 22LR / 9mm / AK / AR / bolt / Mosin mags, unpack, Mosin top load, single shotgun load | small round clicks and plastic mags; the shotgun shell into a tube |
| & More / Bipod | deploy, raise, impact (one / both legs) | spring and hard metal clacks |

What it lacks: no lever, pump, bolt or charging-handle sounds, no rifle mag in/out, no suppressed shots, no distance (far) mic. Those come from what we already had: **The Free Firearm Sound Library** (CC0; ~22 real guns, near + mid-distance mics) and the 2026-11-05 Freesound handling takes (AR-15 / Glock / Uzi sessions, a pump, 1873 Winchester rounds and lever, a Cooey bolt, a holster; [Knife and Sound Pass](2026-11-05%20Knife%20and%20Sound%20Pass.md)).

## Why the old sounds were quiet or "not guns" (found)

- The old build matched loudness in 4 soft-clip passes; the peaky library shots never converged and landed **2-3 dB under target** (Sheriff, Outlaw, Operator, Bulldog, Marshal).
- The suppressed guns (Ghost, Phantom, Spectre) sat **3.5 dB under** everything behind a 2.6-3 kHz low-pass: dull and quiet.
- Several guns were **pitched twice** (baked in the atlas, then again in `GunSounds`): Ares a PPSh at ~0.86 x 0.88, Odin an AK at 0.82, Operator the Tikka at 1.04 x 0.9, Outlaw a Mosin at 0.93 x 0.95.
- Handling foley sat at -24 LUFS and played at 0.6 x 0.75: ~15 dB under the shots. Every gun shared one take per class, and dry fire was a synthesised click.

## The themes (one recording per gun)

Pitch is baked into the slice (the game adds +/-2 % per shot). "SNK" = the new pack, "FFL" = Free Firearm Library.

| Gun | Shot | Theme | Handling signature |
|---|---|---|---|
| Classic | SNK 9mm single + slow-burst end (2 takes, 3 variants) | clean, snappy duty 9mm | the pack's own pistol: mag out / in, slide snaps home, chamber-check inspect, real dry fire |
| Ghost | FFL Walther PPQ 9mm, suppressor polish | quiet operator: tight, dark, still a gunshot | Glock mag, slide-release lever, slide-lock inspect |
| Akimbo | FFL Bersa .380, x1.06 | two small, quick pistols | everything a size smaller and higher |
| Sheriff | FFL S&W 642 .38, x0.92, magnum class | hand cannon with a long tail | .44 Magnum: hammer cock, cylinder out, cases out onto the floor, round in, cylinder shut; cylinder-spin inspect; hammer-fall dry fire |
| Shorty | FFL Mossberg 190 12 ga, x1.05 | pocket coach gun bark | light action open, real shell in, hard snap shut, hammer cock inspect |
| Stinger | SNK 9mm burst/spray ends + slow-burst shots (4 takes), x1.05 | angry buzzing 9mm hose | Uzi mag and bolt |
| Spectre | FFL Carl Gustav M45 9mm (3 takes from its bursts), suppressor polish | soft, tight 9mm stutter | slim pistol-style mag, HK-style slap |
| Bucky | SNK 20 ga single, x0.94 (12-gauge weight) | big pump boom | the pump, real shells into the tube on the ShellIn marker |
| Judge | SNK 20 ga burst / spray / slow-burst ends, x1.02 | rapid semi-auto shotgun | heavy drum, rattling shells inspect |
| Vandal | SNK .308 burst + spray ends | heavy battle-rifle hammer | AR/AK mag work and charging handle, rounds-in-mag inspect |
| Phantom | FFL AR-15 5.56, suppressor polish | quieter, quicker carbine | the same family, pitched lighter |
| Bulldog | FFL Savage .300 Blackout, x1.03 | short, chunky budget bullpup | rifle mags, SMG-style cocking handle |
| Guardian | SNK .308 single, x0.96, marksman class | one huge crack with a rolling tail | heavier mag, a round pressed into a bolt-gun mag |
| Marshal | FFL Marlin 336 .30-30 (a real lever gun) | western lever boom | the lever after every shot, rounds through the gate, hammer-fall dry fire |
| Outlaw | FFL Mosin-Nagant 7.62x54R, x0.96, sniper class | double-rifle thunder | big action drops (Open), brass on the floor (RoundOut), rounds in (RoundIn), heavy clunk shut (Close), hammer cock inspect |
| Operator | FFL Tikka T3 .30-06, x0.97, sniper class | big-bore bolt sniper | the bolt after every shot, stock mag |
| Ares | FFL AK-47 full auto (4 burst-end takes), x0.95 | RPK-style drum LMG | bipod legs on the draw and the inspect, heavy drum |
| Odin | FFL Springfield 1917 .30-06, x0.97 | belt-fed boom (M1919 calibre) | ammo box, feed cover up and slammed shut, deepest handle |
| Knife | unchanged (CC0 swishes, stabs, hits) | — | volumes raised: a slash ~2 dB under a pistol shot |

Akimbo is still in the roster (roster 16), so it has a set. Snake-pack shots lead the most-used guns (Classic, Stinger, Vandal, Guardian, Bucky, Judge); the FFL recordings keep the guns whose identity is a specific action (revolver, lever, bolt, AK, PPQ). Two pairs share a calibre on purpose and differ by take, class polish, cadence and pitch: Vandal / Guardian (.308 auto vs single) and Bucky / Judge (20 ga single vs bursts).

**Alternates to try if one doesn't land** (one line each in `GUNS` in `tools/audio/build_gun_sfx.py`): Bucky → FFL Benelli Nova; Ghost → FFL Ruger Mark III .22 or SNK 9mm with the suppressor polish; Phantom → SNK .308 with the suppressor polish; Odin → SNK .308 spray at x0.86; Sheriff → FFL 1911 .45 at x0.9; Guardian → FFL SKS.

## Every action

| Action | Field | When it plays |
|---|---|---|
| Shot | `fire` | every shot (2D). Semi / pump / bolt: the whole shot with its tail. **Automatic: a short slice**, cut 1.5 fireIntervals in with a 30 ms fade |
| Tail | `tail` | **new:** automatic guns, once the trigger is let go (no shot for 1.5 fireIntervals), starting exactly where the shot slice fades (`Config/Audio TAIL_AFTER`, baked by the build). Sprays stay punchy, the room comes at the end. Also for the player you spectate |
| Other players' shot | `fireFar` | 3D at the muzzle: the FFL mid-distance mic, or the near take darkened (SNK), 2.5 dB under |
| Dry fire | `dryFire` | empty trigger: the pack's real 9mm dry fire per gun pitch; hammer falls for revolver, coach gun, lever and double rifle |
| Draw | `draw` + `rack` | every equip, the rack on the draw clip's slide / bolt / handle / lever beat |
| Inspect | `inspect` | per-gun signature (above) |
| Reload | `magOut`, `magIn` | the clip's **MagOut / MagIn markers** now (they used to be guessed from the Mag joint) |
| Empty reload | + `rack` | the charging handle / slide / bolt joint stopping |
| Break-open, cylinder, feed cover | `open`, `close` | Open / Close markers (Outlaw), else the Barrels / Crane / FeedCover joints (Shorty, Sheriff, Odin). `close` is new (it used to borrow `rack`, the feed cover borrowed `shellIn`) |
| Cases out | `eject` | **new:** the RoundOut marker (Outlaw) or the EjectorRod joint (Sheriff); it used to borrow `magOut` |
| Shell / round in | `shellIn` | ShellIn markers (Bucky, Marshal ReloadInsert), RoundIn (Outlaw), else the round props |
| Pump / bolt / lever cycle | `rack` | after every Pump / Bolt shot (Bucky, Marshal, Operator), `CYCLE_DELAY` later |
| Knife | `fire`, `heavy`, `hit*`, `draw`, `inspect`, `inspectFlip` | unchanged timing, louder |

## Levels

All in the loudest 100 ms, K-weighted (`short_max`; handling clicks are 50-300 ms, which a 400 ms momentary window under-reads by 5-10 dB):

| | Target | Volume |
|---|---|---|
| pistols, SMGs | -11.5 | fire 0.85 (Gun group 0.9) |
| rifles, MGs, magnum | -10.5 | |
| marksman, shotguns | -9.5 | |
| snipers | -8.5 | |
| suppressed | -13 (1.5-2 dB under, no longer 3.5 dB + a muffle) | |
| handling | -15 (was about -21) | 0.8 (Foley group 0.75) |
| draws, inspects, swells | -17 | 0.7 / 0.6 |
| far shots | class - 2.5 | 0.9 (Enemy group) |

Every slice is at or under -1 dBTP (a real true-peak limiter now; the old one only checked sample peaks). Where a peaky recording can't reach its target without more than 6 dB of limiting, the generated set gives it up to 2x volume instead (the dry fire, the small revolver clicks, the Glock mag), so it plays level without being squashed.

## Files

- `tools/audio/build_gun_sfx.py`: the whole thing is data at the top (`CLASSES`, `GUNS`, `FOLEY`, `SETS`). `python -I tools/audio/build_gun_sfx.py --report --preview` (18 s).
- `art-source/audio/GunSfx.flac` (+ `.json`): the **gun atlas**, 148 s, 6.0 MB, 175 slices / 91 names. A second asset, because the shared atlas is already 360 s / 18 MB.
- `art-source/audio/GunSfxPreview.wav` + `.txt` (the timings): every gun's draw, inspect, shots (autos: a 10-round string and a 3-round tap, each with its tail), dry fire, reload and empty reload at game volumes. Gitignored.
- `src/shared/Config/GunAtlas.luau`, `GunSoundSets.luau`: generated. `GunSounds.luau` reads the sets, keeps the knife, and has an `OVERRIDES` table for hand tweaks.
- `AudioController`: `gun:` ids play from the gun atlas (a voice pool per atlas, no SoundId swaps). `Config/Sounds GUN_ATLAS` (placeholder until the upload). `Config/Audio TAIL_AFTER`.
- `WeaponController`: tail on release; `Eject` / `Close` beats. `ViewmodelController.clipBeats`: markers first (MagOut, MagIn, Open, RoundOut, RoundIn, ShellIn, Close, Rack), joints as the fallback. `EffectsController`: preloads the gun atlas; the spectated player's tail.

## What to test (owner)

1. Listen to `art-source/audio/GunSfxPreview.wav` (timings in `GunSfxPreview.txt`). Name any gun that doesn't sound right, or is too loud / quiet next to the others.
2. OK the upload (one audio asset, under the group).
3. In Studio, per gun on the range: hip fire, a long spray and let go (the tail), a tap, dry fire, reload, empty reload, draw, inspect. Outlaw: the four reload beats. Sheriff: open, cases out, load, shut. Bucky / Marshal: a shell per insert, the cycle after each shot.
4. A bot firing at you: their shots duller and further than yours.

## Results

- Build: 148 s, 6.0 MB atlas, no clicks or bleed at any slice edge, every slice at or under -1 dBTP.
- StyLua, Selene (0 errors) and `rojo build` pass.
- 2026-11-08, before the upload: switched through 8 guns (draw, fire, inspect, reload) with the placeholder id. No script errors; `gun:` ids routed to the new voice pool.
- **2026-11-09, uploaded and play-tested in Studio (match place, solo vs bots).** The asset loads in 0.5 s, 148.07 s long. A probe on the 2D voices logged which slice each action played:
  - Bucky: 2 shots, the pump after each, a real shell per insert, the pump on the empty finish.
  - Sheriff: 2 shots, the cylinder-spin inspect, then open, cases out (`eject`, new), round in, cylinder shut (`close`, new).
  - Outlaw: 2 shots, then its four markers: Open, RoundOut (brass on the floor), RoundIn, Close (the heavy clunk).
  - Vandal: 2 taps, each followed by its tail on release, mag out / in on the markers, the charging handle, the rounds-in-mag inspect.
  - Odin: shots + tails, feed cover up and slammed shut, ammo box out / in, bipod inspect.
  - Marshal: the lever after each shot, rounds through the gate (ShellIn marker).
  - Classic: shots, mag out / in, slide release, chamber-check inspect.
  - Every set checked in-game: 19 guns, 196 sounds, every id resolves to a slice, volumes 0.6-1.6, every automatic gun has a tail.
  - Output: no script errors. The only error is an old texture id in the place (`203785492`, not in the source), unrelated.
- Not covered: how it sounds on your speakers in a real fight (the probe checks what plays, not taste), the spectated-player tail, and other players' 3D `fireFar` (a bot fired at me, but I only probed the 2D voices).
