--!strict
-- Rooftops lighting (vault/01 Design/Maps/Rooftops.md → Look): blue hour, about 20 minutes after
-- sunset. MapService applies the map's "Lighting" Configuration (attributes = Lighting properties)
-- and its "LightingFx" folder (Sky, Atmosphere, effects) when the map loads, and restores the
-- place's own lighting afterwards. Bundle with Art: bundle.py Rooftops Art Lighting.
--
-- Readability first: the sun is just under the western horizon (GeographicLatitude 0 keeps its
-- path in the X/Y plane, so any low light rakes across the map, never down a team's view), and
-- the ambient is cool and high (LihFolk "readable night": tinted, never black, Ambient <=
-- OutdoorAmbient) so a player against any wall reads at a glance. The lit windows and signs are
-- Neon in the kit; real lights only at the focal points (6, shadowless).
--
-- PREVIEW = true applies it straight to Lighting for edit-mode screenshots: don't save the place
-- with that (MapService takes the place's lighting as its baseline).

local PREVIEW = false

local map = newMap("Rooftops", CFrame.new(1500, 200, 1500))
local LightingService = game:GetService("Lighting")

local old = map:FindFirstChild("Lighting")
if old then
	old:Destroy()
end
local config = Instance.new("Configuration")
config.Name = "Lighting"
-- Only properties MapService also restores (its LIGHTING_PROPS list).
local PROPS: { [string]: any } = {
	ClockTime = 18.45,
	GeographicLatitude = 0,
	Brightness = 1.4,
	Ambient = Color3.fromRGB(112, 120, 152),
	OutdoorAmbient = Color3.fromRGB(150, 160, 200),
	ColorShift_Top = Color3.fromRGB(176, 192, 255),
	ColorShift_Bottom = Color3.fromRGB(44, 46, 78),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.6,
	ExposureCompensation = 0.35,
	GlobalShadows = true,
	ShadowSoftness = 0.4,
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
sky.Name = "BlueHourSky"
sky.CelestialBodiesShown = true
sky.SunAngularSize = 14
sky.MoonAngularSize = 9
sky.StarCount = 1500
sky.Parent = fx

-- Blue haze: fades the far skyline, keeps the near roofs crisp.
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(112, 132, 190)
atmosphere.Decay = Color3.fromRGB(58, 66, 128)
atmosphere.Glare = 0.2
atmosphere.Haze = 1.2
atmosphere.Parent = fx

-- The windows and signs bloom a little; players (no Neon) never do.
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Size = 24
bloom.Threshold = 1.2
bloom.Parent = fx

local grade = Instance.new("ColorCorrectionEffect")
grade.Brightness = 0.03
grade.Contrast = 0.1
grade.Saturation = 0.05
grade.TintColor = Color3.fromRGB(236, 240, 255)
grade.Parent = fx

fx.Parent = map

-- Focal lights on invisible holders in Art.Lights (6, shadowless).
local lights = section("Art", "Lights")
local count = 0

local function holder(name: string, cf: CFrame): BasePart
	local p = box(
		lights,
		name,
		Vector3.new(0.4, 0.4, 0.4),
		cf,
		Color3.new(1, 1, 1),
		{ transparency = 1, castShadow = false }
	)
	decor(p)
	return p
end

local function spot(
	name: string,
	cf: CFrame,
	color: Color3,
	range: number,
	angle: number,
	brightness: number
)
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Front
	l.Color = color
	l.Range = range
	l.Angle = angle
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = holder(name, cf)
	count += 1
end

local function point(
	name: string,
	x: number,
	y: number,
	z: number,
	color: Color3,
	range: number,
	brightness: number
)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = holder(name, at(x, y, z))
	count += 1
end

-- The Pit billboards: floodlit from their lamp arms (B's faces +Z at z 14.6, A's faces -Z).
local FLOOD = Color3.fromRGB(255, 238, 210)
for _, s in { 1, -1 } do
	local x, z = -12 * s, 14.1 * s
	local eye = Vector3.new(x, 20.5, z + 3.5 * s)
	spot("BillboardFlood", CFrame.lookAt(eye, Vector3.new(x, 6, z)), FLOOD, 18, 80, 2)
end
-- The roof signs spill their colour on the tower roofs (pink west, amber east).
point("SignGlowWest", -36.5, 25, 0, Color3.fromHex("FF4FA3"), 18, 1.2)
point("SignGlowEast", 36.5, 25, 0, Color3.fromHex("FFB238"), 18, 1.2)
-- A warm pool under the water tank in the middle of the Pit.
point("PitLamp", 0, 4, 0, Color3.fromRGB(255, 214, 160), 20, 0.8)

if PREVIEW then
	for name, value in PROPS do
		(LightingService :: any)[name] = value
	end
	for _, c in LightingService:GetChildren() do
		if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end
	for _, c in fx:GetChildren() do
		c:Clone().Parent = LightingService
	end
end

report(
	string.format(
		"Rooftops lighting: ClockTime %.2f, %d effects, %d lights (shadowless)%s",
		PROPS.ClockTime,
		#fx:GetChildren(),
		count,
		if PREVIEW then ", PREVIEW applied to Lighting" else ""
	)
)
