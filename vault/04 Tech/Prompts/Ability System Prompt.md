# Prompt: Ability System + base (L1) of all 9 Mods

**How to use:** open a **new** Claude Code chat in the repo root (Rojo serving, Studio open, Studio MCP connected) and paste the box below. It works in stages and stops for you to test after each one.

```text
We're building the ability ("Mod") system for our game, plus the BASE (L1) version of all 9 Mods. Do NOT build the A/B paths or Glitch paths yet. That's the next phase, once the base Mods are fun. But design the data and code so paths and glitches plug in later without a rewrite.

READ FIRST (these are the source of truth):
- CLAUDE.md
- vault/01 Design/Mods.md   ← the 9 Mods, L1 numbers, the "Controls and activation" section (instant vs held types, held-mode rules, VFX team colours, asset list)
- vault/01 Design/Gunplay.md ← movement and controls (Mods are Q / E / C on PC; crouch/slide moved to Left Ctrl)
- vault/02 Art/Art Direction.md ← Style B look, palette, model standard, import pipeline
- vault/04 Tech/Architecture.md ← folder layout and code rules
Also inspect the current code in src/ and the open Studio place (via the Studio MCP) so you build on what exists: movement, the weapon system, whether Server Authority is on.

GOAL: it should look and feel PROFESSIONAL, like a polished hero shooter. Responsive input, clean previews, satisfying VFX and sounds, smooth first-person animations, a clear HUD, and readable for the enemy.

========================================================
ARCHITECTURE (propose it, then build it)
========================================================
- src/shared/Config/Mods.luau: ALL Mod data. Each Mod has id, name, role, activation type (Instant / HeldThrow / HeldPlace / HeldTarget), cooldown, charges and per-level stats. Structure it so that later each Mod can have levels L1 + A2/A3 + B2/B3 + G2/G3 (fill only L1 now; leave the shape ready).
- src/shared/Mods/: one module per Mod (Blink, LaunchPad, Packet, Firewall, LagField, Ping, PatchUp, Overclock, Rollback), built on shared BUILDING BLOCKS so code isn't duplicated: Dash, Projectile (throw arc), Placeable, Zone, SelfBuff, Reveal, Rewind, Beam/Target.
- Server: src/server/Services/ModService.luau: each player's 3-slot loadout, levels, cooldowns and charges (server timestamps), validation of every use request (owns the Mod, off cooldown, range, line of sight, valid placement, alive, in a round), rate limiting, applying effects, and broadcasting VFX events. The server decides everything that matters.
- Client: src/client/Controllers/ModController.luau: input via the Input Action System (Q / E / C, gamepad LB / RB / D-pad up, 3 touch buttons), a held-mode state machine (Idle → Equipping → Held → Using → Cooldown), previews (throw arc, placement hologram green/red, heal-target highlight), client prediction for instant feel, and VFX/sound playback. It talks to the weapon system to lower the gun while a Mod is held. If the weapon system has no clean API for that yet, add a minimal one.
- HUD (polished, mobile-friendly): 3 slots bottom-centre with key labels (Q E C), icon, radial cooldown sweep + seconds, charges, a "held" highlight, a ready pulse; the held-mode hint ("LMB Heal ally · RMB Heal self · Q Cancel"); a mobile arc of 3 buttons + a context button while holding.
- VFX: a shared VFX module with pooling (no creating and destroying every cast). Colours are chosen PER VIEWER: cyan #00E5FF for you and your team, orange-red #FF5A36 for enemies (glitch magenta comes later).
- DEV TEST PANEL (Studio and game owner only, server-gated): give myself any Mod in any slot, reset cooldowns, spawn a dummy enemy and a dummy teammate. The draft system doesn't exist yet, so this is how we test.
- Movement Mods (Blink, Launch Pad, Rollback) must work with our movement and Server Authority setup (predicted on the client, authoritative on the server). Check Roblox's current docs for the right approach.
- Follow every code rule in CLAUDE.md (strict Luau, validated and rate-limited remotes, config as data, no leaks, pooling). Use the roblox-dev skills if you have them (new-system, roblox-security, roblox-ui, roblox-performance) and run a security review on the remotes.

========================================================
THE 9 MODS AT L1 (details and numbers are in Mods.md)
========================================================
Instant: Blink (dash), Ping (reveal pulse), Overclock (fire-rate buff), Rollback (rewind 3 s).
Held throw: Packet (grenade), Lag Field (slow zone). LMB = throw, RMB = short lob, with an arc preview.
Held place: Launch Pad, Firewall. Hologram preview, LMB = place.
Held target (Sage-style): Patch Up. You hold a heal device. LMB = heal the teammate in your crosshair, RMB = heal yourself. In 1v1, LMB heals yourself.

========================================================
ART, VFX AND ANIMATION (make it look good)
========================================================
- Models in BLENDER, Style B (match the Bitrate rifle: chunky, bevelled, slate and near-black, cyan neon in channels, no grime): the handheld heal device, the Packet grenade, the Launch Pad, the Firewall frame + energy panel, the Lag Field orb, plus reusable VFX meshes (shockwave ring, dome/sphere, scan ring). Sources go in art-source/abilities/<Mod>/; follow the import pipeline in Art Direction and save the finished Roblox versions as .rbxm in assets/Abilities/ (Rojo syncs them to ReplicatedStorage.Assets.Abilities). Show me renders before importing.
- First-person animations: equip/raise and lower for held Mods, a throw wind-up and release, a place push, a heal-device hold idle and use, a Blink camera lunge, a Rollback "rewind" screen effect. Use procedural springs/tweens where that looks good. Where a real animation is needed (third-person throw/place/heal for other players to see), build it and tell me exactly what I need to click to save and publish it.
- Icons: 9 Mod icons in one consistent style (Style B colours), made as SVG → PNG. Tell me how to upload them, or do it if you can.
- Sounds: equip, use, impact and ready sounds for each Mod. Suggest licensed sounds from Roblox's Creator Store audio (give me search terms or IDs to approve), plus jsfxr-style digital sounds where they fit.
- Juice: screen shake on nearby explosions, a hit flash, +HP numbers on heals, a cooldown-ready ping.

========================================================
WORK IN STAGES. STOP after each one and tell me exactly what to test in Studio.
========================================================
Stage 0: Read everything, inspect the project and Studio, then give me your architecture, file list and any questions. Wait for my OK.
Stage 1: Framework: Config/Mods.luau, ModService, ModController, the building blocks, the HUD, the dev test panel. Prove it with 3 Mods: Blink (instant), Packet (held throw) and Patch Up (held target). Placeholder visuals are OK in this stage.
Stage 2: The other 6 Mods at L1 (placeholder visuals OK).
Stage 3: Art: Blender models → import → .rbxm; VFX library with team colours; icons.
Stage 4: Animations + sounds + juice + the mobile controls pass.
Stage 5: Polish: security review of all remotes, performance check (pooling, no leaks, test with 8 players), playtest checklist; update vault/00 Home.md Status, vault/06 Assets/Asset Tracker.md (add an Abilities section) and today's Daily Log; commit and push.

At each stage: run stylua and selene, commit with a clear message, and keep vault/01 Design/Mods.md in sync if any number or behaviour changes.
```
