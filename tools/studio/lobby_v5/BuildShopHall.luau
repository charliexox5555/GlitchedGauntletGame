--!nocheck
-- Lobby V5 SHOP V2, THE SHELL (vault/02 Art/Lobby V5 Plan.md, "Shop V2: the market hall"). ONE-TIME placement record
-- run through the Studio MCP (needs ServerStorage.V5Kit.LobbyKit + LobbySigns). Owner 2026-11-21: "I want the same
-- idea that Rivals has ... that big hallway splitting off into other two sections ... leads to more stuff just to
-- explore". Replaces the walk-in shop (BuildShop.luau) and its gateway.
-- Plan: a big portal from the hub (compress) → a 30-wide, 22-high hall with two display bays a side (release) → a
-- 26-high junction whose back corners are cut at 45° → two low passages (compress) → the Item Shop wing (left) and
-- the Season Pass wing (right). This script builds the structure, floors, ceilings, steel and light; the bay
-- displays, the feature, the wings' fit-out and the signs are BuildShopFit.luau.
-- Frame F: origin on the hub floor at the old gate face (world x -40); x = right as seen from the hub (world -Z),
-- z = toward the hub (world +X); walking in = -z. Every wall is built in its own frame: x along the wall, z toward
-- the room, the visible face at z = 0.

local SS = game:GetService("ServerStorage")
local S = require(SS.V5Kit.LobbySigns:Clone())
local K = S.K
local V = Vector3.new
local Y = Vector3.yAxis
local L = K.L
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local LK = {
	wall = K.look("Lobby_ConcreteBoard", rgb(116, 114, 110)),
	upper = K.look("Concrete-02a", rgb(72, 72, 74)),
	wains = L.wains,
	trim = L.trim,
	ceil = K.look("Concrete-02a", rgb(56, 56, 58)),
	floor = K.look("Lobby_ConcretePolished", rgb(96, 94, 91)),
	aisle = K.look("Lobby_ConcretePolished", rgb(60, 59, 58)),
	bay = K.look("Concrete-02a", rgb(48, 48, 51)),
	stage = K.look("Metal 2022", rgb(44, 45, 49)),
}
local GOLD = K.AREA.shop.col
local goldPaint = K.paint(rgb(196, 150, 42))
local goldGlow = K.neon(K.dim(GOLD, 0.42))
local lampLens = K.neon(rgb(156, 134, 102)) -- warm glow below the neon clip
local DOWN = rgb(255, 236, 214)
local F = K.frame(V(-40, 0, 0), V(1, 0, 0))

-- 0. clear the old shop and its gateway ------------------------------------------------------------------------
local shell = workspace.LobbyV5.Shell
local gates = shell.Hub.Gateways
for _, o in { shell:FindFirstChild("Shop"), gates:FindFirstChild("Gateway_Shop") } do
	if o then
		o:Destroy()
	end
end
local shop = K.model(shell, "Shop")

-- helpers -------------------------------------------------------------------------------------------------------
local function box(Fb, parent, name, a, b, lk)
	return K.lpart(Fb, parent, name, a, b, lk)
end
local function wedge(Fb, parent, name, p, u, a, v, b, w, th, lk)
	return K.ltri(Fb, parent, name, p, u, a, v, b, w, th, lk)
end
-- a wall frame from A to B (Fb-local, y 0): x along the wall, z toward `inside`
local function wallFrame(Fb, A, B, inside)
	local d = (B - A).Unit
	local z = d:Cross(Y)
	if z:Dot(inside - (A + B) / 2) < 0 then
		A, B = B, A
		d = -d
	end
	return Fb * CFrame.fromMatrix(A, d, Y), (B - A).Magnitude, A, d
