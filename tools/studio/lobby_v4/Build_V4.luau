--!strict
-- Lobby V4 staging build tool (Edit mode only, run through the Studio MCP).
-- Data and this tool arrive as one model asset (tools/studio/lobby_v4/upload_data.py):
--   local f = game:GetService("InsertService"):LoadAsset(<V4_Data id>):FindFirstChild("V4Data", true)
--   f.Parent = game.ServerStorage
--   local B = require(f.Build:Clone())
--   B.visual("Hall"); B.collision("Hall"); B.lights("Hall"); B.spawn(); B.use("V4")
-- Everything is built under Workspace.LobbyV4Staging at an offset (attribute Origin), so the live V3 lobby
-- in Workspace.Lobby is never touched. B.use("V3") puts the V3 spawn and lighting back.
-- Visible meshes never collide: players and the camera stop at opaque collider parts hidden inside them.
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local ORIGIN = Vector3.new(-1500, 0, 0)
local ROT = CFrame.Angles(0, math.pi, 0)
local STORE = "V4Data"

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
	local r = workspace:FindFirstChild("LobbyV4Staging")
	if not r then
		r = Instance.new("Folder")
		r.Name = "LobbyV4Staging"
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
	part.CastShadow = not look.glow
		and not look.t
		and (p.ceil == 1 or math.max(p.s[1], p.s[2], p.s[3]) >= 6)
	part:SetAttribute("SWMat", p.mat)
end

local piece: (idx: { [string]: Model }, path: string, home: Instance, parentPath: string?) -> Model

-- Pieces (2026-11-13): every lamp, board, wall bay, pilaster, beam, pad and prop is a Model of its own (attribute
-- PiecePath) holding its meshes, its invisible colliders and its lights, so it can be moved alone in Studio.
-- Identical pieces share one uploaded mesh: the export lists them with a `proto`, and their meshes are cloned here.
local function pieceIndex(): { [string]: Model }
	local idx: { [string]: Model } = {}
	for _, x in root():GetDescendants() do
		if x:IsA("Model") then
			local p = x:GetAttribute("PiecePath")
			if type(p) == "string" then
				idx[p] = x
			end
		end
	end
	return idx
end

local function frameCF(f: { number }): CFrame
	return CFrame.new(
		ORIGIN.X + f[1],
		ORIGIN.Y + f[2],
		ORIGIN.Z + f[3],
		f[4],
		f[5],
		f[6],
		f[7],
		f[8],
		f[9],
		f[10],
		f[11],
		f[12]
	)
end

