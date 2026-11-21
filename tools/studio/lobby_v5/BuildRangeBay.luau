--!nocheck
-- Lobby V5 RANGE BAY entrance (vault/02 Art/Lobby V5 Plan.md, "Character pass"). ONE-TIME placement record run through
-- the Studio MCP (needs ServerStorage.V5Kit.LobbySigns). Owner 2026-11-20: the Range entrance "very similar to Rivals
-- ... a big bay door opening, and then it goes in and it shows this hologram mini of the range ... at the back ...
-- the theme thing ... we won't do that for now. Now it'll just look like a thing". The range itself is not built.
-- Replaces the shuttered Range gateway: a 24 x 16 bay door frame (steel-clad piers with hazard bands, a stiffened
-- girder, beacons) with two ribbed door leaves parked open on a track; a sim bay behind it (24 x 30, steel columns
-- and beams) with a holo grid curtain inside the doors, a projector plinth throwing a translucent miniature range,
-- and a truss landmark with standalone letters on the back wall (a SeasonMount: the season's landmark goes there).
-- Frame F: origin on the floor at the middle of the hub-side face (hub z = 42), x right as seen from the hub
-- (world -X), z toward the hub (world -Z): the bay runs to z = -35.

local S = require(game:GetService("ServerStorage").V5Kit.LobbySigns:Clone())
local K = S.K
local CS = game:GetService("CollectionService")
local V = Vector3.new
local L = K.L
local hub = workspace.LobbyV5.Shell.Hub
local F = K.frame(V(0, 0, 42), V(0, 0, -1))
local function P(parent, name, a, b, lk)
	return K.lpart(F, parent, name, a, b, lk)
end
local function W(parent, name, p, u, a, v, b, w, th, lk)
	return K.ltri(F, parent, name, p, u, a, v, b, w, th, lk)
end
local GREEN = K.AREA.range.col
local HOLO = Color3.fromRGB(86, 236, 200)
local holo = K.neon(HOLO)
local function ghostHolo(p, tr)
	K.ghost(p)
	p.Transparency = tr
	return p
end
local steel = K.look("Metal 2022", Color3.fromRGB(74, 77, 82))
local girderLk = K.look("Metal 2022", Color3.fromRGB(60, 62, 67))
local leafLk = K.look("Metal 2022", Color3.fromRGB(54, 57, 62))
local hazardLk = K.paint(Color3.fromRGB(196, 152, 34))

-- clear the old shuttered door and its gateway
for _, n in { "RangeDoor" } do
	local c = hub:FindFirstChild(n)
	if c then
		c:Destroy()
	end
end
local oldGate = hub.Gateways:FindFirstChild("Gateway_Range")
if oldGate then
	oldGate:Destroy()
end
local old = hub:FindFirstChild("RangeBay")
if old then
	old:Destroy()
end
local bay = K.model(hub, "RangeBay")
local HW, PW, OH = 12, 3, 16 -- opening half width, pier width, opening height
local OX = HW + PW

-- 1. BAY DOOR FRAME --------------------------------------------------------------------------------------------
local fr = K.model(bay, "Frame")
for _, sd in { -1, 1 } do
	P(fr, "Pier", V(sd * HW, 0, -4), V(sd * OX, 18, 0), L.trim)
	P(fr, "Clad", V(sd * (HW + 0.3), 2.6, 0), V(sd * (OX - 0.3), 17.2, 0.25), steel)
	local band = P(fr, "HazardBand", V(sd * HW, 0, 0), V(sd * OX, 2.6, 0.3), hazardLk)
	K.texture(band, Enum.NormalId.Back, K.TEX.hazard, 2.4)
	for row = 0, 5 do
		for _, x in { HW + 0.7, OX - 0.7 } do
			local y = 3.4 + row * 2.6
			if math.abs(y - 6.0) > 0.5 then -- the plates sit on the y = 6 row
				P(
					fr,
					"Rivet",
					V(sd * x - 0.14, y - 0.14, 0.25),
					V(sd * x + 0.14, y + 0.14, 0.36),
					K.L.dark
				)
			end
		end
	end
	-- steel gussets in the opening's top corners (front part only, the leaves run behind them)
	W(
		fr,
		"Gusset",
		V(sd * HW, OH, -0.6),
		V(0, -1, 0),
		2,
		V(-sd, 0, 0),
		2,
		V(0, 0, 1),
		1.2,
		girderLk
	)
end
P(fr, "Header", V(-HW, OH, -4), V(HW, 18, 0), L.trim)
P(fr, "Fascia", V(-OX, 18, -1.5), V(OX, 21, 0), L.trim)
P(fr, "Coping", V(-OX - 0.3, 20.8, -1.5), V(OX + 0.3, 21.2, 0.3), steel)
P(fr, "Girder", V(-OX - 0.6, 17.2, 0), V(OX + 0.6, 19.6, 1.1), girderLk)
for x = -OX, OX, 3 do
	P(fr, "Stiffener", V(x - 0.09, 17.3, 1.1), V(x + 0.09, 19.5, 1.4), steel)
end
P(fr, "GirderLip", V(-OX - 0.6, 17.1, 1.1), V(OX + 0.6, 17.3, 1.5), steel)
-- beacons on the girder
for _, sd in { -1, 1 } do
	local b = K.model(fr, "Beacon")
	local x = sd * (OX - 1.4)
	K.mesh(
		b,
		"Base",
		"V5_Flange8",
		V(0.3, 1.2, 1.2),
		F * CFrame.new(x, 19.75, 0.55) * CFrame.Angles(0, 0, math.rad(90)),
		L.dark
	)
	local lens = ghostHolo(
		P(
			b,
			"Lens",
			V(x - 0.38, 19.9, 0.17),
			V(x + 0.38, 20.6, 0.93),
			K.neon(Color3.fromRGB(255, 150, 40))
		),
		0.05
	)
	K.point(lens, Color3.fromRGB(255, 160, 60), 0.9, 10)
	P(b, "Cap", V(x - 0.45, 20.6, 0.1), V(x + 0.45, 20.75, 1.0), L.dark)
end
-- plates on the clad
local pm = HW + PW / 2
S.plate(
	F * CFrame.new(-pm, 9.5, 0.25),
	fr,
	"GateId",
	2.2,
	1.0,
	{ { text = "R-04", size = 30, heavy = true } },
	"id"
)
S.plate(F * CFrame.new(-pm, 6.0, 0.25), fr, "Warning", 2.2, 2.6, {
	{ text = "WARNING", size = 28, heavy = true },
	{ text = "BAY DOORS", size = 18 },
	{ text = "MOVE WHEN", size = 18 },
	{ text = "LIGHTS FLASH", size = 18 },
}, "warning")
S.plate(F * CFrame.new(pm, 6.0, 0.25), fr, "Caution", 2.2, 2.2, {
	{ text = "CAUTION", size = 28, heavy = true },
	{ text = "EYES & EARS", size = 18 },
	{ text = "ON", size = 18 },
}, "caution")
-- floor apron inside the doors (the hub floor runs to z -10 here) and the threshold channel
P(fr, "Apron", V(-HW, 0, -10), V(HW, 0.06, 0.4), L.diamond)

-- 2. DOOR LEAVES parked open on a track ---------------------------------------------------------------------
local doors = K.model(bay, "Doors")
P(doors, "Track", V(-HW, OH - 0.6, -3.2), V(HW, OH, -1.4), K.L.dark)
for _, sd in { -1, 1 } do
	local leaf = K.model(doors, sd > 0 and "Leaf_R" or "Leaf_L")
	P(leaf, "Panel", V(sd * 6, 0.16, -3.0), V(sd * HW, OH - 0.8, -1.6), leafLk)
	for _, y in { 2.4, 5.9, 9.4, 12.9 } do
		P(leaf, "Rib", V(sd * 6.4, y, -1.6), V(sd * (HW - 0.2), y + 0.55, -1.3), steel)
	end
	local edge = P(leaf, "Edge", V(sd * 6, 0.16, -3.1), V(sd * 6.75, OH - 0.8, -1.5), hazardLk)
	K.texture(edge, Enum.NormalId.Back, K.TEX.hazard, 1.6)
	for _, x in { 7.6, 10.6 } do
		P(
			leaf,
			"Trolley",
			V(sd * x - 0.45, OH - 0.8, -2.75),
			V(sd * x + 0.45, OH - 0.45, -1.85),
			K.L.dark
		)
	end
	for _, y in { 4.2, 7.7, 11.2 } do
		P(
			leaf,
			"Bolt",
			V(sd * 9.0 - 0.15, y - 0.15, -1.6),
			V(sd * 9.0 + 0.15, y + 0.15, -1.48),
			K.L.dark
		)
	end
end
P(doors, "GuideChannel", V(-HW, 0.06, -3.2), V(HW, 0.14, -1.4), K.L.dark)

-- 3. THE SIGN standing on the girder on two posts ------------------------------------------------------------
local signTop = 27.4
local sign, sw, rods = S.sign(F * CFrame.new(0, signTop, 0.9), bay, {
	word = "RANGE",
	sub = "SIMULATION BAY",
	col = GREEN,
	emblem = "crosshair",
	h = 5.0,
	hang = 0,
	tilt = 10,
})
for _, x in rods do
	P(bay, "SignPost", V(x - 0.22, 19.6, 0.35), V(x + 0.22, signTop - 0.6, 0.75), K.L.dark)
	P(bay, "PostFoot", V(x - 0.45, 19.6, 0.31), V(x + 0.45, 19.85, 1.05), steel)
end
local scr = hub.Dressing.Screens:FindFirstChild("Screen_S")
if scr and not scr:GetAttribute("RaisedForSign") then
	scr:PivotTo(scr:GetPivot() + V(0, 6, 0))
	scr:SetAttribute("RaisedForSign", true)
end

-- 4. SIM BAY: walls, steel columns and beams, lights -----------------------------------------------------------
local Z1, Z0, RH = -4, -35, 18
local room = K.model(bay, "SimBay")
local wallLk = K.look("Lobby_ConcreteBoard", Color3.fromRGB(80, 80, 82))
P(
	room,
	"Floor",
	V(-HW - 1, -2, Z0 - 1),
	V(HW + 1, 0, -10),
	K.look("Lobby_ConcretePolished", Color3.fromRGB(66, 67, 70))
)
P(room, "Ceiling", V(-HW - 1, RH, Z0 - 1), V(HW + 1, RH + 1, Z1), L.darkConc)
P(room, "Wall_L", V(-HW - 1, 0, Z0), V(-HW, RH, Z1), wallLk)
P(room, "Wall_R", V(HW, 0, Z0), V(HW + 1, RH, Z1), wallLk)
P(room, "Wall_Back", V(-HW - 1, 0, Z0 - 1), V(HW + 1, RH, Z0), wallLk)
for _, sd in { -1, 1 } do
	P(room, "Wainscot", V(sd * (HW - 0.5), 0, Z0), V(sd * HW, 2.6, -10), L.wains)
end
for _, z in { -11, -18.5, -26, -32.5 } do
	local col = K.model(room, "Column")
	for _, sd in { -1, 1 } do
		P(
			col,
			"Flange",
			V(sd * (HW - 0.9), 0, z - 0.7),
			V(sd * (HW - 0.5), RH - 1.0, z + 0.7),
			girderLk
		)
		P(col, "Web", V(sd * (HW - 0.5), 0, z - 0.15), V(sd * HW, RH - 1.0, z + 0.15), girderLk)
		P(col, "Base", V(sd * (HW - 1.2), 0, z - 0.95), V(sd * HW, 0.25, z + 0.95), steel)
		S.bar(
			F * CFrame.new(0, 0, z),
			col,
			"Knee",
			V(sd * (HW - 0.9), RH - 3.2, 0),
			V(sd * (HW - 3.0), RH - 1.0, 0),
			0.32,
			-0.14,
			0.14,
			girderLk
		)
	end
	P(col, "BeamTop", V(-HW, RH - 0.15, z - 0.45), V(HW, RH, z + 0.45), girderLk)
	P(col, "BeamWeb", V(-HW, RH - 0.85, z - 0.13), V(HW, RH - 0.15, z + 0.13), girderLk)
	P(col, "BeamBottom", V(-HW, RH - 1.0, z - 0.45), V(HW, RH - 0.85, z + 0.45), girderLk)
end
for _, z in { -14.75, -29.25 } do
	local m = K.model(room, "CeilingLight")
	P(m, "Frame", V(-2.5, RH - 0.5, z - 1.6), V(2.5, RH, z + 1.6), K.L.dark)
	K.spot(
		m,
		K.ghost(P(m, "Lens", V(-2.1, RH - 0.58, z - 1.2), V(2.1, RH - 0.5, z + 1.2), L.white)),
		Enum.NormalId.Bottom,
		K.WHITE,
		1.2,
		24,
		110
	)
end
-- floor stencil and a hazard ring round the projector
local st =
	K.ghost(P(room, "Stencil", V(-7, 0.02, -13.5), V(7, 0.04, -11.5), K.paint(Color3.new(0, 0, 0))))
st.Transparency = 1
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Top
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 30
sg.LightInfluence = 1
sg.Parent = st
local tl = Instance.new("TextLabel")
tl.BackgroundTransparency = 1
tl.Size = UDim2.fromScale(1, 1)
tl.FontFace = K.RUBIK_H
tl.TextSize = 44
tl.Text = "SIMULATION BAY 04"
tl.TextColor3 = Color3.fromRGB(150, 150, 146)
tl.TextTransparency = 0.25
tl.Parent = sg

-- 5. HOLO CURTAIN just inside the doors: a walk-through grid with LIVE FIRE SIM over it --------------------------
local cur = K.model(bay, "HoloCurtain")
local CZ = -6
for x = -11.5, 11.5, 2.3 do
	ghostHolo(P(cur, "Line", V(x - 0.04, 0.3, CZ - 0.02), V(x + 0.04, 15.2, CZ + 0.02), holo), 0.45)
end
for y = 0.3, 15.2, 2.3 do
	ghostHolo(
		P(cur, "Line", V(-11.5, y - 0.04, CZ - 0.02), V(11.5, y + 0.04, CZ + 0.02), holo),
		0.45
	)
end
ghostHolo(P(cur, "Pane", V(-11.5, 0.3, CZ - 0.01), V(11.5, 15.2, CZ + 0.01), holo), 0.94)
local Ft = F * CFrame.new(0, 10.2, CZ + 0.05)
S.textStack(
	Ft,
	cur,
	"Title",
	"LIVE FIRE SIM",
	K.RUBIK_HI,
	60,
	23,
	3.0,
	Color3.fromRGB(196, 255, 238),
	K.dim(HOLO, 0.35),
	0,
	2
)
S.textStack(
	F * CFrame.new(0, 7.4, CZ + 0.05),
	cur,
	"Status",
	"»  COMING SOON",
	K.RUBIK_B,
	40,
	16,
	1.8,
	HOLO,
	K.dim(HOLO, 0.5),
	0,
	1
)
for _, d in cur:GetDescendants() do
	if d:IsA("SurfaceGui") then
		d.LightInfluence = 0
		d.Brightness = 1.6
	end
end

-- 6. PROJECTOR and the miniature range hologram ----------------------------------------------------------------
local pj = K.model(bay, "Projector")
local PZ = -20
local Fp = F * CFrame.new(0, 0, PZ) * CFrame.Angles(math.rad(-90), 0, 0) -- octagons lie flat (their z = up)
S.octagon(Fp, pj, "Plinth", 7, 0, 1.0, L.dark)
S.octagon(Fp, pj, "Collar", 5.6, 1.0, 1.2, steel)
S.octagon(Fp, pj, "Emitter", 4.4, 1.2, 1.32, K.neon(K.dim(HOLO, 0.25)))
local lens = S.octagon(Fp, pj, "Lens", 1.6, 1.32, 1.5, K.neon(HOLO))
K.point(lens:FindFirstChild("H"), HOLO, 1.4, 18)
local hz = K.model(bay, "HoloRange")
local HY, HX0, HX1, HZ0, HZ1 = 3.4, -6, 6, -26, -14
ghostHolo(P(hz, "Platform", V(HX0, HY - 0.05, HZ0), V(HX1, HY + 0.05, HZ1), holo), 0.82)
for x = HX0, HX1 + 0.01, 1.5 do
	ghostHolo(P(hz, "Grid", V(x - 0.03, HY + 0.05, HZ0), V(x + 0.03, HY + 0.08, HZ1), holo), 0.45)
end
for z = HZ0, HZ1 + 0.01, 1.5 do
	ghostHolo(P(hz, "Grid", V(HX0, HY + 0.05, z - 0.03), V(HX1, HY + 0.08, z + 0.03), holo), 0.45)
end
-- three lanes with a firing line, targets at the far end, cover blocks and two towers
for _, x in { -2, 2 } do
	ghostHolo(P(hz, "LaneWall", V(x - 0.06, HY, -24.5), V(x + 0.06, HY + 0.5, -16.5), holo), 0.4)
end
ghostHolo(
	P(hz, "FiringLine", V(HX0 + 0.3, HY + 0.05, -15.4), V(HX1 - 0.3, HY + 0.4, -15.1), holo),
	0.35
)
for _, x in { -4, 0, 4 } do
	local t = K.model(hz, "Target")
	ghostHolo(P(t, "Post", V(x - 0.05, HY, -24.9), V(x + 0.05, HY + 0.9, -24.8), holo), 0.35)
	ghostHolo(P(t, "Board", V(x - 0.5, HY + 0.9, -24.92), V(x + 0.5, HY + 1.9, -24.78), holo), 0.4)
	ghostHolo(
		P(
			t,
			"Bull",
			V(x - 0.16, HY + 1.24, -24.98),
			V(x + 0.16, HY + 1.56, -24.72),
			K.neon(Color3.fromRGB(255, 120, 90))
		),
		0.25
	)
end
for _, b in
	{
		{ -4.8, -20, 0.8, 0.7 },
		{ -1, -21.5, 1.0, 0.5 },
		{ 3.6, -19.5, 0.7, 0.9 },
		{ 0.8, -18, 0.6, 0.6 },
		{ -3.2, -17.6, 0.7, 0.5 },
		{ 4.6, -22.6, 0.9, 0.6 },
	}
do
	ghostHolo(
		P(
			hz,
			"Cover",
			V(b[1] - b[3] / 2, HY, b[2] - b[3] / 2),
			V(b[1] + b[3] / 2, HY + b[4], b[2] + b[3] / 2),
			holo
		),
		0.5
	)
end
for _, x in { HX0 + 0.6, HX1 - 0.6 } do
	ghostHolo(
		P(hz, "Tower", V(x - 0.4, HY, HZ0 + 0.2), V(x + 0.4, HY + 2.4, HZ0 + 1.0), holo),
		0.45
	)
	ghostHolo(
		P(hz, "TowerDeck", V(x - 0.6, HY + 2.4, HZ0 + 0.0), V(x + 0.6, HY + 2.5, HZ0 + 1.2), holo),
		0.35
	)
end
-- projection beams from the lens to the platform corners
local anchor = K.ghost(
	P(pj, "BeamOrigin", V(-0.1, 1.5, PZ - 0.1), V(0.1, 1.7, PZ + 0.1), K.paint(Color3.new(0, 0, 0)))
)
anchor.Transparency = 1
local a0 = Instance.new("Attachment")
a0.Parent = anchor
for _, c in { V(HX0, HY, HZ0), V(HX1, HY, HZ0), V(HX0, HY, HZ1), V(HX1, HY, HZ1) } do
	local a1 = Instance.new("Attachment")
	a1.WorldPosition = F * c
	a1.Parent = anchor
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(HOLO)
	b.LightEmission = 1
	b.Transparency = NumberSequence.new(0.55, 0.9)
	b.Width0 = 0.15
	b.Width1 = 0.6
	b.FaceCamera = true
	b.Segments = 1
	b.Parent = anchor
end

-- 7. LANDMARK on the back wall: a steel truss with standalone letters (the season's landmark replaces it) -------
local lm = K.model(bay, "Landmark")
lm:SetAttribute("Slot", "RangeLandmark")
CS:AddTag(lm, "SeasonMount")
local LZ = Z0 + 0.35 -- the truss sits on the back wall
local LY0, LY1 = 9.5, 16.2
local trussLk = K.look("Metal 2022", Color3.fromRGB(96, 98, 104))
for _, y in { LY0, LY1 } do
	P(lm, "Chord", V(-10.5, y - 0.15, LZ - 0.35), V(10.5, y + 0.15, LZ + 0.05), trussLk)
end
local Fl = F * CFrame.new(0, 0, LZ - 0.15)
for i = 0, 13 do
	local x0 = -10.5 + i * 1.5
	S.bar(
		Fl,
		lm,
		"Lattice",
		V(x0, LY0 + 0.15, 0),
		V(x0 + 1.5, LY1 - 0.15, 0),
		0.12,
		-0.08,
		0.08,
		trussLk
	)
end
for _, x in { -10.5, 10.5 } do
	P(lm, "Post", V(x - 0.25, 0, LZ - 0.5), V(x + 0.25, LY1 + 0.6, LZ + 0.1), trussLk)
end
local letters = { "T", "H", "E", " ", "D", "E", "E", "P" }
for i, ch in letters do
	if ch ~= " " then
		local x = -9.1 + (i - 1) * 2.6
		S.textStack(
			F * CFrame.new(x, (LY0 + LY1) / 2 + 0.2, LZ + 0.15),
			lm,
			"Letter_" .. ch,
			ch,
			K.RUBIK_H,
			100,
			3.0,
			6.4,
			Color3.fromRGB(244, 240, 230),
			Color3.fromRGB(120, 118, 112),
			0,
			3
		)
	end
end
for _, x in { -6, 6 } do -- uplights on the floor washing the landmark
	local u = P(lm, "Uplight", V(x - 0.6, 0, Z0 + 3.2), V(x + 0.6, 0.5, Z0 + 4.2), K.L.dark)
	local s = K.spot(lm, u, Enum.NormalId.Top, K.WARM, 1.4, 20, 50)
	s.Face = Enum.NormalId.Top
end
for _, d in lm:GetDescendants() do
	if d:IsA("SurfaceGui") then
		d.LightInfluence = 0.8
	end
end

local n = 0
for _, d in bay:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("range bay built: %d pieces"):format(n)
