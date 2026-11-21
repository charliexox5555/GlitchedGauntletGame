--!nocheck
-- Lobby V5 SHOP (vault/02 Art/Lobby V5 Plan.md, "Entrances and the shop"). ONE-TIME placement record run through the
-- Studio MCP after BuildGateways.luau. Owner 2026-11-20: "I kind of want an entrance. I don't really want it to just
-- be like this one little area ... an entrance similar to Rivals". The old counter-in-the-wall is gone; the west
-- gateway now opens on a walk-in shop (gold accent): a storefront with two display windows, a vestibule, and a room
-- with a featured podium, a wall of guns, the Battle Pass bay (purple) and the Broker behind a counter.
-- Hooks reused, no new code: `LobbyShop` / `LobbyBattlePass` prompt parts (WorldPrompts), `LobbyGunDisplay` anchors
-- (each player's own skins), the `LobbyNPC` Broker, a `SeasonMount` ShopWindow slot.
-- Built in the gateway's frame F: x = right as you face the shop from the hub (world -Z), z = toward the hub
-- (world +X), so world = (-40 + z, y, -x).

local K = require(game:GetService("ServerStorage").V5Kit.LobbyKit:Clone())
local CS = game:GetService("CollectionService")
local V = Vector3.new
local L = K.L
local F = K.frame(V(-40, 0, 0), V(1, 0, 0))
local function P(parent, name, a, b, lk)
	return K.lpart(F, parent, name, a, b, lk)
end
local function W(parent, name, p, u, a, v, b, w, th, lk)
	return K.ltri(F, parent, name, p, u, a, v, b, w, th, lk)
end
local function hub(p) -- frame point to hub-local
	return V(-40 + p.Z, p.Y, -p.X)
end
local function dirW(d) -- frame direction to world
	return V(d.Z, d.Y, -d.X)
end
local GOLD = K.AREA.shop.col
local gold = K.neon(K.dim(GOLD, 0.42))
local goldPaint = K.paint(Color3.fromRGB(196, 150, 42))
local wallLk = K.look("Lobby_ConcreteBoard", Color3.fromRGB(84, 83, 81))
local floorLk = K.look("Lobby_ConcretePolished", Color3.fromRGB(86, 84, 81))
local cornice = K.look("Concrete-02a", Color3.fromRGB(140, 138, 134))

local shell = workspace.LobbyV5.Shell
local old = shell:FindFirstChild("Shop")
if old then
	old:Destroy()
end
local shop = K.model(shell, "Shop")

-- 1. STOREFRONT: wings either side of the gateway, each with a lit display window ---------------------------------
local front = K.model(shop, "Storefront")
-- the wings stop at |x| = 17.2: past it the hub's corner rock stands in front of them (owner 2026-11-20 screenshot)
local XI, XO, WX0, WX1 = 11, 17.2, 12.2, 16.2
local WC = (WX0 + WX1) / 2
for _, sd in { -1, 1 } do
	local wing = K.model(front, sd > 0 and "Wing_N" or "Wing_S")
	local z0, z1 = -5.5, -0.6
	P(wing, "Low", V(sd * XI, 0, z0), V(sd * XO, 2.5, z1), L.wains)
	P(wing, "High", V(sd * XI, 12, z0), V(sd * XO, 18, z1), L.trim)
	P(wing, "SideIn", V(sd * XI, 2.5, z0), V(sd * WX0, 12, z1), L.trim)
	P(wing, "SideOut", V(sd * WX1, 2.5, z0), V(sd * XO, 12, z1), L.trim)
	P(wing, "Coping", V(sd * XI, 17.3, z1), V(sd * XO, 18, 0.2), cornice)
	W(
		wing,
		"CopingCap",
		V(sd * (XI + XO) / 2, 18, z1),
		V(0, 1, 0),
		0.5,
		V(0, 0, 1),
		0.8,
		V(1, 0, 0),
		XO - XI,
		cornice
	)
	local win = K.model(wing, "Window")
	P(win, "Back", V(sd * WX0, 3, z0), V(sd * WX1, 12, -3.6), K.paint(Color3.fromRGB(104, 100, 92))) -- a light display backdrop
	P(win, "Sill", V(sd * (WX0 - 0.7), 2.5, -3.6), V(sd * (WX1 + 0.5), 3, 0.3), L.steel)
	P(win, "LinerTop", V(sd * WX0, 11.86, -3.6), V(sd * WX1, 12, -0.95), L.dark)
	P(win, "LinerL", V(sd * WX0, 3, -3.6), V(sd * (WX0 + 0.14), 11.86, -0.95), L.dark)
	P(win, "LinerR", V(sd * (WX1 - 0.14), 3, -3.6), V(sd * WX1, 11.86, -0.95), L.dark)
	P(win, "CasingTop", V(sd * (WX0 - 0.5), 12, z1), V(sd * (WX1 + 0.5), 12.6, -0.2), L.steel)
	P(win, "CasingL", V(sd * (WX0 - 0.5), 3, z1), V(sd * WX0, 12, -0.2), L.steel)
	P(win, "CasingR", V(sd * WX1, 3, z1), V(sd * (WX1 + 0.5), 12, -0.2), L.steel)
	local glass =
		P(win, "Glass", V(sd * (WX0 + 0.14), 3, -0.95), V(sd * (WX1 - 0.14), 11.86, -0.87), L.glass)
	glass.Transparency = 0.82
	glass.Reflectance = 0.08
	glass.CastShadow = false
	local lens = K.ghost(
		P(win, "Lens", V(sd * (WX0 + 0.5), 11.74, -3.2), V(sd * (WX1 - 0.5), 11.86, -2.2), L.white)
	)
	K.spot(win, lens, Enum.NormalId.Bottom, K.WHITE, 1.8, 11, 95)
	K.ghost(P(win, "Uplight", V(sd * (WX0 + 0.3), 3, -3.6), V(sd * (WX1 - 0.3), 3.1, -3.35), gold))
	P(win, "Pedestal", V(sd * (WC - 1.2), 3, -3.2), V(sd * (WC + 1.2), 3.7, -1.4), L.dark)
	W(
		win,
		"PedestalSlope",
		V(sd * WC, 3, -1.4),
		V(0, 1, 0),
		0.7,
		V(0, 0, 1),
		0.3,
		V(1, 0, 0),
		2.4,
		L.dark
	)
	P(win, "PedestalTop", V(sd * (WC - 1.05), 3.7, -3.05), V(sd * (WC + 1.05), 3.8, -1.55), L.steel)
	K.gunAnchor(
		win,
		sd > 0 and "Stand_Vandal" or "Stand_Phantom",
		hub(V(sd * WC, 6.4, -2.3)),
		sd > 0 and "Vandal" or "Phantom",
		"Stand",
		dirW(V(-1, 0, 0)),
		dirW(V(0, 0, 1)),
		2.2,
		3.4
	)
	if sd < 0 then
		local mount = K.ghost(
			P(
				win,
				"ShopWindow",
				V(sd * (WX0 + 0.3), 3.2, -3.4),
				V(sd * (WX1 - 0.3), 11.6, -1.1),
				K.paint(Color3.new(0, 1, 0))
			)
		)
		mount.Transparency = 1
		mount:SetAttribute("Slot", "ShopWindow")
		CS:AddTag(mount, "SeasonMount")
	end
end

-- 2. VESTIBULE (z -15..-6) behind the gateway ------------------------------------------------------------------
local vest = K.model(shop, "Vestibule")
P(vest, "Threshold", V(-7, 0, -15), V(7, 0.06, -6), L.diamond)
P(vest, "Wall_L", V(-9, 0, -15), V(-7, 15, -6), L.darkConc)
P(vest, "Wall_R", V(7, 0, -15), V(9, 15, -6), L.darkConc)
P(vest, "Ceiling", V(-9, 15, -15), V(9, 16.5, -6), L.darkConc)
for _, sd in { -1, 1 } do
	W(vest, "Cut", V(sd * 7, 15, -10.5), V(0, -1, 0), 3, V(-sd, 0, 0), 3, V(0, 0, 1), 9, L.darkConc)
end
local vl = K.model(vest, "Light")
P(vl, "Housing", V(-2.5, 14.4, -12.5), V(2.5, 15, -8.5), L.dark)
K.spot(
	vl,
	K.ghost(P(vl, "Lens", V(-2.2, 14.32, -12.2), V(2.2, 14.4, -8.8), L.white)),
	Enum.NormalId.Bottom,
	K.WHITE,
	2,
	18,
	110
)
P(shop, "FloorLink", V(-9, -2, -14), V(9, 0, -12), L.floor) -- the hub floor stops at world x -52 (z -12)

-- 3. ROOM SHELL: z -63..-15, x -22..22, y 0..18 ----------------------------------------------------------------
local Z0, Z1, RX, RH = -63, -15, 22, 18
local room = K.model(shop, "Room")
P(room, "Floor", V(-RX - 1, -2, Z0 - 1), V(RX + 1, 0, Z1 + 1), floorLk)
P(room, "Ceiling", V(-RX - 1, RH, Z0 - 1), V(RX + 1, RH + 1, Z1 + 1), L.darkConc)
P(room, "Wall_Back", V(-RX - 1, 0, Z0 - 1), V(RX + 1, RH, Z0), wallLk)
P(room, "Wall_L", V(-RX - 1, 0, Z0), V(-RX, RH, Z1 + 1), wallLk)
P(room, "Wall_R", V(RX, 0, Z0), V(RX + 1, RH, Z1 + 1), wallLk)
P(room, "Wall_Front_L", V(-RX, 0, Z1), V(-9, RH, Z1 + 1), wallLk)
P(room, "Wall_Front_R", V(9, 0, Z1), V(RX, RH, Z1 + 1), wallLk)
P(room, "Wall_Front_Top", V(-9, 16.5, Z1), V(9, RH, Z1 + 1), wallLk)
for _, x in { { -RX, -9 }, { 9, RX } } do
	P(room, "Wainscot", V(x[1], 0, Z1 - 0.5), V(x[2], 3, Z1), L.wains)
	W(
		room,
		"WainscotSlope",
		V((x[1] + x[2]) / 2, 3, Z1),
		V(0, 1, 0),
		0.5,
		V(0, 0, -1),
		0.5,
		V(1, 0, 0),
		x[2] - x[1],
		L.wains
	)
end
-- soffit with a warm lit cove
local soff = K.model(room, "Soffit")
local SY0, SY1 = 15.5, 17
P(soff, "Band_Back", V(-RX, SY0, Z0), V(RX, SY1, Z0 + 3), L.trim)
P(soff, "Band_Front", V(-RX, SY0, Z1 - 3), V(RX, SY1, Z1), L.trim)
P(soff, "Band_L", V(-RX, SY0, Z0 + 3), V(-RX + 3, SY1, Z1 - 3), L.trim)
P(soff, "Band_R", V(RX - 3, SY0, Z0 + 3), V(RX, SY1, Z1 - 3), L.trim)
for _, c in
	{
		{ V(-RX + 3.2, SY1, Z0 + 2.6), V(RX - 3.2, SY1 + 0.1, Z0 + 2.8) },
		{ V(-RX + 3.2, SY1, Z1 - 2.8), V(RX - 3.2, SY1 + 0.1, Z1 - 2.6) },
		{ V(-RX + 2.6, SY1, Z0 + 3.2), V(-RX + 2.8, SY1 + 0.1, Z1 - 3.2) },
		{ V(RX - 2.8, SY1, Z0 + 3.2), V(RX - 2.6, SY1 + 0.1, Z1 - 3.2) },
	}
do
	K.spot(
		soff,
		K.ghost(P(soff, "Cove", c[1], c[2], L.white)),
		Enum.NormalId.Top,
		K.WARM,
		2,
		10,
		150
	)
end
for _, z in { -24, -52 } do
	for _, x in { -9, 9 } do
		local m = K.model(room, "CeilingLight")
		P(m, "Frame", V(x - 2.2, RH - 0.5, z - 3.2), V(x + 2.2, RH, z + 3.2), L.dark)
		K.spot(
			m,
			K.ghost(
				P(m, "Lens", V(x - 1.8, RH - 0.58, z - 2.8), V(x + 1.8, RH - 0.5, z + 2.8), L.white)
			),
			Enum.NormalId.Bottom,
			Color3.fromRGB(255, 236, 214),
			1.7,
			30,
			120
		) -- 1.7: white outfits blew out at 2.2
	end
end
for _, z in { -27, -51 } do
	K.point(K.anchorPart(room, "Fill", hub(V(0, 10, z))), K.WARM, 1.0, 36)
end

-- 4. FEATURED PODIUM in the middle under its own spot ------------------------------------------------------------
local pod = K.model(shop, "Podium")
local PZ = -33
local function chamferedSlab(parent, name, half, c, y0, y1, lk)
	P(parent, name, V(-half + c, y0, PZ - half), V(half - c, y1, PZ + half), lk)
	P(parent, name, V(-half, y0, PZ - half + c), V(-half + c, y1, PZ + half - c), lk)
	P(parent, name, V(half - c, y0, PZ - half + c), V(half, y1, PZ + half - c), lk)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			W(
				parent,
				name .. "Corner",
				V(sx * (half - c), (y0 + y1) / 2, PZ + sz * (half - c)),
				V(sx, 0, 0),
				c,
				V(0, 0, sz),
				c,
				V(0, 1, 0),
				y1 - y0,
				lk
			)
		end
	end
end
chamferedSlab(pod, "Base", 3.4, 1.2, 0, 0.9, L.dark)
chamferedSlab(pod, "Deck", 2.5, 0.85, 0.9, 1.4, L.steel)
local tt = K.mesh(
	pod,
	"Turntable",
	"V5_Flange8",
	V(0.4, 3.4, 3.4),
	F * CFrame.new(0, 1.6, PZ) * CFrame.Angles(0, 0, math.rad(90)),
	L.dark
)
tt.CanCollide = false
K.gunAnchor(
	pod,
	"Stand_Featured",
	hub(V(0, 4.3, PZ)),
	"Operator",
	"Stand",
	dirW(V(1, 0, 0)),
	dirW(V(0, 0, 1)),
	2.4,
	5.6,
	22
)
-- gold inlay diamond on the floor round it
local R = 6
for _, c in { { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } } do
	local a, b = V(c[1] * R, 0, PZ), V(0, 0, PZ + c[2] * R)
	local mid, len = (a + b) / 2 + V(0, 0.02, 0), (b - a).Magnitude
	local d = (b - a).Unit
	K.part(
		pod,
		"Inlay",
		V(len + 0.4, 0.04, 0.4),
		F * CFrame.fromMatrix(mid, d, Vector3.yAxis),
		goldPaint
	)
end
local spotM = K.model(pod, "Spot")
P(spotM, "Housing", V(-1.4, RH - 0.9, PZ - 1.4), V(1.4, RH, PZ + 1.4), L.dark)
K.spot(
	spotM,
	K.ghost(P(spotM, "Lens", V(-1.0, RH - 0.98, PZ - 1.0), V(1.0, RH - 0.9, PZ + 1.0), L.white)),
	Enum.NormalId.Bottom,
	K.WHITE,
	1.5,
	24,
	38
)
-- gold lane lines from the vestibule to the podium
P(shop, "Line_L", V(-6.6, 0.06, -15), V(-6.2, 0.1, PZ + R + 0.6), goldPaint)
P(shop, "Line_R", V(6.2, 0.06, -15), V(6.6, 0.1, PZ + R + 0.6), goldPaint)

-- 5. GUN WALL (left wall, x = -22): 3 x 2 backlit bays, each player's own skins hung in them ----------------------
local gw = K.model(shop, "GunWall")
local GZ0, GZ1, GY0, GY1 = -52, -22, 2.4, 13.2
P(gw, "Frame", V(-RX, GY0 - 0.6, GZ0 - 0.6), V(-RX + 0.5, GY1 + 0.6, GZ1 + 0.6), L.steel)
local GUNS = { { "Operator", "Vandal", "Spectre" }, { "Sheriff", "Phantom", "Judge" } }
local bw, bh = (GZ1 - GZ0 - 1.2) / 3, (GY1 - GY0 - 0.6) / 2
for row = 1, 2 do
	for col = 1, 3 do
		local za = GZ0 + (col - 1) * (bw + 0.6)
		local ya = GY1 - row * bh - (row - 1) * 0.6
		local bay = K.model(gw, "Bay")
		P(
			bay,
			"Back",
			V(-RX + 0.5, ya, za),
			V(-RX + 0.7, ya + bh, za + bw),
			K.look("Metal 2022", Color3.fromRGB(66, 68, 73))
		)
		P(bay, "Hood", V(-RX + 0.5, ya + bh - 0.35, za), V(-RX + 1.3, ya + bh, za + bw), L.dark)
		K.spot(
			bay,
			K.ghost(
				P(
					bay,
					"Lens",
					V(-RX + 0.8, ya + bh - 0.42, za + 0.4),
					V(-RX + 1.2, ya + bh - 0.35, za + bw - 0.4),
					L.white
				)
			),
			Enum.NormalId.Bottom,
			K.WHITE,
			1.6,
			7,
			110
		)
		P(
			bay,
			"Tag",
			V(-RX + 0.7, ya + 0.25, za + bw / 2 - 1.1),
			V(-RX + 0.8, ya + 0.75, za + bw / 2 + 1.1),
			L.plate
		)
		P(
			bay,
			"TagBar",
			V(-RX + 0.8, ya + 0.3, za + bw / 2 - 1.0),
			V(-RX + 0.84, ya + 0.38, za + bw / 2 + 1.0),
			goldPaint
		)
		local name = GUNS[row][col]
		K.gunAnchor(
			bay,
			"Wall_" .. name,
			hub(V(-RX + 0.7, ya + bh / 2 + 0.2, za + bw / 2)),
			name,
			"Wall",
			dirW(V(0, 0, 1)),
			dirW(V(1, 0, 0)),
			1.9,
			bw - 2.4
		)
	end
end

-- 6. BATTLE PASS bay (right wall, x = 22): a framed purple panel with the pass badge, three reward plinths -------
local PASS = K.AREA.pass.col
local bp = K.model(shop, "BattlePass")
local BZ = -37
local FB = F * CFrame.new(RX, 0, BZ) * CFrame.Angles(0, math.rad(-90), 0) -- facing into the room (-x)
K.cutPlate(
	FB * CFrame.new(0, 8.2, 0),
	bp,
	"Panel",
	22,
	11.5,
	2.2,
	0,
	0.3,
	K.look("Metal 2022", Color3.fromRGB(44, 38, 56))
)
K.cutPlate(
	FB * CFrame.new(0, 8.2, 0),
	bp,
	"PanelRim",
	22.5,
	12,
	2.4,
	-0.1,
	0.15,
	K.neon(K.dim(PASS, 0.45))
)
K.badge(FB * CFrame.new(0, 10.6, 0.3), bp, {
	word = "BATTLE PASS",
	sub = "SEASON 1",
	col = PASS,
	icon = K.AREA.pass.icon,
	h = 4.6,
	stand = 0.25,
	glow = 0.5,
})
for i = -1, 1 do
	local pz = BZ + i * 6
	local pl = K.model(bp, "Plinth")
	P(pl, "Body", V(RX - 4.2, 0, pz - 1.6), V(RX - 1.0, 2.2, pz + 1.6), L.dark)
	W(pl, "Slope", V(RX - 4.2, 0, pz), V(0, 1, 0), 2.2, V(-1, 0, 0), 0.5, V(0, 0, 1), 3.2, L.dark)
	K.ghost(
		P(
			pl,
			"Glow",
			V(RX - 4.0, 2.2, pz - 1.4),
			V(RX - 1.2, 2.26, pz + 1.4),
			K.neon(K.dim(PASS, 0.5))
		)
	)
	local crate = K.model(pl, "Crate")
	P(
		crate,
		"Box",
		V(RX - 3.6, 2.26, pz - 1.0),
		V(RX - 1.6, 3.66, pz + 1.0),
		K.look("Metal 2022", Color3.fromRGB(58, 52, 70))
	)
	P(crate, "Lid", V(RX - 3.7, 3.66, pz - 1.1), V(RX - 1.5, 3.9, pz + 1.1), L.dark)
	P(
		crate,
		"Band",
		V(RX - 3.64, 2.7, pz - 1.04),
		V(RX - 1.56, 2.95, pz + 1.04),
		K.paint(K.dim(PASS, 0.2))
	)
end
local bpZone = K.ghost(
	P(
		bp,
		"BattlePassZone",
		V(RX - 9, 0, BZ - 9),
		V(RX - 2, 6, BZ + 9),
		K.paint(Color3.new(0, 1, 0))
	)
)
bpZone.Transparency = 1
CS:AddTag(bpZone, "LobbyBattlePass")

-- 7. COUNTER, the slat wall behind it, the Broker ---------------------------------------------------------------
local ct = K.model(shop, "Counter")
P(ct, "Plinth", V(-9.4, 0, -56), V(9.4, 0.3, -53.9), L.dark)
P(ct, "Body", V(-9.6, 0.3, -56.2), V(9.6, 3.4, -53.9), L.dark)
W(ct, "Front", V(0, 3.4, -53.9), V(0, -1, 0), 3.1, V(0, 0, 1), 0.6, V(1, 0, 0), 19.2, L.dark)
P(ct, "Top", V(-10, 3.4, -56.4), V(10, 3.8, -53.1), L.steel)
K.ghost(P(ct, "Lip", V(-9.6, 3.22, -53.35), V(9.6, 3.4, -53.2), gold))
local term = K.model(ct, "Terminal")
P(term, "Foot", V(-6.2, 3.8, -55.2), V(-5.0, 3.95, -54.2), L.steel)
P(term, "Neck", V(-5.7, 3.95, -54.85), V(-5.5, 4.7, -54.55), L.steel)
local scr = P(term, "Screen", V(-6.5, 4.6, -54.75), V(-4.7, 5.8, -54.65), L.plate)
local g = Instance.new("SurfaceGui")
g.Face = Enum.NormalId.Back -- the frame's +z: toward the customer
g.LightInfluence = 0
g.Brightness = 1.2
g.PixelsPerStud = 60
g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
g.Parent = scr
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(26, 27, 31)
bg.BorderSizePixel = 0
bg.Parent = g
local ic = Instance.new("ImageLabel")
ic.BackgroundTransparency = 1
ic.AnchorPoint = Vector2.new(0.5, 0.5)
ic.Position = UDim2.fromScale(0.5, 0.5)
ic.Size = UDim2.fromScale(0.55, 0.55)
ic.SizeConstraint = Enum.SizeConstraint.RelativeYY
ic.Image = K.AREA.shop.icon
ic.ImageColor3 = GOLD
ic.Parent = bg
local shopZone =
	K.ghost(P(ct, "ShopZone", V(-8, 0, -53), V(8, 6, -48), K.paint(Color3.new(0, 1, 0))))
shopZone.Transparency = 1
CS:AddTag(shopZone, "LobbyShop")
-- slat wall: steel fins over gold-lit slots, the MARKET badge in the middle
local sw = K.model(shop, "SlatWall")
P(sw, "Back", V(-12.5, 1.5, Z0), V(12.5, 15, Z0 + 0.3), L.plate)
for i = 0, 10 do
	local x = -12 + i * 2.4
	P(sw, "Fin", V(x - 0.25, 1.5, Z0 + 0.3), V(x + 0.25, 15, Z0 + 0.9), L.steel)
	if i < 10 then
		K.ghost(P(sw, "Slot", V(x + 1.1, 2.0, Z0 + 0.3), V(x + 1.3, 14.5, Z0 + 0.36), gold))
	end
end
P(sw, "Head", V(-12.8, 15, Z0), V(12.8, 15.5, Z0 + 1.1), L.dark)
P(sw, "Foot", V(-12.8, 1.0, Z0), V(12.8, 1.5, Z0 + 1.1), L.dark)
K.badge(F * CFrame.new(0, 12.3, Z0 + 0.9), sw, {
	word = "MARKET",
	sub = "OPEN NOW",
	col = GOLD,
	icon = K.AREA.shop.icon,
	h = 4.4,
	stand = 0.15,
	glow = 0.6,
})
-- stock shelves either side of the slat wall: steel uprights, four shelves, cases with a gold band
for _, sd in { -1, 1 } do
	local sh = K.model(shop, "Shelves")
	local xa, xb = sd * 14, sd * 20.6
	for _, x in { xa, xb } do
		P(sh, "Upright", V(x - 0.15, 0, Z0), V(x + 0.15, 12.4, Z0 + 1.8), L.steel)
	end
	for i, y in { 0.8, 4.4, 8.0, 11.6 } do
		P(
			sh,
			"Shelf",
			V(math.min(xa, xb) + 0.15, y, Z0),
			V(math.max(xa, xb) - 0.15, y + 0.2, Z0 + 1.7),
			L.dark
		)
		if i < 4 then
			for j, x in { 15.6, 18.9 } do
				local cx = sd * x
				local tall = if (i + j) % 2 == 0 then 1.8 else 1.3
				local crate = K.model(sh, "Case")
				P(
					crate,
					"Box",
					V(cx - 1.25, y + 0.2, Z0 + 0.25),
					V(cx + 1.25, y + 0.2 + tall, Z0 + 1.45),
					K.look("Metal 2022", Color3.fromRGB(46, 47, 52))
				)
				P(
					crate,
					"Band",
					V(cx - 1.29, y + 0.2 + tall * 0.55, Z0 + 0.21),
					V(cx + 1.29, y + 0.2 + tall * 0.55 + 0.22, Z0 + 1.49),
					goldPaint
				)
			end
		end
	end
end
-- the Broker behind the counter (scale 1.5: at the V4 scale 1.8 his cap reached the badge), right of the terminal
local src = workspace:FindFirstChild("LobbyV4Staging")
	and workspace.LobbyV4Staging:FindFirstChild("NPCs")
	and workspace.LobbyV4Staging.NPCs:FindFirstChild("Broker")
if src then
	local npc = src:Clone()
	npc:ScaleTo(1.5)
	local cf, size = npc:GetBoundingBox()
	local pivot = npc:GetPivot()
	local bottom = cf.Position.Y - size.Y / 2
	local target = K.O + hub(V(5, 0, -59.8))
	local rot = CFrame.lookAt(target, target + dirW(V(-0.25, 0, 1)))
	npc:PivotTo(rot.Rotation + V(target.X, pivot.Position.Y - bottom + K.O.Y, target.Z))
	npc.Parent = shop
	-- the V4 vest was a loose 5.7-stud box (read as a purple block): fit it and the sash to the torso
	local ut = npc.UpperTorso
	local function refit(p, newSize, relPos)
		local welds = {}
		for _, c in npc:GetDescendants() do
			if c:IsA("WeldConstraint") and (c.Part0 == p or c.Part1 == p) then
				c.Enabled = false
				table.insert(welds, c)
			end
		end
		local rel = ut.CFrame:ToObjectSpace(p.CFrame)
		p.Size = newSize
		p.CFrame = ut.CFrame * (CFrame.new(relPos) * rel.Rotation)
		for _, w in welds do
			w.Enabled = true
		end
	end
	refit(npc.Vest, V(ut.Size.X + 0.24, ut.Size.Y - 0.35, ut.Size.Z + 0.26), V(0, -0.12, 0))
	refit(npc.Strap, V(0.3, 3.1, ut.Size.Z + 0.4), V(0.25, -0.05, 0))
end

local n = 0
for _, d in shop:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("shop built: %d pieces"):format(n)
