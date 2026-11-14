# UI Overhaul: research and recommendations (phase 1, 2026-11-14)

**What this is:** the research pass before the UI overhaul. It covers what the current UI does, a few references, and how to build screens by hand in Studio. **Nothing is built or changed yet.** The owner picks the first section from this, then gives the specifics.
**Scope:** desktop at 1920 × 1080 only. Other screen sizes and devices come later.
**Builds on:** [Style Bible](Style%20Bible.md), [UI Theme v4 Soft Edge](UI%20Theme%20v4%20Soft%20Edge.md) (the current direction), [UI References](../03%20Research/UI%20References/00%20UI%20References.md) (RIVALS + Valorant video study), [Lobby UI and Queue](../01%20Design/Lobby%20UI%20and%20Queue.md).

---

## 1. The current UI (Lobby place, captured 2026-11-14)

Captures: [HUD](References/ui-overhaul/2026-11-14-lobby-hud.jpg) · [Play menu](References/ui-overhaul/2026-11-14-lobby-play-menu.jpg) · [Shop](References/ui-overhaul/2026-11-14-lobby-shop.jpg). The world renders black in MCP captures (known capture-lighting issue); only the UI matters here.

### How it's built
- **StarterGui is empty in both places.** All 17 Lobby ScreenGuis are made by code at runtime (`src/lobby/client/Controllers/LobbyHud.luau`, `QueueMenu.luau`, `Panels.luau`, builders in `src/shared/UiKit.luau`, tokens in `src/shared/Config/UiStyle.luau`). The owner can't see or edit any of it in Explorer outside a playtest. LobbyHud is 155 instances, BattlePass 276.
- Layout is **Offset at a 1920 × 1080 design size** (about 505 `fromOffset` vs 226 `fromScale` across `src`), with one "Fit" `UIScale` per cluster (`src/lobby/client/Util/Layout.luau`).
- Text is **fixed `TextSize`** everywhere in the Lobby: no `TextScaled`, no `UITextSizeConstraint`, only 3 `UIPadding`s. A "text floor" raises `TextSize` when the Fit scale drops, but **the label's box doesn't grow with it**.

### What's worth keeping
- The **soft dark navy plates**, good contrast, and calm dark backdrop behind menus.
- The **breadcrumb + big title** header pattern ("PLAY · CASUAL DUELS" over "CHOOSE YOUR FIGHT").
- **Round icon buttons** for close and settings; the dock's clear line icons.
- The PLAY sub-line ("1V1 · 2V2 · 3V3") as a quiet second line on a primary button.
- Sizes are readable at 1080p (labels 15-17 px, titles 56 px).

### What makes it read as AI-made (owner's words: pills, corners, no character)
1. **One radius on everything.** Profile, LV badge, currency, FEATURED / COMING SOON tags and the queue bar are capsules (`RADIUS.pill = 999` → `UICorner(0.5, 0)`). Cards, dock buttons and menus share the same ~16 px radius, the same dark stroke and the same drop shadow. When every surface is the same stamped rounded rectangle, nothing feels designed for its job.
2. **Gold means everything.** PLAY, FIND MATCH, the LV badge, coin, "+", breadcrumbs, FEATURED, COMING SOON and the featured card outline are all gold. In the Play menu there are **two big glowing gold buttons** on one screen (FIND MATCH and PLAY). The theme rule is one gold "do this now" per screen.
3. **Generic type.** Display is Montserrat Heavy (on the rejected list) and labels are Builder Sans, Roblox's own system UI font, so the menus look like Roblox's menus. Small caps labels have no tracking, and the three grey meta lines on the mode cards are too close in size and weight to rank.
4. **Glossy CTA.** The gold buttons have a gradient, a lip and a glow ring. That's the "app button" look the theme drops (no glow, no glossy gradients).
5. **No link to the game.** Nothing echoes the Sunwell hall (faceted plates, gold rims, slate), the slash / » brand marks, or the Mod circles. The mode cards' painted characters are generic splash art, not our block bodies.
6. **Loose grid.** In the Play menu the title starts at x 256 but the card row starts at x 396, and the close button doesn't line up with the cards' right edge. Elements float instead of sharing edges.

