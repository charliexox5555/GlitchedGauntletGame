# 2026-11-09 Hit and Shot Feel (and the designed-gun prototype)

**Ask (owner, 2026-11-09):**
- the [gun overhaul](2026-11-08%20Gun%20Sound%20Overhaul.md) sounds "dull, boring": they want Valorant / RIVALS, punchy, "makes you want to shoot";
- better hit sounds, a headshot that sounds different, a kill sound;
- more feel when you shoot and when you hit ("Valorant hit and fun", not "CS:GO smooth"), and the gun's recoil;
- later: jump, footstep, slide and ability sounds in the same punchy style.

Research and sources: [Gun Sound Packs (Valorant-style)](../../03%20Research/Gun%20Sound%20Packs%20(Valorant-style).md).

**Status:**
- Hit / headshot / kill and the shot feel are built and wired.
- The new hit sounds and the designed guns are **audition reels only**, waiting on the owner's ear.
- One gun-atlas upload later carries the hit sounds and the designed guns together.
- Nothing committed.

## 1. Hits, headshots, kills

**Sounds** (real CC0 Freesound recordings, cut tight, layered from real parts only; `tools/audio/build_gun_sfx.py` → `hit_clips`; fetched with `fetch_audio.py`, every page re-checked as CC0):

| Slice | Built from | Level (loudest 100 ms) |
|---|---|---|
| `HitBody` (3 takes) | a gloved hit (insanity54 276600), a fast collision (qubodup 332056), a chop on skin (mmasonghi 321810) | -13.5 |
| `HitHead` (3) | each thwack -6 dB under a metal "dink": pots-and-pans bullet ping (wilhellboy 351371), struck metal ping (JarredGibb 219024), light clang (wilhellboy 351372) | -11.5 |
| `KillTone` (2) | a thwack under a triangle struck with a wooden mallet (cabled_mess 349503), or a brass-pot ding (OwlStorm 23152) | -12.5 |
| `KillHeadTone` | thwack + bullet ping + triangle | -11 |

- Rejected: two punches clipped in the source (johnfolker 269232, Bird_man 275160); the gem ping (high_festiva 194439), which its author says was generated.
- **Reel:** `art-source/audio/HitSfxPreview.wav` (24 s; `HitSfxPreview.txt` has the timings): Classic and Vandal landing body hits and headshots, the kill ladder 1-5, head kills, kills in context.
- The slices sit **after** the uploaded 148.068 s of the gun atlas, so the live atlas still lines up. `Config/Sounds` keeps the old hit sounds until the next upload (then: `HitBody = "gun:HitBody"`, `HitHead = "gun:HitHead"`, `Kill = "gun:KillTone"`, `KillHead = "gun:KillHeadTone"`).

**Kill tone ladder (wired):**
- your own kill tone now plays from the server's `Killed` event (`Util/KillFeed`), so guns and Mods both count;
- it climbs `Config/Audio KILL_LADDER` (0, +2, +4, +5, +7 semitones) per kill in the round, never jittered, and resets on `MatchState` Round;
- the ELIMINATED pop-up lights one more pip per kill (5 pips) and lands bigger each time;
- `WeaponController.onHitConfirm` no longer plays the kill sound itself.

**Markers and flash (wired):**
- `Util/HitFeedback` STYLES: body 1.55x pop / 0.24 s, head 2.0x / 0.36 s, kill 2.2x / 0.55 s (were 1.35 / 1.55 / 1.7);
- `Config/Juice HIT_FLASH`: head 0.32 transparency / 0.2 s, kill 0.3 / 0.32 s.

## 2. Shot feel (wired)

**Found:**
- the viewmodel kick scaled with each gun's *camera* recoil.up, so the automatics (up 0.22-0.42) barely moved: Vandal ~0.007 studs and 0.3° from the spring;
- six automatics' Fire clips (Ares, Bulldog, Odin, Phantom, Spectre, Stinger) have no rotation at all.

