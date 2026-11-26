--!nocheck
-- Lobby V5 RANGE GATES v6 (vault/01 Design/Range v5.md, round 4). Owner 2026-11-26:
-- * the range's way out: "a big sign with a screen or surface UI that just says leave, and you just walk into it ...
--   much bigger, not just like the symbol portal with nothing on it";
-- * the hub side: "open up the door ... more extravagant, like Rivals ... a much larger hologram look ... an openish
--   area, and then have ... a structure in the back that looks pretty cool ... lighting nice".
-- RIVALS study (read-only, vault/03 Research/Rivals Reference/Maps and Lobby.md): their range door is a 123 x 44 walk-in
-- holographic wall (ForceField) with the range seen through it and a big sign over it. Ours, our look: a 26 x 28 portal
-- in the hub's south wall, a chamfered steel frame with teal edge light, a teal holographic field you walk into
-- (RangeEntry), a facility sign over it, and behind it an open-topped chamber: a giant target emblem on a steel A-frame
-- gantry, a lit dais of training bots, teal floor lines, spotlights. Edit mode, safe to run again. Save after.

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local TEAL = K.AREA.range.col
local INK = rgb(12, 14, 17)
local report = {}

local function ghost(p)
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	return p
end
local function label(parent, text, font, size, col, pos, sz, anchor, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = text
	l.TextSize = size
	l.TextColor3 = col
	l.Position = pos
	l.Size = sz
	l.AnchorPoint = anchor or Vector2.zero
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end
local function surface(part, face, pps)
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = 0
	g.Brightness = 1.4
	g.MaxDistance = 400
	g.Parent = part
	return g
end

-- 1. THE RANGE'S WAY OUT: the alcove's back wall becomes one big LEAVE screen ---------------------------------------
do
	local RO = CFrame.new(0, 0, 2600)
	local alcove = workspace.LobbyV5.Range.Alcove
	for _, n in { "ExitGate", "LeaveScreen" } do
		local old = alcove:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local m = K.model(alcove, "LeaveScreen")
	local function lp(name, a, b, lk)
		return K.lpart(RO, m, name, a, b, lk)
	end
	-- a dark plinth, the case (one size up from the screen), a bezel, the screen (its front faces the yard, -Z)
	lp("Plinth", V(-18.6, 0, 143.2), V(18.6, 0.9, 145), K.L.plate)
	lp("Case", V(-18, 0.9, 144.1), V(18, 17.2, 145), K.L.dark)
	lp("CaseTop", V(-16.8, 17.2, 144.1), V(16.8, 18.4, 145), K.L.dark)
	lp("Bezel", V(-17.4, 1.5, 143.95), V(17.4, 17.8, 144.1), K.L.plate)
	local screen = lp("Screen", V(-17, 1.9, 143.85), V(17, 17.4, 143.95), K.paint(INK))
	ghost(screen)
	-- the case's top corners cut at 45 degrees: a wedge each side, tall side toward the middle
	for _, sx in { -1, 1 } do
		local Z = V(-sx, 0, 0)
		local X = Vector3.yAxis:Cross(Z)
		K.part(m, "CaseChamfer", V(0.9, 1.2, 1.2), RO * CFrame.fromMatrix(V(sx * 17.4, 17.8, 144.55), X, Vector3.yAxis), K.L.dark, "WedgePart")
	end
	-- the screen: LEAVE, the way back; it lights the alcove. 12 px per stud: TextScaled / TextSize stop at 100 px, so
	-- a low density is what makes LEAVE ~8 studs tall (408 x 186 px canvas).
	local g = surface(screen, Enum.NormalId.Front, 12)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(14, 17, 21)
	bg.BorderSizePixel = 0
	bg.Parent = g
	local grid = Instance.new("ImageLabel")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 1)
	grid.Image = "rbxassetid://99198970022758"
	grid.ImageColor3 = TEAL
	grid.ImageTransparency = 0.82
	grid.ScaleType = Enum.ScaleType.Tile
	grid.TileSize = UDim2.fromOffset(60, 60)
	grid.Parent = bg
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(rgb(255, 255, 255), rgb(150, 160, 168))
	grad.Parent = bg
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = TEAL
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 14)
	bar.Size = UDim2.fromOffset(70, 5)
	bar.Parent = bg
	label(bg, "LEAVE", K.RUBIK_H, 100, Color3.new(1, 1, 1), UDim2.fromScale(0.5, 0.44), UDim2.fromOffset(400, 104), Vector2.new(0.5, 0.5))
	label(bg, "«  BACK TO THE LOBBY  »", K.RUBIK_B, 20, TEAL, UDim2.fromScale(0.5, 0.74), UDim2.fromOffset(380, 24), Vector2.new(0.5, 0.5))
	label(bg, "WALK IN", K.RUBIK_B, 11, rgb(170, 178, 188), UDim2.fromScale(0.5, 0.86), UDim2.fromOffset(200, 14), Vector2.new(0.5, 0.5))
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color = rgb(200, 240, 230)
	light.Brightness = 1.6
	light.Range = 18
	light.Angle = 120
	light.Parent = screen
	-- the threshold: a glow line on the floor in front, and the walk-in trigger
	ghost(lp("Threshold", V(-16, 0, 140.85), V(16, 0.06, 141.15), K.neon(K.dim(TEAL, 0.25))))
	local trig = lp("Trigger", V(-17, 0, 140.5), V(17, 12, 143.8), K.paint(INK))
	trig.Transparency = 1
	trig.CanCollide, trig.CanQuery, trig.CastShadow = false, false, false
	trig.CanTouch = true
	CS:AddTag(trig, "RangeExit")
	table.insert(report, "range: LEAVE screen 34 x 15.5 on the alcove's back wall, trigger tagged RangeExit")
