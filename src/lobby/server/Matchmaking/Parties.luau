--!strict
-- Roblox parties in this lobby server (vault/02 Art/UI Lobby HUD.md → Party).
-- Parties are made in Roblox itself (the Party button in the Roblox menu or
-- app); a game can't create one or invite to one. It can read who is in a
-- party (`Player.PartyId`, server only) and keep them together, which is all
-- this does: the players here who share a PartyId are one group, its leader
-- is the earliest member to join the Roblox party (SocialService:GetPartyAsync
-- order) and they queue as one (QueueService).
--
-- Clients see it through server-owned attributes, never the real PartyId:
--   PartyKey    a short local key ("P3") shared by the members here, nil solo
--   PartyLeader true on the leader, false on the others, nil solo
--
-- Studio playtests have no PartyId (use Studio's Party Simulator, or set a
-- `TestPartyId` string attribute on players from the server in Studio).
--
-- In-game parties (Services/PartyService invites): Roblox gives games no way
-- to invite into a Roblox party, so an accepted invite sets a local override
-- that puts the player in the inviter's group (their Roblox party's id, or a
-- new "G" id). Leaving sets an empty override (solo); changing Roblox party
-- clears the override.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Parties = {}

local partyOf: { [Player]: string } = {}
local joinedAt: { [Player]: number } = {} -- when they joined their current group
local custom: { [Player]: string } = {} -- in-game override ("" = solo)
local nextGameParty = 0
local localIds: { [string]: boolean } = {} -- the "G" ids made here
local acceptOrder: { [string]: { [number]: number } } = {} -- partyId → userId → order
local keys: { [string]: string } = {}
local nextKey = 0
local listeners: { ({ Player }) -> () } = {}
local conns: { [Player]: { RBXScriptConnection } } = {}

local function readId(p: Player): string
	local override = custom[p]
	if override then
		return override
	end
	if RunService:IsStudio() then
		local t = p:GetAttribute("TestPartyId")
		if typeof(t) == "string" and t ~= "" then
			return t
		end
	end
	local ok, id = pcall(function(): any
		return (p :: any).PartyId
	end)
	return if ok and typeof(id) == "string" then id else ""
end

local function keyOf(partyId: string): string
	local k = keys[partyId]
	if not k then
		nextKey += 1
		k = "P" .. nextKey
		keys[partyId] = k
	end
	return k
end

-- The members of a party who are in this server, leader first.
local function membersOf(partyId: string): { Player }
	local list: { Player } = {}
	for p, id in partyOf do
		if id == partyId and p.Parent == Players then
			table.insert(list, p)
		end
	end
	local order = acceptOrder[partyId] or {}
	table.sort(list, function(a, b)
		local oa, ob = order[a.UserId], order[b.UserId]
		if oa and ob and oa ~= ob then
			return oa < ob
		elseif oa and not ob then
			return true
		elseif ob and not oa then
			return false
		end
		return (joinedAt[a] or 0) < (joinedAt[b] or 0)
	end)
	return list
end

