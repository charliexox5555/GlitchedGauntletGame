--!nocheck
-- Lobby V5 HUB DECOR (vault/02 Art/Lobby V5 Plan.md, "Hub decor"). ONE-TIME placement record (needs V5Kit.LobbyKit +
-- LobbyWay). Owner 2026-11-21: "starting in the main lobby, improve on all the kind of decor ... look at all the
-- rivals decorations and build your own ... sleek, nice ... nothing crazy". RIVALS' hub decor (read-only study:
-- `Lobby.Hub.Extra.Center`, `Important.Displays`) is TVs on arms, standing displays, wall capsule lamps, stanchions,
-- branded crates, vents and intercoms, floor arrows; "life sits where players stop". Ours, built the way they'd be
-- made, in the hub's one accent (hazard yellow) plus each area's own colour on its kiosk:
-- * four INFO KIOSKS, one beside each gateway, turned to the spawn: a stepped plinth, a slim steel tower with front
--   edge trims, a portrait screen (the area, what is there, which gate), the area's icon tile, a crown hood with a
--   lamp that pools light on the floor in front, a cable gland and conduit into the plinth;
-- * two BENCHES behind the spawn facing the lift: steel trestles, three composite slats, end caps.
-- Placed clear of the floor lines, drains, the steel columns and the season mounts.

local SS = game:GetService("ServerStorage")
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local L = K.L
local INK = Color3.fromRGB(18, 19, 22)
local BONE = Color3.fromRGB(242, 239, 232)
local hub = workspace.LobbyV5.Shell.Hub
local old = hub.Dressing:FindFirstChild("Decor")
if old then
	old:Destroy()
end
local decor = K.model(hub.Dressing, "Decor")
local function box(Fb, parent, name, a, b, lk)
	return K.lpart(Fb, parent, name, a, b, lk)
end

local function kiosk(pos, area, title, sub, foot)
	local Fk = K.frame(pos, V(-pos.X, 0, -pos.Z)) -- faces the hub centre
	local col = area.col
	local m = K.model(decor, "Kiosk_" .. title)
	box(Fk, m, "Plinth", V(-1.7, 0, -0.9), V(1.7, 0.3, 0.9), L.dark)
	box(Fk, m, "PlinthStep", V(-1.5, 0.3, -0.75), V(1.5, 0.55, 0.75), L.steel)
	box(Fk, m, "Body", V(-1.3, 0.55, -0.5), V(1.3, 8.2, 0.5), L.dark)
	for _, sx in { -1, 1 } do
		box(Fk, m, "EdgeTrim", V(sx * 1.3, 0.55, 0.38), V(sx * 1.16, 8.2, 0.6), L.steel)
		box(
			Fk,
			m,
			"SideTrim",
			V(sx * 1.3, 0.55, -0.5),
			V(sx * 1.36, 8.2, 0.38),
			K.look("Metal 2022", Color3.fromRGB(70, 72, 77))
		)
	end
	-- crown hood with a lamp, its top sloping to the front
	box(Fk, m, "Crown", V(-1.45, 8.2, -0.6), V(1.45, 8.55, 0.95), L.steel)
	K.ltri(
		Fk,
		m,
		"CrownTop",
		V(0, 8.55, -0.6),
		V(0, 1, 0),
		0.3,
		V(0, 0, 1),
		1.55,
		V(1, 0, 0),
		2.9,
		L.steel
	)
	box(Fk, m, "CrownLip", V(-1.45, 8.05, 0.8), V(1.45, 8.2, 0.95), L.dark)
	local lens = K.ghost(box(Fk, m, "Lens", V(-1.0, 8.14, 0.55), V(1.0, 8.2, 0.78), L.white))
	K.spot(m, lens, Enum.NormalId.Bottom, K.WARM, 0.9, 11, 75)
	-- screen
	box(Fk, m, "Bezel", V(-1.08, 3.25, 0.5), V(1.08, 7.65, 0.62), L.plate)
	local scr = box(Fk, m, "Screen", V(-0.96, 3.37, 0.62), V(0.96, 7.53, 0.66), L.plate)
	scr.CastShadow = false
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0
	g.Brightness = 1.1
	g.Parent = scr
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.fromRGB(22, 23, 27)
	bg.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160))
	grad.Parent = bg
	local ic = Instance.new("ImageLabel")
	ic.BackgroundTransparency = 1
	ic.AnchorPoint = Vector2.new(0.5, 0)
	ic.Position = UDim2.fromScale(0.5, 0.1)
	ic.Size = UDim2.fromScale(0.5, 0.5)
	ic.SizeConstraint = Enum.SizeConstraint.RelativeXX
	ic.Image = area.icon
	ic.ImageColor3 = col
	ic.Parent = bg
	W.label(
		bg,
		title,
		K.RUBIK_H,
		30,
		BONE,
		UDim2.fromScale(0.06, 0.42),
		UDim2.fromScale(0.88, 0.14),
		Enum.TextXAlignment.Center
	)
	local rule = Instance.new("Frame")
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = col
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.fromScale(0.5, 0.58)
	rule.Size = UDim2.new(0.4, 0, 0, 3)
	rule.Parent = bg
	local sl = W.label(
		bg,
		sub,
		K.RUBIK_B,
		13,
		col,
		UDim2.fromScale(0.06, 0.61),
		UDim2.fromScale(0.88, 0.14),
		Enum.TextXAlignment.Center
	)
	sl.TextWrapped = true
	local band = Instance.new("Frame")
	band.BorderSizePixel = 0
	band.BackgroundColor3 = K.dim(col, 0.5)
	band.Position = UDim2.fromScale(0, 0.88)
	band.Size = UDim2.fromScale(1, 0.12)
	band.Parent = bg
	W.label(
		band,
		foot,
		K.RUBIK_B,
		12,
		INK,
		UDim2.new(),
		UDim2.fromScale(1, 1),
		Enum.TextXAlignment.Center
	)
	-- the area tile under the screen
	local Ft = Fk * CFrame.new(0, 2.05, 0.5)
	box(Ft, m, "TileEdge", V(-0.86, -0.71, 0), V(0.86, 0.71, 0.08), K.paint(K.dim(col, 0.45)))
	box(Ft, m, "Tile", V(-0.8, -0.65, 0), V(0.8, 0.65, 0.12), K.paint(col))
	local tg = W.face(Ft, m, "TileFace", 1.6, 1.3, 0.13, 0.25)
	local ti = Instance.new("ImageLabel")
	ti.BackgroundTransparency = 1
	ti.AnchorPoint = Vector2.new(0.5, 0.5)
	ti.Position = UDim2.fromScale(0.5, 0.5)
	ti.Size = UDim2.fromScale(0.7, 0.7)
	ti.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ti.Image = area.icon
	ti.ImageColor3 = INK
	ti.Parent = tg
	-- the cable: a gland on the back and a conduit down into the plinth
	box(Fk, m, "Gland", V(-0.3, 1.9, -0.66), V(0.3, 2.4, -0.5), L.steel)
	K.pipe(m, "Conduit", (Fk * V(0, 1.9, -0.6)) - K.O, (Fk * V(0, 0.3, -0.6)) - K.O, 0.24, L.steel)
	return m
