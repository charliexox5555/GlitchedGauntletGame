# Map Quality Standard

The bar every map rebuild must clear. Every map lane follows it: Claude sessions and the Codex app. Written 2026-11-06 from the user's reviews ([Evening](../../05%20Production/Playtests/2026-11-05%20Evening%20Review.md), [Maps v3](../../05%20Production/Playtests/2026-11-05%20Maps%20v3%20Review.md), [Maps v4](../../05%20Production/Playtests/2026-11-05%20Maps%20v4%20Review.md)) and the lessons from [Rooftops2](Rooftops2.md) and [Dockyard2](Dockyard2.md). Measured project numbers win over general LihFolk advice. Where the two disagree, this note says which one we use.

**Mandatory for every lane and every agent brief:** load `.claude/skills/gauntlet-vault/SKILL.md`, read [00 Home](../../00%20Home.md), this note and the map's own note, and use the LihFolk notes linked below (`lihfolk-worldbuilding`, `roblox-blender-modeling` skills). Plans and results go in the map note.

## 1. Purpose and bar
- **The bar:** a front-page Roblox shooter map that "looks built by a human, like other games' maps, not by AI" (user, v4 review).
- **Detail like Valorant, clarity like RIVALS.** Detail means worn materials, trims, panel lines, real silhouettes, height levels and a clear identity. Clarity means clean sightlines and a bold colour per zone.
- **Surfaces:** our own textures and trim sheets, made from the approved concepts.
- **Concepts are quality references, not 1:1 blueprints.** Take their quality, silhouettes, materials, height and identity from them. Keep our layout and our measured numbers.
- **Done means** 0 floating groups, 0 z-fighting pairs, a blind median of at least 8.5, and the user's approval.

