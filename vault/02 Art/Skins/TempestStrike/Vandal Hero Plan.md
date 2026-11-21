# Tempest-Strike Vandal: hero model plan (restart)

2026-11-21. The owner restarted the Tempest-Strike bundle from zero. The 2026-11-18 attempt (`art-source/weapons/Skins/TempestStrike/Vandal/v01`–`v20`) was rejected for its shapes and design and is **not reused**. Only the stock Vandal's measured contract below is kept. Sources: the owner's [concept sheet](refs/style/Tempest-Strike%20Vandal%20Reference.png), the [concept brief](concept.md) (fore-end, sight, palette still valid), the owner's Valorant Kuronami clip (feel only: crisp silver blades on dark enamel, sharp, sleek). Our own design, built from the owner's sheet, not a copy of the Valorant skin.

**Owner's bar for this build:** high-quality Blender hard-surface work, sharp, sleek and satisfying. "Not the low-poly shapes."

## Concept check (does it work for our game?)
| Point | Verdict | How we resolve it |
|---|---|---|
| Silhouette (long octagonal fluted shroud, ported brake, armoured receiver, skeletal stock, wrapped grip and curved mag) | Works. Reads as a fast, long rifle in profile and from the first-person view | Keep the stock Vandal footprint (3.9 studs, muzzle at x 2.647); the "longer" feel comes from a slim taper, not extra length |
| Faceted rule (no round curves) vs "high quality, not low-poly" | Compatible | Crisp hard surface: flat 1–2 segment chamfers, octagonal shroud and barrel, magazine curve as 5–6 straight segments. Quality comes from layering, plate seats, flutes, ports, vents and wraps, not from smoothing |
| Open crescent rear sight | Works, and is our ADS family (big thin window, about 1/5 screen) | Crescent centred on the stock AimPoint, two small pips outside the aim centre, front post on the shroud; all named `*Sight*` |
| Water rings, lightning, water ribbons | Not model work | VFX pass in Studio later. The model carries anchors only (stock ring mount, vent slots) |
| Leather wraps (grip and mag) | Works | Modelled overlapping diagonal bands (tsuka-maki rhythm), not a texture |
| Charm (shuriken on plate and ring) | Later | Mount point kept at CharmPoint |
| Triangle budget | Over the 5K primary rule | Working target 8–10K for this hero (stock is 5,171); needs the owner's OK |

## Contract kept from the stock Vandal (RemasterV2 v05, Blender units = studs, +X = muzzle, origin = grip)
Muzzle (2.647, 0, 0.285) · RightGrip origin · LeftGrip (1.32, 0, 0.17) · AimPoint (0.078, 0, 0.56) · Eject (0.484, -0.072, 0.316) · CharmPoint (0.93, 0.096, 0.17) · stock rear x -1.252 · mag envelope x 0.46–1.0, bottom z -0.40 · grip envelope x -0.18–0.41, bottom z -0.31 · half-width about 0.10.

## Parts and design intent
1. **Muzzle brake**: angular, three side ports per side, top port, a pointed (cut) crown. Silver ring at the joint.
2. **Barrel shroud**: octagonal, tapered towards the muzzle, matte black with three flutes per face side and a brushed-silver top plate that sweeps back. Clean side vent slots near the receiver.
3. **Receiver**: black chassis with a raised spine; long silver armour plates seated in recesses, tapered blade ends, visible thickness; ejection port and charging handle restyled.
4. **Rear sight**: open crescent (faceted arc), two pips. **Front sight**: post on the shroud.
5. **Grip**: raked, leather wrap bands over a black core, silver cap. **Trigger guard**: angular.
6. **Magazine**: curved in straight segments, three wrapped bands with recessed conduit slots between, silver baseplate.
7. **Stock**: open triangular frame (top bar, diagonal strut, butt plate) with silver edge plates; ring mount at the rear junction.

## Method (skills: blender-director → hard-surface; gauntlet-build-style; Skin Build Pitfalls)
- Live Blender MCP instance on port 9999 (owner opened it), scripts in `tools/blender/tempest_vandal/` (send with `s.sh`).
- Parts are modelled from designed side profiles plus cross-section shaping (top chamfers, tapers), booleans for flutes, vents, ports and plate seats, then flat chamfer bevel + Weighted Normal. Modifiers stay live in the master, applied on export copies.
- Collections: `COL_Model` (parts by assembly), `COL_Cutters`, `REF_Stock` (stock overlay, never exported).
- Saves: `art-source/weapons/Skins/TempestStrike/Vandal/r01/Vandal_TempestStrike_r01.blend` (r = restart).

