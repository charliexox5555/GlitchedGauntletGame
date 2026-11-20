--!nocheck
-- Lobby V5 hub dressing (vault/02 Art/Lobby V5 Plan.md, "Hub dressing"). ONE-TIME placement record, run through the
-- Studio MCP after BuildHub.luau. Rebuilds Workspace.LobbyV5.Shell.Hub.Dressing and Hub.SeasonMounts only, and swaps
-- the temporary invisible lights it replaces for real fixtures. Every fixture is its own Model of separate Parts.
-- Rock-mounted pieces are placed by raycast onto the real rock surface, so nothing floats or sinks.
-- Rules: gauntlet-build-style (fixtures built the way they are made, no blunt ends, pipes enter the rock through a
-- flange, a real light beside every lens, hazard yellow is the hub's one accent).

local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local MS = game:GetService("MaterialService")

local O = Vector3.new(0, 0, -1600)
local UP = Vector3.yAxis
local R = 50
local SIDE = 2 * R * math.tan(math.rad(22.5))
local hub = workspace.LobbyV5.Shell.Hub
local kit = SS.V5Kit

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
	steel = look("Metal 2022", Color3.fromRGB(104, 106, 110)),
	dark = look("Metal 2022", Color3.fromRGB(52, 54, 58)),
	char = look(nil, Color3.fromRGB(40, 41, 44), Enum.Material.Metal),
	trim = look("Concrete-02a", Color3.fromRGB(128, 126, 123)),
	grate = look("Bunker_Grate", Color3.fromRGB(70, 72, 76)),
	lens = look(nil, Color3.fromRGB(176, 150, 118), Enum.Material.Neon),
	white = look(nil, Color3.fromRGB(126, 120, 112), Enum.Material.Neon),
	accent = look(nil, Color3.fromRGB(200, 156, 36), Enum.Material.Neon),
	paint = look(nil, Color3.fromRGB(196, 152, 34), Enum.Material.SmoothPlastic),
	red = look(nil, Color3.fromRGB(170, 44, 32), Enum.Material.Neon),
	glass = look(nil, Color3.fromRGB(160, 170, 175), Enum.Material.Glass),
	cable = look(nil, Color3.fromRGB(26, 26, 28), Enum.Material.SmoothPlastic),
	panel = look(nil, Color3.fromRGB(150, 148, 144), Enum.Material.SmoothPlastic),
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
	if lk.mat == Enum.Material.Glass then
		p.Transparency = 0.55
	end
	p.Parent = parent
	return p
end
local function box(parent, name, a, b, lk)
	local lo, hi = a:Min(b), a:Max(b)
	return part(parent, name, hi - lo, CFrame.new(O + (lo + hi) / 2), lk)
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
-- right-triangle wedge in a local frame: right angle at local point p, legs along local u (a) and v (b), thickness along w
local function wedgeIn(parent, name, F, p, u, a, v, b, w, th, lk)
	local X = w.Unit
	local Y = u.Unit
	local Z = X:Cross(Y)
	if Z:Dot(-v.Unit) < 0 then
		X = -X
	end
	local c = p + u.Unit * a / 2 + v.Unit * b / 2
	local cf = F * CFrame.fromMatrix(c, X, Y)
	return part(parent, name, Vector3.new(th, a, b), cf, lk, "WedgePart")
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
	return l
end
local function mesh(parent, name, tpl, size, cf, lk)
	local m = kit[tpl]:Clone()
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
local function sideFrame(k)
	local th = math.rad(k * 45)
	local d = Vector3.new(math.sin(th), 0, -math.cos(th))
	return d, Vector3.new(math.cos(th), 0, math.sin(th))
end
local SIDE_NAMES = { [0] = "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

local rockParams = RaycastParams.new()
rockParams.FilterType = Enum.RaycastFilterType.Include
rockParams.FilterDescendantsInstances = { hub.Rock }
local solidParams = RaycastParams.new()
solidParams.FilterType = Enum.RaycastFilterType.Include
solidParams.FilterDescendantsInstances = { hub.Rock, hub.Portal_Duels, hub.Shop, hub.Armoury, hub.RangeDoor }
-- radial distance of the rock face from the hub centre along side direction d, at a point
local function rockAt(from, dir, params)
	local hit = workspace:Raycast(from, dir * 60, params or rockParams)
	return hit
end

---------------------------------------------------------------------------------------------------
local old = hub:FindFirstChild("Dressing")
if old then
	old:Destroy()
end
local oldM = hub:FindFirstChild("SeasonMounts")
if oldM then
	oldM:Destroy()
end
local dress = model(hub, "Dressing")
local mounts = Instance.new("Folder")
mounts.Name = "SeasonMounts"
mounts.Parent = hub
local function mount(name, slot, size, cf)
	local p = part(mounts, name, size, cf, look(nil, Color3.new(0, 1, 0)))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p:SetAttribute("Slot", slot)
	CS:AddTag(p, "SeasonMount")
	return p
end
local function accent(p)
	CS:AddTag(p, "SeasonAccent")
	return p
end

-- 1. WALL LAMPS on the rock (replace the invisible Graze_* lights) ---------------------------------------
-- built the way a floodlight is made: mount plate bolted into the rock -> arm -> housing -> bezel -> lens set back
local lamps = model(dress, "WallLamps")
local nLamp = 0
local function wallLamp(name, P, n, target)
	local m = model(lamps, name)
	local plateCF = CFrame.lookAt(P - n * 0.25, P - n * 0.25 + n)
	part(m, "MountPlate", Vector3.new(2.4, 2.0, 1.2), plateCF, L.dark)
	for _, s in { -1, 1 } do
		part(m, "Bolt", Vector3.new(0.3, 0.3, 0.2), plateCF * CFrame.new(s * 0.85, 0.65, -0.65), L.steel)
	end
	local H = P + n * 2.0 + Vector3.new(0, -0.3, 0)
	local F = CFrame.lookAt(H, target, n) -- housing "top" faces away from the rock
	part(m, "Housing", Vector3.new(2.2, 1.3, 1.1), F, L.dark)
	part(m, "Visor", Vector3.new(2.5, 0.14, 0.8), F * CFrame.new(0, 0.72, -0.6) * CFrame.Angles(math.rad(12), 0, 0), L.steel)
	part(m, "Bezel_T", Vector3.new(2.2, 0.2, 0.22), F * CFrame.new(0, 0.55, -0.66), L.steel)
	part(m, "Bezel_B", Vector3.new(2.2, 0.2, 0.22), F * CFrame.new(0, -0.55, -0.66), L.steel)
	part(m, "Bezel_L", Vector3.new(0.2, 0.9, 0.22), F * CFrame.new(-1.0, 0, -0.66), L.steel)
	part(m, "Bezel_R", Vector3.new(0.2, 0.9, 0.22), F * CFrame.new(1.0, 0, -0.66), L.steel)
	local lens = part(m, "Lens", Vector3.new(1.8, 0.9, 0.06), F * CFrame.new(0, 0, -0.59), L.lens)
	light(lens, "SpotLight", Enum.NormalId.Front, WARM, 2.5, 64, 60)
	-- arm from the plate to the back of the housing
	local A = P + n * 0.35
	local B = H - F.LookVector * 0.4
	part(m, "Arm", Vector3.new(0.45, 0.45, (B - A).Magnitude), CFrame.lookAt((A + B) / 2, B), L.steel)
	nLamp += 1
end
for k = 0, 7 do
	local d, tv = sideFrame(k)
	for i, s in { -1, 1 } do
		local along = s * SIDE / 4
		local from = O + d * (R - 16) + tv * along + Vector3.new(0, 40, 0)
		local hit = rockAt(from, d)
		if hit then
			wallLamp(("Lamp_%s_%d"):format(SIDE_NAMES[k], i), hit.Position, -d, O + d * (R - 4) + tv * along + Vector3.new(0, 4, 0))
		end
	end
end
for _, l in hub.Lights:GetChildren() do
	if l.Name:match("^Graze_") then
		l:Destroy()
	end
end

-- 2. PIPES AND CABLE TRAYS along the four diagonal walls ----------------------------------------------
-- Each run stays inside its own wall section (NE / NW stop before the portal buttresses), sits just in front
-- of the most protruding rock, and turns 90 degrees back into the rock at both ends: elbow collar + wall
-- flange for pipes, a closed end plate + conduit for the cable tray. Brackets every 8 studs reach the rock.
local pipes = model(dress, "Pipes")
local pipeParams = RaycastParams.new()
pipeParams.FilterType = Enum.RaycastFilterType.Include
pipeParams.FilterDescendantsInstances = { hub.Rock, hub.Portal_Duels }
local EXT = { [1] = { SIDE / 2 - 12, SIDE / 2 - 2.5 }, [3] = { SIDE / 2 - 2.5, SIDE / 2 - 2.5 }, [5] = { SIDE / 2 - 2.5, SIDE / 2 - 2.5 }, [7] = { SIDE / 2 - 2.5, SIDE / 2 - 12 } }
local function run(k)
	local d, tv = sideFrame(k)
	local m = model(pipes, "Run_" .. SIDE_NAMES[k])
	for _, sp in { { y = 32.6, r = 0.9, lk = L.steel, nm = "PipeA", off = 0 }, { y = 31.2, r = 0.7, lk = L.dark, nm = "PipeB", off = 1.4 }, { y = 29.4, tray = true, nm = "Tray", off = 2.8 } } do
		local a, b = -(EXT[k][1] - sp.off), EXT[k][2] - sp.off -- staggered so the turns do not collide
		local minR = math.huge
		for s = a, b, 1.5 do
			for dy = -0.6, 0.6, 0.6 do
				local h = workspace:Raycast(O + d * (R - 26) + tv * s + Vector3.new(0, sp.y + dy, 0), d * 60, pipeParams)
				if h then
					minR = math.min(minR, (h.Position - O):Dot(d))
				end
			end
		end
		local half = (sp.r or 1.6) / 2
		local c = O + d * (minR - half - 0.35) + Vector3.new(0, sp.y, 0)
		local F = CFrame.fromMatrix(c + tv * (a + b) / 2, tv, UP)
		local len = b - a
		if sp.tray then
			part(m, "Tray_Base", Vector3.new(len, 0.15, 1.6), F, L.dark)
			part(m, "Tray_LipIn", Vector3.new(len, 0.55, 0.12), F * CFrame.new(0, 0.27, 0.77), L.dark)
			part(m, "Tray_LipOut", Vector3.new(len, 0.55, 0.12), F * CFrame.new(0, 0.27, -0.77), L.dark)
			part(m, "Cables", Vector3.new(len - 0.4, 0.32, 1.1), F * CFrame.new(0, 0.24, 0), L.cable)
			for _, e in { a, b } do
				local s = math.sign(e)
				part(m, "Tray_EndPlate", Vector3.new(0.15, 0.7, 1.6), CFrame.fromMatrix(c + tv * (e - s * 0.075) + Vector3.new(0, 0.27, 0), tv, UP), L.dark)
				local pe = c + tv * (e - s * 0.9) + Vector3.new(0, 0.24, 0)
				local h = workspace:Raycast(pe, d * 60, pipeParams)
				local depth = h and ((h.Position - pe):Dot(d) + 0.6) or 2
				part(m, "Conduit", Vector3.new(0.7, 0.5, depth), CFrame.lookAt(pe + d * (depth / 2), pe + d * depth), L.steel)
			end
		else
			mesh(m, sp.nm, "V5_Pipe8", Vector3.new(len, sp.r, sp.r), F, sp.lk)
			for _, e in { a, b } do
				local pe = c + tv * e
				local h = workspace:Raycast(pe, d * 60, pipeParams)
				local depth = h and ((h.Position - pe):Dot(d) + 0.7) or 2
				mesh(m, sp.nm .. "_Turn", "V5_Pipe8", Vector3.new(depth, sp.r, sp.r), CFrame.fromMatrix(pe + d * (depth / 2), d, UP), sp.lk)
				mesh(m, sp.nm .. "_Elbow", "V5_Flange8", Vector3.new(sp.r * 1.3, sp.r * 1.3, sp.r * 1.3), CFrame.fromMatrix(pe, tv, UP), L.steel)
				if h then
					mesh(m, sp.nm .. "_WallFlange", "V5_Flange8", Vector3.new(0.45, sp.r * 1.5, sp.r * 1.5), CFrame.fromMatrix(h.Position - d * 0.1, d, UP), L.steel)
				end
			end
		end
		for s = a + 4, b - 4, 8 do
			local p0 = c + tv * s
			local h = workspace:Raycast(p0, d * 60, pipeParams)
			if h then
				local back = (h.Position - p0):Dot(d) + 0.4
				if back > half + 0.1 then
					local bc = p0 + d * (half + (back - half) / 2)
					part(m, "Bracket", Vector3.new(0.35, 0.35, back - half), CFrame.lookAt(bc, bc + d), L.steel)
					if not sp.tray then
						mesh(m, "Clamp", "V5_Flange8", Vector3.new(0.3, sp.r * 1.25, sp.r * 1.25), CFrame.fromMatrix(p0, tv, UP), L.steel)
					end
				end
			end
		end
	end
end
for _, k in { 1, 3, 5, 7 } do
	run(k)
end

-- 3. SIGNS (cut-corner steel plates, SurfaceGui letters, accent bar) ----------------------------------
local signs = model(dress, "Signs")
local function sign(name, cf, w, h, text)
	local m = model(signs, name)
	local c = 0.6
	local main = part(m, "Plate", Vector3.new(w, h - 2 * c, 0.4), cf, L.char)
	part(m, "Plate_T", Vector3.new(w - 2 * c, c, 0.4), cf * CFrame.new(0, h / 2 - c / 2, 0), L.char)
	part(m, "Plate_B", Vector3.new(w - 2 * c, c, 0.4), cf * CFrame.new(0, -h / 2 + c / 2, 0), L.char)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			-- corner triangle: right angle at the inner corner, legs out to the plate edge
			wedgeIn(m, "Corner", cf, Vector3.new(sx * (w / 2 - c), sy * (h / 2 - c), 0), Vector3.new(0, sy, 0), c, Vector3.new(sx, 0, 0), c, Vector3.zAxis, 0.4, L.char)
		end
	end
	local face = part(m, "Face", Vector3.new(w - 1.0, h - 1.0, 0.06), cf * CFrame.new(0, 0, -0.22), L.dark)
	accent(part(m, "AccentBar", Vector3.new(w * 0.42, 0.2, 0.06), cf * CFrame.new(0, -h / 2 + 0.75, -0.27), L.accent))
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 22 -- TextScaled caps at 100 px: low density keeps letters big
	g.LightInfluence = 0.35
	g.Parent = face
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.92, 0.62)
	t.Position = UDim2.fromScale(0.04, 0.08)
	t.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik Heavy, the game font
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(238, 236, 230)
	t.Text = text
	t.Parent = g
	return m
end
sign("Sign_Duels", CFrame.lookAt(O + Vector3.new(0, 23, -41.8), O + Vector3.new(0, 23, -30)), 20, 4.4, "DUELS")
sign("Sign_Locker", CFrame.lookAt(O + Vector3.new(39.8, 17.5, 0), O + Vector3.new(20, 17.5, 0)), 14, 3.8, "LOCKER")
sign("Sign_Range", CFrame.lookAt(O + Vector3.new(0, 15, 41.8), O + Vector3.new(0, 15, 20)), 12, 3.8, "RANGE")
local shopSign = sign("Sign_Shop", CFrame.lookAt(O + Vector3.new(-37.6, 21.6, 0), O + Vector3.new(-20, 21.6, 0)), 14, 4.2, "SHOP")
for _, z in { -5, 5 } do -- raised on feet so the leaning canopy front does not hide the letters
	box(shopSign, "Foot", Vector3.new(-38.2, 18.5, z - 0.4), Vector3.new(-37.0, 19.6, z + 0.4), L.dark)
end

-- 4. SEASON SCREENS on the NE / NW rock (SurfaceGui; the season pack swaps the art) ---------------------
local screens = model(dress, "Screens")
-- one above the duels portal (the first thing seen from the spawn) and one above the range door; the NE / NW
-- spots were hidden behind the lift towers from the spawn
local function screen(k, W, H, Y)
	local d, tv = sideFrame(k)
	local m = model(screens, "Screen_" .. SIDE_NAMES[k])
	local minR = math.huge
	for u = -W / 2, W / 2, W / 4 do
		for v = -H / 2, H / 2, H / 4 do
			local h = rockAt(O + d * (R - 25) + tv * u + Vector3.new(0, Y + v, 0), d)
			if h then
				minR = math.min(minR, (h.Position - O):Dot(d))
			end
		end
	end
	local rb = minR - 0.6 -- back of the case
	local c = O + d * (rb - 0.35) + Vector3.new(0, Y, 0)
	local cf = CFrame.lookAt(c, c - d)
	part(m, "Case", Vector3.new(W + 0.6, H + 0.6, 0.7), cf, L.char)
	local face = part(m, "Display", Vector3.new(W, H, 0.06), cf * CFrame.new(0, 0, -0.38), look(nil, Color3.fromRGB(10, 10, 12)))
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = 0
	g.Brightness = 1.2
	g.Parent = face
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	bg.BorderSizePixel = 0
	bg.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(46, 44, 42), Color3.fromRGB(16, 16, 18))
	grad.Parent = bg
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.8, 0.3)
	t.Position = UDim2.fromScale(0.1, 0.28)
	t.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik Heavy, the game font
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(240, 236, 228)
	t.Text = "SEASON 1"
	t.Parent = bg
	local s2 = t:Clone()
	s2.Size = UDim2.fromScale(0.6, 0.12)
	s2.Position = UDim2.fromScale(0.2, 0.62)
	s2.TextColor3 = Color3.fromRGB(214, 170, 60)
	s2.Text = "THE DEEP"
	s2.Parent = bg
	face:SetAttribute("Slot", "Screen")
	CS:AddTag(face, "SeasonMount")
	-- wall arm back to the rock
	local hit = rockAt(c, d)
	if hit then
		local back = (hit.Position - c):Dot(d) + 0.5
		local bc = c + d * (0.35 + (back - 0.35) / 2)
		part(m, "WallArm", Vector3.new(4, 1.4, math.max(0.3, back - 0.35)), CFrame.lookAt(bc, bc + d), L.dark)
	end
	local sl = part(m, "Glow", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 0, -2), L.lens)
	sl.Transparency = 1
	sl.CanCollide = false
	light(sl, "PointLight", nil, Color3.fromRGB(200, 196, 190), 0.6, 10, nil, false)
