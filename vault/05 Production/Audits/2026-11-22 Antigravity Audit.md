# 2026-11-22 Antigravity Audit

## Summary
- **Tools:** Roblox Studio MCP is connected read-only to the merged live place (`71551303511506`, `[ 🦃] Draft Duels`, Edit mode); Blender MCP setup is paused because Blender 5.2 already listens on port `9876` via the official Blender Foundation MCP extension with Claude (`PID 13608`) and Codex (`PID 18464`) active.
- **Code baseline:** All 446 `.luau` files use `--!strict` with 0 `wait()`, 0 `_G`, 0 `InvokeClient`, 0 `MouseButton1Click`, and `rojo build default.project.json` succeeds — but `stylua --check src` and `selene src` both fail (1 error each).
- **Top release blockers:** The live merged place replicates **33,409 dead/third-party instances** to every client (including **13,551 RIVALS instances**), and the Shop has **zero `GetProductInfoAsync` calls**, un-gated paid-random Cases on Coin Packs 4–6 / Starter Bundle, a shared-skin-product intent race, and live `LockerV1` Studio writes.
- **Design drift:** `Weapons.luau` leaves the Operator at `95` body / `76` leg damage (breaking the locked 1-shot-anywhere rule), and `ShopCatalog.luau` drops Ruin-Blighted's 6th item (Knife) and carries stale `ITEM_ROBUX` prices.
- **Usage waste:** `00 Home.md` (67.7 KB, listed 13 KB) and `Code Map.md` (63.5 KB, listed 10 KB) plus 27 misleading `<15 KB` size labels in `INDEX.md` and two-place vs one-place doc contradictions burn the most tokens.

---

## Setup status

| Tool / Integration | Status | Details |
|---|---|---|
| **Roblox Studio MCP** | **Connected (read-only verified)** | Configured in `C:\Users\charl\.gemini\config\mcp_config.json` (`cmd.exe /c cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat`). Open Studio windows: merged Lobby/Main place `[ 🔥] Draft Duels` (`game.Name`: `[ 🦃] Draft Duels`, `PlaceId = 71551303511506`, `UniverseId = 10772880160`, `Edit`, `AuthorityMode = Automatic`, `StreamingEnabled = true`, `TestMode = false`) and read-only RIVALS reference (`rivals file updated without DMCA @CLSTUDIO.rbxl`, not inspected). Retired Match place `133387545285290` is closed. |
| **Blender MCP (`blender-mcp`)** | **Connected (wired & read-only verified 2026-11-22)** | Owner approved staying in the running Blender 5.2 instance (`PID 54904`, port `9876`, official Blender Foundation MCP extension). Added `"blender"` (`C:\Users\charl\blender_mcp\mcp\.venv\Scripts\blender-mcp.exe`, `127.0.0.1:9876`) to `C:\Users\charl\.gemini\config\mcp_config.json`. Read-only scene summary confirmed: `<unsaved>`, scene `Scene`, 3 objects (`Camera`, `Cube`, `Light`) in `Collection`. Nothing modified. |
| **Local CLI checks** | **Verified** | `rojo build default.project.json` exits `0` (built outside repo). `stylua --check src` exits `1`. `selene src` exits `1`. |

### Proposed Blender MCP config (not added yet)
Target file: `C:\Users\charl\.gemini\config\mcp_config.json` (under `"mcpServers"`):
- **Option A (Recommended — matches your installed Blender 5.2 official extension):**
  ```json
  "blender": {
    "command": "C:\\Users\\charl\\blender_mcp\\mcp\\.venv\\Scripts\\blender-mcp.exe",
    "args": [],
    "env": {
      "BLENDER_MCP_HOST": "127.0.0.1",
      "BLENDER_MCP_PORT": "9876"
    }
  }
  ```
  *(Or set `BLENDER_MCP_PORT` to a dedicated port such as `"9898"` if keeping Claude on `9876`.)*
- **Option B (Switch to `ahujasid/mcp-for-blender` via `uvx`):** requires disabling the official Blender 5.2 extension on `9876` and running `uvx mcp-for-blender install-addon`, then adding:
  ```json
  "blender": {
    "command": "cmd.exe",
    "args": ["/c", "uvx", "blender-mcp"],
    "env": {
      "BLENDER_HOST": "localhost",
      "BLENDER_PORT": "9876"
    }
  }
  ```

---

## Skill map

### Project skills (`.claude/skills/` and `.agents/skills/`)
- `gauntlet-vault`: Maps every Glitched Gauntlet task to project vault notes, LihFolk folders, and lean lookup rules — **load first on every task**.
- `gauntlet-build-style`: Enforces faceted hard-surface rules (no curves/spheres, angled plates, carved ends, lighting, rejected list) — **every map, lobby, prop, weapon, or Blender task**.
- `gauntlet-model-joins`: Enforces union-before-bevel, seated details, and close-up join renders (only in `.claude/skills/`, missing from `.agents/skills/`) — **every multi-part model or kit piece**.
- `gauntlet-ui-style`: Soft Edge v4.1 UI shape language, slots, motion, and anti-AI rules — **every HUD, menu, SurfaceGui, mobile UI, or Figma task** *(font note lags Rubik Heavy/Bold)*.
- `rivals-reference`: Study-don't-copy rules and paths for the read-only RIVALS reference place — **whenever referencing RIVALS layouts, maps, lobby, UI, rigs, guns, or VFX**.

