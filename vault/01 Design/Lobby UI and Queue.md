# Lobby UI and Queue

Lane B of the [Overnight 2026-11-04](../05%20Production/Overnight%202026-11-04.md) plan: the Lobby place's HUD (top bar, bottom bar), the full-screen **Play** menu, a server-authoritative **solo queue** with **bot backfill**, the **teleport** to a reserved Match server, and hooks from lane A's tagged world parts. Code: `src/lobby/**` (Rojo project `lobby.project.json`, port 34873). Image prompts: [Lobby UI Image Prompts](Lobby%20UI%20Image%20Prompts.md).

**Status (2026-11-05, evening):** bug fixes and the v2 style pass are in [section 8](#8-bug-fixes-and-style-pass-v2-2026-11-05-lane-e-lobby-ui-2) (top row in Roblox's top bar, crisp borders, chat and player list kept clear, one theme module; 9.2/10). Earlier the same day: built, playtested in Lobby Studio, then reworked in a **LihFolk review pass** (section 7): a compact arrangement for phones and small screens, safe-area split menus, gamepad selection, motion tokens, reduced motion, a 12+ px text floor, and teleport handling per LihFolk. Measured at 7 screen sizes; **quality score 9.2/10** (3 blind reviewers, median). `rojo build lobby.project.json`, selene and StyLua pass. Not tested: a real teleport (needs published places) and a physical gamepad.

## 1. Research (phase 1)
A Sonnet research pass on RIVALS, Valorant, Overwatch and Fortnite. Web sources on RIVALS' exact HUD were thin (guide sites only), so items marked *unverified* should be checked in the live game.
- **RIVALS:** a big green **Play** button opens a mode menu (1v1, 2v2, 3v3, 4v4, 5v5 duels plus arcade modes; Ranked is a separate page). Shop, rewards and settings sit along the bottom; currency is Keys. A physical **hologram/pads** in the lobby open the same queues. Duels are first to 5. *Unverified:* top-bar contents, button order, the in-queue overlay and the match-found beat.
- **Valorant:** text-first top nav (PLAY, COLLECTION, AGENTS, BATTLEPASS, STORE), mode tabs, a big PLAY button that becomes a searching state with an **elapsed timer and estimate** and a cancel. No accept step (its most criticised gap).
- **Overwatch:** estimated wait per role (players distrust estimates that lie); a persistent "searching" chip you can carry around menus.
- **Fortnite:** cancel is always reachable while matchmaking.
- **Complaints to avoid:** a queue stuck on "Searching" forever with no timeout or message (RIVALS); requirements not shown in the UI; trolls on instant queues.

**What we took:** elapsed time counts **up**, and the "estimate" is honest because it's a bound: **bots fill the empty slots after `botFillAfter`**, shown as a countdown and a progress bar. Cancel is always in the same place. A short, loud **MATCH FOUND** beat with both teams before the teleport. Live "N searching" per mode. Every failure ends in a message and the lobby state, never a hang. The queue follows you: close the menu and a pill at the top keeps the timer and cancel.

## 2. Design
Style: Theme tokens and the cut-corner 9-slice kit from the match HUD (`Config/Theme`, `src/client/Util/Ui.luau`, synced into the lobby as `LobbyClient.SharedUi`), Oswald titles, Montserrat labels, gold as the one "act now" colour, team cyan / orange-red only where teams mean something. Glitch is a 0.16 s cyan/magenta twitch on the PLAY / FIND MATCH hover and on MATCH FOUND, nothing else.

**Figma** ([Game UI file](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN), page Screens, row at y 2600-4480): components **Lobby · Components** (`icon/lobby/*` Shop, Locker, BattlePass, Range, Settings; `Lobby/Tile` with Label + Icon swap; `Lobby/PlayButton`; `Lobby/ModeCard` with Title / Key / Blurb / Meta / Count text and Selected, Two per side, Three per side toggles), and three screens built from them on the Theme variables and text styles: **Lobby · HUD**, **Lobby · Play menu (searching 2v2)**, **Lobby · Match found (2v2, 1 bot)**. The Roblox build follows these layouts px for px (1920 × 1080 design space). Critique from the mockups: the bars need contrast over the bright lobby, so the HUD got soft top/bottom shade gradients.

**HUD (`LobbyHud`)**
- **Top left:** profile card: headshot, display name, `LV 1` and an XP bar (placeholders until progression).
- **Top right:** currency chip (coin, amount, gold "+" → Shop) and a gear (→ Settings; the gear turns 60° on hover).
- **Bottom centre:** LOCKER · SHOP · **PLAY** · BATTLE PASS · RANGE. Side tiles are dark cut cards with vector icons; hover lifts 6 px, lights the fill, grows a gold accent line, sweeps a light band and whitens icon and label; press pops through UIScale. PLAY is gold with a breathing glow; while queued it turns dark with a spinner and shows SEARCHING / mode / elapsed, then MATCH FOUND in green.
- **Searching pill** (top centre, while queued and the Play menu is closed): spinner, SEARCHING · 2V2, "Bots fill in 0:16", the elapsed timer and CANCEL. Clicking it reopens the menu.
- **Toasts** under the top bar for failures (red strip) and info.
- Entrance: bars slide in, tiles rise one by one with a Back ease. Opening any menu slides the bottom bar away; the top bar stays (DisplayOrder 25 over menus at 20).

**Menus (`Router`)**: one at a time. While open: world **blur** (16) and **desaturation** (−0.25), a scrim with top/bottom vignette bands, character controls disabled, the mouse freed (`Modal`). Close with the ✕, gamepad B or Backspace (Esc is Roblox's). Content fades as one CanvasGroup; the header slides in from the left.

**Play menu (`QueueMenu`)**: "PLAY · CASUAL DUELS / CHOOSE YOUR FIGHT"; three cards (1V1 / 2V2 / 3V3) with a colour wash per mode (stand-in for card art), the mode in display type, ally-vs-enemy figures, a one-line pitch, "FIRST TO 5 · N PLAYERS", a live green dot with **N SEARCHING**, and **BOTS AFTER 0:30**. Keys 1 / 2 / 3 select, Enter finds a match. Selected = white outline, raised fill, gold underline; cards rise in staggered on open. **FIND MATCH** (gold, breathing) becomes a status panel while searching: spinner, SEARCHING · MODE, the line "Looking for players · bots fill empty slots in 0:16", a big elapsed timer, a gold bar filling toward bot fill, and CANCEL. Picking another card while searching shows **SWITCH TO 3V3** (the wait restarts).

**Match found (`LobbyMatchFound`)**: a dark band opens from the middle with gold edges; **MATCH FOUND** punches in (1.35 → 1, Back) with the glitch twitch; "2V2 · CASUAL · 1 BOT"; both teams as headshot cards (you in gold, bots as dark BOT slots) popping in; **TELEPORTING IN 3-2-1** with ticks, then TELEPORTING…. In Studio it then shows the exact TeleportData JSON it would have sent. Sounds: LockIn + Banner, Tick / TickFinal, CardIn per slot.

**Other panels (`Panels`)**: same chrome, a believable skeleton with a shimmer, and a gold COMING SOON line: Shop (featured card + 6 items), Battle Pass (tier bar, premium and free tracks), Locker (real gun renders for Primary / Secondary / Melee, click to preview), Settings (a working **UI sounds** toggle; the rest marked SOON), Range (what it will be).

## 3. Queue system (server)
`src/lobby/server/Services/QueueService.luau` (state, remotes), `Matchmaking/Matchmaker.luau` (pure rules), `Matchmaking/Launcher.luau` (reserve + teleport). Numbers: `src/lobby/shared/Config.luau` (`ReplicatedStorage.Lobby.Config`, lobby-only so it isn't in Shared/Config).

| Config | Value | Meaning |
|---|---|---|
| `MODES` | 1v1, 2v2, 3v3 (`teamSize` 1/2/3, `enabled`) | Add 4v4 here later |
| `botFillAfter` / `botFillAfterStudio` | 30 / 5 s | Oldest player's wait before bots fill |
| `matchFoundDelay` | 3.5 s | The MATCH FOUND beat (no cancel) |
| `teleportAttempts`, `retryBackoff` | 4, {1, 2, 4, 8} s | Per-player attempts; backoff after a thrown TeleportAsync (Failure / Flooded results wait 2 / 10 s) |
| `teleportTimeout` | 25 s | Still here after this → back to lobby + message |
| `studioHold` | 6 s | Studio: how long the payload card stays |
| `RATE.QueueRequest` | 2/s, burst 4 | Token bucket |

**Flow**
```
idle ──join(mode)──► searching ──(2×teamSize queued) or (oldest waited botFillAfter)──► found (3.5 s)
  ▲   ◄──leave────────┘                                                                  │ one ReservedServerId (GUID) per match
  │                                                                                      ▼
  └──── failed (message) ◄── reserve fails / TeleportAsync fails ×3 / InitFailed ×3 / timeout ── teleporting ──► Match place
  └──── Studio: log + show TeleportData, back to idle after 6 s
```
- One queue per mode, oldest first. A full match takes the first 2 × teamSize; bot fill takes **everyone waiting** in that mode.
- **Teams:** humans alternate A, B, A, B so real players face each other first; bots fill what's left on each side.
- Players who leave during the beat are dropped; the rest still go (with `bots = true` if the match is now short).
- **TeleportData** (contract in the Overnight note), set with `TeleportOptions:SetTeleportData` on a `TeleportOptions.ReservedServerId` teleport (one GUID per match, kept server-side; `ReserveServerAsync` is deprecated per LihFolk and the docs, so the contract note's "ReservedServerAccessCode" became this; lane C only reads TeleportData, so nothing changes for it): `{ v = 1, matchId, mode, teams = { {userIds}, {userIds} }, bots }`. `bots` is true when fewer than 2 × teamSize humans go. Note for lane C: in bot fill the second team can be an empty array.
- **Failure handling** (LihFolk: Teleporting and Multi-Place Games; Error Handling and Retries): only `TeleportResult.Failure` (retry after 2 s) and `Flooded` (after 10 s) are retried, per player, with the options `TeleportInitFailed` hands back; `GameFull`, `GameEnded`, `GameNotFound` and `Unauthorized` end with a specific message; `IsTeleporting` is ignored. A thrown `TeleportAsync` retries each player with 1, 2, 4, 8 s backoff, up to 4 attempts. A per-attempt deadline (25 s) returns anyone still here; a launch error or a stuck "found" (20 s) returns everyone. Every give-up sets `idle` and sends a "failed" toast.
- **Studio:** `RunService:IsStudio()` skips reserve/teleport, prints `[Queue] STUDIO: would teleport …` with the JSON to Output and shows it on the MATCH FOUND card.

**Remotes and state** (`src/lobby/shared/LobbyNet.luau`, folder `ReplicatedStorage.LobbyRemotes`, separate from the match's `Remotes`)
| Name | Direction | Payload |
|---|---|---|
| `QueueRequest` | client → server | `("join", mode)` or `("leave")` |
| `QueueEvent` | server → one client | `{ kind = "found", mode, teams, teamSize, startsAt }` · `{ kind = "studio", mode, payload }` · `{ kind = "failed", text }` · `{ kind = "info", text }` |
| Player attributes | server-owned | `QueueStatus` (idle / searching / found / teleporting), `QueueMode`, `QueueSince`, `QueueStartsAt` (server time) |
| Folder attributes | server-owned | `Queued1v1`, `Queued2v2`, `Queued3v3`, `BotFillAfter` |

Lane A: world signs ("X queued" per bay) can read `ReplicatedStorage.LobbyRemotes:GetAttribute("Queued2v2")` and listen with `GetAttributeChangedSignal`.

## 4. World hooks
`WorldPrompts` adds a local ProximityPrompt (E / gamepad X, instant) to anything tagged, through CollectionService added/removed signals, so late tags and streamed-in parts work:
| Tag | Opens | Notes |
|---|---|---|
| `LobbyQueue` | Play menu | `Mode` attribute ("1v1" / "2v2" / "3v3") preselects the mode and the prompt says "Queue 2V2" |
| `LobbyShop`, `LobbyBattlePass`, `LobbyLocker` | those panels | |
| `LobbyRangeEntrance` | Range panel (placeholder until the in-place Range teleport exists) | |
| `LobbySpawn` | not hooked (spawning is server/world work) | |
Tagged Models use their PrimaryPart (or first BasePart); big pads get a reach of half their footprint + 6 studs (10-24).
**Checked with lane A's real tags (2026-11-05):** 8 `LobbyQueue` pads (four 1v1, two 2v2, two 3v3; tagged BaseParts such as `Lobby.Hub.Duels.Pad_2v2_AW.QueueZone`) and one part each for Shop, Battle Pass, Locker and Range all got their prompt after streaming in. On the 2v2 pad the prompt read "Queue 2V2 / Duels" (reach 12.5) and E opened the Play menu with 2V2 selected; E at `Market.ShopZone` opened the Shop panel.

## 5. Security notes
- The client can only send `join(mode)` / `leave`. The handler rate-limits first, then checks `typeof(action) == "string"`, mode is a string ≤ 8 chars and in `Config.MODE_BY_ID` with `enabled`. State changes are only legal from the right state (join from idle/searching, leave only while searching), so spamming can't cancel a found match or double-queue.
- Every displayed value (status, timers, counts, teams) comes from server-owned attributes or server events; the client never says who it is matched with.
- `PlayerRemoving` clears the queue entry, state, limiter bucket and any pending teleport.
- **TeleportData isn't secret or tamper-proof** (it travels through the client). The access code to the reserved server is never sent to clients, so only teleported players can join, and the worst a tamperer can do is change their own match's teams. Hardening for ranked: write `{matchId → teams, mode}` to a MemoryStore hash map when the match is formed and have the Match place read it by `matchId` (the Lobby note's original rule "teleport data only carries a match ID").
- Security review: see [Test log](#test-log).

## 6. Later: cross-server matchmaking (MemoryStore)
Today the queue is per Lobby server, which is fine while one lobby holds everyone. When there are several lobby servers:
1. `join` adds `{userId, mode, since, serverJobId}` to a **MemoryStoreService sorted map** per mode (key = userId, sort key = `since`) with a short expiration renewed by a heartbeat, so crashed servers' players vanish.
2. One elected **matchmaker** (a lease key in a MemoryStore hash map, renewed every few seconds; any lobby server can take over) reads the oldest N per mode, applies the same `Matchmaker.pick` rules, removes them atomically (`UpdateAsync`), reserves a Match server and publishes `{matchId, accessCode, teams}` via **MessagingService** (topic per server, or a hash-map entry each server polls).
3. Each lobby server teleports **its own** players with that access code and the same TeleportData. `QueueService`'s state machine and the whole UI stay as they are: only the "queues" table becomes remote. Parties would join as one entry with a size.
Budget: MemoryStore requests scale with players (1000 + 100 × CCU per minute), fine for heartbeats every few seconds.

## 7. LihFolk review pass (2026-11-05)
Read through the `roblox-ui-builder`, `lihfolk-figma` and `quality-score` skills and these vault notes (via `lihfolk-lookup`): **05 UI and UX**: HUD Design, UI Motion Language and Timing, Menu Archetypes, Responsive UI for Phone Tablet Console and PC, Safe Areas and Insets, Gamepad and Console UX, Settings Menu Design, Accessibility; **21 LihFolk UI Design System** (LihFolk UI Spec); **32 Case Studies / Case Study - Rivals**; **41 Multiplayer Services**: Teleporting and Multi-Place Games, Reserved and Private Servers in Practice, TeleportService - Engine Reference Card, Error Handling and Retries, Matchmaking Queues with MemoryStore, MemoryStore Service; **22 Anti-Exploit and Security**: Rate Limiting and Abuse Prevention, Remote Abuse Patterns and Rate Limiting in Practice, False Positives Lag and Fair Enforcement.

| Found missing | Fixed |
|---|---|
| No scale floor: text drew about 5 px on a 667 x 375 phone (Responsive UI; LihFolk UI Spec) | `Util/Layout`: one clamped **Fit** UIScale per cluster (HUD floor 0.76, menus `min(w/1760, h/980)`), and a **text floor**: at least 15 design units and 14 px drawn, counting nested UIScales |
| Bottom bar and Play cards didn't fit a phone | A **compact arrangement** (short side under 640 px: phones and 1024 x 600) on an 800 x 420 canvas: 96 px tiles with short labels ("PASS") clear of the thumbstick and jump zones, a slim profile, the pill under it, the HUD hidden behind menus, 240 x 208 cards with cropped art and no blurb, shorter status line, larger close/cancel/toggles. The family is decided once from the first real viewport (the camera reports a placeholder size at first) |
| `IgnoreGuiInset` menus put buttons under the Roblox top bar (Safe Areas and Insets) | Every menu is two guis: an edge-to-edge dimmer (`ScreenInsets.None`, DisplayOrder 19) and content in `CoreUISafeInsets` (20), `SafeAreaCompatibility = None` |
| No gamepad selection (Gamepad and Console UX) | Each menu content is a `SelectionGroup` with `Stop` on all sides; the Router selects the menu's focus button at the start of its entrance (FIND MATCH or the selected card; Settings' first toggle; else Close) and clears it on close; a shared 3 px gold `SelectionImageObject`; selection uses the hover look; B closes even while a button is selected |
| Motion timings ad hoc and long (UI Motion Language and Timing) | `Fx.MOTION` tokens: press 0.05, hover 0.1, exit 0.12 (Quad In, no overshoot), dimmer 0.18 / 0.12, enter 0.22, reveal 0.4, stagger 0.04; hover 1.04 + 3 px lift, press 0.96, scaled from the centre. The card rise keeps the project's own 48 px / 0.32 s (project notes win) |
| No reduced motion; idle loops always running | `Fx.reduced()` follows `GuiService.ReducedMotionEnabled` and a Settings toggle: movement snaps, fades and colour still ease, loops / sweeps / glitch / shake stop (shake becomes a red flash). Loops pause while their ScreenGui is disabled |
| Small dim text (#69727F, about 3.6:1) | Secondary text uses `textSecondary` (#A7B0BC, about 8:1). Settings toggles show ON / OFF as a word too |
| FIND MATCH could stack requests (Menu Archetypes) | Ignored for 1.5 s or until the server state changes; shows JOINING... |
| ReserveServerAsync deprecated; every TeleportResult retried | See section 3: `ReservedServerId`, retry only Failure / Flooded, final messages, 1-2-4-8 s backoff |
| Rejected remote calls invisible | Dropped and counted by reason (rate / badAction / badMode / unknownMode), a summary warned once per 60 s; never kicks |
| Esc to close (Menu Archetypes) | Not possible: Roblox reserves Esc for its menu. Backspace and gamepad B close instead |

**Measured** (a client script set each cluster to the scale Layout picks for that screen and read drawn text size, `TextFits`, glyph-box clashes between texts, the smallest button, the bar against the thumb zones, HUD cluster overlaps and the menu's footprint in the safe area under the 58 px top bar):
| Screen | Family | Min text | Min tap | Overflow / clashes / overlaps |
|---|---|---|---|---|
| 1920 x 1080 | desktop | 14.2 px | 57 px | none |
| 1600 x 900 | desktop | 13.3 px | 47 px | none |
| 1366 x 768 | desktop | 13.0 px | 46 px | none |
| 1024 x 600 | compact | 18.0 px | 72 px | none |
| 932 x 430 | compact | 13.3 px | 53 px | none |
| 844 x 390 | compact | 13.3 px | 47 px | none |
| 667 x 375 | compact | 13.2 px | 45 px | none (bar 441 of 447 px) |
(Taken with a 13 px floor.) **Round 2, final:** 14 px drawn floor, an 8 px gap under the compact header, no menu can open behind MATCH FOUND, and two label boxes made taller after the measure caught vertical overflow. Re-measured: desktop text min 14.8 / 14.6 / 14.5 px (1920 / 1600 / 1366), compact 18.0 / 14.2 / 14.2 / 14.3 px (1024 / 932 / 844 / 667); no overflow, clashes or overlaps; taps unchanged (45 px minimum).

Bugs this pass caught in play: controllers read the layout family before the camera had its real size (mixed phone constants with desktop scale); phone card positions used the 1920 canvas; the MATCH FOUND band was a fixed 52% (now sized to its content); the larger desktop HUD's profile covered the menu header (now hides behind menus); "N SEARCHING" ran into "BOTS AFTER" (own row now); COMING SOON overlapped its line (auto-layout row).

**Quality score** (`lihfolk:quality-score`, rubric `ui.md`, 3 blind Sonnet reviewers per round, median per criterion): first **8.3** (U3 style 1, U5 readability 1; all gates pass); after one fix round **9.2** (U1 2, U2 2, U3 2, U4 2, U5 1, U6 2; reviewers 8.3 / 9.2 / 9.2). Logged in `.lihfolk/ledger.jsonl`. The remaining U5 point was small secondary text in short windows; round 2 (above) raised the floor to 14 px and opened the compact header gap, measured but not re-scored.

## Image prompts and uploaded art
[Lobby UI Image Prompts](Lobby%20UI%20Image%20Prompts.md). The core chat generated them in ChatGPT (sources in `assets/UI/lobby/`); uploaded to group 11116787 with `tools/opencloud/upload_asset.py --type Decal`. Open Cloud returns the **Decal** id; ImageLabels need the **Image** id inside it (resolved with `InsertService:LoadAsset(decalId)` → `Decal.Texture`). Image ids in use:
| Art | Image id | Used in |
|---|---|---|
| icon_shop / locker / battlepass / range / settings | 134974442051869 / 73637059723267 / 133121960419132 / 82357119585599 / 85379480378289 | `Util/Icons.luau` ASSETS (white, tinted) |
| icon_coin | 122645025340088 | wallet chip |
| mode_1v1_card / 2v2 / 3v3 (cut corner baked in by PIL, 52 px at 2×) | 114141951060405 / 112915965638467 / 124665198768296 | `QueueMenu.luau` MODE_ART, under a dark top shade and a faint mode-colour wash |
Clearing an id falls back to the vector icon / colour wash. The un-cut `mode_*.png` uploads (decals 113115926168704…) are unused.

## Test log
**2026-11-04, Lobby Studio playtest (place 133387545285290, Rojo 34873)**, driven through MCP mouse/keyboard input (no module requires):
- HUD: profile (headshot, name, LV 1), wallet + gear, five bottom tiles with the uploaded icons; entrance animation plays. Output clean (only the known plugin warning 203785492).
- PLAY → Play menu with blur, desaturation, scrim; three art cards, 1V1 preselected, live "N SEARCHING", "BOTS AFTER 0:05" (Studio value).
- Enter → searching: IN QUEUE tag, 1 SEARCHING, timer 0:02, "bots fill empty slots in 0:03", progress bar, CANCEL.
- Backspace → menu closes, searching pill at the top and the SEARCHING play tile keep the timer.
- CANCEL (mouse) → `QueueStatus` idle, `Queued1v1` 0, FIND MATCH back.
- Bot fill after 5 s → MATCH FOUND band: you vs BOT (1v1) and you + 3 BOTs (2v2), countdown, then "STUDIO: TELEPORT SKIPPED" with the JSON. Output: `[Queue] STUDIO: would teleport 1 player(s) to place 71551303511506 with TeleportData {"teams":[[284035946],[]],"bots":true,"mode":"2v2","matchId":"…","v":1}`. Back to idle after 6 s.
- A temporary pad tagged `LobbyQueue` with `Mode = "3v3"` got the prompt "Queue 3V3 / Duels" (reach 10); E opened the menu with 3V3 selected. Pad removed.
- LOCKER → Locker panel with the Vandal / Classic / Knife renders.
- Fixed during the test: the Match Found band was a fixed 540 px (now 52% of the screen); the countdown overwrote the Studio heading; card figures overlapped the art (moved into the dark half) and titles needed a top shade; the pill showed "0" at the end of the countdown; cancel buttons are now named (`…Status.CancelHolder.Cancel`, `LobbyHud.Searching.Pill.CancelHolder.Cancel`) so tests can click them by path.
- Note: Studio `screen_capture` in play mode sometimes returns stale or white 3D frames; check state through attributes, not only screenshots.

**Security review** (roblox-reviewer): no high findings. Fixed all mediums/lows: a launch error or a hung reserve can no longer strand players on "found" (pcall + `foundTimeout` 20 s); teams are split once at MATCH FOUND and leavers are only removed (the screen stays true); one teleport retry path per player with a per-attempt deadline (no double retry, no "failed" while a teleport is in flight); world prompts re-attach when a tagged Model's parts stream in; `LobbyNet` reuses its folder instead of replacing live remotes. For lane C: the match server must check each arriving player's UserId is in `teams` for that `matchId` and not trust `bots` / `mode` blindly.

## Notes for other lanes
- **Lane A:** tag the **BasePart** of each pad/terminal (or set the Model's `ModelStreamingMode` to Atomic/Persistent) so prompts never go missing under streaming. Bay signs can read `ReplicatedStorage.LobbyRemotes` attributes `Queued1v1/2v2/3v3`.
- **Lane C:** in bot fill, `teams[2]` can be an empty array; humans alternate across teams.
- `art-source/uploads.json` holds my 12 upload records but also other lanes' uncommitted entries, so I left it for the core chat to commit.

## What the user should test tomorrow
1. Lobby Studio, Rojo connected on 34873, Play: the bars slide in; hover each tile (lift, sweep, sound) and click each one; Backspace or ✕ closes.
2. PLAY → pick 2V2 → FIND MATCH: the timer counts, bots fill after 5 s in Studio, MATCH FOUND shows you + 3 bots, then the TeleportData card. **Listen** to the sounds (Open, CardIn, LockIn, Banner, Tick); swap any you don't like in `Shared/Config/UiSounds`.
3. Queue, then walk around: the pill stays at the top; CANCEL works there and in the menu.
4. Once lane A's pads are tagged, walk to a 1v1/2v2/3v3 pad and press E: the menu opens on that mode.
5. **Real teleport** (only works in a published game): publish both places, join the Lobby from the Roblox app with a friend or alt, both queue 1v1 → you land in the same reserved Match server. Solo: wait 30 s → you land in a Match server with bots (needs lane C's TeleportData reader).
6. Decide: casual queue name ("CASUAL DUELS"), the 30 s bot fill, and whether humans should be teammates or opponents when bots fill (now opponents).
7. **Phone / small screen:** Studio → Test → Device emulator: iPhone SE (667 x 375) and a notched phone in both landscapes. Expect the compact arrangement: five tiles clear of the stick and jump buttons, the pill under the profile, the HUD hidden behind menus, 240-wide cards. Or set `workspace` attribute `LobbyForceLayout` to `"phone"` / `"desktop"` in Studio (Studio only) to force an arrangement.
8. **Gamepad:** plug one in; open PLAY: FIND MATCH is selected with a gold ring, the D-pad moves between the cards, A presses, B closes.
9. **Reduced motion:** Settings → REDUCED MOTION on: menus fade without sliding, no sweeps or spins.

## 8. Bug fixes and style pass v2 (2026-11-05, lane E `lobby-ui-2`)
Status: **built, checked at 7 sizes, scored 9.2/10 (3 blind reviewers), committed** (`d2335db`, `c5dfdb1`). Not done: Device-emulator screenshots and saving the Lobby place. Both need computer use, which nobody could approve while you were out (see "What the user should check tonight").

### Plan (phase 1)
**The three bugs, found in play (Studio 1539 x 604, `GuiService.TopbarInset` = 208..1539 x 58):**
1. *Top bar ignores the GUI inset:* the HUD's top clusters and its top shade lived in a `CoreUISafeInsets` gui, so the shade started 58 px down with a hard edge, and the profile and wallet floated in a second row under Roblox's bar instead of beside its buttons.
2. *Borders don't line up:* every panel was a 9-slice (`Ui.cut`) whose outline image scaled with `SliceScale = corner / 32`, so outline width changed per element (corners 10-26 → about 1-2.5 px), then went soft under the fractional Fit `UIScale`; `UIStroke`s were 1.5 px; the PLAY / FIND MATCH glows were the same cut shape 16 px larger, so their corners weren't concentric. Tested: `UIScale` does scale `UIStroke` (a 40 px stroke under 0.25 drew 10 px), so strokes can be snapped.
3. *Chat and player list cover items:* the profile (top left) sat under the TextChatService window and the wallet / gear (top right) under the player list; menu headers and close buttons sat in the same corners.

**Fix plan (LihFolk: Safe Areas and Insets; Responsive UI for Phone Tablet Console and PC; ScreenGui Fundamentals; Layout - Scale Offset and Constraints):**
- Top-bar items go **into Roblox's top-bar row**: a `TopbarSafeInsets` gui (the free strip right of Roblox's buttons, which flexes with them), 44 px chips matching Roblox's buttons; when that strip has no height (console), the row drops to the core-UI safe area top with a 12 px margin. Shades move to an edge-to-edge `None` gui.
- Every shape becomes `UICorner` + `UIStroke` (2 px, `Border` mode) from one kit; nested radii follow LihFolk's rule (inner = outer − gap); strokes are snapped to whole drawn pixels per Fit scale (`Layout.snapStrokes`).
- HUD clears chat and the player list by layout: top row in Roblox's bar, everything else on the bottom dock (searching pill above it on desktop, under the top bar on phones where chat and the player list start closed). Full-screen menus hide the chat window and the player list while open and restore them on close (flag `Style.FLAGS.hideCoreUiInMenus`).

**Style pass (designed in Figma first: [Game UI file](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN), page Screens, row y 4700-6440: `Lobby v2 · Tokens`, `Lobby v2 · HUD 1920x1080`, `Lobby v2 · Play menu 1920x1080`, `Lobby v2 · HUD phone 667x375`).** One theme module `src/lobby/client/Util/Style.luau` (every colour, size, radius, stroke, font and flag) and one kit `Util/Kit.luau`. Rounded surfaces with a top-lit gradient and a stacked soft shadow; the gold PLAY / FIND MATCH get a 6 px lip that sinks on press (LihFolk UI Spec: depth is a lip); Montserrat Heavy for display (matches the Lobby's Montserrat Black signs), Builder Sans for labels and body (LihFolk: Gotham is retired and renders as Montserrat); mode colours from the Lobby world pads (1V1 `#FF7A2F`, 2V2 `#27B7FF`, 3V3 `#A15CFF`); full-bleed ChatGPT mode art (the un-cut `mode_*.png`) on the cards.

RIVALS references: a research pass couldn't fetch any screenshot of RIVALS' lobby menus (wiki and guide sites blocked; only store key art, kept locally in `References/lobby-ui/third-party/`, not committed). What we know from text: a green PLAY on the HUD opening a mode list, an "improved top bar and queue UI" in Update 13. So the pass leans on the LihFolk UI Spec and on general RIVALS polish (clean rounded shapes, one loud action colour, bold sans type); **the user should compare it with the live game.**

### What changed (phases 2-3)
**Bug 1, top bar and the GUI inset.** The profile, wallet and settings now sit **in Roblox's top-bar row** beside its buttons. They live in a `LobbyTopBar` gui with `ScreenInsets = TopbarSafeInsets`. The chips are 44 px, like Roblox's own, and they move whenever `GuiService.TopbarInset` changes. With no top bar (console), the row moves to the top of the core-UI safe area with a 12 px margin. The shades moved to an edge-to-edge `LobbyHudShade` gui (`None`), so the hard line 58 px down is gone. Before and after: `before-hud-1539x604.jpg` → `after-hud-desktop-hover.jpg`.

**Bug 2, borders.** The lobby UI no longer uses scaled 9-slices:
- Every shape is a `UICorner` plus a 2 px `UIStroke` (Border mode), built by `Util/Kit`.
- Radii come from tokens and follow the nested rule (inner = outer − gap). The art is inset 2 px and uses radius − 2; the focus ring uses + 4; each glow layer uses + its grow.
- `Layout.snapStrokes` resets each stroke so it draws a **whole number of pixels** at the cluster's Fit scale. I tested that `UIScale` does scale `UIStroke`: a 40 px stroke under a scale of 0.25 drew 10 px.
- The glows are concentric layers, not a larger copy of the shape.

**Bug 3, chat and player list.** Nothing interactive sits below Roblox's top bar on the left or right any more.
- The top row is inside the bar. The dock is at the bottom, and so is the searching pill on desktop.
- Phones have no pill. A phone's chat opens over the top of the screen, so instead a red ✕ badge on PLAY cancels the search (45 px drawn).
- Full-screen menus hide the chat window, chat bar and player list while they're open. On close they restore exactly what was showing before (`Util/CoreUi`, switch `Style.FLAGS.hideCoreUiInMenus`). I verified this in play by reading the `TextChatService` and `StarterGui` state before, during and after.
- Toasts sit above the dock, or at the top while a menu is open.

**Style pass.**
- One theme module, **`src/lobby/client/Util/Style.luau`**, holds every colour, font, type size, radius, stroke, spacing, shadow, glow, dock size and menu size. It also holds three look flags: `hideCoreUiInMenus`, `shadows` and `shine`.
- The builders are in `Util/Kit.luau`. The Play menu and all five panels share the menu chrome in `Util/Menu.luau`.
- Surfaces are rounded, with a top-lit gradient, a light 2 px edge and a stacked soft shadow.
- PLAY and FIND MATCH are gold, with a darker lip that the face sinks into on press and a breathing layered glow.
- Type is Montserrat Heavy for display and Builder Sans for labels and body.
- The mode cards use full-bleed ChatGPT art: the un-cut uploads (image ids 132175332386485, 88838344441665, 91043835690868), cropped to the fighters and faded into the card. Mode colours come from the Lobby's pads.
- Smaller pieces: SELECTED and IN QUEUE pill tags, key-chip hints, and a round close button in the same place on every menu. The Locker marks its selected slot.
- No new images were needed, so I didn't use ChatGPT this pass.
- Motion keeps the existing tokens: press 0.05 s, hover 0.1, exit 0.12 In, enter 0.22, reveal 0.4. Reduced-motion fades and gamepad selection stay as they were. The focus ring now matches each button's corner.

Files:
- New: `Util/Style.luau`, `Util/Kit.luau`, `Util/Menu.luau`, `Util/CoreUi.luau`.
- Rewritten: `Controllers/LobbyHud.luau`.
- Restyled on the kit: `Controllers/QueueMenu.luau`, `Controllers/Panels.luau`.
- Also changed: `Util/Fx.luau`, `Util/Layout.luau`, `Util/Router.luau`.

Server code and remotes are untouched. The client still only sends `join(mode)` / `leave` through `QueueState`, so no new security review was needed.

LihFolk notes used:
- `05 UI and UX`: Safe Areas and Insets; Responsive UI for Phone Tablet Console and PC; ScreenGui Fundamentals; Layout - Scale Offset and Constraints; UI Motion Language and Timing; Menu Archetypes; Gamepad and Console UX; Accessibility; Figma Property Mapping for Roblox UI.
- `21 LihFolk UI Design System` (LihFolk UI Spec): spacing, radii, nested radius, lip depth, text floor.
- `32 Case Studies`: Case Study - Rivals. It has no UI visuals.
- Skills: `roblox-ui-builder` (Gotham is retired; use Builder Sans), `lihfolk-figma` and `quality-score`.

### Measured at 7 sizes
Running the Device Emulator needs computer use, which nobody could approve while you were out. Instead I checked the sizes with a **size harness** in play mode:
1. Clone the live HUD and Play menu into frames of exact device sizes.
2. Draw Roblox's top-bar buttons, chat window and player list where they sit.
3. Apply the Fit scale and text floor that each size would get.
4. Measure by script, in drawn px.

| Size | Family | Buttons | Under Roblox UI / off-screen | Min tap | Min text |
|---|---|---|---|---|---|
| iPhone SE 667 x 375, HUD while queued | phone | 8 | none | 44 px | 14.3 px |
| iPhone SE 667 x 375, Play menu | phone | 6 | none | 45 px | 14.3 px |
| 844 x 390 with chat **and** player list open | phone | 8 | none | 44 px | 14.2 px |
| Tablet 1024 x 768 with chat and player list | desktop | 9 | none | 44 px | 14.3 px |
| Desktop 1920 x 1080 with chat and player list | desktop | 9 | none | 44 px | 15.2 px |
| Console 1920 x 1080, no top bar | desktop | 9 | none | 44 px | 15.2 px |
| Studio window 1539 x 604 (live play, both families) | both | | none seen | | |

The first harness run caught two real bugs, both fixed:
- The phone pill's CANCEL drew 36 px.
- At 844 x 390 with chat and the player list open, the phone pill sat under both.

Screenshots are in `vault/02 Art/References/lobby-ui/20261105/`:
- Before: `before-hud-1539x604.jpg`, `before-hud-2.jpg`.
- Figma: `figma-hud-v2.png`, `figma-play-menu-v2.png`.
- After: `after-hud-desktop-hover.jpg`, `after-hud-phone-family.jpg`, `after-play-desktop.jpg`, `after-play-searching.jpg`, `after-play-phone-family.jpg`, `after-pill.jpg`, `after-match-found-2v2.jpg`, `after-locker.jpg`, `round2-play-searching-phone-family.jpg`, `round2-match-found-3v3.jpg`.
- Sizes: `sizes-iphone-se-and-844.jpg`, `sizes-desktop-tablet-console.jpg`.

The `third-party/` folder next to it holds RIVALS store art for mood only. Don't commit it.

### Style choices to discuss (all in `Util/Style.luau`)
| # | Choice made | Alternatives (cheap to switch) |
|---|---|---|
| 1 | **Rounded shapes** (radius 14-22, pills for chips) with a 2 px white-14% edge | Keep the match HUD's **cut-corner** identity (the Kit shapes would go back to a cut 9-slice at a fixed scale), or sharper 6-8 px radii for a more tactical look |
| 2 | **Gold** `#FFC83D` as the one action colour (PLAY, FIND MATCH, level, coin) | A RIVALS-style **green** PLAY (the `primary*` tokens to the `#3FD68A` family), or the glitch cyan for a sci-fi feel |
| 3 | **Montserrat Heavy** display + **Builder Sans** labels | Oswald (the match HUD's condensed titles) for display, to match in-match UI; or Builder Sans Black everywhere for a Roblox-native feel |
| 4 | **Dark navy glass** panels (`#1C2531` → `#121922`, 6% transparent) with stacked soft shadows | Lighter, more colourful panels (RIVALS' brighter feel), or flat panels with no shadows (`FLAGS.shadows = false`) |
| 5 | Top row **inside Roblox's top bar**; menus **hide chat and the player list** | Keep chat visible in menus (`FLAGS.hideCoreUiInMenus = false`; the menu content would then need to shrink away from the top-left corner), or a separate bar under Roblox's |

### Scores (`lihfolk:quality-score`, rubric `ui.md`)
**Round 1** used three blind Sonnet reviewers, taking the median per criterion. Result: **9.2**.
- Criteria: U1 2, U2 2, U3 2, U4 2, U5 1, U6 2.
- Reviewers' raw scores: 9.2, 8.6 and 8.3.
- Reviewer 3 failed a gate on a stale phone screenshot that still showed the old phone pill. The re-shot harness (current build) shows no pill and no overlap.
- U5 (small grey secondary text) was the lowest criterion for all three reviewers.

**Fix round 1** changes:
- Secondary text is now `#C8D0DB` (about 11:1) and muted text `#A6B0BE` (about 7.5:1).
- The card meta lines use the secondary colour.
- The dock slides away during MATCH FOUND.
- The Locker marks its selected slot.
- The MATCH FOUND band is slightly translucent.

**Round 2** used one blind reviewer. Result: **9.2**, with gates passing and U1 2, U2 2, U3 2, U4 2, U5 1, U6 2.
- The remaining U5 point is phone small caps at 14 px drawn (dock labels, card meta lines). The reviewer wants about 16 px on phones.
- Raising the phone floor to 16 px would overflow the phone card meta lines, so I stopped. Final score: **9.2**.
- The next step, if you want it, is a phone-only 16 px floor with shorter phone strings ("FT5 · 6P", or dropping the meta line). Or honour Roblox's preferred text size (`GuiService.PreferredTextSize`).

Logged in `.lihfolk/ledger.jsonl`.

### What the user should check tonight
1. **Save the Lobby place** (Ctrl+S, Save to Roblox, not Publish). The new client code is in Studio through Rojo 34873, but I couldn't press Ctrl+S without computer use.
2. In Lobby Studio, press Play. The profile, wallet and gear should sit **in Roblox's top bar** next to its buttons. Open the chat and the player list and check that nothing of ours is under them.
3. Hover and click each dock tile and PLAY. You should see the lift, the gold edge, and the gold face sinking into its lip. Open PLAY: the chat and the player list should disappear while the menu is open and come back when you close it.
4. Queue, then close the menu: the pill shows above the dock. When MATCH FOUND appears, the dock slides away.
5. In Test → Device emulator, try **iPhone SE**, an **iPad** and a **1080p TV**. The harness numbers above say everything fits, but please look. On phones there's no pill, just a red ✕ on PLAY while searching.
6. Decide the 5 style choices above, or tell me your own. Each one is a token change.
7. Figma: the v2 frames (Screens page, y 4700-6440) show the design before the build. Since then the phone pill became the ✕ badge and the close / cancel buttons got bigger. The build is now the reference.
