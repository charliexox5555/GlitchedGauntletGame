# Slipframe rework ledger

2026-11-21. Guns in build order are **Guardian, Vandal, Spectre, Operator, Classic**. The handoff opened the line as Rare. During the Guardian build the owner directed Slipframe toward **Epic**, asked for a sleeker hard-surface profile and more deliberate color, and authorized continued work. Guardian establishes the new treatment. The current Blender pass uses the stock rig and actions and prepares separately named pieces for the first-person inspect effect.

## Guardian brief

- Source: [`Guardian_RemasterV2_v05.blend`](../../../../art-source/weapons/RemasterV2/Guardian/Guardian_RemasterV2_v05.blend). Measure the evaluated stock triangle count, silhouette envelope, rig and attachments in the live session before editing.
- Rework a broad satin titanium shell around the dark frame. Use one broad anodised blue face with a shallow recessed inlay along the player-facing side. End the seam at a solid titanium shoulder ahead of the grip. Develop the fore-end, stock and brake together so their tapers read as a family at first-person scale.
- Keep the left and right shell panels, seam inlay and sight hood as separately named objects. Use flat facets and selective chamfers. Preserve the stock sight picture, hand contact, moving-part clearance and attachment transforms. Target about 1.5× stock triangles, with 2× as the upper bound.
- Use the written Slipframe brief for palette and intent. Design the new geometry on the stock Guardian. The previous build ledger records the earlier attempt and its open checks.

| Role | Hex | Finish |
| --- | --- | --- |
| `SF Shell` | `#A1AEBB` | Light satin titanium |
| `SF Frame` | `#242A32` | Dark gunmetal |
| `SF Face` | `#286AA3` | Deep anodised blue |
| `SF Seam` | `#B9E0EF` | Ice-white metal inlay |
| `SF Grip` | `#343B43` | Matte graphite polymer |

The current silhouette uses one straight lower rail, two sharply raked shoulders, a triangular stock opening, and flat chamfers around a chisel-shaped nose. The receiver trim brings the blue treatment into the held camera. `SF_InspectSlidingPanel_Left`, `SF_SeamInlay_Left`, `SF_ShellPanel_Left`, `SF_ShellPanel_Right`, and `SF_RearSight_Hood` remain individually editable. The r05fx export keeps the moving insert and seam separate with their stock Root welds intact.

## Guardian version record

| Version | Master | Review sheet | Audit, grade and export |
| --- | --- | --- | --- |
| r01 | [Master](../../../../art-source/weapons/Skins/Slipframe/Guardian/r01/Guardian_Slipframe_r01.blend) | [Matched sheet](out/Guardian_r01_review.png) | 4,344 tris. Two near-coplanar overlaps, one receiver cap intersection and an open grip boundary. Held for fixes. |
| r02 | [Master](../../../../art-source/weapons/Skins/Slipframe/Guardian/r02/Guardian_Slipframe_r02.blend) | [Matched sheet](out/Guardian_r02_review.png) | 4,470 tris. Recut the titanium receiver transition, cleared the overlaps and preserved the magazine opening, but caught shroud bevel and grip topology faults. |
| r03 | [Master](../../../../art-source/weapons/Skins/Slipframe/Guardian/r03/Guardian_Slipframe_r03.blend) | [Matched sheet](out/Guardian_r03_review.png) | 4,470 tris. Grip closure passed. Audits still flagged crossed faces and collisions from the shroud bevel. Owner liked the direction and asked for sleeker hard surfaces, clearer color and a premium inspect effect. |
| **r04** | [Master](../../../../art-source/weapons/Skins/Slipframe/Guardian/r04/Guardian_Slipframe_r04.blend) | [Matched sheet](out/Guardian_r04_review.png) · [Finish](out/Guardian_r04_views/slipframe_finish.png) | **3,918 tris, self-grade 9/10.** 0 floating shells, coplanar overlaps, crossed faces, inverted closed shells, open boundaries, and new moving-part collisions. [Audit](out/Guardian_r04_views/audit.json) · [Culling views](out/Guardian_r04_views/culling_contact_sheet.png) · [Flat FBX](../../../../art-source/weapons/Skins/Slipframe/Guardian/r04x/Guardian_Slipframe_RobloxFlat.fbx) |
| **r05** | [Master](../../../../art-source/weapons/Skins/Slipframe/Guardian/r05/Guardian_Slipframe_r05.blend) | [Matched sheet](out/Guardian_r05_review.png) · [Finish](out/Guardian_r05_views/slipframe_finish.png) | **3,838 tris, self-grade 9/10.** Integrated front sight saddle and a rear hood 47% thinner front to back. All geometry, ADS, contract, five action and export checks passed in Blender. [Audit](out/Guardian_r05_views/audit.json) · [Flat FBX](../../../../art-source/weapons/Skins/Slipframe/Guardian/r05x/Guardian_Slipframe_RobloxFlat.fbx) |

