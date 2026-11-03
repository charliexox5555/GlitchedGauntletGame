--!strict
-- Metro lighting (vault/01 Design/Maps/Metro.md → Look). Builds, inside Workspace.Metro:
--   Lighting     a Configuration whose attributes are Lighting properties (MapService applies them
--                when the map loads and puts the place's own lighting back afterwards)
--   LightingFx   Atmosphere, Bloom and ColorCorrection for the map (replacing the place's own)
--   Art.Lighting a few shadowless local lights at the focal points (16 in all)
-- The station is sealed (ceilings everywhere), so there is no sun: ClockTime 0 and Brightness 0
-- leave only Ambient, the Neon (coffer panels, pendant tubes, board, signs) and the lights below.
-- Mood: cool, even fluorescent light; warm amber from the departure board and the kiosks.
-- Re-runnable. It sets no Lighting properties directly: press Play (or load the map) to see it.
-- Tip: Lighting.Technology should be Future (set by hand; scripts can't).

newMap("Metro", CFrame.new(1500, 200, 0))
local map = root()

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

-- Lighting properties (MapService.LIGHTING_PROPS).
local old = map:FindFirstChild("Lighting")
if old then
	old:Destroy()
end
local config = Instance.new("Configuration")
config.Name = "Lighting"
local PROPS: { [string]: any } = {
	ClockTime = 0,
	Brightness = 0,
	GeographicLatitude = 0,
	Ambient = hex("7C8494"), -- the cool fill every surface gets
	OutdoorAmbient = hex("7C8494"), -- same as Ambient: nothing in here is "outdoors"
	ColorShift_Top = hex("000000"),
	ColorShift_Bottom = hex("000000"),
	EnvironmentDiffuseScale = 0.15, -- the sky must not tint a sealed station
	EnvironmentSpecularScale = 0.3, -- some sheen on tile, stainless and the trains
	ExposureCompensation = 0.25,
	GlobalShadows = true,
	ShadowSoftness = 0.2,
	FogStart = 0,
	FogEnd = 100000,
}
local nProps = 0
for k, v in PROPS do
	config:SetAttribute(k, v)
	nProps += 1
end
config.Parent = map

-- Effects.
local oldFx = map:FindFirstChild("LightingFx")
if oldFx then
	oldFx:Destroy()
end
local fx = Instance.new("Folder")
fx.Name = "LightingFx"
fx.Parent = map

local atmo = Instance.new("Atmosphere")
atmo.Density = 0.3 -- a light haze gives the 96-stud hall depth
atmo.Offset = 0
atmo.Color = hex("A9B4C4")
atmo.Decay = hex("5E6878")
atmo.Glare = 0
atmo.Haze = 0.4
atmo.Parent = fx

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 24
bloom.Threshold = 1.5 -- the coffer panels and tubes glow; white tile does not
bloom.Parent = fx

local grade = Instance.new("ColorCorrectionEffect")
grade.Contrast = 0.08
grade.Saturation = 0.04
grade.Brightness = 0.01
grade.TintColor = Color3.fromRGB(246, 249, 255)
grade.Parent = fx

-- Local lights at the focal points, all shadowless (mobile budget). Each hangs on an invisible,
-- non-colliding anchor part. Map space; team A's half is the 180-degree turn of team B's.
local folder = section("Art", "Lighting")
local COOL = hex("DDE8F2")
local WARM = hex("FFD9A8")
local AMBER = hex("FFB547")
local count = 0

local function anchor(name: string, x: number, y: number, z: number, yaw: number?): BasePart
	local a = box(folder, name, Vector3.new(0.2, 0.2, 0.2), at(x, y, z, yaw), COOL, {
		transparency = 1,
		castShadow = false,
	})
	decor(a)
	return a
end

local function point(
	name: string,
	x: number,
	y: number,
	z: number,
	colour: Color3,
	range: number,
	brightness: number
)
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = anchor(name, x, y, z)
	count += 1
end

local function spot(
	name: string,
	x: number,
	y: number,
	z: number,
	yaw: number,
	colour: Color3,
	range: number,
	brightness: number,
	angle: number
)
	-- points along the anchor's -Z (its front), tipped down a little
	local a = anchor(name, x, y, z, yaw)
	a.CFrame = a.CFrame * CFrame.Angles(math.rad(-12), 0, 0)
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Front
	l.Color = colour
	l.Range = range
	l.Brightness = brightness
	l.Angle = angle
	l.Shadows = false
	l.Parent = a
	count += 1
end

local function both(fn: (number) -> ())
	fn(1)
	fn(-1)
end

-- The departure board: a warm pool under each face (2).
both(function(s)
	point("BoardWash", 0, 9, s * 4, AMBER, 20, 1.1)
end)
-- Platforms: an even cool wash down each platform, two per platform (4).
both(function(s)
	point("PlatformWash", s * 24, 20, s * 24, COOL, 40, 0.8)
	point("PlatformWash", -s * 24, 20, s * 24, COOL, 40, 0.8)
end)
-- Kiosks: warm (2).
both(function(s)
	point("KioskGlow", s * 24, 6, s * 8, WARM, 14, 1.4)
end)
-- Each train's tail cab looks down the trench toward the middle: headlights (2).
both(function(s)
	-- team B's tail cab is at z = -6 facing -Z; at(..., yaw 0) faces -Z
	spot("Headlights", s * 8.5, 1.6, s * -6.8, if s > 0 then 0 else 180, hex("FFF4E0"), 34, 1.6, 50)
end)
-- Escalator wells (2) and ticket halls (2): cool.
both(function(s)
	point("EscalatorWell", s * 29.5, 20, s * 62, COOL, 26, 0.9)
	point("TicketHall", 0, 24, s * 86, COOL, 44, 0.8)
end)
-- Service corridors: one warm work light each (2).
both(function(s)
	point("CorridorLamp", s * 46, 8, s * -8, WARM, 22, 1.0)
end)

report(
	string.format(
		"Metro lighting: Lighting config (%d props), LightingFx (3), %d local lights",
		nProps,
		count
	)
)
