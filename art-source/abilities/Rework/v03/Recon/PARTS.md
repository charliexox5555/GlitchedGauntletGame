# Recon bow + sensor bolt: parts sheet (ability rework v03)

**Bow.** A compact, machined recurve bow held upright in the right hand. A charcoal riser has a deep, palm-swelled grip, a sight window, and a left-hand cheek (+Y) that carries the read-out column on its rear face and the Scan sensor on its outer face. The lower riser has two chamfered lightening slots and the cheek has one. Dark clevis pockets on both ends hold slate limbs on hex pivot bolts and are screwed to the riser from the player's side. Each limb is four flat facets (a steep root, a 45° run, a shallow run and a recurve tip that turns back up), with a pointed lightening slot. The tips carry metal nock caps.

**Bolt.** A sensor bolt: a three-blade faceted head, a charcoal collar with the light ring and a machined metal band, a hex shaft (the machined flats), four angular Scan vanes in an X so none lies in the string plane, and a slotted metal nock.

Built only in the live Blender MCP (scene `RW_Recon`) from [recon_build.py](recon_build.py). `recon_build(S)` rebuilds both from scratch. `RECON_SEATS` and `DART_SEATS` are the audit whitelists, and `recon_pose(flex_deg, draw)` poses the draw.
- **Sources:** [Recon.blend](Recon.blend) and [../ReconDart/ReconDart.blend](../ReconDart/ReconDart.blend).
- **Exports:** [../Exports/Recon.fbx](../Exports/Recon.fbx) and `.json` (`kind = handheld`, `size_studs = 1.532`); [../Exports/ReconDart.fbx](../Exports/ReconDart.fbx) and `.json` (`kind = thrown`, `size_studs = 1.0`).
- **Renders:** `../Renders/Recon_*.jpg` and `../Renders/ReconDart_*.jpg`.

Axes: +X forward, +Y the player's left, +Z up, 1 unit = 1 stud. The bow's origin is the grip. The bolt's origin is its tip.

## Overall
| | Size X × Y × Z (studs) | Tris | Parts / locators |
|---|---|---|---|
| Bow, bolt nocked | 1.000 × 0.206 × 1.532 (tip to tip 1.532; riser front to string 0.455) | 2,314 (1,848 without the nocked bolt) | 27 / 9 |
| Bow body only | 0.473 × 0.206 × 1.532. The riser is 0.124 thick; the window cheek makes it 0.16; the pocket bolt heads reach 0.184; the sensor sits proud on the left. | | |
| Bolt | 1.000 long × 0.134 (Y/Z across the vanes; 0.18 across the vane diagonal) | 466 | 7 / 3 |

