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

## Results
(filled in per screen as it lands)

## Open questions (parked)
- RIVALS pops pages and released buttons with **Back Out** (a small overshoot); our rule is Quint Out with no overshoot, so the page pop here is Quint Out from 0.75. Say if you want the RIVALS overshoot on pages only.
