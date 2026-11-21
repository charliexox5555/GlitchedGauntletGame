# Prompt: new Docks map + container fix (2026-11-20)

## Owner calls (2026-11-20)
- **Keep:** Arena, Big Arena, Pier, Dockyard (the "simple" maps). **Fix:** the shipping containers on Pier and Dockyard are slightly see-through.
- **Pull from rotation, keep the models:** Rooftops3, Courtyard, Bunker3, Foundry, Snowpeak3, Model Kit, OldTown3, Metro3, Greenhouse3. Owner's verdict: curved shapes, plain untextured ground, no world around them, don't look like RIVALS/Valorant maps.
- **New map:** a regular-size (1v1-2v2) map with its own name (session picks one that doesn't clash with Pier/Dockyard), modelled on **RIVALS Docks**: same flow (lanes, sizes, heights, sightlines measured from it), every piece rebuilt in our own art.
- **Texture:** subtle custom MaterialVariants (planks, concrete seams, ribbed metal), not flat plastic.
- **Ocean:** one large blue Part (not Terrain water). **Mountains:** faceted Blender meshes on the horizon.
- **Check-in:** none mid-way. Build the whole map, self-review against the reference, then show the owner.

## Prompt (paste into a new chat on Opus 5.5)

> We're building a new map, then fixing a small bug on two old ones. Work from the vault, not from memory.
>
> **Load first (mandatory):** the `gauntlet-vault` skill; `lihfolk-worldbuilding` + `roblox-blender-modeling` (LihFolk); `gauntlet-build-style`; `rivals-reference`; `blender-director`. Read `vault/02 Art/Style Bible.md`, the top of `vault/01 Design/Maps/00 Maps.md`, `vault/01 Design/Maps/Map Quality Standard.md` §3 (hard rules), `vault/01 Design/Maps/Pier and Dockyard.md` (port kit, container kit), and the map contract in `vault/04 Tech/Prompts/2026-11-16 Maps Redesign (RIVALS-clean).md` (grep "Map contract"). Owner calls for this task: `vault/04 Tech/Prompts/2026-11-20 Docks Map Build.md`. Ask `vault-lookup` / `lihfolk-lookup` for facts instead of opening big notes whole.
>
> **Where:** work in the **match place** in Studio (pick the MCP instance by placeId; the Lobby place is another lane's). Blender MCP is connected for meshes.
>
> **Step 1: container fix (Pier + Dockyard).** The shipping containers are slightly see-through: you can see through the mesh. Find the cause (flipped normals / missing faces / single-sided walls / Transparency or a Texture/SurfaceAppearance alpha / LocalTransparencyModifier), fix it at the source (the kit mesh or the builder), and capture before/after from a few angles, close up and from inside. Nothing see-through and no z-fighting.
>
> **Step 2: pull the bad maps from rotation.** Remove Rooftops3, Courtyard, Bunker3, Foundry, Snowpeak3, ModelKit, OldTown3, Metro3, Greenhouse3 from `Config/Match` MAPS and the map vote, so only Arena, Big Arena, Pier and Dockyard (+ the new map when done) play. Keep their models in storage; don't delete. Check the vote and `ForceMap` still work.
>
> **Step 3: study RIVALS Docks (read-only).** The owner put RIVALS' **Docks** in `Workspace` of the match place, and all their maps in `ServerStorage["Maps Rivals"]` (they overlap: move one at a time into Workspace to look, then put it back). Study-not-copy: never reuse their meshes, textures or scripts. Measure Docks: overall size, lanes and their widths, cover heights, height levels and how you climb them, sightline lengths, spawn positions, where containers/cranes/sheds sit, what is landmark vs filler. Also note how they build: mostly **regular Parts** (wedges, trusses, beams), with meshes only where Parts can't do it. Look at 2-3 other RIVALS maps in the folder for how they dress edges and the world beyond the play space. Write the measurements and a top-down layout sketch in a new note `vault/01 Design/Maps/<NewName>.md` before building.
>
> **Step 4: build the new map, whole, no mid-way stop.**
> - **Regular size, 1v1-2v2**, same flow as RIVALS Docks; a name of your choice that fits a port and isn't Pier/Dockyard.
> - **Mostly Parts**, on a clean module (see Arena's 5-stud module), with crisp angled/carved ends. **No round curves or spheres** (curves are angled plates), **no blunt cutoffs**, nothing floating, no same-plane overlaps. Blender only for what Parts can't do well: the **mountains** (faceted, low-poly, on the horizon) and kit props (crane parts, bollards, etc.).
> - **Texture:** subtle custom **MaterialVariants** for planks, concrete (seams), metal (ribs/plates) and asphalt; ground must read as a real dock, not flat plastic. One accent colour for the map. Keep RIVALS' clarity: readable cover, clean silhouettes.
> - **World:** the ocean is **one large blue Part** around the map (no Terrain); mountains and a few distant shapes on the horizon so it sits in a place; lighting/atmosphere set for the map.
> - Follow the map contract (spawns, bounds, `WinnerStage`, kill floor in the water, etc.), add it to `Config/Match` MAPS, and make it playable via `ForceMap`.
> - Run the checks before showing: jump reach (ledge 7.5, gap 9 at sprint, see `Jump Audit 2026-11-13`), route clearance, overlap scan, floating-prop check, spawn travel balance, and a playtest walk. Self-review side by side with RIVALS Docks captures (same camera angles) and fix what's weaker; don't trust a self-score as proof.
>
> **Done means:** containers fixed with before/after captures; bad maps out of rotation; new map built, playable, checks passed; a capture set (overview, each lane, spawns, horizon) shown to me; the map note has measurements, layout, build log and what to test; Home → Status, Asset Tracker row, INDEX and `00 Maps.md` roster updated. Remind me to **save the place**. Commit by exact paths only (never `git add vault`/`-A`, never `third-party/`), on main.
