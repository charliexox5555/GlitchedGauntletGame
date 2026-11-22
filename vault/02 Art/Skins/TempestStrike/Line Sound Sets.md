# Tempest-Strike line: sound sets (Stinger, Marshal, Bucky, Sheriff, Katana) and the electric inspect

## Brief (owner, 2026-11-22, after hearing the Vandal's v2 set in game)
The owner said the sounds were "solid, except for the inspect":
1. **Inspect:** replace the water with electric, and fix the timing so the cues line up with the inspect animation's key moments.
2. **Rest of the line:** apply the same standard to the other guns and the knife: crisp, and in sync with their animations.

## Files
- **Builder:** `tools/audio/design_tempest_line.py`. Run it with `python -I tools/audio/design_tempest_line.py`. It reuses the Vandal's builder (`design_tempest_vandal.py`): its tools, recipes and rules.
- **Output:** `art-source/audio/tempest/line_v1/` (108 files). The folder is git-ignored because it's built from licensed library recordings. It also holds `_reel.wav` with `_reel.txt` timings, and `_levels.json`.
- **Uploads:** each file is a solo Audio asset. The IDs are in `Config/TempestAudio` (`takes`).

## The inspect (every gun): electric, on the move's moments
| Cue | What it is | When |
|---|---|---|
| inspect | a force-field charge swell with a thread of static (GDC Lethal Energies, CC0 Electricity) | as the inspect starts; the stock safety tick or cylinder spin still plays as the physical layer |
| inspectSnap | a rod whoosh with a crackle riding its envelope and a zap on the peak; the peak is 0.10–0.13 s into the file | 0.12 s before each snap lands |
| inspectRoll | an electric pass-by whirl (SoundBits shaver pass-by, pitched up) with a high-voltage arc; the peak is 0.34 s in | timed so the peak lands as the gun passes muzzle-up |
| inspectCatch | a metal click, a zap and a spark | on the catch or flick |
| inspectSettle | a light switch click with a tiny zap | as it settles in the hold |

The timelines are progress values on each inspect track:

| Track | Cue times (progress) |
|---|---|
| `tempestInspect` (Vandal, Stinger, Marshal, Bucky; 5 s) | swell 0.02 · snap 0.126 (lands 0.15) · roll 0.452 (peaks at 0.52, muzzle-up) · catch 0.59 · snap 0.921 (whip home lands 0.945) · settle 0.965 |
| `InspectTempestSheriff` (2.8 s) | swell 0.02 · snap 0.117 · snap 0.537 (rolled to you as the cylinder swings out) · roll 0.62 · catch 0.865 (flicked shut) · settle 0.96 |
| `KatanaInspect` (3.4 s) | swell 0.02 · snap 0.095 (level lands 0.13) · crackle run 0.18 (the first wave) · snap 0.695 (lift lands 0.73) · crackle run 0.78 · snap 0.915 · settle 0.975 |
| `KatanaDraw` | a snap whoosh at 0.3 (the wheel up through the left), then the catch zap as it locks (0.5) |

The timelines live in `Config/TempestProfiles` (`inspectSfx`) and `SkinPreview.TEMPEST.KATANA.INSPECT_SFX`.

## Gun sets
Each set uses the same recipe as the Vandal: the stock ProPack take as the core, plus a real crack from the matching Pole Position gun, a water crack, and an electric snap on alternate takes. Then the glue and a level of +0.8 dB over that gun's own stock shot.

**Glue EQ:** each gun's EQ is auto-matched to its own stock shot (`tune()`). The Vandal's body-forward EQ made the others boomy, because their cores already carry the lows. The aim is +1 dB on lows and presence, level elsewhere.

**Measured result against each gun's stock shot:**
- **Stinger:** within about 0.6 dB in every band.
- **Marshal:** within about 1 dB.
- **Sheriff:** even, with slightly less mid.
- **Bucky:** 1.5–2 dB light across the board.
- **Attacks:** 2–6 ms, against stock 2–88 ms.