### The button-text overflow
- At my Studio viewport (2179 × 964) a scan of every visible label in all Lobby menus found nothing past its own box. Earlier passes ([Lobby UI and Queue](../01%20Design/Lobby%20UI%20and%20Queue.md), [Match HUD](../01%20Design/Match%20HUD.md)) said the same. **I couldn't reproduce what the owner sees yet.**
- **Why the scans miss it:** they compare the text to the *label's own box*, not to the *visible plate minus padding*. A label box can be as wide as (or wider than) its button with zero padding, so text touches or crosses the plate's edge while the scan reports "no overflow". Example: the dock labels are fixed 100 px boxes with no `UIPadding`.
- **Mechanisms that cause it:** fixed `TextSize` in a fixed box; the text floor raising `TextSize` without growing the box; label boxes sized separately from their plate; longer strings dropped into a box sized for a short one.
- **Ask:** which button(s) and which place (Lobby or match) the owner saw it on, ideally a screenshot. The fix in §5 removes all four mechanisms either way.

---

## 1b. The match UI (match place, playtest at the 1920 × 1080 preview, 2026-11-14)

**The owner wants the overhaul to start in the game, not the Lobby.** Captured in a real 1v1 vs a bot (Workspace `TestMode` turned off for the playtest, then set back to true): [range HUD](References/ui-overhaul/2026-11-14-match-range-hud.jpg) · [draft, new Mod](References/ui-overhaul/2026-11-14-match-draft-new-mod.jpg) · [draft, upgrade paths](References/ui-overhaul/2026-11-14-match-draft-upgrade.jpg) · [round HUD](References/ui-overhaul/2026-11-14-match-round-hud.jpg) · [Sudden Death banner](References/ui-overhaul/2026-11-14-match-banner-sudden-death.jpg).
**Not captured:** kill feed, death / spectate, match end (Rematch / Play Again / Leave). Rounds can't be ended by setting a Humanoid's health (the game tracks health itself), so these need real kills in a playtest.

### How it's built
- **StarterGui is empty here too.** All screens are code-built: `CombatHud` (health, ammo, crosshair, hit feedback, kill feed; `HudController`), `ModHud` (3 Mod slots; `ModHudController`), `MatchHud` (scorebug, timer, banner; `MatchHudController`), `Draft` (`DraftController`, 135 instances), `Spectate`, `MatchEnd`, plus one overlay per ability effect (`Util/*Fx`).
- **Almost nothing is named.** The scorebug is `TopBar` → `ImageLabel`, `ImageLabel`, `TextLabel`, `Frame`, `Frame`… Rebuilt in Studio, every node needs a real name to be editable in Explorer.
- **The match is still on the v1 theme** (`Config/Theme`): Oswald (titles, numbers) + Montserrat (labels, body), 9-slice cut plates. The Lobby is on v2 (`Config/UiStyle`: Montserrat Heavy + Builder Sans, rounded and pills). **The Lobby and the match look like two different games.**
- Offset at a 1920 × 1080 design size + one `UIScale` per cluster (`Util/Ui.luau` `fit`). At the 1920 × 1080 preview the ScreenGuis are **1919 × 1022** (the top bar takes 58 px), so everything draws at **0.946** scale.
- Insets are mixed: `CombatHud` / `ModHud` use `DeviceSafeInsets`, `MatchHud` / `Draft` use `CoreUISafeInsets`, so the HUD pieces don't share one reference area.
- Test-only UI shows in a real Studio match: the "Skins · Stock [;]" chip (`SkinPreview`), plus the hidden gun picker and Mod dev panel.
- **Text fit:** a scan of every visible label in `Draft` and `MatchHud` found none past its box, none closer than 6 px to its plate's edge, and nothing drawn under 13 px. So the overflow the owner saw isn't reproduced in the match at 1080 either. The smallest labels are 13 design px (≈ 12.3 drawn, lifted to 13 by the floor).

