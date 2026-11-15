# Play menu, Party menu and the searching bar (2026-11-15)

Owner's brief (with RIVALS screenshots of its party menu, mode grid and in-queue bar):
- **Party menu** like RIVALS: your party on the left, everyone you can invite on the right with a search box and ALL / FRIENDS / LOBBY filters.
- **Play (queue) menu**: the world blurred behind, a grid of mode tiles. Release has **1v1, 2v2, 3v3** only, but the grid leaves room for more, plus a **Beginner 2v2** section (an easier mode, made later).
- **Searching bar** like RIVALS while queued; **PLAY tweens out and disappears** while queued.
- Fixes: the leaderboard didn't fully hide on big monitors; animations felt glitchy; **no UI sounds** in the lobby; **sound atlases are over** (solo sounds from now on).

## Plan
Same method as the Locker ([UI Locker](UI%20Locker.md)): Studio-built ScreenGuis, scripts only for behaviour, and the Locker's look (Builder Extended ExtraBold, dark navy plates `0B1236` see-through, cyan `3FE0F2` selection with slant ends, white plates for the main action, round close button).

Builder: `tools/studio/BuildLobbyMenus.luau` (Lobby place, Edit mode) makes:
- `StarterGui.PlayMenu` (off; `Controllers/PlayMenuController` opens it as the Router's "Queue" menu, so the world blurs behind).
  - Left: a tall **BEGINNER 2V2** tile, SOON (first plan: a tall RANKED tile on the right and a Beginner section below; changed by the owner, see below).
  - Row 1: **1V1 · 2V2 · 3V3** tiles with the mode art and live "N SEARCHING". Click (or keys 1-3) to queue.
  - Row 2: **4V4 · 5V5** tiles marked SOON (the room for more).
- `StarterGui.LobbySearch`: the searching bar, top centre. It holds the mode circle with a turning ring, SEARCHING FOR PLAYERS, the mode and bot-fill line, the timer and a red cancel button.
- `StarterGui.PartyMenu` (off; `Controllers/PartyMenuController`, Router "Party").
  - Left: YOUR PARTY (3 slots, leader tag), INVITE FRIENDS (Roblox invite prompt) and LEAVE PARTY.
  - Right: search, ALL / FRIENDS / LOBBY, and a grid of player cards with INVITE.
    - Players here get an in-game party invite (`PartyRequest`).
    - Online friends who aren't here get a Roblox game invite (`SocialService:PromptGameInvite` with `InviteUser`).
- `UiTemplates.Lobby.PartyPlayerCard`.

HUD changes (`Util/LobbyHudView`):
- the party **+** opens the Party menu (the old pop-over card is removed);
- PLAY scales out while searching and comes back when idle;
- the hidden player list slides by its real drawn width;
- motion is Quint in and out with no Back overshoot, and presses never snap.

Phones keep the old code-built queue menu (`Controllers/QueueMenu`) until the mobile pass. QueueMenu keeps MATCH FOUND on every device.

Parked (Bugs & Ideas):
- the RIVALS-style **1v1 challenge** button on player cards (needs a private-duel flow);
- **device icons** next to names (a client-reported attribute, cosmetic only).

LihFolk used: `05 UI and UX/UI Motion Language and Timing`, `05 UI and UX/Menu Archetypes`, `49 Roblox Platform Features/Friend Invites Referrals and Experience Invites` (`InviteUser`, `CanSendGameInviteAsync`), `49 Roblox Platform Features/Avatar Context Menus Profiles and Social Surfaces` (`GetFriendsOnlineAsync`, 30 s cache, friend data only to its owner).

## Owner changes during the build
- **BEGINNER 2V2 takes Ranked's place**, as the tall tile on the **far left**; Ranked and the separate Beginner section are out for now.
- **Every close button gets a better look in one theme.** It is now a dark navy circle with a drawn X (two rounded bars, not a font "X"). On hover the circle fills white, the X turns dark and turns a quarter, and a press dips it.
  - Code: `Util/CloseButton` (`make` builds it, `hook` animates it).
  - Used on the Play, Party and Locker menus, the code-built menus (Shop, Battle Pass, Settings, Range, phone queue, via `Util/Menu`), and the red cancel on the searching bar.
  - Not changed: the match's F7 skin-preview panel (a dev tool).

## Results (2026-11-15)
Built and played in the Lobby place (Studio play, desktop 1920x1080):

| Check | Result |
|---|---|
| PLAY → Play menu | Opens over the blur, tiles rise in; the bottom bar steps aside |
| Click 2V2 | Queues, the menu closes, **PLAY scales out**, the searching bar drops in (mode ring turning, `2V2 · BOTS FILL IN 0:01`, timer) |
| Bot fill (Studio 5 s) | MATCH FOUND as before, then back to idle: **PLAY comes back** |
| Party **+** | Opens the Party menu: you in slot 1 (cyan name), 1 / 3, empty slots, INVITE FRIENDS; "NO ONE TO INVITE YET" when alone |
| Leaderboard button / Tab | The list now slides by its drawn width plus 40 px, so it clears the edge at any HUD scale (the old fixed 440 px fell short once big monitors scaled it up) |
| Shop close button | The new drawn X, same corner |
| Console | No errors from our code (an unrelated `rbxassetid://203785492` asset-type warning comes from Studio content) |

Other changes:
- **No UI sounds in the lobby:** `Util/Sound` and every call are gone, and so is the UI SOUNDS setting.
- **Cleaner HUD motion:** Quint in/out, no Back overshoot, presses dip from wherever they are and return to their hover size (they used to snap to 1 first: the "glitchy" jump), and pops start from 0.88-0.9 instead of 0.6.

**Not tested yet:** two players (party invite cards, IN YOUR PARTY, full party), the FRIENDS tab with online friends (needs a live server; `GetFriendsOnlineAsync` may return nothing in Studio), and a monitor bigger than 1080p.

**Art to come:** the BEGINNER 2V2 / 4V4 / 5V5 tiles reuse the 2v2 / 3v3 art dimmed; they need their own art.

## Match found (2026-11-16, owner: "more simple... you don't need to show who's in the match... just a little overlay")
Like RIVALS: when the server finds your match, the screen dims and blurs, and **three white dots** pulse in turn in the middle until the teleport. There are no teams, names, title or countdown.
- `StarterGui.LobbyMatchFound` (builder `tools/studio/BuildMatchFound.luau`, DisplayOrder 40) is wired by `Controllers/MatchFoundController` on every device.
  - It opens on QueueEvent "found" (or a found / teleporting status).
  - It closes when you're idle again.
  - It turns "failed" / "info" into toasts and blocks menus while it's up.
- The player list and topbar leave the screen while it's up (`LobbyHudView.placeCorners`), as they do for a menu.
- Motion (owner: "much smoother"): the dots pop in from their centres (staggered 0.06 s, Quint), then ride **one continuous wave drawn every frame**, with no chained tweens. Each swells to 1.42x and back on a smooth peaked curve over 1.2 s, a third of a cycle after the one before, and the wave fades in over 0.45 s. Sampled in play: the largest change was 0.035 a frame, with no steps. Background blur 20, scrim `08060E` at 0.2.
- Studio only: a small "STUDIO · TELEPORT SKIPPED" under the dots.
- The old MATCH FOUND band (teams, avatars, countdown) is gone from `Controllers/QueueMenu`, which is now only the phone queue menu.
- Checked in Studio play: 1v1 → searching → MATCH FOUND dots (clean screen) → the Studio skip → back to the lobby, with no errors.
- Next (owner): a loading screen in the match place.
