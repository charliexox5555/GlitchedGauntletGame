# Exotic bundle concept ledger

[Handoff](Exotic%20Bundle%20Concept%20Handoff.md) · [Bundle briefs](Exotic%20Bundle%20Concepts.md) · [Animator handoff and imagegen prompts](Exotic%20Bundle%20Animator%20Handoff.md) · [Geometry regression checks](Reskin%20Geometry%20Regression%20Checks.md) · [Earlier material pass](Exotic%20Bundle%20Blender%20Finish%20Ledger.md) · [Structural build pass](Exotic%20Bundle%20Structural%20Build%20Ledger.md)

## Current checkpoint

**Complete. All 24 concept items verified.** The final offline queue contains 18 gun sheets, three original melee sheets and three charm sheets. The three gun heroes, three melees and three charms each have a Blender file and a GIF. The 15 other guns have saved pose panels. The table links the selected versions. The stage log retains earlier versions. Studio and runtime work are the next pass.

## Verification

- Reopened all 24 PNGs and visually reviewed the side, player-camera and motion-beat panels. Decoded all nine GIFs and reviewed representative frames against the saved Blender states.
- Reopened all nine Blender files in an isolated process. The added meshes passed manifold and positive-volume checks. All nine assemblies returned to their starting transforms. The three hero models retained the source stock vertices, face topology and UVs. The reopened backface-culled renders were checked against magenta.
- All 18 gun treatments passed 24 of 24 exterior seat probes. Sampled moving-part and charm-extreme checks and applicable aim rays returned zero cosmetic intersections. Both stock mount swing extremes were rendered. Bucky and Marshal include two stock insert cues. Shorty includes an empty load. Bulldog and Stinger use the repaired source scenes, and the audit includes stock action travel.
- Moved Spectre and Classic clear of the selector and slide catch, moved Odin's cage and cheeks away from the feed cover and bolt, thinned and moved Shorty's hatch seat away from the shell sweep, and shortened and tilted Judge's charm away from the drum. The detail cameras follow the stock root on the final Bucky and Marshal sheets.
- Blender MCP on port 9999 listed the nine final scenes. The live Lobby V4 file was clean with 955 scene objects before and after the offline pass.
- Hands and sleeves are posing proxies. The evidence covers the Blender concept poses and stock hardware. Final hand rigs, animation transfer and runtime behavior belong to integration.

## Final deliverables and self-review

Scores are identity and finish **/35**, geometry and fit **/30**, presentation and reference quality **/20**, then motion clarity **/15**. The heroes, melees and charms have animated Blender evidence. The other guns have rendered stock-cued pose evidence.