### Active Blender skills (`~/.claude/skills/` + `~/.codex/skills/gpt-3d`)
- `blender-director`: AAA Blender orchestrator, production briefs, and reference-match loop — **start here before any Blender asset work**.
- `gpt-3d`: Codex router for grapeot's 3D workflows (referenced in `AGENTS.md`) — **when running matched-view or Codex-routed Blender tasks**.
- `blender-modeler`: Core non-destructive Edit Mode, modifier stack, collections, and mesh cleanup — **all Blender blockouts and mesh modeling**.
- `hard-surface`: Mechanical/weapon/industrial boolean, bevel, panel-line, and weighted-normal workflows — **weapons, skins, lobby fixtures, and mechanical map props**.
- `prop-artist`: Real-world-scale everyday/hero prop modeling and kitbash standards — **non-sci-fi map/lobby props (carts, crates, benches, tools)**.
- `materials`: PBR/stylized master materials and vertex-color masks — **Blender shading setup and lookdev previews**.
- `uv-workflow`: Seam placement, texel density, packing, and shared atlases — **any textured weapon skin, prop atlas, or baked asset**.
- `texture-workflow`: High-to-low baking (normal/AO/curvature) and atlas optimization — **when baking details or building shared texture atlases**.
- `asset-optimization`: Polycount, manifold, transform, and draw-call pre-export gate — **before exporting any Blender asset to Roblox**.
- `export-pipeline`: FBX/GLTF/OBJ scale, axis, pivot, and animation export verification — **every Blender → Studio export**.
- `qa-review`: Screenshot-backed ship/no-ship QA checklist gate — **before delivering any Blender asset or render**.
- `lookdev`: Grey-pass → material → lighting → screenshot comparison loop — **iterating on weapon skin or thumbnail shading**.
- `lighting`: Three-point, HDRI, and mood lighting rigs in Blender — **launch thumbnails, icon renders, and lookdev shots**.
- `animation`: Blocking, splining, Graph Editor, and NLA animation cycles — **weapon viewmodel, melee, or third-person character animations**.
- `rigging`: Armatures, IK/FK, constraints, and weight painting — **rigging viewmodel arms, skinned characters, or animated weapon parts**.
- `genre-shooter`: FPS/TPS sightline, cover, and camera-height art direction — **map/arena blockout and weapon silhouette checks**.
- `scene-assembly`: Multi-collection linking and large-set outliner organization — **assembling full thumbnail scenes or multi-piece prop kits**.
- `stylized-style`: Non-photoreal shape language, color harmony, and NPR guidance — **secondary to `gauntlet-build-style` (never override faceted rules)**.
- `collision-proxy`: Convex/box collision proxy authoring (UCX/Unity-oriented) — **rarely needed (Roblox uses simple Part colliders or Hull/Box)**.
- `lod-pipeline`: Manual LOD0–LOD3 mesh chains — **rarely needed (Roblox auto-generates mesh LODs)**.
- `geometry-nodes`: Parametric node groups and scatter systems — **occasional procedural arrays/pipes only (never purposeless scatter)**.
- `procedural-modeling`: Parametric rocks, cables, pipes, and panels — **only repetitive structural pieces (not hero props)**.
- `sculpting`: Multires/Dyntopo organic sculpting — **rarely needed (only organic damage/creatures, never faceted hard-surface)**.
- `retopology`: Quad-dominant retopo for deforming meshes — **only after organic sculpting/character mesh work**.
- `vfx-fx`: Blender smoke/sparks/ribbons and flipbook baking — **only if baking custom VFX flipbooks or thumbnail FX**.
- *(Disabled in `~/.claude/skills-disabled/` per owner 2026-11-21)*: `environment-artist`, `lowpoly-style`, `roblox-map-builder`, `set-dressing` — **keep disabled** (caused purposeless clutter and cheap PS1-style models).

### LihFolk skills (`~/.claude/plugins/cache/lihfolk/lihfolk/2.5.0/skills/`)
- `lihfolk`: Token-lean router (`vault.py`, `INDEX_SLIM`, `SYMPTOMS`) for 1,300+ Roblox notes — **before any non-trivial Roblox engineering, policy, or engine lookup**.
- `council-method`: Blind 1/3/5-seat multi-agent verdict rubric — **only for high-stakes launch/economy/art decisions or explicit "second opinion"**.
- `quality-score`: 0–10 weighted rubric (8.5 bar) + `.lihfolk/ledger.jsonl` loop — **when scoring built UI, VFX, models, or systems**.
- `roblox-secure-remotes`: Ordered remote validation (rate → type → range → context → lock) — **every RemoteEvent/RemoteFunction addition or audit**.
- `roblox-anti-exploit-review`: STRIDE threat modeling, combat/economy checks, Studio fuzzing — **pre-launch security audits and combat/shop reviews**.
- `roblox-datastore-safety`: `UpdateAsync` leases, retries, `BindToClose`, schema migrations, receipt idempotency — **every PlayerData/Locker/Shop persistence change or audit**.
- `roblox-monetization-compliance`: Single `ProcessReceipt`, `GetProductInfoAsync` prices, paid-random odds, fail-closed `PolicyService` — **Shop, Cases, Bundles, and Robux products**.
- `roblox-performance-audit`: MicroProfiler, memory-slope leak hunting, bandwidth, mobile budgets — **lag, memory growth, and mobile release gates**.
- `roblox-debugging`: Reproduce → isolate → bisect → verify method for desync, races, physics, and live bugs — **any non-trivial bug investigation**.
- `roblox-ui-builder`: Responsive `ScreenInsets`, clamped `UIScale`, `Activated`, gamepad focus, 7-viewport testing — **all Lobby, Match, Shop, Settings, and Mobile UI work**.
- `roblox-system-builder`: End-to-end custom system blueprint (config, server, client, remotes, saving, tests) — **building new core gameplay/progression systems**.
- `roblox-asset-import`: Roblox mesh limits (20k tris), stud scale, `PivotOffset`, collision fidelity, PBR maps — **importing any Blender FBX/GLB or texture into Studio**.
- `roblox-blender-modeling`: Roblox-tuned Blender helpers (`lihfolk_bpy`), symmetry/seating gates, GLB/FBX export — **useful reference for Roblox export gates (`gauntlet-build-style` stays in charge)**.
- `lihfolk-worldbuilding`: Macro-to-micro level layout, lighting presets, streaming, `auditWorld` — **secondary to RIVALS study + `gauntlet-build-style` for maps/lobby**.
- `lihfolk-vfx`: Budgeted client-only combat VFX timelines, readability, and replication patterns — **melee/ability/gun VFX tuning and budgets**.
- `lihfolk-sfx`: Licensed-only layered SFX, -18 LUFS normalization, SoundGroup buses, voice caps — **gun, melee, ability, and UI audio passes**.
- `lihfolk-figma`: Figma MCP / REST JSON to Roblox ScreenGui conversion — **only if exporting from the owner's Figma file (superseded by Studio mockups)**.
- `lihfolk-assets`: Catalogue search for the local LihFolk Asset Pack — **only if the external LihFolk Asset Pack is installed and needed**.
- `lihfolk-systems`: Drop-in strict Luau modules (Data, Net, Shop, Receipts) — **reference only (game already has its own Services and PlayerData)**.
- `lihfolk-tutorial`: First-60-second FTUE onboarding flows and funnels — **useful if adding new-player onboarding before public launch**.
- `lihfolk-ui`: Cartoon/simulator "Ink and Candy" UI kit — **does not apply (conflicts with tactical shooter UI)**.
- `roblox-trend-game`: 7-day viral simulator/steal-game playbook — **does not apply to a competitive shooter**.