end
kiosk(V(-27, 0, 19), K.AREA.shop, "SHOP", "DAILY ITEMS · CASES · PASS", "WEST GATE  S-03")
kiosk(V(29, 0, -21), K.AREA.locker, "LOCKER", "LOADOUT · SKINS · GEAR", "EAST GATE  L-02")
kiosk(V(22, 0, -30), K.AREA.duels, "DUELS", "1V1 · 2V2 · 3V3", "GATE  D-01")
kiosk(V(-20, 0, 33), K.AREA.range, "RANGE", "LIVE FIRE · COMING SOON", "GATE  R-04")

local slatLk = K.paint(Color3.fromRGB(72, 74, 79))
local function bench(pos, facing)
	local Fb = K.frame(pos, facing)
	local m = K.model(decor, "Bench")
	for _, x in { -2.4, 2.4 } do
		for _, z in { -0.55, 0.55 } do
			box(Fb, m, "Leg", V(x - 0.09, 0.06, z - 0.09), V(x + 0.09, 1.35, z + 0.09), L.steel)
		end
		box(Fb, m, "Foot", V(x - 0.25, 0, -0.78), V(x + 0.25, 0.06, 0.78), L.dark)
		box(Fb, m, "Rail", V(x - 0.12, 1.35, -0.75), V(x + 0.12, 1.5, 0.75), L.dark)
		box(Fb, m, "Brace", V(x - 0.06, 0.45, -0.55), V(x + 0.06, 0.57, 0.55), L.steel)
	end
	box(Fb, m, "Stretcher", V(-2.4, 0.45, -0.06), V(2.4, 0.57, 0.06), L.steel)
	for i = -1, 1 do
		local z = i * 0.52
		box(Fb, m, "Slat", V(-3, 1.5, z - 0.22), V(3, 1.64, z + 0.22), slatLk)
	end
	for _, x in { -1, 1 } do
		box(Fb, m, "EndCap", V(x * 3, 1.45, -0.8), V(x * 3.08, 1.7, 0.8), L.steel)
	end
	return m
end
bench(V(-13, 0, 22), V(0, 0, -1))
bench(V(13, 0, 22), V(0, 0, -1))

local n = 0
for _, d in decor:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("hub decor: %d parts"):format(n)
