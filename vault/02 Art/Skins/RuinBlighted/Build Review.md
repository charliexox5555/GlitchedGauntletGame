# Shadow Mist v01 Blender review

Built and reopened in Blender 5.2.2 through the MCP add-on at `127.0.0.1:9876` on 2026-11-17. The live window started in the default startup scene. The model was built from a local copy of [Vandal RemasterV2 v05](../../../../art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend). The [model handoff](Model%20Handoff.md) and [owner concept](concept.md) set the scope.

- [Versioned blend](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/Vandal_RuinBlighted_v01.blend)
- [Hero render](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/hero.jpg) | [Matched stock and Shadow Mist](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/matched.jpg) | [Detail sheet](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/details.jpg) | [Matched reload frames](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/reload.jpg)
- Stock cameras in the same lighting and framing. [Hip stock](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/views/hip_stock.png) | [Hip Shadow Mist](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/views/hip_shadow_mist.png) | [Final-pass aim stock](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/views/aim_final_pass_stock.png) | [Final-pass aim Shadow Mist](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/views/aim_final_pass_shadow_mist.png)
- [Left grazing view](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/views/cull_left.png) | [Right grazing view](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/views/cull_right.png) | [Clearance measurements](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/clearance.json) | [Stock contract](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v01/review/stock_contract.json)

## Model

- The receiver retains the stock core, ejection channel, controls, barrel, named sights, pistol grip and charm loop. Dark cleaved panels wrap the upper and lower receiver. The rear-sight foot plates sit outside the original aperture. The contact saddle keeps the center support-hand seat at `z = 0.17050`, matching stock. The circular rear sight and front post keep their original geometry.
- Handguard slates and a rebuilt stock sit over a dark mechanical core with narrow teal binding insets. The small `RB_Shard_Handguard_*` and `RB_Shard_Stock_*` fragments have separate objects and centered origins. The intentional air gaps are at these fragments, the outer handguard cleaves, and the stock flank. The buffer core seats inside the receiver and the stock strut joins the shoulder pad.
- `RB_Crown_ThreePoint` is one closed, hollow rigid mesh with its own origin and an opaque teal band. It rests above the sight corridor. The three points were turned around the circlet so the silhouette reads from profile, held and aim.
- The cracked magazine has a base plate, stock feed lips and round, a narrow curved core, side slabs and two interrupted opaque teal bindings. All magazine meshes share the stock `Mag` bone and its original pivot. The rebuilt panels and bindings were fit inside the stock magazine envelope. The layouts of the small fractures and bands are authored for this model.
- The saved file uses the `Ruin-Blighted | Shadow Mist` collection with five working groups. Hidden stock parts remain in `Vandal` for comparison. Scope is the static model. The current pass leaves animation, effects, custom rounds, charm and Studio for a later phase.

## Verification

| Check | Result |
| --- | --- |
| Stock rig and references | Eight rest bones, five original NLA tracks and their action keyframes, nine locator transforms, stock sight and charm meshes, both aim cameras and the hip camera match v05. The source file hash was stable. |
| Static aim | The crown clears the ring by **5.95%** of the frame height on `Vandal_Cam_ADS` and **5.81%** on `Vandal_FP_ADS`. The nearest crown vertex is beyond both camera clip planes. 1,009 rays per camera found zero new occlusion of the original sight geometry and zero hits from new meshes along eye to AimPoint. The broader fore-end is visible below and to the sides of the front post. |
| Magazine and controls | Reload and ReloadEmpty sampled every half frame across 1–97, 193 evaluations per action. The only magazine-to-receiver contacts were consistent with the stock interface. Draw, Inspect and Fire checked at the same interval. There were zero new magazine or control intersections. The stock reload markers remain at 15 and 30. |
| Hand contacts | 302 archived Vandal arm-block samples across held, reload, empty reload, draw and inspect showed zero extra hand overlap versus stock. The stock Blender actions have gun bones and the archived proxies are solid arm blocks, so this is a hand-envelope comparison. |
| Mesh and shading | Grazing and backface-culled renders from both sides checked the joins and gaps. No open, non-manifold, zero-area or flipped faces in the 92 authored and extracted meshes. No visible overlapping coplanar face candidates in the rest-pose geometry audit. |
| Triangle count | **7,090** visible gun triangles including 4,116 authored or extracted, compared with 5,171 on the stock model. This is above the 5,000-triangle primary target in the art direction. |

**Self-grade 8.5/10.** The handguard and heel read as fractured stone in the hero and held views. The three crown points and the two magazine bands read under ordinary lighting. The fore-end takes up a little more of the lower aim frame, and the model still exceeds the primary triangle target.


## Shadow Mist v02 owner feedback pass

Saved and reopened the v02 file through Blender MCP on 2026-11-17. The owner asked to remove the crown, improve the magazine and wrap, carry the wrap over the rear stock, and fracture the rear sight to match the concept.

