# Riftforge Legendary Bundle Plan (5 Guns + Riftfang Knife)

2026-11-23. Locked roster and production blueprint for Glitched Gauntlet's **first Legendary-tier bundle** (`Config/Skins.luau → Legendary`, obtainable in **Apex Cases** and Featured Shop). All weapons share the verified **Phantom v02** visual, mechanical, VFX, and audio language:

- **Sculpted Compound-Faceted Geometry:** Multi-station 12-sided hulls (`hull_bm`) and swept 3D armor blades (`facet_blade_bm`) with machined steel edge bevels, antique-bronze structural collars/clamps, zero boxy slabs, and closed-manifold FBX exports (`FLIPPED: {}`, `OPEN_FLIPPED: {}`).
- **Shared Surface Tiles:** `Riftforge_Forged` (`115421153499187` — machined octagonal forged obsidian plating), `Riftforge_Plasma` (`126367018987152` — scrolling violet-magenta plasma veins), and `Payload_Carbon` (`113233933286545` — grip twill).
- **Action Removal & Mechanical Identity:** Replace mundane bolts/slides/charging handles with articulated reactor armor cowls, dual counter-rotating gimbal rings, floating dark-matter crystals, 3D Plasma Halo Rings, and magnetic plasma reloads.
- **Full Replacement Audio (`RiftforgeAudio.luau`):** 100% real licensed/CC0 recordings (ProPack + Sonniss GDC 2016 Pole Position weapon mics + steel bulkhead low sub-thump + CC0 electric/lightning/metal latch/blade) using `"riftforge:<key>"` bank IDs matched to `TempestAudio` reference levels (`REPORT = 1.34`, `FOLEY = 0.92`), voice-protected in `AudioController`.

---

## 1. Locked Weapon Roster

| # | Weapon | Status | Core Fantasy & Signature Hook |
| --- | --- | --- | --- |
| 1 | **Phantom** | **Done (v02)** | Cut-through reactor bay, dual gimbal rings, flaring armor cowls, fluted plasma suppressor, 135° snap-twist draw, 360° empty-reload spin, levitating crystal inspect. |
| 2 | **Knife (`Riftfang`)** | **Next (Concept → Blender)** | XERØFANG-inspired sleek tactical combat dagger with **3 segmented reactive spine scales** that ripple open base→tip, micro crossguard reactor crystal, snappy tactical flips, 3-hit slash combo + heavy thrust, and mesmerizing reverse-flip inspect. |
| 3 | **Operator** | Planned | Heavy industrial **dual-rail plasma sniper cannon**. Oversized mid-chassis floating reactor core; **no stock bolt handle** — after every shot, upper/lower rail shrouds recoil back and vent violet plasma shockwaves while the core re-charges (`CycleRiftforgeOperator`). Magnetic battery-core reload. |
| 4 | **Sheriff** | Planned | **Heavy Reactor Revolver**. Replaces the plain bullet cylinder with a **suspended glowing plasma crystal drum** spinning inside a bronze/steel cage. On reload, the cage swings out, spent core bursts into plasma, a 3D portal ring condenses a fresh crystal core, and a crisp magnetic flick snaps it locked. |
| 5 | **Spectre** | Planned | **Twin-Vent Compact Plasma SMG**. High-ROF suppressed sister to Phantom with twin side accelerator fins that flutter open during sprays, fast magnetic snap-draw, and rapid plasma-cell swap reload with 3D barrel pulse rings. |
| 6 | **Shorty** | Planned | **Break-Action Plasma Pocket Shotgun**. Heavy bronze-hinged twin barrel that cracks open to expose **two glowing plasma shells** suspended inside articulated upper/lower jaw cowls; spent shells burst into violet sparks on eject and two fresh cells magnetically slam into the breech as the jaws snap shut. |

---

## 2. Hero Melee Design — **Riftfang** (XERØFANG-Inspired Legendary Knife)

### Silhouette & Proportions
- **Envelope:** Matched to stock Knife rig (`Knife_RemasterV2`), crisp compact tactical dagger footprint (`~1.62` studs total length) so it **never blocks the first-person screen** while feeling ultra-sharp and aggressive.
- **Blade Profile:** Forward-canted predator-fang drop-point / recurve-tactical dagger with:
  - Deeply beveled **forged-obsidian primary blade flats** (`Riftforge_Forged` tile) framed by razor-bright **machined steel cutting bevels**.
  - A **recessed glowing scrolling-plasma edge groove & fuller** (`Riftforge_Plasma` tile, `#B438FF` → `#EDC4FF` tip filament) running along the lower cutting belly and up the fang tip.
  - **Sculpted Ergonomic Handle:** Carbon-twill angled grip (`Payload_Carbon`) with antique-bronze pommel knuckle-ring & chamfered guard collar.