end
-- a wall: body (th thick behind the face), battered wainscot, panel joints, belt ledge, darker upper band.
-- o = { h, belt, th, openings = {{p0, p1, top}} (Fb-local points on the wall line), ext0, ext1 }
local function wall(Fb, parent, name, A, B, inside, o)
	local Fw, len, A2, d = wallFrame(Fb, A, B, inside)
	local m = K.model(parent, name)
	local h, th, belt = o.h, o.th or 1.5, o.belt
	local x0, x1 = -(o.ext0 or 0), len + (o.ext1 or 0)
	local ops = {}
	for _, op in o.openings or {} do
		local a, b = (op[1] - A2):Dot(d), (op[2] - A2):Dot(d)
		assert(op[3] < belt, "opening above the belt")
		table.insert(ops, { math.min(a, b), math.max(a, b), op[3] })
	end
	table.sort(ops, function(p, q)
		return p[1] < q[1]
	end)
	local spans, cur = {}, x0
	for _, op in ops do
		if op[1] > cur then
			table.insert(spans, { cur, op[1] })
		end
		cur = op[2]
	end
	if x1 > cur then
		table.insert(spans, { cur, x1 })
	end
	for _, s in spans do
		local a, b = s[1], s[2]
		box(Fw, m, "Body", V(a, 0, -th), V(b, belt, 0), LK.wall)
		box(Fw, m, "Wainscot", V(a, 0, 0), V(b, 3, 0.45), LK.wains)
		wedge(
			Fw,
			m,
			"WainscotCap",
			V((a + b) / 2, 3, 0),
			V(0, 1, 0),
			0.45,
			V(0, 0, 1),
			0.45,
			V(1, 0, 0),
			b - a,
			LK.wains
		)
		local n = math.floor((b - a) / 6)
		for i = 1, n - 1 do
			local x = a + i * (b - a) / n
			box(Fw, m, "Joint", V(x - 0.12, 3.45, 0), V(x + 0.12, belt, 0.1), LK.upper)
		end
	end
	for _, op in ops do
		box(Fw, m, "Head", V(op[1], op[3], -th), V(op[2], belt, 0), LK.wall)
	end
	box(Fw, m, "Upper", V(x0, belt, -th), V(x1, h, 0), LK.upper)
	box(Fw, m, "Belt", V(x0, belt, 0), V(x1, belt + 0.5, 0.5), LK.trim)
	wedge(
		Fw,
		m,
		"BeltCap",
		V((x0 + x1) / 2, belt + 0.5, 0),
		V(0, 1, 0),
		0.5,
		V(0, 0, 1),
		0.5,
		V(1, 0, 0),
		x1 - x0,
		LK.trim
	)
	return Fw, len, m
end
-- a pilaster standing at c (Fb-local, floor), facing `out`: plinth, shaft, steel capital with bolts; an optional
-- narrower head from the capital to `top`; an optional bar lamp on its face
local function pilaster(Fb, parent, name, c, out, o)
	local w, d, cap = o.w or 2.4, o.d or 1.4, o.cap
	local Fp = Fb * CFrame.fromMatrix(c, Y:Cross(out), Y)
	local m = K.model(parent, name)
	box(Fp, m, "Shaft", V(-w / 2, 0, -d / 2), V(w / 2, cap, d / 2), LK.trim)
	box(
		Fp,
		m,
		"Plinth",
		V(-w / 2 - 0.25, 0, -d / 2 - 0.25),
		V(w / 2 + 0.25, 2, d / 2 + 0.25),
		L.darkConc
	)
	wedge(
		Fp,
		m,
		"PlinthSlope",
		V(0, 2, d / 2),
		V(0, 1, 0),
		0.25,
		V(0, 0, 1),
		0.25,
		V(1, 0, 0),
		w + 0.5,
		L.darkConc
	)
	box(
		Fp,
		m,
		"Capital",
		V(-w / 2 - 0.3, cap, -d / 2 - 0.3),
		V(w / 2 + 0.3, cap + 0.5, d / 2 + 0.3),
		L.steel
	)
	for _, x in { -w / 2 + 0.35, w / 2 - 0.35 } do
		box(
			Fp,
			m,
			"Bolt",
			V(x - 0.12, cap + 0.13, d / 2 + 0.3),
			V(x + 0.12, cap + 0.37, d / 2 + 0.38),
			L.dark
		)
	end
	if o.top then
		box(
			Fp,
			m,
			"Head",
			V(-w / 2 + 0.2, cap + 0.5, -d / 2 + 0.2),
			V(w / 2 - 0.2, o.top, d / 2 - 0.2),
			LK.trim
		)
	end
	if o.lamp then
		local lm = K.model(m, "BarLamp")
		local z = d / 2
		box(Fp, lm, "Back", V(-0.5, 5, z), V(0.5, 13, z + 0.15), L.dark)
		for _, sx in { -1, 1 } do
			box(Fp, lm, "Rail", V(sx * 0.35, 5, z + 0.15), V(sx * 0.5, 13, z + 0.42), L.dark)
		end
		box(Fp, lm, "CapTop", V(-0.5, 12.75, z + 0.15), V(0.5, 13, z + 0.42), L.steel)
		box(Fp, lm, "CapBottom", V(-0.5, 5, z + 0.15), V(0.5, 5.25, z + 0.42), L.steel)
		local lens = K.ghost(
			box(Fp, lm, "Lens", V(-0.35, 5.25, z + 0.15), V(0.35, 12.75, z + 0.3), lampLens)
		)
		K.point(lens, K.WARM, 0.7, 13)
	end
	return Fp, m
