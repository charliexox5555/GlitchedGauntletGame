# Performance and Loading Audit (2026-11-26)

Owner report (phone, live): very laggy on joining a match, stuck on the map-vote screen, and the live error "Exponential deferred event growth detected for Object.AbsoluteSizeChanged when calling fitShadow on line 278 in ...Controllers.TopBarController". That line is *after* the 2026-11-25 rounding fix, so that fix was live and the loop was still running.

Method: Studio Play with the phone layout (`ForceLayout = "phone"` and `BotMatch` **through `Shared.StateValues`**, not as plain attributes: plain attributes do nothing, so the 2026-11-25 "phone" test was really desktop), plus three read-only code audits: per-frame client cost, UI feedback loops, and the loading path from join to first fight.

## Root cause of the phone lag: two writers on one UIScale

`Shared/UiLayout` owns every UIScale named `Fit` unless it has `CustomFit` / `Retired` (or its parent has `FitCanvas`), and writes its own value back whenever the scale changes. `TopBarController.refit` also wrote `TopBar.Root.Fit`, from the bar's size (phone-aware, so it clears Roblox's buttons). On a phone the two values differ (1.386 vs 0.893), so each wrote over the other on every bar resize: an endless loop that starves a phone's frame budget from the vote screen to the end of the match.

- Studio, phone layout, with the old ownership: **202 scale writes in 3 s**. With the fix: **2**.
- Fix: `TopBarController` sets `CustomFit` on its Fit; `UiLayout.watch`'s Scale listener re-checks `ownedFit` before writing (so a controller that claims a scale after mount is never overwritten).

## Fixed in this pass

| Area | Change | Why |
|---|---|---|
| TopBar | `CustomFit`; UiLayout re-checks ownership | The live loop above |
| StatusTray | `CustomFit` (it owns its scale and places the tray from it) | UiLayout overwrote it: tray small and misplaced on phones |
| BottomHud | dropped its own Fit writer (UiLayout owns: no 0.6 floor) | One-frame flash every resize |
| BottomHud | `setHealth` returns when the screen is disabled (touch) | ~40 property writes a frame for a hidden HUD on phones |
| StateValues | `get` caches folder and field per owner (checked against Parent), and "not tagged" per owner | Hundreds of calls a frame, each 2 FindFirstChild + HasTag |
| WeaponController | own third-person gun hidden from a cached part list, write only on change | Was GetDescendants of 3 models every frame |
| InputController | `init` waits 10 s in total (was forever for PlayContext, then 10 s per missing action, in a row) | Every later controller's start (and the vote) waits on it |

Verified: stylua / selene 0/0 / rojo build; Studio phone-layout bot match: vote → draft → live, shots, own gun hidden, status tray scale held (1.43, CustomFit), no script errors, 4.2 ms frames (PC).

## Loading path (join → first fight), what's slow on a phone

1. The whole map replicates twice on a match server: Arena loads at boot, then the voted map replaces it as `Persistent` (whole model to every client) while the phase is still `Vote`, so a phone sits on the vote screen until it has downloaded. (`MatchService.loop` ~1680, `MapService.loadMap` ~106.)
2. `MatchReady` is the last step of a serial bootstrap: 49 controller requires, every `init()` in order, the MapVote clone, `game.Loaded`, a 6 s map poll. One slow phone holds a multi-player lobby up to `READY_TIMEOUT` (12 s).
3. The loading screen waits up to 4 s for equipped skins.
4. `Workspace.StreamingIntegrityMode = PauseOutsideLoadedArea`: a phone slow to stream freezes its own character (plus FloorHold up to 15 s).
5. Two blurs at once on the vote (loading blur fading + vote blur).

## Backlog, ranked (not done yet)

1. **Vote → map swap:** set the phase (e.g. a short "Loading" step or straight to Draft) before `loadMap`, so the vote screen closes; or skip loading Arena at boot. Needs client handling for a new phase.
2. **Fire `MatchReady` early** from a tiny module before the other controllers; build MapVote cards lazily; drop the 6 s map poll.
3. **Stage the bootstrap:** require/init only what the vote and draft need first; defer Replay, Spectate, MatchEnd, ModFx, MapLife, SkinPreview.
4. **Per-frame:** BodySkin bends every limb of every character every frame (cull by distance / off-screen, 15 Hz mid-range); TpIk has no distance culling; ModFeel / StimFx / FrostFx / Frozen / Dash / DashGhost / Footstep each poll every character every frame with their own arrays (one shared fighter list a frame, or change-driven); ModHud builds strings and finds labels every frame; ModFx loops all placed Mod objects every frame; StatusTray allocates every frame.
5. **Mobile GPU suspects (measure):** full-screen CanvasGroup low-HP vignette written every frame; Beginner highlights pulsing every frame.
6. **UI suspects (Studio attributes):** MatchHud band, TopBar clock, TouchLayout and LobbyHudView vs UiLayout `Phone*`/`Base*` overrides (wrong final value, not loops); Lobby `Plates.fitWidth` can grow if content is Scale-sized; DevMod panel scale needs a tolerance.
7. Loading screen: wait only for your own skins in a match; close it once the vote screen is mounted; no stacked blurs on phones.

Not a bug: aim assist resets its raycast filter per ray on purpose (`BallisticGlass` adds broken panes to it).

To confirm the backlog items on real hardware: a phone join with the MicroProfiler and network stats (map send size, the client-side gap from `Vote` to `Draft`).
