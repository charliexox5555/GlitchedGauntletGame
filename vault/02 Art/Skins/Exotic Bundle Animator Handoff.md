# Exotic bundle animator handoff

[Concept ledger](Exotic%20Bundle%20Concept%20Ledger.md) · [Bundle briefs](Exotic%20Bundle%20Concepts.md) · [Stock model sheets](../../../art-source/weapons/ModelSheets/README.md)

Open the `.blend` for the item from the ledger. The assigned camera is the concept player camera on the six handheld assets. Use the timeline markers to locate the reload, inspect, contact and reset poses. The native timelines run at 24 fps. The accompanying GIFs sample those timelines at 8 fps. Gloves and sleeves are posing proxies. Stock mesh vertices, topology and UVs are preserved and checked against the three hero sources. The shaders carry the material roles, including translucent Stacklight inserts. The workbench sheets and GIFs show flat material colors.

## Hero guns

| Item | Animated controls | Pose direction | Rest and interruption |
| --- | --- | --- | --- |
| Spindrift Vandal | `Tide leaf upper pivot`, `Tide leaf lower pivot`, numbered `Ribbon cue` locators | Roll the left side toward the camera as the support hand goes for the stock magazine. Peel the leaves apart and let the ribbon travel through the exposed slit on the `MagIn` cue. | Both leaves seat against the smoked liner. Collapse the ribbon into the channel during cancel. |
| Kilnlock Odin | Separate `Kiln jaw` hinges and a `Heat index` locator | Keep the support motion low and the feed cover visible. The cage opens on `MagIn`, with the heat bar indexing and peaking on the next beat. | The cage closes before the return to the stock hold. The fixed ceramic face sits outside the swept feed cover and bolt. |
| Stacklight Phantom | Three `Sweep` locators and `Shuttle travel` | Draw the shuttle back and dim the window. Sweep the cells from rear to front at `MagIn` while the support hand stays below the window. | Seat the shuttle at the end of its track and return the cells to the dim state on ready and cancel. |

On each gun, use the source action for the host pieces. `STOCK COMMIT` is the existing visual cue for the cosmetic change. The normal reload preview uses the current configured duration. The Bucky and Marshal sheets include two per-round commits from the stock `ReloadInsert` actions. Shorty includes the empty-load second insertion and the close pose in its pose references. Outlaw's two cosmetic pulses use `Open` and `Close`. Use the source rig for any production handoff that requires a different load count or playing the interrupted action at a different point.

## Original melee rigs

All three melees carry their own keyed first-person rig and a single review reel with named sections. `RIGHT GRIP` and the Cleaver's separate `Left support grip anchor` locate the hand contacts. The screenshots use the original concept poses. Stock Knife is the scale and timing reference. Current game data has a seven-stud reach, a 0.60 s light cooldown and a 1.00 s heavy cooldown. The visual-contact poses follow the stock markers at 0.168 s, 0.231 s and 0.378 s after the respective inputs. Gameplay hit checking occurs at input. See [Knife timing in Viewmodel](../../../src/shared/Config/Viewmodel.luau) and [melee swing input](../../../src/client/Controllers/WeaponController.luau).

| Item | Controls and anchoring | Choreography |
| --- | --- | --- |
| Sounding Arc | `Grip` plus independent `Lower crescent`, `Upper crescent`, `Water ribbon` and `Inspect bead` | Sweep the segments up out of the folded carry. First light lifts out, second crosses back in. The heavy moves the gathered arc forward and reforms the open profile. In inspect, tip the face into the camera and roll the bead around the arc. |
| Kiln Cleaver | `Rear grip`, `Slab spine`, two ceramic jaw controls and `Heat insert`. The separate support grip binds to the rear-grip root. | Catch the slab low with the support hand and close the jaws. Alternate a tight descending cut with a broader rising return. Lift overhead and drop into the heat insert's reveal on heavy. Open the jaws in sequence on inspect. |
| Patch Tool | `Offset grip`, `Nested frame`, separate leading and trailing panels, two cheek sliders and three independent diagnostic cells | Fan open in ascending steps. Snap out on light A and backhand through light B. Nest on heavy windup and spread after contact. On inspect, spread the cheek sliders, run the three-cell sweep and close. |

The named recovery section demonstrates the return from a displaced follow-through. `CANCEL` demonstrates the transition from a displaced pose to the exact neutral pose. The reopened Blender files include numeric reset and camera-coverage checks in `reopen-check.json`.

## Charms and mounting

| Charm | Active controls | Mount and review |
| --- | --- | --- |
| Stormglass Buoy | `Bubble guide` raises one faceted air bead through the framed insert. | The closed oval loop keeps the float legible at reward-icon scale. |
| Foundry Stamp | Two `Jaw hinge` controls open around the persimmon enamel core. | The bronze-copper jaws sit closed for the icon and independently rotate open in the active frame. |
| Keycap Tester | `Key travel` depresses the glyph cap. Its mint ring has an independent shader intensity animation. | The raised three-bar glyph and smoked frame provide the icon contrast. |