end
screen(0, 16, 9, 35)
screen(4, 14, 7.9, 29)

-- 5. SHOP FRONT: leaning canopy fascia, light bar, kick strip, display case ---------------------------
local shopD = model(dress, "ShopFront")
local SX = -40
-- canopy front leans out at the top
wedgeIn(shopD, "CanopyFascia", CFrame.new(O), Vector3.new(SX + 4, 18.5, 0), Vector3.new(0, -1, 0), 2.5, Vector3.new(1, 0, 0), 1.4, Vector3.zAxis, 32, look("Concrete-02a", Color3.fromRGB(128, 126, 123)))
local barH = box(shopD, "LightBar_Housing", Vector3.new(SX + 2.0, 15.4, -14), Vector3.new(SX + 3.2, 16, 14), L.dark)
local barL = box(shopD, "LightBar_Lens", Vector3.new(SX + 2.2, 15.32, -13.6), Vector3.new(SX + 3.0, 15.4, 13.6), L.white)
light(barL, "SpotLight", Enum.NormalId.Bottom, WHITE, 2.5, 24, 120)
local kick = box(shopD, "KickStrip", Vector3.new(SX, 0, -16), Vector3.new(SX + 0.12, 1.1, 16), L.paint)
local tx = Instance.new("Texture")
tx.Face = Enum.NormalId.Right
tx.Texture = HAZARD
tx.StudsPerTileU = 2.2
tx.StudsPerTileV = 2.2
tx.Parent = kick
box(shopD, "CounterLip", Vector3.new(SX + 1.5, 4.2, -12), Vector3.new(SX + 1.8, 5.1, 6), L.dark)
-- display case on the south pier (ShopWindow season mount inside)
local dc = model(shopD, "DisplayCase")
local DZ0, DZ1, DY0, DY1 = 8, 14.5, 4.5, 11.5
box(dc, "Sill", Vector3.new(SX, DY0 - 0.5, DZ0 - 0.4), Vector3.new(SX + 1.8, DY0, DZ1 + 0.4), L.steel)
box(dc, "Head", Vector3.new(SX, DY1, DZ0 - 0.4), Vector3.new(SX + 1.8, DY1 + 0.5, DZ1 + 0.4), L.steel)
box(dc, "Post_N", Vector3.new(SX, DY0, DZ0 - 0.4), Vector3.new(SX + 1.8, DY1, DZ0), L.steel)
box(dc, "Post_S", Vector3.new(SX, DY0, DZ1), Vector3.new(SX + 1.8, DY1, DZ1 + 0.4), L.steel)
box(dc, "BackPanel", Vector3.new(SX, DY0, DZ0), Vector3.new(SX + 0.1, DY1, DZ1), L.panel)
box(dc, "Shelf", Vector3.new(SX + 0.1, (DY0 + DY1) / 2 - 0.08, DZ0), Vector3.new(SX + 1.4, (DY0 + DY1) / 2 + 0.08, DZ1), L.steel)
box(dc, "Glass", Vector3.new(SX + 1.55, DY0, DZ0), Vector3.new(SX + 1.65, DY1, DZ1), L.glass)
local dl = box(dc, "CaseLight", Vector3.new(SX + 0.3, DY1 - 0.12, DZ0 + 0.4), Vector3.new(SX + 1.2, DY1, DZ1 - 0.4), L.white)
light(dl, "SpotLight", Enum.NormalId.Bottom, WHITE, 1.2, 9, 120, false)
mount("ShopWindow", "ShopWindow", Vector3.new(1.2, DY1 - DY0 - 0.4, DZ1 - DZ0 - 0.4), CFrame.new(O + Vector3.new(SX + 0.8, (DY0 + DY1) / 2, (DZ0 + DZ1) / 2)))
for _, n in { "ShopCanopy" } do
	local l = hub.Lights:FindFirstChild(n)
	if l then
		l:Destroy()
	end
