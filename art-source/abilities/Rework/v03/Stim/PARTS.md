# Stim beacon: parts sheet (ability rework v03)

A placed support beacon. A heavy octagonal floor flange carries a tapered charcoal housing with a slate shoulder cap whose lip overhangs it: that lip is the seam. From the shoulder a dark collar seats a machined octagonal mast. Four dark insulator ribs on the mast hold a three-turn yellow coil made of flat 8-segment turns, with metal terminal clamps over both coil ends. A slate crown with a bright metal emitter spike sits above the coil. Four slate stabiliser legs hinge between metal ears at the foot of the four diagonal faces. Folded, they nest in dark bays in the housing and tuck into notches in the shoulder lip. When the beacon lands they snap down onto toe pads. The front face (+X) carries the status light in a dark bezel and a hazard plate with two cut stripes.

Built only in the live Blender MCP (scene `RW_Stim`) from [stim_build.py](stim_build.py). `stim_build(S)` rebuilds everything from scratch; `stim_pose(angle)` sets the legs; `STIM_SEATS` is the audit whitelist.
- Source: [Stim.blend](Stim.blend) (the `Stim` collection on its own). It is also saved in `AbilityRework_v03.blend`, scene `RW_Stim`.
- Export: [../Exports/Stim.fbx](../Exports/Stim.fbx) and [../Exports/Stim.json](../Exports/Stim.json), with `kind = placed` and `size_studs = 1.158`.
- Renders: `../Renders/Stim_*.jpg`:
  - views: hero, back, side, front, top, side_ortho;
  - poses and reads: closed, far (the 20-stud floor read), fist (the 0.45-scale hand read), silhouette, silhouette_hero;
  - close-ups: coil, close_clamp, close_hinge, close_seam, close_light.

Axes: +X forward, +Y left, +Z up, 1 unit = 1 stud. The origin is the floor centre.

## Overall
- **Size, legs open:** 1.023 × 1.023 × 1.158 studs. The beacon body is 0.822 across the flange flats (0.89 across its corners). The legs reach 0.512 from the centre on the diagonals.
- **Size, legs closed:** 0.89 × 0.89 × 1.158.
- **Triangles:** 3,046 in total, across 22 mesh parts and 6 locators. This is over the ~2,600 target. The four hinged legs, their ears and their pins cost 1,184 of it (see Notes).
- **Materials:** one `rw_mat` role per part.

