--!nocheck
-- Lobby V5 sign kit v2 and entrance steel (vault/02 Art/Lobby V5 Plan.md, "Character pass"). Installed in the place as
-- the ModuleScript ServerStorage.V5Kit.LobbySigns (it requires a fresh clone of LobbyKit); build tool only.
-- A sign hangs from a frame Fh at its top edge (x right, y up, z toward the viewer), tilted down at the viewer:
-- a slanted dark plate in a steel frame with accent inlay lines, a faceted medallion with the area's 3D emblem
-- breaking out of its left end, extruded letters (stacked Rubik Heavy Italic layers), a slanted sub-tag hanging
-- under its right end, hanger rods with clamps and bolts. Every piece is a Part.

local TS = game:GetService("TextService")
local K = require(game:GetService("ServerStorage").V5Kit.LobbyKit:Clone())
local V = Vector3.new
local S = {}
S.K = K

local INK = Color3.fromRGB(18, 19, 22)
local BONE = K.look(nil, Color3.fromRGB(232, 229, 220), Enum.Material.SmoothPlastic)

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
S.textWidth = textWidth

-- a slanted plate (top edge shifted right by `lean`), centred, between z0 and z1
function S.slant(F, parent, name, w, h, lean, z0, z1, lk)
	local m = K.model(parent, name)
	local hw, hh, zm, th = w / 2, h / 2, (z0 + z1) / 2, z1 - z0
	K.lpart(F, m, "Mid", V(-hw + lean, -hh, z0), V(hw - lean, hh, z1), lk)
	K.ltri(
		F,
		m,
		"EndL",
		V(-hw + lean, -hh, zm),
		V(-1, 0, 0),
		lean,
		V(0, 1, 0),
		h,
		V(0, 0, 1),
		th,
		lk
	)
	K.ltri(F, m, "EndR", V(hw - lean, hh, zm), V(1, 0, 0), lean, V(0, -1, 0), h, V(0, 0, 1), th, lk)
	return m
end

-- a regular octagon plate of width d (flat to flat), centred, between z0 and z1
function S.octagon(F, parent, name, d, z0, z1, lk)
	local m = K.model(parent, name)
	local a = d / 2
	local s = d * 0.41421356 / 2
	local zm, th = (z0 + z1) / 2, z1 - z0
	K.lpart(F, m, "H", V(-a, -s, z0), V(a, s, z1), lk)
	K.lpart(F, m, "V", V(-s, -a, z0), V(s, a, z1), lk)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			K.ltri(
				F,
				m,
				"C",
				V(sx * s, sy * s, zm),
				V(sx, 0, 0),
				a - s,
				V(0, sy, 0),
				a - s,
				V(0, 0, 1),
				th,
				lk
			)
		end
	end
	return m
end

-- a bar between two points in the frame's xy plane (z0..z1), width w
local function bar(F, parent, name, a, b, w, z0, z1, lk)
	local d = b - a
	local len = d.Magnitude
	local x = d.Unit
	local y = V(-x.Y, x.X, 0)
	local c = (a + b) / 2 + V(0, 0, (z0 + z1) / 2)
	return K.part(parent, name, V(len, w, z1 - z0), F * CFrame.fromMatrix(c, x, y), lk)
end
S.bar = bar

-- EMBLEMS: built in a frame at the medallion's face (z = 0 up to `t`), unit u = half the emblem's size
local EMBLEM = {}
function EMBLEM.padlock(F, m, u, t, lk, dark)
	K.lpart(F, m, "Body", V(-0.62 * u, -0.85 * u, 0), V(0.62 * u, 0.12 * u, t), lk)
	-- shackle: two legs and a top with chamfered corners
	for _, sx in { -1, 1 } do
		K.lpart(F, m, "Leg", V(sx * 0.46 * u, 0.12 * u, 0), V(sx * 0.27 * u, 0.62 * u, t * 0.8), lk)
	end
	K.lpart(F, m, "Top", V(-0.27 * u, 0.8 * u, 0), V(0.27 * u, 0.99 * u, t * 0.8), lk)
	for _, sx in { -1, 1 } do
		bar(
			F,
			m,
			"Corner",
			V(sx * 0.365 * u, 0.6 * u, 0),
			V(sx * 0.2 * u, 0.9 * u, 0),
			0.2 * u,
			0,
			t * 0.8,
			lk
		)
	end
	K.lpart(F, m, "Keyhole", V(-0.09 * u, -0.42 * u, t), V(0.09 * u, -0.18 * u, t + 0.03), dark)
	K.lpart(F, m, "KeySlot", V(-0.045 * u, -0.62 * u, t), V(0.045 * u, -0.4 * u, t + 0.03), dark)
