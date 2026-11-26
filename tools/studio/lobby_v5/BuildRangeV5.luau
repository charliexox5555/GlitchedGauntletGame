--!nocheck
-- Lobby V5 RANGE V5 (vault/01 Design/Range v5.md). Owner 2026-11-25: "I dont think we have enough height and levels
-- to work with", the dummies need to be "orange/gold or a blue" and "I want more of them just so there is a lot to get".
-- Run from the command bar / Studio MCP (edit mode); safe to run again (it rebuilds Yard.Levels and Yard.DummiesV5).
-- Range-local coordinates like V3/V4: RO = (0, 0, 2600), x right, -z north, floor top y = 0.
--   * NORTH GALLERY: deck at 12 along the north wall (x -78..62), two stairs up from the yard, low parapets (cover).
--   * SNIPER PERCH: deck at 24 in the north-east corner, a stair up from the gallery along the wall.
--   * WEST TERRACE: deck at 15 along the west wall joining the bunker roof, a stair up from the yard, and a stair on
--     to the hangar roof (25): the yard now has walkable floors at 0, 12, 15, 24, 25 and 40 (tower).
--   * DUMMIES: 18 more (gallery, perch, terrace, the open floor: four strafe ADAD); the damage dummy and the carriage
--     rider become `RangeBot`s. Their look (one blue) and clips come from the server at run time (Range/RangeBots).
-- Needs ServerStorage.V5Kit.LobbyKit + LobbyWay (like V4). Overlaps with existing parts are printed, not fixed.

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local range = workspace.LobbyV5.Range
local yard = range.Yard
local RO = CFrame.new(0, 0, 2600)
local GRID = "rbxassetid://99198970022758"
local STRUCT, BLOCK = rgb(151, 153, 163), rgb(132, 134, 143)
local DARK = rgb(40, 42, 46)
local TEAL = K.AREA.range.col
local report = {}

for _, n in { "Levels", "DummiesV5" } do
	local old = yard:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end
local lv = K.model(yard, "Levels")

local function brick(parent, name, a, b, col)
	local p = K.lpart(RO, parent, name, a, b, K.look(nil, col or STRUCT, Enum.Material.Plastic))
	for _, f in Enum.NormalId:GetEnumItems() do
		local tx = K.texture(p, f, GRID, 5)
		tx.Color3 = Color3.new(0, 0, 0)
		tx.Transparency = 0.75
	end
	return p
end
local function paint(parent, name, a, b, col, mat)
	return K.lpart(RO, parent, name, a, b, K.look(nil, col, mat or Enum.Material.SmoothPlastic))
end
-- A wedge in range space: its high side faces -`out` (toward the part it ends), sloping down toward `out`.
local function wedge(parent, name, centre, size, out, col)
	local Z = -V(out.X, 0, out.Z).Unit
	local X = Vector3.yAxis:Cross(Z)
	local p = K.part(parent, name, size, RO * CFrame.fromMatrix(centre, X, Vector3.yAxis), K.look(nil, col or STRUCT, Enum.Material.Plastic), "WedgePart")
	return p
end

-- overlap check against what was there before this build
local before = OverlapParams.new()
before.FilterType = Enum.RaycastFilterType.Exclude
before.FilterDescendantsInstances = { lv }
local function clear(label, a, b)
	local lo, hi = a:Min(b), a:Max(b)
	local hits = workspace:GetPartBoundsInBox(RO * CFrame.new((lo + hi) / 2), hi - lo - V(0.2, 0.2, 0.2), before)
	for _, h in hits do
		if h:IsDescendantOf(range) and not h:IsDescendantOf(lv) and h.Name ~= "Floor" then
			table.insert(report, label .. " overlaps " .. h:GetFullName():gsub("Workspace.LobbyV5.Range.", ""))
		end
	end
end

