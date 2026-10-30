--!strict
-- Lobby lighting and atmosphere (phase 1 step 6). Stand-alone: run it as-is through the
-- Studio MCP (execute_luau) or the command bar; it is safe to re-run (it sets absolute
-- values and rebuilds Workspace.Lobby.Art.Lighting).
--
-- Owns: the Lighting service and its effects, and Workspace.Lobby.Art.Lighting (the fake
-- sunbeam rig, the rotunda bounce light and the ring cove washes). The dust in the shaft is
-- Ambience.Emitters.SunbeamDust (art-source/lobby/scripts/AmbienceSetup.luau). It also sets absolute brightness, range
-- and colour on a few lights the area agents placed (BALANCE below) so the wings sit
-- together; it never moves or deletes art.
--
-- Plan: vault/02 Art/Lobby Art Plan.md -> Lighting plan. The sun stays at ClockTime 12,
-- GeographicLatitude 33.5: direction (0, 0.985, 0.174), so the beam through the R16
-- oculus lands on the sun patch at (0, -10) and leans toward Duels.
--
-- Beam textures: tools/textures/make_lobby_beam.py -> art-source/lobby/textures/
-- Lobby_SunBeam.png (Decal 87067089378880) and Lobby_DustMote.png (Decal 138082655441656);
-- the ids below are the Image assets behind those Decals. A Beam maps its texture's X axis
-- across the width and Y along the length (tested), so the beam texture varies along X only.
--
-- Findings (Studio, 2026-10-29):
-- - Beam Transparency/Color sequences are sampled only at segment vertices: Segments = 1
--   shows just the two end keys. 10 segments keep the fade under the rim (key 0.1) and
--   are cheap; the polish pass cut 3 stacked beams at 24 segments to 2 at 10 (phone fill rate).
-- - The skybox drives EnvironmentDiffuse/Specular, and the clear blue sky turned every
--   polished floor navy. Indoors both scales stay low (diffuse 0, specular 0.15).

assert(game.PlaceId == 133387545285290, "not the Lobby")

local Lighting = game:GetService("Lighting")

local IMG_SUNBEAM = "rbxassetid://122394313975001"
local IMG_MOTE = "rbxassetid://139664604115042"

-- Clear-day gradient skybox (tools/textures/make_lobby_sky.py -> Lobby_Sky_*.png, Decals
-- Up 109801296619429, Dn 97901748112820, Ft 102517595534046, Bk 87199469264055,
-- Lf 123180123246122, Rt 137044830797265). The default sky read as a saturated navy disc
-- through the oculus; this one is a pale, soft blue (Turrell skyspace).
local SKY: { [string]: string } = {
	Up = "rbxassetid://78657641550449",
	Dn = "rbxassetid://131432477305820",
	Ft = "rbxassetid://71689582225265",
	Bk = "rbxassetid://106983362546025",
	Lf = "rbxassetid://72916886983879",
	Rt = "rbxassetid://86764828164208",
}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

-- Palette (tools/blender/lobbykit.py constants).
local L_SUN = hex("#FFE2B8")
local L_COVE = hex("#FFF1DC")
-- Ambient is lifted from the plan's #1E222A: under it every route off the sun patch went
-- black in Future. Still cool and low; the coves, Neon and light pools carry the mood.
local AMBIENT = hex("#44474F")
local OUTDOOR_AMBIENT = hex("#3A3F48")

local report: { string } = {}
local function note(s: string)
	table.insert(report, s)
end

--------------------------------------------------------------------------------
-- Lighting service
--------------------------------------------------------------------------------

-- Technology is not scriptable from plugin/command-bar security; try anyway.
local okTech, techErr = pcall(function()
	(Lighting :: any).Technology = Enum.Technology.Future
end)
note(
	okTech and "Technology = Future set"
		or ("Technology not scriptable: set it to Future by hand (" .. tostring(techErr) .. ")")
)

Lighting.ClockTime = 12
Lighting.GeographicLatitude = 33.5
Lighting.Brightness = 2
Lighting.Ambient = AMBIENT
Lighting.OutdoorAmbient = OUTDOOR_AMBIENT
Lighting.ColorShift_Top = hex("#FFE9CC")
Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0.15
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.12
Lighting.ExposureCompensation = 0
Lighting.FogStart = 0
Lighting.FogEnd = 100000