end

-- 6. LIFT: corner status lamps, deck downlights under the crossbeam, beacons, control console ----------
local liftD = model(dress, "LiftDetails")
-- beside the east and west deck edges (the diagonal corners are taken by the tower plinths)
for _, c in { Vector3.new(-21.6, 0, -6), Vector3.new(21.6, 0, -6), Vector3.new(-21.6, 0, 6), Vector3.new(21.6, 0, 6) } do
	local dirOut = Vector3.new(math.sign(c.X), 0, 0)
	local F = CFrame.lookAt(O + c + Vector3.new(0, 0.3, 0), O + c + Vector3.new(0, 0.3, 0) + dirOut)
	local m = model(liftD, "StatusLamp")
	part(m, "Base", Vector3.new(1.8, 0.6, 1.2), F, L.dark)
	-- sloped roof on the base, falling toward the lens
	wedgeIn(m, "Roof", F, Vector3.new(0, 0.3, 0.6), Vector3.new(0, 1, 0), 0.4, Vector3.new(0, 0, -1), 1.2, Vector3.xAxis, 1.8, L.steel)
	local ln = accent(part(m, "Lens", Vector3.new(1.2, 0.26, 0.06), F * CFrame.new(0, 0, -0.63), L.accent))
	light(ln, "PointLight", nil, Color3.fromRGB(255, 200, 90), 0.8, 7, nil, false)
