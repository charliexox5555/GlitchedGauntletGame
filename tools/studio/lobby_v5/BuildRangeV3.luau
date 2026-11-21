--!nocheck
-- Lobby V5 RANGE V3 (vault/02 Art/Lobby V5 Plan.md, "Range v3"). Owner 2026-11-21: "the shooting range is pretty boring.
-- it needs more like structure ... not over the top ... the signs you have for markers are pretty bad. I want jump pads
-- to be made in blender ... study the rivals shooting range". Study: vault/03 Research/Rivals Reference/Maps and
-- Lobby.md → "Shooting range study". Taken from it: height and overhead structure (thick 25-high walls with doorways
-- and windows, roofs you can walk, bridges crossing over the ground routes), one material with our grid, colour only on
-- the lane floor and the gameplay objects, big distance numbers on the lane walls, modelled glowing jump pads. Our own
-- layout and pad design.
-- Works on the range from BuildRangeV2.luau (keeps the spawn deck, exit hologram, bins, bots, booths, firing line).
-- Needs V5Kit.LobbyKit + LobbyWay; jump pad mesh asset 103017656207012 (tools/blender/lobby_v5/v5_jumppad.py).
-- Jump pads: trigger parts tagged `RangeJumpPad` with Launch / PushX / PushZ (src/lobby/client/Controllers/LobbyJumpPads).

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
local RO = CFrame.new(0, 0, 2600)
local GRID = "rbxassetid://99198970022758"
local STRUCT, BLOCK, FLOOR = rgb(151, 153, 163), rgb(132, 134, 143), rgb(160, 162, 170)
local TEAL = K.AREA.range.col
local GUN = rgb(78, 80, 86)
local X, Z, H = 130, 120, 45 -- the yard is x ±130, z ±120; walls now 45 high (were 30)

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
local function ramp(parent, name, low, dir, len, w, h, col)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.Color = col or STRUCT
	p.Size = V(w, h, len)
	local c = RO * (V(low.X, 0, low.Z) + dir * (len / 2) + V(0, h / 2, 0))
	p.CFrame = CFrame.lookAt(c, c - RO:VectorToWorldSpace(dir))
	p.Parent = parent
	for _, f in { Enum.NormalId.Top, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Back } do
		local tx = K.texture(p, f, GRID, 5)
		tx.Color3 = Color3.new(0, 0, 0)
		tx.Transparency = 0.75
	end
	return p
end
local function truss(parent, x, z, y0, y1)
	local tr = Instance.new("TrussPart")
	tr.Name = "Ladder"
	tr.Anchored = true
	tr.Size = V(2, y1 - y0, 2)
	tr.CFrame = RO * CFrame.new(x, (y0 + y1) / 2, z)
	tr.Color = GUN
	tr.Material = Enum.Material.Metal
	tr.Parent = parent
end
-- a wall with openings. run = "x" (runs along x, thickness t0..t1 on z) or "z". openings = { {s, e, bottom, top} }
-- along the run; doors have bottom 0. Solid pieces between openings, lintels above, sills below windows.
local function wall(parent, name, run, a0, a1, t0, t1, h, openings, col)
	local function piece(n, s, e, y0, y1)
		if e - s < 0.01 or y1 - y0 < 0.01 then
			return
		end
		if run == "x" then
			brick(parent, n, V(s, y0, t0), V(e, y1, t1), col)
		else
			brick(parent, n, V(t0, y0, s), V(t1, y1, e), col)
		end
	end
	table.sort(openings or {}, function(p, q)
		return p[1] < q[1]
	end)
	local at = a0
	for _, o in openings or {} do
		piece(name, at, o[1], 0, h)
		piece(name .. "_Lintel", o[1], o[2], o[4], h)
		piece(name .. "_Sill", o[1], o[2], 0, o[3])
		at = o[2]
	end
	piece(name, at, a1, 0, h)
