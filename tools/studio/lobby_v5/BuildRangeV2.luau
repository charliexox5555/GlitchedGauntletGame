--!nocheck
-- Lobby V5 RANGE V2 (vault/02 Art/Lobby V5 Plan.md, "Hub 9/10 pass"). Owner 2026-11-21: "like the rivals range, it is
-- a smaller hologram ... where you touch it and enter the range, there should be no dummies from what you can see. The
-- actual range is built further away, it needs to be much bigger, open, levels and look better so many players can be
-- in it at once." Replaces last night's test hall behind the sim bay (BuildRange.luau).
-- * hub side: the sim bay's back wall is closed again, the grid curtain goes, the hologram range on the projector is
--   the way in (trigger tagged `RangeEntry`), `RangeReturn` marks where you come back out;
-- * the range itself is a sunlit "simulation yard" at world (0, 0, 2600), 270 x 250, arena bricks (two greys, our
--   grid tile), walls 30 high: a spawn deck with the exit hologram (`RangeExit`), spawn points (`RangeSpawn`) and the
--   six loadout bins (`RangeLoadout`); three firing lanes on the east with distance bands and the nine bots
--   (`RangeBot`); an open arena with four 10-high bastions, a two-level plateau, catwalks joining them, ramps, truss
--   ladders, cover blocks, two tall walls and jump pads (`RangeJumpPad`, hook for later code). The THE DEEP landmark
--   stands on the north wall.
-- Teleports: src/lobby/server/Services/RangeService.luau. Re-runnable.

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local bay = workspace.LobbyV5.Shell.Hub.RangeBay
local F = K.frame(V(0, 0, 42), V(0, 0, -1)) -- the bay's frame: walking in = -z
local GRID = "rbxassetid://99198970022758"
local STRUCT, BLOCK, FLOOR = rgb(151, 153, 163), rgb(132, 134, 143), rgb(160, 162, 170)
local TEAL = K.AREA.range.col
local YEL = rgb(214, 168, 48)

-- 0. keep what the new range reuses, then drop the old hall -----------------------------------------------------------
local keep = {}
local oldHall = bay:FindFirstChild("Hall")
if oldHall then
	for _, n in { "Bots", "LoadoutBins" } do
		local m = oldHall:FindFirstChild(n)
		if m then
			m.Parent = nil
			keep[n] = m
		end
	end
	oldHall:Destroy()
end
local landmark = bay:FindFirstChild("Landmark")

-- 1. HUB SIDE: close the sim bay, lose the curtain, the hologram is the way in ----------------------------------------
local sim = bay.SimBay
for _, c in sim:GetChildren() do
	if c.Name == "WallEnd" then
		c:Destroy()
	end
end
if not sim:FindFirstChild("Wall_Back") then
	local lk = sim.Wall_L
	local p = K.lpart(F, sim, "Wall_Back", V(-13, 0, -36), V(13, 18, -35), K.look(nil, lk.Color, lk.Material))
	p.MaterialVariant = lk.MaterialVariant
end
local curtain = bay:FindFirstChild("HoloCurtain")
if curtain then
	curtain:Destroy()
end
for _, n in { "RangeEntry", "RangeReturn" } do
	local o = bay:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end
local holo = bay.HoloRange
local hcf, hs = holo:GetBoundingBox()
local entry = Instance.new("Part")
entry.Name = "RangeEntry"
entry.Anchored, entry.CanCollide, entry.CanQuery, entry.CanTouch = true, false, false, true
entry.Transparency = 1
entry.Size = V(hs.X + 1, 7, hs.Z + 1)
entry.CFrame = CFrame.new(hcf.Position.X, 3.5, hcf.Position.Z)
entry.Parent = bay
CS:AddTag(entry, "RangeEntry")
local ret = K.anchorPart(bay, "RangeReturn", (F * V(0, 3, -8)) - K.O)
ret.CFrame = CFrame.lookAt(ret.Position, ret.Position + V(0, 0, -1)) -- facing the hub
CS:AddTag(ret, "RangeReturn")
holo:SetAttribute("SpinSpeed", 12)
CS:AddTag(holo, "LobbySpin")
-- a small hologram caption over the projector (the only label in the bay)
local cap = Instance.new("Part")
cap.Name = "Caption"
cap.Anchored, cap.CanCollide, cap.CanQuery, cap.CanTouch = true, false, false, false
cap.Transparency = 1
cap.Size = V(8, 1.6, 0.05)
cap.CFrame = CFrame.lookAt(V(hcf.Position.X, 9.2, hcf.Position.Z - 3), V(hcf.Position.X, 9.2, hcf.Position.Z - 10))
cap.Parent = bay
local g = Instance.new("SurfaceGui")
g.Face = Enum.NormalId.Front
g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
g.PixelsPerStud = 60
g.LightInfluence = 0
g.Brightness = 2
g.Parent = cap
local t = Instance.new("TextLabel")
t.BackgroundTransparency = 1
t.Size = UDim2.fromScale(1, 1)
t.FontFace = K.RUBIK_H
t.Text = "STEP IN  »  LIVE FIRE"
t.TextColor3 = TEAL
t.TextTransparency = 0.1
t.TextScaled = true
t.Parent = g

