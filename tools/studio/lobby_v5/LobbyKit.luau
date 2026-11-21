--!nocheck
-- Lobby V5 build kit (vault/02 Art/Lobby V5 Plan.md, "Entrances and the shop"). Shared helpers for the one-time
-- placement scripts in this folder. Installed in Studio as the ModuleScript ServerStorage.V5Kit.LobbyKit (the
-- build scripts require a fresh clone of it); it is never shipped or required by game code.
-- Hub-local coordinates: O = (0, 0, -1600), floor top y = 0. A "frame" F is a world CFrame whose X is "right"
-- (as seen by someone facing it), Y up and Z toward the viewer: K.lpart / K.ltri build in that frame.

local MS = game:GetService("MaterialService")
local TS = game:GetService("TextService")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local K = {}
local V = Vector3.new
K.O = V(0, 0, -1600)
K.UP = Vector3.yAxis

local function variant(name)
	for _, v in MS:GetDescendants() do
		if v:IsA("MaterialVariant") and v.Name == name then
			return v
		end
	end
	error("missing " .. name)
end
function K.look(var, col, mat)
	if var then
		return { mat = variant(var).BaseMaterial, var = var, col = col }
	end
	return { mat = mat or Enum.Material.SmoothPlastic, col = col }
end
local look = K.look
K.L = {
	board = look("Lobby_ConcreteBoard", Color3.fromRGB(118, 116, 112)),
	trim = look("Concrete-02a", Color3.fromRGB(128, 126, 123)),
	wains = look("Concrete-02a", Color3.fromRGB(88, 87, 85)),
	darkConc = look("Concrete-02a", Color3.fromRGB(62, 62, 64)),
	floor = look("Lobby_ConcretePolished", Color3.fromRGB(98, 96, 93)),
	steel = look("Metal 2022", Color3.fromRGB(120, 122, 126)),
	dark = look("Metal 2022", Color3.fromRGB(52, 54, 58)),
	plate = look("Metal 2022", Color3.fromRGB(34, 36, 40)),
	diamond = look("Diamond Plate 2022", Color3.fromRGB(104, 106, 110)),
	white = look(nil, Color3.fromRGB(126, 120, 112), Enum.Material.Neon),
	glass = look(nil, Color3.fromRGB(200, 214, 220), Enum.Material.Glass),
	rubber = look(nil, Color3.fromRGB(40, 41, 44), Enum.Material.Rubber),
	fabric = look(nil, Color3.fromRGB(46, 46, 50), Enum.Material.Fabric),
}
-- area colours and icons, the same as the lobby HUD tags (StarterGui.LobbyBar.Bottom)
K.AREA = {
	duels = { col = Color3.fromHex("ff6248"), icon = "rbxassetid://126358774182782" },
	locker = { col = Color3.fromHex("3fe0f2"), icon = "rbxassetid://94062620763078" },
	shop = { col = Color3.fromHex("ffc83d"), icon = "rbxassetid://75746609493674" },
	pass = { col = Color3.fromHex("b58cff"), icon = "rbxassetid://124123984170556" },
	range = { col = Color3.fromHex("2bd9a8"), icon = "rbxassetid://79251886607751" },
}
K.RUBIK_HI = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
K.RUBIK_H = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
K.RUBIK_B = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
K.WHITE = Color3.fromRGB(255, 244, 228)
K.WARM = Color3.fromRGB(255, 214, 170)
K.TEX = {
	hazard = "rbxassetid://75158634706115",
	peg = "rbxassetid://120794687026437",
	mesh = "rbxassetid://79156982233553",
}

function K.dim(c, k)
	return c:Lerp(Color3.new(0, 0, 0), k)
end
function K.neon(c)
	return look(nil, c, Enum.Material.Neon)
end
function K.paint(c)
	return look(nil, c, Enum.Material.SmoothPlastic)
end