end

-- 2. THE HUB'S RANGE GATE ----------------------------------------------------------------------------------------------
-- Hub-local frame: K.O = (0, 0, -1600), +Z is the hub's south (the bay). The opening is x -13..13 in the south wall.
local hub = workspace.LobbyV5.Shell.Hub
local bay = hub.RangeBay
for _, n in { "Doors", "ClosedShutter", "ShutterBand", "Caption", "SimBay", "Frame", "Sign_RANGE", "RangeEntry", "Gate", "Chamber" } do
	local old = bay:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end
-- raise the stone over the opening: the portal is 28 tall
local above = hub.Rock:FindFirstChild("Above_S")
if above and above.Size.Y > 19 then
	local top = above.Position.Y + above.Size.Y / 2
	above.Size = V(above.Size.X, top - 30, above.Size.Z)
	above.Position = V(above.Position.X, (top + 30) / 2, above.Position.Z)
	table.insert(report, "hub: Above_S raised to start at 30")
end
-- the wall screen on Above_S goes up with it (it was centred at 35)
local screenS = hub.Dressing:FindFirstChild("Screens") and hub.Dressing.Screens:FindFirstChild("Screen_S")
if screenS then
	local p = screenS:GetPivot()
	if p.Y < 40 then
		screenS:PivotTo(p + V(0, 8.5, 0))
	end
end

local gate = K.model(bay, "Gate")
local O = CFrame.new(K.O)
local function hp(parent, name, a, b, lk)
	return K.lpart(O, parent, name, a, b, lk)