Live Blender MCP ran on `127.0.0.1:9000`, Blender 5.2.2 LTS, PID `38884`. The stock Guardian had 4,374 evaluated tris. Match comparison preserved all eight bone names and rest frames, all nine locator transforms, the five action curves, the right grip envelope and the left grip mounting surface. The motion audit sampled all 273 integer frames in Draw, Fire, Inspect, Reload, and ReloadEmpty. All five rays from the scaled ADS eye stopped clear of the aperture and the longer sight line found only the original `Guardian_Sights` geometry. The [first-person](out/Guardian_r04_views/slipframe_first_person.png) and [ADS](out/Guardian_r04_views/slipframe_ads.png) images use Blender cameras. The runtime hand fit and viewmodel still need Studio verification.

### Guardian r04 self-grade

| Area | Score | Evidence |
| --- | ---: | --- |
| Silhouette | 9 | Recognizable Guardian profile with a new continuous titanium shroud, folded stock and angular brake. |
| Crispness | 9 | Flat shaded faces and authored folds. Small one-segment chamfers on the inserts, stock and mag heel. |
| Layering | 9 | Color insert, inspect channel and lower reliefs are recessed into the titanium. |
| Connections | 9 | Contact graph reaches every shell. Culled captures show clean joints on both sides and below. |
| ADS | 9 | Wider angular rear opening, stock post and clear eye segment. |
| Palette | 9 | Light titanium and graphite carry the volume. Deep blue and the thin ice-white seam read differently in the held view. |
| Budget | 10 | 3,918 tris, 90% of the stock count. |
| Contract | 9 | Blender rig, locators and action parity passed. Live Studio fit remains a deployment check. |

The [flat manifest](../../../../art-source/weapons/Skins/Slipframe/Guardian/r04x/manifest_flat.json) recorded no coplanar lifts or crossed-face repairs. The FBX was re-imported and reviewed with backface culling from [left](out/Guardian_r04_flat_check/Guardian_r04_Left.png), [right](out/Guardian_r04_flat_check/Guardian_r04_Right.png), and [rear](out/Guardian_r04_flat_check/Guardian_r04_Rear.png). The signed-volume preview initially flagged a material partition of the sight. The [component audit](out/Guardian_r04_flat_check/reimport_topology.json) found two open material sections, three outward closed components, and zero inconsistent edges in that part. All 19 exported MeshParts passed the closed-component check. The r04 review sheet was shared in the chat before starting Vandal.

### Guardian r05 sight and fit check

The owner identified the front sight seat and rear sight bulk in r04. The new front wings and foot share one closed shell. The foot sits inside the shroud, and the original post seats inside the saddle at its stock aim coordinate. The rear hood narrows from 0.0440 to 0.0235 studs deep and opens slightly at the lower corners. Both sights remain attached to Root and keep `Sight` in their names. The contact graph reaches each shell through the shroud and rail. The eye-to-aim segment is clear in all five ADS rays. The longer center ray reaches the stock front post. The [front sight seat](out/Guardian_r05_views/culled_front_sight_join.png), [rear sight seat](out/Guardian_r05_views/culled_rear_sight_join.png), and [ADS](out/Guardian_r05_views/slipframe_ads.png) show the assembled geometry.

