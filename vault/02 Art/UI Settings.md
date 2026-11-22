# UI Settings (full settings screen, saved)

**Date:** 2026-11-21. **Status:** built (lobby place), editing + saving only. Most settings are **not wired to gameplay yet** (owner: "just the ability to edit them and toggle things on/off"). Live today: reduced motion, UI sounds.

Replaces the GENERAL / CROSSHAIR screen from [UI Lobby Overhaul](UI%20Lobby%20Overhaul.md) → Settings. Same page (StarterGui.Settings in the Lobby place, RIVALS-style list + INSPECT panel), now five tabs and saved to the player's save.

References: the owner's RIVALS screenshots (colour wheel picker, Auto Shoot dropdown with a Reaction Time sub-row, Hotkeys table with keyboard / keyboard 2 / controller columns, touch tab), `Config/Input.luau` (our real binds), `Config/Camera.luau` (FOV 70-100, default 80), `Config/Crosshair.luau`, `Config/HitFx.luau` (crit red `FF4D5E`). LihFolk: *05 UI and UX* (Menu Archetypes, Responsive UI), *04 Data and Persistence* (DataStore Fundamentals, Data Loss Prevention), *22 Anti-Exploit and Security* (remote validation).

## Tabs and settings (defaults)
All of it is data in [`Config/Settings.luau`](../../src/shared/Config/Settings.luau): change a default, range or label there.

