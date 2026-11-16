# UI Lobby Overhaul (2026-11-16)

Owner's brief (pasted 2026-11-16): full overhaul of the lobby UI and every lobby screen on one shared kit, then one consistency pass over the match UI. Same theme (dark, slanted price plates, icon tabs, one-piece chunky plates and cells, Fredoka One), studied against RIVALS' own UI files (read-only) for structure, flow and motion. Work through the whole list, park questions here, hand back at the end. Commit per screen by exact paths, **don't push**.

References: [Rivals Reference → UI and Client](../03%20Research/Rivals%20Reference/UI%20and%20Client.md) (numbers), [UI References](../03%20Research/UI%20References/00%20UI%20References.md) (video study), [Style Bible](Style%20Bible.md) → UI, [UI Theme v4 Soft Edge](UI%20Theme%20v4%20Soft%20Edge.md), [UI Shop](UI%20Shop.md) → Plate look passes 1-6 (the chunky look this builds on), screen notes ([Lobby HUD](UI%20Lobby%20HUD.md), [Play and Party](UI%20Play%20and%20Party%20Menus.md), [Locker](UI%20Locker.md), [Battle Pass](UI%20Battle%20Pass.md), [Notifications](UI%20Notifications.md)). LihFolk `05 UI and UX` (Menu Archetypes, UI Motion Language and Timing, Safe Areas and Insets, Responsive UI).

## What RIVALS does (studied in its file, 2026-11-16)
- **Layout:** each cluster is a full-screen frame with a 1:1 aspect constraint, so its contents size from the screen's short side (`size = 0.075 scale + 40 px` of that square). Our equivalent: one `Fit` UIScale per cluster (Util/Layout). Kept.
- **Pages:** live outside the gui until opened, one at a time (PageSystem), open from 0.75 scale. Every page gives a close request and a default gamepad element.
- **Buttons:** ImageButtons with `Background`, `Shine` (the top half) and `Icon` children; hover 1.125, press 0.875, Quint Out 0.25 s, scale from the centre.
- **Settings page:** tab row on top, the settings list on the left half, an **Inspect** panel on the right that explains the selected setting, a close button.
- **Profile (ViewProfile):** one card: headshot, display name, @username, most-played weapons, Casual / Ranked stat blocks, buttons Close / Challenge / Invite.
- **Rewards page:** a list of reward rows (join group, invite, favourite, like, codes, notifications), each with its claim state.

## Plan (in order)
1. **System.** `Config/UiStyle.KIT` (lobby colour, text and motion tokens); `Util/Motion` (button hover 1.125 / press 0.875 at 0.25 s Quint Out, page open from 0.75 scale, pops from the centre, reduced motion = fades); `Util/Kit` (plate, cell, tab, icon button, price plate, close X, list slot, page frame) on top of `Plates`, `Cards`, `Pivot`, `CloseButton`; `Router` = the page router (one page, back / B closes, gamepad focus, blur 24 faded in, the page pop). Move every screen's own hover / press / pop helpers onto it and delete them.
2. **Lobby main HUD:** profile, currency, bottom icon bar, PLAY + party slots, player list, notifications.
3. **Play / queue / party:** mode tiles, searching bar, party menu + invites, MATCH FOUND, a teleport / loading screen.
4. **Locker, Shop, Season Pass:** finish their look; UI-only where the economy is missing, said on screen.
5. **Missing screens:** Settings (with a crosshair editor from `Config/Crosshair`), Profile / stats, an Inbox / Rewards stub.
6. **Phones:** every screen at 375 x 812 and a tablet; touch targets ≥ 44 px; safe areas; nothing clipped.
7. **Match UI consistency pass:** same kit, tokens and motion; no redesign unless something breaks the system.

## Rules kept (memory + brief)
Dark look; slanted price plates; icon tabs; one-piece plates and cells; Fredoka One. No pills, decorative outlines, glows, thin strips, rounded "AI" boxes, generic fonts, bright flat restyle. Quint Out, no overshoot; pops from the centre; list items = fixed holder + centred UIScale; no UI sounds; one drawn-X close. "Looks AI" = missing art: new art goes through the [ChatGPT art brief](UI%20Art%20Brief%20(ChatGPT).md).