-- 2. THE RANGE ----------------------------------------------------------------------------------------------------------
local RO = CFrame.new(0, 0, 2600) -- clear ground (an old greybox range sits at z 1400)
local old = workspace.LobbyV5:FindFirstChild("Range")
if old then
	old:Destroy()
end
local range = Instance.new("Model")
range.Name = "Range"
range.Parent = workspace.LobbyV5

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
-- a wedge ramp from `low` (x, z at ground) rising along `dir` to height h over length len, width w
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
	for _, f in { Enum.NormalId.Top, Enum.NormalId.Left, Enum.NormalId.Right } do
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
	tr.Color = rgb(78, 80, 86)
	tr.Material = Enum.Material.Metal
	tr.Parent = parent
	return tr
end

-- shell: floor, walls with a darker coping
local shell = K.model(range, "Shell")
local X, Z, H = 130, 120, 30
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
	paint(shell, "Coping", c[1], c[2], rgb(78, 80, 86), Enum.Material.Metal)
end

-- spawn deck (south): 5 high, three steps down to the arena, the exit hologram at the back
local deck = K.model(range, "SpawnDeck")
brick(deck, "Deck", V(-35, 0, 95), V(35, 5, Z), STRUCT)
for i, s in { { 93, 3.75 }, { 91, 2.5 }, { 89, 1.25 } } do
	brick(deck, "Step" .. i, V(-20, 0, s[1]), V(20, s[2], s[1] + 2), BLOCK)
end
paint(deck, "EdgeLine", V(-35, 5, 95), V(35, 5.04, 95.6), YEL)
for i, p in { { -25, 108 }, { -10, 108 }, { 10, 108 }, { 25, 108 } } do
	local a = K.anchorPart(deck, "Spawn" .. i, (RO * V(p[1], 8, p[2])) - K.O)
	a.CFrame = CFrame.lookAt(a.Position, a.Position + RO:VectorToWorldSpace(V(0, 0, -1)))
	CS:AddTag(a, "RangeSpawn")
end
-- exit hologram: a teal ring of posts and a glowing pad, a trigger box over it
local exit = K.model(deck, "ExitHologram")
local ec = V(0, 5, 114)
paint(exit, "Base", ec + V(-5, 0, -4), ec + V(5, 0.3, 4), rgb(52, 54, 58), Enum.Material.Metal)
local pad = paint(exit, "Pad", ec + V(-4.2, 0.3, -3.2), ec + V(4.2, 0.42, 3.2), K.dim(TEAL, 0.55), Enum.Material.Neon)
pad.CanCollide = false
K.point(pad, TEAL, 1.2, 14)
for _, sx in { -1, 1 } do
	paint(
		exit,
		"Post",
		ec + V(sx * 4.6 - 0.3, 0.3, -0.3),
		ec + V(sx * 4.6 + 0.3, 7.5, 0.3),
		rgb(78, 80, 86),
		Enum.Material.Metal
	)
	local beam = paint(
		exit,
		"Glow",
		ec + V(sx * 4.6 - 0.12, 0.6, 0.3),
		ec + V(sx * 4.6 + 0.12, 7.2, 0.42),
		K.dim(TEAL, 0.4),
		Enum.Material.Neon
	)
	beam.CanCollide = false
end
paint(exit, "Head", ec + V(-4.9, 7.5, -0.35), ec + V(4.9, 8.1, 0.35), rgb(52, 54, 58), Enum.Material.Metal)
local field = paint(exit, "Field", ec + V(-4.3, 0.42, -0.04), ec + V(4.3, 7.5, 0.04), TEAL, Enum.Material.ForceField)
field.CanCollide = false
field.Transparency = 0.2
local trig = paint(exit, "Trigger", ec + V(-4.2, 0.4, -3), ec + V(4.2, 7, 3), TEAL)
trig.Transparency, trig.CanCollide, trig.CanQuery = 1, false, false
CS:AddTag(trig, "RangeExit")