end
-- a steel I-beam from a to b (Fb-local, horizontal), bottom at yb: flanges, web, stiffeners, end plates
local function ibeam(Fb, parent, name, a, b, yb, depth, wd)
	local dv = V(b.X - a.X, 0, b.Z - a.Z)
	local Fi = Fb * CFrame.fromMatrix(V(a.X, yb, a.Z), dv.Unit, Y)
	local len = dv.Magnitude
	local m = K.model(parent, name)
	box(Fi, m, "FlangeB", V(0, 0, -wd / 2), V(len, 0.25, wd / 2), L.dark)
	box(Fi, m, "Web", V(0, 0.25, -0.14), V(len, depth - 0.25, 0.14), L.dark)
	box(Fi, m, "FlangeT", V(0, depth - 0.25, -wd / 2), V(len, depth, wd / 2), L.dark)
	local n = math.max(2, math.floor(len / 4))
	for i = 1, n - 1 do
		local x = i * len / n
		for _, s in { -1, 1 } do
			box(
				Fi,
				m,
				"Stiffener",
				V(x - 0.08, 0.25, s * 0.14),
				V(x + 0.08, depth - 0.25, s * (wd / 2 - 0.05)),
				L.dark
			)
		end
	end
	for _, x in { 0, len - 0.2 } do
		box(
			Fi,
			m,
			"EndPlate",
			V(x, 0.25, -wd / 2 - 0.1),
			V(x + 0.2, depth - 0.25, wd / 2 + 0.1),
			L.steel
		)
	end
	return m
end
-- a ceiling downlight: a top block, a skirt round a lens set back 0.3, a SpotLight
local function downlight(Fb, parent, name, x, z, y, sz, bright, range, angle)
	local m = K.model(parent, name)
	local h = sz / 2
	box(Fb, m, "Top", V(x - h, y - 0.25, z - h), V(x + h, y, z + h), L.dark)
	box(
		Fb,
		m,
		"Trim",
		V(x - h - 0.15, y - 0.1, z - h - 0.15),
		V(x + h + 0.15, y, z + h + 0.15),
		L.steel
	)
	box(Fb, m, "SkirtA", V(x - h, y - 0.6, z - h), V(x + h, y - 0.25, z - h + 0.15), L.dark)
	box(Fb, m, "SkirtB", V(x - h, y - 0.6, z + h - 0.15), V(x + h, y - 0.25, z + h), L.dark)
	box(
		Fb,
		m,
		"SkirtC",
		V(x - h, y - 0.6, z - h + 0.15),
		V(x - h + 0.15, y - 0.25, z + h - 0.15),
		L.dark
	)
	box(
		Fb,
		m,
		"SkirtD",
		V(x + h - 0.15, y - 0.6, z - h + 0.15),
		V(x + h, y - 0.25, z + h - 0.15),
		L.dark
	)
	local lens = K.ghost(
		box(
			Fb,
			m,
			"Lens",
			V(x - h + 0.15, y - 0.32, z - h + 0.15),
			V(x + h - 0.15, y - 0.25, z + h - 0.15),
			L.white
		)
	)
	K.spot(m, lens, Enum.NormalId.Bottom, DOWN, bright, range, angle)
	return m
