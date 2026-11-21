--!nocheck
-- Lobby V5 LOCKER V3 (vault/02 Art/Lobby V5 Plan.md, "Locker v3"). Owner 2026-11-21 on v2: "the locker is now too
-- empty ... making it bigger and making kind of areas ... the armorer should kind of be in a better place ... rivals
-- ... have that like kind of like circle with different guns around. I want something similar".
-- The room grows 30 east (x 54..134; nothing was behind its back wall) and gets four areas:
-- * LOCKERS (entrance half): the rows stay, the hero plinth (LockerZone, your rifle turning) gets a floor inlay ring;
-- * GUN CIRCLE (new middle, x 114): a medallion in the floor and eight lit pedestals in a ring, each turning one gun
--   (each player's own skin, LobbyGunDisplays "Stand");
-- * WEAPON WALL: moved to the new back wall (x 133);
-- * ARMORY COUNTER (north wall): the Armorer behind a service counter with a gun rack behind him; supplies along the
--   south wall.
-- Needs V5Kit.LobbyKit, LobbyWay, LobbyProps, V5_Pipe8. Re-runnable for the new parts (the shell move is guarded).

local SS = game:GetService("ServerStorage")
local W = require(SS.V5Kit.LobbyWay:Clone())
local P = require(SS.V5Kit.LobbyProps:Clone())
local K = W.K
local V = Vector3.new
local L = K.L
local CYAN = K.AREA.locker.col
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local locker = workspace.LobbyV5.Shell.Locker
local room, polish, arm = locker.Room, locker.Polish, locker.ArmoryV2
local DX = 30 -- how far the back wall moves east
local O = K.O
local GUN = K.look("Metal 2022", rgb(78, 80, 86))
local up = CFrame.Angles(0, 0, math.rad(90)) -- V5_Pipe8 axis X -> vertical

-- 1. GROW THE ROOM (once) -----------------------------------------------------------------------------------------------
if not locker:GetAttribute("GrownEast") then
	local function stretch(p, dx) -- lengthen along world x by dx, keeping the west end
		p.Size = p.Size + V(dx, 0, 0)
		p.CFrame = p.CFrame + V(dx / 2, 0, 0)
	end
	for _, n in { "Floor", "Ceiling", "Wall_N", "Wall_S" } do
		stretch(room[n], DX)
	end
	room.Wall_E.CFrame = room.Wall_E.CFrame + V(DX, 0, 0)
	for _, c in room.Soffit:GetChildren() do
		if c:IsA("BasePart") then
			local w = c.Size.X > c.Size.Z -- runs along x
			local x = c.Position.X - O.X
			if w then
				stretch(c, DX)
			elseif x > 79 then
				c.CFrame = c.CFrame + V(DX, 0, 0)
			end
		end
	end
	for _, n in { "Belt_N", "Belt_S" } do
		stretch(polish[n], DX)
	end
	-- beams, ducts and lights over the new half: copies of the eastern ones
	for _, f in { polish.Beams, polish.Ducts } do
		for _, c in f:GetChildren() do
			if c:IsA("BasePart") then
				local cf, s = c.CFrame, c.Size
				local ex = math.abs(cf.RightVector.X) * s.X
					+ math.abs(cf.UpVector.X) * s.Y
					+ math.abs(cf.LookVector.X) * s.Z
				if ex > 10 then -- runs along the room: lengthen it (along whichever local axis points along x)
					local ax = if math.abs(cf.RightVector.X) > 0.9
						then V(1, 0, 0)
						elseif math.abs(cf.UpVector.X) > 0.9 then V(0, 1, 0)
						else V(0, 0, 1)
					c.Size = s + ax * DX
					c.CFrame = cf + V(DX / 2, 0, 0)
				elseif (c.Position.X - O.X) > 76 then -- a cross piece over the east half: copy it over the new half
					local n = c:Clone()
					n.CFrame = n.CFrame + V(DX, 0, 0)
					n.Parent = f
				end
			end
		end
	end
	for _, c in room:GetChildren() do
		if
			(c.Name == "CeilingLight" and c:GetPivot().Position.X - O.X > 80)
			or (c.Name == "Fill" and c.Position.X - O.X > 80)
		then
			local n = c:Clone()
			if n:IsA("Model") then
				n:PivotTo(n:GetPivot() + V(24, 0, 0))
			else
				n.CFrame = n.CFrame + V(24, 0, 0)
			end
			n.Parent = room
		end
	end
	arm.WeaponWall:PivotTo(arm.WeaponWall:GetPivot() + V(DX, 0, 0))
	locker:SetAttribute("GrownEast", DX)
end

-- 2. new areas live in ArmoryV2.Areas --------------------------------------------------------------------------------
local old = arm:FindFirstChild("Areas")
if old then
	old:Destroy()
end
local areas = K.model(arm, "Areas")
local function mesh(parent, name, h, d, at, y, lk)
	return K.mesh(parent, name, "V5_Pipe8", V(h, d, d), CFrame.new(O + at + V(0, y, 0)) * up, lk)
end

-- 2a. LOCKERS: an inlay ring round the hero plinth (the loadout spot)
local inl = K.model(areas, "LoadoutInlay")
mesh(inl, "Inlay", 0.06, 11, V(78, 0, 0), 0.03, L.plate)
local ring = mesh(
	inl,
	"Ring",
	0.05,
	11.6,
	V(78, 0, 0),
	0.025,
	K.look(nil, K.dim(CYAN, 0.5), Enum.Material.Neon)
)
ring.CanCollide = false

-- 2b. GUN CIRCLE
local gc = K.model(areas, "GunCircle")
local C = V(114, 0, 0)
mesh(gc, "Medallion", 0.08, 23, C, 0.04, L.plate)
local outer =
	mesh(gc, "OuterRing", 0.06, 24, C, 0.03, K.look(nil, K.dim(CYAN, 0.5), Enum.Material.Neon))
outer.CanCollide = false
mesh(gc, "InnerField", 0.1, 8, C, 0.05, K.look("Metal 2022", rgb(62, 64, 69)))
local inner =
	mesh(gc, "InnerRing", 0.09, 8.6, C, 0.045, K.look(nil, K.dim(CYAN, 0.5), Enum.Material.Neon))
inner.CanCollide = false
local GUNS = { "Vandal", "Operator", "Spectre", "Bucky", "Odin", "Phantom", "Sheriff", "Knife" }
for i, gun in GUNS do
	local a = (i - 1) * math.pi / 4 + math.pi / 8
	local at = C + V(math.cos(a) * 10, 0, math.sin(a) * 10)
	local m = K.model(gc, "Pedestal_" .. gun)
	mesh(m, "Base", 0.5, 3.4, at, 0.25, L.dark)
	mesh(m, "Shaft", 2.6, 2.3, at, 1.8, GUN)
	local glow =
		mesh(m, "Glow", 0.12, 2.36, at, 2.6, K.look(nil, K.dim(CYAN, 0.5), Enum.Material.Neon))
	glow.CanCollide = false
	mesh(m, "Cap", 0.25, 2.9, at, 3.225, L.steel)
	K.point(glow, CYAN, 0.5, 6)
	K.gunAnchor(
		m,
		"Stand_" .. gun,
		at + V(0, 4.8, 0),
		gun,
		"Stand",
		V(1, 0, 0),
		V(0, 0, 1),
		2.4,
		gun == "Knife" and 3.2 or 4.2,
		18
	)
end
-- a downlight over the circle's middle
local lens = K.ghost(
	K.lpart(CFrame.new(O + C), gc, "CircleLight", V(-1.2, 17.9, -1.2), V(1.2, 18.0, 1.2), L.white)
)
K.spot(gc, lens, Enum.NormalId.Bottom, K.WHITE, 1.4, 22, 110)

-- 2c. ARMORY COUNTER on the north wall, the Armorer behind it, a rack of guns behind him
local ct = K.model(areas, "ArmoryCounter")
local FC = K.frame(V(113, 0, -22), V(0, 0, 1)) -- x = world x, z = out of the north wall into the room
K.lpart(FC, ct, "Plinth", V(-8, 0, 3.3), V(8, 0.35, 6.6), L.dark)
K.lpart(FC, ct, "Body", V(-7.8, 0.35, 3.5), V(7.8, 3.4, 6.4), GUN)
K.lpart(FC, ct, "Top", V(-8.2, 3.4, 3.3), V(8.2, 3.75, 6.7), L.steel)
for _, x in { -5.2, 0, 5.2 } do -- recessed front panels with shadow gaps
	K.lpart(FC, ct, "Panel", V(x - 2.4, 0.7, 6.4), V(x + 2.4, 3.0, 6.48), L.plate)
end
local lip = K.lpart(
	FC,
	ct,
	"LightLip",
	V(-7.6, 3.1, 6.48),
	V(7.6, 3.18, 6.52),
	K.look(nil, K.dim(CYAN, 0.5), Enum.Material.Neon)
)
lip.CanCollide = false
K.lpart(FC, ct, "Rack", V(-7, 4.0, 0), V(7, 11.5, 0.25), K.look("Metal 2022", rgb(96, 97, 98)))
K.lpart(FC, ct, "RackFrame", V(-7.3, 3.7, 0), V(7.3, 4.0, 0.5), L.plate)
K.lpart(FC, ct, "RackFrame", V(-7.3, 11.5, 0), V(7.3, 11.8, 0.5), L.plate)
local rl = K.ghost(K.lpart(FC, ct, "RackLight", V(-6, 11.38, 0.35), V(6, 11.5, 0.75), L.white))
K.spot(ct, rl, Enum.NormalId.Bottom, K.WHITE, 1.2, 9, 95)
for i, gun in { "Guardian", "Marshal" } do
	K.gunAnchor(
		ct,
		"Wall_" .. gun,
		(FC * V(0, 6.0 + (i - 1) * 3.2, 0.25)) - O,
		gun,
		"Wall",
		V(1, 0, 0),
		V(0, 0, 1),
		2.6,
		9
	)
end
local npc = locker:FindFirstChild("Armorer")
if npc then
	local y = npc:GetPivot().Position.Y
	local at = FC * V(0, 0, 1.6)
	npc:PivotTo(CFrame.lookAt(V(at.X, y, at.Z), V(at.X, y, at.Z + 1)))
end

-- 2d. SUPPLIES along the south wall, and the corner props from v2 moved to the new back corners
local sup = K.model(areas, "Supplies")
local function put(name, scheme, x, z, yaw, y)
	local m =
		P.place(sup, name, scheme, CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
	m.Name = name
end
put("Pallet", "Charcoal", 108, 18.6, 0)
put("WeaponCrate", "Olive", 108, 18.6, 90, 0.52)
put("FlatCase", "Charcoal", 108, 18.6, 92, 0.52 + 2.98)
put("CargoBox", "Olive", 116.5, 19.4, 10)
put("AmmoCan", "Olive", 116.5, 19.3, -5, 3.68)
put("Drum", "Charcoal", 121.5, 20.2, 0)
put("Drum", "Hazard", 123.9, 19.6, 25)
for _, m in arm.Props:GetChildren() do
	local p = m:GetPivot()
	if (p.Position.X - O.X) < 110 then
		m:PivotTo(p + V(DX - 1.5, 0, 0))
	end
end

return arm
