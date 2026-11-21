--!nocheck
-- Lobby V5 RANGE V4 (vault/02 Art/Lobby V5 Plan.md, "Range v4"). Owner 2026-11-21 on v3:
-- * entrance: "not like a thing where you spawn in ... a bigger area and maybe like an indent in the wall ... when you
--   go back on it, it'll return you back to the lobby" -> the spawn deck goes; an alcove cut into the south wall, you
--   arrive in it and walk back into its gate to return (RangeSpawn / RangeExit);
-- * "the distance dummies ... copying rivals a bit too much ... just the colors" -> our colours: the lane runs a
--   teal-to-navy gradient, dummies wear teal (no RIVALS yellow);
-- * "put dummies around the map" -> ten in the yard; "2 dummies that are special": a DAMAGE dummy that never falls and
--   counts your damage up (board, tag RangeDamageDummy), and (our pick) a MOVING dummy on a rail for tracking
--   practice (tag RangeMovingDummy, From/To/Speed). Mechanics come with the merge; this is the build;
-- * loadout: "not a bin ... made in Blender ... professional" -> the loadout terminal (v5_rangekit.py), six around
--   the map (tag RangeLoadout);
-- * jump pad remade with no overlapping parts (v5_rangekit.py).
-- Mesh asset 132467899685396 (V5_RangeKit.fbx: JumpPad_<Role>, Terminal_<Role>). Needs V5Kit.LobbyKit + LobbyWay.

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local range = workspace.LobbyV5.Range
local shell, lanes, yard = range.Shell, range.Lanes, range.Yard
local RO = CFrame.new(0, 0, 2600)
local GRID = "rbxassetid://99198970022758"
local HAZARD = "rbxassetid://75158634706115"
local STRUCT, BLOCK, FLOOR = rgb(151, 153, 163), rgb(132, 134, 143), rgb(160, 162, 170)
local TEAL = K.AREA.range.col
local GUN = rgb(78, 80, 86)
local DARK = rgb(40, 42, 46)
local X, Z, H, FL = 130, 120, 45, 88

local function brick(parent, name, a, b, col, faces)
	local p = K.lpart(RO, parent, name, a, b, K.look(nil, col or STRUCT, Enum.Material.Plastic))
	for _, f in faces or Enum.NormalId:GetEnumItems() do
		local tx = K.texture(p, f, GRID, 5)
		tx.Color3 = Color3.new(0, 0, 0)
		tx.Transparency = 0.75
	end
	return p
end
local function paint(parent, name, a, b, col, mat)
	return K.lpart(RO, parent, name, a, b, K.look(nil, col, mat or Enum.Material.SmoothPlastic))
end
local function yawTo(dx, dz) -- rotation about Y that turns -Z (a prop's front) toward (dx, dz)
	return CFrame.Angles(0, math.atan2(-dx, -dz), 0)
end
local function gui(part, face, ppS)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS or 50
	g.LightInfluence = 0
	g.Brightness = 1.3
	g.Parent = part
	return g
end
local function text(g, t, font, col, y, h)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0.04, y)
	l.Size = UDim2.fromScale(0.92, h)
	l.FontFace = font
	l.Text = t
	l.TextColor3 = col
	l.TextScaled = true
	l.Parent = g
	return l
end

-- 0. the range kit: jump pad v2 and the loadout terminal ---------------------------------------------------------------
local LOOK = {
	Trim = { DARK, Enum.Material.SmoothPlastic },
	Body = { GUN, Enum.Material.Metal },
	Rubber = { rgb(28, 29, 32), Enum.Material.SmoothPlastic },
	Hardware = { rgb(150, 154, 160), Enum.Material.Metal },
	Accent = { K.dim(TEAL, 0.6), Enum.Material.Neon },
	Screen = { rgb(18, 20, 24), Enum.Material.SmoothPlastic },
}
for _, n in { "JumpPad", "Terminal" } do
	local o = SS.V5Kit:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end
local raw = InsertService:LoadAsset(132467899685396)
local kits = {}
for _, p in raw:GetDescendants() do
	if p:IsA("MeshPart") then
		local prop, role = string.match((string.gsub(p.Name, "%.%d+$", "")), "^(%a+)_(%a+)$") -- Blender may add .001
		if prop and role then
			local m = kits[prop]
			if not m then
				m = Instance.new("Model")
				m.Name = prop
				kits[prop] = m
			end
			p.Name = role
			p.Anchored, p.CanTouch = true, false
			p.CanCollide = role == "Body" or role == "Trim" or role == "Rubber"
			p.Color, p.Material = LOOK[role][1], LOOK[role][2]
			p.Parent = m
		end
	end
