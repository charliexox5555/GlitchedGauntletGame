--!strict
-- Bunker lighting (vault/01 Design/Maps/Bunker.md → Look): cool shade everywhere, one warm column of sun.
-- Bundle after the greybox and the art (it needs Workspace.Bunker):
--   python tools/studio/maps/bundle.py Bunker Greybox Art Lighting -o bunker.luau
-- Builds, inside Workspace.Bunker:
--   Lighting     a Configuration whose attributes are Lighting properties (MapService applies them when the map
--                loads and puts the place's own lighting back afterwards)
--   LightingFx   Sky, Atmosphere, Bloom, ColorCorrection, SunRays for the map
--   Art.Lighting the sunbeam rig in the shaft (two camera-facing Beams, the Lobby's textures), a warm bounce off the
--                sunlit dais, shaft dust, and 16 shadowless focal lights (8 per half)
-- Sun: GeographicLatitude 23.5 with ClockTime 12 puts the sun at the zenith (the Lobby uses 33.5 for a 10° lean),
-- so the beam falls straight down the 24-wide shaft onto the dais, the same for both teams. Every roof casts
-- shadow, so only the sunwell's middle is sunlit. Phones below graphics quality 4 have no shadows: the sun then
-- lights the map evenly and the lanes read by value (light sunwell floor, dark corridor floors, painted lower walls).
-- Re-runnable. It sets no Lighting properties directly: press Play (or load the map) to see it.
-- Tip: Lighting.Technology should be Future (set by hand; scripts can't).

newMap("Bunker", CFrame.new(-1500, 200, 1500))
local map = root()

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local old = map:FindFirstChild("Lighting")
if old then
	old:Destroy()
end
local config = Instance.new("Configuration")
config.Name = "Lighting"
local PROPS: { [string]: any } = {
	ClockTime = 12,
	GeographicLatitude = 23.5,
	Brightness = 2.6,
	Ambient = Color3.fromRGB(92, 94, 104), -- the cool shade every room gets (bright enough to read players)
	OutdoorAmbient = Color3.fromRGB(128, 124, 118),
	ColorShift_Top = Color3.fromRGB(255, 236, 210),
	ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
	EnvironmentDiffuseScale = 0.2, -- the sky must not tint a sealed bunker
	EnvironmentSpecularScale = 0.2,
	ExposureCompensation = 0.1,
	GlobalShadows = true,
	ShadowSoftness = 0.15,
}
local nProps = 0
for k, v in PROPS do
	config:SetAttribute(k, v)
	nProps += 1
end
config.Parent = map

local oldFx = map:FindFirstChild("LightingFx")
if oldFx then
	oldFx:Destroy()
end
local fx = Instance.new("Folder")
fx.Name = "LightingFx"
fx.Parent = map

local sky = Instance.new("Sky")
sky.Name = "BunkerSky"
sky.SunAngularSize = 12
sky.StarCount = 0
sky.CelestialBodiesShown = true
sky.Parent = fx

local atmo = Instance.new("Atmosphere")
atmo.Density = 0.3 -- a light dusty haze: depth in the sunwell, the beam reads
atmo.Offset = 0
atmo.Color = hex("C9C0B2")
atmo.Decay = hex("6E6A64")
atmo.Glare = 0
atmo.Haze = 1.0
atmo.Parent = fx

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 24
bloom.Threshold = 1.6 -- the coves, screens and lamps glow; sunlit concrete does not
bloom.Parent = fx

local grade = Instance.new("ColorCorrectionEffect")
grade.Contrast = 0.08
grade.Saturation = -0.04
grade.Brightness = 0
grade.TintColor = Color3.fromRGB(255, 250, 243)
grade.Parent = fx

local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.06 -- only when you look up the shaft
rays.Spread = 0.5
rays.Parent = fx

-- Local light rig.
local folder = section("Art", "Lighting")
local SUN = hex("FFE2B8")
local COOL = hex("DDE8F2")
local WARM = hex("FFD9A8")
local IMG_SUNBEAM = "rbxassetid://122394313975001" -- the Lobby's beam and dust textures (Lighting.luau there)
local IMG_MOTE = "rbxassetid://139664604115042"
local count = 0

local function anchor(name: string, x: number, y: number, z: number, size: Vector3?): BasePart
	local a = box(folder, name, size or Vector3.new(0.2, 0.2, 0.2), at(x, y, z), COOL, {
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

-- The sunbeam: two nested camera-facing ribbons from just under the skylight to the dais.
local beamPart = anchor("SunBeam", 0, 32, 0)
local top = Instance.new("Attachment")
top.Name = "Top"
top.Parent = beamPart
top.WorldPosition = W(CFrame.new(0, 62.5, 0)).Position
local bottom = Instance.new("Attachment")
bottom.Name = "Floor"
bottom.Parent = beamPart
bottom.WorldPosition = W(CFrame.new(0, 0.6, 0)).Position
for _, spec in
	{
		{
			name = "Shaft",
			w = 22,
			t = { { 0, 1 }, { 0.08, 0.66 }, { 0.5, 0.76 }, { 0.85, 0.84 }, { 1, 0.95 } },
		},
		{
			name = "Core",
			w = 12,
			t = { { 0, 1 }, { 0.08, 0.6 }, { 0.5, 0.7 }, { 0.85, 0.8 }, { 1, 0.92 } },
		},
	}
do
	local b = Instance.new("Beam")
	b.Name = spec.name
	b.Attachment0 = top
	b.Attachment1 = bottom
	b.FaceCamera = true
	b.Texture = IMG_SUNBEAM
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.Width0 = spec.w
	b.Width1 = spec.w
	b.Segments = 10
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 1
	b.Color = ColorSequence.new(SUN)
	local keys = {}
	for _, k in spec.t do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	b.Transparency = NumberSequence.new(keys)
	b.Parent = beamPart
end

-- Dust drifting in the shaft (a few motes; client cost is tiny).
local dustBox = anchor("SunDust", 0, 22, 0, Vector3.new(20, 40, 20))
local dust = Instance.new("ParticleEmitter")
dust.Texture = IMG_MOTE
dust.Shape = Enum.ParticleEmitterShape.Box
dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
dust.Rate = 5
dust.Lifetime = NumberRange.new(8, 12)
dust.Speed = NumberRange.new(0.1, 0.4)
dust.SpreadAngle = Vector2.new(180, 180)
dust.Size = NumberSequence.new(0.18)
dust.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.45),
	NumberSequenceKeypoint.new(0.8, 0.45),
	NumberSequenceKeypoint.new(1, 1),
})
dust.LightEmission = 0.6
dust.Color = ColorSequence.new(SUN)
dust.Parent = dustBox

-- Bounce: Roblox has no GI, so a warm, shadowless SurfaceLight on the sunlit dais lights the plinth's sides, the
-- ring's underside and players' faces in the middle.
local bouncePart = anchor("SunBounce", 0, 0.65, 0, Vector3.new(16, 0.1, 16))
local bounce = Instance.new("SurfaceLight")
bounce.Face = Enum.NormalId.Top
bounce.Angle = 90
bounce.Range = 36
bounce.Brightness = 1.1
bounce.Color = SUN
bounce.Shadows = false
bounce.Parent = bouncePart
count += 1

-- Focal lights, all shadowless: team B's half and the east pump; team A's half is their 180° turn.
for _, s in { 1, -1 } do
	point("CorridorEast", s * 36, 9, s * 34, COOL, 24, 0.9)
	point("CorridorWest", -s * 36, 9, s * 34, COOL, 24, 0.9)
	point("Lockers", s * 22, 9, s * 36, COOL, 22, 0.9)
	point("Control", -s * 22, 9, s * 36, COOL, 22, 0.9)
	point("Vestibule", 0, 9, s * 60, COOL, 30, 0.9)
	point("Spawn", 0, 9, s * 84, COOL, 28, 1.0)
	point("Gallery", 0, 20, s * 42, WARM, 30, 0.8)
	point("Pump", s * 28, 9, 0, WARM, 22, 1.0)
end

report(
	string.format(
		"Bunker lighting: Lighting config (%d props), LightingFx (5), sunbeam + dust, %d shadowless lights",
		nProps,
		count
	)
)
