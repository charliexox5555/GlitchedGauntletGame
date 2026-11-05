# Match HUD v2 (2026-11-05)

The in-match UI now uses the same v2 look as the Lobby ([Lobby UI and Queue](Lobby%20UI%20and%20Queue.md) section 8), so the whole game reads as one product. It covers the score bar, the draft (Mod pick), health and ammo, the ability slots, the kill feed with the ELIMINATED pop-up, and the round and match banners. The v1 layout and behaviour are unchanged ([UI Design](../02%20Art/UI%20Design.md)); only the look and the three bug classes changed.

**Status:**
- Built, checked in a live 1v1 bot match in Studio, and committed in `ade0082`, `41927af` and the reduced-motion commit after them.
- Score: **5.0, capped by the phone gate (below the 8.5 bar).** Desktop and tablet alone score **8.3** (uncapped). The cap stays until the match has a phone layout.
- **This replaces the approved v1 look** (Valorant-style cut corners, Oswald). Approve it or ask for changes; see "Check tonight".

## How it's shared
| Module | What | Used by |
|---|---|---|
| `src/shared/Config/UiStyle.luau` | Every colour, font, size, radius, stroke, shadow and glow, plus the look flags | Lobby (via the `Util/Style` alias) and match |
| `src/shared/UiKit.luau` | Rounded surfaces (UICorner + UIStroke), stacked shadows, lipped gold buttons, glows, tags, key chips, `snapStrokes` | Lobby (`Util/Kit` alias) and match (`Util/Ui`) |
| `src/shared/CoreUi.luau` | Hides chat and the player list while a full-screen screen is open, then restores them | Lobby menus, the match draft |
| `src/shared/Config/Theme.luau` | The match's v1 token names, now **resolving to UiStyle** values (fonts and colours) | Every match builder |

Sharing through `src/shared` was clean:
- Both Rojo projects already sync it to `ReplicatedStorage.Shared`.
- The kit no longer depends on either side's motion module. `breathe(loop)` takes the caller's loop helper.

## What changed
**Bug 1, Roblox top-bar inset:**
- The score bar was in a `IgnoreGuiInset` gui at y 0, inside Roblox's 58 px strip. It now sits in a `CoreUISafeInsets` gui, 8 px under Roblox's bar.
- The draft screen moved into the same safe area so its headings stay under the bar. Its backdrop still reaches up under Roblox's bar, with no gap.

**Bug 2, strokes and corners:** `Util/Ui.cut` (every draft card, button and panel) used to be a cut-corner 9-slice whose outline width changed with `SliceScale`. Now:
- It is a rounded surface with a 2 px `UIStroke`, snapped to whole drawn pixels by `Ui.fit`.
- The three overlapping angled plates of the score bar are now three separate rounded plates, 8 px apart. The ally and enemy plates have a soft team-coloured edge.
- Tags are pills, and the key tabs over the draft columns are rounded.
- Ability slots have a rounded face, border and ready ring. The ready bar is a rounded line under the slot.
- Health and ammo sit on rounded panels with a light edge and a soft shadow, where they used to be fades.
- Kill-feed rows are rounded, with an inset team accent. The ELIMINATED pop-up is a rounded panel.
- Nested shapes follow the radius − gap rule: the draft art is inset 2 px with radius − 2, and glows use radius + 8.
- The v1 card art has the old cut corner baked in. In engine it's cropped past it (`ImageRectOffset` 24 px), so no re-upload was needed.