end
raw:Destroy()
for _, m in kits do
	local cf, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position - V(0, size.Y / 2, 0))
	m:PivotTo(CFrame.new())
	m.Parent = SS.V5Kit
end

-- 1. jump pads: the new model at each old pad, the trigger kept ------------------------------------------------------
for _, old in yard.JumpPads:GetChildren() do
	local piv, trig = old:GetPivot(), old:FindFirstChild("Trigger")
	local m = kits.JumpPad:Clone()
	m.Name = old.Name
	m:PivotTo(CFrame.new(piv.Position))
	if trig then
		trig.Parent = m
	end
	K.point(m.Accent, TEAL, 1.0, 12)
	old:Destroy()
	m.Parent = yard.JumpPads
end

-- 2. ENTRANCE: the deck goes; an alcove in the south wall with the way back to the lobby -------------------------------
local deck = range:FindFirstChild("SpawnDeck")
if deck then
	deck:Destroy()
end
for _, n in { "Wall_S", "Alcove" } do
	for _, c in shell:GetChildren() do
		if c.Name == n or c.Name == n .. "_Lintel" then
			c:Destroy()
		end
	end
end
local old = range:FindFirstChild("Alcove")
if old then
	old:Destroy()
end
brick(shell, "Wall_S", V(-X - 5, 0, Z), V(-20, H, Z + 5))
brick(shell, "Wall_S", V(20, 0, Z), V(X + 5, H, Z + 5))
brick(shell, "Wall_S_Lintel", V(-20, 20, Z), V(20, H, Z + 5))
local al = K.model(range, "Alcove")
local AZ1 = Z + 25 -- the alcove runs 25 deep into the wall's back
brick(al, "Floor", V(-25, -2, Z + 5), V(25, 0, AZ1 + 5), FLOOR, { Enum.NormalId.Top })
brick(al, "Side", V(-25, 0, Z + 5), V(-20, 20, AZ1))
brick(al, "Side", V(20, 0, Z + 5), V(25, 20, AZ1))
brick(al, "Back", V(-25, 0, AZ1), V(25, 22.5, AZ1 + 5))
local roof = brick(al, "Roof", V(-25, 20, Z + 5), V(25, 22.5, AZ1))
local wash = Instance.new("SurfaceLight")
wash.Face = Enum.NormalId.Bottom
wash.Angle = 120
wash.Range = 24
wash.Brightness = 1.4
wash.Color = rgb(226, 246, 240)
wash.Parent = roof
-- a frame round the mouth (gunmetal casing, inside the opening)
for _, s in { -1, 1 } do
	paint(
		al,
		"Casing",
		V(s > 0 and 19 or -20, 0, Z - 0.6),
		V(s > 0 and 20 or -19, 20, Z + 1),
		GUN,
		Enum.Material.Metal
	)
end
paint(al, "CasingHead", V(-20, 19, Z - 0.6), V(20, 20, Z + 1), GUN, Enum.Material.Metal)
local strip = paint(
	al,
	"MouthGlow",
	V(-18.5, 18.6, Z - 0.65),
	V(18.5, 18.8, Z - 0.55),
	K.dim(TEAL, 0.5),
	Enum.Material.Neon
)
strip.CanCollide = false
-- the gate on the alcove's back wall: frame, a teal field, a glow line on the floor, the trigger
local gate = K.model(al, "ExitGate")
for _, x in { -9, 8 } do
	paint(gate, "Post", V(x, 0, AZ1 - 1.2), V(x + 1, 14, AZ1), GUN, Enum.Material.Metal)
