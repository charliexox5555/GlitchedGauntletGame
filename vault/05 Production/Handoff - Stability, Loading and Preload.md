# Handoff - Stability, Loading and Preload (2026-11-22)

**Goal:** the whole game loads fast and never breaks: joining, teleporting into a match, the map vote and round start always work, nothing pops in white or untextured, and a new branded loading screen (with sound) covers the loading while the assets the game needs are preloaded. Owner tests on phone and PC after each phase.

## Work rules (mandatory)
- Load the `gauntlet-vault` skill and follow [CLAUDE.md](../../CLAUDE.md): vault first, lean reads (grep, then line ranges; never whole big files), plans and results in the vault. Look up LihFolk first (`lihfolk-lookup`, specialists `roblox-debugging`, `roblox-performance-audit`, `roblox-ui-builder`, `lihfolk-sfx`). Loading-screen look: `gauntlet-ui-style` + [Style Bible](../02%20Art/Style%20Bible.md). RIVALS study: `rivals-reference` skill (study, don't copy; the RIVALS file is read-only).
- Strict Luau, numbers in `src/shared/Config`, no UI built from code (Studio-built screens; the loading screen lives where ReplicatedFirst can show it), stage exact paths only, commit on main, remind the owner to save the place.
- Studio MCP on the **Lobby place** (one place since 2026-11-21). `execute_luau` has its own require cache: read live state from instances, never by requiring game modules (memory: MCP require breaks remotes). Real teleports need a publish: say what couldn't be tested.
- Work in phases below; write the plan section in this note first, results at the end of each phase.

## Owner's reports (2026-11-22)
1. Body part skins sometimes don't load (limbs missing or default).
2. The whole game sometimes doesn't load or breaks when joining, and when teleporting into a match.
3. Getting stuck on the map select (vote never finishes).
4. A match starting before every player has loaded in.
5. UI images and skin models go white / glitch for a moment the first time they're shown (Locker, Shop, previews).
6. Wants a new loading screen at the start of a lobby game (and wherever loading happens) with the Draft Duels logo, RIVALS-like, with a good loading sound.

## Phase 1: reproduce and fix the game-breakers
Find the real cause of each report with logs and timings before changing code (`roblox-debugging`: reproduce, isolate, bisect, verify). Likely places to start (check, don't assume):
- **Join / teleport:** `src/first/LoadingScreen.client.luau` (takes the lobby's teleport gui), `src/lobby/server/Matchmaking/Launcher.luau` (TeleportService), `src/lobby/client/Controllers/MatchFoundController.luau`, `src/server/Services/MatchHost.luau`, `src/server/MatchKit/MatchRunner.server.luau`, the client host/runner bootstrap in `src/client/init.client.luau` (`ServerRole`, `PlayZone`). Look for WaitForChild timeouts, races between PlayerAdded and character / data load, StreamingEnabled lookups cached on streamed models.
- **Stuck map vote / start without players:** `MapVoteController` (client), the server vote and round start in `MatchHost` / `MapService` / `MatchKit`. The match should wait for every expected player (teleport data roster) to be ready (character + `DataReady` + client "ControllersReady"), with a timeout that drops no-shows cleanly instead of hanging.
- **Body skins not loading:** `src/client/Controllers/BodySkinController.luau`, `src/shared/MatchBody.luau` (limbs in `Workspace.GGBodyLimbs`), `Config/Avatar`. Check asset load failures, retries, and characters that stream in late.
- Add a short **health log** (Studio + live): one line per stage (joined, data ready, character, controllers ready, map loaded, round start) with timings, so the next report can be traced.

## Phase 2: loading screen v2
- Study RIVALS' loading / intro first (layout, timing, logo motion, how long it holds, skip rules) and capture only what's needed.
- Art: the approved [Draft Duels Logo](../02%20Art/Draft%20Duels%20Logo.md) (Draft Ticket in Lobby Gold; layered sprites and the two-beat reveal in `art-source/ui/draft-duels/draft-ticket-lobby-gold/`). Studio-built screen, Soft Edge theme, phone + PC + console layouts.
- Shows at the start of a lobby server join and on every teleport into a match (replacing the current `LobbyLoading` teleport gui), with a progress line (real stages from phase 1, not a fake bar) and tips.
- **Sound:** a short branded loading sting + quiet bed; audition 3-5 licensed options with the owner first (memories: designed, not synth; few, auditioned UI sounds). Routed through Settings MUSIC / MASTER (`Shared/SettingsApply` groups).
- Ask the owner: hold time vs skip button, music bed or sting only, show on every teleport or only the first join.

## Phase 3: preload
- One preload manifest in `Config` (UI images, item portraits / renders, skin meshes and textures for the player's equipped loadout, gun meshes, VFX textures, core sounds), loaded with `ContentProvider:PreloadAsync` behind the loading screen, in priority order (what the first screen needs first), with a time cap so a bad asset never blocks the join.
- Existing preloads to fold in: `AudioController.preload`, `EffectsController`, `HitFx`, `WinCutscene`, `UiSfx.preload`, `Simulation/Poses`.
- Fix the white flashes at their source too: Locker / Shop / previews should load their images and models before showing them (or show a placeholder plate, never white), and new skins preload when equipped or hovered.
- Measure before / after (time to playable on phone and PC, memory), per `roblox-performance-audit`.

## Phase 4: optimization pass
- MicroProfiler and memory on a phone-class device in the lobby, a pad duel and a match; fix the biggest costs first (scripts per frame, render, network, memory growth across rounds). Use the measured-check skills where they fit (`rbx-frame-time-regression`, `rbx-instance-retention-audit`, `rbx-asset-access-matrix` for assets that fail for normal players).

## Done when
- Reports 1-5 can't be reproduced (with the steps written down), the health log shows every stage, the new loading screen + sound is approved by the owner, first-time UI / skins don't flash, and the results and remaining risks are in this note, `00 Home.md` Status and `Bugs & Ideas.md`.