The r05 score stays 9 for silhouette, crispness, layering, connections, ADS, palette and contract, and 10 for budget. The wings flow into the saddle and the deepened contact is visible in culled close-ups. The slimmer hood gives the original front post more space. All 273 sampled motion frames again passed the new-part collision check, with all stock bone, attachment, and action data matching. The [r05 re-import audit](out/Guardian_r05_flat_check/reimport_topology.json) found zero inverted closed components and zero inconsistent edges across the 19 parts. The [left](out/Guardian_r05_flat_check/Guardian_r05_Left.png), [right](out/Guardian_r05_flat_check/Guardian_r05_Right.png), and [rear](out/Guardian_r05_flat_check/Guardian_r05_Rear.png) culled FBX renders showed clean joins and no visible holes.

## Epic presentation proposal

One recessed channel on the player-facing shoulder carries the effect. The blue panel moves sideways a small amount on inspect to reveal the ice-white inlay. A single cold-white glint travels toward the fore-end, passes beneath the titanium bridge and disappears. The panel seats with the return of the stock inspect. The sound is three short recordings timed to movement: a dry latch release, a fine metal slide, and a firm closing click. Recorded foley gives the titanium a convincing weight and finish.

| Cue | First-person look | First-person sound |
| --- | --- | --- |
| Fire | A short, low-brightness white pulse travels through the first section of the seam and fades within roughly a tenth of a second. The muzzle flash and tracer keep the existing weapon timing. ADS dims the pulse. | Add a tight metallic snap to the local shot using a short recorded mechanical take. The Guardian's report stays dominant. |
| Magazine seat | One brief point of light appears at the rear of the seam as the new magazine seats. | A close, dry latch click on the existing mag-in cue. |
| Inspect | The insert shifts and the full seam glint appears once, then the panel follows the stock return to its seat. | Three synchronized accents for unlock, travel, and seat. |

