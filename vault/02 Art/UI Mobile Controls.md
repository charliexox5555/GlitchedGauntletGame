# Mobile controls: concept (2026-11-22)

**Status (2026-11-25):** built and on the owner's phone; the stick and button pass is [below](#stick-and-button-pass-2026-11-25) (fixed stick base, analog speed, hit slop). Waiting on the owner's next phone test.
**Owner brief (2026-11-22):** custom, good-looking touch UI with icons, similar to RIVALS (custom jump button and everything), changed where our game needs it. **On mobile, ADS and sprint are always toggles** (no hold option).

Read first: [Rivals Mobile UI](../03%20Research/UI%20References/Rivals%20Mobile%20UI.md) (video study + the 2026-11-22 Studio read of their editor), [UI Theme v4 Soft Edge](UI%20Theme%20v4%20Soft%20Edge.md) §6-7, [UI Architecture](../04%20Tech/UI%20Architecture.md) (layers, Touch layer), LihFolk *Mobile Button Layout Editor*, *Touch Gestures*, *Input - UserInputService and ContextActionService*.

## 1. What we have now
- `HudController:296-346` makes text circles FIRE, AIM, R, SLIDE, SWAP, RUN. `ModHudController:538-580` adds the Mod arc. Jump and the stick are Roblox's own.
- No icons, no editor, no left-handed mode, no tablet sizes.

## 2. Controls (our inputs from `Config/Input`)
| Control | Type | Default size (% of screen height) | Notes |
|---|---|---|---|
| Move stick | **floating**, appears where the left thumb lands in the left zone (x 0-40%, y 35-100%) | ring 24, nub 10 | our art (ring + nub). Pushing past the ring **locks sprint** (optional, §6 Q2) |
| Fire | hold | 21 | gold-tinted ring (the one act-now thing). Optional second FIRE on the left, and double-tap on the right half (settings) |
| Jump | tap | 22 | our button, Roblox's jump button removed |
| Aim (ADS) | **toggle always** | 17 | ring fills gold while aimed |
| Slide / crouch | tap | 17 | slide when moving fast, crouch otherwise (our slide input is C) |
| Sprint | **toggle always** | 13 | lit ring while on; also turned on by the stick lock |
| Reload | tap | 12 | ring shows reload progress |
| Mod 1-3 | tap | 14 each | arc above Fire; cooldown ring + charge pips, the same medallions as the PC HUD |
| Weapon slots (Primary, Secondary, Melee) | tap | 12 each | top-right row with the gun's picture, equipped = gold edge |
| Quick melee | tap | 9 | under the melee slot |
| Scoreboard, emote, settings | tap | 10 | small row top-left, under the Roblox buttons |

Camera: drag anywhere that isn't a button (right half mostly). Sizes are RIVALS-like (their phone sizes at 390 px height: shoot 18%, jump 21%, aim 18%, reload 13%, small 10%) and meet Soft Edge §7 (primary ≥ 13%, secondary ≥ 44 px, gaps ≥ 8 px).

## 3. Default layout (phone, landscape)
```
 ┌───────────────────────────────────────────────────────────────────────┐
 │[Roblox][≡]  (score)(emote)(⚙)        SCOREBUG + TIMER       [PRI][SEC][MEL]│
 │                                                               (qm)     │
 │ kill feed on a fade                                                    │
 │ (left-centre)                    + crosshair          (M3)             │
 │                                                    (M2)      ( AIM )   │
 │   (SPRINT)                                      (M1)   ( FIRE )        │
 │                                                  (R)                   │
 │      [ floating stick zone ]                           (SLIDE) ( JUMP )│
 │ HP ▬▬▬▬▬                                                   ammo 24/96  │
 └───────────────────────────────────────────────────────────────────────┘
```
**After the owner's real-phone RIVALS captures (2026-11-22, [Rivals Mobile UI → Owner's phone captures](../03%20Research/UI%20References/Rivals%20Mobile%20UI.md)):**
- The sizes hold: their Jump 19%, Aim / Fire / Crouch 17%, Reload 12%, slots 10%. Ours (Jump 22, Fire 21, Aim / Slide 17, Reload 12) is a little bigger on the two we press most.
- The scorebug and our round settings button move **into the top-bar row** next to Roblox's buttons, so more of the screen is free.
- Ammo sits on the equipped weapon slot (mag big, reserve small), with the big bottom-right ammo readout kept for desktop only.
- In the lobby the Jump and Slide buttons stay, faded.
- One message slot at top-centre (no toast stacked over the banner), and a smaller killed-by card than theirs so the gun stays visible.