| Tab | Section | Settings |
|---|---|---|
| VIDEO | Performance | Optimized Lighting, Optimized VFX, Optimized Textures (off) |
| | Camera | Sensitivity 1-100 % (50) with sub-rows While Aiming, While Scoped, Horizontal, Vertical (1-200 %, 100); Invert X, Invert Y (off); Field of View 70-100 (80); Viewmodel FOV 80-120 % (100); Camera Shake 0-100 % (100) |
| | Interface | Hide HUD, Hide Side Tasks (off); Show Kill Feed (on); Reduced Motion (live) |
| | Other | Damage Highlight (on) → Base Colour `FF3232`, Flash Colour `FFFFFF` (colour picker); Colourblind Filter Off / Protanopia / Deuteranopia / Tritanopia |
| AUDIO | Volume | Master 100 %, Music 70 %, Sound Effects 100 %; UI Sounds (live) |
| GAMEPLAY | Combat | Damage Numbers (on) → Colour `FFFFFF`, Crit Colour `FF4D5E`; Hide Teammate Tags (off); Aiming Animation (on) |
| | Controls | Toggle Aim, Toggle Crouch (off); Toggle Sprint (off, locked while Auto Sprint is on); Auto Sprint (on); Scroll Weapons (on, mouse only). Phones always use toggles (later). |
| | Assistance (controller + phone) | Aim Assist (on); Auto Shoot Disabled / Custom / Dynamic (Disabled) → Reaction Time 0-500 ms (25) when Custom |
| | Other | Stick Deadzone 0-50 % (10, stick drift); Force Controls Auto / Keyboard / Controller / Touch (Auto; red warning; a change asks KEEP within 10 s or goes back to the old choice) |
| CROSSHAIR | Crosshair | the old editor (size, colour now a picker, length, thickness, gap, dot, outline, X shape, static, show while aiming) with the live preview |
| | Hitmarkers | Show Hitmarkers (on), Style **Original** (the match's own blade marker, `HitFx.TEXTURES.marker`) / Cross / Dot, Size 50-150 %, Hit Colour `FFFFFF`, Crit Colour `FF4D5E` |
| KEYBINDS | Movement, Combat, Weapons, Mods, Interface, Roblox | three columns: KEYBOARD, ALT, CONTROLLER; click a cell then press a key (Esc cancels, Backspace clears). Roblox rows (menu, chat, fullscreen) are shown locked. Defaults = `Config/Input.luau` |

Every tab ends with **RESET TAB** (one press, owner 2026-11-21: resets only that tab). Mobile / touch tab: later, with the mobile UI.

## Owner answers (2026-11-21)
Sensitivity in % (main 1-100, sub-rows 1-200 % multipliers); choices are **dropdowns** (like RIVALS' Auto Shoot); added Colourblind Filter, Viewmodel FOV, Show Kill Feed (Show FPS / Ping and Streamer Mode declined for now); keybinds are **rebindable and saved now**; Force Controls confirms with a 10 s revert; hitmarker styles Original / Cross / Dot (owner: keep the game's current marker as ORIGINAL, the default); Scroll Weapons default on; reset is a single press.

## Saving
- **Where:** the player's save, DataStore `PlayerDataV1`, field `settings` (same key as coins / skins). `Shared/PlayerSettings` cleans any value against `Config/Settings` (unknown ids dropped, numbers finite + clamped + stepped, choices from the list, colours 6-hex, keys real `Enum.KeyCode` names). Values are only what differs from the default would be smaller, but the full table is ~2 KB, fine.
- **Server** (`Lobby/Services/SettingsService`): publishes the loaded settings in a `Settings` StringValue on the player; `SettingsRequest ("save", table)` is rate-limited, type-checked, size-capped, cleaned, then written after a 6 s debounce (and on leave / shutdown) through `PlayerDataService.writeSettings`, one `UpdateAsync` that changes only `settings` (coins, items, skins untouched, so it can't race a purchase). Saves before the load lands are refused, so defaults never overwrite a real save.
- **Client** (`SettingsController`): edits a local copy, sends it 1.5 s after the last change and when the screen closes.
- **Applying:** every client applies them through `Shared/SettingsApply` (below); match servers publish the same `Settings` value.

## Colour picker
A popup like the owner's RIVALS shot: R / G / B boxes, a hex box, a hue-saturation **wheel** (image made by `tools/ui/make_color_wheel.py`, uploaded) with a ring cursor, and a brightness bar. Click outside or the X to close; changes apply live.

## What to test
1. Open Settings (gear): five tabs, rows rise in, INSPECT explains each row.
2. Each kind: toggle, slider drag + typed value, choice arrows, colour picker (wheel drag, bar, RGB / hex typing), keybind capture / clear / cancel.
3. Auto Sprint on → Toggle Sprint greys out. Auto Shoot Custom → Reaction Time appears.
4. RESET TAB resets only that tab.
5. Change things, leave, rejoin: values come back (Studio saves to `PlayerDataV1_Studio`).

## Results (2026-11-21, Lobby Studio playtest)
- Built: `Config/Settings` (rows), `Shared/PlayerSettings` (clean / publish / read), Lobby `SettingsService` + `PlayerDataService.writeSettings`, `SettingsController` rewrite, Studio templates and popups by `tools/studio/BuildSettingsV2.luau` (extends the old screen, keeps PlateArt). Colour wheel: Decal 107999486088868 = image `rbxassetid://78198355622759`.
- Checked in play: five tabs render, sub-rows indent, Toggle Sprint locks while Auto Sprint is on, Auto Shoot → CUSTOM shows Reaction Time (scroll kept), colour wheel sets the colour live, keybind capture (Jump alt → G), RESET TAB resets only its tab, values reach `PlayerDataV1_Studio` with coins untouched and come back after a rejoin. Hitmarker ORIGINAL previews the real blade image.
- Not checked: gamepad keybind capture (no controller in Studio), the Force Controls KEEP countdown by hand, phone layout (mobile settings come later).
- **Save the Lobby place** (new templates and popups live in Studio).
- Parked: the match place reading these values (no PlayerData load there yet); the cursor ring on the wheel could be a cleaner ring.

## Wiring the settings: plan, chunk 1 VIDEO (2026-11-22)
One place applies settings on each client: **`Shared/SettingsApply`** (both clients start it; the lobby client in lobby servers, the match client in match servers). It reads `PlayerSettings.read`, listens to the `Settings` StringValue, exposes `get(id)` / `changed` (a BindableEvent, so a destroyed match-client copy drops its connections) and applies the world-wide rows itself. Numbers in `Config/SettingsApply`.
- **PERFORMANCE** (LihFolk: *Graphics and Performance Toggles for Low-End Devices*, *VFX Performance Budgets and Culling*; quality level and `Lighting.Technology` can't be set by scripts):
  - Lighting: `Lighting.GlobalShadows` off (re-forced when the server or `MapLighting` sets it), `Shadows` off on every PointLight / SpotLight / SurfaceLight, SunRays / DepthOfField / Blur off. Originals restored when turned off.
  - VFX: one flag `SettingsApply.lowVfx()`; the shot hot path (ImpactFx, MuzzleFx, HitFx head flare, ShellFx, TracerFx) scales `:Emit` counts by `VFX_EMIT_SCALE` or skips extras. Mod VFX not covered in this chunk.
  - Textures: MaterialVariants under MaterialService are moved out on this client (parts fall back to the plain material), put back when turned off.
- **CAMERA:** sensitivity is a post-scale of the camera module's turn each frame (`SettingsApply.scaleTurn`), so mouse, gamepad and **touch** all follow it: `sensitivity/50` x aiming / scoped share x horizontal / vertical, plus invert X / Y. 50 % with all subs 100 % = untouched. Match: inside `CameraController`'s step; lobby: SettingsApply's own step (rotates about `Camera.Focus`, so the third-person orbit works). FOV: `CameraController.setBaseFov` (matches only; the lobby keeps its 70 look). Viewmodel FOV: viewmodel pushed along the line of sight (fades out in ADS so the sight window stays). Camera shake: scales `CameraController.shake` and `viewPunch`.
- **INTERFACE:** hideHud hides the lobby bottom bar, tasks and shades (player list + top bar stay, so Settings is reachable) and the match HUD screens (TopBar, BottomHud, KillFeed, StatusTray); hideSideTasks wired into `LobbyHudView` (tasks panel is off until a tasks system exists); showKillFeed hides the feed rows (your own kill pop stays); reducedMotion check only.
- **OTHER:** damageHighlight gates the HitFx body flash; highlightBase / highlightFlash replace the flash colours when changed from the defaults (defaults keep the tuned per-hit colours).
- **Colourblind** (LihFolk *Colour-Blind Safe Design*): `ColorCorrectionEffect` has no colour matrix, so it can't do a real filter; the honest option is **palette swaps** of the semantic colours (ally, enemy, hit highlight). Measured (Machado 2009 simulation, Oklab distance, target 0.20): ally 00E5FF vs enemy FF5A36 = 0.35 protan, 0.25 deutan, 0.45 tritan (passes); the red hit highlight FF3232 vs grey 808080 = 0.11 protan, 0.14 deutan, and vs a green wall 0.03 protan (fails). So: Protanopia + Deuteranopia swap the default hit red to amber FFC400 (0.41 vs grey); Deuteranopia also swaps the team pair to 2F8CFF / FFB000 (0.41); Tritanopia keeps the defaults (they pass), said in the row's note.

## Results, chunk 1 VIDEO (2026-11-22)
- **Built:** `Shared/SettingsApply` + `Config/SettingsApply` (started by the lobby client in lobby servers and the match client in match servers); the lobby `SettingsController` previews every edit through `SettingsApply.preview`, so rows act at once. Hooks: `CameraController` (sensitivity in its step, `setBaseFov`, `setZoom(..., scoped)`, shake / view punch scale, claims the camera), `WeaponController` (passes scoped), `ViewmodelController` (viewmodel FOV push), `HitFx` (damage highlight on/off + colours), `ImpactFx` / `MuzzleFx` / `HitFx` head flare (`vfxCount`), `ShellFx` (no casings), `KillFeedController` (feed rows + palette), `Util/TeamColor` (palette).
- **Checked in the Lobby Studio playtest:** optimized lighting (GlobalShadows off, 69 shadow-casting lights to 0, restored), optimized textures (491 MaterialVariants held and put back), optimized VFX count (10 to 4), Hide HUD (LobbyBar + shades hidden, top bar + player list stay, restored), `scaleTurn` maths (sensitivity 100 doubles the turn, aiming 50 % cancels it, horizontal 200 / vertical 50 / invert Y, third-person orbit keeps its 12-stud distance), colourblind Deuteranopia swaps TeamColor + hit base and goes back on Off, a custom BASE COLOR wins over the swap, `scopeFov` follows FOV. All changed match modules load without errors; no Output errors.
- **Not tested:** anything in a live match or pad duel (range closed): real mouse / stick / touch turning feel, FOV and viewmodel FOV on screen, camera shake scale, the hit highlight on a real hit, the kill feed hiding, the match HUD hiding, how the plain-material maps look. Reduced motion untouched (works as before).
- **Limits (honest):** Roblox's graphics quality level can't be set by scripts; Optimized VFX covers the gun hot path (impacts, muzzle, casings, head flare), not Mod VFX yet; FOV applies in matches only (the lobby keeps its framing); Tritanopia changes nothing because the default colours already pass for it.
