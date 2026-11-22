--!strict
-- Loads a match map: clones the template from ServerStorage.Maps into
-- workspace.ActiveMap. A map still sitting in Workspace (being edited in
-- Studio) moves into ServerStorage.Maps first, for this run only. It finds the
-- map's spawns and barriers by tag: ArenaSpawn_A / ArenaSpawn_B, ArenaBarrier.
--
-- Per-map lighting (vault/01 Design/Maps/00 Maps.md → How a map is built): a
-- map may carry a Configuration named "Lighting" whose AssetData fields are Lighting
-- properties (ClockTime = 17.5, Ambient = Color3, ...), and a Folder named
-- "LightingFx" of Sky / Atmosphere / post-processing effects. Loading the map
-- applies them on top of the place's own lighting (remembered the first time),
-- and loading a map without them puts the place's lighting back.
--
-- Kill height: anyone who falls this far below the map's pivot (a harbour, a
-- rooftop edge) dies at once instead of falling to FallenPartsDestroyHeight.
-- The map's authored "KillDepth" field (studs) overrides the default.

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Globals =
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local CollectionService = game:GetService("CollectionService")
local Players = Context.players
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Health = require(game:GetService("ReplicatedStorage").Shared.Health)
local MapLighting = require(game:GetService("ReplicatedStorage").Shared.MapLighting)
local MatchConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Match)

local HealthService = require(Globals.HealthService)

local MapService = {}

local BARRIER_TAG = "ArenaBarrier"
local SPAWN_TAGS = { "ArenaSpawn_A", "ArenaSpawn_B" }

local active: Model? = nil

local KILL_CHECK = 0.2 -- seconds between checks

-- The place's own lighting, captured before the first map changes it
-- (whole-server matches only: a pad duel's players light their own view,
-- client/Controllers/MatchLightingController).
local baseline: MapLighting.Baseline? = nil

local function applyLighting(map: Model)
	if not Context.ownsServer then
		return
	end
	if not baseline then
		baseline = MapLighting.matchBaseline()
	end
	MapLighting.apply(baseline :: MapLighting.Baseline, map)
end

local function mapsFolder(): Folder
	local folder = ServerStorage:FindFirstChild("Maps")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "Maps"
	made.Parent = ServerStorage
	return made
end

local function template(id: string): Model?
	local folder = mapsFolder()
	local stored = folder:FindFirstChild(id)
	if stored and stored:IsA("Model") then
		return stored
	end
	local inWorkspace = workspace:FindFirstChild(id)
	if inWorkspace and inWorkspace:IsA("Model") then
		inWorkspace.Parent = folder
		return inWorkspace
	end
	return nil
end

-- Loads the map (replacing any loaded one) and switches off every spawn that
-- isn't its own. Returns false if the map doesn't exist.
-- Whether a map with this id is installed (ServerStorage.Maps or Workspace).
function MapService.has(id: string): boolean
	local stored = mapsFolder():FindFirstChild(id)
	local inWorkspace = workspace:FindFirstChild(id)
	return (stored ~= nil and stored:IsA("Model"))
		or (inWorkspace ~= nil and inWorkspace:IsA("Model"))
end

function MapService.load(id: string): boolean
	local source = template(id)
	if not source then
		warn("[MapService] no map named", id)
		return false
	end
	-- The template's lighting (the clone carries the same children).
	applyLighting(source)
	if active then
		active:Destroy()
	end
	local map = source:Clone()
	-- A pad duel (MatchKit/Context): its own name and map slot, in its own world folder.
	map.Name = if Context.ownsServer then "ActiveMap" else "ActiveMap_" .. Context.id
	map:SetAttribute("MatchId", if Context.ownsServer then nil else Context.id)
	if Context.offset ~= Vector3.zero then
		map:PivotTo(map:GetPivot() + Context.offset)
	end
	-- Whole map loaded for everyone, so an enemy never streams out mid-fight. A
	-- pad duel's map only for its own players (lobby players never need it).
	if Context.ownsServer then
		map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	else
		map.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
		for _, p in Players:GetPlayers() do
			map:AddPersistentPlayer(p)
		end
	end
	map.Parent = Context.world
	active = map
	if Context.ownsServer then
		for _, d in workspace:GetDescendants() do
			if d:IsA("SpawnLocation") then
				d.Enabled = d:IsDescendantOf(map)
				d.Duration = 0 -- no spawn shield: the barrier protects you until the fight
			end
		end
	else
		-- In a lobby server the lobby's spawns stay; the duel places its players itself (MatchService).
		for _, d in map:GetDescendants() do
			if d:IsA("SpawnLocation") then
				d.Enabled = false
				d.Duration = 0
			end
		end
	end
	return true