**New:**
- **`Config/Viewmodel SHOT_PUNCH`**, per class, with `SHOT_PUNCH_GUN` overrides (Ghost, Akimbo, Shorty, Judge, Spectre, Phantom, Guardian, Marshal, Odin):
  - `back`: studs slammed back; `rise`: degrees of muzzle jump; random `yaw` and `roll`;
  - `climb`: degrees per shot that build up in a spray (up to `climbMax`) and settle once you stop;
  - hip fire only; aimed shots keep `ADS_KICK_*`, so the sights stay put.
- **Springs:** `PUNCH_STIFFNESS` 900 / `PUNCH_DAMPING` 33 (snappy, a little overshoot), sized so `back` / `rise` are the real peaks (`PUNCH_PEAK`); climb 70 critically damped, settling 0.12 s after the last shot at 7/s.
- **`Config/Juice SHOT_FEEL.upFloor` 0.65:** low-recoil automatics get at least that much FOV punch, roll and shake per shot. The camera recoil itself is unchanged.
- **Measured in Studio (single shot, hip):**

  | Gun | Peak travel | Peak rotation |
  |---|---|---|
  | Vandal | 0.23 studs at 36 ms | 5.3° |
  | Classic | | 7.6° |
  | Operator | | 13.7° |

  Each settles within 0.5 s. Output was clean.
- **Not checked:** the spray climb. The MCP mouse couldn't hold the trigger in the game window, so the owner needs to try a spray by hand.
- LihFolk agrees: camera kick plus a fast-recovering viewmodel kick on top, springs hit by an impulse, no hit-stop on rapid-fire guns (Gun Feel - Recoil, Spread, Bloom; Hit-Stop and Screen Shake Tuning by Numbers; Springs Damping and Smoothing).

## 3. Designed guns (prototype)

**The GDC 2016 bundle:**
- downloaded by the owner to `art-source/audio/library/GDC2016` (gitignored);
- **Windows skipped every file whose path ran past 260 characters**, so 30 libraries unpacked empty. That included most of the Pole Position guns, the London Warehouse firearms, the Barrett, the .44, the SPAS-12 and the GPMG.
- Re-extracted from the zips with short paths into `GDC2016/x/` (104 files; duplicates removed).
- The 6 zips (12 GB) can be deleted now.
- It's a **sampler**: 1-2 recordings per gun, each with 2-17 shots.

**What's usable** (Pole Position Production, multi-mic, many "on gun" DPA mics):
- rifles: HK416, G36C, G3, FAL, AKM, FAMAS, L85 / L86, Tavor;
- SMGs and pistols: MP5, MP7, P90, Uzi / Mini Uzi, TMP, M10, Scorpion, Thompson, M3; VP70, Glock 18, SIG P229, Beretta 93R, Five-seveN;
- revolvers: S&W M29 .44 and M66 .357;
- snipers: Barrett M98B .338 (on gun + 2 m), Sako TRG (and suppressed), Remington 700;
- shotguns: SPAS-12, Saiga-12, USAS-12;
- machine guns: MG4, Minimi, L7A2 GPMG, BAR, M1919;
- the De Lisle **suppressed** carbine;
- foley: G36C mag in / out, the .44's cylinder open / close, a Saiga cocking, a TMP cocking and dry fire;
- TS Sound 12 gauge (slug, pump, shell load), Fascinated Sound Gun Locker (M4, MP40, Tommy), Audiobeast warehouse shots, SoundMorph INTERVENTION / Future Weapons 2 (skins).

**How a shot is built** (`tools/audio/design_gun_sfx.py`): layered from real mics with different jobs:
- **crack:** the on-gun or 1 m mic;
- **body:** a 1 m mic of the same or a heavier gun;
- **boom:** a mic behind the shooter;
- **tail:** the 25-75 m mic, its flight delay removed.

Each layer is band-filtered and aligned on the onset, then glued (transient, 4:1 compression, light saturation, smile EQ) and levelled to the atlas targets at -1 dBTP.
- **Vandal:** HK416 on-gun + AKM 1 m (x0.97) + AKM 55 m.
- **Classic:** VP70 on-gun + SIG P229 1 m + SIG 50 m.
- **Operator:** Barrett on-gun + Barrett 2 m + FAL behind (x0.92, under 1.8 kHz) + Remington 50 m.
- **Reel:** `art-source/audio/DesignedPreview.wav` (24 s): each gun NOW (live) then NEW.

