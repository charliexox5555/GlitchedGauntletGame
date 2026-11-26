--!nocheck
-- Lobby V5 RANGE V5b (vault/01 Design/Range v5.md, round 3). Owner 2026-11-26: "the range just feels a little empty
-- ... have less empty areas", and "red circle targets [in the air] that you can shoot down".
-- Edit mode, safe to run again (rebuilds Yard.Fill and Range.Targets). Range-local coords like V3-V5: RO = (0,0,2600).
--   * FILL: a container stack in the south-west (two on the floor, one across the top, a stair up), a raised
--     platform with a ramp in the centre, crate clusters and jersey barriers on the bare floor; two dummies on top.
--   * TARGETS: 14 air targets (ServerStorage.V5Kit.AirTarget clones, tag RangeTarget, `Home` attribute) over the
--     yard and the lanes, facing the yard's south; some drift side to side (Drift / Period / Phase).
-- Overlaps with what was there are reported and the piece is skipped.

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
local STRUCT, BLOCK, DARK = rgb(151, 153, 163), rgb(132, 134, 143), rgb(40, 42, 46)
local SLATE, SLATE_D = rgb(74, 82, 94), rgb(58, 64, 74)
local TEAL = K.AREA.range.col
local report = {}

for _, n in { "Fill" } do
	local old = yard:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end
local oldT = range:FindFirstChild("Targets")
if oldT then
	oldT:Destroy()
end
local fill = K.model(yard, "Fill")

local before = OverlapParams.new()
before.FilterType = Enum.RaycastFilterType.Exclude
before.FilterDescendantsInstances = { fill }
-- true when the box (range-local, in frame F) is clear of existing range parts (the floor aside)
local function clear(label, F, a, b)
	local lo, hi = a:Min(b), a:Max(b)
	local hits = workspace:GetPartBoundsInBox(RO * F * CFrame.new((lo + hi) / 2), hi - lo - V(0.2, 0.2, 0.2), before)
	for _, h in hits do
		if h:IsDescendantOf(range) and not h:IsDescendantOf(fill) and h.Name ~= "Floor" and h.Name ~= "Band" then
			table.insert(report, label .. " skipped: overlaps " .. h:GetFullName():gsub("Workspace.LobbyV5.Range.", ""))
			return false
		end
	end
	return true
end
local function part(parent, name, F, a, b, col, mat, grid)
	local p = K.lpart(RO * F, parent, name, a, b, K.look(nil, col, mat or Enum.Material.SmoothPlastic))
	if grid then
		for _, f in Enum.NormalId:GetEnumItems() do
			local tx = K.texture(p, f, GRID, 5)
			tx.Color3 = Color3.new(0, 0, 0)
			tx.Transparency = 0.75
		end
	end
	return p
end
local function wedgeAt(parent, name, F, centre, size, high, col)
	-- a WedgePart whose tall side faces `high` (its slope falls away from it)
	local Z = V(high.X, 0, high.Z).Unit
	local X = Vector3.yAxis:Cross(Z)
	return K.part(parent, name, size, RO * F * CFrame.fromMatrix(centre, X, Vector3.yAxis), K.look(nil, col, Enum.Material.SmoothPlastic), "WedgePart")
end