| Gun | Core | Real gun layer | Handling (designed; the stock click is inside, so the old Tempest cues are off via `ownFoley`) |
|---|---|---|---|
| Stinger | ProPack SMG (6 + first, last, tail) | HK MP7 on-gun action and 1 m crack | mag out and in with real G36C mag foley, a water burst and splat, a static fizz, a zap; rack plus an electric chirp; dry fire plus a zap |
| Marshal | ProPack rifle (4, 1.4 s with its decay) | Remington 700 7.62, 1 m | lever rack plus a chirp; each round in with a tiny splash and zap; dry fire |
| Bucky | ProPack shotgun (4) | Saiga-12 1 m body, SPAS-12 1 m bite | pump plus a chirp; shells in with a splash and zap; dry fire |
| Sheriff | ProPack revolver (4) | S&W M66 .357, 1 m | cylinder open and close with the real S&W M29 action under them, water and a zap; ejected rounds with falling drops; rounds in; hammer plus a chirp; dry fire |

**Katana (knife slot):**
- **Swings:** the stock knife whoosh with a crackle trail and a water whip. The light swing peaks at 0.053–0.062 s and the heavy at 0.083–0.089 s, which keeps `Animations.KNIFE_FEEL.whooshPeak` true, so the strike still lands on the peak.
- **Heavy (the Cleave):** adds a real lightning crack (CC0) and a water surge.
- **Hits:** the body and wall hits each get a zap and a splat.
- **Draw:** the sword unsheathe, a zap and a water swish. The draw whoosh carries crackle.
- **Inspect:** the stock knife inspect and flip clicks are off for the katana; its own timeline replaces them.

## Wiring
- `Config/TempestAudio.guns[weaponId]` holds each set's shots and handling. The levels mirror each gun's stock volumes in `Config/GunSounds`.
- `Util/GunAudio`'s `tempest` option plays the shots. Guns without first, last or tail takes play the plain shot.
- `WeaponController.playGun` overrides the handling sounds. It's keyed on `ViewmodelController.hasTempest()`, which now includes the katana.
- Other players hear `fireFar`, picked through the shooter's gun model's SkinLine.

## For the owner to check in game
- Each inspect's timing.
- Each gun's shot against its stock sound.
- The shell, lever and pump handling.
- The katana's swings and hits.

Levels can be tuned per cue in `Config/TempestAudio`.

## v3 (2026-11-22): oomph, spray timing, katana thunder
**Owner's notes:**
- The shots are "too close to the original … needs more oomph … sleek and satisfying".
- The katana heavy's thunder "cuts off too early".
- Spraying "feels like it gets messed up".
- They asked to confirm that nothing uses atlases.

**Spray (a real bug, not Studio lag):**
- The Vandal fires every 0.103 s and the Stinger every 0.075 s, but their designed shots were 0.5 s and 0.3 s long. In a spray they stacked about five deep, and the per-sound voice limit (`Config/Audio` `VOICES_PER_SOUND` = 4) cut the oldest off mid-sound on every shot.
- Auto guns' shots are now cut the way the stock pack does it: about one fire interval × 1.5 + 30 ms (Vandal 0.185 s, Stinger 0.143 s), with a 30 ms fade.
- The separate tail, faded by the next shot, carries the decay.
- The far versions are cut the same way. The last round keeps its full tail.

