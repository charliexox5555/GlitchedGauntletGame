# Prompt: Lobby build from the RIVALS study (2026-11-16)

Handoff and paste-ready prompt for a new chat. The owner wants the lobby **rebuilt (geometry and art only, no scripting)** after a real study of what makes the RIVALS lobby fun and good. Restructure as much as needed. Main area first, then the other parts.

## Handoff: where it stands (checked 2026-11-16)
**Lobby place:** placeId `71551303511506`, lobby Rojo `lobby.project.json` on port 34873. Pick the Studio instance by placeId; the match place is `133387545285290`.

| Build | Where | State |
|---|---|---|
| **Live V3** | `Workspace.Lobby.Hub`; blend `art-source/lobby/LobbyV3.blend`; archive `ServerStorage.Archive.Hub_Bunker2_preV3` | still the live lobby; rollback `use("V3")` |
| **Sunwell Works** (newest) | `Workspace.SunwellStaging`, 1,500 studs east of V3; blend `art-source/lobby/SunwellWorks.blend` | 68×112×28 hall, Locker, Shop, Duels (16 queue zones), Gauntlet 4v4 stage. Range on hold. Screens, billboards, cases and props are placeholders. **Built but not saved, and the owner hasn't approved the look** (Home line 12). |

**Notes:**
- `02 Art/Sunwell Works Build.md` (3-5, 108, 143);
- `02 Art/Sunwell Hub Upgrade.md` (73, 126-137, 345-352, 426-434);
- `02 Art/Lobby V3 Rebuild.md` (26-49, 65-76, 142, 205, 244);
- `01 Design/Lobby.md`;
- `02 Art/Lobby Art Plan.md`;
- concepts in `02 Art/References/lobby/sunwell-works/`.

**Look (locked):**
- **Where it's written:** Style Bible §7 (`02 Art/Style Bible.md` :56-60); `gauntlet-build-style` skill §1-4 (:30-67), rejected list §7 (:90).
- **Palette:** light grey walls `#B9BAB7`, slate wainscot, charcoal, gunmetal; white lamp light.
- **Colour use:** one accent per room; team orange / blue only on duel gear.
- **Surfaces:** faint textures (±4%), matte, no PBR.
- **Shapes:** facets (no curves or spheres, carved ends, no blunt cutoffs).
- **Pads:** equal queue pads in mode order.
- **Not allowed:** blue-teal, steampunk (brass, wood, amber, sepia), neon/glitch, blocky.
- **Detail:** walls need trim, not texture; fixtures need character; boards are SurfaceGuis.
- **Note:** the reference pack's "petrol" steel (:82) is superseded by these rules.

