--!nocheck
-- Lobby V5 duels QUEUE BAYS (vault/02 Art/Lobby V5 Plan.md, "Queue bays v2"). ONE-TIME placement record run through
-- the Studio MCP after BuildDuels.luau: rebuilds Workspace.LobbyV5.Shell.Duels.QueueBays and removes TEMP_EdgeRail.
-- Owner 2026-11-20: no cages ("not a horror game"), larger open areas you walk into, stand on, it highlights and
-- goes up, walk off to leave; signs structured like RIVALS'. So each bay (all the same size, 24 x 26) is an open
-- platform out over the chasm hung from the gantry, with low rails, a raised pad of two light team squares, and a
-- tilted lightbox sign hung from the front runway that also lights the pad.
-- Queueing: an invisible `QueueZone` tagged `LobbyQueue` with state values Mode + Trigger = "Step" (the V4 contract,
-- src/lobby/client/Controllers/WorldPrompts.luau). The squares are tagged `LobbyPadSquare` with Team = 1 / 2 so
-- LobbyPadFx draws its rings and rising glow in the team colour while someone stands on them.

local CS = game:GetService("CollectionService")
local MS = game:GetService("MaterialService")
local O = Vector3.new(0, 0, -1600)
local duels = workspace.LobbyV5.Shell.Duels

local function variant(name)
	for _, v in MS:GetDescendants() do
		if v:IsA("MaterialVariant") and v.Name == name then
			return v
		end
	end
	error("missing " .. name)
end
local function look(var, col, mat)
	if var then
		return { mat = variant(var).BaseMaterial, var = var, col = col }
	end
	return { mat = mat or Enum.Material.SmoothPlastic, col = col }
