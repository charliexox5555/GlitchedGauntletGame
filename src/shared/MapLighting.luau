--!strict
-- Per-map lighting (vault/01 Design/Maps/00 Maps.md → How a map is built): a map may carry a Configuration named
-- "Lighting" whose AssetData fields are Lighting properties (ClockTime = 17.5, Ambient = Color3, ...), and a Folder
-- named "LightingFx" of Sky / Atmosphere / post-processing effects. apply() puts the place's own lighting back
-- (captured the first time) and the map's on top; restore() puts the place's back alone.
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

export type Baseline = { props: { [string]: any }, fx: { Instance } }

-- The place's lighting as it is now.
function MapLighting.capture(): Baseline
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
	return { props = props, fx = fx }
end

-- What every match map starts from (Config/MatchLighting: the old match place's lighting, no effects).
function MapLighting.matchBaseline(): Baseline
	return { props = table.clone(MatchLighting) :: any, fx = {} }
end

-- The baseline back, then `map`'s own lighting on top (if it has any).
function MapLighting.apply(base: Baseline, map: Instance?)
	local config = map and map:FindFirstChild("Lighting")
	local mapFx = map and map:FindFirstChild("LightingFx")
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
	if mapFx and map then
		for _, child in mapFx:GetChildren() do
			if FX_CLASSES[child.ClassName] then
				local c = child:Clone()
				StateValues.set(c, MAP_FX_ATTRIBUTE, map.Name)
				c.Parent = Lighting
			end
		end
	end
	if config and config:IsA("Configuration") then
		for name, value in StateValues.all(config) do
			local ok = pcall(function()
				(Lighting :: any)[name] = value
			end)
			if not ok then
				warn("[MapLighting] can't set Lighting." .. name)
			end
		end
	end
end

function MapLighting.restore(base: Baseline)
	MapLighting.apply(base, nil)
end

return MapLighting
