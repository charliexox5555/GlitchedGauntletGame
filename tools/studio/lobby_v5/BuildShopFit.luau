--!nocheck
-- Lobby V5 SHOP V2, FIT-OUT PART 1: portal sign, hall bays, junction feature, passage signs (vault/02 Art/Lobby V5
-- Plan.md, "Shop V2: the market hall"). ONE-TIME placement record after BuildShopHall.luau; needs V5Kit.LobbyKit,
-- LobbySigns, LobbyWay, ReplicatedStorage.Crates (the real crate models) and Shared.Config.Crates (tier colours).
-- Real objects only (owner: no placeholder bricks): guns via LobbyGunDisplay anchors, the crate meshes in their tier
-- looks, SurfaceGui boards; every board and sign has a light on it.

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local S = require(SS.V5Kit.LobbySigns:Clone())
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local L = K.L
local TIERS = require(RS.Shared.Config.Crates:Clone()).TIERS
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local GOLD, PASS = K.AREA.shop.col, K.AREA.pass.col
local goldPaint = K.paint(rgb(196, 150, 42))
local goldGlow = K.neon(K.dim(GOLD, 0.42))
local F = K.frame(V(-40, 0, 0), V(1, 0, 0))
local shop = workspace.LobbyV5.Shell.Shop
local gate = workspace.LobbyV5.Shell.Hub.Gateways.Gateway_Shop
local fit = shop:FindFirstChild("Fit") or K.model(shop, "Fit")
fit:ClearAllChildren()

local function box(Fb, parent, name, a, b, lk)
	return K.lpart(Fb, parent, name, a, b, lk)
end
local function hubPos(Fb, v)
	return (Fb * v) - K.O
end
local function wdir(Fb, v)
	return Fb:VectorToWorldSpace(v)
end
local function ghostMount(Fb, parent, slot, a, b)
	local p = K.ghost(box(Fb, parent, slot, a, b, K.paint(Color3.new(0, 1, 0))))
	p.Transparency = 1
	p:SetAttribute("Slot", slot)
	CS:AddTag(p, "SeasonMount")
	return p
end
-- a horizontal octagon slab (S.octagon in a frame whose z is up), from y0 to y1
local function oct(Fb, parent, name, x, z, d, y0, y1, lk)
	return S.octagon(
		Fb * CFrame.new(x, 0, z) * CFrame.Angles(-math.pi / 2, 0, 0),
		parent,
		name,
		d,
		y0,
		y1,
		lk
	)
end
-- a real crate model in a tier's look, its bottom centre at Fb * pos, long axis along `along` (Fb-local)
local function crate(Fb, parent, tier, pos, along, scale)
	local t = TIERS[tier]
	local src = RS.Crates[t.template or "Crate"]
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local role = d.Name:match("_(%a+)$")
			local lk = role and t.roles[role]
			if lk then
				d.Color = lk.color
				d.Material = lk.material
			end
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	m:ScaleTo(scale)
	local bcf, bs = m:GetBoundingBox()
	local rel = bcf:ToObjectSpace(m:GetPivot())
	local x = along.Unit
	local target = Fb * CFrame.fromMatrix(pos + V(0, bs.Y / 2, 0), x, Vector3.yAxis)
	m:PivotTo(target * rel)
	m.Name = t.name .. "Case"
	m.Parent = parent
	return m
end
local function board(part, s)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.LightInfluence = 0
	g.Brightness = 1.1
	g.Parent = part
	s.px = part.Size.Y * 30
	W.board(g, s)
	return g
end

-- 1. PORTAL: the v3 SHOP sign standing on the cornice; plain return walls out to the rock ---------------------------
for _, c in gate:GetChildren() do
	if c.Name:match("^Sign_") or c.Name:match("^Return_") then
		c:Destroy()
	end
end
if gate:FindFirstChild("Steel") then
	for _, c in gate.Steel:GetChildren() do
		if c.Name == "Outrigger" then
			c:Destroy()
		end
	end
end
local Tc = 20.5
W.sign(F * CFrame.new(0, Tc + 0.75 + 0.8 + 4.6, 0.75), gate, {
	name = "Sign_SHOP",
	word = "SHOP",
	sub = "ITEMS  ·  SEASON PASS",
	code = "ZONE S-03",
	icon = K.AREA.shop.icon,
	col = GOLD,
	h = 4.6,
	mount = "stand",
	stand = 0.8,
	lamps = true,
})
for _, sd in { -1, 1 } do
	local r = K.model(gate, sd < 0 and "Return_L" or "Return_R")
	box(F, r, "Body", V(sd * 14.5, 0, -6), V(sd * 19.5, 20.5, -0.6), L.trim)
	box(F, r, "Plinth", V(sd * 14.5, 0, -0.6), V(sd * 19.5, 2.4, -0.1), L.wains)
	K.ltri(
		F,
		r,
		"PlinthSlope",
		V(sd * 17, 2.4, -0.6),
		V(0, 1, 0),
		0.5,
		V(0, 0, 1),
		0.5,
		V(1, 0, 0),
		5,
		L.wains
	)
	box(
		F,
		r,
		"Coping",
		V(sd * 14.5, 20.5, -6),
		V(sd * 19.5, 21.1, 0),
		K.look("Concrete-02a", rgb(140, 138, 134))
	)
