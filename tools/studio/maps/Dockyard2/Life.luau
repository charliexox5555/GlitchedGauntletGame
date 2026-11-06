--!strict
-- Dockyard2 map life (2026-11-05, lane F). Run in Studio (edit mode, the
-- match place) through the command bar or MCP; it rebuilds the "Life" folder
-- in Workspace.Dockyard2 and tags what Controllers/MapLifeController moves
-- (Config/MapLife lists the tags and attributes). Save the place after.
--
-- It builds (all anchored, CanCollide / CanQuery / CanTouch false, no shadow):
--   * Gulls: 6 circling in pairs 42-46 studs above the deck (a pair round the
--     crane, two over the water channels), far above every sightline, and 4
--     perched on quay bollards that take off, calling, when someone nears.
--   * Water: sparkle glints on the water outside the quay walls, and foam
--     strips breathing at the foot of the quay walls (below deck level).
--   * A flag on the crane house and a windsock on the crane girder, 56+
--     studs up.
--   * Two far container ships crossing beyond the far quays, 620 studs out.
-- Lane G's Art is never edited: LifeRules in Life/Rules name the parts that
-- move (the crane's spreader and rigging sway together about the trolley,
-- the two Skyline ships rock), so a rebuild of the Art keeps them moving.
-- Positions are local to the map origin (-3000, 200, 0); the deck is
-- 136 x 236 (x -68..68, z -118..118), the water top y -9.1.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ORIGIN = Vector3.new(-3000, 200, 0)
local SPARKLE = "rbxassetid://131441026395130" -- Config/VfxTextures MOD_SPARKLE

local map = Workspace:FindFirstChild("Dockyard2")
assert(map, "Workspace.Dockyard2 not found (run in the match place)")
local old = map:FindFirstChild("Life")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Life"

local function W(x: number, y: number, z: number): Vector3
	return ORIGIN + Vector3.new(x, y, z)
end

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

local function model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent or folder
	return m
end

-- Gulls ------------------------------------------------------------------------

local WHITE = Color3.fromRGB(242, 242, 238)
local WING = Color3.fromRGB(196, 202, 210)
local TIP = Color3.fromRGB(44, 46, 52)
local BEAK = Color3.fromRGB(236, 184, 52)

-- 1.5x a real gull (span about 7.5 studs), so it reads against the sky at
-- the 60-120 studs players see it from.
local function gull(name: string, at: Vector3, scale: number?, facing: Vector3?): Model
	local K = scale or 1.5
	local m = model(name)
	local cf = if facing then CFrame.lookAt(at, at + facing) else CFrame.new(at)
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * K
	end
	local function o(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x * K, y * K, z * K)
	end
	local body = part(m, "Body", v(0.7, 0.6, 1.9), cf, WHITE, "ball")
	part(m, "Head", v(0.46, 0.46, 0.5), o(0, 0.18, -0.95), WHITE, "ball")
	part(m, "Beak", v(0.12, 0.12, 0.34), o(0, 0.14, -1.28), BEAK)
	part(m, "Tail", v(0.5, 0.06, 0.5), o(0, 0.05, 1.05), WHITE)
	for _, side in { -1, 1 } do
		local n = if side < 0 then "WingL" else "WingR"
		part(m, n, v(1.5, 0.08, 0.7), o(side * 0.95, 0.05, -0.05), WING)
		part(m, n .. "Tip", v(0.95, 0.07, 0.48), o(side * 2.2, 0.05, 0.02), TIP) -- clear of the wing
	end
	m.PrimaryPart = body
	m:SetAttribute("HingeX", 0.2 * K)
	return m
end

local GULLS = {
	-- { centre (local), radius, speed deg/s, phases }. All 40+ studs above the
	-- deck, far over every sightline: one pair rounds the crane, two work the
	-- water channels beside the Skyline ships.
	{ c = Vector3.new(0, 46, 10), r = 52, speed = 9, phases = { 0, 140 } },
	{ c = Vector3.new(100, 42, -82), r = 26, speed = -15, phases = { 40, 215 } },
	{ c = Vector3.new(-100, 44, 84), r = 28, speed = 14, phases = { 90, 260 } },
}
for gi, g in GULLS do
	for pi, phase in g.phases do
		local centre = ORIGIN + g.c
		-- Built at its own phase on the loop, so no two gulls overlap in edit
		-- mode (the controller takes over in play).
		local r = g.r + (pi - 1) * 4
		local a = math.rad(phase)
		local m = gull(
			string.format("Gull_%d%d", gi, pi),
			centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		)
		tag(m, "LifeGull", {
			Center = centre,
			Radius = g.r + (pi - 1) * 4,
			Speed = g.speed * (1 + (pi - 1) * 0.08),
			Phase = phase,
		})
	end