end
paint(gate, "Head", V(-9, 14, AZ1 - 1.2), V(9, 15.2, AZ1), GUN, Enum.Material.Metal)
local field = paint(
	gate,
	"Field",
	V(-8, 0.05, AZ1 - 0.6),
	V(8, 14, AZ1 - 0.4),
	TEAL,
	Enum.Material.ForceField
)
field.CanCollide = false
local line = paint(
	gate,
	"FloorGlow",
	V(-8, 0, AZ1 - 4.2),
	V(8, 0.06, AZ1 - 3.8),
	K.dim(TEAL, 0.5),
	Enum.Material.Neon
)
line.CanCollide = false
K.point(line, TEAL, 1.2, 16)
local trig = paint(gate, "Trigger", V(-8, 0, AZ1 - 5), V(8, 8, AZ1), TEAL)
trig.Transparency, trig.CanCollide, trig.CanQuery = 1, false, false
CS:AddTag(trig, "RangeExit")
local sign = paint(gate, "Sign", V(-6, 15.4, AZ1 - 0.9), V(6, 17.4, AZ1 - 0.7), rgb(22, 23, 27))
local sg = gui(sign, Enum.NormalId.Back, 60)
text(sg, "«  BACK TO THE LOBBY", K.RUBIK_H, TEAL, 0.18, 0.64)
-- arrivals: in the alcove, facing out into the range, well clear of the gate
for i, x in { -12, -4, 4, 12 } do
	local a = K.anchorPart(al, "Spawn" .. i, (RO * V(x, 3, Z + 8)) - K.O)
	a.CFrame = CFrame.lookAt(a.Position, a.Position + RO:VectorToWorldSpace(V(0, 0, -1)))
	CS:AddTag(a, "RangeSpawn")
end

-- 3. LOADOUT TERMINALS (six around the map) ---------------------------------------------------------------------------
local tm = range:FindFirstChild("Loadouts")
if tm then
	tm:Destroy()
end
tm = K.model(range, "Loadouts")
local icon = K.AREA.locker.icon
for i, t in
	{
		{ -30, 116.5, 0, -1 }, -- beside the alcove mouth
		{ 30, 116.5, 0, -1 },
		{ -118, -75, 0, 1 }, -- hangar front
		{ 26.2, -18, -1, 0 }, -- lookout, west face
		{ -98.6, 58, 1, 0 }, -- bunker, east face
		{ 64, 106, 1, 0 }, -- lane entrance
	}
do
	local m = kits.Terminal:Clone()
	m.Name = "Loadout" .. i
	m:PivotTo(RO * CFrame.new(t[1], 0, t[2]) * yawTo(t[3], t[4]))
	m.Parent = tm
	CS:AddTag(m.Body, "RangeLoadout")
	local g = gui(m.Screen, Enum.NormalId.Front, 60)
	local ic = Instance.new("ImageLabel")
	ic.BackgroundTransparency = 1
	ic.Image = icon
	ic.ImageColor3 = TEAL
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.fromScale(0.06, 0.5)
	ic.Size = UDim2.fromScale(0.6, 0.6)
	ic.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ic.Parent = g
	local l = text(g, "LOADOUT", K.RUBIK_H, rgb(236, 232, 222), 0.25, 0.5)
	l.Position = UDim2.fromScale(0.3, 0.25)
	l.Size = UDim2.fromScale(0.64, 0.5)
	l.TextXAlignment = Enum.TextXAlignment.Left
	K.point(m.Accent, TEAL, 0.5, 8)
end

