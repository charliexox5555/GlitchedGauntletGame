--!strict
-- Rooftops2 map life (2026-11-05, lane F). Run in Studio (edit mode, the
-- match place) through the command bar or MCP; it rebuilds the "Life" folder
-- in Workspace.Rooftops2 and tags what Controllers/MapLifeController moves
-- (Config/MapLife lists the tags and attributes). Save the place after.
--
-- It builds (all anchored, CanCollide / CanQuery / CanTouch false, no shadow):
--   * Steam: thin wisps from the four roof flues and the two lift-house vents,
--     starting above head height and drifting downwind (+X).
--   * Pigeons (off: BIRDS = false below): three flocks of three, on the
--     tank-house cornices and the east roof sign. They take off when a
--     character comes within 15 studs, with a wing-flap sound, and fly back in
--     once nobody is near.
--   * Banners: two cloth banners on each outer street wall (east and west),
--     below the roof edge, swaying in the wind.
-- Lane G's Art is never edited: LifeRules in Life/Rules name the parts that
-- move (the cooling-tower and condenser fans turn, the roof-sign neon and
-- one billboard lamp flicker now and then), so a rebuild keeps them moving.
-- World positions; the map origin is (3000, 200, 0), roofs at y 200, the Pit
-- at y 192, the outer street walls at x 2952 and 3048.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SMOKE = "rbxassetid://78112081932784" -- Config/VfxTextures MOLLY_SMOKE_2x2 (greyscale puff, 2x2 flipbook)

local map = Workspace:FindFirstChild("Rooftops2")
assert(map, "Workspace.Rooftops2 not found (run in the match place)")
local old = map:FindFirstChild("Life")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Life"

local function tag(inst: Instance, name: string, attrs: { [string]: any })
	for k, v in attrs do
		inst:SetAttribute(k, v)
	end
	CollectionService:AddTag(inst, name)
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: string?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if shape == "ball" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	elseif shape == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = parent
	return p
end

local function model(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = folder
	return m
end

-- Steam ------------------------------------------------------------------------

local function steam(name: string, at: Vector3, rate: number)
	local p = part(folder, name, Vector3.new(2.4, 0.2, 2.4), CFrame.new(at), Color3.new(1, 1, 1))
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Steam"
	e.Texture = SMOKE
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Rate = rate
	e.Lifetime = NumberRange.new(2.6, 3.6)
	e.Speed = NumberRange.new(2.2, 3)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Acceleration = Vector3.new(1.3, 0.3, 0.3)
	e.Drag = 0.6
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), -- narrow until it has risen
		NumberSequenceKeypoint.new(0.3, 3.6), -- fat mid-life, so it reads at 80 studs
		NumberSequenceKeypoint.new(1, 7.5),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.12),
		NumberSequenceKeypoint.new(0.5, 0.42),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- A cool grey-lilac: reads against the warm, pale evening sky (white sank into
	-- it) without the golden light turning it brown.
	e.Color = ColorSequence.new(Color3.fromRGB(200, 204, 214))
	e.LightEmission = 0
	e.LightInfluence = 0.3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Enabled = false
	e.Parent = p
	tag(e, "LifeEmitter", { Range = 140 })
end
-- Flue tops at y 208.4, lift-house vent tops at y 211.2: the steam starts
-- 3.6 / 5.5 studs above them, 7+ studs over a standing head (about 205),
-- and stays narrow (0.8 -> 2.8) for its first second.
steam("Steam_Flue1", Vector3.new(3024, 212, 21), 4.5)
steam("Steam_Flue2", Vector3.new(2976, 212, 21), 4.5)
steam("Steam_Flue3", Vector3.new(2976, 212, -21), 4.5)
steam("Steam_Flue4", Vector3.new(3024, 212, -21), 4.5)
steam("Steam_Lift1", Vector3.new(3030, 216.7, 50), 3.4)
steam("Steam_Lift2", Vector3.new(2970, 216.7, -50), 3.4)

-- Pigeons ----------------------------------------------------------------------

local BODY = Color3.fromRGB(126, 130, 146)
local HEAD = Color3.fromRGB(84, 90, 106)
local WING = Color3.fromRGB(152, 157, 172)
local BAR = Color3.fromRGB(58, 60, 70)

local BELLY = Color3.fromRGB(198, 200, 208)

