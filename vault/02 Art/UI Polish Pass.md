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
