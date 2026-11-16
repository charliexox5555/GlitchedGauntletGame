# 2026-11-13 Hit Feedback Pass (lane F)

Lane F of [Handoff - Grades to 9-10](../Handoff%20-%20Grades%20to%209-10.md). **Owner's asks (2026-11-13):**
- Crosshair hit markers that look more professional and more satisfying.
- The player you hit flashes **white and red instead of yellow**: "a fun highlight and slash".
- A headshot sprays **cartoony fire from the head** (the ChatGPT fire) and gets **a different highlight**.
- Sounds stay as they are (later).

**Status:** built and checked in Studio (match place, test range, Vandal), with captures and frame-by-frame timings. **Revised the same night after the owner's first look (§9):** the slash is toned down and the headshot fire is now a muzzle-flash-style pop. Nothing committed. The owner still has to judge the feel at full speed.

## 1. Findings before (Studio, match place)
- **Bug: the hit flash lit only the head.** The flash was one Highlight on the character. The arms, legs and torso are skinned meshes in `Workspace.GGBodyLimbs`, outside the character (`shared/MatchBody`), so they were never lit. Reproduced with the old settings (yellow `FFD23F`, fill 0.32 on the model): only the head turned yellow.
- **Double pop.** The marker popped on the client's predicted hit and popped again when the server's confirm landed about 70 ms later in Studio (one ping later in live play), so every hit stuttered.
- **The flash** was a flat fade in one colour (white on the body, yellow on the head, orange-red on a kill), with no outline and no slash.
- **Headshots** had nothing special apart from the amber X.
- **A kill flash was never seen.** DeathFxController hides the body on the kill and shows a falling copy, so the flash stayed on the hidden body.
- **The markers** were thin single-colour bars with a weak 1 px outline. On a white-flashed body the white X almost disappeared.
- **The damage numbers** used BuilderSans, not the theme's Sarpanch, and headshots showed in amber.

## 2. References
- **LihFolk** (through `lihfolk-lookup`):
  - *Highlights and Selection Effects*: 255 per client in the 2026 docs, 31 in older engines. Adding or removing a Highlight rebuilds; changing its properties is cheap. A Highlight can adorn a Model or Folder.
  - *Memory Budgets and Leaks*.
  - *Game Feel and Juice*: the hit marker goes on the hit, the head marker is distinct, and a kill gets its own marker.
  - *Gun Feel*.
  - *Hit-Stop and Screen Shake Tuning by Numbers*: no stop per shot at about 10 shots/s. This keeps the Style Bible's **no hit-stop**.
  - *Particle Emitters In Depth* and *ParticleEmitter Engine Reference Card*: Grid4x4 Loop is capped at 30 fps; OneShot spreads its frames over the particle's lifetime; set `LightInfluence` yourself; `LightEmission` 1 is additive.
  - *Elemental VFX Kits*: the fire layers.
  - *Slash VFX Recipes - Crescent and Ring*: sweep 3-5 frames, hold 1-2, erode 10-15.
- **Video study:** a frame burst of RIVALS (`U9XcolnRiXA` 6:00-6:04) showed no clean hit frames, so I didn't spend more on it. The existing [Valorant UI](../../03%20Research/UI%20References/Valorant%20UI.md) note gave a small white marker and a red flash on headshots. [Rivals PC UI](../../03%20Research/UI%20References/Rivals%20PC%20UI.md) says its headshot markers were never captured. **Not done:** a proper frame-by-frame RIVALS / Valorant hit-marker study. The design leans on LihFolk and the theme.
- **Art:**
  - The fire is the Molly flame flipbook (`VfxTextures MOLLY_FLAME_4x4`, `MOLLY_BURST_2x2`, `MOLLY_EMBER`) and [firevfx.jpg](../../02%20Art/References/mods/firevfx.jpg): crisp orange tongues with yellow cores.
  - The UI theme: [Soft Edge](../../02%20Art/UI%20Theme%20v4%20Soft%20Edge.md) (damage red `FF4D5E`, Sarpanch for numbers, the slash as a hero accent).
  - The [Style Bible](../../02%20Art/Style%20Bible.md) §4.

## 3. What was built
All numbers are in the new `src/shared/Config/HitFx.luau`.

**Crosshair markers** (`Util/HitFeedback`):
- An X of four arms that **punch out** from the crosshair with an ease-out-back and settle in 80-100 ms, hold, then fade while drifting outward.
- The arm length follows the damage: ×0.9 at 10 damage, ×1.3 at 80.
- Arms have a 1.5 px dark outline at 25% transparency, so the X reads on a white flash.
- **Body:** a white X.
- **Headshot:** a red `FF4D5E` X with a white core, longer, with a small rotation kick.
- **Kill:** a bigger red/white X plus a **ring** that bursts from 12 to 40 px.
- **Predicted hit and server confirm merge into one pop.** A confirm within 0.25 s of an unconfirmed pop joins it. If the server says headshot, the marker upgrades to a re-pop; if not, it quietly downgrades.
- Damage numbers use Sarpanch Bold, go red on headshots with a bigger pop, and sit further out (+52, -40 px) so they clear the biggest X.
- A headshot slash *through the marker* was tried and turned off (`slash = false`): with the world slash, two slashes read busy.