-- 1.8x a real pigeon (about 1.5 studs long), so a flock reads at the 15-40
-- studs players see it from; a pale belly lifts it off the shaded cornice.
local P = 1.8
local function pigeonModel(name: string, at: Vector3, facing: Vector3, scale: number?): Model
	local P = scale or P
	local m = model(name)
	local cf = CFrame.lookAt(at, at + facing)
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * P
	end
	local function o(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x * P, y * P, z * P)
	end
	local body = part(m, "Body", v(0.46, 0.42, 0.82), cf, BODY, "ball")
	part(m, "Belly", v(0.36, 0.28, 0.6), o(0, -0.08, 0.02), BELLY, "ball")
	part(m, "Head", v(0.27, 0.27, 0.29), o(0, 0.27, -0.36), HEAD, "ball")
	part(m, "HeadBeak", v(0.06, 0.06, 0.13), o(0, 0.25, -0.54), BAR)
	part(m, "Tail", v(0.26, 0.05, 0.32), o(0, 0.04, 0.52), BAR)
	for _, side in { -1, 1 } do
		local n = if side < 0 then "WingL" else "WingR"
		part(m, n, v(0.62, 0.05, 0.4), o(side * 0.46, 0.1, 0.02), WING)
		-- The bar sits proud of the wing (no coplanar faces: z-fighting).
		part(m, n .. "Bar", v(0.5, 0.05, 0.08), o(side * 0.46, 0.14, 0.14), BAR)
	end
	m.PrimaryPart = body
	m:SetAttribute("HingeX", 0.15 * P)
	return m
end
local function pigeon(name: string, top: Vector3, facing: Vector3, flee: Vector3)
	local m = pigeonModel(name, top + Vector3.new(0, 0.29 * P, 0), facing)
	tag(m, "LifePigeon", { FleeDir = flee.Unit })
end

-- Off since 2026-11-05: the user called these block birds "blocky and bad", so
-- lane G moved them to ServerStorage.MapBackups.Rooftops2_Pigeons. Turn back on
-- only with a modelled bird (spec: vault/01 Design/Maps/Dockyard2.md, Concept
-- pass, Birds) in place of pigeonModel.
local BIRDS = false
if BIRDS then
	-- East tank house: the cornice's west edge (top y 207.97), facing the roof.
	for k, z in { 70.6, 73.2, 76.1 } do
		pigeon(
			"Pigeon_E" .. k,
			Vector3.new(3036.7, 207.97, z),
			Vector3.new(-1, 0, (k - 2) * 0.4),
			Vector3.new(1, 0.1, 0.5 + k * 0.15)
		)
	end
	-- West tank house: the cornice's east edge.
	for k, z in { -70.8, -73.4, -76.0 } do
		pigeon(
			"Pigeon_W" .. k,
			Vector3.new(2963.3, 207.97, z),
			Vector3.new(1, 0, (2 - k) * 0.4),
			Vector3.new(-1, 0.1, -0.5 - k * 0.15)
		)
	end
	-- East roof sign: along its top (y 231.25).
	for k, z in { -4.2, -0.4, 3.6 } do
		pigeon(
			"Pigeon_S" .. k,
			Vector3.new(3038, 231.25, z),
			Vector3.new(if k == 2 then 1 else -1, 0, 0.2),
			Vector3.new(1, 0.25, (k - 2) * 0.7)
		)
	end

	-- A small flock circling over the block, 28-32 studs above the roofs (far
	-- over every sightline), so the sky moves too; flap-and-glide like the gulls.
	for k, phase in { 0, 22, 47 } do
		local centre = Vector3.new(3000, 230 + k, 6)
		local m = pigeonModel("SkyPigeon_" .. k, centre + Vector3.new(34, 0, 0), Vector3.zAxis, 2.3)
		tag(m, "LifeGull", {
			Center = centre,
			Radius = 34 + k * 2,
			Speed = 20,
			Phase = phase,
			FlapHz = 5,
			FlapDeg = 50,
		})
	end
end

-- Banners on the outer street walls ------------------------------------------------

