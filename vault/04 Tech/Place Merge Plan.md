# Place Merge Plan (2026-11-21)

The owner's call: **the Lobby and the match become one place.** Everything runs together.

## Owner decisions (2026-11-21)
| Question | Answer |
|---|---|
| Which place stays | **Lobby place** (PlaceId 71551303511506). Maps, match assets and match code move into it. The match place (133387545285290) is retired and kept as a backup. |
| UI queue (PLAY → FIND MATCH) | **Global, across all servers.** Matched groups teleport to a **restricted private server of the same place** (a reserved server) to play. |
| Duel pads in the lobby | Start the duel **in this server**: the match is built and played inside the lobby server. Pads look different while filling. |
| Pad duels per server | **Several at once.** Each duel has its own state, map copy, players and UI. |
| Pad that isn't full | **Real players only.** It waits until every slot has a player from this server, counts down, then starts. No bots. |
| Range this pass | **Guns only.** Enter the range and get your Locker loadout (real match guns, skins, ADS, reload) to shoot dummies. Leaving takes the guns away. Mods come later. |

## Where it starts from (code survey)
- Two codebases: Lobby `src/lobby/*` (Queue, Parties, Shop, Locker, PlayerData, Settings, Range teleport) with `lobby.project.json`; match `src/server` + `src/client` (~9,000 server lines) with `default.project.json`. They already live in separate containers (`LobbyServer` / `Server`, `LobbyClient` / `Client`) and separate remote folders (`LobbyRemotes` / `Net`), so they can be in one tree without name clashes. Duplicated behaviour to fold: `ServerInfoService`, `NetStatsController`, `SoundAuditionController`.
- The queue (`QueueService` + `Matchmaking/Matchmaker` + `Launcher`) only matches **inside one server**, then teleports to a reserved match server with TeleportData (`v, matchId, mode, teams, bots`), which the match reads in `Bots/MatchPlan`.
- **The match code assumes one match per server.** Match state is one folder in ReplicatedStorage (`shared/MatchState`), services keep module-level state (`MatchService` plan, stand-ins, teams; `DraftService`, `MapService`, `BotService`, Mods …), and 23 services use `Players.PlayerAdded` / `GetPlayers` as "everyone is in the match". Clients read the one MatchState folder.
- The match already has a **test range mode** (`TestRangeService` + `TestRange/Dummies`): dummies get shot through the normal `WeaponService` checks; reserve ammo is endless in test mode. The lobby range (`RangeService`) only moves bodies today.

## Target architecture
- **One place, two server roles** (`shared/ServerRole`):
  - **Lobby**: a public server. Lobby world + lobby UI; the range; **pad duels** run here as match instances.
  - **Match**: a reserved server of the same place (`game.PrivateServerId ~= ""` and `PrivateServerOwnerId == 0`) holding one queued match. The lobby UI is hidden; data services (PlayerData, Settings, Locker loadout) still run. When the match ends, players go back to a public Lobby server, parties together.
  - Studio: `workspace` attribute `ServerRole` = `"Match"` tests the match role; default Lobby.
- **Match instances** (for pad duels; the reserved server runs exactly one): each duel is its own context with its own state folder (`ReplicatedStorage.Matches.<id>`), player list, map copy far from the lobby, and remote scoping (only its players' events reach it, and it only fires to them). Players carry a `MatchId` attribute; the client's MatchState follows the local player's match and is empty in the lobby, so match controllers sleep and the lobby HUD shows.
- **Global queue:** MemoryStore holds the waiting groups for each mode; one server at a time (a lease that expires) runs `Matchmaker.pack` over all of them, reserves one server per match, and tells each group's home server (MessagingService, topic per JobId) to teleport its players there with the TeleportData. The current bot fill after `fillAfter` stays. Groups are removed when they cancel, leave or their server shuts down (TTL as the backstop).

## Phases (each one a working, committed step)
1. **Foundation.** One project file (`default.project.json` = lobby + match trees), `ServerRole`, both code sets boot together; match services sleep in the Lobby role until a match instance or the range asks for them. Duplicates folded.
2. **Global queue.** MemoryStore queue + matchmaker lease + MessagingService handoff, teleport to a reserved server of this place, return to a public lobby after the match. Can't be fully tested in Studio (no teleports): needs a published test with two accounts.
3. **Range guns.** Entering the range gives the Locker loadout through `WeaponService` (endless reserve), the lobby range's dummies take hits through the normal checks, leaving removes the guns and the viewmodel.
4. **Match instances (pad duels).** Scope MatchState, remotes, the player list and map placement per match; pads fill with players from this server, count down, start a duel; players come back to the lobby afterwards. Several duels at once.
5. **Studio move.** The 12 release maps, map kits, ambience, MaterialService variants and match-only assets copied from the match place into the Lobby place; save; check every map loads in both roles.

## Open questions (ask as they come up)
- Pad duel map: map vote (as now) or one map per pad? Default: vote among maps that fit the size.
- Can lobby players watch a pad duel? Default: not in this pass.
- What players see while a pad fills (count over the pad, ring fill)? Default: a player count and a fill ring in the pad colour.

## LihFolk notes used
`41 Multiplayer Services`: Teleporting and Multi-Place Games; Reserved and Private Servers in Practice; TeleportService - Engine Reference Card; Matchmaking Queues with MemoryStore; MemoryStore Service; Error Handling and Retries.

## Results
(filled in per phase)