end
for _, x in { -8, 8 } do
	local m = model(liftD, "Downlight")
	local TZ = -17
	for _, dz in { -0.7, 0.7 } do
		box(m, "Hanger", Vector3.new(x - 0.15, 52.8, TZ + dz - 0.15), Vector3.new(x + 0.15, 54.5, TZ + dz + 0.15), L.steel)
	end
	box(m, "Housing", Vector3.new(x - 1.3, 51.8, TZ - 1.1), Vector3.new(x + 1.3, 52.8, TZ + 1.1), L.dark)
	box(m, "Bezel", Vector3.new(x - 1.15, 51.6, TZ - 0.95), Vector3.new(x + 1.15, 51.8, TZ + 0.95), L.steel)
	local ln = box(m, "Lens", Vector3.new(x - 0.9, 51.55, TZ - 0.7), Vector3.new(x + 0.9, 51.6, TZ + 0.7), L.white)
	light(ln, "SpotLight", Enum.NormalId.Bottom, WHITE, 1.2, 70, 60)
end
for _, n in { "Lift_W", "Lift_E" } do
	local l = hub.Lights:FindFirstChild(n)
	if l then
		l:Destroy()
	end
end
for _, x in { -22.2, 22.2 } do
	local m = model(liftD, "Beacon")
	box(m, "Base", Vector3.new(x - 0.6, 117.6, -17.6), Vector3.new(x + 0.6, 118.0, -16.4), L.dark)
	local b = box(m, "Lamp", Vector3.new(x - 0.35, 118.0, -17.35), Vector3.new(x + 0.35, 118.6, -16.65), L.red)
	light(b, "PointLight", nil, Color3.fromRGB(255, 70, 50), 1.2, 12, nil, false)
