# Overtime zone

The storm uses a continuous violet curtain, a bright ground line and slow-drifting magenta fragments. A small set of emitters adds upward sparks near the camera when it approaches the edge. The curtain is 320 studs tall and reaches 290 studs above the zone center. The texture is more visible above cover and feathers at the top, while the lower wall stays transparent enough to read cover. The ground line is inset slightly, and the fragments sit outside the curtain on their own radius.

## Source and Studio

The three Blender meshes total 1,344 triangles. The curtain has 128 connected facets and a horizontally seamless alpha tile. [OvertimeZone_v01](../../art-source/vfx/zone/OvertimeZone_v01) contains the production GLB. [OvertimeZone_v02](../../art-source/vfx/zone/OvertimeZone_v02) contains the updated Blender master, texture, [review render](../../art-source/vfx/zone/OvertimeZone_v02/OvertimeZone_v02.png), and [asset manifest](../../art-source/vfx/zone/OvertimeZone_v02/sources_manifest.json).

Match Studio stores the imported templates at `ReplicatedStorage.OvertimeZoneMeshes`. The group model asset is `118691081568110`. If reinstalling from the raw upload, set the Curtain's SurfaceAppearance to transparency with ColorMap `rbxassetid://139894604022278`. Set Curtain transparency to 0.13, make all three meshes double sided, and set GroundTrace and Drift to Neon. Current Studio templates have these properties staged.

`ZoneController` reads the existing server radius and owns the local warning. `OvertimeZoneVfx` scales the three imported meshes without collisions or hit queries. A single beam layer covers missing templates. The server still owns the zone centre, 20-second shrink, 4-stud final radius and outside damage.

## Studio preview

Open the Match place, press Play, and paste this in the Client Command Bar.

```lua
require(game.ReplicatedStorage.Shared.StateValues).set(workspace, "PreviewOvertime", workspace:GetServerTimeNow())
```

The visual-only preview starts near you, shrinks for 12 seconds, then holds for 8 seconds before clearing. Run the command again to restart it from your current position. The workspace TestMode toggle can stay off. During actual overtime the live zone takes priority. To clear the preview early, run the same command with `false` as the last argument.

[Studio playtest](../05%20Production/Playtests/2026-11-19%20Overtime%20Zone.md)
