# RIVALS (PC) UI reference

Study of the Roblox game RIVALS' PC UI from five YouTube videos (about 38 frames viewed). Purpose: understand layout, hierarchy and patterns before the owner designs our UI in Figma. **Not a copy brief.** Frames are third-party images: they live in the git-ignored folder `vault/02 Art/References/ui/video-frames/rivals-pc/` and must not be committed.

Frame size read: 1280x720 captures, so positions below are % of screen (x from left, y from top) and map 1:1 to a 1920x1080 reference (multiply by 19.2 / 10.8). Anything I could not verify from a still is marked "(my read)".

## Summary

- RIVALS' HUD is **sparse in the centre and anchored to edges**: one wide score strip top-centre, health bottom-left, weapon/ammo bottom-right, kill feed top-right, tasks panel left. The crosshair is tiny, with a gap, and is the only thing in the middle.
- **Team colour is the main code**: purple vs yellow panels, kill-feed rows and name text. Red is reserved for damage (directional wedge, vignette, low HP). Green means full HP and "good".
- Status is shown as **icons and bars, not text**: player slots in the score strip use head + level badge + platform icon + a tiny HP bar; dead players become skulls.
- The in-match screen carries one clear piece of clutter: the persistent **Daily Tasks** panel (there is a "Hide Side Tasks" setting, so players complain about it).
- Menus are **dark, glossy, game-y**: black bars with white bold text, saturated green/blue/red buttons, illustrated 3D icons. Heavy "Roblox simulator" feel; this is the part we should NOT inherit.

## 1. In-match HUD

Screen map (1920x1080 reference, % of screen):

```
x:  0%        25%                50%                75%         100%
y0  [rbx menu pills]  [ OWN TEAM  score ][ TIMER ][ score ENEMY TEAM ]   [gear]
    top-left          x24.5-44 / y1-9     x45.8-54  x55.8-75.5   top-right
y9                                                      [kill feed rows y8-15%, x81-99%]
    [chat log tiny, y5-9%]
y37 +-----------+
    | Daily     |
    | Tasks     |                    + crosshair (tiny, centre, 50%/50%)
    | panel     |                    [red damage wedge near centre when hit]
y61 | x1-20%    |
    +-----------+
                                     [ "Pick Weapons [M]" blue button y72%, centre ]
                                     [ "Eliminated <name>" / "You're up next!" y80-90% ]
y85 [spec count box x3-8%]                        [ hotbar: 4 weapon icons x76-97% y83-95% ]
y91 [ HEALTH PILL x1-21%, y91-95% ]               [ ammo "20 100" + weapon name, right-aligned ]
y97                                  [ key hints pill x77-99%, y96-98% ]
```

Element table:

| Element | Position | Size | Style | Colour | Source |
|---|---|---|---|---|---|
| Score strip (own team) | top-centre, left of timer, x24.5-44%, y1-9% | about 20% x 8% of screen | slightly angled/gradient panel, small corner radius, 4 player slots + big score number on the inner edge | purple (or yellow, team-assigned) with white numerals | [1:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=60s), [1:30](https://www.youtube.com/watch?v=WXABSLhp9nM&t=90s) |
| Score strip (enemy team) | mirrored, x55.8-75.5% | same | same, number on inner edge | yellow (or purple) | same |
| Round timer | centre between strips | about 8% wide | dark grey-teal box, hourglass icon + `m:ss`; in the intermission it drops the hourglass and shows decimals (`2.6`, `4.3`) | white on dark | [3:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=180s), [4:50](https://www.youtube.com/watch?v=q97rS_Z66Lk&t=290s) |
| Player slot (in strip) | inside team panel | about 3.5% wide each | head portrait, blue starburst level badge, platform icon (PC / phone / pad), thin HP bar on top; dead = white skull on dim slot | green HP bar | [1:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=60s), [4:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=240s) |
| Health | bottom-left, x1-21%, y91-95% | about 20% x 3% | long dark pill, black outline, fill bar, number + heart at the right end | green full -> yellow-green -> orange -> red as HP drops (150 max seen) | [1:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=60s), [7:00 (low HP)](https://www.youtube.com/watch?v=U9XcolnRiXA&t=420s) |
| Ammo | bottom-right, right-aligned, y79-85% | mag number about 4% tall, reserve about half that | big bold white mag count, small reserve + bullet icon, weapon name in bold below; no panel/background | white (weapon name goes gold for special weapons) | [1:30](https://www.youtube.com/watch?v=WXABSLhp9nM&t=90s) |
| Hotbar | bottom-right, x76-97%, y83-95% | 4 icons about 4% wide each | frameless weapon icons; selected one larger and brighter; mag count sits left of it; slot numbers 1-4 shown in the FFA mode | icons keep their own colours | [1:30](https://www.youtube.com/watch?v=WXABSLhp9nM&t=90s), [0:27](https://www.youtube.com/watch?v=a3B5CQkX0Lk&t=27s) |
| Key hint pill | bottom edge, x77-99%, y96-98% | tiny (about 1% tall text) | dark pill, `Label KEY` pairs with a small key chip | grey-white | [1:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=60s) |
| Crosshair | dead centre | about 1.5% | thin tick marks with a gap around the centre dot; configurable colour, "critical" colour, scoped bars and dot | white by default (magenta/purple dot in some clips) | [6:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=360s), [7:15](https://www.youtube.com/watch?v=q97rS_Z66Lk&t=435s) |
| Damage / hit indicator | around the crosshair, pointing at the source (my read) | about 8% wide arc | red curved wedge/chevron that rotates; no numbers seen | red | [8:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=480s), [6:00](https://www.youtube.com/watch?v=WXABSLhp9nM&t=360s) |
| Low HP / hurt | full-screen edge | whole screen | pinkish-red vignette that stays while hurt | red-pink | [6:00](https://www.youtube.com/watch?v=WXABSLhp9nM&t=360s), [7:30](https://www.youtube.com/watch?v=WXABSLhp9nM&t=450s) |
| Kill feed | top-right under the gear, x81-99%, y8-15% | rows about 2.5% tall | tight stack of pills: `attacker + assist | weapon silhouette | victim`; own kill row gets a white outline | row colour = killer's team (yellow or purple) | [6:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=360s), [0:27 FFA](https://www.youtube.com/watch?v=a3B5CQkX0Lk&t=27s) |
| Elimination text | lower centre, y80% | about 2% tall | plain text: white `Eliminated` + victim name in the victim team colour | white + team colour | [6:00](https://www.youtube.com/watch?v=WXABSLhp9nM&t=360s) |
| Teammate/enemy markers | on players, through walls | scales with distance | portrait card with purple gradient, green HP bar below; round cyan ring around nearby players in the round-start frame (purpose unknown) | purple card, green bar, cyan ring | [3:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=180s), [1:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=60s) |
| Spectator count | above health, x3-8%, y84-88% | small | dark box with eye icon + number | white | [1:30](https://www.youtube.com/watch?v=WXABSLhp9nM&t=90s) |
| Daily Tasks panel | left, x1-20%, y37-61% | about 19% x 24% | translucent dark-grey gradient panel, bold title, 3 rows with cyan progress bars and gold key reward `x2 x3 x4` | cyan bars, gold rewards | [1:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=60s) |
| Roblox menu pills + gear | top-left (logo, hamburger, chat, mic in one black pill), top-right (gear in a black circle) | small | black pill/circle (Roblox default) | black | all |
| FFA rank row | top-centre, 7 avatar chips `#1..#7` with scores under, timer above | about 40% wide | avatars on dark with numbers, no panel | white | [0:27](https://www.youtube.com/watch?v=a3B5CQkX0Lk&t=27s) |

![](../../02%20Art/References/ui/video-frames/rivals-pc/U9XcolnRiXA_0100_hud4v4.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/WXABSLhp9nM_0130_hud3v3_hotbar.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/q97rS_Z66Lk_0314_hud1v1_sniper.jpg)

Team scores 2v2-4v4: the same strip, just more slots. 1v1 shows one head per side; 3v3/4v4 show 3-4. No minimap anywhere. Round score is one large number per team, next to the timer (not a "best of" tracker).

Hierarchy (big -> small): score numerals and timer > ammo count > health bar > weapon name > key hints and task panel > kill feed text. The crosshair is the smallest thing on screen on purpose. Nothing animates constantly; animation is reserved for the damage wedge, the kill feed slide-in and the countdown.

## 2. Round flow screens

- **Round countdown / intermission.** The timer box changes to a decimal (`4.3`, `2.6`) and the hourglass disappears. The green `ROUND WON` banner (white small `ROUND`, huge bold `WON`) sits right under the timer, about 15-23% down: [4:50](https://www.youtube.com/watch?v=q97rS_Z66Lk&t=290s). A blue `Switch Weapons [M]` button appears at screen centre-low in the same window.
- **Round-start reveal.** Players get large portrait cards with HP bar, visible through walls, plus cyan rings: [3:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=180s).
- **Death / spectate.** No kill-cam seen. After you die the view snaps to a teammate/opponent (scope view in [4:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=240s)) with a bottom-centre name plate flanked by two blue arrow chips (arrows show mouse buttons in 3v3), at y72-79%: [7:30](https://www.youtube.com/watch?v=WXABSLhp9nM&t=450s). In Tag Team a `Pick Weapons before spawn [M]` blue button plus a dark `You're up next!` pill take that spot: [3:00](https://www.youtube.com/watch?v=WXABSLhp9nM&t=180s).
- **Match end / rematch.** Not captured in these videos (the clips cut away). The lobby shows `To Hub` (red) and `Play` (green) buttons plus stacked `Task Completed` toasts: [6:27](https://www.youtube.com/watch?v=q97rS_Z66Lk&t=387s).

![](../../02%20Art/References/ui/video-frames/rivals-pc/q97rS_Z66Lk_0450_round_won.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/U9XcolnRiXA_0300_round_start_reveal.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/WXABSLhp9nM_0300_pick_weapons_prompt.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/WXABSLhp9nM_0730_spectate_bar.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/WXABSLhp9nM_0600_eliminated_vignette.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/U9XcolnRiXA_0400_spectate_scope.jpg)

## 3. Menus

**Lobby HUD.** Bottom-centre nav bar (x24-75%, y91-97%): seven icon + label items (Backpack, Weapons, Tasks, Shop, Pass, Settings, Event), tiny red count badges, white labels on a translucent dark strip. A green `Play` button sits above it at centre (x45-55%). Currency (gold keys + green `+`) is top-centre. Daily Tasks on the left with a glossy blue `To Duels` button. Leaderboard billboards are in-world (3D screens). Queue state: a dark top-centre pill `Searching for players.. 4v4 0:09` with a red X: [0:00](https://www.youtube.com/watch?v=U9XcolnRiXA&t=0s). Source frames: [q97 0:00](https://www.youtube.com/watch?v=q97rS_Z66Lk&t=0s), [WXAB 0:00](https://www.youtube.com/watch?v=WXABSLhp9nM&t=0s).

![](../../02%20Art/References/ui/video-frames/rivals-pc/q97rS_Z66Lk_0000_lobby.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/U9XcolnRiXA_0000_lobby_queue4v4.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/WXABSLhp9nM_0000_lobby_queue3v3.jpg)

**Loadout / weapon select.** A centre grid of tiles with the weapon render, label under it, and a gold star-sparkle backing for rare ones; map name in a dark bar above; four slot squares show what you picked; a `Random` shuffle tile: [0:18](https://www.youtube.com/watch?v=a3B5CQkX0Lk&t=18s). Between rounds in duels this shrinks to a single `Pick Weapons before spawn [M]` prompt.

**Skins / shop.** Full-screen 3D preview of the item, title top-centre with an item icon and a white caption bar (`Unboxed from...`), bottom search field with a red `Back` button, and a horizontal strip of small chips with rarity-coloured borders (red, cyan, green) and padlocks. Purchases use a plain dark modal with a blue `Buy`: [4:45](https://www.youtube.com/watch?v=q4aXJ6aAf3g&t=285s), [1:35](https://www.youtube.com/watch?v=q4aXJ6aAf3g&t=95s).

**Settings.** Top tab pill (Video, Audio, Game, Crosshair, Hotkeys, Account) in black with colourful icons; two-column layout: left = scrolling list, right = a help panel that explains the hovered setting; black section header bars; rows are dark bars with a red "reset" square at left, white/green toggles, sliders and number boxes; red X close top-right: [0:48](https://www.youtube.com/watch?v=q97rS_Z66Lk&t=48s), [7:15](https://www.youtube.com/watch?v=q97rS_Z66Lk&t=435s). Notable settings that show what players care about: Hide HUD, Hide Side Tasks, Padded HUD, Camera Shake, crosshair "critical" colour.

![](../../02%20Art/References/ui/video-frames/rivals-pc/q97rS_Z66Lk_0715_crosshair_settings.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/q4aXJ6aAf3g_0445_skin_picker.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/a3B5CQkX0Lk_0018_weapon_picker.jpg)
![](../../02%20Art/References/ui/video-frames/rivals-pc/q97rS_Z66Lk_0627_task_complete.jpg)

## 4. Colour meaning, hierarchy, clutter

- **Team:** purple vs yellow, used on score strip, kill-feed rows, victim names and player cards. Which colour is "mine" is assigned per match (left strip looked own-team, but its colour changed between clips).
- **Health:** green (full) -> yellow -> orange -> red, in the bar and as a full-screen vignette when hurt.
- **Damage / hit:** red wedge. **Reward / currency:** gold (keys, task rewards). **Interact / action:** saturated blue buttons (`Switch Weapons`, `Pick Weapons`, `To Duels`). **Leave / danger:** red. **Go / success:** green (`Play`, `ROUND WON`, task check).
- **Rarity:** red / cyan / green / gold borders on skin chips (mixed with team/damage meanings, which is a bit confusing).
- **Animates:** damage wedge, kill feed slide, timer decimals, ammo count changes, rarity sparkle. Everything else is static.
- **Clutter:** the left tasks panel, the tiny key-hint pill (hard to read, about 11 px), the Roblox menu pills, in-world kill/name tags with platform icons, and tiny score-strip slots that carry 4 pieces of information each.

## 5. What works / what feels cheap

Works:
- Edge-anchored, centre clear; the score strip reads at a glance (big numerals, team colour).
- Health bar colour ramp + vignette make low HP obvious without reading a number.
- Skull slots in the strip show alive/dead state with zero text.
- Settings with a live help panel and per-setting reset is a good pattern.
- Frameless ammo text and hotbar keep the weapon info quiet.

Feels cheap / cluttered:
- Glossy saturated Roblox buttons (blue/green/red) and "simulator" iconography.
- Tasks panel and promo billboards compete with the game.
- Level badges (blue starbursts) and platform icons inside tiny score slots are noise during a fight.
- Rarity colours overlap with team and damage colours.
- Key hints at 11 px are unreadable at 1080p.
- No visible damage numbers or headshot colour cue in these clips (a missing feedback layer, not a feature).

## Takeaways for our game

1. **Keep the RIVALS skeleton, restyle it.** Score strip top-centre, health bottom-left, ammo + hotbar bottom-right, kill feed top-right, crosshair alone in the middle. It is proven for duels and keeps eyes in the middle.
2. **We need a fifth slot: Mods.** Players draft abilities each round, so reserve a compact **mod row** (icons with cooldown ring and key letter) next to the hotbar or above health. Give it the same weight as the weapon hotbar; do not hide it in the key-hint pill.
3. **Show the shared weapon tier** as a small, always-visible tag near the timer or ammo ("Tier 3"), since the whole lobby shares it each round. It should read as a status chip, not a banner.
4. **Draft screen is our big new surface.** RIVALS' "Pick Weapons" prompt shows the pattern to avoid (a button that interrupts spectating). Make the draft a clear, short, full-width card row with a countdown, not a floating button.
5. **Team colour: pick two calm, non-neon hues** (our art direction: soft but tactical). Purple/yellow is a good model for contrast but is "arcade". Reserve red for damage only; use a different rarity cue (shape/border weight) so colour carries one meaning at a time.
6. **Flat, sharp-cornered panels with a thin border and slight tint**, not glossy rounded bubbles. Use the same corner radius everywhere (about 2-4 px at 1080p), no gradients on buttons, no pill-shaped everything.
7. **Typography:** a single semi-bold geometric sans, title case, heavy numerals for score/timer/ammo. RIVALS' look is bold-rounded; ours can be a squarer, tighter sans for the "tactical" feel.
8. **Round-end moments are under-designed in RIVALS** (a green rectangle that says `ROUND WON`, decimals in the timer). We can do better with a restrained slide-in banner, score tick, and a short "next draft in 3.0" line.
9. **Keep damage feedback minimal:** directional wedge + vignette are enough; add a headshot/crit cue (colour + size) and optional small damage numbers, since RIVALS shows none in these clips.
10. **Declutter by default.** No persistent tasks panel in a match; key hints larger (at least 14 px at 1080p) and only until the player has used them; keep a "Hide HUD" and per-element toggle like RIVALS does.
11. **Menus:** reuse the layout ideas (bottom nav strip, centre Play, queue pill top-centre, two-column settings with a help panel) but in our own style: dark neutral, one accent per screen, no glossy 3D icons.

## Limits of this study

- Frames are 720p stills sampled every 60-95 s, so I saw ordinary gameplay moments, not every transition. Round-end/match-end screens, hit markers on headshots and the death kill-cam were not captured.
- `WXABSLhp9nM` is Tag Team 3v3 (rotating spectate with "you're up next"), which differs from classic 1v1-4v4. `a3B5CQkX0Lk` is a tool-promo clip showing a gun-game weapon picker and an FFA HUD, so it is only used for the picker and the rank row. `q4aXJ6aAf3g` is mostly patch-note text; only the skin picker, buy modal and shooting-range HUD were useful.
- The automatic frame extractor returned 0 frames for the 24-minute video, so I downloaded the videos with yt-dlp and cut frames with ffmpeg. No transcripts were used.

## Sources

- [q97rS_Z66Lk](https://www.youtube.com/watch?v=q97rS_Z66Lk): settings / loadouts video (10 frames, 1v1 sniper HUD, round won, task toasts, settings)
- [U9XcolnRiXA](https://www.youtube.com/watch?v=U9XcolnRiXA): 4v4 match, team HUD, kill feed, spectate
- [WXABSLhp9nM](https://www.youtube.com/watch?v=WXABSLhp9nM): Tag Team 3v3, hotbar, pick-weapons prompt, spectate bar, damage vignette
- [q4aXJ6aAf3g](https://www.youtube.com/watch?v=q4aXJ6aAf3g): update video, skin picker, buy modal, shooting range
- [a3B5CQkX0Lk](https://www.youtube.com/watch?v=a3B5CQkX0Lk): weapon picker, FFA rank row

Frames: `vault/02 Art/References/ui/video-frames/rivals-pc/` (git-ignored).