- **5 Articulated Moving Parts (First-Person Driven by `Util/RiftfangKnife.luau`):**
  1. **`SK_Root_CoreCrystal`** — Compact faceted octahedral violet plasma core suspended inside a cut-through **Crossguard Reactor Eye** right where thumb meets guard.
  2. **`SK_Root_CoreRing`** — Micro antique-bronze hexagonal ring orbiting smoothly around the crossguard crystal (accelerates on slashes & inspect).
  3. **`SK_Root_Scale1`**, **`SK_Root_Scale2`**, **`SK_Root_Scale3`** — **Three overlapping compound-faceted obsidian/steel/bronze spine scales** along the top back of the blade! Driven by staggered springs (`base → mid → tip` ripple):
     - **Idle:** Seated tight and sleek along the spine, with subtle living-machine micro-breathe every few seconds.
     - **Draw:** Scales **ripple rapidly open & snap shut** (`Scale1 → Scale2 → Scale3`) as the blade locks into grip!
     - **Slashes (`M1`):** Brief predatory flare outward on the apex of every swipe, exposing bright glowing plasma beneath each scale.
     - **Heavy Attack (`M2`):** All 3 scales **flare wide open in sequence** during the wind-up coil as lightning arcs jump from guard → tip, then **SLAM shut** on impact!
     - **Inspect:** Scales ripple open in a continuous fluid wave while the dagger spins/flips in hand, exposing the incandescent plasma spine core!

### Custom Animation Set (`Config/Viewmodel.luau` → `Riftfang*`)
Built in the ultra-snappy, tactile **XERØFANG / XenoHunter** spirit (fast, weighty, crisp overshoot & settle — zero floaty drift):
1. **`RiftfangDraw` (`0.68s`)**:
   - Snappy low-left tactical pull-out with a **fast one-handed reverse-to-forward palm flip** (360° flick around the guard pivot) catching cleanly into a ready low-angled predatory hold.
   - **Synced VFX:** Violet plasma ribbon trail arcs through the flip; as the blade locks (`0.48`), scales ripple shut (`1→2→3`) and a **3D Plasma Halo Ring** shoots guard → tip with a crisp tip spark pop!
2. **`RiftfangSlash1` / `RiftfangSlash2` / `RiftfangSlash3` (Fast 3-Hit M1 Combo)**:
   - **Hit 1:** Razor horizontal right-to-left reverse-fang swipe.
   - **Hit 2:** Crisp diagonal bottom-left-to-top-right backhand upward rip.
   - **Hit 3:** Snappy **reverse-grip spin-cut** (twists blade inward and whips outward) resetting cleanly to idle.
   - **Synced VFX:** Full-blade electric-violet swipe `Trail` + razor white-lilac edge highlight + crackling `STIM_ARC_2x2` micro-sparks on hit!
3. **`RiftfangHeavy` (`M2` Heavy Attack)**:
   - Tight predatory reverse-coil wind-up (blade pulls low-right, all 3 spine scales flare wide open charging with violet `STIM_BOLT` lightning along the edge) → **explosive forward diagonal lunge-cleave / stab** with a wide glowing violet crescent slash flash + shockwave ring!
4. **`RiftfangInspect` (`3.8s`, spam-restartable like all Gauntlet inspects!)**:
   - **Beat 1 (`0.00–0.28`):** Snappy tactical **wrist flick into reverse-grip**, tilting the faceted forged-obsidian blade flat toward the camera as `Scale1 → Scale2 → Scale3` ripple open one by one revealing the pulsing plasma core!
   - **Beat 2 (`0.28–0.58`):** Fluid **twirl / finger-spin around the bronze pommel ring** (`toss` pivot at the guard/ring!), trailing glowing violet plasma ribbons & crackling spine bolts inside a shimmering halo!
   - **Beat 3 (`0.58–0.84`):** Catches in forward-grip, smoothly rolls to showcase the opposite blade bevel & spinning crossguard crystal while a plasma energy wave sweeps guard → tip.
   - **Beat 4 (`0.84–1.00`):** All 3 spine scales **SLAM** locked shut (`Scale3 → Scale2 → Scale1`) with a crisp metallic latch snap into combat stance!

### Custom Knife VFX (`src/client/Util/RiftfangKnife.luau`)
- **Edge Plasma Sheath:** Sleek narrow lilac-violet `Beam` edge glow hugging the cutting edge (never obscuring the sculpted blade geometry — lessons learned from `TempestKatana`!).
- **Spine Lightning Bolts:** Intermittent thin `STIM_BOLT` violet arcs flickering from the crossguard crystal up through the segmented scales to the fang tip (surges bright on Heavy coil & Inspect).
- **Blade Slash Trails:** Dual-layer `Trail` (`body` deep violet plasma ribbon + `arc` razor white-lilac cutting edge + `static` crackle streak) active during every draw flip, slash, heavy lunge, and inspect twirl.
- **Impact Flare:** Hit body / wall triggers a bright violet plasma spark burst (`RiftforgeFx.splash`) + blade glow flash + custom metallic plasma cut audio!

