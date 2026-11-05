--!strict
-- Build_Bunker2.luau: "Sunwell Bunker, redone" (vault/02 Art/Lobby Rebuild 2026-11-04.md). Lobby place, edit mode.
-- Re-runnable: rebuilds Workspace.Lobby.Hub; removes the old hub (Greybox / Art / Ambience, except RangeFar, the real
-- range). Needs the Bunker2 kit in ServerStorage.LobbyKit (KitGroup "Bunker2") and Materials_V2.luau.
-- Roblox studs, floor 0, hub centre (0, 0, 0), spawn faces north (-Z). Bearings: 0 north, 90 east (clockwise).
-- Levels: rotunda + ring 0, Duels hall -3, Market niche hall -2 then shop hall -5, Armoury +2, Range room 0.
-- Tags (World -> UI contract): LobbySpawn, LobbyQueue (+Mode, PadId), LobbyShop, LobbyBattlePass, LobbyLocker,
-- LobbyRangeEntrance. Decorative motion (AmbienceClient_V2): LobbySpin, LobbyPulse, LobbyGlitch, LobbyScroll, LobbyBob.
local CS = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
assert(game.PlaceId == 133387545285290, "Build_Bunker2: not the Lobby place")

local KIT = ServerStorage:WaitForChild("LobbyKit")
local root = workspace:WaitForChild("Lobby")

local PIECES: { [string]: Model } = {}
local OLD: { [string]: Model } = {}
for _, m in KIT:GetChildren() do
	if m:IsA("Model") then
		if m:GetAttribute("KitGroup") == "Bunker2" then
			PIECES[m.Name] = m
		elseif m:GetAttribute("KitGroup") ~= "Stylized" then -- older bunker kit (guns, trophy, scale model); never the scrapped pastel kit
			OLD[m.Name] = m
		end
	end
end

local C = {
	floor = Color3.fromHex("8C8070"),
	ring = Color3.fromHex("4E5257"),
	rotunda = Color3.fromHex("A69A88"),
	hall = Color3.fromHex("454B52"),
	walk = Color3.fromHex("33393F"),
	concrete = Color3.fromHex("A39787"),
	dark = Color3.fromHex("625C55"),
	slate = Color3.fromHex("2F4250"),
	warm = Color3.fromHex("FFB45A"),
	duels = Color3.fromHex("FF5A36"),
	market = Color3.fromHex("F2B33D"),
	armoury = Color3.fromHex("3DD9F2"),
	range = Color3.fromHex("FF4757"),
	holo = Color3.fromHex("4FC8FF"),
	magenta = Color3.fromHex("FF3DCB"),
	yellow = Color3.fromHex("F2C230"),
	purple = Color3.fromHex("9B5CFF"),
}
local MODE = { ["1v1"] = Color3.fromHex("FF7A2F"), ["2v2"] = Color3.fromHex("27B7FF"), ["3v3"] = Color3.fromHex("A15CFF") }

-- ---------------------------------------------------------------- helpers

local function Y(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end
local function at(x: number, y: number, z: number, yaw: number?): CFrame
	return CFrame.new(x, y, z) * Y(yaw or 0)
end
local function dir(b: number): Vector3
	return Vector3.new(math.sin(math.rad(b)), 0, -math.cos(math.rad(b)))
end
-- A piece on a circle around (cx, cz) at bearing b, its front (+Z) facing the centre.
local function onRing(r: number, b: number, y: number, cx: number?, cz: number?): CFrame
	local p = dir(b) * r + Vector3.new(cx or 0, y, cz or 0)
	return CFrame.new(p) * Y(-b)
end
local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function child(p: Instance, name: string): any
	local c = p:FindFirstChild(name, true)
	assert(c, p.Name .. " has no " .. name)
	return c
end
local function put(name: string, cf: CFrame, parent: Instance, scale: number?): Model
	local src = PIECES[name] or OLD[name]
	assert(src, "missing kit piece " .. name)
	local m = src:Clone()
	m:SetAttribute("KitGroup", nil)
	m:PivotTo(cf)
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	m.Parent = parent
	return m
end
local function each(m: Instance, suffix: string, fn: (BasePart) -> ())
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, -#suffix) == suffix then
			fn(d)
		end
	end
end
local function tint(m: Instance, suffix: string, color: Color3)
	each(m, suffix, function(p)
		p.Color = color
	end)
end
local function tag(i: Instance, t: string)
	CS:AddTag(i, t)
end

type Opts = { material: Enum.Material?, variant: string?, transparency: number?, collide: boolean?, query: boolean?, touch: boolean?, shape: Enum.PartType?, shadow: boolean? }
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, o: Opts?): Part
	local opts: Opts = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.MaterialVariant = opts.variant or ""
	p.Transparency = opts.transparency or 0
	p.CanCollide = if opts.collide == nil then true else opts.collide
	p.CanQuery = opts.query == true
	p.CanTouch = opts.touch == true
	if opts.shape then
		p.Shape = opts.shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = if opts.shadow == nil then (opts.transparency or 0) < 1 else opts.shadow
	p.Parent = parent
	return p
end
local function col(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	return part(parent, name, size, cf, C.slate, { transparency = 1 })
end
local function zone(parent: Instance, name: string, size: Vector3, cf: CFrame, t: string): Part
	local z = part(parent, name, size, cf, C.slate, { transparency = 1, collide = false, query = true, touch = true })
	tag(z, t)
	return z
end
local function disc(parent: Instance, name: string, r: number, top: number, x: number, z: number, color: Color3, o: Opts?): Part
	local h = 1
	return part(parent, name, Vector3.new(h, r * 2, r * 2), CFrame.new(x, top - h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, (function()
		local opts: Opts = o or {}
		opts.shape = Enum.PartType.Cylinder
		return opts
	end)())
end
-- Invisible tangent boxes along an arc (collision for round walls), skipping gaps {bearing, width}.
local function arcCol(parent: Instance, r: number, h: number, y0: number, gaps: { { number } }, cx: number?, cz: number?)
	local n = math.ceil(2 * math.pi * r / 4)
	for i = 0, n - 1 do
		local b = (i + 0.5) * 360 / n
		local skip = false
		for _, g in gaps do
			local half = math.deg(math.asin(math.min(1, g[2] / 2 / r)))
			if math.abs(((b - g[1] + 180) % 360) - 180) < half then
				skip = true
			end
		end
		if not skip then
			local chord = 2 * r * math.sin(math.rad(180 / n)) + 0.3
			col(parent, "Wall", Vector3.new(chord, h, 2), onRing(r + 1, b, y0 + h / 2, cx, cz))
		end
	end
end

local function light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end
local function lamp(parent: Instance, pos: Vector3, color: Color3, range: number, brightness: number)
	local a = part(parent, "Light", Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos), color, { transparency = 1, collide = false })
	light(a, color, range, brightness)
end
local function spin(i: Instance, speed: number, bobAmp: number?, bobSpeed: number?)
	if i:IsA("Model") and not PIECES[i.Name] then -- older kit models pivot at their grip: spin them about their centre
		local cf = i:GetBoundingBox()
		i.WorldPivot = CFrame.new(cf.Position) * i:GetPivot().Rotation
	end
	tag(i, "LobbySpin")
	i:SetAttribute("SpinSpeed", speed)
	if bobAmp then
		i:SetAttribute("BobAmp", bobAmp)
		i:SetAttribute("BobSpeed", bobSpeed or 1)
	end
end
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local function emitter(parent: Instance, tex: string, color: Color3, rate: number, speed: number, size: number, life: number, alpha: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex
	e.Color = ColorSequence.new(color)
	e.LightEmission = if tex == SPARKLE then 1 else 0.1
	e.LightInfluence = if tex == SPARKLE then 0 else 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, alpha), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(10, 10)
	e.Parent = parent
	return e
end
local function column(anchor: BasePart, color: Color3, width: number, height: number, alpha: number)
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor
	a1.WorldPosition = anchor.Position + Vector3.new(0, height, 0)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Width0, b.Width1 = width, width * 0.85
	b.Color = ColorSequence.new(color)
	b.LightEmission, b.LightInfluence, b.FaceCamera, b.Segments = 1, 0, true, 1
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(0.6, (alpha + 1) / 2), NumberSequenceKeypoint.new(1, 1) })
	b.Parent = anchor
