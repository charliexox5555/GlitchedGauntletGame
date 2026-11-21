# Rare line rework handoff: Slipframe, Kilnlock, Stacklight

2026-11-21. Three skin lines were built in Blender in earlier overnight passes (Slipframe 2026-11-14, Kilnlock and Stacklight 2026-11-16) and never brought into the game. The owner reviewed them ([Slipframe](Slipframe/out/lineup_built.jpg) · [Kilnlock](Kilnlock/out/lineup_built.jpg) · [Stacklight](Stacklight/out/lineup_built.jpg), local sheets, git-ignored): **"done kind of poorly ... sloppy and don't follow the build rules"**. This handoff **rebuilds all three, one line at a time, to the build rules, with every check**, then installs them in the game as **Rare** lines.

## Paste this into the new chat

> Read `vault/02 Art/Skins/Rare Line Rework Handoff.md` and do it. Rebuild the Slipframe, then Kilnlock, then Stacklight skin lines (guns only) in Blender to our build rules, one gun at a time with every check and a self-grade of 9+, then install each finished line in the game as a Rare line. Follow the handoff's order, gates and bookkeeping. Start by loading the skills and reading the notes it lists, then tell me which Blender MCP instance and port you're using before you model anything.

## Owner decisions (2026-11-21)
- **All three are Rare** ("slight changes in the way they look, nothing crazy"): each gun keeps its stock silhouette and changes shape in parts, like Sealwork, Inkshift, Payload and Giltfold.
- **Slipframe has the most potential to become Epic** later ("we're gonna have to really improve on it"). Build it to Rare now, but to the highest finish of the three, and keep the pieces that could move or glow later as separate, named objects (see its brief). The Epic additions (animation, effects) are a later decision; don't build them now.
- **Set aside, don't build:** the melee items (Slipframe Dagger, Kilnlock Kiln Cleaver, Stacklight Patch Tool) and the charms (Foundry Stamp, Keycap Tester). Charms aren't a game system yet.
- **Rebuild, don't patch.** The old files and concept images are references for the idea only. Every gun starts again from its stock RemasterV2 model.
- Tier placement and launch plan: [Skin Lines at Launch](../../01%20Design/Skin%20Lines%20at%20Launch.md).

## Before you start (mandatory)
1. Load the `gauntlet-vault` skill, then `gauntlet-build-style`, `blender-director` and `hard-surface`, plus `lihfolk:roblox-blender-modeling` for the quality gate. Cite the notes you use in the ledger.
2. Read: [Skin Build Pitfalls](Skin%20Build%20Pitfalls.md) (every past mistake and the check that catches it), [Reskin Geometry Regression Checks](Reskin%20Geometry%20Regression%20Checks.md), [Skins README](README.md), `vault/02 Art/Style Bible.md`, and the [Tempest-Strike line handoff](TempestStrike/Line%20Blender%20Handoff.md) (the newest, best-run skin build; reuse its method, staging and scripts).
3. Read each line's original brief before its turn: [Slipframe concept](Slipframe/concept.md) and [Build Ledger](Slipframe/Build%20Ledger.md); [Exotic Bundle Concepts](Exotic%20Bundle%20Concepts.md) → Kilnlock and → Stacklight (per-gun detail tables), plus their concept images in `<Line>/out/*_concept_v*.png`.
4. Look at what was built before (what *not* to do): the lineup sheets above, and the old files in `art-source/weapons/Skins/<Line>/`. Old scripts: `tools/blender/model_slipframe_*.py`, `tools/blender/exotic_concepts/`. Don't build on them.
5. Blender MCP: ask the owner which instance and port to use (memory: two instances both default to 9876; a second needs its own port and the socket script). **Live MCP only, never background Blender** for these models, so the owner can watch and edit.