end
-- an opening's casing on one face of a wall (frame Fo: x across the opening, z toward the viewer, face at z = 0):
-- jambs and a head proud by `p`, cut top corners matching the tunnel
local function casing(Fo, parent, name, hw, top, cut, p, lk)
	local m = K.model(parent, name)
	for _, sd in { -1, 1 } do
		box(Fo, m, "Jamb", V(sd * hw, 0, 0), V(sd * (hw + 1.0), top - cut + 0.5, p), lk)
		S.bar(
			Fo,
			m,
			"Diag",
			V(sd * (hw + 0.5), top - cut + 0.2),
			V(sd * (hw - cut + 0.2), top + 0.5),
			1.0,
			0,
			p,
			lk
		)
	end
	box(Fo, m, "Head", V(-(hw - cut + 0.3), top, 0), V(hw - cut + 0.3, top + 1.0, p), lk)
	return m
end
-- cut corners along a tunnel (frame Ft, x across, z along), from z0 to z1
local function tunnelCuts(Ft, parent, hw, top, cut, z0, z1, lk)
	for _, sd in { -1, 1 } do
		wedge(
			Ft,
			parent,
			"Cut",
			V(sd * hw, top, (z0 + z1) / 2),
			V(0, -1, 0),
			cut,
			V(-sd, 0, 0),
			cut,
			V(0, 0, 1),
			z1 - z0,
			lk
		)
	end
end

-- 1. PORTAL from the hub: the gateway family (Duels / Locker), bigger ----------------------------------------------
local G = {
	name = "Shop",
	W = 20,
	H = 15,
	P = 4.5,
	D = 12,
	T = 19,
	crown = 1.5,
	crownD = 3,
	cut = 2.5,
	cutD = 13.5,
	area = K.AREA.shop,
	word = "SHOP",
	sub = "ITEMS  ·  SEASON PASS",
	badgeH = 6,
	thY0 = 0,
	thY1 = 0.06,
	emblem = "bag",
	signH = 4.6,
	gateId = "S-03",
	caution = {
		{ text = "NOTICE", size = 30, heavy = true },
		{ text = "NO", size = 20 },
		{ text = "REFUNDS", size = 20 },
	},
}
local gate = K.gateway(F, gates, G)
for _, c in gate:GetChildren() do
	if c.Name:match("^Badge_") or c.Name == "WashLamp" then
		c:Destroy()
	end
end
S.gatewaySteel(F, gate, G)

-- 2. HALL: x ±15, z -13 .. -63, 22 high ----------------------------------------------------------------------------
local hall = K.model(shop, "Hall")
local HW, HZ0, HZ1, HH, BELT = 15, -13, -63, 22, 16.5
local BAYS = { { z = -27, l = "FEATURED", r = "SEASON" }, { z = -49, l = "NEWIN", r = "CASES" } }
local LINE_END = -83.8 -- where the gold lines meet the feature's floor ring
box(F, hall, "Aisle", V(-6.2, -2, HZ1), V(6.2, 0, -12), LK.aisle)
for _, sd in { -1, 1 } do
	box(F, hall, "Floor", V(sd * 6.2, -2, HZ1), V(sd * HW, 0, -12), LK.floor)
	box(F, hall, "Line", V(sd * 6.2, 0, LINE_END), V(sd * 6.6, 0.04, -12), goldPaint)