end
function EMBLEM.crosshair(F, m, u, t, lk, dark)
	local r, w = 0.62 * u, 0.15 * u
	for i = 0, 7 do
		local a0, a1 = math.rad(22.5 + i * 45), math.rad(22.5 + (i + 1) * 45)
		local R = r / math.cos(math.rad(22.5))
		bar(
			F,
			m,
			"Ring",
			V(math.cos(a0) * R, math.sin(a0) * R, 0),
			V(math.cos(a1) * R, math.sin(a1) * R, 0),
			w,
			0,
			t,
			lk
		)
	end
	for _, d in { V(1, 0, 0), V(-1, 0, 0), V(0, 1, 0), V(0, -1, 0) } do
		bar(F, m, "Tick", d * 0.3 * u, d * 1.0 * u, 0.13 * u, 0, t, lk)
	end
	local c = K.part(
		m,
		"Dot",
		V(0.22 * u, 0.22 * u, t),
		F * CFrame.new(0, 0, t / 2) * CFrame.Angles(0, 0, math.rad(45)),
		lk
	)
	c.Name = "Dot"
end
function EMBLEM.bag(F, m, u, t, lk, dark)
	-- tapered body (wider at the bottom), a fold band, a handle
	K.lpart(F, m, "Body", V(-0.5 * u, -0.85 * u, 0), V(0.5 * u, 0.3 * u, t), lk)
	for _, sx in { -1, 1 } do
		K.ltri(
			F,
			m,
			"Flare",
			V(sx * 0.5 * u, -0.85 * u, t / 2),
			V(0, 1, 0),
			1.15 * u,
			V(sx, 0, 0),
			0.16 * u,
			V(0, 0, 1),
			t,
			lk
		)
	end
	K.lpart(F, m, "Band", V(-0.53 * u, 0.12 * u, t), V(0.53 * u, 0.22 * u, t + 0.03), dark)
	for _, sx in { -1, 1 } do
		K.lpart(
			F,
			m,
			"HandleLeg",
			V(sx * 0.32 * u, 0.3 * u, t * 0.2),
			V(sx * 0.18 * u, 0.72 * u, t * 0.8),
			lk
		)
	end
	K.lpart(F, m, "HandleTop", V(-0.32 * u, 0.72 * u, t * 0.2), V(0.32 * u, 0.86 * u, t * 0.8), lk)
end
function EMBLEM.versus(F, m, u, t, lk, dark)
	-- two chevrons clashing, a spark between them
	for _, sx in { -1, 1 } do
		local tip = V(sx * 0.17 * u, 0, 0) -- "> <": the tips face each other across a gap
		bar(F, m, "Chevron", tip + V(sx * 0.58 * u, 0.62 * u, 0), tip, 0.24 * u, 0, t, lk)
		bar(F, m, "Chevron", tip + V(sx * 0.58 * u, -0.62 * u, 0), tip, 0.24 * u, 0, t, lk)
	end
	local s = K.part(
		m,
		"Spark",
		V(0.3 * u, 0.3 * u, t + 0.04),
		F * CFrame.new(0, 0, (t + 0.04) / 2) * CFrame.Angles(0, 0, math.rad(45)),
		dark
	)
	s.Name = "Spark"