| Bundle | Item | Concept and audit | Blender, motion and pose evidence | Score /100 | Main deductions and checks |
| --- | --- | --- | --- | --- | --- |
| Spindrift | Vandal v04 | [Sheet](Spindrift/out/Vandal_concept_v04.png) · [Fit and cues](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v04/review.json) | [Blend](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v04/Vandal_Spindrift_concept_v04.blend) · [Motion](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v04/Vandal_motion_v04.gif) · [Reopen check](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v04/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v04/views/reopened_magenta.png) | 33 / 29 / 19 / 14 = **95** | Fine fold edges and grip proxies leave room for production polish. |
| Kilnlock | Odin v04 | [Sheet](Kilnlock/out/Odin_concept_v04.png) · [Fit and cues](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v04/review.json) | [Blend](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v04/Odin_Kilnlock_concept_v04.blend) · [Motion](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v04/Odin_motion_v04.gif) · [Reopen check](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v04/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v04/views/reopened_magenta.png) | 33 / 29 / 18 / 14 = **94** | The heat bar is small in the stock held camera. |
| Stacklight | Phantom v04 | [Sheet](Stacklight/out/Phantom_concept_v04.png) · [Fit and cues](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v04/review.json) | [Blend](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v04/Phantom_Stacklight_concept_v04.blend) · [Motion](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v04/Phantom_motion_v04.gif) · [Reopen check](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v04/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v04/views/reopened_magenta.png) | 33 / 29 / 18 / 14 = **94** | The shuttle and translucent shading are clearest from the material camera. |
| Spindrift | Sounding Arc v02 | [Sheet](Spindrift/out/SoundingArc_concept_v02.png) · [Fit and cues](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v02/review.json) | [Blend](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v02/SoundingArc_Spindrift_concept_v02.blend) · [Motion](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v02/SoundingArc_motion_v02.gif) · [Reopen check](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v02/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v02/views/reopened_magenta.png) | 33 / 27 / 18 / 14 = **92** | Rigid controls give a clear fold. Wrist and suspended-arc transitions are at blockout fidelity. |
| Kilnlock | Kiln Cleaver v02 | [Sheet](Kilnlock/out/KilnCleaver_concept_v02.png) · [Fit and cues](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v02/review.json) | [Blend](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v02/KilnCleaver_Kilnlock_concept_v02.blend) · [Motion](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v02/KilnCleaver_motion_v02.gif) · [Reopen check](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v02/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v02/views/reopened_magenta.png) | 33 / 28 / 18 / 14 = **93** | The low and overhead silhouettes differ. Both grip seats are visible. Fingers use proxies. |
| Stacklight | Patch Tool v03 | [Sheet](Stacklight/out/PatchTool_concept_v03.png) · [Fit and cues](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v03/review.json) | [Blend](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v03/PatchTool_Stacklight_concept_v03.blend) · [Motion](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v03/PatchTool_motion_v03.gif) · [Reopen check](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v03/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v03/views/reopened_magenta.png) | 33 / 27 / 18 / 14 = **92** | The panels nest and fan. The edge-on carry hides some of the glazed finish. |
| Spindrift | Stormglass Buoy v02 | [Sheet](Spindrift/out/StormglassBuoy_concept_v02.png) · [Fit and cues](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v02/review.json) | [Blend](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v02/StormglassBuoy_Spindrift_concept_v02.blend) · [Motion](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v02/StormglassBuoy_motion_v02.gif) · [Reopen check](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v02/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v02/views/reopened_magenta.png) | 34 / 29 / 19 / 14 = **96** | The cap and bubble survive the icon. The glass uses a flat tint in the previews. |
| Kilnlock | Foundry Stamp v02 | [Sheet](Kilnlock/out/FoundryStamp_concept_v02.png) · [Fit and cues](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v02/review.json) | [Blend](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v02/FoundryStamp_Kilnlock_concept_v02.blend) · [Motion](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v02/FoundryStamp_motion_v02.gif) · [Reopen check](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v02/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v02/views/reopened_magenta.png) | 33 / 29 / 19 / 14 = **95** | Both hinge states read. Copper and ceramic retain concept finishes. |
| Stacklight | Keycap Tester v02 | [Sheet](Stacklight/out/KeycapTester_concept_v02.png) · [Fit and cues](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v02/review.json) | [Blend](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v02/KeycapTester_Stacklight_concept_v02.blend) · [Motion](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v02/KeycapTester_motion_v02.gif) · [Reopen check](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v02/reopen-check.json) · [Culled view](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v02/views/reopened_magenta.png) | 33 / 29 / 18 / 14 = **94** | The glyph reads at icon size. Key travel is easiest to see in the standalone clip. |
| Spindrift | Spectre v04 | [Sheet](Spindrift/out/Spectre_concept_v04.png) · [Fit and cues](Spindrift/out/pose-reference/Spectre_v04/review.json) | [Pose references](Spindrift/out/pose-reference/Spectre_v04/views) | 31 / 29 / 18 / 12 = **90** | The compact panel clears the stock selector. The ribbon is subtle in the held angle. |
| Spindrift | Ghost v04 | [Sheet](Spindrift/out/Ghost_concept_v04.png) · [Fit and cues](Spindrift/out/pose-reference/Ghost_v04/review.json) | [Pose references](Spindrift/out/pose-reference/Ghost_v04/views) | 30 / 29 / 16 / 12 = **87** | The wipe comes at recovery. The small pistol treatment reads best in close-up. |
| Spindrift | Marshal v05 | [Sheet](Spindrift/out/Marshal_concept_v05.png) · [Fit and cues](Spindrift/out/pose-reference/Marshal_v05/review.json) | [Pose references](Spindrift/out/pose-reference/Marshal_v05/views) | 31 / 29 / 18 / 13 = **91** | Two seated-round cues establish the timing. The ripple is restrained. |
| Spindrift | Guardian v04 | [Sheet](Spindrift/out/Guardian_concept_v04.png) · [Fit and cues](Spindrift/out/pose-reference/Guardian_v04/review.json) | [Pose references](Spindrift/out/pose-reference/Guardian_v04/views) | 32 / 29 / 18 / 12 = **91** | The reload bead stays small. The extended slot reads best at close range. |
| Spindrift | Bucky v05 | [Sheet](Spindrift/out/Bucky_concept_v05.png) · [Fit and cues](Spindrift/out/pose-reference/Bucky_v05/review.json) | [Pose references](Spindrift/out/pose-reference/Bucky_v05/views) | 30 / 29 / 18 / 13 = **90** | Both shell commits and the stock pump travel are checked. The ripple occupies a short window. |
| Kilnlock | Phantom v04 | [Sheet](Kilnlock/out/Phantom_concept_v04.png) · [Fit and cues](Kilnlock/out/pose-reference/Phantom_v04/review.json) | [Pose references](Kilnlock/out/pose-reference/Phantom_v04/views) | 32 / 29 / 18 / 12 = **91** | Ceramics and the heat cassette distinguish the treatment. Motion evidence is frame-based. |
| Kilnlock | Bulldog v04 | [Sheet](Kilnlock/out/Bulldog_concept_v04.png) · [Fit and cues](Kilnlock/out/pose-reference/Bulldog_v04/review.json) | [Pose references](Kilnlock/out/pose-reference/Bulldog_v04/views) | 31 / 29 / 18 / 12 = **90** | The shallow hatch clears the repaired bolt through the stock travel check. |
| Kilnlock | Shorty v06 | [Sheet](Kilnlock/out/Shorty_concept_v06.png) · [Fit and cues](Kilnlock/out/pose-reference/Shorty_v06/review.json) | [Pose references](Kilnlock/out/pose-reference/Shorty_v06/views) | 30 / 28 / 17 / 13 = **88** | The shallow seat clears both load counts. The held profile is small. |
| Kilnlock | Sheriff v04 | [Sheet](Kilnlock/out/Sheriff_concept_v04.png) · [Fit and cues](Kilnlock/out/pose-reference/Sheriff_v04/review.json) | [Pose references](Kilnlock/out/pose-reference/Sheriff_v04/views) | 30 / 29 / 17 / 12 = **88** | The vent clears the cylinder. The opening reads best in the material close-up. |
| Kilnlock | Judge v06 | [Sheet](Kilnlock/out/Judge_concept_v06.png) · [Fit and cues](Kilnlock/out/pose-reference/Judge_v06/review.json) | [Pose references](Kilnlock/out/pose-reference/Judge_v06/views) | 32 / 29 / 18 / 12 = **91** | The outboard charm clears the drum. The drum mark is small. |
| Stacklight | Stinger v04 | [Sheet](Stacklight/out/Stinger_concept_v04.png) · [Fit and cues](Stacklight/out/pose-reference/Stinger_v04/review.json) | [Pose references](Stacklight/out/pose-reference/Stinger_v04/views) | 31 / 29 / 18 / 12 = **90** | The short window clears the repaired join. The sweep is most legible in close-up. |
| Stacklight | Classic v04 | [Sheet](Stacklight/out/Classic_concept_v04.png) · [Fit and cues](Stacklight/out/pose-reference/Classic_v04/review.json) | [Pose references](Stacklight/out/pose-reference/Classic_v04/views) | 30 / 29 / 17 / 12 = **88** | The cells clear the slide catch. The held profile is small at the stock framing. |
| Stacklight | Outlaw v04 | [Sheet](Stacklight/out/Outlaw_concept_v04.png) · [Fit and cues](Stacklight/out/pose-reference/Outlaw_v04/review.json) | [Pose references](Stacklight/out/pose-reference/Outlaw_v04/views) | 31 / 29 / 18 / 13 = **91** | The open and close cues distinguish both pulses. The window stays small under the scope. |
| Stacklight | Ares v04 | [Sheet](Stacklight/out/Ares_concept_v04.png) · [Fit and cues](Stacklight/out/pose-reference/Ares_v04/review.json) | [Pose references](Stacklight/out/pose-reference/Ares_v04/views) | 32 / 29 / 18 / 12 = **91** | The shoulder sweep and drum mark are separate. Motion evidence is frame-based. |
| Stacklight | Operator v04 | [Sheet](Stacklight/out/Operator_concept_v04.png) · [Fit and cues](Stacklight/out/pose-reference/Operator_v04/review.json) | [Pose references](Stacklight/out/pose-reference/Operator_v04/views) | 32 / 29 / 18 / 12 = **91** | The window clears stock bolt travel. The scope dominates in the held camera. |