end
-- side walls with the bay openings
for _, sd in { -1, 1 } do
	local ops = {}
	for _, b in BAYS do
		table.insert(ops, { V(sd * HW, 0, b.z + 8), V(sd * HW, 0, b.z - 8), 14 })
	end
	wall(
		F,
		hall,
		sd < 0 and "Wall_L" or "Wall_R",
		V(sd * HW, 0, HZ0),
		V(sd * HW, 0, HZ1),
		V(0, 0, -38),
		{
			h = HH,
			belt = BELT,
			openings = ops,
		}
	)
end
-- front wall round the portal, its casing, and the coffer's end above it
wall(F, hall, "Wall_Front", V(-HW, 0, HZ0), V(HW, 0, HZ0), V(0, 0, -38), {
	h = HH,
	belt = BELT,
	th = 1,
	openings = { { V(-10, 0, HZ0), V(10, 0, HZ0), 15 } },
	ext0 = 1.5,
	ext1 = 1.5,
})
local Fport = F * CFrame.new(0, 0, HZ0) * CFrame.Angles(0, math.pi, 0) -- facing into the hall
casing(Fport, hall, "PortalCasing", 10, 15, 2.5, 0.5, L.dark)
box(F, hall, "FrontHead", V(-7.2, HH, HZ0), V(7.2, 26, HZ0 + 1), LK.upper)
-- ceiling: side slabs and a raised coffer down the middle
for _, sd in { -1, 1 } do
	box(F, hall, "Ceiling", V(sd * 6, HH, HZ1), V(sd * 16.5, HH + 1, -12), LK.ceil)
	box(F, hall, "CofferCheek", V(sd * 6, HH + 1, HZ1), V(sd * 7, 25, -12), LK.ceil)
end
box(F, hall, "CofferTop", V(-7, 25, HZ1), V(7, 26, -12), LK.ceil)
for _, z in { -22, -32, -44, -54 } do
	downlight(F, hall, "Downlight", 0, z, 25, 2.4, 1.6, 30, 95)
end
-- pilasters with bar lamps carrying the cross beams; the last pair stands at the junction corners
for _, z in { -16, -38, -62 } do
	for _, sd in { -1, 1 } do
		pilaster(
			F,
			hall,
			"Pilaster",
			V(sd * (HW - 0.7), 0, z),
			V(-sd, 0, 0),
			{ cap = 19, lamp = true }
		)
	end
	ibeam(F, hall, "Beam", V(-14.6, 0, z), V(14.6, 0, z), 19.5, 2.5, 1.2)
end

