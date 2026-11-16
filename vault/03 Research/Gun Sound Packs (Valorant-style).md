# Gun sound packs for a Valorant-style sound (research, 2026-11-09)

**Why:** the owner tried the [2026-11-08 overhaul](../05%20Production/Playtests/2026-11-08%20Gun%20Sound%20Overhaul.md) in game and rejected it, along with the old sounds: "dull, boring", not like Valorant, where the guns "make you want to shoot". **Target:** punchy and designed. A little stylised, but not cartoony and not raw-realistic. Skins should later get sounds of their own.

## What makes Valorant's guns sound like that

It isn't one better recording. Each shot is **designed**:
- a sharp mechanical **transient** (the action and the trigger),
- a punchy **body** with weight down low,
- a **crack**,
- often a stylised **sweetener**,
- then a **tail** that fits the space.

Every layer is tightly compressed and gun-specific. Riot recorded its own foley (shells, mags) and directional third-person shots. Skin sounds are swapped layers kept "neither louder nor softer" than the base gun, so spray control and footsteps still read ([How the VALORANT Arsenal was built](https://playvalorant.com/en-us/news/dev/how-the-valorant-arsenal-was-built/)).

So there are two problems:
1. Our sources are raw field recordings. The Free Firearm Library was recorded in front of the shooter; the Snake pack is a hobby recording of 3 calibres.
2. The 2026-10-25 rule "one recording, polished, no layers" rules out exactly the layering that gives Valorant its punch. That rule came from a test built from **synth** layers. Layering **real, professionally recorded** parts is a different thing, and it's what the target needs.

## Free sources that are good enough (licence checked 2026-11-09)

### 1. Sonniss #GameAudioGDC bundles: the best free option
- **Where:** [sonniss.com/gameaudiogdc](https://sonniss.com/gameaudiogdc). Direct zips on downloads.sonniss.com (or the official torrent), 2015 to 2024, plus GDC 2026 at [gdc.sonniss.com](https://gdc.sonniss.com).
- **Licence** ([v2.0, effective 2026-08-27](https://sonniss.com/gdc-bundle-license/)):
  - commercial games are allowed, no attribution, for unlimited projects, forever;
  - no redistributing them "as sound effects" (sample packs, asset packs; redesigned sounds stay covered);
  - no AI training.
- **On Roblox:** upload them **privately** inside our own game (as our atlas does). Never tick "distribute on Creator Store". Sonniss's licence doesn't name Roblox. LihFolk `lihfolk-sfx` treats a private asset as normal in-game use.
- **GDC 2016** (12.9 GB, 6 parts), the one to get:
  - **Pole Position Production**, about 40 single-gun libraries, pro-recorded with multiple mics, close to far:
    - rifles: HK416, G36C, G3, FN FAL, FAMAS G2, Tavor TAR-21, L85, AKM;
    - SMGs and pistols: MP5, MP7, P90, Uzi / Mini Uzi, Scorpion, Thompson, Grease Gun, Steyr TMP, Ingram M10, Beretta 93R, Glock 18c, Sig P229, FN Five-seveN, VP70;
    - revolvers: S&W M29 **.44 Magnum** and M66 .357;
    - snipers: Barrett M98B .338, Sako TRG 22, Remington 700;
    - shotguns: SPAS-12, Saiga-12, USAS-12;
    - machine guns: L7A2 GPMG, Minimi (belt fed), M1919, BAR;
    - a **De Lisle suppressed carbine** (a real suppressed shot);
    - **Various Gun Foley & Handling**.
  - Audiobeast **London Warehouse Firearms Library** (indoor shots: 1911, M2 .50, Remington 870, HK416).
  - Fascinated Sound **The Gun Locker**.
  - **SoundMorph Future Weapons 2**: designed sci-fi weapons, the source for skin sweeteners.
  - TS Sound 12 Gauge Shotgun, Stuart Duffield Bullet SFX.
- **GDC 2021-2023** (38.7 GB):
  - Pole Position Glock 17 and the Black Powder Guns Library;
  - David Dumais **Sci-Fi Weapons Pack 1**;
  - Shapeforms **Sci-Fi Weapons Cyberpunk Arsenal**;
  - RYK Laser Guns.
  - Skin material.
- **GDC 2024 / 2026:** no gun libraries were seen in their track lists (2026 has Epic Stock Media as a vendor, but no firearms were visible). Not needed.
- *Caveat:* some 2016 / 2021-23 names come from a mirror's directory listing; check them once downloaded.

### 2. Smaller free picks
- Fab **Modern Pistols SFX** (Sound Kajiya, free): 25 shots, slide, mag, outdoor tails. Licence for use outside Unreal **not confirmed**; check before use.
- The Snake packs (in use now) and the Free Firearm Library (CC0): fine as handling or extra layers, not as the hero shot.

### Cheap paid ones, if free isn't enough
- **Epic Stock Media "Game Weapons"** ([itch.io](https://epicstockmedia.itch.io/game-weapons), $77-96): 880 *designed* gun sounds plus 677 foley, "Halo & Borderlands styled". The closest off-the-shelf match to "not cartoony, not super realistic". Royalty-free (read the licence text before buying).
- **Gamemaster Audio Gun Sound Pack** ([Sonniss](https://sonniss.com/product/gun-sound-pack), $19.99): 416 recorded game gun sounds.

### Ruled out
- **Creator Store gunshots:** almost all rips from other games ("Infinity Ward", "StarCraft 2" in the descriptions). No rights chain (searched 2026-11-09).
- **ElevenLabs free:** AI-generated and needs attribution.
- **ZapSplat, Artlist:** see LihFolk `lihfolk-sfx` → dropped sources.
- **Kenney-style packs:** cartoony.

## Hits, headshots, kills and feel (owner, 2026-11-09)

**The ask:** better hit sounds; a headshot that sounds different; a kill sound. More feel when you shoot and when you hit: "Valorant hit and fun", not "CS:GO smooth". It's a fun ability game. Wall hits and knife slashes are fine as they are.

**What exists now** (mapped 2026-11-09):

| Moment | What we have now |
|---|---|
| Shooting | viewmodel kick 0.065 back / 0.045 rotate (`Config/Viewmodel`, per-gun `viewmodelKick`); camera recoil per gun; shot FOV punch and roll (`Config/Juice SHOT_FEEL`, max 2.2° / 1.1°); shake up to 1.2°; muzzle flash and shells. No hit-stop on guns |
| Hit markers | body white 0.2 s, head amber 0.28 s, kill red X 0.45 s (`Util/HitFeedback`); damage numbers stack per target; hit flash on the enemy; the victim flinches |
| Sounds | body = a glass clink, head = a fork tapped on glass, kill = a service bell, and **a headshot kill uses the same bell**. No escalation per kill. All real CC0 recordings, but they read as "dinner party", not as hits |
| Kill | kill feed with a headshot tag, the final-kill replay. **No multi-kill banner or escalation** |

The owner's 2026-11-08 gun round asked for "more umph" too ([Weapon RemasterV2](../05%20Production/Weapon%20RemasterV2.md)).

**What Valorant does differently:**
- **body hit:** a short, solid thwack with a click;
- **headshot:** a bright metallic **"tink"** that cuts through everything;
- **kill:** a tonal confirm that **climbs with every kill in the round** (1 to 5), with a headshot-kill variant and a banner that pops with it;
- **shot weight:** every shot has weight, and the hit marker and crosshair react.

**Sources for the hit and kill sounds:**
- **Roblox-licensed Pro Sound Effects** in the Creator Store: free, licensed for Roblox experiences, nothing to upload. Found 2026-11-09:
  - Gas Pump Bell CU Metallic Dinging Muted 2 (9114557075): a sharp ticking ring, the headshot tink;
  - Tuning Fork 1 (9120288183): a clean tone, for the kill confirm, pitched up a step per kill;
  - Body Hits Leather Baseball Glove 2 (9113513536): the body thwack.
  - More in the same catalogue: metal clanks, pipe hits.
  - Community uploads in the same search (a "gamesense hitsound", CoD rips) are out.
- Sonniss bundles: designed UI and impact libraries for alternates.
- Rule (memory): real recordings, layered and polished, never synth; audition first.

**Feel ideas to prototype** (all data in `Config/Juice` / `Config/Viewmodel`):
1. Heavier per-gun kick (snappier back-kick and recovery, the MGs and snipers bigger).
2. A hit-marker pop: scale-in, a stronger and bigger headshot marker, a crosshair "bloom" tick on hit.
3. A 1-frame flash on headshots.
4. A kill banner with a counter that climbs with the kill sound.
5. A short screen-edge flash on a kill.
6. **No** hit-stop on guns: it fights aim in a competitive shooter (LihFolk 47 Game Feel: hit-stop is for melee).

## Proposed plan (needs the owner's go)

1. **The owner downloads** Sonniss GDC 2016 (12.9 GB; at least the parts with the Pole Position libraries and SoundMorph Future Weapons 2) into `art-source/audio/library/` (gitignored). It never goes in the repo.
2. **Prototype 3 guns first** (Vandal, Classic, Operator):
   - build each shot from real, pro-recorded layers: a mech transient (Pole Position close mic), body and crack (the matching gun's close / mid mics), and a tail (the mid / far mic);
   - glue it hard, Valorant-style;
   - one audition reel, side by side with the current sound;
   - no synth.
3. On a yes, the other 15 guns plus handling from Pole Position's foley, then upload.
4. **Skins:** a skin can swap one layer for a SoundMorph / Dumais sci-fi one, at the same loudness as the base gun (Riot's rule). The code side is small: `GunSounds.get(weaponId, skinId)` with a per-skin override set. Parked in [Bugs & Ideas](../05%20Production/Bugs%20%26%20Ideas.md) until skins exist.