## Image-generated finish studies

Built-in imagegen produced five references. [Vandal](Spindrift/refs/Vandal_finish_study_v01.png) · [Odin](Kilnlock/refs/Odin_finish_study_v01.png) · [Stormglass Buoy](Spindrift/refs/StormglassBuoy_finish_study_v01.png) · [Foundry Stamp](Kilnlock/refs/FoundryStamp_finish_study_v01.png) · [Keycap Tester](Stacklight/refs/KeycapTester_finish_study_v01.png)

Output moderation blocked the Stacklight Phantom study. The final sheet uses Blender renders of the stock-based concept and the brief's materials. [Prompt record](Exotic%20Bundle%20Animator%20Handoff.md#built-in-imagegen-prompt-record)

## Stage log

- **Spindrift Vandal v01 — art direction.** [Image-generated finish and shutter study](Spindrift/refs/Vandal_finish_study_v01.png) reviewed against the [stock sheet](../../../art-source/weapons/ModelSheets/Vandal_model_sheet.png). Preserve stock dimensions, ring sight, stock and grip. Use the generated image for finish and silhouette ideas. The leaves and ribbon still need stock fit and motion validation.
- **Blender MCP** — read-only connection on `127.0.0.1:9999` reached PID 42336, `art-source/lobby/LobbyV4.blend`, Scene (955 objects, clean). The concept build will use isolated Blender files.