end
function EMBLEM.rank(F, m, u, t, lk, dark)
	-- two stacked chevrons pointing up and a diamond over them
	for i, y in { -0.55, -0.1 } do
		bar(F, m, "Chevron", V(-0.7 * u, (y - 0.38) * u, 0), V(0, y * u, 0), 0.22 * u, 0, t, lk)
		bar(F, m, "Chevron", V(0.7 * u, (y - 0.38) * u, 0), V(0, y * u, 0), 0.22 * u, 0, t, lk)
	end
	local d = K.part(
		m,
		"Gem",
		V(0.42 * u, 0.42 * u, t),
		F * CFrame.new(0, 0.55 * u, t / 2) * CFrame.Angles(0, 0, math.rad(45)),
		lk
	)
	d.Name = "Gem"
end
S.EMBLEM = EMBLEM

-- stacked text: `layers` dark extrusion layers behind a bright face; each layer is a transparent part with a
-- SurfaceGui, offset back in z and down-right in the GUI so the letters read solid from any angle
function S.textStack(F, parent, name, text, font, size, w, h, col, depthCol, z0, layers, align)
	local m = K.model(parent, name)
	local PPS = 24
	for i = layers, 0, -1 do
		local front = i == 0
		local p = K.part(
			m,
			front and "Face" or "Depth",
			V(w, h, 0.02),
			F * CFrame.new(0, 0, z0 + (layers - i) * 0.05 + 0.01) * CFrame.Angles(0, math.pi, 0),
			K.paint(Color3.new(0, 0, 0))
		)
		p.Transparency = 1
		K.ghost(p)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = PPS
		g.LightInfluence = front and 0 or 0.4
		g.Brightness = front and 1.25 or 1
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Position = UDim2.fromOffset(i * 1.5, i * 1.5)
		t.FontFace = font
		t.TextSize = size
		t.Text = text
		t.TextColor3 = front and col or depthCol
		t.TextXAlignment = align or Enum.TextXAlignment.Center
		t.Parent = g
		if front then
			local st = Instance.new("UIStroke")
			st.Color = INK
			st.Thickness = 1.5
			st.Parent = t
		end
	end
	return m
end