-- Layout: every piece is a Model you can click and move on its own (Studio selects the outermost Model, so pieces
-- never sit inside another piece's Model). A piece with sub-pieces (a doorway with its lamps and sign) becomes a
-- Folder holding its own Model and the sub-pieces' Models.
local function container(idx: { [string]: Model }, path: string, home: Instance): Instance
	local m = piece(idx, path, home, nil)
	local parent = m.Parent :: Instance
	if parent:IsA("Folder") and parent:GetAttribute("PieceFolder") == path then
		return parent
	end
	local f = Instance.new("Folder")
	f.Name = m.Name
	f:SetAttribute("PieceFolder", path)
	f.Parent = parent
	m.Parent = f
	return f
end

function piece(idx: { [string]: Model }, path: string, home: Instance, parentPath: string?): Model
	local m = idx[path]
	if m then
		return m
	end
	local pp = parentPath or string.match(path, "^(.*)/[^/]+$")
	local parent: Instance = if pp then container(idx, pp, home) else home
	local made = Instance.new("Model")
	made.Name = string.match(path, "([^/]+)$") or path
	made:SetAttribute("PiecePath", path)
	made.Parent = parent
	idx[path] = made
	return made
end

local function depth(p: string): number
	local _, n = string.gsub(p, "/", "")
	return n
end

-- Rebuilds one area's pieces from scratch (meshes only). Run collision(area) and lights() for every area afterwards,
-- or use M.rebuild(), which does all of it in the right order.
function M.visual(area: string): string
	local d = data(area)
	local assets = data("Assets")
	local id = assets["V4_" .. area]
	assert(id, "no asset id for " .. area)
	local raw = InsertService:LoadAsset(id)
	local meshes: { [string]: MeshPart } = {}
	for _, x in raw:GetDescendants() do
		if x:IsA("MeshPart") then
			meshes[x.Name] = x
		end
	end
	local home = fresh(root(), area)
	local idx = pieceIndex()
	local info = d.pieces or {}
	local paths = {}
	for path in info do
		table.insert(paths, path)
	end
	table.sort(paths, function(a, b)
		if depth(a) == depth(b) then
			return a < b
		end
		return depth(a) < depth(b)
	end)
	for _, path in paths do
		piece(idx, path, home, info[path].parent)
	end
	local n, missing, worst, cloned = 0, {}, 0, 0
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
		part.Name = p.mat
		part:SetAttribute("SWName", p.n)
		part:SetAttribute("Ceil", p.ceil == 1)
		part.Parent = if p.g then piece(idx, p.g, home, nil) else home
		n += 1
		if n % 25 == 0 then
			task.wait()
		end
	end
	for _, path in paths do -- identical pieces: clone the prototype's own meshes into place
		local row = info[path]
		local pr = row.proto and info[row.proto]
		local proto = row.proto and idx[row.proto]
		if pr and proto and row.f and pr.f then
			local rel = frameCF(row.f) * frameCF(pr.f):Inverse()
			for _, src in proto:GetChildren() do
				if src:IsA("BasePart") and src:GetAttribute("SWMat") then
					local c = src:Clone()
					c.CFrame = rel * src.CFrame
					c.Parent = idx[path]
					cloned += 1
				end
			end
			idx[path]:SetAttribute("SharedWith", row.proto)
		end
	end
	for _, path in paths do -- pivots: the piece's own frame, else the middle of its footprint
		local m, row = idx[path], info[path]
		if row.anim then
			m.WorldPivot = CFrame.new(G(row.anim.pivot))
			m:SetAttribute("SpinSpeed", row.anim.spin)
			m:SetAttribute(
				"SpinAxis",
				Vector3.new(row.anim.axis[1], row.anim.axis[3], -row.anim.axis[2])
			)
			CollectionService:AddTag(m, "LobbySpin")
			for _, x in m:GetChildren() do
				if x:IsA("BasePart") then
					x.CastShadow = false
				end
			end
		elseif row.f then
			m.WorldPivot = frameCF(row.f)
		elseif #m:GetDescendants() > 0 then
			local cf, size = m:GetBoundingBox() -- own parts only: sub-pieces are siblings, not children
			m.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
		end
	end
	raw:Destroy()
	return string.format(
		"%s: %d pieces, %d meshes + %d shared copies, %d missing [%s], worst size delta %.3f",
		area,
		#paths,
		n,
		cloned,
		#missing,
		table.concat(missing, ","),
		worst
	)
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
		for _, part in f:GetDescendants() do
			local mat = part:GetAttribute("SWMat")
			if part:IsA("MeshPart") and mat and looks[mat] then
				local sz = part.Size
				M.applyLook(
					part,
					{
						mat = mat,
						s = { sz.X, sz.Z, sz.Y },
						ceil = if part:GetAttribute("Ceil") then 1 else 0,
						look = looks[mat],
					},
					looks
				)
				n += 1
			end
		end
	end
	return "relooked " .. n
end

function M.collision(area: string): string
	for _, x in root():GetDescendants() do -- this area's previous colliders, wherever their piece is
		if x:GetAttribute("ColArea") == area then
			x:Destroy()
		end
	end
	local home = areaFolder(area)
	local idx = pieceIndex()
	local folder = home:FindFirstChild("Shell") or Instance.new("Folder") -- colliders that belong to no piece
	folder.Name = "Shell"
	folder.Parent = home
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
			local part: BasePart = if r[1] == "W"
				then Instance.new("WedgePart")
				else Instance.new("Part")
			if r[1] == "C" or r[1] == "X" then
				(part :: Part).Shape = Enum.PartType.Cylinder
			end
			part.Name = "C"
			part.Size = Vector3.new(r[2], r[3], r[4])
			part.CFrame = CFrame.fromMatrix(
				ORIGIN + Vector3.new(r[5], r[6], r[7]),
				Vector3.new(r[8], r[9], r[10]),
				Vector3.new(r[11], r[12], r[13])
			)
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
			part:SetAttribute("ColArea", area)
			local g = r[14]
			part.Parent = if type(g) == "string" and g ~= ""
				then piece(idx, g, home, nil)
				else chunk
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
	for _, x in root():GetDescendants() do
		if x:GetAttribute("LightArea") == area then
			x:Destroy()
		end
	end
	local home = areaFolder(area)
	local idx = pieceIndex()
	local folder = home:FindFirstChild("Lights") or Instance.new("Folder") -- lights that belong to no piece
	folder.Name = "Lights"
	folder.Parent = home
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
		light.Brightness = l[6] * (if l[1] == "P" then (mult or M.POINT_MULT[area] or 1) else 1) -- point fills scaled per area; spots (pools) stay at full
		light.Shadows = false
		light.Parent = a
		CollectionService:AddTag(light, "LobbyLight")
		a:SetAttribute("LightArea", area)
		local g = l[9]
		a.Parent = if type(g) == "string" and g ~= "" then piece(idx, g, home, nil) else folder
	end
	return area .. " lights: " .. #d.lights
end

-- The real gun models on display (Locker bays, Shop boards). Parts and looks follow the weapon build data, the same
-- placement rule as tools/studio/rojo/WeaponBuilder.luau; each gun is scaled, turned along its wall and set on its rail.
local GUN_ROT = CFrame.new(0, 0, 0, 0, -1, 0, 0, 0, -1, 1, 0, 0)

function M.guns(): string
	local d = data("Guns")
	if not d then
		return "guns: none"
	end
	for _, x in root():GetDescendants() do
		if x:GetAttribute("SWGun") then
			x:Destroy()
		end
	end
	local folder = fresh(root(), "Guns")
	local idx = pieceIndex()
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
		model:SetAttribute("SWGun", true)
		model.Parent = if type(pl[10]) == "string"
				and pl[10] ~= ""
				and idx[pl[10]]
			then idx[pl[10]]
			else folder
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
local AMBER = Color3.fromHex("#C5B7D9") -- studio lilac (owner 2026-11-16)
local TEAM_A = Color3.fromHex("#FF7A3D")
local TEAM_B = Color3.fromHex("#3A94FF")
local GOLD = Color3.fromHex("#E5DDEF") -- studio pale lilac replaces gold on screens (owner 2026-11-16)
local TEXT = Color3.fromHex("#F4F6F9")
local PX = 40

local function frame(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	alpha: number?
): Frame
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(
	parent: Instance,
	text: string,
	x: number,
	y: number,
	w: number,
	h: number,
	size: number,
	color: Color3,
	bold: boolean?,
	align: Enum.TextXAlignment?
): TextLabel
	local t = Instance.new("TextLabel")
	t.Position = UDim2.fromOffset(x, y)
	t.Size = UDim2.fromOffset(w, h)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	-- UI theme "Soft Edge": Sarpanch for display and numbers, Titillium Web for labels (gauntlet-ui-style)
	t.FontFace = if bold
		then Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold)
		else Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold)
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.Parent = parent
	return t