local function effect<T>(className: string, name: string): T
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName ~= className then
		found:Destroy()
		found = nil
	end
	if not found then
		local made = Instance.new(className :: any)
		made.Name = name
		made.Parent = Lighting
		found = made
	end
	return (found :: any) :: T
end

-- Sky: a clear day seen through the oculus and the Armoury lantern.
local sky = effect("Sky", "Sky") :: Sky
for face, id in SKY do
	(sky :: any)["Skybox" .. face] = id
end
sky.CelestialBodiesShown = true
sky.SunAngularSize = 9
sky.StarCount = 0

local atmo = effect("Atmosphere", "Atmosphere") :: Atmosphere
atmo.Density = 0.3
atmo.Offset = 0.1
atmo.Color = hex("#4A4D54")
atmo.Decay = hex("#2C3038")
atmo.Glare = 0
atmo.Haze = 1.0

local bloom = effect("BloomEffect", "Bloom") :: BloomEffect
bloom.Enabled = true
bloom.Threshold = 1.3
bloom.Intensity = 0.7
bloom.Size = 28

local cc = effect("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
cc.Enabled = true
cc.Brightness = 0
cc.Contrast = 0.08
cc.Saturation = -0.08
cc.TintColor = hex("#FFFAF3")

local rays = effect("SunRaysEffect", "SunRays") :: SunRaysEffect
rays.Enabled = true
rays.Intensity = 0.04
rays.Spread = 0.5

local dof = effect("DepthOfFieldEffect", "DepthOfField") :: DepthOfFieldEffect
dof.Enabled = false

--------------------------------------------------------------------------------
-- Workspace.Lobby.Art.Lighting: sunbeam rig, dust, bounce light
--------------------------------------------------------------------------------

local lobby = workspace:WaitForChild("Lobby")
local art = lobby:FindFirstChild("Art")
if not art then
	local f = Instance.new("Folder")
	f.Name = "Art"
	f.Parent = lobby
	art = f
end
local old = (art :: Instance):FindFirstChild("Lighting")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Lighting"

local function lightPart(parent: Instance, name: string, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Sun direction from the sky to the floor (downward), from the live sun vector.
local sunUp = Lighting:GetSunDirection()
local down = -sunUp
local TOP_Y = 58 -- inside the oculus shaft (rim y 54, open sky y 60)
local FLOOR_Y = 0.25
local top = Vector3.new(0, TOP_Y, 0)
local t = (FLOOR_Y - TOP_Y) / down.Y
local bottom = top + down * t

local rig = Instance.new("Model")
rig.Name = "SunShaft"
rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
rig.Parent = root

local anchor = lightPart(rig, "BeamAnchor", CFrame.new((top + bottom) / 2), Vector3.new(1, 1, 1))
rig.PrimaryPart = anchor
local a0 = Instance.new("Attachment")
a0.Name = "Top"
a0.Parent = anchor
a0.WorldPosition = top
local a1 = Instance.new("Attachment")
a1.Name = "Floor"
a1.Parent = anchor
a1.WorldPosition = bottom

type BeamSpec = {
	name: string,
	w0: number,
	w1: number,
	t: { { number } },
}

-- Two nested camera-facing ribbons: the shaft (with the old halo folded in) and a brighter core.
-- Transparency runs along the beam (0 = oculus, 1 = floor): brightest just under the rim,
-- thinning toward the floor so the spawn view to DUELS stays clear.
local BEAMS: { BeamSpec } = {
	{
		name = "Shaft",
		w0 = 40,
		w1 = 42,
		t = { { 0, 1 }, { 0.1, 0.62 }, { 0.4, 0.72 }, { 0.8, 0.8 }, { 1, 0.9 } },
	},
	{
		name = "Core",
		w0 = 18,
		w1 = 20,
		t = { { 0, 1 }, { 0.1, 0.58 }, { 0.4, 0.68 }, { 0.8, 0.76 }, { 1, 0.85 } },
	},
}

for _, spec in BEAMS do
	local b = Instance.new("Beam")
	b.Name = spec.name
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.Texture = IMG_SUNBEAM
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.Width0 = spec.w0
	b.Width1 = spec.w1
	b.Segments = 10
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 1
	b.Color = ColorSequence.new(L_SUN)
	local keys = {}
	for _, k in spec.t do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	b.Transparency = NumberSequence.new(keys)
	b.Parent = anchor
end

-- Rotunda bounce: Roblox has no GI, so the sunlit patch would not warm the room. A warm,
-- shadowless up-facing SurfaceLight on the patch fakes the bounce onto the columns, the
-- dome coffers (Range 60 reaches them; without it the dome was black) and players' faces.
local bouncePart =
	lightPart(root, "SunBounce", CFrame.new(bottom.X, 0.1, bottom.Z), Vector3.new(20, 0.2, 20))
local bounce = Instance.new("SurfaceLight")
bounce.Name = "Bounce"
bounce.Face = Enum.NormalId.Top
bounce.Angle = 90
bounce.Range = 60
bounce.Brightness = 1.2
bounce.Color = L_SUN
bounce.Shadows = false
bounce.Parent = bouncePart

-- Ring cove: the neutral warm ring between the wings. Neon coves glow but light nothing, so
-- the ring went black between the portal soffit lights. Four shadowless warm washes on the
-- diagonals (between portals, over the seating alcoves), high under the ring ceiling.
local cove = Instance.new("Folder")
cove.Name = "RingCove"
cove.Parent = root
for i = 0, 3 do
	local bearing = 45 + 90 * i
	local b = math.rad(bearing)
	local p = lightPart(
		cove,
		"RingWash_" .. bearing,
		CFrame.new(math.sin(b) * 58, 15, -math.cos(b) * 58),
		Vector3.new(1, 1, 1)
	)
	local l = Instance.new("PointLight")
	l.Name = "Wash"
	l.Range = 32
	l.Brightness = 1.3
	l.Color = L_COVE
	l.Shadows = false
	l.Parent = p
end

root.Parent = art

--------------------------------------------------------------------------------
-- Balance: absolute values for lights the area agents placed (paths under Workspace.Lobby.Art,
-- "/"-separated because some names contain dots). Missing entries are reported, not created.
--------------------------------------------------------------------------------

type Balance = {
	brightness: number?,
	range: number?,
	color: string?,
	shadows: boolean?,
	enabled: boolean?,
}
local BALANCE: { [string]: Balance } = {
	-- Range Lobby: cool daylight, brighter than the hub. The gate end of the hall was black.
	-- (The Market, Weapons and real-range lights are now tuned in their own Art_* scripts.)
	["Range/Lights/FacadeWash/SurfaceLight"] = { brightness = 1.4, range = 40 },
	["Range/Lights/GateGlow/PointLight"] = { brightness = 1.6, range = 26 },
}

for path, b in BALANCE do
	local inst: Instance? = art :: Instance
	for part in string.gmatch(path, "[^/]+") do
		inst = inst and inst:FindFirstChild(part)
	end
	if inst and inst:IsA("Light") then
		local l = inst :: Light
		if b.brightness then
			l.Brightness = b.brightness
		end
		if b.range then
			(l :: any).Range = b.range
		end
		if b.color then
			l.Color = hex(b.color)
		end
		if b.shadows ~= nil then
			l.Shadows = b.shadows
		end
		if b.enabled ~= nil then
			l.Enabled = b.enabled
		end
	else
		note("balance: missing " .. path)
	end
end

--------------------------------------------------------------------------------
-- Report: dynamic light budget for the whole lobby
--------------------------------------------------------------------------------

local total, enabled, shadowed = 0, 0, 0
local perArea: { [string]: number } = {}
for _, d in lobby:GetDescendants() do
	if d:IsA("Light") then
		total += 1
		if d.Enabled then
			enabled += 1
			if d.Shadows then
				shadowed += 1
				note("shadow light: " .. d:GetFullName())
			end
			local area = string.match(d:GetFullName(), "^Workspace%.Lobby%.Art%.([^%.]+)")
				or "other"
			perArea[area] = (perArea[area] or 0) + 1
		end
	end
end
for area, n in perArea do
	note(string.format("lights %s: %d", area, n))
end
note(
	string.format(
		"dynamic lights: %d enabled (%d total), %d with shadows",
		enabled,
		total,
		shadowed
	)
)
note("sun direction " .. tostring(sunUp) .. ", beam floor hit " .. tostring(bottom))

return table.concat(report, "\n")