**Rejected before (don't repeat):**
- 2026-11-04: pastel flat hall, "too bright, no textures".
- 2026-11-09 V3: walls see-through when zoomed out, overlapping sign parts, identical signs, guns rotated wrong, "looks AI made", **"too close to RIVALS"**, too much neon, glitch parts, blocky shapes, pads too small for two players.
- Sunwell 2026-11-12/13: glitched bench bays and pilasters, board borders, 4v4 overlap, combined meshes (each mesh must be standalone), pipes stopping short, "dull, too steampunk", one warm beige value band, bare alcoves. Blind median score 6.7.

**Pipeline:**
- **Blender → Studio:** Blender MCP (port 9876; second instance needs its own port) → `sw_export.run()` → `art-source/lobby/Exports/<Area>.fbx` + JSON data → `tools/opencloud/upload_models.py --lobby --group 11116787` → in Studio, `require(Build).rebuild()` and `use(...)`.
- **Build data** is a model asset, not Rojo.
- **Colliders:**
  - architecture: the visible mesh is the collider;
  - walk-tops: inset (~0.18);
  - invisible colliders: opaque.
- **Captures:** move `workspace.CurrentCamera` into the room first, or SurfaceGuis and lights capture black. Preload meshes before calling something missing.

**Scripted hooks the rebuild must keep:**
- `src/lobby/client/Controllers/WorldPrompts.luau` :20-24 binds the tags `LobbyQueue`, `LobbyShop`, `LobbyBattlePass`, `LobbyLocker` and `LobbyRangeEntrance`.
- Each tag goes on a BasePart, an Attachment or a Model with a PrimaryPart.
- `LobbyQueue` reads only the attribute `Mode`, which must be `1v1`, `2v2` or `3v3` (`src/lobby/shared/Config.luau` :18-33). There is no `4v4` mode yet, so a 4v4 pad opens the queue with no mode preselected (parked; this job doesn't script).
- Nothing reads `PadId`, `LobbySpawn`, `Workspace.Lobby`, `PadScreen_*` or the other old names (grep 2026-11-16), so the structure is free to change.

**RIVALS lobby, already measured** (`03 Research/Rivals Reference/Maps and Lobby.md` → Lobby):
- **Plan:** a compact cross about 340×290. A round centre hub (spawn on a ringed dais) with wings: Duels hall, Market, Weapons room, Hallway, and an outdoor range facing a landmark hill.
- **Walks from spawn:** range ~4 s, first pad ~6 s, farthest pad ~15 s.
- **Queue pads:** 10 in two rows 48 apart, 27-39 between pads, each 21×34×29.
- **Life:** holograms and TVs.
- **Guidance:** floor lines lead to each wing; camera-blocker planes stop the camera clipping walls.
- Screenshots are in `third-party/lobby/` (9, local only).

## Prompt (paste into a new chat)

---

You're taking over **building the lobby** for GlitchedGauntletGame: **geometry, structure and art only, no scripting**. First study the RIVALS lobby properly: what makes it fun and good, its geometry, signs, structure, the Duels area, everything. Then rebuild ours to our criteria and look. You may restructure all of it, and you'll rebuild a lot. Start with the **main area**, then move on to the other parts.

### Load first (mandatory)
1. **Skills:**
   - `gauntlet-vault`, **`rivals-reference`**, **`gauntlet-build-style`**;
   - `lihfolk-worldbuilding`, `roblox-blender-modeling`, `roblox-asset-import`;
   - `lihfolk:quality-score` for grading;
   - `lihfolk-lookup` for Roblox facts (LihFolk `33 Level Design`, `06 World Building and Art`, `60 High-Craft Game Teardowns`, `32 Case Studies…/Case Study - Rivals.md`).
2. **The handoff** at the top of `vault/04 Tech/Prompts/2026-11-16 Lobby Build (RIVALS study).md` gives the current state, the locked look, the rejected list, the pipeline and the scripted hooks with file:line. Start there and don't re-survey.
3. **Vault, by section** (grep and ranged reads; never whole big notes):
   - `02 Art/Style Bible.md` §7;
   - `01 Design/Lobby.md`;
   - `02 Art/Lobby Art Plan.md`;
   - `02 Art/Sunwell Works Build.md` and `Sunwell Hub Upgrade.md` (what was built and why it was rejected);
   - `03 Research/Rivals Reference/Maps and Lobby.md`.
4. **Your memory notes,** and follow them:
   - lobby art direction: soft but tactical, not a RIVALS copy;
   - Sunwell lobby taste;
   - faceted modelling rules;
   - maps: concept first, real detail;
   - the Lobby Studio pipeline;
   - two Blender MCP instances;
   - capture preload;
   - token efficiency;
   - Codex / ChatGPT: give me prompts to paste, no computer use.

### Phase 1: Study the RIVALS lobby (read-only)
Work in the RIVALS place file, `Workspace.Lobby.Hub`; pick that file's Studio instance. It is **untrusted**: never play it, run or `require` its scripts, or save it. Read geometry and properties with `execute_luau` reads and `search_game_tree`. Take only the screenshots you need; save them in `vault/03 Research/Rivals Reference/third-party/lobby/` (git-ignored, never committed).

Go past the numbers already in `Maps and Lobby.md` and answer **why it works**:
- **Spawn view and flow:**
  - What can you see from spawn?
  - How do floor lines, light and signs pull you to each wing?
  - Where do players bunch up, and why?
- **Layout:**
  - each wing: size, ceiling height, door widths;
  - wing entrances and the sightlines through them;
  - where the landmarks sit.
- **Duels area:**
  - pad rhythm and spacing;
  - sign placement over the lanes;
  - how the mode reads from a distance;
  - where waiting players stand and who can see them.
- **Signs and boards:** sizes, height above the floor, how many per wing, what they say, and how each is lit.
- **Structure language:** wall modules, trims, ceiling grids, how the floor is broken up, transitions between rooms, and camera-blocker planes.
- **"Life":** holograms, TVs, moving bits, and how much of each per room. Get the counts.
- **Lighting:** how many lights per room, the key light vs the fill, and the colour of each.
- **Fun:**
  - the range near spawn;
  - short walks;
  - places to show off a skin;
  - things to do while waiting.

Write it as a new section **"What makes it work"** in `03 Research/Rivals Reference/Maps and Lobby.md`. Each point gets a number, plus a "for us" line in our style.

**Study, don't copy:** take the plan logic, sizes, rhythm and walk times; never their meshes, textures, images, signs or layout one-to-one. The owner rejected V3 for being "too close to RIVALS".

### Phase 2: Plan and concepts (the one checkpoint)
1. **Plan:** write `vault/02 Art/Lobby V4 Plan.md`:
   - **layout:** a top-down plan with sizes and walk times for every area;
   - **areas:**
     - main area / spawn hub;
     - Duels with pads for 1v1, 2v2, 3v3 and 4v4;
     - Locker, Shop and Season Pass;
     - range;
     - any social spot.
   - **each area's look:** its one accent, landmark, signs and life;
   - **reuse:** what you'll keep or reuse from Sunwell Works and V3, and what you'll rebuild;
   - **budgets:** instance and triangle budgets per area;
   - **phase order:** main area first.
2. **Concepts:** follow the concept-first rule. Give me ChatGPT image prompts to paste, for the main area and Duels first. Put them in the plan note; use `02 Art/UI Art Brief (ChatGPT).md` as the template for prompt style.
3. **Interview:** ask me **one round** of questions, each with a suggested answer, to settle what the plan can't. Follow `02 Art/Model Style Interview.md`. For example:
   - What's the hub's landmark?
   - Should the range be indoors or outdoors?
   - Does the Season Pass get its own room?
4. **Stop** until I approve the plan and the concepts.

After that, build without stopping to ask.

### Phase 3: Build (main area first, then the rest)
- **Where to build:** a new staging model in the Lobby place, e.g. `Workspace.LobbyV4Staging`, set away from V3 and Sunwell. Keep **V3 live** and Sunwell as a fallback until I approve the swap.
  - **Before you start,** remind me to **save the Lobby place**: Sunwell is built but not saved.
- **Pipeline:**
  - model in Blender MCP, in steps;
  - export standalone meshes (never combined);
  - upload with Open Cloud;
  - assemble with the Build module;
  - collision follows the handoff rules.
- **Each area,** in this order:
  1. blockout, plus a walk test at 16 studs/s (walk times against the plan);
  2. a capture from spawn and from a high oblique angle;
  3. the full build: trims, fixtures with character, SurfaceGui boards, lighting;
  4. self-review, plus geometry checks:
     - no overlaps or z-fighting;
     - no see-through walls when zoomed out;
     - no floating props;
     - no pipes or trims stopping short;
     - nothing lit black in the captures;
  5. `lihfolk:quality-score`, target **9/10**, with written reasons, a blind median of at least 8.5, and a check against the rejected list;
  6. fix and move on.
- **Keep the hooks:**
  - tag the interactables (`LobbyQueue` with `Mode`, `LobbyShop`, `LobbyBattlePass`, `LobbyLocker`, `LobbyRangeEntrance`) on a BasePart, an Attachment or a Model with a PrimaryPart;
  - test that every prompt still opens in a lobby play-test.
  - Don't write gameplay code. If a 4v4 pad needs a `4v4` mode, park it in `Bugs & Ideas.md`.
- **Budgets:** stay within the plan's budgets, reuse meshes heavily, and sort them into category folders. This must run on phones.

### How to work
- Keep captures lean: only the ones you judge with.
- Write results after each area into `02 Art/Lobby V4 Plan.md` (or a `Lobby V4 Build.md` beside it):
  - captures;
  - scores;
  - what's still weak.
- Commit each finished area by **exact paths only** (never `git add vault` or `-A`; other sessions have work in the tree):
  - the blend files;
  - the exports;
  - the vault notes.

  Don't push. Remind me to save the Lobby place after each area.
- Follow CLAUDE.md for anything you touch in `src/`. You shouldn't need to touch it beyond tags and attributes, which belong on the model.

### Done means
- Every area in the plan is built in `LobbyV4Staging` to the locked look, scored 9+, walk-tested, and every prompt has been checked in a play-test.
- `Lobby V4 Build` covers:
  - captures per area;
  - a test list for me;
  - parked questions;
  - the swap steps (how to make V4 live and how to roll back).
- Updated:
  - Home → Status;
  - `INDEX.md`;
  - the lobby row in the Asset Tracker;
  - Style Bible §7 and the Locked decisions row, if the look changed.
- Hand back with a short summary. I approve the swap.