end
local L = {
	slab = look("Concrete-02a", Color3.fromRGB(150, 148, 144)),
	rim = look("Concrete-02a", Color3.fromRGB(176, 174, 170)),
	steel = look("Metal 2022", Color3.fromRGB(150, 152, 156)),
	dark = look("Metal 2022", Color3.fromRGB(52, 54, 58)),
	cable = look(nil, Color3.fromRGB(26, 26, 28), Enum.Material.Metal),
	face = look(nil, Color3.fromRGB(236, 234, 228), Enum.Material.SmoothPlastic),
}
-- team colours (owner 2026-11-20: away from the orange / blue): A gold (the hub accent), B cyan (the game's ally colour)
local TEAM = {
	{ name = "A", glow = Color3.fromRGB(196, 146, 40), ui = Color3.fromHex("FFB627") },
	{ name = "B", glow = Color3.fromRGB(40, 150, 182), ui = Color3.fromHex("2EC8FF") },
}
local RUBIK = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local QUEUE_MODES = { ["1v1"] = true, ["2v2"] = true, ["3v3"] = true }

local function part(parent, name, size, cf, lk, cls)
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
local function box(parent, name, a, b, lk)
	local lo, hi = a:Min(b), a:Max(b)
	return part(parent, name, hi - lo, CFrame.new(O + (lo + hi) / 2), lk)
end
local function barW(parent, name, A, B, th, lk) -- world points
	return part(parent, name, Vector3.new(th, th, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B), lk)
end
local function tri(parent, name, p, u, a, v, b, w, th, lk) -- hub-local right triangle (see BuildHub)
	local X, Y = w.Unit, u.Unit
	if X:Cross(Y):Dot(-v.Unit) < 0 then
		X = -X
	end
	return part(parent, name, Vector3.new(th, a, b), CFrame.fromMatrix(O + p + u.Unit * a / 2 + v.Unit * b / 2, X, Y), lk, "WedgePart")
end
local function triIn(parent, name, F, p, u, a, v, b, w, th, lk) -- same, in a local frame F
	local X, Y = w.Unit, u.Unit
	if X:Cross(Y):Dot(-v.Unit) < 0 then
		X = -X
	end
	return part(parent, name, Vector3.new(th, a, b), F * CFrame.fromMatrix(p + u.Unit * a / 2 + v.Unit * b / 2, X, Y), lk, "WedgePart")
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function invisible(p)
	p.Transparency = 1
	p.CastShadow = false
	p.CanQuery = false
	return p
end
local function state(inst, name, encoded) -- StateValues encoding: "s" + text, "n" + number
	local f = inst:FindFirstChild("GauntletState") or Instance.new("Folder")
	f.Name = "GauntletState"
	f.Parent = inst
	local v = Instance.new("StringValue")
	v.Name = name
	v.Value = encoded
	v.Parent = f
end
local function label(parent, text, pos, size, col, align)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.FontFace = RUBIK
	t.TextScaled = true
	t.TextColor3 = col
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	t.Text = text
	t.Parent = parent
	return t
end

-- low rail along a line (hub-local a -> b), posts about every 4 studs, rails end inside the end posts
local function rail(parent, name, a, b)
	local m = model(parent, name)
	local A, B = O + a, O + b
	local dir = (B - A).Unit
	local len = (B - A).Magnitude
	for _, r in { { 3.2, 0.4, L.steel, "TopRail" }, { 1.7, 0.28, L.steel, "MidRail" } } do
		barW(m, r[4], A + dir * 0.1 + Vector3.new(0, r[1], 0), B - dir * 0.1 + Vector3.new(0, r[1], 0), r[2], r[3])
	end
	local n = math.max(1, math.floor(len / 4))
	for i = 0, n do
		local p = A + dir * (len * i / n)
		part(m, "Post", Vector3.new(0.5, 3.6, 0.5), CFrame.lookAt(p + Vector3.new(0, 1.8, 0), p + Vector3.new(0, 1.8, 0) + dir), L.dark) -- 0.2 proud of the top rail
	end
	return m
end

---------------------------------------------------------------------------------------------------
local old = duels:FindFirstChild("QueueBays")
if old then
	old:Destroy()
end
for _, n in { "TEMP_EdgeRail", "Cages" } do
	local x = duels:FindFirstChild(n)
	if x then
		x:Destroy()
	end
end
local bays = model(duels, "QueueBays")

local YD = -1
local Z0, Z1 = -97, -123 -- platform front (deck edge) and back
local nZones = 0
local anchors = duels.BayAnchors:GetChildren()
table.sort(anchors, function(a, b)
	return a.Name < b.Name
end)
for _, anchor in anchors do
	local mode = anchor:GetAttribute("Mode")
	local teamSize = tonumber(string.sub(mode, 1, 1))
	local cx = anchor.Position.X - O.X
	local x0, x1 = cx - 12, cx + 12
	local bay = model(bays, "Bay_" .. string.sub(anchor.Name, 5))
	bay:SetAttribute("Mode", mode)

	-- platform hung from the gantry
	box(bay, "Platform", Vector3.new(x0 + 0.1, YD - 0.6, Z1), Vector3.new(x1 - 0.1, YD, Z0), L.slab)
	box(bay, "UnderFrame", Vector3.new(x0 + 0.6, YD - 2.6, Z1 + 0.5), Vector3.new(x1 - 0.6, YD - 0.6, Z0 - 0.5), L.dark)
	for _, x in { x0 + 1.4, cx, x1 - 1.4 } do
		box(bay, "Joist", Vector3.new(x - 0.3, YD - 3.2, Z1 + 0.5), Vector3.new(x + 0.3, YD - 2.6, Z0 - 0.5), L.dark)
	end
	local rails = model(bay, "Rails")
	rail(rails, "Rail_W", Vector3.new(x0 + 0.5, YD, Z0 - 1.0), Vector3.new(x0 + 0.5, YD, Z1 + 0.5))
	rail(rails, "Rail_E", Vector3.new(x1 - 0.5, YD, Z0 - 1.0), Vector3.new(x1 - 0.5, YD, Z1 + 0.5))
	rail(rails, "Rail_Back", Vector3.new(x0 + 0.5, YD, Z1 + 0.5), Vector3.new(x1 - 0.5, YD, Z1 + 0.5))
	for _, c in {
		{ "Collider_W", Vector3.new(x0 + 0.8, YD, Z1 + 0.8), Vector3.new(x0 + 0.9, YD + 12, Z0 - 0.5) },
		{ "Collider_E", Vector3.new(x1 - 0.9, YD, Z1 + 0.8), Vector3.new(x1 - 0.8, YD + 12, Z0 - 0.5) },
		{ "Collider_Back", Vector3.new(x0 + 0.8, YD, Z1 + 0.8), Vector3.new(x1 - 0.8, YD + 12, Z1 + 0.9) },
	} do
		invisible(box(rails, c[1], c[2], c[3], L.steel))
	end
	-- hoist: two cables from lugs on the platform's back corners up to sheave blocks under the back runway (the
	-- front pair stood where players walk in and read as clutter; the sign hangers carry the front visually)
	local hoist = model(bay, "Hoist")
	for _, x in { x0 + 1.6, x1 - 1.6 } do
		box(hoist, "Lug_B", Vector3.new(x - 0.35, YD - 0.6, Z1 - 0.6), Vector3.new(x + 0.35, YD, Z1), L.dark)
		box(hoist, "Cable_B", Vector3.new(x - 0.12, YD, Z1 - 0.42), Vector3.new(x + 0.12, 25.2, Z1 - 0.18), L.cable)
		box(hoist, "Sheave_B", Vector3.new(x - 0.6, 25.2, Z1 - 0.9), Vector3.new(x + 0.6, 26.12, Z1 + 0.3), L.dark)
	end

	-- the pad (v3, owner 2026-11-20 "the duel pads have to look better"): a raised light-concrete dais with sloped
	-- edges, holding two sunken team WELLS (dark floor, angled steel slopes down from the rim), each ringed by a
	-- team-colour border on the rim, with one pip per player on the rim in front. The client (LobbyPadFx) floats a
	-- reticle emblem over each well floor and locks it on in the team colour when someone stands there.
	local pad = model(bay, "Pad")
	local DX, DZ0, DZ1, TOP = 10.5, -101, -119, YD + 0.6
	box(pad, "Rim_Front", Vector3.new(cx - DX, YD, DZ0 - 1.0), Vector3.new(cx + DX, TOP, DZ0), L.rim)
	box(pad, "Rim_Back", Vector3.new(cx - DX, YD, DZ1), Vector3.new(cx + DX, TOP, DZ1 + 1.0), L.rim)
	box(pad, "Rim_W", Vector3.new(cx - DX, YD, DZ1 + 1.0), Vector3.new(cx - DX + 1.0, TOP, DZ0 - 1.0), L.rim)
	box(pad, "Rim_E", Vector3.new(cx + DX - 1.0, YD, DZ1 + 1.0), Vector3.new(cx + DX, TOP, DZ0 - 1.0), L.rim)
	box(pad, "Rim_Mid", Vector3.new(cx - 0.6, YD, DZ1 + 1.0), Vector3.new(cx + 0.6, TOP, DZ0 - 1.0), L.rim)
	tri(pad, "Slope_Front", Vector3.new(cx, YD, DZ0), Vector3.new(0, 1, 0), 0.6, Vector3.new(0, 0, 1), 1.0, Vector3.xAxis, 2 * DX, L.rim) -- ramps down from the rim
	tri(pad, "Slope_Back", Vector3.new(cx, YD, DZ1), Vector3.new(0, 1, 0), 0.6, Vector3.new(0, 0, -1), 1.0, Vector3.xAxis, 2 * DX, L.rim)
	tri(pad, "Slope_W", Vector3.new(cx - DX, YD, (DZ0 + DZ1) / 2), Vector3.new(0, 1, 0), 0.6, Vector3.new(-1, 0, 0), 1.0, Vector3.zAxis, DZ0 - DZ1, L.rim)
	tri(pad, "Slope_E", Vector3.new(cx + DX, YD, (DZ0 + DZ1) / 2), Vector3.new(0, 1, 0), 0.6, Vector3.new(1, 0, 0), 1.0, Vector3.zAxis, DZ0 - DZ1, L.rim)
	local FLOOR = YD + 0.06
	local well = look(nil, Color3.fromRGB(44, 46, 50), Enum.Material.SmoothPlastic)
	for ti, t in TEAM do
		local ha, hb = (ti == 1) and (cx - DX + 1.0) or (cx + 0.6), (ti == 1) and (cx - 0.6) or (cx + DX - 1.0)
		local za, zb = DZ1 + 1.0, DZ0 - 1.0
		-- the well floor (keeps the name Square_A / B: LobbyPadFx and MatchLift read it)
		local sq = box(pad, "Square_" .. t.name, Vector3.new(ha + 0.6, YD, za + 0.6), Vector3.new(hb - 0.6, FLOOR, zb - 0.6), well)
		state(sq, "Team", "n" .. ti)
		CS:AddTag(sq, "LobbyPadSquare")
		-- angled steel slopes from the rim edge down to the floor
		local h, up = TOP - FLOOR, Vector3.new(0, 1, 0)
		tri(pad, "WellSlope", Vector3.new((ha + hb) / 2, FLOOR, zb), up, h, Vector3.new(0, 0, -1), 0.6, Vector3.xAxis, hb - ha, L.dark)
		tri(pad, "WellSlope", Vector3.new((ha + hb) / 2, FLOOR, za), up, h, Vector3.new(0, 0, 1), 0.6, Vector3.xAxis, hb - ha, L.dark)
		tri(pad, "WellSlope", Vector3.new(ha, FLOOR, (za + zb) / 2), up, h, Vector3.new(1, 0, 0), 0.6, Vector3.zAxis, zb - za - 1.2, L.dark)
		tri(pad, "WellSlope", Vector3.new(hb, FLOOR, (za + zb) / 2), up, h, Vector3.new(-1, 0, 0), 0.6, Vector3.zAxis, zb - za - 1.2, L.dark)
		-- the team border on the rim around the well
		local border = look(nil, t.glow, Enum.Material.Neon)
		local y0, y1 = TOP, TOP + 0.04
		box(pad, "Border_" .. t.name, Vector3.new(ha - 0.3, y0, zb), Vector3.new(hb + 0.3, y1, zb + 0.3), border)
		box(pad, "Border_" .. t.name, Vector3.new(ha - 0.3, y0, za - 0.3), Vector3.new(hb + 0.3, y1, za), border)
		box(pad, "Border_" .. t.name, Vector3.new(ha - 0.3, y0, za), Vector3.new(ha, y1, zb), border)
		box(pad, "Border_" .. t.name, Vector3.new(hb, y0, za), Vector3.new(hb + 0.3, y1, zb), border)
		-- one pip per player on the rim in front of the well
		local w = hb - ha
		for i = 1, teamSize do
			local px = ha + w * i / (teamSize + 1)
			box(pad, "Pip_" .. t.name, Vector3.new(px - 0.4, y0, zb + 0.45), Vector3.new(px + 0.4, y1, zb + 0.85), border)
		end
	end
	if QUEUE_MODES[mode] then
		local z = invisible(box(pad, "QueueZone", Vector3.new(cx - DX + 1.0, YD - 0.5, DZ1 + 1.0), Vector3.new(cx + DX - 1.0, YD + 0.5, DZ0 - 1.0), L.steel))
		z.CanCollide = false
		z.CanTouch = false
		state(z, "Mode", "s" .. mode)
		state(z, "Trigger", "sStep")
		CS:AddTag(z, "LobbyQueue")
		nZones += 1
	end

	-- lightbox sign hung from the front runway, tilted 25 degrees toward the deck; it also lights the pad
	local sign = model(bay, "Sign")
	local W, H = 16, 4.8
	local c = O + Vector3.new(cx, 20.2, -98.6)
	local S = CFrame.lookAt(c, c + Vector3.new(0, -math.sin(math.rad(25)), math.cos(math.rad(25))))
	local k = 0.7 -- cut corners
	part(sign, "Case", Vector3.new(W, H - 2 * k, 1.0), S, L.dark)
	part(sign, "Case_T", Vector3.new(W - 2 * k, k, 1.0), S * CFrame.new(0, H / 2 - k / 2, 0), L.dark)
	part(sign, "Case_B", Vector3.new(W - 2 * k, k, 1.0), S * CFrame.new(0, -H / 2 + k / 2, 0), L.dark)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			triIn(sign, "Case_Corner", S, Vector3.new(sx * (W / 2 - k), sy * (H / 2 - k), 0), Vector3.new(0, sy, 0), k, Vector3.new(sx, 0, 0), k, Vector3.zAxis, 1.0, L.dark)
		end
	end
	local face = part(sign, "Face", Vector3.new(W - 1.2, H - 1.2, 0.08), S * CFrame.new(0, 0, -0.52), L.face)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = 0
	g.Parent = face
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(240, 238, 232)
	bg.BorderSizePixel = 0
	bg.Parent = g
	local dark = Color3.fromRGB(28, 28, 32)
	label(bg, string.upper(mode), UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.42, 0.8), dark, Enum.TextXAlignment.Left)
	local soon = not QUEUE_MODES[mode]
	label(bg, soon and "COMING SOON" or "STEP IN TO QUEUE", UDim2.fromScale(0.5, 0.16), UDim2.fromScale(0.46, 0.26), dark, Enum.TextXAlignment.Right)
	for ti, t in TEAM do -- one pip per player, A row then B row
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromScale(0.5, 0.48 + (ti - 1) * 0.22)
		row.Size = UDim2.fromScale(0.46, 0.16)
		row.Parent = bg
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 6)
		list.Parent = row
		for _ = 1, teamSize do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.new(0, 22, 1, 0)
			pip.BackgroundColor3 = t.ui
			pip.BorderSizePixel = 0
			pip.Parent = row
		end
	end
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Color = Color3.fromRGB(255, 248, 236)
	glow.Brightness = 1
	glow.Range = 10
	glow.Angle = 120
	glow.Parent = face
	local under = part(sign, "PadLight", Vector3.new(W - 4, 0.12, 0.4), S * CFrame.new(0, -H / 2 - 0.06, 0.1), look(nil, Color3.fromRGB(138, 135, 128), Enum.Material.Neon))
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Color = Color3.fromRGB(255, 246, 232)
	sl.Brightness = 2
	sl.Range = 34
	sl.Angle = 95
	sl.Shadows = true
	sl.Parent = under
	-- hangers from the runway underside to the sign's top corners
	for _, sx in { -1, 1 } do
		local top = S * Vector3.new(sx * (W / 2 - 1.5), H / 2 - 0.1, 0)
		local at = Vector3.new(top.X, O.Y + 26.12, O.Z - 98)
		part(sign, "Clamp", Vector3.new(0.8, 0.4, 1.0), CFrame.new(at - Vector3.new(0, 0.2, 0)), L.dark)
		barW(sign, "Hanger", at - Vector3.new(0, 0.4, 0), top, 0.25, L.steel)
	end
	task.wait()
end

local n = 0
for _, d in bays:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("queue bays: %d pieces in %d bays, %d queue zones"):format(n, #anchors, nZones)
