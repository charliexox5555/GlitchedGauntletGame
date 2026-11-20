--!nocheck
-- Lobby V5 duels hall STRUCTURE (vault/02 Art/Lobby V5 Plan.md, "Duels hall"). ONE-TIME placement record run
-- through the Studio MCP; rebuilds Workspace.LobbyV5.Shell.Duels only and removes the hub's temporary DuelsStub.
-- Cages / pads, signs and dressing come later. Every piece is its own Part or MeshPart; repeating units
-- (wall bays, deck panels, gantry lines) are their own Models so they can be moved or swapped by hand.
-- Coordinates are hub-local (O = hub centre, floor top). North = -Z. Deck top y = -1 (one step below the hub).

local MS = game:GetService("MaterialService")
local SS = game:GetService("ServerStorage")
local O = Vector3.new(0, 0, -1600)
local UP = Vector3.yAxis
local kit = SS.V5Kit
local hub = workspace.LobbyV5.Shell.Hub

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
	board = look("Lobby_ConcreteBoard", Color3.fromRGB(118, 116, 112)),
	trim = look("Concrete-02a", Color3.fromRGB(128, 126, 123)),
	wains = look("Concrete-02a", Color3.fromRGB(88, 87, 85)),
	darkConc = look("Concrete-02a", Color3.fromRGB(62, 62, 64)),
	corr = look("Corrugated_01a", Color3.fromRGB(138, 140, 144)),
	steel = look("Metal 2022", Color3.fromRGB(104, 106, 110)),
	dark = look("Metal 2022", Color3.fromRGB(52, 54, 58)),
	diamond = look("Diamond Plate 2022", Color3.fromRGB(104, 106, 110)),
	grate = look("Bunker_Grate", Color3.fromRGB(78, 80, 84)),
	under = look(nil, Color3.fromRGB(20, 20, 22), Enum.Material.Metal),
	rock = look("Lobby_Rock", Color3.fromRGB(132, 116, 102)),
	paint = look(nil, Color3.fromRGB(196, 152, 34), Enum.Material.SmoothPlastic),
	lens = look(nil, Color3.fromRGB(176, 150, 118), Enum.Material.Neon),
	white = look(nil, Color3.fromRGB(126, 120, 112), Enum.Material.Neon),
}
local WARM = Color3.fromRGB(255, 196, 140)
local WHITE = Color3.fromRGB(255, 244, 228)
local HAZARD = "rbxassetid://75158634706115"

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
local function bar(parent, name, a, b, th, lk) -- a beam between two hub-local points
	local A, B = O + a, O + b
	return part(parent, name, Vector3.new(th, th, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B), lk)
end
local function tri(parent, name, p, u, a, v, b, w, th, lk)
	local X, Y = w.Unit, u.Unit
	if X:Cross(Y):Dot(-v.Unit) < 0 then
		X = -X
	end
	return part(parent, name, Vector3.new(th, a, b), CFrame.fromMatrix(O + p + u.Unit * a / 2 + v.Unit * b / 2, X, Y), lk, "WedgePart")
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function texture(p, face, tile)
	local t = Instance.new("Texture")
	t.Face = face
	t.Texture = HAZARD
	t.StudsPerTileU = tile
	t.StudsPerTileV = tile
	t.Parent = p
end
local function light(p, cls, face, col, bright, range, angle, shadows)
	local l = Instance.new(cls)
	l.Color = col
	l.Brightness = bright
	l.Range = range
	if cls == "SpotLight" then
		l.Angle = angle
		l.Face = face
	end
	l.Shadows = shadows ~= false
	l.Parent = p
end
local function source(parent, name, pos, target, col, bright, range, angle)
	local p = part(parent, name, Vector3.new(0.5, 0.5, 0.5), CFrame.lookAt(O + pos, O + target), look(nil, Color3.new(1, 1, 1)))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	light(p, "SpotLight", Enum.NormalId.Front, col, bright, range, angle)