### Roblox-dev plugin skills (`AppData/Roaming/Claude/rpm/.../skills/`)
- `new-system`: 4-piece vertical slice generator (types, server, client, registration + specs) — **scaffolding new client/server gameplay features**.
- `roblox-security`: Iron rules for remote validation, rate limiting, reach checks, and anti-exploit — **remote/combat/economy reviews (overlaps LihFolk security skills)**.
- `roblox-datastores`: `pcall` retries, `UpdateAsync` session locks, `BindToClose`, schema migrations — **persistence reviews (overlaps `roblox-datastore-safety`)**.
- `roblox-performance`: Connection cleanup, zero per-frame allocs, network batching, StreamingEnabled — **performance reviews (overlaps `roblox-performance-audit`)**.
- `roblox-ui`: Responsive Scale/constraints, `TweenService`, `CanvasGroup`, `ViewportFrame`, particles — **UI/VFX reviews (overlaps `roblox-ui-builder`; note owner bans ViewportFrames for Shop/Locker cards)**.
- `roblox-testing`: Studio-gated cheat remotes, pure-logic TestEZ specs, multi-client join-order QA — **QA harnesses and unit testing pure `shared/Util` math**.

### Measured `rbx-*` audit skills (`.claude/skills/rbx-*`, 39 checkers)
- `rbx-animation-layer-conflicts`: Finds unintended overlapping joints claimed by simultaneous animation clips — **viewmodel and third-person animation blending**.
- `rbx-animation-loop-seam`: Measures pose/velocity jumps at loop wrap points (tuned for block feet) — **idle/run/crouch loop QA**.
- `rbx-curve-easing-audit`: Audits animation easing overshoot, holds, and strike-contact speed share — **first-person melee and inspect feel passes**.
- `rbx-dual-rig-contact`: Checks maintained contact points/directions between two rigs or hands and weapon — **two-handed gun/bow grips**.
- `rbx-foot-plant-drift`: Measures integrated block-foot sole slip during planted intervals — **third-person locomotion passes**.
- `rbx-locomotion-rate-fit`: Checks in-place clip playback rate vs actual ground movement speed — **sprint/walk/crouch speed tuning**.
- `rbx-motion-breakdown`: Compares normalized animation curves with RMS/bias and HTML charts — **matching reference video timing**.
- `rbx-rig-channel-coverage`: Detects animation tracks that fail to bind to the destination rig — **third-person and viewmodel rig exports**.
- `rbx-audio-peak-audit`: Measures WAV sample peak dBFS and clipped samples — **gun, melee, and hit-sound mix headroom checks**.
- `rbx-spatial-audio-range`: Audits dBFS attenuation across listener distances — **3D gunfire, footsteps, and Mod cue rolloff**.
- `rbx-beam-span-continuity`: Finds positional gaps or width pops between adjacent Beam segments — **tracers, Tempest-Strike water ribbons, and laser VFX**.
- `rbx-effect-window-audit`: Catches trails/emitters surviving interrupted actions — **cancelled reloads, inspects, and melee swings**.
- `rbx-impact-grounding`: Checks impact VFX offset and surface-normal alignment — **bullet impacts, scorch marks, and Molly/Frost hits**.
- `rbx-particle-peak-budget`: Sweeps peak live particles under overlapping combat bursts — **3v3 gun + Mod VFX stress budgets**.
- `rbx-vfx-cue-legibility`: Audits whether critical cues survive low graphics settings — **Flash, Recon, Molly, and Overtime Zone readability**.
- `rbx-vfx-screen-overlap`: Measures target occlusion by obstructive VFX bounds — **muzzle flash and weapon-skin ADS sightline checks**.
- `rbx-vfx-texture-preflight`: Builds light/dark alpha & grid contact sheets for VFX flipbooks — **before importing any particle or flipbook texture**.
- `rbx-import-calibration`: Checks post-import mesh scale ratios and facing direction — **every Blender → Studio weapon, prop, or kit import**.
- `rbx-map-kit-audit`: Measures modular map seam gaps/twist and traversable route snags — **arena maps and Lobby V5 modular kits**.
- `rbx-prop-support-audit`: Downward-raycasts prop contact points to catch floating/buried props — **Lobby V5 and arena map props**.
- `rbx-reference-coverage`: Compares reference views against build captures with feature ledger & landmark drift — **recreating reference layouts/poses**.
- `rbx-route-clearance`: Checks avatar width/height clearance at choke stations — **arena corridors, doorways, and stairwells**.
- `rbx-spawn-travel-balance`: Compares team spawn-to-objective travel medians — **1v1/2v2/3v3 map symmetry verification**.
- `rbx-gamepad-focus-paths`: Graph-checks D-pad navigation reachability and focus traps — **console UI certification across Lobby/Draft/Shop**.
- `rbx-ui-contrast-audit`: Measures composited sRGB contrast ratios for text and states — **HUD and menu readability checks**.
- `rbx-ui-hit-bounds`: Finds interactive buttons leaving safe areas or colliding with siblings — **phone/tablet touch HUD and Lobby menus**.
- `rbx-asset-access-matrix`: Tracks normal-player vs owner asset load failures — **pre-publish check for private audio, meshes, and animations**.
- `rbx-camera-handoff-audit`: Verifies camera mode, subject, and input unlock after transitions — **death → spectate → final-kill replay → respawn**.
- `rbx-character-resource-lifetime`: Detects character-owned connections/tweens/tasks surviving respawn — **weapon, body-skin, and Mod lifecycle QA**.
- `rbx-frame-time-regression`: Compares p95 frame ms against baseline and budget — **before/after performance passes**.
- `rbx-hit-feedback-agreement`: Checks client hit feedback against server confirmation — **gunplay hitmarker/damage-number sync**.
- `rbx-instance-retention-audit`: Detects steady instance growth across repeated rounds/duels — **pad-duel and match cleanup soak tests**.
- `rbx-interaction-cardinality`: Catches duplicate or lost server commits per player intent — **Shop purchases, case opens, and draft lock-ins**.
- `rbx-movement-course`: Measures repeatable acceleration, traversal, and stopping splits — **run/slide/jump tuning**.
- `rbx-npc-stuck-recovery`: Detects bots stalling past allowed windows — **Bot Nav/Brain map QA**.
- `rbx-replication-audience`: Audits required vs forbidden recipients of replicated state — **team-only Reveals, private draft offers, spectate streams**.
- `rbx-round-transition-audit`: Detects illegal or stale server round phase transitions — **MatchService / pad-duel state machine QA**.
- `rbx-streaming-reentry`: Catches duplicate or missed client bindings across StreamingEnabled reentry — **Lobby prompts, gun displays, and jump pads**.

