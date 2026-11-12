# UI Theme "Soft Edge" (v4.1 direction, 2026-11-12)

**What this is:** the **theme and the idea** behind how the game's UI looks: shapes, type, colour, motion, where things go. **It is not the final UI.** The owner redesigns the real screens later, starting from this. The Figma boards are direction boards that show the idea working, not finished screens. Nothing is built in Roblox.

Part of the [Style Bible](Style%20Bible.md). The working rules are in the `gauntlet-ui-style` skill (`.claude/skills/gauntlet-ui-style/SKILL.md`). The evidence is in [UI References](../03%20Research/UI%20References/00%20UI%20References.md) (RIVALS PC + phone, Valorant PC + Mobile, from videos).

## History of the owner's verdicts
| Version | Look | Verdict |
|---|---|---|
| v1 (2026-11-03) | Valorant layout, cut corners, Oswald + Montserrat | Approved then, still in the match HUD |
| v2 (2026-11-05) | Rounded, pills, glow, Montserrat Heavy + Builder Sans (the live Lobby) | "Too AI looking" for the HUD; the Lobby is "a bit better" but too pilly |
| v3 concept | "Clipped steel", hard square plates | Too blocky |
| v4.0 (2026-11-12) | Cut plates + circles, Montserrat + Inter + Oswald | Layout liked, "getting there". Still a bit blocky, **the font looks AI / vibe-coded, no oomph** |
| **v4.1 (2026-11-12)** | Sarpanch + Titillium Web, floating HUD on fades, softer plates, slash + chevron accents | Current direction, waiting on the owner |

The **PC layout** is the vibe the owner wants right now.

## Figma direction boards (file `UbCKQXuZijn0Gpryt0uUxN`, page "Foundations · v4 Soft Edge (draft)")
v4.1 (row 2 onwards, under the gold label):
- [Style tile](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=48-820)
- [Lobby](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=50-837)
- [Match HUD](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=49-820)
- [Draft](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=51-847)
- [Phone HUD](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=52-864)

v4.0 is kept on the top row for comparison (marked superseded). Tokens: variable collection "UI v4 Soft Edge (draft)" (48 variables; the type tokens there predate v4.1).

## 1. The idea in one paragraph
Tactical clarity from Valorant, chunky readable energy from RIVALS, our own shape language. **Things float on soft dark fades instead of sitting in boxes.** Interactive panels are soft plates with one cut corner. Everything that turns, fills or is touched is a circle with a ring. A slanted **slash** and the **» chevron** are the brand marks for hero moments. Gold is the one "do this now" colour. The type is angular and game-like, never the generic app look.

## 2. Shapes
| Element | Spec |
|---|---|
| **Plate** (menus, buttons, cards, chips) | radius **8** (4 on small chips), **one 45° cut 10** on the outer top corner (14-22 on big buttons), a **lit top edge** (1.5 px, 22% white), fill 28% darker at the foot, hairline 1.5 px at 12% white. Left-half HUD cuts top-left; right half and centre cut top-right. |
| **Fade** (HUD backings: health, ammo, scorebug, kill feed, banners, key hints) | Dark `06080C` band at 70-88% that fades to nothing toward the screen centre; a 3 px solid edge strip on the screen-edge side. No box outline. |
| **Round** | True circle; a ring carries state (cooldown sweep, timer, XP, team, gold = active). |
| **Slash** | A parallelogram slanted about 20°: beside titles, under the active tab, as tier pips, health segments, the selection tab, role tags. |
| **Chevron »** | Two stacked arrow marks (back one at 50%): on PLAY, LOCK IN, FIND MATCH. When the action becomes ready they step forward once. |

Never: capsule pills, radius above 10, plain hard boxes behind every HUD number, two cuts on one plate, glow halos, glossy gradients, 3D icons, neon/glitch decoration.

## 3. Type (all checked as built-in Roblox font families, 2026-11-12)
| Role | Font | Notes |
|---|---|---|
| Display, titles, hero words, HUD numbers | **Sarpanch** (Bold / ExtraBold / Black) | Angular letterforms echo the cut corners; numbers are square and readable. No italic in Roblox, so energy comes from the slash and the weight. Black only for hero words (VICTORY, PLAY, banners); ExtraBold for numbers and names. |
| Labels, tabs, body copy | **Titillium Web** (Bold caps +10-20% tracking for labels; SemiBold/Regular body) | Tactical, slightly squared; has italics. |

