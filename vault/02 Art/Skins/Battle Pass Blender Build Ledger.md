# Battle pass Blender build ledger

## Poolside Spectre v02 · 2026-11-16

**State:** Owner approved v02 on 2026-11-16. v02 widens the blue gap between the stripes and moves the bend down at the fixed receiver–handguard join. v01 is the earlier bake.

- Inputs are the [approved Poolside concept](Poolside/out/Spectre_concept_v01.png), [stock Spectre RemasterV2 v05](../../../art-source/weapons/RemasterV2/Spectre/Spectre_RemasterV2_v05.blend), and [Blender handoff](Battle%20Pass%20Blender%20Handoff.md). The Blender MCP read-only query at `127.0.0.1:9999` reported scene `Scene` in `LobbyV4.blend`. The bake and reopen ran in isolated Blender processes.
- [Versioned blend](../../../art-source/weapons/Skins/Poolside/Spectre/v02/Spectre_Poolside_v02.blend) and [manifest](../../../art-source/weapons/Skins/Poolside/Spectre/v02/manifest.json). The material pass uses the original object names and shared stock atlas. Warm-white lanes follow both shoulders, with the yellow mark on the player-facing side. Native indicator emission and ammunition shading are retained.
- The four packed and external maps are [color](../../../art-source/weapons/Skins/Poolside/Spectre/v02/textures/Spectre_Color.png), [normal](../../../art-source/weapons/Skins/Poolside/Spectre/v02/textures/Spectre_Normal.png), [roughness](../../../art-source/weapons/Skins/Poolside/Spectre/v02/textures/Spectre_Roughness.png), and [metalness](../../../art-source/weapons/Skins/Poolside/Spectre/v02/textures/Spectre_Metalness.png). Apply them to the v05 stock meshes with the active UV atlas. Color is sRGB, the other maps are linear data, and normal is tangent-space +Y. This stock-mesh finish reuses the stock geometry asset.
- [Matched review sheet](../../../art-source/weapons/Skins/Poolside/Spectre/v02/review/stock-vs-poolside.jpg) covers three-quarter, both profiles, top, held, hip, ADS, the fixed join, a grazing angle, and the 128×72 reward thumbnail. [Stock motion comparisons](../../../art-source/weapons/Skins/Poolside/Spectre/v02/review/stock-motion.jpg) cover all five stock actions.

| Handoff rubric | Score | Evidence and open items |
| --- | ---: | --- |
| Design and finish | 33/35 | The blue enamel and two lanes read in the held and hip views. The lanes turn onto the fixed shoulder and terminate at the collar. The yellow mark is subtle in the 128×72 reward tile. |
| Geometry and stock fit | 30/30 | All 3,389 triangles, UVs, hierarchy, sight and grip locators, rig, and action data match stock after reopening. Both profiles and a grazing view pass the one-sided visual check. The dry-run audit reports the two inherited coplanar candidates at the suppressor and selector. Both use the same navy finish across the affected slots and look stable in the review stills. |
| Bake and seams | 18/20 | Four byte-identical packed and external 1024² maps, six-texel padding, and zero sampled UV overlaps. Both baked lanes are present on either side of the receiver–handguard seam. Their mean offset changes by 0.00195 and 0.00021 model units across the join. Stripe edges soften in the enlarged seam close-up. |
| Held, aim, and motion clearance | 14/15 | The stock ADS camera and sightline checks match. All 271 sampled frames across Draw, Fire, Inspect, Reload and ReloadEmpty produce matching object and locator transforms. The hold and inspect hand clearance checks use 91 archived arm-block samples and reproduce the stock contacts. Live animated arms and runtime checks are deferred with Studio integration. |
| **Total** | **95/100** | Blender review grade. |

**In production:** Rootglass Vandal from the [handoff](Battle%20Pass%20Blender%20Handoff.md), then Leafblade A / Broad Leaf and the remaining gun roster for both lines.