-- loadout bins along the deck's front edge
if keep.LoadoutBins then
	local bins = keep.LoadoutBins
	bins.Parent = deck
	local xs = { -30, -23, 23, 30, -16, 16 }
	for i, b in bins:GetChildren() do
		local _, s = b:GetBoundingBox()
		local x = xs[i] or (i * 4)
		local base = RO * CFrame.new(x, 5, 98.5)
		local cf, size = b:GetBoundingBox()
		local bottom = cf.Position - V(0, size.Y / 2, 0)
		b:PivotTo(base * CFrame.Angles(0, math.pi, 0) * (CFrame.new(bottom):ToObjectSpace(b:GetPivot())))
	end
end

-- firing lanes (east): divider wall, firing line, distance bands, booths, the bots
local lanes = K.model(range, "Lanes")
local LX0, LX1, FL = 75, X, 88
brick(lanes, "Divider_S", V(70, 0, 30), V(LX0, 10, 95), BLOCK)
brick(lanes, "Divider_M", V(70, 0, -40), V(LX0, 10, 15), BLOCK)
brick(lanes, "Divider_N", V(70, 0, -Z), V(LX0, 10, -55), BLOCK)
paint(lanes, "FiringLine", V(LX0, 0, FL - 0.3), V(LX1, 0.05, FL + 0.3), YEL)
for k = 1, 8 do
	local z1 = FL - (k - 1) * 25
	local z0 = math.max(z1 - 25, -Z)
	if k % 2 == 0 then
		paint(lanes, "Band", V(LX0, 0, z0), V(LX1, 0.03, z1), rgb(138, 140, 148), Enum.Material.Plastic)
	end
	if k <= 6 then
		local mark = paint(lanes, "Mark", V(LX0, 0, z1 - 25 - 0.25), V(LX1, 0.045, z1 - 25 + 0.25), rgb(94, 96, 104))
		local plate = paint(
			lanes,
			"Distance",
			V(LX0 + 0.5, 0.05, z1 - 25 + 0.5),
			V(LX0 + 4.5, 0.06, z1 - 25 + 2.5),
			rgb(52, 54, 58)
		)
		local dg = Instance.new("SurfaceGui")
		dg.Face = Enum.NormalId.Top
		dg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		dg.PixelsPerStud = 40
		dg.Parent = plate
		local dt = Instance.new("TextLabel")
		dt.BackgroundTransparency = 1
		dt.Size = UDim2.fromScale(1, 1)
		dt.FontFace = K.RUBIK_H
		dt.Text = tostring(k * 25)
		dt.TextColor3 = rgb(236, 232, 222)
		dt.TextScaled = true
		dt.Rotation = 180
		dt.Parent = dg
		local _ = mark
	end
end
for _, x in { 92.5, 107.5 } do
	brick(lanes, "Booth", V(x - 0.5, 0, 80), V(x + 0.5, 4, 92), BLOCK)
end
if keep.Bots then
	local bots = keep.Bots
	bots.Parent = lanes
	local laneX = { L = 85, C = 100, R = 115 }
	for _, b in bots:GetChildren() do
		local lane, d = string.match(b.Name, "Pad_(%a)_(%d+)")
		if lane and laneX[lane] then
			local piv = b:GetPivot()
			local cf, size = b:GetBoundingBox()
			local lift = piv.Position.Y - (cf.Position.Y - size.Y / 2)
			b:PivotTo(
				RO * CFrame.new(laneX[lane], lift, FL - tonumber(d)) * CFrame.Angles(0, math.pi, 0) * piv.Rotation
			)
		end
	end
end

-- the arena
local arena = K.model(range, "Arena")
-- bastions (10 high) in the corners, each with a ramp
local bastions = {
	{ "NW", V(-125, 0, -115), V(-100, 10, -90), V(-115, 0, -70), V(0, 0, -1) },
	{ "NE", V(40, 0, -115), V(65, 10, -90), V(50, 0, -70), V(0, 0, -1) },
	{ "SW", V(-125, 0, 60), V(-100, 10, 85), V(-115, 0, 40), V(0, 0, 1) },
	{ "SE", V(40, 0, 60), V(65, 10, 85), V(50, 0, 40), V(0, 0, 1) },
}
for _, b in bastions do
	local m = K.model(arena, "Bastion_" .. b[1])
	brick(m, "Body", b[2], b[3], STRUCT)
	ramp(m, "Ramp", b[4], b[5], 20, 10, 10)
	local faceZ = if b[5].Z < 0 then b[3].Z + 1 else b[2].Z - 1 -- on the ramp side, clear of the catwalk
	truss(m, b[2].X + 20, faceZ, 0, 10)
