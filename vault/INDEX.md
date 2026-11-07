# Vault index

One line per project note: path (relative to `vault/`) and what it answers. Search this first (`Grep`), then read only the section you need (`Grep -n` the heading, `Read` with offset/limit). LihFolk has its own index: `LihFolk/INDEX_SLIM.md`, `LihFolk/SYMPTOMS.md`, `LihFolk/ROUTER.md`. Size in KB after the path: above ~15 KB never read the note whole.

## Start
- `00 Home.md` (13): current status, last results, what waits on the user, Locked decisions table, map of notes
- `05 Production/Status History.md` (42): dated status log before 2026-11-05 (what was built when); grep only
- `04 Tech/Code Map.md` (10): every Service/Controller, its remotes and attributes; pick code files from here
- `04 Tech/Architecture.md` (15): repo layout, shot validation walkthrough, match system, test range, Rojo/Studio gotchas, code rules

## Design (01 Design)
- `01 Design/Match Flow.md` (8): rounds, select/draft, timers, weapon phases, as built
- `01 Design/Gunplay.md` (48): movement, slide, spread, recoil, aim assist, feedback, health/downed (§3), viewmodel (§6), feel roadmap (§5)
- `01 Design/Gun Balance.md` (8): health, shields, every gun's damage, TTK
- `01 Design/Weapons.md` (10): gun roster, tiers per round, gun mechanics
- `01 Design/Mods.md` (15): the 9 abilities, controls, activation types, A/B/Glitch paths
- `01 Design/Abilities/00 Abilities.md` (8): base ability redesign overview and build prompt
- `01 Design/Abilities/<Dash|Updraft|Molly|Firewall|Frost|Recon|Heal Orb|Stim|Recall>.md` (10–16 each): the locked spec of that ability (numbers, behaviour, VFX/sound)
- `01 Design/Abilities/Upgrade Paths.md` (11): L2/L3 paths A/B/Glitch for all 9 abilities
- `01 Design/Bots.md` (23): AI bots: seats, brain, perception, aim, Mods, tuning
- `01 Design/Match Avatar.md` (11): the standard body for players, bots and dummies
- `01 Design/Match HUD.md` (22): match HUD layout, v1 revert, phone arrangement
- `01 Design/Lobby.md` (14): Lobby place design (Sunwell Bunker, compact, wings, queue)
- `01 Design/Lobby UI and Queue.md` (59): Lobby HUD, Play menu, queue rules, Figma frames; grep sections
- `01 Design/Lobby UI Image Prompts.md` (4), `01 Design/Range Brainstorm.md` (4): image prompts; range ideas (not built)
- `01 Design/Archive/Gauntlet_Weapon_Modeling_Briefs.md` (105): sixteen gun-companion modelling briefs (archived); never read whole
- `01 Design/Maps/00 Maps.md` (9): map roster, rules, symmetry, lineup of 8
- `01 Design/Maps/Map Quality Standard.md` (22): the bar for every map rebuild: pipeline, hard rules, audits, blind score ≥ 8.5
- `01 Design/Maps/<Name>.md` and `<Name>2.md`: layout, callouts, props and build log per map. Original: Whitebox (15), Big Whitebox (2), Rooftops (19), Dockyard (21), Metro (24), Old Town (26), Bunker (24), Greenhouse (19), Snowpeak Lodge (20). Rebuilds to the standard: Rooftops2 (94), Dockyard2 (75), Metro2 (33), OldTown2 (10), Bunker2 (14), Greenhouse2 (25), Snowpeak2 (15)

## Art (02 Art)
- `02 Art/Art Direction.md` (16): style rules, palette, model standard, Blender → Open Cloud → WeaponBuilder import pipeline
- `02 Art/UI Design.md` (13): UI look, tokens, type, Figma screens (v1 approved)
- `02 Art/UI Art Brief (ChatGPT).md` (3): UI art made with ChatGPT images
- `02 Art/Lobby Style Guide.md` (8): the stylized grounded look, written for rebuilding maps in it
- `02 Art/Lobby Art Plan.md` (29), `Lobby Kit.md` (15), `Lobby Rebuild 2026-11-04.md` (33), `Lobby Professional Pass.md` (3): Lobby art plan, Blender kit, rebuild log, review pass
- `02 Art/Mod Props.md` (8), `02 Art/Mod Audio.md` (18): Mod models; Mod sound shortlist (unauditioned)
- `02 Art/Archive/Gun Batch Prompt.md` (11), `02 Art/Archive/AI 3D Prompts.md` (13): old prompts for batch gun modelling and AI 3D tools (archived)
- `02 Art/References/` : reference images (some third-party, not committed); `.../SOURCES.md` lists them

