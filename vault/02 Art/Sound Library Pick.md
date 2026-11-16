# Sound Library Pick (2026-11-13)

**Status (2026-11-13, late): v5 is live (§13).** Built the way the pack is designed: a first shot, random takes with no repeats, a tail with every shot faded by the next, and the last round. Every numbered take of every part is in use, matched to our guns by type. Atlas v4 is unchanged (it already held every take). The A/B against the pack's previews and the Studio test are in §13.4–13.5. **Start with §13.6.**

What this note covers:
- What is in the pack the owner bought.
- How each file measured.
- The picks for every gun, the knife and the extras.
- How the files get processed and wired up in Phase 2.

**Listen first:** `art-source/audio/ProPack/PickReel.wav` (173 s, git-ignored). The cue sheet `PickReel.txt` next to it gives the time of every clip. The reel plays:
- every pick raw, only resampled and level-matched;
- for each automatic gun, the pack's own spray preview.

Built from: the [Style Bible](Style%20Bible.md) §5, memory `gun-audio-real-recordings` (Valorant target, real recordings, layered, audition first), the pack's PDF guide, the LihFolk skill `lihfolk-sfx`, and the LihFolk notes *Combat Sound Design and Feedback*, *Spatial Audio and Mixing*, *Sound Design Pitfalls*, *Feedback Timing - Sound Visual and Haptic Sync* and *Music Licensing and Audio Upload Rules for 2026*. Earlier passes: [Gun Sound Overhaul](../05%20Production/Playtests/2026-11-08%20Gun%20Sound%20Overhaul.md), [Hit and Shot Feel](../05%20Production/Playtests/2026-11-09%20Hit%20and%20Shot%20Feel.md), [Gun Sound Packs](../03%20Research/Gun%20Sound%20Packs%20(Valorant-style).md).

---

## 1. What we have

| Library | Where | What | Used before? | Git |
|---|---|---|---|---|
| **New pack** (bought 2026-11-13) | `vault/06 Assets/NewGunSounds/` | 418 WAVs, 222 MB, all **96 kHz / 24-bit stereo**, essentially unclipped (2 files have 2 clipped samples each). `Guns/` (266) + `ProSoundCollection_BonusSounds/` (152) + the PDF *How To Setup Automatic Guns Sounds in Games* | No | **Ignored now** (`.gitignore`) |
| Snake's SECOND Authentic Gun Sounds Pack (F8 Studios, itch.io) | `vault/06 Assets/GunSoundEffectLibrary/` | 167 files: 9 mm, .308, 20 ga, pistol, revolver, mag and bipod foley | **Yes**: the 2026-11-08 atlas (`tools/audio/build_gun_sfx.py`, source `SNK`) and the live v2 atlas foley | **Ignored now** (third-party; was neither tracked nor ignored) |

Processed copies go to `art-source/audio/ProPack/` (ignored). Never commit raw or processed library files.

**Licence:** bought by the owner for this game. **Purchase source and licence terms: owner to fill in.** (The pack folder has no licence file.) How we use it, LihFolk's rule for every paid library:
- Upload privately under the group (11116787) for our game only.
- **Never tick "Distribute on Creator Store".**
- Never redistribute the files.

## 2. How the game plays guns today

- **One gun atlas.** `tools/audio/build_gun_sfx.py` (with `design_gun_sfx.py`) bakes every gun's shots and handling into one FLAC (`art-source/audio/GunSfx.flac`, 138 s, 4.6 MB). It is live as `Sounds.GUN_ATLAS` = 78823707282052 ("v2", 2026-11-09), and `AudioController` plays slices of it through `PlaybackRegion`. Generated tables: `Config/GunAtlas` and `Config/GunSoundSets`. Hand tweaks go in `Config/GunSounds` OVERRIDES.
- **Fields per gun:**
  - Firing: `fire`, `fireFar` (other players, 3D), `tail` (automatic guns).
  - Handling: `draw`, `rack`, `magOut`, `magIn`, `open`, `eject`, `shellIn`, `close`, `inspect`, `dryFire`.
  - Knife only: `heavy` and `hit*`.
- **Your own shot:** 2D, `fire` (`WeaponController` `playGun`). An automatic gun plays its `tail` `Audio.TAIL_AFTER` (1.5) fire intervals after the last shot. Each `fire` slice crossfades into the tail at that point.
- **Other players' shots:** `fireFar` in 3D at the muzzle, `InverseTapered`, 14–320 studs (`EffectsController`).
- **Mix:** SoundGroups Gun / Enemy / Feedback / Foley with ducking, glue and limiter (`Config/Audio`).
- **The v2 shots measure thin.** 50–85% of their first 80 ms sits at 1–4 kHz, and only 1–20% is under 250 Hz. That fits the owner's "dull, no punch". The new pack's shots carry 40–60% of their energy under 400 Hz.

## 3. How the pack wants automatic guns played (its PDF)

- **`shot_00_first`**: play it only on the first shot of a burst.
- **`shot_01..08`**: play these in random order for every following shot.
- **`tail_only`**: start it **with every shot** and fade it out fast when the next shot comes. Only the last tail rings, so tails never stack into mud.
- **`last_with_tail`**: meant for cutscenes, skip.

The `shot_NN` files are **hard-cut slices**:

| Set | Slice length | Pack fire rate | Our guns |
|---|---|---|---|
| SMG | 45–58 ms | 0.05 s | 0.075 s |
| Semi-auto rifle | 86–93 ms | 0.09 s | Phantom 0.091, Vandal 0.103 |
| Heavy MG | 190–213 ms | ~0.13 s (irregular) | Ares 0.077, Odin 0.064 |

The `tail_only` files fade in from silence, so they are built to start under the shot.

**Gap in our code:** our tail starts 1.5 fire intervals after the last shot. On the Stinger that leaves a ~60 ms hole between a 50 ms shot and the tail. **Fix (Phase 2):** bake each `fire` slice as the shot plus the head of `tail_only`, cut at `TAIL_AFTER` × fireInterval, and let the `tail` slice carry on from exactly there. That matches the PDF's "tail with each shot, faded by the next". Also add the **first-shot** variant (`fireFirst`).

## 4. What the measurements say

Method:
- Python with numpy, scipy and soundfile. The scripts are in the session scratchpad, not the repo.
- Per file: length, peak, RMS, loudest 100 ms (K-weighted, the same scale as `build_gun_sfx` `short_max`), crest, attack, decay to −40 dB, noise floor, band shares of the first 80–150 ms, stereo width, onset times (10 ms envelopes).
- Spectrogram contact sheets, which I looked at.

Findings that change the plan:

1. **Designed pre-roll = input lag.** Several shot files open with a mechanical click, and the main blast lands **30–100 ms later**. Shotgun: boom at 80–100 ms. Revolver: 50–70 ms. Rifle: 30–40 ms. Sniper 03/04: 70–90 ms. LihFolk timing: 0–30 ms late fuses with the trigger; 80 ms or more reads as lag. **Plan:** keep the click as a "mech" layer but move it to 6–10 ms before the blast, and start the slice ~3 ms before the click.
2. **The automatic shots are sub-heavy.** In the first 80 ms, 40–100 Hz holds:
   - MG: 39–58%.
   - Semi-auto rifle: 36–54%.
   - SMG: 6–21%.
   
   2–5 kHz holds only 2–7% in all three sets. That is big on headphones and muddy on phone speakers, where LihFolk says cues need 1–4 kHz content. **Plan:** +2–4 dB presence around 3 kHz, −2–3 dB shelf under 60 Hz on the auto sets.
3. **Semi-auto shots carry long outdoor tails** (baked slap echoes, 1–2.5 s). Shotgun files: the energy at 0.3–0.8 s is *higher* than in the first 80 ms. That is the echo, not a pump (no late mech clicks on the spectrogram). **Plan:** the class `hold`/`tau` trims own-shot tails (pistol ~0.75 s, rifle ~0.85 s, sniper ~1.8 s, shotgun ~1.1 s). The far versions keep more tail.
4. **The pistol shots have a stylised tonal ring** (a steady line at ~1–2 kHz for ~1 s on 01, 04, 05). That is designed character, Valorant-ish, but it could grate on a fast Classic. **Listen check.**
5. **Distinct takes inside one family:**
   - Sniper 01/02 are the same gun: 30% sub, full stereo.
   - Sniper 03 is 01 with a different 60 ms pre-section, mono.
   - Sniper 04 is bright and sub-less.
   - Rifle 03 is bright; rifle 01/02/04 are heavy.
   
   These are used to tell guns apart.
6. **No distant mics, no footsteps, no hit tick or headshot "tink", no knife-on-flesh.** Far versions are derived (§7). Hits keep the current sounds plus an optional weight layer.
7. **All 96 kHz.** Roblox takes 48 kHz at most, so everything is resampled to 48 kHz (polyphase) first.

## 5. Picks per gun

Picks are listed first (best take first); the cause follows. **Pitch** is varispeed baked into the files, so each gun gets its own size from a shared family.

The pack has only 9 shot families for 17 guns, so guns that share one are separated by pitch, EQ, tail length and a small second layer. That layering of real recorded parts is the Valorant method from the memory. No synth.

File names drop the `gun_` prefix.

