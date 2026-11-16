# Molly canister: parts sheet (ability rework v03)

Molly is a thrown fire canister: a squat, faceted fuel cell. It passed the parent's review and the in-hand check in Studio on 2026-11-16. It was then scaled up by **1.2× uniformly about its origin** because it read small in the block fist.

The shape: a charcoal frame (slate lid with a shadow lip, two strap ribs, a flared dark foot with a raked toe) holds a warm heat jacket that wraps everything except the back. The jacket has two machined louvres on the left and two chevron heat vents on the front. On the back, a slotted latch lever is hinged at a heel on the foot and pinned through a fork slot in the raked arming head. The pull ring hangs off the back-left. A framed warm thumb pad sits on the deck, and a metal burner nozzle leans out of the raked front cut.

- **Build:** made only in the live Blender MCP (scene `RW_MollyFrost`) by [molly_build.py](molly_build.py). `molly_build(S)` rebuilds from scratch, `MOLLY_SCALE = 1.2`, and `MOLLY_SEATS` is the audit whitelist.
- **Source:** [Molly.blend](Molly.blend).
- **Export:** [../Exports/Molly.fbx](../Exports/Molly.fbx) + `.json`, with `kind = thrown` and `size_studs = 0.455`.
- **Renders:** `../Renders/Molly_*.jpg`, plus `MollyFrost_pair_*.jpg`.

Axes: +X forward, +Y left, +Z up, 1 unit = 1 stud. The origin is the bounding-box centre.

## Overall
- **Size:** 0.383 deep (X) × 0.451 wide (Y) × 0.455 tall (Z). Before scaling it was 0.319 × 0.376 × 0.379.
- **Parts:** 15 meshes plus 5 locators, **1,976 triangles**, one palette material per part.

## Parts (sizes after scaling)
| Part | Role | Size X × Y × Z | Tris | Notes |
|---|---|---|---|---|
| Molly_Body | Body | 0.324 × 0.396 × 0.250 | 136 | The leaning, tapered octagonal shell. It has the jacket seat and the latch channel down the back. |
| Molly_Lid | Panel | 0.305 × 0.375 × 0.071 | 96 | The shoulder cap. Its lip overhangs the shell, and it has the raked front cut, the pad pocket and the channel notch. |
| Molly_Panel_Warm | Warm | 0.315 × 0.403 × 0.192 | 222 | The heat jacket, proud of the shell in its seat. The left end has a 45° cut corner. The louvres and chevrons are cut through it to the seat floor: **0.019 deep** after scaling, above the 0.012 minimum. |
| Molly_Ribs | Body | 0.077 × 0.351 × 0.240 | 48 | Two front-corner straps that clamp the jacket. |
| Molly_Foot | Dark | 0.383 × 0.451 × 0.133 | 268 | The battered, flared collar with a raked toe. Its heel carries the hinge ears. |
| Molly_FuseHead | Body | 0.194 × 0.120 × 0.068 | 72 | The low, raked arming head. A fork slot at its back takes the latch tongue. |
| Molly_FuseBezel | Dark | 0.058 × 0.058 × 0.012 | 80 | The bezel round the light, set low into the head. |
| Molly_Fuse_Energy | Energy | 0.035 × 0.035 × 0.019 | 44 | The fuse light (team-tinted in game). |
| Molly_Latch | Metal | 0.033 × 0.101 × 0.332 | 252 | **Moving.** The slotted lever: knuckle, arm in the channel, tongue in the fork. |
| Molly_HingePin | Metal | 0.022 × 0.122 × 0.022 | 124 | The pin through the heel ears and the knuckle. |
| Molly_Pin | Accent | 0.021 × 0.217 × 0.096 | 276 | **Moving.** The pull pin and faceted ring. The ring hangs 65° down off the back-left, so it stays clear of the pad in the hand view. |
| Molly_ArmPad | Warm | 0.053 × 0.041 × 0.054 | 78 | **Moving.** The thumb pad on its plunger. |
| Molly_PadFrame | Dark | 0.086 × 0.072 × 0.012 | 80 | The frame round the pad pocket. |
| Molly_NozzleCollar | Body | 0.087 × 0.075 × 0.089 | 44 | The boss seating the nozzle in the raked cut. |
| Molly_Nozzle | Metal | 0.080 × 0.069 × 0.101 | 156 | The burner outlet: flared bell, scarf-cut mouth and stepped bore. |

## Locators (after scaling)
| Locator | Position | Axis | Purpose |
|---|---|---|---|
| Molly_Handle | (0, 0, 0) | world | Grip and origin. |
| Molly_Fuse | (−0.0741, 0, 0.2274) | world | Top of the fuse light; the embers attach here. |
| Molly_LatchPivot | (−0.1641, 0, −0.1134) | local Y = −world Y | Hinge axis. A **positive** turn about local Y opens the latch. |
| Molly_PinOut | (−0.1641, 0.168, 0.195) | world | Where the pin ends up when pulled. The pin's origin starts at (−0.1641, 0, 0.195); travel is **0.168 along +Y**. |
| Molly_ArmPadDown | (−0.0525, 0.1056, 0.147) | world | The pressed pad. The pad's origin starts at (−0.0525, 0.1056, 0.1662); travel is **0.0192 down**. |

## Motion and audit (re-run after the scale-up)
- **Tests:** the latch at 15, 30, 45, 60, 75 and 90°; the pin at 25, 50, 75 and 100% of its travel; and the pad pressed. None produced an overlap or coplanar faces. The recommended latch range is 0–70°.
- **Final audit:** `objects 15, tris 1976, style [], overlap [], coplanar [], floating [], open_edges []`.
- **Seats:** the whitelisted seats (`MOLLY_SEATS`) are all deliberate: the shell in the foot, the jacket in its seat, the head, frame, pad and nozzle boss sunk into the lid, both pins through their ears, the light and bezel in the head, and the ribs over the jacket into the shell and foot.

## Grade
- **Self-grade:** 15/18 before the final top change.
- **Blind panel:** 13/18 on the version with the old top. The panel's main note, the teapot-like top, was then fixed: the forked raked head, a light set low into it, and a metal nozzle.
- **Skill rules applied:** `gauntlet-build-style` (faceted, no blunt ends, seated joints), `lihfolk:roblox-blender-modeling` (blockout first, budget, centre origin, FBX_SCALE_UNITS, one material per object), Style Bible §1–3.

## Notes
- `rw_bool` leaves an empty extra material slot. The build flattens every part back to its one role material.
- The ring now sits right beside the pad in the hand view, not over it. It's worth a second look in Studio.
