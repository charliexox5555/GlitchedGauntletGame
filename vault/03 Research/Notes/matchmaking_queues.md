# Matchmaking & Queue Systems on Roblox for a Competitive Ability-Draft Shooter (1v1–4v4 + 16-player "Gauntlet")

> Research date: 2026-10-17. Method note: create.roblox.com, devforum.roblox.com and most non-GitHub sites could not be fetched directly from this environment (egress proxy refused). Roblox's official documentation was therefore read from its source repo, **Roblox/creator-docs on GitHub (latest commit 2026-10-16)**, which is what create.roblox.com renders. Citations point to the GitHub source files; the equivalent live page is the same path under `https://create.roblox.com/docs/...`. Open-source Luau modules were read by cloning their GitHub repos. Non-Roblox and community facts come from web-search result summaries (pages not opened in full); treat those as lower confidence and they are marked "(search summary)".

## 1. Roblox built-in tools: MemoryStoreService, MessagingService, TeleportService, Party API, Custom Matchmaking, open-source samples

### Takeaway
The current (Oct 2026) toolset for a queue → match flow is: **MemoryStore** (queue / sorted map / hash map) for tickets and locks, **MessagingService** for best-effort notifications, **TeleportService:ReserveServerAsync + TeleportAsync with TeleportOptions** to send a matched group to a private match server, and the newer **Party API** (`Player.PartyId`, `SocialService:GetPartyAsync/GetPlayersByPartyId`) for Roblox-native parties. Roblox's **Custom Matchmaking** (GA since Nov 2025) only scores *public* servers on join, and explicitly filters out reserved servers, so it helps lobby placement but cannot form 1v1/2v2 matches for you. Several APIs older tutorials use are now deprecated (`ReserveServer`, `TeleportPartyAsync`, `TeleportToPrivateServer`, client `Teleport`).

### Cited Findings