Retired for this theme: Montserrat, Inter, Oswald, Builder Sans (the generic "AI app" look the owner flagged). Tested in Studio: Barlow, Teko, Chakra Petch, Saira, Bebas, Anton, Orbitron, Rajdhani, Kanit and Russo One are **not** built in. Sarpanch, Zekton, Michroma, Denk One, Roboto Condensed, Titillium Web and Builder Extended are. (Creator Store uploaded fonts via `Font.fromId` weren't checked.)

Sizes at 1920x1080: hero 72-110, titles 44-72, HUD numbers 54-66 (timer 36), names 20-24, tabs 22, labels 13-17, body 18-21. Phone floor: 12 px drawn.

## 4. Colour
- Surfaces: `10141B` (plates), `1F2733` (selected), fades `06080C`.
- Text `F4F6F9`, muted `A9B2BF`, dim `6E7785` (captions on panels only).
- **Gold `FFC83D`** = the single act-now thing per screen (PLAY, LOCK IN, selection, active Mod, XP, own kills in the feed). Text on gold `15110A`.
- Teams: ally `2FD3E6`, enemy `FF5A4E`, always with a position or word. Damage `FF4D5E`, success `3FD68A`, warning `FF9F43`.
- Mod roles (tags, medallion rings, a soft wash at the top of draft cards): mobility `5BC8FF`, damage `FF6B4A`, control `B07CFF`, sustain `5EE09A`.

## 5. Motion
| Token | Time | Easing | Use |
|---|---|---|---|
| tap | 0.08 s | Quad Out | scale 0.97 (`UIScale`) |
| hover | 0.12 s | Quad Out | lift 2 px, edge to 40% |
| enter | 0.24 s | Quint Out | slide 12 px + fade, stagger 0.04, total ≤ 0.3 s |
| exit | 0.14 s | Quad In | faster than enter, no overshoot |
| emphasis | 0.36 s | Back Out | banners (1.06 → 1), LOCK IN, round result; the banner's slash wipes in first (0.12 s) |
| ring fill | linear | — | cooldown, timer, XP; ready = one 0.1 s white flash |
| chevron step | 0.18 s | Back Out | » moves 6 px forward when an action becomes ready |
| shine | 0.6 s once | Sine InOut | only on a ready primary |

Reduced motion keeps fades and rings and drops slides, pops, chevron steps and shine.

## 6. Layout (fixed slots, never moved per mode)
- **Match (PC):** scorebug top-centre (ally fade + round avatars + score, circular timer with ROUND n, enemy mirrored); tier ladder (slash pips) under it; **one banner slot** (x 42-58%, y 12-26%) for every phase message; kill feed top-right on fades (own kills gold edge); centre clear except crosshair, damage arc and an optional small damage number; health bottom-left floating (Sarpanch number, slash segments, round shield badge); **Mods bottom-centre as 3 circles** with key chips; ammo bottom-right floating (gun silhouette, mag / reserve).
- **Lobby (PC):** Roblox top bar reserved top-left; profile next to it (avatar, gold XP ring, level chip); text tabs top-centre with a slash underline; currency plates + round settings button top-right; queue band under the tabs; a season headline on the left (slash + SEASON n + big title); DAILY bottom-left; round party slots bottom-centre; mode chip + big gold PLAY with » bottom-right; key hints on a fade.
- **Draft:** title top-left (ROUND n + DRAFT), timer ring top-right, team roster left ("Picking… / Locked in"), three Mod cards (role wash, medallion circle, name, role tag, two lines), gun row with tier pips (locked tier dimmed), LOCK IN » bottom-right.
- **Phone:** compact scorebug, kill feed left-centre on fades, MAP/TAB rounds top-right, floating joystick (left zone empty), right cluster of circles (FIRE gold-tinted 66, JUMP 66, ADS 56, SLIDE 52, R 44) with Mods Q/E/T 48 in an arc above, optional left FIRE, floating health and ammo at the bottom corners.

## 7. Mobile rules
Touch buttons are circles (dark 55% + hairline; pressed = solid accent + 0.94, no glow; hit box +20%). Primary ≥ 13% of screen height (≥ 48 px at 375), secondary ≥ 44 px, gaps ≥ 8 px. Nothing in the Roblox top bar or safe insets. A layout editor from day one: position, size 85-130%, opacity, presets, left-handed mirror ([Rivals Mobile UI](../03%20Research/UI%20References/Rivals%20Mobile%20UI.md)).

## 8. How it would be built in Roblox (when the owner's redesign is approved)
- `Config/UiStyle`: `RADIUS = { chip = 4, plate = 8, max = 10 }` (no pill); drop `SHADOW`, `GLOW`, `LIP`; add `CUT`, `FADE`, `RING`, `MOTION`; `FONT.display = Sarpanch`, `FONT.label/body = TitilliumWeb`.
- Plates: 9-slice `ImageLabel`s with the cut baked in (fill + outline images per cut size and side). Fades: `Frame` + `UIGradient` transparency. Rounds: `UICorner(0.5,0)` + `UIStroke`; one shared radial-ring util. Slashes and chevrons: small white images tinted with `ImageColor3`.
- One `UiMotion` helper reads the motion tokens; pops through `UIScale`.

## 9. Open for the owner
1. Is v4.1 the direction to redesign from (Sarpanch + Titillium, floating HUD, slash + chevron)?
2. Sarpanch vs a quieter display face (Titillium Web Black for everything, or Zekton) if Sarpanch feels too "racing".
3. The cut size (10) and how often the slash/chevron appear.
4. Mods as round slots bottom-centre vs v1's square slots.

Placeholders on the boards: background (the old SceneBG), avatars, gun icons (white bars), Mod copy (take it from `Config/Mods`).
