--!strict
-- Dockyard lighting (vault/01 Design/Maps/Dockyard.md → Look): dusk over the harbour.
-- MapService applies the map's "Lighting" Configuration (attributes = Lighting properties) and
-- its "LightingFx" folder (Sky, Atmosphere, effects) when the map loads, and restores the
-- place's own lighting afterwards. Bundle with Art: bundle.py Dockyard Art Lighting.
--
-- The sun sits on the horizon down the X axis (GeographicLatitude 0 puts the sun's path in the
-- X/Y plane), so it rakes across the pier and neither team looks into it. Check in Studio:
-- Lighting:GetSunDirection() should be mostly ±X with a small Y.
-- Lights: 9 shadowless lights at the focal points (4 high masts, the crane, 2 sheds, 2 stair
-- heads); everything else that glows is Neon in the kit.
--
-- This script never touches the place's Lighting service (MapService remembers it as the
-- baseline): to see the dusk, playtest with the map forced (Studio ForceMap = "Dockyard").

local map = newMap("Dockyard", CFrame.new(-1500, 200, 0))

-- The Configuration MapService reads. Only properties MapService also restores (its
-- LIGHTING_PROPS list) are set, so another map's lighting comes back clean.
local old = map:FindFirstChild("Lighting")
if old then
	old:Destroy()
end
local config = Instance.new("Configuration")
config.Name = "Lighting"
local PROPS: { [string]: any } = {
	-- Tuned in Studio 2026-11-03: 17.75 / ambient 68-112 left the spawns and the
	-- container lanes too dark to read players in first person.
	ClockTime = 17.3,
	GeographicLatitude = 0,
	Brightness = 2.4,
	Ambient = Color3.fromRGB(118, 108, 140),
	OutdoorAmbient = Color3.fromRGB(168, 152, 186),
	ColorShift_Top = Color3.fromRGB(255, 168, 108),
	ColorShift_Bottom = Color3.fromRGB(70, 60, 110),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.5,
	ExposureCompensation = 0.45,
	GlobalShadows = true,
	ShadowSoftness = 0.25,
}
for name, value in PROPS do
	config:SetAttribute(name, value)
end
config.Parent = map

-- Sky, atmosphere and post effects (the map's replace the place's of the same class).
local oldFx = map:FindFirstChild("LightingFx")
if oldFx then
	oldFx:Destroy()
end
local fx = Instance.new("Folder")
fx.Name = "LightingFx"

local sky = Instance.new("Sky")
sky.Name = "DuskSky"
sky.CelestialBodiesShown = true
sky.SunAngularSize = 18
sky.MoonAngularSize = 9
sky.StarCount = 2500
sky.Parent = fx

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.12
atmosphere.Color = Color3.fromRGB(214, 150, 140)
atmosphere.Decay = Color3.fromRGB(96, 70, 140)
atmosphere.Glare = 0.55
atmosphere.Haze = 1.4
atmosphere.Parent = fx

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 28
bloom.Threshold = 1.4
bloom.Parent = fx

local grade = Instance.new("ColorCorrectionEffect")
grade.Brightness = 0.02
grade.Contrast = 0.08
grade.Saturation = 0.08
grade.TintColor = Color3.fromRGB(255, 244, 238)
grade.Parent = fx

local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.05
rays.Spread = 0.6
rays.Parent = fx

fx.Parent = map

-- Focal lights (sodium, shadowless), on invisible holders in Art.Lights.
local lights = section("Art", "Lights")
local SODIUM = Color3.fromRGB(255, 170, 90)
local count = 0

local function holder(name: string, cf: CFrame): BasePart
	local p = box(
		lights,
		name,
		Vector3.new(0.4, 0.4, 0.4),
		cf,
		SODIUM,
		{ transparency = 1, castShadow = false }
	)
	decor(p)
	return p
end

-- A SpotLight pointing straight down from (x, y, z).
local function downlight(
	name: string,
	x: number,
	y: number,
	z: number,
	range: number,
	angle: number,
	brightness: number
)
	local p = holder(name, at(x, y, z) * CFrame.Angles(-math.pi / 2, 0, 0))
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Front
	l.Angle = angle
	l.Range = range
	l.Brightness = brightness
	l.Color = SODIUM
	l.Shadows = false
	l.Parent = p
	count += 1
end

local function pointlight(
	name: string,
	x: number,
	y: number,
	z: number,
	range: number,
	brightness: number
)
	local p = holder(name, at(x, y, z))
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = SODIUM
	l.Shadows = false
	l.Parent = p
	count += 1
end

-- High masts (crowns at 36.6 on the barrier), pulled 3 studs in toward the yard.
for _, m in { { -67, 40 }, { 67, 84 }, { 67, -40 }, { -67, -84 } } do
	local inward = if m[1] > 0 then -3 else 3
	downlight("MastLight", m[1] + inward, 36, m[2], 60, 110, 2.5)
end
-- The crane's floodlights over the Crane stack.
downlight("CraneLight", 0, 50, 0, 56, 90, 2)
-- Inside each Shed, and at the head of each stair.
for _, s in { 1, -1 } do
	pointlight("ShedLight", 55 * s, 12, 42 * s, 22, 1.5)
	pointlight("StairLight", 30 * s, 12, 56 * s, 16, 1.2)
end

report(
	string.format(
		"Dockyard lighting: ClockTime %.2f, %d effects, %d lights (shadowless)",
		PROPS.ClockTime,
		#fx:GetChildren(),
		count
	)
)