end
-- parapet segments along a roof edge (run "x" or "z" at fixed t0..t1), 2.5 high, 10 long with 5 gaps
local function parapet(parent, run, a0, a1, t0, t1, y)
	local s = a0
	while s < a1 - 0.1 do
		local e = math.min(s + 10, a1)
		if run == "x" then
			brick(parent, "Parapet", V(s, y, t0), V(e, y + 2.5, t1), STRUCT)
		else
			brick(parent, "Parapet", V(t0, y, s), V(t1, y + 2.5, e), STRUCT)
		end
		s = e + 5
	end
end

-- 0. clear what changes -------------------------------------------------------------------------------------------------
for _, n in { "Shell", "Arena" } do
	local m = range:FindFirstChild(n)
	if m then
		m:Destroy()
	end
end
local lanes = range.Lanes
for _, c in lanes:GetChildren() do
	if
		table.find(
			{
				"Divider_S",
				"Divider_M",
				"Divider_N",
				"Band",
				"Mark",
				"Distance",
				"LaneWall",
				"LaneSign",
			},
			c.Name
		)
	then
		c:Destroy()
	end
end

-- 1. shell: floor, 45-high walls, dark coping --------------------------------------------------------------------------
local shell = K.model(range, "Shell")
brick(shell, "Floor", V(-X - 5, -2, -Z - 5), V(X + 5, 0, Z + 5), FLOOR, { Enum.NormalId.Top })
brick(shell, "Wall_N", V(-X - 5, 0, -Z - 5), V(X + 5, H, -Z))
brick(shell, "Wall_S", V(-X - 5, 0, Z), V(X + 5, H, Z + 5))
brick(shell, "Wall_W", V(-X - 5, 0, -Z), V(-X, H, Z))
brick(shell, "Wall_E", V(X, 0, -Z), V(X + 5, H, Z))
for _, c in
	{
		{ V(-X - 5.5, H, -Z - 5.5), V(X + 5.5, H + 1, -Z + 0.5) },
		{ V(-X - 5.5, H, Z - 0.5), V(X + 5.5, H + 1, Z + 5.5) },
		{ V(-X - 5.5, H, -Z + 0.5), V(-X + 0.5, H + 1, Z - 0.5) },
		{ V(X - 0.5, H, -Z + 0.5), V(X + 5.5, H + 1, Z - 0.5) },
	}
do
	paint(shell, "Coping", c[1], c[2], GUN, Enum.Material.Metal)
end

-- 2. the lane: a walled corridor, colour bands every 25, big distance numbers on both walls ---------------------------
local LX0, LX1, FL = 75, X, 88
wall(lanes, "LaneWall", "z", -Z, 92, 70, LX0, H, {}, STRUCT)
local BANDS = {
	rgb(255, 98, 72), -- 25  (duels orange)
	rgb(255, 200, 61), -- 50  (shop yellow)
	rgb(43, 217, 168), -- 75  (range teal)
	rgb(63, 224, 242), -- 100 (locker cyan)
	rgb(181, 140, 255), -- 125 (pass purple)
	rgb(92, 96, 108), -- 150
	rgb(44, 46, 52), -- 175
	rgb(200, 202, 208), -- 200
}
for k, col in BANDS do
	local z1 = FL - (k - 1) * 25
	local z0 = math.max(z1 - 25, -Z)
	local b = brick(lanes, "Band", V(LX0, 0, z0), V(LX1, 0.05, z1), col, { Enum.NormalId.Top })
	b.Material = Enum.Material.SmoothPlastic
	local d = FL - z0 -- the far edge of this band = the distance from the firing line
	if z0 > -Z then
		for _, side in { -1, 1 } do
			local x = if side < 0 then LX0 + 0.06 else LX1 - 0.06
			local p = Instance.new("Part")
			p.Name = "LaneSign"
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Transparency = 1
			p.Size = V(15, 7.5, 0.05) -- the Front face carries the text
			p.CFrame = RO * CFrame.lookAt(V(x, 8, z0), V(x - side, 8, z0)) -- face into the lane
			p.Parent = lanes
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Front
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 50
			g.LightInfluence = 0.2
			g.Parent = p
			local num = Instance.new("TextLabel")
			num.BackgroundTransparency = 1
			num.Position = UDim2.fromScale(0, 0.02)
			num.Size = UDim2.fromScale(1, 0.62)
			num.FontFace = K.RUBIK_H
			num.Text = tostring(d)
			num.TextColor3 = Color3.new(1, 1, 1)
			num.TextScaled = true
			num.Parent = g
			local st = Instance.new("UIStroke")
			st.Color = rgb(20, 20, 24)
			st.Thickness = 4
			st.Parent = num
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.AnchorPoint = Vector2.new(0.5, 0)
			bar.Position = UDim2.fromScale(0.5, 0.66)
			bar.Size = UDim2.fromScale(0.34, 0.05)
			bar.BackgroundColor3 = col
			bar.Parent = g
			local unit = num:Clone()
			unit.Position = UDim2.fromScale(0, 0.74)
			unit.Size = UDim2.fromScale(1, 0.22)
			unit.FontFace = K.RUBIK_B
			unit.Text = "STUDS"
			unit.Parent = g
		end
	end