end
do -- control console on the east tower plinth, facing the lift
	local m = model(liftD, "Console")
	local F = CFrame.lookAt(O + Vector3.new(25, 2.95, -15.5), O + Vector3.new(0, 2.95, -15.5))
	part(m, "Body", Vector3.new(2.6, 2.9, 1.4), F, L.dark)
	wedgeIn(m, "Desk", F, Vector3.new(0, 1.45, 0.7), Vector3.new(0, 1, 0), 0.9, Vector3.new(0, 0, -1), 1.4, Vector3.xAxis, 2.6, L.steel)
	local scr = part(m, "Screen", Vector3.new(2.0, 0.06, 1.1), F * CFrame.new(0, 1.94, 0) * CFrame.Angles(-math.atan2(0.9, 1.4), 0, 0), look(nil, Color3.fromRGB(10, 10, 12)))
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0
	g.Parent = scr
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	t.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik Heavy, the game font
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(214, 170, 60)
	t.Text = "LIFT READY"
	t.Parent = g
end

-- 7. FLOOR: painted walkway lines (hub accent), drains --------------------------------------------------
local floorD = model(dress, "FloorMarks")
local function line(name, a, b)
	box(floorD, name, a + Vector3.new(0, 0, 0), b + Vector3.new(0, 0.04, 0), L.paint)