- **Spindrift Vandal v01 — first blockout.** [Blend](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v01/Vandal_Spindrift_concept_v01.blend) and [backface-culled views](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v01/views) saved and inspected. The stock silhouette and sight window read. The first-person pose lacked hands, the first collar pass had an irregular material break, and the upper forend was underdeveloped. Continue at v02 and review before finalizing.

- **Spindrift Vandal v02 — rendered.** [Sheet](Spindrift/out/Vandal_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v02/Vandal_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v02/Vandal_Spindrift_concept_v02.blend). Compare v02 against v01 collar and hand-pose findings.

- **Kilnlock Odin v01 — rendered.** [Sheet](Kilnlock/out/Odin_concept_v01.png) · [Render and timing record](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v01/review.json) · [Motion preview](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v01/Odin_motion_v01.gif) · [Blender file](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v01/Odin_Kilnlock_concept_v01.blend). Visual review and fit findings pending.

- **Stacklight Phantom v01 — rendered.** [Sheet](Stacklight/out/Phantom_concept_v01.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v01/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v01/Phantom_motion_v01.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v01/Phantom_Stacklight_concept_v01.blend). Visual review and fit findings pending.

- **Spindrift SoundingArc v01 — rendered.** [Sheet](Spindrift/out/SoundingArc_concept_v01.png) · [Render and timing record](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v01/review.json) · [Motion preview](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v01/SoundingArc_motion_v01.gif) · [Blender file](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v01/SoundingArc_Spindrift_concept_v01.blend). Visual review and fit findings pending.

- **Kilnlock KilnCleaver v01 — rendered.** [Sheet](Kilnlock/out/KilnCleaver_concept_v01.png) · [Render and timing record](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v01/review.json) · [Motion preview](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v01/KilnCleaver_motion_v01.gif) · [Blender file](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v01/KilnCleaver_Kilnlock_concept_v01.blend). Visual review and fit findings pending.

- **Stacklight PatchTool v01 — rendered.** [Sheet](Stacklight/out/PatchTool_concept_v01.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v01/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v01/PatchTool_motion_v01.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v01/PatchTool_Stacklight_concept_v01.blend). Visual review and fit findings pending.

- **Spindrift StormglassBuoy v01 — rendered.** [Sheet](Spindrift/out/StormglassBuoy_concept_v01.png) · [Render and timing record](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v01/review.json) · [Motion preview](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v01/StormglassBuoy_motion_v01.gif) · [Blender file](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v01/StormglassBuoy_Spindrift_concept_v01.blend). Visual review and fit findings pending.

