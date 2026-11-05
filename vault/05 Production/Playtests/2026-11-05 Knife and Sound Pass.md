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
- **Atlas:** v4 is `113114942677956`, the second audio upload this month. The gun slices are byte-identical; the knife and sound-pass slices moved by under 1 ms.

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