end

-- rock pieces (imported face points local -Z, so a 180 degree turn); base = bottom-centre of the back face
local nRock = 0
local function rockWall(parent, name, tpl, base, n, w, h, flip, depthScale)
	local t = kit[tpl]
	local D = t.Size.Z * (depthScale or 1)
	local cf = CFrame.fromMatrix(O + base, UP:Cross(n), UP) * CFrame.new(0, h / 2, D / 2) * CFrame.Angles(0, math.pi, 0)
	if flip then
		cf *= CFrame.Angles(0, 0, math.pi)
	end
	local m = t:Clone()
	m.Name = name
	m.Size = Vector3.new(w, h, D)
	m.CFrame = cf
	m.Material, m.MaterialVariant, m.Color = L.rock.mat, L.rock.var, L.rock.col
	m.Parent = parent
	nRock += 1
	return m
end
local function rockFlat(parent, name, cx, cz, w, dpt, yBack, faceDown, rot)
	local t = kit.V5_RockCeil_A
	local D = t.Size.Z
	local y = faceDown and (yBack - D / 2) or (yBack + D / 2)
	local cf = CFrame.fromMatrix(O + Vector3.new(cx, y, cz), Vector3.xAxis, Vector3.zAxis)
	if rot then
		cf *= CFrame.Angles(0, 0, math.pi)
	end
	if faceDown then
		cf *= CFrame.Angles(math.pi, 0, 0)
	end
	local m = t:Clone()
	m.Name = name
	m.Size = Vector3.new(w, dpt, D)
	m.CFrame = cf
	m.Material, m.MaterialVariant, m.Color = L.rock.mat, L.rock.var, L.rock.col
	m.Parent = parent
	nRock += 1
	return m
end

-- LAYOUT ---------------------------------------------------------------------------------------------
local X0, X1 = -122, 122 -- hall width (v2, owner 2026-11-20: bigger queue bays; rock walls clear the gantry by 4+)
local ZW = -60 -- bulkhead face (south wall of the hall)
local ZE = -96 -- deck front edge
local ZF = -150 -- far chasm wall (back plane)
local YD = -1 -- deck top
local YC = -90 -- chasm floor
local YCEIL = 70 -- back of the ceiling rock (faces hang to about 56)
-- queue bays (v2): eight equal 24-stud bays in mode order, mirrored from the tunnel; column lines every 26 studs.
-- 4v4 can be added later as end bays.
local BAY_MODES = { "3v3", "2v2", "1v1", "1v1", "1v1", "1v1", "2v2", "3v3" }
local BAYS = {}
for i, m in BAY_MODES do
	local c = -104 + 26 * (i - 1)
	BAYS[i] = { m, c + 1, c + 25 }
end
local COLS = {} -- column line centres (between bays and at both ends)
for _, b in BAYS do
	COLS[b[2] - 1] = true
	COLS[b[3] + 1] = true
end
local colX = {}
for x in COLS do
	table.insert(colX, x)
end
table.sort(colX)
local ZG0, ZG1 = -98, -124 -- gantry front / back column lines (bays are 26 deep)

---------------------------------------------------------------------------------------------------
local shell = workspace.LobbyV5.Shell
local old = shell:FindFirstChild("Duels")
if old then
	old:Destroy()
end
local stub = hub:FindFirstChild("DuelsStub")
if stub then
	stub:Destroy()
end
for _, n in { "Tunnel_1", "Tunnel_2", "Portal" } do
	local l = hub.Lights:FindFirstChild(n)
	if l then
		l:Destroy()
	end
