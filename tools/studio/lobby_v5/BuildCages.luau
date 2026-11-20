--!nocheck
-- Lobby V5 duels lift cages (vault/02 Art/Lobby V5 Plan.md, "Duels cages"). ONE-TIME placement record run through
-- the Studio MCP after BuildDuels.luau: rebuilds Workspace.LobbyV5.Shell.Duels.Cages and removes TEMP_EdgeRail.
-- One cage per bay (Duels.BayAnchors, attribute Mode), sized by the bay. Built the way a lift car is made:
-- platform + under-frame -> corner posts -> top frame with a header -> barred side / back panels with an X brace ->
-- parked sliding gate leaves -> hoist cables up to the gantry -> header sign, beacon and queue screen.
-- Inside: a pad in two team halves (A orange, B blue) with team edge strips, a team letter and one pip per player.
-- Queueing: an invisible `QueueZone` tagged `LobbyQueue` with state values Mode + Trigger = "Step"
-- (src/lobby/client/Controllers/WorldPrompts.luau: stepping in starts a search for the mode, stepping out cancels).
-- 4v4 is not a queue mode yet (src/lobby/shared/Config.luau): its cage gets no zone and a SOON screen.

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
	steel = look("Metal 2022", Color3.fromRGB(110, 112, 116)),
	dark = look("Metal 2022", Color3.fromRGB(52, 54, 58)),
	diamond = look("Diamond Plate 2022", Color3.fromRGB(96, 98, 102)),
	padBase = look(nil, Color3.fromRGB(28, 29, 32), Enum.Material.SmoothPlastic),
	cable = look(nil, Color3.fromRGB(26, 26, 28), Enum.Material.Metal),
	paint = look(nil, Color3.fromRGB(196, 152, 34), Enum.Material.SmoothPlastic),
	amber = look(nil, Color3.fromRGB(196, 132, 40), Enum.Material.Neon),
	screen = look(nil, Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic),
}
local TEAM = {
	A = { strip = Color3.fromRGB(200, 96, 30), light = Color3.fromRGB(255, 140, 60), letter = "A" },
	B = { strip = Color3.fromRGB(40, 100, 200), light = Color3.fromRGB(80, 150, 255), letter = "B" },
}
local RUBIK = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local HAZARD = "rbxassetid://75158634706115"
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
local function bar(parent, name, a, b, th, lk)
	local A, B = O + a, O + b
	return part(parent, name, Vector3.new(th, th, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B), lk)
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
	return p
end
local function gui(p, face, ppS)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS
	g.LightInfluence = 0.2
	g.Parent = p
	return g
end
local function label(parent, text, pos, size, col)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.FontFace = RUBIK
	t.TextScaled = true
	t.TextColor3 = col or Color3.fromRGB(238, 236, 230)
	t.Text = text
	t.Parent = parent
	return t
end
-- StateValues encoding (src/shared/StateValues.luau): "s" + text, "n" + number
local function state(inst, name, encoded)
	local f = inst:FindFirstChild("GauntletState") or Instance.new("Folder")
	f.Name = "GauntletState"
	f.Parent = inst
	local v = Instance.new("StringValue")
	v.Name = name
	v.Value = encoded
	v.Parent = f
end