end
local FZ = 46.6 -- the field's plane (hub-local z)
-- pylons with a flared foot and head, a header, chamfered inner top corners, teal edge light
for _, sx in { -1, 1 } do
	hp(gate, "Pylon", V(sx * 13, 0, 44.4), V(sx * 15.4, 30, 48.8), K.L.dark)
	hp(gate, "PylonFoot", V(sx * 12.6, 0, 44), V(sx * 15.8, 1.2, 49.2), K.L.plate)
	hp(gate, "PylonCap", V(sx * 12.6, 29.2, 44), V(sx * 15.8, 30.4, 49.2), K.L.plate)
	ghost(hp(gate, "EdgeLight", V(sx * 12.94, 1.2, 45.6), V(sx * 13.04, 27.6, 45.9), K.neon(K.dim(TEAL, 0.15))))
	-- the inner top corner filled with a 45-degree plate: an upside-down wedge, tall side on the pylon
	K.part(gate, "Chamfer", V(4.4, 2.6, 2.6), O * CFrame.fromMatrix(V(sx * 11.7, 26.7, 46.6), V(0, 0, sx), V(0, -1, 0)), K.L.dark, "WedgePart")
end
hp(gate, "Header", V(-13, 28, 44.4), V(13, 30, 48.8), K.L.dark)
ghost(hp(gate, "HeaderLight", V(-10.4, 27.86, 45.6), V(10.4, 27.96, 45.9), K.neon(K.dim(TEAL, 0.15))))
hp(gate, "Sill", V(-13, 0, 44.4), V(13, 0.18, 48.8), K.L.plate)
ghost(hp(gate, "SillGlow", V(-12, 0.18, 46.4), V(12, 0.24, 46.8), K.neon(K.dim(TEAL, 0.1))))
-- the holographic field: a ForceField sheet (it shimmers) and, just in front, the projection (grid + words)
local field = ghost(hp(gate, "Field", V(-13, 0.25, FZ - 0.05), V(13, 28, FZ + 0.05), K.look(nil, TEAL, Enum.Material.ForceField)))
field.Transparency = 0.1
local proj = ghost(hp(gate, "Projection", V(-13, 0.25, FZ - 0.25), V(13, 28, FZ - 0.2), K.paint(TEAL)))
proj.Transparency = 1
local pg = surface(proj, Enum.NormalId.Front, 20)
pg.Brightness = 2
local grid = Instance.new("ImageLabel")
grid.BackgroundTransparency = 1
grid.Size = UDim2.fromScale(1, 1)
grid.Image = "rbxassetid://99198970022758"
grid.ImageColor3 = TEAL
grid.ImageTransparency = 0.55
grid.ScaleType = Enum.ScaleType.Tile
grid.TileSize = UDim2.fromOffset(100, 100)
grid.Parent = pg
local fade = Instance.new("UIGradient")
fade.Rotation = 90
fade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(0.75, 0.55),
	NumberSequenceKeypoint.new(1, 0.9),
})
fade.Parent = grid
label(pg, "SHOOTING", K.RUBIK_H, 100, Color3.new(1, 1, 1), UDim2.new(0.5, 0, 0, 70), UDim2.fromOffset(480, 110), Vector2.new(0.5, 0)).TextScaled = true
label(pg, "RANGE", K.RUBIK_H, 100, TEAL:Lerp(Color3.new(1, 1, 1), 0.35), UDim2.new(0.5, 0, 0, 170), UDim2.fromOffset(420, 110), Vector2.new(0.5, 0)).TextScaled = true
label(pg, "EVERY GUN  ·  TARGETS  ·  BOTS", K.RUBIK_B, 26, Color3.new(1, 1, 1), UDim2.new(0.5, 0, 0, 292), UDim2.fromOffset(500, 32), Vector2.new(0.5, 0))
label(pg, "»  WALK IN  «", K.RUBIK_H, 34, Color3.new(1, 1, 1), UDim2.new(0.5, 0, 1, -110), UDim2.fromOffset(420, 44), Vector2.new(0.5, 0))
-- the field lights the hub teal (pools on the floor in front), and the threshold glows
local spill = Instance.new("SurfaceLight")
spill.Face = Enum.NormalId.Front
spill.Color = TEAL
spill.Brightness = 1.3
spill.Range = 22
spill.Angle = 110
spill.Parent = field
for _, sx in { -1, 1 } do
	K.point(hp(gate, "FootLamp", V(sx * 11.6, 0, 43.6), V(sx * 12.6, 0.4, 44.4), K.neon(K.dim(TEAL, 0.2))), TEAL, 1.2, 12)