What the standard must make impossible (the user's complaints):

| Complaint | Where it's fixed |
|---|---|
| "Smooth plastic circles and blocks", "too simple shapes", "looks built by AI" | §3 Modelling |
| Blocky part-built text, blank signs | §3 Text and signage |
| Floating signs, windsock, parts next to the tank | §3 Support, FloatAudit |
| Not to scale with the player; arrows not aligned | §3 Scale, §3 Text and signage |
| Inconsistent colours; pieces at different levels of finish | §3 Palette, §2 step 3, one kit per map |
| Maps too dark | §3 Lighting |
| No levels, no character | §3 Landmarks and levels, §4 |

## 2. The pipeline (in order; no step skipped)
| # | Step | Output | Done when |
|---|---|---|---|
| 1 | **Reference board and Codex concepts** | Third-party shots (RIVALS, Valorant, Overwatch, CS2, Krunker, real photos) in `vault/02 Art/References/maps/<map>/third-party/`, **never committed**. The identity brief: one sentence, 2–3 story groups and a "not this" list. Codex concepts in `art-source/maps/<Map>2/concepts/` (`01-overview.png` …): a silhouette round, then the overview, then hero views (each fed the overview), then the kit sheet, then the material and trim sheet. | The user approves the board. No modelling before that. |
| 2 | **Layout kept from the map note** | `tools/maps/<map>_layout.py` re-run: gaps, sightlines, spawn safety, cover spread, route times, perch share. | Game Plan §5 holds: 180° symmetry, three lanes, a middle sightline of about 70, two exits per room, spawns out of sight. **After this, the collision boxes don't move.** |
| 3 | **Palette table** | One table in the map note (slots: walls, stone and trim, floors, roofs, steel, machines, accents, glow, sign-art tint), with the same roles in `tools/maps/<map>2_style.py`. | Every colour on the map comes from the table. |
| 4 | **Kit modelled in Blender** | `tools/blender/build_map_kit_<map>2.py` → `art-source/maps/<Map>2/Kit_<Map>2.blend`, with one `Map_<Piece>` collection per piece. A contact sheet with a 5-stud R15 proxy beside each piece. | The coplanar audit (`coplanar.json`) is 0. Every piece passes §3 Modelling and its triangle budget. |
| 5 | **Textures and trim sheets** | Rows cut from the approved trim sheet, made tileable: **one 1024 trim sheet plus at most 6 MaterialVariants at 512** (colour plus normal, no roughness), near-white with `TintMask` so `Color` tints them. Wear is baked in, not added as decals. | It's checked in Studio, not only in Blender. |
| 6 | **Build** | `tools/studio/maps/<Map>2/` with `Greybox.luau` (the collision), `Art.luau` (`put()` / `hide()`), `Lighting.luau` and `Life.luau`. Offline check: `python tools/studio/maps/zfight_check.py <Map>2 <Group>`. Export, upload and `kit_bundle.py` as in [Maps](00%20Maps.md) → Pipeline. | Parts are the collision. The kit is the look. |
| 7 | **Audits** | Z-fighting: `Audit.luau`. Floating: `FloatAudit.luau` (below). Budget counts. The R15 scale check. | **0 pairs, 0 floating groups**, within budget. These are hard gates: no scoring before them. |
| 8 | **Fixed evidence cameras** | The map's entry in [evidence_cameras.json](../../../tools/maps/evidence_cameras.json) (eye height = floor + 5): an overview, each spawn, the landmark from each side, each lane, the Pit or middle. A 5-stud R15 dummy in at least two frames. Lighting via `loadstring(PreviewLighting)("<Map>2", "apply")`, then `"restore"`. Shots go to `vault/02 Art/References/maps/<map>2/v<N>-r<round>-<name>.jpg`, plus a side-by-side with the concepts. | The same angles every round, so rounds compare. |
| 9 | **Blind `lihfolk:quality-score`** | World rubric, **3 fresh blind reviewers**, the median per criterion. Reviewers get the evidence and the rubric, never the maker's notes. | **Median ≥ 8.5.** |
| 10 | **The user's approval** | The approval summary (§6). | The user says yes. Only then does the map go into `Config/Match` MAPS. |

**Running FloatAudit** ([FloatAudit.luau](../../../tools/studio/maps/FloatAudit.luau)), in the match place, edit mode, on every install, next to [Audit.luau](../../../tools/studio/maps/Audit.luau):
1. Take `.claude-locks/match-studio.lock`.
2. Pass the file's source to the Studio MCP `execute_luau` (or the Command Bar) and call `loadstring(src)("<Map>2")`. The map id is the only argument.
3. It returns `<Map>: N visible parts, M floating groups`, then up to 40 groups, each with its pieces, map-local position, size and the gap to whatever is below.
4. If `python tools/studio/receive_server.py` is running and Studio can reach localhost, the full list is also saved to `art-source/maps/<Map>2/float_audit.json`. MCP code often can't reach localhost, so paste the summary into the map note.

How it works: every visible part is a node. Parts that touch or overlap are joined, tested on real triangles for MeshParts (EPS 0.06). Parts within 1.5 studs of the map's lowest visible point are the ground. Any group that can't reach the ground floats.
- **Skipped:** the `Spawns`, `Barriers` and `Ambience` folders; the tags `LifeGull`, `LifePigeon` and `LifeDrift`; anything with the attribute `AllowFloat = true`; names containing "Template".
- **`AllowFloat` is for things that really fly.** Using it to hide a floating sign is a fail.

## 3. Hard rules (checklist; every box ticked before scoring)
**Modelling** ([Hard-Surface Modeling](../../LihFolk/14%203D%20Modeling/Hard-Surface%20Modeling.md), [Bevels Chamfers and Edge Highlights](../../LihFolk/55%20Modelling%20Nuance%20and%20Readability/Bevels%20Chamfers%20and%20Edge%20Highlights%20Without%20Textures.md), [Shape Language and Silhouette Testing](../../LihFolk/55%20Modelling%20Nuance%20and%20Readability/Shape%20Language%20and%20Silhouette%20Testing.md))
- [ ] **No visible object is a stack of Roblox primitives** (Part blocks, cylinders, balls). Visible objects are Blender meshes. Parts are only invisible collision and flush paint strips. If a piece can't be modelled tonight, cut it.
- [ ] Bevels follow the material, at 1–6% of the form: steel 0.12–0.25 studs, stone and concrete 0.3–0.45. Use 1–2 segments (more only on silhouette curves). The tertiary bevel is at least d/215 at the viewing distance d.
- [ ] Shape hierarchy of about 65 / 25 / 10% (primary / secondary / tertiary), with one focal feature per piece. The piece reads from its black silhouette alone.
- [ ] Panel lines are 0.04–0.1 insets, or in the trim sheet's normal map. Undersides of catwalks, decks and jetties get beams and stringers (we're first person).
- [ ] Nothing is thinner than 0.2 studs. Railing posts are at least 0.4. Small props are 1.5–2.5× real size.
- [ ] Repeats vary by 20–40%. Stacked items tilt 2–6°. Walkable tops stay level.
- [ ] Every piece in one map is made to the same finish: the same bevel rules, the same trim sheet, the same detail density. No odd piece out (a smooth box beside a modelled crate).