### Custom Knife Audio (`tools/audio/design_riftforge_knife.py` → `RiftforgeAudio.luau`)
100% real licensed/CC0 recordings (ProPack knife whooshes + CC0 `SWORD`, `LATCH`, `SLIDE_LOCK`, `METAL_CLICK`, `ELECTRICITY`, `ZAP`, `CRACKLE`, `THUMP` bulkhead):
- `knifeDraw` (sharp metallic unsheathe + crisp scale-lock snap + violet zap tail)
- `knifeLight` ×3 (fast predatory electric-metallic whoosh cuts, peak matched cleanly to hit frames)
- `knifeHeavy` ×2 (charging plasma scale flare + heavy bass-driven industrial cleave)
- `knifeHitBody` ×3 & `knifeHitWall` ×3 (visceral plasma-metal strike + crackling spark ring)
- `knifeInspectStart`, `knifeInspectSpin`, `knifeInspectLock` (staggered mechanical scale clicks + magnetic spin hum + crisp lock slam)

---

## 3. Per-Gun Technical Specs (Remaining 4 Guns)

### Operator (`Riftforge Operator`)
- **Action Removed:** `Bolt`, `BoltHandle` removed — replaced by **articulated Upper & Lower Rail Shrouds (`RailTop`, `RailBot`)** + **Side Reactor Vent Flaps (`VentL`, `VentR`)**.
- **Cycle Animation (`CycleRiftforgeOperator`):** Instead of manually pulling a bolt, the rail shrouds violently recoil back & split open venting violet plasma mist + lightning arcs while the huge central `CoreCrystal` over-spins, then **SLAM** forward locking the next round!
- **Audio:** Pole Position Remington 700 / .50-cal GDC core + heavy steel bulkhead sub-thump + thunderous CC0 lightning crack (`1.6s` industrial plasma railgun report) + pressurized mechanical rail-cycle slam!

### Sheriff (`Riftforge Sheriff`)
- **Action Replaced:** Plain cylinder replaced by a **Suspended Plasma Core Drum** (central faceted crystal + 6 bronze energy cells + counter-rotating shroud ring).
- **Draw / Reload / Inspect:** Snappy one-handed cowboy-tech **vertical spin on Draw**; on **Reload**, cylinder swings out, spent core bursts into violet plasma, a **3D Portal Ring** condenses a glowing fresh crystal inside the open crane, and a crisp flick snaps it home!
- **Audio:** Pole Position S&W M66 .357 GDC punch + bulkhead sub-thump + crisp high-voltage snap (iconic heavy one-tap feel!).

### Spectre (`Riftforge Spectre`)
- **Action Removed:** `ChargingHandle` removed — replaced by **Twin Folding Forward Accelerator Cowls (`CowlL`, `CowlR`)** hugging the compact suppressor + exposed mid-body `CoreCrystal`.
- **Reload / Draw:** Ultra-snappy compact magnetic twist draw + rapid plasma-cell eject/gather reload with fast cowl snap!
- **Audio:** Pole Position HK MP7 on-gun & 1m mics + tight high-ROF (`cut = 0.135s`) suppressed plasma crack + bulkhead low thump!

### Shorty (`Riftforge Shorty`)
- **Action Enhanced:** Break-action hinge exposes **twin glowing faceted plasma shells** framed by articulated **Upper/Lower Breech Jaws** (`JawTop`, `JawBot`) + side micro-crystal core!
- **Reload / Draw:** Cracks open venting twin violet plasma bursts (no dull brass shell drop), converging plasma beads forge two glowing shells right into the chambers, and a heavy wrist snap **SLAMS** the barrel + jaws shut with a barrel plasma ring!
- **Audio:** Pole Position SPAS-12 / Saiga-12 heavy 12g core + massive bulkhead bass slam + twin electric discharge crack!

---

## 4. Production Order
1. **Riftfang Knife** — Approve concept sheet → build in live Blender 5.2 → install in Studio → implement `RiftfangKnife.luau`, `Riftfang*` tracks, and knife audio → Range playtest!
2. **Operator** — Flagship heavy rail-cannon sniper (biggest visual & audio showcase after Phantom + Knife).
3. **Sheriff** — High-pick pistol-round & eco staple with spinning crystal drum.
4. **Spectre** — Compact high-ROF suppressed SMG sharing Phantom's proven cowl/suppressor pipeline.
5. **Shorty** — Break-action twin-core pocket shotgun to complete the 6-piece Legendary bundle!