end

-- a slanted slash (the theme's brand mark) at x, y
local function slashMark(parent: Instance, x: number, y: number, h: number, color: Color3): Frame
	local f = frame(parent, x, y, math.max(4, math.floor(h * 0.2)), h, color)
	f.Rotation = 18
	return f
end

local function outline(f: GuiObject, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
end

local function teamPanel(
	bg: Frame,
	x: number,
	w: number,
	h: number,
	name: string,
	color: Color3,
	slots: number,
	live: boolean
)
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
	for _, x in root():GetDescendants() do
		if x:GetAttribute("SWScreen") then
			x:Destroy()
		end
	end
	local folder = fresh(root(), "Screens")
	local idx = pieceIndex()
	local rows = data("Screens") or {}
	for _, r in rows do
		local kind, title, sub = r[1], r[2], r[3]
		local w, h = r[7], r[8]
		local pos = G({ r[4], r[5], r[6] })
		local part = Instance.new("Part")
		part.Name = "Screen_" .. kind
		part.Size = Vector3.new(w, h, 0.05)
		local nz = if typeof(r[12]) == "number" then r[12] else 0
		local normal = Vector3.new(r[9], nz, -r[10]).Unit -- Blender (x, y, z) -> Roblox (x, z, -y): tilted screens follow their case
		part.CFrame = CFrame.lookAt(pos, pos + normal, Vector3.yAxis)
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
		if kind == "warning" or kind == "caution" or kind == "notice" then
			-- printed safety plaques (our own words): WARNING red, CAUTION yellow, NOTICE dark with the gold slash
			local base = if kind == "warning"
				then Color3.fromHex("#C3263C")
				elseif kind == "caution" then Color3.fromHex("#F0B414")
				else Color3.fromHex("#1B1D21")
			local ink = if kind == "caution" then Color3.fromHex("#141414") else Color3.fromHex("#F6F4EE")
			bg.BackgroundColor3 = base
			gui.Brightness = 1
			local m = math.floor(math.min(W, H) * 0.06)
			local panel = frame(bg, m, m, W - 2 * m, H - 2 * m, base)
			outline(panel, ink, math.max(2, math.floor(m * 0.45)))
			local band = math.floor((H - 2 * m) * 0.34)
			local head = frame(panel, 0, 0, W - 2 * m, band, if kind == "caution" then Color3.fromHex("#141414") else base)
			if kind == "notice" then
				slashMark(head, 10, math.floor(band * 0.15), math.floor(band * 0.7), GOLD)
			end
			local ttl = label(head, title, m, 0, W - 4 * m, band, math.floor(band * 0.72), if kind == "caution" then Color3.fromHex("#F0B414") else ink, true, Enum.TextXAlignment.Center)
			ttl.TextScaled = true
			if kind == "warning" then
				frame(panel, m, band, W - 4 * m, math.max(2, math.floor(m * 0.4)), ink)
			end
			local lines = string.split(sub, "|")
			local top = band + math.max(4, m)
			local lh = math.floor((H - 2 * m - top - m) / math.max(1, #lines))
			for i, line in lines do
				local t = label(panel, line, m, top + (i - 1) * lh, W - 4 * m, lh, math.floor(lh * 0.7), ink, true, Enum.TextXAlignment.Center)
				t.TextScaled = true
				local c = Instance.new("UITextSizeConstraint")
				c.MaxTextSize = math.floor(lh * 0.72)
				c.Parent = t
			end
		elseif kind == "poster" then
			-- a printed poster (Locker, owner 2026-11-16: more decor): a gold slash, a big title, lines under it
			bg.BackgroundColor3 = Color3.fromHex("#14171B")
			gui.Brightness = 1
			frame(bg, 0, 0, W, math.floor(H * 0.04), GOLD)
			slashMark(bg, math.floor(W * 0.08), math.floor(H * 0.1), math.floor(H * 0.16), GOLD)
			local t = label(bg, title, math.floor(W * 0.08), math.floor(H * 0.3), math.floor(W * 0.84), math.floor(H * 0.28), math.floor(H * 0.12), CREAM, true, Enum.TextXAlignment.Left)
			t.TextScaled = true
			t.TextWrapped = true
			local lines = string.split(sub, "|")
			local lh = math.floor(H * 0.32 / math.max(1, #lines))
			for i, line in lines do
				local l = label(bg, line, math.floor(W * 0.08), math.floor(H * 0.62) + (i - 1) * lh, math.floor(W * 0.84), lh, math.floor(lh * 0.7), GOLD, true, Enum.TextXAlignment.Left)
				l.TextScaled = true
			end
		elseif kind == "lineup" then
			-- the big queue screen behind each pad (owner 2026-11-16: big screens that show the players): mode and
			-- count across the top, then a TEAM A and a TEAM B column with one player card per slot. Static layout;
			-- the lobby UI code fills names and avatars later.
			local n = tonumber(string.sub(title, 1, 1)) or 1
			bg.BackgroundColor3 = Color3.fromHex("#0B0D10")
			local head = math.floor(H * 0.17)
			local t = label(bg, title, 20, 4, math.floor(W * 0.4), head - 8, math.floor(head * 0.8), CREAM, true)
			t.TextScaled = true
			local q = label(bg, sub, math.floor(W * 0.45), 8, math.floor(W * 0.55) - 20, head - 16, math.floor(head * 0.4), GOLD, true, Enum.TextXAlignment.Right)
			q.TextScaled = true
			frame(bg, 20, head, W - 40, 3, GOLD)
			local colW = math.floor((W - 60) / 2)
			local top = head + 14
			local foot = math.floor(H * 0.09)
			local avail = H - top - foot - 10
			for side = 1, 2 do
				local x = 20 + (side - 1) * (colW + 20)
				local col = if side == 1 then TEAM_A else TEAM_B
				local hdr = frame(bg, x, top, colW, math.floor(avail * 0.14), col)
				local ht = label(hdr, if side == 1 then "TEAM A" else "TEAM B", 12, 0, colW - 24, math.floor(avail * 0.14), 22, Color3.fromHex("#0B0D10"), true)
				ht.TextScaled = true
				local cardsTop = top + math.floor(avail * 0.14) + 8
				local rows = math.max(n, 2)
				local slotH = math.floor((avail - math.floor(avail * 0.14) - 8 - (rows - 1) * 8) / rows)
				for i = 1, n do
					local card = frame(bg, x, cardsTop + (i - 1) * (slotH + 8), colW, slotH, PANEL)
					frame(card, 0, 0, 6, slotH, col)
					local av = frame(card, 14, 6, slotH - 12, slotH - 12, Color3.fromHex("#1C2530"))
					outline(av, col, 2)
					label(av, "+", 0, 0, slotH - 12, slotH - 12, math.floor(slotH * 0.5), MUTED, true, Enum.TextXAlignment.Center)
					local nm = label(card, "OPEN SLOT", slotH + 10, 0, colW - slotH - 20, slotH, math.floor(slotH * 0.34), MUTED, true)
					nm.TextScaled = true
					local c = Instance.new("UITextSizeConstraint")
					c.MaxTextSize = math.floor(slotH * 0.36)
					c.Parent = nm
				end
			end
			local f = label(bg, "STAND ON THE PAD TO QUEUE", 0, H - foot, W, foot - 4, math.floor(foot * 0.6), MUTED, true, Enum.TextXAlignment.Center)
			f.TextScaled = true
		elseif kind == "queue" or kind == "locked" then
			local live = kind == "queue"
			local n = tonumber(string.sub(title, 1, 1)) or 1
			label(bg, title, 18, 4, 220, 50, 50, if live then CREAM else MUTED, true)
			label(
				bg,
				if live then "STATION " .. sub else "LOCKED",
				W - 340,
				6,
				320,
				46,
				28,
				if live then AMBER else MUTED,
				true,
				Enum.TextXAlignment.Right
			)
			frame(bg, 18, 54, W - 36, 2, if live then AMBER else MUTED)
			local pw = (W - 54) / 2
			teamPanel(bg, 18, pw, H, "TEAM A", TEAM_A, n, live)
			teamPanel(bg, 36 + pw, pw, H, "TEAM B", TEAM_B, n, live)
			label(
				bg,
				if live then "STEP ON A PAD TO QUEUE" else "COMING SOON",
				0,
				H - 15,
				W,
				14,
				12,
				MUTED,
				false,
				Enum.TextXAlignment.Center
			)
		elseif kind == "battlepass" then
			label(bg, title, 22, 12, W - 200, 44, 34, CREAM, true)
			label(bg, sub, W - 190, 12, 170, 44, 20, AMBER, true, Enum.TextXAlignment.Right)
			frame(bg, 22, 60, W - 44, 2, AMBER)
			local n = 6
			local tw = (W - 44 - (n - 1) * 10) / n
			for i = 1, n do
				local t = frame(bg, 22 + (i - 1) * (tw + 10), 76, tw, H - 150, PANEL)
				outline(t, if i <= 2 then AMBER else MUTED, 2)
				label(
					t,
					tostring(i),
					0,
					4,
					tw,
					24,
					18,
					if i <= 2 then AMBER else MUTED,
					true,
					Enum.TextXAlignment.Center
				)
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
		elseif kind == "leader" then -- weekly leaderboard in the hall (static layout until the lobby UI code feeds it)
			slashMark(bg, 20, 12, 36, GOLD)
			label(bg, title, 38, 6, W - 150, 46, 36, TEXT, true)
			label(bg, sub, W - 140, 12, 122, 34, 17, MUTED, false, Enum.TextXAlignment.Right)
			frame(bg, 18, 54, W - 36, 2, Color3.fromHex("#2A3642"))
			local rows = 5
			local rh = (H - 66) / rows
			for i = 1, rows do
				local y = 58 + (i - 1) * rh
				local row = frame(bg, 18, y, W - 36, rh - 4, PANEL)
				local c = if i == 1 then GOLD else MUTED
				label(row, tostring(i), 8, 0, 24, rh - 4, 22, c, true)
				local av = frame(row, 34, (rh - 4 - (rh - 12)) / 2, rh - 12, rh - 12, INK) -- avatar circle
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = av
				outline(av, c, 1.5)
				label(row, "—", 40 + rh, 0, 140, rh - 4, 18, MUTED, false)
				label(
					row,
					"0 WINS",
					W - 150,
					0,
					106,
					rh - 4,
					17,
					TEXT,
					true,
					Enum.TextXAlignment.Right
				)
			end
		elseif kind == "season" then -- season board in the hall
			slashMark(bg, 22, 16, 56, GOLD)
			label(bg, title, 48, 6, W - 64, 72, 62, TEXT, true)
			frame(bg, 22, 84, W - 44, 2, Color3.fromHex("#2A3642"))
			label(bg, sub, 22, 94, W - 44, 34, 25, CREAM, false)
			label(bg, "GAUNTLET EVENTS  ·  16 PLAYERS", 22, 128, W - 44, 26, 17, MUTED, false)
			local n = 6
			local sw = (W - 44 - (n - 1) * 8) / n
			for i = 1, n do
				local seg = frame(
					bg,
					22 + (i - 1) * (sw + 8),
					H - 44,
					sw,
					8,
					if i == 1 then GOLD else PANEL
				)
				outline(seg, if i == 1 then GOLD else Color3.fromHex("#2A3642"), 1)
			end
			label(bg, "COMING SOON", 22, H - 34, W - 44, 28, 20, TEXT, true)
		else -- streak
			label(bg, title, 22, 10, W - 44, 44, 34, CREAM, true)
			frame(bg, 22, 58, W - 44, 2, AMBER)
			for i = 1, 5 do
				local y = 68 + (i - 1) * ((H - 80) / 5)
				local row = frame(bg, 22, y, W - 44, (H - 80) / 5 - 6, PANEL)
				label(row, tostring(i), 10, 0, 40, row.Size.Y.Offset, 22, AMBER, true)
				label(row, "—", 60, 0, 300, row.Size.Y.Offset, 20, MUTED, true)
				label(
					row,
					"0",
					W - 190,
					0,
					130,
					row.Size.Y.Offset,
					22,
					CREAM,
					true,
					Enum.TextXAlignment.Right
				)
			end
		end
		outline(bg, Color3.fromHex("#2A3642"), 3)
		part:SetAttribute("SWScreen", true)
		part.Parent = if type(r[11]) == "string"
				and r[11] ~= ""
				and idx[r[11]]
			then idx[r[11]]
			else folder
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

-- The staging spawn on the arrival landing (Blender x, y, z), facing into the hall. Disabled until use("V4").
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


-- NPCs (owner 2026-11-16: "an NPC in there that looks good", like RIVALS' vendors). Anchors tagged LobbyNPCSpot
-- (Yaw = degrees from Blender +Y, counter-clockwise; Look = uniform; Title = name tag) become real R15 rigs in a
-- uniform with a little gear and a name tag, the root anchored, tagged LobbyNPC (the client plays an idle).
local NPC_LOOKS: { [string]: { [string]: string } } = {
	armorer = {
		skin = "#B98364",
		torso = "#34383C",
		arms = "#34383C",
		legs = "#26292D",
		vest = "#3D4347",
		strap = "#8E6CFF",
		cap = "#26292D",
	},
	broker = { -- the Shop's big NPC (owner 2026-11-16: a larger character like RIVALS' vendor)
		skin = "#C08A66",
		torso = "#2A1F45",
		arms = "#2A1F45",
		legs = "#1E1A2B",
		vest = "#401C99",
		strap = "#C5B7D9",
		cap = "#1E1A2B",
	},
	shopkeeper = {
		skin = "#8D5B43",
		torso = "#41454A",
		arms = "#41454A",
		legs = "#2E3135",
		vest = "#B8406A",
		strap = "#E0A830",
		cap = "#2E3135",
	},
}

local function gear(parent: Model, attach: BasePart, name: string, size: Vector3, offset: CFrame, color: string)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = attach.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = attach
	w.Part1 = p
	w.Parent = p
	p.Parent = parent
end

local function nameTag(head: BasePart, title: string, accentHex: string)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromScale(5.5, 1.3)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 70
	tag.LightInfluence = 0
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromHex("#14171B")
	bar.BackgroundTransparency = 0.15
	bar.BorderSizePixel = 0
	bar.Parent = tag
	local accent = Instance.new("Frame")
	accent.Size = UDim2.fromScale(1, 0.1)
	accent.Position = UDim2.fromScale(0, 0.9)
	accent.BackgroundColor3 = Color3.fromHex(accentHex)
	accent.BorderSizePixel = 0
	accent.Parent = bar
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.86)
	t.BackgroundTransparency = 1
	t.Text = title
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromHex("#F4F1EA")
	t.Parent = bar
	tag.Adornee = head
	tag.Parent = head
end

function M.npcs(): string
	local folder = fresh(root(), "NPCs")
	local n = 0
	for _, spot in CollectionService:GetTagged("LobbyNPCSpot") do
		if not spot:IsDescendantOf(root()) or not spot:IsA("BasePart") then
			continue
		end
		local lookName = spot:GetAttribute("Look")
		local look = NPC_LOOKS[if typeof(lookName) == "string" then lookName else "armorer"] or NPC_LOOKS.armorer
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = Color3.fromHex(look.skin)
		d.TorsoColor = Color3.fromHex(look.torso)
		d.LeftArmColor = Color3.fromHex(look.arms)
		d.RightArmColor = Color3.fromHex(look.arms)
		d.LeftLegColor = Color3.fromHex(look.legs)
		d.RightLegColor = Color3.fromHex(look.legs)
		local ok, rig = pcall(function()
			return game:GetService("Players"):CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
		end)
		if not ok or not rig then
			continue
		end
		local model = rig :: Model
		model.Name = spot.Name
		local scaleAttr = spot:GetAttribute("Scale")
		if typeof(scaleAttr) == "number" and scaleAttr > 0 and scaleAttr ~= 1 then
			model:ScaleTo(scaleAttr)
		end
		local hum = model:FindFirstChildWhichIsA("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		local yawAttr = spot:GetAttribute("Yaw")
		local yaw = math.rad(if typeof(yawAttr) == "number" then yawAttr else 0)
		local dir = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)) -- Blender (-sin, cos) -> Roblox (x, -y)
		local feet = spot.Position -- the anchor sits at the feet (Blender z = floor)
		model:PivotTo(CFrame.lookAt(feet, feet + dir))
		local cf, size = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() + Vector3.new(0, feet.Y - (cf.Position.Y - size.Y / 2), 0))
		for _, x in model:GetDescendants() do
			if x:IsA("BasePart") then
				x.CanQuery = false
				x.CanTouch = false
			end
		end
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			hrp.Anchored = true
		end
		local torso = model:FindFirstChild("UpperTorso")
		if torso and torso:IsA("BasePart") then
			gear(model, torso, "Vest", torso.Size * Vector3.new(1.08, 0.86, 1.18), CFrame.new(0, -0.05, 0), look.vest)
			gear(
				model,
				torso,
				"Strap",
				Vector3.new(0.35, torso.Size.Y * 1.02, torso.Size.Z * 1.24),
				CFrame.new(torso.Size.X * 0.22, 0, 0) * CFrame.Angles(0, 0, math.rad(-28)),
				look.strap
			)
		end
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			gear(model, head, "Cap", Vector3.new(head.Size.X * 1.08, head.Size.Y * 0.32, head.Size.Z * 1.08), CFrame.new(0, head.Size.Y * 0.42, 0), look.cap)
			gear(model, head, "Brim", Vector3.new(head.Size.X * 0.9, 0.12, head.Size.Z * 0.55), CFrame.new(0, head.Size.Y * 0.3, -head.Size.Z * 0.62), look.cap)
			local title = spot:GetAttribute("Title")
			nameTag(head, if typeof(title) == "string" then title else "NPC", look.strap)
		end
		-- Talk: the lines the client's NpcTalk opens for this NPC (lobby/shared/NpcTalk); Title: the name it shows
		local talk = spot:GetAttribute("Talk")
		if typeof(talk) == "string" and talk ~= "" then
			model:SetAttribute("Talk", talk)
			model:SetAttribute("Title", spot:GetAttribute("Title"))
		end
		CollectionService:AddTag(model, "LobbyNPC")
		model.Parent = folder
		n += 1
	end
	return "npcs: " .. n
end

-- Visual effects (owner 2026-11-16: "add visual effects", like RIVALS' pickups and stages). Anchors tagged LobbyFX:
-- Kind sparkle | embers | dust (ParticleEmitters in a box the size of Spread) or cone (a soft Beam light cone from
-- the anchor to To). Built-in Roblox textures only.
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function num(inst: Instance, key: string, default: number): number
	local v = inst:GetAttribute(key)
	return if typeof(v) == "number" then v else default
end

function M.fx(): string
	local n = 0
	for _, a in CollectionService:GetTagged("LobbyFX") do
		if not a:IsDescendantOf(root()) or not a:IsA("BasePart") then
			continue
		end
		for _, c in a:GetChildren() do
			c:Destroy()
		end
		local kind = a:GetAttribute("Kind")
		local hex = a:GetAttribute("Color")
		local color = Color3.fromHex(if typeof(hex) == "string" then hex else "#FFC83D")
		local spread = num(a, "Spread", 1.5)
		if kind == "cone" then
			local toAttr = a:GetAttribute("To")
			local to = string.split(if typeof(toAttr) == "string" then toAttr else "0,0,0", ",")
			local target = G({ tonumber(to[1]) or 0, tonumber(to[2]) or 0, tonumber(to[3]) or 0 })
			local a0 = Instance.new("Attachment")
			a0.Parent = a
			local a1 = Instance.new("Attachment")
			a1.Parent = a
			a1.WorldPosition = target
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Width0 = num(a, "W0", 1)
			b.Width1 = num(a, "W1", 5)
			b.FaceCamera = true
			b.Segments = 1
			b.Texture = SMOKE
			b.TextureMode = Enum.TextureMode.Stretch
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Color = ColorSequence.new(color)
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.74),
				NumberSequenceKeypoint.new(0.7, 0.84),
				NumberSequenceKeypoint.new(1, 1),
			})
			b.Parent = a
		else
			a.Size = Vector3.new(spread * 2, if kind == "dust" then spread else 0.5, spread * 2)
			local e = Instance.new("ParticleEmitter")
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.Texture = SPARKLE
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Color = ColorSequence.new(color)
			e.Rate = num(a, "Rate", 5)
			if kind == "embers" then
				e.Lifetime = NumberRange.new(1.2, 2.2)
				e.Speed = NumberRange.new(1.5, 3.5)
				e.Acceleration = Vector3.new(0, 1.2, 0)
				e.SpreadAngle = Vector2.new(25, 25)
				e.EmissionDirection = Enum.NormalId.Top
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			elseif kind == "dust" then
				e.Lifetime = NumberRange.new(6, 10)
				e.Speed = NumberRange.new(0.1, 0.3)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Rate = 3
				e.Size = NumberSequence.new(0.14)
				e.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, 0.55),
					NumberSequenceKeypoint.new(1, 1),
				})
			else -- sparkle
				e.Lifetime = NumberRange.new(0.8, 1.6)
				e.Speed = NumberRange.new(0.3, 1.2)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Rotation = NumberRange.new(0, 360)
				e.RotSpeed = NumberRange.new(-90, 90)
				e.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.3, 0.45),
					NumberSequenceKeypoint.new(1, 0),
				})
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.6) })
			end
			e.Parent = a
		end
		n += 1
	end
	return "fx: " .. n
