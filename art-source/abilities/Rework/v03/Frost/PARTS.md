# Frost canister: parts sheet (ability rework v03)

Frost is a thrown ice canister: a **coolant cell**, the tall, pale partner of Molly's squat fuel can. A pale octagonal cage has deep cooling vents on seven facets (every facet except the back), and a cold-blue core shows through them. A charcoal clamp band, open at the back, splits the vents into upper and lower windows.

It shares Molly's family hardware: a dark flared foot, a charcoal lid with a shadow lip, a long slotted latch hinged at a heel on the foot and pinned through a fork slot in the arming head, and a faceted pull ring. Its own top is a **stepped two-tier arming head** (Molly's is a single raked block) plus a **vented relief valve** in place of Molly's burner nozzle. Frost has no arming pad.

- **Build:** made only in the live Blender MCP (scene `RW_MollyFrost`) by [frost_build.py](frost_build.py). Run it after `molly_build.py`, whose helpers and `MOLLY_SCALE` it shares, then call `frost_build(S)`. `FROST_SEATS` is the audit whitelist.
- **Source:** [Frost.blend](Frost.blend).
- **Export:** [../Exports/Frost.fbx](../Exports/Frost.fbx) + `.json`, with `kind = thrown` and `size_studs = 0.602`.
- **Renders:** `../Renders/Frost_*.jpg` and `MollyFrost_pair_hero.jpg`, `_hand.jpg`, `_silhouette.jpg`.

Axes: +X forward, +Y left, +Z up, 1 unit = 1 stud. The origin is the bounding-box centre. The model is built at the same 1.2 scale family as the scaled Molly.

## Overall
- **Size:** 0.323 deep (X) × 0.310 wide (Y) × 0.602 tall (Z). The brief asked for about 0.30 × 0.30 × 0.62. Molly is 0.383 × 0.451 × 0.455.
- **Parts:** 12 meshes plus 4 locators, **1,832 triangles**, one palette material per part. Pale is the largest area and Cold is the one identity colour.

## Parts
| Part | Role | Size X × Y × Z | Tris | Notes |
|---|---|---|---|---|
| Frost_Body | Pale | 0.240 × 0.259 × 0.408 | 298 | The casing: a tall octagonal tube 0.017 thick. The back is vertical and carries the latch; the front and sides taper in. It has 7 full-height vents with pointed ends: 0.065 wide on the front and sides, 0.034 on the corner facets. **The vents are 0.026 deep** down to the core. |
| Frost_Core | Cold | 0.187 × 0.207 × 0.403 | 28 | The cold cell inside the cage, seen through the vents. It stands in the foot. |
| Frost_Band | Body | 0.223 × 0.273 × 0.048 | 100 | The clamp strap below mid-height. It is open at the back, its ends are chamfered, and it is seated into the casing. |
| Frost_Foot | Dark | 0.320 × 0.310 × 0.115 | 252 | The battered, flared collar. Its back heel carries the hinge ears. |
| Frost_Lid | Body | 0.245 × 0.255 × 0.050 | 44 | The cap. Its lip overhangs the casing and it has a flat deck. |
| Frost_FuseHead | Panel | 0.178 × 0.108 × 0.079 | 120 | The stepped two-tier arming head. It overhangs the back shoulder, with a fork slot for the latch tongue. |
| Frost_FuseBezel | Dark | 0.049 × 0.049 × 0.012 | 80 | The bezel set low into the upper tier. |
| Frost_Fuse_Energy | Energy | 0.031 × 0.031 × 0.018 | 44 | The fuse light (team-tinted in game). |
| Frost_Latch | Metal | 0.033 × 0.096 × 0.474 | 262 | **Moving.** The long slotted lever: knuckle on the heel hinge, arm over the back face (stand-off 0.013), tongue in the fork. |
| Frost_HingePin | Metal | 0.022 × 0.122 × 0.022 | 124 | The pin through the heel ears and the knuckle. |
| Frost_Pin | Accent | 0.021 × 0.216 × 0.090 | 240 | **Moving.** The pull pin with a collar and a faceted ring (10 × 6) hanging 40° down off the back-left. |
| Frost_Valve | Metal | 0.060 × 0.060 × 0.058 | 240 | The octagonal relief valve on the front of the deck, with four vent windows under its cap. |

## Locators
| Locator | Position | Axis | Purpose |
|---|---|---|---|
| Frost_Handle | (0, 0, 0) | world | Grip and origin. |
| Frost_Fuse | (−0.0558, 0, 0.3012) | world | Top of the fuse light; the embers attach here. |
| Frost_LatchPivot | (−0.1326, 0, −0.2052) | local Y = −world Y (rotated 180° about Z) | Hinge axis. A **positive** turn about local Y opens the latch, the same convention as Molly. |
| Frost_PinOut | (−0.1254, 0.168, 0.2448) | world | Where the pin ends up when pulled. The pin's origin starts at (−0.1254, 0, 0.2448); travel is **0.168 along +Y**. |

## Motion and audit
- **Tests:** the latch at 15, 30, 45, 60, 75 and 90°, and the pin at 25, 50, 75 and 100% of its travel. None produced an overlap or coplanar faces; once pulled, the pin is clear of both fork cheeks. The recommended latch range is 0–70°.
- **Final audit:** `objects 12, tris 1832, style [], overlap [], coplanar [], floating [], open_edges []`.
- **Seats:** the whitelisted seats (`FROST_SEATS`) are all deliberate: the casing and core in the foot, the lid on the casing, the head and valve sunk into the deck, both pins through their ears and fork cheeks, the light and bezel in the head, and the band into the casing.

## Silhouette, Molly vs Frost
- **Flight:** in `MollyFrost_pair_silhouette.jpg`, Molly reads as a squat trapezoid with a leaning nozzle and Frost as a tall, slim column with a valve stack. Both carry the latch line at the back.
- **Hand:** in `MollyFrost_pair_hand.jpg`, Molly shows its warm jacket and the pad; Frost shows pale facets and cold vents. They share the latch, ring and fork head.

## Skill rules applied
- **`gauntlet-build-style`:** no cylinders or spheres (8-sided prisms, a faceted ring); no blunt ends (vents with pointed ends, chamfered band ends, scarf and chamfer caps); every joint seated or stepped; detail at edges and joints.
- **`lihfolk:roblox-blender-modeling`:** blockout first, under the triangle budget, centre origin, FBX_SCALE_UNITS, one material per object.
- **Style Bible §1–3.**
