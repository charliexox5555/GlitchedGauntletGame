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

## Chunk 2 AUDIO + lobby FOV (2026-11-22)
**Plan:** volumes as SoundGroups owned by `Shared/SettingsApply` (numbers and names in `Config/SettingsApply` → AUDIO). SoundGroups can't be put above the existing buses without breaking the code that finds them by name (`FlashFx` → `SoundService.Combat`, `UiSfx`), so SettingsApply sets those buses' volumes instead and adds two of its own:
- `Combat` (guns, hits, foley, ambience) = its own level x MASTER x SOUND EFFECTS; `SettingsSfx` = MASTER x SOUND EFFECTS, and any Sound in Workspace / SoundService / PlayerGui left without a group joins it (the world, Roblox footsteps, abilities, cases).
- `SettingsMusic` = MASTER x MUSIC: the lobby music and the win song (it used to play through UI sounds, so UI SOUNDS off silenced it; `UiSfx.play` now takes a group to play through).
- `UiSfx` = MASTER; UI SOUNDS moved from the lobby SettingsController into SettingsApply, so it also works in matches.
- **Lobby music** (owner): asset 130289448486631 (149 s), `Config/Audio.LOBBY_MUSIC` (volume 0.5, 2 s in, 1 s out), new lobby `LobbyMusic` controller: looped, fades out while armed (range, pad duel), lobby servers only.
- **FOV in the lobby** (owner: "FOV should change 3rd person as well"): the lobby camera step sets FIELD OF VIEW while the camera is the normal Custom camera (menus with their own Scriptable camera keep theirs); the case FOV kick now runs after it (`CaseOpening` render step +2).

**Results (Lobby Studio playtest):** the music plays on `SettingsMusic`; master 50 / music 20 / sfx 0 gave Music 0.10, Sfx 0, Combat 0, UiSfx 0.50 and back; UI SOUNDS off stops `UiSfx.play`; every Workspace Sound got a group. The lobby FOV follows the saved value (the owner's Studio save has FOV 95 and sensitivity 89, so the lobby looks wider and turns faster than the defaults). Not tested: the win song on the music group (needs a match end), listening levels by ear, the music fading during a pad duel.
- Studio note: `execute_luau` requires its own copy of a ModuleScript (separate require cache), so check live values from instances, not from a required module.

## Chunk 3 GAMEPLAY + aim assist + auto shoot: plan (2026-11-22)
**Owner answers:** add an AIM ASSIST STRENGTH slider (0-100 %, 100 = our tuned level); assist = slowdown near enemies + a light pull only while the player moves their aim, stronger in ADS, never a snap; the phone FIRE button stays with Auto Shoot on; on phones, rows that don't apply grey out with a note, and AUTO SPRINT stays a real choice on phones (its text fixed).

**Research** (web agent: Roblox's `AimAssistController` in the FPS / Laser Tag templates = friction, tracking, centering with distance easing, gamepad + touch only; CoD slowdown + rotational; Halo friction + magnetism shrinking in zoom; Fortnite and Apex nerfs = stickiness and snap-on-ADS are what players hate; Witchfire two-circle slowdown. LihFolk *Aim Assist and Generous Hitboxes*, *Controller Support QoL*, *Hold vs Toggle Auto-Sprint*: friction first, ~6 deg cone, LOS mandatory, 20 Hz target pick, never mouse. **RIVALS file (studied, not copied):** Auto Shoot casts a camera ray to the gun's reach, needs a live enemy, no smoke between, not blinded; waits the reaction time, then taps fire each frame while on target; DYNAMIC = per-gun time from the fire interval (clamped 25-125 ms); snipers only when fully scoped; patch notes: assist cone 180 -> 15 deg, no assist / auto shoot while blinded or through smoke, Ranked caps strength 50 % and forces Dynamic.)

**Build:**
- `Shared/InputMode`: the one device answer (forced by FORCE CONTROLS, else `PreferredInput`); `UiLayout`, `TouchHud`, `InputGlyphs`, `Router`, `MatchEndScreen`, `Device` read it.
- Toggle Aim / Crouch / Sprint (keyboard + controller): `InputContextService` moves the keys onto `AimToggle` / `CrouchToggle` / `SprintToggle` actions; `InputController` flips the real action on each press (reset on death).
- Auto Sprint off (keyboard + controller): the run needs Sprint held (`Movement`, attribute `AutoSprint` on the own character).
- Scroll Weapons: mouse wheel cycles the loadout. Stick Deadzone: stick drift under the value neither turns the camera nor walks.
- Damage numbers on/off + colours (`HitFeedback`), Hide Teammate Tags (`TeammateBillboardController`), Aiming Animation off = ADS snaps (`ViewmodelController`).
- **Aim assist** (`client/Controllers/AimAssistController`, numbers `Config/AimAssist`): gamepad / touch only, enemies in a 15 deg cone with line of sight inside the gun's range, not blinded. Friction: the turn slows up to 40 % x strength near the target (inner 3 deg full, fading to 0 at the cone edge). Pull: while the aim is moving, up to 15 % (hip) / 30 % (ADS) of that frame's turn bends toward the target. Light tracking (follows a strafing target) only while the aim is moving. No assist under 4 studs; no snap on ADS.
- **Auto shoot** (same controller): camera ray to the gun's reach (melee: its swing reach); a live enemy, LOS, not blinded; snipers only fully scoped. CUSTOM = the player's reaction time; DYNAMIC = 50 ms + 10 % of the gun's shot interval, clamped 50-150 ms (fairer than RIVALS' 25 ms floor). Automatic guns hold the trigger, others tap at their fire rate. Server checks every shot as usual.