-- THE SIGN. spec: word, sub, col, emblem, h, hang (rod length), tilt (degrees), lamps (bool), name
function S.sign(Fh, parent, s)
	local m = K.model(parent, s.name or ("Sign_" .. string.gsub(s.word, "%s", "")))
	local H = s.h
	local PPS = 24
	local wordSize = math.min(100, math.floor((H - 0.5) * PPS * 0.66))
	local ww = textWidth(s.word, K.RUBIK_HI, wordSize) / PPS
	local D = 1.45 * H -- medallion width
	local lean = 0.2 * H
	local textL = 0.62 * D -- the medallion covers the plate's left end this far
	local W = textL + 0.25 * H + ww + 0.35 * H + lean
	local tilt = math.rad(s.tilt or 12)
	local Fs = Fh * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, -(H / 2 + 0.3), 0)
	local col = s.col

	-- frame, plate, inlay lines
	S.slant(Fs, m, "Frame", W + 0.6, H + 0.6, lean * (H + 0.6) / H, -0.5, 0.05, K.L.steel)
	S.slant(Fs, m, "Plate", W, H, lean, -0.3, 0.45, K.L.plate)
	local glow = K.neon(K.dim(col, 0.4))
	K.ghost(
		K.lpart(
			Fs,
			m,
			"InlayTop",
			V(-W / 2 + textL, H / 2 - 0.34, 0.45),
			V(W / 2 - 0.55, H / 2 - 0.2, 0.5),
			glow
		)
	)
	K.ghost(
		K.lpart(
			Fs,
			m,
			"InlayBottom",
			V(-W / 2 + textL, -H / 2 + 0.2, 0.45),
			V(W / 2 - lean - 0.35, -H / 2 + 0.34, 0.5),
			glow
		)
	)
	-- bolts on the frame corners
	for _, p in
		{
			V(W / 2 - lean * 0.2 - 0.05, H / 2 + 0.12, 0.05),
			V(W / 2 - lean - 0.2, -H / 2 - 0.12, 0.05),
		}
	do
		K.lpart(Fs, m, "Bolt", p - V(0.12, 0.12, 0), p + V(0.12, 0.12, 0.08), K.L.dark)
	end
	-- letters
	local areaL, areaR = -W / 2 + textL + 0.25 * H, W / 2 - lean - 0.2 * H
	local Ft = Fs * CFrame.new((areaL + areaR) / 2, 0.02 * H, 0)
	S.textStack(
		Ft,
		m,
		"Word",
		s.word,
		K.RUBIK_HI,
		wordSize,
		areaR - areaL + 1,
		H - 0.4,
		Color3.fromRGB(246, 243, 236),
		K.dim(col, 0.62),
		0.46,
		3
	)

	-- medallion with the emblem, breaking out of the left end
	local Fm = Fs * CFrame.new(-W / 2 + 0.2 * H, 0, 0)
	S.octagon(Fm, m, "MedallionBack", D, -0.55, 0.62, K.L.steel)
	S.octagon(Fm, m, "MedallionRing", D * 0.86, 0.62, 0.72, K.neon(K.dim(col, 0.3)))
	S.octagon(Fm, m, "MedallionFace", D * 0.72, 0.72, 0.82, K.L.plate)
	local em = K.model(m, "Emblem")
	local fn = EMBLEM[s.emblem] or EMBLEM.crosshair
	fn(
		Fm * CFrame.new(0, 0, 0.82),
		em,
		D * 0.27,
		0.28,
		K.paint(col:Lerp(Color3.new(1, 1, 1), 0.15)),
		K.paint(INK)
	)
	for _, d in em:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	K.point(
		K.ghost(K.lpart(Fm, m, "EmblemGlow", V(-0.1, -0.1, 1.2), V(0.1, 0.1, 1.4), K.paint(col))),
		col,
		0.5,
		D * 1.4
	).Parent.Transparency =
		1

	-- sub-tag under the right end
	if s.sub then
		local tagH = 0.36 * H
		local subSize = math.floor((tagH - 0.12) * PPS * 0.62)
		local tw = textWidth(s.sub, K.RUBIK_B, subSize) / PPS + 0.9
		local tlean = lean * tagH / H
		local cx = W / 2 - lean - tw / 2 - 0.4 * H
		local Ftag = Fs * CFrame.new(cx, -H / 2 - tagH / 2 + 0.12, 0)
		S.slant(Ftag, m, "Tag", tw, tagH, tlean, -0.2, 0.3, K.paint(K.dim(col, 0.08)))
		local p = K.part(
			m,
			"TagText",
			V(tw - 2 * tlean, tagH, 0.02),
			Ftag * CFrame.new(0, 0, 0.32) * CFrame.Angles(0, math.pi, 0),
			K.paint(Color3.new(0, 0, 0))
		)
		p.Transparency = 1
		K.ghost(p)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = PPS
		g.LightInfluence = 0.3
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.FontFace = K.RUBIK_B
		t.TextSize = subSize
		t.Text = s.sub
		t.TextColor3 = INK
		t.Parent = g
	end

	-- hangers: rods from the mount down to clamps on the frame's top edge (rods stay vertical, in Fh)
	local hang = s.hang or 1.2
	local rods = { -W / 2 + textL + 0.8, W / 2 - lean - 1.0 }
	if hang > 0 then
		for _, x in rods do
			K.lpart(Fh, m, "Rod", V(x - 0.09, 0, -0.29), V(x + 0.09, hang, -0.11), K.L.steel)
			K.lpart(Fh, m, "Clamp", V(x - 0.3, -0.05, -0.45), V(x + 0.3, 0.3, 0.05), K.L.dark)
			if not s.noPlate then
				K.lpart(
					Fh,
					m,
					"Plate",
					V(x - 0.45, hang, -0.65),
					V(x + 0.45, hang + 0.15, 0.25),
					K.L.dark
				)
			end
		end
	end
	if s.lamps then
		for _, x in { -W * 0.12, W * 0.28 } do
			local lamp = K.lpart(
				Fh,
				m,
				"Lamp",
				V(x - 0.45, hang - 0.4, 1.7),
				V(x + 0.45, hang, 2.4),
				K.L.dark
			)
			K.lpart(
				Fh,
				m,
				"LampArm",
				V(x - 0.08, hang - 0.15, -0.1),
				V(x + 0.08, hang, 1.7),
				K.L.dark
			)
			K.spot(m, lamp, Enum.NormalId.Bottom, K.WARM, 1.1, 10, 75)
		end
	end
	return m, W, rods