---

## Game quality findings

### Critical

1. **33,409 dead legacy & third-party RIVALS instances still replicate to every client in the live merged place**
   - **Where:** Live Studio place `71551303511506` (`Workspace`, `ReplicatedStorage`, `ServerStorage`).
   - **Evidence:** Read-only Studio MCP count on Edit DataModel:
     - `Workspace` has **41,035** descendants, of which only `LobbyV5` (`13,426`) is active. **27,606 instances (67.3%)** are legacy/reference containers replicating to every player: `Lobby` (V3: `8,358`), `LobbyRivals` (`5,798`), `LobbyV4Staging` (`4,740`), `SunwellStaging` (`3,784`), `Texture Pack` (`2,918`), `ShootingRangeRivals` (`1,950`), `NewQueueArea` (`33`), `Model` (`13`), `PathNew` ×3 (`12`).
     - `ReplicatedStorage` has **29,743** descendants, including a second copy of `LobbyRivals` (`5,803`, 19.5%).
     - Combined: **13,551 third-party RIVALS instances** ship in client-replicated containers (direct IP/DMCA violation of `rivals-reference` rule 1: *"We never ship their assets"*) plus massive mobile join-time and memory overhead.
     - `ServerStorage` also carries **19,179** archive/backup instances (`Archive`: `14,175`, `PlateMigrationBackup`: `3,176`, `LobbyKit`: `1,844`, `MapKit`: `751`, `Greybox`: `80`, `RivalsPropTemplates`: `79`, `V5Kit`: `76`, `SW1Data`/`V4Data`/`V3Data`: `52`, `LoadingAudition`: `10`).

2. **Monetization compliance: zero `GetProductInfoAsync` calls (hard-coded Robux prices) + un-gated paid random items on Coin Packs 4–6 & Starter Bundle**
   - **Where:** `src/shared/Config/Products.luau:4, 28–97`, `src/lobby/shared/ShopCatalog.luau:122, 138, 168`, `src/lobby/client/Controllers/ShopController.luau:737, 1158, 1487, 1526–1585`, `src/lobby/server/Services/RobuxService.luau:85–88, 257–278, 327`.
   - **Evidence:**
     - Grep across all 446 files in `src/` found **0 calls** to `MarketplaceService:GetProductInfoAsync`. `ShopController` displays hard-coded numbers (`bundle.robux`, `pack.robux`, `starter.robux`, `DailyRoll.price`), violating Roblox regional pricing / Dynamic Price Check rules (`roblox-monetization-compliance` §4).
     - `Products.luau:46–68, 88–92` include `CaseStandard` / `CaseElite` / `CaseApex` inside Robux Coin Packs 4–6 and the Starter Bundle, making them paid random items. Yet `ShopController.luau:1526–1600` has **no "Odds" disclosure control** on Coin Packs 4–6 or Starter Bundle, and `RobuxService.luau` never replicates `ArePaidRandomItemsRestricted` to the client — restricted players see "+ A STANDARD CASE" (`ShopCatalog.luau:172`), pay Robux, and silently receive substitute coins only after paying.
     - `RobuxService.luau:86` calls `PolicyService:GetPolicyInfoForPlayerAsync` synchronously inside `processReceipt` with **0 retries**; a transient API error permanently replaces an eligible buyer's paid bonus case with coins.

