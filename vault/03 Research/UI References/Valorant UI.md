# Valorant UI (PC and Mobile): reference for our HUD and menus

Research note for the Figma UI pass. Goal: borrow Valorant's clarity, hierarchy and tactical tone, adapted to Roblox. Not a copy. Guns are in [Valorant Gun Mechanics](../Valorant%20Gun%20Mechanics.md) (not repeated here). The owner's own screenshots (Spike Rush-style ability draft cards, bottom bar, top bar) are in `vault/01 Design/ValorantUIExamples/` (git-ignored); this note adds what those do not show: the full HUD map, the round loop screens, menus, Riot's principles and the mobile reflow.

Frames are git-ignored third-party stills in `vault/02 Art/References/ui/video-frames/valorant/`. All percentages are read off 1080p/4K screen captures (screen = 100%), so treat them as +-1-2%.

## Summary (the 10 things that matter)
1. One strict top-to-bottom, centre-out hierarchy: round state top-centre, world in the middle, personal state bottom-centre, ammo/economy bottom-right, intel (minimap) top-left, events (kill feed) top-right. Nothing floats in the middle of the screen except transient banners.
2. Two colours carry team identity everywhere: teal-green = us, red-coral = them. White text, almost no other hue in the HUD.
3. Panels are sharp, thin-lined, translucent dark or just lines with no fill; shapes are chamfered (cut corners), never rounded. The scorebug is two long bars meeting a hexagonal timer.
4. Typography: tall condensed uppercase for banners and big numbers, small tracked-out uppercase for captions, a clean sans for numbers/body.
5. Information is layered by importance: big (health, ammo, timer), medium (ability icons, score), tiny (map callouts, keybind labels, round caption).
6. Phase changes are announced by one centred banner with a tiny caption line (BUY PHASE / press B to buy; FLAWLESS / DEFENDERS; SPIKE PLANTED) in the same slot every time.
7. Menus are calmer than the HUD: navy/near-black with off-white text, thin hollow frames with notched corners, one saturated accent for the primary action (teal "IN QUEUE", red "PLAY").
8. Selection screens (agent select, buy menu) are a grid + one detail panel + one primary button, with every teammate's state visible at the side ("Picking...", locked portrait, loadout and credits).
9. Mobile does not shrink the PC HUD: it keeps the same elements but moves interaction to two thumb zones, relocates the kill feed to the left-centre, drops the portrait rows, and ships three presets plus a drag/resize/opacity editor.
10. Riot's own UI rules: UX (flow) before UI (visuals), one ecosystem with fixed rules for colour/type/shape/motion, layout by proximity, motion for feeling, design for the platform and genre.

## 1. In-match HUD map (PC)
Source frames are spectated or own-view Jett/Phoenix matches (1080p to 4K). The spectated frames show the "SWITCH PLAYER" label bottom-left; ignore it for our HUD.

![](../../02%20Art/References/ui/video-frames/valorant/kI6_uh-L4MU_0800_hud-full.jpg)
Full HUD at [8:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=480s): scorebug, minimap, health/shield, ability bar, ammo.

```
 0%                      50%                       100%
 +-----------------------------------------------------------+ 0%
 |(map)callout   [team bar|SCORE <TIMER> SCORE|enemy bar]  kill feed
 | (minimap       alive portraits sit ON the bars)  [rows, top-right]
 |  circle                                                   |
 |  ~20% w                                                   |
 |  to ~45% y                       banner slot (12-27% y)   | 25%
 |                                                           |
 |                     +  crosshair (50%,50%)       combat    |
 |                                                  report   | 28-72%
 |                                                  (dead)   |
 |                                          weapon list      | 63-81%
 |                                          (tiny, right)    |
 | [spectate]                                                | 75%
 |                                                           |
 |  (shield)100 --\_[ C ][ Q ][ E ][ X ]_/-- 25|60 (ammo)    | 93-96%
 |   28-34%         41-59% ability bar         68-72%  ¤4,200| 97%
 +-----------------------------------------------------------+ 100%
```