## 4. All 18 guns designed (owner: "yes, do all guns")
`design_gun_sfx.py DESIGNS` covers every gun. `build_gun_sfx.py` uses it for each gun's 3 shot variants, the auto tails and the far shot (each gun's **own far mic**; `USE_DESIGNS`, `--legacy` goes back). Atlas v2: 139 s, 4.5 MB. Each layer takes the k-th shot that has room for it (the next shot never bleeds in).

| Gun | Layers (crack · body · boom · tail) |
|---|---|
| Classic | VP70 on-gun · SIG P229 1 m · SIG 50 m |
| Ghost | De Lisle **suppressed** .45 1 m (x1.06) · VP70 action · De Lisle 55 m |
| Akimbo | Glock 18 1 m · Beretta 93R 1 m (x1.04) · Glock 75 m |
| Sheriff | S&W M29 .44 boundary mic · M29 1.5 m · M66 .357 50 m |
| Shorty | USAS-12 · SPAS-12 (x1.04) · SPAS 50 m |
| Stinger | Uzi · Mini Uzi (x1.03) · Uzi 75 m |
| Spectre | Steyr TMP darkened · De Lisle suppressed (x1.12) · MP7 on-gun action · TMP 30 m |
| Bucky | TS Sound 12 ga slug · SPAS-12 · SPAS 50 m |
| Judge | Saiga-12 · USAS-12 · Saiga 55 m |
| Vandal | HK416 on-gun · AKM 1 m · AKM 55 m |
| Phantom | Sako TRG **with suppressor** (x1.08) · HK416 action · G36C 50 m |
| Bulldog | FAMAS · Tavor (both bullpups) · FAMAS 55 m |
| Guardian | G3 7.62 · FAL boom from behind · G3 55 m |
| Marshal | Remington 700 · Marlin 336 lever (FFL) · Remington 50 m |
| Outlaw | BAR at the muzzle · FAL boom · Mosin (FFL) · FAL 25 m, all lower |
| Operator | Barrett M98B on-gun · Barrett 2 m · FAL boom · Remington 50 m |
| Ares | Minimi 1 m · L86 LSW on-gun action · Minimi 50 m |
| Odin | L7A2 GPMG · M1919 .30 cal (lower) · GPMG 50 m |

**Hits v2.** The owner didn't like v1 ("a ding, not punchy"). They want RIVALS' prominent slash for headshots, an impact for body shots, and a Valorant "whoa" kill. Rebuilt from GDC 2016 plus the CC0 takes:
- **Body:** an impact: Bottle Rocket drum hit, RUPTURE concrete crunch, gloved hit.
- **Head:** a whip-crack slash (SoundBits Just Whoosh 3, 3 pitches), a RUPTURE marble crack, the body impact under it. Louder than the body hit.
- **Kill:** the Bottle Rocket distorted boom, a RUPTURE bulb pop, the triangle ringing out (the ladder pitches it).
- **Head kill:** slash + kill.

**Keeping the game in step:** `--no-luau` builds the audio and reels without touching `Config/GunAtlas` / `GunSoundSets`. They stay matched to the uploaded v1 until the v2 upload.