function K.part(parent, name, size, cf, lk, cls)
	local p = Instance.new(cls or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = lk.mat
	if lk.var then
		p.MaterialVariant = lk.var
	end
	p.Color = lk.col
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
function K.ghost(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end
function K.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
-- hub-local axis-aligned box between two corners
function K.box(parent, name, a, b, lk)
	local lo, hi = a:Min(b), a:Max(b)
	return K.part(parent, name, hi - lo, CFrame.new(K.O + (lo + hi) / 2), lk)
end
-- hub-local wedge: right angle at p, legs along u (length a) and v (length b), thickness th along w
function K.tri(parent, name, p, u, a, v, b, w, th, lk)
	return K.ltri(CFrame.new(K.O), parent, name, p, u, a, v, b, w, th, lk)
end
-- the same two in a frame F
function K.lpart(F, parent, name, a, b, lk)
	local lo, hi = a:Min(b), a:Max(b)
	return K.part(parent, name, hi - lo, F * CFrame.new((lo + hi) / 2), lk)
end
function K.ltri(F, parent, name, p, u, a, v, b, w, th, lk)
	local X, Y = w.Unit, u.Unit
	if X:Cross(Y):Dot(-v.Unit) < 0 then
		X = -X
	end
	local c = p + u.Unit * a / 2 + v.Unit * b / 2
	return K.part(parent, name, V(th, a, b), F * CFrame.fromMatrix(c, X, Y), lk, "WedgePart")
end
-- a frame at hub-local pos whose Z faces `toward` (a horizontal direction)
function K.frame(pos, toward)
	local z = V(toward.X, 0, toward.Z).Unit
	local x = K.UP:Cross(z)
	return CFrame.fromMatrix(K.O + pos, x, K.UP)
end
function K.texture(p, face, id, tile)
	local t = Instance.new("Texture")
	t.Face = face
	t.Texture = id
	t.StudsPerTileU = tile
	t.StudsPerTileV = tile
	t.Parent = p
	return t
end
function K.spot(parent, lensPart, face, col, bright, range, angle)
	local s = Instance.new("SpotLight")
	s.Face = face
	s.Color = col
	s.Brightness = bright
	s.Range = range
	s.Angle = angle
	s.Shadows = false
	s.Parent = lensPart
	return s
end
function K.point(p, col, bright, range)
	local l = Instance.new("PointLight")
	l.Color = col
	l.Brightness = bright
	l.Range = range
	l.Shadows = false
	l.Parent = p
	return l
end
function K.state(inst, name, encoded) -- StateValues: "s" text, "n" number
	local f = inst:FindFirstChild("GauntletState") or Instance.new("Folder")
	f.Name = "GauntletState"
	f.Parent = inst
	local v = Instance.new("StringValue")
	v.Name = name
	v.Value = encoded
	v.Parent = f
end
function K.anchorPart(parent, name, pos)
	local p =
		K.part(parent, name, V(1, 1, 1), CFrame.new(K.O + pos), look(nil, Color3.new(0, 1, 0)))
	p.Transparency = 1
	return K.ghost(p)
end
-- a gun display anchor: Roblox barrel / face directions converted to the Blender axes the client reads
function K.gunAnchor(parent, name, pos, gun, mount, barrel, face, scale, fill, spin)
	local a = K.anchorPart(parent, name, pos)
	K.state(a, "Gun", "s" .. gun)
	K.state(a, "Mount", "s" .. mount)
	K.state(a, "BX", "n" .. barrel.X)
	K.state(a, "BY", "n" .. -barrel.Z)
	K.state(a, "BZ", "n" .. barrel.Y)
	K.state(a, "FX", "n" .. face.X)
	K.state(a, "FY", "n" .. -face.Z)
	K.state(a, "FZ", "n" .. face.Y)
	K.state(a, "Scale", "n" .. scale)
	K.state(a, "Fill", "n" .. fill)
	if spin then
		K.state(a, "Spin", "n" .. spin)
	end
	CS:AddTag(a, "LobbyGunDisplay")
	return a
end
-- a V5Kit mesh template (V5_Pipe8 / V5_Flange8: the axis is X)
function K.mesh(parent, name, tpl, size, cf, lk)
	local m = SS.V5Kit[tpl]:Clone()
	m.Name = name
	m.Size = size
	m.CFrame = cf
	m.Material = lk.mat
	if lk.var then
		m.MaterialVariant = lk.var
	end
	m.Color = lk.col
	m.Parent = parent
	return m
end
-- an octagonal pipe between two hub-local points
function K.pipe(parent, name, a, b, d, lk)
	local dir = (b - a)
	local side = math.abs(dir.Unit:Dot(K.UP)) > 0.9 and Vector3.xAxis or K.UP
	return K.mesh(
		parent,
		name,
		"V5_Pipe8",
		V(dir.Magnitude, d, d),
		CFrame.fromMatrix(K.O + (a + b) / 2, dir.Unit, side),
		lk
	)
end

-- A plate with two cut corners (top-left, bottom-right), centred on the frame's origin, between z0 and z1.
function K.cutPlate(F, parent, name, w, h, c, z0, z1, lk)
	local m = K.model(parent, name)
	local hw, hh, zm, th = w / 2, h / 2, (z0 + z1) / 2, z1 - z0
	K.lpart(F, m, "Mid", V(-hw + c, -hh, z0), V(hw - c, hh, z1), lk)
	K.lpart(F, m, "ColL", V(-hw, -hh, z0), V(-hw + c, hh - c, z1), lk)
	K.lpart(F, m, "ColR", V(hw - c, -hh + c, z0), V(hw, hh, z1), lk)
	K.ltri(F, m, "CutL", V(-hw + c, hh - c, zm), V(-1, 0, 0), c, V(0, 1, 0), c, V(0, 0, 1), th, lk)
	K.ltri(F, m, "CutR", V(hw - c, -hh + c, zm), V(1, 0, 0), c, V(0, -1, 0), c, V(0, 0, 1), th, lk)
	return m
end

local function textWidth(text, font, size)
	local p = Instance.new("GetTextBoundsParams")
	p.Text = text
	p.Font = font
	p.Size = size
	p.Width = 4000
	local ok, v = pcall(function()
		return TS:GetTextBoundsAsync(p)
	end)
	return if ok then v.X else #text * size * 0.72
end

-- THE BADGE: an area's logo. A dark gunmetal plate with two cut corners, a soft accent rim behind it, and on its
-- face (self-lit SurfaceGui) the area's icon on an accent tile, the word in Rubik Heavy Italic and a » subtitle.
-- The plate is as wide as its content. F = the mounting surface (z = 0), the badge centred on its origin.
-- spec: word, sub, col, icon, h (plate height), stand (gap to the wall, brackets fill it), glow (light), bright
function K.badge(F, parent, s)
	local m = K.model(parent, "Badge_" .. string.gsub(s.word, "%s", ""))
	local h = s.h
	local PPS = 24
	local inset = 0.18
	local hpx = (h - 2 * inset) * PPS
	local wordSize = math.min(100, math.floor(0.46 * hpx))
	local subSize = math.floor(0.165 * hpx)
	local subText = "»  " .. s.sub
	local ww = textWidth(s.word, K.RUBIK_HI, wordSize)
	local sw = textWidth(subText, K.RUBIK_B, subSize)
	local tile = math.floor(0.64 * hpx)
	local gap = math.floor(0.16 * hpx)
	local contentW = tile + gap + math.max(ww + 0.06 * wordSize, sw)
	local c = 0.24 * h
	local w = math.max(contentW / PPS + 0.44 * h + 2 * inset, s.minW or 0)

	local z0 = s.stand or 0.1
	local g = 0.2
	K.cutPlate(
		F,
		m,
		"Rim",
		w + 2 * g,
		h + 2 * g,
		c + 0.586 * g,
		z0,
		z0 + 0.25,
		K.neon(K.dim(s.col, s.rimDim or 0.35))
	)
	K.cutPlate(F, m, "Plate", w, h, c, z0 + 0.12, z0 + 0.72, K.L.plate)
	if z0 > 0.05 then
		for _, x in { -w * 0.3, w * 0.3 } do
			K.lpart(F, m, "Bracket", V(x - 0.3, -h * 0.25, 0), V(x + 0.3, h * 0.25, z0), K.L.dark)
		end
	end
	local face = K.part(
		m,
		"Face",
		V(w - 2 * inset, h - 2 * inset, 0.04),
		F * CFrame.new(0, 0, z0 + 0.74) * CFrame.Angles(0, math.pi, 0),
		look(nil, Color3.new(0, 0, 0))
	)
	face.Transparency = 1
	K.ghost(face)
	if (s.glow or 0) > 0 then
		K.point(face, s.col, s.glow, s.glowRange or h * 2)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Logo"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.Brightness = s.bright or 1.15
	gui.MaxDistance = 500
	gui.Parent = face
	local root = Instance.new("Frame")
	root.Name = "Content"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(contentW, hpx)
	root.Parent = gui
	local t = Instance.new("Frame")
	t.Name = "Tile"
	t.BorderSizePixel = 0
	t.BackgroundColor3 = s.col
	t.AnchorPoint = Vector2.new(0, 0.5)
	t.Position = UDim2.fromScale(0, 0.5)
	t.Size = UDim2.fromOffset(tile, tile)
	t.Parent = root
	local ic = Instance.new("ImageLabel")
	ic.Name = "Icon"
	ic.BackgroundTransparency = 1
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	ic.Size = UDim2.fromScale(0.68, 0.68)
	ic.ScaleType = Enum.ScaleType.Fit
	ic.Image = s.icon
	ic.ImageColor3 = Color3.fromRGB(22, 23, 27)
	ic.Parent = t
	local wl = Instance.new("TextLabel")
	wl.Name = "Word"
	wl.BackgroundTransparency = 1
	wl.FontFace = K.RUBIK_HI
	wl.TextSize = wordSize
	wl.TextColor3 = Color3.fromRGB(246, 243, 236)
	wl.Text = s.word
	wl.TextXAlignment = Enum.TextXAlignment.Left
	wl.AnchorPoint = Vector2.new(0, 0.5)
	wl.Position = UDim2.new(0, tile + gap, 0.39, 0)
	wl.Size = UDim2.fromOffset(contentW - tile - gap, wordSize * 1.15)
	wl.Parent = root
	local sl = Instance.new("TextLabel")
	sl.Name = "Sub"
	sl.BackgroundTransparency = 1
	sl.FontFace = K.RUBIK_B
	sl.TextSize = subSize
	sl.RichText = true
	sl.TextColor3 = Color3.fromRGB(196, 194, 188)
	sl.Text = '<font color="#' .. s.col:ToHex() .. '">»</font>  ' .. s.sub
	sl.TextXAlignment = Enum.TextXAlignment.Left
	sl.AnchorPoint = Vector2.new(0, 0.5)
	sl.Position = UDim2.new(0, tile + gap + 2, 0.775, 0)
	sl.Size = UDim2.fromOffset(contentW - tile - gap, subSize * 1.3)
	sl.Parent = root
	return m, w
end

-- THE GATEWAY: an area's entrance frame (Lobby V5 "Entrances" pass). Chunky concrete piers and header the full
-- depth of the doorway; proud pilasters on plinths with sloped caps and inset panels; a cornice with a sloped cap
-- (raised over a fascia where the rock allows); a soft accent light line in a channel beside each pilaster and a lit
-- reveal ring set back in the opening; cut top corners; a lintel beam with downlights; a diamond-plate threshold;
-- and the area's badge standing off the header. F: origin on the floor at the middle of the hub-side face, Z toward
-- the hub. spec: name, W, H (opening), P (pier width), D (depth), T (header top), crown, crownD, cut, cutD, area
-- (K.AREA entry), word, sub, badgeH, thY0, thY1.
function K.gateway(F, parent, s)
	local m = K.model(parent, "Gateway_" .. s.name)
	local hw, ox, D, H = s.W / 2, s.W / 2 + s.P, s.D, s.H
	local T = s.T
	local Tc = T + (s.crown or 0)
	local acc = s.area.col
	local glow = K.neon(K.dim(acc, 0.42))
	local core = K.L.trim
	local pil = look("Concrete-02a", Color3.fromRGB(150, 148, 144))
	local panel = look("Concrete-02a", Color3.fromRGB(112, 110, 107))
	local cornice = look("Concrete-02a", Color3.fromRGB(140, 138, 134))

	-- 1. core: piers and header, the full depth; a fascia over the rock gap's top when there is a crown
	for _, sd in { -1, 1 } do
		K.lpart(F, m, "Pier", V(sd * hw, 0, -D), V(sd * ox, T, 0), core)
	end
	K.lpart(F, m, "Header", V(-hw, H, -D), V(hw, T, 0), core)
	if Tc > T then
		K.lpart(F, m, "Fascia", V(-ox, T, -s.crownD), V(ox, Tc, 0), core)
	end
	-- 2. pilasters on plinths, inset panels, accent light channels beside the opening
	for _, sd in { -1, 1 } do
		K.lpart(F, m, "Pilaster", V(sd * (hw + 0.9), 0, 0), V(sd * (ox - 0.3), Tc - 1, 1.0), pil)
		K.lpart(F, m, "Plinth", V(sd * (hw + 0.7), 0, 0), V(sd * (ox - 0.1), 2.2, 1.4), K.L.wains)
		K.ltri(
			F,
			m,
			"PlinthSlope",
			V(sd * (hw + s.P / 2 + 0.3), 2.2, 1.0),
			V(0, 1, 0),
			0.4,
			V(0, 0, 1),
			0.4,
			V(1, 0, 0),
			s.P - 0.8,
			K.L.wains
		)
		local pa, pb = hw + 1.5, ox - 0.9
		if pb - pa > 0.8 then
			K.lpart(F, m, "Panel", V(sd * pa, 3.2, 1.0), V(sd * pb, Tc - 3.0, 1.06), panel)
		end
		K.lpart(
			F,
			m,
			"Channel",
			V(sd * (hw + 0.15), 2.4, 0),
			V(sd * (hw + 0.75), Tc - 1.4, 0.3),
			K.L.dark
		)
		K.ghost(
			K.lpart(
				F,
				m,
				"Strip",
				V(sd * (hw + 0.35), 2.6, 0.3),
				V(sd * (hw + 0.55), Tc - 1.6, 0.36),
				glow
			)
		)
	end
	-- 3. cornice and its sloped cap
	K.lpart(F, m, "Cornice", V(-ox - 0.3, Tc - 1, 0), V(ox + 0.3, Tc, 1.3), cornice)
	K.ltri(
		F,
		m,
		"CorniceCap",
		V(0, Tc, 0),
		V(0, 1, 0),
		0.7,
		V(0, 0, 1),
		1.3,
		V(1, 0, 0),
		2 * ox + 0.6,
		cornice
	)
	-- 4. the opening: cut corners, lintel beam with downlights, a lit reveal ring, the threshold
	local cut, cutD = s.cut, s.cutD or D
	for _, sd in { -1, 1 } do
		K.ltri(
			F,
			m,
			"Cut",
			V(sd * hw, H, -cutD / 2),
			V(0, -1, 0),
			cut,
			V(-sd, 0, 0),
			cut,
			V(0, 0, 1),
			cutD,
			core
		)
	end
	local beam = K.model(m, "Beam")
	local bx = hw - cut + 0.7
	K.lpart(F, beam, "Body", V(-bx, H - 0.7, -1.5), V(bx, H, -0.2), K.L.dark)
	local xs = if s.W > 20 then { -bx * 0.6, 0, bx * 0.6 } else { -bx * 0.45, bx * 0.45 }
	for _, x in xs do
		local lens = K.ghost(
			K.lpart(
				F,
				beam,
				"Lens",
				V(x - 0.9, H - 0.76, -1.15),
				V(x + 0.9, H - 0.7, -0.55),
				K.L.white
			)
		)
		K.spot(beam, lens, Enum.NormalId.Bottom, K.WHITE, 1.3, H + 4, 100)
	end
	local ring = K.model(m, "Reveal")
	local rz0, rz1 = -2.2, -1.8
	for _, sd in { -1, 1 } do
		K.ghost(
			K.lpart(
				F,
				ring,
				"Side",
				V(sd * hw, s.thY1 + 0.04, rz0),
				V(sd * (hw - 0.14), H - cut, rz1),
				glow
			)
		)
		local A, B = V(sd * hw, H - cut, 0), V(sd * (hw - cut), H, 0)
		local d, n = (B - A).Unit, V(-sd, -1, 0).Unit
		local c = (A + B) / 2 + n * 0.075 + V(0, 0, (rz0 + rz1) / 2)
		K.ghost(
			K.part(
				ring,
				"Diag",
				V((B - A).Magnitude, 0.14, rz1 - rz0),
				F * CFrame.fromMatrix(c, d, n),
				glow
			)
		)
	end
	K.ghost(K.lpart(F, ring, "Top", V(-(hw - cut), H - 0.14, rz0), V(hw - cut, H, rz1), glow))
	K.lpart(F, m, "Threshold", V(-hw, s.thY0, -D), V(hw, s.thY1, 0.4), K.L.diamond)
	-- 5. the badge on stand-offs, washed by two small lamps under the cornice
	local by = (H + Tc - 1) / 2
	K.badge(F * CFrame.new(0, by, 0), m, {
		word = s.word,
		sub = s.sub,
		col = acc,
		icon = s.area.icon,
		h = s.badgeH,
		stand = 1.1,
		glow = 0.55,
	})
	for _, sd in { -1, 1 } do
		local lamp = K.lpart(
			F,
			m,
			"WashLamp",
			V(sd * hw * 0.55 - 0.5, Tc - 1.3, 0.2),
			V(sd * hw * 0.55 + 0.5, Tc - 1, 0.7),
			K.L.dark
		)
		K.spot(m, lamp, Enum.NormalId.Bottom, K.WARM, 0.9, 10, 110)
	end
	return m
end

return K