-- A deck: slab top at `y`, front edge facing `front` ("+z" | "-z" | "+x" | "-x"), a darker fascia band and a recessed
-- teal glow line under the front edge, piers under the front edge every ~14 with flared heads and feet.
local function deck(parent, name, x0, x1, z0, z1, y, front, piers)
	clear(name, V(x0, y - 1.5, z0), V(x1, y, z1))
	local m = K.model(parent, name)
	brick(m, "Deck", V(x0, y - 1.5, z0), V(x1, y, z1))
	local function along(f)
		-- returns a function mapping (s, depth) -> point on the front edge, s along it
		if front == "+z" then
			return function(s, d, yy)
				return V(s, yy, z1 + d)
			end, x0, x1
		elseif front == "-z" then
			return function(s, d, yy)
				return V(s, yy, z0 - d)
			end, x0, x1
		elseif front == "+x" then
			return function(s, d, yy)
				return V(x1 + d, yy, s)
			end, z0, z1
		end
		return function(s, d, yy)
			return V(x0 - d, yy, s)
		end, z0, z1
	end
	local at, s0, s1 = along(front)
	-- fascia: 0.15 proud, the top 0.3 below the deck top
	paint(m, "Fascia", at(s0, 0, y - 1.6), at(s1, 0.15, y - 0.3), BLOCK, Enum.Material.Plastic)
	-- glow line under the edge, set 0.4 back from the face
	local glow = paint(m, "Glow", at(s0 + 0.5, -0.4, y - 1.75), at(s1 - 0.5, -0.7, y - 1.5), K.dim(TEAL, 0.45), Enum.Material.Neon)
	K.ghost(glow)
	if piers then
		local n = math.max(1, math.floor((s1 - s0) / 14))
		for i = 0, n do
			local s = s0 + 1.5 + (s1 - s0 - 3) * i / n
			local c = at(s, -1.5, 0)
			brick(m, "Pier", c - V(1, 0, 1), c + V(1, y - 1.5, 1), BLOCK)
			paint(m, "PierFoot", c - V(1.4, 0, 1.4), c + V(1.4, 0.5, 1.4), DARK)
			paint(m, "PierHead", c + V(-1.4, y - 2.1, -1.4), c + V(1.4, y - 1.5, 1.4), DARK)
		end
	end
	return m
end

-- Parapet segments 2.5 high, 1 thick along an edge, `len` long with 4-stud gaps; each end cut back by a wedge.
local function parapet(parent, run, a0, a1, t0, t1, y, len)
	len = len or 10
	local s = a0
	while s < a1 - 0.5 do
		local e = math.min(s + len, a1)
		if run == "x" then
			brick(parent, "Parapet", V(s + 0.8, y, t0), V(e - 0.8, y + 2.5, t1))
			wedge(parent, "ParapetEnd", V(s + 0.4, y + 1.25, (t0 + t1) / 2), V(t1 - t0, 2.5, 0.8), V(-1, 0, 0))
			wedge(parent, "ParapetEnd", V(e - 0.4, y + 1.25, (t0 + t1) / 2), V(t1 - t0, 2.5, 0.8), V(1, 0, 0))
		else
			brick(parent, "Parapet", V(t0, y, s + 0.8), V(t1, y + 2.5, e - 0.8))
			wedge(parent, "ParapetEnd", V((t0 + t1) / 2, y + 1.25, s + 0.4), V(t1 - t0, 2.5, 0.8), V(0, 0, -1))
			wedge(parent, "ParapetEnd", V((t0 + t1) / 2, y + 1.25, e - 0.4), V(t1 - t0, 2.5, 0.8), V(0, 0, 1))
		end
		s = e + 4
	end
end

