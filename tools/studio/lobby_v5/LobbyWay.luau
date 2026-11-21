--!nocheck
-- Lobby V5 WAYFINDING SIGNS v3 (vault/02 Art/Lobby V5 Plan.md, "Signs v3"). Installed in Studio as the ModuleScript
-- ServerStorage.V5Kit.LobbyWay; build scripts require a clone. Owner 2026-11-21 on the v2 signs: "I don't really like
-- the look of them ... they just don't fit our vibe, and we need to make something new".
-- Our vibe is an underground facility (The Deep), so these are facility wayfinding signs, not neon: a dark steel
-- cabinet with one cut corner (the UI theme's plate) on a steel rim, a raised accent tile carrying the area's HUD
-- icon (or a short code such as a bay number or "1V1"), the word in flat white Rubik Heavy, a ruled sub-label in the
-- accent, a small zone code, corner bolts; lit from above by gooseneck lamps (a real light on every sign).
-- W.sign(Fh, parent, s): Fh = frame at the TOP-EDGE centre of the face, z toward the reader. s: word, sub, code,
-- icon | tileText, col, h, tilt (deg, face turns down; bottom swings back), lamps (bool), mount = "wall" (stand-offs
-- back to z = -standoff) | "hang" (rods up to y = hang) | "stand" (posts down by `stand`) | nil, name.
-- Returns the model, its width and the face frame Fs (centre).

local TS = game:GetService("TextService")
local K = require(game:GetService("ServerStorage").V5Kit.LobbyKit:Clone())
local V = Vector3.new
local W = {}
W.K = K
local INK = Color3.fromRGB(18, 19, 22)
local BONE = Color3.fromRGB(242, 239, 232)
local PPS = 40

local function textWidth(text, font, size)
	local p = Instance.new("GetTextBoundsParams")
	p.Text = text
	p.Font = font
	p.Size = size
	p.Width = 4000
	local ok, v = pcall(function()
		return TS:GetTextBoundsAsync(p)
	end)
	return if ok then v.X else #text * size * 0.7
end
W.textWidth = textWidth

-- a plate between z0 and z1 centred on Fx, with its top-right corner cut by c
function W.cutPlate(Fx, parent, name, w, h, c, z0, z1, lk)
	local m = K.model(parent, name)
	local hw, hh = w / 2, h / 2
	K.lpart(Fx, m, "Mid", V(-hw, -hh, z0), V(hw - c, hh, z1), lk)
	K.lpart(Fx, m, "Col", V(hw - c, -hh, z0), V(hw, hh - c, z1), lk)
	K.ltri(
		Fx,
		m,
		"Cut",
		V(hw - c, hh - c, (z0 + z1) / 2),
		V(1, 0, 0),
		c,
		V(0, 1, 0),
		c,
		V(0, 0, 1),
		z1 - z0,
		lk
	)
	return m
end

-- an invisible part whose SurfaceGui faces +z of Fx at depth z
function W.face(Fx, parent, name, w, h, z, light)
	local p = K.part(
		parent,
		name,
		V(w, h, 0.02),
		Fx * CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi, 0),
		K.paint(Color3.new(0, 0, 0))
	)
	p.Transparency = 1
	K.ghost(p)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = PPS
	g.LightInfluence = light or 0.35
	g.Brightness = 1.1
	g.Parent = p
	return g, p
end

local function label(parent, text, font, size, col, pos, sz, ax, ay)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = sz
	t.FontFace = font
	t.TextSize = size
	t.Text = text
	t.TextColor3 = col
	t.TextXAlignment = ax or Enum.TextXAlignment.Left
	t.TextYAlignment = ay or Enum.TextYAlignment.Center
	t.Parent = parent
	return t
end
W.label = label

-- a gooseneck lamp standing on a sign's top edge (frame Fs, sign centre), aimed at the face
function W.gooseneck(Fs, parent, x, top, col)
	local m = K.model(parent, "Gooseneck")
	K.lpart(
		Fs,
		m,
		"Shoe",
		V(x - 0.28, top - 0.05, -0.55),
		V(x + 0.28, top + 0.16, -0.12),
		K.L.steel
	)
	K.lpart(Fs, m, "Riser", V(x - 0.07, top + 0.16, -0.4), V(x + 0.07, top + 0.95, -0.26), K.L.dark)
	K.lpart(
		Fs,
		m,
		"Knuckle",
		V(x - 0.12, top + 0.9, -0.45),
		V(x + 0.12, top + 1.08, -0.2),
		K.L.steel
	)
	K.lpart(Fs, m, "Arm", V(x - 0.07, top + 0.93, -0.2), V(x + 0.07, top + 1.05, 0.8), K.L.dark)
	local c = V(x, top + 0.85, 0.95)
	local aim = V(x * 0.6, 0, 0.05)
	local dir = (aim - c).Unit
	local side = Vector3.yAxis:Cross(dir).Unit
	local up = dir:Cross(side).Unit
	K.mesh(m, "Shade", "V5_Pipe8", V(0.5, 0.42, 0.42), Fs * CFrame.fromMatrix(c, dir, up), K.L.dark)
	K.mesh(
		m,
		"Lens",
		"V5_Flange8",
		V(0.04, 0.32, 0.32),
		Fs * CFrame.fromMatrix(c + dir * 0.26, dir, up),
		K.L.white
	).CastShadow =
		false
	local lp = K.ghost(
		K.part(
			m,
			"Light",
			V(0.1, 0.1, 0.1),
			Fs * CFrame.lookAt(c + dir * 0.3, aim),
			K.paint(K.WARM)
		)
	)
	lp.Transparency = 1
	K.spot(m, lp, Enum.NormalId.Front, col or K.WARM, 1.1, 9, 75)
	return m
