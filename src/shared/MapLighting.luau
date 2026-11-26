--!strict
-- Per-map lighting (vault/01 Design/Maps/00 Maps.md → How a map is built): a map may carry a Configuration named
-- "Lighting" whose AssetData fields are Lighting properties (ClockTime = 17.5, Ambient = Color3, ...), and a Folder
-- named "LightingFx" of Sky / Atmosphere / post-processing effects. Each map
-- starts from the match lighting, and restore() brings the original lobby
-- instances back so the lobby UI keeps its references to them.
-- Used by the server for a whole-server match (MapService) and, since the place merge (2026-11-21), by each
-- player's client for a pad duel in a lobby server (Lighting set on a client only changes that client's view).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local StateValues = require(SharedFolder:WaitForChild("StateValues") :: ModuleScript)
local MatchLighting =
	require(SharedFolder:WaitForChild("Config"):WaitForChild("MatchLighting") :: ModuleScript)

local MapLighting = {}

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
-- Effects other scripts put in Lighting and take away themselves: never captured, suspended or cleared here.
-- The loading screen's blur was captured, suspended by applyMatch, destroyed by the loading screen, and
-- restore() then failed to put it back ("The Parent property of DuelsLoadingBlur is locked", ~270 live
-- reports), leaving the lobby lighting half restored.
local OWNED_ELSEWHERE: { [string]: boolean } = {
	DuelsLoadingBlur = true,
	MapVoteBlur = true,
	ScopeBlur = true,
	FirewallHazeBlur = true,
	LobbyFoundBlur = true,
}

local function ours(child: Instance): boolean
	return FX_CLASSES[child.ClassName] == true and not OWNED_ELSEWHERE[child.Name]
end

type Baseline = { props: { [string]: any }, fx: { [Instance]: boolean } }
local original: Baseline? = nil
local suspended: { Instance } = {}
local installed: { Instance } = {}

function MapLighting.capture()
	if original then
		return
	end
	local props: { [string]: any } = {}
	for _, name in LIGHTING_PROPS do
		props[name] = (Lighting :: any)[name]
	end
	local fx: { [Instance]: boolean } = {}
	for _, child in Lighting:GetChildren() do
		if ours(child) then
			fx[child] = true
		end
	end
	original = { props = props, fx = fx }
end

local function setProperties(props: { [string]: any })
	for name, value in props do
		local ok = pcall(function()
			(Lighting :: any)[name] = value
		end)
		if not ok then
			warn("[MapLighting] can't set Lighting." .. name)
		end
	end
end

function MapLighting.applyMatch(map: Model)
	MapLighting.capture()
	local base = original :: Baseline
	for child in base.fx do
		if child.Parent == Lighting then
			child.Parent = nil
			table.insert(suspended, child)
		end
	end
	for _, child in installed do
		child:Destroy()
	end
	table.clear(installed)

	setProperties(MatchLighting)
	local config = map:FindFirstChild("Lighting")
	if config and config:IsA("Configuration") then
		setProperties(StateValues.all(config))
	end
	local mapFx = map:FindFirstChild("LightingFx")
	if mapFx then
		for _, child in mapFx:GetChildren() do
			if FX_CLASSES[child.ClassName] then
				local c = child:Clone()
				StateValues.set(c, MAP_FX_ATTRIBUTE, map.Name)
				c.Parent = Lighting
				table.insert(installed, c)
			end
		end
	end
end

-- A lighting profile on top of what's there (the range, 2026-11-26): `props` are Lighting properties, and the
-- effects named in `suspend` (e.g. the hub's colour grade) come out until restore(). The rest of the lobby's sky,
-- atmosphere and bloom stay.
function MapLighting.applyProfile(props: { [string]: any }, suspend: { string }?)
	MapLighting.capture()
	local base = original :: Baseline
	for _, name in suspend or {} do
		local child = Lighting:FindFirstChild(name)
		if child and base.fx[child] and child.Parent == Lighting then
			child.Parent = nil
			table.insert(suspended, child)
		end
	end
	setProperties(props)
end

function MapLighting.restore()
	local base = original
	if not base then
		return
	end
	for _, child in Lighting:GetChildren() do
		if ours(child) and not base.fx[child] then
			child:Destroy()
		end
	end
	for _, child in suspended do
		-- something else may have destroyed it meanwhile: its Parent is locked then
		pcall(function()
			child.Parent = Lighting
		end)
	end
	setProperties(base.props)
	table.clear(installed)
	table.clear(suspended)
	original = nil
end

return MapLighting
