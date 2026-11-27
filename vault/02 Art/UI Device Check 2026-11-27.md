# UI device check (2026-11-27)

Workstream 4 of [Launch Hardening 2026-11-27](../05%20Production/Launch%20Hardening%202026-11-27.md). Owner (phone): "the settings button and also the top bar button overlapped with the look of the scoreboard at the top". 81% of players are on mobile. Rules: [UI Architecture](../04%20Tech/UI%20Architecture.md) §4-7, `gauntlet-ui-style` §5.

## How it was checked
- **Live playtests** in Studio's Device Emulator:
  - iPhone 7 (667x375);
  - iPhone 13 (844x390, notch);
  - iPhone 17 Pro (874x402, notch, a 749x381 safe area);
  - iPad 6th gen (1024x768);
  - HD 1080.
  - Everything ran in a 3v3 bot match (the widest scorebug), using the Studio switch `Workspace.HostedTest = "3v3"`, plus the lobby.
- **Measured** with [`tools/studio/UiOverlapCheck.luau`](../../tools/studio/UiOverlapCheck.luau), pasted into the Client datamodel.
  - It lists overlaps between buttons of different screens, the scorebug and Roblox's own top-bar buttons.
  - It also lists clipped text and text drawn under 12 px.
- **Roblox's top bar isn't in `screen_capture`** (it's core UI). Full-window screenshots of Studio show it, which is how the row-under-the-menu-bar bug was found.
- **Captures** are local only, in `art-source/ui/device-check-2026-11-27/`, because they show Roblox's top bar and Studio test UI. That folder is in `.gitignore`.
  - Before: `01`, `02` (iPhone 13 with Roblox's bar, our row behind its menu bar), `11` (Locker).
  - After: `03`-`08` (match), `09` (lobby), `10` (Shop), `12` (Locker).

## Findings and fixes
| # | Where | Found (measured) | Fix |
|---|---|---|---|
| 1 | Match scorebug, phones | It reserved a fixed `0.46 × height` on each side. Roblox's buttons end at x 208, and Settings sat at x 220-264, inside the bar (the owner's report). The weapon slots took the top-right too | `TopBarController` measures its neighbours each 0.5 s: Roblox's buttons (`TopbarInset`), our Settings/Leave, the touch weapon slots and the scoreboard row. It shrinks to fit, centred. Under 80% size or 30 px it moves under Roblox's row |
| 2 | Settings on touch | It sat in the top row next to Roblox's buttons | It joins the scoreboard/inspect row under Roblox's buttons (`MatchSettingsButton`), so the top row is Roblox, the scorebug and the weapon slots only |
| 3 | Scoreboard/inspect row | After a device change it sat ~27 px high, behind Roblox's expanded menu bar (iPhone 13). `TouchLayout.base` resized TopLeft, then read its stale `AbsoluteSize` | The row is placed again on TopLeft's `AbsoluteSize` change. A saved custom spot (`TLCustom`) still wins |
| 4 | Scorebug LV chips | They drew at 5-6 px on phones and 11 px (clipped) at 1080p | 14 px design; hidden when they would draw under 12 px |
| 5 | Scorebug round line | 10.5 px on an iPad | Hidden under 12 px, as it already was on phones |
| 6 | Kill feed, phones | 9-10 px text (row `ScreenScale` PhoneBoost 2) | Studio template `UI.Templates.KillFeed.Row.ScreenScale` PhoneBoost **2.5** (≈12 px at 381 tall) |
| 7 | Round banner (Notify), phones | At y 18% it covered a 3v3 scorebug that had moved under Roblox's row (bottom ≈ 25%) | Studio template `UI.Match.Notify.Root` PhonePosition y **0.27** |
| 8 | Locker v3, notched phones | The gun list ran under the notch (x -62), and the loadout card sat under Roblox's buttons | `fit()` keeps the panels in the device safe area. The left column starts under Roblox's buttons (scaled 0.37 → 0.33 on a 401 px phone), and the title slides clear. Desktop unchanged |
| 9 | Locker v3, touch | A second finger made the card jump | Only the first finger turns it |

**Scorebug result:**
- 1v1 and 2v2 stay in the top row on phones.
- On a phone, 3v3 moves under Roblox's row: 0.35 scale on an iPhone 7 (clock about 11 px), 0.43 on an iPhone 13.
- Tablet and desktop stay in the top row, and desktop is unchanged (scale 1).

**Overlaps after the fixes:** 0 at every size (the Studio-only GUNS / TEST / SKINS / ADMIN / RANGE buttons aren't counted).

## Controller
- **Every lobby page now keeps the selection inside it.** LobbyKit pages (Settings, Profile, Rewards, Backpack, Loadout, StreakSave, NPC talk) now pass their screen to the Router. Before, only the Shop, Battle Pass, Locker, Party and Play did.
- **B steps back before it closes** (`Router` menu `back`):
  - Locker v3: confirm, then the skin strip, then the Locker.
  - The confirm window traps the selection and starts on UNLOCK.
  - The right stick turns the card or gun.
- **Draft:** the selection starts on the first card when a controller is the active input (`InputMode`, so FORCE CONTROLS counts), and also when one is picked up mid-draft.
- **Checked live:** gamepad B closes the Shop. The Shop's selection lands on a case.
- **Not checked live:** the draft and the Locker on a real pad. Studio's MCP keyboard tool sends keyboard input (`GamepadEnabled` stays false). The controller emulator needs clicking through its panel, which didn't fit the shared Studio slot.

## UI instance count per player (loading pass, routed from loading-perf)
[Loading and Performance 2026-11-27 → Routed](../04%20Tech/Loading%20and%20Performance%202026-11-27.md) measured about 8,500 PlayerGui instances per player, even on match servers.

**Where they came from:**
- **StarterGui** held two screens, and Roblox copies StarterGui to every player on every server:
  - `LockerV2`: 603 instances, unused since `LOCKER_V3 = true`;
  - `LockerV3`: 523 instances, run only on lobby servers.
- **`LockerV3Room`** (963 instances, 3,000 studs out) was Persistent, so every client got it.
- **`UI.Mockups`** (TouchMockup, 186 instances, read by no code) shipped in every client's PlayerScripts.
- **Admin and dev screens** (AdminPanelGui ~2,740, ModDevPanel, WeaponPicker) are built only for admins. They inflate Studio counts but don't reach players.

**Changes (Studio edits: save the place):**
- `StarterGui.LockerV2` and `UI.Mockups` moved to `ServerStorage.UiArchive`. That's reversible, and nothing in it reaches clients. StarterGui is now empty.
- `StarterGui.LockerV3` moved to `UI.Lobby.LockerV3`, so `Shared/UiRoot` mounts it on lobby servers only. Its `Fit` scales are marked `CustomFit` (in the template and by `LockerV3Controller`), so `UiLayout` leaves them to the Locker's `fit()`.
- `LockerV3Room.ModelStreamingMode` is now **PersistentPerPlayer**. `LockerService` adds lobby players 3 s after they join, so match servers never send it.

**Measured (Studio, desktop, player-facing PlayerGui = everything but the admin and dev screens):**

| Server | Before | After | Also |
|---|---|---|---|
| Match (`ServerRole = Match`, 1v1 bots) | ≈ 2,585 (the after count + LockerV2 603 + LockerV3 523) | **1,459** (24 screens) | Room 963 → **0** on the client. PlayerScripts −186 |
| Lobby | ≈ 6,884 (the after count + LockerV2 603) | **6,281** (32 screens) | Room still sent, 3 s after join (the Locker needs it). PlayerScripts 5,831 |

**Checked after the move:** the Locker v3 opens with its stage on the lobby.

### Pass 2: lobby-only home and lazy pages (2026-11-27)

**Lobby-only home:**
- 20 lobby-only screens moved in Studio from `StarterPlayerScripts.UI.Lobby` to **`ServerStorage.LobbyUI`** (3,746 instances): Shop, Locker(V3), Battle Pass, LobbyBar, LobbyCoins, Play, Party and the rest.
- **Only a lobby server** parents that folder into ReplicatedStorage, at boot (`LobbyServer` init). It also sets the ReplicatedStorage attribute `LobbyUI = "ready" | "none"`, so a client never waits on a folder that won't come.
- `UI.Lobby` keeps what match clients use: Settings, LobbyTasks and TouchEditor.
- `Shared/UiRoot` reads both homes.
- To edit these screens in Studio, `tools/studio/UiEdit.luau` parks and stores screens from either home, and `UiDeviceSheet` finds them too.
- **Rebuild scripts:** the old `tools/studio/Build*.luau` scripts still write to `UI.Lobby`. After rebuilding a lobby-only screen, move it to `ServerStorage.LobbyUI`.

**Lazy pages (`UiRoot.LAZY`):**
- The Shop and Battle Pass aren't copied into PlayerGui at join. Each controller builds its page on first open, or when the bar's button is hovered (`Router.warm`).
- The Shop's coin counter (LobbyCoins) stays live from join.
- The Battle Pass keeps its season-state hooks at join, and its page wiring is one `build()` function to extend.
- With `Release.BATTLE_PASS_OPEN` off, its page is never built.

**Measured (Studio, HD 1080, admin and dev screens left out):**

| | Before (after pass 1) | After |
|---|---|---|
| Lobby, PlayerGui at join | 6,281 | **3,091** (the Shop adds ~2,250 on first open) |
| Lobby, PlayerScripts | 5,831 | **2,085** |
| Match, PlayerScripts | 5,656 | **1,910** |
| Match, PlayerGui | 1,459 | 1,605 (round-phase screens; no lobby UI) |
| Match, ReplicatedStorage | — | `LobbyUI` not sent (3,746) |

**Checked live:**
- **Desktop:** the Shop builds and opens on first use; the Backpack opens.
- **Phone (iPhone 17 Pro, notch):** the Shop, the Battle Pass (Studio switch `BattlePassTest`) and the Locker v3 open, with the safe-area layout.
- **Match server:** Settings opens (F10), with no lobby UI sent.

**Owner:** save the place. The folder moves are Studio edits.

**Not done:** ~~lazy Shop / Battle Pass~~ and ~~UI.Lobby templates on match clients~~ are done above. The Templates folder (426 instances, shared by match and lobby rows) still ships to everyone.

## Still open
- **Small lobby text on phones:** LobbyTasks 5 px, LobbyBar labels and the LobbyPlayerList at 6 px (749x381). The lobby HUD's Fit and PhoneBoost need a per-screen phone pass, which is design work.
- **BottomHud key chips at 1080p:** 9-11 px.
- **3v3 scorebug on an iPhone 7:** about 0.35 scale. If that reads small on a real phone, hide the headshots below a size on phones.
- **Not covered this pass:** the SURGE pack popup and world-space opening, the Backpack, Rewards, death screen, match end and loading screen on phones. They were checked in parts 4-6 of UI Architecture, but not re-captured. Loading belongs to the loading-perf session.
- **Owner:** save the place (two Studio template edits: the KillFeed PhoneBoost and the Notify PhonePosition), then play once on a real phone and with a pad.

## Wave 2: code-audit fixes in the UI (2026-11-27)
Routed from [Code Audit 2026-11-27](../04%20Tech/Code%20Audit%202026-11-27.md) → mobile-ui and the client P3 perf list.

**Bugs:**
- **P2, the Locker vs a pad duel:** a duel (or the range) that started with the Locker open showed the lobby HUD over the duel 0.3 s later. The Locker's close wipe re-enabled the screens it had hidden, which ArmedHide never tracked. After restoring them, the Locker now calls `ArmedHideController.refresh()`, which takes them over while armed.
- **ShopDisplays:** a ShopBoard missing a part is skipped with a warning, so it doesn't stop the other boards, and each board mounts in its own thread (no chain of 5 s waits).
- **Shop:** the bundle "separately" `Amount` label is guarded.

**Template waits:** `Shared/Util/UiWait.child` waits up to 10 s, then raises "<path> is missing (Studio template)".
- **Used in:** KillFeed, MatchHud (Notify), Scoreboard, TopBar, MatchEndScreen, StatusTray, Shop `child()` and StreakSave.
- **Kill feed, round banner and status tray** bind under `pcall`: a missing part leaves that screen off with a warning instead of hanging it.
- **StatusTray** checks its entry template once at bind, so nothing yields in the render step.
- **Not changed:** `Util/WaitGui` waits for a whole screen to be mounted on purpose (a late first spawn).

**Per frame (measured in Studio where it could be):**

| Where | Before | After |
|---|---|---|
| BottomHud health panel (desktop, every frame) | 10.0 µs a frame, ~40 writes | **0.83 µs at rest** (an early return; it still animates on a hit or at low health) |
| LobbyGunDisplays (lobby spawn view) | 9 gun pivots a frame (in range) | **0** (only on-screen guns turn, and none under a menu) |
| StatusTray | icon, text, colour and 24 segments written every frame per entry, plus a new table a frame | writes only changes; the table is reused |
| ModHud | 3 `ModInfo` tables a frame | 1 reused per slot |
| PadDuelController | `GetTagged` every 0.1 s | waits for each pad's `PadMode` once |
| CaseShow | no cap on other players' openings | at most `MAX_ONLOOKER_SHOWS` = 2, one per player |
| Locker POWERS | grid rebuilt (~20 clones) on every save change | rebuilt only when the owned set changes |

**Not a bug:** the audit's "Shop and Locker buttons overlap" at 1919 wide. For a new player Shop is hidden, and `layoutBar` only moves visible buttons, so the hidden Shop kept an old spot over the Locker. A click there hits the Locker, which is correct.
