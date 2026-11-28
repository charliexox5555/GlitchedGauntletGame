# UI Name Tags (lobby)

Name tags over every player in the lobby. v2 rebuilt 2026-11-28 after the owner said v1 (gold title, gold level chip, name, orange streak chip on plates, 2026-11-27) "looks so bad". Goal: the RIVALS feel, our own art. **Status: owner approved the look 2026-11-28; Studio-tested solo.**

## What it shows
Top to bottom, one tight block of floating type (no plates, no chips, no outlines):
1. **Title** in gold `FFC83D`, Rubik Heavy 20, only when one is equipped (`Shared/PlayerData.title`).
2. **Row:** level badge (our faceted hexagon, light `F4F6F9`, dark `10141B` number, Rubik Heavy 22) · **display name** (Rubik Heavy 44, `F4F6F9`, as the player typed it) · streak (our flame icon + orange `FF8A3D` number, Heavy 30, only when `WinStreak` > 0).
3. **@username** in `C3CAD4`, Bold 17, close up only (hidden when the tag is drawn below 0.8 size).

Every label has a drop shadow: a black copy 2 px down at 30% opacity (named `Shadow`), readable over the bright lobby without an outline or glow.

## How it works
- Template: `StarterPlayerScripts.UI.Templates.Lobby.NameTag` (Studio object, rebuilt by `tools/studio/BuildNameTag.luau`; v1 kept in `ServerStorage.UiBackups.NameTag_1`). Badge art: `art-source/ui/nametag/level_badge.png` (`tools/ui/nametag_badge.py`, image `rbxassetid://134852137458210`), flame: `art-source/ui/streak/streak_icon.png`.
- BillboardGui 520 x 140 px, `AlwaysOnTop`, `LightInfluence` 0, `MaxDistance` 50, `SizeOffset` (0, 0.5) so its bottom edge sits on the anchor point at any distance. **Anchored on the Head** (2026-11-28 fix): the controller sets `StudsOffsetWorldSpace` to half the head's height + `HeadGap` (0.5 studs), so the tag sits just over the head. It was on the HumanoidRootPart at +2.9; a slide drops the head ~2.1 studs while the root stays at standing height, so the tag floated ~2.6 studs over a sliding player (owner: "doesn't really move well with you when you slide"). Measured after the fix: the gap stays 0.50 studs every frame through sprint, slide and slide-jump. Owner OK 2026-11-28. The template's own offset is only used for a body with no Head.
- Size: a `UIScale` on `Root` (anchored bottom-centre, so it grows upward) = `(RefDistance / distance) ^ Falloff`, clamped `MinScale..MaxScale`. Attributes on the template: RefDistance 14, Falloff 0.7, MinScale 0.55, MaxScale 1.6, DetailScale 0.8, HeadGap 0.5. **Phones and tablets** (2026-11-28, owner: "way too big on mobile"): the tag is pixel UI drawn for 1080p, so on a ~390 px-tall phone it covered about three times as much of the view. When `Shared/UiLayout.family()` is Phone or Tablet the size is also multiplied by screen height / 1080 × `PhoneBoost` 1.5 / `TabletBoost` 1.2, capped at 1 (a 390 px phone: x0.54, so the name is ~24 px at 14 studs; a 768 px tablet: x0.85). Desktop and console are unchanged. Falloff < 1 shrinks slower than the world, so a tag at 30 studs still reads (pure world scale made it unreadable there).
- `LobbyClient/Controllers/NameTagController`: one copy per player for as long as they're in the server, in a client-made `Workspace.NameTags` folder (never replicates); respawns only move its `Adornee` to the new Head. Fills on `StateValues` changes (`Level`, `WinStreak`, `Title`) and `DisplayName`. Shown only while both you and they are in the lobby (`PlayZone` Lobby: hidden in the Range and matches), never over your own head in first person; hides the Roblox name while shown.

## Tested (Studio, solo, 2026-11-28)
- Title / level / streak update live (set Title "Season 1", Level 27, WinStreak 4 on the server → tag changed at once).
- Range and Match hide it; back to Lobby shows it; first person hides your own; respawn keeps the same tag on the new body.
- Shots at 10 and 30 studs; 60 is past MaxDistance (hidden). The Studio capture tool doesn't draw `AlwaysOnTop` billboards or run the per-frame scale for its own camera, so shots used a copy with AlwaysOnTop off and the scale the controller would set.
- **Not yet:** a 2-player Local Server and the phone Device Emulator (owner).

## RIVALS study (`Workspace.NameTag` in our place, 2026-11-28; reference only)
- BillboardGui sized in **studs plus pixels**: `{25, 100} x {5, 20}` (scale = studs), so it shrinks with the world and keeps a small pixel floor; `AlwaysOnTop` true, `MaxDistance` 32, `LightInfluence` 0, `StudsOffsetWorldSpace` (0, 4, 0) on the HumanoidRootPart.
- Layout: a horizontal row of [level badge image with the number on it, blue gradient] · [display name, large Bold white, with `@username` small right under it, negative list padding] · [input-device icon]. The win streak is a flame image with an orange-gradient number that swaps into the badge slot. Text has only a faint dark stroke (2 px at 87.5% transparency) for legibility.
- Kept: the hierarchy (badge · big name · small @username), tight stacking, big type up close, AlwaysOnTop, HumanoidRootPart anchor. Not taken: their badge/flame/device art, blue gradients, the device icon, their font and stroke.
- The owner's reference copy `Workspace.NametagGui` is third-party: delete it from the place before publishing.

Related: [UI Theme v4 Soft Edge](UI%20Theme%20v4%20Soft%20Edge.md), [Style Bible](Style%20Bible.md), [RIVALS UI and Client](../03%20Research/Rivals%20Reference/UI%20and%20Client.md).
