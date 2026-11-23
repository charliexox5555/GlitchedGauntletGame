# Riftforge (First Legendary Bundle)

2026-11-22. Glitched Gauntlet's **first Legendary-tier weapon line** (`Config/Skins.luau → Legendary`, obtainable in **Apex Cases** and Featured Shop/Bundles). Inspired by the design principles of Valorant's *Prelude to Chaos* — heavy industrial dark-sci-fi machinery, an exposed suspended reactor core with articulated containment prongs, visceral mechanical reload/inspect feel, and thunderous distorted-metal audio — translated into **100% original Glitched Gauntlet flat-faceted low-poly geometry**.

**Hero Weapon:** **Phantom** (`RemasterV2 v05` stock envelope & rig contract).
**Concept Sheet:** [Phantom_concept_v01.png](out/Phantom_concept_v01.png) (awaiting owner approval before Blender build).

---

## 1. Research Takeaways (*Prelude to Chaos* Analysis)

What makes *Prelude to Chaos* feel genuinely legendary in first person (and how each principle adapts cleanly to Glitched Gauntlet):

| Pillar | Reference Principle | Riftforge Original Translation (Glitched Gauntlet) |
| --- | --- | --- |
| **Silhouette & Craft** | Heavy layered dark-metal armor plates, sharp angular bevels, ancient-relic-meets-heavy-industry weight with subtle bronze/gold trim. | Flat-shaded faceted obsidian-charcoal & forged slate-titanium exoskeleton plates with crisp beveled chamfers and brushed antique-bronze clamp pins/ribs. Strictly follows `gauntlet-build-style` (no smooth spheres, no organic curves, watertight seated joins). |
| **Exposed Reactor Core** | Floating internal energy orb visible in first person that spins, heats up during sprays, and disengages on inspect/reload. | **Cut-through mid-receiver reactor bay** holding a **suspended faceted octahedral plasma crystal** inside **two counter-rotating hexagonal containment rings**, framed by **4 articulated dark-steel prongs**. |
| **Split / Forked Front-End** | Heavy mechanical prongs around the barrel/muzzle that flare open to vent heat on sustained fire and reload, then slam shut on lock. | **Segmented octagonal suppressed baffle shroud** with upper & lower beveled armor forks that spring-flare outward with barrel heat and reload venting, exposing an internal plasma accelerator channel. |
| **Tactile Mechanical Motion** | Reload & equip feel like containing a volatile mini-reactor: chassis unlatches → cell/core ejects → prongs flare & vent → heavy magnetic lock-in. | Custom `Riftforge` moving hardware joints (`CoreCrystal`, `CoreRingOuter`, `CoreRingInner`, `ProngLeft`, `ProngRight`, `VentTop`, `VentBottom`) + custom reload/equip/inspect pose polish on the Phantom rig. |
| **Visceral Heavy Audio** | Bass-heavy thunderous mechanical pulse with subtle electric-guitar overdrive/power-chord resonance on shots, reloads, and kills (never thin "laser pews"). | Real licensed **ProPack** recordings processed into deep suppressed-railgun punch, heavy metallic bolt/prong slams on draw/seat, vent hiss on mag-out, and a resonant industrial overdrive accent (first-person only). |
| **First-Person Restraint** | Dramatic glow without blinding ADS or cluttering the sight picture. | Neon stays tight to the crystal core, thin suppressor accelerator slits, mag charge bar, and two tiny outer pips on the **open hexagonal-arch iron sight** (aim center 100% unobstructed; light/VFX budgeted under Bloom `< 2`, fading cleanly in ADS). |

---

## 2. Phantom Hero Architecture (Stock Contract Preserved)

Matched to `art-source/weapons/ModelSheets/Phantom_model_sheet.png` (muzzle length, grip positions, charm mount on left receiver, sight axis, magazine well):

- **Body & Armor Plates:** Stepped dark obsidian receiver shell wrapped in faceted slate-titanium shoulder shrouds with angled cooling louvers and bronze-gold mechanical lock collars.
- **Open Receiver Core Bay:** True cut-through chamber on the upper-mid receiver (prime first-person focal point!) housing:
  - `SK_CoreCrystal` — floating 8-face faceted violet-magenta plasma octahedron.
  - `SK_CoreRingOuter` & `SK_CoreRingInner` — two tilted 6-sided faceted titanium/bronze containment rings counter-rotating around the crystal.
  - `SK_ProngLeft` & `SK_ProngRight` — articulated dark-steel containment mandibles with bronze tips framing the bay.