end

-- The loaded map's spawns for team 1 or team 2, in a fixed order.
function MapService.spawns(team: number): { SpawnLocation }
	local list: { SpawnLocation } = {}
	local tag = SPAWN_TAGS[team]
	if active and tag then
		for _, s in CollectionService:GetTagged(tag) do
			if s:IsA("SpawnLocation") and s:IsDescendantOf(active) then
				table.insert(list, s)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

-- Up: solid and visible. Down: no collision, no bullets stopped, not seen.
function MapService.setBarriers(up: boolean)
	if not active then
		return
	end
	for _, b in CollectionService:GetTagged(BARRIER_TAG) do
		if b:IsA("BasePart") and b:IsDescendantOf(active) then
			b.CanCollide = up
			b.CanQuery = up
			b.Transparency = if up
				then (StateValues.get(b, "UpTransparency") or 0.6) :: number
				else 1
			for _, t in b:GetChildren() do
				if t:IsA("Texture") then
					t.Transparency = if up then 0 else 1
				end
			end
		end
	end
end

-- From map space (the map's own pivot) to the world.
function MapService.toWorld(position: Vector3): Vector3?
	if not active then
		return nil
	end
	return active:GetPivot():PointToWorldSpace(position)
end

-- Falling off the map kills (the kill height above).
local sinceCheck = 0
local VOID_MARGIN = 50 -- studs above FallenPartsDestroyHeight
local function checkFalls(dt: number)
	sinceCheck += dt
	local map = active
	if sinceCheck < KILL_CHECK then
		return
	end
	sinceCheck = 0
	-- No map (the test range, a lobby): down anyone falling toward the void
	-- before the engine deletes their parts (nobody dies on their own now).
	if not map then
		local voidY = workspace.FallenPartsDestroyHeight + VOID_MARGIN
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if
				root
				and root:IsA("BasePart")
				and humanoid
				and Health.isAlive(humanoid)
				and root.Position.Y < voidY
			then
				HealthService.down(humanoid)
			end
		end
		return
	end
	local depth = StateValues.get(map, "KillDepth")
	local killY = map:GetPivot().Position.Y
		- (if typeof(depth) == "number" then depth else MatchConfig.KILL_DEPTH)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			root
			and root:IsA("BasePart")
			and humanoid
			and Health.isAlive(humanoid)
			and root.Position.Y < killY
		then
			HealthService.down(humanoid)
		end
	end
end

-- The middle of a team's spawns on the loaded map.
function MapService.spawnCentre(team: number): Vector3?
	local spawns = MapService.spawns(team)
	if #spawns == 0 then
		return nil
	end
	local sum = Vector3.zero
	for _, s in spawns do
		sum += s.Position
	end
	return sum / #spawns
end

-- Maps are edited in Workspace (one Model per map, at its own spot). A
-- running server keeps only the loaded one in the world: the rest go to
-- ServerStorage.Maps at start (Config/Match MAPS ids and any model with
-- tagged team spawns), so a live server doesn't carry every map.
local function stashMaps()
	local folder = mapsFolder()
	for _, child in workspace:GetChildren() do
		if not child:IsA("Model") or child.Name == "ActiveMap" then
			continue
		end
		local isMap = false
		for _, d in child:GetDescendants() do
			if d:IsA("SpawnLocation") and (d:HasTag(SPAWN_TAGS[1]) or d:HasTag(SPAWN_TAGS[2])) then
				isMap = true
				break
			end
		end
		if isMap and not folder:FindFirstChild(child.Name) then
			child.Parent = folder
		end
	end
end

function MapService.start()
	if Context.ownsServer then
		stashMaps()
	end
	RunService.Heartbeat:Connect(checkFalls)
end

function MapService.map(): Model?
	return active
end

return MapService
