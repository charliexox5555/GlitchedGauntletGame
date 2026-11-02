# Playtest: 2026-11-02, Whitebox first walk

**Build / commit:** first Whitebox model, gauntletgame place
**Testers (device):** Claude only, one player in a Studio playtest on PC, driven with real keyboard and mouse input through the Studio MCP
**Matches played:** none; this checks scale and collision, not fun

## What was tested
| Test | Result |
|---|---|
| Spawns inside the arena with `TestMap` set | ✅ Blue alcove, facing into the map |
| Player size against the map | ✅ 5.44 studs tall; cover and doorways read to scale |
| Walk up the ramp onto the perch | ✅ Feet reach 7 studs at Z 41 |
| Jump onto the perch from the floor (7 tall, jump 7.2) | ✅ Lands on top |
| Hop the frame sill and pass under the lintel | ✅ Clear, with no head bump |
| Shoot a wall with the Vandal | ✅ Hits, bullet holes and smoke show on the panels |
| Console errors from the map | ✅ None. One asset warning for 203785492 repeats; that id isn't in `src` or `tools`, and it isn't one of the map's assets |

## Not tested yet
- Slide, sprint timing and the real spawn-to-centre time; the 2.5 s is still the script's estimate
- The 9 abilities on this map, including Updraft against the 48-stud walls and Molly or Frost thrown over them
- `ThinWall` slabs with a wall-penetrating gun
- A 2-player fight, sightlines in real use, white avatars against the walls
- Phone view, the no-shadow and greyscale checks, frame rate with the 178 textures
- Mirrored checks at the Yellow end (it is a rotated copy of the Blue end)

## What the user should look at
- Does the scale feel right walking around?
- Are the panel lines too strong, too faint or a good size?
- Are the blue and yellow bands and letters too much?

## Top fixes (ranked)
None found so far. Waiting for the user's walk.
