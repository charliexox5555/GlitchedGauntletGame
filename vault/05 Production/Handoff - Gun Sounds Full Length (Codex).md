# Handoff: gun sounds that play in full and sound great (for Codex, 2026-11-14)

## The owner's diagnosis (his words, condensed)
"The sounds are feeling dull and not good because I think they cut out too early... like the semi-automatic and all the guns, you click it, but then you wouldn't hear the whole fire to the sound. Which is why when I listen to the automatic one, it sounds different. Like there's actually a punch to it. But this one just sounds like there's a dull hit."

**The task:**
1. Fix that: every gun's shot should play its whole sound.
2. Check **every** gun sound (shots, tails, reloads, draws, dry fire, knife, hits, impacts) so they all sound great.

The owner asked you to find whatever skills or tools you need to listen to and understand audio. That is the core gap: the Claude sessions could only measure, not hear.

## Evidence already found (Claude, 2026-11-14): he is right
The atlas build trims every non-automatic shot to a fixed **length cap**, cuts it where it falls 55 dB under its peak, and adds a 40 ms fade. See `tools/audio/build_pro_atlas.py`: `CAPS`, `cap_of`, `tail_trim`. Measured against the raw pack files:

| File | Raw length | In the atlas |
|---|---|---|
| `gun_pistol_shot_01` | 1.50 s | **1.00 s** (cap `pistol_shot`) |
| `gun_rifle_shot_01` | 2.19 s | **1.60 s** |
| `gun_shotgun_shot_01` | 2.66 s | **1.60 s** (some takes 1.586) |
| `gun_rifle_sniper_shot_01` | 2.04 s | 2.00 s |
| `..._tail_only_01` (autos) | 2.02 s | **1.60 s** |
| auto shots `_shot_01..08` | 0.21 s | 0.21 s (the pack cuts these short on purpose; the tail carries the body) |

This explains his ear test:
- **Automatic guns** get their body from the separate tail file, which plays with every shot, so they punch.
- **Semi-automatic guns** (pistol, revolver, rifle, shotgun, sniper) have their room and decay chopped off, so only the "dull hit" is left.

**Other processing to question** (same file, `process()` around line 300):
- **`pull_in`:** moves the mechanical click to 8 ms before the blast on the pistol, rifle, shotgun and sniper. It may smear the attack.
- **`head()`:** trims the start, which may eat the attack.
- **`SHOT_EQ`** ("crack shelf") on every semi shot, and **`AUTO_EQ` plus a synthetic `crack()` layer** at -10 dB on auto takes. The owner hates synth (memory `gun-audio-real-recordings`), so check whether this crack is audible.
- **Loudness:** `SHOT_TARGET` normalises each family to its loudest 100 ms, which can squash the differences between families.

**Playback suspects** (`src/client/Controllers/AudioController.luau`):
- **Voice stealing:** `acquire()` steals the oldest voice once a sound name has `Audio.VOICES_PER_SOUND = 4` voices, or the pool is full (`VOICES_2D = 24`, `VOICES_3D = 32`). A long full-length shot fired fast could be cut by its own next shot. Check this once shots are longer.
- **Tail fade:** `AudioController.fadeOut` and `Config/Audio TAIL_FADE` (0.8 × fire interval, 30–120 ms). Correct for autos per the pack guide. Make sure it never fires on semi guns or cuts a semi shot.
- **Region end:** `endsAt` and `LoopRegion` stop playback at the slice end, so a slice that is too short is a hard stop.
- **Upload quality:** the atlas goes up as one FLAC (`art-source/audio/ProPack/ProAtlas.flac`) and Roblox transcodes audio on upload. The owner said earlier "the quality is good but something about it is off (the way it uploaded?)". Compare a raw file against what plays in Studio.

## Where everything is
- **Pack (licensed, paid; never commit, already git-ignored):**
  - `vault/06 Assets/NewGunSounds/Guns/` (266 WAV);
  - `vault/06 Assets/NewGunSounds/ProSoundCollection_BonusSounds/` (152);
  - the pack's guide, `How To Setup Automatic Guns Sounds in Games.pdf`.

  For autos the guide says: play `shot_first_00` first, then `shot_01-08` at random; start `tail_only_00` with every shot and fade it when the next shot plays; `last_with_tail` is for the last shot.