- **Kilnlock FoundryStamp v01 — rendered.** [Sheet](Kilnlock/out/FoundryStamp_concept_v01.png) · [Render and timing record](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v01/review.json) · [Motion preview](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v01/FoundryStamp_motion_v01.gif) · [Blender file](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v01/FoundryStamp_Kilnlock_concept_v01.blend). Visual review and fit findings pending.

- **Stacklight KeycapTester v01 — rendered.** [Sheet](Stacklight/out/KeycapTester_concept_v01.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v01/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v01/KeycapTester_motion_v01.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v01/KeycapTester_Stacklight_concept_v01.blend). Visual review and fit findings pending.

- **Spindrift Vandal v03 — rendered.** [Sheet](Spindrift/out/Vandal_concept_v03.png) · [Render and timing record](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v03/review.json) · [Motion preview](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v03/Vandal_motion_v03.gif) · [Blender file](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v03/Vandal_Spindrift_concept_v03.blend). Compare v02 against v01 collar and hand-pose findings.

- **Kilnlock Odin v02 — rendered.** [Sheet](Kilnlock/out/Odin_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v02/Odin_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v02/Odin_Kilnlock_concept_v02.blend). Visual review and fit findings pending.

- **Stacklight Phantom v02 — rendered.** [Sheet](Stacklight/out/Phantom_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v02/Phantom_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v02/Phantom_Stacklight_concept_v02.blend). Visual review and fit findings pending.

- **Spindrift SoundingArc v02 — rendered.** [Sheet](Spindrift/out/SoundingArc_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v02/SoundingArc_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Spindrift/SoundingArc/Concept/v02/SoundingArc_Spindrift_concept_v02.blend). Visual review and fit findings pending.

- **Kilnlock KilnCleaver v02 — rendered.** [Sheet](Kilnlock/out/KilnCleaver_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v02/KilnCleaver_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Kilnlock/KilnCleaver/Concept/v02/KilnCleaver_Kilnlock_concept_v02.blend). Visual review and fit findings pending.

- **Stacklight PatchTool v02 — rendered.** [Sheet](Stacklight/out/PatchTool_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v02/PatchTool_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v02/PatchTool_Stacklight_concept_v02.blend). Visual review and fit findings pending.

- **Kilnlock Odin v03 — rendered.** [Sheet](Kilnlock/out/Odin_concept_v03.png) · [Render and timing record](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v03/review.json) · [Motion preview](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v03/Odin_motion_v03.gif) · [Blender file](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v03/Odin_Kilnlock_concept_v03.blend). Visual review and fit findings pending.

- **Spindrift Spectre v01 — rendered.** [Sheet](Spindrift/out/Spectre_concept_v01.png) · [Render and timing record](Spindrift/out/pose-reference/Spectre_v01/review.json). Visual review and fit findings pending.

- **Stacklight Phantom v03 — rendered.** [Sheet](Stacklight/out/Phantom_concept_v03.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v03/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v03/Phantom_motion_v03.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v03/Phantom_Stacklight_concept_v03.blend). Visual review and fit findings pending.

- **Spindrift Ghost v01 — rendered.** [Sheet](Spindrift/out/Ghost_concept_v01.png) · [Render and timing record](Spindrift/out/pose-reference/Ghost_v01/review.json). Visual review and fit findings pending.

- **Stacklight PatchTool v03 — rendered.** [Sheet](Stacklight/out/PatchTool_concept_v03.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v03/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v03/PatchTool_motion_v03.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/PatchTool/Concept/v03/PatchTool_Stacklight_concept_v03.blend). Visual review and fit findings pending.

- **Spindrift Marshal v01 — rendered.** [Sheet](Spindrift/out/Marshal_concept_v01.png) · [Render and timing record](Spindrift/out/pose-reference/Marshal_v01/review.json). Visual review and fit findings pending.

- **Spindrift Guardian v01 — rendered.** [Sheet](Spindrift/out/Guardian_concept_v01.png) · [Render and timing record](Spindrift/out/pose-reference/Guardian_v01/review.json). Visual review and fit findings pending.