-- A solid stair from (x0..x1 or z0..z1) at y0 rising by `rise` toward `dir` over `run`. Steps are solid blocks
-- (no undersides to see); a cheek wedge on each open side, 1 above the nosing line.
local function stair(parent, name, base, dir, width, run, y0, rise, cheeks)
	local m = K.model(parent, name)
	local steps = math.ceil(rise / 0.75)
	local stepRise, stepRun = rise / steps, run / steps
	local d = V(dir.X, 0, dir.Z).Unit
	local side = Vector3.yAxis:Cross(d) -- left of the climb
	clear(name, base - side * width / 2 + V(0, y0, 0), base + side * width / 2 + d * run + V(0, y0 + rise, 0))
	for i = 1, steps do
		local a = base + d * (stepRun * (i - 1)) - side * width / 2 + V(0, y0, 0)
		local b = base + d * (stepRun * i) + side * width / 2 + V(0, y0 + stepRise * i, 0)
		brick(m, "Step", a, b, if i % 2 == 0 then STRUCT else BLOCK)
	end
	for _, sgn in cheeks or { -1, 1 } do
		-- a wedge along the climb: right angle at the top end, 0.5 thick, 1.2 above the nosings
		local mid = base + d * (run / 2) + side * (sgn * (width / 2 + 0.25)) + V(0, y0 + (rise + 1.2) / 2, 0)
		local Z = d -- a wedge's tall side is its +Z: at the top of the climb
		local X = Vector3.yAxis:Cross(Z)
		K.part(m, "Cheek", V(0.5, rise + 1.2, run), RO * CFrame.fromMatrix(mid, X, Vector3.yAxis), K.look(nil, DARK, Enum.Material.SmoothPlastic), "WedgePart")
	end
	return m
end

-- 1. NORTH GALLERY (deck 12) ----------------------------------------------------------------------------------------------
local gal = K.model(lv, "NorthGallery")
deck(gal, "Gallery", -78, 70, -120, -108, 12, "+z", true)
parapet(gal, "x", -78, 18, -109, -108, 12, 12)
parapet(gal, "z", -119, -109, -78, -77, 12, 10) -- the west end
stair(gal, "StairEast", V(58, 0, -86), V(0, 0, -1), 8, 22, 0, 12)
stair(gal, "StairMid", V(7, 0, -86), V(0, 0, -1), 7, 22, 0, 12)

-- 2. SNIPER PERCH (deck 24) over the gallery's east end, a stair up from the gallery along the north wall -----------------
local pr = K.model(lv, "SniperPerch")
deck(pr, "Perch", 40, 70, -120, -100, 24, "+z", false)
for _, x in { 41.5, 66.5 } do -- two big piers under the front corners (in front of the gallery), floor to deck
	brick(pr, "Pier", V(x - 1.5, 0, -104), V(x + 1.5, 22.5, -101), BLOCK)
	paint(pr, "PierFoot", V(x - 1.9, 0, -104.4), V(x + 1.9, 0.5, -100.6), DARK)
end
parapet(pr, "x", 40, 70, -101, -100, 24, 9)
parapet(pr, "z", -112, -101, 40, 41, 24, 5) -- leaves the stair's landing (z -120..-114) open
stair(pr, "StairUp", V(20, 0, -117), V(1, 0, 0), 6, 20, 12, 12, { -1 })

-- 3. WEST TERRACE (deck 15) joining the bunker roof; stairs from the yard and on to the hangar roof -----------------------
local wt = K.model(lv, "WestTerrace")
deck(wt, "Terrace", -130, -118, -80, 35, 15, "+x", true)
-- the bunker's north parapet segment on the join goes (the terrace runs on to its roof)
for _, p in yard.Bunker:GetChildren() do
	if p.Name == "Parapet" and p:IsA("BasePart") and math.abs(p.Position.X - -120) < 0.1 and math.abs(p.Position.Z - 2635.75) < 0.2 then
		p:Destroy()
		table.insert(report, "removed the bunker's north parapet segment x -125..-115 (the terrace joins its roof)")
	end
