# 🏠 Home

**Working title:** GlitchedGauntletGame (final name TBD: see [Game Plan](05%20Production/Game%20Plan.md) §1)
**One-liner:** RIVALS-style run-and-gun duels (1v1 → 4v4) where you **draft abilities ("Mods") every round** and every round opens a new **weapon tier**. Scheduled 16-player Gauntlet events come later.

---

## 📍 Status

- **Weapon final pass (2026-11-11, [note](05%20Production/Weapon%20Final%20Pass%202026-11-11.md)):** the last gun pass before skins. Every iron-sight gun has a new rear sight (a big thin-walled window, one family, each gun its own shape) with a lit front dot; the Stinger no longer loses parts while aiming (sight neon moved into the sight part); a new see-through test found and closed the Phantom suppressor's back and holes on 16 guns; nothing floats; the charm tab is a small plate and ring; the blue controls are bright nickel; the Operator magazine is closed. All 18 are `v05` files, exported, uploaded and rebuilt in Studio (old set in `ServerStorage.WeaponsBackup_PreFinalPass_2026-11-11`). A model sheet per weapon for ChatGPT is in `art-source/weapons/ModelSheets/`. **Waiting on the owner:** the F6 aim check, and **save the match place**. Nothing committed.
- **Gunplay feel pass 2 (2026-11-10, [note](05%20Production/Playtests/2026-11-10%20Gunplay%20Feel%20Pass%202.md)):** pistols held closer and bigger; sprint swings the gun with the stride; aiming and strafing leans the gun into the strafe; arms follow on a spring (wrists give on recoil); a tap on C commits the full slide (0.85 s, jump cancels); new tracers with a lingering wake; new stylised muzzle flash and impact sheets (Codex). Built and checked by script in Studio. **Waiting on the owner:** play the "what to test" list in the note. Nothing committed. **2026-11-11 follow-up (same note):** the owner turned Server Authority off; the server now leaves players' movement to their clients and the stance / camera checks are off (the Operator's "hit marker, no damage" and refused ability throws); the slide runs out into your next speed with no dip. Owner confirmed Operator hits land. **Still to check:** an ability throw; a second player's view. **Follow-up 2 (same day):** slide holds its direction (small steering), no sprint key (walk, then run after 0.4 s), jump 5.6 → 4.4 studs with a faster fall, guns held lower and further left, wider run sway, a pistol's free hand swings when running, bouncy handling kicks on reload / draw / landing, about 1.5x shot recoil movement. **Owner to play it and say what's too much or too little.**
- **Sunwell Works build in Studio (2026-11-12, [note](02%20Art/Sunwell%20Works%20Build.md)):** the new hall plus Locker, Shop and Duels interiors are staged in the Lobby place beside V3 (`Workspace.SunwellStaging`); Range on hold. Four passes on the owner's notes: faceted shape language (no rounded bevel boxes, battered walls, flared piers, one-piece frames), a proper fixture kit, SurfaceGui boards, equal duel pads in mode order, our own faint textures. Walked in play mode. Play spawns in the new hall; `Build.use("V3")` rolls back. Nothing saved or committed. **Waiting on the owner:** notes on the look, and save the place.
- **Sunwell Works lobby concept (2026-11-11):** linear hydro-station hub, custom doorway signs and prop sheets. The [art pack](02%20Art/Sunwell%20Lobby%20Reference%20Pack.md) includes the Studio baseline and picture review. [Phase 1 handoff](02%20Art/Sunwell%20Lobby%20Fable%20Prompt.md) covers the hall and four thresholds for owner review.
- **Lobby V3 rebuild, now in Studio (2026-11-10, [note](02%20Art/Lobby%20V3%20Rebuild.md)):** the whole Lobby was rebuilt in live Blender MCP and imported into the Lobby place: a compact hub with a big light well and a brass armillary centrepiece, four different gates, Duels (ramp, duel rings on terraces, Gauntlet gate), a larger Shop, the Locker vault, the Range. Each wing has its own 3D sign. First props are in. Walls no longer vanish: players and the camera stop at hidden opaque colliders inside thick walls. Walk and camera tests pass; old lobby kept in `ServerStorage.Archive.Hub_Bunker2_preV3`. Self-rating 7.5 / 10. Second pass the same day: dark edge lines (collider corners poking through rounded edges) fixed, vault door on a sill, layered signs with lamps, shop now shows skins, cases and sidearms, the armillary and a featured case turn (existing ambience script). Third pass (evening): the **hub** restyled to the owner's choices (clean stylized surfaces, wing-coloured piers, neon outline signs with icons, a gauntlet trophy, new benches, brighter light); the wing halls come next, one at a time. Hub then went neutral and tactical with halo-lit signs (owner: good for now). **Locker rebuilt 2026-11-11:** in-wall display bays with the 18 real guns by class, a hologram projector with the Vandal turning, the vault door rolled aside in the tunnel. **Duels rebuilt 2026-11-11:** a longer dark hall with nine stations (two team pads and a hologram board each), a Gauntlet portal stage and better lighting. Next: Shop, Range. **Waiting on the owner:** look at it in Studio and **save the place** (not saved, nothing published); decide what the wall boards show. Nothing committed.
- **Sound and feel, Valorant / RIVALS target (2026-11-09, [note](05%20Production/Playtests/2026-11-09%20Hit%20and%20Shot%20Feel.md)):** the owner rejected the 11-08 gun sounds as dull. Live in Studio now: a per-class shot punch with spray climb, bigger hit markers, and a kill tone that climbs per kill with pips on the pop-up. **Shipped overnight:** all 18 guns designed from layered pro mics (Sonniss GDC 2016), new hits (body impact, headshot slash, kill boom + ring, climbing per kill), uploaded as gun atlas v2 (asset 78823707282052) and play-tested in Studio. **Waiting on the owner:** play it. Movement and ability sounds need a bigger library first (the GDC 2016 sampler is too thin). Nothing committed.
- **Cleanup 2026-11-08 ([note](05%20Production/Cleanup%202026-11-08.md)):** repo, code and place tidied for new work: shared helpers (`Ease`, `Fighters`, `BodyClone`), the three biggest scripts split (WeaponService 1,769 → 905, ViewmodelController 2,366 → 1,817, EffectsController 1,656 → 585), dead code and stale comments out, numbers into Config, a running server keeps only the loaded map, 19 old worktrees (5.3 GB) removed, old one-off notes archived, README map of the repo. **Save the match place** (two leftovers removed). Playtested: a full 1v1 to the end screen, clean output.
- **Release 1, match structure revamp (2026-11-07, [plan](05%20Production/Match%20Structure%20Revamp.md)):** phase A built and playtested in Studio ([playtest](05%20Production/Playtests/2026-11-07%20Match%20Revamp%20Phase%20A.md)):
  - select from the moment you join, 30 s / 15 s with the 3-2-1 inside, gun and ability preselected, early end from round 2;
  - bot stand-ins for late players, bots replace team-mode leavers, a side with no real players left loses;
  - sudden death: a closing glitch-storm circle that takes health directly (new `ZoneService`, `ZoneController`, Blender texture).
  - **Not tested yet:** late joining and leaving (needs two real clients).
  - **Phase B built (first person, [playtest](05%20Production/Playtests/2026-11-07%20Match%20Revamp%20Phase%20B.md)):** death camera; then you see through a living teammate's eyes with their gun and arms (killer at round end with no teammate alive); fixed the gun staying up after death.
  - **Phase C built ([playtest](05%20Production/Playtests/2026-11-07%20Match%20Revamp%20Phase%20C.md)):** the match-winning kill replays for everyone (through the killer's eyes since 2026-11-08, slow motion into the hit, FINAL KILL caption). 
  - **Phase D built ([playtest](05%20Production/Playtests/2026-11-07%20Match%20Revamp%20Phase%20D.md)):** match stats (eliminations, deaths, assists, damage), a victory scene on the map, the post-match screen with Rematch (vote) / Play Again (Lobby, straight back in the queue) / Leave, 20 s then everyone to the Lobby; the match server no longer starts a new match by itself. **Real teleports need a published test.** The whole match-structure revamp (A–D) is built.
- **Overnight 2026-11-06, every map rebuilt as `<Map>2`** (ForceMap only; old maps and the pool untouched). The verdict is in [Overnight Maps Approval](05%20Production/Playtests/2026-11-06%20Overnight%20Maps%20Approval.md).
  - The spec is the new [Map Quality Standard](01%20Design/Maps/Map%20Quality%20Standard.md).
  - Best blind scores:
    | Map | Score |
    |---|---|
    | Rooftops2 | **8.3** (ready for an eye-test) |
    | Dockyard2 | 7.5 |
    | Metro2 | 6.7 |
    | OldTown2 | 6.3 |
    | Bunker2 | 6.25 |
    | Snowpeak2 | 5.0 |
    | Greenhouse2 | 5.0 |
  - All audits are 0.
  - Codex made the concepts for all maps, the billboards and posters, and hero props (the Greenhouse iron kit, the Metro train, the Snowpeak snowcat and rocks).
  - **Waiting on the user:**
    - approval of Rooftops2;
    - the layout asks (Bunker2, Snowpeak2, Metro2, OldTown2);
    - the Greenhouse2 design pass;
    - whether Codex should do the hero pieces of every map.
  - Place saved 05:33.
- **Usage optimisation (2026-11-07):** Home slimmed from 54 KB to about 13 KB (history moved to Status History), new `vault-lookup` agent, `INDEX.md`, `Code Map.md`, "Read lean" rules in CLAUDE.md and the `gauntlet-vault` skill. A running session needs a restart to see the new agent.
- **Earlier status** (Evening review 2026-11-05 back to the Week 1 prototype, every "Done" entry): [Status History](05%20Production/Status%20History.md). Grep it, don't read it whole.
- **Blockers:** none known.

---

## 🗺️ Map of the vault

**Look things up, don't read whole notes:** [INDEX](INDEX.md) (one line per note, with sizes) · [Code Map](04%20Tech/Code%20Map.md) (every Service/Controller, its remotes and attributes) · the `vault-lookup` agent (`.claude/agents/vault-lookup.md`: a question in, facts with paths out).

### 01 Design: what the game *is*
- [Gunplay](01%20Design/Gunplay.md): movement, shooting feel, aim assist, feedback (RIVALS core + slide)
- [Weapons](01%20Design/Weapons.md): 22 guns + melee, tiers per round, build waves, gun mechanics
- [Mods](01%20Design/Mods.md): first 9 abilities, controls and activation types, A/B paths + Glitch path (**approved**)
- [Abilities redesign](01%20Design/Abilities/00%20Abilities.md): base abilities reworked one by one, Valorant-style: **all 9 base specs locked**, ready to build with the build prompt in the overview; specs collected here, then built together
- [Lobby](01%20Design/Lobby.md): the pre-game hub place (third person, queue pads, shop, locker, Range wing): **design locked**, ready to build
- [Maps](01%20Design/Maps/00%20Maps.md): the match map roster and ideas; first map [Whitebox](01%20Design/Maps/Whitebox.md) (built, layout approved)
- [Map Quality Standard](01%20Design/Maps/Map%20Quality%20Standard.md): the bar and checklist every map rebuild follows (pipeline, hard rules, audits, blind score ≥ 8.5, user approval)
- [Match Flow](01%20Design/Match%20Flow.md): rounds and the draft, as built
- [UI Design](02%20Art/UI%20Design.md): the UI look (Valorant + RIVALS), tokens, type and the Figma screens (v1)
- [Gun Balance](01%20Design/Gun%20Balance.md): health, shields and every gun's damage
- Map rules and the longer-term draft ideas: in the [Game Plan](05%20Production/Game%20Plan.md) §1, §4 and §5

### 02 Art: how it *looks*
- [Art Direction](02%20Art/Art%20Direction.md): Style B rules, palette, model standard, import pipeline
- [Mod Props](02%20Art/Mod%20Props.md): the Mod models (stylized, energy parts tinted per team), renders in `References/mods/`
- [Lobby Art Plan](02%20Art/Lobby%20Art%20Plan.md): Lobby mood board, palette, materials and the dimensioned "Sunwell Bunker" circular layout
- [Gun Batch Prompt](02%20Art/Archive/Gun%20Batch%20Prompt.md) · [AI 3D Prompts](02%20Art/Archive/AI%203D%20Prompts.md)
- References: `02 Art/References/` (Bitrate master, style tests)

### 03 Research: *why* we decided things
- [Design Research Report](03%20Research/Design%20Research%20Report.md): the full report (shooters, draft design, matchmaking, tech, money, risks)
- Raw notes: `03 Research/Notes/`

### 04 Tech: how it's *built*
- [Setup Guide](04%20Tech/Setup%20Guide.md): install, Rojo, Obsidian, Claude, prompts
- [Architecture](04%20Tech/Architecture.md): folders, Rojo mapping, code rules
- [LihFolk](04%20Tech/LihFolk.md): the Roblox knowledge plugin and its notes in `LihFolk/`

### 05 Production: *when* things happen
- [Game Plan](05%20Production/Game%20Plan.md): day-by-day plan → beta → Season 1
- `Daily Log/` · `Playtests/` · [Bugs & Ideas](05%20Production/Bugs%20%26%20Ideas.md)

### 06 Assets: what *exists*
- [Asset Tracker](06%20Assets/Asset%20Tracker.md): every gun/map/VFX and its status

---

## 🔒 Locked decisions
| Topic | Decision | Where |
|---|---|---|
| Health | **2026-11-02:** 100 health plus a shield. Rounds 1–3: 0 / 25 / 50 from the gun you choose. Round 4 on: 50 for everyone. **2026-11-04: nobody truly dies:** the game's own HP (Humanoid attributes); at 0 you're downed with a fake death look until the next round | [Gun Balance](01%20Design/Gun%20Balance.md) |
| Gunplay | **v2 (2026-10-25): precise run-and-gun.** Valorant-tight first shot, tap/burst control, learnable camera recoil; light movement penalty (~1/4 of Valorant, ADS halves it); slide is the core move; head about ×1.6 and body TTK 0.5–0.75 s at 150 (changed 2026-11-02), no tagging | [Gunplay](01%20Design/Gunplay.md) |
| Rounds | First to 5, a shared weapon phase per round (Sidearm → Light → Heavy → Elite); each round you pick 1 of 3 guns and 1 of 3 abilities. **2026-11-07:** select 30 s (round 1) / 15 s with the 3-2-1 inside, gun and ability preselected; 50 s fight, then a sudden-death circle that takes health directly; 5 s round end; bots keep late players' seats and replace team-mode leavers, a side with no real players left loses; death camera + spectate teammates, final-kill replay, match-end screen with Rematch / Play Again / Leave (being built) | [Match Flow](01%20Design/Match%20Flow.md), [Match Structure Revamp](05%20Production/Match%20Structure%20Revamp.md) |
| Mods | 9 approved ([Mods](01%20Design/Mods.md)); keys **Q / E / T** (gamepad LB / RB / D-pad up, crouch stays C / Left Ctrl), **each ability on a fixed key** (2026-11-03, [Upgrade Paths](01%20Design/Abilities/Upgrade%20Paths.md)); instant and held types; build **L1 of all 9 first**, then paths and glitches; Valorant-style Mod look | [Mods](01%20Design/Mods.md), [Mod System](04%20Tech/Mod%20System.md) |
| Abilities (base) | **Redesign 2026-10-28**, one by one, Valorant-style; specs in [Abilities](01%20Design/Abilities/00%20Abilities.md) override Mods L1. Each ability has its own charges per round and/or cooldown. Blink → **Dash** (1/round), Launch Pad → **Updraft** (2/round), Packet → **Molly** (fire patch, 1/round), **Firewall** → Phoenix-style steerable fire wall that blocks vision (1/round), Lag Field → **Frost** (Waylay-style hinder burst, 1/round), Ping → **Recon** (Sova-style recon dart from a launcher, 1 charge + 30 s cooldown), Patch Up → **Heal Orb** (Sage-style heal over time, 60 ally / 30 self, 1/round), Overclock → **Stim** (Brimstone-style team stim beacon tossed 5 studs ahead, 1/round), Rollback → **Recall** (Chamber-style anchor teleport, 40 studs, the anchor stays, 15 s cooldown, owner-only range ring). Updraft lowers the gun while rising. Own/team fire damage is 50% | [Abilities](01%20Design/Abilities/00%20Abilities.md) |
| Theme | **2026-10-28:** digital/glitch theme shelved for now. Classic gun game, plain names (may return later) | [Abilities](01%20Design/Abilities/00%20Abilities.md) |
| Lobby | **2026-11-05:** same bunker idea rebuilt **compact (about ⅓ the size) with levels**; Duels is one **open, connected RIVALS-style hall** (pads both sides of a walkway); Market = Event + Battle Pass niches and a shop cross; Range room = a holo-caged scale model + gate; queue from a full-screen PLAY menu (1v1/2v2/3v3) or by pressing E on a pad, with bot fill after 30 s. **2026-10-29:** separate Lobby place (start place, 30/server) + Match place (reserved server per match). **Circular underground bunker hub (changed 2026-10-29):** spawn rotunda with a skylight sunbeam + leaderboards, outer ring (slide loop), four wings: Duels (a long dark hall, sections of 1v1/2v2/3v3 pads + queue terminals), Market (winding cave path to a battle-pass cavern), Weapons + Locker (round armoury), Range (ramp down to a scaled-down range model + ENTER gate; the real range is a separate building in the same place, reached by an in-place teleport); no courtyard. Third person + shift-lock. Play button; no guns/abilities in the hub; Range wing (walled zone, first person, all guns + abilities) | [Lobby](01%20Design/Lobby.md) |
| Maps | **2026-11-05:** concept first. Reference boards and ChatGPT concept images (hero views, layout, kit sheet, material swatches) get the user's approval before any build. Target: Valorant-level detail (worn materials, trims, real silhouettes, height levels, place identity) with RIVALS clarity; custom tileable textures and trim sheets; no "smooth plastic blocks". Rooftops and Dockyard first. **2026-11-02:** RIVALS + Valorant mix; 180° rotational symmetry, not mirrored; first map Whitebox (open sky, 1v1 / 2v2 first, built as a Studio model of Parts) | [Maps](01%20Design/Maps/00%20Maps.md) |
| Draft | 3 Mod slots, both sides draft, mirrored offers in 1v1. **One column per slot (2026-11-03, like Gauntlet: Glitched):** an empty slot offers one new ability for it, a filled slot offers its **upgrades** (L1 → path A/B or rare glitch → L3); one card per draft from any column. The loser's +1 card and +1 reroll are parked | [Match Flow](01%20Design/Match%20Flow.md), [Game Plan](05%20Production/Game%20Plan.md) §4 |
| UI | **2026-11-05:** the match HUD stays v1; the v2 rounded look was reverted as "too AI looking". v1 gets improved later. **v1 approved and built 2026-11-03:** Valorant layout + RIVALS chunkiness, cut corners, Oswald + Montserrat (built into Roblox), dark translucent panels, team cyan / orange-red, gold for LOCK IN and upgrades, magenta for glitch | [UI Design](02%20Art/UI%20Design.md) |
| Art | **Changed 2026-11-04 (user):** **stylized and grounded, lower poly**: rounded/bevelled shapes, smooth materials, a brighter palette, fun bold 3D signs; less tactical/realistic than before, not as toy-smooth as RIVALS (about Valorant's detail level); glitch/neon only as a subtle accent. Lobby first ([Lobby Style Guide](02%20Art/Lobby%20Style%20Guide.md)), match maps redesigned later. **Changed 2026-10-25:** no sci-fi look. Professional tactical guns (matte charcoal/black, PBR textures, very restrained neon accent); the Vandal is the new master reference. Style B below is retired | [Art Direction](02%20Art/Art%20Direction.md) |
| Camera | First person | [Gunplay](01%20Design/Gunplay.md) |
| Authority | **2026-11-11 (owner): Server Authority is OFF** (`Workspace.AuthorityMode = Automatic`; it lagged for players). Clients own their movement; the server still decides damage, ammo, fire rate, rounds. The input-based anti-cheat (spread band, camera and aim checks) is **off until a new one is designed**. | [Architecture](04%20Tech/Architecture.md) → Authority mode, `shared/Authority` |
| Money | Cosmetics only (wraps, charms, Mod VFX), no paid random boxes | [Game Plan](05%20Production/Game%20Plan.md) §1 |
| Codex | **2026-11-05:** the Claude core chat drives the user's Codex app (Plus) with computer use: concept images, references, research, trial Blender models, second opinions. No git and no server code. The budget is small | [Codex Collaboration](04%20Tech/Codex%20Collaboration.md) |
| Tech | Rojo + strict Luau, server-authoritative, Server Authority on | [Architecture](04%20Tech/Architecture.md) |
