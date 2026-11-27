--!strict
-- The global queue (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md): PLAY → FIND MATCH matches groups
-- from every lobby server, not only this one. QueueService still owns each group here (parties, states, the UI);
-- this module mirrors those groups into MemoryStore and tells QueueService when one has been matched.
--
--  * Tickets (sorted map GQ_Tickets_v2, key = ticket GUID, sort key = when the group started waiting): one per
--    queued group: { state = "waiting" | "matched", mode, users = { userId }, since = os.time(), server, match? }.
--    The home server refreshes its tickets' TTL; a server that dies leaves tickets that expire on their own.
--  * One matchmaker at a time (lease key "leader" in GQ_Lease_v2, renewed every LEASE_RENEW s, TTL LEASE_TTL): it
--    reads the waiting tickets, runs the same rules as before (Matchmaking/Matchmaker: full teams first, bots after
--    the oldest group waited botFillAfter) and claims each picked ticket with a compare-and-set UpdateAsync (a
--    ticket cancelled meanwhile undoes the whole pick). A match = one reserved server id shared by every server
--    whose players are in it (TeleportOptions.ReservedServerId), never sent to clients.
--  * Home servers poll their own tickets; a matched one is handed to QueueService (onMatched), which teleports its
--    players to that reserved server of this same place.
--  * The leader also publishes how many players wait per mode (key "counts"), shown on the lobby's queue UI.
-- MemoryStore errors are caught; if it can't be reached at all, isOn() is false and QueueService matches inside
-- this server as before.
--
-- LihFolk (41 Multiplayer Services): Matchmaking Queues with MemoryStore (lease, CAS claims, TTL backstop);
-- MemoryStore Service (budgets: 1,000 + 120 x CCU units per minute); Parties and Group Teleports (share the
-- reserved server id server-side); Reserved and Private Servers in Practice.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

local Matchmaker = require(script.Parent.Matchmaker)

export type MatchInfo = {
	id: string,
	rsid: string, -- reserved server id (server-side only)
	mode: string,
	teams: { { number } },
	bots: boolean,
}

type Ticket = {
	state: "waiting" | "matched",
	mode: string,
	users: { number },
	since: number,
	server: string,
	match: MatchInfo?,
}

type ModeRule = { id: string, teamSize: number, fillAfter: number? } -- fillAfter: this mode's own bot-fill wait

local GlobalQueue = {}

local TICKETS = "GQ_Tickets_v2"
local LEASE = "GQ_Lease_v2"
local TICKET_TTL = 60 -- s; refreshed every HEARTBEAT while waiting
local HEARTBEAT = 15
local MATCHED_TTL = 60 -- s a matched ticket lives (the home server removes it sooner)
local LEASE_TTL = 15
local LEASE_RENEW = 5
local CYCLE = 2 -- s between matchmaker passes
local POLL = 1.5 -- s between checks of our own tickets
local COUNTS_TTL = 10
local MAX_READ = 200
local REPROBE_EVERY = 60 -- seconds between MemoryStore probes while it's off

local serverId = HttpService:GenerateGUID(false)
local tickets: MemoryStoreSortedMap? = nil
local lease: MemoryStoreSortedMap? = nil
local on = false
local modes: { ModeRule } = {}
local fillAfter = 30

-- Our tickets: ticket id → the data we wrote (to rewrite if it expired).
local mine: { [string]: Ticket } = {}
local matchedHandler: ((ticket: string, match: MatchInfo) -> ())? = nil
local counts: { [string]: number } = {}

-- During an outage every poll fails: one warn per label per WARN_EVERY s, with a count.
local WARN_EVERY = 60
local warned: { [string]: { at: number, skipped: number } } = {}

local function tryCall<T...>(label: string, fn: (...any) -> T..., ...: any): (boolean, T...)
	local result = table.pack(pcall(fn, ...))
	if not result[1] then
		local now = os.clock()
		local w = warned[label]
		if not w or now - w.at >= WARN_EVERY then
			local more = if w and w.skipped > 0
				then ` (+{w.skipped} more since the last warn)`
				else ""
			warn(`[GlobalQueue] {label} failed: {result[2]}{more}`)
			warned[label] = { at = now, skipped = 0 }
		else
			w.skipped += 1
		end
	end
	return table.unpack(result, 1, result.n)
end

function GlobalQueue.isOn(): boolean
	return on
end

function GlobalQueue.counts(): { [string]: number }
	return counts
end