- **Forked Suppressor Shroud:** Replaces the smooth stock suppressor cylinder with a heavy octagonal plasma-baffle shroud split by upper & lower beveled armor forks (`SK_VentTop`, `SK_VentBottom`) revealing a narrow glowing violet accelerator core.
- **Open Hex-Arch Rear Sight (`*Sight*`):** Angular open-top hexagonal sight housing with two dim lavender-white outer pips and a crisp unobstructed center aimline matching the stock Phantom sight axis.
- **Energy-Cell Magazine (`Mag` bone):** Ribbed dark obsidian-slate containment cartridge with a vertical recessed violet plasma charge window and chamfered bronze baseplate.
- **Skeletonized Angular Stock:** Faceted dark-steel triangular frame matching stock Phantom's open stock footprint, with a small rear capacitor fin.

---

## 3. Colour & Material Roles

| Role | Hex | Roblox Material | Usage |
| --- | --- | --- | --- |
| **Body** | `#181A22` | `SmoothPlastic` / `Metal` | Primary obsidian-charcoal faceted receiver & stock frame |
| **Panel** | `#434B5C` | `Metal` | Secondary forged slate-titanium armor shrouds & suppressor forks |
| **Dark** | `#101218` | `SmoothPlastic` | Deep mechanical recesses, core bay walls, vent cavities |
| **Grip** | `#1D2028` | `SmoothPlastic` | Faceted tactical grip scales with angular ridges |
| **Metal** | `#5C667A` | `Metal` | Containment rings, rails, controls, internal baffles |
| **Accent** | `#C09854` | `Metal` | Brushed antique-bronze locking pins, prong tips, clamp collars, mag base |
| **Neon (Core)** | `#D65CFF` | `Neon` (darkened on export) | Suspended crystal core, mag charge bar, narrow suppressor slits |
| **Neon (Hot)** | `#F5CCFF` | `Neon` | Inner core highlight facets & restrained outer sight pips |

---

## 4. Legendary First-Person Runtime Plan

1. **Live Moving Parts (`RiftforgeEffects.luau`, first-person only):**
   - **Idle:** Gentle crystal levitation + slow counter-rotation of both hexagonal rings; prongs breathe imperceptibly.
   - **Firing & Spray Heat:** Each shot kicks ring spin speed, heats the crystal toward white-magenta, and incrementally flares `ProngLeft`/`ProngRight` + `VentTop`/`VentBottom` outward with spring recoil (cooling down smoothly when the spray stops).
   - **Reload (`MagOut` → `MagIn` → `Close`):** Prongs & suppressor forks flare wide to vent plasma mist while the old energy cell drops; on `MagIn`/`Close`, all 4 jaws **SLAM** shut around the crystal with a bright violet core surge sweeping down the barrel.
   - **Draw & Inspect:** Crisp mechanical snap-lock on draw; on inspect, the prongs open wide as the crystal rises slightly and spins rapidly inside crackling violet micro-arcs before locking back in.
2. **VFX, Muzzle Flash, Tracer & Casings (first-person only):**
   - **Muzzle Flash (`MuzzleFx` style `"Riftforge"`):** Tight electric-violet plasma burst + twin crackling spark forks + suppressed violet-mist puff and subtle magenta muzzle light.
   - **Tracer:** Crisp electric-violet bolt core with white-lavender hot lead.
   - **Idle Core VFX:** Subtle violet `PointLight` (under Bloom threshold, fades during ADS) + intermittent micro-lightning arcs inside the open bay + sparse plasma sparks.
   - **Casings (`SkinCasings.Riftforge`):** Dark obsidian-metal case (`#1B1E28`) with electric-violet neon collar (`#8C36AD`).
3. **Custom Audio (`tools/audio/design_riftforge.py` → `Config/RiftforgeAudio.luau`):**
   - Licensed ProPack stems layered into a deep, punchy suppressed-plasma-cannon report, heavy metallic bolt/prong locks on draw & reload seat, pressurized vent hiss on mag-out, crackling inspect hum, and a resonant industrial overdrive kill accent.

---

## 5. Proposed Full Bundle Roster (After Hero Phantom Approval)

1. **Phantom** *(Hero — build first)*
2. **Vandal** *(or Operator — confirm with owner)*
3. **Operator**
4. **Sheriff** *(or Shorty / Stinger)*
5. **Riftforge Greatsword / Energy Cleaver** *(Legendary Melee with floating core hilt & crackling violet arcs)*
