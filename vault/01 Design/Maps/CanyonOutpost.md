# CanyonOutpost (new map)

**Status (2026-11-21): built v1, build checks at 0 / 0 / 0, in rotation** (shown as **CANYON**, regular, 1v1-2v2). Match place saved (v1018). Map 4 of the [lineup round 2](Map%20Lineup%202026-11-21.md) run and the **last new map for the release** (Castle on hold). A sun-baked mining outpost in a red canyon, built to the RIVALS look.

## RIVALS build study (2026-11-21, read-only)
Sources: `ServerStorage.Maps.Westown` in the RIVALS file (measured by script, never played or saved) and its copy `ServerStorage.MapsRivals.Westown` in the match place (cloned into Workspace for three captures, removed). The Museum study is in [Foundry4](Foundry4.md#rivals-build-study-2026-11-21-read-only) (big Part masses with tiling variants, stacked trims, one colour family, meshes wearing the Parts' variants).

| Question | Westown | What we take |
|---|---|---|
| Mesh vs Part | 1,140 Parts, 490 MeshParts; the canyon is **Rock + Sand-cap mesh pairs** (3 rock shapes, Concrete-01a in reds a75a3c / 9a5238 / 793e2a, the sand caps Sand_01a b4774e); the floor is a Slate02c mesh | Near cliffs as Part strata (bounds we control), the far mesas as their rock + cap meshes |
| Timber | Wood01a ×766, WoodSiding_01a ×186, WoodPlank_01b ×154, Wood03a; browns 553724 / 8c6344 / ab795c / 4d2d1b | The same four variants and that brown family for every timber |
| Hero pieces | a water tower (3 meshes, 14 x 42 x 15), a tunnel portal (timber frame + Parts, a **black Neon** box as the dark inside), a train with carts on a sleeper track | Our own water tower, mine portal (black Neon back, like theirs), ore carts; track as Parts |
| Props | crates (Wood03a), haybales, barrels, trough, hitching posts, wheelbarrow, barricades | Crates, trough, hitching post taken; barrels **not** (the "Sensei" barrel has printed text): our own barrel instead |
| Colour | warm browns, red rock, sand, a few strong accents | Hot palette: red strata, sand, timber, a barn-red trading post with cream trims, an ochre assay hut, rust carts |

**RIVALS meshes used** (owner 2026-11-21: map meshes allowed, no logos, no scripts), in `ServerStorage.MapKit.CanyonOutpostRivals`, pivoted at the bottom centre:

| Ours | RIVALS source (`MapsRivals.Westown.Extra`) | Use |
|---|---|---|
| R_Mesa1 / R_Mesa2 / R_Mesa3 | `Terrain` Rock + nearest Sand cap (meshes 113558344827527 + 120823811067450, 80905809677046 + 91860253627492, 72430809645957 + 123602602762141) | ten mesas round the canyon, scaled 0.45-0.9 |
| R_Crate4 / R_Crate6 | `Crates/OldCrate02`, `OldCrate03` | crates on the docks and at the spawn end |
| R_Trough, R_HitchPost | `Water Trough/Trough`, `Hitching Post` | in front of the trading post |
| (unused) R_Wheelbarrow, R_Barricade, R_WoodBarrel | | not placed (no job / printed text) |

## Layout v1 (`python tools/maps/canyon_layout.py`)
![layout](../../02%20Art/References/maps/canyon/canyon-layout.png)

140 × 192 box canyon, **mirror symmetry across the midline** (z → -z, like Foundry4), team A at +Z.
- **The midline:** the ore track runs at ground level from the **mine portal** in the west cliff to the **tipple** in the east; three ore carts on it are low cover (3.7). The **water tower** (the landmark, roof +35.6) straddles the track in the middle; the **pump houses** that fill it are full cover each side.
- **The tipple** (east): a timber deck at +10 over the track's end, the ore bin with its roof, a hoist, the chute and the buffer stop below. Walkways (+10) join it to each team's **loading dock** (+10, stair up from the middle, crates and barrels on deck, a jib crane over the freight wagon).
- **Each half:** the **trading post** (false front facing the middle, porch +1, trough and hitching rail), the ochre **assay hut**, the stone **powder shed** by the mine, the **ore bin**, pit props, two timber stacks, the **rock shelf** (+7, timber stair) under the west cliff, the **stores shed** (spawn baffle, team-colour doors), barrels and crates at the spawn end.

| Check | v1 |
|---|---|
| Spawn gap / longest line | 174 / 196 (1.12 of the gap, 0 rays over target) |
| Pinches | 0 |
| Spawn sees spawn / enemy half sees a spawn | never / 6.0% |
| First sight | 3.7 s |
| Sprint to the centre / enemy spawn | 3.6 s / 9.1 s |
| Heights | ground 0, porch +1, rock shelves +7, docks + walkways + tipple deck +10; roofs out of reach (roof guards) |

## Kit (`tools/blender/maps_canyon/`, asset 133899335352399, `ServerStorage.MapKit.CanyonOutpost`)
Built in its own file `art-source/maps/CanyonOutpost/Kit_CanyonOutpost.blend`, 5 pieces, ~29k tris: **CNWaterTower** (battered legs on footings, girts, offset X braces, cap beams, joists, octagonal deck, 16-stave tank with hoops, red roof, swing spout over the track, two risers to the pump houses), **CNMinePortal** (battered posts, cut-end header + stepped header, knee braces, plank lagging, two inner sets, black back, a lantern), **CNOreCart** (flared hopper with ribs and rim, ore load, frame, buffer beams, wheels), **CNWagon** (spoked wheels with iron tyres, plank bed, stakes, tarp with ropes, tongue, brake), **CNBarrel**.

**Owner feedback mid-build (2026-11-21):** "the sides of the carts don't connect well ... they're using the bevel thing ... the wagon sides, the wheels ... the wood and wood-dark connection ... it's gotta look professional." Cause: the bevel ran on every overlapping shell, so each join showed a chamfer groove. Fix: **every piece is unioned into one solid before the bevel** (Boolean exact, self-intersection), the wagon sides became one board face with proud seam rails, wheels went to 20 facets. Close-ups of every join type before export ([cart](../../02%20Art/References/maps/canyon/close-cart.png), [wagon side](../../02%20Art/References/maps/canyon/close-wagon-side.png), [wheel](../../02%20Art/References/maps/canyon/close-wagon-wheel.png), [tower braces](../../02%20Art/References/maps/canyon/close-tower-braces.png)). This is now the project skill **`gauntlet-model-joins`** (`.claude/skills/gauntlet-model-joins/SKILL.md`), linked from `gauntlet-build-style`.

## Build v1 (2026-11-21)
`tools/studio/maps/CanyonOutpost/Build.luau` at **(6000, 200, 54000)** (`Workspace.CanyonOutpost`), run in chunks (`require(clone)(upTo)`), authored data **425** (map: KillDepth 20, layout version) / **426** (lighting: afternoon sun, ClockTime 14.2, warm ambient, a warm haze). About 1,810 parts. Builder and audits ran as temporary modules synced from `src/server/CODev/` (removed, not committed).

**Materials (RIVALS variants):** canyon floor Sand_01b, paths Sand_01a, track ballast Slate02c, strata Concrete-01a in four reds / creams with Sand_01a caps, timber Wood01a / Wood03a, decks WoodPlank_01b, walls WoodSiding_01a, plinths and the powder shed StoneBlock_01a, roofs Corrugated_01a, iron Metal 2022. Trims are flat cream; team colour only on the stores-shed doors (A red-orange, B blue).

**One design per kind (Parts):** the building (stone plinth, corner boards, eave and gable bands, attic, tin roof with a ridge cap), door (jambs, header, plank panel, iron strap hinges), window (frame, sill, set-back glass, cross mullion), railing (posts ≤4 apart, top + mid rail, 3.25 high, jumpable), timber deck (planks, fascia, joists, caps, posts on pads, knee braces), stair (stringers, open treads, rails, a wedge ramp collider), timber stack (beams on end bearers, staggered ends, stakes).

**The strata cliffs** (owner: "holes between the layers"): the first cliff build jittered each band's foot on its own, so some bands floated up to 0.6 over the band below. Now each band seats 0.15 into the one below, heights and depths sit on a 0.2 grid with a 0.1 offset on alternate segments (neighbours never share a plane), the bottom band starts under the ground. [Close capture](../../02%20Art/References/maps/canyon/review-cliff-bands.jpg).

| Overview | Mine portal | Water tower |
|---|---|---|
| ![overview](../../02%20Art/References/maps/canyon/build-overview.jpg) | ![portal](../../02%20Art/References/maps/canyon/chunk1-portal.jpg) | ![tower](../../02%20Art/References/maps/canyon/chunk1-tower.jpg) |

## Chunk review
| Chunk | Captures | Found and fixed |
|---|---|---|
| 1. Midline, canyon frame | [portal](../../02%20Art/References/maps/canyon/chunk1-portal.jpg), [tower](../../02%20Art/References/maps/canyon/chunk1-tower.jpg) | Pale plain lagging round the portal: plank variant in a darker wood. Sand too close to the rock's orange: a beiger sand. |
| 2. East: tipple, docks, wagon | [cart](../../02%20Art/References/maps/canyon/chunk2-cart.jpg), [dock and stair](../../02%20Art/References/maps/canyon/chunk2-dock-stair.jpg) | Stair stringers stood over the treads: lowered and slimmer. RIVALS barrel carries printed text: our CNBarrel. Kit joins (owner): union before bevel. |
| 3. Halves' middle and west | [trading post](../../02%20Art/References/maps/canyon/chunk3-trading-post.jpg), [shelf stair](../../02%20Art/References/maps/canyon/chunk3-shelf-stair.jpg) | Upper windows cut by the porch roof: porch roof lowered, smaller upper windows. Checkerboard timber colours: one timber colour. Cut rock steps read as placeholder slabs: the outpost's timber stair. |
| 4. Spawn end | [stores shed](../../02%20Art/References/maps/canyon/chunk4-stores-shed.jpg) | Plain team-colour doors: iron strap hinges on every door. |
| Final review | [cliff bands](../../02%20Art/References/maps/canyon/review-cliff-bands.jpg), [under the tipple](../../02%20Art/References/maps/canyon/review-tipple-under.jpg), [ore bin](../../02%20Art/References/maps/canyon/review-ore-bin.jpg) | Nothing loose left in the walk-round. |

## Checks (owner 2026-11-21: build checks only)
| Check | Result |
|---|---|
| Z-fight (`Audit.luau`) | **0** (first run 252: strata bands sharing end planes, railing corners doubling posts and top rails, roof and attic halves sharing gable planes, window frame tops, door / false-front feet at 0.5, flush-stacked crates; all fixed at the source) |
| Floating (`FloatAudit.luau`) | **0** (first run 12: timber-stack beams on crossing bearers had no vertex contact; bearers moved under the beam ends) |
| Coincident slopes (`SlopeAudit.luau`) | **0** (109 rotated parts) |
| Note | 9-11 meshes cannot be read as EditableMesh (RIVALS props, some kit parts), tested as boxes |

## ChatGPT concept prompts (for the owner later)
1. *Overview:* "Stylised Roblox shooter map in the style of RIVALS, three-quarter aerial view, afternoon sun. A small mining outpost in a red box canyon with layered red, orange and cream rock strata and mesas beyond. A wooden water tower with a red conical roof stands over a mine-cart track that runs from a timber mine entrance in the cliff to a wooden ore tipple with a hoist. Raised timber loading docks with stairs and railings, a barn-red trading post with a tall false front and a porch, small timber sheds, ore carts, a freight wagon with a canvas tarp, stacked timber and barrels. Chunky clean shapes, warm sand ground, flat colours."
2. *Player view:* "First-person view on a canyon mining outpost: rail track with rust-red ore carts leading under a wooden water tower, a barn-red trading post with cream trims on the left, timber decks and stairs on the right, red rock strata cliffs behind. Stylised Roblox RIVALS look, bright afternoon, clean and readable."

## Grade (self, honest): 7.5/10
Good: a clear landmark and story (mine → track → water tower → tipple), the hot palette reads at a glance, RIVALS variants on every surface, Westown's mesas give a world beyond, the kit joins are solid after the union pass, real height levels (+1 porch, +7 shelf, +10 docks / walkways / tipple), audits 0/0/0.
What holds it back:
- **The buildings are closed boxes.** Doors and windows are dressing; no interiors, and the Part buildings are plainer up close than RIVALS' trims.
- **The near cliffs are stacked boxes.** They read as strata and frame the bounds cleanly, but they are blockier than Westown's sculpted rock meshes.
- **Height is lopsided.** The +10 network is all on the east; the west only has the +7 shelf.
- **The ground is one flat sand plane** with a few paths; no scrub or cacti (low-poly and realistic greenery are both ruled out, and nothing else fills that role yet).
- Not playtested (owner: build checks only).

## Waiting on the owner
- Play it: the track lane under the tower, the docks and tipple walkways (+10), the shelf stair, the flanks under the decks.
- Say whether the unioned kit (carts, wagon, tower, portal, barrel) now connects the way you want.