| Gun (fire) | Shot (near, 2D) | Auto set | Layer / treatment | Why |
|---|---|---|---|---|
| **Classic** (semi 0.148) | `pistol_shot_01`, `_03`, `_04` (`02`, `05` spare) | — | ×1.0. Tail ~0.7 s | Front-loaded (0 dB inside 10 ms), crack + body + ring. 04 has the most body. |
| **Ghost** (suppressed) | `pistol_shot_silenced_01`, `_02`, `_04` | — | ×1.0. **No low-pass** (already dark: 6–8% above 5 kHz) | Real suppressed shot with the slide clacking (3 onsets, 0.5 s). 03 is the thinnest. |
| **Sheriff** (revolver 0.25) | `revolver_pistol_shot_02`, `_03`, `_04` (`01` spare) | — | ×0.97. Hammer click pulled in to −8 ms | Biggest low body of the sidearms (24–35% sub). 02 has the shortest click-to-boom. |
| **Shorty** (sawn-off) | `shotgun_shot_02`, `_03` | — | ×1.07, tail ~0.8 s, click pulled in | Smaller and higher than the Bucky from the same gun. 02 has the tightest pre-roll. |
| **Stinger** (SMG 0.075) | `submachine_auto_shot_01`–`09` round-robin + `shot_00_first_01` | `submachine_auto_shot_00_tail_only_01` | +3 dB presence, −2 dB under 60 Hz | The pack's real SMG set. Its 0.05 s rate stretches fine to 0.075. |
| **Spectre** (suppressed SMG 0.075) | `submachine_auto_shot_04`, `_06`, `_09` (+ the rest) + `first` | the same tail at −6 dB, low-passed ~3 kHz, shortened | ×0.97, gentle 1-pole low-pass ~5.5 kHz, −3 dB air shelf | **Weakest pick:** the pack has no suppressed SMG. If it sounds wrong, keep v2's Spectre (Carl Gustav M45 mics) for this one gun. |
| **Bucky** (pump 0.91) | `shotgun_shot_03`, `_04`, `_01` | — | ×0.97, full ~1.1 s tail, click pulled in | The biggest shotgun voice. 01 is very bright (78% air up front), so it is the third choice. |
| **Judge** (auto shotgun 0.286) | `shotgun_shot_02`, `_04` | tail cut from the shots' own decay | ×1.03, slices 0.43 s | Same gun as the Bucky but quicker and tighter. |
| **Vandal** (AR 0.103) | `semi_auto_rifle_shot_01`–`08` + `first_01` | `semi_auto_rifle_shot_00_tail_only_01` | ×0.95, **plus** the first 60 ms of `rifle_shot_02` at −8 dB (150–400 Hz band) for weight | Heavier and slower than the Phantom from the same set. The rifle layer is a real recording of a heavier gun. |
| **Phantom** (suppressed AR 0.091) | the same set + `first` | the same tail at −6 dB, shorter | ×1.02, light suppression (1-pole ~6.5 kHz, −3 dB) | The pack set was recorded at **0.09 s, exactly the Phantom's rate**. |
| **Bulldog** (bullpup 0.11) | the same set (`04`, `07`, `08` lead) | the same tail ×1.04 | ×1.06, **plus** the first 25 ms of `pistol_shot_03` high-passed at 1.5 kHz, −10 dB, as a crack | Brighter and snappier, so three rifles from one set still sound like three guns. **Listen check.** |
| **Guardian** (DMR semi 0.19) | `rifle_shot_01`, `_02`, `_04` | — | ×1.0, click pulled in (30–40 ms → 6 ms), tail ~1.1 s | The heaviest bodies in the pack (41–45% at 100–400 Hz). |
| **Marshal** (lever 0.667) | `rifle_shot_03`, `_04` | — | ×1.04 | The bright rifle take plus one heavy one: a lighter long gun than the Guardian. |
| **Outlaw** (double rifle semi 0.364) | `rifle_sniper_shot_04`, `_03` | — | ×0.98, pre-roll pulled in (70–90 ms!) | The bright, sub-less sniper takes: a sharp double-rifle crack. |
| **Operator** (bolt 1.667) | `rifle_sniper_shot_01`, `_02` | — | ×1.0. **Optional:** `weapon_cannon_shot_03` low-passed at 120 Hz, −12 dB, as a sub "boom" | Full stereo, 30% sub, 2.1 s tail: the AWP-style king. The cannon is a real recording, but it is a **listen check**. |
| **Ares** (LMG 0.077) | `machinegun_auto_heavy_shot_01`–`08` + `first_01` | `machinegun_auto_heavy_shot_00_tail_only_01` | ×1.04, +4 dB presence, −3 dB under 60 Hz | The pack MG. Each 0.2 s slice has a second mech transient at ~0.11–0.14 s, which the next shot cuts at our rate, so only the last shot keeps it. That is fine. |
| **Odin** (HMG 0.064) | the same set (`04`, `07` lead) + `first` | the same tail ×0.96 | ×0.96, **plus** a semi-auto rifle crack (high-pass 1.2 kHz, −9 dB) for edge at its higher rate | Deeper and faster than the Ares. |

**Handling picks.** Each one is a single clean take: head trimmed to ≤ 3 ms before the first transient, the swell kept on slides and draws.

| Gun | magOut | magIn | rack / cock | open / shellIn / close | inspect | dryFire | draw |
|---|---|---|---|---|---|---|---|
| Classic | `pistol_remove_mag_04` | `pistol_insert_mag_05` | `pistol_slide_fast_05` | — | `pistol_slide_slow_03` | `pistol_dry_fire_03` | `pistol_general_handling_08` + cloth |
| Ghost | `pistol_remove_mag_06` | `pistol_insert_mag_03` | `pistol_slide_slow_06` | — | `pistol_safety_switch_02` | `pistol_dry_fire_05` | as Classic ×1.04 |
| Sheriff | — | — | `revolver_pistol_cock_05` | `revolver_pistol_cylinder_open_01` / `revolver_pistol_load_bullet_02` / `revolver_pistol_cylinder_close_02`; eject keeps Snake `R44Eject` (the pack has no casings) | **`revolver_pistol_cylinder_spin_02`** | `revolver_pistol_dry_fire_01` | pistol draw ×0.95 |
| Shorty | — | — | `revolver_pistol_cock_03` ×0.88 | `revolver_pistol_cylinder_open_03` ×0.82 / `shotgun_load_bullet_05` / `revolver_pistol_cylinder_close_04` ×0.8 | `shotgun_pickup_01` | `shotgun_dry_fire_02` | `shotgun_pickup_02` ×1.06 |
| Stinger | `submachine_auto_magazine_unload_02` | `submachine_auto_magazine_load_03` | `submachine_auto_cock_04` | — | `submachine_auto_magazine_safety_switch_02` | `submachine_auto_dry_fire_02` | `rifle_grab_pickup_01` ×1.08 |
| Spectre | `submachine_auto_magazine_unload_03` | `submachine_auto_magazine_load_02` | `submachine_auto_cock_03` | — | `pistol_safety_switch_01` | `submachine_auto_dry_fire_01` | as Stinger |
| Bucky | — | — | **pump** `shotgun_cock_04` (`05` alt) | `shotgun_load_bullet_08` / `05` (shellIn) | `shotgun_cock_02` ×1.05 | `shotgun_dry_fire_01` | `shotgun_pickup_02` |
| Judge | `semi_auto_rifle_magazine_unload_02` ×0.85 | `semi_auto_rifle_magazine_load_03` ×0.85 | `semi_auto_rifle_cock_05` ×0.9 | — | `shotgun_load_bullet_07` (shell rattle) | `shotgun_dry_fire_02` | `shotgun_pickup_02` ×0.94 |
| Vandal | `semi_auto_rifle_magazine_unload_02` | `semi_auto_rifle_magazine_load_02` | `semi_auto_rifle_cock_05` | — | `semi_auto_rifle_safety_switch_03` | `semi_auto_rifle_dry_fire_01` | `rifle_grab_pickup_01` |
| Phantom | `semi_auto_rifle_magazine_unload_04` | `semi_auto_rifle_magazine_load_03` | `semi_auto_rifle_cock_03` | — | `semi_auto_rifle_safety_switch_01` | `semi_auto_rifle_dry_fire_03` | ×1.03 |
| Bulldog | `rifle_magazine_unload_04` | `rifle_magazine_load_01` | `submachine_auto_cock_01` ×0.95 | — | `rifle_safety_switch_02` | `rifle_dry_fire_01` | ×1.0 |
| Guardian | `rifle_magazine_unload_02` | `rifle_magazine_load_04` | `semi_auto_rifle_cock_01` | — | `rifle_load_bullet_04` | `rifle_dry_fire_02` | ×0.97 |
| Marshal | — | — | **lever** `rifle_cock_01` (cut to ~0.55 s so it ends before the next shot) | shellIn `rifle_load_bullet_06` / `07` | `rifle_load_bullet_03` | `rifle_dry_fire_03` | ×0.98 |
| Outlaw | — | — | — | `revolver_pistol_cylinder_open_02` ×0.8 / `rifle_load_bullet_04` ×0.85 / `revolver_pistol_cylinder_close_04` ×0.75; eject keeps Snake `R44EjectFloor` | `rifle_sniper_cock_04` (part) | `rifle_sniper_dry_fire_01` | ×0.95 |
| Operator | `rifle_magazine_unload_01` ×0.9 | `rifle_magazine_load_02` ×0.9 | **bolt** `rifle_sniper_cock_02` (a full real bolt cycle, 0.8 s) | — | **`rifle_sniper_scope_zoom_lens_04`** | `rifle_sniper_dry_fire_01` | ×0.94 |
| Ares | `machinegun_auto_heavy_reload_02` split at its onsets (box off / box on) | (same file) | `semi_auto_rifle_cock_02` ×0.88 | — | `foley_soldier_gear_equipment_rattle_movement_med_01` | `rifle_dry_fire_04` ×0.85 | `foley_soldier_gear_equipment_metal_cloth_heavy_movement_strong_02` |
| Odin | `machinegun_auto_heavy_reload_01` split (feed cover open, belt in, slam) | (same file) | `semi_auto_rifle_cock_04` ×0.82 | open / close from `machinegun_auto_heavy_reload_01` | as Ares ×0.9 | `rifle_dry_fire_04` ×0.8 | as Ares ×0.9 |

"Cloth" in the draws means `foley_cloth_light_fast_movement_04` (a short swell) at −8 dB under the grab. **Optional new sound:** an ADS `aim` field for scoped guns, using `rifle_sniper_scope_zoom_lens_07`. It needs a one-line hook where ADS starts; that is fp-feel's area, so it's asked for, not done.

## 6. Knife, hits, movement, UI, Mods

| For | Pick | Why / note |
|---|---|---|
| **Knife light slash** (`fire`, 1-2-3 chain) | `whoosh_swish_small_01`–`04`, high-passed ~250 Hz | 4 takes for the round-robin. The energy peaks at the start (a whip, not a swell), so trigger on the swing's fast frame. `small_02` has a tonal whistle (blade). |
| **Knife heavy** (`heavy`) | `whoosh_swish_high_fast_01`–`04` ×0.92, full band | Bigger and lower air. |
| **Knife on body** (`hitBody`) | current `KnifeHitBody` + `punch_grit_wet_impact_01` / `04` / `05` at −6 dB | Adds the wet weight Valorant knife hits have. The pack has no blade-in-flesh sound, so the current one stays for the blade. |
| **Body-hit weight layer** (optional) | `punch_general_body_impact_02` / `03` / `05` at −10 dB under `HitBody` | Owner asked for punchier hits. The headshot and kill sounds stay: the pack has no "tink". **Coordinate with hit-feedback** (they own the visuals; the sounds sit in `Config/Sounds`). |
| **PopCircuit Bat** (knife skin, later skin sounds) | swing `whoosh_swish_high_fast` ×0.85; hit `punch_slap_whack_hit_01` / `02` + `wood_block_sticks_hit_clap_01` (a tonal "tok") | Parked until skins get their own sound sets. |
| **Slide start / land gear** | slide: `foley_cloth_light_fast_movement_04` layered on the current skid; land: `foley_soldier_gear_equipment_movement_grab_item_02` at −10 dB | Gear rattle on landings. |
| **Footsteps** | none in the pack | The current steps stay. |
| **UI** | `switch_button_push_on_off_*` are mechanical clacks | **Not recommended**: the Style Bible wants UI sounds short, soft and tonal. Parked. |
| **Announcer** ("headshot", "killing spree", "frenzy") | — | Classic arena-FPS voice, not the Valorant direction. Parked. |
| **Mods (park for the [Mod Audio](Mod%20Audio.md) shortlist)** | `gas_large_flame_ignite_01` / `02` (Molly / Firewall ignite); `explosion_small_*` (Molly burst); `fuse_stop_burn_out_bomb_dynamite_*` (fuse); `gas_leak_0*_loop` (Frost / vent hiss); `taser_stun_gun_zap_electricity_*` (zaps); `powerup_whiz_nightvision_goggles_on_01` (Recon on); `radio_walkie_talkie_static_*` (Recon ping) | Not in this pass (work in phases). The `sci-fi_weapon_blaster_*` files are synth-flavoured, so they're out. |

## 7. Processing plan (Phase 2)

Everything is in `tools/audio/build_gun_sfx.py`: a new source key `PRO` = `vault/06 Assets/NewGunSounds`, plus `design_gun_sfx.py` for the layers. That keeps the one-atlas pipeline and its level targets.

