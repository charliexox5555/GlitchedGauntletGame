# UI architecture: one structure for every device (plan, 2026-11-22)

**Status (2026-11-22):** owner approved the recommended answers. **Steps 1-2 done** (§10): every screen and template now lives in `StarterPlayerScripts.UI`, loaded by `Shared/UiRoot`; tested in a Lobby playtest (lobby HUD and menus) and the range (match screens). **Save the Lobby place.** Next: step 3, the responsive pass, and the mobile controls mockup.
**Goal (owner, 2026-11-22):** a full UI pass for every device and layout. Remove the old UI and code, move everything to one structure, make the layout and text scale on phone, tablet, PC and console, ignore the inset on phones where a full-screen look helps, and design new mobile controls ([UI Mobile Controls](../02%20Art/UI%20Mobile%20Controls.md)).

Sources: code audit of `src/` (2026-11-22), Studio read of the merged place and of the RIVALS client ([Rivals Mobile UI → Studio read](../03%20Research/UI%20References/Rivals%20Mobile%20UI.md), [RIVALS UI and Client](../03%20Research/Rivals%20Reference/UI%20and%20Client.md)), [UI Overhaul Research](../02%20Art/UI%20Overhaul%20Research.md) §3-5 (measured text tests), LihFolk `05 UI and UX` (ScreenGui Fundamentals, Layout - Scale Offset and Constraints, Safe Areas and Insets, Readable Text and UI Scale, Responsive UI for Phone Tablet Console and PC, Mobile Button Layout Editor, Input - UserInputService and ContextActionService).

---

## 1. Where we are (audit, 2026-11-22)

**The UI is already mostly Studio-built, not code-built.** It is stored in three places:

| Where | What | Bound by |
|---|---|---|
| `StarterGui` (place file) | 20 lobby screens: LobbyBar, LobbyTopbar, PlayMenu, PartyMenu, Shop, BattlePass, Locker, Settings, Profile, Rewards, Backpack, NpcTalk, LobbyMatchFound, LobbySearch, LobbyCoins, LobbyLoading, LobbyToast, LobbyPlayerList, LobbyTasks, **LobbyHudMockup (unused)** | `lobby/Util/LobbyHudView` + one lobby controller per screen |
| `ReplicatedStorage.MatchScreens` | 10 match screens: TopBar, BottomHud, DraftScreen, KillFeed, DeathScreen, MatchEndScreen, StatusTray, Scoreboard, MapVote, Notify | `shared/MatchScreens.install` → match controllers |
| `ReplicatedStorage.UiTemplates` | rows and cells (Lobby, KillFeed, TopBar, MatchEnd, MapVote, Status, Scoreboard, Replay). (First read as duplicates of the match screens; checked: they are the row templates those screens clone.) | the same controllers |

**Still built in code:** CombatHud and the touch buttons (`HudController`), ModHud and the Mod touch arc (`ModHudController`), Replay, Spectate, WinCutscene, ModFeel, NetStats, the full-screen ability effects (13 ScreenGuis), LobbyHudShade, LockerWipe, CaseFlash.

**Old UI that only phones still use** (the Studio screens were never laid out for phones):
- `lobby/Controllers/QueueMenu` (754 lines, old Play menu v2)
- `lobby/Controllers/Panels` (346): placeholder Shop and Battle Pass. Its Range panel runs on every device.
- `lobby/Controllers/LobbyHud`: the v2 dock, top row, pill and toast
- `lobby/Util/Menu` (171): chrome for those menus
- the phone halves of `DraftController` (1,794 lines in total), `MatchEndController` and `SpectateController` (the old bar)
- `client/Util/KillFeed` (407): **still live**: HudController builds it and it plays the kill sounds, the kill banner and the assist popup. It goes with the combat HUD rebuild (step 3), not in the cleanup.
- `MatchHudController`'s hidden old top bar: only its sounds are still used (goes with the combat HUD rebuild)