end

-- 3. the yard's structures ------------------------------------------------------------------------------------------------
local yard = K.model(range, "Yard")
-- 3a. HANGAR (north-west): hollow, 25 high, doors south and east, a walkable roof with parapets
local hg = K.model(yard, "Hangar")
local HX0, HX1, HZ0, HZ1, HH = -125, -85, -115, -80, 25
wall(
	hg,
	"South",
	"x",
	HX0,
	HX1,
	HZ1 - 5,
	HZ1,
	HH - 2.5,
	{ { -111, -99, 0, 15 }, { -95, -90, 15, 20 } }
)
wall(hg, "East", "z", HZ0, HZ1 - 5, HX1 - 5, HX1, HH - 2.5, { { -104, -94, 0, 15 } })
wall(hg, "West", "z", HZ0, HZ1 - 5, HX0, HX0 + 5, HH - 2.5, { { -105, -95, 15, 20 } })
wall(hg, "North", "x", HX0 + 5, HX1 - 5, HZ0, HZ0 + 5, HH - 2.5, {})
brick(hg, "Roof", V(HX0, HH - 2.5, HZ0), V(HX1, HH, HZ1), STRUCT)
parapet(hg, "x", HX0, HX1, HZ0, HZ0 + 1.5, HH)
parapet(hg, "z", HZ0 + 6.5, HZ1 - 5, HX0, HX0 + 1.5, HH)
truss(hg, HX1 + 1, -110, 0, HH)
-- 3b. LONG HALL (centre): two 25-high walls with doorways and windows, beams across the top, the walls walkable
local lh = K.model(yard, "LongHall")
local AZ0, AZ1 = -95, 20
wall(
	lh,
	"WallA",
	"z",
	AZ0,
	AZ1,
	-45,
	-40,
	25,
	{
		{ -88, -80, 0, 12 },
		{ -55, -47, 0, 12 },
		{ -20, -12, 0, 12 },
		{ -72, -66, 15, 20 },
		{ -35, -29, 15, 20 },
		{ 2, 8, 15, 20 },
	}
)
wall(
	lh,
	"WallB",
	"z",
	-60,
	AZ1,
	-15,
	-10,
	25,
	{ { -45, -37, 0, 12 }, { -10, -2, 0, 12 }, { -28, -22, 15, 20 }, { 6, 12, 15, 20 } }
)
for _, z in { -50, -20, 10 } do
	brick(lh, "Beam", V(-40, 22, z - 2.5), V(-15, 25, z + 2.5), BLOCK)