- [Versioned blend](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v02/Vandal_RuinBlighted_v02.blend) | [Hero](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v02/review/hero.jpg) | [Matched views](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v02/review/matched.jpg) | [Detail sheet](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v02/review/details.jpg) | [Reload sheet](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v02/review/reload.jpg)
- The crown is removed. The rear sight uses eight opaque cleaved segments on the stock center with the original seat and front post. All new rear sight pieces have `Sight` in their names. The gaps are built into the geometry.
- The lower magazine has three broken floor-plate pieces, broad cracks in the side plates and a stone grain with restrained bump and roughness variation. Two thicker closed teal wraps follow the magazine contour, with a fork along the side crack. The heel binding crosses the stock crest and runs down both fractured flanks. The separate binding meshes give the effects pass surfaces to follow.
- Both stock aim cameras show the original front post and clear center. The 1,009 near-plane samples per camera found zero new front-post occlusion. The magazine stayed within the measured stock envelope. The half-frame scrub of both reloads and the 302 archived arm-block samples found zero added intersections. Draw, inspect and fire were also scrubbed. The stock rig, clips, locators and charm mount match v05.
- The model has **7,766 triangles**, with 5,216 authored or extracted. This exceeds the primary target. The stone grain is procedural in Blender and will need baking if used for the in-game finish. [Clearance measurements](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v02/review/clearance.json) | [Stock contract](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v02/review/stock_contract.json)

### Effects and animation mockup order

1. Prototype one subdued pulse down the magazine and rear stock bindings in Roblox. Check the true first-person camera at rest, while aiming and on low graphics. This establishes how much brightness and mist the skin can carry at play distance.
2. Use the stock `Reload` / `ReloadEmpty` beats for the next pass. A short Blender preview can answer when a shard or magazine piece moves and whether it clears surrounding parts. Prototype the band fade, mag-out burst and mag-in pulse in Roblox so they use the actual viewmodel, animation markers and visibility.
3. Add the inspect spread and equip snap one at a time. Compare each with the stock handling pose and keep the aiming posture readable.


## Shadow Mist v03 pistol grip and Studio idle

The owner pointed to the dark tape below the trigger. v03 adds five overlapping charcoal bands around the pistol grip, using the existing right-hand contact and stock grip as the core. The wraps are matte and separate from the teal effects. The Blender arm-block comparison found zero added hand overlap.

- [Blender source](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/Vandal_RuinBlighted_v03.blend) | [Grip comparison](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/review/grip_compare.jpg) | [Studio model backup](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/Vandal_RuinBlighted_v03.rbxm)
- [Runtime export](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/manifest_flat.json) | [Group model upload](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/studio_asset.json) | [Match Studio playtest](../../../05%20Production/Playtests/2026-11-17%20Shadow%20Mist%20Idle.md)
- The variant is installed at `ReplicatedStorage.WeaponSkins.RuinBlighted.Vandal` in Match Studio Edit. Select RuinBlighted with **Shift+F7** from Stock in a Studio playtest with the Vandal equipped. The backup contains the 54 merged MeshParts, stock rig, four shard motors and two mist anchors. The place remains an Edit draft.
- The source has **8,566 visible triangles**. Studio uses Fabric on the grip strips and Slate for the magazine preview. The fine procedural Blender grain is pending a bake.


## Shadow Mist v04 full shard and lighting pass

v04 adds seated seafoam veins on the receiver and beneath the rear aperture. The export gives every loose fragment and nine outer plates individual stock-Root cosmetic joints. The four regions carry separate emissive material groups. The group asset uses revision 2, which has the two top-facing cowl veins seen in ADS.

- [Blender source](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v04/Vandal_RuinBlighted_v04.blend) | [Studio template backup](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v04/Vandal_RuinBlighted_v04.rbxm) | [Export manifest](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v04/manifest_flat.json)
- 90 MeshParts and 8,950 visible Blender triangles. This is a local preview above the primary triangle target. The original rig contract and front sight passed the v04 install and aperture checks.
- [Match playtest](../../../05%20Production/Playtests/2026-11-17%20Shadow%20Mist%20Idle.md#v04-full-shard-motion-and-continuous-seafoam-light)


## Shadow Mist v05 cleaved spine and full-body finish

The owner's second review asked for a unique upper profile and action, and a convincing structure from the far side and underside. v05 replaces the stock rail with a faceted spine and recessed seafoam channels. The exposed charging handle and stock bolt meshes are hidden. A new obsidian shutter sits in the action detail on the stock Bolt bone. Nine new low or rear shards extend the broken silhouette. The eight rear-sight pieces gained luminous end faces and independent outward travel around the stock aiming center.

Blender reopened the saved model. The 48-phase sweep found no new body mesh or hand-proxy overlaps from shard motion. Both stock ADS cameras kept the front post clear. The archived hand proxies showed no increased penetration through hold, reload, empty reload, draw and inspect. The original reload and empty-reload sweeps showed no new magazine contacts. The previous magazine assembly is unchanged.

The Studio preview has 133 MeshParts, 41 cosmetic joints and 9,802 visible triangles. The mesh asset is group model 107957430602504. Self-grade 9/10 for the local art preview. The model is above the production triangle target, and device performance still needs verification.

- [Blender source](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/Vandal_RuinBlighted_v05.blend) · [Studio template backup](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/Vandal_RuinBlighted_v05.rbxm) · [Export manifest](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/manifest_flat.json)
- [Player side](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/model_left.png) · [Far underside](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/model_other_side.png) · [Held](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/model_held.png) · [Stock aim camera](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/model_aim.png)
- [Static and clip audit](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/blender_clearance.json) · [Motion audit](../../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/idle_clearance.json) · [Match playtest](../../../05%20Production/Playtests/2026-11-17%20Shadow%20Mist%20Idle.md#v05-full-body-lighting-and-moving-aperture)