end
-- the walk-in trigger, just past the field
local entry = hp(gate, "RangeEntry", V(-12.5, 0, FZ + 0.2), V(12.5, 10, FZ + 3.2), K.paint(INK))
entry.Transparency = 1
entry.CanCollide, entry.CanQuery, entry.CastShadow = false, false, false
entry.CanTouch = true
CS:AddTag(entry, "RangeEntry")
-- the approach on the hub floor: two glow lines and a dark apron
hp(gate, "Apron", V(-13, 0, 36), V(13, 0.08, 44.4), K.L.plate)
for _, sx in { -1, 1 } do
	ghost(hp(gate, "ApproachLine", V(sx * 10.4, 0.08, 36.4), V(sx * 10.0, 0.12, 44.2), K.neon(K.dim(TEAL, 0.2))))
end
-- the sign over the gate, tilted down at the hub, on the stone above
local okSign = pcall(function()
	W.sign(O * CFrame.new(0, 37.5, 43.7) * CFrame.Angles(0, math.pi, 0), gate, {
		word = "SHOOTING RANGE",
		sub = "PRACTICE  ·  EVERY GUN FREE",
		tileText = "»", -- the range icon drew as a black blob on the tile (2026-11-26)
		col = TEAL,
		h = 6,
		tilt = 12,
		lamps = true,
		mount = "wall",
		name = "Sign",
	})
end)
if not okSign then
	table.insert(report, "sign skipped (W.sign failed)")
end

-- 3. THE CHAMBER BEHIND THE GATE: open to the sky, the structure at the back ---------------------------------------------
local ch = K.model(bay, "Chamber")
local Z0, Z1, HW, WH = 49.2, 112, 22, 34
hp(ch, "Floor", V(-HW, -2, Z0), V(HW, 0, Z1), K.L.floor)
for _, sx in { -1, 1 } do
	hp(ch, "Wall", V(sx * HW, 0, Z0), V(sx * (HW + 4), WH, Z1 + 4), K.L.board)
	hp(ch, "Wainscot", V(sx * (HW - 0.5), 0, Z0), V(sx * HW, 3, Z1), K.L.wains)
	-- tall light slots along the walls
	for z = Z0 + 8, Z1 - 6, 12 do
		ghost(hp(ch, "Slot", V(sx * (HW - 0.12), 4, z - 0.4), V(sx * HW, WH - 6, z + 0.4), K.neon(K.dim(TEAL, 0.5))))
	end
	-- the walls meet the hub's stone at the gate's sides
	hp(ch, "Return", V(sx * 13, 0, 44.4), V(sx * HW, WH, Z0), K.L.board)
end
hp(ch, "Back", V(-HW - 4, 0, Z1), V(HW + 4, WH, Z1 + 4), K.L.board)
hp(ch, "Lintel", V(-13, 30, 44.4), V(13, WH, Z0), K.L.board)
-- teal floor lines from the gate to the dais
for _, x in { -6, 6 } do
	ghost(hp(ch, "FloorLine", V(x - 0.2, 0, Z0 + 2), V(x + 0.2, 0.06, 86), K.neon(K.dim(TEAL, 0.25))))
