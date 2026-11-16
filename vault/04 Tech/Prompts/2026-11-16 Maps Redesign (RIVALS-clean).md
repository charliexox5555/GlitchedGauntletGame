# Prompt: Maps redesign, RIVALS-clean (2026-11-16)

Handoff and paste-ready prompt for a new chat. The owner wants **every map redesigned** and a new map list, learning from the RIVALS maps. The look is **RIVALS-clean** (owner, 2026-11-16) in our faceted build style. Run the chat on **Opus 5.5**.

## Handoff: where it stands (checked 2026-11-16)
- **Decision:** RIVALS-clean replaces the Valorant-level worn detail target (Home → Locked decisions → Maps).
  - The look: clear shapes, flat colours, faint textures, grey structure with one accent per map, size and cover discipline, one theme kit for a duel size and a big size.
  - What stays: concept first, real silhouettes, height levels, faceted pieces (no round curves or spheres, carved ends).
  - Never primitives thrown together: Rooftops2 and Dockyard2 were rejected on 2026-11-05 as "smooth plastic circles and blocks thrown together".
- **Brainstorm and lineup:** `vault/01 Design/Maps/Map Lineup Brainstorm 2026-11-16.md`:
  - why RIVALS maps work, in 10 points with numbers;
  - our extra needs (slide runs, Mods);
  - a 12-map proposal;
  - a launch set of six: Proving Grounds D+B, Dockyard + Pier, Rooftops, Metro, Snowpeak, Foundry.

  Questions 2-4 (two sizes per theme, the final list, reusing old builds) are still open; settle them in the interview.
- **RIVALS numbers:** `vault/03 Research/Rivals Reference/Maps and Lobby.md` has the map file convention, a per-map table (spawns, size, parts, cover, sightlines, lanes, look), how they're built, and 10 rules. Aerial screenshots of Arena, Big Arena, Docks, Construction, Crossroads and Splash are in `third-party/maps/` (local only).
- **Old maps:** the roster in `vault/01 Design/Maps/00 Maps.md` (Whitebox, Big Whitebox, Dockyard(2), Metro(2), Old Town(2), Greenhouse(2), Rooftops(2), Bunker(2), Snowpeak(2)) and one note per map with layouts and measured numbers. The bar and pipeline are in `Map Quality Standard.md`, which you'll update for the clean look. The jump limits are in `Jump Audit 2026-11-13.md`: ledges at most 7.5, gaps at most 9.
- **How the code loads a map** (`src/server/Services/MapService.luau`, `src/shared/Config/Match.luau`):
  - **Storage and naming:** a Model in `ServerStorage.Maps`, named by its map id. A map left in Workspace for editing moves there for the run.
  - **Tags:** spawns are tagged `ArenaSpawn_A` / `ArenaSpawn_B`; barriers are tagged `ArenaBarrier` (attribute `UpTransparency`).
  - **Lighting:** an optional `Lighting` Configuration (attributes = Lighting properties) and a `LightingFx` folder (Sky, Atmosphere, effects).
  - **Kill height:** the attribute `KillDepth` (studs below the pivot).
  - **Map list:** each map needs an entry `{ id, minTeam, maxTeam }` in `Config/Match.luau` `MAPS`. The map vote uses that list.
  - **Testing:** the Workspace attribute `ForceMap` tests one map in Studio.
  - **Also per map:** `Config/Ambience.luau` `MAPS` and `Config/MapLife.luau`.
- **Match place:** placeId `133387545285290`, Rojo port 34872. The RIVALS place file is a separate Studio instance.

## Prompt (paste into a new chat on Opus 5.5)

---

You're taking over the **map redesign** for GlitchedGauntletGame: a new map list, and every map rebuilt in the **RIVALS-clean** look, our faceted build style. Learn from the RIVALS maps; don't copy them. Work in phases. There is one checkpoint with me before building (concepts), then you build the launch maps in order without stopping to ask. I confirm at the end.