## Parts (size is the world bounding box in the open pose)
| Part | Role | Size X × Y × Z | Tris | What it is |
|---|---|---|---|---|
| Stim_Foot | Dark | 0.822 × 0.822 × 0.070 | 44 | Battered octagonal floor flange with a chamfered top. |
| Stim_Housing | Body | 0.730 × 0.730 × 0.291 | 320 | Tapered octagon; each face leans back 9.2°. It has recesses for front, sides and back, with 45° chamfered mouths, and four 0.012-deep leg bays on the diagonals. |
| Stim_Shoulder | Panel | 0.665 × 0.665 × 0.107 | 172 | Cap with a 0.013 overhanging lip (the seam), a hip roof and a deck. Its four lip notches are where the folded legs tuck in. |
| Stim_Collar | Dark | 0.237 × 0.237 × 0.056 | 60 | Mast collar seated in the deck. |
| Stim_Mast | Metal | 0.142 × 0.142 × 0.570 | 124 | Octagonal mast with a turned groove and a step down where the coil sits. |
| Stim_CoilCollar | Dark | 0.196 × 0.196 × 0.052 | 60 | Insulator collar under the coil. The ribs stand on it. |
| Stim_Coil_Yellow | Yellow | 0.392 × 0.392 × 0.252 | 308 | Three turns, 8 flat segments per turn, pitch 0.07, with mitred joints. The section is 0.048 × 0.042 with chamfered outer corners. Both ends sit inside the clamps. |
| Stim_CoilRibs | Dark | 0.261 × 0.261 × 0.299 | 128 | Four radial insulator ribs on the coil's mid-faces. Their bottom ends are cut at 45°. |
| Stim_CoilClamps | Metal | 0.082 × 0.075 × 0.276 | 88 | Two terminal clamps (bottom and top coil ends) on the 22.5° rib. |
| Stim_Crown | Panel | 0.325 × 0.325 × 0.070 | 76 | Faceted crown with an underside flare and a stepped top. |
| Stim_Emitter | Accent | 0.092 × 0.092 × 0.070 | 60 | Octagonal emitter spike ending in a 0.028 flat (not a point). |
| Stim_FrontBezel | Dark | 0.032 × 0.155 × 0.078 | 92 | Light bezel with a recessed lens pocket. |
| Stim_Light_Energy | Energy | 0.022 × 0.066 × 0.032 | 44 | Status lens, chamfered and sitting 0.008 proud of the bezel. It is team-tinted in game. |
| Stim_Hazard | Hazard | 0.035 × 0.155 × 0.097 | 90 | Hazard plate with two cut stripes at 60°. |
| Stim_SidePanels | Panel | 0.164 × 0.722 × 0.193 | 88 | Two inset side plates (±Y), each with one big cut corner, forward-up. |
| Stim_BackHatch | Panel | 0.050 × 0.146 × 0.186 | 108 | Back hatch with two vent slots. |
| Stim_HingeEars | Metal | 0.661 × 0.661 × 0.073 | 160 | Eight hex-profile ears, seated in the flange and the bay floors. |
| Stim_HingePins | Accent | 0.653 × 0.653 × 0.023 | 176 | Four hex pins with chamfered heads. |
| Stim_Leg1–4 | Panel | 0.291 × 0.291 × 0.125 each | 212 each | **Moving.** A hex knuckle, a spade blade 0.30 long and 0.196 wide with a machined slot, and a toe pad that sits flat on the floor when open. |

## Locators (EMPTY → Attachment)
| Locator | Position | Axis | Purpose |
|---|---|---|---|
| Stim_Floor | (0, 0, 0) | world | Origin and floor centre. |
| Stim_Top | (0, 0, 1.158) | world | Tip of the emitter; sparks and arcs spawn here. |
| Stim_Leg1Pivot | (0.2599, 0.2599, 0.105) | rot Z 45° | Hinge of Leg1. Local Y is the hinge axis; a positive turn opens the leg. |
| Stim_Leg2Pivot | (−0.2599, 0.2599, 0.105) | rot Z 135° | Same for Leg2. |
| Stim_Leg3Pivot | (−0.2599, −0.2599, 0.105) | rot Z 225° | Same for Leg3. |
| Stim_Leg4Pivot | (0.2599, −0.2599, 0.105) | rot Z 315° | Same for Leg4. |

Each leg's origin is its pivot. A leg's rotation equals its pivot's frame turned by θ about local Y. At θ = 0 the blade points straight out, horizontal.
- **Open (authored pose):** θ = **+13°**. The blade tips down 13° and the toe pad is flat on the floor.
- **Closed (fist and flight):** θ = **−99.2°**. The blade is folded up flat in its bay, 0.006 off the bay floor, and its tip sits in the shoulder notch.
- **Travel:** 112.2°. Snap open from −99.2° to +13°. The coil does not move, so there is no `Stim_CoilDown`.

## Final audit (`rw_audit("Stim_", seats=STIM_SEATS)`)
- **Open:** `objects 22, tris 3046, style [], overlap [], coplanar [], floating [], open_edges []`.
- **Folding:** clean with the legs at −99.2°, −60°, −30°, 0° and +13°.

