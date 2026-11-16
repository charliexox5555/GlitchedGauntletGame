# Battle Pass skin line concepts

Proposed art for **35 cosmetics** across the stock Gauntlet roster. Poolside has 17 gun reskins. Rootglass has 17 structural gun cosmetics and one original knife in the Knife slot. Each gun uses its own stock model sheet and Blender source. The visual pitches and names are working choices.

## Poolside

A late-summer swim club graphic on bright enamel. The player-facing side has a broad blue field crossed by two warm-white lane stripes. One stripe bends at the shoulder and returns on top where the stock panels allow it. A little butter-yellow starting-block shape punctuates the turn. The graphic should be easy to pick out on a small reward tile, and its color break should be visible from the held camera.

| Role | Colour and finish |
| --- | --- |
| Main field | Pool blue `#4DB6E4` with a satin enamel finish |
| Lane stripes and selected panels | Warm white `#F4EBDD`, with subtle molded-enamel texture |
| Starting-block mark | Butter yellow `#FFD65A`, a small block of flat color |
| Grips and quiet hardware | Ink navy `#172739`, matte |

**Hero · Spectre.** Start the lane bend on the left receiver and carry the blue-to-white break onto the fixed upper shoulder. Keep the suppressor quiet in ink navy. Give long bodies room for a wider curve and reduce the pattern to two stripes and a yellow tab on handguns.

The treatment uses colour, finish, and printed texture on the stock meshes. Keep the stock UVs where they bake cleanly, align artwork across fixed seams, and give separate moving surfaces their own marks. Materials and artwork are static.

## Rootglass

An old greenhouse specimen preserved in clear mineral. Broad, overlapping dark-wood shells part around a recessed green glass window. Inside, honey-amber growth lines form a layered root pattern with a clear centre. Use faint wood grain on the large shapes and small antique-bronze collars where the shell meets the glass. The glossy interior and satin outer plates should be distinct in an ordinary held view.

| Role | Colour and finish |
| --- | --- |
| Outer shells | Roasted walnut `#3B2926` with satin highlights and subdued grain |
| Underside and grips | Deep umber `#221C19`, matte |
| Window | Moss-green mineral glass `#26745E` with lighter green depths `#67B18D` |
| Vein pattern | Honey amber `#F1B65A`, a brighter line visible inside the green |
| Frames and fittings | Antique bronze `#A48358`, brushed with narrow polished edges |

**Hero · Vandal.** Sculpt two broad shell plates that open around one oblong, player-facing specimen window. Frame it with a thin bronze seat and leave enough dark wood above it to keep the profile readable. Follow the stock Vandal's length, sight picture, and held footprint. [Moltframe material and shell reference](Moltframe/concept.md)

**Inspect and finish.** As the model turns toward the player, one amber trace travels along a branch inside the window and settles. Keep a visible vein pattern in the static material for the reward turntable and for any version without motion. Scale down to one branch on compact guns. The concept calls for original outer geometry, recessed layers, and deliberate material contrast at Moltframe's detail level.

**Knife · Rootglass Leafblade.** A new broad, asymmetrical leaf-shaped blade with a swept shoulder, dark walnut handle, and one bronze collar. A slim translucent green inlay follows the spine and catches the same amber trace during inspect. Give the blade a clear pale edge and keep the glass inside the silhouette. Sketch two shapes for the single deliverable. The lead option is a wide leaf with one asymmetric shoulder. The second option is a narrower tapered leaf with a longer inlay. Compare both against the stock Knife in idle, slash, and inspect pose references. Start from stock timing and check grip position, knuckle clearance, and camera coverage on the selected design.

## Gun roster and placement

| Gun | Poolside graphic | Rootglass remodel |
| --- | --- | --- |
| Vandal | Sweep the lane stripes from the fixed receiver toward the front shoulder. | Hero. Split broad wood shells around one long green specimen window. |
| Phantom | Place the bend low on the side with a slim white return on top. | Extend the window into a low, long recess. Let the stock suppressor finish the silhouette. |
| Bulldog | Turn the stripes around the wider rear shoulder and stop clear of the magazine. | Use a compact, deep specimen window on the fixed rear body. Review the receiver patch. |
| Guardian | Leave a broad blue field with one long white bend beneath the top rail. | Use a tapered walnut cover, narrow glass strip, and small bronze end collar. |
| Spectre | Hero. Lane bend on the left, white shoulder return, yellow block. | Use a compact teardrop insert inside one dark shoulder plate. |
| Stinger | Short lane bend on the fixed side body. | Use one short upper inset and leave the front grip contact clear. Review the handguard join. |
| Ares | Broad blue side panel with a separate yellow tab on the drum shell. | Twin wood shoulders around one body window, with a quiet bronze echo on the drum. |
| Odin | Wide white race-lane curve ending before the feed cover. | Wider segmented shell and a compact specimen window away from moving feed parts. |
| Sheriff | Two white stripes on the fixed frame and a small yellow tab. | Small oval window inside the fixed shroud. Keep the cylinder clear. |
| Classic | Two short stripes and one yellow block on the slide side. | One shallow green inset gives the compact version its focal point. |
| Ghost | Slim blue and ivory graphic along the slide, with a quiet suppressor. | A long, narrow inlay inside the stock outline. |
| Shorty | Reduce the stripes to two white arcs on the fixed side surface. | Small rounded glass insert on the fixed body, clear of the break-action boundary. |
| Bucky | One broad stripe bend on the fixed receiver. Use a separate color block on the pump. | One oval window on the fixed body, clear of the stock pump throughout its travel. |
| Judge | Blue field on the broad side with a yellow starting-block mark. | Broad wood shell with a short wide window and quiet drum treatment. |
| Marshal | Stretch the parallel stripes along the stock body panel. | A slender tapered glass strip beneath the stock optic. |
| Outlaw | Create two parallel white stripes and stop them before the action seam. | Use twin shallow insets on fixed side surfaces, with the front kept quiet. |
| Operator | Long blue and white color break low on the body. | Long specimen recess beneath the optic, with a restrained bronze rim. |

For both lines, keep the existing gun silhouette landmarks, relative sizing, sight picture, hand contacts, moving assemblies, gun animations, and gameplay. Rootglass changes outer cosmetic forms within that footprint. Carry forward the [Bulldog and Stinger regression checks](Reskin%20Geometry%20Regression%20Checks.md) and use the reviewed shared source fixes in the [previous build ledger](Full%20Roster%20Reskin%20Build%20Ledger.md).

## First concept pass

1. Poolside Spectre establishes the graphic across the left and top faces.
2. Rootglass Vandal establishes the outer shell, recess, materials, and three inspect beats.
3. Rootglass Leafblade compares the two silhouettes at stock Knife scale and includes a first-person grip study.

Pair each board with the original Gauntlet renders. Include a held view, a material detail, and a thumbnail at reward-tile size. The battle pass screen already has a 3D reward turntable, so the static materials and silhouette should carry the designs there. Tier and track placement are open. [Season Pass screen notes](../UI%20Battle%20Pass.md)

## Concept sheets for approval

- [Poolside Spectre](Poolside/out/Spectre_concept_v01.png)
- [Rootglass Vandal](Rootglass/out/Vandal_concept_v01.png)
- [Rootglass Leafblade A and B](Rootglass/out/Leafblade_concept_v02.png)

The [Blender handoff](Battle%20Pass%20Blender%20Handoff.md) includes the first prompt to send after concept approval.