end

-- SurfaceGui screen on its own transparent part just in front of a kit screen face (never on the mesh face).
local function screen(face: BasePart, title: string, accent: Color3, lines: { string }, footer: string?)
	local s = part(face.Parent :: Instance, "ScreenSurface", Vector3.new(face.Size.X - 0.4, face.Size.Y - 0.4, 0.05),
		face.CFrame * CFrame.new(0, 0, -(face.Size.Z / 2 + 0.08)), Color3.new(), { transparency = 1, collide = false, shadow = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0
	sg.Brightness = 1.3
	sg.MaxDistance = 220
	sg.Parent = s
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromHex("121822")
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("121822")),
		ColorSequenceKeypoint.new(0.5, accent:Lerp(Color3.fromHex("121822"), 0.72)),
		ColorSequenceKeypoint.new(1, Color3.fromHex("121822")),
	})
	g.Rotation = 20
	tag(g, "LobbyScroll")
	g.Parent = bg
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.025, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bg
	local function label(text: string, h: number, font: Enum.Font, color: Color3, order: number)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.9, h)
		t.Text = text
		t.TextScaled = true
		t.Font = font
		t.TextColor3 = color
		t.LayoutOrder = order
		t.Parent = bg
	end
	label(title, 0.24, Enum.Font.GothamBlack, accent, 1)
	for i, line in lines do
		label(line, 0.12, Enum.Font.GothamBold, Color3.fromHex("E8EDF2"), 1 + i)
	end
	if footer then
		label(footer, 0.1, Enum.Font.GothamBlack, accent, 99)
	end
end

local function sign(key: string, cf: CFrame, parent: Instance, accent: Color3, scale: number?, ghost: boolean?): Model
	local m = put("Sign_" .. key, cf, parent, scale)
	tint(m, "_Glow", accent)
	each(m, "_Tube_Glow", function(p)
		tag(p, "LobbyPulse")
	end)
	if ghost then
		local face = child(m, "Sign_" .. key .. "_Text") :: BasePart
		local g = face:Clone()
		g.Name = "GlitchGhost"
		g.Material = Enum.Material.Neon
		g.Color = C.magenta
		g.Transparency = 1
		g.CastShadow = false
		g.CFrame = face.CFrame + (-cf.LookVector) * 0.12 * (scale or 1)
		tag(g, "LobbyGlitch")
		g.Parent = m
	end
	return m
end

-- ---------------------------------------------------------------- clear the old hub

for _, f in root:GetChildren() do
	if f.Name == "Greybox" or f.Name == "Art" then
		for _, c in f:GetChildren() do
			if c.Name ~= "RangeFar" then
				c:Destroy()
			end
		end
	elseif f.Name == "Ambience" or f.Name == "Hub" then
		f:Destroy()
	end
end
local blockout = workspace:FindFirstChild("LobbyBlockoutV2")
if blockout then
	blockout:Destroy()
end
task.wait()

local hub = folder("Hub", root)
local F = {
	shell = folder("Shell", hub),
	collision = folder("Collision", hub),
	duels = folder("Duels", hub),
	market = folder("Market", hub),
	armoury = folder("Armoury", hub),
	range = folder("Range", hub),
	lights = folder("Lights", hub),
	fx = folder("FX", hub),
	markers = folder("Markers", hub),
}
local function floorPart(parent: Instance, name: string, size: Vector3, top: number, x: number, z: number, color: Color3): Part
	return part(parent, name, size, CFrame.new(x, top - size.Y / 2, z), color, { material = Enum.Material.Slate, variant = "Bunker_Floor" })
end
local function wallCol(name: string, size: Vector3, cf: CFrame)
	col(F.collision, name, size, cf)
end

-- ---------------------------------------------------------------- hub: rotunda and ring (floor 0)

local shell = F.shell
disc(shell, "RingFloor", 45.5, 0, 0, 0, C.ring, { material = Enum.Material.Slate, variant = "Bunker_Floor" })
disc(shell, "RotundaFloor", 30.5, 0.06, 0, 0, Color3.fromHex("85878D"), { material = Enum.Material.Slate, variant = "Bunker_Floor" })
put("RotundaFloorRing", at(0, 0.08, 0), shell)
put("Drum", at(0, 0, 0), shell)
put("Dome", at(0, 0, 0), shell)
put("OculusRim", at(0, 0, 0), shell)
for k = 0, 15 do
	put("DomeRib", at(0, 0, 0, -(k * 22.5 + 11.25)), shell)
end
for k = 0, 7 do
	local b = 22.5 + 45 * k
	local pr = put("Pier", onRing(30, b, 0.06), shell)
	tint(pr, "_Slot_Glow", Color3.fromHex("FFD9A8"))
	col(F.collision, "Pier", Vector3.new(7.2, 20, 7.2), onRing(30, b, 10))
end
put("RingCeiling", at(0, 0, 0), shell)
for _, w in { { "RingWall_444", 27 }, { "RingWall_528", 108.6 }, { "RingWall_528", 198.6 }, { "RingWall_444", 288.6 } } do
	put(w[1], at(0, 0, 0, -w[2]), shell)
end
for _, b in { 33.75, 56.25, 123.75, 146.25, 213.75, 236.25, 303.75, 326.25 } do
	put("RingPilaster", onRing(43.35, b, 0), shell)
	put("RingRib", at(0, 0, 0, -b), shell)
end
for _, b in { 45, 135, 225, 315 } do
	local p = dir(b) * 38
	put("VentFan", at(p.X, 22.05, p.Z), shell)
	local blades = put("FanBlades", at(p.X, 22.05, p.Z), shell)
	spin(blades, 160)
end
arcCol(F.collision, 43.4, 24, 0, { { 0, 40 }, { 90, 28 }, { 180, 28 }, { 270, 28 } })