- **Build:** `python -I tools/audio/build_pro_atlas.py` writes `art-source/audio/ProPack/ProAtlas.flac` and `.json`, plus the generated `src/shared/Config/GunAtlas.luau` (slice start, length and gain per file name; never edit it by hand).
- **Analysis helper:** `tools/audio/analyze_audio.py`. Python has numpy, scipy and soundfile. ffmpeg / ffprobe are not on PATH in Git Bash.
- **Mapping:** `src/shared/Config/GunSounds.luau`, one line per gun naming the pack files per slot (fire, fireFirst, fireLast, tail, magOut, magIn, rack, draw, and so on). Every numbered take plays round-robin with no repeats, with a small random pitch and level.
- **Logic:**
  - `src/client/Util/GunAudio.luau`: first shot, random takes, a tail with each shot faded by the next, the last-round shot.
  - `src/client/Controllers/AudioController.luau`: voices, atlas regions, fades.
  - `src/shared/Config/Audio.luau`: numbers.
  - `src/shared/Config/Sounds.luau`: `GUN_ATLAS`, currently v8 = 72558490061827.
- **Listening reels:** `art-source/audio/ProPack/audition/` (git-ignored). `Guns/<Gun>.wav` is rendered through the game's logic, and `<Gun> pack preview.wav` is the pack's own preview for the autos.
- **History of every pick and the owner's earlier verdicts:** `vault/02 Art/Sound Library Pick.md`.
  - §13: the v5 system and the mapping table.
  - §14 and §16: the owner's listens. Autos were "still a bit dull", the revolver had a "weird hit", the headshot was too metallic. His last verdict was footsteps back to Roblox's own and the knife good.
  - §17: the latest state (v8).

## What to do
1. **Get ears.** Find and set up whatever lets you actually judge audio: an audio-analysis or listening skill, waveform and spectrogram renders, loudness meters (EBU R128 / LUFS), A/B against the raw files. Write down what you used.
2. **Stop the early cuts.**
   - Rebuild the atlas so every shot keeps its full natural length: raise or remove the caps per family, and trim only true digital silence (for example -70 dB or lower) with a short fade.
   - Then check playback (voice stealing, region ends, tail fades) so a full shot is never cut by the next one. On a semi gun fired at its max rate, the previous shot's ring may be faded briefly, but never chopped.
3. **Undo processing that hurts.** For each semi family, A/B atlas slice against raw file: transient sharpness, low end (energy under 250 Hz), decay curve. If `pull_in`, the EQ shelves or the synthetic crack make it worse, remove them. The rule from v4 still holds: light processing wins.
4. **Check every sound:**
   - every gun's shots, tails, reloads, cock and rack, draw, dry fire and ADS;
   - the knife;
   - the hit, headshot and kill sounds;
   - surface impacts.

   Fix whatever is wrong: cut early, too quiet or loud against its neighbours, a wrong pick for the gun's type, clicks or pops.
5. **Upload a new atlas** (private, group 11116787): `python tools/opencloud/upload_asset.py --group 11116787 --type Audio <file> "GG Gun Atlas v9"`, then put the id in `Config/Sounds GUN_ATLAS`.
   - **The audio upload quota is 10 a month,** and v3 to v8 already used several this month. Get it right locally before uploading, and upload once.
6. **Test in Studio:**
   - The match place is placeId 133387545285290 (the Lobby is a separate Studio).
   - Fire every gun class: a single tap, a fast tap-fire, a long spray, a reload, an equip.
   - Render fresh reels so the owner can compare old and new.

## Rules (from CLAUDE.md and the owner)
- **Work from the vault:** read `CLAUDE.md`; the sound section of `vault/02 Art/Style Bible.md` (Valorant-like punchy designed real recordings, never synth); and `Sound Library Pick.md`.
- **Never commit or stage the pack, reels or atlas audio** (the repo is public). Stage exact paths only, never `git add vault` / `-A`. Commit nothing unless the owner asks.
- **Luau:** `--!strict`, tabs, numbers in `src/shared/Config`. Before finishing, `selene src`, `stylua --check src` and `rojo build -o build.rbxl` must be clean.
- **Rojo** (`rojo serve`, port 34872) syncs `src` into Studio. If Studio isn't connected, ask the owner to click Connect rather than hand-editing.
- **In Studio:** leave `TestMode = true` and no dev attributes. Don't `require` server modules from a running playtest.
- **New sounds** are only for real gaps, and only licensed ones. List each one with its licence.

## Done when
- Every semi gun's shot rings out to its natural end in game, measured: in-game slice length vs raw file, and a full-rate tap-fire test.
- Every gun sound is checked against its raw file and its neighbours, and the list of what changed is written up.
- The new atlas is uploaded once and wired in; lint, format and build are clean.
- Results go in `Sound Library Pick.md` as §18: what was cut before, the before and after numbers, the tools used to listen, and an honest grade per family.
- Then add fresh reels for the owner in `art-source/audio/ProPack/audition/`.
