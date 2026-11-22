--!strict
-- One match's context (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md). Every running match has its own
-- copy of the match-flow services (MatchHost builds a "kit": copies of MatchService, DraftService, MapService, the
-- Mods, bots ... plus this module, MatchState and Zone). Those copies read their world through this table:
--  * players: stands in for the Players service, but only this match's players (PlayerAdded / PlayerRemoving /
--    GetPlayers / GetPlayerByUserId / GetPlayerFromCharacter); everything else passes through to Players, and
--    server-wide settings (CharacterAutoLoads, RespawnTime) are only written by a match that owns the server.
--  * net: stands in for Shared/Net: a remote's OnServerEvent only hears this match's players, FireAllClients only
--    reaches them.
--  * world: where the match puts what it builds (map, bots): Workspace for a whole-server match, else its own
--    folder under Workspace.Matches (destroyed with the match).
--  * offset: how far this match's map is moved from where it was built.
-- A whole-server match (a reserved match server, the retired match place) owns the server: everything passes
-- straight through, so it plays exactly as before.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net") :: ModuleScript)

export type Plan = {
	matchId: string,
	mode: string,
	size: number,
	teams: { { number } },
	bots: boolean,
}

local Context = {}

Context.id = "server"
Context.alive = true
Context.ownsServer = true
Context.padDuel = false
Context.offset = Vector3.zero
Context.world = workspace :: Instance
Context.plan = nil :: Plan?
-- Called by MatchEndService when a pad duel ends (instead of teleporting): MatchHost sends everyone back.
Context.finish = nil :: ((players: { Player }) -> ())?
-- Sends one pad duel player back to the lobby now (they picked Leave on the end screen).
Context.sendHome = nil :: ((player: Player) -> ())?

local members: { [Player]: boolean } = {}
local addedEvent = Instance.new("BindableEvent")
local removingEvent = Instance.new("BindableEvent")

function Context.has(player: Player): boolean
	return Context.ownsServer or members[player] == true
end

-- Players --------------------------------------------------------------------------

local playersProxy = {}

function playersProxy.GetPlayers(_self: any): { Player }
	if Context.ownsServer then
		return Players:GetPlayers()
	end
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		if members[p] then
			table.insert(list, p)
		end
	end
	return list
end

function playersProxy.GetPlayerByUserId(_self: any, userId: number): Player?
	local p = Players:GetPlayerByUserId(userId)
	return if p and Context.has(p) then p else nil
end

function playersProxy.GetPlayerFromCharacter(_self: any, character: Instance?): Player?
	local p = Players:GetPlayerFromCharacter(character)
	return if p and Context.has(p) then p else nil
end

local SERVER_WIDE: { [string]: boolean } = { CharacterAutoLoads = true, RespawnTime = true }

setmetatable(playersProxy, {
	__index = function(_, key: string): any
		if key == "PlayerAdded" then
			return if Context.ownsServer then Players.PlayerAdded else addedEvent.Event
		elseif key == "PlayerRemoving" then
			return if Context.ownsServer then Players.PlayerRemoving else removingEvent.Event
		end
		local value = (Players :: any)[key]
		if typeof(value) == "function" then
			return function(_self: any, ...: any): ...any
				return value(Players, ...)
			end
		end
		return value
	end,
	__newindex = function(_, key: string, value: any)
		if SERVER_WIDE[key] and not Context.ownsServer then
			return -- a lobby server's spawning isn't a pad duel's to change
		end
		(Players :: any)[key] = value
	end,
})

Context.players = playersProxy :: any

-- Adds a player to this match (pad duels; a whole-server match has everyone).
function Context.addPlayer(player: Player)
	if members[player] then
		return
	end
	members[player] = true
	addedEvent:Fire(player)
end

-- Takes a player out (left the server, or back to the lobby); listeners hear PlayerRemoving first.
function Context.removePlayer(player: Player)
	if not members[player] then
		return
	end
	removingEvent:Fire(player)
	members[player] = nil
end

-- Net ------------------------------------------------------------------------------

local wrapped: { [Instance]: any } = {}

local function wrap(remote: Instance): any
	if Context.ownsServer then
		return remote
	end
	local existing = wrapped[remote]
	if existing then
		return existing
	end
	local isUnreliable = remote:IsA("UnreliableRemoteEvent")
	local real = remote :: any
	local proxy = {}
	proxy.OnServerEvent = {
		Connect = function(_self: any, fn: (Player, ...any) -> ()): RBXScriptConnection
			return real.OnServerEvent:Connect(function(player: Player, ...: any)
				if Context.alive and members[player] then
					fn(player, ...)
				end
			end)
		end,
	}
	function proxy.FireClient(_self: any, player: Player, ...: any)
		real:FireClient(player, ...)
	end
	function proxy.FireAllClients(_self: any, ...: any)
		for p in members do
			if p.Parent == Players then
				real:FireClient(p, ...)
			end
		end
	end
	proxy.Name = remote.Name
	proxy.unreliable = isUnreliable
	wrapped[remote] = proxy
	return proxy
end

local netProxy = setmetatable({}, {
	__index = function(_, key: string): any
		local value = (Net :: any)[key]
		if key == "event" or key == "unreliable" then
			return function(name: string, ...: any): any
				return wrap(value(name, ...))
			end
		end
		return value
	end,
})

Context.net = netProxy :: any

-- Callbacks into shared services (HealthService.onDowned, damage guards ...) live as long as the server; wrap them
-- so they go quiet once this match is over.
function Context.guard<A..., R...>(fn: (A...) -> R...): (A...) -> R...
	return function(...: A...): R...
		if not Context.alive then
			return nil :: any
		end
		return fn(...)
	end
end

-- Whether `x` belongs to this match: one of its players, a member's character or one of its parts / its Humanoid,
-- or a bot body carrying this match's MatchId. A whole-server match owns everything.
function Context.owns(x: any): boolean
	if Context.ownsServer then
		return true
	end
	if typeof(x) ~= "Instance" then
		return false
	end
	if x:IsA("Player") then
		return members[x] == true
	end
	local model: Instance? = if x:IsA("Model") then x else x:FindFirstAncestorOfClass("Model")
	while model do
		local p = Players:GetPlayerFromCharacter(model)
		if p then
			return members[p] == true
		end
		if model:GetAttribute("MatchId") == Context.id then
			return true
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model") or nil
	end
	return false
end

-- A callback for a shared service's event that only runs while this match is alive and only for what this match
-- owns (argument `argIndex`: the player, humanoid or body the event is about).
function Context.filtered(argIndex: number, fn: (...any) -> ...any): (...any) -> ...any
	return function(...: any): ...any
		if not Context.alive then
			return nil
		end
		if not Context.owns((select(argIndex, ...))) then
			return nil
		end
		return fn(...)
	end
end

-- Set up --------------------------------------------------------------------------

export type Spec = {
	id: string,
	ownsServer: boolean,
	padDuel: boolean,
	offset: Vector3,
	world: Instance,
	plan: Plan?,
	players: { Player },
	finish: ((players: { Player }) -> ())?,
	sendHome: ((player: Player) -> ())?,
}

function Context.setup(spec: Spec)
	Context.id = spec.id
	Context.ownsServer = spec.ownsServer
	Context.padDuel = spec.padDuel
	Context.offset = spec.offset
	Context.world = spec.world
	Context.plan = spec.plan
	Context.finish = spec.finish
	Context.sendHome = spec.sendHome
	for _, p in spec.players do
		members[p] = true
	end
	if not spec.ownsServer then
		Players.PlayerRemoving:Connect(function(player)
			Context.removePlayer(player)
		end)
	end
end

return Context