-- A shipping container, 8 wide x 8.5 tall x 20 long along local Z, floor-centred at F: a body, ribs proud on the long
-- sides, corner posts one size up, a door end with two leaves and lock bars, a roof set 0.1 in.
local function container(name, F, col)
	if not clear(name, F, V(-4.3, 0.2, -10.3), V(4.3, 8.6, 10.3)) then
		return nil
	end
	local m = K.model(fill, name)
	part(m, "Body", F, V(-4, 0, -10), V(4, 8.5, 10), col, Enum.Material.Metal)
	part(m, "Roof", F, V(-3.9, 8.5, -9.9), V(3.9, 8.6, 9.9), SLATE_D, Enum.Material.Metal)
	for z = -8.75, 8.75, 1.25 do
		for _, sx in { -1, 1 } do
			part(m, "Rib", F, V(sx * 4, 0.6, z - 0.2), V(sx * 4.18, 7.9, z + 0.2), col:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Metal)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, "Post", F, V(sx * 4.3, 0, sz * 10.3), V(sx * 3.7, 8.6, sz * 9.7), SLATE_D, Enum.Material.Metal)
		end
		-- sills along the bottom and top of each long side
		part(m, "Sill", F, V(sx * 4.22, 0, -9.7), V(sx * 3.95, 0.6, 9.7), SLATE_D, Enum.Material.Metal)
		part(m, "Sill", F, V(sx * 4.22, 7.9, -9.7), V(sx * 3.95, 8.5, 9.7), SLATE_D, Enum.Material.Metal)
	end
	-- the door end (+Z): two leaves with a seam, four lock bars
	part(m, "Door", F, V(-3.65, 0.6, 10), V(-0.05, 7.9, 10.12), col:Lerp(Color3.new(1, 1, 1), 0.05), Enum.Material.Metal)
	part(m, "Door", F, V(0.05, 0.6, 10), V(3.65, 7.9, 10.12), col:Lerp(Color3.new(1, 1, 1), 0.05), Enum.Material.Metal)
	for _, x in { -2.6, -1.0, 1.0, 2.6 } do
		part(m, "LockBar", F, V(x - 0.08, 0.8, 10.12), V(x + 0.08, 7.7, 10.24), rgb(120, 124, 132), Enum.Material.Metal)
	end
	-- a teal stripe along the long sides (the range's accent)
	for _, sx in { -1, 1 } do
		part(m, "Stripe", F, V(sx * 4.18, 6.6, -8.8), V(sx * 4.22, 6.9, 8.8), K.dim(TEAL, 0.35), Enum.Material.SmoothPlastic)
	end
	return m
end

local function crate(name, F, size, col)
	local h = size.Y
	if not clear(name, F, V(-size.X / 2 - 0.1, 0.2, -size.Z / 2 - 0.1), V(size.X / 2 + 0.1, h + 0.1, size.Z / 2 + 0.1)) then
		return nil
	end
	local m = K.model(fill, name)
	part(m, "Body", F, V(-size.X / 2, 0, -size.Z / 2), V(size.X / 2, h, size.Z / 2), col, Enum.Material.SmoothPlastic)
	-- a darker band round the middle, 0.08 proud; the lid one step in
	part(m, "Band", F, V(-size.X / 2 - 0.08, h * 0.42, -size.Z / 2 - 0.08), V(size.X / 2 + 0.08, h * 0.58, size.Z / 2 + 0.08), DARK)
	part(m, "Lid", F, V(-size.X / 2 + 0.2, h, -size.Z / 2 + 0.2), V(size.X / 2 - 0.2, h + 0.12, size.Z / 2 - 0.2), col:Lerp(Color3.new(1, 1, 1), 0.1))
	return m
end

-- A jersey barrier along local X (`len` long): a wide foot, a narrower wall, chamfered (wedge) shoulders.
local function barrier(name, F, len)
	if not clear(name, F, V(-len / 2, 0.2, -1.1), V(len / 2, 2.9, 1.1)) then
		return nil
	end
	local m = K.model(fill, name)
	part(m, "Foot", F, V(-len / 2, 0, -1), V(len / 2, 0.7, 1), BLOCK, Enum.Material.Concrete)
	part(m, "Wall", F, V(-len / 2, 0.7, -0.45), V(len / 2, 2.8, 0.45), STRUCT, Enum.Material.Concrete)
	for _, sz in { -1, 1 } do
		wedgeAt(m, "Shoulder", F, V(0, 1.05, sz * 0.725), V(len, 0.7, 0.55), V(0, 0, -sz), BLOCK)
	end
	return m
end

local function dummyAt(name, x, y, z, toward)
	local template = yard.Dummies:FindFirstChild("Dummy6")
	local bot = template:FindFirstChild("TrainingBot")
	local r = bot.HumanoidRootPart.Position
	local look = bot.HumanoidRootPart.CFrame.LookVector * V(1, 0, 1)
	local m = template:Clone()
	m.Name = name
	m.WorldPivot = CFrame.lookAt(V(r.X, 0, r.Z), V(r.X, 0, r.Z) + look.Unit)
	local pos = RO * V(x, y, z)
	local to = RO * V(toward.X, y, toward.Z)
	m:PivotTo(CFrame.lookAt(pos, V(to.X, pos.Y, to.Z)))
	m.Parent = fill
end

-- 1. SOUTH-WEST: two containers side by side (doors facing the yard), a third stacked on the west one; a stair up
--    the east side on to the east one's roof (8.6), a dummy on the stacked one (a high, open target).
local c1 = container("ContainerA", CFrame.new(-118, 0, 92), SLATE)
local c2 = container("ContainerB", CFrame.new(-108.4, 0, 92), rgb(96, 100, 108))
if c1 and c2 then
	container("ContainerTop", CFrame.new(-118, 8.6, 90), SLATE)
	local sm = K.model(fill, "ContainerStair")
	local steps, rise, run, z0 = 12, 8.6, 13, 104
	if clear("ContainerStair", CFrame.new(), V(-104.2, 0.2, z0 - run), V(-100.6, rise, z0)) then
		for i = 1, steps do
			part(sm, "Step", CFrame.new(), V(-104.2, 0, z0 - run * (i - 1) / steps), V(-100.6, rise * i / steps, z0 - run * i / steps), if i % 2 == 0 then STRUCT else BLOCK, Enum.Material.Plastic, true)
		end
	end
	dummyAt("DummyContainer", -118, 17.2, 90, V(0, 0, 40))
end

-- 2. CENTRE: a raised platform (deck 6) with a ramp up its south side and low cover on top ------------------------------
local P = CFrame.new()
if clear("Platform", P, V(-62, 0.2, 40), V(-32, 6, 60)) then
	local pm = K.model(fill, "Platform")
	part(pm, "Base", P, V(-62, 0, 40), V(-32, 6, 60), STRUCT, Enum.Material.Plastic, true)
	part(pm, "Trim", P, V(-62.15, 4.9, 39.85), V(-31.85, 5.6, 60.15), DARK)
	part(pm, "Glow", P, V(-61, 5.15, 39.8), V(-33, 5.35, 39.85), K.dim(TEAL, 0.45), Enum.Material.Neon)
	-- the ramp: one wedge, tall side against the platform
	if clear("Ramp", P, V(-52, 0.2, 60.2), V(-42, 5.9, 74)) then
		wedgeAt(pm, "Ramp", P, V(-47, 3, 67), V(10, 6, 14), V(0, 0, -1), BLOCK)
	end
	for _, x in { -59, -41 } do
		barrier("PlatformCover", CFrame.new(x, 6, 46), 6)
	end
	dummyAt("DummyPlatform", -47, 6, 52, V(0, 0, 110))
end

-- 3. CRATES and BARRIERS on the bare floor -------------------------------------------------------------------------------
local CRATE = rgb(150, 146, 136)
-- { x, z, y (0 = floor), yaw, size }
for i, c in {
	{ 30, -92, 0, 0, V(4, 4, 4) },
	{ 34.5, -92, 0, 0, V(4, 4, 4) },
	{ 32, -92, 4.12, 8, V(4, 3, 4) },
	{ 44, -78, 0, 20, V(6, 3, 4) },
	{ -88, 52, 0, 0, V(4, 4, 4) },
	{ -84, 55, 0, 30, V(4, 4, 4) },
	{ 2, 22, 0, 15, V(6, 3, 4) },
	{ -8, 25, 0, 0, V(4, 4, 4) },
	{ 42, 98, 0, 10, V(4, 4, 4) },
} do
	crate("Crate" .. i, CFrame.new(c[1], c[3], c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), c[5], CRATE)
end
for i, b in {
	{ 25, 102, 0 }, { -45, 100, 0 }, { -78, 10, 90 }, { 52, -32, 90 }, { -5, -2, 30 }, { 18, 62, 0 },
} do
	barrier("Barrier" .. i, CFrame.new(b[1], 0, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0), 6)
end

-- 4. AIR TARGETS ----------------------------------------------------------------------------------------------------------
local kit = SS.V5Kit:FindFirstChild("AirTarget")
assert(kit, "run the AirTarget kit build first (ServerStorage.V5Kit.AirTarget)")
local targets = K.model(range, "Targets")
local ALCOVE = V(0, 8, 118)
-- { x, y, z, drift, period, face (nil: the alcove) }
for i, t in {
	{ 0, 18, 0, 8, 5 }, { -40, 22, 30, 0, 5 }, { 35, 16, 55, 6, 4 }, { -82, 26, -20, 0, 5 },
	{ -62, 14, 75, 5, 4.5 }, { 20, 28, -40, 0, 5 }, { -20, 32, -70, 10, 7 }, { 50, 20, -70, 0, 5 },
	{ -100, 34, 40, 0, 5 }, { -10, 12, 92, 4, 3.5 }, { -110, 22, -95, 6, 6 },
	{ 100, 10, 0, 0, 5, V(100, 6, 120) }, { 112, 16, -60, 5, 5, V(112, 6, 120) }, { 88, 22, -95, 0, 5, V(88, 6, 120) },
} do
	local pos = V(t[1], t[2], t[3])
	local face = t[6] or ALCOVE
	local F = CFrame.new()
	if clear("Target" .. i, F, pos - V(2.4, 2.4, 2.4), pos + V(2.4, 2.4, 2.4)) then
		local m = kit:Clone()
		m.Name = "Target" .. i
		local home = RO * CFrame.lookAt(pos, V(face.X, pos.Y, face.Z))
		m:PivotTo(home)
		m:SetAttribute("Home", home)
		m:SetAttribute("Drift", t[4])
		m:SetAttribute("Period", t[5])
		m:SetAttribute("Phase", (i * 1.37) % 5)
		CS:AddTag(m, "RangeTarget")
		m.Parent = targets
	end
end

local n = 0
for _, d in fill:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
table.insert(report, ("fill: %d parts; targets: %d"):format(n, #targets:GetChildren()))
return table.concat(report, "\n")