end

-- 2. HALL BAYS ---------------------------------------------------------------------------------------------------
local HW = 15
local drape = K.look(nil, rgb(36, 36, 40), Enum.Material.Fabric)
local function bayFrame(sd, zc)
	return F * CFrame.new(sd * HW, 0, zc) * CFrame.Angles(0, math.rad(sd < 0 and 90 or -90), 0)
end
local BAYS = {
	{ kind = "FEATURED", sd = -1, z = -27, n = "01", word = "FEATURED" },
	{ kind = "SEASON", sd = 1, z = -27, n = "02", word = "SEASON 1" },
	{ kind = "NEWIN", sd = -1, z = -49, n = "03", word = "NEW IN" },
	{ kind = "CASES", sd = 1, z = -49, n = "04", word = "CASES" },
}
for _, b in BAYS do
	local FB = bayFrame(b.sd, b.z)
	local bay = shop.Bays["Bay_" .. b.kind]
	for _, p in bay:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Back" or p.Name == "Side") then
			p.Material = drape.mat
			p.MaterialVariant = ""
			p.Color = drape.col
		end
	end
	local m = K.model(fit, "Display_" .. b.kind)
	local scr = bay.Screen
	if b.kind == "FEATURED" then
		oct(FB, m, "Base", 0, -5.2, 4.8, 1.1, 1.7, L.dark)
		oct(FB, m, "Band", 0, -5.2, 4.3, 1.7, 1.78, goldPaint)
		oct(FB, m, "Top", 0, -5.2, 4.0, 1.78, 2.1, L.steel)
		local tt = K.mesh(
			m,
			"Turntable",
			"V5_Flange8",
			V(0.3, 3.2, 3.2),
			FB * CFrame.new(0, 2.25, -5.2) * CFrame.Angles(0, 0, math.rad(90)),
			L.dark
		)
		tt.CanCollide = false
		K.gunAnchor(
			m,
			"Stand_Featured",
			hubPos(FB, V(0, 4.9, -5.2)),
			"Vandal",
			"Stand",
			wdir(FB, V(1, 0, 0)),
			wdir(FB, V(0, 0, 1)),
			2.6,
			5.4,
			20
		)
		board(
			scr,
			{
				title = "FEATURED",
				sub = "IN THE SHOP TODAY",
				foot = "BAY 01  ·  SHOP",
				col = GOLD,
				icon = K.AREA.shop.icon,
			}
		)
	elseif b.kind == "SEASON" then
		local items = { { -4.6, 2, 1.6 }, { 0, 3, 2.4 }, { 4.6, 4, 1.6 } }
		for _, it in items do
			local x, tier, h = it[1], it[2], it[3]
			local pl = K.model(m, "Plinth")
			box(FB, pl, "Body", V(x - 1.6, 1.1, -8.2), V(x + 1.6, 1.1 + h, -2.2), L.dark)
			box(FB, pl, "Cap", V(x - 1.7, 1.1 + h, -8.3), V(x + 1.7, 1.25 + h, -2.1), L.steel)
			K.ghost(
				box(
					FB,
					pl,
					"Glow",
					V(x - 1.45, 1.1 + h * 0.5, -2.2),
					V(x + 1.45, 1.22 + h * 0.5, -2.14),
					K.neon(K.dim(PASS, 0.45))
				)
			)
			crate(FB, pl, tier, V(x, 1.25 + h, -5.2), V(0, 0, 1), if tier == 4 then 2.2 else 1.25)
		end
		ghostMount(FB, m, "SeasonShowcase", V(-7, 1.2, -8.5), V(7, 8, -1.5))
		board(
			scr,
			{
				title = "SEASON 1",
				sub = "EARN REWARDS AS YOU PLAY",
				foot = "BAY 02  ·  SEASON PASS",
				col = PASS,
				icon = K.AREA.pass.icon,
			}
		)
	elseif b.kind == "NEWIN" then
		for i, gun in { "Phantom", "Spectre", "Sheriff" } do
			local x = (i - 2) * 5
			oct(FB, m, "Base", x, -5.2, 3.0, 1.1, 1.8, L.dark)
			oct(FB, m, "Top", x, -5.2, 2.5, 1.8, 2.05, L.steel)
			K.gunAnchor(
				m,
				"Stand_" .. gun,
				hubPos(FB, V(x, 4.0, -5.2)),
				gun,
				"Stand",
				wdir(FB, V(1, 0, 0)),
				wdir(FB, V(0, 0, 1)),
				2.0,
				3.6
			)
		end
		board(
			scr,
			{
				title = "NEW IN",
				sub = "FRESH SKINS IN THE DAILY SHOP",
				foot = "BAY 03  ·  SHOP",
				col = GOLD,
				icon = K.AREA.shop.icon,
			}
		)
	elseif b.kind == "CASES" then
		box(FB, m, "RiserFront", V(-7.4, 1.1, -4.4), V(7.4, 1.6, -1.8), L.dark)
		box(FB, m, "RiserBack", V(-7.6, 1.1, -8.4), V(7.6, 2.9, -4.6), L.dark)
		box(FB, m, "RiserBackCap", V(-7.7, 2.9, -8.5), V(7.7, 3.05, -4.5), L.steel)
		box(FB, m, "RiserFrontCap", V(-7.5, 1.6, -4.5), V(7.5, 1.75, -1.7), L.steel)
		crate(FB, m, 1, V(-3.2, 1.75, -3.1), V(1, 0, 0), 1.25)
		crate(FB, m, 2, V(3.2, 1.75, -3.1), V(1, 0, 0), 1.25)
		crate(FB, m, 3, V(0, 3.05, -6.5), V(1, 0, 0), 1.25)
		crate(FB, m, 4, V(-5.6, 3.05, -6.5), V(1, 0, 0), 2.1)
		crate(FB, m, 4, V(5.6, 3.05, -6.5), V(1, 0, 0), 2.1)
		board(
			scr,
			{
				title = "CASES",
				sub = "OPEN ONE IN THE SHOP",
				foot = "BAY 04  ·  SHOP",
				col = GOLD,
				icon = K.AREA.shop.icon,
			}
		)
	end
	-- the bay's sign on the wall above it, and the keep-clear dashes on the hall floor in front
	W.sign(FB * CFrame.new(0, 20.4, 0.75), m, {
		name = "Sign_Bay" .. b.n,
		word = b.word,
		tileText = b.n,
		col = GOLD,
		h = 1.9,
		mount = "wall",
		standoff = 0.75,
		lamps = true,
	})
	for i = 0, 7 do
		local x = -7.2 + i * 2.05
		box(FB, m, "Dash", V(x, 0, 1.3), V(x + 1.2, 0.03, 1.62), goldPaint)
	end
