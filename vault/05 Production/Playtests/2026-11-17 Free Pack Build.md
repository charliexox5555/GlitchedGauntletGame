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

## Round 2: the owner's notes (2026-11-17, same day)
The owner looked and asked for:
- a Roller more like the Boom Bot and fiery (not "a blue thing");
- new Flash and Roller models (the Studio-part ones were disliked);
- the Flash to blind whoever has it **on screen**, with a coloured flash in Valorant's style and real sounds;
- Shock Dart's radius to be visible, plus fun animations;
- a better bow draw for Recon and Shock Dart;
- the F8 panel to list the new Mods (it didn't).

| Note | Done |
|---|---|
| F8 panel missing the new Mods | The Mod row had a fixed 3-line height (9 buttons); it now grows with the list. |
| Bow "at an angle, not drawn back" | Re-posed live in Play to the owner's Sova screenshots, using new Studio-only `TuneHold*` / `TuneBow*` attributes. Big (2.9 scale), canted 40°, right of centre, the fist low in the middle, the bolt head just under the crosshair, the draw pulling down-right. Strings thinned (0.55) and recoloured light, shafts steel; the bolt head glows and sparks as it's drawn. Both bows (Recon, Shock Dart). Self-grade 7.5. |
| Flash rule | Blinded if the pop is on your screen (80° default camera: ±56° across, ±40° up and down): 1.75 s in the centre to 1.25 s at the edge. Off screen within 100°: a 0.35 s glance. Behind you: nothing. |
| Flash look | Valorant's recipe (research below): a warm near-white peak that clears from the edges, a glow pinned on the pop's spot that shrinks into it, gold in the fade (owner's pick). The pop position is sent as `BlindFrom`. |
| Flash sounds | Pin pull, fuse whistle, a crack plus thump for the pop, a thump for the victim (ProSoundEffects; game rips skipped). |
| Shock Dart radius and fun | A lightning strike from above, a dome and floor disc at the true radius held 0.5 s, arcs crawling over the area, arcs to everyone hit. Self-grade 8. |
| Roller fire | A fire-crown blast (kit tongues), fiery bang and gas-fire sounds, fire-orange eyes (not team-tinted). |
| New models | An interview first (4 questions; the owner took every suggestion), then live Blender: the Roller (two big wheels, charcoal with fire glow, hazard chin, team antenna light) and the Flash (faceted flare canister, gold lens). Uploaded, built and installed; the installed models match the renders. |

**Research (agent, 2026-11-17; numbers from guides and patch notes, the look partly from memory):**
- Valorant flashes need line of sight and blind fully when you face them.
- Patch 5.07 made the white shrink as the blind ends; patch 2.02 cut the brightness of its first moment.
- Agents tint their flash mostly in the fade, and there is no ringing.
- Boom Bot: 60 HP, 5 s life, 80 → 30 damage between 2 m and 6 m; it bounces off walls and beeps faster as it locks on.

**Still for the owner:** save the match place (the new Roller and Flash models, bow strings, Shock Dart props); listen to the new sounds; a 2-client check; ChatGPT icons.