## The build rules (the owner checks these first)
- **Build on the stock model, never from scratch.** Open `art-source/weapons/RemasterV2/<Gun>/<Gun>_RemasterV2_v05.blend` (v05 exists for every gun here), save it as the working master, restyle on top: same rig, same bones, same contract points (Muzzle, AimPoint, grips, Eject, CharmPoint), same footprint and held-pose fit.
- **Rare = shape change, not a recolour.** Several main parts change shape (shroud or barrel, brake, sights, receiver plates, grip, mag, stock), but the gun still reads as itself at a glance. Not a "basic reskin" (that was the complaint about every first pass).
- **Faceted and crisp** (`gauntlet-build-style`): no round curves, spheres or smooth-shaded cylinders (round forms are 6-12 facet prisms; curves are runs of straight segments); flat 1-2 segment chamfers only, no soft bevels or weighted-normal rounding on hero faces; **no blunt cut-off ends** (chamfered, raked or carved).
- **Seated and connected:** plates sit in recesses with real thickness, cut-in details instead of stuck-on blocks (memory: the rounded prop set was rejected for "stuck on" pieces), nothing floating, nothing flush or coplanar (z-fight), grip, stock and barrel joins buried and seamless, both sides correct.
- **No script-assembled boxes.** Script helpers are fine for repeats and measurements, but hero shapes are modelled deliberately (memory: models built from bounding-box and prism helpers read as primitives and were rejected).
- **ADS:** a big clear sight window; every sight part's object name contains `Sight` (the viewmodel fades non-sight parts on the aim line); scope lenses untouched.
- **Budget:** about 1.5-2× the stock gun's tris at most; reduce with dissolve-limited flats and by removing hidden bevels, never by losing silhouette.

## The three lines