**Reels:**
- `art-source/audio/GunSfxPreview.wav` (264 s, every gun's draw, inspect, shots, dry fire, reloads; timings in `.txt`);
- `art-source/audio/HitSfxPreview.wav` (24 s).

## 5. Shipped overnight (owner: "just go ahead, get this done")

**Upload:** gun atlas v2 uploaded as **asset 78823707282052** ("GG Gun Atlas v2", group 11116787), 138.07 s, 4.6 MB. It's set as `Config/Sounds GUN_ATLAS`; v1 was 124785078830341. `Config/Sounds` HitBody / HitHead / Kill / KillHead now point at `gun:HitBody` / `gun:HitHead` / `gun:KillTone` / `gun:KillHeadTone`.

**Volumes:** `Config/Audio` hit volumes went up so the headshot slash and the kill sit with your shots: body 0.75, head 0.95, kill 0.95.

**Variants:** before the upload, 5 guns' three variants were the same file and 3 more had a pair. They had only one clean shot per recording. `design_gun_sfx` now gives any variant whose crack layer repeats a small pitch change (x0.972 / x1.03) and a shifted body layer (-1.5 / +1.5 dB). Worst variant similarity is now 0.58 (it was 1.00).

**Spray climb:** a Vandal held for 1.4 s (new Studio-only `DevHold` attribute in WeaponController) climbed about 5° to 8° and settled to 0 within 0.6 s of letting go. That's a touch much, so the climb is trimmed:

| Class | Climb per shot | Cap |
|---|---|---|
| Rifle | 0.35° | 3° |
| SMG | 0.3° | 2.5° |
| MachineGun | 0.3° | 3.5° |

**Play-tested in Studio** (test range, solo, with sound):
- **Atlas:** loads in 0.5 s at 138.07 s.
- **All 18 guns:** a short hold each; every auto played its shots and then its tail, and the pump, bolt and lever cycled (Bucky pump, Operator bolt, Marshal lever).
- **Headshots:** a dummy moved in front of the camera (server side), 8 Classic shots: 3 `HitHead` slashes, then `KillHeadTone`, pip 1 lit.
- **Body shots:** a second dummy: 4 `HitBody`, then `KillTone` at **x1.122** (ladder step 2), pips 1-2 lit.
- **Sets:** 19 sets, 196 sounds, every id resolves.
- **Output:** no script errors (only the old place texture `203785492`).

**Movement (jump / land / footsteps / slide): not done.** The GDC 2016 sampler is too thin to beat what we have:
- the Levan Nadashvili footstep samplers give 2 clean takes per surface (LihFolk wants 4-6), against the current 4-6 CC0 takes;
- the Filmnoise sneaker walk is quiet and noisy (about -38 LUFS over a constant floor);
- the only usable bits are a leather / cloth fight whoosh (jump, slide accent), the drum-hit thump (landings) and the snow walking foley.

The next pass needs a footstep and movement library: check the other Sonniss bundle track lists (2017-2024) for footstep and cloth libraries, or the paid packs in the research note. The ability sounds (`Config/ModSounds`) are the same story: the sampler has whooshes, impacts, sci-fi transitions and ice, enough for accents but not a full designed set per Mod.

## Next (in order, the owner's list)
1. Owner listens to both reels; tune.
2. Design the other 15 guns the same way. Foley from the GDC foley where it fits (G36C mags, .44 cylinder, Saiga / TMP cocking, TS Sound pump and shells, Duffield shell drops); the rest stays as it is.
3. One gun-atlas upload (designed guns + hits), then switch `Config/Sounds`.
4. **Movement:** jump, land, footsteps (Levan Nadashvili Soldier / Civilian Footsteps, Filmnoise footsteps and movements), slide (SoundBits Just Whoosh 3, 3maze swoosh).
5. **Ability sounds** (`Config/ModSounds`): SoundBits Cinematic Hits & Transitions, 3maze High Impact, Bottle Rocket Impact Collection, Digital Rain Lab Sci-Fi Transitions, Kopeikin Sci-Fi Metal, Soundbankster Sci-Fi Book, ice (3maze ICE BLOCK, Kevin Durr, Stuart Duffield Ice SFX) for Frost.
6. **Later, if the game earns:** the Gamemaster Audio Gun Sound Pack ($19.99), which the owner thinks RIVALS uses.

## What to test (owner)
1. `art-source/audio/HitSfxPreview.wav`: body vs head vs kill, the ladder.
2. `art-source/audio/DesignedPreview.wav`: NOW vs NEW for Vandal, Classic, Operator.
3. In Studio (already live): hip-fire taps and a long spray with the Vandal / Stinger / Ares (the kick, the climb and how it settles), then the Operator and Sheriff; get 3 kills in a round and watch the pop-up pips (the tone ladder uses the old bell until the upload).