end

-- 3. JUNCTION FEATURE: the DAILY SHOP screen under a hood, a tiered plinth with the featured gun, a gold floor ring -
local ft = K.model(fit, "Feature")
local PZ = -88
-- kept inside the back corner pilasters (their shafts reach x ±8.4)
box(F, ft, "Bezel", V(-7.6, 4.8, -97), V(7.6, 14.4, -96.7), L.dark)
local scr = box(F, ft, "Screen", V(-7.1, 5.3, -96.7), V(7.1, 13.9, -96.64), L.plate)
scr.CastShadow = false
board(
	scr,
	{
		title = "DAILY SHOP",
		sub = "NEW ITEMS EVERY DAY",
		foot = "THE DEEP MARKET  ·  ZONE S-03",
		col = GOLD,
		icon = K.AREA.shop.icon,
	}
)
local hood = K.model(ft, "Hood")
box(F, hood, "Top", V(-8.0, 14.4, -97), V(8.0, 15.1, -95.0), L.dark)
box(F, hood, "Lip", V(-8.0, 14.0, -95.2), V(8.0, 14.4, -95.0), L.steel)
for _, x in { -5, 0, 5 } do
	local lens =
		K.ghost(box(F, hood, "Lens", V(x - 0.9, 14.33, -96.2), V(x + 0.9, 14.4, -95.5), L.white))
	K.spot(hood, lens, Enum.NormalId.Bottom, K.WHITE, 1.2, 16, 80)