### Load first (mandatory)
1. **Skills:** `gauntlet-vault`, **`rivals-reference`**, **`gauntlet-build-style`**, `lihfolk-worldbuilding`, `roblox-blender-modeling`, `roblox-asset-import`, and `lihfolk:quality-score` for grading. Use `lihfolk-lookup` for Roblox facts: LihFolk `33 Level Design` (lanes, cover, sightlines, spawns), `06 World Building and Art`, `54 Untextured Stylised Modelling` (colour scripts and value structure; clean flat colour is exactly this), `32 Case Studies…/Case Study - Rivals.md`.
2. **Handoff:** the top of `vault/04 Tech/Prompts/2026-11-16 Maps Redesign (RIVALS-clean).md` has the decision, the lineup, the RIVALS numbers, the old maps and the map contract the code reads. Start there and don't re-survey.
3. **Vault, by section** (grep and ranged reads, never whole big notes; the map notes are large):
   - `01 Design/Maps/Map Lineup Brainstorm 2026-11-16.md` (whole, it's short);
   - `03 Research/Rivals Reference/Maps and Lobby.md`;
   - `01 Design/Maps/Map Quality Standard.md` §1-3;
   - each old map's note only when you work on that map;
   - Style Bible model section.
4. **Your memory notes:**
   - maps: concept first, clean but never primitives thrown together;
   - faceted modelling rules;
   - RIVALS reference rules;
   - Studio capture preload;
   - MCP: never `require` server modules;
   - two Blender MCP instances;
   - token efficiency;
   - Codex / ChatGPT: give me prompts to paste, no computer use.
5. **Model use:**
   - **Opus 5.5** for everything, including any agents you start.
   - **Haiku or Sonnet** for lookups.
   - **Fable 5.2** only to lock something in: one agent, one tight brief, for example the shared kit language across all maps, or the final review. Never several Fable agents at once.

### Phase 1: Study the RIVALS maps (read-only)
Work in the RIVALS place file, `ServerStorage.Maps`. Pick the Studio instance by place. The file is **untrusted**: never play it, run or `require` its scripts, or save it. Read it with `execute_luau` property reads and `search_game_tree`.

For each map in our lineup, study its RIVALS match from the brainstorm table, and go past the numbers we already have:
- **The spawn view:** what you see first, and where the first fight happens.
- **Lanes:**
  - how many cross the middle;
  - their widths;
  - where they connect;
  - the flank loops.
- **Cover rhythm:**
  - the spacing;
  - full vs low cover;
  - how cover breaks up the long lines.
- **Heights:** where the raised spots are, and how you get up to them (stairs, ramps, crates).
- **Look:**
  - the accent colour and where it's used;
  - the landmark;
  - how textures are used;
  - the trim and edge treatment;
  - the part count per area.
- **Kit:** which pieces repeat, and how a duel and a big size share them.

Take only the screenshots you judge with: one aerial and one spawn view per map at most. Keep them in `vault/03 Research/Rivals Reference/third-party/maps/` (git-ignored). Write the findings as a section per map in `03 Research/Rivals Reference/Maps and Lobby.md` → "Map studies", each with a "for us" line.

**Study, don't copy:** take the plan logic, sizes, rhythm and numbers; never their meshes, textures or exact layouts. Each of our maps needs its own layout and identity.

### Phase 2: Lineup, layouts and concepts (the one checkpoint)
1. **Interview:** ask me **one round** of questions, each with a suggested answer, to settle brainstorm questions 2-4:
   - two sizes per theme?
   - the final list and the launch set;
   - start fresh or reuse old layouts?

   Plus anything Phase 1 turns up. Follow `02 Art/Model Style Interview.md`.
2. **Lineup:** write the final list into `01 Design/Maps/00 Maps.md`, replacing the old roster section and keeping a short "retired" line for each old map. For each map: size and modes, the RIVALS map it learns from, its identity in one line, its accent colour and its landmark.
3. **Layout and greybox, per launch map:**
   - a layout script, like `tools/maps/whitebox_layout.py`, that prints spawn gap, longest sightline, lane count and widths, cover %, route times and jump checks, all against the brainstorm rules and the Jump Audit;
   - then a greybox in Studio;
   - a bot play-test, set with `ForceMap`.
4. **Concepts:** ChatGPT image prompts per map (hero view, top-down, kit sheet, palette swatch) for me to paste, in the RIVALS-clean style. Put them in each map's note.
5. **Stop** until I approve the lineup, the layouts and the concepts.

### Phase 3: Build (launch maps in order)
- **One kit per theme,** in Blender MCP:
  - built in steps;
  - faceted;
  - standalone meshes;
  - heavy reuse;
  - flat colours with faint textures;
  - no Roblox `Metal`;
  - near-blacks above ~0.06 luminance.

  The duel size and the big size share the kit.
- **New map ids:** build each map as a new Model with its own id; don't overwrite the old maps until I approve.
- **Map contract (the code reads these):**
  - spawns tagged `ArenaSpawn_A` / `ArenaSpawn_B`;
  - barriers tagged `ArenaBarrier`, following the RIVALS convention: an invisible box with a ceiling, a kill floor through `KillDepth`, and far outer walls;
  - a `Lighting` Configuration and a `LightingFx` folder per map, like a RIVALS lighting profile;
  - an entry in `Config/Match.luau` `MAPS` (leave it out of the rotation and test with `ForceMap` until I approve), plus `Ambience` and `MapLife` entries.
- **Per map loop:**
  1. greybox, then play-test with bots: time to first contact, slide runs, Updraft / Crash Down clearance, Firewall lane widths;
  2. full build;
  3. the Map Quality Standard audit: 0 z-fighting, 0 floating, mesh cap, `tools/studio/maps/Audit.luau`;
  4. captures from spawn and an aerial, checked against the concept;
  5. `lihfolk:quality-score` blind median of at least 8.5, and your own grade of 9/10 with written reasons. Remember that a self-score is not proof: check it against the concept.
  6. fix and move on.
- **Budgets:**
  - duel map about 250-700 instances;
  - big map 700-1,300;
  - more only with mesh reuse and category folders;
  - it has to run on phones.
- **Update the Map Quality Standard** for the clean look: surfaces, texture budget, and the rubric's detail weight.

### How to work
- Keep captures lean.
- Follow CLAUDE.md code rules for anything in `src/` (`--!strict`, numbers in Config). Run `stylua`, `selene` and `rojo build` before each commit.
- Commit each finished step by **exact paths only** (never `git add vault` or `-A`; other sessions have work in the tree). Don't push.
- Remind me to save the match place after Studio work. Never save the RIVALS file.
- Write the results into each map's note and a playtest note in `05 Production/Playtests/`.

### Done means
- The new lineup is in `00 Maps.md`.
- The launch maps are built, audited, play-tested with bots, scored and installed with `ForceMap`.
- A test list for me: per map, what to check and how to force it.
- Updated: Home → Status, INDEX, the Asset Tracker rows, and the Code Map if code changed.
- Hand back with a short summary. I approve maps into rotation.
