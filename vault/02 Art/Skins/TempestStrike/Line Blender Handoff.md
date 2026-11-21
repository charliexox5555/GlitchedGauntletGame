# Tempest-Strike line: Blender handoff (Stinger, Marshal, Bucky, Sheriff, Knife)

2026-11-22. The Tempest-Strike **Vandal** is finished (model s08, VFX, animation and foley in Studio). This handoff builds the rest of the line **in Blender only**, to the same standard. The owner has Studio for another build: **no Studio, no uploads, no installs, no VFX**. When every item is graded 9+ and exported, the owner hands back to the Vandal session, which ports them and does the VFX.

**Roster (owner, 2026-11-22):** Stinger, Marshal, Bucky, Sheriff, plus the **Kunai-Katana** knife from the owner's own concept ([Kunai-Katana Concept](Kunai-Katana%20Concept.md); sheet image at `refs/style/Tempest-Strike Kunai-Katana Reference.png`). The roster is deliberately different from Ruin-Blighted (Vandal, Spectre, Ghost, Guardian, Operator), so the two bundles don't overlap.

## Before you start (mandatory)
1. Load the `gauntlet-vault` skill, then `gauntlet-build-style`, `blender-director` and `hard-surface` (plus `lihfolk:roblox-blender-modeling` for the quality gate). Cite the notes you use in the ledger.
2. Read, in this order: [concept brief](concept.md) (palette, water language, crescent sight, charm), the owner's [Vandal concept sheet](refs/style/Tempest-Strike%20Vandal%20Reference.png), the [Vandal Hero Plan](Vandal%20Hero%20Plan.md) (the whole r01 to s07 history: what was rejected and why), [Skin Build Pitfalls](../Skin%20Build%20Pitfalls.md), and `vault/02 Art/Style Bible.md`.
3. Look at the finished Vandal: `out/Vandal_s07_review.png` (the look to match) and the s08 blend `art-source/weapons/Skins/TempestStrike/Vandal/s08x/Vandal_TempestStrike_s08x.blend`.

