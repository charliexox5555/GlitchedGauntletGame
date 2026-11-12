---
name: gauntlet-ui-style
description: The owner's UI theme for GlitchedGauntletGame ("Soft Edge" v4.1 direction, 2026-11-12, from RIVALS and Valorant video research). Load before designing, building or reviewing any UI, HUD, menu, lobby screen, draft screen, SurfaceGui board, mobile/touch layout or Figma frame for this game. Covers the shapes (soft plates with one cut corner, HUD floating on fades, circles with rings, slash and » chevron accents), rejected looks (pills, hard boxes, generic AI fonts, glow), the fonts (Sarpanch + Titillium Web), colour, motion tokens, HUD slot map, mobile rules, the Figma boards and how to build it in Roblox.
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
- **Sarpanch** (Bold / ExtraBold / Black) for display, names and HUD numbers. Black only for hero words. It has no italic in Roblox.
- **Titillium Web** for labels (Bold caps, +10-20% tracking) and body (SemiBold / Regular).
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
1. Query, don't load: the spec note by section; LihFolk `05 UI and UX` through `lihfolk-lookup`. Load `roblox-ui-builder` / `lihfolk-figma` for builds.
2. **Figma file:** `UbCKQXuZijn0Gpryt0uUxN` (memory `figma-ui-file`). It's on a starter plan with a 3-page limit, and the v4.1 boards are on "Foundations · v4 Soft Edge (draft)".
3. **Figma tools:**
   - Load the Figma `figma-use` skill before `use_figma`.
   - Plates are vectors from a path helper (rounded corners + one chamfer).
   - Fades are rectangles with a linear gradient.
   - Rings are ellipses with `arcData` + `innerRadius`.
   - Slashes and chevrons are small vector paths.
4. **Self-review every frame from a screenshot:**
   - overlaps, and a slash touching text;
   - text under 12 px drawn;
   - contrast over a bright world (add a fade or a text shadow);
   - a pill or a hard box sneaking in;
   - more than one gold thing.

   Fix, then screenshot once.
5. **In Roblox:**
   - 9-slice plate images with the cut baked in;
   - `UIGradient` fades;
   - `UICorner(0.5,0)` rounds;
   - one radial-ring util;
   - tinted slash / chevron images;
   - tokens in `Config/UiStyle`;
   - one motion helper.
6. Write results and open questions to the vault (spec §9, `vault/00 Home.md` Status).