1. **Resample** 96 → 48 kHz (polyphase).
2. **Trim:**
   - Pull the pre-roll in (§4.1): the mech click goes 6–10 ms before the blast, and the slice starts 3 ms before the click.
   - Cut tails with the class `hold`/`tau`, with a 10–50 ms fade.
   - Handling: head ≤ 3 ms before the first transient ("hit"), or keep the swell ("swell").
3. **Clean and shape:**
   - High-pass 35 Hz.
   - Auto sets: presence +2–4 dB at ~3 kHz, −2–3 dB shelf under 60 Hz.
   - Suppressed guns: the gentle 1-pole roll-off, never a muffle.
   - Then the existing transient / 4:1 glue / light saturation chain at the class preset.
4. **Layers** (§5) aligned on the blast onset, each band-limited to its job.
5. **Loudness:** keep the project's measured targets so `Config/Audio` mix numbers stay valid. The project's own targets win over LihFolk's generic −18 LUFS.
   - `short_max` (loudest 100 ms, K-weighted): pistols −11.5, rifles −10.5, marksman −9.5, snipers −8.5, suppressed −13.
   - Handling −15, draws and inspects −17.
   - Every slice ≤ −1 dBTP.
6. **Automatic guns:** each `fire` slice = shot + head of `tail_only`, cut at `TAIL_AFTER` × fireInterval. `tail` = the rest. A new `fireFirst` slice. Up to 6 shot variants per gun (the atlas picks a random slice).
7. **Far (`fireFar`, others' shots, 3D):** derived from each gun's own takes, so an enemy Vandal sounds like your Vandal:
   - softer transient, low-passed ~4–5 kHz;
   - more of the baked outdoor tail kept (that suits distance);
   - **mono** (the side channel is −3 to −11 dB under the mid, so the sum is safe; checked per take).
   
   The alternative is to keep v2's real far mics; it can be compared in the reel.
8. **Format:**
   - The atlas stays one **FLAC, 48 kHz stereo 16-bit** (2D own shots keep their stereo width; far slices are L = R).
   - Estimate: ~230–260 s and ~9–11 MB, under Roblox's 7 min / 20 MB. OGG Vorbis (soundfile supports it) only if the file goes over 20 MB.
   - The knife slices move into the gun atlas, so it is **one upload**. The hit / kill slices already live there and are carried over unchanged.
9. **Audition gate:** `build_gun_sfx.py --preview` renders before (v2) / after for every gun: single, burst, spray, reload. **The owner listens before the upload** (memory: audition first).

## 8. Code plan (Phase 2, audio files only)

- **`Config/GunSounds`:** add a `fireFirst` field to the type (optional `aim` for scoped guns).
- **`Config/Audio`:** `FIRST_SHOT_GAP` (seconds without a shot before `fireFirst` plays again). It is data, not hard-coded.
- **`WeaponController`:**
  - play `fireFirst` instead of `fire` after a gap;
  - the tail timing stays `TAIL_AFTER`, but the slices now crossfade with no gap;
  - spectated shots in `EffectsController` do the same.
- **`Config/Sounds`:** the new `GUN_ATLAS` id after the upload (`tools/opencloud/upload_asset.py --group 11116787 --type Audio`; the script already handles `.flac`).
- **Hooks in other lanes' files** (asked for, not edited): an ADS-start hook for `aim` (fp-feel, `ViewmodelController`); a hit weight layer is a `Config/Sounds` change of mine, but tell hit-feedback.
- **Checks:** `selene src`, `stylua --check` on the changed files, `rojo build -o build.rbxl`; a short Studio test on the match place (`get_studio_state` first; `TestMode` stays true).

## 9. What I could and could not judge without ears

**Could judge (measured or seen):**
- format, clipping, loudness and headroom;
- where the blast lands (pre-roll lag);
- tail length and baked echo;
- band balance (sub-heavy vs thin);
- stereo width (mono safety);
- take consistency (sniper 03 = 01 with a new head);
- the auto-set fire rates (SMG 0.05, AR 0.09, MG ~0.13 s);
- whoosh shape (an onset peak, not a swell).

**Could not judge:**
- whether the guns *feel* Valorant (punchy and designed) or too real;
- whether the pistol's tonal ring grates on fast fire;
- whether the three rifles and the two MGs separate enough after pitch and layers;
- the Spectre's suppression treatment;
- how the outdoor tails sit indoors;
- whether the whooshes read as a blade or as wind;
- whether the cannon boom under the Operator is too much.

**These are the listen checks for the reel.**

## 10. Decisions (answered 2026-11-13, owner via the lead session)

1. **Go** with these picks; keep every choice swappable.
2. **Licence:** the owner bought the pack for this game. Upload private, under the group only. The purchase source and terms are for the owner to fill in (§1).
3. **Far sounds:** derived from each gun's own shot.
4. **Operator:** yes to a low boom, but subtle and under the crack, not a cannon. Built as `weapon_cannon_shot_03` band-passed 35–100 Hz at −15 dB under the shot's peak.

## 11. Phase 2 results (2026-11-13)

### 11.1 What was built
- **`tools/audio/pro_gun_sfx.py` (new):**
  - every pick as a table (`SEMI`, `AUTO`, `FOLEY`, `MIX`, `SETS`);
  - the processing from §7;
  - the knife, body-hit and slide extras.
- **`tools/audio/build_gun_sfx.py`:**
  - uses it (`--no-pro` builds the old v2 atlas);
  - builds only the handling slices some gun uses;
  - writes `fireFirst`;
  - keeps alternates in the atlas (§11.2);
  - Akimbo removed (out of the game);
  - slice gap 0.12 s.
- **Atlas v3:** `art-source/audio/GunSfx.flac`, 178.5 s, 9.0 MB, 48 kHz stereo 16-bit FLAC, 252 slices in 116 names. That is under Roblox's 7 min / 20 MB. Uploaded once, privately, as "GG Gun Atlas v3" = **119437853694239**. The v2 atlas was 78823707282052.
- **Generated:** `Config/GunAtlas` and `Config/GunSoundSets` (17 guns, `fireFirst` on the 7 pack-auto guns).
- **Code:**
  - `Config/GunSounds`: the `fireFirst` field; the knife's `fire` / `heavy` / `hitBody` / `fireFar` point at the pro slices; the OVERRIDES comment lists the one-line swaps.
  - `Config/Audio`: `FIRST_SHOT_GAP = 0.25`.
  - `WeaponController`: your first shot after a 0.25 s gap plays `fireFirst`.
  - `EffectsController`: the same for a spectated player.
  - `Config/Juice`: the slide sound is now `gun:ProSlideStart` (the skid plus a cloth swell, same loudness).
- **The SMG tail gap is fixed in the files,** with no code change. Every automatic `fire` slice is the shot plus the head of the pack's tail, cut at `TAIL_AFTER` × fireInterval. The `tail` slice starts exactly there, with a 30 ms crossfade, so letting go of the trigger leaves no hole.
- **Pre-roll measured in the built atlas:** on every semi, pump and bolt gun the blast now lands **9–15 ms** after the slice start (it was 30–100 ms on the shotgun, revolver, rifle and sniper files). Full-band sound starts at 0–1 ms.
- **Tone vs v2 (first 80 ms):** under 250 Hz, v2 had 3–52%; v3 has **30–61%**. That is the weight v2 lacked. The 2–5 kHz crack band went from 7–60% down to 6–16%. That is the main thing to listen for on phone speakers (§11.3).
- **Loudness:** the own-shot targets are unchanged (`short_max` −11.5 … −8.5, ≤ −1 dBTP). Shots that can't reach theirs without heavy limiting get up to 2× `Sound.Volume` in `GunSoundSets` (the existing `boost` rule). The knife and slide slices are levelled to the slices they replace, so the Config volumes stand.
- **Hits:** `HitBody` has a pro-pack body punch under it at −9 dB. The 2026-11-09 one is still `gun:HitBodyV2`. Headshot and kill are unchanged (the pack has no "tink").
- **Reels (git-ignored):**
  - `art-source/audio/GunSfxPreview.wav` (250 s): every gun at game volumes: draw, inspect, shots, a spray with its first shot and tail, dry fire, reload. Cues in `GunSfxPreview.txt`.
  - `HitSfxPreview.wav`: the hits.
  - `ProPack/PickReel.wav`: the raw picks.

### 11.2 How to swap a pick
- **No upload needed** (slices already in the atlas), in `Config/GunSounds` OVERRIDES:
  - any handling field can point at any `gun:Pro*` slice in `Config/GunAtlas`;
  - each sound's pitch and volume;
  - the Spectre can go back to the 2026-11-09 designed one (`gun:SpectreV2Fire` / `SpectreV2FireFar` / `SpectreV2Tail`; the exact lines are in the OVERRIDES comment).
  
  The body hit can go back with `Config/Sounds` `HitBody = "gun:HitBodyV2"`. The old knife sounds are still `atlas:KnifeSwing` / `KnifeSwingHeavy` / `KnifeHitBody`.
- **New take, new layer or new tail length:**
  1. Edit the tables in `tools/audio/pro_gun_sfx.py`.
  2. Run `python -I tools/audio/build_gun_sfx.py --no-luau --preview` and listen.
  3. Run `upload_asset.py --group 11116787 --type Audio art-source/audio/GunSfx.flac "GG Gun Atlas v4"`.
  4. Rebuild without `--no-luau` and put the new id in `Config/Sounds` `GUN_ATLAS`.
  
  Build the Luau only together with the new id: Rojo syncs it into Studio at once.
- Each preset's presence (crack), drive and tail length is one number in `pro_gun_sfx.py` (`PISTOL`, `MAGNUM`, `AR`, `MG`, …).

### 11.3 Listen for these first (`GunSfxPreview.wav`, then in game)
1. **Spectre:** the pack has no suppressed SMG, so this is the pack SMG darkened. If it's wrong, use the V2 swap (§11.2).
2. **Classic's ringing tail:** a tonal ~1–2 kHz ring is designed into the pack's pistol, shortened by the pistol preset to about 0.5 s. Check it doesn't grate on fast taps. If it does, a shorter `length` / `tau` for `Classic` in `SEMI`.
3. **Weight vs crack on phone or laptop speakers:** v3 is much heavier than v2. If guns sound boomy or small on small speakers, raise `presence` in the presets.
4. **Three rifles from one set:** Vandal ×0.95 with a heavy-rifle layer, Phantom ×1.02 suppressed, Bulldog ×1.06 with a pistol crack. Are they different enough? The same for Ares / Odin.
5. **Operator boom:** subtle by request. Check it's felt, not heard.
6. **Knife:** whooshes that read as a blade, not wind (the low rumble is cut at 250 Hz).
7. **Release tails:** the suppressed Phantom / Spectre tails sit low (−3 dB and low-passed on purpose).

### 11.4 Studio test (2026-11-13, match place 133387545285290)
**Copied by hand, not through Rojo.** The Rojo plugin wasn't connected (Connect needs the owner's click), so my changed Luau files were copied into the match place:
- **The six files shared with other sessions' uncommitted work** (`Config/Sounds`, `Audio`, `Juice`, `GunSounds`, `WeaponController`, `EffectsController`): first checked that Studio held exactly the disk text minus my edits. Then only my edits were applied (Studio MCP exact find-and-replace). So no other session's unsynced work was pushed.
- **The two generated files** (`Config/GunAtlas`, `GunSoundSets`): replaced whole.
- **After copying, all 8 match the disk files exactly** (32-bit FNV hash of the full text). When the owner connects Rojo, it will find them already equal.

