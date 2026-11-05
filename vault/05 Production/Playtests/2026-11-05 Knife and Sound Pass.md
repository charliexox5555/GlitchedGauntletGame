# 2026-11-05 Knife and Sound Pass (lane F, `knife-sounds`)

Lane F from the [Day Plan 2026-11-05](../Day%20Plan%202026-11-05.md); rules in [Overnight 2026-11-04](../Overnight%202026-11-04.md) → "Rules for every lane". Follows lane D's [Animation and Knife Pass](2026-11-04%20Animation%20and%20Knife%20Pass.md), where the knife scored **7.0** (P2 timing, P3 anticipation and P5 arcs had no evidence; the slashes were the old Blender wrist clips).

Goals: the knife scores **8.5+** on the LihFolk animation rubric (blind reviewers), in first and third person; the knife gets real recorded sounds (uploaded, wired, with alternates listed); then a sound pass on the rest of the game.

## Phase 1: findings and plan

### How the knife works today (read 2026-11-05)
- **First person:** `ViewmodelController.swing(attack)` plays the knife's Blender clip (`WeaponAnimations/Knife.luau`, a **Root rotation only**: the wrist turns, nothing travels) under a camera track of the same name in `Config/Viewmodel` TRACKS, used **position only** (`rotScale 0`). Slash1-3 differ only in the track's 3 keys (rest → wind → cut → rest, Quad out); no overshoot, settle or held contact frame. Light slash 0.54 s, hit marker 0.17 s; heavy 0.96 s, hit 0.42 s.
- **Hit feedback:** a predicted body hit plays the shared `impact` puff + hit marker; a wall gets the gouge (`slashMark`, already under the crosshair). No hit-stop, no camera punch, no slash streak.
- **Third person:** one `GG_KnifeSlash` clip (wind → cut → follow) for every light slash and one `GG_KnifeHeavy` (raise → strike), both 5 keys, linear easing. Others never see the inspect.
- **Sounds:** placeholders (one ProSoundEffects swoosh re-pitched for light and heavy, the atlas `Impact` pitched up/down for wall and body). No draw or inspect sound.
- **Audio budget:** every game sound is a slice of one atlas asset (`Config/SoundAtlas`, built by `tools/audio/build_sound_atlas.py`). Only 2 audio uploads so far (both October); the plan is **one** new atlas upload (v3) with every new slice appended after the existing ones, so the gun slices keep their exact times.

