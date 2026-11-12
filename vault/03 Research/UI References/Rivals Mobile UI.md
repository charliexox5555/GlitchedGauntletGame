# RIVALS mobile UI (touch layout reference)

Study of four YouTube videos of RIVALS on phone/iPad, for our own mobile HUD design in Figma. Not a copy brief: we want to understand the touch layout and patterns, then do our own soft-but-tactical version. Companion to [Rivals PC UI](Rivals%20PC%20UI.md).

Frames live in `vault/02 Art/References/ui/video-frames/rivals-mobile/` (git-ignored on purpose, third-party images). Percentages are of the screen in landscape (x from left, y from top); sizes are button diameter as a share of screen **height**, measured by eye from the frames, so treat them as ±1.5%.

## Summary

- RIVALS mobile = Roblox's own landscape layout plus a **floating left joystick**, **right-side button cluster** (ADS, fire, reload, slide/crouch, jump), and a **small left stack** of utility buttons (spectate, inspect, leaderboard). Camera = drag on any free area.
- The default cluster is **cramped in the lower right** (five buttons in a 25% x 45% area) while the **top-right is crowded** with a 4-slot weapon hotbar and two utility buttons. The centre and the lower left are empty: that is where the aim and move thumbs live.
- The whole HUD is **user-movable and hideable**: all three non-default players have rearranged it (fire on the left, ADS top-left, hotbar moved to bottom-centre, or almost every button hidden). A Touch settings tab and a "Gameplay HUD" preset dropdown exist.
- Heavy **mobile assists** are first-class settings: Auto Shoot, Auto Jump, Double Tap To Shoot, Aim Assist, Easy Slide, always-on auto sprint and crouch toggle. Players on PC call auto-shoot a balance problem ([4:00 HGMz1](https://www.youtube.com/watch?v=HGMz1-vs4dc&t=4s)). We need an assist plan that does not need a second rule set.
- PC HUD pieces are mostly **kept as is, not re-laid-out** on mobile: top score/timer strip, health bar bottom-left, ammo bottom-right, kill feed top-right. Only the Roblox top bar is shrunk and the mobile buttons are layered on top.

## 1. Touch control layout

### Default layout (video 1, 1150x720 capture, [0:14](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=14s))

![](../../02%20Art/References/ui/video-frames/rivals-mobile/ZsYA86F6jJk_0014_hud-full-layout.jpg)

Everything below is at the default layout of that video unless stated.

```
 0%                                                              100%
 +--------------------------------------------------------------------+ 0%
 |[R][=][chat][gear]    [ team A  score | timer | score team B ]  [4 weapon slots] |
 |[eye][inspect][board]                                  [melee][utility]   |
 |                                                                    |
 | (Daily Tasks panel, lobby/pre-round only)                           |
 |                                         +        <- crosshair       [ADS]    |50%
 |                                                          [fire]            |
 |   ( ) joystick appears where                    [reload]        [JUMP]     |65%
 |   left thumb lands (15-27% x,            [slide/crouch]                    |
 |   70-83% y)                                                    20 | 100    |
 | [=====health=====]                                       Assault Rifle    |95%
 +--------------------------------------------------------------------+ 100%
   LEFT THUMB: move (floating stick)          RIGHT THUMB: look (drag any free area)
                                              + taps the right cluster
```

Thumb map with hot zones (percent of screen):

| Zone | x | y | Who uses it |
|---|---|---|---|
| Move stick (floating, appears under thumb) | 10-30 | 60-90 | left thumb |
| Free look area | 30-72 | 15-95 | right thumb drag (the whole middle is empty on purpose) |
| Right button cluster | 66-96 | 45-85 | right thumb, repositions between taps |
| Top-right weapon slots | 72-98 | 5-20 | tap to switch, away from both thumbs |
| Top-left utility stack | 2-22 | 8-16 | rarely touched, away from both thumbs |

### Control table

| Control | Position (centre) | Size (diam. % screen H) | Notes | Source |
|---|---|---|---|---|
| Move joystick | floating, base ring seen at 15-27 x, 70-83 y | ring about 10%, nub about 5% | Appears where the thumb lands; "dots" trail drawn behind it (seen as 3-5 small dots below the ring) | [0:14](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=14s), [0:43](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=43s) |
| ADS (crosshair icon) | 88 x, 50 y | 14.5% | Top of the cluster, highest reach | [0:14](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=14s) |
| Fire (claw/bullet icon) | 78 x, 58 y | 14.5% | Turns solid cyan while held ([1:40](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=100s)) | [0:14](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=14s) |
| Jump (up arrow) | 88 x, 71 y | 17% (largest) | Bottom-right corner = easiest tap | [0:14](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=14s) |
| Slide / crouch | 75 x, 76 y | 14.5% | Icon changes between "crouch" and "slide/dash" with state ([0:00](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=0s) vs [0:14](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=14s)) | same |
| Reload | 69 x, 64 y | 10% (smallest of the cluster) | Left of fire, lit cyan when needed in [video 2](https://www.youtube.com/watch?v=d5IVyduWhjo&t=199s) | same |
| Melee | 87 x, 21 y | 6.3% | Small, top-right under the hotbar | [0:14](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=14s) |
| Utility/grenade slot | 92 x, 21 y | 6.3% | Next to melee; tiny, mis-tap risk | same |
| Weapon slots (4) | 75, 82, 88, 95 x; 11 y | 8.3% each | Active slot has a cyan ring; slots show weapon art only | same |
| Spectate eye, inspect, leaderboard | 5, 12, 19 x; 12 y | 8% each | Stack under the Roblox top bar, top-left | same |
| Health bar | 2.5-26 x, 92 y | 4% high, 23.5% wide | Number inside the bar | same |
| Ammo + weapon name | 87-96 x, 87-92 y | digits about 5.5% tall | Mag big, reserve small, name under | same |
| Score + timer | 35-65 x, 1-10 y | about 8% tall | Team banners left/right of a timer chip | same |

**Auto-fire or tap?** Both. Default is a manual **Fire** button, but mobile-only settings add **Auto Shoot** (fires when the crosshair is on an enemy), **Double Tap To Shoot**, and **Auto Jump**. Aim Assist Strength is a 0 to 1 slider (0.7 in the capture). Pro and iPad players lean on auto-shoot ([0:04 HGMz1](https://www.youtube.com/watch?v=HGMz1-vs4dc&t=4s)); a PC player says it is a problem in matchmaking ([5:31 HGMz1](https://www.youtube.com/watch?v=HGMz1-vs4dc&t=331s)).

### Handcam: which thumb does what

Video 2 shows hands in a corner inset. It is zoomed (the main screen is a magnified crop), so use it for **grip**, not for percentages.

![](../../02%20Art/References/ui/video-frames/rivals-mobile/d5IVyduWhjo_0106_handcam-hud-zoomed.jpg)

- Left thumb: joystick (bottom-left). Right thumb: camera drag. A **raised left index finger** rests over the top-left area where this player moved the ADS button, and a **right index finger** is over the fire button at the far right edge ([1:06](https://www.youtube.com/watch?v=d5IVyduWhjo&t=66s), [5:31](https://www.youtube.com/watch?v=d5IVyduWhjo&t=331s)). So the player holds the phone in a **claw grip (4 fingers)**: thumbs aim and move, index fingers fire and ADS. This is my reading of the inset, not stated in the video (the creator barely talks).
- That player's layout (video 2): ADS ring top-left near the gear, a left cluster of eye / inspect / leaderboard / melee / slide / utility, four big weapon slots at the **bottom centre** (about 27, 37, 62, 70 x; 72 y) and a very large fire button at the right edge. The reload button sits above fire. Every one of these was moved by the player.

![](../../02%20Art/References/ui/video-frames/rivals-mobile/d5IVyduWhjo_0531_ads-fire-pressed.jpg)

## 2. How the PC HUD is adapted

- **Kept as on PC:** score/timer strip top-centre, health bar bottom-left, ammo bottom-right, weapon slots top-right, small centre crosshair, damage-direction arc around the crosshair, "Eliminated <name>" text under the crosshair, kill feed top-right. Nothing is re-flowed into a mobile-specific HUD.
- **Added for touch:** the button cluster, the floating stick and the top-left utility stack.
- **Hidden on mobile:** key-hint labels (no letters on buttons, icons only), the spectator list is a small eye button, the leaderboard is a button not a hold-Tab panel.
- **Roblox top bar:** a tight pill with logo, menu, chat (badge counter) and gear at the very top-left, **above** the RIVALS utility stack. The mic icon shows in the iPad capture of video 3. The rest of the HUD starts below about 10% height, so the top-left is permanently crowded.
- **Safe area:** the capture has no visible notch, but nothing sits in the outer 2% (health bar starts at x=2.5%, ammo ends at x=96%). The pro capture (3:2 iPad, no notch) puts everything within 1-3% of the edges, so the edge buffer is tiny.
- **Pre-round panel:** the "Daily Tasks" card sits left-middle (x 1.5-23, y 35-58). It blocks the left thumb zone's upper half, visible only before the round ([0:00](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=0s) and [0:29 LlVGV](https://www.youtube.com/watch?v=LlVGVAABi14&t=29s)).

![](../../02%20Art/References/ui/video-frames/rivals-mobile/ZsYA86F6jJk_0000_daily-tasks-crouch-icon.jpg)

**Kill feed and 4v4 banners** (video 4, [4:17](https://www.youtube.com/watch?v=HGMz1-vs4dc&t=257s)): in 4v4 the score banners grow to carry four avatars, each with a rank badge and a platform icon (phone / monitor / controller), a small health pip bar above each avatar, and a live weapon + ammo cluster at the end of the enemy banner. The strip then runs 13%-43% (team A) and 57%-91% (team B) of the width and about 8% of the height. The kill feed shows two attackers plus a weapon icon plus the victim, one line per kill ([12:54](https://www.youtube.com/watch?v=HGMz1-vs4dc&t=774s)).

![](../../02%20Art/References/ui/video-frames/rivals-mobile/HGMz1-vs4dc_0417_4v4-team-bars-kill-panel.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-mobile/HGMz1-vs4dc_1254_killfeed-multi-weapon-icons.jpg)

## 3. Mobile menus

- **Lobby bottom bar** ([video 2, 0:22](https://www.youtube.com/watch?v=d5IVyduWhjo&t=22s)): seven icon+label tabs in a dark strip along the bottom: Backpack, Weapons (red badge), Tasks, Shop, Pass, Settings, Event; a wide green **Play** button sits above the strip, centre (about 50% x). Labels are bold white, about 3.5% of screen height tall, icons 11% tall and protruding above the bar. The capture is zoomed, so on-device sizes are smaller; read it as "7 tabs, one primary CTA".

![](../../02%20Art/References/ui/video-frames/rivals-mobile/d5IVyduWhjo_0022_lobby-bottom-bar.jpg)

- **Settings** are a centred column (about 38% of the screen width) of full-width rows, each with an icon, a bold title, a grey one-line explanation, and a toggle or slider on the right. Row height about 7.5% of screen H. Mobile-only rows say "Only available for mobile devices". Per-setting reset button (red circular arrows) appears when changed. A red X (about 7% wide) floats outside the panel top-right ([1:26](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=86s)).

![](../../02%20Art/References/ui/video-frames/rivals-mobile/ZsYA86F6jJk_0126_settings-mobile-options.jpg)

- **iPad settings, Game tab** ([6:26 LlVGV](https://www.youtube.com/watch?v=LlVGVAABi14&t=386s)): tabs Video / Audio / Game / Crosshair / Touch / Account along the top, each with an icon; a page rail (1, 2, 3, download) on the left; a **description panel on the right** that fills in for the selected row. Contains a "Weapon Picker: Grid" dropdown and "Gameplay HUD: Default" dropdown (the HUD has presets).

![](../../02%20Art/References/ui/video-frames/rivals-mobile/LlVGVAABi14_0626_settings-game-tab.jpg)

- **Roblox pause menu** is the stock one: People grid, Settings, Gallery, Report, Help; **Leave / Respawn / Resume** at the bottom ([0:36 HGMz1](https://www.youtube.com/watch?v=HGMz1-vs4dc&t=36s)). Buttons about 7% high, readable.
- **Spectate** (after elimination): name pill with two cyan arrow buttons at the bottom centre (about 25%-75% x, 70-77% y), the player name with a platform icon ([7:44 video 2](https://www.youtube.com/watch?v=d5IVyduWhjo&t=464s)).

![](../../02%20Art/References/ui/video-frames/rivals-mobile/d5IVyduWhjo_0744_spectate-arrows.jpg)

- **Not captured:** the loadout/weapon locker and shop screens on a phone, the match draft screens. None of the four videos opened them. A new video search is needed if we want those (e.g. "rivals mobile inventory", "rivals mobile loadout").

## 4. HUD customisation

- A **Touch** settings tab and "Gameplay HUD" dropdown exist ([6:26 LlVGV](https://www.youtube.com/watch?v=LlVGVAABi14&t=386s)), but no video opens the Touch tab, so slider names, opacity and size controls are unconfirmed.
- Evidence that buttons are **freely repositionable, resizable and hideable**: video 2's player has ADS top-left and weapon slots at the bottom centre; video 3's pro has jump, fire, reload and slide hidden or faint with only ADS (22% H wide) left on the right and the crouch icon moved to the top centre ([4:27](https://www.youtube.com/watch?v=LlVGVAABi14&t=267s), [7:25](https://www.youtube.com/watch?v=LlVGVAABi14&t=445s)); video 4's iPad player has fire on the left at 13% x, 31% y.
- Video 2 at 3:19 and 7:44 shows an extra icon strip in the Roblox top bar after the round ends (close X, gear, two panel icons, a wrench) that might be the layout editor entry ([3:19](https://www.youtube.com/watch?v=d5IVyduWhjo&t=199s)). Unverified.
- Left-handed mode exists as a toggle ("Left Handed Touch Controls") rather than a mirrored preset.

![](../../02%20Art/References/ui/video-frames/rivals-mobile/d5IVyduWhjo_0319_edit-mode-toolbar.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-mobile/HGMz1-vs4dc_0149_ipad-custom-layout-left-fire.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-mobile/LlVGVAABi14_0725_pro-minimal-hud.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-mobile/LlVGVAABi14_0228_pro-custom-hud.jpg)

Settings found (mobile-relevant, [1:26 video 1](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=86s)): Toggle Crouch (always on for mobile), Toggle Sprint (not on mobile), Auto Sprint (always on), Easy Slide (slide by crouching while sprinting), Auto Shoot, Auto Jump, Double Tap To Shoot, Left Handed Touch Controls, Aim Assist Strength (0.7), Controller Deadzone, Sensitivity (2.75). A tip from a PC player is low sniper sensitivity plus high FOV on mobile ([4:10 HGMz1](https://www.youtube.com/watch?v=HGMz1-vs4dc&t=250s)).

## 5. What works and what is cramped

Works:
- Floating stick = no wasted resting spot, zero thumb travel.
- Free-look area is the biggest part of the screen (about 40% of the width).
- Colour state: pressed = solid cyan, idle = translucent grey. Easy to see a held button without looking at it.
- Icon-only buttons with simple, high-contrast glyphs; the cluster has no text.
- Jump as the largest, lowest, rightmost button.
- Settings rows are large, one-line help text, and sliders are easy to hit.
- Pro and iPad players reach "minimal HUD" by hiding most buttons, so the system is flexible.

Cramped / wrong:
- **Five buttons in a quarter of the screen.** Fire and ADS are 14.5% each, but their centres are only about 15% apart vertically. Fire, slide, reload cluster in one arc where a thumb sweep triggers the wrong one (visible: slide icon in [0:14](https://www.youtube.com/watch?v=ZsYA86F6jJk&t=14s) swaps between crouch and slide, so the same spot changes meaning).
- **Reload is the smallest button (10%) but is used constantly.**
- **Top-right is a wall:** four weapon slots + two tiny utility buttons + the kill feed + the player ping text all share the strip, and in the pro video the kill feed and slots overlap ([2:28 LlVGV](https://www.youtube.com/watch?v=LlVGVAABi14&t=148s)).
- The Roblox top bar plus a 3-button utility stack costs the whole top-left, and in the pro capture the crouch button moved to the middle of the top and **covers a player's team portrait** ([2:28](https://www.youtube.com/watch?v=LlVGVAABi14&t=148s)).
- Fire needs the right thumb off the camera; this is why players want auto shoot and why it looks unfair to PC players.
- No labels or hints: new players cannot tell reload from slide from melee.
- The default utility buttons (melee, utility at 6.3%) are below any reasonable touch target.

## Takeaways for our game

Our game has abilities ("Mods") per round, a draft screen every round, and a shared weapon tier. That adds buttons and a mid-match decision screen that RIVALS does not have.

**Touch-target rules (to put in Figma as a mobile spec):**
1. Primary combat buttons (fire, ADS, jump): **at least 13% of screen height** (about 60 pt on a 6.1 inch phone, roughly 12 mm). Jump may be 15-16%.
2. Secondary buttons (reload, slide/crouch, melee, ability 1/2): **at least 10% of height** (about 44-48 pt). Never go below 9%.
3. Anything that costs a life if hit by mistake (grenade, ult): at least 10%, plus 3% of dead space around it.
4. Gap between neighbours: at least **2.5% of height** between edges.
5. Safe zone: keep controls at least **4% from the left/right/bottom edges** and **12% from the top** for the Roblox bar; add extra for notches via `GuiService:GetGuiInset()` and `ScreenGui.ScreenInsets`.

**Zones (landscape):**
- **Left thumb zone** x 0-35, y 55-100: floating joystick only. Nothing static lives there. Keep it free of panels, quest cards and kill feed.
- **Right thumb zone** x 65-100, y 40-100: one arc of at most **4 buttons** (fire, jump, ADS, slide/crouch), reload on the inner edge.
- **Dead zone for look** x 35-65: nothing at all except the crosshair and centre alerts.
- **Top strip** y 0-12: Roblox bar on the left, score/timer in the middle, weapon/mod slots on the right. Info only, no frequent taps.
- **Ability (Mod) buttons**: put the two Mod buttons directly above the cluster on the right edge (y 20-40), not in the top-right strip. They are tapped mid-fight, unlike RIVALS's utility slots.

**What to hide or merge on mobile:**
- Hide key hints and the ammo reserve; show mag only, big (5.5%+ tall) at bottom-right.
- Hide the spectate/inspect/leaderboard stack from the live HUD: tuck them into one "more" button or the pause menu (we do not need three at all times).
- Merge crouch + slide into **one** button with stable icon and behaviour, like RIVALS's Easy Slide, but keep the icon fixed.
- Make **auto sprint always on** and **auto jump optional**. Plan auto-shoot/auto-aim as a **server-aware setting with the same damage and rate for everyone**; otherwise "auto-shoot iPad kids" complaints repeat.
- Show the 4v4 team strip as **compact health pips** on mobile (avatar + pip only, no rank/platform badge).
- Weapon switching: avoid 4 tiny slots in a corner; use a **tap on the weapon card** (bottom right) plus a swipe, or only two slots visible (current + last), since our tier gives a shared weapon.

**Customisation (do this from day one, RIVALS proves players want it):**
- Per-button **position, size (85-130%) and opacity** sliders, save as a preset, reset button, and a "left-handed" mirror preset. Offer 2-3 shipped presets (Default, Minimal, Claw).
- Show a **live preview** with the drag handles and a safe-area overlay while editing.
- Settings as rows with icon, title, one-line description, toggle or slider. A right-hand description panel on tablets.

**Art direction (soft but tactical, not neon, not bubbly, not a RIVALS copy):**
- Idle buttons: dark translucent plates with a hairline edge, not a plain grey disc. Pressed: a **calm solid accent fill** (one accent colour) and a small scale-down, no glow.
- Use square-ish plates with softened corners (small radius, not pills) and **crisp pictograms**; no gradients, no bubbly drop shadows. Icon strokes about 6% of the button diameter.
- Buttons are slightly smaller than RIVALS's but larger in hit area than they look (extend the hit box about 20% past the visible plate).
- Keep text off combat buttons; reserve text for menus (about 3.5% of height, bold, high contrast), with 7-8% row height in lists.

**Menus on a phone:**
- Bottom tab bar with 4-5 items max (RIVALS shows 7; too many for a phone) with labels, a single large primary **Play** CTA above it.
- Scroll lists: row 8% of height, icon + title + one-line description + right-side control, wide hit area.
- Settings: left tab rail (Video / Audio / Game / Crosshair / Touch / Account is a good template), one column of rows, close X outside the panel top-right.
- Draft screens (ours): full-width card row, 3 cards at least 28% of the width each, 40% of the height, confirm with a single tap and a short timer ring. Not captured in RIVALS, so design from our own needs.

**Open questions for a follow-up video search:** loadout/locker screens on a phone, the Touch settings tab itself (opacity/size sliders), the lobby on a phone with the shop and matchmaking dialogs.

## Sources

All four are YouTube videos of RIVALS (Roblox). Frames saved locally, never committed.

- Video 1, "Roblox Rivals Mobile Gameplay" (GodlyWiz, 2:23): https://www.youtube.com/watch?v=ZsYA86F6jJk
- Video 2, "#1 Mobile HANDCAM In Roblox Rivals!" (8:51): https://www.youtube.com/watch?v=d5IVyduWhjo
- Video 3, "AVERAGE RIVALS GAMEPLAY AS A PRO MOBILE PLAYER" (11:54, iPad, 3:2): https://www.youtube.com/watch?v=LlVGVAABi14
- Video 4, "I Tried Mobile for the FIRST Time in RIVALS..." (14:46, PC player on iPad, 16:9): https://www.youtube.com/watch?v=HGMz1-vs4dc

Method note: the analyzer's frame extraction failed on videos 2-4 (AV1/webm), so frames were re-extracted from a 720p MP4 downloaded with yt-dlp; evenly spaced 12 frames per video. Percentages are measured by eye from those frames. Videos 2 and 4 have little speech, so the claims about grip and layout come from the frames, not the narration.