-- Portals with their sign boxes and accent edge colour.
local PORTALS = {
	{ b = 0, w = 40, key = "DUELS", accent = C.duels },
	{ b = 270, w = 28, key = "SHOP", accent = C.market },
	{ b = 90, w = 28, key = "ARMOURY", accent = C.armoury },
	{ b = 180, w = 28, key = "RANGE", accent = C.range },
}
for _, p in PORTALS do
	local cf = onRing(44, p.b, 0)
	local m = put("Portal_" .. p.w, cf, shell)
	tint(m, "_Edge_Glow", p.accent)
	sign(p.key, cf * CFrame.new(0, 16.8, 2.85), shell, p.accent, 1.0, p.key == "DUELS" or p.key == "RANGE")
	lamp(F.lights, (cf * CFrame.new(0, 12, 4)).Position, p.accent, 16, 0.8)
	local h = p.w / 2 + 3.4
	for _, s in { -1, 1 } do
		wallCol("Jamb", Vector3.new(3.4, 20, 4.4), cf * CFrame.new(s * (p.w / 2 + 1.7), 10, 0))
	end
	wallCol("Header", Vector3.new(h * 2, 6, 4.4), cf * CFrame.new(0, 17, 0))
	part(shell, "HeaderFascia", Vector3.new(h * 2 + 0.4, 2.6, 4.0), cf * CFrame.new(0, 20.85, 0.1), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
end

-- Threshold plates: fill the floor between the round ring floor and each straight wing floor (visual + collision).
-- Stops where a stair landing starts (Duels, Market) and inside the portal reveal, so no face is shared.
for _, p in PORTALS do
	local deep = if p.b == 0 or p.b == 270 then 4.75 else 5.4
	part(shell, "Threshold", Vector3.new(p.w - 0.7, 0.2, deep), onRing(40.8 + deep / 2, p.b, -0.02), C.dark, { material = Enum.Material.Slate, variant = "Bunker_Floor" })
end

-- Spawn dais under the oculus, guide lines to each wing.
put("SpawnDais", at(0, 0.06, 0), shell)
local d1 = part(F.collision, "DaisBase", Vector3.new(0.6, 19.2, 19.2), CFrame.new(0, 0.36, 0) * CFrame.Angles(0, 0, math.rad(90)), C.slate, { transparency = 1, shape = Enum.PartType.Cylinder })
d1.Name = "DaisBase"
part(F.collision, "DaisTop", Vector3.new(1.16, 16.6, 16.6), CFrame.new(0, 0.58, 0) * CFrame.Angles(0, 0, math.rad(90)), C.slate, { transparency = 1, shape = Enum.PartType.Cylinder })
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(10, 0.2, 10)
spawn.CFrame = CFrame.new(0, 1.25, 0)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.CanQuery = false
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = shell
tag(spawn, "LobbySpawn")
for _, p in PORTALS do
	for _, r in { 37 } do
		local cf = onRing(r, p.b, if r < 30 then 0.07 else 0.01) * Y(0)
		local g = put("GuideLine", cf, shell)
		tint(g, "_Glow", p.accent)
	end
end

-- Leaderboards on the ring wall, seen through the NE / NW colonnade openings.
for i, b in { 45, 315 } do
	local m = put("PadScreen", onRing(43.3, b, 4.0), shell, 1.35)
	m.Name = if i == 1 then "Leaderboard_Wins" else "Leaderboard_Streaks"
	screen(child(m, "PadScreen_Face"), if i == 1 then "TOP WINS" else "WIN STREAKS", if i == 1 then C.market else C.duels, { "#1  ----", "#2  ----", "#3  ----" }, "LIVE SOON")
	tint(m, "_Status_Glow", if i == 1 then C.market else C.duels)
end

-- Sunwell: light shafts through the oculus, dust, a warm floor hot spot.
local sunFx = part(F.fx, "SunwellDust", Vector3.new(18, 30, 18), CFrame.new(0, 18, 0), C.warm, { transparency = 1, collide = false })
local dust = emitter(sunFx, SPARKLE, Color3.fromHex("FFE9C4"), 10, 0.3, 0.16, 9, 0.5)
dust.Shape = Enum.ParticleEmitterShape.Box
dust.SpreadAngle = Vector2.new(180, 180)
lamp(F.lights, Vector3.new(0, 8, 0), Color3.fromHex("FFE2B8"), 22, 0.7)
task.wait()

-- ---------------------------------------------------------------- Duels hall (north, floor -3)

local duels = F.duels
put("Steps_40_3", at(0, 0.08, -46.2), duels) -- landings sit 0.08 proud: a threshold plate, never level with a floor
for k = 0, 2 do
	col(F.collision, "Step", Vector3.new(40, 1, 2), CFrame.new(0, -k - 0.5, -46.2 - 2 * k - 1))
end
for _, s in { -1, 1 } do
	part(duels, "StepLedge", Vector3.new(1.8, 3.6, 6.4), CFrame.new(s * 20.9, -1.8, -49.4), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
end
floorPart(duels, "HallFloor", Vector3.new(44.4, 2, 94), -3, 0, -93.5, C.hall)
part(duels, "Walkway", Vector3.new(10, 0.2, 88), CFrame.new(0, -2.9, -96.4), C.walk, { material = Enum.Material.Slate, variant = "Bunker_Floor" })
for _, s in { -1, 1 } do
	part(duels, "WalkLineY", Vector3.new(0.35, 0.1, 88), CFrame.new(s * 5.3, -2.75, -96.4), C.yellow)
	part(duels, "WalkLineP", Vector3.new(0.35, 0.1, 88), CFrame.new(s * 6.1, -2.85, -96.4), C.purple)
end
for z = -58, -134, -8 do
	put("Chevron", at(0, -2.8, z), duels)
end
part(duels, "Ceiling", Vector3.new(46, 2, 96), CFrame.new(0, 26.1, -93.5), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
for i, z in { -55, -74, -93, -112, -131 } do
	for _, s in { -1, 1 } do
		local cf = at(s * 22.6, -3, z, -90 * s)
		local bay = put("HallBay", cf, duels)
		bay.Name = "Bay" .. i
	end
end
for _, s in { -1, 1 } do
	wallCol("HallWall", Vector3.new(2, 30, 96), CFrame.new(s * 22.8, 12, -93.5))
	for _, z in { -64.5, -83.5, -102.5, -121.5 } do
		put("Buttress", at(s * 22.6, -3, z, -90 * s), duels)
		col(F.collision, "Buttress", Vector3.new(3.6, 20, 3), CFrame.new(s * 21.1, 7, z))
		if s == 1 then -- one truss per seam spans the whole hall
			local t = put("HallTruss", at(0, -3, z), duels)
			t.Name = "Truss"
		end
	end
end
for _, s in { -1, 1 } do
	put("HallBay", at(s * 9.5, -3, -141.4), duels)
	put("Pier", at(s * 20.8, -3.05, -140.2), duels, 0.95) -- closes the end corners (0.95: plinth tops never level with the bays)
end
wallCol("HallEnd", Vector3.new(46, 30, 2), CFrame.new(0, 12, -142.6))
local door = put("BlastDoor", at(0, -3, -140.5), duels)
door.Name = "SoonDoor"
tag(child(door, "BlastDoor_Beacon_Glow"), "LobbyPulse")
for _, s in { -1, 1 } do
	local scr = put("PadScreen", at(s * 9.5, -0.2, -141.4), duels)
	scr.Name = "EndScreen"
	screen(child(scr, "PadScreen_Face"), if s < 0 then "4V4" else "GAUNTLET", Color3.fromHex("8FA3B8"), { "Coming soon" }, nil)
end
for _, z in { -55, -74, -93, -112, -131 } do
	local p = put("Pendant", at(0, 25.1, z), duels)
	tag(child(p, "Pendant_Lamp_Glow"), "LobbyPulse")
	lamp(F.lights, Vector3.new(0, 18, z), C.warm, 20, 1.0)
end

type Pad = { id: string, mode: string, size: number, z: number }
local PADS: { Pad } = {
	{ id = "1v1_A", mode = "1v1", size = 12, z = -55 },
	{ id = "1v1_B", mode = "1v1", size = 12, z = -74 },
	{ id = "2v2_A", mode = "2v2", size = 14, z = -93 },
	{ id = "3v3_A", mode = "3v3", size = 16, z = -112 },
}
for _, pd in PADS do
	for _, s in { -1, 1 } do
		local x = s * (5.6 + pd.size / 2)
		local id = pd.id .. (if s < 0 then "W" else "E")
		local color = MODE[pd.mode]
		local m = put("DuelPad_" .. pd.size, at(x, -2.92, pd.z), duels)
		m.Name = "Pad_" .. id
		tint(m, "_Glow", color)
		each(m, "_Rings_Glow", function(p)
			tag(p, "LobbyPulse")
		end)
		local z = zone(m, "QueueZone", Vector3.new(pd.size - 1, 5, pd.size - 1), CFrame.new(x, -0.5, pd.z), "LobbyQueue")
		z:SetAttribute("Mode", pd.mode)
		z:SetAttribute("PadId", id)
		local tab = put("ModeTab_" .. string.upper(pd.mode), at(x, 9.5, pd.z, -90 * s) * CFrame.Angles(math.rad(-14), 0, 0), duels)
		tag(tab, "LobbyBob")
		tab:SetAttribute("BobAmp", 0.25)
		tab:SetAttribute("BobSpeed", 0.9 + pd.size * 0.03)
		tint(tab, "_Plate", color)
		local bay = at(s * 22.6, -3, pd.z, -90 * s)
		local scr = put("PadScreen", bay * CFrame.new(0, 2.8, 0), duels)
		scr.Name = "PadScreen_" .. id
		tint(scr, "_Status_Glow", color)
		screen(child(scr, "PadScreen_Face"), string.upper(pd.mode), color, { "0 / " .. string.sub(pd.mode, 1, 1) }, "STAND HERE TO QUEUE")
		local fx = part(F.fx, "PadFx_" .. id, Vector3.new(pd.size - 3, 0.2, pd.size - 3), CFrame.new(x, -2.4, pd.z), color, { transparency = 1, collide = false })
		local e = emitter(fx, SPARKLE, color, 4, 3.5, 0.35, 1.8, 0.3)
		e.Shape = Enum.ParticleEmitterShape.Box
		column(fx, color, pd.size * 0.55, 9, 0.95)
	end
	lamp(F.lights, Vector3.new(0, 4, pd.z), MODE[pd.mode], 22, 0.9)
end
for _, s in { -1, 1 } do
	local v = part(F.fx, "Steam", Vector3.new(2, 0.2, 2), CFrame.new(s * 19.5, -2.8, -136), C.dark, { transparency = 1, collide = false })
	local e = emitter(v, SMOKE, Color3.fromHex("C8CCD2"), 2, 3, 3, 4, 0.75)
	e.RotSpeed = NumberRange.new(-20, 20)
end
task.wait()

-- ---------------------------------------------------------------- Market (west): niche hall -2, shop hall -5

local market = F.market
put("Steps_24_2", at(-46.2, 0.08, 0, 90), market)
for k = 0, 1 do
	col(F.collision, "Step", Vector3.new(2, 1, 24), CFrame.new(-46.2 - 2 * k - 1, -k - 0.5, 0))
end
for _, s in { -1, 1 } do
	part(market, "StepLedge", Vector3.new(4.4, 2.6, 2), CFrame.new(-48.4, -1.3, s * 13), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
end
floorPart(market, "NicheFloor", Vector3.new(34, 2, 28), -2, -63.2, 0, C.floor)
part(market, "NicheCeiling", Vector3.new(36, 2, 30), CFrame.new(-64, 21, 0), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
for _, s in { -1, 1 } do -- s = -1 north (Battle Pass, right), 1 south (Event, left)
	for _, x in { -52, -76 } do
		put("WallModule", at(x, -2, s * 14.6, if s < 0 then 0 else 180), market)
	end
	local nf = put("NicheFrame", at(-64, -2, s * 14.4, if s < 0 then 0 else 180), market)
	nf.Name = if s < 0 then "Niche_BattlePass" else "Niche_Event"
	local inside = nf:GetPivot() * CFrame.new(0, 1.2, -2.6)
	local scr = put("PadScreen", inside * CFrame.new(0, 1.1, 0), market, 0.85)
	screen(child(scr, "PadScreen_Face"), if s < 0 then "BATTLE PASS" else "EVENT", if s < 0 then C.purple else C.market,
		if s < 0 then { "Season 1", "30 tiers of rewards" } else { "Season 1 kickoff", "Limited-time rewards" }, "COMING SOON")
	sign(if s < 0 then "BATTLEPASS" else "EVENT", nf:GetPivot() * CFrame.new(0, 14.6, 0.9), market, if s < 0 then C.purple else C.market, 0.8, false)
	if s < 0 then
		zone(market, "BattlePassZone", Vector3.new(14, 6, 6), CFrame.new(-64, 1, s * 10.5), "LobbyBattlePass")
		local badge = put("SeasonCrest", nf:GetPivot() * CFrame.new(0, 1.3, -1.6), market, 0.42)
		spin(badge, 30, 0.25, 1)
	else
		local tr = put("GauntletTrophy", nf:GetPivot() * CFrame.new(0, 1.2, -1.15), market)
		local ts = tr:GetExtentsSize()
		tr:ScaleTo(6.5 / math.max(ts.X, ts.Y, ts.Z))
		local tb = tr:GetBoundingBox()
		tr:PivotTo(tr:GetPivot() + Vector3.new(0, (nf:GetPivot().Y + 1.25) - (tb.Position.Y - tr:GetExtentsSize().Y / 2), 0))
		tag(tr, "LobbyBob") -- bob, don't spin: a spin would sweep through the screen behind it
		tr:SetAttribute("BobAmp", 0.3)
		tr:SetAttribute("BobSpeed", 0.5)
	end
	lamp(F.lights, (nf:GetPivot() * CFrame.new(0, 8, 0)).Position, if s < 0 then C.purple else C.market, 14, 0.8)
	wallCol("NicheWall", Vector3.new(34, 24, 2), CFrame.new(-64, 10, s * 15.2))
	-- The niche is 12.4 tall in a 22-tall wall: close the wall above it.
	part(market, "NicheUpper", Vector3.new(17.2, 10.5, 1.2), CFrame.new(-64, 14.65, s * 15.0), C.concrete, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
end
for _, s in { -1, 1 } do -- close the gaps between the portal and the first wall modules
	part(market, "EntryFiller", Vector3.new(2.2, 24, 1.5), CFrame.new(-47.15, 10, s * 14.4), C.concrete, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
end
for _, x in { -52, -76 } do
	put("Pendant", at(x, 20, 0), market)
	lamp(F.lights, Vector3.new(x, 13, 0), C.warm, 18, 0.9)
end
put("Steps_24_3", at(-80.2, -1.92, 0, 90), market)
for k = 0, 2 do
	col(F.collision, "Step", Vector3.new(2, 1, 24), CFrame.new(-80.2 - 2 * k - 1, -2 - k - 0.5, 0))
end
for _, s in { -1, 1 } do
	part(market, "StepLedge", Vector3.new(6.4, 3.6, 2), CFrame.new(-83.4, -3.8, s * 13), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
end
floorPart(market, "ShopFloor", Vector3.new(33, 2, 34), -5, -102.3, 0, Color3.fromHex("A39582"))
disc(market, "ShopMedallion", 7, -4.92, -102, 0, C.slate, { material = Enum.Material.Slate, variant = "Bunker_Floor" })
part(market, "ShopCeiling", Vector3.new(38, 2, 36), CFrame.new(-101, 22, 0), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
for _, s in { -1, 1 } do
	for _, x in { -90.4, -114 } do
		put("WallModule", at(x, -5, s * 16.6, if s < 0 then 0 else 180), market)
	end
	local bd = put("BlastDoor", at(-102.2, -5, s * 16.0, if s < 0 then 0 else 180), market)
	bd.Name = if s < 0 then "DoorNorth" else "DoorSouth"
	tag(child(bd, "BlastDoor_Beacon_Glow"), "LobbyPulse")
	put("WallModule", at(-118.6, -5, s * 12, 90), market)
	part(market, "EastWall", Vector3.new(2, 28, 4), CFrame.new(-86.4, 9, s * 14.4), C.concrete, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
	wallCol("ShopWall", Vector3.new(34, 30, 2), CFrame.new(-102, 10, s * 17.4))
end
wallCol("ShopBack", Vector3.new(2, 30, 36), CFrame.new(-119.4, 10, 0))
for _, s in { -1, 1 } do -- the 22-tall modules stop at 17 here: close the band up to the ceiling
	-- Full-height backing behind the modules and doors: closes every gap to the outside, even with the doors scaled down.
	part(market, "UpperWall", Vector3.new(36, 26, 1.0), CFrame.new(-102.2, 8, s * 17.7), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
	part(market, "UpperWallW", Vector3.new(0.9, 25.8, 9.8), CFrame.new(-119.65, 7.9, s * 12.3), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
end
local back = put("ShopBackdrop", at(-118.4, -5, 0, 90), market)
local counter = put("ShopCounter", at(-112.5, -5, 0, 90), market)
col(F.collision, "Counter", Vector3.new(4, 4, 15), CFrame.new(-112.5, -3, 0))
zone(market, "ShopZone", Vector3.new(6, 6, 15), CFrame.new(-108.5, -2, 0), "LobbyShop")
part(market, "BackWall", Vector3.new(1.2, 26, 16.4), CFrame.new(-119.6, 8, 0), C.concrete, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
local crest = put("SeasonCrest", at(-118.6, 12.2, 0, 90), market, 0.6)
crest.Name = "SeasonCentrepiece"
crest:SetAttribute("Season", 1)
each(crest, "_Emblem_Glow", function(p)
	tag(p, "LobbyPulse")
end)
local shopSign = sign("SHOP", back:GetPivot() * CFrame.new(0, 14.6, 1.0), market, C.market, 0.7, false)
shopSign.Name = "ShopSign"
lamp(F.lights, Vector3.new(-102, 10, 0), Color3.fromHex("FFD49A"), 26, 1.2)
lamp(F.lights, Vector3.new(-112, 6, 0), C.market, 14, 1.0)
put("Pendant", at(-96, 21, 0), market)
task.wait()

-- ---------------------------------------------------------------- Armoury + Locker (east, floor +2)

local arm = F.armoury
local AX = 73
put("Steps_24_2", at(50.6, 2.08, 0, 90), arm)
for k = 0, 1 do
	col(F.collision, "Step", Vector3.new(2, 1, 24), CFrame.new(50.6 - 2 * k - 1, 2 - k - 0.5, 0))
end
col(F.collision, "StepFoot", Vector3.new(1, 1, 24), CFrame.new(46.5, -0.42, 0))
disc(arm, "RoomFloor", 22.4, 2, AX, 0, Color3.fromHex("3E4752"), { material = Enum.Material.Slate, variant = "Bunker_Floor" })
part(arm, "Throat", Vector3.new(7.6, 2, 30), CFrame.new(54.3, 0.92, 0), C.dark, { material = Enum.Material.Slate, variant = "Bunker_Floor" })
part(arm, "ThroatCeiling", Vector3.new(11.4, 2, 30), CFrame.new(52, 23, 0), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
put("RoomWall_R22", at(AX, 2, 0, 49.5), arm)
put("RoomCeiling_R22", at(AX, 2, 0), arm)
for _, s in { -1, 1 } do
	part(arm, "Filler", Vector3.new(11.6, 24, 3.2), CFrame.new(52, 12, s * 16.2), C.concrete, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
	wallCol("Filler", Vector3.new(11.6, 24, 3.2), CFrame.new(52, 12, s * 16.2))
end
arcCol(F.collision, 21.8, 24, 2, { { 270, 30 } }, AX, 0)
put("HeroPlinth", at(AX - 2, 2, 0), arm)
local hero = put("Hero_Vandal", at(AX - 2, 9.5, 0), arm)
local hs = hero:GetExtentsSize()
hero:ScaleTo(9 / math.max(hs.X, hs.Z)) -- hero size, but believable next to a 5-stud avatar (blind review W6)
spin(hero, 14, 0.4, 0.6)
col(F.collision, "HeroPlinth", Vector3.new(10, 2.4, 10), CFrame.new(AX - 2, 3.2, 0))
lamp(F.lights, Vector3.new(AX - 2, 16, 0), Color3.fromHex("DFF4FF"), 26, 1.3)
for i, pair in { { 30, "Display_Phantom" }, { 150, "Display_Operator" }, { 210, "Display_Sheriff" }, { 330, "Display_Guardian" } } do
	local cf = onRing(14, pair[1], 2, AX, 0)
	put("GunPedestal", cf, arm)
	col(F.collision, "Pedestal", Vector3.new(4.6, 3.5, 4.6), cf * CFrame.new(0, 1.75, 0))
	if OLD[pair[2]] then
		local g = put(pair[2], cf * CFrame.new(0, 5.2, 0), arm)
		local ss = g:GetExtentsSize()
		g:ScaleTo((if pair[2] == "Display_Sheriff" then 2.2 else 4.0) / math.max(ss.X, ss.Z))
		spin(g, 22 + i * 3)
	end
end
put("LockerBackdrop", at(AX + 18.6, 2, 0, -90), arm)
local plat = put("LockerPlatform", at(AX + 12, 2, 0), arm)
spin(plat, 18)
-- Locker preview: a default R15 avatar as a clean mannequin (light grey, slate torso). Lane B can swap in the
-- player's own avatar later; the old block mannequin is the fallback.
local okA, made = pcall(function()
	return game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
end)
local man: Model = if okA and made then made else put("Mannequin", at(AX + 12, 2.8, 0, -90), arm)
man.Name = "LockerAvatar"
for _, d in man:GetDescendants() do
	if d:IsA("BasePart") then
		d.Material = Enum.Material.SmoothPlastic
		d.Color = if string.find(d.Name, "Torso") then C.slate else Color3.fromHex("D5D9DE")
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
	elseif d:IsA("Script") or d:IsA("LocalScript") then
		d:Destroy()
	end
end
local hum = man:FindFirstChildOfClass("Humanoid")
if hum then
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end
man:PivotTo(at(AX + 12, 10, 0, -90))
man.Parent = arm
local mb, msz = man:GetBoundingBox()
man:PivotTo(man:GetPivot() + Vector3.new(0, 2.9 - (mb.Position.Y - msz.Y / 2), 0))
spin(man, 18)
zone(arm, "LockerZone", Vector3.new(9, 7, 9), CFrame.new(AX + 12, 5, 0), "LobbyLocker")
col(F.collision, "LockerPlatform", Vector3.new(8.4, 0.8, 8.4), CFrame.new(AX + 12, 2.4, 0))
for _, b in { 52, 128 } do
	local cf = onRing(18.2, b, 2, AX, 0)
	put("LockerCabinet", cf, arm)
	col(F.collision, "Cabinet", Vector3.new(4.6, 10.5, 3), cf * CFrame.new(0, 5.2, 0))
end
sign("LOCKER", at(AX + 18.2, 18.4, 0, -90), arm, C.armoury, 0.8, false)
lamp(F.lights, Vector3.new(AX + 14, 10, 0), Color3.fromHex("CFF6FF"), 18, 1.2)
task.wait()

-- ---------------------------------------------------------------- Range room (south, floor 0)

local range = F.range
floorPart(range, "RangeFloor", Vector3.new(50, 2, 41), 0, 0, 66.7, Color3.fromHex("9B9488"))
part(range, "RangeCeiling", Vector3.new(52, 2, 44), CFrame.new(0, 21, 66.2), C.dark, { material = Enum.Material.Concrete, variant = "Bunker_Concrete" })
for _, s in { -1, 1 } do
	for _, z in { 50.2, 58.2, 66.2, 74.2, 82.2 } do
		put("WallModule", at(s * 24.6, -0.05, z, -90 * s), range)
	end
	put("WallModule", at(s * 20.4, -0.05, 46.8, 0), range)
	wallCol("RangeSide", Vector3.new(2, 24, 42), CFrame.new(s * 25.4, 12, 66.2))
	wallCol("RangeFront", Vector3.new(8, 24, 2), CFrame.new(s * 20.4, 12, 46))
end
for _, x in { -20, -12, -4, 4, 12, 20 } do
	put("WallModule", at(x, -0.05, 86.6, 180), range)
end
wallCol("RangeBack", Vector3.new(50, 24, 2), CFrame.new(0, 12, 87.4))
for _, c in { { -24.6, 46.8 }, { 24.6, 46.8 }, { -24.6, 86.6 }, { 24.6, 86.6 } } do
	put("Pier", at(c[1], -0.05, c[2], if c[2] > 60 then 0 else 180), range) -- full size: hides the wall-module corner joins
end
-- Scale model of the real range in a blue holo cage.
local MZ = 62
put("ModelPlinth", at(0, 0, MZ), range)
col(F.collision, "ModelPlinth", Vector3.new(20, 2.3, 14), CFrame.new(0, 1.15, MZ))
if OLD["ScaleModel"] then
	local sm = put("ScaleModel", at(0, 2.05, MZ, 90), range)
	local ss = sm:GetExtentsSize()
	sm:ScaleTo(math.min(17.4 / ss.X, 11.6 / ss.Z))
	local bb = sm:GetBoundingBox()
	sm:PivotTo(sm:GetPivot() + Vector3.new(0, 2.2 - (bb.Position.Y - sm:GetExtentsSize().Y / 2), 0))
end
local cage = folder("HoloCage", range)
for _, c in { { -9.4, -6.4 }, { 9.4, -6.4 }, { -9.4, 6.4 }, { 9.4, 6.4 } } do
	put("CageCorner", at(c[1], 2.0, MZ + c[2]), cage)
end
for _, h in { 6.0, 10.0, 14.0 } do
	for _, e in { { 0, -6.4, 18.8, 0.18 }, { 0, 6.4, 18.8, 0.18 }, { -9.4, 0, 0.18, 12.8 }, { 9.4, 0, 0.18, 12.8 } } do
		local l = part(cage, "HoloLine", Vector3.new(e[3], 0.12, e[4]), CFrame.new(e[1], h, MZ + e[2]), C.holo, { material = Enum.Material.Neon, collide = false, shadow = false })
		tag(l, "LobbyGlitch")
	end
end
for _, f in { { 0, -6.4, 18.8, 0.1 }, { 0, 6.4, 18.8, 0.1 }, { -9.4, 0, 0.1, 12.8 }, { 9.4, 0, 0.1, 12.8 } } do
	local w = part(cage, "HoloWall", Vector3.new(f[3], 12, f[4]), CFrame.new(f[1], 8, MZ + f[2]), C.holo, { material = Enum.Material.ForceField, collide = false, shadow = false })
	w.Transparency = 0.2
end
local cageFx = part(F.fx, "CageSparkles", Vector3.new(17, 10, 11), CFrame.new(0, 8, MZ), C.holo, { transparency = 1, collide = false })
local ce = emitter(cageFx, SPARKLE, C.holo, 6, 0.6, 0.25, 3, 0.4)
ce.Shape = Enum.ParticleEmitterShape.Box
ce.SpreadAngle = Vector2.new(180, 180)
lamp(F.lights, Vector3.new(0, 10, MZ), C.holo, 24, 1.1)
lamp(F.lights, Vector3.new(0, 16, 52), Color3.fromHex("EEF3FF"), 30, 0.9)
-- The way in: walk past the model to the gate at the back.
local gcf = at(0, 0, 83.4, 180)
local gate = put("Portal_28", gcf, range)
gate.Name = "RangeGate"
tint(gate, "_Edge_Glow", C.range)
sign("RANGE", gcf * CFrame.new(0, 16.8, 2.85), range, C.range, 1.0, true)
local surf = part(range, "GateSurface", Vector3.new(27.2, 13.6, 0.3), gcf * CFrame.new(0, 6.9, -0.4), C.range, { material = Enum.Material.ForceField, collide = false, shadow = false })
tag(surf, "LobbyPulse")
zone(range, "RangeEntrance", Vector3.new(26, 14, 6), gcf * CFrame.new(0, 7, 2), "LobbyRangeEntrance")
lamp(F.lights, (gcf * CFrame.new(0, 8, 5)).Position, C.range, 20, 1.2)
local gfx = part(F.fx, "GateFx", Vector3.new(24, 12, 0.5), gcf * CFrame.new(0, 7, 1), C.range, { transparency = 1, collide = false })
local ge = emitter(gfx, SPARKLE, Color3.fromHex("FFB1A6"), 8, 2, 0.35, 1.5, 0.3)
ge.Shape = Enum.ParticleEmitterShape.Box
ge.EmissionDirection = Enum.NormalId.Back
local ret = part(F.markers, "RangeReturnPoint", Vector3.new(4, 1, 4), CFrame.new(0, 0.5, 52) * Y(180), C.range, { transparency = 1, collide = false })
ret:SetAttribute("Note", "Range exit lands here, facing the hub")

-- ---------------------------------------------------------------- pass 2 (2026-11-05): mood, signs, centrepiece, dressing
-- From the core chat's comparison with RIVALS and the LihFolk notes: Level Design Principles - Flow Sightlines and
-- Landmarks, Teaching Through Level Design (light the objective, one beam per objective), Colour Scripts and Value
-- Structure for Untextured Art (walls one value band from the floor, interactables lightest), Stylized Lighting Recipes
-- (bloom threshold 1.2-2), Light Sources and Shadows (tag lights, disable out of view), Lobby and Hub Design (busy
-- edges, clear paths).
-- 1. Value structure: concrete one band darker, so lit focal points and accent pools carry the contrast.
for _, d in hub:GetDescendants() do
	if d:IsA("BasePart") and d.MaterialVariant == "Bunker_Concrete" then
		d.Color = d.Color:Lerp(Color3.new(0, 0, 0), 0.16)
	end
end

-- 2. Accent light as light: each portal throws its wing colour onto the ring floor; pads light their bays.
for _, l in F.lights:GetDescendants() do
	if l:IsA("PointLight") then
		tag(l, "LobbyLight")
		local c = l.Color
		local isAccent = c == C.duels or c == C.market or c == C.armoury or c == C.range
		if isAccent then
			l.Brightness, l.Range = 2.2, 24
		end
		for _, m in MODE do
			if c == m then
				l.Brightness, l.Range = 2.4, 22
				local p = l.Parent :: BasePart
				p.Position = Vector3.new(0, -1, p.Position.Z)
			end
		end
	end
end

-- 3. Portal signs: 1.8x, hanging into the top of the opening, glowing white letters over the accent tube and icon.
for _, s in shell:GetChildren() do
	if s:IsA("Model") and string.sub(s.Name, 1, 5) == "Sign_" then
		local cf = s:GetPivot()
		s:ScaleTo(1.8)
		s:PivotTo(cf * CFrame.new(0, -1.3, 0.75))
		each(s, "_Text", function(p)
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromHex("F4F7FF")
		end)
		local ghost = s:FindFirstChild("GlitchGhost", true)
		if ghost and ghost:IsA("BasePart") then
			local face = child(s, s.Name .. "_Text") :: BasePart
			ghost.Size = face.Size
			ghost.CFrame = face.CFrame + (-cf.LookVector) * 0.22
		end
	end
end

-- 4. Spawn centrepiece: a hologram season banner and emblem high over the dais (above the sightline to Duels),
--    a projector beam from the grate, sparkles; two leaderboards on stands behind the dais.
local holo = Color3.fromHex("6FE3FF")
local emblem = put("SeasonCrest", at(0, 20.5, 0), shell, 0.55)
emblem.Name = "HoloEmblem"
for _, p in emblem:GetDescendants() do
	if p:IsA("BasePart") then
		p.Material = Enum.Material.Neon
		p.Color = holo
		p.Transparency = 0.45
		p.CastShadow = false
	end
end
spin(emblem, 22, 0.5, 0.4)
local banner = part(shell, "HoloBanner", Vector3.new(16, 4.4, 0.1), CFrame.new(0, 15.8, 0), holo, { transparency = 1, collide = false, shadow = false })
for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Brightness = 2.2
	sg.MaxDistance = 200
	sg.Parent = banner
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.66)
	t.Text = "SEASON 1"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = holo
	t.TextTransparency = 0.05
	t.Parent = sg
	local u = t:Clone()
	u.Position = UDim2.fromScale(0, 0.66)
	u.Size = UDim2.fromScale(1, 0.34)
	u.Text = "LAUNCHING SOON"
	u.Font = Enum.Font.GothamBold
	u.TextColor3 = Color3.fromHex("E8FBFF")
	u.Parent = sg
end
spin(banner, 14)
local proj = part(F.fx, "HoloProjector", Vector3.new(8, 0.2, 8), CFrame.new(0, 1.3, 0), holo, { transparency = 1, collide = false })
local pe = emitter(proj, SPARKLE, holo, 6, 4, 0.3, 3, 0.35)
pe.Shape = Enum.ParticleEmitterShape.Box
for i, b in { 125, 235 } do
	local cf = onRing(21, b, 0.06)
	part(shell, "BoardStand", Vector3.new(0.8, 4.6, 0.8), cf * CFrame.new(0, 2.3, 0.6), C.slate, { material = Enum.Material.Metal, variant = "Bunker_Metal" })
	part(shell, "BoardFoot", Vector3.new(4, 0.4, 2.4), cf * CFrame.new(0, 0.2, 0.6), C.slate, { material = Enum.Material.Metal, variant = "Bunker_Metal" })
	col(F.collision, "BoardFoot", Vector3.new(4, 4.6, 2.4), cf * CFrame.new(0, 2.3, 0.6))
	local m = put("PadScreen", cf * CFrame.new(0, 4.4, 0.2), shell, 0.75)
	m.Name = if i == 1 then "Board_TopDuelists" else "Board_Season"
	screen(child(m, "PadScreen_Face"), if i == 1 then "TOP DUELISTS" else "SEASON 1", if i == 1 then C.duels else holo, if i == 1 then { "#1  ----", "#2  ----" } else { "Battle Pass soon" }, nil)
end
-- (Light columns over the dais were tried and removed: Beams read as flat grey sheets across the spawn view.)

-- 5. Set dressing in the kit style. Busy edges, clear walking paths.
local dress = folder("Dressing", hub)
local function caseStack(cf: CFrame)
	put("HardCase_L", cf, dress)
	put("HardCase_S", cf * CFrame.new(0.4, 3.0, 0.2) * Y(12), dress)
	col(F.collision, "Cases", Vector3.new(6, 5, 3), cf * CFrame.new(0, 2.5, 0))
end
local function displayGun(name: string, cf: CFrame, len: number, parent: Instance): Model?
	if not OLD[name] then
		return nil
	end
	if name == "Display_Classic" or name == "Display_Sheriff" then
		len = math.min(len, 2.4) -- pistols stay pistol-sized
	elseif len > 4.4 then
		len = 4.4 -- rifles at believable display size next to the avatar
	end
	local g = put(name, cf, parent)
	local ss = g:GetExtentsSize()
	g:ScaleTo(len / math.max(ss.X, ss.Z))
	return g
end
-- Ring: benches and cases at the back walls, vents and cable runs above the leaderboards.
for _, b in { 135, 225 } do
	put("BunkerBench", onRing(39.5, b, 0), dress)
	col(F.collision, "Bench", Vector3.new(6, 2, 2), onRing(39.5, b, 1))
	caseStack(onRing(40.5, b + 9, 0))
	put("WallVent", onRing(43.3, b, 11), dress)
	put("CableTray_16", onRing(43.3, b, 17.5), dress, 0.6)
end
for _, b in { 45, 315 } do
	put("CableTray_16", onRing(43.3, b, 16.4), dress, 0.6)
	put("BunkerBench", onRing(38.5, b, 0), dress)
	col(F.collision, "Bench", Vector3.new(6, 2, 2), onRing(38.5, b, 1))
end
-- Duels: cases and a barrier by the sealed door, benches between the end bays.
for _, s in { -1, 1 } do
	caseStack(at(s * 15.5, -3, -136.5, 180 - 8 * s))
	put("BunkerBench", at(s * 17.5, -3, -128.5, 90 * s), dress)
	col(F.collision, "Bench", Vector3.new(2, 2, 6), CFrame.new(s * 17.5, -2, -128.5))
end
put("Barrier", at(0, -3, -136.2), dress)
col(F.collision, "Barrier", Vector3.new(6, 2.4, 1.6), CFrame.new(0, -1.8, -136.2))
-- Market niche hall: cases at the step corners.
for _, s in { -1, 1 } do
	caseStack(at(-75.5, -2, s * 11.0, if s < 0 then 8 else 172)) -- at the far end, framing the shop steps, never in front of the niches
end
-- Shop cross: lit glass cases with game guns around the medallion, racks by the doors, barriers keep players off
-- the decorative doors, cable runs high on the walls.
local shopGuns = { "Display_Phantom", "Display_Operator", "Display_Sheriff", "Display_Guardian" }
for i, p in { { -94.5, -9 }, { -94.5, 9 }, { -109.5, -9 }, { -109.5, 9 } } do
	local cf = at(p[1], -5, p[2], 90)
	put("GlassCase", cf, dress)
	col(F.collision, "GlassCase", Vector3.new(3, 5.8, 3), cf * CFrame.new(0, 2.9, 0))
	local g = displayGun(shopGuns[i], cf * CFrame.new(0, 4.2, 0), 2.3, dress)
	if g then
		spin(g, 30)
	end
end
for _, s in { -1, 1 } do
	put("Barrier", at(-102.2, -5, s * 13.2, if s < 0 then 0 else 180), dress)
	col(F.collision, "Barrier", Vector3.new(6, 2.4, 1.6), CFrame.new(-102.2, -3.8, s * 13.2))
	local rack = put("WeaponRack", at(-114, -5 + 3.0, s * 15.5, if s < 0 then 0 else 180), dress)
	local rcf = rack:GetPivot()
	for k, name in { "Display_Phantom", "Display_Spectre" } do -- two per rack, spaced so guns never touch
		displayGun(name, rcf * CFrame.new(0, (k - 1) * 2.6 + 1.9, 1.3), 6.0, dress)
	end
	put("CableTray_16", at(-102.2, 13.5, s * 16.9, if s < 0 then 0 else 180), dress)
	caseStack(at(-90.5, -5, s * 13.4, if s < 0 then 4 else 176))
end
-- Armoury: weapon racks on the north and south walls, glass cases flanking the entrance.
for i, b in { 0, 180 } do
	local rack = put("WeaponRack", onRing(21.0, b, 4.5, AX, 0), dress)
	local rcf = rack:GetPivot()
	local set = if i == 1 then { "Display_Odin", "Display_Phantom" } else { "Display_Guardian", "Display_Operator" }
	for k, name in set do
		displayGun(name, rcf * CFrame.new(0, (k - 1) * 2.6 + 1.9, 1.3), 6.0, dress)
	end
end
for _, b in { 222, 318 } do -- clear of the entrance sightline to the Locker
	local cf = onRing(17.5, b, 2, AX, 0)
	put("GlassCase", cf, dress)
	col(F.collision, "GlassCase", Vector3.new(3, 5.8, 3), cf * CFrame.new(0, 2.9, 0))
	if OLD["GauntletTrophy"] then
		local t = put("GauntletTrophy", cf * CFrame.new(0, 3.2, 0), dress)
		local ts = t:GetExtentsSize()
		t:ScaleTo(1.8 / math.max(ts.X, ts.Y, ts.Z))
		spin(t, 25)
	end
end
-- Range room: benches and cases along the side walls, vents.
for _, s in { -1, 1 } do
	put("BunkerBench", at(s * 21.5, 0, 56, 90 * s), dress)
	col(F.collision, "Bench", Vector3.new(2, 2, 6), CFrame.new(s * 21.5, 1, 56))
	caseStack(at(s * 20.5, 0, 77, -90 * s))
	put("WallVent", at(s * 24.0, 11, 66.2, -90 * s), dress)
end

-- 6. Locker: a curved lit alcove behind the avatar replaces the flat backdrop; a cool key light on the avatar.
local backdrop = arm:FindFirstChild("LockerBackdrop")
if backdrop then
	backdrop:Destroy()
end
local alcove = put("LockerAlcove", at(AX + 12, 2, 0, -90), arm)
tint(alcove, "_Glow", C.armoury)
each(alcove, "_Glow", function(p)
	tag(p, "LobbyPulse")
end)
local lockerSign = arm:FindFirstChild("Sign_LOCKER")
if lockerSign and lockerSign:IsA("Model") then
	lockerSign:PivotTo(at(AX + 17.4, 21.2, 0, -90))
end
local key = part(F.lights, "LockerKey", Vector3.new(0.5, 0.5, 0.5), CFrame.new(AX + 9.5, 13, 0), C.armoury, { transparency = 1, collide = false })
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Bottom
spot.Angle = 55
spot.Range = 16
spot.Brightness = 3
spot.Color = Color3.fromHex("E8F7FF")
spot.Shadows = false
spot.Parent = key
tag(spot, "LobbyLight")
-- Shop counter key light.
local sk = part(F.lights, "ShopKey", Vector3.new(0.5, 0.5, 0.5), CFrame.new(-110, 14, 0), C.market, { transparency = 1, collide = false })
local ss = spot:Clone()
ss.Color = Color3.fromHex("FFE1B0")
ss.Range = 20
ss.Parent = sk

-- 7. Screens: bigger type and more glow, readable from 15-20 studs.
for _, sg in hub:GetDescendants() do
	if sg:IsA("SurfaceGui") and sg.Parent and sg.Parent.Name == "ScreenSurface" then
		sg.Brightness = 2.2
		for _, t in sg:GetDescendants() do
			if t:IsA("TextLabel") then
				if t.LayoutOrder == 1 then
					t.Size = UDim2.fromScale(0.94, 0.3)
				elseif t.LayoutOrder == 99 then
					t.Size = UDim2.fromScale(0.9, 0.12)
				else
					t.Size = UDim2.fromScale(0.9, 0.17)
				end
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 2
				stroke.Color = Color3.fromHex("0A0E16")
				stroke.Parent = t
			end
		end
	end
end
for _, l in hub:GetDescendants() do
	if l:IsA("Light") then
		tag(l, "LobbyLight")
	end
end
-- Every sign's letters glow (the Range gate and wing signs too, not only the portal signs).
for _, sgn in hub:GetDescendants() do
	if sgn:IsA("Model") and string.sub(sgn.Name, 1, 5) == "Sign_" then
		each(sgn, "_Text", function(p)
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromHex("F4F7FF")
		end)
	end
end

-- ---------------------------------------------------------------- fix round 1 (blind review on the LihFolk world rubric)
-- Lowest criteria: Armoury W6 scale / W3 palette, Range W4-W6, Market value contrast, Duels ceiling, Spawn floor tone.
each(market, "BlastDoor_Leaves", function(p)
	p.Color = Color3.fromHex("56687A") -- no navy on navy in the shop
end)
for _, nm in { "DoorNorth", "DoorSouth" } do
	local d = market:FindFirstChild(nm)
	if d and d:IsA("Model") then
		d:ScaleTo(0.75) -- decorative doors stop dominating the shop
	end
end
each(market, "ShopBackdrop_Back", function(p)
	p.Color = Color3.fromHex("43586B")
end)
each(arm, "RoomCeiling_R22_Light_Glow", function(p)
	p.Transparency = 0.35
end)
for _, l in F.lights:GetDescendants() do
	if l:IsA("PointLight") and (l.Parent :: BasePart).Position.X > 60 and l.Range >= 26 then
		l.Brightness = 1.0
	end
end
for r = 0, 1 do -- exit cue from the Armoury back to the hub
	local g = put("GuideLine", at(AX - 9 - r * 12.5, 2.05, 0, 90), arm)
	tint(g, "_Glow", C.armoury)
end
for _, s in { -1, 1 } do -- Duels ceiling light strips
	local strip = part(duels, "CeilingStrip", Vector3.new(0.5, 0.2, 86), CFrame.new(s * 6, 24.9, -95), Color3.fromHex("FFDDB0"), { material = Enum.Material.Neon, collide = false, shadow = false })
	strip.Transparency = 0.15
end
lamp(F.lights, Vector3.new(0, 4, -134), C.warm, 22, 2.2) -- warm pool at the far door: a destination
for _, w in range.HoloCage:GetChildren() do
	if w.Name == "HoloWall" and w:IsA("BasePart") then
		w.Material = Enum.Material.Glass
		w.Transparency = 0.82
	end
end
local rk = part(F.lights, "RangeKey", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 15, 62), C.warm, { transparency = 1, collide = false })
local rs = Instance.new("SpotLight")
rs.Face = Enum.NormalId.Bottom
rs.Angle = 70
rs.Range = 18
rs.Brightness = 2.6
rs.Color = Color3.fromHex("FFE6C2")
rs.Shadows = false
rs.Parent = rk
for _, s in { -1, 1 } do
	local scr = put("PadScreen", at(s * 23.9, 3.5, 66.2, -90 * s), range, 0.8)
	screen(child(scr, "PadScreen_Face"), if s < 0 then "PRACTICE" else "ALL GUNS", C.range, if s < 0 then { "Lanes 25 to 150", "Dummies and Mods" } else { "Every gun and Mod", "unlocked here" }, "WALK INTO THE GATE")
	local rack = put("WeaponRack", at(s * 23.9, 3.5, 77.5, -90 * s), range)
	local rcf = rack:GetPivot()
	for k, name in { "Display_Operator", "Display_Phantom" } do
		if OLD[name] then
			local g = put(name, rcf * CFrame.new(0, (k - 1) * 2.6 + 1.9, 1.3), range)
			local ss = g:GetExtentsSize()
			g:ScaleTo(4.4 / math.max(ss.X, ss.Z))
		end
	end
end

-- Warm neon reads as saturated yellow on Roblox Neon: practical coves and slots use a soft warm white.
for _, d in hub:GetDescendants() do
	if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Color == Color3.fromHex("FFB45A") then
		d.Color = Color3.fromHex("FFDDB0")
	end
end
-- Decorative motion: art-source/lobby/scripts/AmbienceClient_V2.luau, kept as ServerStorage.LobbyTools.AmbienceClient_V2.
local ambF = Instance.new("Folder")
ambF.Name = "Ambience"
ambF.Parent = root
local tools = ServerStorage:FindFirstChild("LobbyTools")
local src = tools and tools:FindFirstChild("AmbienceClient_V2")
if src and src:IsA("Script") then
	local ac = src:Clone()
	ac.Name = "AmbienceClient"
	ac.Enabled = true
	ac.Parent = ambF
end
local n = #hub:GetDescendants()
return "Bunker2 hub built: " .. n .. " instances"