**Oomph, for every gun (the Vandal's shots now come from this builder too):**
- **Thump:** a real low thump: a steel bulkhead hit, low-passed at 160 Hz, 8–12 dB under the core.
- **Mechanism:** the HK416 on-gun action is up 4 dB on the Vandal (from −12 to −8).
- **Skin layers:** water and electric are about 3 dB up.
- **Glue:** a harder transient (+6 dB), 5:1 compression and +3 dB drive.
- **Level:** +1.5 dB over each stock shot (was +0.8).
- **EQ:** auto-matched again, aiming +2 dB on the lows and presence.

**Result:** the lows are 1.2–2.8 dB over stock and the presence +1 to +2.7 dB. The Bucky stays about 1–2 dB light in the mids.

**Katana heavy:** the real lightning crack now runs 2.4 s, with a 1.3 s natural fade; the file is 2.6 s long.

**Atlases: confirmed none.** Every Tempest take is its own asset, played from 0 s (`AudioController` bank takes carry no start offset). The only "combined" file is each layered shot, which is one designed take.

**Uploads:** 54 new or changed files went up solo. The handling, inspect and swing files kept their uploads.

## Round 4 (2026-11-22): katana thunder down, A/B for the shots
**Owner's notes on v3:**
- The thunder cracks "still seemed a bit too much".
- The Stinger, Marshal and Sheriff "mostly just sound like the original … we gotta add some stuff".
- The Bucky is a shotgun, so it's lower priority, but it shouldn't just be stock either.

**Katana heavy (in the game):**
- The lightning now rings about 1.1 s with a 0.6 s fade, at −13 dB under the swing (was 2.4 s at −7). The file is 1.3 s.
- Its peak is still at 0.089 s, so the swing timing holds.
- Re-uploaded both takes.

**Shots, A/B audition (not in the game until the owner picks):** built by `tools/audio/design_tempest_ab.py`; the output is `art-source/audio/tempest/line_v1/ab/` with `_reel.wav` and `_reel.txt`.
- v1–v3 put layers on top of the stock ProPack shot and EQ'd them to sit over it, so the stock shot always led.
- In round 4, Pole Position's real-gun recordings are the core instead, one job per mic: crack (close or on-gun), body (1 m), bite (a second gun's close mic, high-passed), and tail (the 50–55 m mic).
- On top of those come the bulkhead thump, the Tempest water and electric layers (louder), the class finish (SMG, MARKSMAN, MAGNUM, SHOTGUN), a 300 Hz body lift, air where the mics are dark, and a level of +1.5 dB over stock.
- **A:** pro-designed only.
- **B:** the same with the stock shot at −7 dB under it.

| Gun | Crack | Body | Bite | Tail |
|---|---|---|---|---|
| Stinger | HK MP7 on-gun | MP7 1 m and FN P90 1 m | Uzi 1 m | — |
| Marshal | Remington 700 1 m | Sako TRG 1 m | Barrett M98B on-gun | Remington 50 m |
| Sheriff | S&W M66 .357 1 m | S&W M29 .44 | SIG P229 1 m | M66 50 m |
| Bucky | Saiga-12 1 m | USAS-12 1 m | SPAS-12 1 m | Saiga-12 55 m |

**Distance from the stock shot (RMS over 5 bands):**

| Version | Distance |
|---|---|
| v3 | 1.0–1.9 dB |
| A | 3–7 dB |
| B | 1.9–2.8 dB |

A is heavier in the lows, leaner in the low-mids and, on the Marshal, darker on top.

The Stinger is also played in 12-round sprays at its fire rate (stock, A, B). Once the owner picks per gun, the takes are uploaded solo and replace `<Gun>_fire` / `fireFar` in `Config/TempestAudio`.

**Owner's pick (2026-11-22): B for all four guns.** The owner said "go with the stock and see how it sounds", and B (pro-designed with the stock shot under it) was also the recommendation: each gun stays recognisable, but it's fuller than v3. This is now in the game:
- the B fire takes;
- B far takes (skin layers pulled back, low-passed 5 kHz, 2 dB down, cut to the fire interval on the Stinger), built by `design_tempest_ab.py --set B`;
- the Stinger's first shot (B, water +2 dB).

That's 31 solo uploads. The Stinger's last shot and tail, and all handling, stay from v3. Switching any gun to A means building with `--set A`, uploading, and changing that gun's `PICKED` entries in the TempestAudio generator.