- **Spindrift Bucky v01 — rendered.** [Sheet](Spindrift/out/Bucky_concept_v01.png) · [Render and timing record](Spindrift/out/pose-reference/Bucky_v01/review.json). Visual review and fit findings pending.

- **Kilnlock Phantom v01 — rendered.** [Sheet](Kilnlock/out/Phantom_concept_v01.png) · [Render and timing record](Kilnlock/out/pose-reference/Phantom_v01/review.json). Visual review and fit findings pending.

- **Kilnlock Bulldog v01 — rendered.** [Sheet](Kilnlock/out/Bulldog_concept_v01.png) · [Render and timing record](Kilnlock/out/pose-reference/Bulldog_v01/review.json). Visual review and fit findings pending.

- **Kilnlock Shorty v01 — rendered.** [Sheet](Kilnlock/out/Shorty_concept_v01.png) · [Render and timing record](Kilnlock/out/pose-reference/Shorty_v01/review.json). Visual review and fit findings pending.

- **Kilnlock Sheriff v01 — rendered.** [Sheet](Kilnlock/out/Sheriff_concept_v01.png) · [Render and timing record](Kilnlock/out/pose-reference/Sheriff_v01/review.json). Visual review and fit findings pending.

- **Kilnlock Judge v01 — rendered.** [Sheet](Kilnlock/out/Judge_concept_v01.png) · [Render and timing record](Kilnlock/out/pose-reference/Judge_v01/review.json). Visual review and fit findings pending.

- **Stacklight Stinger v01 — rendered.** [Sheet](Stacklight/out/Stinger_concept_v01.png) · [Render and timing record](Stacklight/out/pose-reference/Stinger_v01/review.json). Visual review and fit findings pending.

- **Stacklight Classic v01 — rendered.** [Sheet](Stacklight/out/Classic_concept_v01.png) · [Render and timing record](Stacklight/out/pose-reference/Classic_v01/review.json). Visual review and fit findings pending.

- **Stacklight Outlaw v01 — rendered.** [Sheet](Stacklight/out/Outlaw_concept_v01.png) · [Render and timing record](Stacklight/out/pose-reference/Outlaw_v01/review.json). Visual review and fit findings pending.

- **Stacklight Ares v01 — rendered.** [Sheet](Stacklight/out/Ares_concept_v01.png) · [Render and timing record](Stacklight/out/pose-reference/Ares_v01/review.json). Visual review and fit findings pending.

- **Stacklight Operator v01 — rendered.** [Sheet](Stacklight/out/Operator_concept_v01.png) · [Render and timing record](Stacklight/out/pose-reference/Operator_v01/review.json). Visual review and fit findings pending.

- **Spindrift Vandal v04 — rendered.** [Sheet](Spindrift/out/Vandal_concept_v04.png) · [Render and timing record](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v04/review.json) · [Motion preview](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v04/Vandal_motion_v04.gif) · [Blender file](../../../art-source/weapons/Skins/Spindrift/Vandal/Concept/v04/Vandal_Spindrift_concept_v04.blend). Compare v02 against v01 collar and hand-pose findings.

- **Kilnlock Odin v04 — rendered.** [Sheet](Kilnlock/out/Odin_concept_v04.png) · [Render and timing record](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v04/review.json) · [Motion preview](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v04/Odin_motion_v04.gif) · [Blender file](../../../art-source/weapons/Skins/Kilnlock/Odin/Concept/v04/Odin_Kilnlock_concept_v04.blend). Visual review and fit findings pending.

- **Stacklight Phantom v04 — rendered.** [Sheet](Stacklight/out/Phantom_concept_v04.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v04/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v04/Phantom_motion_v04.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/Phantom/Concept/v04/Phantom_Stacklight_concept_v04.blend). Visual review and fit findings pending.

- **Spindrift StormglassBuoy v02 — rendered.** [Sheet](Spindrift/out/StormglassBuoy_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v02/StormglassBuoy_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Spindrift/StormglassBuoy/Concept/v02/StormglassBuoy_Spindrift_concept_v02.blend). Visual review and fit findings pending.

- **Kilnlock FoundryStamp v02 — rendered.** [Sheet](Kilnlock/out/FoundryStamp_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v02/FoundryStamp_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Kilnlock/FoundryStamp/Concept/v02/FoundryStamp_Kilnlock_concept_v02.blend). Visual review and fit findings pending.

