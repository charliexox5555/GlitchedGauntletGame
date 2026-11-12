---
name: gauntlet-ui-style
description: The owner's UI style for GlitchedGauntletGame (theme v4 "Soft Edge", drafted 2026-11-12 from RIVALS and Valorant video research). Load before designing, building or reviewing any UI, HUD, menu, lobby screen, draft screen, mobile/touch layout or Figma frame for this game. Covers the two shape families (cut-corner plates + true circles), the rejected looks (pills, hard boxes, glow), colour and type rules, motion tokens, HUD slot map, mobile touch rules, the Figma file and how to build it in Roblox.
---

# Gauntlet UI style ("Soft Edge", v4)

The owner's words: the UI must look good and **smooth**, with **stylish corners but also smooth, circular things** and good animations. **Not too pilly** ("Claude makes pills that don't look good") and **not too blocky**. Rounded v2 was reverted as "too AI looking"; v3 "Clipped steel" was too hard. References are RIVALS (layout, chunkiness, touch circles) and Valorant (clarity, restraint, thin chamfered plates). They are not something to copy.

Full spec, tokens and Figma links: `vault/02 Art/UI Theme v4 Soft Edge.md`. Evidence: `vault/03 Research/UI References/00 UI References.md` (+ Rivals PC, Rivals Mobile, Valorant notes with timestamps). v4 is a **draft** until the owner approves it (check the Locked decisions in `vault/00 Home.md`).

## 1. Two shape families, nothing else
- **Plates** (panels, buttons, cards, chips, feed rows, score plates): radius **6** (4 on chips) with **one 45° cut** on the outer top corner (8 / 12 / 16-20 by size). Left-half HUD cuts top-left; right half and centre cut top-right.
- **Rounds** (true circles) for anything that **turns, fills or is touched**: Mod/ability slots, avatars, timer, touch buttons, rewards, party slots, pips, dots, toggle knobs, slider thumbs. **Rings carry state** (cooldown, timer, XP, team, active = gold).
- Thin lines: 1.5 px hairline at 14% white; selection = 2 px gold edge + short gold ticks; team = 3 px colour strip.

**Rejected, never ship:** capsule pills (buttons, tags, bars, search bars), radius > 10 on rectangles, plain 0-radius boxes everywhere, two cuts on one plate, glow halos, glossy or bubbly gradients, 3D icons, neon/glitch decoration, invented UI copy.

## 2. Colour and type
- Near-black glass `10141B` at 88-92%; text `F4F6F9` / `A9B2BF`; dim `6E7785` only for captions on panels.
- **Gold `FFC83D` is the single act-now colour** per screen (PLAY, LOCK IN, selection, active Mod, XP). Text on gold `15110A`.
- Ally `2FD3E6`, enemy `FF5A4E`, each always paired with a position or a word; damage `FF4D5E`. Mod role colours only on tags and medallion rings.
- Fonts: **Montserrat ExtraBold** for display (italic only for hero words: PLAY, LOCK IN, VICTORY, banners); **Oswald SemiBold** for HUD numbers; **Builder Sans** Bold caps for labels and SemiBold for body (Inter stands in for it in Figma). Copy is 2 short lines at most.

## 3. Motion
tap 0.08 Quad Out (scale 0.97 via `UIScale`) · hover 0.12 (lift 2 px, edge to 40%) · enter 0.24 Quint Out (12 px slide + fade, stagger 0.04, total ≤ 0.3) · exit 0.14 Quad In · emphasis 0.36 Back Out (banners, LOCK IN) · rings fill linearly and flash once when ready · shine sweep only on a ready primary. Reduced motion keeps fades and rings and drops the rest.

## 4. Where things go (fixed slots, never moved per mode)
Match: scorebug + circular timer top-centre, tier ladder under it; **one banner slot** (x 42-58%, y 12-26%) for every phase message; kill feed top-right; health bottom-left; **Mods bottom-centre as 3 circles**; ammo bottom-right; centre third holds only the crosshair and the damage arc. Lobby: Roblox top bar reserved top-left, profile next to it, text tabs top-centre, currency + settings top-right, queue bar under the tabs, DAILY bottom-left, party circles bottom-centre, PLAY bottom-right. Draft: roster left, 3 cards centre, gun row below, timer ring top-right, LOCK IN bottom-right.

## 5. Mobile
Touch buttons are **circles** (dark 55% + hairline; pressed = solid accent + 0.94, no glow; hit box +20%). Primary ≥ 13% of screen height (≥ 48 px at 375 tall), secondary ≥ 44 px, gaps ≥ 8 px. The left thumb zone holds only the joystick; the right cluster has ≤ 4 big buttons + reload, with the Mods in an arc above; nothing under the Roblox top bar or the safe insets. Kill feed left-centre (2 rows), compact scorebug, lobby tabs become a right-edge rail. Ship a layout editor (position/size/opacity, presets, left-handed mirror). Design frames at 1920x1080 and 667x375; check 844x390 too.

## 6. Working method
1. Query, don't load: the spec note and reference notes by section; LihFolk `05 UI and UX` (HUD Design, UI Motion Language and Timing, Responsive UI, Safe Areas, Figma to Roblox UI) through `lihfolk-lookup`. Load `roblox-ui-builder` / `lihfolk-figma` for builds.
2. Figma file `UbCKQXuZijn0Gpryt0uUxN` (memory `figma-ui-file`): v4 frames and the "UI v4 Soft Edge (draft)" variables live on the page "Foundations · v4 Soft Edge (draft)". The starter plan allows only 3 pages, so add frames to existing pages. Load the Figma `figma-use` skill before `use_figma`. Plates are vectors built from a path helper (rounded corners + one chamfer); rings are ellipses with `arcData` + `innerRadius`.
3. Self-review every frame from a screenshot: overlaps, text under 12 px drawn, contrast over a bright world (add a plate or a text shadow), a pill or a hard box sneaking in, more than one gold thing. Fix, then screenshot once more.
4. Don't import into Studio until the owner approves the look. In Roblox: 9-slice plate images (cut baked in), `UICorner(0.5,0)` for rounds, one shared radial-ring util, motion via one helper reading tokens in `Config/UiStyle`.
5. Write results and open questions to the vault (spec note §8, `vault/00 Home.md` Status).