end

-- Gulls perched on the quay bollards (top local y 3.5), facing the deck. They
-- take off over the water, calling, when someone comes within 15 studs, and
-- fly back once nobody is near (the pigeon code with gull numbers). Real size:
-- a bird on a 1-stud bollard at the quay edge hides nobody.
local PERCHES = {
	{ at = Vector3.new(67, 3.5, -12), flee = Vector3.new(1, 0.25, -0.35) },
	{ at = Vector3.new(67, 3.5, 64), flee = Vector3.new(1, 0.25, 0.35) },
	{ at = Vector3.new(-67, 3.5, 44), flee = Vector3.new(-1, 0.25, 0.35) },
	{ at = Vector3.new(-67, 3.5, -64), flee = Vector3.new(-1, 0.25, -0.35) },
}
for i, perch in PERCHES do
	local inward = Vector3.new(-perch.flee.X, 0, 0)
	local m =
		gull(string.format("Perched_%d", i), ORIGIN + perch.at + Vector3.new(0, 0.42, 0), 1, inward)
	tag(m, "LifePigeon", {
		FleeDir = perch.flee.Unit,
		FlapHz = 3.2,
		FlapDeg = 50,
		Away = 130,
		Rise = 30,
		Sound = "atlas:AmbGulls",
		Volume = 0.5,
	})
end

-- Water: glints and foam ------------------------------------------------------

local function glints(name: string, at: Vector3, size: Vector3, rate: number)
	local p = part(folder, name, size, CFrame.new(at), WHITE)
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Glints"
	e.Texture = SPARKLE
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.35, 0.75)
	e.Speed = NumberRange.new(0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 3, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.15)
	e.LightEmission = 1
	e.Color = ColorSequence.new(Color3.fromRGB(255, 246, 224))
	e.Rotation = NumberRange.new(0, 90)
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Enabled = false
	e.Parent = p
	tag(e, "LifeEmitter", { Range = 170 })
end
-- The water top is local y -9.1; the channels between the quay walls (x +-68)
-- and the Skyline ships (inner hull edge x +-92) are 24 studs wide; the ends
-- are open water.
glints("Glints_E", W(80, -8.95, 0), Vector3.new(20, 0.2, 230), 14)
glints("Glints_W", W(-80, -8.95, 0), Vector3.new(20, 0.2, 230), 14)
glints("Glints_N", W(0, -8.95, 142), Vector3.new(150, 0.2, 40), 16)
glints("Glints_S", W(0, -8.95, -142), Vector3.new(150, 0.2, 40), 16)

local FOAM = Color3.fromRGB(236, 244, 246)
local function foam(name: string, cf: CFrame, length: number, i: number)
	local p = part(folder, name, Vector3.new(1.3, 0.12, length), cf, FOAM)
	p.Transparency = 0.5
	tag(
		p,
		"LifePulse",
		{ PulseMin = 0.15, PulseMax = 0.7, PulseHz = 0.16 + (i % 3) * 0.03, Phase = i * 67 }
	)
end
local n = 0
for _, side in { -1, 1 } do
	for k = 0, 7 do
		n += 1
		local z = -103.25 + k * 29.5
		foam(string.format("Foam_%02d", n), CFrame.new(W(side * 68.95, -9.05, z)), 29.4, n)
	end
end
for _, side in { -1, 1 } do
	for k = 0, 3 do
		n += 1
		local x = -51 + k * 34
		foam(
			string.format("Foam_%02d", n),
			CFrame.new(W(x, -9.05, side * 119.9)) * CFrame.Angles(0, math.pi / 2, 0),
			33.9,
			n
		)
	end
end

-- Flag and windsock on the crane ------------------------------------------------

local POLE = Color3.fromRGB(70, 72, 78)
local statics = Instance.new("Folder")
statics.Name = "Poles"
statics.Parent = folder

-- Flag on the crane house (house top about y 61.5).
local flagPole =
	part(statics, "FlagPole", Vector3.new(0.45, 9, 0.45), CFrame.new(W(0, 65.9, 4)), POLE)