- **Stacklight KeycapTester v02 — rendered.** [Sheet](Stacklight/out/KeycapTester_concept_v02.png) · [Render and timing record](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v02/review.json) · [Motion preview](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v02/KeycapTester_motion_v02.gif) · [Blender file](../../../art-source/weapons/Skins/Stacklight/KeycapTester/Concept/v02/KeycapTester_Stacklight_concept_v02.blend). Visual review and fit findings pending.

- **Spindrift Spectre v02 — rendered.** [Sheet](Spindrift/out/Spectre_concept_v02.png) · [Render and timing record](Spindrift/out/pose-reference/Spectre_v02/review.json). Visual review and fit findings pending.

- **Kilnlock Shorty v02 — rendered.** [Sheet](Kilnlock/out/Shorty_concept_v02.png) · [Render and timing record](Kilnlock/out/pose-reference/Shorty_v02/review.json). Visual review and fit findings pending.

- **Stacklight Classic v02 — rendered.** [Sheet](Stacklight/out/Classic_concept_v02.png) · [Render and timing record](Stacklight/out/pose-reference/Classic_v02/review.json). Visual review and fit findings pending.

- **Spindrift Ghost v02 — rendered.** [Sheet](Spindrift/out/Ghost_concept_v02.png) · [Render and timing record](Spindrift/out/pose-reference/Ghost_v02/review.json). Visual review and fit findings pending.

- **Spindrift Marshal v02 — rendered.** [Sheet](Spindrift/out/Marshal_concept_v02.png) · [Render and timing record](Spindrift/out/pose-reference/Marshal_v02/review.json). Visual review and fit findings pending.

- **Spindrift Guardian v02 — rendered.** [Sheet](Spindrift/out/Guardian_concept_v02.png) · [Render and timing record](Spindrift/out/pose-reference/Guardian_v02/review.json). Visual review and fit findings pending.

- **Spindrift Bucky v02 — rendered.** [Sheet](Spindrift/out/Bucky_concept_v02.png) · [Render and timing record](Spindrift/out/pose-reference/Bucky_v02/review.json). Visual review and fit findings pending.

- **Kilnlock Shorty v03 — rendered.** [Sheet](Kilnlock/out/Shorty_concept_v03.png) · [Render and timing record](Kilnlock/out/pose-reference/Shorty_v03/review.json). Visual review and fit findings pending.

- **Kilnlock Sheriff v02 — rendered.** [Sheet](Kilnlock/out/Sheriff_concept_v02.png) · [Render and timing record](Kilnlock/out/pose-reference/Sheriff_v02/review.json). Visual review and fit findings pending.

- **Kilnlock Judge v02 — rendered.** [Sheet](Kilnlock/out/Judge_concept_v02.png) · [Render and timing record](Kilnlock/out/pose-reference/Judge_v02/review.json). Visual review and fit findings pending.

- **Stacklight Classic v03 — rendered.** [Sheet](Stacklight/out/Classic_concept_v03.png) · [Render and timing record](Stacklight/out/pose-reference/Classic_v03/review.json). Visual review and fit findings pending.

- **Stacklight Ares v02 — rendered.** [Sheet](Stacklight/out/Ares_concept_v02.png) · [Render and timing record](Stacklight/out/pose-reference/Ares_v02/review.json). Visual review and fit findings pending.

- **Spindrift Spectre v04 — rendered.** [Sheet](Spindrift/out/Spectre_concept_v04.png) · [Render and timing record](Spindrift/out/pose-reference/Spectre_v04/review.json). Visual review and fit findings pending.

- **Spindrift Ghost v04 — rendered.** [Sheet](Spindrift/out/Ghost_concept_v04.png) · [Render and timing record](Spindrift/out/pose-reference/Ghost_v04/review.json). Visual review and fit findings pending.

- **Spindrift Marshal v04 — rendered.** [Sheet](Spindrift/out/Marshal_concept_v04.png) · [Render and timing record](Spindrift/out/pose-reference/Marshal_v04/review.json). Visual review and fit findings pending.