Carry the same treatment across the line after hero approval and shorten the stroke for the compact guns. The effects and foley are first-person only under the [locked presentation decision](../../../00%20Home.md#-locked-decisions). The sound column remains the proposal for a later pass.

## Guardian r05fx Studio review

The owner asked for the Guardian effects and model in game before proceeding with the rest of the roster. The [r05fx export](../../../../art-source/weapons/Skins/Slipframe/Guardian/r05fx/manifest_flat.json) packages the r05 silhouette into 20 MeshParts. Both receiver insert and seam passed the [one-sided re-import and topology check](out/Guardian_r05fx_flat_check/reimport_topology.json). The live 9000 Blender window had unsaved changes, so the export copy was made from the saved r05 file in the separate live Blender instance on `127.0.0.1:9897`.

- Group model `122077047011165` is installed at `ReplicatedStorage.WeaponSkins.Slipframe.Guardian` in Lobby and Match. The asset rows are `GGAsset_LobbySkins_243` and `GGAsset_MatchSkins_347`.
- `SlipframeEffects` creates one moving insert joint and one glint on the first-person clone. The insert floats out of the recess before sliding upward, then reseats. The sweep uses the left-facing hold of the existing inspect track. Fire flashes along the short rear section and dims in ADS. The normal `MagIn` beat flashes a stationary point. The third-person model uses static geometry and stock animation.
- Match Studio Solo Play passed hold, clear ADS, inspect, firing, mag-in, ADS interrupt, Stock fallback and the third-person check. [Playtest and captures](../../../05%20Production/Playtests/2026-11-21%20Slipframe%20Guardian.md)
- Team Create saved Match **v990** and Lobby **v897**. The review is in Studio. The game's published versions are separate.
- Studio preview is enabled for the hero. The remaining guns, case catalog, and custom audio follow the owner's review.

### Owner review and effects revision

The owner found the previous receiver glint hard to see at gameplay size and asked for a distinct muzzle flash and a more purposeful inspect. The revision is in the repository. Studio was in use, so the existing place saves remain the record for the first pass.

| Cue | Revised first-person presentation |
| --- | --- |
| Fire | A compact cool-white muzzle core and two angled blue flares last about 50 to 70 ms. On the gun, the receiver seam lights up, a broad pulse washes across the blue fore-end, and a thin highlight travels toward the muzzle for a 170 ms total cue. ADS reduces intensity. |
| Inspect | The camera pose holds the player-facing shoulder in view for the reveal. The blue panel lifts clear of its pocket and slides rearward. Three recessed contacts illuminate in order and send one sweep down the blue fore-end. The panel then slides forward and seats as the gun rolls back into the hold. |
| Magazine seat | A brief receiver flash and low blue light mark the existing mag-in beat. |

The camera clone uses the existing Guardian r05fx panel, inlay and blue fore-end MeshParts. The standard world gun, tracers, hit effects and audio retain their current presentation. The [VFX Design Playbook](../../../LihFolk/07%20Lighting%20VFX%20and%20Audio/VFX%20Design%20Playbook.md) informed the white core, blue edge and short falloff. Offline Luau checks covered the inspect sequence and reset, fire and reload fades, ADS attenuation, hiding, and the muzzle recipe and its stock and Shadow Mist fallbacks. In-game appearance remains open for owner review.

### Inspect visibility and finish

The owner liked the revised effect and reported that the support hand hid the front light during inspect. `InspectSlipframe` now owns a shorter 2.4 s presentation with a small left-facing turn. It skips the stock press-check clip, which moved the support hand off its grip. The panel still lifts, slides and returns. The three recessed contacts pass the light to a white leading edge with a blue wake along the upper titanium chamfer. A short receiver flash lands when the panel seats. The shot uses the same chamfer for its forward pulse.

Offline checks sampled the default held camera, stock Grip and AimPoint frames, authored inspect keys, and both arm bounds through the sweep. Both light layers cleared the arms and stayed above the chamfer surface. The effect lifecycle, ADS attenuation, shot and reload resets, and first-person muzzle routing also passed offline.

### Draw, reload and roster approval

The owner approved continuing the line after a draw and reload effects pass. During the stock equip motion, the receiver seam comes up as the rifle clears the bottom of the screen. A softer blue wash and one short forward sweep follow as the rifle reaches its hold. During reload, charge builds briefly on the receiver. The existing magazine-seat beat triggers a brighter 260 ms sweep from the seam to the fore-end. Shot and inspect keep their existing cues. Custom foley remains a separate pass.

The offline check passed draw and reload onset, sequencing, interruption and restoration, including an early magazine seat during an empty reload. The previous shot, muzzle and inspect checks also passed. Both Rojo projects built. Claude was using Studio, so this revision has no new live playtest or place save. Roster build order is Vandal, Spectre, Operator and Classic after Guardian.

## Roster rework

Masters start from each gun's RemasterV2 v05 in the live Blender 5.2.2 MCP session on `127.0.0.1:9000` (PID 38884). The session's unsaved Guardian work was saved in a separate local backup before opening stock Vandal. All guns inherit the Guardian's finish roles. The receiver insert, seam and forward faces are named separately so they can be animated after whole-line review.

### Vandal r03

The titanium shoulder steps down over the front trunnion into the blue fore-end. A shorter matching receiver insert sits above the charging channel. The titanium stock opens around a raked lower strut, the brake has a recessed facet on both sides, and the front saddle and rear aperture sit on the original sight line.

- [r01 review](out/Vandal_r01_review.png) and [r02 review](out/Vandal_r02_review.png). The r01 audit identified two capped stock openings, a grip boundary and a disconnected charging handle. R02 continued the upper shell across the trunnion and recut the brake. R03 bridged the grip closure with matched edges.
- [r03 master](../../../../art-source/weapons/Skins/Slipframe/Vandal/r03/Vandal_Slipframe_r03.blend), [matched review](out/Vandal_r03_review.png), [audit](out/Vandal_r03_views/audit.json), and [flat manifest](../../../../art-source/weapons/Skins/Slipframe/Vandal/r03x/manifest_flat.json).
- 3,988 triangles versus 5,171 stock. Zero topology faults, floating islands or coplanar pairs. Five ADS rays cleared the approach, and the center line reached the stock front post. Bones, locator transforms and actions matched, with zero new intersections in 309 stock action frames. The 22 exported parts passed the [culled reimport and topology check](out/Vandal_r03x_flat_check/reimport_topology.json).
- Self-grade by handoff rubric: silhouette 9, crispness 9, layering 9, connections 9, ADS 9, palette 9, budget 10, contract 9. Overall **9/10**.

### Spectre r02

The compact mantle frames the charging slot and ejection port. A shorter receiver insert and fore-end face carry the blue from the Guardian, with a faceted graphite suppressor between stepped titanium collars and a canted open stock.

- [r01 review](out/Spectre_r01_review.png). R02 extended the ejection recess through the full bolt travel, gave the selector's two materials clearance, and adjusted the magazine neck to sit inside the unchanged stock well.
- [r02 master](../../../../art-source/weapons/Skins/Slipframe/Spectre/r02/Spectre_Slipframe_r02.blend), [matched review](out/Spectre_r02_review.png), [audit](out/Spectre_r02_views/audit.json), and [flat manifest](../../../../art-source/weapons/Skins/Slipframe/Spectre/r02x/manifest_flat.json).
- 3,312 triangles versus 3,389 stock. Zero topology faults, floating islands or coplanar pairs. Five approach rays cleared and the center line reached the stock front sight. Bones, locator transforms and actions matched, with zero new intersections in 271 stock action frames. The 20 exported parts passed the [culled reimport and topology check](out/Spectre_r02x_flat_check/reimport_topology.json). The aggregate signed-volume heuristic flagged an open magazine material partition. The closed-component check found zero inversions and zero inconsistent edges, and the magazine showed no holes in the culled views.
- Self-grade by handoff rubric: silhouette 9, crispness 9, layering 9, connections 9, ADS 9, palette 9, budget 10, contract 9. Overall **9/10**.

### Operator r04

The longer handguard stays low under the optic. The matching receiver panel sits beneath the bolt channel, with a shallower ejection-side panel. Blue collars follow the stock scope's external bells. The brake has two raked pockets on each side, and the open rear frame carries a deep cheek-rest seat.

- [r01 review](out/Operator_r01_review.png), [r02 review](out/Operator_r02_review.png), and [r03 review](out/Operator_r03_review.png). The first two revisions refined the stock receiver closures and magazine collar. R04 deepened the cheek-rest seat after the one-sided side views showed a weak join.
- [r04 master](../../../../art-source/weapons/Skins/Slipframe/Operator/r04/Operator_Slipframe_r04.blend), [matched review](out/Operator_r04_review.png), [audit](out/Operator_r04_views/audit.json), and [flat manifest](../../../../art-source/weapons/Skins/Slipframe/Operator/r04x/manifest_flat.json).
- 5,240 triangles including the original lenses versus 4,950 stock. Zero topology faults, floating islands or coplanar pairs. Both stock lens shells match the original vertex and material data and remain in the stock model during installation. Five approach rays and the long scope axis match stock. Bones, locator transforms and actions matched, with zero new intersections in 296 stock action frames. The 15 exported parts passed the [culled reimport and topology check](out/Operator_r04x_flat_check/reimport_topology.json).
- Self-grade by handoff rubric: silhouette 9, crispness 9, layering 9, connections 9, ADS 9, palette 9, budget 10, contract 9. Overall **9/10**.

### Classic r04

The faceted titanium slide carries a longer blue cap and low silver inlay on the player-facing side, three raked serrations, and a smaller panel beside the ejection opening. The cap and inlay ride the stock Slide bone. The stock sights retain their shape and use `Sight` in the export names.

- [r01 review](out/Classic_r01_review.png), [r02 review](out/Classic_r02_review.png), and [r03 review](out/Classic_r03_review.png). R02 seated the magazine heel. R03 cleared the full barrel sweep while keeping the hood supported. R04 added a concealed frame guide with a wider channel in the slide to cover the visible seam throughout its travel.
- [r04 master](../../../../art-source/weapons/Skins/Slipframe/Classic/r04/Classic_Slipframe_r04.blend), [matched review](out/Classic_r04_review.png), [audit](out/Classic_r04_views/audit.json), and [flat manifest](../../../../art-source/weapons/Skins/Slipframe/Classic/r04x/manifest_flat.json).
- 2,548 triangles versus 2,334 stock. Zero topology faults, floating islands or coplanar pairs. The physical sight ray passed through the rear notch to the stock front post. Classic uses alt fire, so there is no gameplay ADS check. Bones, locator transforms and actions matched, with zero new intersections in 234 stock action frames. All 19 exported parts passed the [culled reimport and topology check](out/Classic_r04x_flat_check/reimport_topology.json). The aggregate signed-volume heuristic flagged an open slide material partition. The closed-component check found zero inversions and zero inconsistent edges, and the slide showed no holes in the culled views.
- Self-grade by handoff rubric: silhouette 9, crispness 9, layering 9, connections 9, physical sight line 9, palette 9, budget 10, contract 9. Overall **9/10**.

The owner approved the [complete Slipframe roster](out/Slipframe_Roster_Review.png) for installation and the effects pass.

## Studio roster

The five Epic guns are in `ReplicatedStorage.WeaponSkins.Slipframe` in Lobby and Match. All use the stock rig and actions. Their Locker entries use a satin-blue swatch, five individual portraits and the Slipframe collection emblem. Both places resolve all five pairs through the Locker and list them in the Elite and Apex case pools.

| Gun | Group model | Lobby authored row | Match authored row | First-person cue |
| --- | ---: | --- | --- | --- |
| Guardian r05fx | 122077047011165 | 243 | 347 | Standard ice-white fork and receiver-to-fore-end sweep |
| Vandal r03x | 122325619319111 | 244 | 348 | Wider forks and a shorter shot pulse to suit its cadence |
| Spectre r02x | 112457284331698 | 245 | 349 | Short blue suppressor puff and a quick body sweep |
| Operator r04x | 92532245309065 | 246 | 350 | Tighter flash, longer fore-end sweep and stock lenses |
| Classic r04x | 106789299448345 | 247 | 351 | Small fork and a short sweep mounted on the moving slide |

`Config/Slipframe` defines the five mounted effect profiles. Each gun uses the draw wake-up, reload buildup, magazine seat and inspect reveal. Inspect lifts the player-facing insert, lights three recessed contacts and sends a sweep along the shell. Each effect restores the base finish when it finishes or is interrupted. The third-person effect path and weapon sounds still use the stock cues.

Edit-mode checks in both places preloaded 96 meshes per place and verified the catalog, authored tags, per-part welds, attachment frames and the retained Operator lens. Match Edit mode ran the effect functions on scaled clones and verified the inspect, draw, reload, shot, ADS dimming, muzzle recipes, and Classic Slide attachment. An offline check sampled 210 light positions against the Blender surfaces. Both Rojo builds and changed-file lint passed. The owner requested the Studio pass without a playtest.

Team Create saved Lobby **v913** and Match **v1009**. The saved builds are separate from the published places.

| Art | Roblox image ID |
| --- | ---: |
| Guardian portrait | 70699969818687 |
| Vandal portrait | 121492869454776 |
| Spectre portrait | 113376297827501 |
| Operator portrait | 71233783641578 |
| Classic portrait | 94927383283154 |
| Slipframe emblem | 104958460854328 |

All six images passed an Edit-mode preload in both places after Roblox finished processing them.

### Gun audio in the merged place

Nine short recordings made from the licensed ProPack provide five shot accents and four shared handling cues. The firing layers sit about 20–26 dB below the stock shots in the comparison reel. Guardian has a firm metal tick, Vandal a brighter snap, Spectre a short, soft action tick, Operator a lower clack, and Classic a lighter click. Each mix is a separate private Roblox audio asset. The project keeps the licensed recordings and derived mixes out of public Git. [Audition](../../../../art-source/audio/slipframe/_audition.wav) · [Builder](../../../../tools/audio/design_slipframe.py)

`Config/SlipframeAudio` owns the takes and timing. Draw plays during the light buildup, magazine seat uses the existing `MagIn` beat, and inspect plays at lift and reseat. The usual gun report, last-round take and room tail play underneath. Other players hear the stock spatial audio.

All nine audio assets loaded in merged Studio Edit mode. The merged combat client and all five Slipframe model routes were verified in place 71551303511506. A local check exercised first and last shots, tails and first-person audio isolation. Both Rojo builds and changed-file lint passed. Rojo synced the audio during the active merge. The merge's place save and publishing remain with the owner.

### Melee concept

The owner asked for a new knife silhouette with Legendary as the goal. The [Arc r01 export and motion block](concept.md#faceted-export-and-motion-block) add a faceted collar, meet the 10,000-triangle budget, and block the draw and guided inspect in Blender. The r01x FBX and manifest are ready for local Studio import after motion review.

### Arc in the merged place

The 7,264-triangle r01x model is installed as `WeaponSkins/Slipframe/Knife` in place 71551303511506. Roblox group model `74454399706306` supplied 13 meshes and portrait image `129500655642464` passed preload. The Arc is Legendary in the Apex knife pool. The other five Slipframe skins are Epic. Stock grip and blade anchors were verified against the stock Knife.

The Arc's screen-keyed first-person draw rolls into the stock grip and lights the seam. Inspect raises the panel through `ArcPlate`, lights the contacts and brings the finish back as the panel reseats. A short blade ribbon follows light slashes and a two-layer ribbon follows the heavy hit beat. The five licensed ProPack cues follow the draw, release, seat, slash and heavy events. Other players see the static Arc with stock motion and spatial audio.

Edit mode drove the installed rig on a 1.2-scale clone. The panel moved 0.0216 studs along the outward axis, reseated, and cleared its lights on interruption. The effect and audio routes passed draw, inspect, and both swing checks. All 14 Slipframe clips loaded. The five guns each retained their close accent on first and last shots, their stock reports, and their stock spatial route. Team Create saved the merged place as **v954**. [Motion and effects code](../../../04%20Tech/Code%20Map.md) · [Migration parity](../../../04%20Tech/Place%20Merge%20Plan.md#weapon-skin-migration-audit-2026-11-21)

## Review and install gates

1. Capture matched stock and candidate hero, left, right, top, underside, join details, first-person and ADS views for every version. Check Fire, Reload, ReloadEmpty and Inspect poses where the stock source provides them.
2. Audit evaluated geometry for floating islands, same-facing coplanar faces, inverted closed meshes, crossed faces and visible holes. Verify the joins, `Sight` names, aim clearance and stock rig and attachment parity. Record evaluated triangle counts and all eight grades from the handoff. The lowest grade must be at least 9/10.
3. Review the hero with the owner. Stage modifiers on a separate export copy and inspect the re-imported flat FBX with backface culling. Repeat the build and checks in roster order.
4. After the whole line clears review, install in Lobby and Match. Record the asset IDs, portraits and emblem, approved catalog rarity, playtest results and place save status.

## Project references

- [Rare line rework handoff](../Rare%20Line%20Rework%20Handoff.md), [Slipframe brief](concept.md), [previous build ledger](Build%20Ledger.md) and [Style Bible](../../Style%20Bible.md)
- [Skin build pitfalls](../Skin%20Build%20Pitfalls.md), [reskin geometry checks](../Reskin%20Geometry%20Regression%20Checks.md), [skins README](../README.md) and [Tempest-Strike staging](../TempestStrike/Line%20Blender%20Handoff.md)
- [Moderate skin deployment](../Moderate%20Skin%20Deployment.md), [Skin Lines at Launch](../../../01%20Design/Skin%20Lines%20at%20Launch.md) and [Code Map](../../../04%20Tech/Code%20Map.md)
- [LihFolk hard-surface modeling](../../../LihFolk/14%203D%20Modeling/Hard-Surface%20Modeling.md) and [camera and player scale](../../../LihFolk/55%20Modelling%20Nuance%20and%20Readability/Modelling%20to%20the%20Roblox%20Camera%20and%20Player%20Scale.md)