end

-- a stencil/caution plate on a wall frame F (z = wall face): kind "caution" (yellow) / "id" (dark) / "warning" (red)
function S.plate(F, parent, name, w, h, lines, kind)
	local m = K.model(parent, name)
	local bg = if kind == "caution"
		then Color3.fromRGB(232, 182, 34)
		elseif kind == "warning" then Color3.fromRGB(196, 52, 46)
		else Color3.fromRGB(34, 36, 40)
	local fg = if kind == "caution" then INK else Color3.fromRGB(240, 236, 228)
	local p = K.lpart(F, m, "Plate", V(-w / 2, -h / 2, 0), V(w / 2, h / 2, 0.06), K.paint(bg))
	K.lpart(
		F,
		m,
		"Edge",
		V(-w / 2 - 0.06, -h / 2 - 0.06, -0.02),
		V(w / 2 + 0.06, h / 2 + 0.06, 0.03),
		K.paint(kind == "id" and Color3.fromRGB(120, 122, 126) or INK)
	)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0.6
	g.Parent = p
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = g
	for i, line in lines do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.LayoutOrder = i
		t.Size = UDim2.new(1, 0, 0, line.size * 1.15)
		t.FontFace = if line.heavy then K.RUBIK_H else K.RUBIK_B
		t.TextSize = line.size
		t.Text = line.text
		t.TextColor3 = fg
		t.Parent = g
	end
	return m
end

