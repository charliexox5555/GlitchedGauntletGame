# Match damage and reset

## Reproduction and fixes

- Three rejected shots moved the client's shot counter beyond the server's allowed gap. Three subsequent shots with a valid origin were rejected for the counter mismatch. The server now resends the weapon state and issues a fresh spread seed when the counter gets too far ahead. Queued shots from before that correction expire.
- The match restarted during a round transition after Roblox rejected a Player attribute write with `Attribute total payload exceeds 1024 bytes`. The match now puts saved skin choices on a replicated `LockerSkins` folder under the Player, leaving room for the Player's combat attributes. The match loop logs a traceback if a future match error occurs.

The fixes follow the server-owned hit validation and round state described in [Arena Shooter with Server-Checked Hits](../../LihFolk/24%20Worked%20Builds/Weekend%20Build%20-%20Arena%20Shooter%20with%20Server-Checked%20Hits.md) and [Match Flow](../../01%20Design/Match%20Flow.md).

## Studio retest

- In a main-place 1v1 bot match on OldTown2, a valid hit reduced the bot to 72 HP. Three deliberately invalid shot origins left it at 72 HP. The first shot with a valid origin triggered the counter correction. The next shot dealt 38 damage and the following shot downed the bot in the same round.
- The match loaded 18 equipped skins in the folder. All three ability slots filled by round three, and the match advanced through five rounds, the replay, and the visible 5–0 results screen. The equipped Phantom resolved to its saved Inkshift skin on the world gun.
- StyLua, Selene and the Rojo build passed. The gameplay run used one Studio client and one bot.