local function publish(partyId: string)
	if partyId == "" then
		return
	end
	local list = membersOf(partyId)
	for i, p in list do
		p:SetAttribute("PartyKey", if #list > 1 then keyOf(partyId) else nil)
		p:SetAttribute("PartyLeader", if #list > 1 then i == 1 else nil)
	end
end

local function fire(affected: { Player })
	for _, cb in listeners do
		task.spawn(cb, affected)
	end
end

-- Who joined the Roblox party first decides the leader (index 1 of
-- GetPartyAsync). Yields; failures keep the join-order fallback.
local function fetchOrder(partyId: string)
	-- local in-game ids ("G…") aren't Roblox parties: don't spend the budget
	if partyId == "" or RunService:IsStudio() or localIds[partyId] then
		return
	end
	local ok, data = pcall(function(): any
		return (SocialService :: any):GetPartyAsync(partyId)
	end)
	if not ok or typeof(data) ~= "table" then
		return
	end
	local order: { [number]: number } = {}
	for i, member in data :: { any } do
		if typeof(member) == "table" and typeof(member.UserId) == "number" then
			order[member.UserId] = i
		end
	end
	acceptOrder[partyId] = order
	local list = membersOf(partyId)
	if #list > 1 then
		publish(partyId)
		fire(list)
	end
end

local function update(p: Player)
	local before = partyOf[p] or ""
	local now = if p.Parent == Players then readId(p) else ""
	if before == now and partyOf[p] ~= nil then
		return
	end
	local affected: { Player } = { p }
	if before ~= "" then
		for _, m in membersOf(before) do
			if m ~= p then
				table.insert(affected, m)
			end
		end
	end
	partyOf[p] = now
	joinedAt[p] = os.clock() -- the newest in a group never takes the lead
	if now == "" then
		p:SetAttribute("PartyKey", nil)
		p:SetAttribute("PartyLeader", nil)
	else
		for _, m in membersOf(now) do
			if not table.find(affected, m) then
				table.insert(affected, m)
			end
		end
		publish(now)
		task.spawn(fetchOrder, now)
	end
	publish(before)
	-- an emptied group forgets its key and order (in-game groups churn)
	if before ~= "" and #membersOf(before) == 0 then
		keys[before] = nil
		acceptOrder[before] = nil
		localIds[before] = nil
	end
	fire(affected)
end

local function onAdded(p: Player)
	joinedAt[p] = os.clock()
	local list: { RBXScriptConnection } = {}
	local ok, signal = pcall(function()
		return p:GetPropertyChangedSignal("PartyId" :: any)
	end)
	if ok and signal then
		table.insert(
			list,
			signal:Connect(function()
				custom[p] = nil -- a new Roblox party wins over an in-game one
				update(p)
			end)
		)
	end
	if RunService:IsStudio() then
		table.insert(
			list,
			p:GetAttributeChangedSignal("TestPartyId"):Connect(function()
				update(p)
			end)
		)
	end
	conns[p] = list
	update(p)
end

local function onRemoving(p: Player)
	local before = partyOf[p] or ""
	for _, c in conns[p] or {} do
		c:Disconnect()
	end
	conns[p] = nil
	partyOf[p] = nil
	joinedAt[p] = nil
	custom[p] = nil
	if before ~= "" then
		local rest = membersOf(before)
		publish(before)
		if #rest == 0 then
			acceptOrder[before] = nil
			keys[before] = nil
		end
		table.insert(rest, p)
		-- after the other PlayerRemoving handlers (QueueService drops its state)
		task.defer(fire, rest)
	end
end

-- Still in this server (false from the moment they start leaving).
function Parties.isHere(p: Player): boolean
	return partyOf[p] ~= nil and p.Parent == Players
end

-- The player's party here, leader first ({ player } when solo).
function Parties.members(p: Player): { Player }
	local id = partyOf[p]
	if not id or id == "" then
		return { p }
	end
	local list = membersOf(id)
	return if #list > 0 then list else { p }
end

function Parties.leader(p: Player): Player
	return Parties.members(p)[1]
end

-- An accepted in-game invite: `p` joins `host`'s group (a new one if solo).
function Parties.join(p: Player, host: Player)
	local target = partyOf[host] or ""
	if target == "" or #membersOf(target) == 0 then
		nextGameParty += 1
		target = "G" .. nextGameParty
		localIds[target] = true
		custom[host] = target
		update(host)
	end
	custom[p] = target
	update(p)
end

-- Leaves the current group (solo until they accept another invite or
-- change Roblox party).
function Parties.leave(p: Player)
	custom[p] = ""
	update(p)
end

-- Called (in its own thread) with the players whose party changed.
function Parties.onChanged(cb: ({ Player }) -> ())
	table.insert(listeners, cb)
end

function Parties.start()
	Players.PlayerAdded:Connect(onAdded)
	Players.PlayerRemoving:Connect(onRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onAdded, p)
	end
end

return Parties