## Results, chunk 3 GAMEPLAY + aim assist + auto shoot (2026-11-22)
- **Built:** `Shared/InputMode` (FORCE CONTROLS; `UiLayout`, `TouchHud`, `InputGlyphs`, `Router`, `MatchEndScreen`, `Device`, `TouchController`, the Settings screen read it); `phoneLock` rows in `Config/Settings` (Toggle Aim / Crouch / Sprint "ALWAYS ON FOR PHONES", Scroll Weapons "MOUSE ONLY", Stick Deadzone "CONTROLLER ONLY") greyed on touch by `SettingsController`; new AIM ASSIST STRENGTH sub-row; Auto Sprint and Aiming Animation texts fixed. Toggles: `Config/Input.toggle`, `InputContextService` (`<Name>Toggle` actions), `InputController` (flip; released on death, on a new character, when the row turns off; Aim also on a weapon swap). Auto Sprint off: `Simulation/Movement` reads the character's `AutoSprint` attribute (set by SettingsApply). Scroll Weapons: `WeaponController` mouse wheel. Stick Deadzone: SettingsApply (right stick drift turns nothing, left stick drift walks nowhere). Damage numbers + colours: `HitFeedback`. Hide Teammate Tags: `TeammateBillboardController`. Aiming Animation off: `ViewmodelController` (no spring; the aim time stays, it's gameplay).
- **Aim assist + auto shoot:** `client/Controllers/AimAssistController` + `Config/AimAssist` (numbers as planned), hooked through `CameraController.setAssist` (runs after the sensitivity scale, never on a placed camera) and `WeaponController.autoTrigger` / `autoTap` / `readyToFire` / `isScoped` / `currentConfig`. Target point = the nearest of 5 points from hip to head, so the pull never drags a head aim down to the chest.
- **Checked in the Lobby Studio playtest:** all changed modules load; `AimToggle` / `CrouchToggle` / `SprintToggle` exist with no keys by default; publishing TOGGLE AIM + CROUCH on moved RMB / L2 and C / Ctrl / B onto the toggle actions and back when off; a CrouchToggle press held Crouch on, a second press let go; `AutoSprint` attribute set on the character; no Output errors.
- **Not tested (owner will):** aim assist and auto shoot feel (needs a gamepad or phone in a duel or the range), Toggle Aim / Sprint in a fight, Auto Sprint off on keyboard and phone, scroll switching, deadzone on a drifting pad, FORCE CONTROLS switching layouts (and its 10 s KEEP), damage number colours, teammate tags, Aiming Animation off.
- **Limits:** no smoke clouds exist yet, so "not through smoke" isn't coded (add when a smoke Mod lands); no Ranked cap yet (RIVALS: 50 % strength, Dynamic only).