end
oct(F, ft, "Base", 0, PZ, 11, 0, 0.6, L.wains)
oct(F, ft, "Mid", 0, PZ, 8.6, 0.6, 1.4, L.dark)
oct(F, ft, "Band", 0, PZ, 7.3, 1.4, 1.5, goldGlow)
oct(F, ft, "Top", 0, PZ, 7.0, 1.5, 2.0, L.steel)
local tt = K.mesh(
	ft,
	"Turntable",
	"V5_Flange8",
	V(0.4, 5, 5),
	F * CFrame.new(0, 2.2, PZ) * CFrame.Angles(0, 0, math.rad(90)),
	L.dark
)
tt.CanCollide = false
K.gunAnchor(
	ft,
	"Stand_Feature",
	hubPos(F, V(0, 5.6, PZ)),
	"Operator",
	"Stand",
	wdir(F, V(1, 0, 0)),
	wdir(F, V(0, 0, 1)),
	3.0,
	7.6,
	16
)
ghostMount(F, ft, "ShopWindow", V(-4.5, 2.1, PZ - 3.5), V(4.5, 9, PZ + 3.5))
local ap = 7.5
local edge = 2 * ap * math.tan(math.rad(22.5))
for i = 0, 7 do
	local a = math.rad(i * 45)
	local n = V(math.sin(a), 0, math.cos(a))
	local t = V(n.Z, 0, -n.X)
	local c = V(0, 0, PZ) + n * ap
	K.part(
		ft,
		"Ring",
		V(edge + 0.33, 0.04, 0.4),
		F * CFrame.fromMatrix(c + V(0, 0.02, 0), t, Vector3.yAxis),
		goldPaint
	)
end
local spotRig = K.model(ft, "Spot")
box(F, spotRig, "Housing", V(-1.2, 25.2, PZ - 1.2), V(1.2, 26, PZ + 1.2), L.dark)
local sl =
	K.ghost(box(F, spotRig, "Lens", V(-0.8, 25.14, PZ - 0.8), V(0.8, 25.2, PZ + 0.8), L.white))
K.spot(spotRig, sl, Enum.NormalId.Bottom, K.WHITE, 1.4, 34, 34)

-- 4. JUNCTION WAYFINDING: a board on each side wall pointing to its wing; a hanging sign over each passage ---------
local function wallFrame(A, B, inside)
	local d = (B - A).Unit
	local z = d:Cross(Vector3.yAxis)
	if z:Dot(inside - (A + B) / 2) < 0 then
		A, B = B, A
		d = -d
	end
	return F * CFrame.fromMatrix(A, d, Vector3.yAxis), (B - A).Magnitude
end
local inJ = V(0, 0, -82)
local WINGS = {
	[-1] = {
		word = "ITEM SHOP",
		sub = "SKINS  ·  CASES  ·  COINS",
		code = "S-03A",
		icon = K.AREA.shop.icon,
		col = GOLD,
	},
	[1] = {
		word = "SEASON PASS",
		sub = "SEASON 1  ·  REWARDS",
		code = "S-03B",
		icon = K.AREA.pass.icon,
		col = PASS,
	},
}
for _, sd in { -1, 1 } do
	local wd = WINGS[sd]
	local Fs, len = wallFrame(V(sd * 24, 0, -72), V(sd * 24, 0, -83), inJ)
	local Fc = Fs * CFrame.new(len / 2, 0, 0)
	local bm = K.model(fit, "WayBoard_" .. (sd < 0 and "L" or "R"))
	box(Fc, bm, "Bezel", V(-3.6, 4.6, 0), V(3.6, 10.4, 0.3), L.dark)
	local s2 = box(Fc, bm, "Screen", V(-3.3, 4.9, 0.3), V(3.3, 10.1, 0.36), L.plate)
	s2.CastShadow = false
	board(
		s2,
		{
			title = (sd < 0 and "ITEMS" or "PASS") .. " »",
			sub = wd.sub,
			foot = wd.word,
			col = wd.col,
			icon = wd.icon,
		}
	)
	local lamp = box(Fc, bm, "Lamp", V(-1.2, 10.9, 0.3), V(1.2, 11.3, 1.4), L.dark)
	box(Fc, bm, "LampArm", V(-0.1, 10.95, 0), V(0.1, 11.15, 0.3), L.steel)
	K.spot(bm, lamp, Enum.NormalId.Bottom, K.WARM, 0.9, 9, 90)
	-- passage sign
	local Fw, wl = wallFrame(V(sd * 24, 0, -83), V(sd * 10, 0, -97), inJ)
	local FP = Fw * CFrame.new(wl / 2, 0, 0)
	W.sign(FP * CFrame.new(0, 19.6, 1.8), fit, {
		name = "Sign_" .. wd.word:gsub("%s", ""),
		word = wd.word,
		sub = wd.sub,
		code = wd.code,
		icon = wd.icon,
		col = wd.col,
		h = 3.0,
		tilt = 8,
		mount = "hang",
		hang = 26 - 19.6,
		lamps = true,
	})
end

local n = 0
for _, d in fit:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("shop fit (hall): %d parts"):format(n)
