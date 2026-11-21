--!nocheck
-- Lobby V5 SHOP V2, FIT-OUT PART 2: the two wings (vault/02 Art/Lobby V5 Plan.md, "Shop V2: the market hall").
-- ONE-TIME placement record after BuildShopHall.luau + BuildShopFit.luau. Each wing model carries its frame in the
-- `FrameCF` attribute (x across, z toward the passage; the room is x ±16, z 0 .. -30, 18 high; pilasters on the side
-- walls at z -10 / -20 split each side into three sections). Wall fittings stand 0.5 proud so the wainscot hides.
-- ITEM SHOP (gold): the Broker behind the counter (`LobbyShop`, Talk line "broker"), the slat wall with the MARKET
-- sign and stock shelves, two gun cabinets (`LobbyGunDisplay`), a knife-case table under a pendant, a BUNDLES board,
-- and a closed STOCKROOM shutter (a future door).
-- SEASON PASS (purple): the pass screen with a tier track under a lit hood, a three-step reward stage with the cases
-- (`LobbyBattlePass`, `PassHero` mount), hanging season banners, a floor emblem, and a NEXT SEASON shutter.

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
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
local shop = workspace.LobbyV5.Shell.Shop

local function box(Fb, parent, name, a, b, lk)
	return K.lpart(Fb, parent, name, a, b, lk)
end
local function hubPos(Fb, v)
	return (Fb * v) - K.O
end
local function wdir(Fb, v)
	return Fb:VectorToWorldSpace(v)
end
local function zone(Fb, parent, tag, a, b)
	local p = K.ghost(box(Fb, parent, tag .. "Zone", a, b, K.paint(Color3.new(0, 1, 0))))
	p.Transparency = 1
	CS:AddTag(p, tag)
	return p
end
local function mount(Fb, parent, slot, a, b)
	local p = K.ghost(box(Fb, parent, slot, a, b, K.paint(Color3.new(0, 1, 0))))
	p.Transparency = 1
	p:SetAttribute("Slot", slot)
	CS:AddTag(p, "SeasonMount")
	return p
end
local function crate(Fb, parent, tier, pos, along, scale)
	local t = TIERS[tier]
	local m = RS.Crates[t.template or "Crate"]:Clone()
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
	m:PivotTo(Fb * CFrame.fromMatrix(pos + V(0, bs.Y / 2, 0), along.Unit, Vector3.yAxis) * rel)
	m.Name = t.name .. "Case"
	m.Parent = parent
	return m
end
local function screenGui(part, pps)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps or 30
	g.LightInfluence = 0
	g.Brightness = 1.1
	g.Parent = part
	return g
end
-- a framed screen board on a wall frame Fw (face at z 0), centred at x, from y0 to y1
local function wallBoard(Fw, parent, name, x, w, y0, y1, s)
	local m = K.model(parent, name)
	box(Fw, m, "Bezel", V(x - w / 2, y0, 0.5), V(x + w / 2, y1, 0.8), L.dark)
	local scr = box(
		Fw,
		m,
		"Screen",
		V(x - w / 2 + 0.3, y0 + 0.3, 0.8),
		V(x + w / 2 - 0.3, y1 - 0.3, 0.86),
		L.plate
	)
	scr.CastShadow = false
	local g = screenGui(scr)
	s.px = scr.Size.Y * 30
	W.board(g, s)
	local lamp = box(Fw, m, "Lamp", V(x - 1.2, y1 + 0.5, 0.8), V(x + 1.2, y1 + 0.9, 1.9), L.dark)
	box(Fw, m, "LampArm", V(x - 0.1, y1 + 0.55, 0), V(x + 0.1, y1 + 0.75, 0.8), L.steel)
	K.spot(m, lamp, Enum.NormalId.Bottom, K.WARM, 0.9, 9, 90)
	return m
