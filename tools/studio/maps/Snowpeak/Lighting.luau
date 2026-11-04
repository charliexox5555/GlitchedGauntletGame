--!strict
-- Snowpeak Lodge lighting (vault/01 Design/Maps/Snowpeak Lodge.md → Look): a clear, cold morning.
-- MapService applies the map's "Lighting" Configuration (attributes = Lighting properties) and its
-- "LightingFx" folder (Sky, Atmosphere, effects) when the map loads, and restores the place's own
-- lighting afterwards. Bundle with Art: bundle.py Snowpeak Art Lighting.
--
-- GeographicLatitude 0 keeps the sun's path in the X/Y plane, so it rakes across the map (±X) and
-- neither team looks into it; ClockTime 8.6 puts it about 40 degrees up for long, blue shadows.
-- Snow is the brightest surface on screen: exposure comes down and the ambient goes blue (LihFolk
-- Frost preset) so the snow keeps its shape and players read against it. Check:
-- Lighting:GetSunDirection() mostly ±X; a greyscale screenshot where the snow is not clipped white.
-- Lights: 10 warm, shadowless lights inside the Lodge and on the station decks (the focal points);
-- every other glow is Neon in the kit (windows, lanterns, lamp posts).

local map = newMap("Snowpeak", CFrame.new(-1500, 200, -1500))

local old = map:FindFirstChild("Lighting")
if old then
	old:Destroy()
end
local config = Instance.new("Configuration")
config.Name = "Lighting"
local PROPS: { [string]: any } = {
	ClockTime = 8.6,
	GeographicLatitude = 0,
	Brightness = 2.3,
	Ambient = Color3.fromRGB(112, 126, 152),
	OutdoorAmbient = Color3.fromRGB(150, 168, 198),
	ColorShift_Top = Color3.fromRGB(255, 236, 212),
	ColorShift_Bottom = Color3.fromRGB(140, 164, 210),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.4,
	ExposureCompensation = -0.35,
	GlobalShadows = true,
	ShadowSoftness = 0.2,
}
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

local sky = Instance.new("Sky")
sky.Name = "MorningSky"
sky.CelestialBodiesShown = true
sky.SunAngularSize = 12
sky.MoonAngularSize = 6
sky.StarCount = 0
sky.Parent = fx

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.15
atmosphere.Color = Color3.fromRGB(205, 222, 245)
atmosphere.Decay = Color3.fromRGB(150, 172, 212)
atmosphere.Glare = 0.25
atmosphere.Haze = 1.2
atmosphere.Parent = fx

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.4
bloom.Size = 24
bloom.Threshold = 1.6
bloom.Parent = fx

local grade = Instance.new("ColorCorrectionEffect")
grade.Brightness = 0
grade.Contrast = 0.08
grade.Saturation = -0.05
grade.TintColor = Color3.fromRGB(245, 250, 255)
grade.Parent = fx

local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.04
rays.Spread = 0.5
rays.Parent = fx

fx.Parent = map

-- Warm focal lights (shadowless) on invisible holders in Art.Lights.
local lights = section("Art", "Lights")
local WARM = Color3.fromRGB(255, 184, 120)
local FIRE = Color3.fromRGB(255, 140, 70)
local count = 0

local function pointlight(
	name: string,
	x: number,
	y: number,
	z: number,
	range: number,
	brightness: number,
	color: Color3
)
	local p = box(
		lights,
		name,
		Vector3.new(0.4, 0.4, 0.4),
		at(x, y, z),
		color,
		{ transparency = 1, castShadow = false }
	)
	decor(p)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color
	l.Shadows = false
	l.Parent = p
	count += 1
end

for _, s in { 1, -1 } do
	pointlight("FireLight", 0, 3, 5 * s, 14, 1.6, FIRE) -- each face of the fireplace
	pointlight("LoungeLight", 9 * s, 14, 6 * s, 22, 1.2, WARM) -- under the chandeliers
	pointlight("LoftLight", 0, 16, 17 * s, 16, 1.0, WARM)
	pointlight("HallLight", 0, 6.5, 17 * s, 14, 0.9, WARM) -- the bar and the entry hall under the loft
	pointlight("DeckLight", -52 * s, 18.5, 42 * s, 18, 0.8, WARM) -- the station deck under its roof
end

report(
	string.format(
		"Snowpeak lighting: ClockTime %.1f, %d effects, %d lights (shadowless)",
		PROPS.ClockTime,
		#fx:GetChildren(),
		count
	)
)