## Phases and gates
1. Plan and concept check (this note). ✅
2. Blockout: silhouette in profile, stock overlay, both sides. Gate: reads like the sheet, contract points hold.
3. Detail pass: plates and seats, flutes, ports, vents, wraps, sight. Gate: close-ups of every joint, nothing floating, no flush faces.
4. Materials (Storm Shadow roles) and review sheet: hero, both sides, top, bottom, held, ADS. Self-grade 9+/10.
5. Owner look review. Then rig/actions, export, Studio install, VFX, chromas, then the rest of the bundle.

## Log
- 2026-11-21: plan written; stock contract measured from `Vandal_RemasterV2_v05.blend`.
- 2026-11-21, **r01 (design pass, for the owner's look review).** [Master](../../../../art-source/weapons/Skins/TempestStrike/Vandal/r01/Vandal_TempestStrike_r01.blend) · [review sheet](out/Vandal_r01_review.png) (hero, rear 3/4, both sides, first-person hip, stock footprint) · build scripts `tools/blender/tempest_vandal/` (`10_build.py` model, `20_render.py` views, `30_sheet.py` save + sheet). 61 parts, **9,950 triangles** (live modifiers). Same footprint as the stock Vandal (muzzle, grip, mag, stock, AimPoint unchanged).
  - **Built:** lofted receiver with a stepped lower band (shadow line + steel trim), brushed-silver cowl per side (stepped lower edge clearing the ejection port and charging slot, pointed nose into the collar, storm-blue inlay groove), black spine with a silver inlay; octagonal shroud whose flutes are part of the section (they taper and run out cleanly), raked side vents to a dark liner, silver side blades and a top blade; steel collar, barrel neck, stepped brake with three through-ports, two top ports and a cut crown; swept front post; open crescent rear sight on the AimPoint with two cyan pips; raked grip with slanted leather bands and a silver cap; magazine curved in 5 straight segments with three leather sleeves, two cyan conduits, silver baseplate; triangular stock (neck, top bar, strut, butt with pad) with silver edge plates and a ring hub; selector, pins at real joints, recessed trigger-housing panel.
  - **Self-grade 7/10** (honest: design reads, finish not there yet). Open: magazine sleeves still read blocky (need folded wrap edges and crossing tsuka-maki bindings); stock bars thin and plain next to the receiver; rear of the receiver above the stock neck is one dark mass; front sight post plain; no hydro-core round, charm, chromas, rig or export yet; ADS view not checked at the game camera.
  - **Next (after the owner's look review):** finish pass on the items above, materials review, ADS check, then rig + export per the plan.
- 2026-11-21, **r02 (owner feedback on r01: "not clean, everything looks curved, the base Vandal has sharper corners; layer it over the reference").** [Master](../../../../art-source/weapons/Skins/TempestStrike/Vandal/r02/Vandal_TempestStrike_r02.blend) · [review sheet](out/Vandal_r02_review.png) · [concept vs r02](out/Vandal_r02_vs_concept.png) · overlay tool `25_overlay.py`, comparison `26_compare.py`. 9,540 tris.
  - **Why r01 looked curved:** smooth shading + weighted / hardened normals smeared light across the faces, and two-segment crown bevels on the grip, stock and receiver read as rounded. Not a modelling-method problem: sculpting would make it softer, so it stays for leather folds only.
  - **Crisp finish (now the rule for this gun):** flat shading on every face, one flat chamfer per hard edge at most 0.0025 studs (a thin edge highlight), sharp mitres, no weighted normals, single big facets instead of two-step crowns.
  - **From the overlay on the owner's sheet:** handguard rebuilt as one long wedge with the receiver (almost as tall at the back, bottom rising forward); shorter handguard, exposed barrel, long boxy brake with two big windows and inner baffles; brushed-silver band on the lower handguard side carrying the cowl's line; magazine curved harder; stock top bar now continues the receiver top line; lighter charcoal body, matte-brushed silver so it reads on every face.
  - **Self-grade 7.5/10.** Still open: magazine and grip wraps read as sleeves (need crossing tsuka-maki bands), no raised black top rail block like the sheet, trigger guard should be a faceted loop, stock bars plain, ADS not checked at the game camera.