end
-- central plateau, 10 high, an upper block 10 more, ramp from the east, ladder to the top
local pl = K.model(arena, "Plateau")
brick(pl, "Base", V(-50, 0, -20), V(-30, 10, 0), STRUCT)
brick(pl, "Upper", V(-45, 10, -15), V(-35, 20, -5), BLOCK)
ramp(pl, "Ramp", V(-10, 0, -10), V(-1, 0, 0), 20, 10, 10)
truss(pl, -34, -10, 10, 20)
-- catwalks at 10: north and south runs between the bastions, a spine through the plateau
local cw = K.model(arena, "Catwalks")
brick(cw, "North", V(-100, 9, -105), V(40, 10, -100), STRUCT)
brick(cw, "South", V(-100, 9, 70), V(40, 10, 75), STRUCT)
brick(cw, "SpineN", V(-45, 9, -100), V(-40, 10, -20), STRUCT)
brick(cw, "SpineS", V(-45, 9, 0), V(-40, 10, 70), STRUCT)
for _, x in { -80, -60, -20, 0, 20 } do
	brick(cw, "Post", V(x - 1.25, 0, -103.75), V(x + 1.25, 9, -101.25), BLOCK)
	brick(cw, "Post", V(x - 1.25, 0, 71.25), V(x + 1.25, 9, 73.75), BLOCK)
end
for _, z in { -80, -55, 25, 50 } do
	brick(cw, "Post", V(-43.75, 0, z - 1.25), V(-41.25, 9, z + 1.25), BLOCK)
end
-- cover blocks (cx, cz, sx, h, sz)
local cover = K.model(arena, "Cover")
for i, c in
	{
		{ -112, -60, 10, 5, 10 },
		{ -85, -60, 5, 10, 15 },
		{ -115, -25, 10, 5, 5 },
		{ -90, -15, 5, 5, 10 },
		{ -112, 20, 10, 10, 5 },
		{ -85, 35, 5, 5, 10 },
		{ -20, -60, 10, 5, 10 },
		{ 5, -75, 5, 10, 5 },
		{ 25, -45, 10, 5, 15 },
		{ -5, -30, 5, 5, 5 },
		{ 15, -10, 10, 10, 5 },
		{ 0, 20, 5, 5, 10 },
		{ 25, 35, 10, 5, 5 },
		{ -15, 45, 5, 10, 5 },
		{ 50, 5, 5, 5, 10 },
		{ -65, -85, 10, 5, 5 },
		{ -65, 55, 10, 5, 5 },
	}
do
	brick(cover, "Block" .. i, V(c[1] - c[3] / 2, 0, c[2] - c[5] / 2), V(c[1] + c[3] / 2, c[4], c[2] + c[5] / 2), BLOCK)
end
brick(cover, "TallWall", V(-72.5, 0, -50), V(-67.5, 15, -25), STRUCT)
brick(cover, "TallWall", V(-72.5, 0, 15), V(-67.5, 15, 40), STRUCT)
-- jump pads (hook: RangeJumpPad), a dark plinth with a teal top
local jp = K.model(arena, "JumpPads")
for i, p in { { -95, -80 }, { -95, 50 }, { 35, -80 }, { 35, 50 }, { -25, -32 } } do
	local m = K.model(jp, "JumpPad" .. i)
	paint(
		m,
		"Plinth",
		V(p[1] - 3.5, 0, p[2] - 3.5),
		V(p[1] + 3.5, 0.6, p[2] + 3.5),
		rgb(52, 54, 58),
		Enum.Material.Metal
	)
	local top = paint(
		m,
		"Top",
		V(p[1] - 2.6, 0.6, p[2] - 2.6),
		V(p[1] + 2.6, 0.75, p[2] + 2.6),
		K.dim(TEAL, 0.5),
		Enum.Material.Neon
	)
	K.point(top, TEAL, 0.8, 9)
	CS:AddTag(top, "RangeJumpPad")
end

-- the THE DEEP landmark on the north wall, facing the deck
if landmark then
	landmark.Parent = range
	local cf, size = landmark:GetBoundingBox()
	local lift = landmark:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	landmark:PivotTo(RO * CFrame.new(-30, H + 1 + lift, -Z - 2.5))
end

return range