Whitelisted seats (deliberate overlaps):
- Housing–Foot, Shoulder–Housing, Collar–Shoulder, Mast–Collar, CoilCollar–Mast: each part is sunk 0.005–0.03 into the one below it.
- CoilRibs–Mast, CoilRibs–CoilCollar, CoilRibs–Crown, Mast–Crown: the rib roots and tops are buried in the parts they join.
- CoilRibs–Coil: the coil sits 0.005 into the rib edges.
- CoilClamps–Coil and CoilClamps–CoilRibs: the clamps wrap the coil ends and bolt to the rib.
- Emitter–Crown: the emitter is sunk into the deck.
- HingeEars–Foot and HingeEars–Housing: the ears are seated in the flange and the bay floor.
- HingePins through HingeEars and the leg knuckles.
- The front, side and back plates sit 0.002 into their recess floors; the light lens sits in its bezel pocket.

## Grade (self, V1–V9, 0–2)
| | Score | Note |
|---|---|---|
| V1 silhouette | 2 | The white silhouette reads base / mast / coil / crown at 64 px. The legs widen the foot. |
| V2 hierarchy | 2 | Big: flange, housing and coil. Medium: shoulder, mast, crown, legs. Small: hinges, clamps, light, hazard plate. |
| V3 proportions | 1 | It is planted and wide, but the mast stack (collar, mast, groove, coil collar) is a touch thin and busy under the head. |
| V4 chamfers | 2 | One language throughout: 0.004–0.006 on plates, 0.011–0.03 on the big forms, 45° recess mouths. |
| V5 shading | 2 | Flat faces only, and no artifacts in the close-ups. |
| V6 colour/value | 2 | Charcoal housing, slate cap and legs, dark flange, ribs and bays. The accents are the yellow coil, a small hazard plate and a cyan light. |
| V7 geometry earns it | 2 | Every detail has a job: bays, notches, hinges, terminal clamps, vents, lens pocket. Panel middles stay quiet. |
| V8 kit match | 2 | Same palette, planar-cut language and hinge hardware as Molly. |
| V9 game-ready | 1 | Not yet verified in Studio, and over the triangle target. |
| **Total** | **16/18** | |

The owner's rejection words, checked against the renders:
- No rounded parts: the coil, mast and crown are 8-sided, and the pins and knuckles are hexes.
- No blunt ends: the emitter, rib feet, toes and leg tips are all carved.
- Fluid joints: every join has a collar, lip, bay or seat.
- Character: the snap-open legs and the coil.

## What was kept from the old Stim
- Octagonal housing about 0.45 tall.
- Four floor panels around the base, now the hinged legs.
- A stepped mast.
- The yellow coil centred around 0.9 (now 0.89).
- A spike on top.
- Status light on the front face.
- Hazard paint.
- Total height 1.16 (was 1.10).

## Notes for the parent
- **Triangles: 3,046.** To reach ~2,600, the cheapest cuts are the leg slots (about −160) and a 6-sided mast and crown (about −120). The leg hinges are what makes the deploy read as real; I would cut those last.
- **Appended reference data:** the read-only `Stim.blend` reference was appended, studied (hero and side) and deleted: objects, meshes and materials. A `bpy.data.libraries["Stim.blend"]` entry still shows 1 user after the Blender restart. I left it, because removing a library that something still uses is not mine to do. It holds no Stim objects.
- **`rw_bool`:** the material-slot issue is handled by `st_finish` (one slot, index 0) in this build.

## Second-opinion prompt (ChatGPT, optional)
"Model sheet of a stylised game prop, low-poly faceted hard-surface (no curves, flat shading, chunky chamfers), matte charcoal and slate with one electric-yellow element: a support beacon 1.15 m tall. It has a wide octagonal floor flange, a tapered octagonal housing with an overhanging shoulder cap, a short octagonal mast, a bold three-turn faceted yellow coil held by four dark insulator ribs, and a crown with a short metal spike. The front face has a small cyan status light and a yellow hazard plate. Four slate stabiliser legs are hinged at the foot. Show three panels: legs folded flat against the housing; legs snapped open onto the floor; a top-down three-quarter view from 20 m. Dark neutral background, even studio light, Valorant-like restraint."
