--!strict
-- Old Town lighting (vault/01 Design/Maps/Old Town.md → Look): a warm, readable afternoon.
-- Bundle after the greybox (it needs Workspace.OldTown):
--   python tools/studio/maps/bundle.py OldTown Greybox Art Lighting -o oldtown.luau
-- Builds OldTown.Lighting (a Configuration: attributes = Lighting properties) and
-- OldTown.LightingFx (Sky, Atmosphere, Bloom, ColorCorrection, SunRays). MapService applies
-- both when the map loads and puts the place's own lighting back for maps without them, so
-- this script never touches the Lighting service itself unless PREVIEW is on.
--
-- Sun: GeographicLatitude 23.5 puts Roblox's (June) sun path through the zenith, so the
-- afternoon sun sits low in the west (-X, about 11° north of west, ~41° up at 15.6): shadows
-- run across the map toward the clock tower, not along it toward a spawn. Sunlit plaza,
-- shaded alleys, warm bounce under the arcades. Mobile: no dynamic lights, one shadowed sun;
-- phones below quality 4 lose shadows, so the lanes still read by colour (light paving,
-- darker cobbles, cream walls, terracotta roofs).

-- PREVIEW = true also applies the look to Lighting now (edit-mode screenshots). Don't save the
-- place with it on: the place's own lighting is the baseline for maps without their own.
local PREVIEW = false

local Lighting = game:GetService("Lighting")

local map = root()

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local PROPS: { [string]: any } = {
	ClockTime = 15.6,
	GeographicLatitude = 23.5,
	Brightness = 2.4,
	Ambient = rgb(112, 100, 90),
	OutdoorAmbient = rgb(150, 136, 122),
	ColorShift_Top = rgb(255, 228, 196),
	ColorShift_Bottom = rgb(0, 0, 0),
	EnvironmentDiffuseScale = 0.4,
	EnvironmentSpecularScale = 0.3,
	ExposureCompensation = 0.05,
	ShadowSoftness = 0.25,
	GlobalShadows = true,
}

local old = map:FindFirstChild("Lighting")
if old then
	old:Destroy()
end
local config = Instance.new("Configuration")
config.Name = "Lighting"
for name, value in PROPS do
	config:SetAttribute(name, value)
end
config.Parent = map

local oldFx = map:FindFirstChild("LightingFx")
if oldFx then
	oldFx:Destroy()
end
local fx = Instance.new("Folder")
fx.Name = "LightingFx"

-- Roblox's default skybox (no custom textures), a warm sun disc, no stars.
local sky = Instance.new("Sky")
sky.Name = "OldTownSky"
sky.SunAngularSize = 14
sky.MoonAngularSize = 8
sky.StarCount = 0
sky.CelestialBodiesShown = true
sky.Parent = fx

-- A light warm haze: depth on the tower and the far roofs, the plaza stays crisp.
local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "OldTownAtmosphere"
atmosphere.Density = 0.3
atmosphere.Offset = 0.18
atmosphere.Color = rgb(222, 198, 168)
atmosphere.Decay = rgb(178, 142, 112)
atmosphere.Glare = 0.25
atmosphere.Haze = 1.6
atmosphere.Parent = fx

-- High threshold: the cream walls must not blow out.
local bloom = Instance.new("BloomEffect")
bloom.Name = "OldTownBloom"
bloom.Intensity = 0.45
bloom.Size = 22
bloom.Threshold = 1.6
bloom.Parent = fx

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "OldTownGrade"
grade.Brightness = 0.02
grade.Contrast = 0.1
grade.Saturation = 0.1
grade.TintColor = rgb(255, 247, 236)
grade.Parent = fx

local rays = Instance.new("SunRaysEffect")
rays.Name = "OldTownSunRays"
rays.Intensity = 0.04
rays.Spread = 0.6
rays.Parent = fx

fx.Parent = map

if PREVIEW then
	for name, value in PROPS do
		pcall(function()
			(Lighting :: any)[name] = value
		end)
	end
	for _, child in Lighting:GetChildren() do
		for _, mine in fx:GetChildren() do
			if child.ClassName == mine.ClassName then
				child:Destroy()
				break
			end
		end
	end
	for _, mine in fx:GetChildren() do
		mine:Clone().Parent = Lighting
	end
end

local count = 0
for _ in PROPS do
	count += 1
end
report(
	string.format(
		"OldTown lighting: %d properties, %d effects%s",
		count,
		#fx:GetChildren(),
		if PREVIEW then " (applied to Lighting for preview)" else ""
	)
)
