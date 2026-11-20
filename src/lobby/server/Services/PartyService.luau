--!strict
-- In-game party invites (vault/02 Art/UI Lobby HUD.md → Party invites).
-- Roblox gives games no way to invite someone into a Roblox party (the party
-- API is read-only), so the lobby has its own invites on top: invite anyone
-- in this server (the party card or the player list), they get an ACCEPT /
-- DECLINE card, and an accepted invite groups them with you exactly like a
-- Roblox party (Matchmaking/Parties), so you queue together on one team.
--
-- PartyRequest (client -> server): ("invite", userId) | ("accept", userId) |
-- ("decline", userId) | ("leave"). Every request is type-checked and
-- rate-limited; the server owns the pending invites, the size cap and who
-- is in which party. Rejected requests are dropped and counted, never kicked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)

local Parties = require(script.Parent.Parent.Matchmaking.Parties)

local PartyService = {}

local limiter = RateLimit.new(Config.RATE)
local partyEvent: RemoteEvent
-- pending[target][inviter] = os.clock() the invite expires
local pending: { [Player]: { [Player]: number } } = {}
local rejects: { [string]: number } = {}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function send(p: Player, payload: LobbyNet.PartyEventPayload)
	if p.Parent == Players then
		partyEvent:FireClient(p, payload)
	end
end

local function info(p: Player, text: string)
	send(p, { kind = "info", text = text })
end

local function name(p: Player): string
	return string.upper(p.DisplayName)
end

-- A player in this server from a client-sent userId, or nil.
local function playerById(id: unknown): Player?
	if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 or id <= 0 or id > 2 ^ 53 then
		return nil
	end
	return Players:GetPlayerByUserId(id :: number)
end

-- Mid-way into a match: parties can't change.
local function busy(p: Player): boolean
	local s = StateValues.get(p, "QueueStatus")
	return s == "found" or s == "teleporting"
end

local function invite(from: Player, to: Player)
	if to == from or table.find(Parties.members(from), to) then
		return
	end
	if #Parties.members(from) >= Config.PARTY.max then
		info(from, `Your party is full ({Config.PARTY.max} max)`)
		return
	end
	if busy(from) or busy(to) then
		info(from, "Can't invite while joining a match")
		return
	end
	local list = pending[to]
	if not list then
		list = {}
		pending[to] = list
	end
	local open = list[from]
	if open and open > os.clock() then
		return -- already waiting on this one
	end
	list[from] = os.clock() + Config.PARTY.inviteTtl
	send(to, { kind = "invite", from = from.UserId, expiresIn = Config.PARTY.inviteTtl })
	info(from, `Party invite sent to {name(to)}`)
end

local function respond(to: Player, from: Player, accept: boolean)
	local list = pending[to]
	local expires = list and list[from]
	if not list or not expires then
		return
	end
	list[from] = nil
	if expires < os.clock() then
		info(to, "That invite expired")
		return
	end
	if not accept then
		info(from, `{name(to)} declined your invite`)
		return
	end
	if busy(from) or busy(to) then
		info(to, "They're joining a match. Try again after")
		return
	end
	if #Parties.members(from) + 1 > Config.PARTY.max then
		info(to, "That party is full")
		return
	end
	Parties.join(to, from)
	for _, m in Parties.members(to) do
		if m ~= to then
			info(m, `{name(to)} joined your party`)
		end
	end
	info(to, `You joined {name(Parties.leader(to))}'s party`)
end

local function leave(p: Player)
	local members = Parties.members(p)
	if #members < 2 or busy(p) then
		return
	end
	Parties.leave(p)
	for _, m in members do
		if m ~= p then
			info(m, `{name(p)} left the party`)
		end
	end
	info(p, "You left the party")
end

local function onRequest(player: Player, action: unknown, arg: unknown)
	if not limiter:allow(player, "PartyRequest") then
		reject("rate")
		return
	end
	if typeof(action) ~= "string" then
		reject("badAction")
		return
	end
	if action == "leave" then
		leave(player)
		return
	end
	if action ~= "invite" and action ~= "accept" and action ~= "decline" then
		reject("badAction")
		return
	end
	local other = playerById(arg)
	if not other then
		reject("badTarget")
		return
	end
	if action == "invite" then
		invite(player, other)
	else
		respond(player, other, action == "accept")
	end
end

function PartyService.init()
	partyEvent = LobbyNet.event("PartyEvent")
end

function PartyService.start()
	LobbyNet.event("PartyRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		pending[p] = nil
		for _, list in pending do
			list[p] = nil
		end
		limiter:forget(p)
	end)
	while true do
		task.wait(Config.rejectLogInterval)
		if next(rejects) then
			local parts = {}
			for reason, n in rejects do
				table.insert(parts, `{reason}={n}`)
			end
			warn(
				`[Party] rejected PartyRequest in the last {Config.rejectLogInterval} s: {table.concat(
					parts,
					", "
				)}`
			)
			table.clear(rejects)
		end
	end
end

return PartyService
