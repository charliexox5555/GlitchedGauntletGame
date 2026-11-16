--!strict
-- Lobby V3 build tool (Edit mode only, run through the Studio MCP).
-- Data and this tool arrive as one model asset (tools/studio/lobby_v3/upload_data.py):
--   local f = game:GetService("InsertService"):LoadAsset(<V3_Data id>):FindFirstChild("V3Data", true)
--   f.Parent = game.ServerStorage
--   local B = require(f.Build:Clone())
--   B.archive(); B.visual("Hub"); B.collision("Hub"); B.lights("Hub"); ... ; B.cleanup()
-- Visible meshes never collide. Players and the camera stop at opaque collider parts that sit 0.04 studs
-- inside the visible solids (the default camera ignores invisible or non-colliding parts).
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local ASSETS: { [string]: number } = {
	Hub = 78785650590802,
	Duels = 72542414741450,
	Market = 125117584621870,
	Vault = 72428789126155,
	Range = 112402207067679,
}
local ROT = CFrame.Angles(0, math.pi, 0)

local function G(v: { number }): Vector3
	return Vector3.new(v[1], v[3], -v[2])
end

local function data(name: string): any
	local store = ServerStorage:FindFirstChild("V3Data")
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

local function hub(): Folder
	local lobby = workspace:FindFirstChild("Lobby")
	assert(lobby, "Workspace.Lobby is missing")
	local h = lobby:FindFirstChild("Hub")
	if not h then
		h = Instance.new("Folder")
		h.Name = "Hub"
		h:SetAttribute("V3", true)
		h.Parent = lobby
	end
	assert(h:GetAttribute("V3"), "Workspace.Lobby.Hub is the old lobby: run archive() first")
	return h :: Folder
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
	local h = hub()
	local f = h:FindFirstChild(area)
	if not f then
		f = Instance.new("Folder")
		f.Name = area
		f.Parent = h
	end
	return f :: Folder
end

local M = {}

-- Move the old lobby out of the Workspace (kept whole in ServerStorage.Archive).
function M.archive(): string
	local lobby = workspace:FindFirstChild("Lobby")
	assert(lobby, "Workspace.Lobby is missing")
	local old = lobby:FindFirstChild("Hub")
	if not old or old:GetAttribute("V3") then
		return "nothing to archive"
	end
	local arch = ServerStorage:FindFirstChild("Archive") or Instance.new("Folder")
	arch.Name = "Archive"
	arch.Parent = ServerStorage
	old.Name = "Hub_Bunker2_preV3"
	old.Parent = arch
	return "archived old hub: " .. #old:GetDescendants() .. " instances"
end

function M.applyLook(part: MeshPart, p: any, override: any?)
	local look = (override and override[p.mat]) or p.look
	part.Material = (Enum.Material :: any)[look.m]
	part.MaterialVariant = look.v or ""
	part.Color = Color3.fromHex(look.c)
	part.Transparency = look.t or 0
	part.Reflectance = look.r or 0
	part.CanCollide = look.collide == true
	part.CanQuery = look.collide == true
	part.CanTouch = false
	part.CastShadow = not look.glow and math.max(p.s[1], p.s[2], p.s[3]) >= 6
	part:SetAttribute("V3Mat", p.mat)
	if look.pulse then
		CollectionService:AddTag(part, "LobbyPulse")
	end
end

function M.visual(area: string): string
	local d = data(area)
	local raw = InsertService:LoadAsset(ASSETS[area])
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
		part.CFrame = CFrame.new(G(p.c)) * ROT
		M.applyLook(part, p)
		if p.grp then -- moving group: one Model, turned by the existing ambience script (tag LobbySpin)
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
	end
	for name, g in d.groups or {} do
		local m = models[name]
		if m then
			m.WorldPivot = CFrame.new(G(g.pivot))
			m:SetAttribute("SpinSpeed", g.spin)
			if g.bob then
				m:SetAttribute("BobAmp", g.bob[1])
				m:SetAttribute("BobSpeed", g.bob[2])
			end
			CollectionService:AddTag(m, "LobbySpin")
		end
	end
	raw:Destroy()
	return string.format(
		"%s visual: %d parts, %d missing [%s], worst size delta %.3f",
		area,
		n,
		#missing,
		table.concat(missing, ","),
		worst
	)
end

-- Re-apply looks without re-importing: looks = { [myMaterialName] = { m, v, c, t?, r?, glow?, collide? } }
function M.relook(looks: any): string
	local n = 0
	for _, area in { "Hub", "Duels", "Market", "Vault", "Range" } do
		local d = data(area)
		local f = hub():FindFirstChild(area)
		local vis = f and f:FindFirstChild("Visual")
		if not (d and vis) then
			continue
		end
		for _, p in d.parts do
			local part = vis:FindFirstChild(p.n, true)
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
			local part: BasePart = if r[1] == "W"
				then Instance.new("WedgePart")
				else Instance.new("Part")
			if r[1] == "C" or r[1] == "X" then
				(part :: Part).Shape = Enum.PartType.Cylinder
			end
			part.Name = "C"
			part.Size = Vector3.new(r[2], r[3], r[4])
			part.CFrame = CFrame.fromMatrix(
				Vector3.new(r[5], r[6], r[7]),
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
			if r[1] == "X" or r[1] == "Y" then -- invisible: keep-outs and glass (never walls: the camera ignores invisible parts)
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

function M.lights(area: string): string
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
		a.CFrame = CFrame.new(l[2], l[4], -l[3])
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
		light.Brightness = l[6]
		light.Shadows = false
		light.Parent = a
		CollectionService:AddTag(light, "LobbyLight")
		a.Parent = folder
	end
	return area .. " lights: " .. #d.lights
end

-- The real gun models on the Locker displays. Parts and looks follow the weapon build data (same placement rule as
-- tools/studio/rojo/WeaponBuilder.luau); each gun is scaled, turned along the wall and set down on its rail.
local GUN_ROT = CFrame.new(0, 0, 0, 0, -1, 0, 0, 0, -1, 1, 0, 0)

function M.guns(): string
	local d = data("Guns")
	local folder = fresh(areaFolder("Vault"), "Guns")
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
		local target = Vector3.new(pl[3], pl[5], -pl[4])
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

-- Soft particle effects listed in an area's data: [x, y, z, sx, sy, sz, colour, rate] in Blender coordinates.
function M.fx(area: string): string
	local d = data(area)
	local folder = fresh(areaFolder(area), "FX")
	for _, f in d.fx or {} do
		local a = Instance.new("Part")
		a.Name = "Motes"
		a.Size = Vector3.new(f[4], f[5], f[6])
		a.CFrame = CFrame.new(f[1], f[3], -f[2])
		a.Transparency = 1
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.CastShadow = false
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromHex(f[7]))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Rate = f[8]
		e.Lifetime = NumberRange.new(2.4, 3.6)
		e.Speed = NumberRange.new(1.0, 1.8)
		e.SpreadAngle = Vector2.new(4, 4)
		e.EmissionDirection = Enum.NormalId.Top
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.16),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Parent = a
		a.Parent = folder
	end
	return area .. " fx: " .. #(d.fx or {})
end

-- Remove the build data from the place when the build is done.
function M.cleanup(): string
	local store = ServerStorage:FindFirstChild("V3Data")
	if store then
		store:Destroy()
	end
	return "build data removed"
end

return M