## Tech (04 Tech)
- `04 Tech/Mod System.md` (36): how Mods are built: data, server, predicted simulation, stages, Mod HUD/VFX/audio
- `04 Tech/Setup Guide.md` (9): install, Rojo, Obsidian, Claude, prompts
- `04 Tech/Codex Collaboration.md` (3): how the core chat uses the user's Codex app
- `04 Tech/LihFolk.md` (2): the Roblox knowledge plugin and where its notes live
- `04 Tech/Prompts/Archive/Ability System Prompt.md` (8), `Lobby Build Prompt.md` (6): old build prompts (archived)

## Production (05 Production)
- `05 Production/Game Plan.md` (33): day-by-day plan, scope, §1 map rules, §4 draft ideas, §5 longer-term
- `05 Production/Match Structure Revamp.md` (21): Release 1 match flow plan, phases A–D, as built
- `05 Production/Cleanup 2026-11-08.md` (4): the repo / code / place cleanup: what was tidied, what was left on purpose, how things are organized
- `05 Production/Archive/`: finished one-off plans and briefs: `Handoff 2026-11-06 Release 1.md` (7), `Overnight 2026-11-04.md` (7), `Day Plan 2026-11-05.md` (9), `Codex Concept Brief 2026-11-05.md` (2)
- `05 Production/Bugs & Ideas.md` (4): bug and idea capture, parked ideas
- `05 Production/LihFolk Gap Review 2026-11-05.md` (20): LihFolk advice the game isn't using yet, ranked
- `05 Production/Daily Log/YYYY-MM-DD.md`: one note per work day (only 2026-10-26 so far)
- `05 Production/Playtests/`: one note per playtest/review; newest are `2026-11-07 Match Revamp Phase A..D.md` (2 each: what was tested, results), `2026-11-06 Overnight Maps Approval.md` (5: per-map scores and asks), `2026-11-05 Evening Review.md` (4: user verdict: maps too simple, HUD v1), `2026-11-05 Maps v3/v4 Review.md` (2 each), `2026-11-05 Morning Test Checklist.md` (4), `2026-11-05 Knife and Sound Pass.md` (65), `2026-11-04 Animation and Knife Pass.md` (21), `2026-11-04 Gunplay Feel Pass 1.md` (4), `2026-11-04 Lobby Professional Pass.md` (4), `2026-11-03 Ability Upgrades Overnight.md` (5), `2026-11-03 Draft Columns.md` (2), `2026-11-02 Match Flow First Run.md` (4), `2026-11-02 Whitebox First Walk.md` (2), `Mods Overnight Checklist.md` (16), `2026-10-26/27 Gun Feedback Round 2/3.md` (12 / 5)

## Research (03 Research): only when a decision needs the "why"
- `03 Research/Design Research Report.md` (62): shooters, draft design, matchmaking, tech, money, risks
- `03 Research/Valorant Gun Mechanics.md` (10): Valorant spread/recoil numbers behind Gunplay v2
- `03 Research/Notes/` : raw research: `ability_draft_design.md` (39), `gun_system_tech.md` (50), `matchmaking_queues.md` (50), `monetization_retention.md` (32), `top_roblox_shooters.md` (30)

## Assets (06 Assets)
- `06 Assets/Asset Tracker.md` (47): every gun/map/VFX/sound and its status; grep the row, don't read whole

## Templates and folder guides
- `Templates/Daily Log.md`, `Playtest.md`, `Gun Spec.md`, `Mod Spec.md`: note templates
- `05 Production/Daily Log/README.md`, `05 Production/Playtests/README.md`: how those folders are used