-- 3. DISPLAY BAYS: 16 wide, 9 deep, 14 high; a stage, a lighting truss with three cans, a backdrop screen ---------
local bays = K.model(shop, "Bays")
local function bayShell(sd, zc, kind)
	local FB = F * CFrame.new(sd * HW, 0, zc) * CFrame.Angles(0, math.rad(sd < 0 and 90 or -90), 0)
	local m = K.model(bays, "Bay_" .. kind)
	m:SetAttribute("Kind", kind)
	box(FB, m, "Floor", V(-9.5, -2, -10.5), V(9.5, 0, 0), LK.floor)
	box(FB, m, "Back", V(-9.5, 0, -10.5), V(9.5, 15, -9), LK.bay)
	for _, x in { -1, 1 } do
		box(FB, m, "Side", V(x * 8, 0, -9), V(x * 9.5, 14, 0), LK.bay)
	end
	box(FB, m, "Ceiling", V(-9.5, 14, -10.5), V(9.5, 15, 0), LK.bay)
	-- stage: deck, steel nose with a gold step light
	box(FB, m, "Deck", V(-8, 0, -9), V(8, 1.1, -1.3), LK.stage)
	box(FB, m, "Nose", V(-8, 0, -1.3), V(8, 1.25, -1.0), L.steel)
	K.ghost(box(FB, m, "StepLight", V(-7.6, 0.45, -1.0), V(7.6, 0.6, -0.95), goldGlow))
	-- proscenium: jambs, head, cut top corners through the bay
	for _, x in { -1, 1 } do
		box(FB, m, "Jamb", V(x * 8, 0, 0), V(x * 9.6, 14, 0.6), L.dark)
	end
	box(FB, m, "Head", V(-9.6, 14, 0), V(9.6, 15.2, 0.6), L.dark)
	tunnelCuts(FB, m, 8, 14, 1.5, -9, 0, LK.bay)
	tunnelCuts(FB, m, 8, 14, 1.5, 0, 0.6, L.dark)
	-- backdrop screen in a bezel (BuildShopFit fills its SurfaceGui)
	box(FB, m, "Bezel", V(-6.7, 4.2, -9), V(6.7, 11.8, -8.75), L.dark)
	local scr = box(FB, m, "Screen", V(-6.3, 4.6, -8.75), V(6.3, 11.4, -8.7), L.plate)
	scr.CastShadow = false
	-- lighting truss across the bay, bolted to the side walls
	local tr = K.model(m, "Truss")
	local ty0, ty1, tz0, tz1 = 10.6, 11.8, -3.6, -2.4 -- below the chamfered corners (they start at 12.5)
	for _, y in { ty0, ty1 } do
		for _, z in { tz0, tz1 } do
			box(FB, tr, "Chord", V(-8, y - 0.11, z - 0.11), V(8, y + 0.11, z + 0.11), L.dark)
		end
	end
	for _, z in { tz0, tz1 } do
		local Ff = FB * CFrame.new(0, 0, z)
		for i = 0, 9 do
			local xa, xb = -8 + i * 1.6, -8 + (i + 1) * 1.6
			local a, b = V(xa, i % 2 == 0 and ty0 or ty1, 0), V(xb, i % 2 == 0 and ty1 or ty0, 0)
			S.bar(Ff, tr, "Lace", a, b, 0.12, -0.06, 0.06, L.dark)
		end
	end
	for _, x in { -1, 1 } do
		box(FB, tr, "EndPlate", V(x * 7.85, 10.3, -3.9), V(x * 8, 12.1, -2.1), L.steel)
	end
	-- three cans hung under the truss, aimed at the stage
	local target = V(0, 3.4, -5.6)
	for _, x in { -5, 0, 5 } do
		local can = K.model(tr, "Can")
		local c = V(x, 9.95, -3.0)
		local dir = (V(x * 0.35, target.Y, target.Z) - c).Unit
		local side = Y:Cross(dir).Unit
		local up = dir:Cross(side).Unit
		K.mesh(
			can,
			"Body",
			"V5_Pipe8",
			V(1.3, 0.85, 0.85),
			FB * CFrame.fromMatrix(c, dir, up),
			L.dark
		)
		K.mesh(
			can,
			"Lens",
			"V5_Flange8",
			V(0.06, 0.66, 0.66),
			FB * CFrame.fromMatrix(c + dir * 0.66, dir, up),
			L.white
		).CastShadow =
			false
		for _, s in { -1, 1 } do
			box(
				FB,
				can,
				"Yoke",
				V(x + s * 0.47 - 0.05, 9.95, -3.15),
				V(x + s * 0.47 + 0.05, 10.49, -2.85),
				L.steel
			)
		end
		local lp = K.ghost(
			K.part(
				can,
				"Light",
				V(0.2, 0.2, 0.2),
				FB * CFrame.lookAt(c + dir * 0.75, c + dir * 2),
				K.paint(DOWN)
			)
		)
		lp.Transparency = 1
		K.spot(can, lp, Enum.NormalId.Front, K.WHITE, 1.7, 16, 50)
	end
	return FB, m
end
for _, b in BAYS do
	bayShell(-1, b.z, b.l)
	bayShell(1, b.z, b.r)
end