end
-- a closed roller shutter on a wall frame Fw: channel jambs, roller box, ribbed curtain, hazard bottom bar, a sign
local function shutter(Fw, parent, name, x, word, sub, col)
	local m = K.model(parent, name)
	local hw, H = 2.8, 8.4
	for _, sd in { -1, 1 } do
		box(Fw, m, "Jamb", V(x + sd * hw, 0, 0.5), V(x + sd * (hw + 0.6), H, 1.0), L.dark)
		box(
			Fw,
			m,
			"JambLip",
			V(x + sd * (hw - 0.1), 0, 0.95),
			V(x + sd * (hw + 0.6), H, 1.05),
			L.steel
		)
	end
	box(Fw, m, "RollerBox", V(x - hw - 0.8, H, 0.5), V(x + hw + 0.8, H + 1.4, 1.35), L.dark)
	box(Fw, m, "RollerLip", V(x - hw - 0.8, H - 0.12, 1.2), V(x + hw + 0.8, H, 1.35), L.steel)
	local n = 0
	for y = 0.3, H - 0.4, 0.42 do
		n += 1
		box(
			Fw,
			m,
			"Slat",
			V(x - hw, y, 0.55),
			V(x + hw, y + 0.42, n % 2 == 0 and 0.78 or 0.72),
			K.look("Metal 2022", rgb(98, 100, 104))
		)
	end
	local bar = box(
		Fw,
		m,
		"BottomBar",
		V(x - hw, 0, 0.55),
		V(x + hw, 0.3, 0.85),
		K.paint(rgb(196, 152, 34))
	)
	K.texture(bar, Enum.NormalId.Back, K.TEX.hazard, 1.4)
	for _, sd in { -1, 1 } do
		box(
			Fw,
			m,
			"Handle",
			V(x + sd * 1.2 - 0.3, 0.45, 0.78),
			V(x + sd * 1.2 + 0.3, 0.6, 0.95),
			L.steel
		)
	end
	W.sign(Fw * CFrame.new(x, H + 3.2, 1.15), m, {
		word = word,
		sub = sub,
		tileText = "!",
		col = col,
		h = 1.5,
		mount = "wall",
		standoff = 0.65,
	})
	return m
end
local function sideFrame(FW, sd, zc) -- side wall frame (face at x = sd*16), x along the wall
	return FW * CFrame.new(sd * 16, 0, zc) * CFrame.Angles(0, math.rad(sd < 0 and 90 or -90), 0)
end

