--!nocheck
-- Lobby V5 LOCKER ARMORY (vault/02 Art/Lobby V5 Plan.md, "Locker armory"). ONE-TIME placement record (needs
-- V5Kit.LobbyKit + LobbyWay). Owner 2026-11-21: "the locker also needs sections for the guns ... the stands need to
-- look better. They kind of look dull". Every gun now sits in a section for its class (Config/Weapons `class`):
-- * back wall (x 103): three glass-fronted, lit cabinets: SNIPERS (3 rows), RIFLES (2 x 2), HEAVY (2 rows), split by
--   steel columns, each with its class sign and a hood light over every row;
-- * centre: the four flat tables become sloped display consoles (plinth, body, a 15° felt top between steel cheeks,
--   a front lip, a canopy lamp on two posts, the class sign on the fascia): SIDEARMS, SMGS, SHOTGUNS; and a MELEE
--   vitrine with the knife turning.
-- Guns stay `LobbyGunDisplay` anchors (each player's own skins). Also fixes the two wainscot slopes on the west wall,
-- which were turned the wrong way and stuck 6 studs out through the wall into the vestibule.

local SS = game:GetService("ServerStorage")
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local L = K.L
local CYAN = K.AREA.locker.col
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local locker = workspace.LobbyV5.Shell.Locker
local function box(Fb, parent, name, a, b, lk)
	return K.lpart(Fb, parent, name, a, b, lk)
end
local function hubPos(Fb, v)
	return (Fb * v) - K.O
end
local function wdir(Fb, v)
	return Fb:VectorToWorldSpace(v)
end

-- 0. clear the old tables, the pegboard wall and the workbench knife ------------------------------------------------
if locker:FindFirstChild("Tables") then
	locker.Tables:Destroy()
end
for _, c in locker.GunWall:GetChildren() do
	if not (c.Name == "Cage_N" or c.Name == "Cage_S" or c.Name == "WallSpot") then
		c:Destroy()
	end
end
local knife = locker.Workbench:FindFirstChild("Stand_Knife", true)
if knife then
	knife:Destroy()
end
local old = locker:FindFirstChild("Armory")
if old then
	old:Destroy()
end
local arm = K.model(locker, "Armory")
-- the west wall's wainscot slopes, rebuilt along the wall
for _, p in locker.Room:GetChildren() do
	if p.Name == "WainscotSlope" then
		p:Destroy()
	end
end
for _, z in { { -22, -9 }, { 9, 22 } } do
	K.tri(
		locker.Room,
		"WainscotSlope",
		V(55, 3, (z[1] + z[2]) / 2),
		V(0, 1, 0),
		0.5,
		V(1, 0, 0),
		0.5,
		V(0, 0, 1),
		z[2] - z[1],
		L.wains
	)
end

-- 1. BACK WALL CABINETS ----------------------------------------------------------------------------------------------
local panel = K.look("Metal 2022", rgb(62, 64, 69))
local function cabinet(name, zc, w, rows, cols, guns, fill)
	local FB = K.frame(V(103, 0, zc), V(-1, 0, 0)) -- x = world +z, z = into the room
	local m = K.model(arm, "Cabinet_" .. name)
	local hw = w / 2
	box(FB, m, "Plinth", V(-hw, 0, 0), V(hw, 2.6, 1.3), L.dark)
	K.ltri(
		FB,
		m,
		"PlinthSlope",
		V(0, 2.6, 1.0),
		V(0, 1, 0),
		0.3,
		V(0, 0, -1),
		0.6,
		V(1, 0, 0),
		w,
		L.dark
	)
	box(FB, m, "Back", V(-hw, 2.6, 0), V(hw, 13.0, 0.15), panel)
	box(FB, m, "Head", V(-hw - 0.1, 13.0, 0), V(hw + 0.1, 13.5, 1.25), L.dark)
	K.ltri(
		FB,
		m,
		"HeadCap",
		V(0, 13.5, 0.45),
		V(0, 1, 0),
		0.25,
		V(0, 0, 1),
		0.8,
		V(1, 0, 0),
		w + 0.2,
		L.dark
	)
	for _, sx in { -1, 1 } do
		box(FB, m, "Stile", V(sx * (hw - 0.35), 2.6, 0.15), V(sx * hw, 13.0, 0.95), L.steel)
	end
	local y0, y1 = 2.85, 13.0
	local rh = (y1 - y0) / rows
	local cw = w / cols
	for r = 1, rows - 1 do
		local y = y0 + r * rh
		box(FB, m, "Rail", V(-hw, y - 0.12, 0.15), V(hw, y + 0.12, 0.9), L.steel)
	end
	box(FB, m, "Sill", V(-hw, 2.6, 0.15), V(hw, 2.85, 0.95), L.steel)
	for c = 1, cols - 1 do
		local x = -hw + c * cw
		box(FB, m, "Mullion", V(x - 0.12, y0, 0.15), V(x + 0.12, y1, 0.9), L.steel)
	end
	local i = 0
	for r = 1, rows do
		for c = 1, cols do
			i += 1
			local gun = guns[i]
			if gun then
				local xa, xb = -hw + (c - 1) * cw, -hw + c * cw
				local ya, yb = y1 - r * rh, y1 - (r - 1) * rh
				local xc = (xa + xb) / 2
				box(
					FB,
					m,
					"Hood",
					V(xa + 0.35, yb - 0.32, 0.15),
					V(xb - 0.35, yb - 0.12, 0.85),
					L.dark
				)
				local lens = K.ghost(
					box(
						FB,
						m,
						"Lens",
						V(xa + 0.7, yb - 0.38, 0.35),
						V(xb - 0.7, yb - 0.32, 0.75),
						L.white
					)
				)
				K.spot(m, lens, Enum.NormalId.Bottom, K.WHITE, 1.0, 4.5, 75)
				box(FB, m, "Tag", V(xc - 1.0, ya + 0.3, 0.15), V(xc + 1.0, ya + 0.7, 0.24), L.plate)
				box(
					FB,
					m,
					"TagBar",
					V(xc - 0.9, ya + 0.35, 0.24),
					V(xc + 0.9, ya + 0.42, 0.28),
					K.paint(K.dim(CYAN, 0.2))
				)
				K.gunAnchor(
					m,
					"Wall_" .. gun,
					hubPos(FB, V(xc, (ya + yb) / 2 + 0.15, 0.2)),
					gun,
					"Wall",
					wdir(FB, V(1, 0, 0)),
					wdir(FB, V(0, 0, 1)),
					2.0,
					math.min(fill, xb - xa - 1.0)
				)
			end
		end
	end
	local glass = box(FB, m, "Glass", V(-hw + 0.35, 2.85, 0.95), V(hw - 0.35, 13.0, 1.0), L.glass)
	glass.Transparency = 0.88
	glass.Reflectance = 0.06
	glass.CastShadow = false
	W.sign(
		FB * CFrame.new(0, 15.25, 1.0),
		m,
		{ -- under the soffit band (15.5), clear of the head cap
			name = "Sign_" .. name,
			word = name,
			icon = K.AREA.locker.icon,
			col = CYAN,
			h = 1.3,
			mount = "wall",
			standoff = 1.0,
		}
	)
	return m
end
cabinet("SNIPERS", -10.3, 9.4, 3, 1, { "Operator", "Outlaw", "Marshal" }, 7.6)
cabinet("RIFLES", 0, 8.8, 2, 2, { "Vandal", "Phantom", "Guardian", "Bulldog" }, 3.6)
cabinet("HEAVY", 10.3, 9.4, 2, 1, { "Odin", "Ares" }, 7.6)
for _, z in { -5, 5 } do
	local FB = K.frame(V(103, 0, z), V(-1, 0, 0))
	local c = K.model(arm, "Column")
	box(FB, c, "Flange", V(-0.4, 0, 0), V(0.4, 15.5, 0.2), L.steel)
	box(FB, c, "Web", V(-0.1, 0, 0.2), V(0.1, 15.5, 0.9), L.dark)
	box(FB, c, "FlangeFront", V(-0.4, 0, 0.9), V(0.4, 15.5, 1.1), L.steel)
	box(FB, c, "BasePlate", V(-0.6, 0, -0.0), V(0.6, 0.25, 1.4), L.dark)
	for _, y in { 4, 9, 14 } do
		box(FB, c, "Bolt", V(-0.12, y - 0.12, 1.1), V(0.12, y + 0.12, 1.18), L.dark)
	end
end

-- 2. DISPLAY CONSOLES ------------------------------------------------------------------------------------------------
local felt = K.look(nil, rgb(30, 33, 38), Enum.Material.Fabric)
local gunmetal = K.look("Metal 2022", rgb(78, 80, 86)) -- bright steel read white under the canopy lamp
local RISE, DEPTH, HW = 1.07, 4.0, 4.0
local n = V(0, DEPTH, RISE).Unit -- the top's normal (tilts toward the viewer)
local function topAt(x, z) -- a point on the felt
	return V(x, 2.6 + (DEPTH / 2 - z) * RISE / DEPTH, z) + n * 0.07
end
local function console(name, x, z, facing, guns)
	local Fc = K.frame(V(x, 0, z), facing)
	local m = K.model(arm, "Console_" .. name)
	box(Fc, m, "Plinth", V(-HW - 0.2, 0, -2.2), V(HW + 0.2, 0.35, 2.2), L.dark)
	box(Fc, m, "Body", V(-HW, 0.35, -2), V(HW, 2.6, 2), K.look("Metal 2022", rgb(56, 58, 63)))
	K.ltri(
		Fc,
		m,
		"Slope",
		V(0, 2.6, -2),
		V(0, 1, 0),
		RISE,
		V(0, 0, 1),
		DEPTH,
		V(1, 0, 0),
		2 * HW,
		K.look("Metal 2022", rgb(56, 58, 63))
	)
	K.part(
		m,
		"Felt",
		V(2 * HW - 0.5, 0.06, DEPTH * 1.03 - 0.4),
		Fc * CFrame.fromMatrix(topAt(0, 0) - n * 0.04, Vector3.xAxis, n),
		felt
	)
	for _, sx in { -1, 1 } do
		box(Fc, m, "Cheek", V(sx * HW, 0.35, -2.05), V(sx * (HW + 0.15), 2.75, 2.05), gunmetal)
		K.ltri(
			Fc,
			m,
			"CheekTop",
			V(sx * (HW + 0.075), 2.75, -2.05),
			V(0, 1, 0),
			RISE,
			V(0, 0, 1),
			4.1,
			V(1, 0, 0),
			0.15,
			gunmetal
		)
	end
	box(Fc, m, "Lip", V(-HW, 2.5, 1.95), V(HW, 2.8, 2.12), L.steel)
	box(Fc, m, "Kick", V(-HW + 0.1, 0.35, 1.95), V(HW - 0.1, 0.6, 2.05), K.paint(K.dim(CYAN, 0.2)))
	-- canopy lamp on two posts at the back
	for _, sx in { -1, 1 } do
		box(
			Fc,
			m,
			"Post",
			V(sx * (HW - 0.1) - 0.12, 3.6, -2.15),
			V(sx * (HW - 0.1) + 0.12, 6.75, -1.91),
			gunmetal
		)
	end
	box(Fc, m, "Crossbar", V(-HW, 6.6, -2.3), V(HW, 6.95, -1.8), L.dark)
	box(Fc, m, "Hood", V(-HW + 0.2, 6.7, -1.8), V(HW - 0.2, 6.92, 0.4), L.dark)
	box(Fc, m, "HoodLip", V(-HW + 0.2, 6.5, 0.25), V(HW - 0.2, 6.92, 0.4), gunmetal)
	local lens =
		K.ghost(box(Fc, m, "Lens", V(-HW + 0.6, 6.64, -1.3), V(HW - 0.6, 6.7, 0.0), L.white))
	K.spot(m, lens, Enum.NormalId.Bottom, K.WHITE, 0.6, 7, 80)
	W.sign(Fc * CFrame.new(0, 2.25, 2.6), m, {
		name = "Sign_" .. name,
		word = name,
		icon = K.AREA.locker.icon,
		col = CYAN,
		h = 1.3,
	})
	for _, g in guns do
		K.gunAnchor(
			m,
			"Lay_" .. g[1],
			hubPos(Fc, topAt(g[2], g[3])),
			g[1],
			"Lay",
			wdir(Fc, V(1, 0, 0)),
			wdir(Fc, n),
			2.0,
			g[4]
		)
		local p = topAt(g[2], g[3] + 0.85)
		K.part(m, "Plate", V(1.3, 0.05, 0.3), Fc * CFrame.fromMatrix(p, Vector3.xAxis, n), L.plate)
	end
	return m
end
console("SIDEARMS", 64, -9, V(0, 0, 1), {
	{ "Classic", -1.9, 0.75, 2.2 },
	{ "Ghost", 1.9, 0.75, 2.2 },
	{ "Sheriff", -1.9, -0.95, 2.2 },
	{ "Shorty", 1.9, -0.95, 2.2 },
})
console("SMGS", 64, 9, V(0, 0, -1), { { "Stinger", -1.9, 0, 3.4 }, { "Spectre", 1.9, 0, 3.4 } })
console("SHOTGUNS", 92, -9, V(0, 0, 1), { { "Bucky", 0, 0.75, 5.6 }, { "Judge", 0, -0.95, 4.6 } })

-- 3. MELEE VITRINE: an octagon plinth, a glass case on steel posts, the knife turning under a lamp -----------------
local S = require(SS.V5Kit.LobbySigns:Clone())
do
	local Fv = K.frame(V(92, 0, 9), V(0, 0, -1))
	local m = K.model(arm, "Vitrine_MELEE")
	local function oct(name, d, y0, y1, lk)
		return S.octagon(Fv * CFrame.Angles(-math.pi / 2, 0, 0), m, name, d, y0, y1, lk)
	end
	oct("Base", 4.4, 0, 0.4, L.dark)
	oct("Body", 3.6, 0.4, 2.8, K.look("Metal 2022", rgb(56, 58, 63)))
	oct("Band", 3.8, 2.8, 2.95, K.paint(K.dim(CYAN, 0.2)))
	oct("Top", 3.4, 2.95, 3.2, L.steel)
	local glass = box(Fv, m, "Glass", V(-1.45, 3.2, -1.45), V(1.45, 5.6, 1.45), L.glass)
	glass.Transparency = 0.86
	glass.CastShadow = false
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(
				Fv,
				m,
				"Post",
				V(sx * 1.5 - 0.09, 3.2, sz * 1.5 - 0.09),
				V(sx * 1.5 + 0.09, 5.75, sz * 1.5 + 0.09),
				L.steel
			)
		end
	end
	box(Fv, m, "Lid", V(-1.65, 5.6, -1.65), V(1.65, 5.85, 1.65), L.dark)
	local lens = K.ghost(box(Fv, m, "Lens", V(-0.8, 5.54, -0.8), V(0.8, 5.6, 0.8), L.white))
	K.spot(m, lens, Enum.NormalId.Bottom, K.WHITE, 0.9, 4, 70)
	K.gunAnchor(
		m,
		"Stand_Knife",
		hubPos(Fv, V(0, 4.4, 0)),
		"Knife",
		"Stand",
		wdir(Fv, V(1, 0, 0)),
		wdir(Fv, V(0, 0, 1)),
		1.8,
		2.0,
		24
	)
	W.sign(
		Fv * CFrame.new(0, 2.35, 2.3),
		m,
		{ name = "Sign_MELEE", word = "MELEE", icon = K.AREA.locker.icon, col = CYAN, h = 1.1 }
	)
end

-- the Armorer 1.6 toward the room: his tail accessory reached into the snipers' cabinet
local a = locker:FindFirstChild("Armorer")
if a and not a:GetAttribute("MovedForArmory") then
	a:PivotTo(a:GetPivot() + V(-1.6, 0, 0))
	a:SetAttribute("MovedForArmory", true)
end

local c = 0
for _, d in arm:GetDescendants() do
	if d:IsA("BasePart") then
		c += 1
	end
end
return ("armory: %d parts"):format(c)