Tablet: the same layout; sizes are in screen-height units, so it scales by itself. The editor saves positions as fractions, so a phone layout opens fine on an iPad.

## 4. Look (Soft Edge + owner taste)
- Circles: dark plate at 55% + 1.5 px hairline at 12% white. Pressed = solid accent fill + scale 0.94 (`UIScale`, Quad Out 0.08), no glow. Toggled on = gold ring + gold icon.
- **Icons: our own set**, one style: white glyphs, flat, chunky strokes with cut ends (no round caps), slight forward slant on motion icons, no outlines, no 3D. Fire = burst/cartridge, Aim = scope reticle, Jump = up chevron, Slide = sliding figure, Sprint = running figure, Reload = cut-corner circular arrows, Scoreboard = bars, Emote = figure, Settings = cog. Drawn as vectors (SVG → 256 px PNG, uploaded), so they stay crisp and editable.
- No text labels on buttons, except the Mod key chip on PC.
- Ammo inside the Fire ring as a thin arc (empty = red tick); Reload pulses once when the mag is empty.

## 5. Layout editor (from day one)
- Opened from Settings → Touch, and from the small cog row in the lobby. Bar on top: Done, Reset, profiles 1 / 2 / 3, left-handed mirror, global opacity.
- Tap a button: drag to move, corner handle to resize (75-150%), per-button opacity, hide (Fire and Jump can't be hidden).
- **Saved as fractions of the safe area + size as a fraction of the screen height**, per profile, in `PlayerDataV1.settings.touch`. The server validates it (types, finite, clamped 0-1, sizes in range, known button ids, rate-limited). RIVALS saves raw pixels, which breaks when you switch devices.
- Overlap check on save: buttons can't cover each other or the Roblox top-bar rectangle.

### Build plan v1 (owner 2026-11-22: "Touch Layout Editor ... change up controls settings for mobile", with RIVALS Touch-tab screenshots)

**Settings → TOUCH tab:**
- **Layout:** LAYOUT EDITOR (opens the editor), LEFT-HANDED, BUTTON OPACITY, CAMERA THROUGH BUTTONS, SHOW AMMO.
- **Attack:** DOUBLE TAP TO FIRE plus its window.
- **One section per button group:** Fire, Aim, Jump, Slide, Reload, Sprint, Abilities, Weapon slots, Quick melee, Scoreboard, Inspect.
  - Each section has ENABLED (Fire and Jump can't be hidden) and CUSTOM, which gives that group its own OPACITY.
- **Source:** all rows come from `Config/TouchControls` and `Config/Settings`.

**Saved data:**
- `touchProfile` (1-3) and `touchLayout1..3` hold `{ [object] = { x, y, s } }`.
  - `x` and `y` are the centre as a fraction of the touch root, in the right-handed frame.
  - `s` is a size multiplier from 0.6 to 1.6.
- `Shared/PlayerSettings` cleans them on both sides: only known object ids, finite numbers, clamped.
- No entry means the default spot, so RESET just clears the profile.

**`Shared/TouchLayout`:**
- It owns the geometry that used to live in `TouchController.layout` (cluster sizes, the row under Roblox's bar).
- It then applies the saved layout on top: the left-handed mirror, custom spots and sizes, hidden groups (kept hidden even when HUD code shows them), and opacity.
- The match HUD and the editor use the same module.

**Editor (`UI.Lobby.TouchEditor`, Studio-built bar, `lobby/client/Util/TouchEditor`):**
- It previews a copy of `UI.Match.Touch` with every button showing.
- Tap a button to select it, drag to move it, use −/+ for size, HIDE for its group.
- The bar also has profiles 1/2/3, RESET, CANCEL and DONE.
- DONE saves through Settings.

**Controller:** BottomHud key chips already show pad glyphs (`Shared/InputGlyphs`). This round adds a SWITCH (Y) hint and a Studio `ForceInput` switch so glyphs can be tested without a pad.

**Not in v1:** these rows exist but do nothing yet; they come with the "functionality for all settings" pass.
- Double tap to fire.
- Camera through buttons.

### Build v1 results (2026-11-22, phone emulator)
**Tested live:**
- The TOUCH tab works on phones, with INSPECT beside the list.
- EDIT opens the editor. The lobby HUD steps aside, and the preview shows the saved layout.
- Dragging moves a button 1:1. The size buttons step by 10%, and HIDE fades a hidden group to 25% in the editor.
- DONE saves through SettingsService; the published Settings value showed `touchLayout1 = { FireButton = {0.638, 0.519, 1.2} }` and `touchAimOn = false`.
- Backing out of Settings cancels the editor and restores the HUD.

**Checked on a copy of `UI.Match.Touch`:** the range entrance now says "opens in a later update", so the match HUD couldn't load in the lobby. `TouchLayout.refresh` with the saved settings put Fire at the saved spot and size, and hid Aim. Left-handed mirrors the stick zone, the button clusters and the health bar.

**Fixed while testing:**
- The bar plates are dark, the active profile white, DONE gold.
- `LobbyKit.button` wraps buttons in same-named holders (`Util/Pivot`); the editor now looks inside them.
- The settings gear is hidden in the preview.
- The wash reaches past the safe area.

**Test data reset:** my test layout was cleared from the owner's account again.

**Still to do:**
- Double tap to fire and camera-through-buttons (they save, but do nothing yet).
- Editing from inside a match (the match has no settings screen yet).
- A test on a real phone.

## 6. Owner questions
1. **Stick:** our own floating stick (full control of the look, recommended), or Roblox's dynamic thumbstick like RIVALS (hide its start marker, can't restyle much)?
2. **Sprint toggle:** a SPRINT button, a stick-push lock, or both (recommended: both; the lock can be turned off)?
3. **Slide and crouch:** one button (recommended) or two like RIVALS?
4. **Fire extras:** double-tap the right half to fire, and an optional left FIRE button, both off by default?
5. **Icons:** I draw the set as vectors in our style (recommended), or ChatGPT draws them from a prompt sheet?
6. **Weapon slots:** top-right row with gun pictures (RIVALS-like), or one SWAP button like now?

## Mockup v1 (2026-11-22; owner picked the recommended answers: own stick, sprint button + stick lock, one Slide button, double-tap / left FIRE off by default, icons drawn by Claude, weapon slots top-right)

**Where:** `StarterGui.TouchMockup`, parked for review (its `UiEditFrom` attribute is `Mockups`; `tools/studio/UiEdit.luau` with `ACTION = "store", NAME = "TouchMockup"` moves it to `StarterPlayerScripts.UI.Mockups`). Builder and backup: `tools/studio/BuildTouchMockup.luau` (`PREVIEW` = a device size, or nil for full screen). Lobby place, **not saved yet**.

![](References/ui/touch/touch-mockup-v1-844x390.jpg)
![](References/ui/touch/touch-mockup-v1-667x375.jpg)
![](References/ui/touch/touch-mockup-v1-1024x768.jpg)

**Icons** (`tools/ui/make_touch_icons.py` → `art-source/ui/touch/`, sheet `References/ui/touch/touch-icons-v1.png`): fire (a round in flight + motion dashes, gold), aim (16-sided reticle), jump (arrow over a ground bar), run (Sprint), slide (feet-first figure), reload (two faceted arrow bands), scoreboard, settings cog, melee knife, and the » chevrons (the stick's sprint-lock hint only). White, faceted, cut ends, tinted in Roblox. Uploaded as Decals; **use the Image ids** (`InsertService:LoadAsset(decal).Decal.Texture`), which are listed at the top of the builder.

**How it's built:**
- Four corner clusters are squares sized off the screen height (`SizeConstraint = RelativeYY`): right 0.8 H, left 0.8 H, weapons 0.5 H, top-left 0.6 H, scorebug 0.62 H. Inside them everything is Scale, so each cluster keeps its shape on every aspect ratio.
- Text is `TextScaled` + `UITextSizeConstraint` (min 12).
- Rest = dark plate at 55%. A toggle that's on = a solid light plate with a dark icon. Fire = gold icon (the one gold thing). A Mod on cooldown = a dark cover with the seconds.

**Measured (drawn px at the device size):**

| Device | Jump | Fire | Aim / Slide | Reload | Mod | Weapon slot | Quick melee | Ammo text |
|---|---|---|---|---|---|---|---|---|
| 667×375 (worst phone) | 83 | 77 | 64 | 44 | 52 | 43 | 41 | 16 |
| 1024×768 (iPad, tablet factor 0.78) | 132 | | | 70 | | | | |

The 43 / 41 px slots get the +20% invisible hit box (≈ 52 / 49 px). RIVALS' tablet jump is ≈ 137 px.

**Self-review fixes:**
- v1: the fire icon read as a rocket, so the side trails became motion dashes behind the round.
- v2: Sprint's » looked like the Dash Mod icon next to it, so Sprint is now a runner. The side-on guns overlapped, so they sit at −35° at 1.15× of the slot. Quick melee was 25 px, now 41. White on cyan/red scorebug plates didn't read, so the plates are dark with coloured numbers. The health number was dark on dark, now white.

**Tablet:** height-sized clusters get too big on 4:3, so tablets multiply every cluster side by **0.78** (`TabletFactor` attribute on the mockup; `PhoneSide` on each cluster).

**Placeholders, not designs:** the faint Roblox buttons top-left (real ones come from Roblox), the scorebug (the phone TopBar gets its own pass), and the health bar.

**Open for the owner:**
1. Is the equipped-slot look (a lighter plate) enough, or should it be bigger or edged?
2. Ammo on the slot only, or also a small count on the Fire ring?
3. Do the icons read? Is anything off-taste?
4. Sprint button placement (above-left of the stick).
5. Should NetStats (top-right in the top-bar row) move on phones, since the weapon slots sit there now?

## Mockup v2 (2026-11-22, after the owner's review: "looks good, I like it")
Owner notes:
1. More compact in the firing area (worried the Mods won't look good; will playtest).
2. Don't change the UI too much: the top bar with score and timer should stay similar.
3. The ammo count needs to look better.
4. Add an inspect button next to settings and scoreboard. Then: keep settings at the top, and put the other two under the Roblox buttons.

![](References/ui/touch/touch-mockup-v2-844x390.jpg)

Changes:
- **Firing cluster:** the three Mods sit on one arc round Fire (0.245 of the cluster from Fire's centre, at 196° / 244° / 292°). Reload, Slide and Aim moved in. The cluster now spans 0.21-0.96 of its width instead of 0.09-0.96, and its top is at 0.24 instead of 0.04. Every gap is at least 8 px at 390.
- **Top bar:** the **real match TopBar** (`UI.Match.TopBar.Root`), not a placeholder.
  - Phone fit = 11.5% of the height, capped so the bar clears Settings and the weapon slots: `min(0.115 H / 80, (W − 2 × (0.46 H + 8)) / barWidth)`. That gives 0.561 at 844×390 and 0.443 at 667×375 (2v2).
  - On phones the "ROUND n · tier" line under the clock is hidden, because it drew at 7.3 / 5.5 px. The clock centres. Scores draw at 28 px and the clock at 19 px. The round still shows in the round banner.
- **Ammo:** the desktop readout's look under the equipped slot (a big heavy count, a grey `/reserve`, a magazine bar on a dark plate). The other guns keep a small outlined count on their slot.
- **Settings row:** Settings sits beside Roblox's buttons in the top-bar row; Scoreboard and the new **Inspect** (a faceted magnifier with a glint) sit in a row under Roblox's buttons, like RIVALS. The real controller places Settings from `GuiService.TopbarInset`.
- Builder updated (`tools/studio/BuildTouchMockup.luau` rebuilds v2); inspect icon added to `make_touch_icons.py`.

**For the build:** the TopBar's phone fit rule and the hidden info line belong in `TopBarController`; the Settings position comes from `TopbarInset`; tablets keep the 0.78 factor.

## Build v1: the real touch controls (2026-11-22)
Owner: "yes go ahead"; health = "the simple bar like in the mockup" (the old panel didn't fit the theme).

**Studio:** `StarterPlayerScripts.UI.Match.Touch` (Layer `Touch`, off by default), built by `tools/studio/BuildTouchScreen.luau`.
- Mockup v2 layout with ImageButtons named after `Config/Input` touch names, each with a `Face` (plate) and a `Press` UIScale.
- `StickZone`, `Stick` / `Nub` / `SprintLock`, `StickRest`, and the simple `Health` bar (Fill, Shield line, Value).
- The mockup is stored in `UI.Mockups.TouchMockup`. StarterGui is empty.

**Code:**
- `client/Controllers/TouchController`:
  - our floating stick (`Player:Move`, camera-relative, dead zone 0.12)
  - sprint lock: past 1.25× the ring, straight ahead, for 0.25 s (timed per frame); pulling back unlocks it
  - Aim and Sprint as toggles (`InputAction:Fire`); Slide = a 0.25 s Crouch press while running, else a crouch toggle; Jump held
  - press motion on every button
  - hides in the Vote, Draft, Replay and MatchEnd phases
  - tablets × 0.78
  - Settings and the row placed from `GuiService.TopbarInset`
  - hides Roblox's stick and jump button (`TouchControlsEnabled`); the lobby host turns them back on when you leave an armed zone
- `client/Util/TouchHud`: touch on/off (a touch-first device or Studio `ForceTouchUI`), screen lookup, weapon slots (gun art, counts, the held one lit), the ammo readout under the held slot, and the health bar. Fed from `BottomHud.setLoadout / setAmmo / setHealth`.
- `ModHudController` adopts the screen's `Mod1-3Button` and `ModAltButton` (icon, cooldown seconds, held state) instead of drawing its own arc.
- `HudController`'s old text buttons (FIRE / AIM / R / SLIDE / SWAP / RUN) and `touchLayer()` are removed.
- `PhoneHudController` hides the old ammo and health panels and the Q / E / T faces when the touch screen is up.
- `Config/Input`:
  - new touch names: Primary / Secondary / Melee / QuickMelee / Inspect buttons
  - Aim, Sprint and Crouch have no touch name (they're toggles)
  - SwapButton removed (the slots replace it)

**Tested** (Lobby playtest, range, Studio `ForceTouchUI` + `ForceLayout = phone`, mouse as the finger):
- the screen comes up and Roblox's stick is hidden
- 10 actions link to their buttons
- the ammo readout shows `25 /∞`
- Aim toggles on and lights
- the stick moves the character forward and stops on release
- Slide while standing toggles crouch (MoveState Crouch)
- Sprint toggles
- Jump puts the character in the air
- leaving the range restores Roblox's stick and removes the screen
- no errors

**Not tested:**
- the sprint lock after the per-frame fix
- a slide from a real run
- Mods in a real match (the range has none)
- a real phone
- a full match server

**Known:**
- In Studio's desktop view Roblox's chat window covers the Sprint button and eats its taps. On a phone the chat stays closed until opened. If that's a problem, Sprint moves nearer the stick.
- The scoreboard button is hidden (the scoreboard isn't laid out for touch yet), and so is Settings (no match settings screen yet).

**Next:** the owner's playtest on a phone (or the Studio Device Emulator), then the layout editor (UI Architecture §9 step 7).

## Fixes after the owner's phone review (2026-11-22)
- **Look-through:** the buttons don't take touches (`Interactable = false`), so Roblox's camera turns with a touch that starts on Fire or a Mod; TouchController hit-tests the touch itself (circles 20% bigger than drawn) and fires the actions. The stick zone still blocks the camera.
- **Highlight:** a held button shows a lit plate (`3B4454`) and presses to 0.94.
- **Stick:** it follows the thumb past 1.6× its ring, so changing direction answers at once. *(Removed 2026-11-25: easing back read as reversing.)*
- **Auto Sprint** (Settings, default on): the Sprint button and the stick's lock hint hide.
- **Aim:** hidden on guns with `noAds`. On guns with `noAds` + `altFire` (Classic, Knife) it holds the alt fire, their right click.
- **Inspect row:** placed from `GuiService.TopbarInset`, which is the free space between Roblox's buttons (Min.X = the right edge of Roblox's left buttons). The first version read it backwards and Inspect landed mid-screen.
- **Hidden while dead / spectating;** the death and spectate screens own the bottom.
- **Scoreboard button:** hold to show, like Tab (the scoreboard now works on phones).
- **Kill feed** on the right under the weapon slots, 2× size. **NetStats** hidden on phones.
- **Health:** the simple bar is the touch screen's own; the old v1 panel is deleted.
- **Not yet:** touch camera sensitivity and aim assist (after the owner's playtest).

## Fixes after the second phone test (2026-11-22 overnight)
The owner reported buttons that felt unresponsive or stuck, the inspect and tab row too low, "ENTER" on LOCK IN on a phone, and a tiny match end.
- **Hit-test:**
  - The touch now asks `PlayerGui:GetGuiObjectsAtPosition`, which uses the same coordinates as the touch, so the hit areas line up with what is drawn.
  - Another screen's button or panel on top wins.
  - The old `processed` gate is gone: Roblox flags touches over our buttons as processed, which dropped presses.
- **Stuck buttons:** if the window loses focus (a notification, the home bar), every held button and the stick let go.
- **Inspect / tab row:**
  - `TopbarInset` is in screen pixels, while GUI positions start below Roblox's 58 px bar. The row was a whole bar too low.
  - It's converted with `GetGuiInset` now, so its top tucks 4 px under Roblox's buttons.
- **Test tools:** GUNS, TEST and SKINS (Studio and test mode only) sit in a row under it, away from the knife and fire buttons.
- **Key chips:** no keyboard hints on touch anywhere (`Shared/InputGlyphs`).
- **Match end:** 1.6× on phones, with the winner cards placed from the real canvas.

## Stick and button pass (2026-11-25)
Owner on a phone: "you can pull it so far so then it just follows you and then if you try to slow down it ends up going backwards if you pulled too far." Study: [RIVALS Mobile Controls](../03%20Research/Rivals%20Reference/Mobile%20Controls.md) (their stick is Roblox's dynamic thumbstick: the base stays put).
- **Stick base stays where the thumb landed** for the whole touch (the follow from 2026-11-22 is gone). Past the ring the nub sits on its edge and the move is full speed that way; easing back slows down; only crossing the start point turns you around. Numbers in `Config/TouchControls` `STICK`: dead zone 0.08, full speed at 0.55 of the ring radius, linear in between, sprint lock unchanged.
- **Real analog speed:** `Humanoid.MoveDirection` is always unit length (measured), so a half-pushed stick used to run at full speed. The movement sim now scales idle / walk / run / crouch speed by the push (`Simulation/Movement` `setOwnPush`); the auto run needs a push of `Movement.TOUCH_RUN_PUSH = 0.6` and builds from the walk. Keys and pads are unchanged (push 1).
- **Stick under the thumb:** `InputObject.Position` and `AbsolutePosition` share one space (both start under the top bar, measured). We added `GetGuiInset` on top, so the stick was drawn 58 px below the thumb and the Mod cancel zone test was off by the same.
- **Hit slop:** the nearest combat circle within 12 px of the touch (`HIT_SLOP`), by circle maths; inside overlapping square boxes the nearest circle wins. It replaced 16 extra GUI queries on every touch that missed (most camera swipes).
- **Camera through buttons** (setting, default on) now means Fire, Aim and the Mods only (`CAMERA_THROUGH`). Jump, Slide, Reload, slots and the rest keep their touch, so tapping them never jerks the view (RIVALS: every button keeps its touch). `ModAltButton` no longer fires twice (an old `Activated` hook).
- **Jump:** the touch Jump asks `MovementController.requestJump`, so it gets the jump buffer and coyote time like Space.
- **Studio check** (phone layout, `ForceTouchUI`, 1v1 bot match, mouse as the finger): base lands on the thumb; pulled 500 px right it stays put at full speed; easing back walk speed falls 15.6 → 0.1 studs/s and reverses only past the start; a press 7 px outside Fire fires, 22 px outside doesn't; Jump from the button leaves the ground; combat gaps ≥ 8 px at phone scale.
- **Not checked:** a real phone (multi-touch, thumb feel), camera sink on Jump with a real swipe (Studio's mouse can't pan the touch camera), tablets.

## 7. Build steps (after picks)
1. Icon sheet (SVG) → owner review → upload.
2. Studio mockup of the Touch screen in `StarterPlayerScripts.UI/Touch` at 844×390 and 667×375 (device sheet capture) → owner edits it in Studio.
3. `TouchController` (client): stick, buttons from a data table (`Config/TouchButtons`: id, input, icon, default position/size, toggle, hide rules), visibility rules (menus open, dead, spectating), settings hooks. Removes the touch code from `HudController` and `ModHudController`.
4. Editor + `Remotes.Settings` touch-layout save (validated) + 3 profiles.
5. Emulator pass on phone and tablet sizes, then a real phone.