-- 4. JUNCTION: flares at 45°, straight sides, cut back corners with the passages, the back wall; 26 high ---------
local jn = K.model(shop, "Junction")
local JH = 26
local inJ = V(0, 0, -82)
box(F, jn, "HallHead", V(-HW, HH, HZ1), V(HW, JH, HZ1 + 1.5), LK.upper)
box(F, jn, "HallLintel", V(-HW, HH - 0.6, HZ1 - 0.3), V(HW, HH, HZ1 + 0.2), L.dark)
local cutWalls = {}
for _, sd in { -1, 1 } do
	local w = { h = JH, belt = BELT }
	wall(F, jn, "Flare", V(sd * HW, 0, HZ1), V(sd * 24, 0, -72), inJ, w)
	wall(F, jn, "Side", V(sd * 24, 0, -72), V(sd * 24, 0, -83), inJ, w)
	local A, B = V(sd * 24, 0, -83), V(sd * 10, 0, -97)
	local d = (B - A).Unit
	wall(F, jn, "Cut", A, B, inJ, {
		h = JH,
		belt = BELT,
		openings = { { A + d * 3.9, A + d * 15.9, 14 } },
	})
	cutWalls[sd] = { A = A, B = B }
end
wall(F, jn, "Back", V(-10, 0, -97), V(10, 0, -97), inJ, { h = JH, belt = BELT })
-- corner pilasters on the bisectors (they hide the mitres); the beams across rest on the side pairs
local function bis(p, a, b)
	return ((a - p).Unit + (b - p).Unit).Unit
end
for _, sd in { -1, 1 } do
	local c1, c2, c3 = V(sd * 24, 0, -72), V(sd * 24, 0, -83), V(sd * 10, 0, -97)
	pilaster(
		F,
		jn,
		"Corner",
		c1 + bis(c1, V(sd * HW, 0, HZ1), c2) * 0.5,
		bis(c1, V(sd * HW, 0, HZ1), c2),
		{ cap = 23, top = JH }
	)
	pilaster(F, jn, "Corner", c2 + bis(c2, c1, c3) * 0.5, bis(c2, c1, c3), { cap = 23, top = JH })
	pilaster(
		F,
		jn,
		"Corner",
		c3 + bis(c3, c2, V(0, 0, -97)) * 0.5,
		bis(c3, c2, V(0, 0, -97)),
		{ cap = 23, top = JH }
	)
end
for _, z in { -72, -83 } do
	ibeam(F, jn, "Beam", V(-22.9, 0, z), V(22.9, 0, z), 23.5, 2.5, 1.3)
end
box(F, jn, "Ceiling", V(-25.5, JH, -98.5), V(25.5, JH + 1, HZ1), LK.ceil)
for _, p in
	{ { -11, -67.5 }, { 11, -67.5 }, { -16, -77.5 }, { 16, -77.5 }, { -6, -90 }, { 6, -90 } }
do
	downlight(F, jn, "Downlight", p[1], p[2], JH, 2.4, 1.5, 32, 95)
end
-- floor: tiled to the walls' outline without overlaps (aisle to the feature, sides, corner triangles)
box(F, jn, "Aisle", V(-6.2, -2, -97), V(6.2, 0, HZ1), LK.aisle)
for _, sd in { -1, 1 } do
	box(F, jn, "Floor", V(sd * 6.2, -2, -92), V(sd * 15, 0, HZ1), LK.floor)
	box(F, jn, "Floor", V(sd * 6.2, -2, -97), V(sd * 10, 0, -92), LK.floor)
	box(F, jn, "Floor", V(sd * 15, -2, -83), V(sd * 24, 0, -72), LK.floor)
	wedge(
		F,
		jn,
		"FloorTri",
		V(sd * 10, -1, -92),
		V(sd, 0, 0),
		5,
		V(0, 0, -1),
		5,
		V(0, 1, 0),
		2,
		LK.floor
	)
	wedge(
		F,
		jn,
		"FloorTri",
		V(sd * 15, -1, -72),
		V(0, 0, 1),
		9,
		V(sd, 0, 0),
		9,
		V(0, 1, 0),
		2,
		LK.floor
	)
	wedge(
		F,
		jn,
		"FloorTri",
		V(sd * 15, -1, -83),
		V(sd, 0, 0),
		9,
		V(0, 0, -1),
		9,
		V(0, 1, 0),
		2,
		LK.floor
	)