end
for _, x in { -14, 14 } do
	line("Line_N", Vector3.new(x - 0.2, 0, -41.5), Vector3.new(x + 0.2, 0, -18))
end
for _, z in { -13.5, 7.5 } do
	line("Line_W", Vector3.new(-35, 0, z - 0.2), Vector3.new(-26.6, 0, z + 0.2)) -- stops clear of the tower plinth
end
for _, z in { -9, 9 } do
	line("Line_E", Vector3.new(21.5, 0, z - 0.2), Vector3.new(39.5, 0, z + 0.2))
end
for _, x in { -9, 9 } do
	line("Line_S", Vector3.new(x - 0.2, 0, 18), Vector3.new(x + 0.2, 0, 41.5))
end
for _, k in { 1, 3, 5, 7 } do
	local d, tv = sideFrame(k)
	local F = CFrame.fromMatrix(O + d * 37 + Vector3.new(0, 0.02, 0), tv, UP) -- clear of the tower plinths
	local g = part(floorD, "Drain", Vector3.new(4, 0.04, 2), F, L.grate)
	part(floorD, "DrainFrame", Vector3.new(4.4, 0.03, 2.4), F * CFrame.new(0, -0.005, 0), L.dark)
	g.Name = "Drain_" .. SIDE_NAMES[k]
