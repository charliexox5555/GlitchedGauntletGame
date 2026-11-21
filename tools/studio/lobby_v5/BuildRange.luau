--!nocheck
-- Lobby V5 RANGE, the TEST HALL (vault/02 Art/Lobby V5 Plan.md, "Range: the test hall"). ONE-TIME placement record
-- (needs V5Kit.LobbyKit + LobbyWay + LobbySigns). Owner 2026-11-21: "start by building the range ... this is the
-- rival shooting range, which is kind of the vibe we're going for ... use like the arena bricks ... bots different
-- sets away that kind of stand there ... these trash cans ... is what they do to change their loadout ... We don't
-- need to do that yet. We're literally just building it". Reference: Workspace.ShootingRangeRivals (read-only):
-- a grey 5-stud-module playground (151,153,163 Plastic + a black grid Texture at 0.75), cover blocks, platforms on
-- 5x15x5 posts with 2.5 slabs, truss ladders, loadout bins, bots spawned at runtime.
-- Extends Hub.RangeBay (memory: never replace it): the sim bay's back wall opens into a hall behind it; the hologram
-- preview stays; the curtain now says NOW OPEN; the THE DEEP landmark (SeasonMount RangeLandmark) moves to the far
-- wall, bigger (the owner's "Hollywood thing at the back").
-- Frame F = the range bay's (origin at the bay face, z toward the hub, walking in = -z). The hall: x ±60, z -41 ..
-- -196 inside, 40 high, floor y 0. Our arena recipe (memory arena-plain-rivals-parts): two greys, our grid tile.
-- Hooks for later code, no code now: bots tagged `RangeBot` (Distance, Lane), bins tagged `RangeLoadout`.

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local W = require(SS.V5Kit.LobbyWay:Clone())
local S = require(SS.V5Kit.LobbySigns:Clone())
local K = W.K
local V = Vector3.new
local L = K.L
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local F = K.frame(V(0, 0, 42), V(0, 0, -1))
local bay = workspace.LobbyV5.Shell.Hub.RangeBay
local GRID = "rbxassetid://99198970022758"
local STRUCT, BLOCK = rgb(151, 153, 163), rgb(132, 134, 143)
local old = bay:FindFirstChild("Hall")
if old then
	old:Destroy()
end
local hall = K.model(bay, "Hall")
local function box(Fb, parent, name, a, b, lk)
	return K.lpart(Fb, parent, name, a, b, lk)
end
-- an arena brick: plain Plastic, the grid on its faces
local function brick(parent, name, a, b, col, faces)
	local p = box(F, parent, name, a, b, K.look(nil, col or STRUCT, Enum.Material.Plastic))
	for _, f in faces or Enum.NormalId:GetEnumItems() do
		local t = K.texture(p, f, GRID, 5)
		t.Color3 = Color3.new(0, 0, 0)
		t.Transparency = 0.75
	end
	return p
end
local function paint(parent, name, a, b, col)
	return box(F, parent, name, a, b, K.paint(col))
end

-- 1. OPEN THE SIM BAY into the hall ----------------------------------------------------------------------------------
local sim = bay.SimBay
if sim:FindFirstChild("Wall_Back") then
	local lk = sim.Wall_L
	sim.Wall_Back:Destroy()
	for _, sd in { -1, 1 } do
		local p = box(
			F,
			sim,
			"WallEnd",
			V(sd * 12, 0, -36),
			V(sd * 13, 18, -35),
			K.look(nil, lk.Color, lk.Material)
		)
		p.MaterialVariant = lk.MaterialVariant
	end
end
for _, d in bay.HoloCurtain:GetDescendants() do
	if d:IsA("TextLabel") and d.Text:find("COMING SOON") then
		d.Text = "»  NOW OPEN"
	end
end

-- 2. THE HALL: floor, walls, ceiling ---------------------------------------------------------------------------------
local X, Z0, Z1, H = 60, -41, -196, 40
brick(hall, "Floor", V(-X - 5, -2, Z1 - 5), V(X + 5, 0, -36), STRUCT, { Enum.NormalId.Top })
brick(hall, "Front_L", V(-X - 5, 0, Z0), V(-12, H, -36))
brick(hall, "Front_R", V(12, 0, Z0), V(X + 5, H, -36))
brick(hall, "Front_Top", V(-12, 18, Z0), V(12, H, -36))
for _, sd in { -1, 1 } do
	brick(hall, sd < 0 and "Wall_L" or "Wall_R", V(sd * X, 0, Z1), V(sd * (X + 5), H, Z0))
end
brick(hall, "Wall_Back", V(-X - 5, 0, Z1 - 5), V(X + 5, H, Z1))
box(
	F,
	hall,
	"Ceiling",
	V(-X - 5, H, Z1 - 5),
	V(X + 5, H + 2, -36),
	K.look("Concrete-02a", rgb(48, 48, 51))
)
-- the opening gets a steel frame on the hall side
local Fo = F * CFrame.new(0, 0, Z0) * CFrame.Angles(0, math.pi, 0)
for _, sd in { -1, 1 } do
	box(Fo, hall, "OpeningJamb", V(sd * 12, 0, 0), V(sd * 13.2, 18, 0.5), L.dark)
end
box(Fo, hall, "OpeningHead", V(-13.2, 18, 0), V(13.2, 19.2, 0.5), L.dark)
-- light: three rows of big downlights
for _, x in { -30, 0, 30 } do
	for z = -60, -185, -25 do
		local m = K.model(hall, "Downlight")
		box(F, m, "Housing", V(x - 2, H - 0.5, z - 2), V(x + 2, H, z + 2), L.dark)
		box(F, m, "Trim", V(x - 2.2, H - 0.15, z - 2.2), V(x + 2.2, H, z + 2.2), L.steel)
		local lens = K.ghost(
			box(F, m, "Lens", V(x - 1.7, H - 0.56, z - 1.7), V(x + 1.7, H - 0.5, z + 1.7), L.white)
		)
		K.spot(m, lens, Enum.NormalId.Bottom, rgb(255, 240, 224), 1.6, 50, 110)
	end
end

-- 3. FIRING LINE and distance markers --------------------------------------------------------------------------------
local FL = -45
local marks = K.model(hall, "Marks")
local yellow = rgb(232, 182, 34)
paint(marks, "FiringLine", V(-X, 0, FL - 0.4), V(X, 0.04, FL + 0.4), yellow)
local function stencil(text, x, z, size, col)
	local p = K.part(
		marks,
		"Stencil",
		V(size * #text * 0.7, 0.02, size),
		F * CFrame.new(x, 0.03, z),
		K.paint(Color3.new(0, 0, 0))
	)
	p.Transparency = 1
	K.ghost(p)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = 1
	g.Parent = p
	W.label(
		g,
		text,
		K.RUBIK_H,
		math.floor(size * 20 * 0.8),
		col,
		UDim2.new(),
		UDim2.fromScale(1, 1),
		Enum.TextXAlignment.Center
	)
	return p
end
stencil("FIRING LINE", 0, FL + 2.2, 2.4, yellow)
for d = 25, 125, 25 do
	local z = FL - d
	paint(
		marks,
		"DistanceLine",
		V(-X + 2, 0, z - 0.15),
		V(X - 2, 0.03, z + 0.15),
		rgb(226, 226, 222)
	)
	for _, x in { -X + 6, X - 6 } do
		stencil(tostring(d), x, z + 2.0, 2.6, rgb(226, 226, 222))
	end
end

-- 4. TRAINING BOTS on pads, three lanes at different distances --------------------------------------------------------
local bots = K.model(hall, "Bots")
local LANES = {
	{ x = -30, d = { 20, 60, 110 } },
	{ x = 0, d = { 35, 80, 130 } },
	{ x = 30, d = { 45, 95, 120 } },
}
local function oct(Fb, parent, name, d, y0, y1, lk)
	return S.octagon(Fb * CFrame.Angles(-math.pi / 2, 0, 0), parent, name, d, y0, y1, lk)
end
local botBase
do
	local desc = Instance.new("HumanoidDescription")
	botBase = game:GetService("Players")
		:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	for _, c in botBase:GetDescendants() do
		if c:IsA("Script") or c:IsA("LocalScript") then
			c:Destroy()
		end
	end
	local bc = botBase:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3 = rgb(206, 208, 214)
		bc.TorsoColor3 = yellow
		bc.LeftArmColor3, bc.RightArmColor3 = rgb(70, 72, 78), rgb(70, 72, 78)
		bc.LeftLegColor3, bc.RightLegColor3 = rgb(58, 60, 66), rgb(58, 60, 66)
	end
	local hum = botBase:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, p in botBase:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
end
for li, lane in LANES do
	for _, d in lane.d do
		local z = FL - d
		local Fp = F * CFrame.new(lane.x, 0, z)
		local pad = K.model(bots, ("Pad_%s_%d"):format(string.sub("LCR", li, li), d))
		oct(Fp, pad, "Base", 4.6, 0, 0.3, L.dark)
		oct(Fp, pad, "Top", 3.9, 0.3, 0.42, L.steel)
		oct(Fp, pad, "Ring", 4.0, 0.29, 0.33, K.paint(yellow))
		-- a distance plate on a post at the pad's front right
		local Fs = Fp * CFrame.new(2.9, 0, 1.6)
		box(Fs, pad, "PostFoot", V(-0.3, 0, -0.3), V(0.3, 0.12, 0.3), L.steel)
		box(Fs, pad, "Post", V(-0.09, 0.12, -0.09), V(0.09, 2.4, 0.09), L.dark)
		local plate = box(Fs, pad, "Plate", V(-0.8, 2.4, -0.05), V(0.8, 3.2, 0.05), L.plate)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Back
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.5
		g.Parent = plate
		W.label(
			g,
			tostring(d),
			K.RUBIK_H,
			26,
			rgb(242, 239, 232),
			UDim2.fromScale(0, 0),
			UDim2.fromScale(0.62, 1),
			Enum.TextXAlignment.Right
		)
		W.label(
			g,
			"STUDS",
			K.RUBIK_B,
			11,
			yellow,
			UDim2.fromScale(0.66, 0.1),
			UDim2.fromScale(0.34, 0.9),
			Enum.TextXAlignment.Left
		)
		-- the bot
		local bot = botBase:Clone()
		bot.Name = "TrainingBot"
		local hrp = bot:FindFirstChild("HumanoidRootPart")
		local hum = bot:FindFirstChildOfClass("Humanoid")
		local hip = if hum then hum.HipHeight else 2
		local stand = Fp * CFrame.new(0, 0.42 + hip + hrp.Size.Y / 2, 0)
		bot:PivotTo(CFrame.lookAt(stand.Position, stand.Position + Fp.LookVector * -1))
		bot:SetAttribute("Distance", d)
		bot:SetAttribute("Lane", string.sub("LCR", li, li))
		bot.Parent = pad
		CS:AddTag(bot, "RangeBot")
	end
end
botBase:Destroy()

-- 5. COVER, TOWERS, LADDERS (arena bricks in the darker grey) --------------------------------------------------------
local cover = K.model(hall, "Cover")
local COVER = {
	{ V(-20, 0, -87), V(-10, 10, -77) },
	{ V(12.5, 0, -118), V(17.5, 10, -98) },
	{ V(-50, 0, -115), V(-40, 10, -105) },
	{ V(40, 0, -80), V(50, 5, -70) },
	{ V(-25, 0, -152.5), V(-5, 10, -147.5) },
	{ V(15, 0, -160), V(25, 10, -150) },
}
for i, c in COVER do
	brick(cover, "Block" .. i, c[1], c[2], BLOCK)
end
for _, sd in { -1, 1 } do
	local t = K.model(cover, sd < 0 and "Tower_L" or "Tower_R")
	local x0, x1 = sd * 40, sd * 60
	local lo, hi = math.min(x0, x1), math.max(x0, x1)
	for _, x in { lo, hi - 5 } do
		for _, z in { -140, -125 } do
			brick(t, "Post", V(x, 0, z), V(x + 5, 15, z + 5), STRUCT)
		end
	end
	brick(t, "Slab", V(lo, 15, -140), V(hi, 17.5, -120), STRUCT)
	brick(t, "Parapet", V(lo, 17.5, -140), V(hi, 20, -137.5), STRUCT)
	local truss = Instance.new("TrussPart")
	truss.Name = "Ladder"
	truss.Anchored = true
	truss.Size = V(2, 17.5, 2)
	truss.CFrame = F * CFrame.new(sd * 39, 8.75, -130)
	truss.Color = rgb(70, 72, 78)
	truss.Material = Enum.Material.Metal
	truss.Parent = t
end

-- 6. LOADOUT BINS: our own take on RIVALS' bins (a faceted steel bin, a hinged lid, a cyan band and the locker
-- icon); tagged for the loadout GUI later -------------------------------------------------------------------------------
local bins = K.model(hall, "LoadoutBins")
local CYAN = K.AREA.locker.col
for i, p in ipairs({
	{ -18, -50 },
	{ 18, -50 },
	{ -56, -62 },
	{ 56, -62 },
	{ -40, -186 },
	{ 40, -186 },
}) do
	local Fb = F * CFrame.new(p[1], 0, p[2]) * CFrame.Angles(0, math.rad(p[1] < 0 and 30 or -30), 0)
	local m = K.model(bins, "LoadoutBin" .. i)
	oct(Fb, m, "Foot", 3.2, 0, 0.25, L.dark)
	oct(Fb, m, "Body", 2.9, 0.25, 3.1, K.look("Metal 2022", rgb(64, 66, 72)))
	oct(Fb, m, "Band", 3.0, 2.2, 2.55, K.paint(CYAN))
	oct(Fb, m, "Rim", 3.15, 3.1, 3.3, L.steel)
	oct(Fb, m, "Lid", 3.05, 3.3, 3.55, L.dark)
	box(Fb, m, "Hinge", V(-0.5, 3.15, -1.62), V(0.5, 3.45, -1.45), L.steel)
	box(Fb, m, "Handle", V(-0.45, 3.55, 0.9), V(0.45, 3.7, 1.15), L.steel)
	local Ft = Fb * CFrame.new(0, 1.35, 1.45)
	box(Ft, m, "Tile", V(-0.55, -0.55, 0), V(0.55, 0.55, 0.06), K.paint(CYAN))
	local tg = W.face(Ft, m, "TileFace", 1.1, 1.1, 0.07, 0.3)
	local ic = Instance.new("ImageLabel")
	ic.BackgroundTransparency = 1
	ic.Size = UDim2.fromScale(1, 1)
	ic.Image = K.AREA.locker.icon
	ic.ImageColor3 = rgb(18, 19, 22)
	ic.Parent = tg
	m:SetAttribute("Station", "Loadout")
	CS:AddTag(m, "RangeLoadout")
end

-- 7. THE LANDMARK to the far wall, bigger ---------------------------------------------------------------------------
local lm = bay:FindFirstChild("Landmark")
if lm and not lm:GetAttribute("MovedToHall") then
	lm:ScaleTo(lm:GetScale() * 1.8)
	local mn = math.huge
	local miny = math.huge
	for _, p in lm:GetDescendants() do
		if p:IsA("BasePart") then
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local l = F:PointToObjectSpace(p.CFrame * (p.Size / 2 * V(sx, sy, sz)))
						mn = math.min(mn, l.Z)
						miny = math.min(miny, l.Y)
					end
				end
			end
		end
	end
	local cf = lm:GetBoundingBox()
	local c = F:PointToObjectSpace(cf.Position)
	lm:PivotTo(lm:GetPivot() + F:VectorToWorldSpace(V(-c.X, -miny, (Z1 + 0.05) - mn)))
	lm:SetAttribute("MovedToHall", true)
end

local n = 0
for _, d in hall:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("range hall: %d parts"):format(n)
