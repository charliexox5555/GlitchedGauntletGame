---
name: gauntlet-ui-style
description: The owner's UI theme for GlitchedGauntletGame ("Soft Edge" v4.1 direction, 2026-11-12, from RIVALS and Valorant video research). Load before designing, building or reviewing any UI, HUD, menu, lobby screen, draft screen, Shop, SurfaceGui board or mobile/touch layout for this game. Covers shapes (soft plates with one cut corner, HUD on fades, circles with rings, slash and » accents), rejected looks (pills, outlines, glow, generic AI fonts), the font (Rubik Heavy/Bold), colour, motion, HUD slots, mobile rules and how to build it in Roblox.
---

# Gauntlet UI style ("Soft Edge", v4.1 direction)

The owner's words: the UI must look good and **smooth**, with **stylish corners but also smooth, circular things**, good animations, and **oomph**. Rejected:
- **Pills**: "Claude makes pills that don't look good".
- **Too blocky**: v3 "Clipped steel", and v4.0 was still a bit blocky.
- **Generic "AI / vibe-coded" fonts** (Montserrat, Inter, Oswald).
- The rounded v2 HUD: "too AI looking".

References: RIVALS for layout, chunky energy and touch circles; Valorant for clarity, restraint and fades. Our own design, not a copy.

**This is a theme and direction, not final UI.** The owner redesigns the real screens from it. Don't present direction boards as finished screens, and don't import anything into Studio unless asked.

Full spec: `vault/02 Art/UI Theme v4 Soft Edge.md`. Whole-game look: `vault/02 Art/Style Bible.md`. Evidence: `vault/03 Research/UI References/00 UI References.md`.

## 1. Shapes
- **Plates** (menus, buttons, cards, chips): radius 8 (4 on chips), **one 45° cut** of 10 on the outer top corner (14-22 on big buttons), a lit top edge (1.5 px, 22% white), fill 28% darker at the foot, 1.5 px hairline at 12% white. Left-half HUD cuts top-left; right half and centre cut top-right.
- **Fades** for the HUD: health, ammo, scorebug, kill feed, banners and key hints float on a dark band that fades toward the screen centre, with a 3 px edge strip on the screen-edge side. **No box behind HUD numbers.**
- **Rounds**: true circles for anything that turns, fills or is touched (Mods, avatars, timer, touch buttons, party slots, rewards). Rings carry state (cooldown, timer, XP, team, gold = active).
- **Brand marks**: a slanted **slash** (titles, active tab, pips, segments, selection tab, role tags) and the **» chevron** on PLAY / LOCK IN / FIND MATCH. Use them only for hero moments.

**Never:** capsule pills, radius > 10, hard boxes everywhere, two cuts on one plate, glow halos, glossy gradients, 3D icons, neon/glitch decoration, invented UI copy.

## 2. Type and colour
- **Rubik (Heavy / Bold)** for the UI and world signs (`UiStyle.FONT` / `Config/Theme.luau`, owner's pick 2026-11-16, `vault/02 Art/Style Bible.md` §6, `UI Lobby Overhaul.md`, `UI Match Overhaul.md`).
- Earlier passes (retired): **Fredoka One** (2026-11-16 font board pass) and **Sarpanch** / **Titillium Web** (v4.1 draft). Never Roblox's default Builder Sans or retired Gotham/Montserrat.
- **Chunky look (lobby, 2026-11-16):** slanted plates and cells are one-piece sliced art (`client/Util/Plates`, `Util/Cards`, `art-source/ui/plates/`): bright top, deeper base, a dark lip, a thin top bevel line, and white words outlined in a dark shade of the plate colour. Never build plates from separately scaled pieces; they come apart on hover.
- Both are built-in Roblox families (checked in Studio). Barlow, Teko, Chakra Petch, Bebas and Orbitron are not.
- Plates `10141B`, fades `06080C`, text `F4F6F9` / `A9B2BF`.
- **Gold `FFC83D` = the one act-now thing per screen.** Ally `2FD3E6` / enemy `FF5A4E`, always with a position or a word. Damage `FF4D5E`.
- Mod role colours only on tags, medallion rings and draft-card washes.

## 3. Motion
- tap 0.08 Quad Out (scale 0.97 via `UIScale`)
- hover 0.12 (lift 2 px)
- enter 0.24 Quint Out (12 px slide + fade, stagger 0.04, ≤ 0.3 total)
- exit 0.14 Quad In
- emphasis 0.36 Back Out: banners, LOCK IN; the slash wipes in first
- rings fill linearly and flash once when ready
- the » steps forward 6 px when an action becomes ready
- one shine on a ready primary

Reduced motion keeps fades and rings and drops the rest.

## 4. Fixed slots (never moved per mode)
- **Match:** scorebug + circular timer top-centre, tier ladder under it; **one banner slot** (x 42-58%, y 12-26%); kill feed top-right; health bottom-left; **Mods bottom-centre as 3 circles**; ammo bottom-right; the centre holds only the crosshair and damage feedback.
- **Lobby:** Roblox top bar reserved top-left; profile next to it; tabs top-centre; currency + settings top-right; queue band under the tabs; season headline left; DAILY bottom-left; party circles bottom-centre; PLAY » bottom-right.
- **Draft:** roster left, 3 Mod cards centre, gun row below, timer ring top-right, LOCK IN » bottom-right.

## 5. Mobile
- Touch buttons are circles: dark 55% + hairline; pressed = solid accent + 0.94, no glow; hit box +20%.
- Primary ≥ 13% of screen height (≥ 48 px at 375), secondary ≥ 44 px, gaps ≥ 8 px.
- Left thumb zone holds only the joystick. Right cluster: ≤ 4 big buttons + reload, with the Mods in an arc above.
- Kill feed left-centre; nothing under the Roblox top bar or the insets.
- Ship a layout editor (position / size / opacity, presets, left-handed).
- Frames at 1920x1080 and 667x375; check 844x390.

## 6. Working method
1. Query, don't load: the spec note by section; LihFolk `05 UI and UX` through `lihfolk-lookup`. Load `lihfolk:roblox-ui-builder` for builds.
2. **Mock up as real ScreenGuis in Studio** (not Figma; owner's call): build under `StarterPlayerScripts.UI` / `UiRoot` (see `vault/04 Tech/UI Architecture.md`), the owner edits them in Studio, read the edits back. The old Figma file (`UbCKQXuZijn0Gpryt0uUxN`) is history only.
3. **Self-review every screen from a capture** (preload first, memory `studio-capture-preload`): overlaps, a slash touching text, text under 12 px, contrast over a bright world (add a fade or text shadow), a pill / outline / hard box sneaking in, more than one gold thing. Fix, then capture once.
4. **In Roblox:** 9-slice plate images with the cut baked in; `UIGradient` fades; one radial-ring util; tinted slash / chevron images; tokens in `Config/UiStyle` + `Config/Theme`; one motion helper (Quint, no overshoot; scale pops from the centre).
5. Write results and open questions to the vault (the UI note, `vault/00 Home.md` Status).
