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