| Element | Position | Size | Style | Colour | Source |
|---|---|---|---|---|---|
| Scorebug (round timer, score, alive portraits) | top-centre, spans about 20% to 80% x, y 2-7% | about 60% wide, 5% tall; timer box about 6% wide | two long bars (ally left, enemy right) meeting a chamfered hex timer; thin diagonal ends; alive portraits are small squares sitting on the bars with a thin white life tick under each | ally bar teal-green, enemy bar red-coral, both muted; text white; timer turns red below 10 s | [8:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=480s), [12:40](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=760s) (red 08.99) |
| Round score numbers | inside the bar next to the timer | about 2% tall | big white numerals, flat | white | [8:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=480s) |
| Spike/objective icon | replaces the timer when the spike is planted, top-centre | about 3% wide | red triangle/hex icon, red "SPIKE PLANTED" tag below it (y 13-17%) | red | [17:20](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=1040s) |
| Minimap | top-left, x 0.5-22%, y 4-45% | about 20% of screen width | circular/ellipse frame with thin ring, map rotates; callout name in tiny text above it ("A Link", "Mid Bend") | grey map, teal allies, red enemies, thin white ring | [1:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=60s) |
| Health + shield | bottom-centre-left, x 28-34%, y 93-96% | large numerals about 4% tall | shield badge with number, then big white health value; fine diagonal connector line to the ability bar | white; shield badge teal; turns red below low | [5:40](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=340s) |
| Ability bar | bottom-centre, x 41-59%, y 92-97% | four icons about 3% wide | outline icons with key letter below, charge pips, a thin teal fill bar under each icon showing readiness; spent abilities dim | white icons, teal readiness | [8:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=480s), [1:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=60s) |
| Ammo | bottom-right of centre, x 68-72%, y about 95% | mag number large, reserve small, tiny bullets glyph | current number in big white, reserve smaller and dimmer | white | [8:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=480s) |
| Credits | bottom-right corner, x 96-97%, y 97% | tiny | currency glyph plus number | white, low contrast | [8:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=480s) |
| Equipped weapon list | right edge, x 92-98%, y 63-81% | tiny icons stacked vertically with slot numbers | the equipped weapon is brighter, others faded; slot ticks on the far right | white at different alpha | [1:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=60s) |
| Kill feed | top-right, x 72-99%, y 8-17% (rows stack down) | rows about 2.5% tall | one row: killer portrait, weapon icon, (headshot/wallbang glyph), victim portrait; your own kill gets a bright frame | killer side tinted by team (teal row for ally kills, red for enemy), white icons | [10:20](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=620s), [33:40](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=2020s) |
| Crosshair | screen centre | tiny, user-configurable | small dot/lines | player's colour | all gameplay frames |
| Damage/hit feedback | around crosshair + on the weapon list | n/a | tiny hit marker; damage is explained after death by the combat report (not floating numbers) | white, red for headshot flash | see 3 below |
| Spectate label | bottom-left, x 1.5-14%, y 74-80% | tiny | portrait, name, "SWITCH PLAYER" | white | [3:20](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=200s) |
| Network problem icon | top-right corner | tiny icon | only appears on trouble | red/white | [25:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=1500s) |

### Objective states
![](../../02%20Art/References/ui/video-frames/valorant/kI6_uh-L4MU_1720_spike-planted.jpg)
Spike planted: the timer is replaced by the spike icon and a red tag ([17:20](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=1040s)).

![](../../02%20Art/References/ui/video-frames/valorant/kI6_uh-L4MU_1940_defusing.jpg)
Defusing: a small caption "DEFUSING" over a thin yellow-white progress bar under the scorebug, x 43-57%, y 17-19% ([19:40](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=1180s)). Progress bars are thin and pale, not chunky.

### Death, damage and spectating
![](../../02%20Art/References/ui/video-frames/valorant/kI6_uh-L4MU_0320_combat-report.jpg)
After death, a combat report panel sits right-centre (x 89-99.5%, y 28-72%): "KILLED BY" header with the killer's player-card banner, then rows OUTGOING | weapon | INCOMING, damage numbers big and white, a "ROUND ONGOING" footer and keybind hints in tiny text ([3:20](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=200s), [22:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=1320s)). Damage is learned after the fact, not in-world.

![](../../02%20Art/References/ui/video-frames/valorant/kI6_uh-L4MU_1040_killfeed.jpg)
Kill feed and spectator count at [10:20](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=620s).

## 2. Round loop screens
![](../../02%20Art/References/ui/video-frames/valorant/kI6_uh-L4MU_1500_buy-phase-banner.jpg)
BUY PHASE banner at [15:00](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=900s): centred, x 42-58%, y 12-26%. A framed box (thin white corner brackets, translucent dark) with a tiny tracked caption "ROUND 10 /// DEFENDERS", the title in tall condensed off-white caps, and "PRESS [B] TO BUY" in tiny caps with a key-cap glyph. The timer in the scorebug counts the buy window.

