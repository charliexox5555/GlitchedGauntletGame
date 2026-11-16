# Recall anchor: parts sheet (ability rework v03)

A sturdy, low field device. A dark keel plate with a pointed prow stands on four splayed legs with rubber pads. On it sits a charcoal housing whose flanks lean in and whose front deck is raked down to the prow. The raked deck carries a violet chevron, and the flat nose carries the status light. A slate deck plate on top holds a dark collar with a violet ring inside it. The violet core, a hexagonal elongated bipyramid, stands in the open on a centre cradle pin. Three hinged guard prongs surround it. The back prong is tall and hooks forward over the core, so the device "looks" forward. The two front prongs leave the front open. A carry handle on the back is what the owner picks it up by.

Built only in the live Blender MCP (scene `RW_Recall`) from [recall_build.py](recall_build.py). `recall_build(S)` rebuilds everything from scratch. `recall_pose(open_deg, core_up)` poses the moving parts, and `RECALL_SEATS` is the audit whitelist.
- **Source:** [Recall.blend](Recall.blend) (the `Recall` collection on its own). It is also saved in `AbilityRework_v03.blend`.
- **Export:** [../Exports/Recall.fbx](../Exports/Recall.fbx) and [../Exports/Recall.json](../Exports/Recall.json), with `kind = placed` and `size_studs = 1.022`.
- **Renders:** `../Renders/Recall_*.jpg`. The views are hero, back, side, front, top and side_ortho. There is also `far` (the floor view), `silhouette`, `silhouette_front` (a 140 px read), `fist` (a 160 px hand-view read) and `open`. The close-ups are close_core_cradle, close_prong_socket, close_foot and close_facing_light.

**Axes:** +X forward, +Y left, +Z up, 1 unit = 1 stud. The origin is the floor centre, and the prop faces +X.

## Overall
- **Size:** 0.699 deep (X: −0.364 to 0.335) × 0.784 wide (Y) × 1.022 tall (Z) studs. The brief asked for about 0.8 × 0.8 × 0.95–1.05.
- **Triangles:** 2,140 in total, across 20 mesh parts and 7 locators. The budget was about 2,800.
- **Materials:** one palette material per part, using `rw_mat` roles only.
- **Smallest feature:** the fixing heads, 0.024 across. Nothing is under 0.015.

## Parts
| Part | Role | Size X × Y × Z | Tris | What it is |
|---|---|---|---|---|
| Recall_Base | Dark | 0.655 × 0.520 × 0.080 | 76 | The keel plate: the housing plan grown by 0.05, with battered edges top and bottom. It ends in a prow with a flat nose. |
| Recall_Legs | Panel | 0.583 × 0.715 × 0.093 | 112 | Four splayed outriggers, tapered and chamfered. They run from under the plate down into the pads. |
| Recall_Pads | Grip | 0.637 × 0.784 × 0.046 | 176 | Four hexagonal rubber feet with a chamfered top. The legs plunge into them. |
| Recall_Housing | Body | 0.555 × 0.420 × 0.240 | 56 | The armoured body, with an arrowhead plan and a flat nose. The flanks lean in 0.02, the top edge is chamfered, and the front deck is raked (slope 1 : 1.5). |
| Recall_Deck | Panel | 0.376 × 0.320 × 0.024 | 44 | The slate top plate, with a chamfered lip. Its front edge is carved where the rake starts. |
| Recall_SidePanels | Panel | 0.260 × 0.427 × 0.140 | 64 | Two flank plates that lean with the wall. Each has one cut corner and sits 0.009 proud. |
| Recall_Fixings | Metal | 0.221 × 0.437 × 0.115 | 256 | Eight hexagonal bolt heads, four per plate, at the plate corners. |
| Recall_Handle | Metal | 0.099 × 0.150 × 0.171 | 76 | The back carry handle, a faceted strap loop. Its ends run into the back wall. |
| Recall_Bezel | Dark | 0.012 × 0.055 × 0.064 | 32 | The hexagonal bezel on the nose. |
| Recall_Light_Energy | Energy | 0.031 × 0.036 × 0.042 | 32 | The status light, a hexagonal lens with a chamfered face. It is on the front and is team-tinted in game. |
| Recall_Strips_Violet | Violet | 0.106 × 0.170 × 0.075 | 32 | The facing chevron, a guide strip inlaid 0.007 proud on the raked deck and pointing +X. |
| Recall_Collar | Dark | 0.277 × 0.277 × 0.115 | 80 | The octagonal cradle collar, with a chamfered top. |
| Recall_Ring_Violet | Violet | 0.218 × 0.218 × 0.060 | 64 | The octagonal ring inside the collar. It stands 0.01 above the collar top. |
| Recall_CradlePin | Metal | 0.055 × 0.064 × 0.185 | 32 | The hexagonal centre post with a tapered top. The core's lower tip sits in it. |
| Recall_Core_Violet | Violet | 0.200 × 0.173 × 0.400 | 44 | **Moving.** The core: an elongated hexagonal bipyramid, with a band at −0.07 to +0.03 and short cut tips. Its origin is at the centre, (0, 0, 0.70). |
| Recall_Prong1 | Metal | 0.184 × 0.100 × 0.629 | 200 | **Moving.** The tall back prong: a swept, tapered blade that hooks forward over the core, unioned with its hinge knuckle. Origin on the hinge. |
| Recall_Prong2 / Recall_Prong3 | Metal | 0.124 × 0.137 × 0.470 | 184 each | **Moving.** The front-left and front-right prongs: the same blade, shorter. Origin on the hinge. |
| Recall_Sockets | Metal | 0.388 × 0.447 × 0.120 | 264 | Three pairs of hinge ears with carved tops, sunk into the deck. |
| Recall_HingePins | Accent | 0.359 × 0.411 × 0.024 | 132 | Three hexagonal pins through the ears and knuckles, with chamfered ends. |