end
truss(lh, -46, -30, 0, 25)
-- 3c. TOWER (west of centre): a 40-high block with a lookout top
local tw = K.model(yard, "Tower")
brick(tw, "Body", V(-75, 0, -30), V(-60, 40, -15), STRUCT)
parapet(tw, "x", -75, -60, -30, -28.5, 40)
truss(tw, -59, -22.5, 0, 40)
-- 3d. BRIDGES at 25: hangar roof -> wall A, wall B -> the lookout (on a pier)
local br = K.model(yard, "Bridges")
brick(br, "HangarBridge", V(HX1, 22.5, -92), V(-45, 25, -82), STRUCT)
brick(br, "LookoutBridge", V(-10, 22.5, -22.5), V(30, 25, -12.5), STRUCT)
brick(br, "Pier", V(7.5, 0, -20), V(12.5, 22.5, -15), BLOCK)
brick(br, "Pier", V(-67.5, 0, -89.5), V(-62.5, 22.5, -84.5), BLOCK)
-- 3e. LOOKOUT (east, by the lane wall): a 25-high block, parkour posts up its south face
local lo = K.model(yard, "Lookout")
brick(lo, "Body", V(30, 0, -30), V(55, 25, -5), STRUCT)
parapet(lo, "z", -30, -5, 53.5, 55, 25)
parapet(lo, "x", 30, 55, -30, -28.5, 25)
for i, p in { { 42.5, 12.5, 5 }, { 37.5, 7.5, 10 }, { 42.5, 2.5, 15 }, { 47.5, -2.5, 20 } } do
	brick(lo, "Step" .. i, V(p[1] - 2.5, 0, p[2] - 2.5), V(p[1] + 2.5, p[3], p[2] + 2.5), BLOCK)
end
-- 3f. BUNKER (south-west): 15 high, a ramp up its east side, parapets
local bk = K.model(yard, "Bunker")
brick(bk, "Body", V(-125, 0, 35), V(-100, 15, 65), STRUCT)
ramp(bk, "Ramp", V(-75, 0, 45), V(-1, 0, 0), 25, 10, 15)
parapet(bk, "x", -125, -100, 35, 36.5, 15)
parapet(bk, "z", 37, 65, -125, -123.5, 15)
-- 3g. GROUND: U-walls and blocks for cover between the buildings
local gr = K.model(yard, "Ground")
for i, u in { { 10, 45, 0 }, { -70, 20, 90 }, { 20, -75, 180 } } do
	local m = K.model(gr, "UWall" .. i)
	local cf = RO * CFrame.new(u[1], 0, u[2]) * CFrame.Angles(0, math.rad(u[3]), 0)
	local function ub(a, b)
		local p = K.lpart(cf, m, "Wall", a, b, K.look(nil, STRUCT, Enum.Material.Plastic))
		for _, f in Enum.NormalId:GetEnumItems() do
			local tx = K.texture(p, f, GRID, 5)
			tx.Color3 = Color3.new(0, 0, 0)
			tx.Transparency = 0.75
		end
	end
	ub(V(-7.5, 0, -2.5), V(7.5, 10, 0))
	ub(V(-7.5, 0, 0), V(-5, 10, 10))
	ub(V(5, 0, 0), V(7.5, 10, 10))
end
for i, c in
	{
		{ -100, -40, 10, 5, 5 },
		{ -110, 0, 5, 10, 10 },
		{ -95, 20, 5, 5, 5 },
		{ -28, -75, 5, 5, 5 },
		{ -27.5, 35, 10, 5, 5 },
		{ 5, 15, 5, 10, 5 },
		{ 25, 70, 10, 5, 5 },
		{ -55, 70, 5, 5, 10 },
		{ 15, -50, 5, 5, 10 },
		{ 60, 40, 5, 5, 5 },
	}
do
	brick(
		gr,
		"Block" .. i,
		V(c[1] - c[3] / 2, 0, c[2] - c[5] / 2),
		V(c[1] + c[3] / 2, c[4], c[2] + c[5] / 2),
		BLOCK
	)
end

-- 4. JUMP PADS (modelled) ---------------------------------------------------------------------------------------------
local kit = SS.V5Kit:FindFirstChild("JumpPad")
if not kit then
	local raw = InsertService:LoadAsset(103017656207012)
	kit = Instance.new("Model")
	kit.Name = "JumpPad"
	local look = {
		Trim = { rgb(40, 42, 46), Enum.Material.SmoothPlastic },
		Body = { GUN, Enum.Material.Metal },
		Rubber = { rgb(28, 29, 32), Enum.Material.SmoothPlastic },
		Hardware = { rgb(150, 154, 160), Enum.Material.Metal },
		Accent = { K.dim(TEAL, 0.6), Enum.Material.Neon },
	}
	for _, p in raw:GetDescendants() do
		if p:IsA("MeshPart") then
			local role = string.match(p.Name, "_(%a+)$")
			p.Name = role or p.Name
			p.Anchored, p.CanTouch = true, false
			p.CanCollide = role ~= "Accent"
			local l = look[role]
			if l then
				p.Color, p.Material = l[1], l[2]
			end
			p.Parent = kit
		end
	end
	raw:Destroy()
	local cf, size = kit:GetBoundingBox()
	kit.WorldPivot = CFrame.new(cf.Position - V(0, size.Y / 2, 0))
	kit:PivotTo(CFrame.new())
	kit.Parent = SS.V5Kit
