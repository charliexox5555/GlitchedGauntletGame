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
- **Now:** gun system and first-person feel signed off by the user (2026-10-25). Keep saving the place in Studio (guns live in it).
- **Next:** 2-player test (Studio "Start" with 2 players) → tune numbers → aim assist (touch/gamepad) → rounds + tier rotation → Mods → draft → **Playtest #1**
- **Open question:** Inspect uses **F**, which the control table also plans for Mod 3; pick new keys before Mods are built (see [Gunplay](01%20Design/Gunplay.md) §6).
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
| Gunplay | RIVALS-style run-and-gun, accurate while moving, slide is the core move, ~1.5× headshots, TTK 0.35–0.6 s | [Gunplay](01%20Design/Gunplay.md) |
| Rounds | First to 5, shared weapon tier per round (Sidearm → Light → Heavy → Wildcard) | [Weapons](01%20Design/Weapons.md) |
| Draft | 3 Mod slots, L1→L3, both sides draft, the loser gets +1 card and +1 reroll, mirrored offers in 1v1 | [Game Plan](05%20Production/Game%20Plan.md) §4 |
| Art | Style B "Stylized Neon"; Bitrate is the master reference | [Art Direction](02%20Art/Art%20Direction.md) |
| Camera | First person | [Gunplay](01%20Design/Gunplay.md) |
| Money | Cosmetics only (wraps, charms, Mod VFX), no paid random boxes | [Game Plan](05%20Production/Game%20Plan.md) §1 |
| Tech | Rojo + strict Luau, server-authoritative, Server Authority on | [Architecture](04%20Tech/Architecture.md) |