-- 4. OUR COLOURS: lane bands teal -> navy, dummies in teal -------------------------------------------------------------
local GRAD = {
	rgb(110, 232, 200),
	rgb(64, 212, 186),
	rgb(36, 180, 170),
	rgb(28, 146, 156),
	rgb(30, 112, 140),
	rgb(34, 82, 120),
	rgb(36, 58, 98),
	rgb(32, 40, 72),
}
for _, b in lanes:GetChildren() do
	if b.Name == "Band" then
		local zTop = RO:PointToObjectSpace(b.Position).Z + b.Size.Z / 2
		local k = math.clamp(math.floor((FL - zTop) / 25 + 0.5) + 1, 1, #GRAD)
		b.Color = GRAD[k]
	elseif b.Name == "LaneSign" then
		local d = FL - RO:PointToObjectSpace(b.Position).Z
		local k = math.clamp(math.floor(d / 25 + 0.5), 1, #GRAD)
		local g = b:FindFirstChildWhichIsA("SurfaceGui")
		local bar = g and g:FindFirstChildWhichIsA("Frame")
		if bar then
			bar.BackgroundColor3 = GRAD[k]
		end
	end
end
local BOT =
	{ torso = rgb(32, 150, 126), limbs = rgb(52, 56, 64), head = rgb(226, 222, 212), ring = TEAL }
local function dress(pad, scheme)
	for _, d in pad:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Parent and d.Parent.Name == "Ring" then
				d.Color = scheme.ring
			elseif d.Name == "UpperTorso" or d.Name == "LowerTorso" then
				d.Color = scheme.torso
			elseif d.Name == "Head" then
				d.Color = scheme.head
			elseif
				string.find(d.Name, "Arm")
				or string.find(d.Name, "Hand")
				or string.find(d.Name, "Leg")
				or string.find(d.Name, "Foot")
			then
				d.Color = scheme.limbs
			end
		elseif d:IsA("BodyColors") then
			d.TorsoColor3 = scheme.torso
			d.HeadColor3 = scheme.head
			d.LeftArmColor3, d.RightArmColor3 = scheme.limbs, scheme.limbs
			d.LeftLegColor3, d.RightLegColor3 = scheme.limbs, scheme.limbs
		end
	end
end
for _, pad in lanes.Bots:GetChildren() do
	dress(pad, BOT)
end

-- 5. DUMMIES ROUND THE YARD ----------------------------------------------------------------------------------------------
local src = lanes.Bots:GetChildren()[1]
local yd = yard:FindFirstChild("Dummies")
if yd then
	yd:Destroy()
end
yd = K.model(yard, "Dummies")
local function dummy(parent, name, x, y, z, dx, dz)
	local m = src:Clone()
	m.Name = name
	local piv = src:GetPivot()
	local cf, size = src:GetBoundingBox()
	local lift = piv.Position.Y - (cf.Position.Y - size.Y / 2)
	-- the lane dummies face +z; turn that toward (dx, dz)
	local turn = CFrame.Angles(0, math.atan2(dx, dz), 0)
	m:PivotTo(CFrame.new((RO * V(x, y, z)) + V(0, lift, 0)) * turn * piv.Rotation)
	m.Parent = parent
	for _, b in m:GetDescendants() do
		if CS:HasTag(b, "RangeBot") then
			b:SetAttribute("Lane", "Yard")
			b:SetAttribute("Distance", nil)
		end
	end
	return m
end
for i, d in
	{
		{ -105, 25, -100, 0, 1 }, -- hangar roof
		{ 45, 25, -15, -1, 1 }, -- lookout roof
		{ -67.5, 40, -22.5, 0, 1 }, -- tower top
		{ -115, 15, 55, 1, 0 }, -- bunker roof
		{ -105, 0, -97, 0, 1 }, -- inside the hangar
		{ 10, 0, 49, 0, 1 }, -- in the south U-wall
		{ -27.5, 0, -40, 0, 1 }, -- in the long hall
		{ -100, 0, -33, 0, 1 }, -- behind a block
		{ 20, 0, -62, 0, 1 }, -- by the north U-wall
		{ -55, 0, 82, 0, 1 }, -- near the alcove
	}
do
	dummy(yd, "Dummy" .. i, d[1], d[2], d[3], d[4], d[5])
end

-- 6. SPECIAL DUMMIES ----------------------------------------------------------------------------------------------------
for _, n in { "DamageDummy", "MovingDummy" } do
	local o = yard:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end
-- 6a. DAMAGE dummy: never falls, counts your damage up. A stage, the dummy in the duels orange, a board behind
local dmg = K.model(yard, "DamageDummy")
local DC = V(-40, 0, 80)
local up = CFrame.Angles(0, 0, math.rad(90))
local DOR = rgb(255, 98, 72)
local function mesh(name, h, d, y, lk)
	return K.mesh(dmg, name, "V5_Pipe8", V(h, d, d), RO * CFrame.new(DC + V(0, y, 0)) * up, lk)
end
mesh("Stage", 0.8, 9, 0.4, K.L.dark)
mesh("Deck", 0.2, 8.2, 0.9, K.look(nil, GUN, Enum.Material.Metal))
local ring = mesh("Glow", 0.08, 9.4, 0.05, K.look(nil, K.dim(DOR, 0.5), Enum.Material.Neon))
ring.CanCollide = false
K.point(ring, DOR, 0.8, 10)
local bot = dummy(dmg, "Dummy", DC.X, 1.0, DC.Z, 0, 1)
dress(bot, { torso = DOR, limbs = rgb(40, 42, 48), head = rgb(226, 222, 212), ring = DOR })
for _, b in bot:GetDescendants() do
	if CS:HasTag(b, "RangeBot") then
		CS:RemoveTag(b, "RangeBot")
		CS:AddTag(b, "RangeDamageDummy")
		b:SetAttribute("Unkillable", true)
		b:SetAttribute("Lane", nil)
	end
end
for _, x in { -6.5, 5.5 } do
	paint(
		dmg,
		"Foot",
		DC + V(x - 0.3, 0, -7.1),
		DC + V(x + 1.3, 0.3, -5.5),
		DARK,
		Enum.Material.Metal
	)
	paint(dmg, "Post", DC + V(x, 0.3, -6.6), DC + V(x + 1, 12.6, -6.0), GUN, Enum.Material.Metal) -- behind the frame
end
paint(
	dmg,
	"BoardFrame",
	DC + V(-6.2, 6.4, -6.0),
	DC + V(6.2, 12.6, -5.6),
	DARK,
	Enum.Material.Metal
)
local board =
	paint(dmg, "Board", DC + V(-5.9, 6.7, -5.6), DC + V(5.9, 12.3, -5.55), rgb(20, 21, 25))
local bg = gui(board, Enum.NormalId.Back, 50)
text(bg, "DAMAGE", K.RUBIK_B, DOR, 0.06, 0.16)
local total = text(bg, "0", K.RUBIK_H, rgb(244, 240, 230), 0.22, 0.46)
total.Name = "Total"
local rate = text(bg, "DPS  0   ·   HITS  0", K.RUBIK_B, rgb(200, 196, 188), 0.7, 0.12)
rate.Name = "Rate"
text(bg, "THIS ONE NEVER FALLS", K.RUBIK_B, rgb(120, 118, 114), 0.84, 0.1)
-- 6b. MOVING dummy: rides a rail side to side (tracking practice). Sleepers, two rails, end buffers, a carriage
local mv = K.model(yard, "MovingDummy")
local blk = yard.Ground:FindFirstChild("Block7") -- the block that stood where the rail goes
if blk then
	blk:Destroy()
end
local RZ, RX0, RX1 = 72, 20, 56
for x = RX0 + 1.5, RX1 - 1.5, 3 do
	paint(mv, "Sleeper", V(x - 0.4, 0, RZ - 1.6), V(x + 0.4, 0.25, RZ + 1.6), DARK)
end
for _, z in { RZ - 1.0, RZ + 0.75 } do
	paint(
		mv,
		"Rail",
		V(RX0, 0.25, z),
		V(RX1, 0.5, z + 0.25),
		rgb(150, 154, 160),
		Enum.Material.Metal
	)
end
for _, x in { RX0 - 1.6, RX1 } do
	local bf = paint(mv, "Buffer", V(x, 0, RZ - 1.8), V(x + 1.6, 1.6, RZ + 1.8), rgb(255, 255, 255))
	local t = Instance.new("Texture")
	t.Texture, t.Face, t.StudsPerTileU, t.StudsPerTileV = HAZARD, Enum.NormalId.Back, 2, 2
	t.Parent = bf
	local t2 = t:Clone()
	t2.Face = Enum.NormalId.Front
	t2.Parent = bf
end
local car = K.model(mv, "Carriage")
paint(car, "Plate", V(36.4, 0.5, RZ - 1.6), V(39.6, 0.9, RZ + 1.6), GUN, Enum.Material.Metal)
local edge = paint(
	car,
	"Edge",
	V(36.5, 0.9, RZ - 1.5),
	V(39.5, 0.96, RZ + 1.5),
	K.dim(rgb(181, 140, 255), 0.5),
	Enum.Material.Neon
)
edge.CanCollide = false
local mbot = dummy(car, "Dummy", 38, 0.96, RZ, 0, 1)
for _, n in { "Base", "Top", "Ring" } do -- it stands on the carriage, not on its own pad
	local p = mbot:FindFirstChild(n)
	if p then
		p:Destroy()
	end
end
local purple = rgb(181, 140, 255)
dress(mbot, { torso = purple, limbs = rgb(40, 42, 48), head = rgb(226, 222, 212), ring = purple })
-- stand it on the carriage by its feet (the pad's rotated pieces make the box bottom useless)
local foot = mbot.TrainingBot.LeftFoot
mbot:PivotTo(
	mbot:GetPivot()
		+ V(0, (edge.Position.Y + edge.Size.Y / 2) - (foot.Position.Y - foot.Size.Y / 2), 0)
)
for _, b in mbot:GetDescendants() do
	if CS:HasTag(b, "RangeBot") then
		CS:RemoveTag(b, "RangeBot")
		b:SetAttribute("Lane", nil)
	end
end
CS:AddTag(car, "RangeMovingDummy")
car:SetAttribute("From", RX0 + 2)
car:SetAttribute("To", RX1 - 2)
car:SetAttribute("Speed", 10)

return range
