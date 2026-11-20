# UI Polish Pass (2026-11-20)

Owner's brief: consistent UI sounds (satisfying, not over the top); better hover / click motion; the Play menu's duel tiles should focus instead of shake; the Locker gun bigger for long guns; a proper Locker background instead of the see-through blurred world; cleaner Settings motion; a general look pass; and a call on how the cut corners are built. **Lobby first, then the match.** This note is the analysis and plan. Nothing is built yet; questions at the bottom.

References: [UI Lobby Overhaul](UI%20Lobby%20Overhaul.md) (the current kit: `Shared/UiMotion`, `Util/LobbyKit`, `Util/Plates`), [Rivals Reference → UI and Client](../03%20Research/Rivals%20Reference/UI%20and%20Client.md), [Style Bible](Style%20Bible.md) → UI, memory "UI motion clean" (Quint, no overshoot). LihFolk `05 UI and UX` → UI Motion Language and Timing.

## 1. What RIVALS does (read from its client scripts, 2026-11-20, read-only)
Study, don't copy: numbers and recipes only.
- **Sounds are few.** One helper makes a Sound per play into a UI group (master 0.5). **No hover sound anywhere.** Click on *press* (mouse down), one shared error sound, the Shop alone has an open sound, nothing on close / tabs / toggles. Queue joined, 3-2-1 ticks, purchase confirm, reward notifications (one per reward type). Locker: a whoosh in (speed 1-1.2) and out (0.8-1.0), and on every item switch one of 3 equip sounds at random speed 0.9-1.1, the previous one stopped first.
- **Buttons:** hover 1.125 / press 0.875 (known). Not everything grows: toggles 0.95, dropdowns 1.025, **queue cards shrink to 0.975**.
- **Queue / mode cards (our duel tiles' match):** no shake, no big scale. Hover runs ~0.12 s cubic-out: the picture goes from dim grey (0.375 transparent) to full bright, and an **inner stroke grows to 4 px**. That is the "focus" look.
- **Tabs:** no sliding underline; the picked tab swaps to a white plate with black words.
- **Locker:** camera rises 25 studs in 0.375 s under a feathered black wipe (we already have this). Behind the gun is a **real 3D room** (table, crates, racks, spot lights) far away, softened with **DepthOfField**. Framing is not fit-to-bounds: the gun sits ~11 studs away under a **very narrow FOV (15; 12.5 when customising)** on a spring, scroll zoom ±10 FOV. Item switch: the gun rises in on a spring, the right panel slides in Quint Out 0.25 s. Drag spin flings and decays (×0.975 per frame) and eases back to rest over ~4 s.
- **Settings:** toggles = a knob that slides 0.25↔0.75, Quint Out **0.5 s**, the track colour follows the knob. Slider handle tweens Quint Out 0.25 s and trails halfway between snap and mouse while dragging. Tabs, dropdowns and the Inspect panel swap instantly (RIVALS isn't smooth here either).
- **Pages:** open from 0.75 (known), **close instantly**. The background behind a page is Lighting (blur 0→24, brightness −0.3, a grey tint) eased Quint Out over ~0.8 s, plus slow drifting tinted textures.
- **Cut corners:** about half of RIVALS' 2,249 UI images are **9-slice images** (one source, `SliceCenter`, corner size by `SliceScale`). No multi-frame shapes.

## 2. What ours does now (code read 2026-11-20)
| Item | Cause | File |
|---|---|---|
| Duel tiles "shake" on hover | the hover `UIScale` (1.04) sits inside the `TextButton`, so the hit area grows with it; at an edge or the gap between tiles MouseEnter / Leave flip back and forth. The memory rule "fixed holder + inner scale" isn't applied here. | `Controllers/PlayMenuController.luau:149-169`, `StarterGui.PlayMenu.Canvas.Modes.*` |
| Locker background = blurred world above you | `Backdrop` fades to **0.3** transparency, so the world (camera risen 25 studs, Router blur) shows through | `Controllers/LockerController.luau:831-840` |
| Long guns look small | every gun is fitted into the same 5 x 2 stud box at FOV 30 (`GUN_LENGTH`/`GUN_HEIGHT`), so a Vandal gets the same length as a pistol's box allows and reads thin | `LockerController.luau:56-58, 307-312` |
| Settings clunky | toggles snap colour and text (no knob, no tween); tabs destroy and rebuild every row with no transition; full-width rows grow 1.04 on hover (card pop), which looks heavy on a list; slider fill / knob jump on click; Inspect text swaps | `Controllers/SettingsController.luau:330-492` |
| Lobby has no UI sounds | removed 2026-11-15 by owner call (now reversed). The match already has `Util/UiSound` + `Config/UiSounds` (Roblox's own UI pack, provisional) | `src/client/Util/UiSound.luau`, `src/shared/Config/UiSounds.luau` |
| One shared motion hook | `UiMotion.button` (hover / press / gamepad / click) is the one place every Studio-built button runs through: the place to add sounds once | `src/shared/UiMotion.luau:169-209` |

## 3. Cut corners: how they're built and what's best
**Now:** in Studio each plate is a body Frame + `CapL` + `CapR` slant images (232 caps in the lobby guis). At runtime `Util/Plates.finish` deletes the caps and draws the plate as **two 9-sliced images** (`Skin` + `Gloss`, 128 x 96 sources), plus a width-fitting workaround for auto-sized plates. So the final drawing is already 9-slice (the right method), but it is built the long way: three pieces in Studio, converted on every load, with extra code.

**Options:**
| Method | Animate | Cost | Verdict |
|---|---|---|---|
| Multiple frames (body + caps / rotated wedges) | seams appear when scaled (we hit this, pass 3); rotation doesn't clip | 3+ objects per plate | no |
| **9-slice image** (one PNG per shape, `ScaleType.Slice`) | scales, tints (`ImageColor3`), fades cleanly as one piece | 1 object, one shared texture | **yes (RIVALS does this)** |
| CanvasGroup mask | fine, but re-renders to a texture, soft text, memory per group | heavy | only for special effects |
| `Path2D` | outline only (no fill) | — | no |
| `UICorner` | round only (rejected look) | — | no |

**Recommendation:** keep 9-slice, but make it the *source* instead of a runtime conversion: a small set of plate images (both ends slanted, one cut corner, a cell, a selected / outlined state; each as base + gloss or one combined) placed directly in the Studio templates, and drop the caps and the `finish()` conversion. **Figma is a good place to draw them** (exact angles, export PNG at 2x, one frame per shape, `SliceCenter` noted on the frame) or a small Python script for pixel-exact output; either way it's ~6 images, uploaded once. This also makes the hover pops clean by construction.

## 4. Plan (lobby first)
1. **Sounds:** one lobby `UiSound` (or the match one shared), cues in `Config/UiSounds`, hooked into `UiMotion.button` and `LobbyKit` so every button gets it at once. Set: hover (very quiet, throttled, or none like RIVALS), click on press, back / close, tab, toggle on / off, slider tick (throttled), error / SOON, page open (soft whoosh, few pages), queue join / leave, match found, Locker whoosh in / out + equip-switch (random pitch 0.9-1.1), purchase / equip confirm. Volumes ~0.2-0.5 through the Ui group; audition reel first.
2. **Duel tiles:** fixed hit area (the button stays still, an inner `Visual` holds the scale); focus = art dim → bright, an inner frame / stroke grows in, a slight lift, the other tiles dim a little; no shake. SOON tiles: a short dim + toast instead of the nudge (or keep a tiny nudge on click only).
3. **Buttons everywhere:** same fixed-holder rule for every hover pop; press on mouse down (as RIVALS), release eases home; Quint everywhere.
4. **Locker:** an opaque backdrop (a charcoal gradient with a soft spotlight behind the gun and the floor shadow, tinted by the skin like now) or a small 3D stage room with depth of field; framing per gun: narrower FOV (~18-20) and a per-class size box so rifles fill more of the screen; the switch rises in.
5. **Settings:** a real toggle (knob slides Quint Out ~0.3 s, track colour follows); tab switch = rows fade / slide in with a short stagger (~0.025 s each) instead of popping; rows highlight (colour / bar) instead of growing; slider knob eases to clicks; Inspect panel cross-fades.
6. **Look pass:** after the plate images (3) exist, a pass over the HUD, Play, Party, Locker, Shop, Settings for spacing, hierarchy and the new plates.
7. **Match:** the same sounds and motion rules in the match UI.

## 5. Questions for the owner
See the chat for the multiple-choice versions; answers go here.
1. Sound source.
2. Hover sound or not.
3. Locker background style.
4. Cut-corner images: Figma or script; one combined plate or base + gloss.
5. "Duel to play": the Play menu's mode tiles, or another thing?

## Answers (owner, 2026-11-20)
1. **Sounds:** an audition reel of both Roblox's own UI pack and Kenney "Interface Sounds" (CC0, download + upload ~15); the owner picks per cue.
2. **Hover:** a tiny, quiet, throttled tick on big items only (mode tiles, Locker gun cards, shop cells); small buttons silent.
3. **Locker background:** opaque charcoal gradient + a soft spotlight behind the gun and the floor shadow, lightly skin-tinted.
4. **Plates:** script-generated 9-slice PNGs, shown on a preview board in Studio, then uploaded and placed in the templates.
5. "Duel to play" taken as the Play menu's mode tiles (1V1 / 2V2 / 3V3).

## Results (2026-11-20, lobby; not committed to the match yet)
Checked in a Lobby Studio play test (no errors from the new code; captures in chat).
- **Sounds.** `Shared/UiSfx` (pooled 2D player, `UiSfx` SoundGroup, per-cue gap and pitch spread, on / off) + lobby `Controllers/UiSoundController` (every GuiButton: `Click` on activate, `Back` for Close / Back buttons, attribute `UiSound` = cue or "none"; a faint `HoverBig` tick only on buttons covering 1-30% of the screen or `UiHover = true`). Specific cues claim the click so nothing doubles: `Confirm` / `Denied` (Play tiles), `Tab` (LobbyKit.tabs), `PageOpen` (Router, from the world only; Locker / Talk quiet), `Back` (Backspace / B), `QueueJoin` / `QueueLeave` / `MatchFound` (queue status), `LockerIn` / `LockerOut` / `Equip` (Locker), `ToggleOn` / `ToggleOff` / `SliderTick` (Settings). Cues in `Config/UiSounds` are **provisional Roblox-pack sounds**; Settings → GENERAL → UI SOUNDS turns them off.
- **Audition reel:** `art-source/audio/ui/UiReel.wav` + `UiReel.txt` (64 Kenney CC0 clips in 11 roles, `tools/audio/ui_reel.py`; the zips in `art-source/audio/downloads/kenney_ui/`, git-ignored). Owner picks a number per role → upload those (~15) → swap the ids in `Config/UiSounds`.
- **Play tiles:** cause measured: tiles sit ~6 px apart and the old 1.04 hover pushed ~7 px into the neighbour, with the hover area scaling too, so the mouse flipped between tiles. Now each tile has a fixed invisible `<Mode>Hit` button (the tile itself `Interactable = false`); focus = lift 1.025, art full bright, the other tiles dim toward grey.
- **Locker:** `Backdrop` is opaque (was 0.3, the world showed through); the skin-tinted light is stronger (0.7 / 0.58). Gun size per class (`CLASS_SIZE`): sidearms 1, SMG 1.12, shotgun 1.2, rifle 1.24, sniper / heavy 1.28 (before, every gun was fitted to the same 5 studs ≈ 838 px). The Vandal now spans ~880 px on screen.
- **Settings:** toggles have a knob that slides (Quint 0.3 s) while the plate eases white / navy; rows highlight (colour + name eases 8 px) instead of growing 1.04 and don't dip; a tab's rows rise in 0.025 s apart; slider clicks ease (0.16 s) and tick per step; Inspect words cross-fade.
- **Plates:** `tools/ui/make_plates.py` → `art-source/ui/plates/v2/` (`plate_slant`, `plate_slant_r`, `plate_cut1`, `plate_cut2`, `plate_cell`, `plate_shadow`, `slices.json`, `preview.png`). One image each (fill, top light and lip baked in), tinted by `ImageColor3`. Approved and uploaded 2026-11-20 (ids in `Config/UiPlates`).

## Test list
1. Lobby: hover the Play tiles (no jitter, the focused one brightens, others dim); click 1V1 (Confirm) and a SOON tile (Denied + nudge).
2. Any button clicks; big cards tick faintly on hover; small buttons silent on hover.
3. Locker: opens with a whoosh, opaque background, Vandal / Operator big, switching guns plays Equip; closing whooshes out.
4. Settings: REDUCED MOTION / UI SOUNDS toggles slide; rows highlight; CROSSHAIR tab rows rise in; sliders tick.
5. Queue: search start / cancel / match found sounds.
6. Listen to `UiReel.wav` and pick per role.

## Plates moved over (2026-11-20, after the owner approved the board)
- Uploaded all six (`Config/UiPlates`: slant 126358774182782, slantR 79321781380250, cut1 129601412125296, cut2 131426917946532, cell 94287691931985, shadow 120049214308831).
- **Studio migration** (`tools/studio/MigratePlates.luau`, run in the Lobby's Edit mode): **122 cap plates** in StarterGui and `UiTemplates.Lobby` now hold one `PlateArt.Skin` (the slant image, sliced) instead of `CapL` + `CapR`; same geometry as before. The originals are copied to `ServerStorage.PlateMigrationBackup` (delete it once you're happy). **Save the Lobby place.**
- **`Util/Plates`** now only binds a plate at run time (Skin follows the body's colour / transparency, white words get an outline); the second Gloss layer is gone (its light is in the image). Plates still built with caps by code are converted the same way. NpcTalk now binds its plates too (it never did).
- Play-tested: no errors, 130 plates bound, no runaway widths, HUD and Shop captured. The new shapes (`slantR`, `cut1`, `cut2`, `cell`, `shadow`) are ready for the look pass; nothing uses them yet.
- Rollback: delete each `PlateArt` / `HideFill` and copy the guis back from the backup folder; `git revert` the Plates change.

## Round 2: owner's lobby test (2026-11-20)
Owner's notes, then what changed (play-tested in the Lobby Studio; the owner's Studio was lagging, about 15 fps, so motion is checked in code and traces, live-server test next).
1. **Bottom bar hover didn't line up with the name tag, chunky.** The pop-up plate and the tag were two slanted shapes with different widths and slant angles. Now the item's own **tag grows up** behind the icon (96 x 28 → 104 x 104, Quint Out 0.28 s both ways), the name stays at its foot, the » fades and slides in at its top corner; the old Plate stays hidden. **The » showed on idle tags:** LobbyLook's `TitleOutline` stroke stayed drawn while the text was hidden; the stroke is removed and the » is hidden when not hovered.
2. **Queue tiles: text still shimmered; too dark.** Scaling a tile redraws its words every frame. Nothing scales now (hover or entrance): focus = art full bright + its shade lifted, others ease back a little; live tiles rest brighter (tone 35% toward white), shades lighter. Scrims 0.45 → 0.62 (Play, Party); the page wash (Shop, Season Pass, Settings, Profile, Rewards) lighter and less opaque in Studio (0.3 → 0.42, gradient `3C3C42 → 2B2B31 → 1F1F24`; `KIT.color.wash` matches). **Save the Lobby place.** The Studio builders (`tools/studio/Build*.luau`) still carry the old wash.
3-5, 7. **Sounds.** The bright Roblox click and the gun / skin switch sound were disliked, and the Settings sounds were too much. Now: **one soft round tap for every click** (Kenney CC0 `drop_002`, trimmed: `art-source/audio/ui/UiClick_Soft.wav`, asset 112177281704509) at small pitch steps for meaning (click 0.92, back 0.8, confirm 1.05, toggle on 1.02 / off 0.84), quieter; **switching guns or skins is silent** (no click either); slider ticks gone. A tiny tick (`click_002`, asset 89023085407630) was tried for tabs and toggles and **rejected as high-pitched**, so it's unused. Owner's direction: "fun sounds that add to the game", not high. The Locker whooshes are about half as loud.
6. **Locker open / close a little more subtle:** camera rise 25 → 14 studs (0.32 s), wipe 0.9 / 0.75 → 0.72 / 0.6 s, the gun swings in from a smaller angle (yaw -75° → -42°) over 0.75 s.
8. **Settings tabs grew and overlapped.** `LobbyKit.tabs` no longer grows or dips: an idle tab lifts a shade and its words go white on hover (0.2 s); the picked tab eases to white.
9. **Leaderboard (player list) open / close.** Traced in play: it does slide (440 → 0 px), but the old version came in with an overshoot (removed by the no-overshoot rule) and left with an accelerating Quint In that reads as a snap at low fps. Now Tab slides it out with a soft stop (Quint Out 0.36 s), in over 0.45 s, and its rows cascade in again each time it comes back.

## Round 3 (owner, 2026-11-20)
- **Sounds:** the soft tap "sounds like a bubble, sci-fi cartoony"; the owner wants professional UI sounds from a real pack, not made-up ones. Source now: **Roblox's licensed Pro Sound Effects library** (Creator Store, creator "ProSoundEffects", free for Roblox games, no upload). 36 candidates by role (switch / plastic clicks, "thuddy" UI selects, soft paddle swishes, fuzzy UI buzzes, soft beep clusters), sci-fi / bubbly / metallic / high-pitched families excluded. **Audition board:** `Controllers/SoundAudition` (Studio only): press **F4** in a play test, click to hear; the first button in each row is the current sound. All 41 ids load. Owner picks per role → `Config/UiSounds`.
- **Bottom bar »** sat behind the icon (a tag's children draw under its sibling icon); it's on the button now, above the icon, white, where the old plate had it.
- **Play tiles get size on hover without scaling words:** the picture zooms 1.08 inside its own frame (its crop rect shrinks around the centre; `ART_PX` 840 x 940 default, read from the image when the client can) and the tile lifts 5 px.

## Round 4: owner's picks (2026-11-20)
Set in `Config/UiSounds` (Pro Sound Effects = PSE, Roblox's own UI pack = Roblox):

| Cue | Sound | Volume |
|---|---|---|
| Click | PSE Toggle Button 1 `9119717529` | 0.3 |
| Back / close | PSE Soft swish 14 `9119703221` | 0.3 |
| Tab | PSE Paddle swish 1 `9119704482` | 0.25 |
| Toggle on / off | PSE Toggle Button 2 `9119717523` / Toggle Button 1 `9119717529` | 0.3 |
| Error / SOON | Roblox Delete `15675075163` (kept) | as before |
| Page open | Roblox Whoosh 03 `15674975792` (kept) | 0.1 |
| Queue leave | the close swish, pitch 0.9 | 0.26 |
| Confirm | PSE Thuddy select B `9126040335` (provisional; "too sci-fi") | 0.35 |
| Hover | still the old tap (provisional; owner dislikes it) | 0.05 |
| Match found | Roblox Tonal Stinger (okay, owner wants a new one) | 0.45 |

**Why the hover row seemed dead:** the three PSE "Trackball Mouse" recordings peak at about 3 PlaybackLoudness at full volume (a click is about 150), so at 0.12 they're silent. Measure loudness before shortlisting quiet sounds (`PlaybackLoudness` only reads in a play test, not in Edit).

**Round 5 board** (F4, same controller): only Hover (Roblox GUI Hover 01-03, RBLX UI Hover 01-03), Confirm (Roblox GUI Select / Equip, RBLX UI Select 01-02, a big plastic button, a PSE game pad button, the current Thuddy B) and Match found (Roblox GUI Notification High / Low, APM hits: Get Up And Go, Scoundrels, Raunch On, Universal Flip, the current stinger). Every candidate is level-matched by measured loudness (hover ~20, confirm ~50, match found ~100). "No hover sound" is also an option (RIVALS has none). Found through the Creator Store search API, filtered to creators ProSoundEffects, Roblox and APMOfficial only (user uploads skipped: many are ripped from other games).

## Round 5: last picks (owner, 2026-11-20)
- **Hover:** Roblox "GUI - Hover 02" `17208343514` at 0.67.
- **Confirm:** Roblox "GUI - Select" `17208396156` at 0.29.
- **Match found:** APM "Universal Flip - Hit" `9042542887` at 0.23. **Backup the owner wants kept:** Roblox "GUI - Notification High" `17208361335` at 0.3 (a comment next to the cue in `Config/UiSounds`).
- Every lobby UI sound is now picked by the owner. The Studio audition board (`Controllers/SoundAudition`) is removed; to audition again, rebuild it from git history (commit 07f2b45e).