-- Sage and the map's one cobalt accent (team cyan and orange-red stay off the map).
local CLOTHS = { Color3.fromRGB(150, 172, 136), Color3.fromRGB(47, 98, 200) } -- sage, the tank cobalt
local ROD = Color3.fromRGB(58, 56, 54)
-- Blade banners: an arm out from the wall with the cloth hanging under it,
-- square to the wall, so it reads face-on from the roofs along the street.
local function banner(name: string, x: number, z: number, out: number, colour: Color3)
	local m = model(name)
	local top = Vector3.new(x + out * 1.6, 197, z)
	part(
		folder,
		name .. "_Arm",
		Vector3.new(3, 0.18, 0.18),
		CFrame.new(Vector3.new(x + out * 1.5, 197.1, z)),
		ROD
	)
	part(m, "Cloth", Vector3.new(2.6, 6, 0.06), CFrame.new(top + Vector3.new(0, -3.1, 0)), colour)
	part(
		m,
		"Stripe",
		Vector3.new(2.64, 0.5, 0.18), -- 0.06 proud of the cloth on both faces
		CFrame.new(top + Vector3.new(0, -5.3, 0)),
		Color3.fromRGB(240, 226, 196)
	)
	tag(m, "LifeSway", {
		Pivot = top,
		SwayAxis = Vector3.xAxis, -- swings along the wall, about the arm
		SwayDeg = 4.5,
		SwayHz = 0.24,
		Sway2Axis = Vector3.yAxis,
		Sway2Deg = 4,
	})
end
banner("Banner_E1", 3048.4, -34, 1, CLOTHS[1])
banner("Banner_E2", 3048.4, 30, 1, CLOTHS[2])
banner("Banner_W1", 2951.6, -30, -1, CLOTHS[2])
banner("Banner_W2", 2951.6, 34, -1, CLOTHS[1])

-- Lane G's parts, by rule: fans, the roof-sign neon, a billboard lamp ------------

local rulesFolder = Instance.new("Folder")
rulesFolder.Name = "Rules"
rulesFolder.Parent = folder
-- A LifeRule: the controller moves every part or model of this map named
-- `target` (never written to; see Config/MapLife).
local function rule(kind: string, target: string, attrs: { [string]: any })
	local r = Instance.new("Configuration")
	r.Name = kind .. "_" .. target
	r:SetAttribute("Kind", kind)
	r:SetAttribute("Target", target)
	tag(r, "LifeRule", attrs)
	r.Parent = rulesFolder
end
rule("Spin", "CoolingTower_Fan", { SpinSpeed = 140 })

-- Fan blades over the AC and condenser discs (their own meshes are plain
-- domes, so turning them shows nothing): a light four-blade cross, copied
-- onto each disc by the controller (Rotor rule) and spun there.
local BLADE = Color3.fromRGB(150, 154, 160)
local rotor = Instance.new("Model")
rotor.Name = "RotorTemplate"
-- Parked far under the map; the controller only ever uses copies.
local hub = CFrame.new(3000, -300, 0)
rotor.PrimaryPart = part(rotor, "BladeA", Vector3.new(2.3, 0.06, 0.34), hub, BLADE)
part(rotor, "BladeB", Vector3.new(0.34, 0.16, 2.3), hub, BLADE) -- 0.05 proud of A
-- A faint disc under the blades reads as their motion blur.
local blur = part(
	rotor,
	"Blur",
	Vector3.new(0.03, 2.4, 2.4),
	hub * CFrame.new(0, -0.09, 0) * CFrame.Angles(0, 0, math.pi / 2),
	BLADE,
	"cylinder"
)
blur.Color = Color3.fromRGB(96, 100, 108)
blur.Transparency = 0.55
for _, b in rotor:GetChildren() do
	if b:IsA("BasePart") and string.sub(b.Name, 1, 5) == "Blade" then
		b.Transparency = 0.45 -- soft, so a head peeking over the unit reads first
	end
end
part(rotor, "Hub", Vector3.new(0.5, 0.3, 0.5), hub, Color3.fromRGB(70, 72, 78))
rotor.Parent = folder
rule("Rotor", "ACUnit_Fans", {
	Template = "RotorTemplate",
	Offset1 = Vector3.new(-1.62, 0.22, 0),
	Offset2 = Vector3.new(1.62, 0.22, 0),
	SpinSpeed = 300,
	SpinJitter = 0.15,
	SpinWander = 0.2,
})
rule("Rotor", "Condenser_Fan", {
	Template = "RotorTemplate",
	Offset1 = Vector3.new(0, 0.22, 0),
	SpinSpeed = 340,
	SpinJitter = 0.1,
	SpinWander = 0.2,
})
rule("Flicker", "RoofSign_Neon_Glow", { FlickerTo = 0.85, FlickerGap = Vector2.new(5, 14) })
rule(
	"Flicker",
	"Billboard22_LampGlow_Glow",
	{ Only = 1, FlickerTo = 0.9, FlickerGap = Vector2.new(8, 20) }
)

folder.Parent = map
print(string.format("Rooftops2 life: %d instances built", #folder:GetDescendants()))
