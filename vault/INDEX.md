# Vault index

One line per project note: path (relative to `vault/`) and what it answers. Search this first (`Grep`), then read only the section you need (`Grep -n` the heading, `Read` with offset/limit). LihFolk has its own index: `LihFolk/INDEX_SLIM.md`, `LihFolk/SYMPTOMS.md`, `LihFolk/ROUTER.md`. Size in KB after the path: above ~15 KB never read the note whole.

## Start
- `00 Home.md` (13): current status, last results, what waits on the user, Locked decisions table, map of notes
- [State Values and Asset Data](04%20Tech/State%20Values%20and%20Asset%20Data.md): results snapshot, runtime values and shared authored configuration
- [State Values playtest](05%20Production/Playtests/2026-11-19%20State%20Values.md): oversized results, 2v2 rematch, Lobby queue and current asset audit
- `05 Production/Status History.md` (42): dated status log before 2026-11-05 (what was built when); grep only
- `04 Tech/Code Map.md` (10): every Service/Controller, its remotes and attributes; pick code files from here
- `04 Tech/Architecture.md` (15): repo layout, shot validation walkthrough, match system, test range, Rojo/Studio gotchas, code rules
- `04 Tech/Developer Handoff.md`: both places, player journey, edit map, Studio audit, troubleshooting and release handoff
- `04 Tech/Measured Check Skills.md` (3): the 38 installed `rbx-*` measured-check skills, which to use per area, the security scan, what was left out

