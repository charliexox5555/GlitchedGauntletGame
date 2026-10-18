# Game Plan: From Day 1 to Season 1

Start date: **Monday, October 19, 2026**
Public beta target: **Saturday Oct 31, 2026 (Halloween)**
Season 1 "real" launch target: **Wednesday Nov 25, 2026 (US Thanksgiving break)**

This is the master plan. It assumes you work on the game most of the day, most days, with Claude doing a large share of the code and asset building. If you can only do evenings, every date stretches about 2x, and the order stays the same.

The deeper research and the reasoning behind these decisions are in [`reports/Roblox ability draft shooter design.md`](../reports/Roblox%20ability%20draft%20shooter%20design.md).

---

## 0. Read this first: the honest version

**What "made this month" means.** In under two weeks you can ship a **playable, fun, public beta**: casual 1v1 and 2v2, 5 guns, 8 abilities, 3 maps, mobile controls and a practice bot. Ranked, the Gauntlet, the shop and the season pass come in November. Trying to ship everything in October gets you a buggy game that loses its first players, and the 2026 Roblox algorithm punishes exactly that (players leaving on their first visit).

**Nobody can promise a hit.** What this plan can do is stack the odds:

1. Gunplay that feels great comes first. RIVALS won on feel.
2. You test the fun with real people at the end of week 1, before building more.
3. You launch small, measure, fix, then grow.
4. You build an audience *while* you make the game (the devlog plan in section 9).
5. You time the big launch for the biggest Roblox traffic weeks: Thanksgiving, then Christmas break.

**The one rule for the whole month:** if something isn't on the must-have list, it waits. When you fall behind, use the cut list in section 10. Don't work longer hours instead.

---

## 1. The game on one page (locked design decisions)

Decide these Monday morning and don't reopen them this month.

### Name
"Glitched Gauntlet" is too close to Valorant's mode name. Pick something original. Ideas:
- **OVERWRITE**: you overwrite your kit every round.
- **GLITCHLINE**
- **PATCHWORK**
- **HOTFIX**
- **CORRUPTED**

Check that the name is free on Roblox search first. The repo name can stay as it is.

### Fiction (keep it light)
You're a "Runner" inside a broken combat simulation. Your abilities are **Mods**. Rare corrupted Mods are **Glitches**. Arenas are server rooms, firewalls and data caches. That gives a clean visual theme and explains why the rules change each round.

### Art direction: low-poly neon digital
Simple blocky shapes, dark surfaces, bright neon edges, and hit effects that dissolve into pixels/voxels instead of blood. This style was chosen on purpose:
- **Claude can build it.** It's made from simple shapes, which Claude can generate reliably with code (section 6).
- **It reads well on phones**, where most Roblox players are.
- **No blood** helps you get the **"Mild"** content label, which means the widest audience.
- **It runs smoothly on cheap phones.**

### Camera
First person, like RIVALS. Add an optional third-person spectator view later.

### Match format (every queue)
- **First to 5 round wins.** One life per round, and everyone resets to 100 HP each round.
- Rounds last **50 seconds**. After that comes **15 seconds of shrinking-zone overtime**. If it's still tied, the side with more total HP wins.
- **Between rounds: a 12-second draft.** The opening draft before round 1 gets 20 seconds, which also covers the loadout check.

### Gun-class rounds (your idea, and the big difference from OVERKILL)
Every round has a **weapon class both sides share**, announced *before* the draft, so you draft for the gun you're about to use.

| Round | Weapon class |
|---|---|
| 1 | Sidearm |
| 2 | SMG |
| 3 | Shotgun |
| 4 | Rifle |
| 5 | Marksman |
| 6–8 | Player's choice (pick any class you've unlocked in your loadout) |
| 9 (deciding round) | **WILDCARD**: everyone gets the same random special weapon |

Each class has one gun at launch, and players can pick between guns in the same class later. Players skin *their* gun of each class, so cosmetics keep their value.

### Abilities (Mods) and the draft
- **3 Mod slots.** Each Mod levels L1 → L2 → L3.
  - MVP: straight-line upgrades.
  - Week 3: the L2 branch (pick path A or B).