end
local jp = K.model(yard, "JumpPads")
-- { x, z, launch, pushX, pushZ }: each next to the roof it serves
for i, p in
	{
		-- tested in play: in the air the humanoid caps sideways speed near walk speed, so pads sit ~7 from the wall and
		-- launch high (peaks 33-56) to clear the roof edge; all four land on their roof
		{ -92, -73, 122, 0, -26 }, -- onto the hangar roof (25)
		{ 42.5, -36.5, 122, 0, 20 }, -- onto the lookout (25), clearing its north parapet
		{ -67.5, -8, 145, 0, -16 }, -- onto the tower (40)
		{ -112.5, 28.5, 108, 0, 25 }, -- onto the bunker (15), clearing its north parapet
	}
do
	local m = kit:Clone()
	m.Name = "JumpPad" .. i
	m:PivotTo(RO * CFrame.new(p[1], 0, p[2]))
	m.Parent = jp
	for _, part in m:GetChildren() do
		if part.Name == "Accent" then
			K.point(part, TEAL, 1.0, 12)
		end
	end
	local trig = Instance.new("Part")
	trig.Name = "Trigger"
	trig.Anchored, trig.CanCollide, trig.CanQuery, trig.CanTouch = true, false, false, true
	trig.Transparency = 1
	trig.Size = V(8, 2, 8)
	trig.CFrame = RO * CFrame.new(p[1], 1.5, p[2])
	trig:SetAttribute("Launch", p[3])
	trig:SetAttribute("PushX", p[4])
	trig:SetAttribute("PushZ", p[5])
	trig.Parent = m
	CS:AddTag(trig, "RangeJumpPad")
end

-- 4b. the bots stand on the 25-stud lines (their old "20 STUDS" post signs go: the lane walls carry the numbers)
local laneX = { L = 85, C = 100, R = 115 }
local plan = { L = { 25, 100, 175 }, C = { 50, 125, 200 }, R = { 75, 150, 25 } }
local used = { L = 0, C = 0, R = 0 }
local list = lanes.Bots:GetChildren()
table.sort(list, function(a, b)
	return a.Name < b.Name
end)
for _, b in list do
	for _, n in { "PostFoot", "Post", "Plate" } do
		local p = b:FindFirstChild(n)
		if p then
			p:Destroy()
		end
	end
	local lane = string.match(b.Name, "Pad_(%a)_")
	if lane then
		used[lane] += 1
		local d = plan[lane][used[lane]]
		local piv = b:GetPivot()
		local cf, size = b:GetBoundingBox()
		local lift = piv.Position.Y - (cf.Position.Y - size.Y / 2)
		b:PivotTo(CFrame.new((RO * V(laneX[lane], 0, FL - d)) + V(0, lift, 0)) * piv.Rotation)
		b.Name = "Pad_" .. lane .. "_" .. d
	end
end
-- the firing line sits 0.09 high, over the first band (0.05), no shared face
local fline = lanes:FindFirstChild("FiringLine")
if fline then
	fline.Size = V(fline.Size.X - 0.2, 0.09, fline.Size.Z)
	fline.CFrame = CFrame.new(fline.Position.X, 0.045, fline.Position.Z) * fline.CFrame.Rotation
end

-- 5. THE DEEP on the taller north wall ---------------------------------------------------------------------------------
local lm = range:FindFirstChild("Landmark")
if lm then
	local cf, size = lm:GetBoundingBox()
	local lift = lm:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	lm:PivotTo(RO * CFrame.new(-30, H + 1 + lift, -Z - 2.5))
end

return range