**Bug 3, chat and player list:**
- In a match, Roblox's player list hides; the team plates already show both teams. The kill feed now has the top-right corner to itself, under the bar at 180 px.
- The chat window moves from the top-left corner (behind the ally plate on 1366-wide screens) to the left middle. That's above health and clear of the bar.
- The draft hides chat while it's open (it would cover the first column) and restores it afterwards. In play, chat was off during the draft and back the moment the draft closed.
- These are flags in `UiStyle.FLAGS`: `matchHidePlayerList`, `matchChatVertical` ("Top" restores Roblox's default) and `hideCoreUiInMenus`.

**Style:**
- Montserrat Heavy for titles and numbers, about 0.8× the v1 Oswald sizes because it's wider. Builder Sans for labels and body.
- The Lobby's navy surfaces and its gold action colour (LOCK IN, upgrade numbers).
- A scan of every visible match label found **no text overflowing its box**, horizontally or vertically, after the font change.

Files:
- `Util/Ui.luau`, `Util/KillFeed.luau`
- `Controllers/DraftController.luau`, `HudController.luau`, `MatchHudController.luau`, `ModHudController.luau`
- `Config/Theme.luau`, plus the shared modules above

Hit markers (`Util/HitFeedback`) are lines and numbers with no panels, so they only took the new colours. Remotes are untouched (UI only).

## Checked
- **Live 1v1 bot match** (`Workspace.BotMatch = "1v1"`, TestMode off): draft rounds 1 and 4 (new cards and upgrade paths), lock in, countdown, live HUD, kill feed and ELIMINATED (driven through the `Killed` remote), ROUND LOST. Output is clean.
- **Layout script** (every HUD cluster's rect, from its gui's insets and Fit scale, against Roblox's buttons, the moved chat window and each other):

| Size | Result |
|---|---|
| 1920 x 1080 | clear (once the kill feed moved to 180 px) |
| 1366 x 768 | clear |
| 1024 x 768 | clear, except the 0.5 s ELIMINATED pop-up can cross an **opened** chat window |
| 667 x 375 phone | the HUD is still the 1080p layout scaled down (no phone layout yet, as in v1); an opened chat covers HUD |

- **Lobby** still boots with the shared modules (top bar, dock and Play menu present, Output clean).

Screenshots are in `vault/02 Art/References/match-ui/v2-20261105/`:
- Before: `before-hud-v1.jpg`, `before-draft-v1.jpg`.
- Design: `figma-match-hud-v2.png` (Figma Screens page, frame "Match v2 · HUD 1920x1080", y 6540).
- After: `after-draft.jpg`, `after-draft-upgrades.jpg`, `after-hud-countdown.jpg`, `after-hud-live-eliminated.jpg`, `after-killfeed-round-lost.jpg`.

LihFolk notes used:
- Safe Areas and Insets, ScreenGui Fundamentals, HUD Design, Layout - Scale Offset and Constraints, UI Motion Language and Timing, Accessibility.
- LihFolk UI Spec: nested radius and lip depth.
- Skills: `roblox-ui-builder` and `quality-score`.

## Scores
Rubric `ui.md` from `lihfolk:quality-score`.

**Round 1** used three blind Sonnet reviewers.
- **All three failed the phone gate**, so the score is capped at **5.0**. On a 667 x 375 phone the 1080p layout scales to about 0.29: LOCK IN and the draft cards fall well under 44 px and the text under 12 px.
- Uncapped they scored 8.3, 7.9 and 7.1. The medians per criterion were U1 1, U2 2, U3 2, U4 1, U5 1, U6 2, which gives 7.1.
- They flagged four things:
  - small secondary labels;
  - world signs showing through the score plates;
  - a "beige" empty ability slot (the viewmodel showing through it);
  - no reduced motion or gamepad in the draft.

**Fix round 1:**
- A drawn text floor of 13 px in `Ui.fit`, re-applied to each new set of draft cards. A scan found no overflow afterwards.
- Opaque score plates and solid empty slots.

**Round 2** used one blind reviewer on desktop and tablet only. Result: **8.3 uncapped**.
- Criteria: U1 2, U2 2, U3 2, U4 1, U5 1, U6 2.
- Its top fix was reduced motion plus bigger secondary labels. Reduced motion is now wired into `Ui.tween` (movement jumps to its end value, fades still ease), but it wasn't re-scored.

**What it takes to pass 8.5:**
1. A phone arrangement for the match: a compact draft (columns you can swipe between, or one column at a time) and a HUD scale floor.
2. Secondary labels at about 15 px with more contrast.
3. Gamepad selection in the draft.

Logged in `.lihfolk/ledger.jsonl`.

## Not done / next
- **A phone layout for the match HUD and draft is the blocker for the 8.5 bar.** It's still the 1080p layout scaled (about 0.29 on an iPhone SE). It needs its own compact arrangement, like the Lobby's phone family.
- Secondary labels at about 15 px; gamepad selection in the draft.
- The gold LOCK IN is a plain gold button, not the Lobby's lipped primary button.
- The enemy ability badges on the draft are still small square icons.

## Check tonight
1. Approve or reject the **v2 look in matches**. It replaces the approved v1 (cut corners, Oswald). One token change in `Config/UiStyle` brings colours or fonts back. Bringing back cut corners would mean a cut-shape kit.
2. Play a bot match (`Workspace.BotMatch = "1v1"`, TestMode off) and check four things:
   - The score bar sits under Roblox's top bar.
   - The player list is gone and chat is at the left middle.
   - Chat hides while you draft.
   - The draft cards and the LOCK IN button look right.
3. Get a kill: you should see the rounded ELIMINATED panel and the kill feed under the bar.
4. Decide whether hiding the player list in matches is right. You'd lose Roblox's per-player list, so you might want a Tab scoreboard of our own. Flag: `matchHidePlayerList`.
5. Save the match place if you're happy. Nothing was changed in Studio by hand; the code comes through Rojo.