-- a barred panel in a vertical plane: from point a to point b along the floor line, height h from y0
local function barredPanel(parent, name, a, b, y0, h, spacing, noBrace)
	local m = model(parent, name)
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	bar(m, "RailBottom", a + Vector3.new(0, y0 + 0.2, 0), b + Vector3.new(0, y0 + 0.2, 0), 0.4, L.steel)
	bar(m, "RailMid", a + Vector3.new(0, y0 + h * 0.5, 0), b + Vector3.new(0, y0 + h * 0.5, 0), 0.3, L.steel)
	bar(m, "RailTop", a + Vector3.new(0, y0 + h - 0.2, 0), b + Vector3.new(0, y0 + h - 0.2, 0), 0.4, L.steel)
	local n = math.max(2, math.floor(len / spacing))
	for i = 1, n - 1 do
		local p = a + dir * (len * i / n)
		box(m, "Bar", p + Vector3.new(-0.11, y0 + 0.4, -0.11), p + Vector3.new(0.11, y0 + h - 0.4, 0.11), L.dark)
	end
	-- X brace in the lower half (steel flats); none on the gate leaves (they read as sawhorses)
	if noBrace then
		return m
	end
	bar(m, "Brace", a + Vector3.new(0, y0 + 0.4, 0) + dir * 0.3, b + Vector3.new(0, y0 + h * 0.5, 0) - dir * 0.3, 0.22, L.steel)
	bar(m, "Brace", a + Vector3.new(0, y0 + h * 0.5, 0) + dir * 0.3, b + Vector3.new(0, y0 + 0.4, 0) - dir * 0.3, 0.22, L.steel)
	return m
end

---------------------------------------------------------------------------------------------------
local old = duels:FindFirstChild("Cages")
if old then
	old:Destroy()
end
local temp = duels:FindFirstChild("TEMP_EdgeRail")
if temp then
	temp:Destroy()
end
local cages = model(duels, "Cages")

local YD = -1 -- deck / cage floor top
local Z0, Z1 = -97, -117 -- cage front (deck edge) and back (back column faces)
local YTOP = 13 -- top of the cage frame
local nZones = 0