end

-- 8. PROPS: hard-case stacks on steel pallets ------------------------------------------------------------
local props = model(dress, "Props")
local function case(parent, cf, w, h, dpt)
	local m = model(parent, "HardCase")
	part(m, "Body", Vector3.new(w, h - 0.3, dpt), cf * CFrame.new(0, -0.15, 0), L.char)
	part(m, "Lid", Vector3.new(w + 0.12, 0.3, dpt + 0.12), cf * CFrame.new(0, h / 2 - 0.15, 0), L.dark)
	for _, sx in { -1, 1 } do
		accent(part(m, "Latch", Vector3.new(0.35, 0.45, 0.1), cf * CFrame.new(sx * w * 0.3, h / 2 - 0.45, -dpt / 2 - 0.05), L.paint))
		part(m, "CornerGuard", Vector3.new(0.18, h - 0.3, 0.18), cf * CFrame.new(sx * (w / 2 + 0.02), -0.15, -dpt / 2 - 0.02), L.steel)
	end
	part(m, "Handle", Vector3.new(w * 0.35, 0.18, 0.3), cf * CFrame.new(0, h / 2 + 0.09, 0), L.steel)
end
local function stack(name, k, along)
	local d, tv = sideFrame(k)
	local h = rockAt(O + d * (R - 26) + tv * along + Vector3.new(0, 1.5, 0), d)
	local r = h and ((h.Position - O):Dot(d) - 4) or 36
	local base = O + d * r + tv * along
	local F = CFrame.fromMatrix(base, tv, UP) * CFrame.Angles(0, math.rad(8), 0)
	local m = model(props, name)
	part(m, "Pallet", Vector3.new(6, 0.25, 4), F * CFrame.new(0, 0.55, 0), L.steel)
	for _, z in { -1.6, 0, 1.6 } do
		part(m, "Runner", Vector3.new(6, 0.45, 0.5), F * CFrame.new(0, 0.22, z), L.dark)
	end
	case(m, F * CFrame.new(-1.4, 0.68 + 0.9, 0), 3, 1.8, 3.2)
	case(m, F * CFrame.new(1.6, 0.68 + 0.75, 0.2) * CFrame.Angles(0, math.rad(-6), 0), 2.6, 1.5, 3)
	case(m, F * CFrame.new(-1.2, 0.68 + 1.8 + 0.6, -0.1) * CFrame.Angles(0, math.rad(5), 0), 2.4, 1.2, 2.4)