- **Spindrift Guardian v04 — rendered.** [Sheet](Spindrift/out/Guardian_concept_v04.png) · [Render and timing record](Spindrift/out/pose-reference/Guardian_v04/review.json). Visual review and fit findings pending.

- **Spindrift Bucky v04 — rendered.** [Sheet](Spindrift/out/Bucky_concept_v04.png) · [Render and timing record](Spindrift/out/pose-reference/Bucky_v04/review.json). Visual review and fit findings pending.

- **Kilnlock Phantom v04 — rendered.** [Sheet](Kilnlock/out/Phantom_concept_v04.png) · [Render and timing record](Kilnlock/out/pose-reference/Phantom_v04/review.json). Visual review and fit findings pending.

- **Kilnlock Bulldog v04 — rendered.** [Sheet](Kilnlock/out/Bulldog_concept_v04.png) · [Render and timing record](Kilnlock/out/pose-reference/Bulldog_v04/review.json). Visual review and fit findings pending.

- **Kilnlock Shorty v04 — rendered.** [Sheet](Kilnlock/out/Shorty_concept_v04.png) · [Render and timing record](Kilnlock/out/pose-reference/Shorty_v04/review.json). Visual review and fit findings pending.

- **Kilnlock Sheriff v04 — rendered.** [Sheet](Kilnlock/out/Sheriff_concept_v04.png) · [Render and timing record](Kilnlock/out/pose-reference/Sheriff_v04/review.json). Visual review and fit findings pending.

- **Kilnlock Judge v04 — rendered.** [Sheet](Kilnlock/out/Judge_concept_v04.png) · [Render and timing record](Kilnlock/out/pose-reference/Judge_v04/review.json). Visual review and fit findings pending.

- **Stacklight Stinger v04 — rendered.** [Sheet](Stacklight/out/Stinger_concept_v04.png) · [Render and timing record](Stacklight/out/pose-reference/Stinger_v04/review.json). Visual review and fit findings pending.

- **Stacklight Classic v04 — rendered.** [Sheet](Stacklight/out/Classic_concept_v04.png) · [Render and timing record](Stacklight/out/pose-reference/Classic_v04/review.json). Visual review and fit findings pending.

- **Stacklight Outlaw v04 — rendered.** [Sheet](Stacklight/out/Outlaw_concept_v04.png) · [Render and timing record](Stacklight/out/pose-reference/Outlaw_v04/review.json). Visual review and fit findings pending.

- **Stacklight Ares v04 — rendered.** [Sheet](Stacklight/out/Ares_concept_v04.png) · [Render and timing record](Stacklight/out/pose-reference/Ares_v04/review.json). Visual review and fit findings pending.

- **Stacklight Operator v04 — rendered.** [Sheet](Stacklight/out/Operator_concept_v04.png) · [Render and timing record](Stacklight/out/pose-reference/Operator_v04/review.json). Visual review and fit findings pending.

- **Kilnlock Shorty v05 — rendered.** [Sheet](Kilnlock/out/Shorty_concept_v05.png) · [Render and timing record](Kilnlock/out/pose-reference/Shorty_v05/review.json). Visual review and fit findings pending.

- **Kilnlock Judge v05 — rendered.** [Sheet](Kilnlock/out/Judge_concept_v05.png) · [Render and timing record](Kilnlock/out/pose-reference/Judge_v05/review.json). Visual review and fit findings pending.

- **Spindrift Marshal v05 — rendered.** [Sheet](Spindrift/out/Marshal_concept_v05.png) · [Render and timing record](Spindrift/out/pose-reference/Marshal_v05/review.json). Visual review and fit findings pending.

- **Spindrift Bucky v05 — rendered.** [Sheet](Spindrift/out/Bucky_concept_v05.png) · [Render and timing record](Spindrift/out/pose-reference/Bucky_v05/review.json). Visual review and fit findings pending.

- **Kilnlock Shorty v06 — rendered.** [Sheet](Kilnlock/out/Shorty_concept_v06.png) · [Render and timing record](Kilnlock/out/pose-reference/Shorty_v06/review.json). Visual review and fit findings pending.

- **Kilnlock Judge v06 — rendered.** [Sheet](Kilnlock/out/Judge_concept_v06.png) · [Render and timing record](Kilnlock/out/pose-reference/Judge_v06/review.json). Visual review and fit findings pending.
