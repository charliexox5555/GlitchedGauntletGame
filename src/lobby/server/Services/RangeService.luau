--!strict
-- RangeService: the lobby's shooting range (owner 2026-11-21: "a smaller hologram ... where you touch it and
-- enter the range ... the actual range is built further away"; place merge 2026-11-21: "wire the range, joining,
-- leaving ... so the player can load in and practice", guns only for now).
--
-- Joining: touching a part tagged `RangeEntry` (the hologram in the hub's sim bay) puts the player in the "Range"
-- PlayZone and reloads their character with the match body at a part tagged `RangeSpawn`; WeaponService then gives
-- them a loadout with endless reserve ammo, and the gun picker (P) works there. Leaving: touching `RangeExit` puts
-- them back in the "Lobby" zone, takes the guns away and reloads their own avatar at `RangeReturn`. Falling or
-- being downed in the range respawns them in the range.
--
-- The training bots (models tagged `RangeBot`): LobbyServer/Range/RangeBots (look, hit stamps, respawn, strafers,
-- the damage dummy, the moving carriage) and the air targets to Range/RangeTargets (vault/01 Design/Range v5.md).
-- Remotes: `RangeTravel` (LobbyNet, no payload; the lobby bar's RANGE button): to the range from the lobby zone,
-- back from the range, nothing anywhere else; one trip per COOLDOWN, the server decides everything. Built by tools/studio/lobby_v5/BuildRangeV4/V5.luau.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local Release = require(ReplicatedStorage.Shared.Config.Release)

local RangeBots = require(script.Parent.Parent.Range.RangeBots)
local RangeTargets = require(script.Parent.Parent.Range.RangeTargets)

local RangeService = {}

local STUDIO_REMOTE = "StudioRangeToggle"

local COOLDOWN = 1.5 -- seconds between two trips for one player
local SPREAD = 3 -- studs of random spread around a spawn point, so a crowd doesn't stack

-- The match's per-player services (ServerScriptService.Server, the same place since the merge). Missing in a
-- place without the match code: the range then only moves bodies, as before.
type MatchServices = { Character: any, Weapon: any, Health: any, HealthLib: any, Damage: any }
local match: MatchServices? = nil

local lastTrip: { [Player]: number } = {}
local connections: { [Instance]: RBXScriptConnection } = {}
local placeOnSpawn: { [Player]: string } = {} -- the tag of where the next character should stand

local function loadMatch(): MatchServices?
	local server = ServerScriptService:WaitForChild("Server", 10)
	local services = server and server:FindFirstChild("Services")
	if not services then
		warn("[Range] no match code in this place: the range only moves players")
		return nil
	end
	local character = services:FindFirstChild("CharacterService")
	local weapon = services:FindFirstChild("WeaponService")
	local health = services:FindFirstChild("HealthService")
	local weaponParts = services:FindFirstChild("Weapon")
	local damage = weaponParts and weaponParts:FindFirstChild("Damage")
	if
		not (character and character:IsA("ModuleScript"))
		or not (weapon and weapon:IsA("ModuleScript"))
		or not (health and health:IsA("ModuleScript"))
		or not (damage and damage:IsA("ModuleScript"))
	then
		warn("[Range] match services missing: the range only moves players")
		return nil
	end
	return {
		Character = require(character) :: any,
		Weapon = require(weapon) :: any,
		Health = require(health) :: any,
		HealthLib = require(ReplicatedStorage.Shared.Health) :: any,
		Damage = require(damage) :: any,
	}
end

local function pick(tag: string): BasePart?
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			table.insert(list, inst)
		end
	end
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

local function spotNear(target: BasePart): CFrame
	local offset =
		Vector3.new((math.random() - 0.5) * 2 * SPREAD, 0, (math.random() - 0.5) * 2 * SPREAD)
	local look = target.CFrame.LookVector
	local pos = target.Position + offset + Vector3.new(0, 3, 0)
	return CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z))
end

local function playerFromHit(hit: BasePart): (Player?, Model?)
	local model = hit:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if not model then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player or player.Character ~= model then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return player, model
end

-- Stands a character at a spot with the tag (streaming the area in first).
local function place(player: Player, character: Model, tag: string)
	local target = pick(tag)
	if not target then
		return
	end
	local spot = spotNear(target)
	pcall(function()
		player:RequestStreamAroundAsync(spot.Position, 5)
	end)
	if character.Parent and player.Character == character then
		character:PivotTo(spot)
	end
end

