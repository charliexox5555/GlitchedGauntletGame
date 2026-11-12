--!strict
-- Sunwell Works staging build tool (Edit mode only, run through the Studio MCP).
-- Data and this tool arrive as one model asset (tools/studio/sunwell_p1/upload_data.py):
--   local f = game:GetService("InsertService"):LoadAsset(<SW1_Data id>):FindFirstChild("SW1Data", true)
--   f.Parent = game.ServerStorage
--   local B = require(f.Build:Clone())
--   B.visual("Hall"); B.collision("Hall"); B.lights("Hall"); B.spawn(); B.use("Sunwell")
-- Everything is built under Workspace.SunwellStaging at an offset (attribute Origin), so the live V3 lobby
-- in Workspace.Lobby is never touched. B.use("V3") puts the V3 spawn and lighting back.
-- Visible meshes never collide: players and the camera stop at opaque collider parts hidden inside them.
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local ORIGIN = Vector3.new(1500, 0, 0)
local ROT = CFrame.Angles(0, math.pi, 0)
local STORE = "SW1Data"

local function G(v: { number }): Vector3
	return ORIGIN + Vector3.new(v[1], v[3], -v[2])
end

local function data(name: string): any
	local store = ServerStorage:FindFirstChild(STORE)
	if not store then
		return nil
	end
	local chunks = {}
	while true do
		local v = store:FindFirstChild(name .. "__" .. (#chunks + 1))
		if not v then
			break
		end
		table.insert(chunks, (v :: StringValue).Value)
	end
	return if #chunks > 0 then HttpService:JSONDecode(table.concat(chunks)) else nil
end

local function root(): Folder
	local r = workspace:FindFirstChild("SunwellStaging")
	if not r then
		r = Instance.new("Folder")
		r.Name = "SunwellStaging"
		r.Parent = workspace
	end
	r:SetAttribute("Origin", ORIGIN)
	return r :: Folder
end

local function fresh(parent: Instance, name: string): Folder
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function areaFolder(area: string): Folder
	local r = root()
	local f = r:FindFirstChild(area)
	if not f then
		f = Instance.new("Folder")
		f.Name = area
		f.Parent = r
	end
	return f :: Folder
end

local M = {}
M.ORIGIN = ORIGIN

function M.applyLook(part: MeshPart, p: any, override: any?)
	local look = (override and override[p.mat]) or p.look
	part.Material = (Enum.Material :: any)[look.m]
	part.MaterialVariant = look.v or ""
	part.Color = Color3.fromHex(look.c)
	part.Transparency = look.t or 0
	part.Reflectance = look.r or 0
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = not look.glow and not look.t and (p.ceil == 1 or math.max(p.s[1], p.s[2], p.s[3]) >= 6)
	part:SetAttribute("SWMat", p.mat)
end

function M.visual(area: string): string
	local d = data(area)
	local assets = data("Assets")
	local id = assets["SW1_" .. area]
	assert(id, "no asset id for " .. area)
	local raw = InsertService:LoadAsset(id)
	local meshes: { [string]: MeshPart } = {}
	for _, x in raw:GetDescendants() do
		if x:IsA("MeshPart") then
			meshes[x.Name] = x
		end
	end
	local folder = fresh(areaFolder(area), "Visual")
	local n, missing, worst = 0, {}, 0
	local models: { [string]: Model } = {}
	for _, p in d.parts do
		local src = meshes[p.n]
		if not src then
			table.insert(missing, p.n)
			continue
		end
		local part = src:Clone()
		local want = Vector3.new(p.s[1], p.s[3], p.s[2])
		worst = math.max(worst, (part.Size - want).Magnitude)
		part.Anchored = true
		part.Size = want
		part.PivotOffset = CFrame.new()
		part.CFrame = CFrame.new(G(p.c)) * ROT
		M.applyLook(part, p)
		if p.grp then -- a moving group: one Model, turned by the lobby ambience script (tag LobbySpin)
			local m = models[p.grp]
			if not m then
				m = Instance.new("Model")
				m.Name = p.grp
				m.Parent = folder
				models[p.grp] = m
			end
			part.CastShadow = false
			part.Parent = m
		else
			part.Parent = folder
		end
		n += 1
		if n % 20 == 0 then
			task.wait()
		end
	end
	for name, g in d.groups or {} do -- pivot, speed and axis (Blender coordinates) for each moving group
		local m = models[name]
		if m then
			m.WorldPivot = CFrame.new(G(g.pivot))
			m:SetAttribute("SpinSpeed", g.spin)
			m:SetAttribute("SpinAxis", Vector3.new(g.axis[1], g.axis[3], -g.axis[2]))
			CollectionService:AddTag(m, "LobbySpin")
		end
	end
	raw:Destroy()
	return string.format("%s visual: %d parts, %d missing [%s], worst size delta %.3f", area, n, #missing, table.concat(missing, ","), worst)
end

-- Our own subtle MaterialVariants (tools/textures/make_sunwell_textures.py). Rows: { name, studs per tile, colour, normal,
-- roughness } as decal asset ids; each decal is loaded once to read its image id.
function M.materials(): string
	local MaterialService = game:GetService("MaterialService")
	local function image(id: number): string
		local ok, model = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		if ok and model then
			local d = model:FindFirstChildWhichIsA("Decal", true)
			local tex = d and d.Texture
			model:Destroy()
			if tex and tex ~= "" then
				return tex
			end
		end
		return "rbxassetid://" .. id
	end
	local rows = data("Materials") or {}
	for _, r in rows do
		local mv = MaterialService:FindFirstChild(r[1])
		if not (mv and mv:IsA("MaterialVariant")) then
			mv = Instance.new("MaterialVariant")
			mv.Name = r[1]
			mv.Parent = MaterialService
		end
		local v = mv :: MaterialVariant
		v.BaseMaterial = Enum.Material.SmoothPlastic
		v.StudsPerTile = r[2]
		v.ColorMap = image(r[3])
		v.NormalMap = image(r[4])
		v.RoughnessMap = image(r[5])
		v.MaterialPattern = Enum.MaterialPattern.Regular
	end
	return "materials: " .. #rows
end

-- Re-apply looks without re-importing: looks = { [materialName] = { m, v, c, t?, r?, glow? } }
function M.relook(looks: any, areas: { string }?): string
	local n = 0
	for _, f in root():GetChildren() do
		if areas and not table.find(areas, f.Name) then
			continue
		end
		local d = data(f.Name)
		local vis = f:FindFirstChild("Visual")
		if not (d and vis) then
			continue
		end
		for _, p in d.parts do
			local part = vis:FindFirstChild(p.n)
			if part and looks[p.mat] then
				M.applyLook(part :: MeshPart, p, looks)
				n += 1
			end
		end
	end
	return "relooked " .. n
end

function M.collision(area: string): string
	local folder = fresh(areaFolder(area), "Collision")
	local k, total = 1, 0
	local grey = Color3.fromRGB(70, 70, 74)
	while true do
		local rows = data(area .. "_col" .. k)
		if not rows then
			break
		end
		local chunk = Instance.new("Folder")
		chunk.Name = "c" .. k
		for i, r in rows do
			local part: BasePart = if r[1] == "W" then Instance.new("WedgePart") else Instance.new("Part")
			if r[1] == "C" or r[1] == "X" then
				(part :: Part).Shape = Enum.PartType.Cylinder
			end
			part.Name = "C"
			part.Size = Vector3.new(r[2], r[3], r[4])
			part.CFrame = CFrame.fromMatrix(ORIGIN + Vector3.new(r[5], r[6], r[7]), Vector3.new(r[8], r[9], r[10]), Vector3.new(r[11], r[12], r[13]))
			part.Anchored = true
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.Color = grey
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			if r[1] == "X" or r[1] == "Y" then -- invisible: keep-outs, rails and glass (never walls: the camera ignores them)
				part.Transparency = 1
				part.CanQuery = false
			end
			part.Parent = chunk
			if i % 350 == 0 then
				chunk.Parent = folder
				task.wait()
				chunk = Instance.new("Folder")
				chunk.Name = "c" .. k
			end
		end
		chunk.Parent = folder
		total += #rows
		k += 1
		task.wait()
	end
	return area .. " collision: " .. total .. " parts"
end

function M.lights(area: string, mult: number?): string
	local d = data(area)
	local folder = fresh(areaFolder(area), "Lights")
	for _, l in d.lights do
		local a = Instance.new("Part")
		a.Name = "Light"
		a.Size = Vector3.new(0.4, 0.4, 0.4)
		a.Transparency = 1
		a.Anchored = true
		a.CanCollide = false
		a.CanTouch = false
		a.CanQuery = false
		a.CastShadow = false
		a.CFrame = CFrame.new(G({ l[2], l[3], l[4] }))
		local light: Light
		if l[1] == "S" then
			local s = Instance.new("SpotLight")
			s.Face = Enum.NormalId.Bottom
			s.Angle = l[8]
			s.Range = l[7]
			light = s
		else
			local pl = Instance.new("PointLight")
			pl.Range = l[7]
			light = pl
		end
		light.Color = Color3.fromHex(l[5])
		light.Brightness = l[6] * (mult or 1)
		light.Shadows = false
		light.Parent = a
		CollectionService:AddTag(light, "LobbyLight")
		a.Parent = folder
	end
	return area .. " lights: " .. #d.lights
end

-- The real gun models on display (Locker bays, Shop boards). Parts and looks follow the weapon build data, the same
-- placement rule as tools/studio/rojo/WeaponBuilder.luau; each gun is scaled, turned along its wall and set on its rail.
local GUN_ROT = CFrame.new(0, 0, 0, 0, -1, 0, 0, 0, -1, 1, 0, 0)

function M.guns(): string
	local d = data("Guns")
	local folder = fresh(root(), "Guns")
	local raws: { [string]: { [string]: MeshPart } } = {}
	local placed, missing = 0, 0
	for _, pl in d.place do
		local id = pl[1]
		local g = d.guns[id]
		if not raws[id] then
			local raw = InsertService:LoadAsset(g.assetId)
			local meshes = {}
			for _, x in raw:GetDescendants() do
				if x:IsA("MeshPart") then
					meshes[x.Name] = x
				end
			end
			raws[id] = meshes
		end
		local model = Instance.new("Model")
		model.Name = id
		for _, q in g.parts do
			local src = raws[id][q[1]]
			if not src then
				missing += 1
				continue
			end
			local part = src:Clone()
			part:ClearAllChildren()
			part.Size = Vector3.new(q[7], q[8], q[9])
			part.CFrame = CFrame.new(-q[5], q[6], -q[4]) * GUN_ROT
			part.Material = (Enum.Material :: any)[q[2]]
			part.Color = Color3.fromHex(q[3])
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Parent = model
		end
		model.WorldPivot = CFrame.identity
		model:ScaleTo(pl[2])
		model:PivotTo(CFrame.lookAt(Vector3.zero, Vector3.new(pl[6], 0, -pl[7])))
		local cf, size = model:GetBoundingBox()
		local target = G({ pl[3], pl[4], pl[5] })
		local from = if pl[8] == 1 then cf.Position else cf.Position - Vector3.new(0, size.Y / 2, 0)
		model:PivotTo(model:GetPivot() + (target - from))
		if pl[9] ~= 0 then
			model.WorldPivot = model:GetPivot().Rotation + (cf.Position + (target - from))
			model:SetAttribute("SpinSpeed", pl[9])
			model:SetAttribute("BobAmp", 0.18)
			model:SetAttribute("BobSpeed", 0.22)
			CollectionService:AddTag(model, "LobbySpin")
		end
		model.Parent = folder
		placed += 1
		if placed % 4 == 0 then
			task.wait()
		end
	end
	return string.format("guns: %d placed, %d parts missing", placed, missing)
end

-- Gameplay hooks for the wings: invisible tagged parts, same tags and attributes as the V3 lobby's anchors.
-- Rows: { name, tag, x, y, z, sx, sy, sz, { attributes } } in Blender coordinates.
function M.anchors(): string
	local folder = root():FindFirstChild("Anchors")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Anchors"
		folder.Parent = root()
	end
	for _, c in folder:GetChildren() do
		if not c:IsA("SpawnLocation") then
			c:Destroy()
		end
	end
	local rows = data("Anchors") or {}
	for _, r in rows do
		local p = Instance.new("Part")
		p.Name = r[1]
		p.Size = Vector3.new(r[6], r[8], r[7])
		p.CFrame = CFrame.new(G({ r[3], r[4], r[5] }))
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		for k, v in r[9] do
			p:SetAttribute(k, v)
		end
		CollectionService:AddTag(p, r[2])
		p.Parent = folder
	end
	return "anchors: " .. #rows
end

-- SurfaceGui screens (station boards, Shop boards, the win-streak board). Static layouts for now: the live data
-- comes later from the lobby UI code. Rows: { kind, title, sub, x, y, z, width, height, normal x, normal y }.
local INK = Color3.fromHex("#0C1218")
local PANEL = Color3.fromHex("#151E28")
local CREAM = Color3.fromHex("#EDE2CA")
local MUTED = Color3.fromHex("#8A97A6")
local AMBER = Color3.fromHex("#F0A030")
local TEAM_A = Color3.fromHex("#FF7A3D")
local TEAM_B = Color3.fromHex("#3A94FF")
local PX = 40

local function frame(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, alpha: number?): Frame
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, x: number, y: number, w: number, h: number, size: number, color: Color3, bold: boolean?, align: Enum.TextXAlignment?): TextLabel
	local t = Instance.new("TextLabel")
	t.Position = UDim2.fromOffset(x, y)
	t.Size = UDim2.fromOffset(w, h)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	t.Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamMedium
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.Parent = parent
	return t
end

local function outline(f: GuiObject, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
end

local function teamPanel(bg: Frame, x: number, w: number, h: number, name: string, color: Color3, slots: number, live: boolean)
	local p = frame(bg, x, 62, w, h - 76, PANEL)
	outline(p, if live then color else MUTED, 2)
	frame(p, 0, 0, w, 6, if live then color else MUTED)
	label(p, name, 14, 10, w - 120, 30, 26, if live then color else MUTED, true)
	label(p, "0 / " .. slots, w - 114, 10, 100, 30, 28, CREAM, true, Enum.TextXAlignment.Right)
	local box = math.min(58, (w - 28 - (slots - 1) * 10) / slots)
	local x0 = (w - (slots * box + (slots - 1) * 10)) / 2
	for i = 1, slots do
		local s = frame(p, x0 + (i - 1) * (box + 10), 46, box, box, INK)
		outline(s, if live then color else MUTED, 2)
		label(s, "+", 0, 0, box, box, 26, MUTED, true, Enum.TextXAlignment.Center)
	end
end

function M.screens(): string
	local folder = fresh(root(), "Screens")
	local rows = data("Screens") or {}
	for _, r in rows do
		local kind, title, sub = r[1], r[2], r[3]
		local w, h = r[7], r[8]
		local pos = G({ r[4], r[5], r[6] })
		local part = Instance.new("Part")
		part.Name = "Screen_" .. kind
		part.Size = Vector3.new(w, h, 0.05)
		part.CFrame = CFrame.lookAt(pos, pos + Vector3.new(r[9], 0, -r[10]))
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PX
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.Parent = part
		local W, H = w * PX, h * PX
		local bg = frame(gui, 0, 0, W, H, INK)
		if kind == "queue" or kind == "locked" then
			local live = kind == "queue"
			local n = tonumber(string.sub(title, 1, 1)) or 1
			label(bg, title, 18, 4, 220, 50, 50, if live then CREAM else MUTED, true)
			label(bg, if live then "STATION " .. sub else "LOCKED", W - 340, 6, 320, 46, 28, if live then AMBER else MUTED, true, Enum.TextXAlignment.Right)
			frame(bg, 18, 54, W - 36, 2, if live then AMBER else MUTED)
			local pw = (W - 54) / 2
			teamPanel(bg, 18, pw, H, "TEAM A", TEAM_A, n, live)
			teamPanel(bg, 36 + pw, pw, H, "TEAM B", TEAM_B, n, live)
			label(bg, if live then "STEP ON A PAD TO QUEUE" else "COMING SOON", 0, H - 15, W, 14, 12, MUTED, false, Enum.TextXAlignment.Center)
		elseif kind == "battlepass" then
			label(bg, title, 22, 12, W - 200, 44, 34, CREAM, true)
			label(bg, sub, W - 190, 12, 170, 44, 20, AMBER, true, Enum.TextXAlignment.Right)
			frame(bg, 22, 60, W - 44, 2, AMBER)
			local n = 6
			local tw = (W - 44 - (n - 1) * 10) / n
			for i = 1, n do
				local t = frame(bg, 22 + (i - 1) * (tw + 10), 76, tw, H - 150, PANEL)
				outline(t, if i <= 2 then AMBER else MUTED, 2)
				label(t, tostring(i), 0, 4, tw, 24, 18, if i <= 2 then AMBER else MUTED, true, Enum.TextXAlignment.Center)
			end
			frame(bg, 22, H - 54, W - 44, 12, PANEL)
			frame(bg, 22, H - 54, (W - 44) * 0.3, 12, AMBER)
			label(bg, "TIER 2 / 30", 22, H - 36, W - 44, 24, 18, MUTED, true)
		elseif kind == "event" then
			label(bg, title, 20, 12, W - 40, 44, 34, CREAM, true)
			frame(bg, 20, 60, W - 40, 2, AMBER)
			label(bg, sub, 20, 78, W - 40, 60, 46, AMBER, true)
			label(bg, "16 PLAYERS  ·  ONE GAUNTLET", 20, 142, W - 40, 26, 18, MUTED, true)
			label(bg, "COMING SOON", 20, H - 46, W - 40, 30, 22, CREAM, true)
		else -- streak
			label(bg, title, 22, 10, W - 44, 44, 34, CREAM, true)
			frame(bg, 22, 58, W - 44, 2, AMBER)
			for i = 1, 5 do
				local y = 68 + (i - 1) * ((H - 80) / 5)
				local row = frame(bg, 22, y, W - 44, (H - 80) / 5 - 6, PANEL)
				label(row, tostring(i), 10, 0, 40, row.Size.Y.Offset, 22, AMBER, true)
				label(row, "—", 60, 0, 300, row.Size.Y.Offset, 20, MUTED, true)
				label(row, "0", W - 190, 0, 130, row.Size.Y.Offset, 22, CREAM, true, Enum.TextXAlignment.Right)
			end
		end
		outline(bg, Color3.fromHex("#2A3642"), 3)
		part.Parent = folder
	end
	return "screens: " .. #rows
end

-- Looping 3D sounds (licensed library audio only). Rows: { name, x, y, z, asset id, volume, playback speed, min, max distance }.
function M.sounds(): string
	local folder = fresh(root(), "Sounds")
	local rows = data("Sounds") or {}
	for _, r in rows do
		local p = Instance.new("Part")
		p.Name = r[1]
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(G({ r[2], r[3], r[4] }))
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		local snd = Instance.new("Sound")
		snd.Name = r[1]
		snd.SoundId = "rbxassetid://" .. r[5]
		snd.Volume = r[6]
		snd.PlaybackSpeed = r[7]
		snd.Looped = true
		snd.RollOffMode = Enum.RollOffMode.InverseTapered
		snd.RollOffMinDistance = r[8]
		snd.RollOffMaxDistance = r[9]
		snd.Playing = true
		snd.Parent = p
		p.Parent = folder
	end
	return "sounds: " .. #rows
end

-- The staging spawn on the arrival landing (Blender x, y, z), facing into the hall. Disabled until use("Sunwell").
function M.spawn(x: number?, y: number?, z: number?): string
	local anchors = root():FindFirstChild("Anchors")
	if not anchors then
		anchors = Instance.new("Folder")
		anchors.Name = "Anchors"
		anchors.Parent = root()
	end
	local oldSpawn = anchors:FindFirstChild("LobbySpawn")
	if oldSpawn then
		oldSpawn:Destroy()
	end
	local sp = Instance.new("SpawnLocation")
	sp.Name = "LobbySpawn"
	sp.Anchored = true
	sp.Size = Vector3.new(10, 0.2, 8)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.CanTouch = false
	sp.CanQuery = false
	sp.Neutral = true
	sp.Duration = 0
	sp.Enabled = false
	sp.CFrame = CFrame.new(G({ x or 0, y or -8, (z or 3) + 0.1 }))
	sp.Parent = anchors
	return "staging spawn placed (disabled)"
end

local LIGHTING_PROPS = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "GeographicLatitude", "ExposureCompensation",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ColorShift_Top", "ShadowSoftness" }

-- Lighting for the Sunwell hall: daylight down the skylights, warm-neutral fill.
M.SUNWELL_LIGHTING = {
	Ambient = Color3.fromRGB(80, 78, 76), -- a little lower so the lamps make warm pools (RIVALS reference)
	OutdoorAmbient = Color3.fromRGB(104, 104, 108),
	Brightness = 2.2,
	ClockTime = 12.4,
	GeographicLatitude = 8,
	ExposureCompensation = -0.6,
	EnvironmentDiffuseScale = 0.35,
	EnvironmentSpecularScale = 0.08, -- painted, not glossy (owner 2026-11-12: surfaces read too realistic)
	ColorShift_Top = Color3.fromRGB(255, 244, 226),
	ShadowSoftness = 0.4,
}

-- which = "Sunwell": players spawn on the staging landing and the hall lighting is on.
-- which = "V3": the live V3 spawn and the lighting recorded before the switch come back.
function M.use(which: string): string
	local r = root()
	local staging = r:FindFirstChild("Anchors") and (r :: any).Anchors:FindFirstChild("LobbySpawn")
	local lobby = workspace:FindFirstChild("Lobby")
	local v3: any = nil
	if lobby then
		for _, s in CollectionService:GetTagged("LobbySpawn") do
			if s:IsDescendantOf(lobby) and s:IsA("SpawnLocation") then
				v3 = s
			end
		end
	end
	if which == "Sunwell" then
		if not r:GetAttribute("V3LightingSaved") then
			for _, p in LIGHTING_PROPS do
				r:SetAttribute("V3_" .. p, (Lighting :: any)[p])
			end
			r:SetAttribute("V3LightingSaved", true)
		end
		for p, v in M.SUNWELL_LIGHTING do
			(Lighting :: any)[p] = v
		end
		if v3 then
			v3.Enabled = false
		end
		if staging then
			staging.Enabled = true
		end
		r:SetAttribute("Active", "Sunwell")
		return "Sunwell staging active: staging spawn on, V3 spawn off, hall lighting applied"
	end
	if r:GetAttribute("V3LightingSaved") then
		for _, p in LIGHTING_PROPS do
			(Lighting :: any)[p] = r:GetAttribute("V3_" .. p)
		end
	end
	if v3 then
		v3.Enabled = true
	end
	if staging then
		staging.Enabled = false
	end
	r:SetAttribute("Active", "V3")
	return "V3 active: V3 spawn on, staging spawn off, V3 lighting restored"
end

function M.cleanup(): string
	local store = ServerStorage:FindFirstChild(STORE)
	if store then
		store:Destroy()
	end
	return "build data removed"
end

return M