**Duplicates and drift:**
- Two theme modules: `Config/Theme` (v1, about 16 users) on top of `Config/UiStyle` (v2).
- Two builder kits: `client/Util/Ui` (v1) and `shared/UiKit` (v2), plus 7-line aliases `lobby/Util/Kit`, `Style` and `CoreUi`.
- Two motion modules: `lobby/Util/Fx` and `shared/UiMotion`.
- Two device rules: `client/Util/Device` and `lobby/Util/Layout` (both: short side < 640 = phone).
- `NetStatsController` and `SoundAuditionController` exist in both client trees.
- Fonts set in code: BuilderSans, Gotham, RobotoMono, Arcade, Code, Sarpanch, Titillium. Only `UiStyle` tokens should set fonts.
- ~~Bug: Rewards waits 15 s on phones~~ Not a bug: phones also got the (disabled) Studio `LobbyTopbar`, so the wait returns at once.

**Devices today:** phone vs desktop by size only. No tablet or console family, `PreferredInput` isn't used, and there is no custom thumbstick or jump button. The touch buttons are text labels (FIRE, AIM, R, SLIDE, SWAP, RUN).

## 2. What RIVALS does (read from their client, numbers in the research note)
- **Nothing in StarterGui** (only a Studio dev gui). All UI is a template library in `StarterPlayerScripts.UserInterface` (~200 templates, 38 pages). One controller builds `MainGui` at runtime, and each screen or slot has a matching module.
- **A few big ScreenGuis, not one per screen:** `MainGui` (ScreenInsets None + IgnoreGuiInset, holds HUD, pages, lobby and mobile inputs), `InsetGui` (TopbarSafeInsets, their buttons in Roblox's top-bar row), `TeleportingGui` (None, on top).
- **Scale almost everywhere:** 2,199 Scale-sized vs 55 Offset-sized objects, 109 `UIAspectRatioConstraint`s, `TextScaled` on 292 of 293 labels, and a single `UIScale`. Only the touch buttons are pixel-sized, because the editor saves pixels.

## 3. Decision 1: where the UI lives (recommended)
**Studio-built templates, bound by code. Not all-code, and nothing in StarterGui.**
- All code: every look change needs a code change, the owner can't edit in Explorer, and it is why we have 600+ `fromOffset` calls. Studio-only: lists and live data still need code. **Hybrid** is what RIVALS and LihFolk both use: Studio owns the layout and look; code sets `Text`, `Image`, `Visible`, attributes, clones list rows, and runs motion. Scripts never set Position, Size, colours or fonts on static layout.
- **One home:** `StarterPlayer.StarterPlayerScripts.UI` (client-only, like RIVALS; a Studio-owned folder next to Rojo's `Client` / `LobbyClient`; Rojo ignores unknown children there because that node has no `$path`. Check this on the first `rojo serve`.)
  - **Changed 2026-11-27 (loading pass):** lobby-only screens live in `ServerStorage.LobbyUI`. Only a lobby server hands them to its clients, so match servers never send them. The Shop and Battle Pass build on first open (`UiRoot.LAZY`). See [UI Device Check → Pass 2](../02%20Art/UI%20Device%20Check%202026-11-27.md#pass-2-lobby-only-home-and-lazy-pages-2026-11-27).
  ```
  StarterPlayerScripts.UI
    Screens/      one ScreenGui per screen (Lobby*, Match*, Menus, Modals)
    Templates/    rows, cells, slots, buttons (one copy each; the duplicates go)
    Touch/        the touch-control screen and button template
  ```
- **One loader** (`client/Ui/UiRoot`, Rojo-owned): clones a screen into PlayerGui when it is first needed, applies its layer (§4), and gives screen modules a typed handle. It replaces `MatchScreens.install` and the "turn the lobby screens off in a match server" code.
- **Editing in Studio:** a ScreenGui only draws in the edit viewport when it is under StarterGui. A command-bar tool `tools/studio/UiEdit.luau` moves a named screen to StarterGui to edit and back to `UI/Screens` when done. The loader warns if a screen is left in StarterGui.
- **Backups:** after changes, export the `UI` folder to `art-source/ui/UI.rbxmx` (XML, diffable) and save the place, the same as the guns.

## 4. Decision 2: layers and insets (the phone "full screen" rule)
Each screen carries a `Layer` attribute; the loader sets these:

| Layer | ScreenInsets | DisplayOrder | Use |
|---|---|---|---|
| Backdrop | **None** (edge to edge, under the notch) | 0-9 | dims, blur, HUD fades, scope, hit vignettes, ability screens, menu backgrounds |
| Hud | DeviceSafeInsets | 10 | combat HUD, lobby HUD |
| Touch | DeviceSafeInsets | 15 | joystick, buttons, double-tap zone |
| Menu | DeviceSafeInsets | 20 | Play, Shop, Locker, Settings… |
| Topbar | TopbarSafeInsets | 30 | our buttons in Roblox's top-bar row |
| Modal | DeviceSafeInsets | 40 | match found, confirm, rewards |
| Overlay | **None** | 50 | loading, teleport, transitions, toasts |

All of them: `IgnoreGuiInset = true`, `ResetOnSpawn = false`, `SafeAreaCompatibility = None`, `ZIndexBehavior = Sibling`.
- **The phone full-screen look:** art and backgrounds bleed to every edge (None). Things you press stay out of the notch and home bar (DeviceSafeInsets) but use the top-bar row's height. Only the **Roblox buttons' rectangle** is kept clear, read live from `GuiService.TopbarInset` (never a hard-coded 58 px). On a phone the right half of the top row is free, which is where RIVALS puts its weapon slots.

## 5. Decision 3: layout rules (Scale where it matters, Offset only for hairlines)
1. **Place with Scale + AnchorPoint** on the nearest corner or edge (top-right cluster: anchor (1, 0)).
2. **Size controls by screen height:** buttons, plates, circles and cards use `SizeConstraint = RelativeYY` (both axes follow the screen height) plus a `UIAspectRatioConstraint` for non-square ones. A button stays the same shape on 16:9, 19.5:9 and 4:3. Full-width bands and panels use plain Scale.
3. **Inside components: Scale.** Offset only for 1-2 px strokes, hairlines and the 9-slice cut.
4. **Clamp:** a `UISizeConstraint` minimum on anything you press (44 px), and a maximum on TV / 4K so nothing gets silly.
5. **Phone sizing:** phones show the same screens with their own sizes. An element can carry `PhoneSize` / `PhonePosition` attributes (UDim2); the loader applies them on the phone family. Screens that really differ (HUD, Play menu, Draft) get a `Phone` variant frame instead.
6. **Motion** never tweens Size or Position on layout: pops use an inner `UIScale` (memory `ui-scale-pivot`), entries use a `UIScale` or a `CanvasGroup` fade.

## 6. Decision 4: text that scales on every device
- `TextScaled = true` + `UITextSizeConstraint` on every label (RIVALS: 292 of 293 labels are scaled). **The box height sets the size**, so labels with equal box heights draw at equal sizes (no mixed sizes in a row). Changing numbers (ammo, timer, coins) get a box wide enough for the longest value, so height limits them and they don't jump.
- **Floors (drawn px):** phone 12 (labels) / 14 (body), desktop 14, TV 18. Set as `MinTextSize`. MaxTextSize = the 1080p token × 1.25.
- Keep one line on buttons: padded height < 2 × MinTextSize (measured rule, [UI Overhaul Research §5](../02%20Art/UI%20Overhaul%20Research.md)).
- Paragraphs: `TextScaled` + `TextWrapped` in a box sized for the longest copy + 30% headroom (other languages run longer).
- Fonts only from `UiStyle` tokens (the house font, Rubik per the Style Bible). Remove Gotham, BuilderSans, Arcade and Code.

## 7. Devices and input
- **Layout family** (by size, from `ViewportDisplaySize` + viewport): `phone` (short side < 640), `tablet` (touch, short side ≥ 640), `desktop`, `tv` (gamepad + 10-foot). One shared `Device` module replaces `client/Util/Device` and `lobby/Util/Layout`.
- **Input** separately, from `UserInputService.PreferredInput` (Touch / KeyboardAndMouse / Gamepad), live. A tablet with a keyboard switches to KBM hints without changing layout.
- **Test sizes (Device Emulator):** 1920×1080, 1366×768, 1024×768 (iPad), 932×430, 844×390 (notched), 667×375 (worst case), TV 1920×1080 + Controller Emulator. Plus `tools/studio/UiDeviceSheet.luau`: draws every screen at those sizes side by side in one capture, so a pass can be checked in one look before the owner uses the real emulator and a real phone.
- `tools/studio/ValidateUi.luau`: off-token fonts and colours, Offset sizes outside hairlines, `TextScaled` without a constraint, text under the floor at 667×375, touch targets < 44 px, overlaps, pills.

## 8. Owner questions (answer before the build)
1. **Home:** `StarterPlayerScripts.UI` (like RIVALS, needs the UiEdit toggle to edit) or keep editing in StarterGui? Recommended: StarterPlayerScripts.
2. **Old phone UI:** delete it now (phones show the desktop screens, broken, until the phone pass reaches each screen) or delete each piece as its phone layout lands? Recommended: as each phone layout lands, in one sprint.
3. **Mobile controls:** see the questions in [UI Mobile Controls](../02%20Art/UI%20Mobile%20Controls.md).

## 9. Build order (after answers)
1. **Clean (safe now):**
   - delete LobbyHudMockup, the duplicate UiTemplates copies, and the second NetStats and SoundAudition controllers
   - move the KillFeed / MatchHud sounds into `UiSfx`, then delete the old KillFeed util and the hidden top bar
   - fold `Theme` into `UiStyle`, `client/Util/Ui` into `UiKit`, `Fx` into `UiMotion`, and `Device` + `Layout` into one module; remove the aliases
   - fix the RewardsController wait
2. **Structure:** the `UI` folder, `UiRoot` + layers, `UiEdit`, and moving the screens (StarterGui + MatchScreens + UiTemplates → `UI`). Check the lobby and a match in a playtest.
3. **Responsive pass, screen by screen:** apply §5-6, check the device sheet, add the phone variant, then delete that screen's old phone code. Order: lobby HUD + Play/Party → combat HUD + touch → Draft → Match end / death / spectate → Shop / Locker / Battle Pass / Settings → the rest.
4. **Mobile controls** (v1 built 2026-11-22, waiting on the owner's phone playtest): build to the approved mockup v2 and replace `HudController`'s and `ModHudController`'s touch code ([UI Mobile Controls](../02%20Art/UI%20Mobile%20Controls.md) §7).
5. **Input prompts that follow the device and the keybinds** (owner, 2026-11-22). Every place that shows a key or button reads it live:
   - One `InputGlyphs` module: action → the binding for the current input (`UserInputService.PreferredInput`) → a key label (PC) or a gamepad glyph. Use `UserInputService:GetImageForKeyCode`, which gives the right Xbox or PlayStation picture. Touch shows no glyph.
   - Saved keybinds (Settings → KEYBINDS, saved in `PlayerDataV1` but not applied yet) must be applied to the `PlayContext` bindings (server builds it, client too). Every hint re-reads when they change.
   - RIVALS-style hint spots: L1 / R1 beside the weapon slots, a key-hint row under them (Emote, Scoreboard, Quick Melee, Quick Utility), and lobby buttons with their glyph (Play = X, party + = Y, the lobby bar on the D-pad).
6. **Controller support** (owner: "full customization for controller support"):
   - **TV-safe padding:** on the gamepad / TV family, the HUD root gets about 3-5% padding on every edge. RIVALS pads its HUD corners on console because TVs crop the picture edge (overscan / title-safe area).
   - Gamepad focus paths in every menu (`GuiService.SelectedObject`, NextSelection; check with `rbx-gamepad-focus-paths`).
   - Rebindable gamepad buttons in Settings.
7. **Touch layout editor** (after the controls ship; RIVALS' editor read in [Rivals Mobile UI](../03%20Research/UI%20References/Rivals%20Mobile%20UI.md) → Studio read):
   - drag, resize, per-button opacity, hide (not Fire / Jump), 3 profiles, reset, left-handed mirror
   - saved as fractions of the safe area plus size as a share of the screen height, server-validated through `SettingsService`

## 10. Results

### Steps 1-2 (2026-11-22)
- **Studio (Lobby place, unsaved until the owner saves):**
  - `StarterPlayer.StarterPlayerScripts.UI` now holds `Lobby` (19 ScreenGuis from StarterGui), `Match` (the 10 from `ReplicatedStorage.MatchScreens`) and `Templates` (was `ReplicatedStorage.UiTemplates`).
  - StarterGui is empty. `MatchScreens` was removed, and the unused `LobbyHudMockup` deleted (rebuildable with `tools/studio/BuildLobbyHudMockup.luau`).
- **Code:**
  - `Shared/UiRoot` (mount, source, templates, layers) replaces `Shared/MatchScreens`. 17 files now read templates through it.
  - The lobby client mounts `Lobby` on lobby servers; on match servers it returns at once (the "turn off StarterGui copies" code is gone). The match client mounts `Match`.
  - `NetStats.mount` reuses a live copy, so the lobby and an armed zone no longer draw two readouts.
  - `tools/studio/UiEdit.luau` parks a screen (or `Templates`) in StarterGui to edit and stores it back.
- **Tested:** Lobby playtest (19 screens mounted, HUD, player list, Shop, Locker, Settings, Party, Backpack bound, no new errors) and the range (each match screen once, BottomHud bound, one NetStats). A full match server wasn't run; it uses the same mount path.
- **Not changed (on purpose):**
  - No screen has a `Layer` attribute yet, so nothing looks different. Layers go on screen by screen in step 3.
  - `Theme` / `Ui` v1 kit / `Fx` / `Device` + `Layout` fold into one as their screens are rebuilt; folding them before that would be throwaway work.
  - The `tools/studio/Build*.luau` builders still write to the old homes (StarterGui, MatchScreens, UiTemplates). After running one, move its output into `UI` (or park and store it with UiEdit).
  - `selene src` reports one error from before this change: `Content` is undefined at `PlayMenuController:219`.

### Device pass, parts 1-3 (2026-11-22, after the owner's phone review)
Owner list: the old phone HUD, kill feed, draft, spectate and ability hints are still old UI; Auto Sprint should hide Sprint; Inspect sat mid-screen; fire and look at once; kill feed on the right; NetStats crowds the corner; buttons need a highlight; ADS only on guns that aim (Classic keeps it as its right click); scope not round on phones; text spills out of boxes (Round · Match Point); damage, cutscene bars and other overlays must cover the whole phone; Shop, Settings etc. go off phone screens; content overlaps Roblox's buttons, but blurred and dimmed backdrops should still cover them.

**How layout works now** (`Shared/UiLayout`, applied by `UiRoot.mount`):
- **Device families:** Phone, Tablet, Desktop and Console, from size, touch and `PreferredInput`. Studio: `Workspace.GauntletState.ForceLayout` / `ForceTouchUI` StringValues.
- **Per-device overrides** live as attributes on the same screen (`PhonePosition`, `PhoneSize`, `PhoneScale`, `PhoneVisible`, `PhoneAnchorPoint`, and the same for Tablet and Console), so they can be edited in Studio.
- **Three ways a screen scales:**
  - **Scale screens** (`tools/studio/modules/UiToScale`, for fixed layouts): every size and position is Scale; the groups on the screen get a FitWithinMaxSize aspect constraint; text is `TextScaled` with a max of the design size and a min of 11. Used by: KillFeed, Notify.
  - **Fit canvases** (`UiFitCanvas`, for content-sized HUD screens): the 1080p pixel design stays on a canvas that always covers the screen; the canvas's groups sit on Scale positions; Fit = min(W/1920, H/1080) × `<Family>Boost`. Used by: DeathScreen (phone 1.7×), MatchEndScreen, DraftScreen, Scoreboard, MapVote.
  - **Every other `Fit` UIScale** (lobby menus and HUD clusters) is owned by UiLayout: min(W/1920, (H − top bar)/1080) × boost, with **no floor**. The old 0.5-0.6 floor is what pushed menus off phones. UiLayout overrides any old controller code that still writes Fit.
- **Rows that size to their content** (kill feed rows) carry a `ScreenScale` UIScale (screen height / 1080 × `<Family>Boost`).
- **`AvoidTopbar` and `FullBleed`:** menu content stays under Roblox's top-bar buttons; the backdrops (Wash, Scrim, Dim) are separate full-screen layers.
- **Full-screen code-built overlays** use `ScreenInsets.None`, `SafeAreaCompatibility.None` and `ClipToDeviceSafeArea = false`: the low-HP and hit vignettes, all ability screens, replay bars, spectate fade and win cutscene.
- **Preview:** `UiDeviceSheet` draws a screen at a device size with that family's overrides. Studio tools are installed as ModuleScripts in `ServerStorage.UiTools`; the repo copies are in `tools/studio/modules`.

**Moved to the Studio screens on phones; old code deleted:**
- The kill feed: the Studio screen everywhere, on the right on phones at 2×. Util/KillFeed is now just the kill sounds.
- TopBar (phone fit rule; its info line hidden on phones).
- Notify (Scale, below the weapon slots on phones).
- StatusTray (ability hints and status; ModHud's old hint and status line drop out).
- DeathScreen + spectate (the old spectate bar is deleted).
- MatchEndScreen and DraftScreen (the old code-built Draft and MatchEnd are deleted, about 1,600 lines).
- Scoreboard (touch hold-to-show button).
- MapVote.
- PhoneHudController and HudController's v1 health and ammo panels are deleted.
- BottomHud is off while touch controls show.

**Touch:**
- Buttons don't take touches, so the camera turns while holding Fire or a Mod.
- Touch circles are 20% bigger than the drawn buttons.
- A held button lights up.
- The stick follows the thumb.
- Aim is hidden on `noAds` guns, and is an alt-fire hold on Classic and Knife.
- Sprint is hidden while Auto Sprint (Settings, default on) is on.
- The Inspect row is placed from `TopbarInset`, which is the free space between Roblox's buttons.
- The controls hide while you're dead or spectating.
- NetStats is hidden on phones.

**Scope:** the surround is a mask texture (`Config/Scope.MASK`, `tools/ui/make_scope_mask.py`) plus four black frames, instead of a 4000 px UIStroke.

**Still to do / known:**
- ~~Lobby phones on old code-built UI~~ Done (part 4): phones use the Studio lobby HUD and every menu. QueueMenu, Util/Layout, LobbyHud's v2 dock, Panels' placeholder Shop / Season Pass, the LobbyKit phone specs and all controller Fit code are deleted. ModHud's old slot faces, hint and status line are deleted too (the Recon charge meter stays, in its own small ScreenGui).
- The last code-built lobby menu is Panels' **Range** placeholder ("COMING SOON", opened by the bar's Range button and the range entrance prompt). Its text is out of date now the range hall exists; it should become a Studio screen or open the real range.
- Menu open / close no longer pops the Fit scale (UiLayout owns it); the wash fade remains. A pop on an inner UIScale can come back per menu.
- Dense menus (Draft, MatchEnd, Shop, Settings) fit on phones now, but at 1080p proportions the text is small. They need phone-specific positions and boosts per screen, tuned in the Device Emulator or on a phone.
- ModHud still builds its old slot faces (always hidden now) and the Recon charge meter in code; no Studio replacement for the meter yet.
- "Controls don't feel smooth": the stick-follow and look-through are in; touch camera sensitivity and aim assist come after the owner's playtest.

### Part 5 (2026-11-22 overnight): phone fixes, key hints, controller, keybinds

From the owner's phone test: stuck or unresponsive buttons, inspect and tab rows too low, LOCK IN showing "ENTER" on a phone, and the match end too small.

**Touch fixes (TouchController):**
- **Hit-testing** now uses `PlayerGui:GetGuiObjectsAtPosition`, which uses the same coordinates as the touches. A button from another screen drawn on top blocks the touch. The `processed` check is gone: Roblox marks touches over our non-interactable buttons as processed, and that ate presses.
- **Focus loss:** when the window loses focus, every held button and the stick are released, so nothing stays stuck.
- **The real cause of "too low":** `GuiService.TopbarInset` is in screen pixels, but `AbsolutePosition` is measured from below Roblox's 58 px bar. The scoreboard and inspect row was a whole bar lower than intended. It's converted with `GetGuiInset` now, so the row's top sits 4 px under Roblox's buttons.
- **Test tools:** the GUNS, TEST and SKINS buttons (Studio and test mode only, code-built) used to cover the knife and fire buttons on a phone. They now form a row under the scoreboard and inspect pair. SKINS drops its `[;]` key there.

**Key hints follow the device (`Shared/InputGlyphs`, new):**
- **Tagging:** a key chip in a Studio screen carries `KeyAction` (an input action, e.g. `Mod1`), or `KeyText` (a keyboard-only shortcut such as `ENTER`) plus an optional `KeyGamepad` (a KeyCode name).
- **By input:** on keyboard the chip shows the key, on a gamepad the button glyph (`GetImageForKeyCode`, so Xbox and PlayStation each get their own), on touch nothing. `UiRoot.mount` watches every screen.
- **Who uses it:** the BottomHud hints and the draft's LOCK IN and column chips go through it. Screens that switch a chip themselves ask `InputGlyphs.shows(chip)` first.
- **Tagged in Studio:**
  - Draft: Gun 1-3, columns Q/E/T, LOCK IN.
  - MatchEnd: PLAY AGAIN, REMATCH.
  - Play menu: modes 1/2/3.
  - BottomHud: Mods, Loadout, Hints.
- **Gamepad shortcuts:**
  - Draft: X locks in (the D-pad moves between cards, A picks).
  - Match end: X is PLAY AGAIN, Y is REMATCH.

**Match end on phones:**
- **Size:** canvas `PhoneBoost` is 1.6 and `TabletBoost` 1.15.
- **Position:** `Right` has PhonePosition (0.969, 0.935), so its bottom lines up with the cards.
- **Code fix:** the winner cards had a fixed y of 1036 design px and fell off a boosted (shorter) canvas. They now sit `CARD_LIFT` above the canvas bottom and stop at the right column wherever it is.
- **Checked:** in the phone emulator (749×381) with 4 winners. Every number and label is readable, and nothing overlaps.

**Controller (Console family, `Shared/UiLayout`):**
- **TV-safe margin:** important UI stays out of the outer 5% (`CONSOLE_SAFE`, from LihFolk *Gamepad and Console UX* and RIVALS' padded HUD corners).
  - Fit canvases and Fit scales shrink into that box, and full-bleed backdrops still cover the screen.
  - `SafePad = true` pads a frame by the margin (set on BottomHud.Root and KillFeed.Canvas).
  - The top, bottom and corner groups of the match and lobby HUDs have `ConsolePosition` attributes moved into the box.
- **Bigger on TV:** `CONSOLE_BOOST` 1.15 is the default boost when a screen has no `ConsoleBoost` of its own.
- **Menu focus:** the lobby `Router` takes an optional `screen`.
  - Shop, Battle Pass, Locker, Party and Play now select their first button on a gamepad.
  - An open menu traps the selection (SelectionGroup + Stop).
  - Picking up a controller with a menu open gives it a selection.
  - Match end selects PLAY AGAIN.
  - B already backed out of lobby menus.

**Keybinds:**
- **Settings rows:** each rebindable action in `Config/Input` names its Settings KEYBINDS row (`setting`).
- **Server:** `InputContextService` puts the player's saved { keyboard, alt, controller } keys into their PlayContext, and again whenever the published Settings value changes. It also runs in match servers, because SettingsService does.
- **Hints:** InputGlyphs reads the live bindings back, so the hints redraw when the keys change.
- **Tested:** setting Reload to G on the server moved the binding and the hint source, and setting it back restored R.
- **Not covered:**
  - walking and jumping (Roblox's own controls);
  - the scoreboard key (ScoreboardController reads Tab / Select directly);
  - FREE MOUSE on a gamepad.

**Still open after part 5:**
- **Needs a real device:**
  - touch feel on a real phone (the owner's next playtest);
  - gamepad glyphs and focus with a real controller. The emulator was on phone, so the gamepad mode couldn't be driven in Studio; console layout was checked with `UiDeviceSheet` and the `ForceLayout` switch.
- **Console nit:** the lobby `LobbyTopbar` buttons are close to the player list in console layout on small screens.
- **Next build steps:** the touch layout editor (§9 step 7), the Range placeholder menu, and aim assist (after the playtest).
- **Studio warnings:** `rbxassetid://203785492` ("asset type does not match") and "EditableImage is not accessible" print at start. Both were there before this work and don't come from `src`.

### Part 6 (2026-11-22): centring and lobby menus on phones

The owner's phone test found off-centre UI (crosshair, killed-by, draft), the round notify too low, the lobby player board under the top bar, a case reveal that didn't shade the whole screen, and a Locker, Shop and close buttons not fitted to phones.

**Why things sat off centre:**
- **Crosshair, hit markers, damage numbers, flash, match-end cards:**
  - On a phone the camera viewport is the safe area, while full-bleed screens also cover the notch.
  - The 3D view is centred on the whole screen, and the phone's insets are uneven.
  - So `ViewportSize / 2` put the crosshair 62 px left and 10 px low.
  - New `Shared/ScreenPoint` converts camera pixels to a GUI's pixels. Its aim point is the projected look direction.
- **Draft, killed-by:**
  - Fit-canvas groups were left-anchored at Scale positions on a 1920-wide design, so they spread apart on a wider phone canvas. (The phone position patches from part 4 hid this.)
  - New Studio tool `tools/studio/modules/UiCentreAttach` (installed as `ServerStorage.UiTools.UiCentreAttach`) re-attaches each group to the centre, or to the edge it hugs, by its design offset. On desktop nothing moves.
  - The draft is one centred block (phone boost 1.3).

**Fixes:**
- **Notify:** sits just under the top bar on phones (0.165), narrower and taller. UiLayout now supports `<Family>Aspect` on a UIAspectRatioConstraint.
- **Lobby player board:** sits under Roblox's top bar on phones (`PhonePosition` (1,-4,0,26)), boost 1.55. Names have a fixed width and truncate, so long names no longer run into STREAK / LV.
- **Locker:**
  - It's a fit canvas now: the list hugs the left, the close hugs the right, and the gun gets the free middle.
  - The gun spots are measured from the canvas centre. `cameraFor` frames them from the real on-screen point and the 3D view's own shape.
  - The skins view puts the gun between the name and the tray.
  - The gun list slides fully off screen, so no stray guns show or can be tapped.
  - The floor shadow follows the gun.
- **Shop:** fit canvas, the scroll centred at full height, phone boost 1.5. Popups are a fit canvas (1.3).
- **Backpack / case reveal:**
  - `RevealShade` and `ItemShade` sat inside a centred 16:9 canvas, so a phone's side bands stayed unshaded. That was the half-blur.
  - The Backpack is now a fit canvas with those shades full-bleed.
  - The case flash and the Locker wipe are full-bleed too.
- **Settings (phone):** INSPECT is hidden, and the tabs and list are centred with the list at full height (boost 1.4).
- **Play (phone):** the title band sits on top, the mode tiles are centred under it (boost 1.3).
- **Party, Battle Pass, Profile, Rewards:** centred blocks on fit canvases.
- **Close buttons:** every menu's close is about 42 px on a phone and sits in the top-right corner.

**Checked:**
- In the phone emulator (873×401 with a notch) in a live playtest: crosshair, Notify, the lobby board, Locker and skins, Shop, Backpack shade, Settings and Play.
- At 1920×1080 desktop with `UiDeviceSheet`: Settings is unchanged.

**Still open:**
- ~~Dense menus~~ Done (below).

**Phone layouts for Party, Battle Pass and Rewards (2026-11-22).** These are Studio `Phone*` attributes only, so desktop is unchanged.
- **Party (boost 1.38):**
  - The title sits on top, and the party column is moved up under it.
  - Search and filters sit at the top right, and the player grid fills the height.
- **Battle Pass (boost 1.3):**
  - The subtitle and the big reward picture are hidden on phones.
  - The reward details are one short row: tier, name and text on the left; CONTENTS / price / CLAIM on the right.
  - The level bar and the reward tracks sit under that row.
- **Rewards (boost 1.3):** the title, subtitle and a full-height list.
- **Close buttons:** about 42 px on all three.
- **Checked:** live in the phone emulator, all three readable and nothing clipped.
- **Test tip:** emulator mouse clicks land offset by the notch. To open a menu, set `GuiService.SelectedObject` to its button and press Enter.
- **Locker skins on phones:** the gun in the skins view is on the small side.

