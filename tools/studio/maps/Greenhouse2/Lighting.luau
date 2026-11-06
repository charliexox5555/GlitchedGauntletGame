--!strict
-- Greenhouse lighting (vault/01 Design/Maps/Greenhouse.md -> Look): bright midday through glass.
-- Bundle after the greybox (it needs Workspace.Greenhouse):
--   python tools/studio/maps/bundle.py Greenhouse Greybox Art Lighting -o greenhouse.luau
-- Greenhouse2 (forked from Greenhouse's, lifted per the Map Quality Standard §3 Lighting). Builds Greenhouse2.Lighting (a Configuration: attributes = Lighting properties) and Greenhouse2.LightingFx (Sky,
-- Atmosphere, Bloom, ColorCorrection, SunRays). MapService applies both when the map loads and puts the place's own
-- lighting back for maps without them, so this never touches the Lighting service unless PREVIEW is on.
--
-- Sun high (about 65 degrees, from the south-west at 13.2) so the iron ribs stripe the floors and no spawn looks
-- into it. Wall and roof glass cast no shadow (Art.luau), so the halls are sunlit; the brick Sheds keep their solid
-- ceiling and stay the one shaded lane. No dynamic lights. Bloom has a high threshold so white iron and mint glass
-- don't glow. Phones below quality 4 lose shadows: white frames, mint glass, green beds and grey stone still
-- separate by value.

-- PREVIEW = true also applies the look to Lighting now (edit-mode screenshots). Don't save the place with it on.
local PREVIEW = false

local Lighting = game:GetService("Lighting")

local map = root()

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local PROPS: { [string]: any } = {
	ClockTime = 16.7, -- kit v2: low golden sun (reviewers r1-r3: no golden light)
	GeographicLatitude = 38,
	Brightness = 3.1, -- kit v2: lifted again for the lower sun
	Ambient = rgb(146, 138, 126), -- kit v2: warm fill (a real fill: shade reads lit, not grey)
	OutdoorAmbient = rgb(180, 172, 160),
	ColorShift_Top = rgb(255, 204, 146),
	ColorShift_Bottom = rgb(0, 0, 0),
	EnvironmentDiffuseScale = 0.35,
	EnvironmentSpecularScale = 0.35,
	ExposureCompensation = -0.1, -- Greenhouse was -0.3; kit v2 warmer and lower sun needs more
	ShadowSoftness = 0.2,
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

-- Roblox's default skybox, a bright sun disc, no stars.
local sky = Instance.new("Sky")
sky.Name = "GreenhouseSky"
sky.SunAngularSize = 12
sky.StarCount = 0
sky.CelestialBodiesShown = true
sky.Parent = fx

-- A light green-white haze: depth for the dome and the far halls; the floors stay crisp.
local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "GreenhouseAtmosphere"
atmosphere.Density = 0.16
atmosphere.Offset = 0.1
atmosphere.Color = rgb(238, 228, 208)
atmosphere.Decay = rgb(170, 186, 200)
atmosphere.Glare = 0.2
atmosphere.Haze = 0.4
atmosphere.Parent = fx

local bloom = Instance.new("BloomEffect")
bloom.Name = "GreenhouseBloom"
bloom.Intensity = 0.35
bloom.Size = 24
bloom.Threshold = 1.8
bloom.Parent = fx

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "GreenhouseGrade"
grade.Brightness = 0
grade.Contrast = 0.18
grade.Saturation = 0.12
grade.TintColor = rgb(255, 238, 214) -- r2: warmer, against the glass's cyan cast
grade.Parent = fx

local rays = Instance.new("SunRaysEffect")
rays.Name = "GreenhouseSunRays"
rays.Intensity = 0.14
rays.Spread = 0.5
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
		"Greenhouse lighting: %d properties, %d effects%s",
		count,
		#fx:GetChildren(),
		if PREVIEW then " (applied to Lighting for preview)" else ""
	)
)