## Chunk 4 CROSSHAIR + spectating: plan (2026-11-22)
- `client/Util/CrosshairSettings.fromValues(values)` turns the CROSSHAIR rows into a `Config/Crosshair` table (size, colour, length, thickness = bar + dot size, gap, dot, outline, X = 45 deg, static, show while aiming); the rest stays the tuned default. `HudController` applies it from `SettingsApply`.
- **Spectating (owner):** while you watch someone (`Util/Watched`), `HudController` builds the crosshair from **their** published `Settings` value (every Player's `Settings` StringValue replicates to all clients); bots and players with no settings use the default; back to yours when you stop watching. Hitmarkers stay your own preference.
- SHOW WHILE AIMING: `Crosshair.step` keeps it up when the aim blend is in (the callers hide it on ADS, so the flag was never reaching it).
- **Hitmarkers** (`HitFeedback`): SHOW HITMARKERS off skips the hit pop (the shield "blocked" marker stays: it's information); STYLE ORIGINAL = the current blades, CROSS = four thin diagonal lines, DOT = a small square (same timing, outline behind); SIZE scales it; HIT / CRIT COLOR replace the tuned white / red once changed from the default.

## Results, chunk 4 CROSSHAIR (2026-11-22)
- **Built:** `client/Util/CrosshairSettings` (rows → `Config/Crosshair` table; `rawOf` / `decode` for someone else's published settings), `HudController.syncCrosshair` (yours, or the watched player's while spectating; re-applied when they change their settings; bots = default), `Crosshair.step` SHOW WHILE AIMING fix, `HitFeedback` hitmarker on/off, ORIGINAL / CROSS / DOT, size, hit / crit colours. `SettingsApply.values()` added.
- **Checked in the Lobby Studio playtest:** the four modules load; a custom set (X, colour 00FF88, thickness 4, no dot, show while aiming) builds rotation 45 / dot size 4 and leaves the default untouched; your own published settings read back (2.8 KB); a bot reads nil (default).
- **Not tested (owner will):** how each row looks on screen in a match, CROSS / DOT hitmarkers, show while aiming on a scope, spectating someone with a custom crosshair.

## Chunk 5 KEYBINDS + TOUCH leftovers: plan (2026-11-22)
**Audit:** every KEYBINDS row with an Input action already works (`InputContextService`). Saved but dead: WALK FORWARD / BACKWARD / STRAFE LEFT / RIGHT and JUMP (Roblox's own control module reads WASD / Space) and OPEN SCOREBOARD (Tab and Select were hard-coded in `ScoreboardController` and the lobby's `LobbyHudView`).
- **Scoreboard:** `SettingsApply.keyIs("kScoreboard", keyCode)` checks the saved keys; both Tab handlers use it.
- **Movement keys (keyboard):** only once a player changes them (defaults = untouched, Roblox moves you). SettingsApply's input step (after the control module) then builds the move from the saved keys, camera-relative, so W stops walking if it's no longer bound; typing in a text box leaves it to Roblox. The controller stick isn't rebindable (it stays the left stick).
- **Jump (keyboard and controller):** a changed JUMP row: the new keys jump (held = repeat, like Roblox), Space / A are sunk through ContextActionService at high priority unless still bound.
- **TOUCH CAMERA THROUGH BUTTONS** (default on = today): off makes the touch buttons interactable, so a swipe starting on one is the button's and the camera ignores it (Roblox's camera skips processed touches).
- **TOUCH DOUBLE TAP TO FIRE:** two taps on empty screen on the right half within the DOUBLE TAP WINDOW: the second touch holds Fire until it lifts (it still turns the camera).

## Results, chunk 5 KEYBINDS + TOUCH (2026-11-22)
- **Built:** `SettingsApply.keyIs` (used by `ScoreboardController` and the lobby's `LobbyHudView` for OPEN SCOREBOARD); rebound WALK / STRAFE keys move you through SettingsApply's input step (keyboard only, only when changed); rebound JUMP through ContextActionService (`GGJumpKeys`, high priority; Space / A only taken when JUMP left them; held = repeat). `TouchController`: CAMERA THROUGH BUTTONS off makes the buttons interactable; DOUBLE TAP TO FIRE on the empty right half (the FIRE button held by another finger keeps firing).
- **Checked in the Lobby Studio playtest:** publishing JUMP = F (pad A kept) and SCOREBOARD = P bound `GGJumpKeys` at priority 3000 on the real client; restoring the settings unbound it; the changed controllers load; no Output errors.
- **Not tested (owner will):** pressing the rebound keys (walk, jump, scoreboard), double tap to fire and camera-through on a phone. Every Settings row now does something.