-- Reloads the character; the CharacterAdded hook stands it at `tag`.
local function respawn(player: Player, tag: string)
	placeOnSpawn[player] = tag
	task.spawn(function()
		local ok, err = pcall(function()
			-- Everyone wears the match body now, lobby included (CharacterService).
			if match then
				match.Character.loadCharacter(player)
			else
				player:LoadCharacter()
			end
		end)
		if not ok then
			warn(`[Range] couldn't reload {player.Name}: {err}`)
			placeOnSpawn[player] = nil
		end
	end)
end

local function join(player: Player, character: Model)
	if PlayZone.get(player) ~= "Lobby" then
		return
	end
	if not match then
		task.spawn(place, player, character, "RangeSpawn")
		return
	end
	PlayZone.set(player, "Range")
	respawn(player, "RangeSpawn")
end

local function leave(player: Player, character: Model)
	if PlayZone.get(player) ~= "Range" then
		if not match then
			task.spawn(place, player, character, "RangeReturn")
		end
		return
	end
	PlayZone.set(player, "Lobby")
	if match then
		match.Weapon.disarm(player)
	end
	respawn(player, "RangeReturn")
end

local function onTouched(hit: BasePart, entering: boolean)
	local player, character = playerFromHit(hit)
	if not player or not character then
		return
	end
	local now = os.clock()
	if now - (lastTrip[player] or 0) < COOLDOWN then
		return
	end
	lastTrip[player] = now
	if entering then
		join(player, character)
	else
		leave(player, character)
	end
end

local function hook(part: Instance, entering: boolean)
	if not part:IsA("BasePart") or connections[part] then
		return
	end
	connections[part] = part.Touched:Connect(function(hit: BasePart)
		onTouched(hit, entering)
	end)
end

local function unhook(part: Instance)
	local c = connections[part]
	if c then
		c:Disconnect()
		connections[part] = nil
	end
end

local function onCharacter(player: Player, character: Model)
	local tag = placeOnSpawn[player]
	placeOnSpawn[player] = nil
	if not tag and PlayZone.get(player) == "Range" then
		tag = "RangeSpawn" -- a respawn after being downed or falling: back to the range
	end
	if tag then
		task.defer(function()
			character:WaitForChild("HumanoidRootPart", 5)
			place(player, character, tag :: string)
		end)
	end
end

-- The lobby bar's RANGE button (LobbyNet RangeTravel). Takes no arguments, so there is nothing to validate but the
-- player's state: alive, in the lobby or the range, and not inside the trip cooldown.
local function onTravel(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - (lastTrip[player] or 0) < COOLDOWN then
		return
	end
	local zone = PlayZone.get(player)
	if zone == "Lobby" then
		lastTrip[player] = now
		join(player, character)
	elseif zone == "Range" then
		lastTrip[player] = now
		leave(player, character)
	end
end

function RangeService.start()
	local isStudio = RunService:IsStudio()
	if not Release.RANGE_OPEN and not isStudio then
		return -- closed for this update (shared/Config/Release)
	end
	match = loadMatch()

	if isStudio then
		local lobbyFolder = ReplicatedStorage:FindFirstChild("Lobby")
		if lobbyFolder then
			local existing = lobbyFolder:FindFirstChild(STUDIO_REMOTE)
			local remote: RemoteEvent
			if existing and existing:IsA("RemoteEvent") then
				remote = existing
			else
				remote = Instance.new("RemoteEvent")
				remote.Name = STUDIO_REMOTE
				remote.Parent = lobbyFolder
			end
			remote.OnServerEvent:Connect(function(player: Player)
				if not RunService:IsStudio() then
					return
				end
				local character = player.Character
				if not character then
					return
				end
				local now = os.clock()
				if now - (lastTrip[player] or 0) < COOLDOWN then
					return
				end
				lastTrip[player] = now
				local zone = PlayZone.get(player)
				if zone == "Range" then
					leave(player, character)
				elseif zone == "Lobby" then
					join(player, character)
				end
			end)
		end
	end

	LobbyNet.event("RangeTravel").OnServerEvent:Connect(onTravel)

	for tag, entering in { RangeEntry = true, RangeExit = false } do
		for _, part in CollectionService:GetTagged(tag) do
			hook(part, entering)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			hook(part, entering)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unhook)
	end

	if match then
		RangeBots.start(match)
		local weapon = match.Weapon
		RangeTargets.start(function(fn)
			weapon.onRays(fn)
		end)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTrip[player] = nil
		placeOnSpawn[player] = nil
	end)
end

return RangeService
