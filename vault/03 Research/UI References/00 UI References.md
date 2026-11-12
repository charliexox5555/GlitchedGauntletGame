# UI References (video study, 2026-11-12)

What RIVALS (PC and phone) and Valorant (PC and Mobile) do with their UI. It was studied from YouTube videos with the [Video Analyzer](../../04%20Tech/Video%20Analyzer.md) tool so we could draft our own theme: [UI Theme v4 Soft Edge](../../02%20Art/UI%20Theme%20v4%20Soft%20Edge.md). These notes are references, not things to copy.

| Note | What's in it |
|---|---|
| [Rivals PC UI](Rivals%20PC%20UI.md) | In-match HUD map, team score strip, round flow, lobby, settings, clutter. 18 frames |
| [Rivals Mobile UI](Rivals%20Mobile%20UI.md) | Touch layout with % positions and sizes, thumb zones, mobile assists, HUD editor, phone menus. 16 frames |
| [Valorant UI](Valorant%20UI.md) | PC HUD slots, banners, buy menu, agent select, match end, combat report, Riot's UI principles, Valorant Mobile reflow. 16 frames |

Frames are in `vault/02 Art/References/ui/video-frames/` (git-ignored: third-party images never get committed). Every claim in the notes links to the video at its timestamp.

## The 12 findings that shaped v4
1. **Fixed slots, never moved per mode** (both games): state top-centre, events top-right, self bottom-left/centre, ammo bottom-right, centre third clear except the crosshair. ([Valorant UI §1](Valorant%20UI.md), [Rivals PC UI](Rivals%20PC%20UI.md))
2. **One banner slot for every phase message** (BUY PHASE, FLAWLESS…) at about x 42-58%, y 12-26%. We use it for "TIER II OPEN", the draft and round results.
3. **Agent select is the model for our Mod draft**: a roster with each teammate's "Picking… / Locked in" state, three cards, one LOCK IN.
4. **Restraint in colour**: white text plus two team colours. Accents only for state (low HP, timer). RIVALS gives purple and yellow several meanings at once, which costs it.
5. **Valorant plates are thin-lined and chamfered; RIVALS plates are chunky and rounded.** The owner wants "corners but also smooth", which became v4: chamfered plates **plus** true circles.
6. **RIVALS touch buttons are translucent circles.** Jump is about 17% of screen height; fire, ADS and slide about 14.5%; reload 10%; utility only 6% (too small). Five buttons sit in the right cluster.
7. **Every serious mobile player customises the layout.** Position, size and opacity per button, presets, left-handed mirror. Valorant Mobile adds share codes. We need an editor from day one.
8. **Valorant Mobile reflow**: the scorebug shrinks, the minimap halves, the kill feed moves to the left-centre and the portrait rows go.
9. **Weapon tier needs a persistent chip** near the timer (a thin ladder), and a one-time banner when it opens.
10. **Damage**: RIVALS shows a red wedge and vignette, no numbers. Valorant teaches damage through a post-death combat report. Both keep the centre clean.
11. **Round end is under-designed in RIVALS** (a green "ROUND WON" block, decimals in the timer): a chance for us to do better with a restrained banner, a score tick and "next draft in 3".
12. **Riot's principle**: flow (UX) before visuals (UI), and one rulebook for colour, type, shape and motion. That is what [the gauntlet-ui-style skill](../../../.claude/skills/gauntlet-ui-style/SKILL.md) is.

## Not covered yet (follow-up searches)
- Kill cam and match-end screens in RIVALS; clutch and ace callouts in Valorant.
- RIVALS loadout and locker on a phone, and the Touch settings tab itself (slider names).
- Console (gamepad) UI for either game.