**Text and signage** ([World Composition](../../LihFolk/06%20World%20Building%20and%20Art/World%20Composition%20and%20Set%20Dressing%20-%20Designed%2C%20Not%20Scattered.md) §3, [Lore Delivery Without Walls of Text](../../LihFolk/36%20Narrative%20and%20Worldbuilding/Lore%20Delivery%20Without%20Walls%20of%20Text.md))
- [ ] **No letters built from Parts.** Text is a texture rendered from a real font on a modelled plate or panel, or a modelled mesh. Otherwise it's cut.
- [ ] **No blank sign frames.** Every frame carries art (Codex originals, fictional brands, tinted into the palette) or real text, or the frame goes.
- [ ] Signs use 3–8 words at most, face the approach, and sit on a visible mount (posts, brackets, a bolted plate).
- [ ] Landmarks, light and openings guide players before text does.
- [ ] **Arrows and route marks** are flush (0.04–0.05 proud) textures or decals that follow the walkable route, turns included, and point at the next node. Check each one from an eye-height camera. One that points at a wall is cut.

**Support (nothing floats)**
- [ ] FloatAudit is at 0. Every sign, light, banner, windsock and tank part reaches the ground through real contact.
- [ ] Mounts are modelled: posts with base plates and kickers, wall brackets that run into the wall, feet on bolted plates, hangers. No gap of even 0.1.
- [ ] Props sit on their surface or sink in slightly. None are half inside walls unless that's deliberate (roots, rubble).

**Scale against the R15 player** (5 studs tall; [Modelling to the Roblox Camera and Player Scale](../../LihFolk/55%20Modelling%20Nuance%20and%20Readability/Modelling%20to%20the%20Roblox%20Camera%20and%20Player%20Scale.md), [Game Plan](../../05%20Production/Game%20Plan.md) §5, [Gunplay](../Gunplay.md))

