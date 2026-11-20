# Kill feed, ELIMINATED, killed-by and spectate (2026-11-14)

**Owner's brief:** the kill feed and the spectate screen next, "same style" as the new top bar, HUD and draft.

## Before
All code-built: the kill feed rows (Oswald, a team-colour edge strip, an outline on your rows), the ELIMINATED pop (skull diamond, gradient slant, headshot pill), the SPECTATING bar (cut plate with an outline, `<` `>` arrows, thin health line). No killed-by panel at all.
![before](References/ui-overhaul/2026-11-14-feed-spectate-before.jpg)

## Mockup v1 (in Studio, waiting on the owner)
`StarterGui.FeedMockup` in the match place (Enabled off), two canvases; rebuilt by `tools/studio/BuildFeedMockup.luau`.

One rule for all four: **a team-colour block with a slanted end that joins a navy plate** (the top bar's slant cap), dark ink on the bright block (keycap rule, readable at feed size), Builder Extended ExtraBold, soft shadows on the big cards. No outlines, edge strips, pills, glows or gradients.

- **Kill feed** (top right, under the top bar, right-aligned, width fits the names): killer block in their team colour, then on navy the gun silhouette (or the Mod's icon), a gold skull for a headshot, and the victim's name in their team colour. Rows with you in them sit on the brighter navy (no outline).
- **ELIMINATED** (your kill, just under the crosshair): a red skull block, ELIMINATED, the victim and HEADSHOT in gold, and the kill-ladder bars under it (one per kill this round, lit red).
- **Killed by** (new; bottom centre during the death camera): the killer's headshot cell, a red block with KILLED BY and their name, their gun and HEADSHOT, and **their HP left**.
- **Spectating** (bottom centre): `<` `>` keycaps either side, the player's cell, a team block with SPECTATING and the name, and their HP with the bottom HUD's segment bar.

Death: ![death](References/ui-overhaul/2026-11-14-feed-mockup-death.jpg)
Spectating (v2, no kill pop): ![spectate](References/ui-overhaul/2026-11-14-feed-mockup-spectate.jpg)

## Mockup v2: the kill pop (owner on v1)
Owner: the kill pop should be "a little more simple", the skull "doesn't look" right, it shouldn't say "eliminated" + a name (it read oddly next to the spectate bar), and "more like Valorant… a circle with the skull, or maybe… the sword… something fun, different".
- **Kill pop = a circle, no words:** a navy disc with a white emblem, ringed by **5 segments, one lit red per kill this round** (the kill ladder). A headshot turns the emblem and its lit segments gold. It pops from its centre, a little bigger each kill (as now), under the crosshair, only for your own kills.
- **Three emblem options** (`tools/ui/make_kill_icons.py` → `art-source/ui/hud/kill_*.png`, faceted like the HUD icons):
  - **A Sword** (`rbxassetid://123591008906340`): one blade up, crossguard, diamond pommel.
  - **B Crossed blades** (`rbxassetid://98763575799680`).
  - **C Glitch shard** (`rbxassetid://76745392849672`): a diamond cut in three, the slices knocked sideways, with cyan / pink copies offset behind (the glitched draft title's split): the game's name.
  - Ring segment `rbxassetid://136514326667794` (rotated 72° per segment).
- The ELIMINATED card is gone from the spectate view.

Kill pop options: ![options](References/ui-overhaul/2026-11-14-kill-pop-options.jpg)

## Built (live on desktop; owner picked C, the glitch shard)
- **Studio-owned guis** (backup `tools/studio/BuildFeedScreens.luau`, checked: a rebuild matches Studio with 0 differences):
  - `StarterGui.KillFeed` (DisplayOrder 6): `Canvas.Feed` (vertical list, right-aligned, under the top bar) and `Canvas.KillPop` (5 ring segments, navy disc, the glitch shard with its cyan / pink split).
  - Feed row template `ReplicatedStorage.UiTemplates.KillFeed.Row`: a fixed holder, the `Strip` (CanvasGroup, horizontal list, sizes to the names) right-aligned in it.
  - `StarterGui.DeathScreen` (DisplayOrder 7): `Canvas.KilledBy` and `Canvas.Spectate` (`<` `>` keycap buttons either side of the strip).
- **`Controllers/KillFeedController`** fills the feed and the kill pop from the `Killed` event. Rows slide in from the right and fade (5 s, 4 at most, newest on top), rows with you on the brighter navy, no killer block for the zone / falls / your own Molly. Your kill: the disc pops from its centre (bigger each kill this round), one more ring segment lit, gold on a headshot. `Util/KillFeed` keeps playing the kill sounds (its kill-tone ladder, another session's uncommitted work); its old code-built rows and pop are taken off screen on desktop.
- **`Util/DeathScreen`**, fed by `SpectateController`: killed-by during the death camera (killer's headshot, name, gun or Mod, HEADSHOT, their HP left), then the spectate bar (name in their team colour, live HP and segments). The `<` `>` keycaps cycle; a click on them doesn't also count as the Fire / Aim cycle. The old bar is hidden.
- Phones keep the old feed and bar until the mobile pass.
- **Checked live** (2v2 bot match): killed-by (JINX, Classic, 100 HP left), spectating NOVA (80 HP), feed rows, and the kill pop (sent by a test `Killed` from the server: the glitch shard, gold on a headshot).

Killed by: ![killed by](References/ui-overhaul/2026-11-14-live-killed-by.jpg)
Spectating: ![spectate](References/ui-overhaul/2026-11-14-live-spectate.jpg)
Kill pop (headshot): ![kill pop](References/ui-overhaul/2026-11-14-live-kill-pop.jpg)

## Kill pop v2 (owner: "not really satisfying enough, and too high up")
- **Lower:** centre at y 790 (of 1080), above the Mod cells, like Valorant's kill banner (was 650, just under the crosshair).
- **Impact** (`KillFeedController`, beats at the top of the file; the owner's "oomph" rule: snap, brake, overshoot, settle):
  - slams in from 1.6x (a bit bigger each kill) to 0.88 in 70 ms, rebounds to 1.06, settles to 1;
  - on the hit: the disc flashes white (gold on a headshot), a **shockwave ring** bursts out to 2.1x and fades (`tools/ui/make_kill_icons.py` → `kill_wave.png`, `rbxassetid://128750671180422`);
  - the ring spins into place from -70° (each segment turns on its own); the new segment lights white-hot, a little out, then takes its colour and settles in;
  - the glitch split snaps from ±16 px to ±4 and the shard kicks side to side (7, -5, 3, 0 px);
  - out: the split closes, it shrinks to 0.85 and fades.
- Studio: `KillPop.Wave` (the shockwave), `Group` is now 1.3x with room around the ring (a CanvasGroup clips), `Group.Ring` holds the segments, `Disc.Flash`. Backup updated; rebuild matches Studio (0 differences).
- Checked in play (a test `Killed` from the server): no errors; settled frame below. The impact itself is too fast for a still capture.
![kill pop v2](References/ui-overhaul/2026-11-14-kill-pop-v2.jpg)

## Fix: hotbar over the ammo panel (owner, testing)
The hotbar sat a fixed 106 px above the bottom while the ammo panel grows with the screen (its UIScale), so above 1080p the panel ran into it. `StarterGui.BottomHud.Root.Right` is now one column (hotbar, ammo, key hints) with a vertical `UIListLayout` (8 px) and one `Fit` UIScale, so they stack at any size. `Util/BottomHud` and `tools/studio/BuildBottomHud.luau` updated (rebuild matches Studio but for preview-only values). Checked at 1.4x scale: 11 px between each.
![1.4x](References/ui-overhaul/2026-11-14-hud-right-column-1_4x.jpg)
## Assist feedback

The player who helped with an elimination gets a small cyan **+1 ASSIST** popup. Assisted eliminations have a count tag on the desktop and compact kill feeds. The tag lights up for the player who earned the credit. Scores and UI use the same award from StatsService, based on damage within the match's assist window.