local poleTop = flagPole.Position + Vector3.new(0, 4.1, 0)
local flag = model("Flag")
local NAVY = Color3.fromRGB(32, 58, 120)
part(flag, "Cloth", Vector3.new(8, 5, 0.08), CFrame.new(poleTop + Vector3.new(4.2, -2.5, 0)), NAVY)
part(
	flag,
	"Band",
	Vector3.new(8.04, 1, 0.2), -- 0.06 proud of the cloth on both faces
	CFrame.new(poleTop + Vector3.new(4.2, -2.5, 0)),
	Color3.fromRGB(240, 196, 40)
)
tag(flag, "LifeSway", {
	Pivot = poleTop,
	SwayAxis = Vector3.yAxis,
	SwayDeg = 14,
	SwayHz = 0.42,
	Sway2Axis = Vector3.xAxis,
	Sway2Deg = 7,
})

-- Windsock: lane G's Art (Codex's modelled windsock on a mast with a base plate, on the north girder top;
-- the Parts windsock here floated between the girders). Its sock meshes sway by rule, below.

-- Far ships ------------------------------------------------------------------------

-- Built along z, then turned to cross along x beyond the ends of the far
-- quays (z +-500), so the quays' stacks never hide them.
local function farShip(name: string, z: number, from: number, to: number, speed: number)
	local m = model(name)
	local at = W(from, -6, z)
	local hull = Color3.fromRGB(96, 40, 36)
	m.PrimaryPart = part(m, "Hull", Vector3.new(14, 6, 76), CFrame.new(at), hull)
	part(
		m,
		"Deck",
		Vector3.new(14.2, 0.6, 76.2),
		CFrame.new(at + Vector3.new(0, 2.4, 0)),
		Color3.fromRGB(58, 60, 66)
	)
	part(
		m,
		"Bridge",
		Vector3.new(11, 9, 8),
		CFrame.new(at + Vector3.new(0, 7.3, 30)), -- sunk 0.2 into the hull
		Color3.fromRGB(236, 230, 214)
	)
	-- Blue, mustard, green (no team orange-red).
	local colours =
		{ Color3.fromRGB(46, 86, 150), Color3.fromRGB(214, 168, 62), Color3.fromRGB(70, 128, 84) }
	for k = 0, 2 do
		part(
			m,
			"Boxes" .. k,
			Vector3.new(12, 5, 16),
			CFrame.new(at + Vector3.new(0, 5.6, -22 + k * 17)),
			colours[k + 1]
		)
	end
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.pi / 2, 0))
	-- Twice the first build, so it reads as a ship (not a speck) at 620 studs.
	m:ScaleTo(2)
	m:PivotTo(m:GetPivot() - Vector3.new(0, 2, 0)) -- hull 12 tall, 7 above the water
	local y = m:GetPivot().Y
	tag(m, "LifeDrift", {
		From = Vector3.new(at.X, y, at.Z),
		To = Vector3.new(ORIGIN.X + to, y, at.Z),
		Speed = speed,
		Wake = 2500,
	})
end
farShip("FarShip_N", 620, 460, -460, 1.6)
farShip("FarShip_S", -640, -460, 460, 1.3)

-- Lane G's parts, by rule: the crane's load and the Skyline ships ----------------

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
local trolley = W(0, 57.3, 0)
local craneSway = {
	Pivot = trolley,
	SwayAxis = Vector3.xAxis,
	SwayDeg = 1.6,
	SwayHz = 0.11,
	Sway2Axis = Vector3.zAxis,
	Sway2Deg = 0.8,
	Phase = 30, -- the same phase, so the spreader and its cables swing together
}
rule("Sway", "Crane_Spreader", craneSway)
local sockSway = {
	Pivot = W(30.5, 66.4, 16), -- the mast head
	SwayAxis = Vector3.yAxis,
	SwayDeg = 14,
	SwayHz = 0.3,
	Sway2Axis = Vector3.zAxis,
	Sway2Deg = 4,
}
rule("Sway", "Windsock_SockSockOrange", sockSway)
rule("Sway", "Windsock_SockWhite", sockSway)
rule("Sway", "Crane_Rigging", craneSway)
rule("Sway", "Ship", {
	PivotY = ORIGIN.Y - 9.1, -- each ship rolls about its own waterline
	SwayAxis = Vector3.zAxis,
	SwayDeg = 1.1,
	SwayHz = 0.07,
	Sway2Axis = Vector3.xAxis,
	Sway2Deg = 0.4,
	Wake = 400,
})

folder.Parent = map
print(string.format("Dockyard2 life: %d instances built", #folder:GetDescendants()))