end
local duels = model(shell, "Duels")
duels:SetAttribute("Bays", #BAYS)

-- 1. TUNNEL from the hub portal (z -50) to the bulkhead (z -60) ------------------------------------
local tun = model(duels, "Tunnel")
box(tun, "Floor", Vector3.new(-17, -3, ZW), Vector3.new(17, YD, -50), L.grate)
box(tun, "Step", Vector3.new(-17, YD, -51.5), Vector3.new(17, -0.4, -50), L.dark)
box(tun, "Wall_W", Vector3.new(-19, -3, ZW), Vector3.new(-17, 20, -50), L.darkConc)
box(tun, "Wall_E", Vector3.new(17, -3, ZW), Vector3.new(19, 20, -50), L.darkConc)
box(tun, "Roof", Vector3.new(-19, 20, ZW), Vector3.new(19, 22, -50), L.darkConc)
for i, z in { -53, -57 } do
	local m = model(tun, "CeilingLight_" .. i)
	box(m, "Housing", Vector3.new(-6, 19.3, z - 0.8), Vector3.new(6, 20, z + 0.8), L.dark)
	local ln = box(m, "Lens", Vector3.new(-5.6, 19.22, z - 0.5), Vector3.new(5.6, 19.3, z + 0.5), L.white)
	light(ln, "SpotLight", Enum.NormalId.Bottom, WHITE, 2.5, 26, 120)
end

-- 2. BULKHEAD (south wall of the hall): pilasters every 16 studs, battered wainscot, corrugated panels -
local bulk = model(duels, "Bulkhead")
local PIL = { -100, -84, -68, -52, -36, -20, 20, 36, 52, 68, 84, 100 } -- rock corners take over beyond +/-100
local WALL_TOP = 30
for _, x in PIL do
	local m = model(bulk, ("Pilaster_%d"):format(x))
	box(m, "Shaft", Vector3.new(x - 1.2, YD, ZW - 1.4), Vector3.new(x + 1.2, WALL_TOP - 1.5, ZW), L.trim)
	box(m, "Foot", Vector3.new(x - 1.6, YD, ZW - 1.9), Vector3.new(x + 1.6, YD + 1.4, ZW), L.wains)
	tri(m, "FootSlope", Vector3.new(x, YD + 1.4, ZW - 1.4), Vector3.new(0, 1, 0), 0.6, Vector3.new(0, 0, -1), 0.5, Vector3.xAxis, 3.2, L.wains) -- slope falls toward the deck
	box(m, "Head", Vector3.new(x - 1.6, WALL_TOP - 1.5, ZW - 1.9), Vector3.new(x + 1.6, WALL_TOP, ZW), L.trim)
	tri(m, "HeadSlope", Vector3.new(x, WALL_TOP - 1.5, ZW - 1.4), Vector3.new(0, -1, 0), 0.6, Vector3.new(0, 0, -1), 0.5, Vector3.xAxis, 3.2, L.trim) -- corbel under the head
end
for i = 1, #PIL - 1 do
	local xa, xb = PIL[i] + 1.2, PIL[i + 1] - 1.2
	if not (PIL[i] == -20 and PIL[i + 1] == 20) then -- the tunnel frame fills the middle
		local m = model(bulk, ("Bay_%d"):format(i))
		box(m, "Wall", Vector3.new(xa, YD, ZW), Vector3.new(xb, WALL_TOP, ZW + 2), L.board)
		box(m, "Wainscot", Vector3.new(xa, YD, ZW - 0.6), Vector3.new(xb, YD + 3.2, ZW), L.wains)
		tri(m, "WainscotSlope", Vector3.new((xa + xb) / 2, YD + 3.2, ZW), Vector3.new(0, 1, 0), 0.6, Vector3.new(0, 0, -1), 0.6, Vector3.xAxis, xb - xa, L.wains) -- slope falls toward the deck
		box(m, "Panel", Vector3.new(xa + 1.4, YD + 5.5, ZW - 0.3), Vector3.new(xb - 1.4, 23, ZW), L.corr)
		box(m, "PanelFrame_T", Vector3.new(xa + 1.0, 23, ZW - 0.45), Vector3.new(xb - 1.0, 23.5, ZW), L.dark)
		box(m, "PanelFrame_B", Vector3.new(xa + 1.0, YD + 5.0, ZW - 0.45), Vector3.new(xb - 1.0, YD + 5.5, ZW), L.dark)
		box(m, "Cap", Vector3.new(xa, WALL_TOP - 1.2, ZW - 1.0), Vector3.new(xb, WALL_TOP, ZW), L.trim)
	end
end
-- tunnel mouth on the hall side: concrete frame with cut top corners (matches the hub portal)
local mouth = model(bulk, "TunnelMouth")
box(mouth, "Jamb_W", Vector3.new(-18.8, YD, ZW - 1.6), Vector3.new(-17, 26, ZW), L.trim) -- only as deep as the bulkhead: no shared face with the tunnel walls
box(mouth, "Jamb_E", Vector3.new(17, YD, ZW - 1.6), Vector3.new(18.8, 26, ZW), L.trim)
box(mouth, "Lintel", Vector3.new(-17, 20, ZW - 1.6), Vector3.new(17, 26, ZW), L.trim)
box(mouth, "Upper", Vector3.new(-18.8, 26, ZW - 1.0), Vector3.new(18.8, WALL_TOP, ZW + 2), L.board)
for _, s in { -1, 1 } do
	tri(mouth, s < 0 and "Cut_W" or "Cut_E", Vector3.new(17 * s, 20, ZW - 0.8), Vector3.new(0, -1, 0), 4, Vector3.new(-s, 0, 0), 4, Vector3.zAxis, 1.6, L.trim)
end

-- 3. DECK: 12 x 12 panels on a dark under-plate, grating on a pattern, hazard kerb on the edge ---------
local deck = model(duels, "Deck")
box(deck, "UnderPlate", Vector3.new(X0, YD - 1.2, ZE), Vector3.new(X1, YD - 0.6, ZW), L.under)
local panels = model(deck, "Panels")
local PW = (X1 - X0) / 20
for i = 0, 19 do
	for j = 0, 2 do
		local x0, z0 = X0 + i * PW, ZW - j * 12
		local entry = math.abs(x0 + PW / 2) < 12
		local isGrate = (not entry) and j == 1 and (i % 2 == 0)
		box(panels, ("Panel_%d_%d"):format(i, j), Vector3.new(x0 + 0.05, YD - 0.5, z0 - 11.95), Vector3.new(x0 + PW - 0.05, YD, z0 - 0.05), isGrate and L.grate or L.diamond)
	end
end
local kerb = box(deck, "EdgeKerb", Vector3.new(X0, YD - 0.6, ZE - 1), Vector3.new(X1, YD + 0.2, ZE), L.paint)
texture(kerb, Enum.NormalId.Top, 2.4)
box(deck, "EdgeBeam", Vector3.new(X0, YD - 3.4, ZE - 1), Vector3.new(X1, YD - 0.6, ZE + 1.2), L.dark)
-- cantilever brackets under the deck edge, back to the ledge rock
for x = X0 + 6, X1 - 6, 12 do
	bar(deck, "Strut", Vector3.new(x, YD - 14, -86), Vector3.new(x, YD - 3.4, ZE + 0.4), 0.9, L.dark)
	box(deck, "Girder", Vector3.new(x - 0.5, YD - 3.4, ZE), Vector3.new(x + 0.5, YD - 1.2, -82), L.dark)
end

-- 4. TEMPORARY EDGE RAIL (removed when the cages are built) and permanent end rails ---------------------
local function rail(parent, xa, xb)
	local m = model(parent, ("Rail_%d_%d"):format(xa, xb))
	local z = ZE + 0.6
	box(m, "TopRail", Vector3.new(xa + 0.1, YD + 3.2, z - 0.25), Vector3.new(xb - 0.1, YD + 3.6, z + 0.25), L.steel) -- ends inside the end posts
	box(m, "MidRail", Vector3.new(xa + 0.1, YD + 1.6, z - 0.15), Vector3.new(xb - 0.1, YD + 1.9, z + 0.15), L.steel)
	box(m, "ToeBoard", Vector3.new(xa + 0.1, YD + 0.2, z - 0.1), Vector3.new(xb - 0.1, YD + 0.6, z + 0.1), L.paint)
	for x = xa, xb, math.max(2, (xb - xa) / math.max(1, math.floor((xb - xa) / 4))) do
		local px = math.clamp(x, xa + 0.3, xb - 0.3)
		box(m, "Post", Vector3.new(px - 0.3, YD + 0.2, z - 0.3), Vector3.new(px + 0.3, YD + 3.2, z + 0.3), L.dark)
		tri(m, "PostCap", Vector3.new(px, YD + 3.6, z), Vector3.new(0, 1, 0), 0.4, Vector3.new(0, 0, 1), 0.3, Vector3.xAxis, 0.6, L.dark)
	end
end
local temp = model(duels, "TEMP_EdgeRail")
rail(temp, colX[1] + 1, colX[#colX] - 1)
-- end landings: a concrete parapet on the deck edge that runs into the rock (no rail stubs in the rock)
local ends = model(duels, "EndParapets")
for _, s in { -1, 1 } do
	local xa, xb = s < 0 and X0 or colX[#colX] + 1, s < 0 and colX[1] - 1 or X1
	local m = model(ends, s < 0 and "Parapet_W" or "Parapet_E")
	box(m, "Wall", Vector3.new(xa, YD - 0.8, ZE - 1.2), Vector3.new(xb, YD + 3.2, ZE + 0.2), L.trim)
	box(m, "Cap", Vector3.new(xa, YD + 3.2, ZE - 1.5), Vector3.new(xb, YD + 3.7, ZE + 0.5), L.wains)
end

-- 5. GANTRY over the chasm edge: column pairs on every bay line, runway beams, cross beams, bracing -----
local gantry = model(duels, "Gantry")
local YT = 26 -- underside of the cross beams
for _, x in colX do
	local m = model(gantry, ("Line_%d"):format(x))
	for _, z in { ZG0, ZG1 } do
		box(m, "Column" .. (z == ZG0 and "_F" or "_B"), Vector3.new(x - 1, YC - 2, z - 1), Vector3.new(x + 1, YT + 2.6, z + 1), L.dark)
		box(m, "Shoe" .. (z == ZG0 and "_F" or "_B"), Vector3.new(x - 1.6, YC - 2, z - 1.6), Vector3.new(x + 1.6, YC + 1.5, z + 1.6), L.steel)
	end
	box(m, "CrossBeam", Vector3.new(x - 0.9, YT, ZG1 - 0.9), Vector3.new(x + 0.9, YT + 2.6, ZG0 + 0.9), L.steel) -- 0.1 short of the column faces
	box(m, "CrossFlange", Vector3.new(x - 1.3, YT + 2.6, ZG1 - 1), Vector3.new(x + 1.3, YT + 3.0, ZG0 + 1), L.dark)
	-- tie under the cage floor level and X-bracing down in the chasm
	box(m, "Tie_Deck", Vector3.new(x - 0.6, YD - 4.4, ZG1 + 1), Vector3.new(x + 0.6, YD - 3.4, ZG0 - 1), L.steel)
	for _, y in { -60, -34 } do
		bar(m, "Brace", Vector3.new(x, y, ZG0 - 1), Vector3.new(x, y + 24, ZG1 + 1), 0.7, L.steel)
		bar(m, "Brace", Vector3.new(x, y + 24, ZG0 - 1), Vector3.new(x, y, ZG1 + 1), 0.7, L.steel)
	end
end
for _, z in { ZG0, ZG1 } do
	box(gantry, "Runway" .. (z == ZG0 and "_F" or "_B"), Vector3.new(colX[1] - 0.9, YT + 0.1, z - 0.9), Vector3.new(colX[#colX] + 0.9, YT + 2.6, z + 0.9), L.steel)
	box(gantry, "RunwayFlange" .. (z == ZG0 and "_F" or "_B"), Vector3.new(colX[1] - 1, YT + 2.6, z - 1.3), Vector3.new(colX[#colX] + 1, YT + 3.0, z + 1.3), L.dark)
end
-- bay markers (empty anchors the cage build will use)
local anchors = folder(duels, "BayAnchors")
for i, b in BAYS do
	local p = part(anchors, ("Bay_%02d_%s"):format(i, b[1]), Vector3.new(b[3] - b[2], 1, ZG0 - ZG1 - 2), CFrame.new(O + Vector3.new((b[2] + b[3]) / 2, YD + 0.5, (ZG0 + ZG1) / 2)), look(nil, Color3.new(0, 1, 0)))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p:SetAttribute("Mode", b[1])
end

-- 6. ROCK SHELL: east / west walls, far wall, ledge under the deck, chasm floor, ceiling --------------
local rockF = folder(duels, "Rock")
local TPL = { "V5_RockWall_A", "V5_RockWall_B", "V5_RockWall_C" }
local ROWS = { { YC - 10, 58 }, { YC + 46, 48 }, { YC + 92, YCEIL - (YC + 92) + 2 } } -- bottom y, height; the bottom row sinks 10 below the chasm floor (no gap)
local k = 0
for _, side in { { -1, "W" }, { 1, "E" } } do
	local n = Vector3.new(-side[1], 0, 0)
	for c = 0, 3 do
		local z = -58 - 11.5 - c * 23
		for r, row in ROWS do
			k += 1
			rockWall(rockF, ("Wall_%s_%d_%d"):format(side[2], c, r), TPL[k % 3 + 1], Vector3.new(side[1] * X1, row[1], z), n, 25.5, row[2], k % 2 == 0)
		end
	end
	-- corner rock where the bulkhead ends (+/-100 to the side wall), floor to ceiling
	k += 1
	rockWall(rockF, "Corner_" .. side[2], TPL[k % 3 + 1], Vector3.new(side[1] * 112.25, YD, ZW + 2), -Vector3.zAxis, 23.5, YCEIL - YD + 2, k % 2 == 0)
end
local SPAN = (X1 - X0) / 9
for c = 0, 8 do
	local x = X0 + SPAN * (c + 0.5)
	for r, row in ROWS do
		k += 1
		rockWall(rockF, ("Wall_N_%d_%d"):format(c, r), TPL[k % 3 + 1], Vector3.new(x, row[1], ZF), Vector3.zAxis, SPAN + 2.5, row[2], k % 2 == 1)
	end
	for r, row in { { YC - 10, 58 }, { YC + 46, (YD - 1.4) - (YC + 46) } } do
		k += 1
		rockWall(rockF, ("Ledge_%d_%d"):format(c, r), TPL[k % 3 + 1], Vector3.new(x, row[1], -84), -Vector3.zAxis, SPAN + 2.5, row[2], k % 2 == 0, 0.8)
	end
end
for c = 0, 7 do
	k += 1
	rockWall(rockF, ("Above_Bulkhead_%d"):format(c), TPL[k % 3 + 1], Vector3.new(-100 + 12.5 + c * 25, WALL_TOP - 1, ZW + 2), -Vector3.zAxis, 27.5, YCEIL - WALL_TOP + 3, k % 2 == 0, 0.8)
end
local FW = (X1 - X0) / 6
for c = 0, 5 do -- chasm floor runs under the ledge so nothing shows between floor and walls
	for r, zr in { { -82, -118 }, { -116, -153 } } do
		rockFlat(rockF, ("ChasmFloor_%d_%d"):format(c, r), X0 + FW * (c + 0.5), (zr[1] + zr[2]) / 2, FW + 2, math.abs(zr[2] - zr[1]) + 2, YC - 6, false, (c + r) % 2 == 0)
	end
end
-- ceiling, leaving the skylight crack over the chasm (x -36..36, z -118..-138)
local CEIL = {
	{ -60, -90, { { X0, X1 } } },
	{ -90, -118, { { X0, X1 } } },
	{ -118, -138, { { X0, -36 }, { 36, X1 } } },
	{ -138, ZF, { { X0, X1 } } },
}
for ri, row in CEIL do
	for _, span in row[3] do
		local w = span[2] - span[1]
		local nPieces = math.max(1, math.floor(w / 44 + 0.5))
		local pw = w / nPieces
		for i = 0, nPieces - 1 do
			rockFlat(rockF, ("Ceil_%d_%d"):format(ri, i), span[1] + pw * (i + 0.5), (row[1] + row[2]) / 2, pw + 3, math.abs(row[2] - row[1]) + 3, YCEIL, true, (ri + i) % 2 == 0)
		end
	end
end
-- the crack's chimney (jagged top, open to the sky)
local CH = { { "N", Vector3.new(0, 0, -141), Vector3.zAxis, 76 }, { "S", Vector3.new(0, 0, -115), -Vector3.zAxis, 76 }, { "W", Vector3.new(-39, 0, -128), Vector3.xAxis, 28 }, { "E", Vector3.new(39, 0, -128), -Vector3.xAxis, 28 } }
for _, c in CH do
	local nP = math.max(1, math.floor(c[4] / 26 + 0.5))
	local tv = UP:Cross(c[3])
	for i = 0, nP - 1 do
		local along = -c[4] / 2 + c[4] / nP * (i + 0.5)
		rockWall(rockF, ("Crack_%s_%d"):format(c[1], i), (i % 2 == 0) and "V5_RockChimney_A" or "V5_RockChimney_B", c[2] + tv * along + Vector3.new(0, 58, 0), c[3], c[4] / nP + 3, 26, false, 0.6) -- short, so the afternoon sun reaches down
	end
end

-- 7. LIGHTS (fixtures on the gantry and the bulkhead; chasm glow from below) --------------------------
local lights = folder(duels, "Lights")
-- (bay lighting comes from the lightbox signs built with the queue bays)
for _, x in PIL do -- wall lamps on every pilaster head, lighting the deck
	local m = model(lights, ("WallLamp_%d"):format(x))
	local F = CFrame.lookAt(O + Vector3.new(x, WALL_TOP - 3, ZW - 2.6), O + Vector3.new(x, YD, ZW - 18))
	part(m, "Bracket", Vector3.new(0.5, 0.5, 1.4), CFrame.new(O + Vector3.new(x, WALL_TOP - 2.6, ZW - 1.9 - 0.5)), L.steel)
	part(m, "Housing", Vector3.new(2.2, 1.2, 1.0), F, L.dark)
	part(m, "Visor", Vector3.new(2.5, 0.14, 0.8), F * CFrame.new(0, 0.66, -0.55), L.steel)
	local ln = part(m, "Lens", Vector3.new(1.8, 0.8, 0.06), F * CFrame.new(0, 0, -0.53), L.lens)
	light(ln, "SpotLight", Enum.NormalId.Front, WARM, 3, 44, 75)
end
-- grazing lamps on the far and side rock (same fixture as the hub), placed by raycast onto the rock
local lampParams = RaycastParams.new()
lampParams.FilterType = Enum.RaycastFilterType.Include
lampParams.FilterDescendantsInstances = { rockF }
local function rockLamp(name, P, n, target, bright, range)
	local m = model(lights, name)
	local plateCF = CFrame.lookAt(P - n * 0.25, P - n * 0.25 + n)
	part(m, "MountPlate", Vector3.new(2.4, 2.0, 1.2), plateCF, L.dark)
	for _, s in { -1, 1 } do
		part(m, "Bolt", Vector3.new(0.3, 0.3, 0.2), plateCF * CFrame.new(s * 0.85, 0.65, -0.65), L.steel)
	end
	local H = P + n * 2.0 + Vector3.new(0, -0.3, 0)
	local F = CFrame.lookAt(H, target, n)
	part(m, "Housing", Vector3.new(2.2, 1.3, 1.1), F, L.dark)
	part(m, "Visor", Vector3.new(2.5, 0.14, 0.8), F * CFrame.new(0, 0.72, -0.6) * CFrame.Angles(math.rad(12), 0, 0), L.steel)
	for _, b in { { "Bezel_T", Vector3.new(2.2, 0.2, 0.22), CFrame.new(0, 0.55, -0.66) }, { "Bezel_B", Vector3.new(2.2, 0.2, 0.22), CFrame.new(0, -0.55, -0.66) }, { "Bezel_L", Vector3.new(0.2, 0.9, 0.22), CFrame.new(-1, 0, -0.66) }, { "Bezel_R", Vector3.new(0.2, 0.9, 0.22), CFrame.new(1, 0, -0.66) } } do
		part(m, b[1], b[2], F * b[3], L.steel)
	end
	local lens = part(m, "Lens", Vector3.new(1.8, 0.9, 0.06), F * CFrame.new(0, 0, -0.59), L.lens)
	light(lens, "SpotLight", Enum.NormalId.Front, WARM, bright, range, 60)
	local A, B = P + n * 0.35, H - F.LookVector * 0.4
	part(m, "Arm", Vector3.new(0.45, 0.45, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B), L.steel)
end
for x = -96, 96, 24 do
	local h = workspace:Raycast(O + Vector3.new(x, 20, -120), Vector3.new(0, 0, -60), lampParams)
	if h then
		rockLamp(("RockLamp_Far_%d"):format(x), h.Position, Vector3.zAxis, O + Vector3.new(x, -50, -146), 3, 80)
	end
end
for _, sx in { -1, 1 } do
	for _, z in { -78, -125 } do
		local h = workspace:Raycast(O + Vector3.new(sx * 95, 22, z), Vector3.new(sx * 40, 0, 0), lampParams)
		if h then
			rockLamp(("RockLamp_Side_%s_%d"):format(sx < 0 and "W" or "E", z), h.Position, Vector3.new(-sx, 0, 0), O + Vector3.new(sx * 118, -30, z), 3, 70)
		end
	end
end
-- uplights on the gantry beams wash the rock ceiling
for _, x in { -78, -26, 26, 78 } do -- on cross beams (column lines)
	local m = model(lights, ("Uplight_%d"):format(x))
	local base = O + Vector3.new(x, 29.0, -111)
	part(m, "Housing", Vector3.new(1.8, 0.8, 1.8), CFrame.new(base + Vector3.new(0, 0.4, 0)), L.dark)
	local ln = part(m, "Lens", Vector3.new(1.4, 0.06, 1.4), CFrame.new(base + Vector3.new(0, 0.83, 0)), L.lens)
	light(ln, "SpotLight", Enum.NormalId.Top, WARM, 2.5, 45, 100)
end
-- warm fill over the deck (no shadows)
for x = -100, 100, 40 do
	local p = part(lights, "Fill", Vector3.new(0.5, 0.5, 0.5), CFrame.new(O + Vector3.new(x, 18, -78)), look(nil, Color3.new(1, 1, 1)))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	light(p, "PointLight", nil, WARM, 0.9, 45, nil, false)
end
for x = -60, 60, 30 do -- glow from far below, up the far wall
	source(lights, "ChasmGlow", Vector3.new(x, YC + 6, -130), Vector3.new(x, -20, ZF + 4), WARM, 3, 80, 70)
end

local n = 0
for _, d in duels:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("duels hall built: %d pieces, %d rock meshes, %d bays, column lines %s"):format(n, nRock, #BAYS, table.concat(colX, ","))
