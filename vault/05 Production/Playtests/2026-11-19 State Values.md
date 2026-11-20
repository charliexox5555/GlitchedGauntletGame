# State values playtest

- **Oversized results.** A simulated 3v3 snapshot sent through MatchEndService had six fighter rows, nine rounds and 1,236 encoded bytes. The desktop client displayed VICTORY and the fighter rows.
- **Match.** Local Studio Play under Automatic authority with one human and three bots. Map vote and draft ran, bots moved and took damage, and successive live rounds used the health service to speed up the result. The desktop results screen opened with 5–1, six round markers and four fighter rows. Voting Rematch opened a new map vote and round one cleared the previous results.
- **Lobby.** Local Studio Play joined the 2v2 queue, saw searching status and a queue count of one, then left and returned to idle. The client read Lobby V4 configuration from the module.
- **Scene audit.** The open Match scene migrated 21,606 authored fields and the open Lobby scene migrated 9,180. Roblox owns the two reserved refinement attributes found in the Lobby NPC assets. No game Attributes remain in the scoped scene assets. Archives and reference assets were outside the migration.
- **Repository.** StyLua, Selene and both Rojo builds passed. The migration is staged in the open Studio places. Live teleports and multiplayer clients were outside this Studio run.