### Screen by screen
| Screen | Works | Off |
|---|---|---|
| **Scorebug** (top centre) | Clear and readable: two team plates and a centre timer plate, angled ends, team colour bars, round pips, "ROUND 2 // LIGHT" already uses the slash, the timer turns orange in Sudden Death. The strongest piece; keep its structure. | YOU / VEX at 13 px; diamond pips are tiny; the three plates are hard trapezoid boxes (the v3 "blocky" note). |
| **Health** (bottom left) | Big Oswald number, shield hexagon with its value, shield + health bars. | Sits in a **dark box with a gradient**: the theme says no box behind HUD numbers (fades instead). "HEALTH" is a grey 13 px caption floating far from the number and vanishes over light floors. |
| **Mods** (bottom centre) | Right slot, clear icons, a cyan line under ready Mods. | **Square tiles**; the theme wants circles with rings (cooldown, charges). Keys Q / E / T are tiny grey text under the tiles and unreadable on bright floors (`A7B0BC` on near-white). Empty slots are plain grey squares. |
| **Ammo** (bottom right) | Big number with "/ 13" and the gun name. | Same dark box as health. The gun silhouette floats above the plate. In the test range the ammo had a ring the match doesn't, so the two versions don't match. |
| **Banner** (Sudden Death) | Loud and readable; "Get inside the circle" tells you what to do. | A **full-width red band through the middle of the screen, across the crosshair** in a fight; the theme's banner slot is x 42-58%, y 12-26%. |
| **Draft** | The most designed screen: two clear tiers ("SELECT A GUN", "DRAFT AN ABILITY"), key tabs on top of each card, role tags, one gold LOCK IN with cut corners. The upgrade draft's "Path A / OR / Path B" stack reads well. | The **Mod card art is glossy painted splash art** (glow, fire, crystals) that fights the flat UI and doesn't look like our blocky world. Lots of 13 px grey text ("UPGRADES", "1 PER ROUND", "Ready: press Enter or LOCK IN."). The dimmed combat HUD still shows under it (100 / ammo in the corners). "ENEMY HAS NO ABILITIES YET" in red competes with LOCK IN. The upgrade column has no art and a different height, which breaks the 3-card rhythm. |

### What the match says about the overhaul
- The match UI has more character than the Lobby (angled plates, slash, one gold button), but it's a **different language** from the Lobby. Step one of the overhaul is one shared kit, used by both.
- The biggest gaps against the Soft Edge direction are in the **combat HUD**: boxes behind numbers, square Mods, captions too small to read over a bright map.
- The draft needs **art direction** (card illustrations) as much as layout.

---

## 2. References

RIVALS and Valorant are already studied ([UI References](../03%20Research/UI%20References/00%20UI%20References.md)). Five more, each checked against full-size screenshots on Interface In Game:

| Game | Learn from | Don't copy |
|---|---|---|
| **The Finals** ([mode select](https://interfaceingame.com/screenshots/the-finals-game-mode/), [pre-match](https://interfaceingame.com/screenshots/the-finals-pre-match/)) | Heavy italic condensed caps for headings, tiny widely tracked caps for labels ("SPECIALIZATION", "GADGETS"). The loadout is a row of small tiles in labelled groups with lots of air above: a model for the draft's 3 Mod cards + your Mods strip. Health is white segments with no plate (our fades). One loud brand colour, used in big fields, not sprinkled. | Hard square tiles everywhere (the rejected "hard box" look). |
| **Overwatch 2** ([play](https://interfaceingame.com/screenshots/overwatch-2-play/), [hero select](https://interfaceingame.com/screenshots/overwatch-2-character-selection/)) | Soft but competitive. Selected = filled colour, slightly bigger, white edge; unselected = flat navy. **State from fill and size, never glow.** Portraits in hexagons: a faceted shape for faces, which fits our "no round curves" model rule. Orange only on the one main button. | The plain, even card grid (players call the menus bland). |
| **Marvel Rivals** ([HUD](https://interfaceingame.com/screenshots/marvel-rivals-hud/), [hero select](https://interfaceingame.com/screenshots/marvel-rivals-hero-selection/)) | HUD frames are slanted parallelograms with thin double outlines: character without pills. Numbers split with a backslash ("30/30"), close to our slash mark. One yellow for timer, confirm and your own slot; everything else white / grey. | The comic look and the portrait arc. |
| **Apex Legends** ([main menu](https://interfaceingame.com/screenshots/apex-legends-main-menu/)) | The closest lobby to ours (squad + READY). **The identity is carried by 2-3 signature shapes only** (red banner tab for the logo, slanted active tab, diamond level badge); everything else is a plain rectangle. Selected rows: thin accent outline. | The diagonal-stripe texture on READY (decoration we banned). |
| **XDefiant** ([round result](https://interfaceingame.com/screenshots/xdefiant-beta-round-win-lost/)) | Round results with one size per tier: big heavy italic number, light small label above it. Your own card is the only one on a plate, with a coloured underline. | A giant headline behind the characters. |

**What recurs in all the good ones:**
1. **One signature shape, used sparingly.** Apex's slanted tab, Overwatch's hexagon, Marvel Rivals' slanted frame. Most surfaces stay plain. → Our one-cut plate should go on the plates that matter (PLAY, LOCK IN, the selected card, the active tab), not on every chip.
2. **Heavy, energetic caps for hero words and numbers; small tracked caps for labels.** → Sarpanch has no italic in Roblox. Worth checking whether it carries enough energy, or whether Titillium Web Black is the hero-number face.
3. **State = one accent + a change of fill or size.** Never glow. → Matches the gold-is-active and ring rules.
4. **Few radii, chosen per job.** Small radius (or none) on chips, a medium one on panels, true circles only for round things. No capsules.

Roblox games (Arsenal, Bedwars, Frontlines, …) have no reliable UI sources online; if wanted, run them through the [Video Analyzer](../04%20Tech/Video%20Analyzer.md) the way RIVALS was studied.

---

## 3. Recommended Studio hierarchy

**Principle:** Studio owns the *layout* (what the owner sees in Explorer); scripts own *behaviour and dynamic content*. Scripts never set Position, Size, colours or fonts on static layout; they set `Text`, `Visible`, `Image`, state attributes, and tween transparency / `UIScale` for motion.

### Ownership and backups (same pattern as the guns)
- Rojo doesn't map `StarterGui` in either project file, so Studio can own it with **no Rojo conflict**.
- After each change, export each changed ScreenGui to `art-source/ui/<Lobby|Match>/<ScreenGui>.rbxmx` (XML, diffable in git) and **save the place**.
- Shared components live in a Studio-owned `ReplicatedStorage.UiTemplates` folder (Rojo owns `ReplicatedStorage.Shared`, not this). Publish it as a **Roblox Package** so the Lobby and match places stay in sync with one update.

### One ScreenGui per screen
```
StarterGui
  Hud                  DisplayOrder 10   (lobby HUD: profile, currency, tabs, PLAY)
  Menu_Play            DisplayOrder 20   Enabled = false
  Menu_Shop            DisplayOrder 20   Enabled = false
  Menu_Locker / Menu_BattlePass / Menu_Settings / Menu_Range
  Modal_MatchFound     DisplayOrder 30
  Backdrop             DisplayOrder 19   (one shared dimmer, not one per menu)
  Overlay              DisplayOrder 40   (toasts, tooltips)
```
- Every ScreenGui: `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`, `ScreenInsets = CoreUISafeInsets` (the default, which the docs recommend for anything interactive); `None` only for full-bleed backdrops and fades.
- Inside a screen: `Root` (Scale 1, 1, with a `UIPadding` for the screen margins) → regions `Header` / `Body` / `Footer` → components. Regions are Scale; components inside them come from templates.

### Components (`ReplicatedStorage.UiTemplates`)
`Button_Primary`, `Button_Secondary`, `Button_Icon` (circle), `Tab`, `Chip`, `Plate` (one-cut 9-slice), `Card_Mode`, `Card_Item`, `Fade`, `Ring`.
- Every button has the same anatomy: `Button` (ImageButton, the plate; hit area) → `UIPadding` → `Label` (TextLabel) and optional `Icon`; a `UIScale` named `Press` on an inner frame for tap / hover motion (never on the hit area).
- Static buttons in a screen are copies of the template placed by hand. Lists (shop items, mode cards, party slots) are filled by script, cloning the template into a `UIListLayout` / `UIGridLayout` container.

### How scripts find things
- **Names for structure** (`Menu_Play.Root.Footer.FindMatch`), `WaitForChild` from `PlayerGui`.
- **Attributes for intent:** `Action = "FindMatch"`, `Mode = "2v2"`, so one handler serves many buttons and renames don't break logic.
- **One CollectionService tag for shared behaviour:** `UiButton` → one binder adds press / hover motion and the click sound to every tagged button.
- One controller per screen in `src/lobby/client/Screens/` (Rojo-owned), replacing the builder code screen by screen.

### Keeping hand-built screens on-theme
`Config/UiStyle` stays the source of truth for colours, fonts, radii and type sizes. A command-bar check, `tools/studio/ValidateUi.luau` (like `ValidateWeapons`), flags off-token fonts and colours, capsules (`UICorner` scale ≥ 0.5 on non-square objects), missing `UIPadding` in buttons, and text that doesn't fit its plate (§5).

### Migration
Rebuild one section at a time. The old code-built screen stays as the fallback until the Studio version is approved, then its builder code is deleted.

---

## 4. Scale vs Offset at 1920 × 1080

**Scale is the default for where things go and how big regions are; Offset is for small fixed details inside components.**

| Use **Scale** for | Use **Offset** for |
|---|---|
| Screen regions (header, body, footer, side columns) | `UIPadding` inside buttons, plates and cards (e.g. 24 px sides, 12 px top/bottom) |
| Positioning every cluster (with `AnchorPoint` matching its corner: top-right cluster = anchor (1, 0), position (0.97, 0.04)) | `UIStroke` thickness (1-2 px hairlines), the 3 px edge strip |
| Panel and card sizes, grid column widths | `UICorner` radius (4 / 8 px), the 9-slice cut size (corners stay fixed px by design) |
| Bar and ring *fills* (progress = Scale X 0 → 1) | Icon sizes (24 / 32 px, so they stay crisp) |
| Full-screen fades and backdrops (1, 1) | Text sizes (type tokens), list gaps (`UIListLayout.Padding` 8 / 12 / 16) |

**Mixed, with a constraint:**
- **Buttons and cards:** Scale size + `UIAspectRatioConstraint` so the shape, the cut corner and the text area keep their proportions.
- **Anything clickable:** add a `UISizeConstraint` with a minimum size so a Scale button never drops below a usable hit area.
- **Circles** (avatars, Mod slots, timer): Scale height + `UIAspectRatioConstraint` 1.

**At 1080p specifically:** with `CoreUISafeInsets` the usable area is 1920 wide but shorter than 1080 by Roblox's top bar, so a Scale Y of 0.1 is a little under 108 px. Design numbers should be read off the real ScreenGui `AbsoluteSize` in Studio's 1920 × 1080 device preview, not assumed.

**For later (not this phase):** LihFolk's advice is Offset panels under one `UIScale` per cluster (LihFolk note "Layout - Scale Offset and Constraints"); the owner wants Scale by default. Building layout in Scale and keeping Offset only *inside* components keeps both options open for the device pass.

---

## 5. Text sizing

### Facts (Roblox docs + measured in Studio, Titillium Web Bold, 2026-11-14)
- **`TextScaled` fills the padded area, both up and down.** `UIPadding` on the label shrinks the area it scales into: "PLAY" in a 200 × 56 label with 24 / 12 padding drew at 32 px. Without a limit it stops at **100 px** (measured: a 2000 × 400 box drew 100 px text).
- **`UITextSizeConstraint` caps it.** Same "PLAY" with `MaxTextSize = 24` drew at 24. "FIND MATCH" drew at 24. "CUSTOM MATCH SETTINGS" shrank to **18** to stay on one line. Docs: don't set `MinTextSize` below 9.
- **`TextScaled` turns wrapping on by itself**, even with `TextWrapped = false`. A long label ("A VERY LONG LOCALISED BUTTON LABEL HERE") went to **two lines at 16 px** in a 56 px-tall button instead of shrinking on one line.
- **In one row, `TextScaled` gives mixed sizes** (24 / 24 / 18 above), which looks sloppy in a row of tabs or buttons.
- **Measure only after fonts load.** Right after creating labels in edit mode every scaled label reported 14 px (fallback font metrics). Any validator must `PreloadAsync` the fonts and wait a frame first.
- `TextFits` (read-only) goes false when the text doesn't fit; `TextBounds` is the drawn text size; `AutomaticSize` grows a GuiObject to fit its text (docs: meant for localized text); `TextTruncate.AtEnd` cuts with "…".
- LihFolk: `TextScaled` renders long strings tiny and doesn't follow the player's text-size setting; use it with a `UITextSizeConstraint` only. Localized strings run 20-35% longer, so leave **30-40% headroom**.

### Recommended approach
| Kind of text | Setup |
|---|---|
| **Short fixed buttons** (PLAY, FIND MATCH, LOCK IN, CLOSE, 1-3 words, button size fixed by layout) | `TextScaled = true` + `UITextSizeConstraint` (Max = the type token, e.g. 24 for primary, 18 for secondary; Min = 14) + `UIPadding` on the label (≥ 20 px sides). At 1080p the Max caps every button to the same size; a long translation shrinks instead of spilling. **Keep one line:** make the padded height less than 2 × MinTextSize (e.g. 56 px button, 16 px top/bottom padding → 24 px inner < 28), so it can't wrap. |
| **Rows of tabs / chips / content-sized buttons** | Fixed `TextSize` from tokens, `AutomaticSize = X` on the button, `UIPadding` for the sides, `UISizeConstraint` min width so short words don't make tiny buttons. The button grows to fit its label, so text can never leave it, and every item in the row shares one size. |
| **Rows of equal fixed buttons** (dock, mode tabs) | Either content-sized as above inside a `UIListLayout` with flex fill, or `TextScaled` with the same Max on all and the **row sized to the longest label** + 30% headroom. |
| **Long text** (descriptions, mode blurbs, tooltips) | Fixed `TextSize` (body 16-18), `TextWrapped = true`, `AutomaticSize = Y` on the label or its card. Never `TextScaled`. |
| **Names in fixed slots** (player names, item names) | Fixed `TextSize`, `TextTruncate = AtEnd`, full name in a tooltip. |
| **Numbers that change** (timer, currency, ammo) | Fixed `TextSize`; never `TextScaled` (it would jump size as digits change). Box sized for the widest value. |

**Type scale at 1080p (draft, owner to adjust):** hero 64-96 (Sarpanch Black), title 40-56 (Sarpanch ExtraBold), primary button 24, secondary button / tab 18, label 15-16 (Titillium Web Bold caps, tracked), body 16-18 (Titillium Web SemiBold), minimum drawn size 14.

**The check (part of `ValidateUi.luau`):** for every label inside a plate: `TextFits` is true, and `TextBounds` + padding fits inside the *plate's* `AbsoluteSize` (not the label's box), at the 1920 × 1080 preview, after fonts load. This is the check the old scans were missing.

---

## 6. What could go first (owner's call)
**Owner, 2026-11-14: start in the game, not the Lobby.** The owner picks the section and gives the specifics. Candidates in the match, smallest first:
1. **Combat HUD** (health, ammo, Mod slots): seen every second of play, furthest from the direction (boxes, squares, unreadable captions), few parts. It also proves the kit pieces (fade, ring, circle slot, type scale) in Studio.
2. **Scorebug + banner:** already strong; mostly re-skin, plus moving the banner off the crosshair.
3. **Draft:** the biggest screen, lots of dynamic content (cards cloned from templates) and its own art question.
4. Kill feed, death / spectate, match end: not captured yet.

Whichever goes first carries the foundations with it (`UiTemplates`, type scale, `ValidateUi`).

**Picked (2026-11-14): the match top bar.** Draft 1 → [UI Top Bar Draft](UI%20Top%20Bar%20Draft.md).

## 7. Open questions for the owner
1. Where did the button text overflow (screen, button, place)? A screenshot helps.
2. Keep the one-cut plate as the signature shape, or try a slanted tab / faceted frame (Apex / Overwatch style) for the active and selected states?
3. Sarpanch for hero words, or Titillium Web Black for hero numbers (Sarpanch has no italic in Roblox)?
4. OK to publish `UiTemplates` as a Package shared by both places?

---

## Sources
**Roblox docs** (read 2026-11-14):
- [Position and size](https://create.roblox.com/docs/ui/position-and-size): Scale vs Offset, AnchorPoint, ZIndex
- [Size modifiers and constraints](https://create.roblox.com/docs/ui/size-modifiers): UIAspectRatioConstraint, UISizeConstraint, UITextSizeConstraint, UIScale, AutomaticSize
- [List and flex layouts](https://create.roblox.com/docs/ui/list-flex-layouts): UIListLayout flex, UIFlexItem
- [Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers): UICorner (per-corner radii; scale ≥ 0.5 = pill), UIStroke, UIGradient
- [9-slice design](https://create.roblox.com/docs/ui/9-slice)
- [On-screen containers](https://create.roblox.com/docs/ui/on-screen-containers): StarterGui → PlayerGui, ResetOnSpawn, ScreenInsets, DisplayOrder
- [Labels](https://create.roblox.com/docs/ui/labels), [TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel) (TextScaled, TextFits, TextBounds, TextTruncate), [UITextSizeConstraint](https://create.roblox.com/docs/reference/engine/classes/UITextSizeConstraint), [UIPadding](https://create.roblox.com/docs/reference/engine/classes/UIPadding), [TextService](https://create.roblox.com/docs/reference/engine/classes/TextService), [TextTruncate](https://create.roblox.com/docs/reference/engine/enums/TextTruncate), [ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets)
- [Font](https://create.roblox.com/docs/reference/engine/datatypes/Font), [Enum.Font](https://create.roblox.com/docs/reference/engine/enums/Font) (Sarpanch and TitilliumWeb are built in)

The docs don't state the 100 px `TextScaled` cap or that `UIPadding` shrinks the scaling area; both were measured in Studio (above).

**LihFolk** (`vault/LihFolk/05 UI and UX`, `21 LihFolk UI Design System`): ScreenGui Fundamentals (one ScreenGui per screen, DisplayOrder bands, Studio templates cloned by code, WaitForChild + tags), Layout - Scale Offset and Constraints, Text Fonts and Rich Text, Readable Text and UI Scale (minimum sizes, localization headroom), LihFolk UI Spec (button anatomy, spacing 4/8/12/16/24/32), Safe Areas and Insets.
