--!nocheck
-- Lobby V5 LOCKER V4 (vault/02 Art/Lobby V5 Plan.md, "Final lobby cleanup"). Owner 2026-11-21 on v3: "I don't like how
-- the things are spaced out so much ... you walk in and there's not really anything ... just one stand, and the gun
-- stands are a little further. And I think they need to look a little better ... I don't think the armor[er] should
-- be behind a stand ... like rivals where you should just be standing in there".
-- * the room comes back 12 (back wall x 121; it grew 30 in v3, now 18);
-- * the GUN CIRCLE moves to just inside the doors (centre x 80) with the hero plinth (your rifle, the LockerZone) in
--   its middle; the pedestals are the modelled V5_Pedestal (tools/blender/lobby_v5/v5_pedestal.py, asset
--   117837262151466);
-- * the Armorer stands free between the circle and the weapon wall; the counter and its rack go;
-- * weapon wall on the new back wall, supplies along the south wall, the v2 crates in the back corners.

local SS = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")
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
local O = K.O
local up = CFrame.Angles(0, 0, math.rad(90))

-- 1. pull the back wall in to x 121 (once) -------------------------------------------------------------------------
local grown = locker:GetAttribute("GrownEast") or 0
local BACK = -(grown - 18) -- negative: the shrink
if grown ~= 18 and BACK ~= 0 then
	local function stretch(p, dx)
		p.Size = p.Size + V(dx, 0, 0)
		p.CFrame = p.CFrame + V(dx / 2, 0, 0)
	end
	for _, n in { "Floor", "Ceiling", "Wall_N", "Wall_S" } do
		stretch(room[n], BACK)
	end
	room.Wall_E.CFrame = room.Wall_E.CFrame + V(BACK, 0, 0)
	for _, c in room.Soffit:GetChildren() do
		if c:IsA("BasePart") then
			if c.Size.X > c.Size.Z then
				stretch(c, BACK)
			elseif c.Position.X - O.X > 79 then
				c.CFrame = c.CFrame + V(BACK, 0, 0)
			end
		end
	end
	-- the belts: one clean piece each again (v3 split the north one round the counter's rack)
	for _, c in polish:GetChildren() do
		if c.Name == "Belt_N" then
			c:Destroy()
		end
	end
	stretch(polish.Belt_S, BACK)
	local bn = polish.Belt_S:Clone()
	bn.Name = "Belt_N"
	bn.CFrame = bn.CFrame - V(0, 0, 2 * (bn.Position.Z - O.Z))
	bn.Parent = polish
	local wallX = 121 + O.X
	for _, f in { polish.Beams, polish.Ducts } do
		for _, c in f:GetChildren() do
			if c:IsA("BasePart") then
				local cf, s = c.CFrame, c.Size
				local ex = math.abs(cf.RightVector.X) * s.X
					+ math.abs(cf.UpVector.X) * s.Y
					+ math.abs(cf.LookVector.X) * s.Z
				if ex > 10 then
					local ax = if math.abs(cf.RightVector.X) > 0.9
						then V(1, 0, 0)
						elseif math.abs(cf.UpVector.X) > 0.9 then V(0, 1, 0)
						else V(0, 0, 1)
					c.Size = s + ax * BACK
					c.CFrame = cf + V(BACK / 2, 0, 0)
				elseif c.Position.X + ex / 2 > wallX - 0.5 then
					c:Destroy()
				end
			end
		end
	end
	arm.WeaponWall:PivotTo(arm.WeaponWall:GetPivot() + V(BACK, 0, 0))
	locker:SetAttribute("GrownEast", 18)
end

-- 2. new areas ---------------------------------------------------------------------------------------------------------
local old = arm:FindFirstChild("Areas")
if old then
	old:Destroy()
end
local areas = K.model(arm, "Areas")
local function mesh(parent, name, h, d, at, y, lk)
	return K.mesh(parent, name, "V5_Pipe8", V(h, d, d), CFrame.new(O + at + V(0, y, 0)) * up, lk)
end
-- the pedestal model
local ped = SS.V5Kit:FindFirstChild("Pedestal")
if not ped then
	local raw = InsertService:LoadAsset(117837262151466)
	ped = Instance.new("Model")
	ped.Name = "Pedestal"
	local LOOK = {
		Trim = { rgb(40, 42, 46), Enum.Material.SmoothPlastic },
		Body = { rgb(78, 80, 86), Enum.Material.Metal },
		Hardware = { rgb(150, 154, 160), Enum.Material.Metal },
		Accent = { K.dim(CYAN, 0.55), Enum.Material.Neon },
	}
	for _, p in raw:GetDescendants() do
		if p:IsA("MeshPart") then
			local role = string.match((string.gsub(p.Name, "%.%d+$", "")), "_(%a+)$")
			p.Name = role or p.Name
			p.Anchored, p.CanTouch = true, false
			p.CanCollide = role ~= "Accent"
			if LOOK[role] then
				p.Color, p.Material = LOOK[role][1], LOOK[role][2]
			end
			p.Parent = ped
		end
	end
	raw:Destroy()
	local cf, size = ped:GetBoundingBox()
	ped.WorldPivot = CFrame.new(cf.Position - V(0, size.Y / 2, 0))
	ped:PivotTo(CFrame.new())
	ped.Parent = SS.V5Kit
end

-- 2a. GUN CIRCLE just inside the doors, the hero plinth (loadout spot) in its middle
local gc = K.model(areas, "GunCircle")
local C = V(80, 0, 0)
mesh(gc, "Medallion", 0.08, 23, C, 0.04, L.plate)
local outer =
	mesh(gc, "OuterRing", 0.06, 24, C, 0.03, K.look(nil, K.dim(CYAN, 0.5), Enum.Material.Neon))
outer.CanCollide = false
local hero = arm:FindFirstChild("HeroPlinth")
if hero then
	local hp = hero:GetPivot().Position
	local lift = if hero:GetAttribute("OnMedallion") then 0 else 0.08 -- stand it on the medallion
	hero:PivotTo(hero:GetPivot() + V(O.X + C.X - hp.X, lift, O.Z + C.Z - hp.Z))
	hero:SetAttribute("OnMedallion", true)
end
local zone = arm:FindFirstChild("LockerZone")
if zone then
	zone.CFrame = CFrame.new(O + C + V(0, zone.Position.Y, 0)) * zone.CFrame.Rotation
end
for i, gun in { "Vandal", "Operator", "Spectre", "Bucky", "Odin", "Phantom", "Sheriff", "Knife" } do
	local a = (i - 1) * math.pi / 4 + math.pi / 8
	local at = C + V(math.cos(a) * 9.4, 0.08, math.sin(a) * 9.4)
	local m = ped:Clone()
	m.Name = "Pedestal_" .. gun
	m:PivotTo(CFrame.new(O + at) * CFrame.Angles(0, -a, 0))
	m.Parent = gc
	K.point(m.Accent, CYAN, 0.45, 6)
	K.gunAnchor(
		m,
		"Stand_" .. gun,
		at + V(0, 4.7, 0),
		gun,
		"Stand",
		V(1, 0, 0),
		V(0, 0, 1),
		2.4,
		gun == "Knife" and 3.2 or 4.2,
		18
	)
end
local lens = K.ghost(
	K.lpart(CFrame.new(O + C), gc, "CircleLight", V(-1.2, 17.9, -1.2), V(1.2, 18.0, 1.2), L.white)
)
K.spot(gc, lens, Enum.NormalId.Bottom, K.WHITE, 1.4, 22, 110)

-- 2b. the Armorer, standing free between the circle and the weapon wall, looking at the doors
local npc = locker:FindFirstChild("Armorer")
if npc then
	local y = npc:GetPivot().Position.Y
	local at = O + V(100, 0, -7)
	npc:PivotTo(CFrame.lookAt(V(at.X, y, at.Z), V(at.X - 1, y, at.Z + 0.35)))
end

-- 2c. supplies along the south wall; the v2 crates in the back corners
local sup = K.model(areas, "Supplies")
local function put(name, scheme, x, z, yaw, y)
	local m =
		P.place(sup, name, scheme, CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
	m.Name = name
end
put("Pallet", "Charcoal", 100, 18.6, 0)
put("WeaponCrate", "Olive", 100, 18.6, 90, 0.52)
put("FlatCase", "Charcoal", 100, 18.6, 92, 0.52 + 2.98)
put("CargoBox", "Olive", 107.5, 19.4, 10)
put("AmmoCan", "Olive", 107.5, 19.3, -5, 3.68)
put("Drum", "Charcoal", 111.6, 20.2, 0)
if not arm.Props:GetAttribute("BackIn") then -- they moved +28.5 in v3; the wall came back 12
	for _, m in arm.Props:GetChildren() do
		m:PivotTo(m:GetPivot() - V(12.5, 0, 0))
	end
	arm.Props:SetAttribute("BackIn", true)
end

return arm