end

function W.sign(Fh, parent, s)
	local m = K.model(parent, s.name or ("Sign_" .. string.gsub(s.word, "%s", "")))
	local H = s.h
	local col = s.col
	local tilt = math.rad(s.tilt or 0)
	local Fs = Fh * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, -H / 2, 0)
	local wordPx = math.min(100, math.floor(H * 0.4 * PPS))
	local subPx = math.min(60, math.floor(H * 0.15 * PPS))
	local ww = math.max(
		textWidth(s.word, K.RUBIK_H, wordPx),
		s.sub and textWidth(s.sub, K.RUBIK_B, subPx) or 0
	) / PPS
	local T = H - 0.5
	local padL = 0.25 + T + 0.55
	local Wd = padL + ww + 1.0
	local c = 0.3 * H
	local hw, hh = Wd / 2, H / 2
	-- cabinet on a steel rim, corner bolts
	W.cutPlate(Fs, m, "Rim", Wd + 0.3, H + 0.3, c + 0.12, -0.62, -0.12, K.L.steel)
	W.cutPlate(Fs, m, "Cabinet", Wd, H, c, -0.5, 0, K.L.plate)
	for _, p in
		{ V(hw - c - 0.3, hh - 0.22, 0), V(hw - 0.22, -hh + 0.22, 0) } -- clear of the accent tile
	do
		K.lpart(Fs, m, "Bolt", p - V(0.09, 0.09, 0), p + V(0.09, 0.09, 0.06), K.L.steel)
	end
	-- accent tile with the icon or a code
	local tx = -hw + 0.25 + T / 2
	local Ft = Fs * CFrame.new(tx, 0, 0)
	K.lpart(Ft, m, "Tile", V(-T / 2, -T / 2, 0), V(T / 2, T / 2, 0.1), K.paint(col))
	K.lpart(
		Ft,
		m,
		"TileEdge",
		V(-T / 2 - 0.06, -T / 2 - 0.06, -0.02),
		V(T / 2 + 0.06, T / 2 + 0.06, 0.06),
		K.paint(K.dim(col, 0.45))
	)
	local tg = W.face(Ft, m, "TileFace", T, T, 0.11, 0.25)
	if s.icon then
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		ic.Size = UDim2.fromScale(0.72, 0.72)
		ic.Image = s.icon
		ic.ImageColor3 = INK
		ic.Parent = tg
	else
		label(
			tg,
			s.tileText or "",
			K.RUBIK_H,
			math.min(100, math.floor(T * PPS * (#(s.tileText or "") > 2 and 0.42 or 0.58))),
			INK,
			UDim2.new(),
			UDim2.fromScale(1, 1),
			Enum.TextXAlignment.Center
		)
	end
	-- word, rule, sub-label, code
	local ax0, ax1 = -hw + padL, hw - 0.5
	local Fw = Fs * CFrame.new((ax0 + ax1) / 2, 0, 0)
	local g, facePart = W.face(Fw, m, "WordFace", ax1 - ax0, H - 0.3, 0.02)
	local wordY = if s.sub then 0.06 else 0.2
	local wordH = if s.sub then 0.52 else 0.6
	local wl = label(
		g,
		s.word,
		K.RUBIK_H,
		wordPx,
		BONE,
		UDim2.fromScale(0, wordY),
		UDim2.fromScale(1, wordH)
	)
	wl.TextYAlignment = Enum.TextYAlignment.Bottom
	if s.sub then
		local rule = Instance.new("Frame")
		rule.BorderSizePixel = 0
		rule.BackgroundColor3 = K.dim(col, 0.25)
		rule.Position = UDim2.new(0, 0, 0.62, 0)
		rule.Size = UDim2.new(0, math.floor(ww * PPS), 0, math.max(2, math.floor(H * 2)))
		rule.Parent = g
		label(g, s.sub, K.RUBIK_B, subPx, col, UDim2.fromScale(0, 0.68), UDim2.fromScale(1, 0.24))
	end
	if s.code then
		label(
			g,
			s.code,
			K.RUBIK_B,
			math.floor(H * 0.09 * PPS),
			Color3.fromRGB(150, 150, 156),
			UDim2.fromScale(0, 0.84),
			UDim2.fromScale(1, 0.14),
			Enum.TextXAlignment.Right
		)
	end
	-- mounts
	local xs = { -Wd * 0.3, Wd * 0.3 }
	if s.mount == "wall" then
		local back = -(s.standoff or 1.0)
		for _, x in xs do
			K.lpart(
				Fs,
				m,
				"Standoff",
				V(x - 0.18, -0.25, back + 0.1),
				V(x + 0.18, 0.25, -0.62),
				K.L.dark
			)
			K.lpart(
				Fs,
				m,
				"WallPlate",
				V(x - 0.4, -0.55, back),
				V(x + 0.4, 0.55, back + 0.1),
				K.L.steel
			)
		end
	elseif s.mount == "hang" then
		local hang = s.hang or 1.5
		for _, x in xs do
			K.lpart(Fh, m, "Rod", V(x - 0.07, 0, -0.32), V(x + 0.07, hang, -0.18), K.L.steel)
			K.lpart(
				Fh,
				m,
				"Turnbuckle",
				V(x - 0.12, hang * 0.45, -0.37),
				V(x + 0.12, hang * 0.45 + 0.4, -0.13),
				K.L.dark
			)
			K.lpart(
				Fh,
				m,
				"CeilingPlate",
				V(x - 0.4, hang, -0.65),
				V(x + 0.4, hang + 0.12, 0.15),
				K.L.dark
			)
			K.lpart(
				Fs,
				m,
				"Clamp",
				V(x - 0.25, hh - 0.15, -0.6),
				V(x + 0.25, hh + 0.12, 0.04),
				K.L.dark
			)
		end
	elseif s.mount == "stand" then
		local st = s.stand or 1.0
		for _, x in xs do
			K.lpart(Fs, m, "Post", V(x - 0.16, -hh - st, -0.41), V(x + 0.16, -hh, -0.09), K.L.dark)
			K.lpart(
				Fs,
				m,
				"Shoe",
				V(x - 0.35, -hh - st - 0.4, -0.6),
				V(x + 0.35, -hh - st, 0.1),
				K.L.steel
			)
		end
	end
	if s.lamps then
		for _, x in { -Wd * 0.22, Wd * 0.18 } do
			W.gooseneck(Fs, m, x, hh, s.lampCol)
		end
	end
	return m, Wd, Fs, facePart
end

-- a dark screen board's content (SurfaceGui `g`): icon, title, sub, an accent slash and corner ticks
function W.board(g, s)
	local bg = Instance.new("Frame")
	bg.Name = "Board"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.fromRGB(22, 23, 27)
	bg.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 160))
	grad.Parent = bg
	local band = Instance.new("Frame")
	band.BorderSizePixel = 0
	band.BackgroundColor3 = K.dim(s.col, 0.55)
	band.Position = UDim2.fromScale(0, 0.86)
	band.Size = UDim2.fromScale(1, 0.14)
	band.Parent = bg
	if s.icon then
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.2, 0.45)
		ic.Size = UDim2.fromScale(0.5, 0.5)
		ic.SizeConstraint = Enum.SizeConstraint.RelativeYY
		ic.Image = s.icon
		ic.ImageColor3 = s.col
		ic.Parent = bg
	end
	local x0 = if s.icon then 0.36 else 0.08
	local hpx = s.px -- the board's height in pixels (part height x PixelsPerStud)
	label(
		bg,
		s.title,
		K.RUBIK_H,
		math.min(100, math.floor(hpx * 0.24)),
		BONE,
		UDim2.fromScale(x0, 0.16),
		UDim2.fromScale(0.95 - x0, 0.36)
	)
	if s.sub then
		label(
			bg,
			s.sub,
			K.RUBIK_B,
			math.min(60, math.floor(hpx * 0.09)),
			s.col,
			UDim2.fromScale(x0, 0.52),
			UDim2.fromScale(0.95 - x0, 0.14)
		)
	end
	if s.foot then
		label(
			bg,
			s.foot,
			K.RUBIK_B,
			math.min(50, math.floor(hpx * 0.07)),
			Color3.fromRGB(20, 20, 22),
			UDim2.fromScale(0.04, 0.86),
			UDim2.fromScale(0.92, 0.14)
		)
	end
	for _, c in { { 0.02, 0.04, 0 }, { 0.98, 0.04, 1 } } do
		local tick = Instance.new("Frame")
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = s.col
		tick.AnchorPoint = Vector2.new(c[3], 0)
		tick.Position = UDim2.fromScale(c[1], c[2])
		tick.Size = UDim2.fromScale(0.06, 0.02)
		tick.Parent = bg
	end
	return bg
end

return W