## What made the Vandal work (follow this, don't reinvent it)
- **Build on the stock RemasterV2 model, never from scratch.** r01 to r03 were built new and rejected ("a new gun, misaligned, not like our guns"). s01 opened `art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend`, saved it as the working master and restyled on top of it: same rig, same bones, same contract points (Muzzle, AimPoint, LeftGrip, Eject, CharmPoint), same footprint.
- **But not a reskin.** s01 and s03 were called "basic reskin". Every main part must change shape: barrel or shroud, brake, sights, action or receiver plates, grip, mag, stock. Ruin-Blighted is the quality bar.
- **Crisp, not soft.** No smooth shading or weighted normals on hero faces, no 3+ segment rounded bevels, no wide octagon diagonals that read as round. Use flat 1–2 segment chamfers, near-square sections, raked or pointed blade ends. Curves are runs of straight segments (gauntlet-build-style: no round curves or spheres, no blunt cutoffs).
- **Seated, connected layers.** Plates sit in recesses with visible thickness (solidify outward, offset +1; check right-side plates, which were once thickened inward). Nothing floating, nothing flush or coplanar (z-fight), handle and stock joins buried and seamless (the owner caught a disconnected grip back and a stock bar that didn't meet its collar).
- **Sleek metal.** s04 needed "a sleeker metal look": brushed-silver blade plates on a storm-navy body, thin parts, nothing chunky.
- **Budget.** Stock Vandal 5,171 tris, final 9,896. Tri budgets below; reduce with dissolve-limited flats and by removing hidden bevels, never by losing silhouette.

## The Tempest-Strike design language (every item)
- **Palette roles** (material names exactly these, the flat exporter reads them):

| Material | Colour | Roblox material | Use |
|---|---|---|---|
| TS Body | 1D2433 | SmoothPlastic | storm-navy main body |
| TS Dark | 0C111C | SmoothPlastic | recesses, inner frames |
| TS Panel | DCE1E6 | Metal | brushed-silver blade plates, bands |
| TS Metal | 7A8491 | Metal | darker steel, sliders, small parts |
| TS Accent | 3E6580 | SmoothPlastic | small blue accents |
| TS Grip | 4A3328 | SmoothPlastic | leather wrap bands |
| TS Neon | 5FE6E0 | Neon | thin cyan conduit slots (thin lines only) |
| TS Brass | A8844E | Metal | the round / cartridge |

- **Motifs:** long silver blade plates with raked ends seated in the body; fluted octagonal shrouds or barrels; ported brakes with a pointed crown; thin recessed cyan conduit slots; overlapping diagonal leather wrap bands (tsuka-maki rhythm) on grips and mags; banded collars; skeletal stocks.
- **Sights:** the open **crescent** rear sight (big clear ADS window, about 1/5 of the screen, two small pips outside the aim centre) with a thin front post. Every sight part's object name contains `Sight` (the viewmodel fades non-sight parts on the aim line).
- **Water and lightning are not modelled.** VFX comes in Studio later. The model carries clean anchor surfaces only (shroud tops, vent slots, plate edges).

## Per-item briefs
Stock bases are in `art-source/weapons/RemasterV2/<Gun>/`. Use the **highest version** (`*_RemasterV2_v05.blend`; Bucky and Sheriff also have v04, use v05). Read the rig's bone list and every contract attachment first, and keep all of them. Measure the stock footprint and record it in the ledger like the Vandal's contract line.

| Item | Stock base | Class | Tri budget | Design direction | Keep separate for moving parts later |
|---|---|---|---|---|---|
| **Stinger** | `Stinger_RemasterV2_v05.blend` | SMG (auto) | ≤ 8K | compact storm SMG: short fluted shroud with a small ported brake, silver blade plates on the receiver, wrapped grip and wrapped mag, folding skeletal stock, crescent sight scaled down | the two side blade plates (vents), the crescent sight |
| **Marshal** | `Marshal_RemasterV2_v05.blend` | lever-action scoped sniper | ≤ 9K | long, thin and elegant: octagonal fluted barrel, a crescent-collared scope (crescent rings at both scope ends, scope lens objects untouched), silver blade plates along the receiver, wrapped fore-end and grip, lever reshaped as a sharp blade loop | the lever (its stock bone), the scope's crescent rings, side-gate cover |
| **Bucky** | `Bucky_RemasterV2_v05.blend` | pump shotgun | ≤ 9K | heavy storm shotgun: faceted barrel with a wide pointed brake, fluted pump fore-end wrapped in leather bands, armoured receiver with blade plates, crescent sight, shell-carrier plate | the pump (its stock bone), the receiver blade plates |
| **Sheriff** | `Sheriff_RemasterV2_v05.blend` | revolver | ≤ 6K | storm revolver: octagonal fluted barrel with top rib and pointed muzzle crown, cylinder with straight-cut flutes and cyan conduit slots, silver blade side plates, wrapped grip with a silver cap, small crescent rear sight | the cylinder (its stock bone: it spins on reload and inspect), hammer, the side plates |
| **Kunai-Katana** | `Knife_RemasterV2_v05.blend` + the owner's sheet | melee | ≤ 3.5K (sheet says 2,140 for the core) | see the Kunai-Katana section below | the water blade (`TS_Katana` bone for the extension), the pommel ring (`TS_Ring`, it spins on the draw twirl) |

### Kunai-Katana (owner concept, Blender scope only)
Follow the owner's sheet for shape and proportion; the brief's VFX and Roblox implementation notes are direction only (the Studio pass does those our way). Model:
- **Kunai core** (always visible): matte-black leaf/diamond blade with a raised centre spine and **brushed-silver bevelled edges** (separate edge plates seated on the blade, not painted), an etched lightning crack cut into the spine (shallow boolean groove, TS Neon thin line inside, or TS Panel); round steel **disc guard** with a chamfered rim; steel collar; **leather grip** with the **diamond wrap** modelled as crossed bands over a dark core (diamond windows recessed); a large steel **ring pommel** (an octagon or 12-gon ring with flat chamfers: no round torus).
- **Water blade** (`WaterKatana`, separate object, its own material `TS Water` = cyan 40F5D4): a long thin katana blade extending from the kunai tip, about three kunai-blade lengths, slight curve built from straight segments, sharp faceted edge and tip, diamond cross-section. It is a single clean mesh (Studio will make it translucent water with ribbons and arcs): no modelled ribbons or arcs.
- **Rig**: keep the stock Knife rig and the hand origin so it holds in the current knife poses. At export prep add `TS_Katana` (pivot at the kunai tip; the extension scales and slides the blade out from here) and `TS_Ring` (pivot at the ring centre, for the draw twirl), same orientation as the stock Root bone.
- **Palette**: blade TS Dark / TS Body, edges, guard, collar and ring TS Panel or TS Metal, grip TS Grip, the crack TS Neon, the water blade TS Water.
- **Checks**: review sheet with the katana both retracted (hidden) and extended, first-person angle, the ring pommel clear of the hand, nothing floating between the kunai tip and the water blade.

Pistols and the Sheriff are held two-handed in first person. Check the grip still fits the stock hand pose: keep the RightGrip origin and the grip envelope.

## Workflow and gates (per item)
1. **s01 working master:** open the stock base and save it as `art-source/weapons/Skins/TempestStrike/<Gun>/s01/<Gun>_TempestStrike_s01.blend`. Write scripts in `tools/blender/tempest_<gun>/` with the same staging as `tools/blender/tempest_vandal/`. Reuse the helpers in `tv_s_lib.py` (dup, surface_plate, loft, octo, fluted, prism_xz / prism_yz, boolean, new_obj), but copy and adapt them, don't edit the Vandal's. Point stock names at the right gun (`<Gun>_Rig`, `<Gun>_Receiver`...).
2. **One .blend per version** (s01, s02...). Never save over an earlier version: earlier Vandal saves overwrote s02–s06 and had to be restored from git.
3. **Review sheet every version:** hero, left, right, top, under, close-ups of every join, ADS view (adapt `20_render.py`, `30_sheet.py`, `46_ads.py`). Save to `vault/02 Art/Skins/TempestStrike/out/<Gun>_sNN_review.png`.
4. **Audit every version** with an adapted `49_audit.py`: 0 floating parts, 0 coplanar same-facing faces, 0 inverted closed meshes, joins checked. ADS check: only `*Sight*` parts on the aim line, a big clear window.
5. **Self-grade** with the rubric below. Keep going until 9+/10. Write the grade and the reasons in the ledger.
6. **Export copy:** adapt `53_export_prep.py` (apply modifiers on a copy, rename role materials `TS <Role>`, hide cutters, fix missing material indices) to `<Gun>/sNNx/`. Run the flat exporter (`tools/blender/export_skin_items_flat.py` with `ITEMS = [("TempestStrike", "<Gun>", "sNNx")]`), then `tools/blender/check_flat_export.py` (one-sided render on magenta: no holes, no black flipped faces). **Stop there:** no upload, no Studio.
7. **Moving parts:** keep the "moving parts later" pieces as separate objects with clear names. At export prep, add a `TS_Rig` armature with one bone per moving piece: head at the pivot, **same orientation as the stock Root bone**, and parent the pieces to their bone (see `tools/blender/tempest_vandal/70_moving_parts.py`). The flat exporter turns the bones into Studio joints, and their offsets are already in the Root part's axes (Root part = Blender axes). Pieces that already ride a stock bone (lever, pump, cylinder, hammer) stay on that bone.

## Grading rubric (score each, the item's grade is the lowest)
| Area | 9–10 looks like |
|---|---|
| Silhouette | Reads as that gun at a glance; clearly Tempest-Strike next to the Vandal; not a stock reskin |
| Crispness | All faces flat-shaded and sharp; chamfers 1–2 segments; no soft or round reads |
| Layering | Plates seated with thickness; flutes, ports, slots cut clean; wraps overlap |
| Connections | Nothing floating, flush or poking through; joins buried; both sides correct |
| ADS | Big clear crescent window; only Sight parts on the aim line; scope lens untouched (Marshal) |
| Palette | Roles as in the table; silver on navy; cyan only as thin lines |
| Budget | Within the tri budget, no silhouette loss |
| Contract | Every stock attachment and bone kept; held-pose fit unchanged |

## Bookkeeping
- Log every version, grade and owner note in a new **[Line Build Ledger](Line%20Build%20Ledger.md)** (create it; one section per item, contract line, tri counts, review sheet links).
- Add new notes to `vault/INDEX.md`. Commit small steps with exact paths (never `git add -A` or `git add vault`: the owner's third-party screenshots live in the vault). Commit messages end with the co-author line the session gives you.
- Blender MCP: the Tempest instance used port 9999 via `tools/blender/tempest_vandal/s.sh`. Check which instance and port the owner opens for this job, and update the port and pid in your own `s.sh`.
- When everything is 9+ and exported, report: per item, its grade, tri count, review sheet and export path. That is the hand-back to the Vandal session for the Studio port and VFX.