### 1. Slipframe (first; aim highest, Epic potential)
**Guns:** Guardian (hero, build first), Vandal, Spectre, Operator, Classic.
**Look:** smooth blue-grey "otherworldly industrial" metal: an uninterrupted satin-titanium shell over a darker inner frame; a broad anodised-blue face meets the grey frame at **one shallow recessed seam** per gun; the signature is that seam (later it carries a silver-blue glint). Clean, sleek, few large planes, crisp edges. The old build was mostly a two-tone recolour with thin bars and flat slabs: give each gun a real shell with designed plate breaks, a reshaped fore-end or shroud, a reshaped stock, and a sculpted brake.
**Epic headroom (don't animate now):** keep as separate, named objects the parts that could move or light up later: the shell's side panels (could slide), the seam inlay strip (could glow), and the sight hood.
**Materials (role names):** `SF Shell` (satin titanium, Metal), `SF Frame` (dark gunmetal), `SF Face` (anodised blue), `SF Seam` (thin bright seam inlay, small amounts), `SF Grip` (dark polymer). Pick exact hexes from the concept and record them in the ledger.

### 2. Kilnlock
**Guns:** Phantom (hero), Odin, Judge, Bulldog, Sheriff, Shorty.
**Look:** a portable foundry: blackened iron `#282525`, matte firebrick ceramic `#D5C1A4`, oxidised copper `#9A5137`, and a small persimmon heat core `#FF793F`. Heavy rectangular iron plates, broad ceramic faces, **offset rectangular vents cut into the plates** (not painted), copper banding, a fixed shell around a visible **cage** over the heat core. Per-gun detail: Exotic Bundle Concepts → Kilnlock table. The old build was the stock gun with small cream slabs and copper strips stuck on: rebuild so the iron shell, ceramic faces and cage *are* the gun's form.
**Materials:** `KL Iron`, `KL Ceramic`, `KL Copper` (Metal), `KL Core` (heat core, Neon, small), `KL Dark`.

### 3. Stacklight
**Guns:** Phantom (hero), Ares, Operator, Classic, Outlaw, Stinger.
**Look:** a modular electronics test bench: off-white moulded polymer `#E4E1D7`, graphite `#20232E`, smoked blue acrylic `#344656`, cool mint `#53E4D2`. One **translucent-looking window** per gun (smoked acrylic, modelled as an inset pane in a frame) with **three squared indicator cells** behind it and a short clear shuttle; moulded polymer housings with crisp parting lines and screw bosses; graphite frame. Per-gun detail: Exotic Bundle Concepts → Stacklight table. The old build was a grey stock gun with white strips and tiny mint dots: rebuild with real moulded housings and the window as the centrepiece.
**Materials:** `ST Polymer`, `ST Graphite`, `ST Acrylic`, `ST Mint` (Neon, cells and thin lines only), `ST Metal`.

## Workflow and gates (per gun)
1. **Working master:** `art-source/weapons/Skins/<Line>/<Gun>/r01/<Gun>_<Line>_r01.blend` (r = rework, so the old v-files stay untouched). Scripts in `tools/blender/rework_<line>/` (copy and adapt the Tempest-Strike staging in `tools/blender/tempest_*`; don't edit those).
2. **One .blend per version** (r01, r02...). Never save over an earlier version.
3. **Review sheet every version:** hero, left, right, top, under, close-ups of every join, first-person and ADS view, beside the stock gun. Save to `vault/02 Art/Skins/<Line>/out/<Gun>_rNN_review.png`.
4. **Audit every version:** 0 floating parts, 0 coplanar same-facing faces, 0 inverted closed meshes, joins checked, sight parts named `*Sight*`, ADS window clear (adapt the Tempest-Strike `49_audit.py` and `46_ads.py`; the Skin Build Pitfalls check list).
5. **Self-grade** with the rubric below; keep going until **9+/10**. Then show the owner the review sheet for the **hero gun of each line before building the rest of that line** (the hero sets the line's language; the owner may redirect).
6. **Export copy:** `<Gun>/rNNx/` (apply modifiers on a copy, role materials named as above, cutters hidden), the flat exporter (`tools/blender/export_skin_items_flat.py` with `ITEMS = [("<Line>", "<Gun>", "rNNx")]`), then `tools/blender/check_flat_export.py` (one-sided render: no holes, no flipped faces). The exporter maps materials: emission above 0.5 → Neon, metallic 0.55+ → Metal, else SmoothPlastic; a material's `mf_hex` property sets its exact colour.

## Grading rubric (score each; the gun's grade is the lowest)
| Area | 9-10 looks like |
|---|---|
| Silhouette | reads as that gun at a glance; clearly this line next to its hero; not a recolour |
| Crispness | all faces flat-shaded and sharp; 1-2 segment chamfers; no round or soft reads |
| Layering | plates seated with thickness; vents, windows and seams cut clean |
| Connections | nothing floating, flush or poking through; joins buried; both sides right |
| ADS | big clear window; only Sight parts on the aim line; lenses untouched |
| Palette | the line's roles; accent colours small |
| Budget | within budget, no silhouette loss |
| Contract | every stock attachment and bone kept; held-pose fit unchanged |

## Into the game (after a whole line is 9+ and the owner has seen it)
1. Upload and install with the flat pipeline: `tools/studio/InstallFlatSkin.luau` (one MeshPart per material, flat colour; see [Moderate Skin Deployment](Moderate%20Skin%20Deployment.md) for how lines were installed in both places and verified). Install in **both** the Lobby place (71551303511506) and the match place (133387545285290). Check first which place another session is working in, and don't play-test there (memory "test in the free place").
2. Register the line: `src/shared/Config/SkinPreview.luau` (LINES), `src/shared/Locker.luau` (COLORS, EMBLEMS: an emblem image per line), and `src/shared/Config/Skins.luau` LINES with `tier = "Rare", kind = "shape"`. It then joins the Apex and Elite case pools automatically (`Shared/SkinCases`).
3. Pictures: render each gun's square portrait with `tools/studio/RenderPortraits.luau` → `tools/render/icon_sheet.py --cols 5 --rows 3 --centered` → upload → add to `src/shared/ItemPortraits.luau` (see [Skin Tiers and Cases](../../01%20Design/Skin%20Tiers%20and%20Cases.md) → Portraits). No ViewportFrames for UI art.
4. Verify in a play test: Locker shows and equips it, match preview routes it, the first-person hold and ADS are right, CONTENTS shows the new line with its odds and pictures, a case can roll it. **Remind the owner to save both places.**

## Bookkeeping
- One **Rework Ledger** per line (`vault/02 Art/Skins/<Line>/Rework Ledger.md`): per gun, versions, tri counts, audit results, grade and reasons, owner notes, review sheet links. Add new notes to `vault/INDEX.md`.
- Update [Skin Lines at Launch](../../01%20Design/Skin%20Lines%20at%20Launch.md) and `vault/00 Home.md` → Status when a line lands in the game.
- Commit small steps with exact paths (never `git add -A` or `git add vault`: the owner's third-party screenshots live in the vault). The `out/` folders are git-ignored; review sheets stay local, links in the ledger.
- **Report per line:** each gun's grade, tri count, review sheet and export path, then the install results.
