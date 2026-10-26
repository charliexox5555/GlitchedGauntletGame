# 🏠 Home

**Working title:** GlitchedGauntletGame (final name TBD: see [Game Plan](05%20Production/Game%20Plan.md) §1)
**One-liner:** RIVALS-style run-and-gun duels (1v1 → 4v4) where you **draft abilities ("Mods") every round** and every round opens a new **weapon tier**. Scheduled 16-player Gauntlet events come later.

---

## 📍 Status
> Update this block at the end of every work session (Claude does it when asked).

- **Phase:** Week 1 — "Find the fun" (prototype)
- **Done:** research · game plan · weapon roster · art style (Style B) · all gun models in Blender · repo + Rojo scaffold · this vault · toolchain checks · `main` branch · Studio MCP connected · place setup (StreamingEnabled, `ImportStaging`, first person FOV 80)
- **Done (2026-10-25 overnight):**
  - All 24 guns exported, uploaded (Open Cloud, group-owned), built to the model standard in `ReplicatedStorage.Weapons`, validated, `.rbxm` backups in `art-source/weapons/Studio/`
  - Gun system for wave 1 (Byte, Root, Bandwidth, Hard Reset, Long Poll, Bitrate, Flood, Ray Trace, Cutter): server-validated hitscan, pellets, falloff, head/legs, spin-up, charge, wall penetration, melee + backstab, ammo/reload
  - Movement: sprint, crouch, slide, slide-jump (Input Action System; keyboard, gamepad, touch buttons)
  - First-person viewmodel with arms, ADS, scope, sway/bob/recoil and the Blender Fire/Reload animations; third-person holding pose
  - Neon muzzle flash, tracers, sparks, pixel-dissolve deaths, hit/headshot/kill markers, damage numbers, kill feed, HUD, placeholder sounds
  - Studio test range: armed dummies (one strafing), a solid wall and a ThinWall