### High

3. **Shared-product skin purchase intent race condition in `RobuxService`**
   - **Where:** `src/lobby/server/Services/RobuxService.luau:106–137, 294–314, 361–369`.
   - **Evidence:** All standalone/daily skins at a given price share one Developer Product ID (`Products.SKIN_BY_PRICE[349/449/649]`) and rely on `data.buys.intents[tostring(product.id)]` to identify which skin to grant. However, `PromptProductPurchaseFinished` clears `skinPromptOpen[player] = nil` (line 366) immediately when the client dialog closes — **before `ProcessReceipt` runs**. A player buying two skins at the same price tier back-to-back can overwrite `data.buys.intents[productId]` before the first `ProcessReceipt` executes, causing the wrong skin or fallback coins to be granted.

4. **Studio playtests write directly to the live production `LockerV1` DataStore**
   - **Where:** `src/shared/Locker.luau:20` vs `src/shared/PlayerData.luau:78`.
   - **Evidence:** `PlayerData.STORE` properly isolates Studio (`if RunService:IsStudio() then "PlayerDataV1_Studio" else "PlayerDataV1"`), but `Locker.STORE = "LockerV1"` has no `IsStudio()` suffix. Any Studio test with API access enabled mutates live `LockerV1` keys (violates `roblox-datastore-safety` hard rule). Also in `src/lobby/server/Services/PlayerDataService.luau:259–271`, `writeSettings` constructs a new-save table without `prog = data.prog`, and `BindToClose` (lines 354–359) lacks a Studio fast-exit check.