end
stack("Stack_SE", 3, -8)
stack("Stack_SW", 5, 9)
stack("Stack_NW", 7, 6)

-- 9. SEASON MOUNTS (the LobbySeason module fills these per season) ----------------------------------
for i, x in { -15, 15 } do
	mount("Banner_" .. i, "Banner", Vector3.new(6, 12, 0.2), CFrame.lookAt(O + Vector3.new(x, 48.2, -15.6), O + Vector3.new(x, 48.2, 10)))
end
mount("Centrepiece", "Centrepiece", Vector3.new(10, 0.2, 10), CFrame.new(O + Vector3.new(0, 0.1, 30)))
mount("FloorDecal", "FloorDecal", Vector3.new(12, 0.03, 12), CFrame.new(O + Vector3.new(0, 0.05, -30)))
for i, p in { Vector3.new(-26, 0.1, 30), Vector3.new(26, 0.1, 30), Vector3.new(30, 0.1, -26) } do
	mount("Prop_" .. i, "Prop", Vector3.new(6, 0.2, 6), CFrame.new(O + p))
end

local n = 0
for _, x in dress:GetDescendants() do
	if x:IsA("BasePart") then
		n += 1
	end
end
return ("dressing: %d pieces, %d wall lamps, %d season mounts"):format(n, nLamp, #CS:GetTagged("SeasonMount"))
