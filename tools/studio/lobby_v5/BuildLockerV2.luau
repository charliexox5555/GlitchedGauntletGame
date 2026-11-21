--!nocheck
-- Lobby V5 LOCKER V2 (vault/02 Art/Lobby V5 Plan.md, "Hub 9/10 pass"). Owner 2026-11-21: the locker is "cluttered
-- ... needs more room, and more detail like rivals. the gun stands dont show much ... floating and unaligned parts",
-- the part-built kitbags "make the map look unprofessional", "remove the benches".
-- * clears the centre: old Armory (cabinets, consoles, melee vitrine), GunWall cages, Workbench (keeps LockerZone),
--   Polish.Gear (kitbags, helmets, stacks) and the locker-row benches;
-- * one WEAPON WALL across the back wall (x 103, z -15..15): long guns on the top tier (SNIPERS | RIFLES | HEAVY),
--   short guns and the knife on the bottom tier (SMGS | SHOTGUNS | SIDEARMS | MELEE); a light backboard so the dark
--   guns read, guns big (Fill = section width), a lens strip over every tier, class names on the bands above;
-- * a hero plinth in the middle (octagonal, V5_Pipe8) with your rifle turning over it, LockerZone kept there;
-- * supply props (V5Kit.Props) in the two back corners.
-- Needs V5Kit.LobbyKit, LobbyWay, LobbyProps. Re-runnable: removes Locker.ArmoryV2 first.

local SS = game:GetService("ServerStorage")
local W = require(SS.V5Kit.LobbyWay:Clone())
local P = require(SS.V5Kit.LobbyProps:Clone())
local K = W.K
local V = Vector3.new
local L = K.L
local CYAN = K.AREA.locker.col
local BONE = Color3.fromRGB(236, 232, 222)
local locker = workspace.LobbyV5.Shell.Locker

-- 0. clear ------------------------------------------------------------------------------------------------------------
local zone = locker:FindFirstChild("LockerZone", true)
for _, n in { "Armory", "GunWall", "ArmoryV2" } do
	local m = locker:FindFirstChild(n)
	if m then
		m:Destroy()
	end
end
local gear = locker.Polish:FindFirstChild("Gear")
if gear then
	gear:Destroy()
end
for _, row in locker.Lockers:GetChildren() do
	for _, c in row:GetChildren() do
		if c.Name == "Bench" then
			c:Destroy()
		end
	end
end
local arm = K.model(locker, "ArmoryV2")
if zone then
	zone.Parent = arm
end
local wb = locker:FindFirstChild("Workbench")
if wb then
	wb:Destroy()
end

-- 1. WEAPON WALL --------------------------------------------------------------------------------------------------------
local FB = K.frame(V(103, 0, 0), V(-1, 0, 0)) -- x = world +z, z = into the room, origin on the wall face
local wall = K.model(arm, "WeaponWall")
local board = K.look("Metal 2022", Color3.fromRGB(150, 148, 142))
local gun = K.look("Metal 2022", Color3.fromRGB(78, 80, 86))
local HW = 15
local Y0, YS0, YS1, YH0, YH1 = 2.4, 7.5, 8.3, 14.4, 15.3 -- plinth top, shelf band, head band

K.lpart(FB, wall, "Plinth", V(-HW - 0.6, 0, 0), V(HW + 0.6, Y0, 1.3), L.dark)
K.ltri(FB, wall, "PlinthSlope", V(0, Y0, 1.0), V(0, 1, 0), 0.3, V(0, 0, -1), 0.6, V(1, 0, 0), 2 * HW + 1.2, L.dark)
K.lpart(FB, wall, "Board", V(-HW, Y0, 0), V(HW, YH0, 0.2), board)
for _, s in { -1, 1 } do
	K.lpart(FB, wall, "Stile", V(s > 0 and HW or -HW - 0.6, 0, 0), V(s > 0 and HW + 0.6 or -HW, YH1, 1.25), gun)
end
K.lpart(FB, wall, "Head", V(-HW - 0.6, YH0, 0), V(HW + 0.6, YH1, 1.35), L.plate)
K.lpart(FB, wall, "Shelf", V(-HW, YS0, 0.2), V(HW, YS1, 1.15), L.plate)
-- mullions: three long-gun sections on top, four short ones below
for _, x in { -5, 5 } do
	K.lpart(FB, wall, "Mullion", V(x - 0.18, YS1, 0.2), V(x + 0.18, YH0, 0.95), gun)
end
for _, x in { -7.5, 0, 7.5 } do
	K.lpart(FB, wall, "Mullion", V(x - 0.18, Y0, 0.2), V(x + 0.18, YS0, 0.95), gun)
end
-- lens strips under the head and the shelf, spots down onto the guns
for _, t in
	{
		{ YH0, -HW, -5 },
		{ YH0, -5, 5 },
		{ YH0, 5, HW },
		{ YS0, -HW, -7.5 },
		{ YS0, -7.5, 0 },
		{ YS0, 0, 7.5 },
		{ YS0, 7.5, HW },
	}
do
	local lens =
		K.ghost(K.lpart(FB, wall, "Lens", V(t[2] + 0.6, t[1] - 0.06, 0.45), V(t[3] - 0.6, t[1], 0.85), L.white))
	K.spot(wall, lens, Enum.NormalId.Bottom, K.WHITE, 1.6, 9, 95)
end