-- ENTRANCE STEEL for a K.gateway (same F and spec): outrigger beams with knee braces to hang the sign from, steel
-- capitals on the pilasters, hazard kick plates in the jambs, a gate ID plate, a caution plate, a status lamp, a
-- conduit with a junction box, floor chevrons; then the sign. spec adds: gateId, caution {lines}, emblem, signH, sub
function S.gatewaySteel(F, gate, s)
	local hw, ox = s.W / 2, s.W / 2 + s.P
	local Tc = s.T + (s.crown or 0)
	local col = s.area.col
	local m = K.model(gate, "Steel")
	-- the sign first (its hanger rods set where the outriggers go), hung from the outrigger tips
	local reach = s.reach or 3.4
	local hang = s.hang or 1.0
	local Fh = F * CFrame.new(0, Tc + 0.7 - hang, reach - 0.25)
	local sign, _, rods = S.sign(Fh, gate, {
		word = s.word,
		sub = s.sub,
		col = col,
		emblem = s.emblem,
		h = s.signH,
		hang = hang,
		tilt = 12,
		noPlate = true,
	})
	-- outriggers over the cornice cap on bearing pads, braced down to the cornice face
	for _, x in rods do
		local a = K.model(m, "Outrigger")
		K.lpart(F, a, "Pad", V(x - 0.5, Tc, -0.6), V(x + 0.5, Tc + 0.7, -0.02), K.L.steel)
		K.lpart(F, a, "Top", V(x - 0.4, Tc + 1.55, -0.6), V(x + 0.4, Tc + 1.7, reach), K.L.dark)
		K.lpart(F, a, "Web", V(x - 0.12, Tc + 0.85, -0.6), V(x + 0.12, Tc + 1.55, reach), K.L.dark)
		K.lpart(F, a, "Bottom", V(x - 0.4, Tc + 0.7, -0.6), V(x + 0.4, Tc + 0.85, reach), K.L.dark)
		K.lpart(
			F,
			a,
			"EndPlate",
			V(x - 0.5, Tc + 0.62, reach),
			V(x + 0.5, Tc + 1.78, reach + 0.12),
			K.L.steel
		)
		bar(
			F * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(-90), 0),
			a,
			"Brace",
			V(1.45, Tc - 0.45, 0),
			V(reach - 0.4, Tc + 0.7, 0),
			0.3,
			-0.12,
			0.12,
			K.L.dark
		)
		K.lpart(
			F,
			a,
			"BraceShoe",
			V(x - 0.35, Tc - 0.85, 1.3),
			V(x + 0.35, Tc - 0.15, 1.42),
			K.L.steel
		)
	end
	-- capitals and bolts on the pilasters
	for _, sd in { -1, 1 } do
		K.lpart(
			F,
			m,
			"Capital",
			V(sd * (hw + 0.75), Tc - 1.45, 0),
			V(sd * (ox - 0.15), Tc - 1.0, 1.2),
			K.L.steel
		)
		for _, x in { hw + 1.3, ox - 0.7 } do
			K.lpart(
				F,
				m,
				"Bolt",
				V(sd * x - 0.13, Tc - 1.32, 1.2),
				V(sd * x + 0.13, Tc - 1.12, 1.3),
				K.L.dark
			)
		end
		-- hazard kick plates on the jambs inside the opening
		local kp = K.lpart(
			F,
			m,
			"KickPlate",
			V(sd * (hw - 0.1), 0.06, -1.6),
			V(sd * hw, 2.0, -0.25),
			K.paint(Color3.fromRGB(196, 152, 34))
		)
		K.texture(kp, sd > 0 and Enum.NormalId.Left or Enum.NormalId.Right, K.TEX.hazard, 2.0)
	end
	-- gate ID (left pilaster) and caution plate (right pilaster) at eye level, on the panel faces
	local pm = hw + (s.P + 0.6) / 2 + 0.3
	S.plate(
		F * CFrame.new(-pm, 6.4, 1.06),
		m,
		"GateId",
		math.min(s.P - 1.4, 3.0),
		1.2,
		{ { text = s.gateId, size = 28, heavy = true } },
		"id"
	)
	S.plate(
		F * CFrame.new(pm, 5.2, 1.06),
		m,
		"Caution",
		math.min(s.P - 1.4, 3.2),
		2.2,
		s.caution,
		"caution"
	)
	-- status lamp on the left pilaster, beside its inner edge, level with the opening's top
	local lamp = K.model(m, "StatusLamp")
	local lx = -(hw + 1.2)
	K.lpart(F, lamp, "Box", V(lx - 0.26, s.H - 0.6, 1.0), V(lx + 0.26, s.H + 0.4, 1.42), K.L.dark)
	local lens = K.ghost(
		K.lpart(
			F,
			lamp,
			"Lens",
			V(lx - 0.18, s.H - 0.5, 1.42),
			V(lx + 0.18, s.H + 0.3, 1.48),
			K.neon(Color3.fromRGB(70, 200, 110))
		)
	)
	K.point(lens, Color3.fromRGB(90, 230, 130), 0.6, 6)
	-- conduit up the right pilaster's outer edge into the outrigger level, with a junction box
	if s.P >= 5 then
		local cx = ox - 0.15
		K.lpart(F, m, "JunctionBox", V(cx - 0.75, 2.6, 1.0), V(cx + 0.05, 3.8, 1.55), K.L.dark)
		K.pipe(
			m,
			"Conduit",
			(F * V(cx - 0.35, 3.8, 1.27)) - K.O,
			(F * V(cx - 0.35, Tc - 1.45, 1.27)) - K.O,
			0.3,
			K.L.steel
		)
	end
	-- floor chevrons into the door
	local paint = K.paint(K.dim(col, 0.18))
	for i = 0, 2 do
		local z = (s.chevronZ or 4.5) + i * 2.2
		local tip = V(0, 0, z - 0.9)
		for _, sx in { -1, 1 } do
			local a, b = tip + V(sx * 1.6, 0, 1.6), tip
			local d = b - a
			K.part(
				m,
				"Chevron",
				V(d.Magnitude + 0.35, 0.03, 0.45),
				F
					* CFrame.fromMatrix(
						(a + b) / 2 + V(0, s.floorY or 0.015, 0),
						d.Unit,
						Vector3.yAxis
					),
				paint
			)
		end
	end
	return m, sign
end

return S