![](../../02%20Art/References/ui/video-frames/valorant/kI6_uh-L4MU_0540_flawless-banner.jpg)
Round-result banner "FLAWLESS" at [5:40](https://www.youtube.com/watch?v=kI6_uh-L4MU&t=340s): same slot, wider box (x 36-63%, y 12-27%), a second thin bar under it carries the caption "DEFENDERS". Clutch/ace callouts use this same banner slot, so players learn one place to look.

Buy menu:

![](../../02%20Art/References/ui/video-frames/valorant/gbYeJyxNjp4_0410_buy-menu.jpg)
Buy menu at [4:10](https://www.youtube.com/watch?v=gbYeJyxNjp4&t=250s) (scorebug stays visible and live at the top, so time pressure is never hidden):
- Left column (x 2-20%): your card (portrait, credits large, "MIN NEXT ROUND" line, three quick-buy buttons "LET'S BUY / I HAVE EXTRA CREDS / LET'S SAVE") then teammates' cards with their loadout icons and credits.
- Centre grid (x 22-70%): category headings in tiny caps (SIDEARMS, SMGS, RIFLES, SNIPER RIFLES, SHOTGUNS, MACHINE GUNS, DEFENSE) over weapon tiles that show icon, name and price; the selected/hovered tile is filled teal-green; unaffordable tiles are dimmed; owned tiles are marked OWNED.
- Abilities row below the grid (y 74-89%): three large tiles (name, price, charges), teal when bought.
- Right panel (x 81-97%): stats of the hovered weapon (run speed, reload, magazine, fire rate, spread, damage by range) as small boxes with thin meters.
- Close X top-right. Credits and teammate economy are visible in one glance; the next-round minimum is shown to teach saving.

Scoreboard (Tab):

![](../../02%20Art/References/ui/video-frames/valorant/gbYeJyxNjp4_0550_scoreboard.jpg)
In-match scoreboard at [9:10](https://www.youtube.com/watch?v=gbYeJyxNjp4&t=550s) (x 30-70%, y 29-70%): columns NAME, ULTIMATE (ready state), K/D/A, LOADOUT (weapon and shield icons), CREDITS, PING. Own-team rows teal-tinted with your row highlighted, enemy rows red-tinted below, and a thin strip between them with round-win ticks (ATK/DEF). Dense, but only 6 columns, aligned numerals, tiny headers.

Match end:

![](../../02%20Art/References/ui/video-frames/valorant/eL4DTjNX9r4_1740_match-end.jpg)
End screen at [17:40](https://www.youtube.com/watch?v=eL4DTjNX9r4&t=1060s): "10 DEFEAT 13" centred top in condensed caps (the word biggest, the scores flanking it, the result word coloured), sub-tabs PROGRESSION / SUMMARY / SCOREBOARD / TIMELINE / PERFORMANCE in tiny tracked caps, a two-column Match Results | Progress layout with thin hollow frames and corner notches, an "XP EARNED" number at the bottom, and one button "PLAY AGAIN".

## 3. Menus
![](../../02%20Art/References/ui/video-frames/valorant/eL4DTjNX9r4_0005_map-intro.jpg)
Map intro ([0:05](https://www.youtube.com/watch?v=eL4DTjNX9r4&t=5s)): giant condensed off-white map name "BIND" top-left over a darkened flyover, with a tiny coordinates line and the mode ("UNRATED") in tracked caps. Huge type + tiny type, nothing in between.

![](../../02%20Art/References/ui/video-frames/valorant/eL4DTjNX9r4_0100_agent-select.jpg)
Agent select ([1:00](https://www.youtube.com/watch?v=eL4DTjNX9r4&t=60s)): a pastel sky backdrop (calmer than the HUD); left column (x 3-20%, y 24-72%) lists all five teammates with names and a status line ("Picking..." until they lock, then their portrait); a huge countdown numeral top-left; the selected agent as a 3D model in the centre-right; the agent name in big pale-yellow condensed caps with the role above it in tiny caps, plus tabs INFO / C / Q / E / X and a short bio; the agent grid sits bottom-centre (x 30-70%, y 81-97%, two rows of nine small portraits) with a single LOCK IN button above it (x 50%, y 75%). See also [1:30](https://www.youtube.com/watch?v=eL4DTjNX9r4&t=90s) (YORU, role and ability tabs).

![](../../02%20Art/References/ui/video-frames/valorant/eL4DTjNX9r4_0030_main-menu.jpg)
Main menu ([0:30](https://www.youtube.com/watch?v=eL4DTjNX9r4&t=30s)): a centred top nav HOME / BATTLEPASS / AGENTS, the PLAY tab in the middle (shows the queue timer when searching), CAREER / COLLECTION / STORE on the right; mode tabs (UNRATED, COMPETITIVE, SPIKE RUSH, DEATHMATCH, ESCALATION, CUSTOM GAME) in tiny caps; the party as five tall player cards with "READY" labels; one teal "IN QUEUE" primary button bottom-centre and quieter "PRACTICE / LEAVE PARTY" beside it. Navy-black background with a red tint, off-white text, thin white frames.

Collection/loadout was not covered by these videos; see the owner's screenshots or a later pass.

## 4. Riot's stated UI principles (episode 9, [Riot Games](https://www.youtube.com/watch?v=sc3h5JXtIzw))
No frames from this video are used (League/Fortnite examples).
- UX comes first, UI second. UX decides where information lives and how few actions it takes to reach; UI then builds the visuals on that map ([1:42](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=102s)).
- Visual design means presenting complex information simply enough that the audience can act on it ([2:34](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=154s)).
- Know the audience and the platform: PC vs mobile need different interfaces (their Fortnite example) ([3:02](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=182s)). The genre decides how much UI there is ([3:31](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=211s)).
- UI is more than the HUD: maps, character select, inventory, quest windows are all part of it ([4:05](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=245s)).
- Build one ecosystem: fixed rules for the meaning of colours, text and screen position ([4:41](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=281s)); they wrote guidelines for typography, iconography, colour, shape language and animation, anchored on one theme (hextech) ([5:08](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=308s)).
- Layout is meaning: proximity tells you what belongs together (a bar next to an enemy name is that enemy's health), and layout controls how fast critical information is read ([6:05](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=365s)).
- Motion makes the message felt. Quote: "you can't polish a bad design into functioning the way you want" ([7:43](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=463s)). Five motion goals: responsiveness (fast, fluid), intention (lead focus to key actions), awareness (elements react from where they are), consistency (repeated motion patterns), physical intuition (movement fits the game's brand and feels natural) ([8:11](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=491s)).
- Workflow: UX flow, then UI with consistent shape/colour/layout/values, with motion artists reinforcing messages and feedback ([9:38](https://www.youtube.com/watch?v=sc3h5JXtIzw&t=578s)).

## 5. Valorant Mobile (China version) HUD
Sources are the China client (Chinese text with an English overlay in some frames), screen recordings at 1080p with letterbox bars. Percentages below are of the visible 16:9 area.

![](../../02%20Art/References/ui/video-frames/valorant/TI4qzsGLQaE_0335_mobile-hud.jpg)
Mobile HUD at [3:35](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=215s).

```
 0%                      50%                       100%
 +-----------------------------------------------------------+
 |                [3 <0:49> 0]  (slim scorebug, no portrait   |
 |                 row; x 40-62%, y 1-8%)       [mute][opts]  | top-right
 |                                    (melee)  (aim/scope)    |
 |  [kill feed rows                      (ping) (A1) (A2)     |
 |   x 8-19%, y 32-39%]                         (A3)          |
 |                                                     (jump) | 65%
 |   ( joystick,       [crosshair 50%,60%]                    |
 |     ~23%,63% )                                  (crouch)   |
 |   (A)  [minimap  30-40% x, 74-97% y]   (FIRE)              | 87-89%
 |        [hp/armor][weapon+ammo 43-58%]    ~69%,89%          |
 +-----------------------------------------------------------+
```

| Element | Position | Size | Style | Source |
|---|---|---|---|---|
| Scorebug | top-centre, x 40-62%, y 1-8% | much smaller than PC | score, small timer, no alive-portrait row | [3:35](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=215s) |
| Movement joystick | left, about 23% x, 63% y; "follow finger" or fixed or left-half-screen modes | about 12% wide | faint ring, drawn low-contrast so the view shows through | [3:35](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=215s), [0:25](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=25s) |
| Minimap | bottom-centre-left, x 30-40%, y 74-97% | about 10% wide (smaller than PC's 20%) | same dark map, no ring | [3:35](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=215s) |
| Health, armor, weapon, ammo | bottom-centre, x 43-58%, y 88-97% | one compact strip | weapon icon + ammo (10/20), grenade/secondary, health/armor numbers beside the minimap | [3:35](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=215s) |
| Kill feed | left-centre, x 8-19%, y 32-39% (PC: top-right) | small rows | relocated because the right side is full of buttons | [3:35](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=215s) |
| Right thumb cluster | x 69-90%, y 12-90% | circular buttons about 4-7% wide | melee (72%,12%), scope/aim (83%,14%), ability buttons stacked around (76-88%, 32%), jump (89%,65%), crouch (82%,87%), fire (69%,89%) | [3:35](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=215s) |
| Fire buttons | left-fire and right-fire, each can be always-on, off or "only when scoped"; "top-left zone fires"; right-fire can follow the finger | n/a | big, translucent | [0:45](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=45s) |
| Utility | buy-cart button bottom-centre; ping/notify buttons top-right | small | label under icons in tiny text | [0:45](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=45s) |

![](../../02%20Art/References/ui/video-frames/valorant/TI4qzsGLQaE_0045_mobile-layout-editor.jpg)
Layout editor ([0:45](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=45s)): a floating panel over the live HUD with a layout dropdown, "sync to all agents" checkbox, Exit / Reset / Save and use, per-button Size % and Opacity % sliders, nudge arrows, and "hide button". Three presets: two-finger, multi-finger (claw) and compact for small screens. Layouts can be saved per agent and shared by in-game friend send or a share code (search by code in a cloud/library panel). Transcript: [0:30](https://www.youtube.com/watch?v=TI4qzsGLQaE&t=30s) onward.

Settings that change HUD behaviour ([IvOhdhX9-3k](https://www.youtube.com/watch?v=IvOhdhX9-3k)): walk modes (button, in-joystick, separate walk joystick), scope and crouch as tap/hold/mixed, aim assist, per-weapon-class "smart fire" (sidearm, SMG, rifle, MG, sniper, shotgun: off / ADS & fire / crouch & fire / both) ([3:50](https://www.youtube.com/watch?v=IvOhdhX9-3k&t=230s)), left-hand mode, and a settings screen that is a left vertical tab list (BASIC, LAYOUT, GRAPHICS & AUDIO, AGENT, SENSITIVITY, CROSSHAIR, OTHER) with top tabs and rows of 2-3 radio options ([5:00](https://www.youtube.com/watch?v=IvOhdhX9-3k&t=300s)).

![](../../02%20Art/References/ui/video-frames/valorant/IvOhdhX9-3k_0500_mobile-map-settings.jpg)
Map options ([5:00](https://www.youtube.com/watch?v=IvOhdhX9-3k&t=300s)): radar local/global, camera rotate/fix, conical view, tap minimap to expand, show current callout, show location names off/buy phase only/always. Combat info toggles ([6:00](https://www.youtube.com/watch?v=IvOhdhX9-3k&t=360s)): kill banner names, ability announcer, ability tags, enemy highlight colour. Quick comms wheel (Walk, Rotate, Fall Back, Rush, Tactics, Need Healing) at [8:20](https://www.youtube.com/watch?v=IvOhdhX9-3k&t=500s).

What they resized or hid vs PC: portrait rows and the weapon list are dropped, the scorebug shrinks, the minimap halves, the kill feed moves, key letters under abilities are replaced by tap targets with name labels, and crosshair/aim/fire become buttons with configurable behaviour.

## 6. Takeaways for our game
Our tone: soft but tactical, not neon/glitch, not rounded and bubbly. Existing owner screenshots (the ability draft cards and bottom bar) already follow the right direction; use the points below to complete the rest.

### Round draft picks ("Mods") with Valorant clarity
- Reuse the BUY PHASE slot: a centred framed banner (x 42-58%, y 12-26%) with tiny caption "ROUND 3 /// DRAFT" and the title "DRAFT A MOD", plus "PRESS [KEY] TO PICK". The scorebug timer already counts the window; keep it visible and live above the picker.
- Use the agent-select pattern for the pick: a left roster column showing each teammate's state ("Picking..." then their locked pick icon), a row/grid of 3 cards in the centre, one LOCK IN button. Teammate states give social pressure without a chat.
- Colour code by teammate side: teal for ours, red for theirs, applied to roster rows and to the chosen mod icon in the kill-feed/scorebug alive row afterwards (a tiny mod icon under each portrait).
- After lock-in, the picked mods show on the bottom bar like Valorant's C/Q/E/X row: icon, key letter, readiness bar underneath, charge pips above. Same bar for every mod so players never relearn it.
- Card anatomy: tiny caps category tag, big condensed name, one-line description, price/rarity as a thin coloured line, not a badge.

### "Weapon tier opens" with Valorant clarity
- A round-start banner in the same slot: title "TIER 2: SMGS OPEN" (tiny caption "ROUND 4 /// ALL PLAYERS"), 1.5-2 s, no sound-effect noise beyond a single tonal tick.
- A persistent tier ladder inside the scorebug or beneath it (thin segments, the open tier filled teal, upcoming tiers outlined) so players can read "what weapons are legal now" at a glance, like Valorant's credit line.
- When the tier opens, the equipped-weapon list on the right edge (tiny icons) shows the newly allowed class with a one-time pulse, then settles. Stay with Valorant's rule: transient things use the banner slot, permanent things use fixed HUD slots.

### Borrow
- Hierarchy and fixed slots (top-centre state, top-left intel, top-right events, bottom-centre self, bottom-right ammo). Do not move anything per mode.
- Restraint: HUD is white text plus two team colours; accents only for state (red timer, red low health).
- Chamfered/notched thin-line panels, translucent dark fill, off-white type, tiny tracked caps for captions.
- Banner-per-phase, one place to look.
- Damage learning via a post-death report instead of floating numbers (we can show the same, it fits 1v1 to 4v4 duel rounds).
- Mobile: presets + per-element size/opacity editor + shareable layouts; relocate kill feed to the left-centre; shrink the scorebug and drop portrait rows.

### Do not borrow / adapt
- No Riot-specific marks, agent portraits, the exact hexagonal timer silhouette or the Tungsten-like type; use our own timer shape and a Roblox-available condensed face (check the Font enum, e.g. Oswald/BebasNeue-style) with a clean sans for numerals. Test at 1080p and on phone.
- Roblox UI has no native chamfers: build them with ImageLabel slices or UIStroke on a plain frame plus corner "tab" pieces, not UICorner. Never round them.
- Keep the red/teal contrast but soften for our tone: slightly desaturated, no neon glow, no glitch/scanline decoration (our own rule, and Valorant's HUD does not use it either).
- Valorant's menus are dense; our lobby is more social and simpler, so use fewer tabs and one primary action colour.

## Sources
- Riot Games, "So You Wanna Make Games?? | Episode 9: User Interface Design": [sc3h5JXtIzw](https://www.youtube.com/watch?v=sc3h5JXtIzw) (transcript).
- "Valorant Gameplay 4K (No Commentary)" (spectated/own-view Jett match, 1080p frames): [kI6_uh-L4MU](https://www.youtube.com/watch?v=kI6_uh-L4MU).
- "Valorant Unrated Random Agent Select?!" (agent select, menus, end screen): [eL4DTjNX9r4](https://www.youtube.com/watch?v=eL4DTjNX9r4).
- "What to BUY on EVERY ROUND in VALORANT (Economy Guide)" (buy menu, scoreboard, ability state): [gbYeJyxNjp4](https://www.youtube.com/watch?v=gbYeJyxNjp4).
- Valorant Mobile control layout/HUD (auto-captions used): [TI4qzsGLQaE](https://www.youtube.com/watch?v=TI4qzsGLQaE).
- Valorant Mobile settings explained (auto-captions used): [IvOhdhX9-3k](https://www.youtube.com/watch?v=IvOhdhX9-3k).
- Also screened but unused (no usable HUD variety): [zFioR7K-JLI](https://www.youtube.com/watch?v=zFioR7K-JLI).
- Project: [Valorant Gun Mechanics](../Valorant%20Gun%20Mechanics.md), owner screenshots in `vault/01 Design/ValorantUIExamples/`. LihFolk `05 UI and UX` (HUD Design, Responsive UI) was not consulted for this pass.

## Method and caveats
Frames were extracted with ffmpeg from the 1080p downloads (the video-analyzer tool returned no frames for the 4K video), sampled evenly; so some screens (clutch/ace callouts, collection) were not captured. Sizes and positions are estimated from stills, not measured from Riot's files. The mobile videos show the China client, whose HUD may differ from the global release.