## Bow parts (`Recon`)
| Part | Role | Size X × Y × Z | Tris | Notes |
|---|---|---|---|---|
| Recon_Riser | Body | 0.225 × 0.160 × 0.620 | 332 | Faceted side profile. Sight window: right of y = 0.042 between the shelf (z 0.072) and the window head (z 0.236–0.252), with a concave chamfer at the wall. Two chamfered slots in the lower riser and one through the cheek. |
| Recon_Grip | Grip | 0.192 × 0.148 × 0.184 | 128 | An octagonal wrap with a palm swell and four V palm grooves. It clamps the riser throat; the riser spine shows 0.01 in front. |
| Recon_PocketTop / Bottom | Dark | 0.126 × 0.162 × 0.092 | 68 each | Clevis pockets. The base caps the riser end (sunk 0.01, overhanging 0.01–0.02). The cheeks leave a 0.006 gap each side of the limb. |
| Recon_BoltTop / Bottom | Accent | 0.038 × 0.184 × 0.033 | 92 each | Hex pivot bolts along Y through the cheeks and the limb knuckle. Heads on both sides. |
| Recon_Screws | Metal | 4 heads, 0.0135 across flats | 128 | Two screws per pocket into the riser. Heads on the rear face (the player's side), proud 0.006. |
| Recon_LimbTop / Bottom | Panel | 0.385 × 0.095 × 0.432 | 208 each | **Moving.** Four-facet plate sweep (0.048 → 0.025 thick, 0.095 → 0.05 wide) on an octagonal knuckle. Pointed hexagon lightening slot. Origin = pivot. |
| Recon_TipCapTop / Bottom | Metal | 0.066 × 0.054 × 0.056 | 24 each | Nock cap clamped over the limb end, with a rear lug that holds the string loop. **Parented to its limb**; weld it to the limb in Studio. Its origin is the limb pivot. |
| Recon_StringTop / Bottom | Dark | 0.014 across flats; 0.622 / 0.842 long | 20 each | Closed hex prisms. **Origin at the tip end; length along local +X** (the Roblox LookVector after the export axis map). Rest lengths are stored as the custom prop `rest_length`. Re-aim each frame: position = tip locator, local +X → hand, scale X = distance / `rest_length`. |
| Recon_Rest | Metal | 0.042 × 0.073 × 0.031 | 64 | Shelf block with a right-hand lip. Seated on the shelf and 0.004 into the window wall. 0.003 under the shaft. |
| Recon_Readout | Dark | 0.027 × 0.038 × 0.176 | 44 | Read-out plate sunk into the cheek's sloped rear face. |
| Recon_Charge_Energy | Energy | 0.022 × 0.024 × 0.126 | 176 | Four stacked segments (one object), proud 0.005. This is the draw-charge strip. |
| Recon_Bounce1_Energy / Bounce2_Energy | Energy | 0.015 squares | 44 each | Side by side above the strip: Bounce1 on the player's left (+Y), Bounce2 on the right. |
| Recon_Sensor / SensorLens | Dark / Scan | 0.082 × 0.017 × 0.070 / 0.058 × 0.046 | 32 / 32 | Sensor housing with one large cut corner, sunk into the outer face of the cheek, with the Scan lens proud of it. |
| Recon_Dart_Head, _Collar, _Light_Energy, _Band, _Shaft, _Fletch, _Nock | as the bolt | as the bolt | 466 | The nocked bolt: copies of the `ReconDart` meshes, tip at (0.647, 0, 0.11), the nock slot bottom on the string. Hide all `Recon_Dart*` parts when fired. They **translate with the nock** (−X by the draw). |

## Bolt parts (`ReconDart`, tip at the origin, body along −X)
| Part | Role | u range (X) | Size | Tris |
|---|---|---|---|---|
| ReconDart_Head | Accent | 0 → −0.098 | Three-blade faceted head (blades up, lower left, lower right), 0.068 across the blades, barb shoulder at −0.068 | 46 |
| ReconDart_Collar | Body | −0.086 → −0.157 | Octagon, 0.054 across flats, chamfered ends | 60 |
| ReconDart_Light_Energy | Energy | −0.106 → −0.124 | Octagonal ring proud 0.0055 all round, so it is visible from every side | 60 |
| ReconDart_Band | Metal | −0.129 → −0.145 | Machined ring | 60 |
| ReconDart_Shaft | Dark | −0.14 → −0.97 | Hex, 0.032 across flats (flats up and down) | 20 |
| ReconDart_Fletch | Scan | −0.80 → −0.962 | Four angular vanes at 45/135/225/315°, 0.015 thick, edges chamfered | 144 |
| ReconDart_Nock | Metal | −0.962 → −1.0 | Octagon with a 0.017 vertical string slot, 0.025 deep (prongs at ±Y) | 76 |

## Locators (EMPTY → Attachment)
| Locator | Position | Axis | Purpose |
|---|---|---|---|
| Recon_Handle | (0, 0, 0) | world | Grip and origin. |
| Recon_LeftGrip / Recon_Nock | (−0.335, 0, 0.11) | world | The drawing hand on the string; the nock point at rest. |
| Recon_NockDrawn | (−0.885, 0, 0.11) | world | Full draw: **0.55** behind rest along −X. |
| Recon_Muzzle | (0.647, 0, 0.11) | world | The nocked bolt's tip at rest. |
| Recon_LimbTopPivot | (0.035, 0, 0.355) | rotated 180° about Z (local Y = −world Y) | **A positive turn about local Y flexes the limb toward the string.** Origin of `Recon_LimbTop`. |
| Recon_LimbBottomPivot | (0.035, 0, −0.355) | world (local Y = world Y) | Same rule: positive about local Y = flex. Origin of `Recon_LimbBottom`. |
| Recon_TipTop / TipBottom | (−0.335, 0, ±0.732) at rest | parented to their limbs | String ends. At 12° of flex they move to about (−0.405, 0, ±0.645). |
| ReconDart_Handle | (0, 0, 0) | +X = flight direction | The tip, which sticks into surfaces. |
| ReconDart_Light | (−0.115, 0, 0) | world | Centre of the light ring (pulse / blink). |
| ReconDart_Tail | (−1.0, 0, 0) | world | Rear end (trail). |

## Motion (tested)
- **Flex:** 0 to 12° per limb. **Draw:** 0 to 0.55. Audited together at 4°/0.18, 8°/0.37 and 12°/0.55: no overlaps, no coplanar faces, nothing floating. Restored to rest, it re-audits clean.
- **Clearances:**
  - At full draw the collar ends 0.022 in front of the rest. The head blades and the light ring clear the window wall by 0.004 or more.
  - At rest the vanes sit 0.025 behind the grip.
  - Vane X pattern: no vane crosses the string plane at full draw.

## Final audit
- `rw_audit("Recon_", RECON_SEATS)`: objects 27, tris 2314, style [], overlap [], coplanar [], floating [], open_edges [].
- `rw_audit("ReconDart_", DART_SEATS)`: objects 7, tris 466, all lists empty.

Whitelisted seats, all deliberate:
- Grip–Riser: the clamped wrap.
- Pocket–Riser: the base is sunk 0.01.
- Bolt–Pocket and Bolt–Limb: the pivot passes through the cheeks and the knuckle.
- TipCap–Limb: the clamp.
- String–TipCap: the loop sits in the lug.
- StringTop–StringBottom: the halves meet at the nocking point.
- Rest–Riser: seated.
- Readout–Riser, Charge/Bounce–Readout and Sensor–Riser, Lens–Sensor: inset plates.
- Screws: into the pocket and riser.
- Bolt internals: head, light, band and shaft in the collar; shaft in the fletch and nock.
- Dart_Nock / Dart_Shaft–String: at full draw the string bears on the nock throat. A real bow does this. It is the only seat that appears only while posed.

## Grade (self, V1–V9, 0–2): 16/18
| | Score | Note |
|---|---|---|
| V1 silhouette | 2 | Recurve with crisp facet kinks, a bulky machined riser, and an asymmetric cheek from the hand view. Not a smooth bow. |
| V2 hierarchy | 2 | Big: riser and limbs. Medium: pockets, grip, bolt. Small: bolts, screws, rest, read-outs, sensor. |
| V3 proportions | 2 | Chunky for the first-person hand. The smallest features are the screws and the string (0.0135 to 0.014). |
| V4 chamfers | 2 | One flat-chamfer language: 0.005 to 0.012 on parts, 45° chamfered slot entries. |
| V5 shading | 2 | Flat shading only, no artifacts in the renders. |
| V6 colour/value | 2 | Charcoal riser, slate limbs, dark pockets and read-out, bright bolt heads. Scan only on the lens and the vanes; Energy on the read-outs and the bolt light. |
| V7 geometry earns it | 1 | The nock caps are simple hulls, and the grip is plain from the front. |
| V8 kit match | 2 | Same palette and planar-cut, slotted, bolted language as Molly and the Vandal/Phantom checks. |
| V9 game-ready | 1 | Not verified in Studio. The parented tip caps and locators need welding, and the strings need the re-aim code. |

## Notes for the parent
- `rw_bool` still leaves an empty material slot. `fix_mats()` in the build flattens each part back to one role material.
- The `rw_audit` overlap test reports parts within about 0.0015 as overlapping, so running gaps here are 0.003 or more. The coplanar test flags anything proud by under 0.004, so lights and plates are proud by 0.005.
- `rw_write_source("ReconDart")` writes to `v03/ReconDart/ReconDart.blend` (its own folder by default).