**MemoryStoreService: quotas and limits (current docs)**
- Three structures: sorted map, queue, hash map. Roblox's own docs list "Skill-based matchmaking: save user information, such as skill level, in a shared **queue** among servers, and use lobby servers to run matchmaking periodically" as a primary use case. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md)
- Decision guide in the docs: need ordering → sorted map; need to scan all items and expect fewer than 1,000 keys → sorted map; otherwise hash map; need processing in order → queue. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md)
- **Memory quota = 64 KB + 1.2 KB × [number of users]**, applied per game (universe), not per server. When users leave, the quota does not drop right away: there is an **8-day traceback** before it is re-evaluated down. Once the quota is hit, writes that grow memory fail. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md)
- **Request-unit quota = 1000 + 120 × [concurrent users] per minute**, game-wide. Most calls cost 1 unit. Exceptions: `SortedMap:GetRangeAsync()` costs 1 unit per returned item (minimum 1). `Queue:ReadAsync()` costs 1 per item returned, plus 1 more for every 2 s it waits (`waitTimeout`). `HashMap:UpdateAsync()` costs at least 2. `HashMap:ListItemsAsync()` costs partitions scanned + items returned. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md)
- Per-structure caps: max 1,000,000 items and 100 MB for a single sorted map or queue. Item value max 32 KB (`ItemValueSizeTooLarge`). Expiration must be 0–3,888,000 s (45 days), and 45 days is also the default TTL for `Queue:AddAsync` and `SortedMap:SetAsync`. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md)
- **Per-partition limits:** each sorted map and each queue lives on **one partition**, while hash maps spread across many. Throttling begins at roughly **30,000 request units/min per partition**. Hash map keys also have a limit of about **5,000 write and 15,000 read units/min per key**. When exceeded, calls return `PartitionRequestsOverLimit`. The status-code table separately lists `DataStructureRequestsOverLimit` at "100,000 request units per minute". These two figures are not reconciled in the docs, so plan around the lower ~30k/min figure. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md); [Roblox docs: Partitions](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/per-partition-limits.md)
- Docs warn that "additional, undocumented limits might apply". Best practices: always pcall, use exponential backoff on `DataUpdateConflict`, remove processed items explicitly, use short TTLs as a safety net, shard large structures, and use an **Observability dashboard** for live quota and status-code charts. Extended Services enrollment can raise quotas. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md)
- Studio uses data isolated from production but has the **same quotas**, so user-scaled quotas are tiny in Studio when you are the only user. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md)
- **Queue semantics:** `GetQueue(name, invisibilityTimeout)`. The default invisibility timeout is 30 s. `ReadAsync` hides read items from other readers until you `RemoveAsync(id)`; if you do not remove them in time, they reappear. `AddAsync(value, expiration, priority)`: higher priority is read first, and FIFO applies within a priority level. `GetSizeAsync(excludeInvisible)` counts invisible items unless you pass `true`. — [Roblox docs: Memory store queue](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/queue.md); [MemoryStoreQueue API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/MemoryStoreQueue.yaml)
- A community DevForum thread notes that a player cannot be removed from a MemoryStore *queue* by key once added, which complicates cancel-queue and party flows. (search summary) — [DevForum: Player matchmaking with Memory service](https://devforum.roblox.com/t/player-matchmaking-with-memory-service/1760150)
- **Sorted map:** key ≤128 chars, value ≤32 KB, sort key ≤128 chars. Sort keys may be numbers or strings, and numeric sort keys sort before string ones. `GetRangeAsync` accepts lower/upper bounds on `sortKey`; the docs example uses `sortKey` 100–500, which is exactly an MMR-window query. — [Roblox docs: Sorted map](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/sorted-map.md)

**MessagingService**
- Delivery is "typically within 1–2 seconds" and is **best effort and not guaranteed**. Topics are 1–80 chars. — [MessagingService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/MessagingService.yaml)
- Limits ("subject to change"):
  - Message size: 1 kB.
  - Sends per server: 600 + 240 × players-in-server per min.
  - Receives per topic: 40 + 80 × servers per min.
  - Receives game-wide: 400 + 200 × servers per min.
  - Subscriptions per server: 20 + 8 × players.
  - Subscribe requests: 240/min per server.
  — [MessagingService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/MessagingService.yaml)

**TeleportService: current vs deprecated**
- `TeleportAsync(placeId, players, TeleportOptions?)` is "the all-encompassing method". It is **server-only**, teleports groups only within one experience, and is limited to **50 players per call**. — [TeleportService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TeleportService.yaml)
- **OUTDATED-API FLAG:** `TeleportService:ReserveServer` is now tagged **Deprecated** ("Use ReserveServerAsync()"). `TeleportPartyAsync` and `TeleportToPrivateServer` are Deprecated ("Use TeleportAsync() instead"). Client-side `Teleport()` is "not recommended for new work". Most DevForum tutorials and the open-source modules below still call `ReserveServer`. — [TeleportService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TeleportService.yaml)
- `ReserveServerAsync(placeId)` returns an access code plus the `PrivateServerId`. A server starts on first use of the code, and **codes remain valid indefinitely**: if no server is running, a new one starts. To detect a reserved server: `game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0`. Console players with cross-play disabled can land on a *different* game server with the same `PrivateServerId`; distinguish them with `DataModel.MatchmakingType` (Default / XboxOnly / PlayStationOnly). — [TeleportService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TeleportService.yaml); [MatchmakingType enum](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/MatchmakingType.yaml)
- `TeleportOptions` has these members: `ReservedServerAccessCode`, `ServerInstanceId` (specific public server), `ShouldReserveServer` (create a new reserved server inline), and `SetTeleportData`/`GetTeleportData`. Teleport data is **client-visible and unencrypted**, so it must not carry secure data. Use DataStore or MemoryStore for authoritative match manifests. Read arriving data with `Player:GetJoinData().TeleportData`. — [Roblox docs: Teleport between places](https://github.com/Roblox/creator-docs/blob/main/content/en-us/projects/teleport.md); [TeleportOptions API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TeleportOptions.yaml)
- Failure handling: wrap calls in pcall and retry (the docs say "some failures benefit from retries, particularly those involving reserved servers"). A call that succeeds can still fail late without throwing. That fires `TeleportService.TeleportInitFailed`, so handle it to re-queue or retry. The docs provide a `SafeTeleport` module pattern. TeleportService does not work in Studio playtests. — [Roblox docs: Teleport between places](https://github.com/Roblox/creator-docs/blob/main/content/en-us/projects/teleport.md)
- Security settings (newer naming): **Access Control for Places** = Fully open / Limited to same universe / **Secure within universe only**. The last option allows only server-initiated teleports into non-start places and is recommended "for places that exclusively use reserved servers". `SetTeleportGui` sets a custom loading screen; its scripts do not run. — [Roblox docs: Teleport between places](https://github.com/Roblox/creator-docs/blob/main/content/en-us/projects/teleport.md)

**Party API (new since 2025)**
- `Player.PartyId` is a read-only string, empty if the player is not in a party. `SocialService:GetPlayersByPartyId(partyId)` returns party members in *this* server. `SocialService:GetPartyAsync(partyId)` returns all party members currently in the experience **across all servers**, ordered by invite-accept time (so element 1 can serve as leader). Fields include UserId, PlaceId, JobId, and more. It is meant for "coordinated group behavior such as teleportation, matchmaking". — [SocialService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/SocialService.yaml); [Player API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Player.yaml)
- Studio has a **Party Simulator** that assigns test players to simulated parties, so PartyId, GetPartyAsync and GetPlayersByPartyId return simulated data. — [Roblox docs: Studio testing modes](https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/testing-modes.md)
- DevForum announcement: "Party API Is Here!" (search summary). — [DevForum announcement](https://devforum.roblox.com/t/party-api-is-here-enable-connected-player-experiences-and-drive-deeper-engagement/3676068)

**Roblox Custom Matchmaking (server-placement scoring)**
- Flow: a player requests to join → Roblox filters out servers that are **full, private, reserved**, or shutting down → scores the remaining servers by a weighted sum of signals (each signal is 0–1, weights are ≥0) → the highest score wins. — [Roblox docs: Matchmaking](https://github.com/Roblox/creator-docs/blob/main/content/en-us/matchmaking/index.md); [Roblox docs: Server scoring](https://github.com/Roblox/creator-docs/blob/main/content/en-us/matchmaking/scoring.md)
- Built-in signals: Age, Device Type, Friends, Language, Latency, Occupancy, Play History, Voice Chat, and Text Chat. Limits: **2 custom signals**, **5 player and 5 server custom attributes** per game. Player attributes are read from a DataStore key template (`{UserId}`) plus a JSON value path. Numerical signals aggregate by Average, Median or Sum; categorical signals by Cluster or Diversify. Configure it in Creator Dashboard → Configurations → Custom matchmaking, where you can preview against mock servers and apply per place. — [Roblox docs: Customize matchmaking](https://github.com/Roblox/creator-docs/blob/main/content/en-us/matchmaking/customize-matchmaking.md); [Attributes & signals](https://github.com/Roblox/creator-docs/blob/main/content/en-us/matchmaking/attributes-and-signals.md)
- `MatchmakingService:SetServerAttribute(name, value)` / `GetServerAttribute` let a server publish its state, for example "mode=Ranked" or an average MMR. Name and value are each ≤50 chars. `InitializeServerAttributesForStudio` supports Studio tests. — [MatchmakingService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/MatchmakingService.yaml)
- Timeline: beta "Custom Matchmaking with Custom Signals" (DevForum 3598471, 2025). GA for all experiences was announced on DevForum (4051419), and Bloxy News reported it around 2025-11-06. (search summary) — [DevForum beta](https://devforum.roblox.com/t/beta-introducing-custom-matchmaking-with-custom-signals/3598471); [DevForum GA](https://devforum.roblox.com/t/custom-matchmaking-is-now-available-to-all-experiences-on-roblox/4051419); [Bloxy News](https://x.com/Bloxy_News/status/1986580925128581219)
- Community complaints (search summary):
  - Roblox spreads players across 4–5 small servers instead of filling configured slots (Mar 2025 bug report).
  - A later feature request says matchmaking prioritizes existing servers "even when those servers are not an ideal match", and asks for a toggle to prefer new servers.
  — [DevForum bug](https://devforum.roblox.com/t/roblox-does-not-fill-servers-according-to-configured-settings/3530280); [DevForum feature request](https://devforum.roblox.com/t/option-to-prioritize-new-server-creation-through-custom-matchmaking/4526757)

**Open-source matchmaking modules**
- **MatchmakingService (steven4547466):** MemoryStore-based and cross-server, with optional **OpenSkill** rating, party queueing (`QueueParty`), and per-map player ranges. Its DevForum thread title says "ON HOLD", and the last GitHub commit is 2023-05-26. It uses six **sorted maps** (not queues) plus MessagingService topics. Its FAQ cites old limits ("1000 + 100 × players", a "1kb" value limit that is now 32 KB), so it is **outdated** but useful as reference architecture. — [GitHub: steven4547466/MatchmakingService](https://github.com/steven4547466/MatchmakingService); [DevForum thread](https://devforum.roblox.com/t/v203-matchmakingservice/1483736)
- **Match (g0ofycat):** MIT licensed, last commit 2026-05-10. Features:
  - Modes × SubModes (default `Casual`/`Ranked` × `1v1`…`4v4`), with **one MemoryStore sorted map per mode/sub-mode** (e.g. `MatchQueue_Casual_1v1`).
  - Elo window `ELO_CHANGE=200`, widening by `ELO_INCREASE_RATE=50` per loop.
  - Loop every `CHECK_MATCHMAKING_INTERVALS=5` s, queue timeout `MATCHMAKING_DURATION=300` s.
  - Player **locks** with `LOCK_TIMEOUT=10` s, to stop two servers matching the same player.
  - `TELEPORT_RETRIES=3`, continent grouping, an experimental PartyManager, and cross-server match creation via MessagingService.
  — [GitHub: g0ofycat/Match](https://github.com/g0ofycat/Match); [DevForum: Match](https://devforum.roblox.com/t/match-customizable-matchmaking-module/3985013)
- Other community tutorials: "Matchmaking: How to use MemoryStoreQueue" and "How to make a cross-server matchmaking system (full tutorial)" (search summary; not opened). — [DevForum tutorial 1](https://devforum.roblox.com/t/matchmaking-how-to-use-memorystorequeue/1515961); [DevForum tutorial 2](https://devforum.roblox.com/t/how-to-make-a-cross-server-matchmaking-system-full-tutorial/2707983)
- No Roblox-maintained matchmaking sample or module was found. (search summary) — [search: Roblox MatchmakingService open source](https://github.com/steven4547466/MatchmakingService)

### Inferences
- **Recommended data layout:**
  - One **sorted map per queue** (`Q_1v1`, `Q_2v2`, `Q_3v3`, `Q_4v4`, `Q_Gauntlet`, plus Ranked variants). Key = ticketId (partyId or userId), sortKey = MMR, value = {members, mmr, enqueuedAt, region, jobId}, TTL ≈ 120 s and refreshed by a heartbeat. This allows cancel-by-key, which queues lack, and MMR-window `GetRangeAsync`.
  - A **hash map** for per-player state (`InQueue`/`Matched`/`InMatch`), match manifests (`matchId → teams, draft seed, accessCode`), and a leader lock.
- **Single-matchmaker pattern:** elect one lobby server as matchmaker per queue using a hash-map `UpdateAsync` lock with a TTL of about 10–15 s, renewed by heartbeat. The other servers only write tickets. This prevents double-matching, and it keeps `GetRangeAsync` costs (1 unit per item) off N servers.
- **Quota math at launch:** at 50 CCU the request quota is 1000 + 6000 = 7,000 units/min. If one matchmaker scans 5 queues × ~20 tickets every 2 s, that is ~3,000 units/min. Running the same scan on 5 lobby servers would be ~15,000/min, which exceeds quota. A single matchmaker is close to mandatory at low CCU. Memory quota at 50 CCU is only ~124 KB, so keep tickets small (≈200–300 bytes) and use short TTLs.
- **Match handoff:**
  1. Matchmaker writes the match manifest to the hash map.
  2. Lobby servers learn of it by polling their own players' state keys, or via a MessagingService hint (best effort, so never rely on it alone).
  3. Each lobby server calls `TeleportAsync(matchPlaceId, itsPlayers, opts)` with `opts.ReservedServerAccessCode` from a single `ReserveServerAsync` call made by the matchmaker.
  4. The match server reads the manifest by `PrivateServerId`/matchId from MemoryStore. It does not trust TeleportData beyond a matchId.
- **Use Custom Matchmaking for the lobby place only:** for example, a custom server attribute "lobby skill band" or Latency weighting so lobby servers cluster by region and skill. It cannot form duels, because reserved match servers are excluded from its scoring.
- Set the match place's Access Control to **Secure within universe only**, so players cannot join match servers directly.

### Gaps
- No official Roblox numbers found on reserved-server spin-up time, teleport latency, or teleport failure rates.
- Could not open the DevForum Party API announcement or the Custom Matchmaking GA post to confirm exact dates and any party-teleport helper.
- The 100,000 vs ~30,000 units/min per-structure inconsistency in the docs is unresolved.
- No 2026-specific MemoryStore quota change announcement found. The formulas above are what the docs say as of 2026-10-16.

## 2. In-place (in-lobby arenas) vs teleporting to reserved match servers

### Takeaway
RIVALS uses **both**. In-lobby "Duel Zone" pads match people in the same server and fight in arenas inside that lobby, which is instant with no teleport. The global "Play" button matchmakes across servers into private servers. For a low-CCU launch, in-place matching is fastest and simplest. Cross-server reserved matches become necessary for ranked integrity, larger pools, and the 16-player Gauntlet once lobbies fragment.

### Cited Findings
- RIVALS lobby: each lobby has a Duel Zone where players step on a pad for a team size. Once enough players ready up, they are moved "to a match within that same lobby". The zone supports standard duels and 1v1v1/2v2v2. Parties do not work on these pads. (search summary of wiki) — [RIVALS wiki (Miraheze): Updates](https://robloxrivals.miraheze.org/wiki/Updates); [RIVALS wiki (Fandom): Lobby](https://robloxrivals.fandom.com/wiki/Lobby)
- RIVALS "global matchmaking" (Update 2, July 2024) connects players to private servers for 1v1–5v5, FFA, TDM, Ranked and LTMs, and was described as placing players "almost instantly". Parties can queue together, but not while any member is in a duel. (search summary) — [Sportskeeda: Rivals Update 2](https://www.sportskeeda.com/roblox-news/news-roblox-rivals-update-2-global-matchmaking-new-charms-balance-changes); [RIVALS wiki (Fandom): Gamemodes](https://robloxrivals.fandom.com/wiki/Gamemodes)
- The RIVALS lobby is also a warm-up space for testing weapons and repeat challenges. Matches start with a map vote. (search summary) — [GameBoost: Rivals maps](https://gameboost.com/blog/roblox-rivals-maps-ranked)
- Reserved servers are excluded from Roblox's public matchmaking scoring, so a reserved match server never receives random joiners. — [Roblox docs: Matchmaking](https://github.com/Roblox/creator-docs/blob/main/content/en-us/matchmaking/index.md)
- A DevForum tutorial contrasts same-server matchmaking, where each server runs its own queue logic, with cross-server approaches. (search summary) — [DevForum: Matchmaking System Tutorial](https://devforum.roblox.com/t/matchmaking-system-tutorial/1366126)
- Teleport constraints: a teleport discards local state, the destination must load, failures can be silent (`TeleportInitFailed`), and there is a 50-player cap per call. — [Roblox docs: Teleport](https://github.com/Roblox/creator-docs/blob/main/content/en-us/projects/teleport.md); [TeleportService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TeleportService.yaml)

### Inferences
- **Trade-off summary:**

| | In-lobby arenas | Reserved match server |
|---|---|---|
| Queue start | Instant, no load screen | Teleport + place load each match |
| Pool size | Capped at the lobby's players | All servers |
| Rematch loop | Fast | Slower |
| Lobby social feel | Kept (spectating, flexing) | Lost during the match |
| Fairness and isolation | Weaker: performance shared with lobby, harder anti-cheat | Clean server per match, good for ranked |
| Size | Lobby server must hold many arenas (instances, streaming, memory) | Small server sized to the mode (2–8, or 16 for Gauntlet) |
| Ranked integrity | Weaker | Stronger |

- Roblox does not bill creators per server-hour, as far as is known. That was not verified in this session, so the real "cost" difference is engineering complexity and player time, not money.
- **Recommended hybrid (RIVALS-like):**
  1. Default to **in-server matching first**: if enough compatible tickets exist in the same lobby, use a local arena immediately.
  2. After ~10–20 s with no local match, the ticket goes to the **global MemoryStore pool** and the match runs in a reserved server.
  3. Run Ranked and Gauntlet **always in reserved servers**, for clean state, consistent performance, and leaver detection.
  4. Ability draft UI can run in the lobby before teleport (players see the draft while the server spins up), or in the match server. Running it in the match server is simpler and more authoritative.
- Size lobby servers so 4v4 (8 players) can form locally. A lobby max of 30–40 with ~6–8 arena instances lets most casual matches stay local at low CCU.

### Gaps
- No official RIVALS dev statements on their architecture were found. The above is from community wikis.
- No data on Roblox server cost or performance for many simultaneous arenas in one server.

## 3. Party/duo queues, cross-server invites, backfill, rematch, leaver penalties

### Takeaway
Use Roblox's native **Party API** (`PartyId` + `GetPartyAsync`) as the primary party source, plus an in-game invite flow for players not in a Roblox party. Treat a party as one ticket with an aggregated MMR and cap MMR spread in Ranked. RIVALS' precedent: parties blocked while a member is in a duel, an 800-Elo party spread cap in Ranked, and a 15-minute lockout plus an automatic loss for leaving Ranked.

### Cited Findings
- `GetPartyAsync` returns cross-server party state, with each member's PlaceId and JobId, ordered by join. The docs present it for "teleportation, matchmaking, or party-based gameplay logic". — [SocialService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/SocialService.yaml)
- The teleport guide suggests getting a whole group via `Player.PartyId` + `SocialService:GetPlayersByPartyId()` and teleporting them together. If no server is specified, "the information of the first user in the list is used for matchmaking". — [Roblox docs: Teleport](https://github.com/Roblox/creator-docs/blob/main/content/en-us/projects/teleport.md)
- `TeleportPartyAsync` is deprecated, so use `TeleportAsync` with a player array instead. — [TeleportService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TeleportService.yaml)
- MessagingService can be used to find friends across servers. The docs' example topic "FriendServerEvent" fires when a user is teleported. — [Roblox docs: Cross-server messaging](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/cross-server-messaging.md)
- MatchmakingService (open source) "does not handle party creation". It only guarantees that a queued group lands in the same game. — [GitHub: MatchmakingService FAQ](https://github.com/steven4547466/MatchmakingService)
- The Match module's PartyManager API: CreateParty, AddPlayer, RemovePlayer, QueueParty (the README suggests using the leader's Elo), StopParty and DeleteParty. Teleport data includes a `Parties` mapping so the match server can keep premades on the same team. — [GitHub: g0ofycat/Match](https://github.com/g0ofycat/Match)
- RIVALS:
  - Parties can't queue while a member is in a duel.
  - Ranked parties must be within 4 tiers (800 Elo).
  - Leaving a Ranked match = **15-minute matchmaking lockout + automatic loss**.
  - Daily "ELO Shield" below Platinum I (1,800).
  (search summary of community wikis; values change between updates) — [RIVALS wiki (Miraheze): Ranked](https://robloxrivals.miraheze.org/wiki/Ranked); [AllThings.How: Rivals ranked](https://allthings.how/roblox-rivals-ranked-mode-and-ranks-explained/)
- Valorant Gauntlet: Glitched lets players queue solo or as a duo with **no rank restriction** on duo partners (Riot's example: Diamond + Bronze). (search summary) — [games.gg guide](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/); [AllThings.How: Gauntlet Glitched](https://allthings.how/valorant-gauntlet-glitched-how-the-8-duo-ability-draft-mode-works/)
- Call of Duty's matchmaking blog says that long waits lead players to cancel and re-queue or leave, which does not speed matchmaking and can make it worse. (search summary) — [Call of Duty: Inside look at matchmaking](https://www.callofduty.com/blog/2024/01/call-of-duty-update-an-Inside-look-at-matchmaking)

### Inferences
- **Party ticket:**
  - One ticket per party, keyed by `PartyId` (or an internal party GUID).
  - Ticket MMR = a weighted mean that leans toward the top player, e.g. `max*0.6 + mean*0.4`, or OpenSkill team μ sum. This deters boosting low-rated alts.
  - In Ranked, refuse parties with MMR spread above ~2 tiers for 2v2 or ~4 tiers for 3v3/4v4, following RIVALS' 800-Elo precedent.
  - Casual and Gauntlet: no restriction (follows the Valorant duo precedent).
- **Party composition fitting:**
  - 2v2: solo+solo vs duo is allowed, but prefer duo vs duo when both are queued.
  - 3v3/4v4: a bin-packing step fills teams from party sizes, e.g. 4v4 = [2+2] vs [2+1+1], with a preference to put premades against premades.
- **Cross-server invite:** an invite is written to the target's hash-map inbox key (polled by the target's server every few seconds) plus a MessagingService ping for speed. On accept, teleport the invitee to the leader's `JobId` via `TeleportOptions.ServerInstanceId` (lobby) before queueing.
- **Backfill:**
  - Avoid backfill in 1v1 and Ranked.
  - For casual 3v3/4v4, allow backfill only in the first round(s), from a high-priority "backfill" ticket (sorted-map or queue priority).
  - Gauntlet: no backfill. A disconnected duo partner leaves the teammate playing 1v2, or a bot substitutes and the duo loses the right to rewards.
- **Rematch:** after a match, show a 10–15 s "Rematch?" vote. If everyone accepts, reuse the same reserved server: re-run the draft and reset the arena, with no teleport. Otherwise, teleport back to the lobby with a "requeue" flag in TeleportData so the lobby auto-enqueues them, and refresh MMR from the DataStore.
- **Leavers:**
  - Ranked: automatic loss + escalating lockout (5 → 15 → 60 min within 24 h).
  - Casual: no Elo, but short (1–2 min) lockouts for repeat leavers.
  - Gauntlet: a leaver forfeits the run. Their partner continues and earns placement rewards.
  - Distinguish disconnects (Players.PlayerRemoving without a clean exit) from rage-quits only where feasible. RIVALS applies the penalty "regardless of the reason".

### Gaps
- Could not confirm how RIVALS aggregates party MMR or whether it allows backfill.
- No primary data on optimal leaver-penalty durations.

## 4. Skill-based matchmaking & ranked: rating systems, widening windows, per-queue MMR, tiers, placements

### Takeaway
For 1v1, Elo or Glicko-2 works. For 2v2–4v4 and the 8-team Gauntlet, use **OpenSkill (Weng-Lin, Plackett-Luce)**: it is open-licensed, handles teams and multi-team rankings natively, and the open-source Roblox MatchmakingService already ships a Luau port. Keep a hidden MMR (μ, σ) per queue, show a separate visible rank/tier ladder (RIVALS: 200-Elo tiers, 10 placements), and widen search windows over time. Apex in 2026 found that holding a strict window longer (60 s vs 30 s) improved quality without much queue-time cost.

### Cited Findings
- OpenSkill (openskill.py, actively maintained, last commit 2026-02):
  - Multiplayer and multi-faction, supports asymmetric team sizes, and predicts win/draw/rank. Supports weights and score margins.
  - Five models. Its authors claim it is "150% faster than TrueSkill" with "accuracy [that] matches TrueSkill" under an "Open License". Peer reviewed in JOSS (DOI 10.21105/joss.05901).
  - Default rating μ=25, σ=25/3≈8.333 (Plackett-Luce). μ=25, σ=8 means ~95% confidence of skill in 9–41.
  - Use `ordinal` for leaderboards/sorting, and turn on `limit_sigma` to keep leaderboard order stable.
  - Time decay: add a small σ increase per inactive day, up to the default σ.
  - Elo-like display: "one standard deviation ≈ 200 points for an Elo starting around 1500". Set `alpha = 200/σ` and `target = 1500` in `ordinal`.
  - "Partial pairing" models are faster but less accurate for many-team games.
  — [GitHub: openskill.py README & docs](https://github.com/vivekjoshy/openskill.py)
- A Luau OpenSkill implementation exists on DevForum ("OpenSkill: a skill-based rating system for matchmaking", thread 1571168) and is used by MatchmakingService. — [GitHub: MatchmakingService docs](https://github.com/steven4547466/MatchmakingService)
- The Match module has an Elo window of ±200 that widens by +50 per 5 s loop, with a 300 s maximum queue time. — [GitHub: g0ofycat/Match Settings.luau](https://github.com/g0ofycat/Match)
- Apex Legends (EA, 2026): a test held the strict skill search for **60 s instead of 30 s** before widening. It cut skill mismatches with no significant rise in queue times and rolled out globally in May 2026. EA calls the speed-vs-fairness trade-off inherent. (search summary) — [EA: Apex matchmaking tests update](https://www.ea.com/games/apex-legends/apex-legends/news/overclocked-matchmaking-update)
- Edgegap (vendor) says a tight skill band works in large pools but empties small pools, where connection quality often matters more than skill. It also reports, secondhand, that Activision's 2024 white paper relaxes skill constraints faster than connection constraints as wait grows. (search summary, secondhand) — [Edgegap: SBMM glossary](https://edgegap.com/glossary/sbmm); [Edgegap: Regional matchmaking deep dive](https://edgegap.com/blog/matchmaking-deep-dive-regional-matchmaking-and-server-region-selection)
- Academic: a cost-balancing model for when to trigger matches (waiting cost vs skill gap) — [arXiv 2601.21858](https://arxiv.org/pdf/2601.21858). A study of MOBA traces found that adding matching criteria raised average wait by ~50% (search summary) — [ResearchGate: Matchmaking in multi-player online games](https://www.researchgate.net/publication/260086948_Matchmaking_in_multi-player_on-line_games_Studying_user_traces_to_improve_the_user_experience)
- RIVALS ranked:
  - **10 placement matches** before a rank shows. Placements cap at Diamond I.
  - Tiers every **200 Elo** from Bronze I (0) to Diamond III (2,800), then Onyx, Nemesis (3,600), and Archnemesis (top 200 players).
  - Decay of 100 Elo/day after 7 days inactive at 3,000+.
  - Party spread cap of 800 Elo.
  (search summary of community wikis; exact thresholds conflict between guides, e.g. Diamond I at 2,400 vs 2,500) — [RIVALS wiki (Miraheze): Ranked](https://robloxrivals.miraheze.org/wiki/Ranked); [PixelTwelve: Rivals ranks 2026](https://pixeltwelve.com/articles/roblox-rivals-ranked-guide-rank-up); [RobloxDatabase: Rivals ranks](https://robloxdatabase.com/guides/rivals-ranks/)
- Roblox Custom Matchmaking supports a numeric player attribute (e.g. skill) read from a DataStore, with Average/Median aggregation per server. This is useful for clustering lobbies by skill. — [Roblox docs: Customize matchmaking](https://github.com/Roblox/creator-docs/blob/main/content/en-us/matchmaking/customize-matchmaking.md)

### Inferences
- **Rating plan:**
  - Store hidden `{mu, sigma}` per queue (`1v1`, `2v2`, `3v3`, `4v4`, `Gauntlet`) in the DataStore profile.
  - Seed a new queue's μ from the player's best other queue (e.g. μ_new = 0.7·μ_1v1 + 0.3·25) with a raised σ, so a strong 1v1 player is not stomping new 2v2 players.
  - Team modes: OpenSkill PlackettLuce with teams.
  - Gauntlet: one multi-team update at the end, using final placement (1st–8th) as the rank order, which OpenSkill supports natively. Optionally also update per duel round.
- **Visible rank vs hidden MMR:** show a points ladder (RIVALS-style, e.g. 200 points per tier, 20 tiers) that converges toward hidden MMR. Award points as base ± (MMR - displayed). Placements = 5–10 games at high σ. Cap placement results at a mid-high tier to protect the top of the ladder, as RIVALS does. Use the OpenSkill ordinal (μ - 3σ) for leaderboards.
- **Search-window schedule for a small pool:**
  - Start at ±100 display-Elo (or Δμ ≈ 1.5).
  - Hold for 15–30 s. At large CCU, consider 60 s like Apex.
  - Widen by +50 every 5 s.
  - After 60 s, accept anyone in the same region band. After 90 s, accept anyone.
  - Make the hold period a server-tunable config, since the right value depends on CCU.
  - Also match on |Δσ|: pair high-σ new players with each other first.
- Ranked should probably launch only for **1v1** (largest pool, simplest to rate), with team ranked added once CCU supports it.
- Apply rating decay as σ inflation, not μ loss, except for visible-tier decay at the top (RIVALS precedent).

### Gaps
- The Glicko-2 and TrueSkill primary docs were not opened in this session. TrueSkill's licensing/patent status was not verified. The OpenSkill README's "open license" positioning is a self-claim.
- No GDC talk or official Riot/Valve matchmaking blog was retrievable in this session.

## 5. Low-CCU strategies for a new game

### Takeaway
At launch, maximize pool density. Offer as few queues as possible (e.g. one "Duels" queue that auto-sizes, plus 2v2), put queue merging and "fill with whoever is here" timers ahead of strict SBMM, show live queue counts, let people play while queued, and use bots only as clearly labeled placeholders. MemoryStore quotas also scale with CCU, so a small game has a small request and memory budget.

### Cited Findings
- MemoryStore request quota (1000 + 120 × CCU per min) and memory quota (64 KB + 1.2 KB × users) both scale with users, so a game with ~20 CCU has ~3,400 units/min and ~88 KB. — [Roblox docs: Memory stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md)
- Small pools: tight skill bands empty the queue, and connection quality often matters more than skill. (search summary, vendor) — [Edgegap: SBMM](https://edgegap.com/glossary/sbmm)
- Bots as placeholders that fill empty slots until humans arrive, then leave, are an established pattern (non-Roblox example). (search summary) — [Steam: Speed Freeks discussion](https://steamcommunity.com/app/2078450/discussions/0/787664259085520879)
- Roblox ran an enforcement wave against bot *accounts* (~Aug 2026) that may lower reported player counts. This is unrelated to AI bots in matches, but relevant for reading CCU. (search summary) — [DevForum: Actioning against bot accounts](https://devforum.roblox.com/t/actioning-against-bot-accounts-on-roblox/4820656)
- The RIVALS lobby works as a playground: warm-ups, weapon testing, and repeated challenges while waiting. (search summary) — [GameBoost: Rivals maps](https://gameboost.com/blog/roblox-rivals-maps-ranked)
- MatchmakingService exposes `GetQueueCounts()`, the basis for a population display. — [GitHub: MatchmakingService](https://github.com/steven4547466/MatchmakingService)
- The Match module groups by continent. Roblox's built-in Latency signal scores servers by estimated player latency for lobby placement. — [GitHub: g0ofycat/Match](https://github.com/g0ofycat/Match); [Roblox docs: Attributes & signals](https://github.com/Roblox/creator-docs/blob/main/content/en-us/matchmaking/attributes-and-signals.md)

### Inferences
- **Queue roster at launch:**
  - Ship **Duels (1v1)**, **Duos (2v2)**, and the **Gauntlet as a scheduled event**.
  - Hide 3v3/4v4 behind a "Squads" queue that forms 3v3 or 4v4 depending on who is waiting: target 4v4, fall back to 3v3 after 45 s.
  - Add dedicated queues once a mode sustains roughly 10+ concurrent queuers.
- **Multi-queue selection:** let players tick several queues at once. The matchmaker places the ticket in each and removes it from all on match, using the hash-map state lock. This multiplies effective pool size.
- **Merge rules:** after N seconds with no match, allow cross-region matching, and let Ranked ticket holders match into Casual-rated games ("unranked fallback"). Always ask or notify the player first, never silently.
- **Fill timers:** Squads starts at minimum viable size (e.g. 3v3) after a timeout. Uneven parties get a bot or a handicap, and the match is flagged unrated.
- **Bots:** in a shooter with drafted abilities, an AI duel bot is useful for (a) tutorials/onboarding, (b) a "practice while queued" arena, and (c) emergency Gauntlet fill. Label bots clearly, never in Ranked, and give no rating changes against them.
- **Play while queued:** queueing should never lock the player. Keep them in the lobby to free roam, use an aim range, dummy-duel with drafted abilities, or spectate live arena matches. Pop a full-screen "MATCH FOUND" with a 10 s accept window.
- **Population display:** show per-queue "in queue / in match" counts, cached and updated every ~5–10 s from one matchmaker write (not every server scanning). At very low counts, consider showing "Players online: X" and estimated wait instead of a demotivating "1 in queue".
- **Region:** at low CCU, do not split by region at all. Use Roblox's lobby latency signal for placement and only prefer same-continent tickets in the first ~20 s of a search.

### Gaps
- No primary Roblox data on minimum CCU thresholds per queue, or on retention effects of bots or queue counts.
- No Roblox-specific DevForum thread on AI bot fill was found.

## 6. Acceptable queue times; presenting long queues for big tournament modes

### Takeaway
No rigorous public study gives a universal quit threshold. Industry guidance and anecdote cluster around **~30–90 s** for quick modes, with players reporting giving up around 5–10+ minutes. A 16-player mode should not rely on an open-ended queue at low CCU. Instead, use **scheduled lobbies with countdowns** and gathering (RSVP/event) mechanics; Roblox now has Experience Events APIs for this.

### Cited Findings
- No study measuring a specific queue-abandon threshold was found. Anecdotes: quitting after ~5 min (Fellowship), ~10–11 min (other forums). A low-authority primer gives a 30–90 s budget depending on genre. (search summary) — [Steam: Fellowship discussion](https://steamcommunity.com/app/2352620/discussions/0/594016102539878058/); [NeuralBase: Matchmaking quality](https://theneuralbase.com/ai-for-gaming/learn/beginner/matchmaking-quality/)
- An academic MOBA study found ~90 s average wait between sessions. (search summary) — [ResearchGate: user traces study](https://www.researchgate.net/publication/260086948_Matchmaking_in_multi-player_on-line_games_Studying_user_traces_to_improve_the_user_experience)
- CoD: long waits → players cancel/requeue or leave, which makes matchmaking worse. (search summary) — [Call of Duty matchmaking blog](https://www.callofduty.com/blog/2024/01/call-of-duty-update-an-Inside-look-at-matchmaking)
- Apex 2026: a 60 s strict window did not significantly raise queue times at Apex's scale. (search summary) — [EA: Apex matchmaking update](https://www.ea.com/games/apex-legends/apex-legends/news/overclocked-matchmaking-update)
- RIVALS global matchmaking was described as placing players "almost instantly", which sets expectations for this genre on Roblox. (search summary) — [Sportskeeda: Rivals Update 2](https://www.sportskeeda.com/roblox-news/news-roblox-rivals-update-2-global-matchmaking-new-charms-balance-changes)
- Roblox `SocialService` includes Experience Events APIs (`GetUpcomingExperienceEventsAsync`, `GetExperienceEventAsync`, `PromptRsvpToEventAsync`, `GetEventRsvpStatusAsync`). Scheduled tournaments can be published as events that players RSVP to. — [SocialService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/SocialService.yaml)
- Valorant runs Gauntlet: Glitched as a limited-time mode (Patch 13.06, live 2026-09-22) with ~8–15 min games. (search summary) — [VALORANT on X](https://x.com/VALORANT/status/2102387565579882564); [IDC Games](https://idcgames.com/en/valorant/news/valorant-unveils-gauntlet-glitched,-a-16-player-roguelike-mode-built-around-custom-agents-2026-09-15-09-00-13857)

### Inferences
- **Targets:** 1v1/2v2 median under 30 s, p90 under 90 s. Squads p90 under 2 min. Gauntlet can take 2–5 min only if the player keeps playing duels while waiting.
- **Gauntlet presentation options:**
  - (a) **Always-on queue that keeps players playing.** Gauntlet queuers can still play Duels. The Gauntlet ticket persists, and a full-screen "Gauntlet ready 16/16, accept" pops at the end of the current duel. Show "Gauntlet: 11/16 queued" live.
  - (b) **Scheduled "Gauntlet Hour"**, every 30–60 min or at fixed peak times. Show a lobby countdown banner, publish a Roblox Experience Event with RSVP, and use a "check-in" window that opens 2 min before. At T-0, fill brackets with checked-in players and add bots for leftover slots, unrated.
  - (c) **Flexible bracket size:** start with 8 or 12 players (4–6 duos) after a timeout, with HP damage scaled so match length stays similar.
- Always show an estimated wait (rolling median per queue), elapsed time, and the reason ("widening search…"). Let players set a "fill me with anyone" opt-in to skip the skill window.

### Gaps
- No primary telemetry on abandonment curves for Roblox specifically.
- Experience Events API semantics (who can create events, limits) were not reviewed in depth.

## 7. Tournament/bracket structures for an 8-duo Gauntlet inside one server

### Takeaway
Valorant's **Gauntlet: Glitched** is the direct model: 8 duos (16 players), each team has **100 HP**, every round pairs you against a *different* duo, and losses cost escalating HP across **7 stages of 3 rounds** (-10, -10, -20, -20, -20, -30, -30). The last duo standing wins, with ability drafting between rounds. Compared with single elimination (3 rounds, half the lobby out after round 1), the HP-pool format keeps everyone playing for several rounds, which fits a draft/roguelike loop. It also runs naturally in one 16-player reserved server with 4 parallel arenas.

### Cited Findings
- Gauntlet: Glitched details (search summary):
  - 16 players = 8 two-player teams in 2v2 rounds. Each team has 100 HP.
  - Loss penalty by stage: S1 -10, S2 -10, S3 -20, S4 -20, S5 -20, S6 -30, S7 -30.
  - 7 stages × 3 rounds. Eliminated at 0 HP.
  - Players draft and upgrade abilities from a randomized pool between rounds to build a "Robo-Agent".
  - About 8–15 min per game. Each round you face "a different pair". The exact pairing algorithm is **not documented** in the sources found.
  - Live 2026-09-22 (Patch 13.06). One pre-launch source (1v9.gg) predates release.
  — [VALORANT Wiki: Gauntlet: Glitched](https://wiki.playvalorant.com/en-us/Gauntlet:_Glitched); [games.gg guide](https://games.gg/valorant/guides/valorant-gauntlet-glitched-guide/); [AllThings.How](https://allthings.how/gauntlet-glitched-in-valorant-how-the-2v2-roguelike-mode-works/); [esports.gg](https://esports.gg/news/valorant/gauntlet-glitched-ability-draft/); [Sportskeeda mastersheet](https://www.sportskeeda.com/valorant/valorant-gauntlet-glitched-mastersheet-features-abilities-everything-need-know); [1v9.gg](https://1v9.gg/blog/valorant-gauntlet-glitched-guide)
- "Gauntlet" is also a generic bracket term. Toornament uses it for a single-elimination-style final stage, usually after a League or Swiss stage. (search summary) — [Toornament blog: Gauntlet format](https://blog.toornament.com/2019/02/new-gauntlet/)
- A single TeleportAsync call can move up to 50 players, so all 16 Gauntlet players can go to one reserved server in one call (or one call per source lobby). — [TeleportService API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TeleportService.yaml)

### Inferences
- **HP math (copying Valorant's numbers):** a duo that loses every round is out after **8 straight losses**: 3×10 + 3×10 = 60, then 20 + 20 = 100, in round 8. A duo that splits 50/50 lasts into roughly stages 5–6. The maximum is 21 rounds. With ~60–90 s duels plus a ~20–30 s draft phase, budget ~12–20 min. Consider 5 stages × 3 rounds or 2-round stages to reach a 10–12 min target, and scale damage (e.g. 15/15/25/25/35) if the game ships fewer stages.
- **One-server layout:** 16-player reserved server, a central hub or draft room, and **4 identical duel arenas** (8 duos = 4 simultaneous 2v2s per round). Each round:
  1. Draft/shop phase in the hub.
  2. Teleport duos to arenas with in-server CFrame moves (no TeleportService).
  3. Fight.
  4. Apply HP damage.
  5. Return to the hub.
  Spectators (eliminated duos) can watch any arena, or they leave with a placement and rewards.
- **Pairing:** a Swiss-like rotation. Avoid repeat opponents until all have been faced, and pair teams with similar current HP. When an odd number of duos remains alive, give one team a "ghost" fight against a recorded or bot copy of an eliminated duo, or a bye that takes no damage. The ghost approach is the convention in auto-battlers such as TFT (not sourced here). In the final 2 teams, play head-to-head until one hits 0.
- **Alternatives compared:**
  - (a) Single elimination with 8 duos: 3 rounds. Fast, but 4 duos are out after one fight, which is poor for a draft loop and wastes long queue time.
  - (b) Double elimination: about 14 matches and uneven idle time.
  - (c) **HP-pool Swiss (recommended)**: everyone plays at least ~4–8 rounds, draft choices compound, and all 4 arenas stay busy each round until fewer than 8 duos remain.
- **Solo queue into Gauntlet:** pair solos into duos by MMR proximity (or reverse, to balance duos), and keep premade duos. Allow no rank restriction (Valorant precedent), but compute duo MMR for pairing.
- **Disconnects:** if a partner leaves, the remaining player continues alone with +X% damage resistance, or a bot substitutes. Never pause the 4-arena schedule.
- **Rating:** one OpenSkill multi-team update with 8 teams ranked by elimination order. Ties (simultaneous elimination) are broken by remaining HP before the final round, or by round damage dealt.

### Gaps
- Gauntlet: Glitched's exact opponent-pairing logic, odd-team handling, and tie-breaks were not found in accessible sources. Pages were seen only as search summaries; the official wiki could not be opened.
- No data on optimal stage count or HP tuning for shorter Roblox session lengths.
