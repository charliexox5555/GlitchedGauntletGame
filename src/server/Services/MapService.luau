--!strict
-- Loads a match map: clones the template from ServerStorage.Maps into
-- workspace.ActiveMap. A map still sitting in Workspace (being edited in
-- Studio) moves into ServerStorage.Maps first, for this run only. It finds the
-- map's spawns and barriers by tag: ArenaSpawn_A / ArenaSpawn_B, ArenaBarrier.
--
-- Per-map lighting (vault/01 Design/Maps/00 Maps.md → How a map is built): a
-- map may carry a Configuration named "Lighting" whose attributes are Lighting
-- properties (ClockTime = 17.5, Ambient = Color3, ...), and a Folder named
-- "LightingFx" of Sky / Atmosphere / post-processing effects. Loading the map
-- applies them on top of the place's own lighting (remembered the first time),
-- and loading a map without them puts the place's lighting back.
--
-- Kill height: anyone who falls this far below the map's pivot (a harbour, a
-- rooftop edge) dies at once instead of falling to FallenPartsDestroyHeight.
-- The map's "KillDepth" attribute (studs) overrides the default.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Health = require(game:GetService("ReplicatedStorage").Shared.Health)
local MatchConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Match)

local HealthService = require(script.Parent.HealthService)

local MapService = {}

local BARRIER_TAG = "ArenaBarrier"
local SPAWN_TAGS = { "ArenaSpawn_A", "ArenaSpawn_B" }

local active: Model? = nil

local KILL_CHECK = 0.2 -- seconds between checks

-- The place's own lighting, captured before the first map changes it.
type Baseline = { props: { [string]: any }, fx: { Instance } }
local baseline: Baseline? = nil
local LIGHTING_PROPS = {
	"Ambient",
	"Brightness",
	"ClockTime",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
	"FogStart",
	"GeographicLatitude",
	"GlobalShadows",
	"OutdoorAmbient",
	"ShadowSoftness",
}
local FX_CLASSES: { [string]: boolean } = {
	Sky = true,
	Atmosphere = true,
	BloomEffect = true,
	ColorCorrectionEffect = true,
	SunRaysEffect = true,
	DepthOfFieldEffect = true,
	BlurEffect = true,
}
local MAP_FX_ATTRIBUTE = "FromMap"

local function captureBaseline()
	if baseline then
		return
	end
	local props: { [string]: any } = {}
	for _, name in LIGHTING_PROPS do
		props[name] = (Lighting :: any)[name]
	end
	local fx: { Instance } = {}
	for _, child in Lighting:GetChildren() do
		if FX_CLASSES[child.ClassName] then
			table.insert(fx, child:Clone())
		end
	end
	baseline = { props = props, fx = fx }
end

-- The place's lighting back, then the map's own on top (if it has any).
local function applyLighting(map: Model)
	captureBaseline()
	local base = baseline :: Baseline
	local config = map:FindFirstChild("Lighting")
	local mapFx = map:FindFirstChild("LightingFx")
	for name, value in base.props do
		pcall(function()
			(Lighting :: any)[name] = value
		end)
	end
	-- Effects: the map's replace the place's of the same class.
	local replace: { [string]: boolean } = {}
	if mapFx then
		for _, child in mapFx:GetChildren() do
			replace[child.ClassName] = true
		end
	end
	for _, child in Lighting:GetChildren() do
		if FX_CLASSES[child.ClassName] then
			child:Destroy()
		end
	end
	for _, fx in base.fx do
		if not replace[fx.ClassName] then
			fx:Clone().Parent = Lighting
		end
	end
	if mapFx then
		for _, child in mapFx:GetChildren() do
			if FX_CLASSES[child.ClassName] then
				local c = child:Clone()
				c:SetAttribute(MAP_FX_ATTRIBUTE, map.Name)
				c.Parent = Lighting
			end
		end
	end
	if config and config:IsA("Configuration") then
		for name, value in config:GetAttributes() do
			local ok = pcall(function()
				(Lighting :: any)[name] = value
			end)
			if not ok then
				warn("[MapService] map lighting: can't set Lighting." .. name)
			end
		end
	end
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
	map.Name = "ActiveMap"
	-- Whole map loaded for everyone, so an enemy never streams out mid-fight.
	map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	map.Parent = workspace
	active = map
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = d:IsDescendantOf(map)
			d.Duration = 0 -- no spawn shield: the barrier protects you until the fight
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
			b.Transparency = if up then (b:GetAttribute("UpTransparency") or 0.6) :: number else 1
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
	local depth = map:GetAttribute("KillDepth")
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
	stashMaps()
	RunService.Heartbeat:Connect(checkFalls)
end

function MapService.map(): Model?
	return active
end

return MapService