- **Done (2026-10-25):** all 23 weapons playable and tested vs dummies (burst, Loopback discs, Null beam + battery, Dual Boot two-gun viewmodel, move/crouch spread) · Studio dev weapon menu (**P**) · third-person poses as real uploaded animations (gun hold blended by aim pitch, sprint carry, crouch / crouch-walk, slide), played in the Server Authority simulation so everyone and the server hitboxes see them
- **Done (2026-10-25, viewmodel rebuild):** first-person arms are blocky arms in the player's own shirt (classic Shirt template) and skin colours, IK'd onto the grips every frame; the left hand follows the mag / pump / bolt / cylinder / barrels during the gun's clips · keyframed equip, inspect (**F**, melee has its own flip), reload body motion, and spring-blended sprint/slide/crouch/air poses · clean ADS on every gun (stocks fade, holo reticles on Ray Trace / Loopback / Null, reticles in Checksum's and Mute's optics, closer pistol ADS) · details in [Gunplay](01%20Design/Gunplay.md) §6
- **Done (2026-10-25, weapon VFX):** all shot effects rebuilt on a Blender-rendered texture set (`tools/vfx/`, ids in `Config/VfxTextures`): flipbook muzzle flashes (front star; side flame in third person; small puff when suppressed) with smoke and a light pop · travelling Beam tracers (none when suppressed) · impacts with sparks, surface-coloured dust and chips, and pooled bullet holes with a cooling neon rim · brass and shotgun shells from `Eject` · Ray Trace charge glow and twisting rail · textured Null beam · glowing spinning Loopback disc · hologram-flash + pixel dissolve on death · kill edge flash · camera shake on fire. Pooled, 60 fps under sustained Flood fire. Details in [Art Direction](02%20Art/Art%20Direction.md) → VFX
- **Done (2026-10-25, hit feedback):** hit markers pop with a rotation kick and always fade out fully (the old outline no longer lingers) · damage numbers sit on the target, stack, then fall off in an arc · cyan kill X with a ring and an "ELIMINATED" banner that counts up streaks
- **Done (2026-10-25, viewmodel pass 2):** first-person stutter fixed at the root (camera followed Server Authority's uneven predicted steps; it now follows a smoothed position) · arms are smooth RIVALS-style blocks (one bevelled block per arm, skin colour + the player's Shirt), entering the grips from below so the gun always reads in front; guns ~25% bigger; pistols big and centred · every viewmodel part anchored and hand-posed (no physics) · bigger, closer gun · ADS hides only parts that really block the sight line, and keeps a gentle sway/bob/breathing so the sights move like RIVALS
- **Done (2026-10-25, viewmodel pass 3):** walking/sprinting shake fixed (zero mispredictions measured; the camera follow filter used jittery frame dt) · rifles in a diagonal hip composition (superseded by pass 4) · zoomed RIVALS-style ADS with tighter FOV
- **Done (2026-10-25, viewmodel pass 4, rebuild):** one rigid rig (camera × motion → gun pose → hands in gun space), so the gun and arms move as one · each viewmodel part lives in a WorldModel (Server Authority's Workspace snaps part positions by up to 0.006 studs, which made every part jitter on its own) · primaries point straight down the view like RIVALS; pistols two-handed with a high grip, placed by the grip · smooth figure-8 bob, breathing, sway, tilted sprint carry, all frame-rate independent · measured walking: peak acceleration 116 → 2.3 studs/s², arm-vs-gun drift 0.013 → < 0.00001 studs · details and numbers in [Gunplay](01%20Design/Gunplay.md) §6
- **Done (2026-10-25, viewmodel pass 5):** every gun framed like Bitrate (long guns placed by sight height at the grip, sidearms/melee/Dual Boot by the grip, scoped rifles further back; contact sheet of all 23 in `02 Art/References/rivals-viewmodel/viewmodel-all-23-hip.jpg`) · aimed recoil keeps the sight on target (rises ≤ 0.3°, snappy push back) · strafing sways the gun and the sights follow (aimed: ≤ 1.2° drift, eases back) · iron sights left as they are (moving the eye back made them worse)
- **Done (2026-10-25, combat audio):** gun sounds re-done from the real CC0 recordings: polished (no longer dull) and given an identity per class (machine guns use real full-auto shots, snipers the big bolt rifles), 3 variants per gun plus a duller enemy version, a new atlas (asset 105241531021545). New `AudioController`: pooled voices, SoundGroup mix (your gun / enemies / hit feedback / foley, master limiter), random pitch, low-ammo tick, bolt or pump after each shot, damage-taken thud, separate headshot-kill sound. A layered synth version was tried and rejected; stay with real recordings. Details in [Art Direction](02%20Art/Art%20Direction.md) → Audio
- **Done (2026-10-25, test range for testers):** publishable test mode. The Workspace attribute **`TestMode`** (a checkbox: Workspace → Properties → Attributes) turns a server into the test range; it is ON in the place now. The range is built from code (`src/server/TestRange/`, backup `art-source/maps/TestRange.rbxm`): an enclosed Style B hall with 7 lanes and distance markers (10/25/50/100/150), a cover section (ThinWall, solid wall, low cover, pillars), a movement course (sprint/slide strip with distance ticks, jump boxes, 6/10/13-stud gaps, crouch walls) and an armory of 23 walk-up gun racks (E / D-pad right). Six dummy kinds (static ×4 for falloff, strafe, strafe + jump, crouch-walk, long range on a platform, a shooter that fires harmless tracers), prepared like players so every shot goes through the normal validation and rewind, with client health bars, respawn after 2.5 s, and shared toggles (move / shoot back / heal). Tester menu on **B** / D-pad up / TEST button: Loadout (any gun per slot), Range (refill, reset dummies, reset stats, behaviours), Settings (FOV 70–100, panels), Controls (keys + how to play). Stats panel with server-measured damage, last TTK (+ shots), accuracy, headshots, kills, DPS (current + peak) and the last hit's damage, zone and distance. All 23 guns picked and fired at a dummy in a Studio playtest; tester remotes security-reviewed. Details in [Architecture](04%20Tech/Architecture.md) → Test range
- **New direction (2026-10-25, decided by the user):** start mostly fresh. **Keep** the gun-holding/first-person viewmodel, sprint, crouch/slide and the gunplay system. **Remove** the sci-fi look, the old map (back to a basic map), all previous guns and the old UI. Then add guns **one at a time**, each finished properly: model (Blender) → in game with simple, realistic VFX (muzzle flare, standard gun mechanics) → professional animations (equip with cocking, reload, sprint…). No corners cut; researching existing open scripts/examples is allowed.
- **Gun 1, Vandal (2026-10-25):** default rifle, Valorant name for now. Modelled by script (`tools/blender/build_vandal.py` → `art-source/weapons/Vandal.blend`, concept `02 Art/References/vandal-concept.webp`): matte charcoal, restrained blue neon, side buddy loop, ~5.0K tris, rigged Mag / ChargingHandle / Bolt / Trigger / FireSelector / Charm. One baked 1024² PBR set for the whole gun (`tools/blender/bake_textures.py` → `art-source/weapons/Textures/Vandal_*.png`, image ids in `Exports/textures.json`), applied as a SurfaceAppearance on every non-neon part by WeaponBuilder. Fire + Reload clips by `tools/blender/anim_vandal.py` → `src/shared/WeaponAnimations/Vandal.luau`. Uploaded (asset 123991644913328).
- **Done (2026-10-25, fresh base + Vandal in game):** the gut the user approved: the 23 old guns (Studio models, config, clips; `.rbxm` backups stay in `art-source/weapons/Studio/`), the old HUD, kill feed and banner, the sci-fi VFX, pixel-dissolve deaths, the dev weapon picker, the tester menu/stats/racks, and the Projectile, Beam and Charge mechanics (with the `Charge`, `Dev`, `Tester`, `TesterStats` remotes). The **Vandal** is in `ReplicatedStorage.Weapons` (validated, backup `Studio/Vandal.rbxm`) and is the only gun: default primary with the Gunplay v2 numbers (other slots empty). **New:** plain HUD (crosshair, ammo, health, damage direction; hit marker white / amber head / red kill; damage numbers); realistic VFX (fiery flash + side flame, smoke and barrel wisps, brass, warm tracers, impacts per surface, bullet holes; textures by `tools/vfx/make_real_vfx.py`); the test range rebuilt as a plain concrete practice yard with grey dummies; handling animations: **first draw racks the charging handle**, tactical vs empty reload (empty racks), inspect with a mag tap and press check, foley timed off the clips. Inspect moved to **Y**. Playtested in Studio (draw, fire, hits/kills on dummies, empty reload, ADS sight picture, inspect; screenshots taken); remote changes security-reviewed. Details: [Gunplay](01%20Design/Gunplay.md) §5–6, [Art Direction](02%20Art/Art%20Direction.md) → VFX.
- **Now:** fresh base with the Vandal. **Save the place** in Studio (the Vandal lives in it and the old guns were deleted from it). Gunplay v2 *mechanics* (protected shots, speed-scaled move penalty, recoil pattern, step falloff) are not coded yet: the Vandal uses v2 numbers on the current spread/recoil system. Keep saving the place in Studio (guns live in it). Before publishing for testers: `TestMode` ticked, save, publish.
- **Next:** 2-player test in the test range (Studio Test → Clients and Servers, 2 players: not run yet, the MCP can't start it) → tune numbers → aim assist (touch/gamepad) → rounds + tier rotation → Mods → draft → **Playtest #1**
- **Blockers:** none. (Server Authority is on; movement and poses run in the shared simulation.)

---

## 🗺️ Map of the vault

### 01 Design: what the game *is*
- [Gunplay](01%20Design/Gunplay.md): movement, shooting feel, aim assist, feedback (RIVALS core + slide)
- [Weapons](01%20Design/Weapons.md): 22 guns + melee, tiers per round, build waves, gun mechanics
- Mods, Draft, Rounds and Maps: in the [Game Plan](05%20Production/Game%20Plan.md) §1, §4 and §5

### 02 Art: how it *looks*
- [Art Direction](02%20Art/Art%20Direction.md): Style B rules, palette, model standard, import pipeline
- [Gun Batch Prompt](02%20Art/Gun%20Batch%20Prompt.md) · [AI 3D Prompts](02%20Art/AI%203D%20Prompts.md)
- References: `02 Art/References/` (Bitrate master, style tests)

### 03 Research: *why* we decided things
- [Design Research Report](03%20Research/Design%20Research%20Report.md): the full report (shooters, draft design, matchmaking, tech, money, risks)
- Raw notes: `03 Research/Notes/`

### 04 Tech: how it's *built*
- [Setup Guide](04%20Tech/Setup%20Guide.md): install, Rojo, Obsidian, Claude, prompts
- [Architecture](04%20Tech/Architecture.md): folders, Rojo mapping, code rules

### 05 Production: *when* things happen
- [Game Plan](05%20Production/Game%20Plan.md): day-by-day plan → beta → Season 1
- `Daily Log/` · `Playtests/` · [Bugs & Ideas](05%20Production/Bugs%20%26%20Ideas.md)

### 06 Assets: what *exists*
- [Asset Tracker](06%20Assets/Asset%20Tracker.md): every gun/map/VFX and its status

---

## 🔒 Locked decisions
| Topic | Decision | Where |
|---|---|---|
| Gunplay | **v2 (2026-10-25): precise run-and-gun.** Valorant-tight first shot, tap/burst control, learnable camera recoil; light movement penalty (~1/4 of Valorant, ADS halves it); slide is the core move; head ×2.25 (rifles: 2 headshots), no tagging, body TTK 0.3–0.5 s | [Gunplay](01%20Design/Gunplay.md) |
| Rounds | First to 5, shared weapon tier per round (Sidearm → Light → Heavy → Wildcard) | [Weapons](01%20Design/Weapons.md) |
| Draft | 3 Mod slots, L1→L3, both sides draft, the loser gets +1 card and +1 reroll, mirrored offers in 1v1 | [Game Plan](05%20Production/Game%20Plan.md) §4 |
| Art | **Changed 2026-10-25:** no sci-fi look. Professional tactical guns (matte charcoal/black, PBR textures, very restrained neon accent); the Vandal is the new master reference. Style B below is retired | [Art Direction](02%20Art/Art%20Direction.md) |
| Camera | First person | [Gunplay](01%20Design/Gunplay.md) |
| Money | Cosmetics only (wraps, charms, Mod VFX), no paid random boxes | [Game Plan](05%20Production/Game%20Plan.md) §1 |
| Tech | Rojo + strict Luau, server-authoritative, Server Authority on | [Architecture](04%20Tech/Architecture.md) |