The mounted charm boards show the hero player angle and the close swing pose. `mount.png` and `mount_reverse.png` capture the stock `CharmPoint` at the two ±15° extrema. The standalone file keeps the origin at the mount. Non-hero poses use compact versions where space is tighter. The nominal mount and animation are editor references for later review with final hands, camera motion and runtime attachment.

## Art development

The imagegen finish studies are linked and documented in the concept ledger. The final geometry follows the project’s stock files and faceted build style. The linked artist work informed material placement and visual pacing. [Koko Liem’s Kuronami study](https://kokoliem.artstation.com/projects/aoA4lq) · [Rabcat’s Prelude to Chaos study](https://rabcat_gameart.artstation.com/projects/5B2Vd1?album_id=705901) · [Bingxu Liu’s Phantom study](https://jeremy6.artstation.com/projects/JvEEBR)

### Built-in imagegen prompt record

One call per study. Vandal, Odin and Phantom used their own Gauntlet stock PNGs as silhouette references. The Phantom study was blocked during image-output moderation. Its final board uses the Blender design and the brief’s materials.

### Spindrift Vandal · saved

Use case: stylized-concept. Generate an original wide landscape AAA game cosmetic material and shape exploration, for the fictional Glitched Gauntlet Spindrift Vandal. Attached stock PNG is reference for exterior silhouette only. Draw one large clean three-quarter presentation of the original fictional cosmetic on a charcoal blue sheet and two smaller close studies of the same decorative shutter, closed and open. Keep the stock tapered silhouette, iron ring sight, three-part rear outline, bent dark magazine, and low angular forend recognizable. Storm instrument design: original broad cut-facet basalt shell #202B36, two folded pearl-alloy cheek frames #CADADD, a recessed smoked central side channel with two angular hinged decorative leaves, one restrained ribbon of sea-glass #76E6DA tracing the side when open, a single faded red-orange #D47C61 collar. Crisp planar cuts, believable seats and seams, selective fine tooling engravings, sparse and atmospheric. Graphically show a retail-ready game skin with a strong unbroken dark resting silhouette. No people, no scene action, no drafting dimensions, no cross-sections, no internal or functioning weapon design, no publisher branding. No typography.

### Kilnlock Odin · saved

Use case: stylized-concept. Landscape material exploration for the fictional Glitched Gauntlet Kilnlock Odin cosmetic. Stock sheet is exterior silhouette reference: keep heavy stock, existing stock feed and ammo box, grips, front profile and sights. Render an original portable foundry design: large matte pale firebrick ceramic facets #D5C1A4 against blackened iron #282525; sparse oxidized copper #9A5137 and a very small persimmon #FF793F heat bar. Main image is a stylized angular game asset product render. Two smaller close studies show a low ornamental rectangular cage on the left side, closed and with two jaws opened revealing the short solid heat bar. Designed for readability in a first-person game; offset rectangular vents and joined beveled plates. Dusty charcoal-grey backdrop. No words, no branding, no people or action. No internal or functional weapon description or dimensions.

### Stacklight Phantom · image output blocked

Use case: stylized-concept. Wide game cosmetic material exploration of fictional Glitched Gauntlet Stacklight Phantom, from the attached stock silhouette. Original modular electronics test bench design, warm ivory angular molded polymer #E4E1D7 over graphite #20232E, recessed smoked blue #344656 acrylic window with exactly three squared mint #53E4D2 indicator cells and a short clear shuttle in a separate shallow track. Keep the long stock suppressor visually quiet and stock sights intact. One large three-quarter silhouette, two smaller detail studies showing the same window asleep and at diagnostic sweep. Premium hard surface, purposeful tactile seam line and small chips only, flat chamfered facets, asymmetrical tooling. Charcoal studio backdrop, readable uncluttered silhouettes. No typography, no branding, no people or action. Exterior game cosmetic only.

### StormglassBuoy · saved

Use case: stylized-concept. Original standalone reward charm for Glitched Gauntlet, a palm-sized faceted storm navigation float. Compact opaque charcoal basalt body and tiny red-orange cap, one pearl-metal vertical frame around smoked sea glass, a single clearly visible mint air bubble, short closed oval mount ring. Render two views next to each other, three-quarter float and isolated close-up showing the air bead higher in the glass. Clean angular game-art finish with unequal chamfers, slate studio backdrop, sculpted silhouette; no text, no other objects, no weapon.

### FoundryStamp · saved

Use case: stylized-concept. Original standalone game reward charm shaped like a miniature square ceramic foundry seal. A pale chamfered firebrick square holds two small copper hinged shutter leaves over one persimmon enamel square, with a dark iron reverse and a short closed oval hang ring. Render two complementary three-quarter views at rest and with the little copper doors open. Slight real material character, stylized solid facets, charcoal backdrop, no text, no weapon, no other object.

### KeycapTester · saved

Use case: stylized-concept. Original standalone game reward charm. A single warm ivory control key on a square smoky dark-blue acrylic frame, three raised graphite glyph bars, one soft cool mint underglow, and a compact dark closed oval hang ring. Show rest and depressed key state side by side in matching angled studio product views. Strong pixel-size readability, clipped geometry, hard surface prop, graphite backdrop, no type, no weapon, no other object.