end


-- Props (owner 2026-11-16): the owner's RivalsProps templates stand in for our crates and cases until our own props are
-- made. The templates live in ServerStorage.RivalsPropTemplates (moved there from Workspace.RivalsProps the first time,
-- so nothing floats in the world); each LobbyPropSpot anchor (Kind = template name, Yaw = degrees from Blender +X,
-- counter-clockwise) gets a copy, bottom on the floor, in LobbyV4Staging["Rivals Props"]. Placeholders only: they are
-- RIVALS' meshes and must be replaced before publishing.
local PROP_LAY = { ["Ski Crate"] = true } -- templates that stand on end in RivalsProps but lie flat in the lobby

function M.props(): string
	local templates = ServerStorage:FindFirstChild("RivalsPropTemplates")
	if not templates then
		local src = workspace:FindFirstChild("RivalsProps")
		if not src then
			return "props: no templates (Workspace.RivalsProps or ServerStorage.RivalsPropTemplates)"
		end
		src.Name = "RivalsPropTemplates"
		src.Parent = ServerStorage
		templates = src
	end
	local folder = fresh(root(), "Rivals Props")
	local n, missing = 0, {}
	for _, spot in CollectionService:GetTagged("LobbyPropSpot") do
		if not spot:IsDescendantOf(root()) or not spot:IsA("BasePart") then
			continue
		end
		local kind = spot:GetAttribute("Kind")
		local tpl = if typeof(kind) == "string" then (templates :: Instance):FindFirstChild(kind) else nil
		if not tpl then
			table.insert(missing, tostring(kind))
			continue
		end
		local copy = tpl:Clone()
		for _, d in copy:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		if copy:IsA("BasePart") then
			copy.Anchored = true
		end
		local yawAttr = spot:GetAttribute("Yaw")
		local yaw = math.rad(if typeof(yawAttr) == "number" then yawAttr else 0)
		if not (copy:IsA("Model") or copy:IsA("BasePart")) then
			copy:Destroy()
			continue
		end
		-- keep the template's world orientation (the owner placed them upright), pivot at the bottom centre of its world
		-- box, then turn it by the spot's yaw (Blender yaw about +Z is Roblox yaw about +Y) and sit it on the spot
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		local parts: { BasePart } = if copy:IsA("BasePart") then { copy } else {}
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		for _, p in parts do
			local h = p.Size / 2
			for _, c in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local w = p.CFrame:PointToWorldSpace(h * c)
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
		if #parts == 0 then
			copy:Destroy()
			continue
		end
		local base = CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
		if PROP_LAY[tpl.Name] and copy:IsA("Model") then
			-- stood upright in the owner's folder; lay it down: shortest box axis up, longest along the spot's X
			local bcf, bsize = copy:GetBoundingBox()
			local axes = { { bcf.RightVector, bsize.X }, { bcf.UpVector, bsize.Y }, { bcf.LookVector, bsize.Z } }
			table.sort(axes, function(a, b)
				return a[2] < b[2]
			end)
			local up, long = axes[1][1], axes[3][1]
			base = CFrame.fromMatrix(bcf.Position - up * axes[1][2] / 2, long, up)
		end
		local target = CFrame.new(spot.Position) * CFrame.Angles(0, yaw, 0)
		if copy:IsA("Model") then
			copy.WorldPivot = base
			copy:PivotTo(target)
		else
			local bp = copy :: BasePart
			bp.CFrame = target * base:ToObjectSpace(bp.CFrame)
		end
		copy.Name = tpl.Name
		copy.Parent = folder
		n += 1
	end
	return "props: " .. n .. (if #missing > 0 then " (no template: " .. table.concat(missing, ", ") .. ")" else "")
end

local LIGHTING_PROPS = {
	"Ambient",
	"OutdoorAmbient",
	"Brightness",
	"ClockTime",
	"GeographicLatitude",
	"ExposureCompensation",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ColorShift_Top",
	"ShadowSoftness",
}

-- Lighting for Lobby V4 ("Gauntlet Bunker", the RIVALS feel): a dark interior lit by white bar lamps and pools, daylight
-- down the lantern over the spawn. Tuned from Studio captures.
M.V4_LIGHTING = {
	-- round 3 (2026-11-16): RIVALS runs full environment light on mid-grey shells; ours: env diffuse for the form
	-- gradients, ambient below outdoor (LihFolk: Lighting Technologies and Settings), a neutral grade against sky blue
	Ambient = Color3.fromRGB(74, 74, 78), -- owner 2026-11-16: some parts too dark; a step up from round 4
	OutdoorAmbient = Color3.fromRGB(112, 112, 116),
	Brightness = 3,
	ClockTime = 12.3,
	GeographicLatitude = 4,
	ExposureCompensation = 0.1,
	EnvironmentDiffuseScale = 0.55,
	EnvironmentSpecularScale = 0.25,
	ColorShift_Top = Color3.fromRGB(255, 253, 248),
	ShadowSoftness = 0.6,
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
	if which == "V4" then
		if not r:GetAttribute("V3LightingSaved") then
			for _, p in LIGHTING_PROPS do
				r:SetAttribute("V3_" .. p, (Lighting :: any)[p])
			end
			r:SetAttribute("V3LightingSaved", true)
		end
		for p, v in M.V4_LIGHTING do
			(Lighting :: any)[p] = v
		end
		-- a neutral grade with a little more contrast (hub upgrade); switched off again by use("V3")
		local cc = Lighting:FindFirstChild("HubGrade") :: ColorCorrectionEffect?
		if not cc then
			local n = Instance.new("ColorCorrectionEffect")
			n.Name = "HubGrade"
			n.Contrast = 0.14
			n.Saturation = 0.02
			n.TintColor = Color3.fromRGB(255, 255, 255)
			n.Parent = Lighting
			cc = n
		end
		-- clearer air indoors (the default haze read as a muddy vignette in the wings); bloom only on real highlights
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm then
			if r:GetAttribute("V3_AtmHaze") == nil then
				r:SetAttribute("V3_AtmHaze", atm.Haze)
				r:SetAttribute("V3_AtmDensity", atm.Density)
				r:SetAttribute("V3_AtmOffset", atm.Offset)
			end
			atm.Haze, atm.Density, atm.Offset = 0.6, 0.25, 0.15 -- a light distance fade down the Duels hall
		end
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		if bloom then
			if r:GetAttribute("V3_Bloom") == nil then
				r:SetAttribute(
					"V3_Bloom",
					Vector3.new(bloom.Intensity, bloom.Size, bloom.Threshold)
				)
			end
			bloom.Intensity, bloom.Size, bloom.Threshold = 0.6, 24, 1.4
		end
		local grade = cc :: ColorCorrectionEffect
		grade.Contrast, grade.Saturation, grade.TintColor =
			0.12, -0.12, Color3.fromRGB(255, 251, 245) -- neutral: takes the sky's blue out of the env light
		grade.Enabled = true
		if v3 then
			v3.Enabled = false
		end
		if staging then
			staging.Enabled = true
		end
		r:SetAttribute("Active", "V4")
		local sw = workspace:FindFirstChild("SunwellStaging")
		local swSpawn = sw and sw:FindFirstChild("Anchors") and (sw :: any).Anchors:FindFirstChild("LobbySpawn")
		if swSpawn then
			swSpawn.Enabled = false
		end
		return "V4 staging active: V4 spawn on, V3 and Sunwell spawns off, V4 lighting applied"
	end
	local grade = Lighting:FindFirstChild("HubGrade") :: ColorCorrectionEffect?
	if grade and which ~= "V4" then
		grade.Enabled = false
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and which ~= "V4" and r:GetAttribute("V3_AtmHaze") ~= nil then
		atm.Haze, atm.Density, atm.Offset =
			r:GetAttribute("V3_AtmHaze"),
			r:GetAttribute("V3_AtmDensity"),
			r:GetAttribute("V3_AtmOffset")
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local bv = r:GetAttribute("V3_Bloom")
	if bloom and which ~= "V4" and typeof(bv) == "Vector3" then
		bloom.Intensity, bloom.Size, bloom.Threshold = bv.X, bv.Y, bv.Z
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

-- Everything, in the order pieces need: all meshes first (lights and colliders may belong to a piece in another
-- area's data, e.g. the doorway lamps' lights are recorded with the hall), then colliders, lights, screens, guns.
M.AREAS = { "Concourse", "Duels", "Locker", "Shop" }
-- point-light scale per area (2026-11-13: the point fills pushed the light walls past white; spots make the pools)
M.POINT_MULT = { Concourse = 1, Duels = 1, Locker = 1, Shop = 1, Range = 1 }
function M.rebuild(): string
	local out = {}
	for _, a in M.AREAS do
		table.insert(out, M.visual(a))
		task.wait()
	end
	for _, a in M.AREAS do
		table.insert(out, M.collision(a))
	end
	for _, a in M.AREAS do
		local d = data(a)
		if d and d.lights and #d.lights > 0 then
			table.insert(out, M.lights(a))
		end
	end
	table.insert(out, M.screens())
	table.insert(out, M.guns())
	table.insert(out, M.anchors())
	table.insert(out, M.npcs())
	table.insert(out, M.props())
	table.insert(out, M.fx())
	table.insert(out, M.sounds())
	return table.concat(out, "\n")
end

function M.cleanup(): string
	local store = ServerStorage:FindFirstChild(STORE)
	if store then
		store:Destroy()
	end
	return "build data removed"
end

return M