-- ITEM SHOP ------------------------------------------------------------------------------------------------------
do
	local wg = shop.Wing_ItemShop
	local FW = wg:GetAttribute("FrameCF")
	local fit = wg:FindFirstChild("Fit") or K.model(wg, "Fit")
	fit:ClearAllChildren()
	local FB = FW * CFrame.new(0, 0, -30) -- back wall, facing the entrance
	-- counter: plinth, leaning front, steel top, gold lip, terminal
	local ct = K.model(fit, "Counter")
	box(FW, ct, "Plinth", V(-8.6, 0, -22.6), V(8.6, 0.3, -20.5), L.dark)
	box(FW, ct, "Body", V(-8.8, 0.3, -22.8), V(8.8, 3.4, -20.5), L.dark)
	K.ltri(
		FW,
		ct,
		"Front",
		V(0, 3.4, -20.5),
		V(0, -1, 0),
		3.1,
		V(0, 0, 1),
		0.6,
		V(1, 0, 0),
		17.6,
		L.dark
	)
	box(FW, ct, "Top", V(-9.2, 3.4, -23.0), V(9.2, 3.8, -19.7), L.steel)
	K.ghost(
		box(FW, ct, "Lip", V(-8.8, 3.22, -19.95), V(8.8, 3.4, -19.8), K.neon(K.dim(GOLD, 0.42)))
	)
	local term = K.model(ct, "Terminal")
	box(FW, term, "Foot", V(-5.6, 3.8, -21.8), V(-4.4, 3.95, -20.8), L.steel)
	box(FW, term, "Neck", V(-5.1, 3.95, -21.45), V(-4.9, 4.7, -21.15), L.steel)
	local ts = box(FW, term, "Screen", V(-5.9, 4.6, -21.35), V(-4.1, 5.8, -21.25), L.plate)
	local tg = screenGui(ts, 60)
	local tbg = Instance.new("Frame")
	tbg.Size = UDim2.fromScale(1, 1)
	tbg.BorderSizePixel = 0
	tbg.BackgroundColor3 = rgb(26, 27, 31)
	tbg.Parent = tg
	local ic = Instance.new("ImageLabel")
	ic.BackgroundTransparency = 1
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	ic.Size = UDim2.fromScale(0.55, 0.55)
	ic.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ic.Image = K.AREA.shop.icon
	ic.ImageColor3 = GOLD
	ic.Parent = tbg
	zone(FW, ct, "LobbyShop", V(-7, 0, -19.6), V(7, 6, -14.5))
	-- slat wall on the back wall with the MARKET sign above, stock shelves either side
	local sw = K.model(fit, "SlatWall")
	box(FB, sw, "Back", V(-9.5, 1.5, 0.5), V(9.5, 11, 0.8), L.plate)
	for i = 0, 8 do
		local x = -9.2 + i * 2.3
		box(FB, sw, "Fin", V(x - 0.25, 1.5, 0.8), V(x + 0.25, 11, 1.4), L.steel)
		if i < 8 then
			K.ghost(
				box(
					FB,
					sw,
					"Slot",
					V(x + 1.05, 2.0, 0.8),
					V(x + 1.25, 10.5, 0.86),
					K.neon(K.dim(GOLD, 0.42))
				)
			)
		end
	end
	box(FB, sw, "Head", V(-9.8, 11, 0.5), V(9.8, 11.5, 1.6), L.dark)
	box(FB, sw, "Foot", V(-9.8, 1.0, 0.5), V(9.8, 1.5, 1.6), L.dark)
	W.sign(FB * CFrame.new(0, 14.3, 1.8), sw, {
		name = "Sign_MARKET",
		word = "MARKET",
		sub = "OPEN EVERY DAY",
		code = "S-03A",
		icon = K.AREA.shop.icon,
		col = GOLD,
		h = 2.5,
		mount = "wall",
		standoff = 1.3,
		lamps = true,
	})
	for _, sd in { -1, 1 } do
		local sh = K.model(fit, "Shelves")
		local xa, xb = sd * 10.2, sd * 13.2
		for _, x in { xa, xb } do
			box(FB, sh, "Upright", V(x - 0.15, 0, 0.5), V(x + 0.15, 12.2, 2.4), L.steel)
		end
		for i, y in { 0.8, 4.0, 7.2, 10.4 } do
			box(
				FB,
				sh,
				"Shelf",
				V(math.min(xa, xb) + 0.15, y, 0.5),
				V(math.max(xa, xb) - 0.15, y + 0.2, 2.3),
				L.dark
			)
			box(
				FB,
				sh,
				"ShelfLip",
				V(math.min(xa, xb) + 0.15, y + 0.2, 2.2),
				V(math.max(xa, xb) - 0.15, y + 0.35, 2.3),
				L.steel
			)
			if i < 4 then
				crate(FB, sh, 1, V(sd * 11.7, y + 0.2, 1.4), V(1, 0, 0), 0.75)
			end
		end
	end
	-- the Broker behind the counter, with a Talk line
	local src = workspace:FindFirstChild("LobbyV4Staging")
		and workspace.LobbyV4Staging:FindFirstChild("NPCs")
		and workspace.LobbyV4Staging.NPCs:FindFirstChild("Broker")
	if src then
		local npc = src:Clone()
		npc:ScaleTo(1.5)
		local cf, size = npc:GetBoundingBox()
		local pivot = npc:GetPivot()
		local bottom = cf.Position.Y - size.Y / 2
		local target = FW * V(2.5, 0, -25.6)
		local rot = CFrame.lookAt(target, target + wdir(FW, V(-0.2, 0, 1)))
		npc:PivotTo(rot.Rotation + V(target.X, pivot.Position.Y - bottom + target.Y, target.Z))
		npc.Parent = fit
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
		if npc:FindFirstChild("Vest") then
			refit(npc.Vest, V(ut.Size.X + 0.24, ut.Size.Y - 0.35, ut.Size.Z + 0.26), V(0, -0.12, 0))
		end
		if npc:FindFirstChild("Strap") then
			refit(npc.Strap, V(0.3, 3.1, ut.Size.Z + 0.4), V(0.25, -0.05, 0))
		end
		K.state(npc, "Talk", "sbroker")
	end
	-- gun cabinets in the middle side sections (two guns each), lit from hoods
	local GUNS = { [-1] = { "Vandal", "Phantom" }, [1] = { "Operator", "Spectre" } }
	for _, sd in { -1, 1 } do
		local Fg = sideFrame(FW, sd, -15)
		local cab = K.model(fit, "GunCabinet")
		box(
			Fg,
			cab,
			"Back",
			V(-3.0, 3.4, 0.5),
			V(3.0, 13.0, 0.65),
			K.look("Metal 2022", rgb(66, 68, 73))
		)
		for _, x in { -1, 1 } do
			box(
				Fg,
				cab,
				"Stile",
				V(x * 2.95 - 0.25, 3.4, 0.65),
				V(x * 2.95 + 0.25, 13.0, 1.25),
				L.steel
			)
		end
		for _, y in { 3.4, 8.05, 12.7 } do
			box(Fg, cab, "Rail", V(-3.2, y, 0.65), V(3.2, y + 0.3, 1.25), L.steel)
		end
		box(Fg, cab, "Plinth", V(-3.2, 0, 0.5), V(3.2, 3.4, 1.35), L.dark)
		K.ltri(
			Fg,
			cab,
			"PlinthSlope",
			V(0, 3.4, 1.25),
			V(0, 1, 0),
			0.3,
			V(0, 0, -1),
			0.6,
			V(1, 0, 0),
			6.4,
			L.dark
		)
		for row = 1, 2 do
			local y0 = if row == 1 then 8.35 else 3.7
			local y1 = y0 + 4.35
			box(Fg, cab, "Hood", V(-2.8, y1 - 0.35, 0.65), V(2.8, y1, 1.4), L.dark)
			local lens = K.ghost(
				box(Fg, cab, "Lens", V(-2.3, y1 - 0.42, 0.85), V(2.3, y1 - 0.35, 1.25), L.white)
			)
			K.spot(cab, lens, Enum.NormalId.Bottom, K.WHITE, 1.5, 7, 110)
			box(Fg, cab, "Tag", V(-1.1, y0 + 0.25, 0.65), V(1.1, y0 + 0.75, 0.75), L.plate)
			box(Fg, cab, "TagBar", V(-1.0, y0 + 0.3, 0.75), V(1.0, y0 + 0.38, 0.79), goldPaint)
			local gun = GUNS[sd][row]
			K.gunAnchor(
				cab,
				"Wall_" .. gun,
				hubPos(Fg, V(0, (y0 + y1) / 2 + 0.2, 0.75)),
				gun,
				"Wall",
				wdir(Fg, V(1, 0, 0)),
				wdir(Fg, V(0, 0, 1)),
				1.9,
				4.4
			)
		end
	end
	-- left front: BUNDLES board; left back: the STOCKROOM shutter; right front and back: tall stock shelving
	wallBoard(sideFrame(FW, -1, -4.4), fit, "BundlesBoard", 0, 6.4, 4.2, 10.2, {
		title = "BUNDLES",
		sub = "SKIN SETS AT A BETTER PRICE",
		foot = "ITEM SHOP  ·  S-03A",
		col = GOLD,
		icon = K.AREA.shop.icon,
	})
	shutter(sideFrame(FW, -1, -25.6), fit, "Shutter", 0, "STOCKROOM", "STAFF ONLY", GOLD)
	for _, zc in { -4.4, -25.6 } do
		local Fs = sideFrame(FW, 1, zc)
		local sh = K.model(fit, "Racking")
		for _, x in { -3.0, 3.0 } do
			box(Fs, sh, "Upright", V(x - 0.18, 0, 0.5), V(x + 0.18, 12.6, 2.3), L.steel)
		end
		for i, y in { 0.6, 3.6, 6.6, 9.6, 12.4 } do
			box(Fs, sh, "Shelf", V(-2.82, y, 0.5), V(2.82, y + 0.2, 2.2), L.dark)
			box(Fs, sh, "ShelfLip", V(-2.82, y + 0.2, 2.1), V(2.82, y + 0.35, 2.2), L.steel)
			if i <= 4 then
				crate(Fs, sh, 1, V(0, y + 0.2, 1.28), V(1, 0, 0), 1.1)
			end
		end
		for _, y in { 2.1, 5.1, 8.1, 11.1 } do
			box(Fs, sh, "Brace", V(-3.0, y, 0.55), V(3.0, y + 0.12, 0.65), L.steel)
		end
	end
	-- knife-case table under a pendant hung from the first beam
	local tb = K.model(fit, "CaseTable")
	local TZ = -10
	for _, x in { -3.2, 3.2 } do
		for _, z in { TZ - 1.3, TZ + 1.3 } do
			box(FW, tb, "Leg", V(x - 0.15, 0, z - 0.15), V(x + 0.15, 3.0, z + 0.15), L.steel)
		end
	end
	box(FW, tb, "Shelf", V(-3.2, 0.6, TZ - 1.3), V(3.2, 0.75, TZ + 1.3), L.dark)
	box(FW, tb, "Apron", V(-3.5, 2.6, TZ - 1.6), V(3.5, 3.0, TZ + 1.6), L.dark)
	box(
		FW,
		tb,
		"Felt",
		V(-3.3, 3.0, TZ - 1.4),
		V(3.3, 3.1, TZ + 1.4),
		K.look(nil, rgb(30, 44, 36), Enum.Material.Fabric)
	)
	local glass = box(FW, tb, "Glass", V(-3.3, 3.1, TZ - 1.4), V(3.3, 4.7, TZ + 1.4), L.glass)
	glass.Transparency = 0.85
	glass.CastShadow = false
	glass.CanCollide = false
	for _, x in { -3.4, 3.4 } do
		for _, z in { TZ - 1.5, TZ + 1.5 } do
			box(FW, tb, "Post", V(x - 0.1, 3.0, z - 0.1), V(x + 0.1, 4.8, z + 0.1), L.steel)
		end
	end
	box(FW, tb, "LidFront", V(-3.5, 4.7, TZ + 1.4), V(3.5, 4.85, TZ + 1.6), L.steel)
	box(FW, tb, "LidBack", V(-3.5, 4.7, TZ - 1.6), V(3.5, 4.85, TZ - 1.4), L.steel)
	for _, x in { -1.7, 1.7 } do
		crate(FW, tb, 4, V(x, 3.1, TZ), V(1, 0, 0), 1.6)
	end
	local pd = K.model(fit, "Pendant")
	for _, x in { -2.4, 2.4 } do
		box(FW, pd, "Rod", V(x - 0.06, 10.4, TZ - 0.06), V(x + 0.06, 15, TZ + 0.06), L.steel)
		box(FW, pd, "Clamp", V(x - 0.3, 14.85, TZ - 0.7), V(x + 0.3, 15.05, TZ + 0.7), L.dark)
	end
	box(FW, pd, "Body", V(-3, 10.0, TZ - 0.5), V(3, 10.4, TZ + 0.5), L.dark)
	local pl =
		K.ghost(box(FW, pd, "Lens", V(-2.7, 9.95, TZ - 0.3), V(2.7, 10.0, TZ + 0.3), L.white))
	K.spot(pd, pl, Enum.NormalId.Bottom, K.WHITE, 1.3, 12, 70)
	-- floor: gold lines from the passage to the counter
	for _, sd in { -1, 1 } do
		box(FW, fit, "Line", V(sd * 6.2, 0, -19.4), V(sd * 6.6, 0.04, -1.0), goldPaint) -- starts in front of the jambs
	end