5. **Design vs. code drift: Operator does not 1-shot on body/legs; Ruin-Blighted bundle missing Knife; conflicting `ShopCatalog.ITEM_ROBUX`**
   - **Where:** `src/shared/Config/Weapons.luau:802` vs [00 Home.md](../00%20Home.md#L171); `src/lobby/shared/ShopCatalog.luau:120–134, 184` vs `src/shared/Config/Economy.luau:58–64` and `src/shared/Config/Products.luau:95–97`.
   - **Evidence:**
     - Locked decision (`00 Home.md:171`): *"the Operator alone kills in one shot anywhere, except through a wall"* (150 HP+shield). Actual code (`Weapons.luau:802`): `damage = { body = 95, head = 155, legs = 76 }` — neither body nor legs even kill a 100-HP unshielded target in one shot.
     - `ShopCatalog.luau:120–134`: `RuinBlighted` bundle advertises `"5 EXCLUSIVE SKINS"` and lists 5 guns, omitting the 6th item (**Ruined Reaver / Knife**), which is documented as installed and part of the 6-item line in `00 Home.md:33, 61, 75`.
     - `ShopCatalog.luau:184` defines `ITEM_ROBUX = { Skin = { Common = 249, Rare = 349, Epic = 479, Legendary = 599 } }`, which disagrees with `Economy.SKIN_ROBUX` (`199 / 349 / 449 / 649 / 499`) and `Products.SKIN_BY_PRICE` (`349 / 449 / 649`).

### Medium

6. **CI formatting and lint checks currently fail (`stylua` and `selene`)**
   - **Where:** `src/lobby/client/Controllers/BattlePassController.luau:496` and `src/lobby/client/Controllers/PlayMenuController.luau:215`.
   - **Evidence:** `stylua --check src` exits `1` (line 496 exceeds line width). `selene src` exits `1` (`error[undefined_variable]: Content is not defined` at `Content.fromUri(art.Image)` — repo's Selene Roblox std lacks the `Content` global).

7. **Retired font (`GothamBlack` → Montserrat) & hard-coded UI values in `RangeController`**
   - **Where:** `src/client/Controllers/RangeController.luau:86, 120`.
   - **Evidence:** Hard-codes `Enum.Font.GothamBlack` (retired by Roblox; falls back to Montserrat, explicitly rejected as a generic "AI font" in `gauntlet-ui-style` and `Style Bible`) instead of `Config/UiStyle` / `Config/Theme` Rubik.

8. **Per-frame allocations in client loops**
   - **Where:** `src/client/Controllers/FootstepController.luau:174–196` and `src/lobby/client/Controllers/PlayMenuController.luau:385–409`.
   - **Evidence:** `FootstepController` runs every `Heartbeat` calling `Workspace:FindFirstChild("Dummies")` and `dummies:GetChildren()` (allocating a new array every frame) plus `Players:GetPlayers()`. `PlayMenuController`'s `updateBar` runs at 60 Hz via `Heartbeat` formatting the 1-second timer string every frame (only the spinner rotation needs per-frame updates).

9. **Un-rate-limited remote & documented client-spread exploit surface**
   - **Where:** `src/server/Bots/MatchPlan.luau:227` and `src/server/Services/WeaponService.luau:941–943`.
   - **Evidence:**
     - `MatchReady` (`MatchPlan.luau:227`) has no `RateLimit` guard (safe once ready due to `if not MatchPlan.isReady(player)`, but violates `CLAUDE.md` rule 3 requiring every remote handler to rate-limit).
     - **Authority note:** Core combat authority is well-built (server checks finite vectors, origin-to-head distance + wall LOS, ammo, cadence, rewind hitboxes, damage, and Mod charges/stun/lock). Because the owner intentionally set `Workspace.AuthorityMode = Automatic` (`00 Home.md:184`), `WeaponService.luau:941–943` clamps client-claimed `p.spread` to `0..45°` — meaning a modified client can send `spread = 0` for laser accuracy while jumping/running until the parked anti-cheat is built. (Flagged as a known exploit surface, not a bug in the owner's `AuthorityMode` choice.)

### Low

10. **Dead/unreferenced helper & stale comments**
    - **Where:** `src/lobby/client/Util/Thumb.luau:47–48` (`Thumb.model` creates a `ViewportFrame`, 0 direct callers across `src/`); `src/lobby/client/Controllers/ShopController.luau:4–6` (header comment still says *"UI only... every buy shows 'coming soon'"* despite Step 3 Robux and Ticket buying being live).

---

## Usage-waste findings

### Large savings

1. **`vault/00 Home.md` is 67.7 KB (listed as `13 KB` in `INDEX.md`) with 50.0 KB of unpruned Status history and internal contradictions** *(Saving: Large)*
   - **Evidence:** `00 Home.md` has 189 lines / 67.7 KB; `Status` alone is 116 lines / 50.0 KB going back to `2026-11-12` despite `CLAUDE.md:68` requiring older entries to move to `Status History.md`. Its `Locked decisions` table also contradicts itself: line 167 says *"Keep the separate Lobby and Match places... Lobby V4"* and line 188 says *"Server Authority on"* while line 31 says *"Place merge done: one game, one place"* and line 184 says *"Server Authority is OFF"*; line 185 says *"one currency, Coins"* while line 187 says *"two currencies: Coins and Tickets"*.
   - **Fix:** Move Status entries older than the last ~7 milestones to `Status History.md` and prune superseded paragraphs in `Locked decisions` (cuts `00 Home.md` from 67.7 KB → ~12 KB).

2. **27 "size-trap" entries in `vault/INDEX.md` are listed `<15 KB` when they are 15–95 KB (+ 14 unlabeled ≥15 KB notes, 105 notes ≥15 KB total = 3,494 KB / 67% of vault)** *(Saving: Large)*
   - **Evidence:** Agents rely on `INDEX.md` sizes to obey the "never read >15 KB whole" rule, but major working notes grew 3–12× without updating `INDEX.md`:
     - `02 Art/Lobby V5 Plan.md`: listed `12` → actual **95.4 KB**
     - `05 Production/Overnight 2026-11-20 Animation Pass.md`: listed `6` → actual **74.9 KB**
     - `00 Home.md`: listed `13` → actual **67.7 KB**
     - `04 Tech/Code Map.md`: listed `10` → actual **63.5 KB**
     - `05 Production/Weapon RemasterV2.md`: listed `6` → actual **53.8 KB**
     - `02 Art/Lobby V4 Build.md`: listed `8` → actual **38.5 KB**
     - `02 Art/Lobby V3 Rebuild.md`: listed `11` → actual **32.3 KB**
     - `04 Tech/UI Architecture.md`: listed `10` → actual **31.0 KB**
     - `02 Art/Ability VFX Direction.md`: listed `5` → actual **27.5 KB**
     - `02 Art/UI Polish Pass.md`: listed `8` → actual **26.3 KB**
     - `01 Design/Inventory and Crates.md`: listed `7` → actual **24.0 KB**
     - `02 Art/UI Settings.md`: listed `4` → actual **23.8 KB**
     - `02 Art/Sunwell Works Build.md`: listed `9` → actual **23.4 KB**
     - `02 Art/UI Locker.md`: listed `4` → actual **22.4 KB**
     - `02 Art/UI Mobile Controls.md`: listed `5` → actual **22.2 KB**
     - `04 Tech/Place Merge Plan.md`: listed `5` → actual **21.1 KB**
     - `01 Design/Maps/Foundry4.md`: listed `11` → actual **20.2 KB**
     - `01 Design/Maps/Rooftops4.md`: listed `12` → actual **19.4 KB**
     - `01 Design/Maps/Metro4.md`: listed `12` → actual **19.3 KB**
     - `05 Production/Handoff - Stability, Loading and Preload.md`: listed `6` → actual **19.0 KB**
     - `05 Production/Bugs & Ideas.md`: listed `4` → actual **18.3 KB**
     - `02 Art/UI Lobby HUD.md`: listed `5` → actual **18.3 KB**
     - `01 Design/Maps/00 Maps.md`: listed `9` → actual **17.9 KB**
     - Plus largest overall notes (≥40 KB): `01 Design/Archive/Gauntlet_Weapon_Modeling_Briefs.md` (**102.4 KB**), `01 Design/Third Person Overhaul.md` (**98.0 KB**, listed `19`), `01 Design/Maps/Rooftops2.md` (**91.9 KB**), `05 Production/Status History.md` (**91.6 KB**, listed `42`), `06 Assets/Asset Tracker.md` (**84.0 KB**, listed `47`), `02 Art/Sound Library Pick.md` (**81.5 KB**, listed `23`), `01 Design/Maps/Dockyard2.md` (**73.4 KB**), `05 Production/Playtests/2026-11-05 Knife and Sound Pass.md` (**63.9 KB**), `03 Research/Design Research Report.md` (**60.3 KB**), `01 Design/Lobby UI and Queue.md` (**58.5 KB**), `01 Design/Gunplay.md` (**54.2 KB**), `03 Research/Notes/gun_system_tech.md` (**48.9 KB**), `03 Research/Notes/matchmaking_queues.md` (**48.6 KB**), `02 Art/Skins/Blender Review.md` (**46.8 KB**, no size label), `02 Art/References/lobby/sunwell-works/Generation Prompts.md` (**45.0 KB**), `05 Production/Playtests/2026-11-15 Gunplay Overhaul.md` (**43.3 KB**, listed `9`), `05 Production/Playtests/2026-11-13 Hit Feedback Pass.md` (**41.0 KB**, listed `8`).
   - **Fix:** Add a tiny Python script to auto-refresh `(KB)` labels and flag unindexed notes in `vault/INDEX.md`.

3. **`AGENTS.md`, `CLAUDE.md`, `Developer Handoff.md`, and `.agents/skills/` vs `.claude/skills/` contradict each other** *(Saving: Large)*
   - **Evidence:**
     - `AGENTS.md:3, 14–15` and `Developer Handoff.md:3, 31–109` still instruct *"two places"*, *"Lobby V4 is the release target"*, *"two Rojo projects"*, *"StarterGui templates"*, and Match place `133387545285290` — contradicting the 2026-11-21 single-place merge (`default.project.json` on `34873`, Lobby `71551303511506`, Lobby V5, `StarterGui` empty / `UiRoot` in `PlayerScripts`, title "Draft Duels").
     - `CLAUDE.md` still cites `"1v1 → 4v4"`, `Sarpanch + Titillium Web`, and `.claude/skills/`.
     - `.agents/skills/` has 4 heavily abridged copies (1.1–2.5 KB vs 5–13 KB in `.claude/skills/`) and is **missing `gauntlet-model-joins`** completely; meanwhile `.claude/skills/gauntlet-ui-style` still names **Fredoka One** instead of **Rubik Heavy/Bold** (`Style Bible.md:51`, `Config/Theme.luau:17`).
   - **Fix:** Update `AGENTS.md` and `Developer Handoff.md` to the single-place Draft Duels reality, sync `gauntlet-model-joins` into `.agents/skills/`, and keep one canonical source per project skill.

4. **`vault/04 Tech/Code Map.md` grew to 63.5 KB (listed `10 KB`) and has lookup gaps** *(Saving: Large)*
   - **Evidence:** 244 dense lines (63.5 KB). Missing 3 Match Controllers (`AmbienceController`, `FootstepController`, `TeammateBillboardController`), 3 Shared Configs (`ShadowMistAudio`, `TouchControls`, `UiPlates`), and remotes `MatchReady` (`Net.luau`) and `Queued` (`LobbyNet.luau`).
   - **Fix:** Split into a compact ~8 KB `Code Map.md` (path → 1-line ownership) + `Remotes and Attributes.md` reference, and fill the 8 missing entries.

### Medium savings

5. **Overlapping superseded vault notes (~610 KB of old Lobby & Map versions) and duplicate memory note** *(Saving: Medium — propose merges/archives, not executed)*
   - **Lobby cluster (~278 KB across 9 notes):** `01 Design/Lobby.md`, `02 Art/Lobby Art Plan.md`, `Lobby Rebuild 2026-11-04.md`, `Lobby V3 Rebuild.md`, `Sunwell Works Build.md`, `Sunwell Hub Upgrade.md`, `Lobby V4 Build.md`, `Lobby V4 Plan.md`, `Lobby V5 Plan.md` (95.4 KB) → archive V1–V4/Sunwell under `02 Art/Archive/Lobby/` and extract a lean `Lobby V5 Current.md`.
   - **Map iteration cluster (~360 KB of deleted maps):** `Rooftops.md` + `Rooftops2.md` (91.9 KB), `Dockyard2.md` (73.4 KB), `Metro.md` + `Metro2.md`, `Greenhouse.md` + `Greenhouse2.md`, `Old Town.md`, `Snowpeak Lodge.md` → move superseded iterations to `01 Design/Maps/Archive/` so greps hit only the 12 active rotation maps.
   - **UI cluster:** Archive superseded v1/v4.0 drafts (`UI Design.md`, `UI Overhaul Research.md`) and keep `Style Bible.md` + `UI Architecture.md` as the two entry points.
   - **Claude memory duplicate:** `map-build-checks-only.md` and `maps-build-checks-only.md` in `~/.claude/projects/.../memory/` duplicate each other — merge into one.

6. **Unused and overlapping skills across Blender, LihFolk, and `roblox-dev`** *(Saving: Medium)*
   - **Keep disabled (`~/.claude/skills-disabled/`):** `environment-artist`, `lowpoly-style`, `roblox-map-builder`, `set-dressing` (owner 2026-11-21).
   - **Recommend disabling for this project:**
     - LihFolk: `lihfolk-ui` (cartoon simulator kit), `roblox-trend-game` (wrong genre), `lihfolk-systems` (game has its own Services/PlayerData), `lihfolk-assets` (if external Asset Pack isn't used).
     - Blender: `sculpting`, `retopology`, `lod-pipeline` (Roblox auto-LODs), `collision-proxy` (UCX/Unity-oriented), `vfx-fx`, `geometry-nodes`, `procedural-modeling` (keep in `skill-library`, remove from active `~/.claude/skills/`).
     - `roblox-dev` duplicates: `roblox-security`, `roblox-datastores`, `roblox-performance`, `roblox-ui` (all superseded by deeper LihFolk equivalents; keep `roblox-testing` and `new-system`).
   - **Leave active:** all 5 project skills, `blender-director`, `gpt-3d`, core Blender modeling/export/render skills (`blender-modeler`, `hard-surface`, `prop-artist`, `materials`, `uv-workflow`, `texture-workflow`, `asset-optimization`, `export-pipeline`, `qa-review`, `lookdev`, `lighting`, `animation`, `rigging`, `genre-shooter`, `scene-assembly`), core LihFolk skills, and on-demand `rbx-*` checkers.

### Small savings

7. **Unused Daily Log habit & mixed `INDEX.md` formatting** *(Saving: Small)*
   - **Evidence:** `vault/05 Production/Daily Log/` has only one entry (`2026-10-26.md`, 2.7 KB). `INDEX.md` (39.8 KB) mixes backtick bare filenames (54 relative names that don't include folder paths) with Markdown links, making automated verification noisy.

### Applied usage-savings pass (2026-11-22)
Per owner approval, the usage-savings pass was applied without touching Studio or `src/`:
- Pruned `vault/00 Home.md` from **67.7 KB → ~11 KB** (37.0 KB of 2026-11-12..21 status entries preserved verbatim at the top of `vault/05 Production/Status History.md`; `Locked decisions` contradictions resolved).
- Updated `AGENTS.md` and `vault/04 Tech/Developer Handoff.md` to the single merged place (`71551303511506`, Draft Duels, Lobby V5, `UiRoot`).
- Added missing `.agents/skills/gauntlet-model-joins/SKILL.md`, refreshed `.agents/skills/` pointers, and fixed the stale Fredoka One font line in `.claude/skills/gauntlet-ui-style/SKILL.md`.
- Patched all 8 missing entries and stale notes in `vault/04 Tech/Code Map.md`.
- Added `tools/vault_index_sizes.py`, refreshed **114** `(KB)` labels in `vault/INDEX.md` (0 remaining `<15 KB` size traps), and tagged superseded Lobby V1–V4 / Sunwell notes as `[SUPERSEDED by Lobby V5]`.
- Merged duplicate Claude memory `maps-build-checks-only.md` into `map-build-checks-only.md`, and moved 7 non-fitting Blender skills (`sculpting`, `retopology`, `lod-pipeline`, `collision-proxy`, `vfx-fx`, `geometry-nodes`, `procedural-modeling`) to `~/.claude/skills-disabled/`.

---

## Recommended next 5 actions

1. **Strip legacy & third-party RIVALS containers from live place `71551303511506` before publishing:** Export backups to local `.rbxm` outside the repo, then remove `Workspace.LobbyRivals`, `Workspace.ShootingRangeRivals`, `ReplicatedStorage.LobbyRivals`, `Workspace.Lobby` (V3), `LobbyV4Staging`, `SunwellStaging`, `Texture Pack`, and `ServerStorage` archives/backups (~52.5k instances cut, removing IP risk and ~47% of client-replicated bloat).
2. **Fix monetization compliance & Robux race before real Robux testing:** Fetch live prices with `MarketplaceService:GetProductInfoAsync` in `ShopController`; replicate `PolicyService` `ArePaidRandomItemsRestricted` on join (with retries) to hide "+Case" for restricted players and add "Odds" disclosures on Coin Packs 4–6 & Starter Bundle; keep `skinPromptOpen` locked until `ProcessReceipt` completes (or move each skin to its own product / append-only intent queue).
3. **Fix Studio `LockerV1` isolation + Operator / Ruin-Blighted / lint defects:** Add `RunService:IsStudio()` suffix to `Locker.STORE` (`LockerV1_Studio`), resolve Operator body/leg damage (`95/76` vs locked 1-shot-anywhere), add Ruined Reaver or confirm 5-item Ruin-Blighted scope, reconcile `ShopCatalog.ITEM_ROBUX` with `Economy`/`Products`, fix `BattlePassController` formatting, update Selene std for `Content`, and replace `GothamBlack` in `RangeController`.
4. **Finalize Blender MCP wiring for Antigravity:** Confirm whether Antigravity should connect to your existing official Blender 5.2 MCP (`blender-mcp.exe` on `9876` or a dedicated second port) rather than installing the conflicting `ahujasid/blender-mcp` add-on.
5. **Run the vault hygiene pass (large token savings):** Prune `00 Home.md` Status to the last ~7 bullets & clean its contradictory Locked decisions, update `AGENTS.md` / `Developer Handoff.md` to the merged single-place Draft Duels reality, sync `gauntlet-model-joins` into `.agents/skills/`, refresh `INDEX.md` KB sizes, and archive superseded Lobby V1–V4 & Map v1–v3 notes.

---

## Open questions for the owner

1. **Blender MCP port & protocol:** Since Blender 5.2 is already running the official Blender Foundation MCP on port `9876` with Claude (`PID 13608`) active, should I wire Antigravity to your existing official `blender-mcp.exe` (and on port `9876` or a second port like `9898`), or do you want to replace it with `ahujasid/mcp-for-blender` (`uvx blender-mcp`)?
2. **Operator 1-shot rule:** Should `Config/Weapons.luau` Operator damage return to `>= 150` body/legs to match the locked 1-shot-anywhere rule in `00 Home.md`, or was `95 / 76` an intentional balance change that should update the locked decision?
3. **Ruin-Blighted bundle scope:** Should `ShopCatalog.luau` include the 6th item (**Ruined Reaver / Knife**) in the 999 R$ Ruin-Blighted bundle, or is the knife intentionally excluded / sold separately?
4. **Legacy & RIVALS containers in `71551303511506`:** Are you ready for a cleanup script to export `.rbxm` backups and delete `LobbyRivals`, `ShootingRangeRivals`, `Lobby` (V3), `LobbyV4Staging`, `SunwellStaging`, and `Texture Pack` from the live place before your soft-launch publish?