end

-- 5. PASSAGES (12 x 14, 14 long) and WINGS (32 x 30 x 18) --------------------------------------------------------
local WINGS = {}
for _, sd in { -1, 1 } do
	local cw = cutWalls[sd]
	local Fw, len = wallFrame(F, cw.A, cw.B, inJ)
	local FP = Fw * CFrame.new(len / 2, 0, 0) -- z toward the junction; the passage runs to -z
	local name = sd < 0 and "ItemShop" or "SeasonPass"
	local ps = K.model(shop, "Passage_" .. name)
	box(FP, ps, "Floor", V(-6, -2, -14), V(6, 0, 0), LK.aisle)
	for _, x in { -1, 1 } do
		wall(FP, ps, "Wall", V(x * 6, 0, 0), V(x * 6, 0, -14), V(0, 0, -7), { h = 14, belt = 10.5 })
	end
	box(FP, ps, "Ceiling", V(-7.5, 14, -14), V(7.5, 15, 0), LK.ceil)
	tunnelCuts(FP, ps, 6, 14, 1.5, -14.6, 0.6, L.dark)
	casing(FP, ps, "CasingJunction", 6, 14, 1.5, 0.6, L.dark)
	casing(
		FP * CFrame.new(0, 0, -14) * CFrame.Angles(0, math.pi, 0),
		ps,
		"CasingWing",
		6,
		14,
		1.5,
		0.6,
		L.dark
	)
	downlight(FP, ps, "Downlight", 0, -7, 14, 2, 1.3, 18, 95)
	-- the wing
	local FW = FP * CFrame.new(0, 0, -14)
	local wg = K.model(shop, "Wing_" .. name)
	local WH, WB = 18, 15
	local inW = V(0, 0, -15)
	box(FW, wg, "Floor", V(-16, -2, -30), V(16, 0, 0), LK.floor)
	wall(FW, wg, "Wall_Front", V(-16, 0, 0), V(16, 0, 0), inW, {
		h = WH,
		belt = WB,
		openings = { { V(-6, 0, 0), V(6, 0, 0), 14 } },
		ext0 = 1.5,
		ext1 = 1.5,
	})
	wall(
		FW,
		wg,
		"Wall_Back",
		V(-16, 0, -30),
		V(16, 0, -30),
		inW,
		{ h = WH, belt = WB, ext0 = 1.5, ext1 = 1.5 }
	)
	for _, x in { -1, 1 } do
		wall(
			FW,
			wg,
			x < 0 and "Wall_L" or "Wall_R",
			V(x * 16, 0, 0),
			V(x * 16, 0, -30),
			inW,
			{ h = WH, belt = WB }
		)
	end
	box(FW, wg, "Ceiling", V(-17.5, WH, -31.5), V(17.5, WH + 1, 1.5), LK.ceil)
	for _, z in { -10, -20 } do
		for _, x in { -1, 1 } do
			pilaster(FW, wg, "Pilaster", V(x * 15.3, 0, z), V(-x, 0, 0), { cap = WB - 0.5 })
		end
		ibeam(FW, wg, "Beam", V(-15.4, 0, z), V(15.4, 0, z), WB, WH - WB, 1.2)
	end
	for _, p in { { -8, -5 }, { 8, -5 }, { -8, -15 }, { 8, -15 }, { -8, -25 }, { 8, -25 } } do
		downlight(FW, wg, "Downlight", p[1], p[2], WH, 2.2, 1.4, 24, 95)
	end
	WINGS[name] = FW
end

local n = 0
for _, d in shop:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
for _, d in gate:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("shop shell: %d parts"):format(n)
