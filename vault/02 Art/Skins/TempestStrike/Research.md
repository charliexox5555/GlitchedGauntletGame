# Tempest-Strike research and continuity

Reviewed 2026-11-18. The latest owner brief and archived [Vandal sheet](refs/style/Tempest-Strike%20Vandal%20Reference.png) define Tempest-Strike. The reference sources below support art and motion study. Our application notes are design decisions for Glitched Gauntlet.

## Owner research archive

The [complete supplied research PDF](refs/research/Valorant%20Skin%20Collection%20Breakdown.pdf) is archived with this brief. Its Kuronami discussion runs through pages 7–11. Pages 17–19 contain original adaptation ideas and Roblox architecture suggestions. The Kuronami text and relevant page layouts were inspected. The PDF also retains all other collection research for context.

The report covers the silver, black, brown and teal material family, water-guided reloads, custom equip and inspect, chromas, both melee generations, sounds, accessories and the storm finisher. It identifies gaps in published frame timings and idle curves. Treat its exact timing gaps as measurement work for the later animator, and trace collection facts back to the credited artist work or Riot material. The source contains secondary-guide discrepancies about prices, upgrades and dates, which do not define this asset's production requirements.

Its Tidal Kunai charm, Storm-Forge Flourish and Monsoon Containment Sphere are original adaptation proposals in the report. The current owner brief selects a spinning shuriken charm and the revised Vandal. Weather finishers, emotes, upgrade purchases and a transforming melee remain future design topics.

Archive integrity is SHA-256 `a4e9b92386e774d117e243619d59c767f62915fdd7728e63421b50527b45d605` for the PDF and `428df1853bd5eedd16e3f2197a618873f1b3887b46d62703cfd7f59bfff9c5dd` for the owner PNG.

## Primary art and motion references

| Reference | Verified material and intended study |
| --- | --- |
| [Koko Liem, Kuronami AK](https://kokoliem.artstation.com/projects/aoA4lq) | The concept artist presents a final concept, first-person and muzzle iterations, early melee designs, and water and blade-formation ideas. Study the development of the held silhouette and placement of readable detail. |
| [Kudos, Kuronami production reel](https://kudos3d.artstation.com/projects/ZavEO8) | The credited Riot and Kudos collaboration provides separate Sheriff, Spectre, Vandal, Marshal, finisher, melee VFX, melee animation and audio reels. Use the Vandal reel to study effects around the magazine and hands, then compare other classes before adapting the family. |
| [Kudos, Kuronami 2.0](https://kudos3d.artstation.com/projects/0aYweV) | The production page provides separate melee, Ghost, Guardian, Phantom, Operator and audio reels. Study how one material and water vocabulary supports distinct platform proportions and melee states. |
| [Piotr Kopertowski, Kuronami visual design](https://piotrkopertowski.artstation.com/projects/xD06o2) | The designer documents the kill banner and color variants. Use the presentation hierarchy when considering later original kill feedback. |
| [Riot, Storm and Shadow trailer](https://www.youtube.com/watch?v=pXqSRj-JEkA) | The official reveal describes Phantom, Operator, Guardian, Ghost and a transforming kunai blade. It provides broad collection context for the later melee discussion. |

Direct reel links from the credited production pages are [Vandal VFX](https://www.youtube.com/watch?v=XsVD4kfGZmY), [original collection audio](https://www.youtube.com/watch?v=35KawQgp5qo), [original melee animation](https://www.youtube.com/watch?v=5zkxcyXz1Oc) and [second melee VFX](https://www.youtube.com/watch?v=rRM-DSvlDNw). The browser exposed their links and labels but did not play the embeds in this research pass. Frame-level action timing has not been measured from them. Capture and annotate the needed beats during the motion pass before reporting a measured reference timing.

## Lessons applied to this design

- Make first-person composition a design input. Long silver planes should frame the barrel and receiver, while the wrapped magazine and grip establish a second material rhythm. This application follows the owner's sheet and Koko Liem's documented iteration focus.
- Give water a clear job in each action. It circulates in idle, condenses into the magazine in reload, aligns and seats that magazine, then becomes the inspect suspension ring. Keep the geometry and hand performance readable at each transition.
- Maintain a common material and effect vocabulary across hosts while authoring each platform's proportions and actions. The production reels provide class-specific study material. The prior rejected Ruin-Blighted expansion is direct project evidence that passing a rig check alone is insufficient art review.
- Establish a valid opaque model, assembly roots and grip anchors early. Inspect spin, a detached magazine and any later transforming melee need explicit state ownership and cancellation paths.

## Existing Gauntlet research and work

| Local reference | Role in the new handoff |
| --- | --- |
| [Exotic bundle concepts, Spindrift section](../Exotic%20Bundle%20Concepts.md#spindrift) | Preserves the original Kuronami links, six-gun roster and water-shutter direction. The current Tempest-Strike brief replaces its hero styling. |
| [Earlier concept handoff](../Exotic%20Bundle%20Concept%20Handoff.md) | Historical queue, modeling and motion-preview requirements. Its port, restart schedule, scope and autonomous approval directions belonged to that pass. |
| [Concept ledger](../Exotic%20Bundle%20Concept%20Ledger.md) | Earlier sheets and motion-preview evidence. |
| [Structural ledger](../Exotic%20Bundle%20Structural%20Build%20Ledger.md) and [finish ledger](../Exotic%20Bundle%20Blender%20Finish%20Ledger.md) | Earlier saved model versions and review outputs. Preserve them while building the new hero separately. |
| [Animator handoff](../Exotic%20Bundle%20Animator%20Handoff.md) | Earlier leaf, water-guide and original melee control layouts. Reuse suitable rigging ideas after checking this revised action brief. |
| [Ruin-Blighted Vandal review](../RuinBlighted/Build%20Review.md#shadow-mist-v05-cleaved-spine-and-full-body-finish) | Approved comparison for replacing a stock rail and action into a coherent elite form, with underside and far-side finish. |
| [Elite skin playbook](../RuinBlighted/Elite%20Skin%20Playbook.md) | Proven export, magazine ownership, sight-name, pose, audio and visibility checks. |
| [Ruin-Blighted expansion ledger](../RuinBlighted/Expansion%20Ledger.md) | Owner rejection history and subsequent revisions. Another agent owns those edits. |
| [Skin build pitfalls](../Skin%20Build%20Pitfalls.md) | Exported bow-tie faces, gaps, doubled surfaces, sight fading and z-fighting checks. |

## Roblox implementation references

Beams use distinct attachments, cubic curves, texture flow and width and transparency settings. Their appearance depends on attachment orientation as well as curve size. Preload the water texture and confirm its loaded appearance before evaluating the effect. [Roblox Beam guide](https://create.roblox.com/docs/effects/beams)

For implementation, consult the existing [LihFolk beam and trail notes](../../../LihFolk/07%20Lighting%20VFX%20and%20Audio/Beams%20and%20Trails.md), [camera and scale notes](../../../LihFolk/55%20Modelling%20Nuance%20and%20Readability/Modelling%20to%20the%20Roblox%20Camera%20and%20Player%20Scale.md), and [export notes](../../../LihFolk/14%203D%20Modeling/Exporting%20and%20Validating%20Models%20for%20Roblox.md). These are credited LihFolk Vault V2 references under [CC BY 4.0](../../../LihFolk/LICENSE.md). Measure against Gauntlet's current camera, rig and runtime source.