end
-- the dais: two steps, a glow ring, three training bots (posed, matte blue; not RangeBots)
hp(ch, "DaisLow", V(-14, 0, 86), V(14, 1, 100), K.L.darkConc)
hp(ch, "DaisTop", V(-12, 1, 87.5), V(12, 2, 98.5), K.L.plate)
ghost(hp(ch, "DaisGlow", V(-12, 0.96, 87.3), V(12, 1.04, 87.5), K.neon(K.dim(TEAL, 0.2))))
local template = workspace.LobbyV5.Range.Yard.Dummies:FindFirstChild("Dummy6")
local tBot = template and template:FindFirstChild("TrainingBot")
if tBot then
	for i, x in { -7, 0, 7 } do
		local b = tBot:Clone()
		for _, tag in b:GetTags() do
			b:RemoveTag(tag)
		end
		for _, d in b:GetDescendants() do
			if d:IsA("Clothing") or d:IsA("Accessory") or d:IsA("BodyColors") or d:IsA("Decal") or d:IsA("FaceControls") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.Material = Enum.Material.SmoothPlastic
				d.Color = rgb(52, 118, 226)
				if d:IsA("MeshPart") and d.Name == "Head" then
					d.TextureID = ""
				end
			end
		end
		local hum = b:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		b.Name = "ShowBot" .. i
		b:PivotTo(O * CFrame.lookAt(V(x, 2 + 3.02, 93 - math.abs(x) * 0.3), V(x * 0.4, 2 + 3.02, 0)))
		b.Parent = ch
	end
end
-- the structure at the back: a giant target on a steel A-frame gantry, lit from the floor
local kit = SS.V5Kit:FindFirstChild("AirTarget")
if kit then
	local big = kit:Clone()
	big.Name = "GiantTarget"
	big:ScaleTo(6)
	big:PivotTo(O * CFrame.new(0, 19, 105) * CFrame.Angles(0, math.pi, 0))
	for _, d in big:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery = false, false
		end
	end
	big.Parent = ch
end
local legs = { { -15, 0, 107.6 }, { 15, 0, 107.6 } }
for _, l in legs do
	-- each leg leans in toward the target's rim; a foot plate, a collar where it meets the crossbeam
	local foot = V(l[1], 0, l[3])
	local topP = V(l[1] * 0.55, 31, l[3])
	local mid = (foot + topP) / 2
	local len = (topP - foot).Magnitude
	K.part(ch, "Leg", V(1.6, len, 1.6), O * CFrame.lookAt(mid, mid + V(0, 0, 1), (topP - foot).Unit), K.L.dark)
	hp(ch, "LegFoot", foot - V(1.6, 0, 1.6), foot + V(1.6, 0.6, 1.6), K.L.plate)
end
hp(ch, "Crossbeam", V(-10, 30.2, 106.8), V(10, 32, 108.4), K.L.dark)
hp(ch, "Hanger", V(-0.5, 23.5, 106.8), V(0.5, 30.2, 108), K.L.steel)
-- light: spots on the target from the dais, uplights on the gantry, cool fill from above
for _, x in { -9, 9 } do
	local lens = ghost(hp(ch, "SpotLens", V(x - 0.6, 2, 99), V(x + 0.6, 2.6, 99.6), K.neon(K.dim(TEAL, 0.1))))
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Back
	s.Color = rgb(235, 245, 255)
	s.Brightness = 3
	s.Range = 28
	s.Angle = 40
	s.Parent = lens
end
for _, l in legs do
	local up = ghost(hp(ch, "Uplight", V(l[1] - 0.5, 0.6, l[3] - 2.6), V(l[1] + 0.5, 1, l[3] - 1.6), K.neon(K.dim(TEAL, 0.1))))
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Top
	s.Color = TEAL
	s.Brightness = 2
	s.Range = 30
	s.Angle = 30
	s.Parent = up
end

-- 4. THE WAY BACK FROM THE RANGE: in front of the gate, facing the hub -------------------------------------------------
local ret = bay:FindFirstChild("RangeReturn")
if ret then
	local at = K.O + V(0, 3, 32)
	ret.CFrame = CFrame.lookAt(at, at - V(0, 0, 1))
end

local n = 0
for _, d in bay:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
table.insert(report, ("hub: range gate + chamber built, %d parts in RangeBay"):format(n))
return table.concat(report, "\n")