| Element | Number (studs) |
|---|---|
| Gameplay doorway | ≥ 6 wide, about 8 high |
| Decorative door (not a route) | 3.6–4 × 7.5–8 |
| Railing, parapet you shoot over | 3 (3.3 measured fine) |
| Perch parapet | 2.5–3.5 |
| Step | rise 1 (≤ 1.5), depth ≥ 2 |
| Low cover | 2.5–3.5 (half cover 3, crouch) |
| Full cover | ≥ 7 |
| **Dead band** | nothing collidable at 4–6: make it decor (no collision) or resize it |
| Jump | **5.6** (not Roblox's 7.2). Every rise is ≤ 4 per hop. |
| Perch deck | above the highest standable top within reach + 5.6 + clearance (Dockyard2: a catwalk at 14 over two stacked containers at 8 + 5.6 = 13.6) |
| Corridor | 8–12 wide |
| Indoor ceiling | 10–15 |
| Crates, table tops | 2–3 |
| Handles, switches | about 3.5 |

- [ ] Every prop is checked next to the 5-stud dummy in an evidence shot. Write the measured numbers in the map note.

**Palette and value** ([Colour Scripts and Value Structure](../../LihFolk/54%20Untextured%20Stylised%20Modelling/Colour%20Scripts%20and%20Value%20Structure%20for%20Untextured%20Art.md), [Zone and Biome Art Direction](../../LihFolk/06%20World%20Building%20and%20Art/Zone%20and%20Biome%20Art%20Direction.md))
- [ ] There is one palette table (step 3). Any colour that isn't in it gets recoloured. Imported Codex props are recoloured by role.
- [ ] The environment is desaturated. Saturation goes on the landmark and the zone accents, about 10% of the view. There is one accent hue per zone, and no second landmark colour (for example a second yellow).
- [ ] **No team colours on the map.** Team cyan and orange-red stay in the UI. Sides read by tone (Rooftops2: A apricot, B sage).
- [ ] Painted surfaces never use Roblox `Metal`: it mirrors the sky. Use clean SmoothPlastic or a variant, and let the geometry carry the detail.
- [ ] Lift near-black surfaces above a luminance of about 0.06. Below that, textures vanish and they read as holes (Rooftops2's dark slate and navy windows).
- [ ] Neighbouring maps differ in at least two of hue, key and saturation.

**Lighting: bright and readable** ([Stylized Lighting Recipes](../../LihFolk/07%20Lighting%20VFX%20and%20Audio/Stylized%20Lighting%20Recipes.md))
- [ ] Start from a recipe (toon arena §3.2, golden hour §3.3), then **lift it**. Shade must never be underexposed. Dockyard2 v4 (no longer "dark"): Brightness 3.0, ExposureCompensation 0.2, Ambient (130,134,146), OutdoorAmbient (172,176,192).
- [ ] Ambient ≤ OutdoorAmbient per channel. Warm key against a neutral-cool shade (a blue ambient crushes blue paint). Use haze for depth.
- [ ] **Greyscale test:** if the player and the ground are within about 10% value of each other, the map is too dark.
- [ ] **No-shadow test:** phones below graphics quality 4 have no shadows, so colour shifts must carry the light.
- [ ] Neon is the single hot spot. Bloom threshold about 1.1, above the walls' brightness. Practical light uses Neon strips, because PointLights don't show in edit-mode captures. Small parts and Neon don't cast shadows.

**Landmarks and levels** ([Level Design Principles](../../LihFolk/33%20Level%20Design/Level%20Design%20Principles%20-%20Flow%20Sightlines%20and%20Landmarks.md), [Combat Arena and Encounter Layout](../../LihFolk/33%20Level%20Design/Combat%20Arena%20and%20Encounter%20Layout.md))
- [ ] One global landmark. It's unique as a black silhouette, at least 1.5× taller than anything else, in the first frame after spawning, and it doesn't hide a route exit.
- [ ] The spawn view shows the landmark and the way out. No blank wall in front of a spawn.
- [ ] At least three playable heights: a low ground (pit, deck, street), the main floor, and a high perch.
- [ ] Every high spot has two contested ways up, a parapet, and a perch share of at most 40% (layout script). No position beats its mirror.
- [ ] Routes read by contrast: darker stringers and rails against light walls, and a lit route. Never stack stairs, catwalks and frames in one view of the landmark (Rooftops2's W2 stuck at 1).
- [ ] Dress every face the overview sees, outside the play space too.

**Storytelling props** ([World Composition](../../LihFolk/06%20World%20Building%20and%20Art/World%20Composition%20and%20Set%20Dressing%20-%20Designed%2C%20Not%20Scattered.md) §1–3)
- [ ] 2–3 story groups from the identity brief, at path edges and nodes. Each one answers "what happened here?" (Rooftops2's laundry line; Dockyard2's open reefer with cut cables).
- [ ] Groups have an odd count: one big, a couple of mid, a few small, with 5–15% variation. Made things align (90° plus a few degrees), grown things get random yaw, and props face their use.
- [ ] Dense at walls and corners, sparse in play spaces, nothing in the path. No even sprinkle.

**Z-fighting**
- [ ] `Audit.luau` is at 0 pairs, and `coplanar.json` is 0 before export. Trims, paint, bands, caps, signs and cloth sit ≥ 0.05 studs proud. Parts butt edge to edge.

**Phone budgets** ([Art Budgets](../../LihFolk/06%20World%20Building%20and%20Art/Art%20Budgets%20-%20Triangles%20Draw%20Calls%20Memory.md), [Textures Decals and Texture Memory](../../LihFolk/06%20World%20Building%20and%20Art/Textures%20Decals%20and%20Texture%20Memory.md), [Mesh Optimization for Mobile](../../LihFolk/14%203D%20Modeling/Mesh%20Optimization%20for%20Mobile.md))

| Budget | Limit |
|---|---|
| Map visible triangles | ≤ 450k (Dockyard2 is about 300k) |
| Repeated prop (crate, AC, planter) | ≤ 800 tris |
| Medium piece | 800–3,000 tris |
| Landmark or hero | 5k–12k tris |
| One mesh, hard cap | 20k tris |
| Visible parts | measured 1.7k–2.5k on Rooftops2 / Dockyard2. Investigate anything over 3k. |
| Textures | one 1024 trim sheet plus ≤ 6 variants at 512. Sign art ≤ 1024. Minor images ≤ 256. Reuse by tint, never a unique texture per prop. |
| Transparency | none on grating or cards. Grating is opaque. |

- [ ] Draw calls come down first: fewer unique meshes and materials, one cloned SurfaceAppearance template.

**The 2048 mesh cap**
- [ ] No kit piece is over **2048 studs** on any axis. Roblox shrinks a bigger mesh on upload and it lands out of place (Snowpeak's mountain range). Crop or split it.

**Collisions**
- [ ] The greybox Parts are the collision. Once step 2 is checked, they don't move. Art may not change gameplay.
- [ ] Kit and decor: `CanCollide`, `CanQuery` and `CanTouch` off, unless the piece *is* the collision. Cover meshes fill their cover box exactly, with nothing outside it.
- [ ] No invisible blockers on routes. Walk every route at eye height.

## 4. Map identity
Each map needs a **landmark**, a **height structure** and a **zone colour**. They're settled in the identity brief (step 1) and the palette table, and approved with the concepts.

| Map | Landmark (from its note) | Height structure | Zone colour |
|---|---|---|---|
| Rooftops2 | timber water tank on a steel lift tower | Pit, team roofs, side towers +8, tank platform | A apricot / B sage, cobalt accent |
| Dockyard2 | yellow gantry crane (the only yellow) | quay deck, container stacks, crane catwalk at 14 | red / blue / green lanes |
| Bunker | sunwell light shaft and sun plinth | sunwell floor, ring catwalk +12, overlooks | set in the concept pass |
| Greenhouse | glass dome over the fountain | garden, gallery, bridge | set in the concept pass |
| Old Town | clock tower | plaza, arcades, cafe terrace | set in the concept pass |
| Metro | the two staggered trains | sunken track, platforms, end terraces | set in the concept pass |
| Snowpeak | two-storey timber lodge, gondola stations | pond, saddle, lodge floors | set in the concept pass |
| Whitebox / Big Whitebox | abstract by design; keep it that way unless the user asks | — | — |

A zone must be recognisable from any one of three reads on its own: silhouette, colour, light.

## 5. How to use Codex ([Codex Collaboration](../../04%20Tech/Codex%20Collaboration.md))
- **Delegate:**
  - concept images (step 1);
  - original sign and billboard art (fictional brands, no real logos);
  - trim-sheet swatches;
  - props in Blender through its MCP, one row each in the map note's "Codex prop list" (concept reference, size, triangle budget, roles, export path `art-source/maps/<Map>2/props/<Prop>.glb` plus `.blend` and a preview with a 5-stud block);
  - blind second opinions.
- **Don't delegate:** layout, collision, Studio installs, code, remotes or git. The Claude lane reviews every Codex prop against the concept and §3 before using it. Recolour it by role and re-check its scale (Dockyard2's 8-long rack didn't fit the 14-long footprint and was cut).
- **Budget:** ChatGPT Plus has a 5-hour limit and a weekly limit. Images burn it **3–5× faster**. Send one batched, well-specified brief per job, written in the vault first. Connect Studio or Blender MCP only for a job that needs it. If the limit is hit, stop, note where the job got to, and never buy credits.
- **Locks:** take `.claude-locks/blender.lock` or `match-studio.lock` before using a tool, and never touch a locked one. No git. Write only the named paths. Never publish a place, never `require` server modules over MCP, and never type credentials. Every brief repeats the vault-and-LihFolk rule.

## 6. The review loop
- **One round:** fix → audits (0 / 0) → evidence cameras → blind score → a commit (exact paths only).
- **Fix rounds** may use one blind reviewer for direction. The pass or fail result always uses **3 reviewers and the median per criterion**.
- **Score maths:** the rubric weights are W1 composition 3, W2 navigation 3, W3 cohesion 2, W4 lighting 2, W5 detail 1, W6 scale 1, each graded 0–2. The score is Σ(W × grade) / 24 × 10. **8.5 needs 21 of 24**: at most one weight-3 criterion at 1, or one weight-2 plus one weight-1 at 1. 8.33 is a fail.
- **Stop rule (the project's; it overrides the skill's "max 3 fix rounds"):** loop until the median is ≥ 8.5, or until **two rounds in a row each gain under 0.3** on the best score so far. Then stop and write down what's holding the map back.
- **Never round up.** Below 8.5 is a draft, and the note says so.

**Each round in the map note:**
- what changed;
- the audit counts (parts, pairs, floating groups);
- the shots (`v<N>-r<round>-*.jpg`) and the side-by-side;
- the three scores and the medians per criterion;
- the reviewers' low points;
- the next list.

**Approval summary** (when the lane thinks a map is ready, at most about 10 lines for the user):
1. The map, its version, and how to see it (`ForceMap`).
2. The score and the audits.
3. Three best shots and the side-by-side.
4. What changed since the user's last review, item by item against their complaints.
5. The known weak spots.
6. What the lane asks: approve, or what to change.

The core chat saves the place (Ctrl+S) and passes the summary on.

## 7. New-version convention
- **Build `<Map>2` as a new version.** It gets a new map id, a free world origin listed in its note and in [Maps](00%20Maps.md), a new note `vault/01 Design/Maps/<Map>2.md`, new scripts in `tools/studio/maps/<Map>2/`, and new art in `art-source/maps/<Map>2/`.
- **The old map stays untouched:** its files, its Studio model and its Config rows.
- **ForceMap only until the user approves.** In Studio, set `workspace:SetAttribute("ForceMap", "<Map>2")`. Make no `Config/Match` MAPS change until the user approves the swap.
- **Never edit `tools/studio/maps/Snowpeak/Art.luau`.** It holds the user's uncommitted edits. Snowpeak2 may read it, but it writes its own files.
- **Commit only exact paths.** Never `git add -A` or the whole vault: third-party images live there and the repo is public. Never commit `.rbxl` files.