**Body flash** (new `Util/HitFx`, called from `EffectsController.hitFlash`):
- One Highlight on the character **plus one per skinned limb mesh** (the `BodyLimb` links), so the whole body flashes.
- **Body hit:** white (fill 0.15) for 40 ms, a 40 ms blend to red `FF3B4A`, then a fade, gone at 0.2 s. A white outline fades over 0.14 s.
- **Headshot:** white for 50 ms, then **fire orange `FF7A1F`** with a warm rim `FFD9A0`, gone at 0.32 s. This is the "different highlight" that matches the fire.
- **Kill:** white, then deep red `FF2E3D`, gone at 0.42 s. **It moves onto the death copy** (`<name>Down`, tag `DeathFxCopy`) and its limbs in `GGBodyLimbsLocal`, so the kill flash is seen while the body falls.
- **Budget:** at most 18 flash Highlights (6 per body). Past that, a body flashes its model only, then nothing. Highlights exist only while a body is flashing.

**Slash:**
- A pooled `BillboardGui` (6) at the hit point, 1.2 studs toward the camera.
- A red edge under a white core with tapered ends. It wipes in over 45 ms, then thins and fades by 0.16 s (headshot 0.2 s).
- On a kill it is a **crossed pair**, 3.6 studs with a 60 px floor.
- Each slash has a pixel floor (46-60 px), so it still reads at range.

**Headshot fire:**
- Three pooled rigs, each with 4 emitters (flames, embers, whoomp, white pop).
- The rig sits 0.5 studs above the hit point and sprays mostly up and a little away from the shooter. Away-only was hidden behind the head in the first capture.
- **8 flame tongues** from the 16-frame flipbook (26 fps, low `LightEmission` 0.12 so they stay solid and crisp; additive blew them out into a white blob at first), 10 embers, the Molly whoomp, and a 50 ms white pop.
- ×1.5 on a head kill, and it **grows with range** (×dist/25, up to ×2) so it reads far away.

## 4. Measured (Studio, Vandal, 60 fps runs unless noted)

| What | Number |
|---|---|
| Predicted marker pop | 1 frame after the shot (17 ms) |
| Server confirm (Studio) | 69-70 ms. It **merges** into the predicted pop: scale log 1.079 → 1.030 → 1.004 → 1.000, no second rise |
| Body flash | 6 Highlights (model + 5 limbs); white 0.069-0.102, blend to `FF3B4A` by 0.149, gone at 0.266 (0.2 s life) |
| Head flash | white 0.069-0.119, orange by 0.169, gone at 0.40 (0.33 s) |
| Kill flash | copy appears at 0.357; the flash is on the copy and its 5 local limbs by 0.369 (one frame); gone at 0.735 (0.38 s) |
| Body marker | visible 0.017 → 0.33 with the confirm merge (0.28 s life) |
| Spray (1 s, Vandal) | 3 pops for 3 shots, each confirm merged; no double pops. Measured with Studio throttled to 15 fps in the background |
| Cost: 8 bodies flashed in one frame (worst case) | `hit()` ×8 = 2.28 ms total, including first-time pool creation; `step` ≤ 0.39 ms; all Highlights gone after 0.6 s. Pools per client: 12 emitters, 6 BillboardGuis. Fire particles per headshot: 20 (30 on a kill). The range already had 8 other Highlights (the gun outline, dev outlines) |

**Captures** (frozen with `VfxTimeScale`, looked at zoomed):
- **Body:** the whole dummy turns white, then red, with a white-core red slash.
- **Headshot:** an orange body, a crisp flame cluster above the head with embers, a red/white X and a red number.
- **Head kill:** a crossed slash, the kill X with its ring, a red 100, big fire.
- **Body kill:** the falling copy flashes red; the 100 clears the X.
- **51-53 studs:** a body hit reads (red body, slash at its pixel floor). The headshot fire at ×2 reads, where it was about 20 px tall before the range scaling.

## 5. Grades
| Item | Grade | Evidence / what holds it back |
|---|---|---|
| Whole-body flash white → red (the limb bug) | **9** | 6 adornees measured; captures at both phases; kill flash carried to the death copy |
| Headshot highlight (orange with a warm rim) | **9** | Captures; clearly different from the body hit |
| ~~Headshot fire spew~~ (replaced, §9) | ~~8.5~~ | The owner didn't want real fire; see §9 |
| ~~Slash~~ (toned down, §9) | ~~8.5~~ | The owner: "a bit obnoxious"; see §9 |
| Crosshair markers | **8.5** | One clean pop per hit (the double pop is fixed), two-tone head and kill variants, scales with damage, kill ring. Needs the owner's eye at full speed; the size is a taste call (`MARKER.*.length / gap`) |
| Damage numbers | **8.5** | Sarpanch, red headshots, clear of the X. The stack and fall motion are unchanged |
| Cost | **9** | Measured worst case above; everything pooled; Highlights capped at 18 and only alive while flashing |

Below 9 on the feel items because a person hasn't judged them at full speed. That's the owner's call, not a known flaw.

Re-graded after the owner's feedback in §9.

## 6. Not verified
- What it looks like at full speed by eye. Studio was in the background (15 fps) for the last spray, and every visual check was a frozen frame.
- Phone screens (the marker is designed at 1080p and scales 0.75-1.5 with screen height).
- Shotguns: many pellets on one body is one flash, but a marker pop per pellet confirm was not checked.
- The knife: it uses the same hit confirm, so it should get the same flash and slash; not checked.
- Two real players: the effects are local to the shooter, so another player's view doesn't apply.
- Not seen against dark map backgrounds (only the bright test range).