end

-- SEASON PASS ----------------------------------------------------------------------------------------------------
do
	local wg = shop.Wing_SeasonPass
	local FW = wg:GetAttribute("FrameCF")
	local fit = wg:FindFirstChild("Fit") or K.model(wg, "Fit")
	fit:ClearAllChildren()
	local FB = FW * CFrame.new(0, 0, -30)
	local purpleGlow = K.neon(K.dim(PASS, 0.45))
	-- the pass screen under a lit hood
	local sc = K.model(fit, "PassScreen")
	box(FB, sc, "Bezel", V(-11.2, 4.4, 0.5), V(11.2, 13.4, 0.8), L.dark)
	local scr = box(FB, sc, "Screen", V(-10.8, 4.8, 0.8), V(10.8, 13.0, 0.86), L.plate)
	scr.CastShadow = false
	local g = screenGui(scr, 24)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = rgb(24, 20, 34)
	bg.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(140, 130, 160))
	grad.Parent = bg
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromScale(0.04, 0.08)
	icon.Size = UDim2.fromScale(0.13, 0.34)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.Image = K.AREA.pass.icon
	icon.ImageColor3 = PASS
	icon.Parent = bg
	W.label(
		bg,
		"SEASON 1",
		K.RUBIK_H,
		64,
		rgb(242, 239, 232),
		UDim2.fromScale(0.16, 0.08),
		UDim2.fromScale(0.6, 0.22)
	)
	W.label(
		bg,
		"THE SEASON PASS  ·  FREE AND PREMIUM TRACKS",
		K.RUBIK_B,
		22,
		PASS,
		UDim2.fromScale(0.16, 0.3),
		UDim2.fromScale(0.8, 0.1)
	)
	for i = 1, 7 do
		local t = Instance.new("Frame")
		t.BorderSizePixel = 0
		t.BackgroundColor3 = if i <= 2 then K.dim(PASS, 0.2) else rgb(40, 36, 52)
		t.Position = UDim2.new(0.04 + (i - 1) * 0.134, 0, 0.5, 0)
		t.Size = UDim2.fromScale(0.12, 0.34)
		t.Parent = bg
		local corner = Instance.new("Frame")
		corner.BorderSizePixel = 0
		corner.BackgroundColor3 = rgb(24, 20, 34)
		corner.AnchorPoint = Vector2.new(1, 0)
		corner.Position = UDim2.fromScale(1, 0)
		corner.Size = UDim2.fromOffset(14, 14)
		corner.Rotation = 45
		corner.Parent = t
		W.label(
			t,
			tostring(i),
			K.RUBIK_H,
			40,
			if i <= 2 then rgb(20, 18, 26) else rgb(200, 196, 210),
			UDim2.fromScale(0, 0.1),
			UDim2.fromScale(1, 0.55),
			Enum.TextXAlignment.Center
		)
		W.label(
			t,
			if i % 3 == 0 then "CASE" elseif i % 2 == 0 then "SKIN" else "COINS",
			K.RUBIK_B,
			16,
			if i <= 2 then rgb(20, 18, 26) else PASS,
			UDim2.fromScale(0, 0.66),
			UDim2.fromScale(1, 0.24),
			Enum.TextXAlignment.Center
		)
	end
	local band = Instance.new("Frame")
	band.BorderSizePixel = 0
	band.BackgroundColor3 = K.dim(PASS, 0.5)
	band.Position = UDim2.fromScale(0, 0.9)
	band.Size = UDim2.fromScale(1, 0.1)
	band.Parent = bg
	box(FB, sc, "HoodTop", V(-12, 13.4, 0.5), V(12, 14.1, 2.6), L.dark)
	box(FB, sc, "HoodLip", V(-12, 13.0, 2.4), V(12, 13.4, 2.6), L.steel)
	for _, x in { -7, 0, 7 } do
		local lens =
			K.ghost(box(FB, sc, "Lens", V(x - 1, 13.33, 1.2), V(x + 1, 13.4, 2.1), L.white))
		K.spot(sc, lens, Enum.NormalId.Bottom, K.WHITE, 1.2, 14, 80)
	end
	mount(FB, sc, "PassHero", V(-10.8, 4.8, 0.9), V(10.8, 13, 1.5))
	-- the reward stage: three steps with purple step lights, the cases on the top step
	local st = K.model(fit, "Stage")
	local steps = { { 0.6, 9.5 }, { 1.2, 7.0 }, { 1.8, 4.5 } }
	for i, s in steps do
		local y, d = s[1], s[2]
		box(
			FB,
			st,
			"Step",
			V(-10, y - 0.6, 1.5),
			V(10, y, 1.5 + d),
			if i % 2 == 0 then L.dark else K.look("Metal 2022", rgb(54, 52, 62))
		)
		box(
			FB,
			st,
			"Nose",
			V(-10, y - 0.12, 1.5 + d - 0.15),
			V(10, y + 0.02, 1.5 + d + 0.02),
			L.steel
		)
		K.ghost(
			box(
				FB,
				st,
				"StepLight",
				V(-9.6, y - 0.42, 1.5 + d + 0.02),
				V(9.6, y - 0.3, 1.5 + d + 0.06),
				purpleGlow
			)
		)
	end
	crate(FB, st, 2, V(-6, 1.8, 3.6), V(1, 0, 0), 1.2)
	crate(FB, st, 3, V(0, 1.8, 3.6), V(1, 0, 0), 1.2)
	crate(FB, st, 4, V(6, 1.8, 3.6), V(1, 0, 0), 2.1)
	zone(FW, st, "LobbyBattlePass", V(-8, 0, -20), V(8, 6, -13.5))
	-- hanging banners: rod on brackets, fabric, the pass emblem, a weighted hem
	local function banner(Fw, x)
		local bm = K.model(fit, "Banner")
		for _, sx in { -1, 1 } do
			box(
				Fw,
				bm,
				"Bracket",
				V(x + sx * 1.6 - 0.12, 12.6, 0.5),
				V(x + sx * 1.6 + 0.12, 13.0, 1.3),
				L.dark
			)
		end
		box(Fw, bm, "Rod", V(x - 1.9, 12.6, 1.05), V(x + 1.9, 12.8, 1.25), L.steel)
		local cloth = box(
			Fw,
			bm,
			"Cloth",
			V(x - 1.45, 3.6, 1.1),
			V(x + 1.45, 12.6, 1.2),
			K.look(nil, K.dim(PASS, 0.55), Enum.Material.Fabric)
		)
		box(Fw, bm, "Hem", V(x - 1.5, 3.4, 1.05), V(x + 1.5, 3.6, 1.25), L.steel)
		local cg = Instance.new("SurfaceGui")
		cg.Face = Enum.NormalId.Back
		cg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		cg.PixelsPerStud = 30
		cg.LightInfluence = 0.8
		cg.Parent = cloth
		local e = Instance.new("ImageLabel")
		e.BackgroundTransparency = 1
		e.AnchorPoint = Vector2.new(0.5, 0)
		e.Position = UDim2.fromScale(0.5, 0.12)
		e.Size = UDim2.fromScale(0.7, 0.7)
		e.SizeConstraint = Enum.SizeConstraint.RelativeXX
		e.Image = K.AREA.pass.icon
		e.ImageColor3 = rgb(236, 226, 255)
		e.Parent = cg
		W.label(
			cg,
			"S1",
			K.RUBIK_H,
			54,
			rgb(236, 226, 255),
			UDim2.fromScale(0, 0.62),
			UDim2.fromScale(1, 0.16),
			Enum.TextXAlignment.Center
		)
		local stripe = Instance.new("Frame")
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = rgb(236, 226, 255)
		stripe.Position = UDim2.fromScale(0.15, 0.84)
		stripe.Size = UDim2.fromScale(0.7, 0.015)
		stripe.Parent = cg
		return bm
	end
	for _, zc in { -4.4, -15, -25.6 } do
		banner(sideFrame(FW, -1, zc), 0)
	end
	for _, zc in { -4.4, -15 } do
		banner(sideFrame(FW, 1, zc), 0)
	end
	shutter(sideFrame(FW, 1, -25.6), fit, "Shutter", 0, "NEXT SEASON", "OPENS SOON", PASS)
	-- floor emblem: a purple octagon ring with the lines from the passage leading to it
	local R, PZ = 4.2, -9
	local edge = 2 * R * math.tan(math.rad(22.5))
	local purplePaint = K.paint(K.dim(PASS, 0.25))
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local n = V(math.sin(a), 0, math.cos(a))
		K.part(
			fit,
			"Ring",
			V(edge + 0.33, 0.04, 0.4),
			FW * CFrame.fromMatrix(V(0, 0.02, PZ) + n * R, V(n.Z, 0, -n.X), Vector3.yAxis),
			purplePaint
		)
	end
	for _, sd in { -1, 1 } do
		box(FW, fit, "Line", V(sd * 6.2, 0, -18.8), V(sd * 6.6, 0.04, -1.0), purplePaint)
	end
end

return "wings fitted"