local anchors = duels.BayAnchors:GetChildren()
table.sort(anchors, function(a, b)
	return a.Name < b.Name
end)
for _, anchor in anchors do
	local mode = anchor:GetAttribute("Mode")
	local teamSize = tonumber(string.sub(mode, 1, 1))
	local cx = anchor.Position.X - O.X
	local W = anchor.Size.X
	local x0, x1 = cx - W / 2, cx + W / 2
	local cage = model(cages, "Cage_" .. string.sub(anchor.Name, 5))
	cage:SetAttribute("Mode", mode)

	-- platform and under-frame
	box(cage, "Platform", Vector3.new(x0 + 0.1, YD - 0.6, Z1 + 0.1), Vector3.new(x1 - 0.1, YD, Z0), L.diamond)
	box(cage, "UnderFrame", Vector3.new(x0 + 0.5, YD - 2.6, Z1 + 0.5), Vector3.new(x1 - 0.5, YD - 0.6, Z0 - 0.4), L.dark)
	for _, x in { x0 + 1.2, cx, x1 - 1.2 } do
		box(cage, "FloorJoist", Vector3.new(x - 0.3, YD - 3.2, Z1 + 0.5), Vector3.new(x + 0.3, YD - 2.6, Z0 - 0.4), L.steel)
	end
	-- plain steel threshold: the deck kerb already carries the hazard stripes
	box(cage, "Threshold", Vector3.new(x0 + 0.9, YD, Z0 - 1.2), Vector3.new(x1 - 0.9, YD + 0.08, Z0 - 0.05), L.dark)

	-- the pad: two team halves, edge strips, letter, one pip per player
	local pad = model(cage, "Pad")
	local px0, px1, pz0, pz1 = x0 + 1.2, x1 - 1.2, Z1 + 1.6, Z0 - 2.0
	local mid = cx
	box(pad, "Divider", Vector3.new(mid - 0.3, YD, pz1), Vector3.new(mid + 0.3, YD + 0.14, pz0), L.steel)
	for _, side in { { "A", px0, mid - 0.3 }, { "B", mid + 0.3, px1 } } do
		local t = TEAM[side[1]]
		local ha, hb = side[2], side[3]
		local half = box(pad, "Team_" .. side[1], Vector3.new(ha, YD, pz1), Vector3.new(hb, YD + 0.08, pz0), L.padBase)
		-- LobbyPadFx (client) draws team rings + a glow over this half while someone stands on it
		state(half, "Team", side[1] == "A" and "n1" or "n2")
		CS:AddTag(half, "LobbyPadSquare")
		local strip = look(nil, t.strip, Enum.Material.Neon)
		local e = 0.25
		box(pad, "Strip_" .. side[1], Vector3.new(ha + 0.15, YD + 0.08, pz1 - 0.15 - e), Vector3.new(hb - 0.15, YD + 0.12, pz1 - 0.15), strip)
		box(pad, "Strip_" .. side[1], Vector3.new(ha + 0.15, YD + 0.08, pz0 + 0.15), Vector3.new(hb - 0.15, YD + 0.12, pz0 + 0.15 + e), strip)
		box(pad, "Strip_" .. side[1], Vector3.new(ha + 0.15, YD + 0.08, pz0 + 0.15 + e), Vector3.new(ha + 0.15 + e, YD + 0.12, pz1 - 0.15 - e), strip)
		box(pad, "Strip_" .. side[1], Vector3.new(hb - 0.15 - e, YD + 0.08, pz0 + 0.15 + e), Vector3.new(hb - 0.15, YD + 0.12, pz1 - 0.15 - e), strip)
		-- one pip per player, near the front of the half
		local w = hb - ha
		for i = 1, teamSize do
			local px = ha + w * i / (teamSize + 1)
			local pip = box(pad, "Pip_" .. side[1], Vector3.new(px - 0.35, YD + 0.08, pz1 - 1.6), Vector3.new(px + 0.35, YD + 0.13, pz1 - 0.9), strip)
			pip:SetAttribute("Team", side[1])
		end
		-- team letter on the half (faint, readable from the deck)
		local g = gui(half, Enum.NormalId.Top, 12)
		local l = label(g, t.letter, UDim2.fromScale(0.15, 0.35), UDim2.fromScale(0.7, 0.3), t.strip)
		l.TextTransparency = 0.35
		local glow = invisible(part(pad, "Glow_" .. side[1], Vector3.new(0.4, 0.4, 0.4), CFrame.new(O + Vector3.new((ha + hb) / 2, YD + 1.5, (pz0 + pz1) / 2)), L.steel))
		glow.CanCollide = false
		glow.CanQuery = false
		local pl = Instance.new("PointLight")
		pl.Color = t.light
		pl.Brightness = 0.6
		pl.Range = math.max(6, w)
		pl.Shadows = false
		pl.Parent = glow
	end

	-- frame: corner posts, top ring, header
	local frame = model(cage, "Frame")
	for _, c in { { x0 + 0.45, Z0 - 0.45 }, { x1 - 0.45, Z0 - 0.45 }, { x0 + 0.45, Z1 + 0.45 }, { x1 - 0.45, Z1 + 0.45 } } do
		box(frame, "Post", Vector3.new(c[1] - 0.45, YD, c[2] - 0.45), Vector3.new(c[1] + 0.45, YTOP, c[2] + 0.45), L.steel)
		box(frame, "PostShoe", Vector3.new(c[1] - 0.65, YD, c[2] - 0.65), Vector3.new(c[1] + 0.65, YD + 0.5, c[2] + 0.65), L.dark)
	end
	box(frame, "TopSide_W", Vector3.new(x0 + 0.15, YTOP - 0.85, Z1 + 0.1), Vector3.new(x0 + 0.85, YTOP - 0.05, Z0 - 0.9), L.steel) -- inset from the post faces
	box(frame, "TopSide_E", Vector3.new(x1 - 0.85, YTOP - 0.85, Z1 + 0.1), Vector3.new(x1 - 0.15, YTOP - 0.05, Z0 - 0.9), L.steel)
	box(frame, "TopBack", Vector3.new(x0 + 0.9, YTOP - 0.8, Z1 + 0.1), Vector3.new(x1 - 0.9, YTOP, Z1 + 0.9), L.steel)
	local header = box(frame, "Header", Vector3.new(x0 + 0.1, YTOP - 1.6, Z0 - 0.85), Vector3.new(x1 - 0.1, YTOP + 0.6, Z0 - 0.05), L.dark)
	box(frame, "GateTrack", Vector3.new(x0 + 0.9, YTOP - 1.9, Z0 - 0.75), Vector3.new(x1 - 0.9, YTOP - 1.6, Z0 - 0.35), L.steel)

	-- barred walls: sides and back, plus invisible colliders just inside so nobody slips through the bars
	local walls = model(cage, "Walls")
	barredPanel(walls, "Side_W", Vector3.new(x0 + 0.45, 0, Z0 - 0.9), Vector3.new(x0 + 0.45, 0, Z1 + 0.9), YD, YTOP - YD - 0.8, 1.6)
	barredPanel(walls, "Side_E", Vector3.new(x1 - 0.45, 0, Z0 - 0.9), Vector3.new(x1 - 0.45, 0, Z1 + 0.9), YD, YTOP - YD - 0.8, 1.6)
	barredPanel(walls, "Back", Vector3.new(x0 + 0.9, 0, Z1 + 0.45), Vector3.new(x1 - 0.9, 0, Z1 + 0.45), YD, YTOP - YD - 0.8, 1.6)
	for _, c in {
		{ "Collider_W", Vector3.new(x0 + 0.7, YD, Z1 + 0.7), Vector3.new(x0 + 0.8, YTOP + 6, Z0 - 0.9) },
		{ "Collider_E", Vector3.new(x1 - 0.8, YD, Z1 + 0.7), Vector3.new(x1 - 0.7, YTOP + 6, Z0 - 0.9) },
		{ "Collider_Back", Vector3.new(x0 + 0.7, YD, Z1 + 0.7), Vector3.new(x1 - 0.7, YTOP + 6, Z1 + 0.8) },
	} do
		local p = invisible(box(walls, c[1], c[2], c[3], L.steel))
		p.CanQuery = false
	end

	-- sliding gate leaves, parked open behind the front posts
	local gw = math.clamp(W * 0.18, 1.8, 4)
	for _, s in { { "Gate_W", x0 + 0.9, x0 + 0.9 + gw }, { "Gate_E", x1 - 0.9 - gw, x1 - 0.9 } } do
		local gm = barredPanel(cage, s[1], Vector3.new(s[2], 0, Z0 - 1.1), Vector3.new(s[3], 0, Z0 - 1.1), YD + 0.3, YTOP - YD - 2.6, 0.9, true)
		box(gm, "Hanger", Vector3.new(s[2] + 0.2, YTOP - 2.3, Z0 - 1.25), Vector3.new(s[3] - 0.2, YTOP - 1.9, Z0 - 0.95), L.dark)
	end

	-- hoist: front cables rise from lugs on the header, back cables from lugs behind the top back beam; each runs
	-- straight up into a sheave block seated in the underside of a gantry runway (front z -98, back z -118)
	local hoist = model(cage, "Hoist")
	for _, x in { x0 + 1.4, x1 - 1.4 } do
		box(hoist, "Lug_F", Vector3.new(x - 0.35, YTOP + 0.6, Z0 - 0.85), Vector3.new(x + 0.35, YTOP + 1.1, Z0 - 0.15), L.dark)
		box(hoist, "Cable_F", Vector3.new(x - 0.12, YTOP + 1.1, Z0 - 0.62), Vector3.new(x + 0.12, 25.2, Z0 - 0.38), L.cable)
		box(hoist, "Sheave_F", Vector3.new(x - 0.6, 25.2, Z0 - 1.1), Vector3.new(x + 0.6, 26.12, Z0 + 0.1), L.dark)
		box(hoist, "Lug_B", Vector3.new(x - 0.35, YTOP - 0.6, Z1 - 0.45), Vector3.new(x + 0.35, YTOP, Z1 + 0.1), L.dark)
		box(hoist, "Cable_B", Vector3.new(x - 0.12, YTOP, Z1 - 0.32), Vector3.new(x + 0.12, 25.2, Z1 - 0.08), L.cable)
		box(hoist, "Sheave_B", Vector3.new(x - 0.6, 25.2, Z1 - 0.8), Vector3.new(x + 0.6, 26.12, Z1 + 0.4), L.dark)
	end

	-- header sign (mode + pips), beacon on top, queue screen on the back wall
	local plate = box(frame, "SignPlate", Vector3.new(cx - (W / 2 - 1.2), YTOP - 1.3, Z0 - 0.05), Vector3.new(cx + (W / 2 - 1.2), YTOP + 0.3, Z0 + 0.05), L.screen)
	local g = gui(plate, Enum.NormalId.Back, 20)
	local soon = not QUEUE_MODES[mode]
	label(g, string.upper(mode), UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.5, 0.84))
	local pipsFrame = Instance.new("Frame")
	pipsFrame.BackgroundTransparency = 1
	pipsFrame.Position = UDim2.fromScale(0.56, 0.3)
	pipsFrame.Size = UDim2.fromScale(0.4, 0.4)
	pipsFrame.Parent = g
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.02, 0)
	list.Parent = pipsFrame
	for ti, t in { TEAM.A, TEAM.B } do
		for _ = 1, teamSize do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.new(0, 10, 0, 10)
			pip.BackgroundColor3 = t.strip
			pip.BorderSizePixel = 0
			pip.LayoutOrder = ti
			pip.Parent = pipsFrame
		end
	end
	local beacon = model(frame, "Beacon")
	box(beacon, "Base", Vector3.new(cx - 0.6, YTOP + 0.6, Z0 - 0.75), Vector3.new(cx + 0.6, YTOP + 0.9, Z0 - 0.2), L.dark)
	local lens = box(beacon, "Lens", Vector3.new(cx - 0.4, YTOP + 0.9, Z0 - 0.65), Vector3.new(cx + 0.4, YTOP + 1.5, Z0 - 0.3), L.amber)
	CS:AddTag(lens, "CageBeacon")
	local bl = Instance.new("PointLight")
	bl.Color = Color3.fromRGB(255, 170, 70)
	bl.Brightness = 0.8
	bl.Range = 8
	bl.Shadows = false
	bl.Parent = lens
	local scr = model(cage, "QueueScreen")
	local sw = math.min(6, W - 4)
	box(scr, "Mount", Vector3.new(cx - sw / 2 - 0.2, 6.2, Z1 + 0.25), Vector3.new(cx + sw / 2 + 0.2, 9.6, Z1 + 0.75), L.dark)
	local face = box(scr, "Display", Vector3.new(cx - sw / 2, 6.4, Z1 + 0.75), Vector3.new(cx + sw / 2, 9.4, Z1 + 0.8), L.screen)
	local sg = gui(face, Enum.NormalId.Back, 24)
	sg.LightInfluence = 0
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
	bg.BorderSizePixel = 0
	bg.Parent = sg
	label(bg, soon and "COMING SOON" or "STEP IN TO QUEUE", UDim2.fromScale(0.06, 0.18), UDim2.fromScale(0.88, 0.34))
	label(bg, string.upper(mode), UDim2.fromScale(0.3, 0.58), UDim2.fromScale(0.4, 0.26), Color3.fromRGB(214, 170, 60))

	-- the queue zone (same contract as the V4 step pads)
	if not soon then
		local z = invisible(box(cage, "QueueZone", Vector3.new(px0, YD - 0.5, pz0), Vector3.new(px1, YD + 0.5, pz1 + 1.2), L.steel))
		z.CanCollide = false
		z.CanQuery = false
		z.CanTouch = false
		state(z, "Mode", "s" .. mode)
		state(z, "Trigger", "sStep")
		CS:AddTag(z, "LobbyQueue")
		nZones += 1
	end
end

local n = 0
for _, d in cages:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("cages: %d pieces in %d cages, %d queue zones"):format(n, #anchors, nZones)
