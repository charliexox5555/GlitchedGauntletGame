# Prompt: Lobby, phase 1 (build and art only, NO game code)

> **Note (2026-10-29):** after step 1 the user changed the layout to a **circular underground bunker hub** (rotunda + skylight, outer ring, Duels / Market / Weapons + Locker / Range wings, no courtyard). Where this prompt says hall, courtyard or late afternoon, follow [Lobby](../../01%20Design/Lobby.md) and the [Lobby Art Plan](../../02%20Art/Lobby%20Art%20Plan.md) instead.

**Locked 2026-10-29:** the Lobby is a **new place called "Lobby" in the same experience** as the game. Claude works in **both places** (the game place and the Lobby place). In this phase we **only build the hub and make it look good**:
- **Allowed:** building, Blender models, materials, lighting, and **decorative scripts** (ambient VFX, animated signs and screens, light flicker, moving dust and props).
- **Not allowed:** **game-structure code** (queues, teleports, parties, data, cameras, movement, UI systems, Rojo project changes). That's phase 2, and **only after the user approves the build**.

Paste this into Claude Code (repo root):

```text
We're starting the LOBBY, phase 1: BUILD AND ART ONLY.

Read first: CLAUDE.md, vault/01 Design/Lobby.md (the locked design: modern tactical training facility, bright indoor central queue hall opening onto an outdoor courtyard, late-afternoon sun, 1v1/2v2/3v3 pads, shop, locker, leaderboard wall, Range wing gate) and vault/02 Art/Art Direction.md (art style, Blender → Roblox pipeline, upload tools).

LOCKED RULES FOR THIS PHASE
- The Lobby is a NEW PLACE named "Lobby" in the SAME experience as the game (not a new game). You'll work in both places. Before every Studio action, confirm which place the Studio MCP is connected to (print game.PlaceId and the place name) and that it's the Lobby.
- NO GAME CODE until I approve the finished build: no queue/matchmaking, teleport, party, data, camera, movement, HUD/UI systems, and no Rojo project changes. Do NOT connect Rojo while the Lobby place is open (the current project would sync the match game's code into it).
- Allowed: building geometry, Blender models, materials/textures, lighting/atmosphere, and DECORATIVE scripts only (ambient VFX, animated LED signs/screens, flickering lights, rotating displays, dust motes in sunbeams, swaying plants, glowing pad rings). Keep decorative scripts inside the Lobby place under one folder (e.g. Workspace.Lobby.Ambience; client-only effects in a single LocalScript), and save a copy of each to art-source/lobby/scripts/ so they're versioned.
- Quality bar: professional, like a real shipped game's lobby. Blender for models and effect textures (same standard as the abilities: preview renders BEFORE importing), layered lighting and atmosphere. Never plain grey Roblox parts in the final result.
- Performance: 30 players on phones. StreamingEnabled, reuse kit pieces, CastShadow off on small props, few dynamic lights, sane triangle and texture budgets.

STEPS (STOP after each one, show me renders/screenshots, and wait for my OK):
0. SETUP: Walk me through creating the "Lobby" place in this experience (exact clicks, e.g. Studio → View → Asset Manager → Places → Add New Place, or Creator Dashboard → Places) and opening it in Studio. Then verify the MCP is connected to it. Don't change the start place yet (that's done later by publishing the Lobby over the start place; I'll back up the game first).
1. REFERENCE + PLAN: Look up reference images (modern tactical training facilities, high-end gyms and offices with big glass and concrete, esports venue lobbies, the RIVALS lobby for scale and readability). Make a short mood board note in the vault, and a top-down layout plan with dimensions (hall ~120 × 90 studs, ~40-stud ceiling, courtyard ~150 × 100, pad spacing, sightlines from spawn to pads and leaderboard wall, the Range wing gate and an empty shell behind it). Save it as vault/02 Art/Lobby Art Plan.md.
2. GREYBOX in the Lobby place: simple coloured parts per zone (spawn, pads, shop, locker, leaderboard wall, glass doors, courtyard, Range wing gate + empty shell). Let me walk around it at real scale (default Roblox character is fine for scale).
3. BLENDER MODULAR KIT, design: list every kit piece (walls, columns, floor tiles, glass panels/frames, ceiling beams and light panels, trims, stairs/ramps, doors, the queue pads with LED rings, shop counter + display stands, locker wall + preview pedestal, leaderboard screen frames, benches, planters/trees, signage), with a style sheet (materials, palette, trim sizes). Render previews in Blender and show me BEFORE modelling everything.
4. BUILD THE KIT in Blender, render a contact sheet, then import/upload it with our pipeline (tools/blender, tools/opencloud) and assemble the hub over the greybox. Back up each piece to art-source/lobby/ (.blend sources, exports, Studio .rbxm backups).
5. PROPS, SIGNAGE and SURFACES: big clear signs for "1v1 / 2v2 / 3v3", SHOP, LOCKER, RANGE; leaderboard screen frames with placeholder content; decals, floor markings, glass, and courtyard landscaping.
6. LIGHTING and ATMOSPHERE: bright late afternoon (Future lighting, sun angle through the glass, Atmosphere, bloom, colour correction, sun rays), then the decorative ambience scripts and VFX listed above.
7. POLISH + PERFORMANCE PASS: screenshots from spawn, the pads, shop, locker, courtyard and the Range gate, plus a phone-performance check.
Then remind me to SAVE and PUBLISH the Lobby place, update vault/01 Design/Lobby.md (status), vault/00 Home.md Status and vault/06 Assets/Asset Tracker.md (add a Lobby section), and commit and push.
```