## 7. What to test (owner)
1. Range: tap body shots, then headshots, then spray a dummy. Is the white → red flash plus slash the "fun highlight and slash"? Is the X big enough?
2. Headshot at 10 and at 50 studs: does the flash pop from the head feel like the Valorant flash you meant? Too big or too small? (`Config/HitFx HEAD_FLASH`)
3. Kill a dummy: the kill X with its ring, the slash, the falling body flashing red.
4. Full-auto spray: is the slash now quiet enough? (`Config/HitFx SLASH`: `size`, `alpha`, `minGap`)

## 8. Files
- **New:** `src/shared/Config/HitFx.luau`, `src/client/Util/HitFx.luau`.
- **Changed:** `src/client/Util/HitFeedback.luau` (markers, numbers), `src/client/Controllers/EffectsController.luau` (`hitFlash` forwards to `Util/HitFx`, steps it).
- `Config/Juice HIT_FLASH` is no longer read. The first-person feel session owns `Juice`, so it can delete that block.
- **Follow-up (not this lane's file):** DevModController's `DevOutline` on dev dummies has the same head-only bug (it outlines the character, not the limb meshes). Logged in [Bugs & Ideas](../Bugs%20%26%20Ideas.md).

## 9. Owner's first look and revision (2026-11-13, night)
**Feedback** (the owner saw it in Studio before bed; relayed by the coordinating session):
- **Slash:** "that kind of slashing look. I kind of love it, but I think it's a bit obnoxious... but I like the idea of it". Keep it, tone it down.
- **Headshot fire:** "the fire on the head is not supposed to be like actual fire. It's supposed to be kind of like the Valorant kind of like flash fire looking thing... It's gonna be very similar to like the muzzle flash look". Use best judgment; he'll adjust in the morning.

**Changes** (all in `Config/HitFx`):

*Slash*
- About half the size: 1.9 / 1.8 / 2.4 studs for body / head / kill, was 3.2 / 3 / 3.6. Pixel floor 24-30 px, was 46-60.
- Shorter: 0.1-0.15 s, was 0.16-0.28.
- See-through: base transparency 0.15-0.2.
- One slash on a kill, not the crossed pair.
- **At most one every 0.14 s** (`minGap`; kills always get one).
- Measured: a 1 s spray at 60 fps had 5 hits and showed 3 slashes.
- **Capture:** a thin, see-through red/white streak on the torso that no longer covers the body.

*Headshot flash pop* (`HEAD_FLASH`, replaces `FIRE`; the Molly flame flipbook is no longer used here)
- Built from the muzzle-flash art the guns use (`VfxTextures FLASH_FRONT_2x2`, `FLASH_SIDE_2x2`, colours baked, as in `Util/MuzzleFx`):
  - one star burst facing the camera;
  - 5 flame tongues shooting out (`VelocityParallel`, like the side flash);
  - 6 spark streaks;
  - a 40 ms white pop.
- **Gone in about 0.11 s**: particle lives 0.04-0.14 s, the tongues 0.07-0.11 s.
- Brightness 1.6 (under Bloom). `LightEmission` 0.45: the full additive glow washed out to white against the sky.
- ×1.4 on a head kill; grows with range up to ×2.
- **Placement:** it bursts out of the top of the head (0.8 studs up, 0.6 toward the camera). Centred on the head it was hidden: the head's own flash covered it in two captures, most likely because a Highlight's fill draws over particles in front of its body.
- **Captures:**
  - 14 studs: angular yellow-orange flash tongues burst from the top of the orange-flashed head.
  - 57 studs: a bright flash burst at the head that reads clearly.

**Studio note:** in one play session no BillboardGui rendered at all, not even a plain test frame. A fresh session drew them again, and the slash capture above comes from that session.

**Re-grade**
| Item | Grade | Evidence / what holds it back |
|---|---|---|
| Headshot flash pop (muzzle-flash style) | **8.5** | Matches the muzzle-flash art, short and punchy, reads at 14 and 57 studs. The owner's taste call in the morning; only frozen frames looked at |
| Slash (toned down) | **8.5** | Half the size, see-through, rate-limited (measured); still readable on a white flash. Needs the owner's eye ("obnoxious" is a feel call) |
| Everything else | unchanged | §5 |

## 10. Default crosshair (2026-11-13 morning)
**Owner:** "the default crosshair could be a bit improved" (customisation comes later). Sounds are his job (he'll buy a pack); not touched.

### Research
- **RIVALS' crosshair settings screen** (video `q97rS_Z66Lk`, 7:00-7:30, read frame by frame):
  - **Global:** Scale; Rotation (the screen recommends 0 or 45); a Static toggle; Show While Aiming; Show While Inspecting; Override Specials.
  - **Bars:** colour, spacing, length 6, thickness 2, transparency, shape (Sharp), and each side on or off.
  - **Dot:** colour, thickness, shape (Round).
  - **Extras:** a circle, and an outline.
- **Our [Rivals PC UI](../../03%20Research/UI%20References/Rivals%20PC%20UI.md) note:** the default is white ticks with a gap around a centre dot.
- **[Valorant UI](../../03%20Research/UI%20References/Valorant%20UI.md) note:** tiny, white, user-set.
- **Valorant defaults, from general knowledge (not measured here):**
  - inner lines 6 long × 2 thick, 3 px offset, with a 1 px outline;
  - movement and firing error on;
  - pros mostly switch to a small static plus, often cyan or green.
- **LihFolk** (no crosshair spec in the vault; through `lihfolk-lookup`):
  - the gap should show the real spread cone (*Gun Feel - Recoil, Spread, Bloom*);
  - a CanvasGroup renders to a texture and can blur thin lines (*CanvasGroup*);
  - add a dark stroke on busy backgrounds (*Accessibility Contrast*);
  - lightness is the channel every kind of colour vision keeps (*Colour-Blind Safe Design*).

### Before
- A CanvasGroup (it can blur), centred at a fractional pixel on odd-sized screens.
- 8×2 lines, a 2 px dot, a 1 px outline at 50% transparency.
- Fixed pixel sizes: no screen scaling.
- The gap eased at 18/s.
- No link to the hit markers: a different outline colour and a different centre.

### Built
- **`Config/Crosshair.luau`**: its fields mirror RIVALS' options (scale, rotation, static, show while aiming, bars with per-side toggles, dot, outline), so a settings screen can write a per-player copy.
- **`Util/Crosshair.luau`** (`apply(config)` for the later customisation): built from plain Frames, not a CanvasGroup.
- **HudController** now just calls it; its old crosshair code is gone.
- **Default:**
  - White 6×2 bars with 4 px spacing and a 2 px dot.
  - A 1 px outline at 30% transparency in the hit markers' near-black `06080C`, with square (mitred) corners.
  - Sizes scale with screen height (×0.9 to ×1.5).
  - Every size and position lands on whole pixels: even widths and lengths, and the centre snapped to a whole pixel.
  - The bars' inner ends sit on the gun's real spread cone (+ spacing), eased at 22/s, capped at 70 px.
  - Hidden while aiming or sprinting, as before.
- **One system with the hit markers:**
  - the X snaps to the same whole-pixel centre;
  - the X uses the crosshair's scale limits, so the two keep their proportions on a phone;
  - it shares the crosshair's outline colour.
  - The X's arms sit on the diagonals, so they never cover the bars.

### Checked in Studio (match place, test range, Vandal, viewport 2179×964)
- **Whole pixels:** all 5 frames sit on whole-pixel positions (6×2 bars, 2×2 dot).
  - The first run showed 5 px bars landing on half pixels. Fixed with even lengths and re-checked.
- **Spread response** (the inner end of the right bar):

  | Situation | Gap |
  |---|---|
  | Standing | 6 px |
  | Walking (15 studs/s) | up to 14 px |
  | Spraying 1 s | up to 13-14 px, closing again after |
  | In the air | up to 35 px |

  It eases back each time.
- **Contrast**, measured on the captures (downscaled JPEG, so the 1 px outline reads softer than on screen):

  | Background | Bar vs background | Outline vs background | Bar vs outline |
  |---|---|---|---|
  | Grey concrete (bright range) | 3.1:1 | 3.2:1 | 9.7:1 |
  | Night lighting (client-only) | **21:1** | n/a | 21:1 |
  | Pure white neon wall (worst bright case) | n/a | **6.4:1** | 6.4:1 |

  On pure white the shape reads from its outline alone.
  - Every case passes 4.5:1 on at least one edge.
  - The bar-to-outline edge is ≥ 6.4:1 everywhere, so the shape holds on any surface.
- **With a hit:** the X and the plus share one centre and one style; together they read as a small eight-point burst.
- **Phone size:** this viewport already runs at the 0.9 scale floor, the same scale a 375-430 pt-tall phone gets. So the captures show the exact phone sizes in points: 6×2 bars, a 2 pt dot, 4 pt spacing.
  - That is about 1.6% of the screen height on a phone, against 0.56% at 1080p, so phones get a relatively bigger crosshair.
  - On 2-3× phone screens, points are whole device pixels, so it stays crisp.
- `selene src`, `stylua --check` on my files and `rojo build` are clean. Studio is back in Edit with `TestMode = true` and no Dev attributes.

### Grade
| Item | Grade | Evidence / what holds it back |
|---|---|---|
| Default crosshair | **8.5** | Crisp (measured whole pixels), honest spread response (measured 6 → 14 / 35 px), readable on night, grey and pure white (measured contrast), one system with the hit X, fully data-driven. Holding it back: the owner's taste (white vs a colour, dot or no dot), not seen on a real phone, and `showWhileAiming` / per-player configs exist in data but nothing writes them yet (the customisation screen) |

### Not verified
- A real phone or the Studio device emulator (the MCP can't resize the viewport). Phone sizes are from the scale floor, which this viewport already uses.
- A real dark map; the dark case was client-only night lighting on the range.
- The knife or other guns' spread (only the Vandal was checked).
- How it looks to the owner's eye in motion.

### What to test (owner)
1. Walk, jump and spray on the range: does the gap's movement feel right, or would you rather have a static default?
2. White, or a colour (cyan or green, like many pros)? Dot or no dot? Edit `Config/Crosshair DEFAULT`.
3. Hit a dummy: do the X and the crosshair read as one thing?

## 11. Owner's second look (2026-11-13, after playing)
**Feedback** (relayed by the coordinating session). He likes the direction: "it's looking really good, it's all looking a lot better". His RIVALS screenshots are in [References/hitfx](../../02%20Art/References/hitfx/):
- **Markers:** "on a regular hit it'll kind of be like a white part of the crosshair that comes in and hits, and then it's red for a headshot". The white indent is liked. The red/white headshot X is "a bit too much... it's like a red outline. It should just be red, and more subtle." And on a kill: "you won't get any extra crosshair on a kill".
- **Flash:** "I kind of want the flashing just to look better". The references show a body hit as a solid white body with a thin red rim, and a headshot as a solid red body.
- **Headshot flash:** still "too much like real fire. It should just be like a regular flash, like the Valorant one". His RIVALS shot shows bright radial streaks behind the head.
- **Slashes:** "they don't follow the player, which I don't really like".

**Research**
- The owner's three RIVALS screenshots (above).
- **Valorant:** no usable close-up video turned up in a search. Two useful facts from coverage of its patches:
  - its hit effects move with the spot on the body you hit, not hanging in space;
  - its headshot effect was made smaller so players can keep tracking the target.

  Both are applied below.

**Changes** (numbers in `Config/HitFx`)
- **Markers:** four small **wedges** on the diagonals, tips pointing at the centre.
  - They **slide in** from 2.4× their rest gap and "hit" (ease-out-back).
  - **White on the body, plain red `FF3B3B` on a headshot**, same size; no white core, no slash.
  - **Kill:** bigger red wedges plus a red ring burst, drawn over the hit marker.
  - Each wedge has a dark backing wedge so a white wedge reads on a white-flashed body; the baked edge alone was under half a pixel.
  - The wedge is a new texture (`tools/vfx/make_hit_vfx.py` → `art-source/vfx/hit/marker_wedge.png`, tinted per hit).
- **Flash:**
  - **Body hit:** solid white (fill 0) with a **thin red rim**, holding 0.06 s, gone by 0.18 s.
  - **Headshot:** one white frame, then **solid red** (fill 0.04), gone by 0.26 s.
  - **Kill:** solid deep red for 0.4 s, carried onto the falling copy as before.
  - Each limb mesh draws its own rim, so thin red lines show where the limbs meet the torso, like a cel outline. The RIVALS shot shows a little of this too.
- **Headshot flash:** a **radial streak burst** (new texture `head_flash.png`: 12 tapered streaks, white core to warm yellow to orange rim) drawn just behind the head, so the red head sits in front of its centre. Plus 5 sparks.
  - Gone in about 0.13 s; ×1.3 on a head kill; grows with range.
  - The muzzle-flash pop and every flame sheet are gone.
  - The textures are preloaded: without that, the first headshot of a session showed nothing while the image downloaded.
- **Slashes follow the body:** the slash rides on the body part it hit (an attachment on that part, re-pulled toward the camera every frame). Its gui lives in the effects folder and gets a new attachment if the part is destroyed.

**Measured / captured in Studio** (match place, Vandal; frozen with `VfxTimeScale`):
- **Body hit:** the whole dummy is solid white with a thin red rim; the numbers are fill 0.00 and outline `FF2E3D` at 0.00. This matches the reference.
- **Headshot:** a solid red body, the radial burst fanning out behind the head, red wedges and a red 29. This matches the reference.
- **Marker on white:** with the dark backing, the white wedges read as dark-edged indents on the white flash.
- **Head kill:** big red wedges and a red ring around the crosshair, plus the burst.
- **Slash follow:** on the strafing dummy the slash rode `RightLowerArm`. It moved up to 2.28 studs with the body, with **0.000** drift from its spot on the part.
- **Not captured:** the slash in this session's frames. Studio drew no BillboardGui at all in one session (not even a plain test frame), as happened once before. The slash was enabled, sized and placed correctly by the numbers, and it rendered in earlier sessions.
- **Rojo was down** (nothing on port 34872). I copied my files into Studio by hand, byte-for-byte equal to disk (sizes and checksums compared). I also started `rojo serve` again; the Rojo plugin in Studio needs a **Connect** click to pick it up.

**Re-grade**
| Item | Grade | Evidence / what holds it back |
|---|---|---|
| Body flash (white with red rim) | **9** | Matches the RIVALS reference in a capture; measured fill and rim values |
| Headshot flash (solid red) | **9** | Matches the reference in a capture |
| Headshot burst behind the head | **8.5** | Matches the reference's idea; a best-effort procedural texture until the ChatGPT render below |
| Crosshair markers (wedges in, white / red, kill ring) | **8.5** | Captures of body, head and kill; the owner's taste on size and backing darkness |
| Slash following the body | **8.5** | Follow measured (0 drift on a moving arm); not seen in this session's captures (the Studio billboard glitch) |

**ChatGPT prompt for the headshot burst** (the owner offered: "we could have ChatGPT render something, just ask me"):

**ChatGPT image prompt for the headshot flash** (for the owner to run; then drop the PNG in `art-source/vfx/hit/` and I'll swap it in):

> A single stylised "headshot hit flash" VFX sprite for a cartoony-competitive shooter in the style of Valorant: a quick burst of 10-14 sharp, tapered light streaks radiating out from a small white-hot centre, like a camera flash or impact star. The streaks vary in length (alternating long and short) and are slightly uneven, not perfectly symmetrical. Colours: pure white core fading to pale warm yellow (#FFE9A8) and a thin warm orange rim (#FF9A3C) on each streak's edges. Clean vector-like shapes with crisp edges and only a very soft, small glow around the centre; no smoke, no fire, no flames, no sparks or particles, no text. Centred, filling about 90% of the frame, on a fully transparent background (PNG with alpha), 1024×1024, flat 2D, front view, no perspective, no shadow.

Optional second image for variety: the same, but with 8 streaks and a slight fan upward (more of the burst above the centre than below), like the RIVALS reference.

## 12. Owner's third look: a subtler flash (2026-11-13)
**Feedback:** "the flash is a bit too prominent. It should be more subtle... It's just kind of that like background kind of effect that just like adds to like the nice feeling of gunplay, but it's not actually like that apparent." Keep white-to-red and the redder head.

**Change** (`Config/HitFx FLASH`; markers, kill marker, slash and head burst from §11 unchanged):
- **Peaks:** see-through (fill about 0.6) instead of solid; the rim is half see-through.
- **Timing:** holds of 20-30 ms (was 60-80) and a quicker fade.
- **Body:** white, easing to a light red.
- **Head:** red.
- **Kill:** stays the strongest (fill 0.46, 0.24 s).

**Measured in Studio** (every rendered frame, Vandal on a dummy):

| Hit | Peak fill (0 = solid) | Peak rim | Visible | Colours |
|---|---|---|---|---|
| Body, before | 0.00 | 0.00 | 164 ms | solid white |
| **Body, after** | **0.62** | **0.55** | **99 ms** | white → light red `FF6A6A` |
| Head, before | 0.00 | 0.20 | 251 ms | white → solid red |
| **Head, after** | **0.59** | **0.60** | **148 ms** | white → red `FF3535` |

**Captures** (frozen at the peak):
- Body: a light whitening with a faint red rim; the dummy's own colours show through.
- Head: a red tint over the body with the burst behind the head.

Both read as an accent on the hit, not a silhouette.

**Grade:** the flash stays **9** on fit to the brief ("felt more than seen", measured 40% opacity at most and gone in about 0.1-0.15 s). It's the owner's call whether this is now too quiet; one number to raise is `FLASH.*.whiteFill` / `fill`.

## 13. Round 4: slash, kill marker, head flash (2026-11-13)
**Feedback** (owner, after playing; full text in the handoff note under "Round 4"):
- **Slash:** "still looks a bit off".
- **Kill:** "there shouldn't be like a thing on the crosshair when you get a kill".
- **Head flash:** "looks really off. It should be low... more subtle, and there should be like a fun, more animation".
- **Overall:** "a little more improvement on these things".

**1. Slash: dropped.**
- Why: in his RIVALS reference shots a body hit carries no slash at all; the body flash and the crosshair marker carry it. Valorant shows only a small neutral puff at the hit point.
- We already draw that puff (`Util/ImpactFx`), and each retune of the slash came back "off". It was decoration over a hit that now reads cleanly without it.
- `Config/HitFx SLASH.enabled = false`; true brings it back, and all its code and numbers are kept.
- **Before:** the §11 capture, a thin red/white streak on the body.
- **After:** nothing beyond the flash and the marker. Measured: zero slash billboards shown through a whole kill.

**2. Kill marker: removed.**
- `HitFx.KILL_MARKER = false`. A kill now shows the normal hit marker only: the white or red wedges.
- Measured through a full kill: hit marker shown, kill marker never shown, ring never shown.
- True brings back the bigger red wedges and the ring.

**3. Head flash: smaller, lower, see-through, and animated.**

| | Before (§11) | After |
|---|---|---|
| Size | 1.2 → 3.1 studs, a big star behind the head | **0.3 → 2.2 (snap) → 1.8 (settle) → 0 (retract)** |
| Opacity | solid (transparency 0-0.05) | **0.3-0.35** |
| Motion | a static sprite that grows and fades | **snaps out with a 22% overshoot in 30 ms, settles, spins 260-380 °/s (random direction), retracts into the head** |
| Place | behind the head's centre, 1.2 studs back | **0.15 studs below the centre, 0.5 back: the streak tips peek out round the head** |
| Brightness | 1.6 | 1.3 |
| Life | 0.11-0.14 s | 0.16-0.19 s |
| Sparks | 5 | 3, smaller |
| Kill and range scaling | ×1.3 on a kill, up to ×2 at range | ×1.15 on a kill, up to ×1.6 at range |

**Captures** (frozen with `VfxTimeScale`):
- **Snap-out:** thin yellow streaks around the head.
- **Settle:** the burst turned a few degrees (the spin), tips peeking out, partly see-through.

The retract ends inside the head, so the burst seems to pop out of the head and suck back in.

An honest finding along the way: the first settle size (1.3 studs) matched the head and hid behind it mid-animation, so I raised it to 1.8.

**Not verified:**
- The motion by eye at full speed: every look was a frozen frame. The spin and snap are configured and their numbers checked, but whether they read as "fun" is the owner's call.
- The ChatGPT burst image (§11 prompt) is still pending. The procedural texture is used meanwhile.

**Grades**
| Item | Grade | Evidence |
|---|---|---|
| Slash | dropped (n/a) | Matches both references; switch kept |
| Kill marker | done (9) | Measured: a kill shows the hit marker only |
| Head flash | **8** | Much smaller and subtler, animated (snap, spin, retract), captured at two moments. Held back by: not judged in motion by eye, and a placeholder texture |
| Body flash (§12), markers (§11) | unchanged | |

**Studio:** Rojo still isn't connected, so I copied my three changed files in by hand. All three match disk byte for byte (size and checksum), and lint, format and build are clean:

| File | Size/checksum |
|---|---|
| `Config/HitFx` | 11900/926814458 |
| `Util/HitFx` | 15832/823822721 |
| `Util/HitFeedback` | 18788/478298653 |

- Another session has changed `EffectsController` on disk; I didn't touch it or copy it.
- Studio is left in Edit with `TestMode = true`.

## 14. The owner's ChatGPT headshot flare (2026-11-13)
**From the owner:** "I am having chat gpt make head hit markers for the head similar to our other ones."
- **Sheet:** `art-source/vfx/hit/HeadshotFlare_chatgpt.png`, 1254², 2×2 on black, no alpha.
- **ChatGPT's own reading, which settled how to use it** (relayed by the owner after one round of "separate layers"): "Play the four frames left to right, top row first. The impact flashes, the flame shoots upward, then breaks apart and fades into embers."

**Processing** (`tools/vfx/make_hit_vfx.py` `flare_flipbook`, output `head_flare_2x2.png`, 1024², 512 px cells):
- Each frame is keyed to alpha by un-premultiplying (alpha = brightest channel above a 10/255 noise floor ×1.15; colour = rgb / alpha). No black fringe on a mid-tone check.
- The frames weren't drawn centred, so **each frame's base point** (the bottom-centre of what it draws) **is moved onto one anchor** (256, 440) at one shared scale, so the sequence doesn't jump.
- Measured bases in the source cells: (304, 500), (332, 496), (310, 357), (323, 275).
- Uploaded as decal `80426787467983`, image `120765867865312`. The first, unaligned upload is unused.

**In game** (`Config/HitFx HEAD_FLASH`; `TEXTURES.headFlare` is the **one id to swap** for a new version):
- **Why not a particle flipbook:** it can't cross-fade or re-anchor frames. So the flare is a **small billboard riding the head** (it follows the target), with **one image layer per frame** cut from the sheet.
- The frames **cross-fade** on Config windows over 0.32 s. Each fades in, holds, and fades out under the next:

  | Frame | Window |
  |---|---|
  | Impact flash | 0-0.09 s |
  | Flame shooting up | 0.04-0.19 s |
  | Breaking apart | 0.14-0.27 s |
  | Embers | 0.21-0.32 s |

- It snaps in with an overshoot (1.1 → 1.85 → 1.6 studs) and is 20% see-through at most.
- The shared base sits on top of the head (0.45 studs above its centre).
- 3 sparks; ×1.15 on a head kill; up to ×1.6 at range.

**Checked in Studio** (frozen with `VfxTimeScale`):
- At 0.06 s: the impact-flash and flame layers are mid cross-fade (transparency 0.43 / 0.60). The capture shows a small see-through flame shooting up from the top of the dummy's red head.
- At 0.19 s: only the "breaks apart" layer is on (0.20), a small wisp on the head.
- The billboard rides `Head`.
- The image's preload reported "Failure" (most likely moderation on a fresh upload), but it rendered in both captures.

**Not verified:**
- The motion at full speed by eye.
- The embers frame captured on its own.
- At about 14 studs it's very small and faint, which is round 4's direction but may need `HEAD_FLASH.size` or `alpha` raised if the owner can't see it.

**Grade: 8.5.** It uses the owner's art as its author described, aligned and cross-faded, small and on the head. It's held back by the full-speed and taste checks only he can do.

**Studio and files:**
- Rojo was syncing again this round. Studio matches disk byte for byte:

  | File | Size/checksum |
  |---|---|
  | `Config/HitFx` | 12774/631859804 |
  | `Util/HitFx` | 18035/326692117 |
  | `Util/HitFeedback` | 18788/478298653 |

- Lint, format and build are clean, and Studio is left in Edit with `TestMode = true`.

## 15. Bullet-impact sounds hooked up (2026-11-13, for the audio lane)
**The ask:** the audio lane built `Config/Sounds IMPACTS` (Hard / Metal / Glass / Wood / Soft, gun atlas v4) and asked for a hook in `Util/ImpactFx`.

**The hook:** `ImpactFx.impact` plays `Sounds.IMPACTS[kind]` for the surface it picked.
- Played 3D at the hit point in the "Enemy" group.
- **World impacts only:** bodies keep the hit sounds, and the knife's `noHole` path is skipped (it has its own wall sounds).
- **Throttle:** at most one every 30 ms, so shotgun pellets don't stack.
- **Numbers** in `Config/HitFx IMPACT_SOUND`: volume 0.5, range 60, minGap 0.03.

**Checked in Studio:** a shot at the concrete floor started a 3D voice about 9 studs away (the hit point) at atlas time 199.01. That's inside `impact_hard` take 1 (198.993 + 0.14 s).
- Not judged by ear: the sound is the audio lane's and the owner's call.
- Lint, format and build are clean.
- Studio matches disk: ImpactFx 11969 bytes, Config/HitFx 13071.

## 16. The flare, made loud (2026-11-13)
**Owner, after seeing §14 in game:** "The flare effect is just dull and boring. please fix". I had tuned round 4's "subtle / low" into timid. The fix: keep it **short and small, but loud while it lasts**. Short is what keeps it subtle, not faint.

**Changes** (`Config/HitFx HEAD_FLASH`, `Util/HitFx`):
- **Glow:** every frame peaks at **full colour** (was 20% see-through), and the billboard brightness is 2.4 with `LightInfluence` 0, over the place's Bloom (2), so it glows.
- **Hit frame:** a hard **white pop** drawn in front of the head (70 ms) and an **orange shockwave ring** (1 → 3.8 studs in 0.17 s), both additive particles.
- **Snap:** width 0.6 → 3.2 studs in 50 ms, back to 2.35, a small bounce to 2.6, settles at 2.5.
- **Motion:** the flame rises 0.9 studs off the head (ease-out), stretches up to 1.4× tall while it shoots up, turns 8-16° and drifts 0.25 studs to one side.
- **Bits:** 8 spark streaks (26-46 studs/s, gravity 70, spread 115°) and 6 embers (gravity 28) fly out.
- **Variety per hit:** size ±14%, lean ±9°, flick side, and a left-right mirror on half the hits.
- **Distance:** size × dist/18, capped at 0.75× up close and 2.4× far.
- **Timing:** 0.3 s in all (frame windows tightened).

**Measured at full speed** (60 fps, every rendered frame, 24 studs):

| Time | Width × height (studs) | Up (studs) | Turn | What shows |
|---|---|---|---|---|
| 0 ms | 0.64 | 0.53 | -6° | — |
| 13 ms | **2.88** | 1.49 | | frame 1 at full colour (the snap) |
| 49 ms | 2.31 × 2.59 | | | frames 1 → 2 cross-fading |
| 97 ms | 2.47 × 3.33 | 2.15 | | the flame, stretched |
| 130 ms | 2.46 × **3.44** | | | peak stretch |
| 161 ms | | 2.43 | -18° | frame 3 |
| 229 ms | | | -20° | frame 4 (embers) |
| 278 ms | | | | fading out |

- The flare's screen position rose 47 px over the first 160 ms.
- A frame-by-frame screen video wasn't possible with the MCP (captures are single frames), so the motion is shown by the numbers above and by frozen captures at key moments.

**Captures:**
- **Hit frame:** a white-hot head, an orange ring round it, the red wedges.
- **~80 ms:** a bright yellow-white flame tongue rising off the head inside the expanding ring.
- **14 studs** (near cap): flame and ring clear.
- **51 studs:** the flare is 78×95 px on screen, a clear flame over the far dummy's head.

**Side by side with RIVALS:** [2026-11-13 headshot flare vs RIVALS.png](2026-11-13%20headshot%20flare%20vs%20RIVALS.png).
- RIVALS fills a **wide fan** of bright streaks above the head; ours is a **single tall flame** with a ring.
- After the comparison I made it 30% bigger, but it's still narrower than RIVALS. That's the art's shape: one flame tongue, about a third of its frame's width.
- If the owner wants the RIVALS fan, the next ChatGPT version should be a wider burst, or two mirrored copies of the flame can be fanned out (about 10 lines of code).

**Grade: 8.** Vivid, punchy and moving now, readable from 14 to 51 studs. Held back by:
- narrower than the RIVALS reference;
- not judged as video at full speed by eye.

**Checks:**
- Rojo was syncing, and Studio matches disk byte for byte: `Config/HitFx` 14685/339500468, `Util/HitFx` 21124/848057726.
- Lint, format and build are clean.
- Studio is left in Edit with `TestMode = true`.
- The long white lines in some frozen captures are the range dummies' tracers piling up while time is frozen, not part of this effect.

## 17. The flare fanned out (2026-11-13)
**Owner:** "We can try to fan it out." This is the RIVALS-style fan offered in §16.

**Change** (`Config/HitFx HEAD_FLASH.fan`, `Util/HitFx`):
- **Copies:** the flare is now `count` 3 flame copies: the centre flame (randomly mirrored) plus side copies at ±30° (±5° per hit).
- **Sides:** each side copy is mirrored to lean outward, at 80% of the centre's size, and starts 25 ms (1.5 frames) later.
- **One pivot:** a GUI rotates around its own centre, so each copy is shifted to pivot on the flame's base instead. All three splay from one point on top of the head.
- **Kept:** the white pop, the ring, the sparks and embers, and the per-hit variety (size, lean, flick side).
- **Wider:** `fan.count = 5` adds a further pair at ±60° and 64% size.

**Checked in Studio** (frozen at about 90 ms):

| Distance | What it looks like |
|---|---|
| 13 studs | three flames at 4° / -30° / 31° (1.7-2.1 studs wide) fanning out of the top of the red head, inside the orange ring |
| 25 studs | tallest flame 99 px. In this shot the range's "10" lane sign stood right behind the head and covered part of the fan: the flare is depth-tested, which is correct, but a bad capture |
| 51 studs | tallest flame 87 px; the fan reads clearly over the far dummy's head |

**Side by side with RIVALS:** [2026-11-13 headshot fan vs RIVALS.png](2026-11-13%20headshot%20fan%20vs%20RIVALS.png).
- It now reads as a fan bursting out of the head, which it didn't before.
- RIVALS still has more streaks (about 6-8, out to about ±60°), and they're paler, white-hot light streaks rather than flame shapes.
- Closer would be `count = 5`, and a whiter, more streak-like ChatGPT render.

**Grade: 8.5** (from 8). Not 9 because:
- it's still narrower and more "flame" than the reference's light burst;
- it hasn't been judged in motion by eye.

**Checks:**
- Studio matches disk byte for byte: `Config/HitFx` 15204/879322155, `Util/HitFx` 22950/214390132.
- Selene is clean on all my files: Config/HitFx, Config/Crosshair, Util/HitFx, HitFeedback, ImpactFx and Crosshair. Run over the whole of `src`, it currently shows 1 warning in `EffectsController.luau` (an unused `Audio`, from the sounds session's edit in progress; a moment earlier there was also an undefined `GunAudio`). Not my lines, so I left them.
- Format and build are clean.
- Studio is left in Edit with `TestMode = true`.