## Design (01 Design)
- `01 Design/Match Flow.md` (8): rounds, select/draft, timers, weapon phases, as built
- `01 Design/Gunplay.md` (48): movement, slide, spread, recoil, aim assist, feedback, health/downed (§3), viewmodel (§6), feel roadmap (§5)
- `01 Design/Gun Balance.md` (8): health, shields, every gun's damage, TTK
- [Gun and round balance playtest](05%20Production/Playtests/2026-11-19%20Gun%20and%20Round%20Balance.md): shot breakpoints, Sheriff in round two, Elite and Mod draft variety
- [Ammo and assists playtest](05%20Production/Playtests/2026-11-19%20Ammo%20and%20Assists.md): reserve limits, Classic backup and assist feedback
- [Overtime Zone](02%20Art/Overtime%20Zone.md): Blender meshes, curtain texture and Studio setup
- [Overtime Zone playtest](05%20Production/Playtests/2026-11-19%20Overtime%20Zone.md): visual review, shrink, warning, damage and cleanup
- `01 Design/Weapons.md` (10): gun roster, tiers per round, gun mechanics
- `01 Design/Mods.md` (15): the 9 abilities, controls, activation types, A/B/Glitch paths
- `01 Design/Abilities/00 Abilities.md` (8): base ability redesign overview and build prompt
- `01 Design/Abilities/<Dash|Updraft|Molly|Firewall|Frost|Recon|Heal Orb|Stim|Recall>.md` (10–16 each): the locked spec of that ability (numbers, behaviour, VFX/sound)
- `01 Design/Abilities/Upgrade Paths.md` (11): L2/L3 paths A/B/Glitch for all 12 abilities
- `01 Design/Abilities/<Shock Dart|Flash|Roller>.md` (3–4 each): the free pack, built 2026-11-17 (numbers, how it's built, sounds, bots, counter-play)
- `01 Design/Bots.md` (23): AI bots: seats, brain, perception, aim, Mods, tuning
- `05 Production/Bot Redesign 2026-11-17.md`: shooter research, movement and Mod redesign, difficulty profiles, Studio test results
- [Shadow Mist idle playtest](05%20Production/Playtests/2026-11-17%20Shadow%20Mist%20Idle.md)
- [Shadow Mist action polish](05%20Production/Playtests/2026-11-18%20Shadow%20Mist%20Action%20Polish.md)
- `05 Production/Playtests/2026-11-17 Bot Redesign.md`: Studio route, combat and overtime observations
- `01 Design/Match Avatar.md` (11): the standard body for players, bots and dummies
- `01 Design/Third Person Overhaul.md` (19): 2026-11-12, built: why players weren't posed (Server Authority off), the block body and how its clothing is drawn, the accessory rule, the 40 re-authored clips and the `tools/anim` rig, per-gun findings; §7 second pass: research links, Toolbox findings, the jitter measurement, rifle stance, spring recoil, self-grade, what is not verified
- `01 Design/Match HUD.md` (22): match HUD layout, v1 revert, phone arrangement
- `01 Design/Lobby.md` (14): Lobby place design (Sunwell Bunker, compact, wings, queue)
- `01 Design/Lobby UI and Queue.md` (59): Lobby HUD, Play menu, queue rules, Figma frames; grep sections
- `01 Design/Lobby UI Image Prompts.md` (4), `01 Design/Range Brainstorm.md` (4): image prompts; range ideas (not built)
- `01 Design/Archive/Gauntlet_Weapon_Modeling_Briefs.md` (105): sixteen gun-companion modelling briefs (archived); never read whole
- `01 Design/Maps/00 Maps.md` (9): map roster, rules, symmetry, lineup of 8
- `01 Design/Maps/Jump Audit 2026-11-13.md` (8): every map checked against the 4.4 jump (measured reach: ledge 7.5, gap 9 at sprint); owner chose keep the jump, fix the maps: Dockyard got 4 step crates, nothing else was a designed loss
- `01 Design/Maps/Map Quality Standard.md` (22): the bar for every map rebuild: pipeline, hard rules, audits, blind score ≥ 8.5
- `01 Design/Maps/Arena.md` (6): Arena + Big Arena (redesign batch 1): owner calls, v2 build (plain parts, 5-stud module, two greys, grid tile), layout checks vs RIVALS, playtest, test list
- `01 Design/Maps/Pier and Dockyard.md` (6): redesign batch 2: port kit module, layout checks, greybox builder, container kit test, ChatGPT concept prompts, test list
- `01 Design/Spawn Hold.md` (2): pre-round ghost hold at open-floor markers (no spawn nooks), why, build plan
- `01 Design/Maps/Overnight Run 2026-11-16.md` (6): all 13 release maps built overnight: method, origins, incident and repair, status table (layout, greybox, kit, grade), checks, builder additions
- `01 Design/Maps/Map Lineup Brainstorm 2026-11-16.md` (7): why RIVALS maps work (10 points with numbers), our extra needs (slide, Mods), a 12-map proposed lineup with duel/big pairs and a launch set of 6, owner questions
- `01 Design/Maps/<Name>.md` and `<Name>2.md`: layout, callouts, props and build log per map. Original: Whitebox (15), Big Whitebox (2), Rooftops (19), Dockyard (21), Metro (24), Old Town (26), Bunker (24), Greenhouse (19), Snowpeak Lodge (20). Rebuilds to the standard: Rooftops2 (94), Dockyard2 (75), Metro2 (33), OldTown2 (10), Bunker2 (14), Greenhouse2 (25), Snowpeak2 (15)

## Art (02 Art)
- `02 Art/Art Direction.md` (16): style rules, palette, model standard, Blender → Open Cloud → WeaponBuilder import pipeline
- `02 Art/UI Design.md` (13): UI look, tokens, type, Figma screens (v1 approved)
- `02 Art/UI Art Brief (ChatGPT).md` (3): UI art made with ChatGPT images
- `02 Art/Style Bible.md` (8): **the whole look and feel on one page** (pillars, models, guns, feedback/VFX, sound, UI); start here for anything players see or hear
- `02 Art/UI Overhaul Research.md` (27): **UI overhaul phase 1** (2026-11-14): current Lobby and match UI review (captures, measured), 5 references, Studio-built ScreenGui hierarchy, Scale vs Offset, text sizing (measured TextScaled tests), what to build first
- `02 Art/UI Top Bar Draft.md` (12): **match top bar** (2026-11-14): v2 built in Studio (team blocks, headshots, scores, stopwatch timer, motion), the owner calls that led there, where it lives; Figma draft 1 below
- `02 Art/UI Draft Screen.md` (3): **draft screen redesign** mockup (2026-11-14): two numbered steps, one selection rule, upgrade paths as equal tiles, glitch as a magenta tile
- `02 Art/UI Feed and Spectate.md` (2): **kill feed, ELIMINATED, killed-by and spectate** redesign in the match UI style: mockup v1 in Studio (2026-11-14)
- `02 Art/UI Match Extras.md` (2): **status tray** (draining rings), **hold-Tab scoreboard**, combat report, final-kill card, prompts, zone alert: built 2026-11-14
- `02 Art/UI Lobby HUD.md` (5): **lobby main HUD**, built: RIVALS-style bar (coloured tags, hover plates, ChatGPT icons v2), PLAY + party slots, player list (Tab / topbar), Roblox + in-game parties with invites, topbar buttons (2026-11-14)
- `02 Art/UI Play and Party Menus.md` (4): **Play menu** (mode tiles, BEGINNER 2V2 left, 4V4 / 5V5 soon), **searching bar** (PLAY scales out while queued), **Party menu** (your party + search, ALL / FRIENDS / LOBBY, invites), the shared close button, no lobby UI sounds (2026-11-15)
- `02 Art/UI Lobby Overhaul.md` (12): **the lobby UI overhaul** on one kit (Shared/UiMotion, Util/LobbyKit, KIT tokens) after RIVALS' own UI files: every screen moved over, new Settings (crosshair editor), Profile, Rewards, the loading screen, phone layouts, the match motion pass; grades, test list, parked questions (2026-11-16)
- `02 Art/UI Polish Pass.md` (8): **UI polish pass** analysis + plan (2026-11-20): UI sounds back (RIVALS sound set read from its files), duel-tile hover jitter cause, Locker backdrop + gun framing, Settings motion, cut corners as 9-slice images (vs multi-frame), owner questions
- `02 Art/UI Match Overhaul.md` (6): **match UI overhaul + map vote**: RIVALS' duel structure read from their files, the map vote (MapVoteService / MapVote screen), server / FPS / ping readout (lobby + match), level and device marks, then the match restyle (2026-11-16)
- `02 Art/UI Battle Pass.md` (4): **Season Pass** screen: free + premium tracks, 30 tiers in pages of 7, the picked reward big (3D skins), CLAIM / CONTENTS / +5 LEVELS / UNLOCK PREMIUM; UI only (2026-11-16)
- `02 Art/UI Shop.md` (6): **Shop** plan: HOME (paid cases with odds + region lock, season pass, offers, cosmetics), BUNDLES (some with exclusive Mods), DAILY (8 items + login rewards), COINS; one currency (Coins); motion; ChatGPT art prompts (2026-11-16)
- `02 Art/UI Locker.md` (4): **Locker** plan: weapons synced into the Lobby (`tools/studio/SyncWeapons.luau`), 3D gun on a hidden stage, per-gun skins, Abilities = your Mod collection (buyable Mods, changed Money decision) (2026-11-15)
- `02 Art/UI Notifications.md` (4): **match notifications** (long band under the top bar, match point, no 3-2-1) and the de-AI pass on the HUD (2026-11-14)
- `02 Art/UI Combat HUD Mockup.md` (5): **health, ammo and Mod slots mockup** (2026-11-14) in the top bar style; states board, design, open questions
- `02 Art/UI Theme v4 Soft Edge.md` (9): **UI theme direction v4.1** (2026-11-12): plates with one cut, HUD on fades, circles, Sarpanch + Titillium Web, motion, layouts, mobile, Figma boards, owner questions
- `02 Art/Model Style Interview.md` (4): the owner's modelling rules (no curves/spheres, carved ends), the reference-screenshot interview question bank, design methods
- `02 Art/Lobby Style Guide.md` (8): the stylized grounded look, written for rebuilding maps in it
- `02 Art/Lobby V3 Rebuild.md` (11): the current Lobby rebuild (2026-11): owner's notes, rules, layout, audit, self-review, steps
- `02 Art/Lobby V4 Plan.md` (12): **Lobby V4 plan** (2026-11-16) from the RIVALS lobby study: octagon Concourse with a lantern dais, horseshoe Duels (8 equal bays, trophy at the end), Locker, Supply (Shop + Season Pass), Range window + yard; sizes, walk times, budgets, reuse, ChatGPT concept prompts, the owner's interview answers
- `02 Art/Lobby V4 Theme.md` (3): **Lobby V4 theme "Gauntlet Bunker"** (owner 2026-11-16: the RIVALS look and feel in our own pieces): dark structured shell, light grey trim, white bar lamps, gold lines, RIVALS-style glowing word signs; replaces the light-grey Sunwell look
- `02 Art/Lobby V4 Build.md` (8): **Lobby V4 build results** (2026-11-16): Concourse, Duels, Locker, Shop in `Workspace.LobbyV4Staging`; pipeline, numbers, audit, prompt play-test, blind scores, test list, swap and rollback steps
- `02 Art/Sunwell Works Build.md` (9): the Sunwell Works build in Studio: hall, Locker, Shop, Duels staging, checks, pipeline, rollback (the style rules from it are the project skill `.claude/skills/gauntlet-build-style`)
- `02 Art/Sunwell Hub Upgrade.md` (15): the hub hall's sixth pass (2026-11-12): Sun Well, sun ring, boards, pipe racks, turbine, story props, floor route cues, four blind review rounds (median 6.7, stop rule), next list
- `02 Art/Sunwell Build Rules Handoff.md` (6): every rule from the Sunwell hub sessions in one page: shape rules, de-steampunk palette, lighting lessons, Blender → Studio pipeline, blind grading, open owner calls, git
- `02 Art/Sunwell Lobby Reference Pack.md` and `Sunwell Lobby Fable Prompt.md`: new lobby layout, image gallery, Roblox research, Studio captures and phase-one build brief
- `02 Art/Lobby Art Plan.md` (29), `Lobby Kit.md` (15), `Lobby Rebuild 2026-11-04.md` (33), `Lobby Professional Pass.md` (3): Lobby art plan, Blender kit, rebuild log, review pass
- `02 Art/Mod Props.md` (8), `02 Art/Mod Audio.md` (18): Mod models; Mod sound shortlist (unauditioned)
- `02 Art/Sound Library Pick.md` (23): the bought pro gun sound pack (418 files) measured; picks per gun (shots, auto sets, reload parts), knife / hit / Mod candidates, processing and code plan, audition reel `art-source/audio/ProPack/PickReel.wav`
- [Combat Feedback Audio](02%20Art/Combat%20Feedback%20Audio.md) has original headshot and standard elimination audition takes, comparisons and source credits.
- `05 Production/Handoff - Gun and Knife Feel from Videos.md` (6): brief for the session that studies the owner's gun / knife clips (video-analyzer): what to measure, where it lives in code, lanes, rules, done-when
- `05 Production/Handoff - Feel Polish (Fable).md` (20): the next session's brief after the feel-videos passes: owner's taste and verdicts, the clips and their numbers, what exists (knife solver + pipeline, rigid fist + wrist, PCHIP tracks, toss, gun snap, Sheriff cylinder roll), how to test, the queue (knife polish, guns, Sheriff, Bat, headshot / crosshair / head flare)
- `05 Production/Handoff - Gun Sounds Full Length (Codex).md` (7): brief for Codex: semi-auto shots are capped short in the atlas build (pistol 1.5 to 1.0 s, rifle 2.19 to 1.6, shotgun 2.66 to 1.6), so they sound dull; restore full length, audit every gun sound, listening tools, upload quota
- `03 Research/Animation Flow and Feel Research (2026-11-14).md` (29): why our knife reads blocky and staged (PCHIP stops at pose keys, dead holds) and how to fix it; RIVALS' inspect frame by frame; LihFolk + published sources (Overwatch GDC 2017, Holden springs and inertialization, Gears of War 4, Rosen, Riot clarity and hit registration); looks good / bad; a checklist for every animation change
- `02 Art/Archive/Gun Batch Prompt.md` (11), `02 Art/Archive/AI 3D Prompts.md` (13): old prompts for batch gun modelling and AI 3D tools (archived)
- `02 Art/References/` : reference images (some third-party, not committed); `.../SOURCES.md` lists them
- `02 Art/Skins/README.md` (4): how a skin line goes from idea to ChatGPT concept sheets: folder per line (`concept.md`, `prompt.md`, `refs/`, `out/`), the rules a skin must follow; `_Template/` to copy

- `02 Art/Skins/Sol Roster Handoff.md`: execute remaining 70 skin assets in Blender while owner is away; Studio deferred while Claude uses it
- `02 Art/Skins/Prism/Build Ledger.md`: saved Prism Vandal v01, approved texture IDs, selector, completed checks and Studio save/testing gaps
- `02 Art/Skins/Blender Review.md`: roster completion table, Blender contact sheets, Bat pose review, checks, and Studio handoff
- `02 Art/Skins/First-Person Melee Animation.md`: Bat grip, swings, two-handed smash and toss inspect, plus the stock Knife grip correction
- `02 Art/Skins/{Redline,Nitrous,PopCircuit}/Build Ledger.md`: per-line Blender files, texture sets, manifests and next steps
- `02 Art/Skins/Skin Build Pitfalls.md` (6): every skin problem the owner found (gaps, z-fighting, sights fading on ADS, textures showing through hidden parts, blunt outlines), cause, fix, and the check that catches it
- `02 Art/Skins/Structural Skin Round One Results.md`: all 36 structural skins (6 lines) built in Blender 2026-11-14, grades, checks, Studio pass to do
- [Ruin-Blighted Vandal concept](02%20Art/Skins/RuinBlighted/concept.md) and [model handoff](02%20Art/Skins/RuinBlighted/Model%20Handoff.md): owner reference and breakdown, [Shadow Mist Blender reviews](02%20Art/Skins/RuinBlighted/Build%20Review.md)
- [Shadow Mist Vandal sound cue sheet](02%20Art/Skins/RuinBlighted/Sound%20Cue%20Sheet.md): stock takes, current Shadow Mist layers, sound design direction, and draw, reload and inspect timing
- [Elite skin playbook](02%20Art/Skins/RuinBlighted/Elite%20Skin%20Playbook.md) and [Ruin-Blighted expansion ledger](02%20Art/Skins/RuinBlighted/Expansion%20Ledger.md): reusable Shadow Mist workflow and roster continuation
- [Ruin-Blighted sound production checklist](02%20Art/Skins/RuinBlighted/Expansion%20Sound%20Queue.md): exact current recordings, reuse and export instructions for each gun, Ruined Reaver and the stock Knife
- [Ruin-Blighted audio playtest](05%20Production/Playtests/2026-11-20%20Ruin-Blighted%20Audio.md): approved gun mix, Reaver cue layers, Roblox source assets and Match client checks
- [Tempest-Strike concept](02%20Art/Skins/TempestStrike/concept.md), [research archive](02%20Art/Skins/TempestStrike/Research.md) and [Vandal build handoff](02%20Art/Skins/TempestStrike/Build%20Handoff.md): revised Kuronami-inspired elite hero, fluted shroud, laminar water, custom actions, chromas, round and shuriken charm
- `02 Art/Skins/{Moltframe,Slipframe,Giltfold,Inkshift,Sealwork,Payload}/Build Ledger.md`: per-item files, build, measured checks, grade and open checks for each structural line

## Tech (04 Tech)
- `04 Tech/Mod System.md` (36): how Mods are built: data, server, predicted simulation, stages, Mod HUD/VFX/audio
- `04 Tech/Prompts/2026-11-15 Ability Rework.md`: current Claude implementation brief for all nine Mods, fresh Blender MCP art direction and model routing. `02 Art/References/mods/rework/` holds the earlier art reviews.
- `04 Tech/Prompts/2026-11-16 Ability Rework Follow-up.md` (5): follow-up for the ability rework session: Opus 5.5 for nearly everything (Fable only to lock in), RIVALS VFX/ability study per Mod, what assets may be used
- `04 Tech/Prompts/2026-11-15 Lobby UI Overhaul.md` (5): prompt for the lobby UI overhaul session (shared kit, router, every lobby screen, phones, match UI pass)
- `04 Tech/Prompts/2026-11-15 Gunplay Feel (RIVALS).md` (9): handoff (current state with file:line) + prompt for RIVALS-style hit markers, headshot look, crosshair motion on slide, body on slide
- `04 Tech/Prompts/2026-11-16 Lobby Build (RIVALS study).md` (10): handoff (Sunwell / V3 state, locked look, rejected list, pipeline, scripted hooks) + prompt to study the RIVALS lobby and rebuild ours as Lobby V4, main area first
- `04 Tech/Prompts/2026-11-16 Maps Redesign (RIVALS-clean).md` (9): handoff (decision, lineup, RIVALS numbers, map contract the code reads) + prompt for the full map redesign in the RIVALS-clean look, Opus routing
- `04 Tech/Setup Guide.md`: toolchain, both Rojo ports, Studio MCP, Obsidian, Git and release
- `04 Tech/Codex Collaboration.md`: migration from Claude, current project skills and working routine
- `04 Tech/LihFolk.md` (2): the Roblox knowledge plugin and where its notes live
- `04 Tech/Video Analyzer.md` (4): YouTube study tool (transcripts + frames), install, CLI command, gotchas
- `04 Tech/Prompts/Archive/Ability System Prompt.md` (8), `Lobby Build Prompt.md` (6): old build prompts (archived)

## Production (05 Production)
- `02 Art/Ability VFX Direction.md` (5): the shared effects language for the nine Mods (2026-11-15): grammar (shapes first, three beats, stepped motion, clear aim area, glitch as a rare accent), element signatures (wind, fire, ice, healing, teleport, scan, impact, shield), per-effect changes, review method
- `04 Tech/Ability Effects Map.md` (6): where each Mod's effect is drawn (file and function per effect, shared helpers, mesh kits), plus the skinned-limb gap; start effect work here instead of searching
- `05 Production/Handoff - Ability Rework (Opus).md` (9): start here to continue the ability rework in a pure Opus chat: paste-ready opener, usage rules, what is done and Play-checked, what is left in order, Studio / Blender / git state, gotchas
- `05 Production/Ability Rework 2026-11-15.md` (5): plan and status for the nine-Mod rework: model routing, live Blender MCP rules + shared core `tools/blender/rework/rw_core.py`, prop interfaces to keep, phases
- `05 Production/Game Plan.md` (33): day-by-day plan, scope, §1 map rules, §4 draft ideas, §5 longer-term
- [Release Roadmap](05%20Production/Release%20Roadmap.md): full pre-release checklist, build dependencies, test matrix and ranked deadline cuts
- [Experience Naming](05%20Production/Experience%20Naming.md): Roblox naming research, spoken-name shortlist, and collision checks
- [Experience Naming Review](05%20Production/Experience%20Naming%20Review.md): numbered name candidates for owner feedback, comparison titles, and first-page Roblox checks
- `05 Production/Handoff - Grades to 9-10.md` (5): the lanes left to bring every animation and gunplay grade to 9-10 (2026-11-13), shared rules for parallel sessions
- `05 Production/Match Structure Revamp.md` (21): Release 1 match flow plan, phases A–D, as built
- `05 Production/Weapon RemasterV2.md` (6): Opus weapon rebuild via live Blender MCP; all 18 v03 guns imported into Studio 2026-11-08, first-person pass, F6 gun review mode
- `05 Production/Weapon Final Pass 2026-11-11.md` (7): final gun pass before skins: new sight family, see-through and floating test, charm ring, nickel accent, v05 files, model sheets for ChatGPT
- `05 Production/Codex Gun Remaster Brief 2026-11-07.md` (10): Codex job: remaster every gun and the knife in Blender (style, rig contract, sights, rounds, anims, renders); Akimbo dropped
- `05 Production/Cleanup 2026-11-08.md` (4): the repo / code / place cleanup: what was tidied, what was left on purpose, how things are organized
- `05 Production/Archive/`: finished one-off plans and briefs: `Handoff 2026-11-06 Release 1.md` (7), `Overnight 2026-11-04.md` (7), `Day Plan 2026-11-05.md` (9), `Codex Concept Brief 2026-11-05.md` (2)
- `05 Production/Bugs & Ideas.md` (4): bug and idea capture, parked ideas
- `05 Production/LihFolk Gap Review 2026-11-05.md` (20): LihFolk advice the game isn't using yet, ranked
- `05 Production/Daily Log/YYYY-MM-DD.md`: one note per work day (only 2026-10-26 so far)
- `05 Production/Playtests/2026-11-14 Full-Length Gun Audio.md`: match-range roster checks, full Vandal tail and 70-shot positional overlap, hit and metallic headshot playback.
- `05 Production/Playtests/2026-11-15 Gunplay Feel RIVALS.md`: RIVALS-style hit marker (kite blades, shrink spring), faceted headshot crown burst, crosshair slide tilt / air / Dash / bloom / ADS collapse, springy slide roll, RIVALS tracer timing; RIVALS numbers, grades, test list, parked calls.
- `04 Tech/Prompts/2026-11-17 New Abilities (Free Pack).md`: **locked spec** for three new free Mods (Roller bot, Flash, Shock Dart): every level's numbers, the owner's 8 decisions, build order and per-Mod steps. Not built yet.
- `05 Production/Handoff - New Abilities.md`: paste-to-start handoff for building those three Mods: phases (Shock Dart, Flash, Roller, finish), rules, gotchas from the rework.
- `05 Production/Playtests/2026-11-17 Free Pack Build.md`: Shock Dart, Flash and Roller built and checked in Play at their levels; the fixes found in the test, grades, what still needs the 2-client test.
- `05 Production/Spectate Replay Fix Plan.md`: the spectate + final-kill replay fix plan from a 74-agent study: causes per complaint (jittery aim, no skins, wrong animations, no hitmarkers, lag), workstreams A-H, decisions taken.
- `05 Production/Playtests/2026-11-16 Match Fixes Round 1.md`: the owner's first match-fix list: mid-match restarts (per-round error recovery), map vote mouse + M key, early round 1 start, no pre-round quick melee, post-round shooting, headshot size, damage numbers per target; RIVALS numbers; what to test.
- `05 Production/Playtests/2026-11-16 Effects Pass Overnight.md`: the overnight pass over every ability effect after fire (ice, then the rest), before / after grades and captures, the capture recipe on the shared effects clock.
- `05 Production/Playtests/2026-11-16 Recon Bow Draw.md`: the Recon bow's limbs were installed backwards (fixed in Studio + builder `turnY`); first-person hold rebuilt as a left-hand bow with a right-hand two-hand draw; the geometry rules behind the numbers.
- `05 Production/Playtests/2026-11-16 Fire Element Pass 1.md`: rework fire (ReworkVfx kit + FireFx): Molly patch, Fork Fire split, burning bodies; greyscale and colour captures, spec deviations waiting on the owner, how to freeze and capture through the MCP.
- `05 Production/Playtests/2026-11-15 Match Damage and Reset.md`: shot counter lockout and Player attribute overflow, reproduced and tested through a full bot match.
- `05 Production/Playtests/`: one note per playtest/review; newest are `2026-11-15 Gunplay Overhaul.md` (9: new clip study of ADS, scope and tracers; ADS spring + trailing zoom + corner darkening, feathered sniper scope that opens from the eyepiece, per-class tracer darts, tip-over damage number, per-class pull-outs; measured vs the clips, test list, owner calls, what is not done), `2026-11-14 Gun and Knife Feel from Videos.md` (14: the owner's clips measured at 60 fps; knife rebuilt RIVALS-style with a rigid fist, spline motion, toss pull-out; gun snap kick, calmer camera, Sheriff cylinder roll; hit notes for lane F; captures in `2026-11-14 feel captures/`; grades, test list), `2026-11-13 Shot Feel Pass 5.md` (7: lane B, shot satisfaction per class: camera kick timing, look-only view punch, aimed kick, burst release, Sheriff and shell-loop reloads; before / after tables, grades), `2026-11-13 First-Person Feel Pass 4.md` (7: lane B, reload / draw / inspect re-keyed with anticipation and overshoot, beats aligned to each gun's clip, MagIn timing bug, run limp fixed (bob pivot), spray texture; before / after numbers, grades, test list), `2026-11-13 Hit Feedback Pass.md` (8: lane F, hit markers, white→red whole-body flash (limb-mesh bug fixed), slash, headshot flash pop and orange highlight (revised after the owner's first look), kill flash on the death copy; timings, cost, grades, test list), `2026-11-12 Gunplay Feel Pass 3.md` (5: spray kick follows the recoil, jump / fall / crouch motion, run step shape, knife hold, stab and inspect; what is not done; test list), `2026-11-10 Gunplay Feel Pass 2.md` (7: pistol hold, sprint swing, aimed strafe lean, arm follow-through, tap slide, new tracers and stylised flash; results table and test list), `2026-11-09 Hit and Shot Feel.md` (10: hit / headshot / kill sounds and ladder, shot punch, the designed-gun prototype from GDC 2016, next steps), `2026-11-08 Gun Sound Overhaul.md` (11: gun SFX library catalogue and licence, per-gun sound themes, every action's sound, levels, what to test), `2026-11-07 Match Revamp Phase A..D.md` (2 each: what was tested, results), `2026-11-06 Overnight Maps Approval.md` (5: per-map scores and asks), `2026-11-05 Evening Review.md` (4: user verdict: maps too simple, HUD v1), `2026-11-05 Maps v3/v4 Review.md` (2 each), `2026-11-05 Morning Test Checklist.md` (4), `2026-11-05 Knife and Sound Pass.md` (65), `2026-11-04 Animation and Knife Pass.md` (21), `2026-11-04 Gunplay Feel Pass 1.md` (4), `2026-11-04 Lobby Professional Pass.md` (4), `2026-11-03 Ability Upgrades Overnight.md` (5), `2026-11-03 Draft Columns.md` (2), `2026-11-02 Match Flow First Run.md` (4), `2026-11-02 Whitebox First Walk.md` (2), `Mods Overnight Checklist.md` (16), `2026-10-26/27 Gun Feedback Round 2/3.md` (12 / 5)

## Research (03 Research): only when a decision needs the "why"
- `03 Research/Design Research Report.md` (62): shooters, draft design, matchmaking, tech, money, risks
- `03 Research/Gun Sound Packs (Valorant-style).md` (8): what makes Valorant's guns sound good, free pro gun libraries (Sonniss GDC bundles) with licences, hit / kill sound sources, the redo plan
- `03 Research/Valorant Gun Mechanics.md` (10): Valorant spread/recoil numbers behind Gunplay v2
- `03 Research/UI References/00 UI References.md` (4): hub of the 2026-11-12 video study + 12 findings; `Rivals PC UI.md` (19), `Rivals Mobile UI.md` (22), `Valorant UI.md` (27): HUD maps, touch layouts, menus, timestamped
- `03 Research/Rivals Reference/00 Rivals Reference.md` (4): hub of the 2026-11-15 study of RIVALS' own files (place file + match-place folder), sources, rules (study, don't copy), screenshot index (local only), top findings, risks; with `Maps and Lobby.md` (map convention, per-map numbers, layout rules, lobby hub and queue pads), `UI and Client.md` (5: UI storage, router, motion numbers, 9-slice, phones, client architecture), `Body, Viewmodel, Guns and VFX.md` (6: own-R15 body + hand IK, viewmodel springs, gun attachment contract, abilities, VFX recipes). Skill: `rivals-reference`
- `03 Research/Rivals Reference/Ability VFX Numbers.md` (13): per-layer numbers of RIVALS ability effects (fire, freeze, explosion, dash, vortex, portals, war horn, deflect, smoke clouds, thrown props), read 2026-11-16; summary in `Body, Viewmodel, Guns and VFX.md` → Ability VFX
- `03 Research/Notes/` : raw research: `ability_draft_design.md` (39), `gun_system_tech.md` (50), `matchmaking_queues.md` (50), `monetization_retention.md` (32), `top_roblox_shooters.md` (30)

## Assets (06 Assets)
- `06 Assets/Asset Tracker.md` (47): every gun/map/VFX/sound and its status; grep the row, don't read whole

## Templates and folder guides
- `Templates/Daily Log.md`, `Playtest.md`, `Gun Spec.md`, `Mod Spec.md`: note templates
- `05 Production/Daily Log/README.md`, `05 Production/Playtests/README.md`: how those folders are used