## Locators (EMPTY → Attachment)
| Locator | Position | Axis | Purpose |
|---|---|---|---|
| Recall_Floor | (0, 0, 0) | world | The origin and floor centre. |
| Recall_Top | (0, 0, 1.0) | world | Top centre, where the arrival effect spawns. It sits just in front of the back prong's hook tip, at (−0.065, 0, 1.01). |
| Recall_CoreUp | (0, 0, 0.78) | world | The armed core position: 0.08 straight up from the core origin at (0, 0, 0.70). |
| Recall_Prong1Pivot | (−0.19, 0, 0.42) | rotated 180° about Z, so local Y = −world Y | The back prong's hinge. |
| Recall_Prong2Pivot | (0.095, 0.1645, 0.42) | rotated 60° about Z | The front-left prong's hinge. |
| Recall_Prong3Pivot | (0.095, −0.1645, 0.42) | rotated −60° about Z | The front-right prong's hinge. |

Each prong's origin and rotation equal its pivot's. A **positive** turn about the pivot's local Y tilts that prong outward (open), away from the core.

## Motion (tested)
- **Prongs:** open 0 to 20°. Audited at 10° and at 20°, both with the core up: no overlaps and no coplanar faces.
- **Core:** travels +0.08 to `CoreUp`. Audited with the prongs at rest (closed) and with them open: no overlaps. Raised, the core reports "floating", which is expected because it has lifted off its pin. The tightest running clearance is 0.015, between a front prong and the band of the raised core. Both parts were returned to rest, and the rest pose re-audits clean.
- Running clearances: knuckle to ear 0.004, knuckle to deck about 0.03, and core band to prong at rest at least 0.025.

## Final audit (`rw_audit("Recall_", seats=RECALL_SEATS)`)
`objects 20, tris 2140, style [], overlap [], coplanar [], floating [], open_edges []`

Whitelisted seats (all overlaps are deliberate):
- Housing–Base, Legs–Base and Legs–Pads: the body is sunk into the plate, and the legs run into the plate underside and into the pads.
- SidePanels–Housing and Fixings–SidePanels: the plates are sunk 0.011 into the flanks, and the bolts 0.005 into the plates.
- Deck–Housing, Collar–Deck/Housing, Sockets–Deck/Housing and CradlePin–Deck/Housing: all of these are sunk through the deck plate into the body.
- Ring_Violet–Collar: the ring is pressed 0.003 into the collar's inner wall.
- Core–CradlePin: the core's lower tip sits in the pin top.
- HingePins–Sockets and HingePins–Prong: each pin passes through its ears and knuckle.
- Bezel–Housing, Light–Bezel and Light–Housing: the lens and bezel are sunk into the nose.
- Strips–Housing: the chevron is sunk 0.006 into the raked deck.
- Handle–Housing: the handle's ends run into the back wall.

## Grade (self, V1–V9, 0–2)
| | Score | Note |
|---|---|---|
| V1 silhouette | 2 | The side silhouette reads as a hooked back prong, the core, a back handle and a low prow. At 140–160 px the core and prongs still read. |
| V2 hierarchy | 2 | Big: keel and housing. Medium: collar, prongs, core. Small: pins, ears, bolts, light, chevron. |
| V3 proportions | 2 | Low and wide, with the core held high in the open. Nothing is spindly: the prongs are 0.06–0.10 wide. |
| V4 chamfers | 2 | One flat-chamfer language throughout. Every end is tapered, carved or run into its seat. |
| V5 shading | 2 | Flat faces only. No smoothing and no artifacts in the close-ups. |
| V6 colour/value | 2 | Dark keel, charcoal body, slate deck, plates and legs, metal hardware, violet as the only accent, and one team light. |
| V7 geometry earns it | 1 | The flank plates are honest but plain: a plate with four bolts. A vent or service hatch would give them a reason to exist. |
| V8 kit match | 2 | Same palette, prism and chamfer language, and seated-hardware approach as Molly. |
| V9 game-ready | 1 | Not verified in Studio yet. Export, pivots, scale and the names the game looks up are correct. |
| **Total** | **16/18** | |

**Facing read:**
- From above: the prow, the violet chevron and the forward hook of the back prong.
- From the side: the tall hooked back against the low raked front, with the handle at the back.
- From the front: the chevron over the status light.

The far view (`Recall_far`) shows the chevron and light on the front face.

## Skill rules applied
- **`gauntlet-build-style`.** No cylinders or spheres: round things are 6- or 8-sided prisms, and the core is a hexagonal bipyramid. No blunt ends. Every joint has a transition: plate, deck, collar, ears and pins, bezel. Detail sits at joints and edges. One identity colour.
- **`lihfolk:roblox-blender-modeling`.** Built big → medium → small. Silhouette and small-size reads were checked. 2,140 tris is inside the "medium" target. Floor-centre origin; FBX with FBX_SCALE_UNITS; one material per object.
- **Style Bible §1–3.** Readable first; tactical, not cute; faceted and carved; charcoal with one accent.

## Notes for the parent
- `rw_bool` leaves an empty material slot (same as on Molly). `rc_fix` in the build script flattens each part back to its one role material.
- RW_Violet (emission 2.5 under the Standard view transform) renders pink-white in Blender. Check the hue in Studio, where Neon behaves differently.
