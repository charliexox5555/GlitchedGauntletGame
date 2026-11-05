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
- **Phone layout: built in the afternoon (see "Phone and touch tablets"); the remaining blocker is compact phone draft cards.** It's still the 1080p layout scaled (about 0.29 on an iPhone SE). It needs its own compact arrangement, like the Lobby's phone family.
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

## Phone and touch tablets (2026-11-05, afternoon)
Built on top of the existing mobile input, not a new scheme. `HudController` already had a bottom-right touch layer:
- FIRE, AIM, R, SLIDE, SWAP and RUN;
- `ModHudController`'s ability arc and an ALT button;
- all laid out around Roblox's jump button, and scaled by height / 760 (at least 0.62).

LihFolk used: Responsive UI for Phone Tablet Console and PC, Safe Areas and Insets, HUD Design, Case Study - Phone UI Overhaul (fixed footer, one scroller, "hide, don't shrink"), Debugging UI Layout and Input (Roblox's touch controls take touches in their zones).

**Who gets it:** `Util/Device` decides.
- Phones (short side under 640 px) get the compact arrangement.
- **Touch-only tablets** get it too, because a 1024 x 768 iPad also has a thumbstick and the touch layer in its bottom corners.
- Desktop and touch-plus-keyboard keep the 1080p layout.
- Studio test hooks: `Workspace.ForceLayout = "phone"` and `ForceTouchUI`.

**HUD** (`Controllers/PhoneHudController.luau`, which moves and scales what the other controllers built):
- **Status along the top.** The score bar is centred in the space left of the ability arc (on short phones the arc reaches up beside it). Health sits at the top left, with its HEALTH caption hidden. The kill feed sits beside health and shows its newest 3 rows.
- **Bottom-left quarter clear** for the thumbstick.
- **Ammo** joins the combat cluster in the touch layer's free strip, left of SLIDE. It shows only the count and the mag size (34 px).
- **Q/E/T faces hide** on touch: the touch ability buttons show the same icons and cooldowns. Their hint text stays.
- **Touch buttons are at least 72 design px**, so they draw 45 px at the 0.62 floor. Their labels are 22 px, and SWAP moved up to keep 8 px gaps.

**Draft** on compact screens:
- One vertical scroller for the cards. LOCK IN (45 px), the hint and the enemy kit sit in a fixed footer.
- It **opens on the ability cards**: a gun is preselected, and you scroll up to change it. The score bar steps aside and its clock goes into the footer hint.
- Hints use touch wording, for example "Gun: GHOST (scroll up to change). Tap one card."
- Roblox's touch controls and chat are off while the draft is open, then restored (`Shared/CoreUi`; the Lobby menus get the same).

**Results banners:** full width already; their text gets the 13 px floor.

**Text floor fix found on the way:** on the first frame a gui reports a near-zero size. The floor used to inflate label boxes then (312 px tall) and they never shrank back. It now waits for a real scale and restores the authored heights.

**Measured** with the size harness (the live UI cloned into exact frames, with Roblox's top-bar buttons, the thumbstick quarter, the jump button and the touch layer drawn in). Screenshots:
- `phone-hud-round2.jpg`, `phone-draft-round2.jpg`;
- earlier `phone-hud-se-tall-tablet.jpg`, `phone-draft-se-tall-tablet.jpg`, `phone-hud-se-first-try.jpg`;
- design `figma-phone-hud.png` (Figma Screens page, "Match v2 · Phone HUD / draft 667x375", y 7720).

| Size | HUD | Draft |
|---|---|---|
| iPhone SE 667 x 375 | all panels clear of Roblox UI, jump, touch buttons and the thumbstick quarter; touch min 45 px; text 13+ px; ammo 34 px | taps 45+ px, text 13+ px, no overflow; opens on the ability cards |
| Tall phone 844 x 390 | clear (same checks) | clear |
| Tablet 1024 x 768, touch | clear; touch buttons 72 px | clear; the whole draft fits with a little scroll |

The first harness run caught two real problems, both fixed:
- Touch buttons drew 32-40 px.
- The ability arc reached into the score bar.

**Scores** (`lihfolk:quality-score`, rubric `ui.md`, three blind Sonnet reviewers each round):

| Round | Reviewers | Median | What they flagged |
|---|---|---|---|
| Phone 1 | 6.25, 5.0 (capped), 5.8 | about 5.8 | ability cards below the fold, keyboard hints on touch, small ammo |
| Phone 2, after the fixes | 6.7, 5.0 (capped; 5.8 raw), 6.7 | **6.7** (U1 1, U2 2, U3 2, U4 1, U5 1, U6 1) | card descriptions cut at the fold, "DRAFT AN ABILITY" half cut at 844 x 390, team names struck through by the health bar, unproven motion |

The reviewers mostly fault the draft cards: on a 375 px-tall phone a 540-design-px card can't fit, so its description is cut at the fold.

After round 2 I made three fixes, checked on desktop, **not re-scored**:
- the scroll stop moved up (338 design px);
- the plate names and bars moved apart (names at 8, bars at 46);
- the gun cue went into the hint.

That's the last of the three allowed fix rounds, so the score stops at **6.7, below the 8.5 bar**.

**To pass:** a compact phone card, about 260 design px tall with a short art band and 2-3 description lines, so a whole ability row fits on a 375 px screen. Optionally a tab strip for guns. It needs a new card builder for the phone family; it's the next job.

### Check tonight (phone)
1. In Studio, set `Workspace.ForceLayout = "phone"` and `ForceTouchUI = true` (and `BotMatch = "1v1"`, TestMode off), or use the Device emulator (iPhone SE, a tall phone, an iPad).
2. In the draft: it should open on the ability cards, the gun row should be above, and LOCK IN fixed at the bottom. The thumbstick and jump button should be gone until the draft closes.
3. In a round, check:
   - health and the kill feed at the top left;
   - the score bar left of the ability buttons;
   - ammo above SLIDE / RUN;
   - nothing under the thumbstick or the jump button.
4. Try the touch buttons for size (72 design px now). Say if the layer feels too big on an iPad (it's 1.0x there).
5. **Real phone test** from the Roblox app, since none of this ran on a device.

### Compact phone draft cards (2026-11-05, ~11:15)
Built in `c08bbea` and `79fe1ba`. On compact screens:
- A new-ability card shrinks from 540 to 306 design px. It keeps a 180 px art band with the name and role on it, plus up to 3 description lines ending in "…".
- Upgrade columns always use their short (160 px) cards.
- The MAXED panel gets the same squeeze.
- Holding a card (touch), or right-clicking it, opens a **details sheet** with all of the card's text; tap to close.
- The scroller height follows the real cards, and the draft opens far enough down that the whole ability row is in view.
- The hint names the preselected gun: "Gun: SHERIFF (scroll up to change). Tap a card, hold it for details."

Measured with the harness:

| Size | Ability row at open | Result |
|---|---|---|
| iPhone SE | 70..229 of a 245 px view | fits |
| 844 x 390 | 52..255 of a 259 px view | fits |
| 1024 x 768 | | fits |

At all three sizes text is 13 px or more and there's no overflow. The detail sheet was checked in play.

Screenshots: `phone-draft-compact-cards.jpg`, `phone-detail-sheet.jpg`, `phone-hud-live-forced.jpg`, `figma-phone-compact-card.png` (Figma, Screens page, y 7720).

**Not done:** the re-score with three fresh blind reviewers. It was started but stopped when the usage limit was reached, so the last recorded score is still 6.7 (from before the compact cards). Re-run `lihfolk:quality-score` on the screenshots above.

**Known gap:** a long-press opens the sheet, and releasing it also picks the card.

**Check tonight:** on a phone (or with ForceLayout = "phone" and ForceTouchUI), the draft should open with the full ability row visible. Hold a card: the sheet should show its full text.