- The opening pick plus a pick after every round adds up to **9 picks max**. That exactly fills 3 Mods at L3 by the deciding round, so the last round is the "fully built" climax.
- **Both sides draft every round.** The round loser sees **4 cards instead of 3** and gets **+1 reroll**.
- In 1v1, **both players see the same offers** (mirrored random seed), so nobody can say "they got luckier".
- **Enemy Mods and levels are visible** during the draft, which allows counter-picking.
- **Glitches** sometimes replace an upgrade card. The card says exactly what the Mod turns into, and you can take it or leave it. A glitched Mod looks different in a fight, so the enemy can read it.

### Queues
| Phase | Queues |
|---|---|
| Beta | Duels (1v1) and Duos (2v2), casual only. Plus Practice vs Bot. |
| November | Ranked Duels, Squads (3v3/4v4), scheduled Gauntlet events |

### Money
Cosmetics only, all sold directly, with **no Robux loot boxes** (they're restricted in the UK, Australia and Brazil). Every gun and Mod is free in ranked. Nothing that changes a fight is ever sold.

---

## 2. Your toolchain (set up Monday)

| Tool | What it's for |
|---|---|
| **Roblox Studio** | Building, testing, publishing |
| **Git + GitHub** (this repo) | Saving your code history. Commit every day. |
| **Rojo** | Syncs code files from this repo into Studio, so Claude Code can write real files |
| **VS Code** (+ Luau LSP extension) | Reading and editing code |
| **Claude Code** | Writes most of the code in this repo; uses the roblox-dev skills (new-system, security, UI, reviewer) |
| **Roblox Studio MCP server** | Lets Claude Code act directly inside Studio: insert parts, build models, run Luau, start playtests. Roblox ships an official one, updated Feb 2026 ([MoguraVR coverage](https://www.moguravr.com/roblox-studio-mcp-server-agentic-update/)); check Roblox's docs for current setup. A community alternative is [robloxstudio-mcp](https://glama.ai/mcp/servers/@boshyxd/robloxstudio-mcp/blob/a7a918df2bd92027177c4893462925ee737a5635/studio-plugin/INSTALLATION.md). |
| **Blender** (free) + optional **Blender MCP** ([ahujasid/blender-mcp](https://glama.ai/mcp/servers/ahujasid/blender-mcp)) | For guns/props that need real meshes; Claude can drive Blender with Python |
| **Wally / Selene / StyLua** | Package manager, linter, formatter. Claude's `roblox-dev:setup` skill sets these up. |
| **ProfileStore** (via Wally) | Safe player data saving (well-known community library) |
| **jsfxr** (free, in browser) | Retro "digital" sound effects that fit the glitch theme |
| **Discord server + Roblox group** | Testers, community, announcements |

**Where things live:**
- **Code** lives in Git (this repo), synced by Rojo.
- **Maps and models** live in the Studio place file. Every Sunday, export them as `.rbxm` into `assets/` and commit them as a backup.
- **Never** use free Toolbox models with scripts in them. They're a common source of backdoors (hidden code that gives other people control of your game).

---

## 3. Code architecture (what Claude will build)

```
src/
  shared/                     -> ReplicatedStorage.Shared
    Config/
      Weapons.luau            -- stats for every gun (data only)
      Mods.luau               -- every ability, every level, every glitch (data only)
      Rounds.luau             -- class rotation, timers, HP, win condition
      Arenas.luau             -- arena list + sizes + spawn tags
    Net.luau                  -- all RemoteEvents in one place, typed
    Types.luau
    Util/ Spring.luau, SeededRandom.luau, Signal.luau
  server/                     -> ServerScriptService.Server
    Services/
      MatchService            -- creates a match, holds teams, ends match
      RoundService            -- round state machine (Draft -> Live -> Overtime -> End)
      DraftService            -- builds offers from seed, validates picks, timer, auto-pick
      WeaponService           -- ammo, fire rate, HIT VALIDATION, damage
      HitboxHistory           -- stores recent hitbox positions for lag compensation
      ModService              -- cooldowns, casts, validation, effects
      LobbyService            -- queue pads, party-on-pad, arena allocation
      ArenaService            -- spawns/cleans arena instances
      BotService              -- practice bot brain
      DataService             -- ProfileStore: level, XP, stats, settings, cosmetics
      AnalyticsService        -- funnel + economy events
      AntiCheatService        -- rate limits, sanity checks, suspicion score
  client/                     -> StarterPlayerScripts.Client
    Controllers/
      InputController         -- PC / gamepad / touch via Input Action System
      CameraController
      WeaponController        -- viewmodel, recoil springs, tracers, hit markers
      ModController           -- ability buttons, prediction, VFX
      DraftController         -- draft screen
      HudController           -- HP, ammo, round score, kill feed, round banner
      LobbyController         -- queue status, pads UI
```

**Rules Claude must follow (put these in a `CLAUDE.md` on Monday):**
1. `--!strict` everywhere.
2. **The server decides everything that matters:** damage, hits, cooldowns, draft picks, round results. The client only asks and shows.
3. All guns and Mods are **data in Config files**. Adding a gun or Mod should mean adding a table entry, not new systems.
4. Check every RemoteEvent: argument types, finite numbers, rate limits.
5. Turn on Server Authority from day 1 (it blocks speed, fly and teleport hacks; very hard to add later).
6. No `_G`, no free-model scripts, no `wait()`; use `task.wait()`.

---

## 4. Starting numbers (tune them in playtests)

### Guns (100 HP per round)
| Class | Gun (placeholder name) | Fire | Damage (body / head) | Fire interval | Mag | Notes |
|---|---|---|---|---|---|---|
| Sidearm | **Byte** pistol | Semi | 30 / 52 | 0.18 s | 12 | 4 body shots |
| SMG | **Burst Buffer** | Auto | 16 / 24 | 0.075 s | 30 | Damage drops after 25 studs |
| Shotgun | **Hard Reset** | Pump | 8 pellets × 12 | 0.8 s | 6 | Damage drops after 15 studs |
| Rifle | **Bitrate** | Auto | 24 / 38 | 0.11 s | 25 | Main all-rounder |
| Marksman | **Long Poll** | Bolt | 75 / 150 | 1.1 s | 5 | Headshot = 1-shot |
| Wildcard pool | Railgun, Ricochet launcher, Twin pistols… | — | — | — | — | Add 1 for beta, more later |

Target time-to-kill is about 0.4–0.6 s for automatics. Movement speed is 16 studs/s, sprint 22, with a slide.

### 8 launch Mods (original abilities)
| # | Mod | Role | L1 | L2 | L3 | Glitch (MVP has 3) |
|---|---|---|---|---|---|---|
| 1 | **Blink** | Mobility | Dash 12 studs, 6 s cooldown | 2 charges | Dash refills your mag | **Desync**: dash leaves a decoy afterimage that fakes your position |
| 2 | **Firewall** | Control | Wall 8×6 studs, 150 HP, 5 s | 250 HP | Enemies passing through are slowed | — |
| 3 | **Packet** | Damage | Grenade, 50 damage area | 2 charges | Leaves a burning area | **Fork Bomb**: splits into 3 smaller bombs |
| 4 | **Ping** | Info | Reveals enemies within 30 studs for 2 s | 45 studs | Reveal goes through walls for teammates too | — |
| 5 | **Patch Up** | Sustain | Heal 40 over 2 s | Instant heal | +25 overshield | — |
| 6 | **Overclock** | Buff | +25% fire rate for 4 s | +faster reload | Kills reset its cooldown | **Overheat**: +60% fire rate but you lose 8 HP/s |
| 7 | **Launch Pad** | Mobility | Placeable jump pad | Pad works twice | Mid-air accuracy bonus | — |
| 8 | **Lag Field** | Control | Zone slowing enemies 40% | Bigger zone | Slowed enemies take +10% damage | — |

Ability buttons: 3 on screen (one per slot). Every Mod reuses one of a few code building blocks: *dash, projectile, placeable object, area zone, self-buff, reveal*. That's how 8 Mods fit in a week.

### Draft
| Rule | Value |
|---|---|
| Cards offered | 3 (round loser gets 4) |
| Rerolls | 1 per match + 1 per round lost (max 3) |
| Card mix | Early rounds mostly new Mods; later rounds mostly upgrades |
| Glitch chance | ~8% per eligible upgrade card, +3% each draft without one (cap 25%) |
| Timer | 12 s; ends early when everyone has locked in |
| Timeout | Auto-pick: upgrade your highest Mod, else the first card |
| First-ever match | Only 2 obvious cards, to teach the draft |

---

## 5. Maps

### Rules for every arena
- **Mirror-symmetric**, so neither spawn has an advantage.
- **Three lanes** (left / middle / right) with a contested middle.
- Because of gun-class rounds, every arena must work for **shotgun AND marksman**: close-quarters rooms on the flanks, one longer middle sightline (max ~70 studs).
- **Cover heights:** half cover 3 studs (crouch), full cover 7+ studs. The character is ~5 studs tall.
- Doorways at least 6 studs wide, and not too much height so it plays well on mobile.
- No dead-end camping spots; every room has 2 exits.
- Spawns are out of sight of each other.

### Launch maps
| Arena | Mode | Size | Theme |
|---|---|---|---|
| **Cache** | 1v1 | ~64 × 64 studs | Tight data vault, good for shotgun and SMG rounds |
| **Firewall** | 1v1 / 2v2 | ~90 × 70 studs | Glowing wall lanes, a central bridge |
| **Mainframe** | 2v2 | ~100 × 80 studs | Server racks, a raised middle, long sightline |
| **Lobby** | Hub | Large | Queue pads, aim range, bot pad, leaderboards, a "Gauntlet coming soon" board |

### How to make a map (half a day each)
1. **Sketch** it top-down on paper or in a drawing app, 10 minutes: lanes, cover, spawns.
2. **Greybox** it: grey Parts only, no detail. Ask Claude through Studio MCP: *"Build a greybox arena from this layout: [describe or paste grid]. 64×64 studs, mirror-symmetric on the X axis, half cover 3 studs, full cover 8 studs, tag spawns with CollectionService tag ArenaSpawn_A / ArenaSpawn_B."*
3. **Playtest the greybox.** Run with each gun class. Fix sightlines.
4. **Art pass** only after it plays well: neon trims, materials, lighting, a few props from your kit (section 6).
5. **Performance check:** keep the part count reasonable, and use anchored, non-colliding decoration with `CanQuery = false` and `CanTouch = false`.

Build a reusable **kit** of pieces once (wall 8×8, half wall, pillar, ramp, door frame, server rack, crate, neon strip) and build every map from it. That's how one person makes several maps fast.

---

## 6. Making guns and assets with Claude

### The three ways, in the order to use them

**1. Part-built models from code (use this for the beta, ~80% of assets).**
Claude writes a Luau "builder" that creates the model out of Parts and Wedges, then runs it in Studio (through the MCP server, or you paste it into the Command Bar). The low-poly neon style makes this look intentional, not cheap.
- *Pros:* instant, editable, consistent style, zero import problems.
- *Cons:* blocky. That's fine for this art style.

**2. Blender meshes (use for "hero" assets: wildcard guns, the lobby centerpiece).**
Claude writes Blender Python (or drives Blender through Blender MCP) to model a low-poly gun, then you export FBX/OBJ and bring it in with Studio's 3D Importer.
- Keep guns under ~3,000 triangles. Roblox caps a single mesh at roughly 20K triangles, and lower is better for phones.

**3. Roblox's built-in mesh generator.**
Roblox launched AI mesh generation (Cube 3D, the `/generate` command in Studio's Assistant) as a beta in 2025 ([Roblox newsroom](https://about.roblox.com/newsroom/2025/03/introducing-roblox-cube)). Its meshes are untextured and its 2026 status needs checking. It's good for quick props (crates, plants, cables), not precise guns.

### The gun model standard (every gun must follow this so code works)
Each gun is a `Model` in `ReplicatedStorage.Assets.Weapons` named exactly like its config ID (e.g. `Byte`), containing:
- `Handle` (PrimaryPart, invisible, non-colliding)
- Attachments on the Handle: **`Muzzle`** (bullet origin + flash), **`RightGrip`**, **`LeftGrip`**, **`AimPoint`** (where the camera sits when aiming down sights), **`Eject`** (shell eject)
- All parts welded to the Handle, `Anchored = false`, `CanCollide = false`, `Massless = true`
- Parts named `Body`, `Barrel`, `Mag` (the mag moves during reload), `Sight`, `Accent` (neon parts, so skins can recolour them)
- Barrel pointing forward along the Handle's **−Z** axis
- Size: pistols ~1.5 studs long, rifles ~3.5–4 studs long

### Copy-paste prompt for a gun
> Build a Roblox gun model with a Luau builder script for my low-poly neon art style.
> Name: `Bitrate` (class: Rifle). Silhouette: compact bullpup rifle, angular top rail, short barrel shroud, curved magazine behind the grip.
> Size: 3.8 studs long. Budget: max 35 parts (Parts and WedgeParts only).
> Colors: body #1C1F2B (SmoothPlastic), trim #2E3447, accents Neon #00E5FF.
> Follow my gun model standard: Handle as PrimaryPart, attachments Muzzle / RightGrip / LeftGrip / AimPoint / Eject, parts named Body / Barrel / Mag / Sight / Accent, everything welded, massless, non-colliding, barrel along −Z.
> Put it in ReplicatedStorage.Assets.Weapons. Then screenshot it from the side and from first-person aim so I can check it.

Reuse the same prompt for every gun and change only the name, class, silhouette and accent colour. **Give each class its own silhouette** (pistol small, shotgun chunky with a pump, marksman long with a big scope) so players can tell guns apart at a glance.

### Other assets with Claude
| Asset | How |
|---|---|
| **Mod icons, card frames, rank badges, UI buttons** | Claude writes SVG icons in one consistent style, converts them to PNG, and you upload them as Images. Keep one 2-colour icon style. |
| **VFX** (muzzle flash, tracers, hit sparks, glitch shimmer, pixel-dissolve death) | Claude writes ParticleEmitter / Beam / Trail setups in code. Pool them, don't create new ones every shot. |
| **Recoil and gun motion** | Claude codes them with springs, so no animation files are needed for the beta. |
| **Character arms** (first-person viewmodel) | Simple part-built arms in the same art style |
| **Sounds** | Roblox's free licensed sound library in the Creator Store for gunshots and footsteps, plus jsfxr for glitchy UI and ability sounds. Make every gun sound distinct. |
| **Lobby and map props** | Part-built kit pieces from code; Blender for the centerpiece |
| **Game icon and thumbnails** | Take in-game screenshots with a clean camera angle, then add bold text and effects. Claude can draft layout ideas. Thumbnails are the #1 click driver, so make 3 variants to A/B test. |
| **Music** | Roblox's licensed music library (lobby only; keep matches readable by sound) |

**Asset checklist before anything goes in the game:** it's readable on a phone screen, it matches the palette, it has no scripts inside, the part/triangle count is OK, and it's named correctly.

---

## 7. The day-by-day plan

Every day ends the same way: **playtest what you built, write 3 bullet notes, commit and push to Git.**

### WEEK 1: "Find the fun" (Mon Oct 19 – Sun Oct 25)
Goal: by Sunday, two people can play a full drafted 1v1 with all 5 gun classes, and you know whether it's fun.

**Mon Oct 19: Setup + decisions**
- [ ] Pick the name, palette (3–4 colours) and art style. Collect 10 reference images in a folder.
- [ ] Install Studio, VS Code, Rojo, Git, Claude Code. Connect the Roblox Studio MCP server.
- [ ] Ask Claude to run `roblox-dev:setup`: Rojo project, Wally, Selene, StyLua, strict Luau, the folder structure from section 3.
- [ ] Write `CLAUDE.md` with the rules from section 3.
- [ ] Create the Roblox place. In Game Settings, enable **Server Authority** and **StreamingEnabled**.
- [ ] Commit config skeletons: `Weapons.luau`, `Mods.luau`, `Rounds.luau` with the section 4 numbers.
- [ ] Create the Discord + Roblox group. Post "Day 1" (section 9).
- **Done when:** a script you edit in VS Code shows up in Studio through Rojo, and Server Authority is on.

**Tue Oct 20: Movement, camera, first map**
- [ ] First-person camera, sprint, slide, crouch, jump tuned for arena combat.
- [ ] Input Action System set up for keyboard/mouse, gamepad and touch (placeholder touch buttons are OK).
- [ ] Greybox **Cache** (section 5) with tagged spawns.
- [ ] Claude builds the first gun model: **Byte** pistol (section 6 prompt).
- **Done when:** you can run, slide and jump around Cache smoothly on PC and on your phone.

**Wed Oct 21: The gun system (the most important day)**
- [ ] WeaponService + WeaponController: fire on press, server-checked fire rate and ammo, reload.
- [ ] Hitscan shooting: the client sends the shot, and the server validates angle, line of sight and distance against **rewound hitboxes** (HitboxHistory, ~200–250 ms cap).
- [ ] Headshots, damage drop-off, damage numbers on server confirm.
- [ ] Feel: recoil springs, camera kick, muzzle flash, tracer, hit marker (instant, then confirmed), kill sound.
- [ ] Ask Claude to run the `roblox-dev:roblox-reviewer` agent on the gun code for security.
- **Done when:** shooting a friend (or a dummy) feels crunchy and hits register correctly with simulated lag (Studio's network simulator).

**Thu Oct 22: Rounds + gun-class rotation**
- [ ] RoundService state machine: Pre-round → Live (50 s) → Overtime zone (15 s) → Round end → next.
- [ ] First to 5, HP reset each round, one life per round, spectate teammate/enemy when dead.
- [ ] Gun-class rotation from `Rounds.luau`: Sidearm → SMG → Shotgun → Rifle → Marksman → choice → Wildcard.
- [ ] Claude builds the other 4 guns + 1 wildcard (same prompt, different silhouettes).
- [ ] Round banner UI: "ROUND 3 — SHOTGUNS".
- **Done when:** a full 1v1 match runs start to finish with the right gun each round.

**Fri Oct 23: Mods (abilities), part 1**
- [ ] ModService/ModController: cast request → server validation (owned, cooldown, range) → effect → VFX broadcast.
- [ ] The building blocks: dash, projectile, placeable, zone, self-buff, reveal.
- [ ] First 4 Mods at L1–L3: **Blink, Firewall, Packet, Patch Up**.
- [ ] 3 ability buttons + cooldown display (PC keys Q/E/F; touch buttons in an arc).
- **Done when:** you can use all 4 Mods in a match, and spamming the remote does nothing (rate-limited).

**Sat Oct 24: The draft**
- [ ] DraftService: offers from a seed (mirrored in 1v1), new vs upgrade cards, loser +1 card and +1 reroll, 12 s timer, auto-pick, early end when everyone locks in.
- [ ] Draft screen: big cards with icon + one-line text, the enemy's Mods shown at the top, the next round's gun class shown big, a reroll button.
- [ ] Opening draft (20 s) before round 1.
- [ ] Remaining 4 Mods at L1–L3: **Ping, Overclock, Launch Pad, Lag Field**.
- **Done when:** a whole match flows: draft → round → draft → round … → winner.

**Sun Oct 25: PLAYTEST #1 (decision day)**
- [ ] Get 3–6 friends on (PC and phone). Play at least 10 matches.
- [ ] **The control test:** play some matches with Mods turned off. Ask: which was more fun? Would you play again tomorrow?
- [ ] Watch players without helping. Note where they're confused (especially the draft screen).
- [ ] Write a top-10 fix list. Export map/model backups to `assets/`.
- **Decision:** if drafted matches are clearly more fun, continue. If not, spend Monday changing the Mods/draft before building anything else.

### WEEK 2: "Make it a game" + public beta (Mon Oct 26 – Sun Nov 1)
Goal: something a stranger can join, understand in 20 seconds and enjoy.

**Mon Oct 26: Fix list + glitches**
- [ ] The top 5 fixes from playtest #1.
- [ ] Glitch system: the glitch chance on upgrade cards, a special card design, and a glitched visual tell.
- [ ] 3 Glitches: **Desync** (Blink), **Fork Bomb** (Packet), **Overheat** (Overclock).
- [ ] Greybox **Firewall**.

**Tue Oct 27: Lobby + queues**
- [ ] Lobby greybox → art: Duels pad, Duos pad, Practice-vs-Bot pad, aim range with targets, a "Gauntlet coming soon" board.
- [ ] LobbyService: stand on a pad to join that queue (2 friends on a Duos pad = a party), a queue status UI, and a leave-queue button.
- [ ] ArenaService: copy an arena into the lobby server for each match, then clean up after.
- [ ] 2v2 support in Match/Round/Draft (team HP, teammate spectating).
- **Note:** at beta player counts, everyone fits in one lobby server, so in-server matching is all you need. Cross-server matchmaking comes later (week 3–4) when you have more than one full server.

**Wed Oct 28: HUD + mobile**
- [ ] The full HUD: HP, ammo, the 3 Mod buttons with level pips, round score, kill feed, a timer.
- [ ] The final mobile layout: left joystick, right fire button (+ optional left fire), ADS, reload, jump, slide, 3 Mod buttons in an arc. Everything sized for thumbs.
- [ ] Roblox's official Aim Assist on touch and gamepad only (modest strength).
- [ ] **Test on an actual cheap phone.** Fix anything below 50 fps.
- [ ] Greybox **Mainframe**.

**Thu Oct 29: Bot, first-time experience, saving, analytics**
- [ ] Practice bot: strafes, peeks, shoots with human-like delay and misses, uses Blink/Packet. Clearly labeled "BOT".
- [ ] First-time flow: join → straight into a **bot duel within 20 seconds** → a simple first draft (2 cards) → after the match, the lobby with a "Queue Duels" arrow.
- [ ] Queue fallback: if nobody's queued after ~45 s, offer "Play a bot while you wait" (and keep the queue spot).
- [ ] DataService (ProfileStore): level, XP, wins, matches, settings (sensitivity, button layout). Session locking + autosave.
- [ ] Analytics funnel events: joined → first shot → first draft → match finished → second match → queued real players.
- [ ] Anti-cheat basics: rate limits on every remote, validation, kick on impossible values.

**Fri Oct 30: Polish + private stress test**
- [ ] Art pass on all 3 arenas (neon trims, lighting).
- [ ] Sounds for all 5 guns, Mods, the UI, hits, kills, round win/loss.
- [ ] Game icon + 3 thumbnail variants + description + tags. Set the **content maturity questionnaire** honestly (aim for Mild).
- [ ] Private test with 8–12 people in one server (lag, bugs, match flow).
- [ ] Claude runs a security review over all remotes before you go public.
- **Stretch:** go public tonight if everything is stable.

**Sat Oct 31: PUBLIC BETA LAUNCH 🚀 (Halloween)**
- [ ] Publish. Title it as a beta (e.g. "[BETA] OVERWRITE").
- [ ] Post the launch video (section 9), open Discord, add a "beta tester" badge for everyone who joins in the first week.
- [ ] Watch players live (join their servers, watch the Developer Console for errors).

**Sun Nov 1: Read the data, fix fast**
- [ ] Check retention, session length and where the funnel drops.
- [ ] Hotfix the top 3 problems.
- [ ] Back up maps/models, commit, write next week's plan from what you learned.

### WEEKS 3–6: Grow it into the real launch (Nov 2 – Nov 29)

**Week 3 (Nov 2–8): Depth + first money**
- L2 branches for all 8 Mods (path A/B).
- 4 new Mods + 3 more Glitches.
- Cosmetics v1: gun wraps for all 5 guns, Mod effect colours, kill effects. Direct-buy shop + a rotating daily shop. A "Supporter Pack" (cosmetic only).
- Codes system (Discord/YouTube codes give cosmetic currency).
- If you regularly have more than one full server: **cross-server matchmaking** (MemoryStore queues + reserved match servers; design in the report).

**Week 4 (Nov 9–15): Ranked + reasons to return**
- **Ranked Duels:**
  - Hidden OpenSkill rating, visible tiers (Bronze → …).
  - 10 placement matches.
  - Gates: account 14+ days old, a level requirement, 10 casual wins.
  - Leaver penalty.
- Earned ranked currency ("Glory"-style) for prestige cosmetics that can't be bought.
- Daily/weekly challenges ("Win a round using only Sidearm + Blink").
- Global leaderboards in the lobby.
- First small sponsored-ad test **only if** first-day return rate is about 12% or higher.

**Week 5 (Nov 16–22): Squads + Gauntlet event**
- **Squads** (3v3, falls back from 4v4): the third arena size.
- **Gauntlet v1** as a **scheduled event** ("Gauntlet Hour" at peak times):
  - 16 players / 8 duos in one server, shared team HP and 4 small arenas.
  - Labeled bots fill empty slots, and those runs are unrated.
  - Players hold a Gauntlet ticket and keep playing duels while it fills.
- Season pass v0: free track + premium track, XP from wins **or** playtime.

**Week 6 (Nov 23–29): SEASON 1 LAUNCH (Thanksgiving week)**
- Drop "[BETA]". Launch trailer, a big update log, a new map, a new Wildcard gun, 2 new Mods.
- A creator push: invite YouTubers/TikTokers to a private creator Gauntlet.
- A **Christmas update** plan (Dec 19 onward, the biggest Roblox traffic period of the year): snow map variant, holiday cosmetics, double-XP weekend.

---

## 8. Milestone checklists ("am I actually done?")

**✅ Prototype (Oct 25)**
- Full 1v1 match with 5 gun classes, 8 Mods, draft, first to 5
- Hits feel right with 150 ms simulated lag
- Playtesters prefer it over the no-Mods version

**✅ Public beta (Oct 31)**
- A new player is in a bot fight within 20 s
- Duels + Duos work with 2+ real people; the bot fills in when the queue is empty
- Phone controls are comfortable; 50+ fps on a mid-range phone
- Data saves and loads; no errors in the console during a 10-match session
- Every remote validated and rate-limited

**✅ Season 1 (Nov 25)**
- Ranked Duels, Squads, scheduled Gauntlet, shop, season pass
- First-day return rate above ~12% and 7-day return rate above ~3–5%. The Roblox median is about 10% and 1.6%.
- Queue median under 30 s at peak times

---

## 9. Getting players (start Monday, not after launch)

1. **"Making a Roblox game in 30 days" devlog.** Post a 30–60 s TikTok/YouTube Short every 1–2 days: the first gun shot, the first glitch, a broken bug, a friend reacting to a Glitch. The devlog itself is the marketing, and it builds an audience that's waiting on launch day.
2. **Discord from day 1.** Testers get a role and a badge. Ask them what to name things, and let them vote on the next Mod.
3. **Roblox group.** Give a small bonus for joining (e.g. +XP), which also gives you a way to announce updates.
4. **Clips are your ads.** Make Glitch reveals, L3 upgrades and 1v1 clutches look amazing on screen: a big UI pop, sound and a slow-mo kill cam on the final round.
5. **Creators.** Once stable, give creators private servers for "1v1 the dev" or Gauntlet tournaments.
6. **Update every week** with something visible: a new Mod, map, gun or event. Put the update number in the game title (e.g. "[UPDATE 3]").
7. **Thumbnails/icons:** test 3 variants. Show a gun, a bright ability effect and a big readable word.
8. **Friend referrals.** Roblox has an official referral system that rewards both the person inviting and the new player. Add it in week 3–4.

---

## 10. When you fall behind: the cut list

Cut in this order. Cut from the top first:
1. Wildcard round → just replay Rifle
2. Third arena → launch with 2
3. Glitches → launch with 1, add more in week 3
4. 2v2 → launch Duels only
5. Mods 7 and 8 → launch with 6

**Never cut:** gun feel, the draft, mobile controls, the practice bot, data saving and remote security. Those are what make or break the first play.

---

## 11. Working with Claude every day

**Start each session with:**
> Read CLAUDE.md and docs/GAME_PLAN.md. Today is [date], we're on [day's tasks]. Here's what happened yesterday: [your 3 notes]. Build [first task] first, then wait for me to test it.

**Tips:**
- **One system at a time.** Ask for "the DraftService + draft screen", not "the whole game".
- Ask Claude to use the **roblox-dev skills**: `new-system` for features, `roblox-security` for anything with remotes, `roblox-ui` for screens, `roblox-datastores` for saving, and the `roblox-reviewer` agent after every big system.
- **You test, Claude fixes.** Describe exactly what you saw ("the shotgun hit marker shows but no damage when I'm moving left").
- **Ask for tests on pure logic** (draft offers, seeds, damage drop-off, round state), so bugs show up before a playtest.
- **Commit every day.** If Claude breaks something, you can go back.
- **Keep the numbers in Config files** so you can tune balance in 10 seconds without new code.

---

## 12. Biggest risks this month

| Risk | Warning sign | What to do |
|---|---|---|
| Not fun enough, or "OVERKILL clone" vibes | Playtesters prefer the no-Mods version | Lean harder on gun-class rounds + active Mods + counter-drafting; rework the Mods before adding content |
| Gun feel is mediocre | People say "floaty" or "it didn't hit" | Spend extra days on Wed Oct 21 work. Nothing else matters if this is bad. |
| Empty queues at launch | Queue times over 60 s | Bot fallback, Duels-first, advertise "Gauntlet Hour" times, devlog audience |
| Scope creep | Behind schedule by Wednesday of week 2 | Use the cut list. Don't skip testing days. |
| Exploiters | Impossible kills, speed reports | Server Authority, hit validation, rate limits, kick and ban tools |
| Burnout | You stop enjoying it | Take Sunday evenings off. The schedule includes buffer by cutting, not by working longer. |

---

Good luck. The first goal is just Sunday's question: **is a drafted 1v1 with gun-class rounds more fun than plain gunplay?** Everything after that builds on the answer.