-- class names on the band above each section
local function label(text, x0, x1, y0, y1, z)
	local p = K.lpart(FB, wall, "Label_" .. text, V(x0, y0, z), V(x1, y1, z + 0.04), L.plate)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 80
	g.LightInfluence = 0
	g.Brightness = 1.2
	g.Parent = p
	local tick = Instance.new("Frame")
	tick.BorderSizePixel = 0
	tick.BackgroundColor3 = CYAN
	tick.AnchorPoint = Vector2.new(0, 0.5)
	tick.Position = UDim2.new(0, 10, 0.5, 0)
	tick.Size = UDim2.new(0, 8, 0.5, 0)
	tick.Parent = g
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = K.RUBIK_B
	t.Text = text
	t.TextColor3 = BONE
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Position = UDim2.new(0, 28, 0.18, 0)
	t.Size = UDim2.new(1, -36, 0.64, 0)
	t.Parent = g
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 44
	c.Parent = t
end
local midH, midS = (YH0 + YH1) / 2, (YS0 + YS1) / 2
for _, s in { { "SNIPERS", -15 }, { "RIFLES", -5 }, { "HEAVY", 5 } } do
	label(s[1], s[2] + 0.5, s[2] + 4.0, midH - 0.28, midH + 0.28, 1.35)
end
for _, s in { { "SMGS", -15 }, { "SHOTGUNS", -7.5 }, { "SIDEARMS", 0 }, { "MELEE", 7.5 } } do
	label(s[1], s[2] + 0.5, s[2] + 4.0, midS - 0.26, midS + 0.26, 1.15)
end

-- guns: wall mounts, barrel along +x (world +z), the side looking into the room
local function hubPos(v)
	return (FB * v) - K.O
end
local barrel, face = FB:VectorToWorldSpace(V(1, 0, 0)), FB:VectorToWorldSpace(V(0, 0, 1))
local function mount(name, x, y, fill, scale)
	K.gunAnchor(wall, "Wall_" .. name, hubPos(V(x, y, 0.2)), name, "Wall", barrel, face, scale or 3.0, fill)
end
mount("Operator", -10, 13.2, 8.6)
mount("Outlaw", -10, 11.3, 8.0)
mount("Marshal", -10, 9.4, 8.0)
mount("Vandal", -2.5, 12.5, 4.3)
mount("Phantom", 2.5, 12.5, 4.3)
mount("Guardian", -2.5, 10.0, 4.3)
mount("Bulldog", 2.5, 10.0, 4.3)
mount("Odin", 10, 12.4, 8.4)
mount("Ares", 10, 9.9, 8.4)
mount("Spectre", -11.25, 6.0, 5.6)
mount("Stinger", -11.25, 3.8, 5.6)
mount("Bucky", -3.75, 6.0, 6.0)
mount("Judge", -3.75, 3.8, 6.0)
mount("Classic", 1.9, 5.9, 2.8, 2.4)
mount("Ghost", 5.6, 5.9, 2.8, 2.4)
mount("Sheriff", 1.9, 3.7, 2.8, 2.4)
mount("Shorty", 5.6, 3.7, 2.8, 2.4)
mount("Knife", 11.25, 4.9, 4.6, 3.0)

-- 2. HERO PLINTH in the middle (the loadout spot) ----------------------------------------------------------------------
local hero = K.model(arm, "HeroPlinth")
local C = V(78, 0, 0) + K.O
local up = CFrame.Angles(0, 0, math.rad(90)) -- V5_Pipe8 axis X -> vertical
K.mesh(hero, "Base", "V5_Pipe8", V(0.9, 5.2, 5.2), CFrame.new(C + V(0, 0.45, 0)) * up, L.dark)
K.mesh(hero, "Collar", "V5_Pipe8", V(0.25, 4.6, 4.6), CFrame.new(C + V(0, 1.02, 0)) * up, gun)
K.mesh(hero, "Top", "V5_Pipe8", V(0.2, 4.2, 4.2), CFrame.new(C + V(0, 1.22, 0)) * up, L.steel)
local ring = K.mesh(
	hero,
	"GlowRing",
	"V5_Pipe8",
	V(0.08, 5.5, 5.5),
	CFrame.new(C + V(0, 0.06, 0)) * up,
	K.look(nil, K.dim(CYAN, 0.45), Enum.Material.Neon)
)
ring.CanCollide = false
K.point(ring, CYAN, 0.6, 7)
local lamp = K.ghost(K.lpart(CFrame.new(C), hero, "HeroLight", V(-0.3, 1.25, -0.3), V(0.3, 1.3, 0.3), L.white))
K.spot(hero, lamp, Enum.NormalId.Top, K.WHITE, 1.4, 6, 60)
K.gunAnchor(hero, "Stand_Vandal", (C - K.O) + V(0, 3.0, 0), "Vandal", "Stand", V(1, 0, 0), V(0, 0, 1), 2.2, 4.6, 24)

-- 3. supply props in the back corners -----------------------------------------------------------------------------------
local props = K.model(arm, "Props")
local O = CFrame.new(K.O)
local function put(name, scheme, x, z, yaw, y)
	local m = P.place(props, name, scheme, CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
	m.Name = name
	return m
end
-- north corner (z -): crates delivered for the armory
put("Pallet", "Charcoal", 99.3, -18.6, 0)
put("WeaponCrate", "Olive", 99.3, -18.6, 90, 0.52)
put("AmmoCan", "Olive", 99.0, -18.1, 75, 0.52 + 2.98)
put("AmmoCan", "Charcoal", 99.0, -19.6, 95, 0.52 + 2.98)
-- south corner (z +): the Armorer out of the way of the wall, beside a tool chest and a drum
put("ToolChest", "Charcoal", 101.9, 18.0, 90)
put("Drum", "Charcoal", 101.6, 20.9, 0)
local npc = locker:FindFirstChild("Armorer")
if npc then
	local y = npc:GetPivot().Position.Y
	local at = K.O + V(98.6, 0, 19.0)
	npc:PivotTo(CFrame.lookAt(V(at.X, y, at.Z), V(at.X - 1, y, at.Z - 1)))
end

return arm