-- Puts a group in the global queue; returns its ticket id (nil if MemoryStore failed).
function GlobalQueue.add(mode: string, users: { number }, waitedSeconds: number): string?
	local map = tickets
	if not on or not map then
		return nil
	end
	local id = HttpService:GenerateGUID(false)
	local since = os.time() - math.floor(waitedSeconds)
	local data: Ticket =
		{ state = "waiting", mode = mode, users = users, since = since, server = serverId }
	local ok = tryCall("add", function()
		-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
		map:SetAsync(id, data, TICKET_TTL, since)
	end)
	if not ok then
		return nil
	end
	mine[id] = data
	return id
end

function GlobalQueue.remove(ticket: string)
	mine[ticket] = nil
	local map = tickets
	if not map then
		return
	end
	task.spawn(tryCall, "remove", function()
		-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
		map:RemoveAsync(ticket)
	end)
end

function GlobalQueue.onMatched(fn: (ticket: string, match: MatchInfo) -> ())
	matchedHandler = fn
end

-- Matchmaker -------------------------------------------------------------------

local function claim(ids: { string }, match: MatchInfo): boolean
	local map = tickets :: MemoryStoreSortedMap
	local claimed: { string } = {}
	for _, id in ids do
		local ok, result = tryCall("claim", function()
			-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
			return map:UpdateAsync(id, function(old: any)
				if typeof(old) == "table" and old.state == "waiting" then
					old.state = "matched"
					old.match = match
					return old
				end
				return nil -- gone or already matched: cancel
			end, MATCHED_TTL)
		end)
		if not ok or result == nil then
			-- Undo the ones already claimed: they wait again (same since).
			for _, back in claimed do
				tryCall("unclaim", function()
					-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
					map:UpdateAsync(back, function(old: any)
						if
							typeof(old) == "table"
							and old.state == "matched"
							and old.match
							and old.match.id == match.id
						then
							old.state = "waiting"
							old.match = nil
							return old
						end
						return nil
					end, TICKET_TTL)
				end)
			end
			return false
		end
		table.insert(claimed, id)
	end
	return true
end

type GEntry = { players: { number }, since: number, ticket: string }

local function matchPass()
	local map = tickets :: MemoryStoreSortedMap
	local ok, items = tryCall("read", function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, MAX_READ)
	end)
	if not ok or typeof(items) ~= "table" then
		return
	end
	local byMode: { [string]: { GEntry } } = {}
	local waiting: { [string]: number } = {}
	for _, item in items :: { any } do
		local v = item.value
		if
			typeof(v) == "table"
			and v.state == "waiting"
			and typeof(v.mode) == "string"
			and typeof(v.users) == "table"
		then
			byMode[v.mode] = byMode[v.mode] or {}
			table.insert(
				byMode[v.mode],
				{ players = v.users, since = tonumber(v.since) or os.time(), ticket = item.key }
			)
			waiting[v.mode] = (waiting[v.mode] or 0) + #v.users
		end
	end
	local now = os.time()
	for _, rule in modes do
		local queue = byMode[rule.id]
		while queue and #queue > 0 do
			local pick =
				Matchmaker.pick(queue :: any, rule.teamSize, now, rule.fillAfter or fillAfter)
			if not pick then
				break
			end
			local ids: { string } = {}
			local users = 0
			for _, e in pick.entries :: { any } do
				table.insert(ids, (e :: GEntry).ticket)
				users += #(e :: GEntry).players
			end
			local teams: { { number } } = { {}, {} }
			for t, team in pick.teams :: { any } do
				for _, userId in team do
					table.insert(teams[t], userId)
				end
			end
			local match: MatchInfo = {
				id = HttpService:GenerateGUID(false),
				rsid = HttpService:GenerateGUID(false),
				mode = rule.id,
				teams = teams,
				bots = users < rule.teamSize * 2,
			}
			if claim(ids, match) then
				print(
					`[GlobalQueue] matched {rule.id}: {users} player(s) from {#ids} group(s), bots {match.bots}`
				)
				waiting[rule.id] = math.max((waiting[rule.id] or 0) - users, 0)
			end
			-- Picked groups leave this pass either way (a failed claim retries next pass).
			for _, e in pick.entries :: { any } do
				local i = table.find(queue, e)
				if i then
					table.remove(queue, i)
				end
			end
		end
	end
	tryCall("counts", function()
		local store = lease :: MemoryStoreSortedMap
		-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
		store:SetAsync("counts", waiting, COUNTS_TTL)
	end)
	counts = waiting
end

