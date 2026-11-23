# Draft Duels Launch Art

## Visual direction

Use the approved [Draft Ticket in Lobby Gold](Draft%20Duels%20Logo.md#approved-title) for the brand. The gold fighter is faceless, with gold on the body and a soft edge glow against charcoal. The bacon study uses Roblox's Pal Hair, Blue and Black Motorcycle Shirt, and Dark Green Jeans. The blue and orange studies use a color wash to identify the teams. Keep each composition readable at 256 × 144 and each icon readable at 48, 96 and 150 pixels. Use the game's own weapons, maps, Mods, and effects.

## Reference archive

All 11 attachments are preserved in order in the [local reference folder](../03%20Research/Rivals%20Reference/third-party/draft-duels-thumbnails/). The copies match the original attachment hashes. The references stay local.

| Image | What reads at a glance | What Draft Duels can use |
| --- | --- | --- |
| 01 | One saturated figure, a large barrel, and a cool room separate the shapes. The scope gives the eye a second place to look. | Gold fighter against a cool, desaturated arena. Keep a single dominant silhouette. |
| 02 | The weapon and arena edges converge on an energetic midair event. | Place the first-person barrel, one movement arc, and the opponent on the same visual path. |
| 03 | A large foreground opponent and a small opponent across a doorway establish scale and two sides. | Show an opposing fighter across a real lane. Preserve the space between silhouettes. |
| 04 | The bright trail links the gun to its target across several depth layers. | Use an existing shot tracer or movement streak with one clear endpoint. |
| 05 | The wall edge, hands, and open sky sell the corner peek and point of view. | Frame a player-height combat shot from real cover and use the actual viewmodel. |
| 06 | One card, oversize effect, and expressive avatar explain the upgrade. | Put a single selected Draft Duels Mod beside a clear effect. |
| 07 | The foreground reaction makes the consequence of the upgrade immediate. | Frame the caster and opponent around a visible change in the lane. |
| 08 | Group staging, a single effect, and a separate card establish the team's role. | Give each team member their own silhouette. Keep the Mod card large if it appears. |
| 09 | A circular scope is a strong framing device, with an instantly identifiable avatar at its center. | Explore an authentic ADS crop as a control study. |
| 10 | A near-diagonal weapon with an effect on the model reads as an inspect even at small size. | Use a tested Draft Duels skin and preserve the actual color and effect language. |
| 11 | An interrupted reload provides stakes, with the player's hands and the enemy peek clearly separated. | Leave room for the hands and one opponent when a weapon action is the subject. |

## Five launch candidates

| Priority | Shot | Studio and Blender layout |
| --- | --- | --- |
| 1 | **Gold Duelist** | Medium three-quarter Vandal hold at Canyon Outpost. Gold figure on the right, graphic rim light, arena cover on the left. A natural bacon treatment is the alternate for the same composition. |
| 2 | **Foundry Slide** | Match first-person viewmodel at slide height in Foundry4. The barrel and a short bright tracer frame one orange opponent. Furnace light provides the warm accent. |
| 3 | **Draft Firewall** | Two-thirds action with one visible Firewall curtain and one selected Firewall card composited from the current draft UI. Use the actual fire-wall shape. A bacon caster carries this variant. |
| 4 | **Rooftop 2v2** | Blue foreground pair and orange opposing pair, using Rooftops4 elevation and cover to separate them. Keep the brightest background near center so both team edges read. |
| 5 | **Snowpeak Inspect** | First-person inspect of an approved release weapon skin with Snowpeak4 as the cool backdrop. Preserve both grip contacts and one effect highlight on the weapon. |

Start the detail page with Gold Duelist and the Home page set with all five once the shot exports pass review. Use the resulting qualified play-through data during the soft launch to evaluate the art. The icon pick is an editorial judgment based on small-size legibility. [Roblox thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) · [Roblox icons](https://create.roblox.com/docs/production/publishing/experience-icons)

## Avatar and accessory workflow

- Open the [local Blender master](../03%20Research/Rivals%20Reference/third-party/draft-duels-thumbnails/rig-study/Draft%20Duels%20-%20Avatar%20Look%20Development.blend) and pick **Gold**, **Bacon**, **Blue** or **Orange** from the scene menu. Frame 13 is the portrait pose. Frames 1–25 show the rifle move through a low-to-level hold. The scene uses the game's Vandal model and the Starter Blocky Rig from the supplied ZIP. The ZIP's README allows use in commercial renders and prohibits redistribution of the modified rig. The working Blend stays local. [Starter Rigs course](https://www.youtube.com/watch?v=gXA67QZrGyQ)
- To bring in another actual outfit, stage a temporary avatar in Studio and read the Shirt and Pants **template image IDs** issued by the HumanoidDescription. Clothing uses the `Roblox classic clothing` UV map. Replace the image in the `Image Texture` node of the appropriate body material. The bacon outfit's catalog IDs are 144076358 for the shirt and 144076760 for the pants. Studio resolved the atlas image IDs to 144076357 and 144076759.
- To fit another real accessory, use the Studio item's Handle mesh, texture, and the live accessory weld frames. Align the Handle by `bodyAttachment.CFrame * handleAttachment.CFrame:Inverse()` after converting the axes, then parent to the rig's matching named attachment empty. The bacon scene applies this to Pal Hair's original mesh and image. The head sockets follow the neck pose. Keep the faceless gold scene clean. [Pal Hair](https://www.roblox.com/catalog/63690008/Pal-Hair) · [Roblox rigid accessory specs](https://create.roblox.com/docs/avatar/rigid-accessories/specifications)
- [Studio's Match Avatar setup](../01%20Design/Match%20Avatar.md) uses the skinned S15 body and the player's own head, clothing, and accessories. The Blender study reuses the established rifle movement against its own armature and has its own arm deformation. For first-person staging, match the camera and grip data in [Viewmodel](../../src/shared/Config/Viewmodel.luau). The third-person pose source is [tp_clips.py](../../tools/anim/tp_clips.py).

## Outputs and verification

- [Thumbnail prompts and asset map](../../art-source/ui/draft-duels/launch-art/Thumbnail%20Brief.md) · [Local thumbnail handoff ZIP](../03%20Research/Rivals%20Reference/third-party/draft-duels-thumbnails/Draft%20Duels%20-%20Thumbnail%20Handoff.zip)
- [Avatar and icon comparison](../../art-source/ui/draft-duels/launch-art/draft-duels-avatar-studies.jpg)
- [512 × 512 Gold icon candidate](../../art-source/ui/draft-duels/launch-art/draft-duels-icon-gold.png) · [512 × 512 bacon variant](../../art-source/ui/draft-duels/launch-art/draft-duels-icon-bacon.png) · [Local layered icon master](../03%20Research/Rivals%20Reference/third-party/draft-duels-thumbnails/rig-study/Draft%20Duels%20-%20Gold%20Icon.ora)
- The four named map layouts were captured from the Match Studio Edit DataModel (place 133387545285290). The local capture contains visible part transforms, sizes, colors, materials, mesh IDs, and texture IDs. Several map meshes require Studio access and returned HTTP 401 from public Asset Delivery. Scene assembly and final thumbnail renders are pending. The map capture was read-only.
- Blender MCP on port 9067 verified the four scenes and their retargeted hold actions through a library inspection. The Blender starter-rig elbow and wrist deformation still falls short of the Match body. Use the actual S15 animation path in the brief for production renders. The staged Blender file remains a wardrobe, lighting, and framing aid.

## Twelve thumbnail concepts

The expanded set pairs neutral and cinematic lighting on the same 12 compositions. Each full-size export is 1920 × 1080. The single comparison sheet places the 256 × 144 previews side by side and marks Gold Duelist, Foundry Slide, Draft Firewall, Rooftop 2v2 and Snowpeak Inspect as the launch shortlist. Draft Firewall and Updraft Crossfire show the selected Mod card from the current draft design alongside the effect it produces.

The revision uses the Match S15 meshes and attachment positions, the installed Roblox classic head mesh, the catalog accessories and classic clothing, and the authored third-person poses. The gun grips use the actual weapon contact points. In first person, the Blender render uses recorded viewmodel arm poses and the animated weapon joints, including the magazine joint during the reload. Both lighting passes use the same camera, pose and effect placement. Cinematic adds colored keys, rim lights and a selective glow grade.

The four environments use the recorded Match Edit layouts and local map kit geometry. The local handoff lacks matching geometry for some Canyon Outpost and Snowpeak props. These are Blender compositions for review using those captures.

[Paired contact sheet](../../art-source/marketing/draft-duels/thumbnail-concepts/DraftDuels-ContactSheet.png) · [24 full-size exports](../../art-source/marketing/draft-duels/thumbnail-concepts/DraftDuels-12-Thumbnail-Pairs.zip) · [Concept list and source notes](../../art-source/marketing/draft-duels/thumbnail-concepts/README.md)

## Second thumbnail pass

The owner asked for clearer action, believable holds, faceless team fighters, real Bacon wardrobe, larger ability cards and unbranded Gold Duelist and Snowpeak Inspect. The second Blender stage uses the original fingerless arm and hand meshes, keeps the forearm and grip rigid together on the trigger side, and solves the support hand beneath the long gun. First-person shots use plain Roblox block arms. The detached magazine and the opponent each have their own space in Reload Window.

The built-in ImageGen edit tool created 12 lighting studies from the scene proofs and numbered visual references. The finish samples their low-frequency illumination and color. All visible models, contours, poses and effects come from the Blender plates. Neither the generated character shapes nor hands are used in the exports.

[Revised contact sheet](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/DraftDuels-Revised-ContactSheet.png) · [Revision package](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/DraftDuels-Revised-Thumbnails.zip) · [ImageGen prompts](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/ImageGen-prompts.md)

## Polished thumbnail set

The 12 final grades use the revision-02 Draft Duels plates. ImageGen received three four-shot groups of those plates and contributed broad lighting and color. The original staged cameras, poses, weapons, faces and fingerless hands supply the visible geometry. The Blender effect pass reduced muzzle flashes and scattered sparks while preserving the game’s Firewall, Updraft and directional tracers.

The official Match Firewall and Updraft card artwork was composited with larger names. Bacon Lock-In uses the approved Draft Ticket wordmark. Gold Duelist and Snowpeak Inspect are logo-free. Reload Window has a dedicated highlight on the detached magazine and support block.

[Named contact sheet](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/polished/DraftDuels-Polished-ContactSheet.png) · [12 full-size PNGs](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/polished/DraftDuels-12-Polished-Thumbnails.zip)

## Featured three thumbnails

The owner selected Updraft Crossfire, Gold Duelist and Draft Firewall for a focused pass. Draft Firewall now stages Bacon in three-quarter view with the casting arm clear of the face, the actual flame wall angled across the lane, and the official card on the right. Gold Duelist uses a tighter unbranded Vandal portrait. Updraft Crossfire has more air above the launched duelist and a wider view of the ground fight.

The original Match S15 blocks, fingerless hands, weapons and maps supply all rendered geometry. Built-in ImageGen contributed three empty environmental lighting studies. Their broad light and color were applied to the Blender plates. The export check decoded all three 1920 × 1080 RGB PNGs, matched each against its 256 × 144 contact tile and tested the ZIP.

[Contact sheet](../../art-source/marketing/draft-duels/thumbnail-concepts/three-shot-pass/DraftDuels-Three-Thumbnail-ContactSheet.png) · [Full-size PNGs](../../art-source/marketing/draft-duels/thumbnail-concepts/three-shot-pass/DraftDuels-Three-Thumbnails.zip) · [ImageGen prompts](../../art-source/marketing/draft-duels/thumbnail-concepts/three-shot-pass/ImageGen-prompts.md)