Playtest (Studio test hooks `DevAction` / `DevHold`), slices logged as they played:
- **Vandal spray, 0.6 s held:** the first shot `VandalFireFirst`, then `VandalFire` variants about 0.11 s apart, then `VandalTail` 0.15 s after the last shot (= 1.5 × 0.103).
- **Classic:** draw (`ProDrawPistol`), slide (`ProPistolSlide`), tap (`ClassicFire`).
- **Knife:** a light slash (`ProKnifeSwing`).

Every sound came from atlas v3 and was loaded when it played. The console showed no errors from these changes. The 3 "asset type does not match" errors for `rbxassetid://203785492` are not in `src` (not audio's).

**Not tested in Studio:** listening, with no ears in the loop: §11.3 is the owner's list. Also not tested: enemy (3D) shots and the spectated first shot, which need a second player.

## 12. v4: the pack as a library (2026-11-13, evening)

### 12.1 What the owner said about v3, and the causes found
- **"Something about them's off."** v3 put every pack shot through the old v2 glue chain:
  - transient boost;
  - 4:1 compressor;
  - saturation;
  - presence and sub EQ;
  - pitch shifts of 0.95–1.07 to tell guns apart;
  - extra layers;
  - mono, low-passed far versions.
  
  The pack's shots are already finished designs, so that chain coloured and flattened them. **v4 does none of it:** a resample, a trim, and one gain per family (no limiter, no compressor, no EQ).
- **"Still using old reload sounds."** True. v3 kept two Snake-pack slices (the Sheriff and Outlaw case ejects), and the knife's draw, inspect, flip and surface hits came from the old shared atlas. **v4: no gun or knife sound comes from anything but the pack.** The Snake pack and the v2/v3 sounds are gone from Config.
- **"The whooshes sound like impact things."** Measured cause: the pack's `whoosh_swish_*` files sit at 60–260 Hz with almost nothing above 2 kHz (a low "whump"). v3 cut them below 250 Hz, which left the thud. **v4's knife uses cloth swishes:** pure air, a bell-shaped swell, their first 20 ms 11–17 dB under the peak. They're cut so their peak lands where the swing expects it (60 ms light / 90 ms heavy, `Config/Animations` KNIFE_FEEL). The hits play separately, only when the blade lands.
- **"The impact sounds are pretty bad."** Those were the 2026-11-09 GDC/Freesound hits. **v4 builds them from the pack** (§12.3).

### 12.2 How v4 is built
- **Builder:** `tools/audio/build_pro_atlas.py`. `build_gun_sfx.py` is marked superseded; `pro_gun_sfx.py` (v3) is removed.
- **Atlas:** **337 slices, 202.8 s, 12.0 MB** (under Roblox's 7 min / 20 MB). Uploaded privately to the group as **"GG Gun Atlas v4" = 86848219110428** (`Config/Sounds` `GUN_ATLAS_V4`).
- **Every gun-relevant pack file is its own slice, named by its file name:**
  - all of `Guns/`, except the 3 auto "preview" bursts and the tank / cannon shots;
  - from the bonus folder: whooshes, cloth, punches, slaps, wood blocks, sheet metal, small metal, gear, switches.
  
  Ambiences, birds, explosions, radios, sci-fi and announcer files are out, and the Mod-type sounds are parked for the Mod pass.
- **Processing:**
  - 96 → 48 kHz, stereo kept.
  - **Head:** trimmed 2 ms before the first sound.
  - **Click pull-in:** the designed click before the blast is pulled to 8 ms (revolver, rifle, sniper and shotgun shots; it was 30–100 ms, which read as lag). The suppressed pistol is left alone: its pop and slide clack are one sound.
  - **Tail:** cut 55 dB under the peak with a 40 ms fade, capped per kind (pistol 1.0 s, shotgun / rifle 1.6 s, sniper 2.0 s, auto tails 1.6 s).
  - **The pack's hard-cut auto shots:** only a 3 ms de-click.
  - **Level:** one gain per family (a gun's shots + its first shot + its tail; a reload part's takes), so the pack's own balance inside a family stays. The gain is never allowed to push past −1 dBTP. A family that falls short of its target keeps a `gain` in `Config/GunAtlas`, applied by `AudioController`. It is mostly the peaky handling clicks, short by 2–9 dB.
- **Checked against the raw files** (`zz raw vs processed` in the audition, and the builder's report): plain shots keep their tone and punch exactly (band difference 0.0 dB, crest unchanged). The pulled-in shots differ only in their first 150 ms, because the blast now starts sooner.
- **Automatic guns are played as the pack's guide says:**
  - the first-shot file on a burst's first shot;
  - the shot files in round robin;
  - the tail **started with every shot**, with the next shot fading the last one over `Config/Audio` `TAIL_FADE` = 0.05 s.
  
  This replaces v3's baked crossfade (`AudioController.fadeOut`, `WeaponController.playTail`, the spectated tail in `EffectsController`).
- **Enemy shots (3D):** the gun's own files. Auto guns use the pack's `last_with_tail` (one shot with its full tail). No mono fold, no low-pass; `Config/Audio` `ENEMY_EQ` stays as the only colouring.

### 12.3 Hits, impacts, knife (built from the pack, A/B takes)
| Sound | Default | Alternative |
|---|---|---|
| Body hit (`Sounds.HitBody`) | `hit_body_A`: punch + a slap's 35 ms snap | `hit_body_B`: wet punches |
| Headshot (`HitHead`) | `hit_head_A`: the wood block's bright tonal tock over a punch | `hit_head_B`: slap + a sheet-metal ring |
| Kill (`Kill`, pitched up per kill) | `kill_A`: sheet-metal clang over a wet punch | `kill_B`: wood-block ring + slap |
| Headshot kill (`KillHead`) | `kill_head_A`: kill A + the wood tock | — |
| Damage taken (`Damage`) | `damage`: a muffled body thud | — |
| Bullet on surfaces (`Sounds.IMPACTS`: Hard, Metal, Glass, Wood, Soft) | `impact_hard` / `impact_metal` / `impact_wood` / `impact_soft` | — |
| Knife | `knife_whoosh` (cloth 02, 03, 10, 14), `knife_whoosh_heavy` (cloth 12, 04, 05), stab = `punch_grit_wet_impact` 01/04/05, walls / metal / wood / soft = the impacts, draw = `metal_small_movement_04/05`, flip = pistol safety clicks | any file in the audition |
| Low-ammo tick | rifle safety-switch clicks | — |

The pack has no ricochet or debris files, so "hard" is a slap's crack with a little small-metal grit. **Bullet surface impacts play (2026-11-13, hit-feedback's hook):** `Util/ImpactFx.impact` plays `Sounds.IMPACTS[kind]` in 3D at the hit point (Enemy group), at most one every 30 ms. Volume 0.5, range 60 and the gap are in `Config/HitFx` `IMPACT_SOUND`. Only world hits play it: bodies keep `HitBody` / `HitHead`, and the knife keeps its own wall sounds. Checked in Studio by hit-feedback: a Vandal shot at the range floor played `impact_hard` take 1 at the hit point.

### 12.4 Choosing your own sounds (owner)
1. **Listen:** `art-source/audio/ProPack/audition/` (git-ignored). Every file there is exactly a slice of the atlas, named like its slice.
   - `Guns/<Gun>.wav`: each gun's current set, played like the game: draw, inspect, shots or a 10-round spray + a 3-round burst with the tail behaviour, dry fire, reload parts.
   - `<family> shots` / `<family> handling`: every take of every family.
   - `bonus …`: the foley files.
   - `00 built (knife, hits, impacts)`: the whooshes and the hit A/B candidates.
   - `zz raw vs processed`: the raw file, a gap, then what the game plays.
2. **Swap:** in `src/shared/Config/GunSounds.luau`, each slot is one line naming files, e.g. `magIn = S({ A .. "magazine_load_02", A .. "magazine_load_01" }, FOLEY)`. Change or add a file name (the prefixes `P`, `R`, `SG`, `M`, `A`, `RF`, `SN` and `H` are spelled out at the top). Several names = a different one each play.
   - Volume is the second value; pitch is optional (`around(1.03)`).
   - Hits, kills and impacts are one line each in `src/shared/Config/Sounds.luau` (change `_A` to `_B`).
   - **No rebuild or upload needed.** Rojo syncs the line into Studio.
3. **Only a new trim or a new built mix needs a rebuild:**
   1. `python -I tools/audio/build_pro_atlas.py --no-luau`, then listen.
   2. Upload with `tools/opencloud/upload_asset.py --group 11116787 --type Audio art-source/audio/ProPack/ProAtlas.flac "GG Gun Atlas v5"`.
   3. Rebuild without `--no-luau` and set `GUN_ATLAS_V4` in `Config/Sounds` to the new id.

### 12.5 Listen for these first
1. **Every gun's reel** in `audition/Guns/`. Does each sound like the pack does raw (compare `zz raw vs processed`)? If anything is still "off", it is now the pick, not the processing.
2. **Spectre:** the pack has no suppressed SMG. v4 gives it the pack's real suppressed 9 mm shots (thump + action, no room tail) at ×1.03. The alternative is the plain SMG set (Stinger's files).
3. **Phantom:** the pack has no suppressed rifle either. It has the other 4 takes of the Vandal's rifle and a half-volume tail. Is it different enough from the Vandal?
4. **Shared recordings:**
   - Bulldog = the same rifle at ×1.03;
   - Odin = the MG's other takes at ×0.97;
   - Ghost and Spectre share the suppressed shots;
   - Guardian / Marshal share the 4 rifle takes, and Outlaw / Operator the 4 sniper takes.
   
   The pack has 9 gun families for 17 guns, so some sharing can't be avoided.
5. **Classic's ring:** the pack's pistol ring (~1–2 kHz) is now untouched, up to the 1.0 s cap.
6. **Hits:** A vs B for the body, the headshot and the kill. **Knife:** whooshes (air, not a hit) and the wet stab.
7. **Loudness between guns:** families were levelled to the old targets where their peaks allowed. Guns may still differ in loudness; each gun's `FIRE` volume is one number in its line.

### 12.6 Test (Studio, match place, 2026-11-13 evening)
- **Rojo was connected this time:** all changed scripts in Studio were checked by hash to match the disk files exactly, and the deleted `GunSoundSets` is gone from Studio.
- **First run caught a bug:** the several-files ids cached their merged list into the frozen atlas table, which errored inside `fireShot`. **Fixed** with a separate cache, re-synced and re-tested.
- **Second run, through the Studio hooks (`DevAction` / `DevHold`):**
  - **Vandal spray:** `…first_01`, then `…shot_01..04` in round robin, with the tail on each shot. **0.25 s after release only one voice was still sounding: the last tail.**
  - **Classic:** `pistol_general_handling_08` (draw), `pistol_slide_fast_05`, `pistol_shot_04`.
  - **Knife:** `metal_small_movement_05` (draw), `knife_whoosh`.
- **No errors from audio.** The 3 "asset type does not match" errors for `rbxassetid://203785492` are not in `src`.
- **Not checked:** how anything *sounds* (no ears; this is §12.5). Also not checked: hit and kill sounds in play (they need hits on a target), and enemy 3D shots (need a second player). Bullet surface impacts were checked by hit-feedback (§12.3).
- **Checks:** `selene src` (0 errors, 0 warnings), `stylua --check src` and `rojo build` all clean.

## 13. v5: built the way the pack is designed, every take used (2026-11-13, late)

The owner, after v4: *"we need this to be good. use a lot of the sounds"*. He asked for:
- the pack's guide followed exactly: a first shot, random takes, tails faded by the next shot, a last shot;
- every numbered take of every sound in use, "so it is random and not the same every time for cocking etc.";
- the pack's sounds matched to our guns by name and type.

### 13.1 The system (`src/client/Util/GunAudio.luau`, new)
The same logic plays your gun (2D), a spectated player's (2D) and everyone else's (3D). State is kept **per shooter** (your gun slot, or a character), so two guns or two players never fade each other's tails.
- **First shot:** a shot is a sequence's first when no shot came for **one fire interval + `FIRST_SHOT_GAP` (0.12 s)**. It plays `fireFirst` (the pack's `shot_00_first`).
- **Random takes:** every other shot plays one of the `fire` takes at random, **never the same take twice running** (`AudioController`'s picker over the whole `a|b|c` list). On top: a pitch of ±2 % on shots / ±3 % on handling (the slot's `pitch`), and a level of ±1.5 dB (`Config/Audio VOLUME_JITTER_DB`).
- **Tails:** `tail` (the pack's `tail_only`) **starts with every shot**. The next shot fades the ringing one over **0.8 × the fire interval, kept inside 30–120 ms** (`Config/Audio TAIL_FADE`), so only the final tail rings on: the guide's ">--\ >-\ >--\ >-----".
- **Last round:** the shot that empties the mag plays `fireLast` (the pack's `last_with_tail`) with no separate tail. This is for your own gun only; we don't know other players' ammo.
- **3D:** other players' shots use the same logic at the muzzle (`fireFar` takes + `tail`). Suppressed guns carry a shorter way (`Config/Audio SUPPRESSED_RANGE` = 180 studs, instead of 320), as Riot does for Valorant.
- **Handling:** every slot (rack / bolt / pump / slide, mag out / in, shells, dry fire, draw, inspect) lists **all** the pack's numbered takes for that part. One plays at random each time, never twice running.
- **Code changed:**
  - `Util/GunAudio` (new);
  - `WeaponController`: the shot calls `GunAudio.shot(slot, config, { lastRound })`; the old global tail is removed;
  - `EffectsController`: the spectated and 3D paths call `GunAudio.shot`;
  - `AudioController`: level jitter, a range per play, `fadeOut`;
  - `Config/Audio`: `TAIL_FADE`, `FIRST_SHOT_GAP`, `VOLUME_JITTER_DB`, `SUPPRESSED_RANGE`;
  - `Config/GunSounds`: rewritten. `takes(prefix, 1, 8)` lists numbered files.

### 13.2 The mapping (pack family → our guns, every take)
Takes per slot are the pack's numbered files (e.g. "shot 01–08"). The pack has 9 gun families for our 17 guns.

| Our gun (class) | Pack family | fire | first / tail / last | rack / bolt / pump | mag out / in | shells / rounds | dry | draw | inspect |
|---|---|---|---|---|---|---|---|---|---|
| Classic (pistol) | pistol | shot 01–05 | — | cock 01–07 | remove_mag 01–06 / insert_mag 01–05 | — | dry 01–06 | general_handling 05–10 | slide_slow 01–06 |
| Ghost (suppressed pistol) | pistol, suppressed shots | shot_silenced 01–04 | — | slide_fast 01–06 | remove_mag 01–06 / insert_mag 01–05 | — | dry 01–06 | general_handling 05–10 | general_handling 02–04 |
| Sheriff (revolver) | revolver | shot 01–04 | — | cock 01–05 | cylinder_open 01–03 / cylinder_close 01–04 | load_bullet 01–05 (eject: pistol load_bullet 01–07) | dry 01–05 | general_handling 05–10 | cylinder_spin 01–02 |
| Shorty (sawn-off) | shotgun (hinge: revolver cylinder open / close, hammers: revolver cock) | shot 01–04 | — | revolver cock 01–05 | open 01–03 / close 01–04 | load_bullet 01–08 | dry 01–02 | pickup 01–02 | safety 01–04 |
| Stinger (SMG) | SMG (auto set) | shot 01–09 | first / tail / last | cock 01–04 | mag_unload 01–03 / mag_load 01–04 | — | dry 01–03 | rifle grab + shotgun pickup 01–02 | mag safety 01–02 |
| Spectre (suppressed SMG) | SMG (auto set), tail at half, 180-stud range | shot 01–09 | first / tail ×0.5 / last | cock 01–04 | 01–03 / 01–04 | — | dry 01–03 | as Stinger | load_bullet 01–04 |
| Bucky (pump) | shotgun | shot 01–04 | — | pump cock 01–05 | — | load_bullet 01–08 | dry 01–02 | pickup 01–02 | safety 01–04 |
| Judge (drum shotgun) | shotgun (drum: semi-auto rifle mags) | shot 01–04 | — | cock 01–05 | rifle mag_unload 01–04 / mag_load 01–05 | — | dry 01–02 | pickup 01–02 | load_bullet 01–08 |
| Vandal (rifle) | semi-auto rifle (auto set) | shot 01–08 | first / tail / last | cock 01–05 | mag_unload 01–04 / mag_load 01–05 | — | dry 01–04 | rifle grab + shotgun pickups | safety 01–03 |
| Phantom (suppressed rifle) | semi-auto rifle, tail at half, 180-stud range | shot 01–08 | first / tail ×0.5 / last | cock 01–05 | 01–04 / 01–05 | — | dry 01–04 | as Vandal | safety 01–03 |
| Bulldog (rifle) | semi-auto rifle | shot 01–08 | first / tail / last | cock 01–05 | 01–04 / 01–05 | — | dry 01–04 | as Vandal | load_bullet 01–07 |
| Guardian (semi DMR) | semi-auto rifle (by name) | shot 01–08 | first / tail / last | cock 01–05 | 01–04 / 01–05 | — | dry 01–04 | as Vandal | load_bullet 01–07 |
| Marshal (lever) | rifle (bolt / lever) | shot 01–04 | — | cock 01–04 (after every shot) | — | load_bullet 01–08 | dry 01–04 | rifle grab | safety 01–02 |
| Outlaw (double rifle) | sniper (hinge: revolver cylinder) | shot 01–04 | — | sniper cock 01–04 | open 01–03 / close 01–04 | rifle load_bullet 01–08 (eject: sniper load_bullet 01–05) | dry 01–02 | rifle grab | rifle safety 01–02 |
| Operator (bolt sniper) | sniper | shot 01–04 | — | bolt cock 01–04 (after every shot) | rifle mag_unload 01–05 / mag_load 01–04 | sniper load_bullet 01–05 | dry 01–02 | rifle grab | scope_zoom_lens 01–07 |
| Ares (LMG) | heavy MG (auto set) | shot 01–08 | first / tail / last | rifle cock 01–05 | rifle mag_unload 01–04 / MG reload 01–02 | — | rifle dry 01–04 | soldier gear heavy 01–04 | gear rattle 01–03 |
| Odin (HMG) | heavy MG (auto set) | shot 01–08 | first / tail / last | rifle cock 01–05 | rifle mag_unload 01–04 / MG reload 01–02 (cover: gear rattle / rifle cock) | — | rifle dry 01–04 | soldier gear heavy 01–04 | gear grab 01–07 |
| Knife | bonus | air whooshes (cloth 02, 03, 10, 14; heavy 12, 04, 05) | — | — | — | — | — | metal_small_movement 01–05 | metal_small_movement 01–05, flips: pistol safety 01–02; stab: punch_grit_wet 01–05; walls / metal / wood / soft: the built impacts |

**Unavoidable sharing:**
- The four rifles share one set, the two SMGs another, and the two MGs another. Guardian and Marshal are split between the semi-auto rifle and the bolt rifle; Outlaw and Operator share the sniper shots.
- The pack has **no suppressed SMG or rifle**: the Spectre and Phantom get a half-level tail and a shorter 3D range, not a different shot.
- The pack has **no break action**: Shorty and Outlaw open and shut on the revolver's hinge sounds.

### 13.3 Research (game gun audio)
- **What Riot and Valve say:**
  - Riot recorded each gun's mechanical parts separately.
  - Third-person shots change with the direction of fire.
  - **Suppressed guns carry a shorter distance**, which v5 now does.
  - Reloads are a 2–3 beat pattern tied to the animation (ours are on clip markers).
  - CS:GO gives each gun its own distant, draw and reload sounds, and caps gunfire and impact voices.
  
  Sources: playvalorant.com "How the VALORANT arsenal was built"; Valve's operator stacks; CS:GO update notes.
- **Elsewhere:**
  - Your own gun in 2D stereo, other players' in 3D mono (Battlefield).
  - Apex: four or more distance layers per gun, with EQ that changes over distance.
  - CryEngine: auto fire as loops plus a tail after the last shot.
  - Tails must end before the next shot. A fade of about one shot interval (30–60 ms at 600+ RPM) is an **inference** from these, not a published number. v5 uses 0.8 × interval, 30–120 ms.
- **Not done (gaps):**
  - **Distance layers:** the pack has no distant mics.
  - **Mono 3D files:** the atlas is one stereo file.
  - **Direction-of-fire EQ.**
  
  Roblox's newer `AudioEmitter:SetDistanceAttenuation` could give custom distance curves later. That is an Audio-API migration: parked in Bugs & Ideas territory, not done.
- **New sounds:** none were added. The gaps (distant gunfire layers, ricochets, bullet whiz-bys, a break action) need the owner to buy or download licensed files: the LihFolk rule is that the AI never downloads sound files. Candidates:

| Source | What it has | Licence |
|---|---|---|
| BOOM Library "Assault Weapons" | close / medium / distant perspectives, impacts, tails | paid; video games allowed, no redistribution |
| Sonniss GDC bundles | varies by year | free; royalty-free in games, no credit, no resale, no AI training |
| Stormwave "Bullet Ricochet" and High Impact Media "Bullet Sound FX" (itch.io) | ricochets, whiz-bys, impacts | read each licence file before use |
| Roblox Creator Store, Roblox-licensed audio | — | free inside Roblox |

### 13.4 A/B against the pack's own previews
`audition/Guns/<Gun>.wav` is rendered by the same logic as the game (the builder runs the real `Config/GunSounds` through Lune). It plays: equip, inspect, taps, a 3-round burst, a spray to the last round, dry fire and a reload. `<Gun> pack preview.wav` is beside each automatic gun; cue times are in `cues.txt`.

Measured on the spray:

| | shots | level spread between shots | shot-to-gap depth |
|---|---|---|---|
| Vandal | 25 | 1.1 dB | 31.1 dB |
| Vandal's pack preview | 10 | 0.7 dB | 32.5 dB |
| Stinger | 20 | 0.9 dB | 29.9 dB |
| Stinger's pack preview | 11 | 0.4 dB | 26.5 dB |
| Ares | 32 | 2.0 dB | 21.5 dB |
| Ares's pack preview | 25 | 2.8 dB | 21.7 dB |

The shots separate as they do in the pack's own preview. Our spread is a little wider, from the ±1.5 dB jitter. The tail-after-release measure was unreliable (the previews end differently), so it is not used.

### 13.5 Studio test (match place, Rojo connected; all 8 changed scripts hash-match the disk)
Tested through the Studio remote `PickWeapon` and the `DevAction` / `DevHold` hooks. Slices logged as they played:
- **Classic:** draw `general_handling_10` + rack `cock_04`; shots `03`, `04`, `05`, `04`, `02` (random, no repeat); reload `remove_mag_02`, `insert_mag_01`, `cock_05`.
- **Sheriff:** shots `04`, `02`, `01`, `02`; reload `cylinder_open_02`, rounds out, `load_bullet_04`, `cylinder_close_01`.
- **Stinger:** `first_01` + `tail_only`, random shots `02`, `06`, `08`, …, **`last_with_tail` on the round that emptied the mag**, auto-reload `mag_unload_03`, `mag_load_04`, `cock_02`.
- **Vandal:** the same pattern (`first` + tail, shots `01`–`08`, `last_with_tail`, reload). A spray hit a range dummy and played `hit_body_A`.
- **Bucky:** shot then a **pump after each shot** (`cock_02`, `04`, `05`); shells `load_bullet_08`, `03`, `02`.
- **Guardian:** `first_01` + tail; `mag_unload_03` / `mag_load_03`.
- **Operator:** sniper `shot_02` / `04`, each followed by a different bolt (`cock_04`, `cock_03`); `rifle_magazine_unload_04` / `load_03`.
- **Ares:** `first_01` + tail, six different takes across the spray, reload `rifle mag_unload_02` + `MG reload_02`.

No errors in the console (the three `rbxassetid://203785492` "asset type" errors are not in `src`). The atlas is unchanged since v4 (byte-identical, asset 86848219110428), so **no new upload was needed**: v5 is the logic and the mapping.

**Checks:** `selene src` 0/0 (it caught a real bug first: a pitch-range variable shadowing the new range argument; fixed), `stylua --check src` and `rojo build` all clean.

### 13.6 Honest grade (without ears)
| Part | Grade |
|---|---|
| The system (first shot, no-repeat random takes, faded tails, last round, per shooter, 3D the same, suppressed range) | **9**: does what the pack's guide and the research describe; verified slice by slice |
| Use of the pack | **9**: every numbered take of every part in use; nothing old |
| Matching by type | **8**: right families everywhere, but the pack has 9 families for 17 guns. Same-family guns sound alike (four rifles, two SMGs, two MGs), and suppressed / break-action guns use stand-ins |
| How it sounds | **not graded**: I can't hear it. The numbers say it plays like the pack's own previews; whether that is "Valorant-good" is the owner's ear. |
| Gaps | distance layers, ricochets / whiz-bys and a break action need licensed files the owner buys (§13.3). |

**The next steps that would raise it:** distinct shots for same-family guns (a second licensed rifle / SMG pack) and distance layers for 3D shots.

## 14. Owner's listen on v5, and the fixes (2026-11-13, night)

**What he said:**
- The reloads are good.
- The shots "feel dull ... dampened ... too quiet".
- The knife pull-out and the knife sounds aren't good: use the pack's `whoosh_swish` files for all of them.
- Add a little whoosh to every equip.
- He doesn't like the headshot, body-hit and kill sounds, nor a "weird sound on the ragdoll" when a player dies. **He will say which sounds to use; left as they are until then.**

**Why the shots were dull (measured):**
- In their first 150 ms, the pack's shots had **34–79 % of their energy below 150 Hz and only 2–9 % at 2–6 kHz**. The reloads have 28–34 % there, which is why they sounded crisp. Laptop / phone / headset speakers drop most of what is under 150 Hz.
- In the game, shots sat **only 6–8 dB over the reloads**.
- The gun-group compressor (−14 dB, 3:1) and the master limiter (−4 dB) both pressed on the loud shots.

**Fixes:**
- **Shots and their tails, only EQ** (`tools/audio/build_pro_atlas.py` `SHOT_EQ`): a +4 dB shelf above 2.5 kHz (the crack) and −3 dB below 90 Hz, which frees headroom so they level up louder. No compression, saturation or pitch: what made v3 "off" stays out. The crack share (2–6 kHz):

| Gun family | before | after |
|---|---|---|
| Pistol | 9 % | 15 % |
| Rifle | 4.5 % | 9.5 % |
| SMG | 4.3 % | 8.2 % |
| MG | 3.9 % | 9.8 % |
| Sniper | 8.5 % | 17 % |
| Shotgun, revolver | 2 % | 4 % (the darkest recordings) |

- **Mix** (`Config/Audio` and `Config/GunSounds`):
  - **Groups:** Gun group 0.9 → 1; Foley group 0.75 → 0.65.
  - **Shot volumes:** `FIRE` / `TAIL` 0.85 → 1.
  - **Compressor and limiter:** gun glue −14 dB 3:1 → −8 dB 1.5:1; master limit −4 → −2 dB.

  Shots now land **about 9–13 dB over the reloads** (was 6–8).
- **Knife:**
  - Light slashes: `whoosh_swish_small_01–04`.
  - Heavy stab: `whoosh_swish_high_fast_01–04`.
  - Each is placed so its peak lands on the strike, padded where a file peaks too soon.
  - Pull-out: `whoosh_swish_small` + `high_fast`.
  - Inspect and its flips: `whoosh_swish_small`.

  The cloth swishes stay in the atlas as `knife_whoosh_cloth` / `_cloth_heavy`.
- **Every equip:** a small `whoosh_swish_small` (volume 0.35) under the draw (`Config/GunSounds` `drawWhoosh`, played in `WeaponController` with the draw).
- **Atlas v5** = **111750467221295** (private, group; 205.6 s, 12.1 MB, 339 slices). v4 was 86848219110428.

**Test (match place, Rojo synced, hashes match):**
- **Vandal:** a spray played from v5 (first shot, tail, random takes; voices at volume 2.0–2.8 with the make-up gain).
- **Knife:** equip played `whoosh_swish_small_04` + `high_fast_03`; slash `knife_whoosh`; heavy `knife_whoosh_heavy`; inspect `whoosh_swish_small_01`.
- **Errors:** none from audio.
- **Checks:** selene 0/0, stylua and rojo build clean.

**Still can't judge by ear:**
- whether the crack shelf is enough or too much: `SHOT_EQ` is one line, rebuild + upload;
- whether the `whoosh_swish` files (almost all below 150 Hz, a soft "whump") read on small speakers.

**Waiting on the owner:**
- the hit / headshot / kill / ragdoll sounds he wants;
- an MP4 of the knife animations he wants (the video-analyzer tool can read it).

## 15. Hit marker, headshot, ADS, footsteps, slide, jump, land (2026-11-13, night)

**The owner's asks:**
- His hit marker on every hit.
- A RIVALS / Valorant-style headshot: "high pitched metallic ... like a knife swing ... sped up".
- Sounds for everything: aiming down sights, new running footsteps, sliding, jumping.

**What changed:**
- **Hit marker:** `Config/Sounds` `HitBody` = **rbxassetid://125235091454234** ("hitmarker_2", a 66 ms click uploaded by NeoDoesStuff: the owner's pick, a community upload whose licence we haven't seen). `WeaponController` now plays it on **every** confirmed hit, kills included. A headshot adds `HitHead` on top, and the kill tone still comes from `KillFeed`.
- **Headshot:** `HitHead` = `gun:hit_head_shing_B`. It is a sword unsheathe's brightest 0.3 s (its metallic ring) sped up 1.5× (faster and higher together), high-passed at 1.5 kHz, over a pro-pack `whoosh_swish_high_fast` sped up 1.6× at −7 dB; 0.21 s, 3 takes. A and C use the other two unsheathe recordings: change the letter to try them. The pack-built `hit_head_A/B` and `hit_body_A/B` are still in the atlas.
- **ADS:**
  - **Most guns:** in and out of the sights plays a short pro-pack cloth flick (`aimIn`: cloth 13/14 at 0.3; `aimOut`: cloth 06/15 at 0.22).
  - **Marshal, Outlaw and Operator:** aiming in plays the pack's sniper scope lens (`scope_zoom_lens_01–07`).
  - **Wiring:** `Config/GunSounds` `aimIn` / `aimOut` (defaults `AIM_IN` / `AIM_OUT`), played by `WeaponController` when the aim state flips.
- **Footsteps:** new running steps in sneakers, cut into single footfalls from CC0 recordings (`build_pro_atlas.py` `movement_clips`: the most consistent 5–8 steps of each, from 4 ms before the step):

| Surface | Slice | Takes |
|---|---|---|
| Concrete | `step_concrete` | 8 |
| Metal | `step_metal` | 8 |
| Wood | `step_wood` | 6 |
| Grass | `step_grass` | 5 |
| Snow | `step_gravel` | 6 |

  `Config/Sounds` `STEPS` points at them; the old steps are still `atlas:Step*`.
- **Slide** (`Config/Juice SLIDE`): `gun:slide_skid`, a CC0 sneaker skid's first 0.7 s with the pack's cloth swell under it, 3 takes.
- **Jump** (`Config/Juice JUMP`): `gun:jump`, the pack's short cloth flicks. It was a provisional ProSoundEffects "Cloth Flap 2".
- **Landing** (`Config/Juice LAND`): `gun:land`, a CC0 stone landing with a heavy step and the pack's gear rattle.
- **Atlas v6** = **110896849099678** (private, group; 225.2 s, 13.5 MB, 350 slices). v5 was 111750467221295.

**CC0 sources** (fetched with `tools/audio/fetch_audio.py`, which reads each sound page's licence before saving; `source.json` is beside each file in `art-source/audio/downloads/`, git-ignored):

| id | title | author | page | licence | used for |
|---|---|---|---|---|---|
| 170505 | Footsteps, Tile, Male Sneakers, Fast Pace.wav | SpliceSound | [freesound.org](https://freesound.org/people/SpliceSound/sounds/170505/) | CC0 1.0 (read on the sound page) | steps concrete |
| 151227 | Running Shoes (2) | OwlStorm | [freesound.org](https://freesound.org/people/OwlStorm/sounds/151227/) | CC0 1.0 (read on the sound page) | steps concrete |
| 19310 | FX_030908 running on metal .aiff | martian | [freesound.org](https://freesound.org/people/martian/sounds/19310/) | CC0 1.0 (read on the sound page) | steps metal |
| 786977 | Metal Grate Running | Oilcan03 | [freesound.org](https://freesound.org/people/Oilcan03/sounds/786977/) | CC0 1.0 (read on the sound page) | steps metal |
| 389658 | Footsteps; running; wood; sneakers; consistently close.wav | TylerAM | [freesound.org](https://freesound.org/people/TylerAM/sounds/389658/) | CC0 1.0 (read on the sound page) | steps wood |
| 411148 | running in grass | EvanSki | [freesound.org](https://freesound.org/people/EvanSki/sounds/411148/) | CC0 1.0 (read on the sound page) | steps grass |
| 750797 | Gravel Footsteps 1 | simonjeffery13 | [freesound.org](https://freesound.org/people/simonjeffery13/sounds/750797/) | CC0 1.0 (read on the sound page) | steps gravel (snow) |
| 68247 | sneaker_skid.wav | shakaharu | [freesound.org](https://freesound.org/people/shakaharu/sounds/68247/) | CC0 1.0 (read on the sound page) | slide skid |
| 88502 | sneaker squeak rubber.wav | shakaharu | [freesound.org](https://freesound.org/people/shakaharu/sounds/88502/) | CC0 1.0 (read on the sound page) | (fetched, not used) |
| 235711 | Footsteps_sneakers on tile_running.wav | speedygonzo | [freesound.org](https://freesound.org/people/speedygonzo/sounds/235711/) | CC0 1.0 (read on the sound page) | (fetched, not used) |
| 422754 | Landing_Stone_2.wav | KieranKeegan | [freesound.org](https://freesound.org/people/KieranKeegan/sounds/422754/) | CC0 1.0 (read on the sound page) | landing |
| 581594 | Sword draw unsheathe | SamsterBirdies | [freesound.org](https://freesound.org/people/SamsterBirdies/sounds/581594/) | CC0 1.0 (read on the sound page) | headshot shing A |
| 320521 | Unsheathed blade | deleted_user_2906614 | [freesound.org](https://freesound.org/people/deleted_user_2906614/sounds/320521/) | CC0 1.0 (read on the sound page) | headshot shing B |
| 107589 | unsheath_sword.wav | Qat | [freesound.org](https://freesound.org/people/Qat/sounds/107589/) | CC0 1.0 (read on the sound page) | headshot shing C (fetched 2026-11-05) |

**Test (match place, Rojo synced, hashes match):**
- **ADS:** aim in `cloth_14`, out `cloth_15`.
- **Hits:** a spray into a range dummy gave two hits, each playing **the hit marker**.
- **Walking:** played `step_concrete`.
- **Jump:** played `jump`, then `land`.
- **Errors:** none from audio.
- **Not heard in play:** the headshot shing (the one head shot missed at 48 studs; its slice is checked and loads) and the slide (needs a crouch while sprinting).
- **Checks:** selene 0/0, stylua, rojo build clean; all 1,004 sound references resolve.

**Next (the owner):** videos of the knife and gun pull-out animations, plus how the crosshair and shooting look, for the next pass (video-analyzer tool).

## 16. Owner's listen on v6, and the fixes (2026-11-14)

**What he said:**
- The guns are better, but the automatic ones are "still a bit dull".
- The quality is good, but something about it is off ("the way it uploaded?").
- The revolver has a "weird hit" to it.
- The **hit marker fires way too late**.
- The headshot is **too metallic, too sharp**.
- The footsteps are **too realistic**: "this is a Roblox game", RIVALS-like, Roblox's footsteps are good.
- The kill sound needs to be "a nice little positive kind of thing" (RIVALS / Valorant).
- The knife is good.

**Fixes:**
- **Hit marker timing:**
  - **Cause one:** it played as a plain asset id, so every hit made a new Sound that had to load before playing.
  - **Cause two:** it only played on the server's confirm, a full round trip after the shot.
  - **Now:** plain asset ids play from a small **preloaded pool** (`AudioController.preload` at start-up: the hit marker, headshot and kill ids), and the marker (and the headshot sound) plays **the instant your own shot sees a hit** (`WeaponController`, LihFolk: predict the neutral contact).
  - **No doubles:** a server confirm within `Config/Audio HIT_PREDICT_WINDOW` (0.5 s) of that is the same hit and stays quiet. A hit the client didn't see (a wallbang) still sounds on the confirm. The kill tone still waits for the server.
- **Automatic guns (rifles, SMGs, MGs):** their shot takes get `AUTO_EQ`:
  - +6 dB above 2.5 kHz;
  - +3 dB at 3.5 kHz;
  - −4.5 dB under 90 Hz;
  - plus the first 18 ms of a pistol shot, high-passed, 10 dB under, on the front for snap.

  Their tails keep the milder `SHOT_EQ`. The crack band (2–6 kHz) roughly doubled again:

| Family | before | after |
|---|---|---|
| Rifle | 9.5 % | 19.8 % |
| SMG | 8.2 % | 17.4 % |
| MG | 9.8 % | 22.2 % |

- **Revolver:** its shots now start right at the blast. The hammer click that was pulled in in front of it (the likely "weird hit") is dropped.
- **Headshot:** `HitHead` = `gun:hit_head_soft_A`: a sped-up whoosh (×1.35) with the unsheathe ring only ×1.25, low-passed at 5.5 kHz, 9 dB under it, and a short punch. `hit_head_soft_B` is the other; `hit_head_shing_A/B/C` are the sharp ones.
- **Footsteps: Roblox's own.** The four footfalls inside the built-in `rbxasset://sounds/action_footsteps_plastic.mp3`, played as slices (`Config/Sounds BUILTIN` `rbxsteps`, each with a level `gain`) on every surface. The landing is the built-in `action_jump_land.mp3` (`rbxland`). They are built into every Roblox client: no upload, no licence question. The CC0 steps and landing stay in the atlas (`gun:step_*`, `gun:land`).
- **Kill:** `Kill` = `gun:kill_C`, a CC0 game pop ("The Best Bubble Pop Sound For Game and UI", el_boss, Freesound 669918, CC0) over a short pack punch. `kill_D` is the brighter "Task Complete Pop" (Qvantor, Freesound 878606, CC0). The `kill_head_*` versions add a faint ring. The pitch climbs per kill in a round (`KILL_LADDER`), as Valorant does.
- **"The way it uploaded":** our atlas is uploaded lossless (FLAC, 48 kHz). Roblox re-encodes every audio upload itself, and we can't change that.
- **Atlas v7** = **90648224762598** (private, group; 229.3 s, 13.7 MB, 356 slices).

**Not judged by ear:** whether the auto guns are bright enough now (`AUTO_EQ` is one line, then rebuild + upload), the headshot (A/B), and the kill pop (C/D). Each is one letter in `Config/Sounds`.

**Test of v7 (2026-11-14, match place, Rojo synced, hashes match):**
- **Hit marker timing:** on a range dummy at 14 studs, the hit marker started **in the same frame as the shot** (it waited a server round trip before).
- **Spray at the head:** first shot + tail, the marker on each hit, `hit_head_soft_A` on the head hits, and `kill_head_C` when the dummy died (the kill waits for the server, ~0.3 s after the first shot).
- **Misses:** `impact_hard` on the wall behind.
- **Movement:** walking plays Roblox's footfalls (`rbxsteps`); a jump plays our `jump`, then the landing (`rbxland`).
- **Found and fixed: the "weird sound on the ragdoll when the player dies".** It was Roblox's default character sound **"Died" (the classic "uuhhh")**, still live at 0.65. Roblox's default **Jumping and Landing** were also live and doubled ours: only "Running" had been muted.
  - **Fix:** `FootstepController` now silences Running, Jumping, Landing and Died on every player's character at spawn, near or far.
  - **Checked in play:** all four at volume 0, and no default sound plays during a jump.
- **Checks:** selene 0/0, stylua, rojo build clean.

## 17. Back to Roblox's own character sounds, a softer slide, the headshot crunch (2026-11-14)

**What the owner said:**
- The hit markers are better.
- The headshot is "still too high pitched and annoying ... not satisfying".
- The slide is "a squeech sound".
- "Revert it back to default Roblox sounds ... I just want the regular sounds."

**Changes:**
- **Character sounds:** `Config/Audio ROBLOX_CHARACTER_SOUNDS = true`. Roblox's own RbxCharacterSounds play the running loop, jump and landing for every character. Our steps (`FootstepController`) and our jump / land (`Config/Juice`, ids now `""`) stay quiet. Roblox's **"uuhhh" death sound stays muted**. Set the flag false to go back to our per-surface steps; note that Roblox's running loop doesn't get quieter while crouch-walking.
- **Slide:** `gun:knife_whoosh_cloth_heavy`, soft pure-air cloth swishes. The CC0 skid is still `gun:slide_skid`.
- **Headshot:** `HitHead = gun:hit_head_crunch`, with no metallic ring. It is a slap slowed to 0.85× and low-passed at 5 kHz, over a wet crunch and a body thud. `hit_head_crunch_B` is deeper (no slap). The earlier ones are still in the atlas.
- **Atlas v8** = **72558490061827**.

**Test (match place, Rojo synced, hashes match):**
- A jump played Roblox's `Jumping`, and moving played Roblox's `Running`. None of our steps played.
- My single headshot attempt missed, so the crunch itself was checked only as a slice.
- Lint, format and build are clean.

**Next:** the gun / knife feel from the owner's videos. Handoff: [Handoff - Gun and Knife Feel from Videos](../05%20Production/Handoff%20-%20Gun%20and%20Knife%20Feel%20from%20Videos.md).

## 18. Full-length gun audio (2026-11-14)

**Atlas v9 is 97238006800068.** One private upload under group 11116787. Rojo synced the asset ID and its generated regions into match place 133387545285290. The FLAC is stereo, 48 kHz, 255.936 s and 14.69 MB, with 358 cue names and 432 playable regions.

### Source and playback

The v8 builder shortened shots with per-family caps and a fade. It also subtracted the mean of the first 64 samples across the entire file. Several recordings were already in the attack there. The Classic take 01 decay plot shows the resulting offset holding the processed signal around −34 dBFS in the level-matched comparison before the cut. V9 keeps every source frame. It resamples to 48 kHz, applies a constant gain per family, and smooths only discontinuities at the edges (up to 0.5 ms in and 3 ms out). Removed the moved or dropped pre-click, attack trim, EQ shelves and added high-passed pistol transient. The fully decoded FLAC matched all 323 pack clips within 0.000019 full scale after accounting for level and edge fades.

| Family | Numbered shots | Take 01 v8 → v9 (s) | Technical check and listening grade |
|---|---:|---:|---|
| Classic pistol | 5 | 1.000 → 1.500 | Pass. The owner heard the whole shot and picked it as the reference. |
| Ghost suppressed pistol | 4 | 0.525 → 0.525 | Pass. Take 03 recovered 0.413 → 0.580 s. Listen pending. |
| Sheriff revolver | 4 | 1.000 → 2.245 | Pass. Restored the original attack and decay. Listen pending. |
| Shorty, Bucky, Judge shotgun | 4 | 1.586 → 2.662 | Pass. Repeated takes reach their real end. Listen pending. |
| Guardian, Marshal rifle | 4 | 1.600 → 2.192 | Pass. Guardian now uses these complete takes instead of the split auto set. Listen pending. |
| Outlaw, Operator sniper | 4 | 2.000 → 2.039 | Pass. Take 04 recovered 1.272 → 2.167 s. Listen pending. |
| Stinger, Spectre SMG | 9 | 0.047 → 0.047 | Pass. Separate tail 1.859 s. Listen pending. |
| Vandal, Phantom, Bulldog auto rifle | 8 | 0.089 → 0.089 | Pass for timing and take coverage. Tail 1.600 → 2.532 s and last-round take 1.800 → 2.532 s. Vandal's new tail mix awaits a listen. |
| Ares, Odin MG | 8 | 0.209 → 0.209 | Pass. Separate tail 2.015 s. Listen pending. |

Gunfire voices can outlive the ordinary cue budget and reuse a voice after it finishes. Long shots ring through the next shot. Only an automatic's separate tail fades when its next round fires. The draw, reload, cocking, dry-fire, ADS, knife and impact pools play through a shuffled bag so each mapped take gets a turn. The licensed contact cues retain their existing sources. The raw handling clips also keep their complete source frames. Capped playback makeup on handling and designed cues to avoid driving quiet transients and knife swishes into the limiter.

### Mix and Vandal

The mix trims match the guns' median loudest 100 ms to **−12.32 through −11.69 LUFS**. Classic is −11.95, Sheriff −12.32 and the shotguns −11.69. The 400 ms readings still show the shotgun body at −13.33 and the Sheriff at −15.83. Whisper-quiet details and suppressed tails keep their relative levels. Removed the gun compressor and enemy EQ, plus the sidechain that used to turn the gun down on contact. The existing master safety limiter remains.

- **Hit marker** measured from the Roblox-decoded cue at 0.28 volume is −19.5 LUFS over 100 ms.
- **Headshot** uses the three `hit_head_shing_C` takes at 0.80× and 0.31 volume. It's the existing CC0 sword unsheathe by Qat (Freesound 107589) over a short pack swish. These takes measure −17.7 to −17.6 LUFS over 100 ms. No new sources were added.
- **Kill** keeps the positive pop at 0.36 volume and the pitch ladder. Surface impacts keep the hard, metal/glass, wood and soft sets.
- **Vandal** uses the correct semi-auto rifle family. Matching the first 50 ms showed the preview plays `first`, `01–08` in order, then `last_with_tail`, with correlations of 0.986–1.000. Its reports are roughly 86–93 ms apart, versus Vandal's configured 103 ms and the frame scheduling in game. The Roblox-decoded first attack correlated 0.965 with the local mono fold-down at zero sample lag. The decoded attack retained its 2–6 kHz energy. At 100–200 ms, one Vandal last-round recording has about 21 dB less body than the Classic, whose recording carries its own longer report. Vandal now plays the split recordings at source pitch and raises its separate tail by 4.1 dB. The last-round recording carries its own tail.

### Checks and reels

SoundFile and SciPy decoded and compared all pack takes. Matplotlib plotted attack waveforms, 5 ms RMS decays and spectrograms. FFmpeg EBU R128 measured the atlas at −17.8 integrated LUFS and −1.1 dBTP. Roblox Studio's `AudioPlayer:GetWaveformAsync` supplied decoded attack excerpts and the standalone hit click. This session could do signal analysis and render audio for audition. It lacked audio input for a firsthand listening grade.

- Local audition at `art-source/audio/ProPack/audition/v9/` includes the complete per-gun reels, 60 level-matched cue-family comparisons, raw/v8/v9 metrics, the Vandal preview comparison and the old crunch versus the new metallic headshot. The older reels and v8 baseline remain in the ignored audition tree.
- In match place 133387545285290, all 17 guns and the knife passed equip, tap, cadence, reload where applicable, and native sound-end checks. The balanced-mix run logged 247 gun reports and four knife swings ending naturally. Full-mag automatic sequences were also exercised. The last pass measured the isolated Vandal tail and last-round region at 2.532 s, exhausted all eight repeat takes in one bag, checked 17 dry-fire slots and the feedback/surface cues, and ended all 70 positional Judge shots naturally with up to 67 concurrent. [Studio playtest](../05%20Production/Playtests/2026-11-14%20Full-Length%20Gun%20Audio.md)
- `selene src`, `stylua --check src`, and `rojo build -o build.rbxl` passed. Two pre-existing formatting-only failures in `WeaponService` and `SkinPreview` were formatted. The Git index stayed empty.

References for the pass are the pack's *How To Setup Automatic Guns Sounds in Games*, [Style Bible §5](Style%20Bible.md), [LihFolk Sound Fundamentals](../LihFolk/07%20Lighting%20VFX%20and%20Audio/Sound%20Fundamentals.md), and [Combat Sound Design and Feedback](../LihFolk/07%20Lighting%20VFX%20and%20Audio/Combat%20Sound%20Design%20and%20Feedback.md).

### Follow-up on the Vandal opener and clean headshots

The owner still heard less impact in game than in the pack's first shot and preview. The Vandal opener in the match client is `gun_semi_auto_rifle_shot_00_first_01` in asset `97238006800068`, from 123.842083 to 123.934666 s. Range input confirmed the opener and tail both play from this asset, at the original pitch. The raw source's loudest 100 ms measures −7.41 LUFS. The previous Vandal setting was −12.23 LUFS, so the same performances compared at their existing levels had about a 4.8 dB gap. Increased the Vandal report trim from 1.04 to 1.34 (+2.20 dB). The opener now measures −10.03 LUFS and −0.46 dBTP before random level variation and the in-game master effects.

Switched headshot contact to the three `hit_head_A` takes at 0.30 volume. They are short wood tocks with a quiet body layer, built from the licensed pack. The body click plays for body hits and the tock plays for headshots. Actual range input logged three headshots with one `hit_head_A` each and no accompanying body click. A separate body shot played the standalone marker, `125235091454234`. The new head cue alone measures −20.4 to −23.0 LUFS over 100 ms. The former stacked cue measured −15.5 LUFS on the audition take.

The Studio-only raw WAV comparison loaded, and the instrumented client showed the right regions and the expected gain at playback. The isolated Windows output recording was silent, so final speaker-output parity and the owner's verdict on the revised impact remain open. The match copy in Studio has these edits. This follow-up used the existing atlas and made no place publish. The reference pack preview and raw first-shot WAV remain local.

The ignored audition folder `art-source/audio/ProPack/audition/v9/Comparison/` has new Vandal and headshot A/Bs, `Vandal sound IDs.txt`, and `Gun and feedback sound IDs.tsv`. The TSV covers all mapped gun slots and the contact cues with their exact asset IDs and start/end seconds. The atlas ID opens the entire track, so audition with the listed region.

## 19. Standalone audio

Export one complete WAV for each active weapon and combat cue take. Verify the Vandal opener first, then record group-owned asset IDs and migrate playback to start from time zero. Keep numbered variation and auto tail fades. Use the running upload ledger to resume if Roblox throttles the batch.

### Results

The initial migration uploaded **368 individual audio files** under group 11116787. The upload queue contains 307 weapon, handling and combat feedback takes, 33 previously licensed optional surface footsteps and 28 shared ambience/UI takes. Each export is sample-exact to the prior mix, with source levels, pitch ranges and randomized take bags carried over. The standalone exports and their [local ID manifest](../../art-source/audio/ProPack/standalone/Sound%20IDs.tsv) are under the ignored `art-source/audio/ProPack/standalone/` directory. The uploader records accepted IDs and operation handles to support safe resumption.

`Config/GunSoundAssets` and `Config/SharedSoundAssets` replace the runtime region tables. Weapon and feedback playback start at zero. The automatic tail fades still apply when a following shot arrives. Ambient beds and emitters loop their complete assets. Roblox's built-in character audio runs in its normal engine path. The CC0 step takes are available if that path is disabled.

Match Studio **133387545285290** loaded all 368 files at their exported durations. The roster run covered all 17 guns and the knife, with 1,209 standalone starts and 250 primary shot or swing completions. Each observed Vandal part uses its own ID. The opener is **130905608133953** (92.583 ms). Roblox's decoded standalone opener correlated 0.993 with the WAV's mono fold, at zero sample lag. Dockyard's harbour and wind beds each looped their full 24-second assets. Selene, StyLua and Rojo build passed. Changes were synced to the match copy in Studio. The upload queue and source audio stayed out of Git.

References for ownership and preload behavior are [Roblox Audio assets](https://create.roblox.com/docs/audio/assets), [LihFolk Sound Fundamentals](../LihFolk/07%20Lighting%20VFX%20and%20Audio/Sound%20Fundamentals.md), and [Combat Sound Design and Feedback](../LihFolk/07%20Lighting%20VFX%20and%20Audio/Combat%20Sound%20Design%20and%20Feedback.md).


### Final volume and feedback check

The owner liked the standalone reports and wanted more audible hit feedback. Across the standalone repeat takes, 16 gun medians cover −12.32 to −11.69 LUFS over the loudest 100 ms. Vandal reads at −9.80 LUFS after its earlier impact adjustment. The levels checked out, with the shotgun reports averaging slightly above the Sheriff.

Raised the body marker from 0.28 to 0.42 and the short headshot tock from 0.30 to 0.45 (+3.52 dB each). The final body cue measures −15.94 LUFS and the head cues measure −16.85 to −19.52 LUFS in the 100 ms window. The export matcher had skipped capitalized cue suffixes in the first batch, so the three `hit_head_A` variants and the `kill_C` and `kill_head_C` cues had missing IDs. The corrected manifest covers all 315 referenced cue names and **373 uploaded takes**. Complete generation now checks the queue against live config references.

In match Studio, two body hits played the marker at 0.42. Three head hits played the three distinct tock takes, each as its own cue, and the lethal head hit played the restored kill pop. All 373 standalone assets loaded at their expected durations. Selene, StyLua and Rojo build passed.

## 20. Headshot and kill from the owner's clip (2026-11-15)
The owner picked **H5** (headshot) and **K5** (kill) from a batch built to measurements of the hit sounds in his own RIVALS clip: a deep thump (peak ~35 Hz) under a clean bell-like ding with partials near 3.1, 5.0 and 6.5 kHz, about 10% of the energy above 3 kHz. Made from the Sonniss GDC 2016 bundle (a struck wine glass tuned to those partials, a drum hit low-passed to the thump) and the pro pack's punch. Live as `gun:hit_head_E`, `gun:kill_E`, `gun:kill_head_E`. The regular hit tick is louder and plays ~50 ms after the shot. Full record, measurements and how to rebuild: [Gunplay Overhaul](../05%20Production/Playtests/2026-11-15%20Gunplay%20Overhaul.md) §9-11; tool `tools/audio/hit_candidates.py`.

## 21. Headshot and kill, batch 3 (2026-11-15, later)
The owner did not like H5 / K5 in the game. Batch 3 drops the sub thump (a dry knock with a louder ring, a filled middle) and is also rendered after a gunshot for judging in the mix: `art-source/audio/ProPack/audition/2026-11-15 headshot and kill, batch 3/`. Nothing wired. Record: [Gunplay Overhaul](../05%20Production/Playtests/2026-11-15%20Gunplay%20Overhaul.md) §12.

## 22. Headshot and kill, batch 4: soft shing, subtle kill (2026-11-15)
The owner wants a "nice shing" for the headshot (no high-pitched ding) and a subtle kill. Finding: most of our sword draws sit at 6-9 kHz as recorded, and the earlier shings sped them up. Batch 4 uses the two low ones (freesound 107589 unsheathe, 351372 light clang, both CC0) and slowed draws, low-passed at 4-5 kHz; kills are soft pops and low notes on a muffled thud. Record: [Gunplay Overhaul](../05%20Production/Playtests/2026-11-15%20Gunplay%20Overhaul.md) §13.

## 23. Kill sound picked: K13 (2026-11-15)
Live as `gun:kill_F`: the CC0 bubble pop (freesound 669918) slowed to 0.9x and low-passed at 3 kHz, on a muffled thud (freesound 275160). Headshot still open: metal and high tones are out, batch 5 tries crisp pops. Record: [Gunplay Overhaul](../05%20Production/Playtests/2026-11-15%20Gunplay%20Overhaul.md) §14.

## 24. Headshot picked: H18 (2026-11-15)
Live as `gun:hit_head_F`: the same CC0 bubble pop (freesound 669918) played 1.26x faster, with a 45 ms high-passed slap from the pro pack on its front and a quiet body thud; three takes 3% apart. With §23 the hit sounds are one family: pops. Record: [Gunplay Overhaul](../05%20Production/Playtests/2026-11-15%20Gunplay%20Overhaul.md) §15.