## Results (2026-11-16)
Commits (local, **not pushed**): `3d15cc12` system, `61af1dbe` HUD, `465082f4` play / party / loading, `d48986a4` Settings, `7f064199` Profile + Rewards, `700e11e7` phones, `325ae5c7` match motion. Captures in [Overhaul/](Overhaul/).

### 1. System
- **`Shared/UiMotion`** (lobby and match): one tween (Quint Out), `rest` / `press` with RIVALS' beats (buttons hover **1.125**, press **0.875**; cards and tiles 1.04 / 0.96, since 1.125 would cover their neighbours), `nudge`, `slideIn`, `popIn`, `pageIn` (from **0.75**), `button`, one reduced-motion switch (`Fx` and Settings use it). Numbers in **`Config/UiStyle.KIT`** with the lobby's colour and font tokens.
- **`Util/LobbyKit`**: plate, cell, button, tabs, price, close, slot / clearSlots (RIVALS' Slot pattern), **page** (a Router page: blur, wash, the 0.75 pop, back / B closes, gamepad focus, phone regions). The new screens are built on it.
- **Router**: blur **24**, faded in over 0.5 s (RIVALS: 24).
- Moved over: every lobby screen's own `tween` / `press` / `rest` / `nudge` copies (Shop, Locker, Season Pass, Play, Party, MATCH FOUND, the HUD view) now call `UiMotion`; `Fx` (the code-built menus) reads the same numbers; every **overshoot (Back) ease removed** (owner rule), in the lobby and in the match pass below.
- Grade **9**. Weak: the Studio builders still each carry their own small helpers (`make`, `slant`, `drawX`); folding them into one builder kit is a cleanup for later.

### 2. Lobby HUD ([before](Overhaul/hud_before.jpg) / [after](Overhaul/hud_after.jpg))
- **Coins top-middle on the HUD** (your "like rivals does with its keys"); they hide while another page is open and show in the Shop. They read 0 until the economy.
- **No lobby words under 12 px** (`LobbyLook` text floor): the player list's STREAK / LV / IN LOBBY were drawn at 8-10 px.
- A **gift button** in the top bar opens Rewards; a **player-list row** opens that player's Profile.
- The top-left profile chip stays out (you removed it on 2026-11-14). Grade **8.5**: the gift icon is drawn from shapes until real art.

### 3. Play / queue / party ([party](Overhaul/party.jpg), [loading](Overhaul/loading.jpg))
- Every flat text button gets the chunky **bevel** (INVITE, INVITE FRIENDS, LEAVE, VIEW, BACK, ACCEPT / DECLINE, the queue's cancel); the search box and the **searching bar** get the cell look.
- **Teleport / loading screen**: MATCH FOUND fills `StarterGui.LobbyLoading` (the mode as the hero word over the mode's own tile art, LOADING MATCH, the three dots, a tip from `Config/Loading`) and hands it to `TeleportService:SetTeleportGui`; the match place's new ReplicatedFirst script (`src/first/LoadingScreen.client.luau`, mapped in `default.project.json`) keeps it up, pulses the dots and fades it out once the match and your character are in (12 s cap). No logo yet (none exists). Grade **9** (not seen in a real teleport yet).
- Grades: mode tiles 9, Party 8.5, MATCH FOUND 9 (unchanged).

### 4. Locker, Shop, Season Pass
- On the shared motion (hover / press numbers above); everything else from today's plate passes stands ([UI Shop](UI%20Shop.md) → passes 1-6). UI-only parts already say so on screen (SOON toasts, claims on screen only, the coin note). Grades **8.5-9**. Weak: the Season Pass's empty free cells read bare.

### 5. New screens
- **Settings** ([crosshair tab](Overhaul/settings_crosshair.jpg)), RIVALS' layout: GENERAL / CROSSHAIR tabs, the list, an INSPECT panel that explains the row you point at. GENERAL: reduced motion (live); camera sensitivity and FOV say SOON. CROSSHAIR: size, colour, length, thickness, gap, centre dot, outline, X shape, static, show while aiming, over a copy of `Config/Crosshair` with a **live preview**. Choices last the session (saving: question 3). Replaces the old code-built Settings panel. Grade **9**.
- **Profile** ([own card](Overhaul/profile.jpg)): portrait, names, LV and STREAK plates, the **skins you have on with their emblems**, match stats as SOON; INVITE TO PARTY (the same validated `PartyRequest` the player list uses) or OPEN LOCKER on your own card. Grade **8.5** (stats wait for data).
- **Rewards** ([page](Overhaul/rewards.jpg)): favourite the game / invite a friend / turn on notifications open **Roblox's own prompts**; join the group, like and codes are SOON; coin amounts (`lobby/shared/RewardsCatalog`) wait for the economy, and the page says so. No remotes. Grade **8.5**.

### 6. Phones ([Settings, forced phone layout](Overhaul/phone_settings.jpg))
- Measured first: every Studio-built page drew at **0.35 on a 812 x 375 phone** (4-9 px words, 19-31 px buttons). Pages now take a **phone region** (`LobbyKit.page`): the phone shows part of the canvas zoomed to fill the screen, and the controller moves its pieces in. **Settings** (~0.78: 20 px words, 70 px rows, INSPECT hidden), **Rewards** (~0.65, scrolling list, 46 px GO), **Profile** (~0.63, compact card, 49 px button). Checked with Studio's `LobbyForceLayout = "phone"` (this Studio can't run at a real phone size).
- **Not done, grade 5:** on phones the HUD, Shop, Season Pass, Play and Party are still the **old code-built v2 versions** (rounded pills: `Controllers/LobbyHud`, `Panels`, `QueueMenu`), and that HUD has no way into Profile or Rewards. Tablets (1024 x 768) use the desktop pages at ~0.53: buttons pass 44 px, but the smallest words land near 7 px. This is the biggest piece left (question 5).

### 7. Match consistency pass
- Top bar, combat HUD, draft, death card and match end now use `Shared/UiMotion`; their 17 overshoot pops are Quint now. **Skipped** because other lanes have uncommitted edits in them: `KillFeed`, `StatusTray`, `HudController`. Fonts unchanged (question 4). Built with Rojo and linted; **not played** (the match Studio isn't on Rojo here). Grade **8**.

## Test list for you
1. **Save both places.** Lobby: the new `Settings`, `Profile`, `Rewards` and `LobbyLoading` guis, the top bar's gift button, the templates, Fredoka at Regular. Match: connect Rojo once so the new `ReplicatedFirst.Loading` script syncs.
2. Lobby, any page: buttons grow 1.125 and dip 0.875, cards 1.04; pages open from 0.75 with the blur; Backspace or gamepad B closes.
3. HUD: the coins sit top-middle and leave when a page opens (they stay for the Shop); the gift opens Rewards; clicking your row (or anyone's) opens their Profile.
4. Profile: on someone else's card, INVITE TO PARTY sends the invite (the button reads INVITE SENT); on your card, OPEN LOCKER.
5. Settings: reduced motion on / off; every crosshair control and the live preview.
6. Rewards (published game): the three GO buttons open Roblox's prompts.
7. Live: queue, MATCH FOUND, then the loading screen through the teleport, fading out in the match.
8. A match: the top bar, draft, death card and match end pop in with no overshoot.
9. Phone (Studio device emulator, 812 x 375): Settings, Rewards and Profile.

## Open questions (parked)
1. RIVALS pops pages and released buttons with **Back Out** (a small overshoot); our rule is Quint Out with no overshoot, so the page pop here is Quint Out from 0.75. Say if you want the RIVALS overshoot on pages only.
2. **Profile on the HUD:** you removed the top-left profile chip (2026-11-14), so Profile opens from the player list. Want a HUD button for it?
3. **Saving settings** (crosshair, later sensitivity / FOV): needs a profile DataStore and the match's crosshair reading it (another lane owns the match crosshair). Go ahead?
4. **Match font:** Fredoka One in the match too? You chose Builder Extended for the top bar's numbers on 2026-11-14; the swap is one command, in place, like the lobby's.
5. **Phones:** move the phone HUD and the phone Shop / Season Pass / Play / Party / Locker onto the kit (separate phone arrangements, like RIVALS' mobile place). Next phase?
6. **Art** (the "looks AI = missing art" rule): a gift / inbox icon, settings tab icons, a logo for the loading screen. Add them to the [ChatGPT art brief](UI%20Art%20Brief%20(ChatGPT).md)?
7. **Rewards:** which group to join, whether "like" can count (Roblox gives no like event), and a codes system.
8. The match files skipped while other lanes edit them (`KillFeed`, `StatusTray`, `HudController`) move onto `UiMotion` once that work lands.
