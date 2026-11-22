# Mobile controls: concept (2026-11-22)

**Status (2026-11-22):** mockup v2 built in Studio after the owner's review (compact firing cluster, real TopBar, new ammo readout, Inspect). Waiting on the owner's playtest notes, then the build (§7).
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

## 7. Build steps (after picks)
1. Icon sheet (SVG) → owner review → upload.
2. Studio mockup of the Touch screen in `StarterPlayerScripts.UI/Touch` at 844×390 and 667×375 (device sheet capture) → owner edits it in Studio.
3. `TouchController` (client): stick, buttons from a data table (`Config/TouchButtons`: id, input, icon, default position/size, toggle, hide rules), visibility rules (menus open, dead, spectating), settings hooks. Removes the touch code from `HudController` and `ModHudController`.
4. Editor + `Remotes.Settings` touch-layout save (validated) + 3 profiles.
5. Emulator pass on phone and tablet sizes, then a real phone.