local function holdLease(): boolean
	local map = lease :: MemoryStoreSortedMap
	local ok, result = tryCall("lease", function()
		-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
		return map:UpdateAsync("leader", function(old: any)
			if old == nil or (typeof(old) == "table" and old.server == serverId) then
				return { server = serverId }
			end
			return nil
		end, LEASE_TTL)
	end)
	return ok and result ~= nil
end

local function leaderLoop()
	local leading = false
	local renewAt = 0
	while true do
		local now = os.clock()
		if now >= renewAt then
			leading = holdLease()
			renewAt = now + LEASE_RENEW
		end
		if leading then
			matchPass()
		else
			local ok, value = tryCall("read counts", function()
				-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
				return (lease :: MemoryStoreSortedMap):GetAsync("counts")
			end)
			if ok and typeof(value) == "table" then
				counts = value
			end
		end
		task.wait(CYCLE)
	end
end

-- Home server --------------------------------------------------------------------

local function pollLoop()
	while true do
		task.wait(POLL)
		local ids: { string } = {}
		for id in mine do
			table.insert(ids, id)
		end
		for _, id in ids do
			local data = mine[id]
			if not data then
				continue
			end
			local ok, value = tryCall("poll", function()
				-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
				return (tickets :: MemoryStoreSortedMap):GetAsync(id)
			end)
			if not ok or mine[id] ~= data then
				continue
			end
			if
				typeof(value) == "table"
				and value.state == "matched"
				and typeof(value.match) == "table"
			then
				mine[id] = nil
				GlobalQueue.remove(id)
				if matchedHandler then
					task.spawn(matchedHandler, id, value.match :: MatchInfo)
				end
			elseif value == nil then
				-- Expired (a slow heartbeat): write it again as it was.
				tryCall("rewrite", function()
					local store = tickets :: MemoryStoreSortedMap
					-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
					store:SetAsync(id, data, TICKET_TTL, data.since)
				end)
			end
		end
	end
end

local function heartbeatLoop()
	while true do
		task.wait(HEARTBEAT)
		local ids: { string } = {}
		for id in mine do
			table.insert(ids, id)
		end
		for _, id in ids do
			if not mine[id] then
				continue
			end
			tryCall("heartbeat", function()
				local store = tickets :: MemoryStoreSortedMap
				-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
				store:UpdateAsync(id, function(old: any)
					if typeof(old) == "table" and old.state == "waiting" then
						return old
					end
					return nil
				end, TICKET_TTL)
			end)
		end
	end
end

-- Starts the loops. `rules`: the modes (id, teamSize); `fill`: seconds before bots fill (botFillAfter).
function GlobalQueue.start(rules: { ModeRule }, fill: number)
	modes = rules
	fillAfter = fill
	local function probe(): boolean
		return tryCall("open", function()
			tickets = MemoryStoreService:GetSortedMap(TICKETS)
			local leaseMap = MemoryStoreService:GetSortedMap(LEASE)
			lease = leaseMap
			-- One read proves MemoryStore is reachable (Studio needs API access on).
			local map = leaseMap
			-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
			map:GetAsync("counts")
		end)
	end
	if not probe() then
		warn("[GlobalQueue] MemoryStore unavailable: queueing inside this server only")
		-- a blip at boot must not cut this server off for its whole life: try again now and then
		-- (Studio without API access stays local, so it doesn't retry there)
		if RunService:IsStudio() then
			return
		end
		repeat
			task.wait(REPROBE_EVERY)
		until probe()
	end
	on = true
	print(
		`[GlobalQueue] on (server {string.sub(serverId, 1, 8)}{if RunService:IsStudio()
			then ", Studio"
			else ""})`
	)
	task.spawn(leaderLoop)
	task.spawn(pollLoop)
	task.spawn(heartbeatLoop)
end

-- Removes every ticket this server still holds (shutdown). Waits (up to RELEASE_WAIT s) so
-- the leader doesn't match other servers' players against groups that are gone.
local RELEASE_WAIT = 5
function GlobalQueue.releaseAll()
	local map = tickets
	local ids: { string } = {}
	for id in mine do
		table.insert(ids, id)
	end
	table.clear(mine)
	if not map or #ids == 0 then
		return
	end
	local left = #ids
	for _, id in ids do
		task.spawn(function()
			tryCall("release", function()
				-- lihfolk-ignore: datastore-no-pcall (MemoryStore, inside tryCall, which pcalls)
				map:RemoveAsync(id)
			end)
			left -= 1
		end)
	end
	local t = os.clock()
	while left > 0 and os.clock() - t < RELEASE_WAIT do
		task.wait(0.1)
	end
end

return GlobalQueue