end
parapet(wt, "z", -66, -57, -119, -118, 15, 9) -- open at the yard stair's landing (z -55.5..-48.5)
parapet(wt, "z", -47, 35, -119, -118, 15, 12)
parapet(wt, "x", -130, -125, 34, 35, 15, 5) -- the gap between the wall and the bunker
stair(wt, "StairYard", V(-96, 0, -52), V(-1, 0, 0), 7, 22, 0, 15)
stair(wt, "StairHangar", V(-121, 0, -66), V(0, 0, -1), 6, 14, 15, 10, { 1 })

-- 4. DUMMIES ---------------------------------------------------------------------------------------------------------------
local template = yard.Dummies:FindFirstChild("Dummy6")
assert(template, "missing Yard.Dummies.Dummy6 (the dummy + pad template)")
local tplBot = template:FindFirstChild("TrainingBot")
local tplRoot = tplBot.HumanoidRootPart.Position
local tplLook = tplBot.HumanoidRootPart.CFrame.LookVector * V(1, 0, 1)
local dv = K.model(yard, "DummiesV5")
-- { x, z, deck y, face toward (x, z) or nil = the alcove, behaviour, sway }
local SPOTS = {
	-- gallery (12)
	{ -68, -113, 12, { -68, 40 } },
	{ -44, -113, 12, { -30, 40 } },
	{ -22, -112, 12, { -10, 40 } },
	{ 0, -112.5, 12, { 0, 40 } },
	{ 32, -111, 12, { 20, 40 } },
	-- perch (24)
	{ 48, -105, 24, { 10, 60 } },
	{ 63, -112, 24, { 0, 60 } },
	-- terrace (15)
	{ -124, -45, 15, { 0, -20 } },
	{ -124, -10, 15, { 0, 10 } },
	{ -124, 22, 15, { 0, 40 } },
	-- the open floor: four strafers and four still
	{ 36, 26, 0, nil, "Strafe", 6 },
	{ 56, 44, 0, nil, "Strafe", 5 },
	{ -22, 44, 0, nil, "Strafe", 6 },
	{ 30, -60, 0, { 30, 40 }, "Strafe", 6 },
	{ -80, -50, 0, { 0, 0 } },
	{ 60, -45, 0, { 0, 40 } },
	{ -95, 85, 0, { 0, 40 } },
	{ 52, 82, 0, { 0, 60 } },
}
for i, s in SPOTS do
	clear("Dummy" .. i, V(s[1] - 1.5, s[3] + 0.2, s[2] - 1.5), V(s[1] + 1.5, s[3] + 5.5, s[2] + 1.5))
	local m = template:Clone()
	m.Name = "Dummy" .. (100 + i)
	-- pivot on the floor under the bot, facing where the bot faces: then lookAt turns the bot itself
	m.WorldPivot = CFrame.lookAt(V(tplRoot.X, 0, tplRoot.Z), V(tplRoot.X, 0, tplRoot.Z) + tplLook.Unit)
	local pos = RO * V(s[1], s[3], s[2])
	local toward = if s[4] then RO * V(s[4][1], s[3], s[4][2]) else RO * V(s[1], s[3], 140)
	m:PivotTo(CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z)))
	local bot = m:FindFirstChild("TrainingBot")
	if s[5] then
		bot:SetAttribute("Behaviour", s[5])
		bot:SetAttribute("Sway", s[6])
	end
	m.Parent = dv
end

-- The two specials join in as training bots.
local dmg = yard.DamageDummy:FindFirstChild("Dummy")
local dmgBot = dmg and dmg:FindFirstChild("TrainingBot")
if dmgBot then
	CS:AddTag(dmgBot, "RangeBot")
	CS:AddTag(dmgBot, "RangeDamageDummy")
end
local rider = yard.MovingDummy.Carriage:FindFirstChild("Dummy")
local riderBot = rider and rider:FindFirstChildWhichIsA("Model")
if riderBot then
	CS:AddTag(riderBot, "RangeBot")
end

local bots = #CS:GetTagged("RangeBot")
table.insert(report, ("built: gallery, perch, terrace, %d new dummies; RangeBot total %d"):format(#SPOTS, bots))
return table.concat(report, "\n")
