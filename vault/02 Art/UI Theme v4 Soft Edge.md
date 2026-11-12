# UI Theme v4 "Soft Edge" (draft, 2026-11-12)

**Status: draft for the owner to review. Nothing is built in Roblox.** Figma frames only; the owner said not to import into Studio yet.

**Why a v4:** the owner doesn't like the current UI. The live Lobby (v2, `Config/UiStyle`) is "a bit better" but too pilly. The v3 "Clipped steel" concept ([Lobby UI and Queue](../01%20Design/Lobby%20UI%20and%20Queue.md) → Proposed direction) is too blocky. The ask: stylish corners **and** smooth circles, good animations, "looking good". References: RIVALS and Valorant ([UI References](../03%20Research/UI%20References/00%20UI%20References.md)). The rules for working in this style are in the `gauntlet-ui-style` skill (`.claude/skills/gauntlet-ui-style/SKILL.md`).

## Figma (file `UbCKQXuZijn0Gpryt0uUxN`, page "Foundations · v4 Soft Edge (draft)")
- [Style tile](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=41-756): colour, type, plates, buttons, rounds, health, rules
- [Lobby 1920x1080](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=42-756)
- [Match HUD 1920x1080](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=43-766)
- [Draft 1920x1080](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=44-783)
- [Phone HUD 667x375](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=45-800)
- [Phone Lobby 667x375](https://www.figma.com/design/UbCKQXuZijn0Gpryt0uUxN?node-id=45-883)
- Tokens: variable collection **"UI v4 Soft Edge (draft)"**, 48 variables. The frames use plain hex for now (see the binding quirk in memory `figma-ui-file`).
- The starter plan allows 3 pages, so v4 lives on the old empty Foundations page.

## 1. Shape language: two families
| Family | Used for | Spec |
|---|---|---|
| **Plates** | Panels, buttons, score plates, kill-feed rows, cards, chips | Rectangle, **6 px radius** (4 on small chips), with **one 45° cut** on the outer top corner: 8 small, 12 medium, 16-20 large. HUD on the left half cuts top-left; the right half and the centre cut top-right. |
| **Rounds** | Ability (Mod) slots, avatars, timer, touch buttons, rewards, party slots, tier pips, notification dots, toggle knob, slider thumb | True circles. Rings carry state: cooldown sweep, XP, timer, team colour, active (gold). |

Never: capsule pills, radius above 10 on a rectangle, plain 0-radius boxes everywhere, two cuts on one plate, glow halos, glossy gradients, 3D icons.

**Lines:** 1.5 px hairline at 14% white on every plate (1 px on phone). Selected = 2 px gold edge + a short gold tick (18x3, radius 1.5) above the top-left and below the bottom-right corner. Team plates get a 3 px team-colour edge strip.

## 2. Colour (same hex as v3; the change is how they're used)
- Surfaces: `surface 10141B` at 88% (92% on busy HUD), `raised 171D26`, `select 1F2733`, `scrim 06080C` at 55-72%.
- Text: `F4F6F9`, muted `A9B2BF`, dim `6E7785` (captions only, never over the world).
- **Gold `FFC83D` = the one act-now thing on screen** (PLAY, FIND MATCH, LOCK IN, selection, active Mod, XP). Text on gold is `15110A`.
- Teams: ally `2FD3E6`, enemy `FF5A4E`, always paired with a position or a word. Damage `FF4D5E`, success `3FD68A`, warning `FF9F43`.
- Mod roles (tags and medallion rings only): mobility `5BC8FF`, damage `FF6B4A`, control `B07CFF`, sustain `5EE09A`.

## 3. Type
| Role | Font (Roblox) | Figma stand-in | Use |
|---|---|---|---|
| Display | Montserrat ExtraBold, caps, -1% tracking | same | Titles, card names, PLAY. **Italic only for hero words** (PLAY, LOCK IN, VICTORY, banners) |
| HUD numbers | Oswald SemiBold | same | Health, ammo, score, timers, cooldown seconds |
| Labels | Builder Sans Bold caps, +6-16% tracking | Inter Bold | Tabs, chips, captions |
| Body | Builder Sans SemiBold/Medium | Inter Semi Bold/Medium | Descriptions (2 short lines max) |

Sizes at 1920x1080: display 52-88, card name 36, HUD numbers 40-44 (timer 34), tabs 20, labels 13-18, body 16-20. Phone floor: 12 px drawn for labels, 10 only for kill-feed names.

## 4. Motion (from LihFolk *UI Motion Language and Timing*, adapted)
| Token | Time | Easing | Use |
|---|---|---|---|
| tap | 0.08 s | Quad Out | press scale to 0.97 (`UIScale`, not Size) |
| hover | 0.12 s | Quad Out | lift 2 px, hairline to 40% |
| enter | 0.24 s | Quint Out | menus/cards slide 12 px + fade; stagger 0.04 s, total ≤ 0.3 s |
| exit | 0.14 s | Quad In | always faster than enter, no overshoot |
| emphasis | 0.36 s | Back Out | banners (1.06 → 1), LOCK IN confirm, round result |
| ring fill | linear | — | cooldown and timer sweeps; the ring "snaps" white with a 0.1 s flash when ready |
| shine | 0.6 s once | Sine InOut | only on PLAY / FIND MATCH / LOCK IN when they become ready |

Reduced motion (`GuiService.ReducedMotionEnabled` + in-game toggle): keep fades and ring fills, drop slides, scale pops and shine.

## 5. Screen layouts (what the frames show)
**Lobby:** Roblox top bar reserved top-left. Profile chip next to it (avatar circle, gold XP ring, level chip). Text tabs top-centre (PLAY · LOCKER · SHOP · PASS · RANGE) with a gold underline and a round notification dot. Currency plates and a round settings button top-right. The searching bar drops under the tabs (spinner ring, mode + time, CANCEL in enemy red). Round party slots bottom-centre with "+" invites. DAILY plate bottom-left (progress lines, round reward coins). Mode selector + big gold PLAY bottom-right. Key hints on a small plate.
**Match HUD:** top-centre scorebug (ally and enemy plates with round avatars and team rings, dead = dim + ✕; a **circular timer with a ring** and ROUND n). Tier ladder chip under it (round pips, "II"). Banner slot for TIER II OPEN / round results. Kill feed top-right (mirrored plates, own kills edged gold, gun silhouettes). Health bottom-left (number + 10 segments, round shield badge). **Mods bottom-centre as three 84 px circles** with cooldown rings and key chips (Q/E/T). Ammo bottom-right (gun silhouette, divider, mag / reserve). Crosshair: dot + 4 lines with a gap; damage direction = red arc segment around it; small optional damage number.
**Draft:** dark scrim over the world. Title top-left ("ROUND 3 · DRAFT" + one line). Timer ring top-right. Team roster on the left (round avatars, "Picking… / Locked in" with gold ring). Three Mod cards (medallion circle with a role-coloured ring, name, role tag, two lines of copy, key number). Gun row with tier pips; locked guns dimmed with "TIER III". Gold LOCK IN bottom-right. Key hints bottom.
**Phone HUD (667x375):** compact scorebug with a timer ring. Kill feed left-centre (Valorant Mobile). MAP/TAB rounds under the top-right. Floating joystick ghost (left thumb zone kept empty). Right cluster of circles: FIRE 64 (gold-tinted), JUMP 64, ADS 56, SLIDE 52, R 44, Mods Q/E/T 48 in an arc above. Optional left FIRE 48. Health bottom-left, ammo bottom-right.
**Phone Lobby:** profile on a plate, currency + settings top-right. Tabs become a **right-edge rail** of plates. DAILY compact bottom-left, round party slots, mode chip + PLAY bottom-right.

## 6. Mobile rules (from [Rivals Mobile UI](../03%20Research/UI%20References/Rivals%20Mobile%20UI.md) + LihFolk *Responsive UI*, *Safe Areas*)
- Touch buttons are **circles**, dark translucent (55%) with a hairline. Pressed = solid accent fill + 0.94 scale, no glow. Hit box about 20% bigger than the visible circle.
- Primary (fire, jump, ADS) ≥ 13% of screen height (≥ 48 px at 375); secondary ≥ 10% and never under 44 px; gaps ≥ 8 px.
- Zones: left thumb (x 0-35%, y 55-100%) only the joystick; centre clear; right cluster at most 4 big buttons + reload; nothing interactive under the Roblox top bar or in the safe-area insets.
- Day-one layout editor: per-button position, size (85-130%) and opacity, presets (Default, Minimal, Claw), left-handed mirror, reset.
- Phone hides key hints and the ammo reserve; the kill feed moves left-centre and shows 2 rows.

## 7. How it would be built in Roblox (when the owner approves)
- `Config/UiStyle` changes: `RADIUS` becomes `{ chip = 4, plate = 6, max = 10 }` (no `pill`); `SHADOW`, `GLOW` and `LIP` are removed; add `CUT = { sm = 8, md = 12, lg = 16, xl = 20 }`, `RING`, `MOTION` tokens; colours as above.
- Plates: 9-slice `ImageLabel`s (one white plate image per cut size, both orientations, `SliceCenter` inside the 6 px corners), tinted with `ImageColor3` and `ImageTransparency`. Hairline = a second 9-slice outline image (`UIStroke` can't follow a chamfer).
- Rounds: `Frame` + `UICorner(0.5, 0)` + `UIStroke`. Radial rings: two half-circle images with `UIGradient` transparency or a rotating mask. One shared `RadialRing` util for cooldown, timer and XP.
- Motion through one `UiMotion` helper reading the tokens; pops via `UIScale`.
- Fonts: Montserrat, Oswald and BuilderSans are all Roblox font families.

## 8. For the owner to decide
1. Is **Soft Edge** the direction (cut plates + circles)? If yes it replaces "Clipped steel" and the v2 rounded/pill look in Lobby and HUD.
2. The cut size: 12 px medium feels right in the frames. More cut = more tactical; less = softer.
3. Mods as **round** slots bottom-centre (v4) vs the square Q/E/T slots of v1.
4. Lobby tabs at the top (v4, like every reference on PC) with a right rail on phone.
5. Next: real art in the frames (in-engine lobby and arena captures, gun silhouettes for the feed and ammo, our own avatars), then one more pass, then build.

Placeholders in the frames: the Mod copy (take the real text from `Config/Mods`), the gun icons (white bars), the avatars (grey circles), and the background (the old SceneBG stand-in).
