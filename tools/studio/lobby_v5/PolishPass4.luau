--!nocheck
-- Lobby V5 final cleanup, range part (2026-11-21, vault/02 Art/Lobby V5 Plan.md, "Final lobby cleanup"). Owner: "I
-- didn't really want a sign and a pedestal he was on ... just being a different color", "I like the moving one ...
-- improve on that a bit", "all the NPCs are kind of facing the same ... direction ... they should be around the map,
-- facing different areas". Re-runnable.

local K = require(game.ServerStorage.V5Kit.LobbyWay:Clone()).K
local CS = game:GetService("CollectionService")
local V = Vector3.new
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local yard = workspace.LobbyV5.Range.Yard
local RO = CFrame.new(0, 0, 2600)
local HAZARD = "rbxassetid://75158634706115"
local GUN, DARK, STEEL = rgb(78, 80, 86), rgb(40, 42, 46), rgb(150, 154, 160)
local PURPLE = rgb(181, 140, 255)
local function paint(parent, name, a, b, col, mat)
	return K.lpart(RO, parent, name, a, b, K.look(nil, col, mat or Enum.Material.SmoothPlastic))
end
local function bodyFacing(m) -- the dummy's own facing (its root part), which may differ from the pad model's pivot
	local root = m:FindFirstChild("HumanoidRootPart", true)
	return root and root.CFrame.LookVector or m:GetPivot().LookVector
end
local function faceBody(m, dx, dz)
	local lv = bodyFacing(m)
	local cur = math.atan2(-lv.X, -lv.Z)
	local want = math.atan2(-dx, -dz)
	local p = m:GetPivot()
	m:PivotTo(CFrame.new(p.Position) * CFrame.Angles(0, want - cur, 0) * p.Rotation)
end

-- 1. DAMAGE dummy: no stage, no board; it keeps its orange and its tag
local dmg = yard:FindFirstChild("DamageDummy")
if dmg then
	for _, c in dmg:GetChildren() do
		if c.Name ~= "Dummy" then
			c:Destroy()
		end
	end
	local d = dmg:FindFirstChild("Dummy")
	if d and not dmg:GetAttribute("Grounded") then
		d:PivotTo(d:GetPivot() - V(0, 1.0, 0)) -- it stood on the 1.0 stage
		dmg:SetAttribute("Grounded", true)
	end
	if d then
		faceBody(d, 1, 0.4)
	end
end

-- 2. MOVING dummy: a proper track (bed, sleepers, rails, end stops with hazard faces) and a carriage on wheels
local mv = yard:FindFirstChild("MovingDummy")
local keep = mv and mv:FindFirstChild("Carriage") and mv.Carriage:FindFirstChild("Dummy")
if keep then
	keep.Parent = nil
end
if mv then
	mv:Destroy()
end
mv = K.model(yard, "MovingDummy")
local RZ, X0, X1 = 72, 16, 60
paint(mv, "Bed", V(X0, 0, RZ - 1.8), V(X1, 0.12, RZ + 1.8), DARK)
for x = X0 + 1.25, X1 - 1.25, 2.5 do
	paint(mv, "Sleeper", V(x - 0.35, 0.12, RZ - 1.5), V(x + 0.35, 0.32, RZ + 1.5), rgb(60, 62, 68))
end
for _, z in { RZ - 1.0, RZ + 0.7 } do
	paint(mv, "Rail", V(X0 + 0.5, 0.32, z), V(X1 - 0.5, 0.62, z + 0.3), STEEL, Enum.Material.Metal)
end
for _, e in { { X0 - 1.6, X0, Enum.NormalId.Right }, { X1, X1 + 1.6, Enum.NormalId.Left } } do
	paint(mv, "EndStop", V(e[1], 0, RZ - 2), V(e[2], 1.8, RZ + 2), GUN, Enum.Material.Metal)
	local band = paint(
		mv,
		"EndBand",
		V(if e[3] == Enum.NormalId.Right then e[2] else e[1] - 0.04, 0.6, RZ - 1.8),
		V(if e[3] == Enum.NormalId.Right then e[2] + 0.04 else e[1], 1.4, RZ + 1.8),
		Color3.new(1, 1, 1)
	)
	local t = Instance.new("Texture")
	t.Texture, t.Face, t.StudsPerTileU, t.StudsPerTileV = HAZARD, e[3], 1.6, 1.6
	t.Parent = band
end
local car = K.model(mv, "Carriage")
local CX = 38
for _, x in { CX - 1.4, CX + 1.4 } do -- wheels, one over each rail
	for _, z in { RZ - 1.0, RZ + 0.7 } do
		paint(
			car,
			"Wheel",
			V(x - 0.45, 0.62, z - 0.1),
			V(x + 0.45, 0.98, z + 0.4),
			DARK,
			Enum.Material.Metal
		)
	end
end
paint(
	car,
	"Frame",
	V(CX - 1.9, 0.98, RZ - 1.4),
	V(CX + 1.9, 1.18, RZ + 1.4),
	DARK,
	Enum.Material.Metal
)
paint(
	car,
	"Deck",
	V(CX - 2.1, 1.18, RZ - 1.6),
	V(CX + 2.1, 1.48, RZ + 1.6),
	GUN,
	Enum.Material.Metal
)
for _, z in { RZ - 1.68, RZ + 1.6 } do
	local s = paint(
		car,
		"Glow",
		V(CX - 2.0, 1.22, z),
		V(CX + 2.0, 1.44, z + 0.08),
		K.dim(PURPLE, 0.55),
		Enum.Material.Neon
	)
	s.CanCollide = false
end
if keep then
	keep.Parent = car
	local p = keep:GetPivot()
	keep:PivotTo(CFrame.new(RO * V(CX, 0, RZ)) * CFrame.new(0, p.Position.Y, 0) * p.Rotation)
	local foot = keep:FindFirstChild("LeftFoot", true)
	if foot then
		keep:PivotTo(
			keep:GetPivot() + V(0, (RO * V(0, 1.48, 0)).Y - (foot.Position.Y - foot.Size.Y / 2), 0)
		)
	end
end
CS:AddTag(car, "RangeMovingDummy")
car:SetAttribute("From", X0 + 3)
car:SetAttribute("To", X1 - 3)
car:SetAttribute("Speed", 10)

-- 3. the yard dummies face different ways (along paths, at each other, out of doorways)
local dirs = {
	Dummy1 = { 1, 0 }, -- hangar roof, looking along the bridge
	Dummy2 = { -1, 0.3 }, -- lookout roof, looking back over the bridge
	Dummy3 = { 1, -1 }, -- tower top
	Dummy4 = { 0.4, -1 }, -- bunker roof, toward the hall
	Dummy5 = { 1, 0 }, -- in the hangar, at its east door
	Dummy6 = { 0, 1 }, -- in the U-wall, out of its mouth
	Dummy7 = { 0.2, -1 }, -- down the long hall
	Dummy8 = { 1, 1 },
	Dummy9 = { -1, 0.2 },
	Dummy10 = { 1, -0.5 },
}
for name, d in dirs do
	local m = yard.Dummies:FindFirstChild(name)
	if m then
		faceBody(m, d[1], d[2])
	end
end

-- 4. whole-lobby pass (FlickerFix scan + floating scan over Hub, Shop, Locker, Duels, Range): three left, fixed in
--    place: the Season Pass blast door's Core shrunk 0.1 (it shared faces with the leaves), the range alcove's
--    MouthGlow raised 0.2 to touch the casing head, the exit gate's Sign set flat on the alcove's back wall.
--    Result: 0 flicker, 0 floating.
