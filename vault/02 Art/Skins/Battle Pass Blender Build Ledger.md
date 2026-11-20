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

The approved Poolside Spectre established the finish for the roster below.


## Rootglass heroes · 2026-11-16

| Hero | Design and finish | Geometry and stock fit | Bake and seams | Held, aim, and motion | Grade |
| --- | ---: | ---: | ---: | ---: | ---: |
| Vandal v02 | 33/35 | 30/30 | 18/20 | 14/15 | **95/100** |
| Leafblade A / Broad Leaf v02 | 34/35 | 29/30 | 18/20 | 14/15 | **95/100** |

- **Vandal.** The walnut leaves follow the stock rail and receiver, with a bronze seat and a faceted window. v02 moves the window above the support-hand envelope and trims the lower walnut leaf to clear the selector and magazine. All 309 stock frame samples match, and the new shells clear the moving assemblies, sightline, and 302 archived arm-block samples. The window is smaller than the concept rendering so it clears the stock left hand. [Blend](../../../art-source/weapons/Skins/Rootglass/Vandal/v02/Vandal_Rootglass_v02.blend) · [Manifest and maps](../../../art-source/weapons/Skins/Rootglass/Vandal/v02/manifest.json) · [Review](../../../art-source/weapons/Skins/Rootglass/Vandal/v02/review/hero-review.jpg) · [Motion](../../../art-source/weapons/Skins/Rootglass/Vandal/v02/review/motion-review.jpg)
- **Leafblade.** Broad Leaf follows the lead concept, reuses the original hilt contact surfaces, and seats its tang inside the bronze collar. v02 pulls the inlay inside the blade bevel. The stock grip anchor, blade reach, and 169 sampled frames across all seven Knife actions were checked. The archived hold proxy clears the added blade and inlay. The blade widens at the shoulder, so the live arm and camera read during slash and inspect remains part of the Studio pass. [Blend](../../../art-source/weapons/Skins/Rootglass/Leafblade/v02/Leafblade_Rootglass_v02.blend) · [Manifest and maps](../../../art-source/weapons/Skins/Rootglass/Leafblade/v02/manifest.json) · [Review](../../../art-source/weapons/Skins/Rootglass/Leafblade/v02/review/hero-review.jpg) · [Motion](../../../art-source/weapons/Skins/Rootglass/Leafblade/v02/review/motion-review.jpg)
- **Animator notes.** The Leafblade geometry is parented to the stock Knife Root bone. The original RightGrip locates the held hilt. The green inlay and named amber vein pieces travel with the blade. On Rootglass, use the primary AmberVein object as the inspect pulse target, travel from rear to front along its local +X path, and settle on the static amber finish. The stock inspect clips supply the pose timing. Packed maps provide the static fallback.
- The shared 1024² atlases have six-pixel bake padding and zero sampled overlaps. The close-up renders show the slight softening at finish borders at macro scale. Both local FBXs reimport with the same mesh and triangle counts and were checked with backface culling.

## Completed roster · 2026-11-16

All 35 versioned assets were reopened in Blender. Across the roster, the stock action audit sampled 9,677 frames. The 140 external map hashes match their per-asset manifests and the maps packed in the blends. The Rootglass packages include local FBXs, with saved reimport and culling evidence. Studio imports, live validation, and pass assignments are deferred.

[Poolside roster review](../../../art-source/weapons/Skins/Review/Battle%20Pass/Poolside%20Roster.jpg) · [Rootglass roster review](../../../art-source/weapons/Skins/Review/Battle%20Pass/Rootglass%20Roster.jpg) · [Asset index](../../../art-source/weapons/Skins/Review/Battle%20Pass/manifest.json)

| Stock slot | Poolside delivery | Rootglass delivery |
| --- | --- | --- |
| Vandal | [v02 manifest](../../../art-source/weapons/Skins/Poolside/Vandal/v02/manifest.json) | [v02 manifest](../../../art-source/weapons/Skins/Rootglass/Vandal/v02/manifest.json) |
| Phantom | [v02 manifest](../../../art-source/weapons/Skins/Poolside/Phantom/v02/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Phantom/v01/manifest.json) |
| Bulldog | [v02 manifest](../../../art-source/weapons/Skins/Poolside/Bulldog/v02/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Bulldog/v01/manifest.json) |
| Guardian | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Guardian/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Guardian/v01/manifest.json) |
| Spectre | [v02 manifest](../../../art-source/weapons/Skins/Poolside/Spectre/v02/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Spectre/v01/manifest.json) |
| Stinger | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Stinger/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Stinger/v01/manifest.json) |
| Ares | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Ares/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Ares/v01/manifest.json) |
| Odin | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Odin/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Odin/v01/manifest.json) |
| Sheriff | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Sheriff/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Sheriff/v01/manifest.json) |
| Classic | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Classic/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Classic/v01/manifest.json) |
| Ghost | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Ghost/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Ghost/v01/manifest.json) |
| Shorty | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Shorty/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Shorty/v01/manifest.json) |
| Bucky | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Bucky/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Bucky/v01/manifest.json) |
| Judge | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Judge/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Judge/v01/manifest.json) |
| Marshal | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Marshal/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Marshal/v01/manifest.json) |
| Outlaw | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Outlaw/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Outlaw/v01/manifest.json) |
| Operator | [v01 manifest](../../../art-source/weapons/Skins/Poolside/Operator/v01/manifest.json) | [v01 manifest](../../../art-source/weapons/Skins/Rootglass/Operator/v01/manifest.json) |
| Leafblade | — | [v02 manifest](../../../art-source/weapons/Skins/Rootglass/Leafblade/v02/manifest.json) |

### Bulldog and Stinger

Both Bulldog variants use the approved SightSeat v01 source, which includes the earlier bolt repair. The seat closes the roughly 0.029-model-unit gap beneath the original front sight. The original sight and AimPoint retain their stock transforms. [Matched close-ups](../../../art-source/weapons/Skins/Review/Battle%20Pass/Bulldog%20Sight%20Seat.jpg)

Both Stinger variants use HandguardFix v01. The asset reviews include the flagged owner and grazing angles and sampled stock motion alongside the full held views.

The same seat is now saved and checked in nine earlier local Bulldog variants: Faultline, Misprint, Nitrous, Oilwake, Payload, Playback, PopCircuit, Prism and Redline. [Corrected blends and close-ups](../../../art-source/weapons/Skins/Review/Battle%20Pass/Bulldog%20Sight%20Seat%20Follow-up.json)

**Studio deployment:** see the saved versions and verification below.


## Regular skin deployment · 2026-11-16

All 35 cosmetics are installed as ordinary Locker skins in the Lobby and Match. Rootglass Broad Leaf uses the stock Knife slot. The two skin lines are registered in the shared Locker and match preview config. Rootglass uses its baked static finish and stock actions.

| Place | Roblox place ID | Saved Team Create version |
| --- | --- | ---: |
| Lobby | 71551303511506 | 604 |
| Match | 133387545285290 | 617 |

Each place passed 622 attachment and rig-joint comparisons. All 35 Locker routes and the Match selector routes resolved the new templates. Studio preloaded 596 mesh assets and 140 maps in each place with zero fetch failures. Both Bulldogs retain the front sight seat. The saves are ready for publication.

[Installation jobs](../../../art-source/weapons/Skins/Review/Battle%20Pass/Studio/deployment-jobs.json) · [Asset IDs](../../../art-source/weapons/Skins/Review/Battle%20Pass/Studio/deployment-uploads.json) · [Studio validation](../../../art-source/weapons/Skins/Review/Battle%20Pass/Studio/deployment-validation.json)
