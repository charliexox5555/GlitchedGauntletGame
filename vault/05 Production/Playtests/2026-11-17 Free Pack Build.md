# Playtest: free pack build (Shock Dart, Flash, Roller), 2026-11-17

Studio Play (solo, test range), driven through the dev remotes and keys. Built from [Handoff - New Abilities](../Handoff%20-%20New%20Abilities.md); specs in [Shock Dart](../../01%20Design/Abilities/Shock%20Dart.md), [Flash](../../01%20Design/Abilities/Flash.md), [Roller](../../01%20Design/Abilities/Roller.md).

## Results
| Check | Result |
|---|---|
| Shock Dart L1 at a dummy's feet | 100 → 66 HP (chest 3.4 studs off: 50 → 25 falloff) ✅ |
| Shock Dart G2 Static | no damage, Hinder 2 s on the dummy ✅ |
| Shock Dart B3 | 4 charges ✅ |
| Flash L1 quick pop (RMB) looking at it | blinded 1.5 s at strength 0.88, the white-out shows; the dummy facing it blinded too ✅ |
| Flash G2 Exposure | 2 facing dummies revealed 3 s (style Exposure), nobody blinded ✅ |
| Flash A3 | 3 charges ✅ |
| Roller L1 at a dummy 13 studs ahead | placed → locked 0.15 s later → warned → boom 0.6 s after the lock; 100 → 53 HP after the stop-at-feet fix ✅ |
| Roller G2 Remote | ModTrigger 0.6 s after placing: boom, no lock needed ✅ |
| Roller B3 | 1 charge spent, no stray model, no errors ✅ |
| Shock Dart bow in first person | Recon's hold and draw, power / bounce meter ✅ |
| HUD | stand-in icons show on all three ✅ |

## Fixed during the test
- Roller: a text replace made its raycast helper call itself (stack overflow every frame, Studio at 3 fps); fixed.
- Roller rolled through its target before the blast: it now stops 1.2 studs from them.
- Shock Dart's ring stood up (it used the flight direction): the server now sends the surface normal.
- Blasts: soft glows and the bolt texture vanished on the pale floor, and RECALL_FLASH (85958731477951) fails to load. Rebuilt on the rework kit's solid pieces (FX_Stroke arcs, FX_FloorStar, FX_Ring) with MOD_SPARKLE as the hard flash.
- Flash plates: overlapping plates stacked their see-through into patches; now one CanvasGroup. Two filler plates closed a gap at the top.
- RollerFx: a pooled hum Sound destroyed with an old model broke the next track (a stray model left behind). It now owns its hum.

## Grades (self, 0-10)
- Shock Dart burst: 7 (reads as electric; arcs could crawl more).
- Flash white-out: 8. World pop: not captured (whoever looks is blinded).
- Roller model: 6 (Studio parts, readable; wants a Blender pass). Roller blast: 6.5.
- Flash canister: 6.5 (bands bloom a little).

## Not checked
- The 2-client test (what others see of each): needs the owner (Test → Clients and Servers, 2 players).
- Bots using the new Mods in a real match (the rules are in; only dummies were in the range).
- The Flash world pop capture; third-person poses (the activations' generic clips: Throw / Lob / Place / the bow).