### References
- **Valorant / RIVALS knives** (lane D's research): light swing ~50 ms of strike, heavy ~150 ms; forward grip in the right hand; each light swing in a chain takes a different line; the heavy is a two-handed thrust with a clear pull-back. Valorant shows a faint swipe streak on every swing; a hit gives a short, crisp flesh impact and a hit marker; a wall gives a metal-on-surface scrape.
- **LihFolk** (cited as used; filled in below as the lookups come back): `lihfolk-sfx` skill (−18 LUFS momentary max, −1 dBTP, onset within ~10 ms of the file start, melee tails ≤ 0.6 s, ≥ 3 takes for frequent sounds, 4-6 for footsteps, mono for 3D, pitch ±3-6 %, combo steps may climb a semitone, kill confirms not randomised, impact sound at the start of a hit-stop); `lihfolk-vfx` skill (slashes frontal only, three tones white / body / dark, flash 1-2 frames one frame after contact, small; no clutter).
- **Licensing note:** `lihfolk-sfx` says to prefer Roblox-licensed audio and that the AI never downloads sound files. The user decided otherwise for this game on 2026-11-05 (real **CC0** recordings picked, polished and uploaded by the agent, with alternates listed); project decisions win over LihFolk's general advice (CLAUDE.md). CC0 has no redistribution ban; raw downloads still stay out of git.

### Plan
1. **First-person knife re-key** (`Config/Viewmodel` TRACKS, full rotation; the wrist clips stop driving slashes):
   - Each attack: anticipation (2-3 frames at 30 fps) → strike (fast, ease-out, the blade crosses the crosshair at contact) → follow-through with overshoot → settle (Back ease). Contact frame = the `hit` fraction in the track (replaces the clip marker).
   - Slash1 forehand: high right → low left, curved through the centre. Slash2 backhand: high left → low right. Slash3 finisher: overhead chop, bigger wind-up. HeavyStab: pull back low right with both hands, hold the tension, thrust, hold, recover. Inspect: raise, flip to show both faces of the blade, a little toss, catch.
   - **Hit-stop:** on a predicted hit, the swing freezes ~60 ms (light) / ~90 ms (heavy), then continues; **camera punch** along the swing (pitch/yaw kick + roll), bigger on hit, tiny on a whiff.
   - **Slash streak:** a thin curved swipe (Beam with curve) along the blade's path in first person on every swing; on contact a small white flash and sparks / dust for the surface; the mark stays.
2. **Third-person clips** (pose text → `pose_text_to_rbxm.py` → group upload): `KnifeSlash1/2/3` with the same three lines as first person, `KnifeHeavy` with a pull-back, eased keys (Cubic/Back) and overshoot. The server sets a `SwingStep` attribute (its own combo count) so others see the right one.
3. **Knife sounds** (CC0 recordings, own folder per download under `art-source/audio/downloads/`, ledger with URL + licence): draw, light whoosh ×3, heavy whoosh ×3, flesh hit ×3, wall hits by surface (concrete / metal / wood, ×2-3 each), inspect. Polished in `tools/audio/` (trim, fades, high-pass, −18 LUFS momentary, −1 dBTP), picked by measurement (loudness, attack time, spectral centroid) and judgement, appended to the atlas, wired in `GunSounds.Knife`.
4. **Sound pass** in order: hit / kill confirms, footsteps by surface, slide, reload and equip cleanliness, UI clicks. Same rules.
5. **Score** with 3 blind reviewers on the LihFolk animation rubric from Studio contact sheets (frozen frames with `VfxTimeScale`), fix rounds, stop after two rounds that each gain < 0.3.

Map ambience is the map-redesign lane's; offered below, not built.

## Phase 2: knife sounds (sourced, polished, measured)

### How they were picked
- **Search:** `tools/audio/freesound_search.py` lists Freesound results with the licence filter set to CC0, most downloaded first (15-70 candidates per sound). `tools/audio/fetch_audio.py` re-reads each sound page and refuses anything not marked CC0, then saves the HQ preview (OGG ~192 kbps; the original WAV needs a signed-in download) into **its own folder** `art-source/audio/downloads/freesound-<id>/` with a `source.json` (URL, author, licence, description, date). Nothing downloaded is run; the folder is gitignored.
- **Real recordings only:** each page's description was read. Rejected: `591155` (made in FL Studio by layering), `421929` (knuckles on a cardboard box), anything labelled synthesized. `504615` (a mix of CC0 recordings) is kept only as an alternate.
- **Measured** with `tools/audio/analyze_audio.py`: every event's length, peak, attack time, spectral centroid and momentary loudness (BS.1770), noise floor and clipping, plus a spectrogram per file. Picks: the cleanest takes with the right shape (whooshes that swell and fall in 0.3-0.5 s, hits with an attack under 10 ms), takes from the same recording session for round-robin variants, light swings brighter (centroid 1.5-2.6 kHz) than heavy ones (1.0-1.8 kHz).
- **Polished** with `tools/audio/build_sfx.py`: mono, high-pass 90-250 Hz, the head trimmed so a hit peaks within 12 ms of the start and every whoosh peaks at the same point (60 ms light, 90 ms heavy, so the game can time it to the blade), the tail cut 60 dB under the peak with a fade, normalised to **−18 LUFS momentary max** (draw −21, inspect −22; our gunshots sit at −15 to −21) with a **−1 dBTP** limiter. No layering, no synthesis.
- **One upload:** the takes are **appended** to the existing gun atlas (`GameAtlas.flac`); the gun slices stay byte-identical (checked), so `Config/SoundAtlas` keeps their times. Pitch variation happens at runtime (`GunSounds` ranges + the Foley jitter); light slashes in a 1-2-3 chain climb a semitone each (LihFolk *Combat Sound Design and Feedback*).

### Knife sounds (atlas name → takes; 2 alternates each to swap)
| Sound | Used (Freesound id, author: what it is) | Alternates |
|---|---|---|
| `KnifeDraw` | 30248 Streety: a knife pulled along a cheese slicer; 417035 FunWithSound: a sword drawn from a leather sheath | 471148 AuDRoger "Sword slide 2"; 107589 Qat "unsheath_sword" |
| `KnifeSwing` (light) | 60007, 60013, 60006 qubodup: bamboo-stick swishes; 72190 snowflakes: a whip swish | 535359 EminYILDIRIM "Combat Whooshes" (20 short takes); 59988 qubodup "SWOSH-01" |
| `KnifeSwingHeavy` | 352719 Dalesome: a long stick swung hard; 19312 martian: double swoosh; 127197 dave.des: a low chop whoosh | 535359 (its lower takes); 169867 Halgrimm "swoosh" |
| `KnifeHitBody` | 395365, 395373 ihitokage: stabbing a cabbage; 179222 Mixedupmoviestuff: stabbing a cabbage | 752346 justjenah "Meaty Stab" (lemon, watermelon, tomato, chicken thighs); 574821 Wenpire "Slash1" |
| `KnifeHitWood` | 531877 shtran: a knife hitting wood (3 takes) | 504618 NeoSpica "Knife thrust into wall"; 196562 kylepyke "Knife throw 1" (into wood) |
| `KnifeHitStone` (concrete, brick, any hard surface) | 321477 dslrguide: a metal axe on a concrete slab; 431019 CamoMano: a hatchet on a rock; 145122 qubodup: a metal plate on a stone oven | 145122 (its other hits); 360946 marcusgar "Sharpening knife" (a scrape) |
| `KnifeHitMetal` | 471095 spycrah: two kitchen knives clashing; 336593 Anthousai: a knife on a sharpening steel; 547041 CogFireStudios: a light blade hit (origin not stated) | 360946 marcusgar "Sharpening knife"; 410364 BenjaminNelan "Metal Hit" |
| `KnifeInspect` (start) | 360946 marcusgar: a blade drawn across a stone | 150365 starakaj "Knife Sharpening"; 241805 Mikaaku_Hoshine "Blade sharpen" |
| `KnifeFlip` (each flip caught) | 431533 supersound23: a real metal balisong clicking (3 clicks) | 107590 Qat "sheath_sword"; other clicks of 431533 |
Soft surfaces (grass, dirt, snow, fabric) reuse `KnifeHitBody` lower and quieter.

**To swap a sound:** edit its line in `TAKES` in `tools/audio/build_sfx.py` (the id and the start time from `analyze_audio.py`), run `python -I tools/audio/fetch_audio.py <cands.json> role:<id>` if it isn't downloaded yet, rebuild with `python -I tools/audio/build_sfx.py --preview`, listen to `art-source/audio/SfxPreview.wav`, then upload `GameAtlas.flac` and paste its id into `Config/Sounds.luau` `ATLAS`.

### Licence ledger (every file downloaded today; all CC0 1.0 as read on the sound page)
| Id | Title | Author | Source | Licence | Role |
|---|---|---|---|---|---|
| 19312 | classic double swwosh .wav | martian | [freesound.org](https://freesound.org/people/martian/sounds/19312/) | CC0 1.0 | swing |
| 30248 | sword7.flac | Streety | [freesound.org](https://freesound.org/people/Streety/sounds/30248/) | CC0 1.0 | knife_draw |
| 59988 | SWOSH-01 44.1kHz | qubodup | [freesound.org](https://freesound.org/people/qubodup/sounds/59988/) | CC0 1.0 | swing2 |
| 60006 | Swoosh Metal Rod Swing Sound made with Bamboo Stick | qubodup | [freesound.org](https://freesound.org/people/qubodup/sounds/60006/) | CC0 1.0 | swing2 |
| 60007 | Swipe Whoosh | qubodup | [freesound.org](https://freesound.org/people/qubodup/sounds/60007/) | CC0 1.0 | swing |
| 60013 | Whoosh | qubodup | [freesound.org](https://freesound.org/people/qubodup/sounds/60013/) | CC0 1.0 | swing |
| 72190 | whip02.wav | snowflakes | [freesound.org](https://freesound.org/people/snowflakes/sounds/72190/) | CC0 1.0 | swing2 |
| 99625 | bell003mono.wav | tec_studio | [freesound.org](https://freesound.org/people/tec_studio/sounds/99625/) | CC0 1.0 | head |
| 107589 | unsheath_sword.wav | Qat | [freesound.org](https://freesound.org/people/Qat/sounds/107589/) | CC0 1.0 | knife_draw |
| 107590 | sheath_sword.wav | Qat | [freesound.org](https://freesound.org/people/Qat/sounds/107590/) | CC0 1.0 | inspect |
| 108336 | click_01-fast.wav | Qat | [freesound.org](https://freesound.org/people/Qat/sounds/108336/) | CC0 1.0 | hit |
| 119839 | Glass_Clink.aif | kbnevel | [freesound.org](https://freesound.org/people/kbnevel/sounds/119839/) | CC0 1.0 | hit |
| 127197 | fast simple chop 5.aif | dave.des | [freesound.org](https://freesound.org/people/dave.des/sounds/127197/) | CC0 1.0 | swing |
| 127955 | Running on grass with wet feet.aif | nathanaelsams | [freesound.org](https://freesound.org/people/nathanaelsams/sounds/127955/) | CC0 1.0 | steps |
| 145122 | thin metal plate against wood, stone and metal.flac | qubodup | [freesound.org](https://freesound.org/people/qubodup/sounds/145122/) | CC0 1.0 | hit_concrete |
| 146718 | button | Leszek_Szary | [freesound.org](https://freesound.org/people/Leszek_Szary/sounds/146718/) | CC0 1.0 | hit |
| 150365 | Knife Sharpening | starakaj | [freesound.org](https://freesound.org/people/starakaj/sounds/150365/) | CC0 1.0 | inspect |
| 164643 | Pen_click_3.wav | deleted_user_2104797 | [freesound.org](https://freesound.org/people/deleted_user_2104797/sounds/164643/) | CC0 1.0 | hit |
| 169867 | swoosh | Halgrimm | [freesound.org](https://freesound.org/people/Halgrimm/sounds/169867/) | CC0 1.0 | swing |
| 173932 | Ding Ding Small Bell | JohnsonBrandEditing | [freesound.org](https://freesound.org/people/JohnsonBrandEditing/sounds/173932/) | CC0 1.0 | kill |
| 176550 | VERY LOUD Stab.wav | deleted_user_3277771 | [freesound.org](https://freesound.org/people/deleted_user_3277771/sounds/176550/) | CC0 1.0 | hit_flesh |
| 179222 | Knife Stab.wav | Mixedupmoviestuff | [freesound.org](https://freesound.org/people/Mixedupmoviestuff/sounds/179222/) | CC0 1.0 | hit_flesh |
| 187343 | Rubber Shoe Squeak.wav | baidonovan | [freesound.org](https://freesound.org/people/baidonovan/sounds/187343/) | CC0 1.0 | slide |
| 196562 | Knife throw 1.aif | kylepyke | [freesound.org](https://freesound.org/people/kylepyke/sounds/196562/) | CC0 1.0 | hit_wood |
| 196563 | Knife throw 2.aif | kylepyke | [freesound.org](https://freesound.org/people/kylepyke/sounds/196563/) | CC0 1.0 | hit_wood |
| 205938 | Arrow Impact | Twisted_Euphoria | [freesound.org](https://freesound.org/people/Twisted_Euphoria/sounds/205938/) | CC0 1.0 | wood2 |
| 206030 | footsteps grass.wav | Yuval | [freesound.org](https://freesound.org/people/Yuval/sounds/206030/) | CC0 1.0 | steps |
| 208101 | Metal Steps | Phil25 | [freesound.org](https://freesound.org/people/Phil25/sounds/208101/) | CC0 1.0 | steps |
| 208103 | Stone Steps | Phil25 | [freesound.org](https://freesound.org/people/Phil25/sounds/208103/) | CC0 1.0 | steps |
| 208104 | Wood Steps | Phil25 | [freesound.org](https://freesound.org/people/Phil25/sounds/208104/) | CC0 1.0 | steps |
| 221515 | service bell ring | AlaskaRobotics | [freesound.org](https://freesound.org/people/AlaskaRobotics/sounds/221515/) | CC0 1.0 | kill |
| 223965 | d0 Meatslap on Glass 3 | dav0r | [freesound.org](https://freesound.org/people/dav0r/sounds/223965/) | CC0 1.0 | flesh2 |
| 235563 | pen clicking.wav | SkeetMasterFunk69 | [freesound.org](https://freesound.org/people/SkeetMasterFunk69/sounds/235563/) | CC0 1.0 | hit |
| 240640 | Metallic Whoosh.wav | MissCellany | [freesound.org](https://freesound.org/people/MissCellany/sounds/240640/) | CC0 1.0 | swing2 |
| 241805 | Blade sharpen | Mikaaku_Hoshine | [freesound.org](https://freesound.org/people/Mikaaku_Hoshine/sounds/241805/) | CC0 1.0 | inspect |
| 255156 | Bell ding | jmayoff | [freesound.org](https://freesound.org/people/jmayoff/sounds/255156/) | CC0 1.0 | kill |
| 256116 | Click.wav | kwahmah_02 | [freesound.org](https://freesound.org/people/kwahmah_02/sounds/256116/) | CC0 1.0 | hit |
| 264777 | Swoosh | Shinplaster | [freesound.org](https://freesound.org/people/Shinplaster/sounds/264777/) | CC0 1.0 | swing |
| 268227 | Swing.mp3 | XxChr0nosxX | [freesound.org](https://freesound.org/people/XxChr0nosxX/sounds/268227/) | CC0 1.0 | swing2 |
| 321477 | Concrete Hit | dslrguide | [freesound.org](https://freesound.org/people/dslrguide/sounds/321477/) | CC0 1.0 | hit_concrete |
| 332003 | whoosh.wav | LloydEvans09 | [freesound.org](https://freesound.org/people/LloydEvans09/sounds/332003/) | CC0 1.0 | swing2 |
| 336593 | knife sharpen 02.wav | Anthousai | [freesound.org](https://freesound.org/people/Anthousai/sounds/336593/) | CC0 1.0 | hit_metal |
| 346328 | Bright Tibetan Bell Ding B Note - cleaner | steaq | [freesound.org](https://freesound.org/people/steaq/sounds/346328/) | CC0 1.0 | kill |
| 346373 | Throwing / Whip Effect | denao270 | [freesound.org](https://freesound.org/people/denao270/sounds/346373/) | CC0 1.0 | swing2 |
| 352719 | Woosh (stick swung in the air) | Dalesome | [freesound.org](https://freesound.org/people/Dalesome/sounds/352719/) | CC0 1.0 | swing2 |
| 353799 | Footsteps_6_Dirt_shoe.wav | monte32 | [freesound.org](https://freesound.org/people/monte32/sounds/353799/) | CC0 1.0 | steps |
| 360946 | Sharpening knife | marcusgar | [freesound.org](https://freesound.org/people/marcusgar/sounds/360946/) | CC0 1.0 | hit_metal |
| 389590 | Swing Woosh | Jofae | [freesound.org](https://freesound.org/people/Jofae/sounds/389590/) | CC0 1.0 | swing2 |
| 389625 | Footsteps_Grass_1.wav | SilentStrikeZ | [freesound.org](https://freesound.org/people/SilentStrikeZ/sounds/389625/) | CC0 1.0 | steps |
| 395365 | Sword stab 4 | ihitokage | [freesound.org](https://freesound.org/people/ihitokage/sounds/395365/) | CC0 1.0 | flesh2 |
| 395373 | Sword stab 2 | ihitokage | [freesound.org](https://freesound.org/people/ihitokage/sounds/395373/) | CC0 1.0 | flesh2 |
| 399183 | Major punch | janbezouska | [freesound.org](https://freesound.org/people/janbezouska/sounds/399183/) | CC0 1.0 | flesh2 |
| 405665 | metal bowl - hit - with wooden spoon 01.wav | Anthousai | [freesound.org](https://freesound.org/people/Anthousai/sounds/405665/) | CC0 1.0 | kill |
| 410364 | Metal Hit | BenjaminNelan | [freesound.org](https://freesound.org/people/BenjaminNelan/sounds/410364/) | CC0 1.0 | hit |
| 417035 | Quick Sword Draw.mp3 | FunWithSound | [freesound.org](https://freesound.org/people/FunWithSound/sounds/417035/) | CC0 1.0 | knife_draw |
| 420392 | Sliding on a frozen asphalt road.wav | Magdaadga | [freesound.org](https://freesound.org/people/Magdaadga/sounds/420392/) | CC0 1.0 | slide |
| 421929 | Chopping wood 02 | micahlg | [freesound.org](https://freesound.org/people/micahlg/sounds/421929/) | CC0 1.0 | hit_wood |
| 423935 | Draw sword#1.wav | fielastro | [freesound.org](https://freesound.org/people/fielastro/sounds/423935/) | CC0 1.0 | knife_draw |
| 431019 | Stone hit | CamoMano | [freesound.org](https://freesound.org/people/CamoMano/sounds/431019/) | CC0 1.0 | hit_concrete |
| 431533 | Ballisong Click | supersound23 | [freesound.org](https://freesound.org/people/supersound23/sounds/431533/) | CC0 1.0 | inspect |
| 471095 | Sword clash 1.wav | spycrah | [freesound.org](https://freesound.org/people/spycrah/sounds/471095/) | CC0 1.0 | hit_metal |
| 471147 | Sword slide.wav | AuDRoger | [freesound.org](https://freesound.org/people/AuDRoger/sounds/471147/) | CC0 1.0 | knife_draw |
| 471148 | Sword slide 2.wav | AuDRoger | [freesound.org](https://freesound.org/people/AuDRoger/sounds/471148/) | CC0 1.0 | knife_draw |
| 472503 | 29_Deslizando_cuchillo_en_madera.wav | JoseAgudelo | [freesound.org](https://freesound.org/people/JoseAgudelo/sounds/472503/) | CC0 1.0 | wood2 |
| 478197 | Click_1.wav | JonnyRuss01 | [freesound.org](https://freesound.org/people/JonnyRuss01/sounds/478197/) | CC0 1.0 | hit |
| 504383 | Boots Gravel Feet Slide  1_5 | Joao_Janz | [freesound.org](https://freesound.org/people/Joao_Janz/sounds/504383/) | CC0 1.0 | slide |
| 504615 | Slicing through flesh | NeoSpica | [freesound.org](https://freesound.org/people/NeoSpica/sounds/504615/) | CC0 1.0 | hit_flesh |
| 504618 | Knife thrust into wall | NeoSpica | [freesound.org](https://freesound.org/people/NeoSpica/sounds/504618/) | CC0 1.0 | hit_wood |
| 515643 | ding2.wav | MashedTatoes2 | [freesound.org](https://freesound.org/people/MashedTatoes2/sounds/515643/) | CC0 1.0 | head |
| 521030 | STABBING STAB KNIFE.mp3 | Podcapocalipsis | [freesound.org](https://freesound.org/people/Podcapocalipsis/sounds/521030/) | CC0 1.0 | hit_flesh |
| 521587 | Hiking Boot Footsteps on Grass | Fission9 | [freesound.org](https://freesound.org/people/Fission9/sounds/521587/) | CC0 1.0 | steps |
| 531877 | Knife throw wood hits | shtran | [freesound.org](https://freesound.org/people/shtran/sounds/531877/) | CC0 1.0 | wood2 |
| 534956 | ARROW_WOOD_IMPACT_SINGLE_ARCHERY_01.wav | JoeDinesSound | [freesound.org](https://freesound.org/people/JoeDinesSound/sounds/534956/) | CC0 1.0 | wood2 |
| 535359 | Combat Whooshes | EminYILDIRIM | [freesound.org](https://freesound.org/people/EminYILDIRIM/sounds/535359/) | CC0 1.0 | swing2 |
| 536736 | Chop.ogg | egomassive | [freesound.org](https://freesound.org/people/egomassive/sounds/536736/) | CC0 1.0 | hit_wood |
| 547041 | Hit Swing Sword Small 3 | CogFireStudios | [freesound.org](https://freesound.org/people/CogFireStudios/sounds/547041/) | CC0 1.0 | hit_metal |
| 574821 | Slash1.ogg | Wenpire | [freesound.org](https://freesound.org/people/Wenpire/sounds/574821/) | CC0 1.0 | hit_flesh |
| 585257 | swoosh-1.mp3 | lesaucisson | [freesound.org](https://freesound.org/people/lesaucisson/sounds/585257/) | CC0 1.0 | swing |
| 591155 | Sword Contact (with swipe) | ultraaxvii | [freesound.org](https://freesound.org/people/ultraaxvii/sounds/591155/) | CC0 1.0 | hit_metal |
| 613849 | Footsteps_Mountain_Boots_Snow_Walk_Mono.wav | Nox_Sound | [freesound.org](https://freesound.org/people/Nox_Sound/sounds/613849/) | CC0 1.0 | steps |
| 641386 | Foot Skid on Wood 01.m4a | WhiteFire43 | [freesound.org](https://freesound.org/people/WhiteFire43/sounds/641386/) | CC0 1.0 | slide |
| 683101 | quick woosh | florianreichelt | [freesound.org](https://freesound.org/people/florianreichelt/sounds/683101/) | CC0 1.0 | swing |
| 707915 | Women walking on grass outside with sneakers | AnikadeBeer_231312 | [freesound.org](https://freesound.org/people/AnikadeBeer_231312/sounds/707915/) | CC0 1.0 | grass |
| 752346 | J's Meaty Stab | justjenah | [freesound.org](https://freesound.org/people/justjenah/sounds/752346/) | CC0 1.0 | flesh2 |
| 800337 | Foley Footsteps Grass Foley Makers | FoleyMakers | [freesound.org](https://freesound.org/people/FoleyMakers/sounds/800337/) | CC0 1.0 | grass |
| 877027 | Meat Slime Hit Layer 3 | qubodup | [freesound.org](https://freesound.org/people/qubodup/sounds/877027/) | CC0 1.0 | flesh2 |

## Phase 3: knife animation and feel (built)

### First person (`Config/Viewmodel` TRACKS, `ViewmodelController`)
- **Found in the first prototype:** a track's offsets were applied in the knife's own tilted axes (the blade sits up-left at the hold), so screen-space arcs came out skewed and small; the old Blender wrist clips only turned the blade. Measured in play: grip at (0.62, −0.70, −1.12) in camera space, blade pointing forward-left-up.
- **New `screen` tracks:** the knife's attacks are keyed in camera axes about the grip (x right, y up, z back) and interpolated as rotations (CFrame slerp, no Euler flips). `own` tracks are the whole move, so the Blender wrist clip doesn't play under them. The keys come from `tools/studio/knife_fp_keys.py`, which takes, per key, where the grip is, which way the blade points and which way the edge faces, and solves the offset and rotation. `--check` prints the blade tip's screen position per key.
- **Timings (30 fps):**

| Attack | Anticipation | Strike → contact | Contact | Follow-through | Settle | Length |
|---|---|---|---|---|---|---|
| Slash1 forehand, high right → low left | 3 f (Quad out) | 1.5 f linear | 0.15 s | 3.6 f to past the end pose | overshoot at 12.9 f | 0.50 s |
| Slash2 backhand, high left → low right (arm across the body) | 3 f | 1.5 f | 0.15 s | 3.6 f | 12.9 f | 0.50 s |
| Slash3 finisher, overhead chop | 4.2 f | 1.5 f | 0.19 s | 4.4 f | 15.1 f | 0.58 s |
| HeavyStab, both hands | 8 f pull-back + 2 f held coil | 1.6 f thrust | 0.40 s | overshoot 1.6 f, hold 3.2 f | 23.8 f | 0.90 s |
- **Measured speeds:** blade turn at contact 1,443 / 2,157 / 1,246 °/s (LihFolk *Combat Animation Craft*: 1,000-2,000 °/s); on-screen tip sweep at contact 813-1,065 °/s, about twice the anticipation's (311-507 °/s); the heavy thrust drives the point into the crosshair (tip on screen at (0.01, −0.03)).
- **Hit feel (runtime, never baked):** hit-stop on a body hit 66 ms (light), 80 ms (the chop), 100 ms (heavy); on a wall 35 ms. The view is punched along the swing's screen path (0.25° on a whiff, 0.7-1.1° on a hit, recovering in 0.14 s), a roll kick of 0.6-1.4°, a −3° FOV punch on a heavy hit, and a 0.25° shake after the stop releases (LihFolk *Hit-Stop and Screen Shake Tuning by Numbers*, *Camera Shake and Camera FX*). Numbers: `Config/Animations` `KNIFE_FEEL`.
- **Swipe streak:** a curved Beam whose head sweeps through the crosshair at contact and whose tail chases it, then erodes (white core plus a dark steel body, so it reads on bright floors; no streak on the stab). It's fainter on a whiff and full on a hit, with a small white flash one frame after contact on a body. Walls get the surface's own burst (sparks on metal, chips and dust on stone, splinters on wood) and the existing gouge, with no bullet hole (`EffectsController.knifeSwipe`, `knifeContact`, `impact(..., noHole)`).
- **Inspect:** raise and turn to one face, flip over the knuckles (a half turn about the blade) to the other face, flip back, settle (2.3 s). Each flip is caught on a balisong click (`inspectFlips`).
- **Sound timing:** each whoosh is cut so its peak sits 60 ms (light) or 90 ms (heavy) into the file. `WeaponController` starts it so the peak lands 30 ms before contact (LihFolk *Feedback Timing*: never early at the hit, 0-30 ms late fuses). The impact sound plays at the start of the hit-stop.

### Third person (`tools/studio/make_knife_poses.py` → group-owned clips)
- `GG_KnifeSlash1/2/3` (same lines and contact times as first person) and `GG_KnifeHeavy` (pull back, coil, thrust, hold), upper body only (Action4) so the legs keep running. The server counts the chain (`WeaponService`, cosmetic `SwingStep` attribute) so others see the right slash. Plus a new `GG_KnifeReady` loop.
- **Overlap gate:** checked on oriented boxes of the block R15 rig, every 1/60 s, with joint neighbours skipped. The first draft failed (forearm 0.38 studs into the chest; even lane D's ready pose was at 0.22). The poses are now re-solved: the joints move until the limbs clear the torso, while each key's **blade tip stays within 0.16 studs** of where it was authored. The worst is now **0.015 studs**, with the wrist kept within real limits (≤ 60° flexion, ≤ 40° side to side; the worst is 39°). In practice the chest twist carries the follow-through instead of the arm folding across the body.
- Peak blade-tip speed sits in each strike (Slash1 91 studs/s at 0.12 s, Slash2 55 at 0.15 s, Slash3 114 at 0.18 s, Heavy 68 at 0.40 s). The wind-up is 3 frames, so the strike is the fastest segment.
- **Checked in Studio** (key poses FK-posed on block dummies; frozen first-person frames in a live playtest): each slash reads ready → wind-up → contact → follow-through, the backhand comes across from the left, the chop is raised overhead, the heavy pulls back and drives into the crosshair with both hands, and the inspect shows both faces. A real hit on a range dummy gave the server-confirmed "50", the hit marker, the flash and the full streak during the hit-stop. A hit on a concrete wall gave chips and dust at the crosshair. The new atlas loads in game (142.5 s).
- Ids in `Config/Animations` (`KnifeReady`, `KnifeSlash`, `KnifeSlash2`, `KnifeSlash3`, `KnifeHeavy`). `MakeCombatPoseAnimations`' knife clips are marked superseded.

## Phase 4: sound pass (built, in the same atlas upload)
Sourcing for these was done by a sub-agent with the same tools and rules (CC0 checked on each page, real recordings only, descriptions read: `521587` rejected for a layered thud). I re-measured and picked from its results. All of it is in atlas v3 `133446200676645` (one audio upload this month, 2026-11-05).

| Sound | Used | Alternates | Wired in |
|---|---|---|---|
| `HitConfirm` (body hit) | 119839 kbnevel: two clinks of a glass (0.11 s, −20 LUFS) | 478197 JonnyRuss01 "Click_1"; 235563 SkeetMasterFunk69 "pen clicking" | `Sounds.HitBody` |
| `HeadConfirm` | 255156 jmayoff: a fork tapped on a wine glass (lightly denoised by its author); 515643 MashedTatoes2: a spoon on a glass candle holder | 99625 tec_studio "bell003mono" (small bowl bell); 346328 steaq "Bright Tibetan Bell Ding" | `Sounds.HitHead` |
| `KillConfirm` | 221515 AlaskaRobotics: a metal service bell (one take, a learned signature, not randomised) | 405665 Anthousai "metal bowl hit with a spoon"; 346328 steaq | `Sounds.Kill`, `KillHead` |
| `StepConcrete` ×4 | 208103 Phil25: steps on a stone slab | 166509 Yoyodaman234 "concrete footstep 1"; 521590 Fission9 "Hiking Boot Footsteps on Stone" | `FootstepController` |
| `StepMetal` ×6 | 208101 Phil25: steps on a metal plate | 50724 RutgerMuller "Footsteps Metallic Muffled Louder"; 148462 conleec "FOLEY_Footsteps_Metal_001" | 〃 |
| `StepWood` ×6 | 208104 Phil25: steps on wooden floor panels | 235718 speedygonzo "sneakers on wood"; 19292 martian "footstep on wood foley" | 〃 |
| `StepGrass` ×5 (grass, ground, mud, sand, fabric) | 208102 Phil25: walking on grass ("Soil Steps") | 800337 FoleyMakers "Footsteps Grass" (quiet, hissy); 707915 AnikadeBeer "walking on grass with sneakers" | 〃 |
| `StepSnow` ×6 (snow, ice, glacier) | 613849 Nox_Sound: mountain boots in snow | 543385 alexo400 "FOOT_STEPS_SNOW_HEAVY"; 333422 MDRivet "Snow Walking Quiet" | 〃 |
| `SlideStart` ×3 | 641386 WhiteFire43: a shoe skid on wood; 420392 Magdaadga: sliding on frozen asphalt (2 takes) | 504383 Joao_Janz "Boots Gravel Feet Slide"; 187343 baidonovan "Rubber Shoe Squeak" | `Juice.SLIDE.sound` (yours 2D, others' 3D) |
| `UiClick` ×2 | 478197 JonnyRuss01: a click; 256116 kwahmah_02: a click | 108336 Qat "click_01-fast"; 146718 Leszek_Szary "button" | `UiSounds.Hover` / `Select` (in-match menus; the lobby has its own sounds) |

- **Footsteps** (`Controllers/FootstepController`, new): a step every 5 studs on the ground (6.2 sprinting, 3.6 crouching), so about 3.2 steps/s at 16 studs/s, matching the run cycle. The surface comes from a downward raycast's material. Your own steps play 2D and quiet (0.32); everyone else's play 3D at their feet (0.75, fading out by 80 studs, not tracked past 90). Crouch-walking is ×0.3, sprinting ×1.25. No steps in the air or in a slide. It's distance-based, so it works the same for players, bots and dummies without a remote. Numbers: `Config/Audio` `STEPS`.
- **Swapped out (kept in the atlas for going back):** the synthesized hit tick, head ding and kill sounds; the ProSoundEffects slide scrape `9125380604`; Roblox UI clicks `15675032796` / `15675059323`.
- **Not done:** reload and equip cleanliness. Every gun shares four Audioscape foley ids (mag out, mag in, rack, draw). Per-class CC0 foley is the next step, see *Offered* below. Damage-taken and the low-ammo tick stay synthesized.

### Offered, not built
- **Map ambience** belongs to the `map-redesign` lane: wind and distant harbour (cranes, gulls, water lapping) for Dockyard2, sourced and polished the same way and added to the atlas on its next upload.
- **Per-class reload and draw foley** from CC0 gun-handling recordings (the Free Firearm Sound Library has handling takes), replacing the shared Audioscape ids.

## Phase 5: scoring (LihFolk `quality-score`, animation rubric, 3 blind reviewers, median per criterion)
Evidence given to the reviewers: frozen first-person frames from live playtests (wind-ups, contacts, the heavy coil and thrust, both inspect faces, a body hit and a wall hit), third-person key poses on block dummies (front and side), and the measured numbers above (frame timings, blade speeds, overlap, wrist range, arm roll, contact times). Weights P1 3, P2 3, P3-P6 2, P7 1. Bar: 8.5.

| Item | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| First-person knife | 6.7 (P1 1, P2 2, P3 1, P4 2, P5 1, P6 1, P7 1) | 7.7 (P1 1, P2 2, P3 2, P4 2, P5 1, P6 1, P7 2) | **8.3** (P1 1, P2-P4 2, P5 1, P6 2, P7 2; six votes: 8.3 ×4, 9.3 ×2). Round 4: 7.3 / 7.7, reverted |
| Third-person knife | 5.0 (all 1) | 5.0 (all 1; individual 5.7 / 5.0 / 6.0) | **5.7** (P3 2, the rest 1; six votes: 5.7 ×4, 5.0 ×2) |

(The round-3 panel ran twice because a usage limit interrupted the first run; both runs finished, so six votes were recorded.)

**First person: shipped at 8.3, 0.2 under the bar, after three fix rounds (the LihFolk maximum).** Round 4 tried what the reviewers asked: a flat, near-horizontal forehand contact, a rolled back-cocked wind-up, two curved keys per strike, and the wrist trailing through the strike. It scored *lower* (7.3 and 7.7 from the first two reviewers): the block forearm filled the right half of the screen at the wind-up and contact, and the flat blade sat under the impact point. So the round-3 version is shipped (LihFolk: ship the best-scoring version), commit `876bfb1`.
What still holds it under 8.5, in every review:
- **P1:** Slash1's contact reads close to the rest pose.
- **P5:** the knife and the RIVALS block arm are one rigid piece, so only the 35 ms wrist lag overlaps.
The likely route to 9+ is a second, separate wrist/forearm part in the viewmodel, so the arm can lag the hand and the blade can roll without dragging the whole block across the screen. That is an arm-rig change, so it needs the user's OK on the RIVALS arm style.

**Third person: stopped at 5.7, below the bar.** The rounds gained 0.0, then +0.7. A fourth attempt, aiming each key's blade by searching the wrist angles, pushed every wrist to its limit and flipped the forearm about 170° between neighbouring keys, so it was reverted, not shipped. What every reviewer still marks down needs an animator, not a pose solver:
- the lower body never drives (P4);
- all joints hit the same key times, so nothing leads or trails (P5);
- a thin black blade on 1-stud block limbs stays inside the body outline from the front at several keys (P1, P7).
The next step is a hand-keyed pass in Studio's Animation Editor or Blender on a standard-proportion avatar, with offset keys per joint and hip shifts. The clips, tools and overlap gate built here are the starting point.

What each round fixed (from the reviewers' lowest criteria):
- **Round 1 → 2 (first person):** contacts re-solved so the blade, not the block arm, crosses the crosshair; the heavy coil drawn in close and rolled edge-up (it read like the rest pose); a 35 ms wrist lag (the arm and blade moved as one rigid piece); a stronger streak.
- **Round 1 → 2 (third person):** the world-model knife used the guns' grip, running the blade along the forearm and hiding it in the body. It now has a forward grip (`Animations.KNIFE_WORLD_GRIP`, applied by `WeaponService` for melee). Also a compact guard, a true backhand cock, a wrist-flexed thrust and side views.
- **Round 2 → 3 (first person):** curved strike paths (a mid key bulged out along the arc); contacts on a 45° diagonal along each cut, with the backhand's hand crossing left of centre; the wrist lag builds only after contact, so the blade is on the impact point at the hit frame; the inspect's second face is edge-on (spine to camera).
- **Round 2 → 3 (third person):** the hand's yaw is the forearm's turn (up to 85°), so the blade lies broadside along the cut at contact; the backhand follow-through ends low and forward; the chop's raised blade tips back over the head.

## What the user should check tonight
Listen with headphones. Every sound is a real CC0 recording; to swap one, see *To swap a sound* above (2 alternates are listed per sound).
- [ ] **Knife swings (first person):** click 1-2-3 quickly. Each slash takes its own line: forehand (high right to low left, the blade on a diagonal through the crosshair), backhand (the hand crosses left), overhead chop. Each whoosh should peak just before the blade crosses the crosshair, rising a semitone per step. Right-click: the knife is drawn in close, held, then a two-handed thrust. Y: the inspect shows one face, turns the spine to you, flips with two balisong clicks.
- [ ] **Hit a bot or range dummy:** a short freeze (hit-stop), a camera punch, a flash and a full swipe streak, the cabbage-stab sound, the glass-clink hit tick. Kill it: the service-bell kill sound. Does the freeze feel good or too long (`Config/Animations` `KNIFE_FEEL` `stop`)?
- [ ] **Hit walls:** concrete (axe-on-slab sound, chips and dust), a metal container (knife clash, sparks), wood (knife-into-wood thunk, splinters), grass or snow (a dull stab). The gouge still sits under the crosshair.
- [ ] **Watch someone else swing** (a second client or a bot): three different slashes in a row, a heavy with a coil, the knife held blade-forward (new grip). Third person scored only 5.7: say whether it's good enough for now or should go to a hand-keyed pass.
- [ ] **Footsteps:** walk on concrete, metal, wood, grass and snow (Snowpeak). Crouch-walk (much quieter), sprint (a bit louder). Others' steps should come from their feet. Your own steps shouldn't double with Roblox's default running sound.
- [ ] **Slide:** a shoe skid at the start (yours and others').
- [ ] **Menus in a match:** hover and click use the new real click. If it's too dry or too quiet, the old Roblox clicks are noted in `Config/UiSounds`.
- [ ] **Guns:** nothing about the guns changed (same slices in the new atlas), but fire a few to confirm nothing went silent.

## Phase 6: map ambience (Dockyard2 first; core chat's follow-up job)
Ambience is a client controller driven by data:
- **Beds:** each map gets a stereo 2D bed while the camera is inside its box.
- **Emitters:** parts tagged in the map play positional loops (only the nearest 4) and random one-shots, culled by distance.
- **Indoors:** inside a tagged room the outdoor bus is muffled (highs −16 dB, mids −6 dB) and turned down to 35%, and the room tone comes up.
- **Ducking:** the outdoor bus also ducks a few dB under your own gunfire (sidechain).

The client has no "current map" signal, so the map is chosen from the camera position and the map boxes in config. This needs no server change.
- `src/shared/Config/Ambience.luau`: map boxes, beds, room tones, emitter sound kinds (volume, range, loop or interval, pitch), the indoor settings and the voice cap.
- `src/client/Controllers/AmbienceController.luau`: the system; new `Ambience` and `Room` buses in `AudioController` / `Config/Audio`.
- `tools/studio/maps/Dockyard2/Ambience.luau`: places Dockyard2's 19 emitters (10 water along the quay walls and pier ends, the crane hum, 3 gull spots over the water, a far horn, 4 creaks in the stacks) and the 2 Shed rooms in a `Workspace.Dockyard2.Ambience` folder. Lane G's scripts are untouched.
- **Old maps:** a map gets ambience by adding an entry to `MAPS` (its box and beds) and running a placement script like Dockyard2's.

**Tested in play** (Dockyard2 via `ForceMap`, restored afterwards):
- **Outdoors:** the harbour bed (0.45) and wind bed (0.28) play, the room tone is silent, the nearest water loop plays, and all 19 emitters stream in.
- **Inside a Shed:** the beds drop to 0.16 / 0.10, the room tone comes up to 0.55, the bus EQ goes to highs −16 / mids −6, and the water loops drop to 0.24.
- **One-shots:** two gull variants, two creaks and the horn all fired within 40 s.
- **Atlas:** v4 loads (280.4 s).
- **Console:** no new errors.

**Recordings** (all CC0, licence read on each page, real field recordings; `72091` rejected because it was generated in Audacity):
- **Beds** are seamless loops: the tail is crossfaded into the head, and every slice starts on a whole millisecond so the loop region lands exactly (an earlier build clicked at the seams; measured seam jumps are now 1.2-3.4x a normal sample step).
- **Loudness:** the stereo 2D beds are normalised to −24/−26 LUFS integrated, the mono positional loops to −22/−24, and the one-shots to about −24 LUFS momentary. Peaks are capped at −1 dBTP with a lookahead limiter.
- **Atlas:** v4 was `113114942677956`, the second audio upload this month (now superseded by v5, below). The gun slices are byte-identical; the knife and sound-pass slices moved by under 1 ms.

| Sound | Used (Freesound id, author: what it is) | Alternates |
|---|---|---|
| `AmbHarbour` bed | 413334 flood-mix: Baltimore harbour with distant industry (steadiest 24 s, ±0.4 dB) | 342878 Pfannkuchn: Hamburg harbour at night across the river; 570910 bruno.auzet: Loctudy small harbour |
| `AmbWind` bed | 390740 FunWithSound: wind through pines (steadiest 24 s) | 181801 keweldog: breeze; 176252 strangy: wind in a small town (has hammering) |
| `AmbWater` (pier edges) | 254130 clif_creates: harbour, boats at the dock, water lapping, flags (Sennheiser 416) | 384360 Ali_6868: waves on a breakwater; 528067 laughatlantic: lake water lapping |
| `AmbRoom` (inside the Sheds) | 240895 Kostrava: abandoned warehouse room tone | 458871 qreiff: large interior with AC; 144046 gchase: control room low hum |
| `AmbHum` (crane) | 556369 Nox_Sound: a fridge motor hum loop, played at 0.62 speed | 144046 gchase: room-tone hum; 154668 crcavol: large building AC |
| `AmbGulls` ×3 | 462462 Soojay: clean seagull wildtrack (2 bursts); 510917 Lydmakeren: seagulls short | 537854 Ambientsoundapp: seagulls distant; 263786 steaq: single call |
| `AmbHorn` ×2 | 99630 tec_studio: a fog horn in San Francisco; 441223 devy32: big boat horn | 37914 kathol: fog horn (dry); 352374 Kinoton: cruise ship horn ×3 |
| `AmbCreak` ×3 | 238289 LoafDV: long metal creak; 119468 ingudios: metal creak; 556714 NachtmahrTV: bending metal | 339184 joedeshon: squeak; 262325 coltures: squeaky car door |

### Ambience licence ledger (CC0 1.0, read on each sound page)
| Id | Title | Author | Source |
|---|---|---|---|
| 119468 | Metal Creak 4.wav | ingudios | [freesound.org](https://freesound.org/people/ingudios/sounds/119468/) |
| 144046 | Room_Tone_Ambience_Medium_Control_Low_Hum.wav | gchase | [freesound.org](https://freesound.org/people/gchase/sounds/144046/) |
| 154668 | Roomtone_Large_Building_AC.aif | crcavol | [freesound.org](https://freesound.org/people/crcavol/sounds/154668/) |
| 176252 | wind in the grass small town | strangy | [freesound.org](https://freesound.org/people/strangy/sounds/176252/) |
| 181801 | breeze.wav | keweldog | [freesound.org](https://freesound.org/people/keweldog/sounds/181801/) |
| 238289 | Long Metal Creak | LoafDV | [freesound.org](https://freesound.org/people/LoafDV/sounds/238289/) |
| 240895 | abandoned warehouse | Kostrava | [freesound.org](https://freesound.org/people/Kostrava/sounds/240895/) |
| 254130 | Harbor Ambience 2 | clif_creates | [freesound.org](https://freesound.org/people/clif_creates/sounds/254130/) |
| 263786 | Seagull single call | steaq | [freesound.org](https://freesound.org/people/steaq/sounds/263786/) |
| 342878 | Distant harbour noise in a windy night, Hamburg Landungsbrücken | Pfannkuchn | [freesound.org](https://freesound.org/people/Pfannkuchn/sounds/342878/) |
| 352356 | Gentle small waves lapping on shore.wav | Alex_hears_things | [freesound.org](https://freesound.org/people/Alex_hears_things/sounds/352356/) |
| 352374 | Cruise Ship Horn, 3x | Kinoton | [freesound.org](https://freesound.org/people/Kinoton/sounds/352374/) |
| 37914 | fog horn sample(dry).wav | kathol | [freesound.org](https://freesound.org/people/kathol/sounds/37914/) |
| 384360 | Waves Crashing Against Wall/Break Water 2 | Ali_6868 | [freesound.org](https://freesound.org/people/Ali_6868/sounds/384360/) |
| 390740 | Wind 2.mp3 | FunWithSound | [freesound.org](https://freesound.org/people/FunWithSound/sounds/390740/) |
| 413334 | Baltimore Harbor with Distant Industrial Ambience | flood-mix | [freesound.org](https://freesound.org/people/flood-mix/sounds/413334/) |
| 441223 | Boat Horn.aif | devy32 | [freesound.org](https://freesound.org/people/devy32/sounds/441223/) |
| 458871 | Room Tone - Large Interior with AC.wav | qreiff | [freesound.org](https://freesound.org/people/qreiff/sounds/458871/) |
| 462462 | Seagulls / gaviotas clean wildtrack.WAV | Soojay | [freesound.org](https://freesound.org/people/Soojay/sounds/462462/) |
| 510917 | Seagulls_short.wav | Lydmakeren | [freesound.org](https://freesound.org/people/Lydmakeren/sounds/510917/) |
| 528067 | Water lapping on lake Pukaki,South Island,New Zealand.mp3 | laughatlantic | [freesound.org](https://freesound.org/people/laughatlantic/sounds/528067/) |
| 537854 | Seagulls distant.wav | Ambientsoundapp | [freesound.org](https://freesound.org/people/Ambientsoundapp/sounds/537854/) |
| 556369 | Foley_Object_Fridge_Motor_Humming_Loop_Mono_NTG4.wav | Nox_Sound | [freesound.org](https://freesound.org/people/Nox_Sound/sounds/556369/) |
| 556714 | Bending Metal | NachtmahrTV | [freesound.org](https://freesound.org/people/NachtmahrTV/sounds/556714/) |
| 570910 | Loctudy small harbour.wav | bruno.auzet | [freesound.org](https://freesound.org/people/bruno.auzet/sounds/570910/) |
| 72091 | Low Frequency Humming Noise | JoeDinesSound | [freesound.org](https://freesound.org/people/JoeDinesSound/sounds/72091/) |
| 99630 | foghorn.wav | tec_studio | [freesound.org](https://freesound.org/people/tec_studio/sounds/99630/) |

### Check tonight (ambience)
- [ ] Set `Workspace.ForceMap = "Dockyard2"` and play. You should hear a low harbour-and-industry bed with light wind. Walk to a quay edge: water lapping near the walls. Gulls over the water every 10-25 s, a distant ship horn now and then, metal creaks near the stacks, a low hum under the crane.
- [ ] Walk into a Shed: the outside goes muffled and quieter, and a warehouse room tone comes up. Walk out: it fades back in about 0.6 s.
- [ ] Fire a gun: the ambience dips a little under your shots.
- [ ] If anything is too loud, too busy or wrong, the volumes and intervals live in `Config/Ambience`; to swap a recording, see the alternates above.
- [ ] **Save the match place** (Ctrl+S, Save to Roblox): the 19 emitters and 2 rooms live in `Workspace.Dockyard2.Ambience` (Studio-owned, like the map).

### Rooftops2 ambience (same system)
- **Beds:** the city below (`AmbCity`, 0.45) and wind across the roofs (0.24). There are no rooms: nothing on Rooftops2 is enterable.
- **`tools/studio/maps/Rooftops2/Ambience.luau`** places 19 emitters:
  - AC-unit hum loops on the 6 roof and 2 Pit AC units (the nearest 4 play);
  - pigeons cooing on the penthouses, tank houses and lift tower, and wing flaps on the two water tanks;
  - car horns in the street below;
  - two far sirens across the city.
- **Tested in play:** both beds play, the nearest AC loop plays (36 studs), and sirens, flaps, horns and pigeons all fired within 35 s.
- **Atlas v5:** `98111406982561`, the third audio upload this month. Everything earlier is unchanged; 346 s, 17.7 MB, so about 2 MB of headroom is left under Roblox's 20 MB limit.
- **The older maps** get beds only, through `MAPS` entries:
  - Dockyard: harbour and wind;
  - Rooftops: city and wind;
  - Old Town: city and wind, quieter;
  - Snowpeak: wind;
  - Metro and Bunker: room tone (Metro also a faint hum);
  - Greenhouse: wind and a little room tone.

  They'd get emitters the same way, from a placement script per map. Silent loops (other maps' beds, the room tone outdoors) pause, so only audible loops cost a voice.

| Sound | Used (Freesound id, author: what it is) | Alternates |
|---|---|---|
| `AmbCity` bed | 369891 SpliceSound: a Brooklyn rooftop over traffic and an elevated train (steadiest 24 s, ±0.2 dB) | 330427 janbezouska: downtown LA, semi-distant traffic from a 4th floor; 350267 simonjeffery13: a car park near a road on a sunny day |
| `AmbAC` (AC units) | 148906 timgormly: an air-conditioning unit outside a window | 273620 myrinvp: an old AC unit in a garage; 259205 smart8951: a fan |
| `AmbSiren` ×2 | 568814 TRP: distant sirens echoing off buildings (Toronto) | 469363 brunoboselli: a distant ambulance passing; 577312 TRP: sirens, Calgary |
| `AmbCarHorn` ×2 | 182474 keweldog: a car horn in traffic; 349922 DeVern: a car horn honk | 423990 AmishRob: two short beeps |
| `AmbPigeon` ×3 | 701282 5ro4: a male pigeon walking and cooing | 319512 squashy555: a wood pigeon; 154865 pawsound: pigeons cooing in a park |
| `AmbFlap` | 689998 Kinoton: a pigeon flying off, close wing flaps | 616623 TRP: a pigeon flock flying off; 414671 zouzmusic: a short wing flap |

### Rooftops2 licence ledger (CC0 1.0, read on each sound page)
| Id | Title | Author | Source |
|---|---|---|---|
| 148906 | A/C Hum.aif | timgormly | [freesound.org](https://freesound.org/people/timgormly/sounds/148906/) |
| 182474 | car horn.wav | keweldog | [freesound.org](https://freesound.org/people/keweldog/sounds/182474/) |
| 259205 | Ventillation | smart8951 | [freesound.org](https://freesound.org/people/smart8951/sounds/259205/) |
| 273620 | Old air conditioning unit | myrinvp | [freesound.org](https://freesound.org/people/myrinvp/sounds/273620/) |
| 319512 | pigeon.wav | squashy555 | [freesound.org](https://freesound.org/people/squashy555/sounds/319512/) |
| 330427 | Downtown LA, Little Tokyo, late night semi distant traffic.wav | janbezouska | [freesound.org](https://freesound.org/people/janbezouska/sounds/330427/) |
| 349922 | Car Horn Honk.wav | DeVern | [freesound.org](https://freesound.org/people/DeVern/sounds/349922/) |
| 350267 | Outside in the car park | simonjeffery13 | [freesound.org](https://freesound.org/people/simonjeffery13/sounds/350267/) |
| 369891 | New York City night evening rooftop ambience traffic, Bushwick, Brooklyn, above-ground subway M train.wav | SpliceSound | [freesound.org](https://freesound.org/people/SpliceSound/sounds/369891/) |
| 423990 | Car horn beep beep two beeps honk honk | AmishRob | [freesound.org](https://freesound.org/people/AmishRob/sounds/423990/) |
| 469363 | Distant Ambulance Siren | brunoboselli | [freesound.org](https://freesound.org/people/brunoboselli/sounds/469363/) |
| 568814 | 200829 Sirens, distant, ambulence, police, urban echoes roof, stops 9am.flac | TRP | [freesound.org](https://freesound.org/people/TRP/sounds/568814/) |
| 577312 | Sirens, fire, police, close pass, distant, urban, CALGARY, 2011.wav | TRP | [freesound.org](https://freesound.org/people/TRP/sounds/577312/) |
| 616623 | 121003 Pigeon flock fly away, wing flaps, Toronto.wav | TRP | [freesound.org](https://freesound.org/people/TRP/sounds/616623/) |
| 689998 | Pigeon, Flies Away, Flapping Wings | Kinoton | [freesound.org](https://freesound.org/people/Kinoton/sounds/689998/) |
| 701282 | pigeon walking and cooing.wav | 5ro4 | [freesound.org](https://freesound.org/people/5ro4/sounds/701282/) |

### Check tonight (Rooftops2 ambience)
- [ ] Set `Workspace.ForceMap = "Rooftops2"` and play. You should hear the city below with a train now and then, and wind. Near an AC unit, its hum. Pigeons on the high ledges every 12-30 s, now and then a pigeon flying off a water tank. Car horns from the street, and a far siren every minute or so.
- [ ] Old maps (Dockyard, Rooftops, Old Town, Snowpeak, Metro, Bunker, Greenhouse) now have a bed. Say if any doesn't fit.
- [ ] **Save the match place** (Ctrl+S): the emitters live in `Workspace.Rooftops2.Ambience` and `Workspace.Dockyard2.Ambience`.

## Phase 7: reload and equip sounds per gun class (core chat's third job, part 1)

### What was off (found 2026-11-05)
- **Every gun shared the same four handling sounds** (Audioscape foley 01-04: mag out, mag in, rack, draw). Each gun bent them with a pitch range, so a pump shotgun, a revolver and a bolt rifle all made the same click at different speeds. The inspect used the draw sound.
- **No real pump, bolt, lever, revolver or shell sound.** The shotgun pump was the charging handle pitched down. The revolver cylinder was the mag sound pitched up. The lever was the charging handle pitched up.
- **Timing was already right.** Sounds fire on the clip beats (`MagOut`, `MagIn`, `Rack`, `Open`, `ShellIn` markers, `WeaponController` BEAT_SOUNDS), so the sound needs its transient at its start. The new slices peak within 12 ms of their start (inside the 0-30 ms "fuses" window, LihFolk *Feedback Timing - Sound Visual and Haptic Sync*).

### What changed
- 17 new atlas slices, 37 takes (`Foley*`, `tools/audio/build_sfx.py`), appended to the atlas so every earlier slice stays byte-identical. **Atlas v6 = 136994389000525** (360 s, 17.9 MB), set in `Config/Sounds` ATLAS.
- Polished like the knife set: high-pass 120 Hz, cut so the transient lands within 12 ms, a −24 LUFS momentary target (about 6 dB under the shots; very short clicks stay a few dB lower because the −1 dBTP limit holds them), mono, short fades.
- `Config/GunSounds` adds **CLASS_FOLEY**: Rifle, SMG, Sidearm, Shotgun, Sniper, MachineGun. **GUN_FOLEY** overrides single guns: the Sheriff revolver, the Shorty and Outlaw break actions, the Marshal lever, the Operator bolt, the Odin feed cover and the Akimbo draw. Each gun keeps its own volume; the pitch range is the class one, near 1.
- The Knife is untouched.

| Class / gun | mag out | mag in | rack | other | draw |
|---|---|---|---|---|---|
| Rifle (Vandal, Phantom, Bulldog, Guardian) | AK / M16 mag out | AK / M16 mag seat | AR-15 charging handle ×2, M16 bolt release | — | AR-15 handled |
| MachineGun (Ares, Odin) | rifle, pitched 0.9 | rifle, 0.9 | rifle, 0.94 | Odin: cover lifts (revolver open), latches (slide) | rifle, 0.94 |
| SMG (Stinger, Spectre, Akimbo) | Uzi mag out | Uzi mag in | Uzi bolt | — | rifle draw 1.06 (Akimbo: holster) |
| Sidearm (Classic, Ghost) | Glock mag release ×2 | Glock mag seat ×2 | Glock slide ×3 | — | holster draw, Glock grab |
| Sheriff (revolver) | cases out (Glock click, pitched up) | — | hammer cocked ×3 | cylinder out (.22 revolver eject), speedloader (shell clicks) | holster |
| Shorty, Outlaw (break action) | — | — | snapped shut (.22 bolt, low) | barrels drop (revolver open, low), shells in (Winchester gate) | class |
| Shotgun (Judge, Bucky) | — | — | pump ×3 | shells into the tube ×3 | rifle draw |
| Sniper (Operator) | rifle, 0.96 | rifle, 0.96 | .22 bolt ×2 | — | rifle draw |
| Marshal (lever) | — | — | Winchester 1873 lever ×2 | a round through the gate | rifle draw |

### Foley licence ledger (CC0 1.0, read on each sound page; files in `art-source/audio/downloads/freesound-<id>/`, gitignored)

| Id | Title | Author | Used for | Kind |
|---|---|---|---|---|
| 393732 | AR15 M4 Gun Hardware Magazine Movement Sounds | jackthemurray | rifle rack, rifle draw | real gun |
| 393734 | Glock 19 Handgun Pistol Slide Cocking Sounds | jackthemurray | pistol mag, slide, grab | real gun |
| 674742 | AK-47 Assault Rifle being unloaded and reloaded | serøutōnin--deprivəd | rifle mag out / in | mixed real |
| 725397 | An M16 Rifle being reloaded while empty; full sequence | serøutōnin--deprivəd | rifle mag out / in, bolt release | airsoft replica |
| 677160 | Uzi submachine gun being reloaded while empty | serøutōnin--deprivəd | SMG mag and bolt | airsoft replica |
| 693125 | 22lr Revolver ejecting bullets from cylinder | serøutōnin--deprivəd | revolver / break-action open | real gun |
| 145209 | shotgun sounds | lensflare8642 | shotgun pump | real gun |
| 204204 | 22 Bolt.wav | Danwardvs | sniper bolt, break-action shut | real gun |
| 218319 | Winchester 1873, cock and dry fire.wav | SpliceSound | lever, shell clicks | real gun |
| 540065 | Weapon_Revolver_Hammer_Mono.wav | Nox_Sound | revolver hammer | real gun |
| 388819 | Holster Pistol | nioczkus | pistol draw | real |

Links: `https://freesound.org/people/<author>/sounds/<id>/`.

Alternates downloaded but not used: 396331 (1911 reload, the next pistol mag in), 177863 (prop revolver, the next cylinder), 402790 (cocking revolver, the next hammer). Rejected: 432139 (a compilation of other people's uploads, so the licence chain is unclear) and 233044 (resynthesized, not a recording).

### Checked in play (2026-11-05, 13:45, Dockyard2 match, Stinger)
Every `Sound.Played` was logged from the client while a reload and a draw ran by `DevAction`. The reload played `FoleySmgMagOut` at 0.43 s and `FoleySmgMagIn` at 1.33 s. The draw played `FoleyDrawRifle` at 0.00 s and `FoleySmgRack` at 0.40 s. Every slice played at volume 0.6, pitched between 1.01 and 1.06. The class mapping and the clip beats work. A partial reload has no rack; it only plays on an empty reload. Not checked by ear: the AI can't listen. The other classes use the same code path.

### Check tonight (reloads)
- [ ] Reload each class in the test range (`Workspace.TestMode = true`): Vandal, Stinger, Classic, Sheriff, Judge, Shorty, Operator, Marshal, Ares. Each click should land on the hand's move. Say any that sounds early or late, or too quiet next to the shots.
- [ ] The M16 and Uzi takes are airsoft replicas (lighter plastic). If the SMG or rifle mag sounds toy-like, say so; the AR-15 session (393732) has more mag sounds to swap in.

## Phase 8: map life on Dockyard2 and Rooftops2 (core chat's third job, part 2)

Client-only ambient motion: no remotes, and nothing the server sees.

### How it's built
- **Code.** `Controllers/MapLifeController.luau` holds the logic and `Config/MapLife.luau` the data. The pattern comes from the Lobby's `AmbienceClient_V2`: tag-driven, streaming-safe, and asleep beyond a distance.
- **Per-map scripts.** `tools/studio/maps/Dockyard2/Life.luau` and `tools/studio/maps/Rooftops2/Life.luau` each build a `Life` folder in the map. Run them in edit mode in the match place, then save.
- **Tags:**
  - `LifeSpin`, `LifeSway`, `LifePulse`, `LifeFlicker`: turning, swaying, breathing and flickering parts.
  - `LifeGull`: birds on circling loops.
  - `LifePigeon`: perched birds that take off.
  - `LifeDrift`: far ships.
  - `LifeEmitter`: particle emitters that only run while awake.
- **Lane G's art is never edited.** Their parts move through `LifeRule` objects in `Life/Rules`, which name their meshes. Examples: the crane spreader and rigging, the skyline ships, the fans, the neon and one billboard lamp. A `Rotor` rule puts client-side blade copies on the AC and condenser fan discs. A rebuild of the art keeps it all working. My first pass tagged their parts directly, and their rebuild dropped the tags, so I switched to rules.
- **Out of the way of play:**
  - Every moved part is CanCollide, CanQuery and CanTouch false; the controller refuses colliding parts.
  - Birds stay 28 or more studs above the roofs or deck, perched ones sit on ledges and bollards, and steam starts 7 or more studs over a standing head.
  - Glints and foam sit at the waterline, below deck level.
  - Banners hang below the roof edge.
  - The Dockyard2 flag and windsock are on the crane top, about 60 studs up and out of reach.
- **Budget:**
  - One Heartbeat stepper with BulkMoveTo.
  - Everything sleeps beyond 170 studs from the camera; gulls wake within 450 plus their radius, the far ships within 2500.
  - Emitters run only while awake, at half rate on low graphics.
  - Still birds are posed once, not every frame.
  - Particles: about 33 alive on Dockyard2 and about 75 on Rooftops2.
- **Colours.** No team colours. Rooftops2 uses sage and the map's own tank cobalt (47,98,200). The Dockyard2 windsock is signal yellow, and the far-ship containers are blue, mustard and green.
- **Lane G's z-fighting audit** (`Audit.luau`) found 22 pairs and then 24. Both are fixed, and their re-audit now shows **0 pairs on both maps, Life folders included**.
- **LihFolk notes used:**
  - "VFX Performance Budgets and Culling": sleep by distance, one stepper, emitters only switched on or off, decoration off the camera line.
  - "Water Sky and Atmosphere Art": foam and glints at the water line.
  - "World Composition and Set Dressing - Designed, Not Scattered": life in the backdrop, never in the lanes.
  - The `lihfolk-vfx` skill's rules on value and clutter.

### Dockyard2
- **Circling gulls.** 6 gulls (1.5× scale) circle in pairs, 42–46 studs up: one pair around the crane and two over the water channels. Their loops are egg-shaped and breathe, and they flap in bursts, glide and bank.
- **Perched gulls.** 4 gulls sit on quay bollards. When someone comes within 15 studs they take off over the water with a recorded gull call (`AmbGulls`). They fade out 130 studs away and fly back facing their perch, with a landing flare.
- **Crane load.** The spreader and its cables sway together about the trolley (1.6°).
- **Ships.** The two moored ships roll 1.1°.
- **Flag and windsock** on the crane top.
- **Water line.** Foam strips breathe at the foot of the quay walls, and sparkle glints play on the water channels and the open ends.
- **Far ships.** Two container ships at double size cross beyond the far quays, 620 studs out, fading in and out at the ends of their path.

### Rooftops2
- **Fans.** Soft four-blade rotors spin over a blur disc on all 16 AC fan discs and both condenser fans. Speeds vary by ±15% per copy and drift like gusts. The cooling-tower fans turn too.
- **Steam** rises from 4 roof flues and 2 lift-house vents.
- **Perched pigeons (removed, see below).** Three flocks of 3 (1.8×, slate with a pale belly) sit on two tank-house cornices and a roof sign. They peck and turn. When someone comes within 15 studs they flush with a wing-flap sound, fly 110 studs out past the parapets, fade, and come home once nobody is within 32 studs.
- **Sky flock (removed).** 3 pigeons (2.3×) circle 30 studs above the block.
- **Pigeons removed (2026-11-05).** The user called these block birds "blocky and bad". Lane G moved all 12 (`Pigeon_*`, `SkyPigeon_*`) to `ServerStorage.MapBackups.Rooftops2_Pigeons`, and the script now builds them only with `BIRDS = true`. They come back only as a modelled bird: the spec is in [Dockyard2](../../01%20Design/Maps/Dockyard2.md), under Concept pass, Birds. The perch, flush and flight code stays as it is. Dockyard2's gulls are the same kind of block bird and are still in place for now.
- **Flicker.** The roof-sign neon and one billboard lamp flicker now and then.
- **Banners.** Four blade banners on the outer street walls swing about their arms.

### Scoring
LihFolk VFX rubric adapted for ambient life. X5 became "reacts to play" and X6 "never in the way of play". Weights 3/3/2/2/1/2 out of 13, 3 blind reviewers per round, median per criterion.

| Round | Dockyard2 | Rooftops2 | What changed |
|---|---|---|---|
| 0 | 7.3 | 6.5 | first build |
| 1 | **8.85 (pass)** | 6.54 | bollard gulls react, egg-shaped loops, stronger sway, roll and glints, far ships 2× with fades, blade rotors, birds fade and fly home facing the perch, banners square to the wall |
| 2 | — | 8.08 | steam higher and self-lit, pigeons 1.8× with a pale belly and flushed 110 studs, sky flock, blur discs, rotor jitter and gusts |
| 3 | — | 8.08 | cool-grey steam, banners in the tank cobalt, softer rotors over a darker disc, sky flock 2.3× |

- **Dockyard2 ships at 8.85.**
- **Rooftops2 stopped at 8.08.** It had 3 fix rounds, the maximum, and round 3 gained 0. What holds it back:
  - X1 (read at distance) and X3 (colour and value) stayed at 1 in every review.
  - The steam is the main reason. White steam vanished into the pale sky; grey steam reads as smoke in the golden light.
  - The banners only show from the roof edge.
- Round 3 is what's built.

### Not done, or left for the user
- **Steam colour.** It needs a call by eye: near-white (round 2) against grey (round 3). A reviewer suggested (225,228,236) at 0.35–0.45 transparency through mid-life. This is one line in `tools/studio/maps/Rooftops2/Life.luau` → `steam()`.
- **A modelled bird** for the pigeons and the Dockyard2 gulls, to the Birds spec. Build `pigeonModel()` and `gull()` again with the same part names (Body, Head, WingL*, WingR*, and the `HingeX` attribute) so the controller needs no change.
- **Flag and banners** are rigid plates that sway. Two-segment cloth would read better.
- **The Sky Diner neon glows cyan-white,** close to team cyan. That's lane G's art colour; the flicker only toggles it.
- **AC fan disc positions** are ±1.62 studs along the mesh's long axis, measured from screenshots. If lane G re-cuts the AC mesh, adjust `Offset1` and `Offset2` on the `Rotor_ACUnit_Fans` rule.

### Check tonight (map life)
- [ ] **Save the match place** (Ctrl+S). `Workspace.Dockyard2.Life` and `Workspace.Rooftops2.Life` live in the place, not in Rojo; the pigeons are now in `ServerStorage.MapBackups`. `Workspace.ForceMap` is currently `"Rooftops2"`.
- [ ] **Dockyard2:**
  - Walk up to a quay bollard gull: it should take off calling and come back about 30 s later.
  - Look up: gulls circle the crane.
  - Look at the crane load: it sways slightly.
  - Look over the quay edge: foam and glints at the water line.
  - Look out past the ends of the far quays: far ships drift.
- [ ] **Rooftops2:**
  - The AC fans spin.
  - Steam rises from the flues. Say whether it reads as steam or smoke.
  - Look over the street-wall edges: the banners swing.
- [ ] Peek over an AC unit as the enemy would. The spinning rotor must never draw the eye before the head does. If it does, raise the `Blur` part's transparency to 0.75 in the rotor template in `tools/studio/maps/Rooftops2/Life.luau`.
