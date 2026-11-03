--!strict
-- Match map kit: the shared prelude for every map script in tools/studio/maps/<Map>/
-- (vault/01 Design/Maps/00 Maps.md → How a map is built). bundle.py puts it in front
-- of the map's script bodies; the bundle runs in the Studio Command Bar or through the
-- Studio MCP, in edit mode, in the match place only.
--
-- A map is one Model in Workspace named by its id, which MapService loads by name
-- (it moves it into ServerStorage.Maps at match start):
--   <Map>.Greybox.<Section>   collision Parts (box/wedge/cyl). Never deleted by the art
--                             pass: parts the art replaces are hidden (hide), not removed.
--   <Map>.Art.<Section>       visual kit pieces (MeshParts, no collision), cloned from
--                             ServerStorage.MapKit.<Map> (kit_bundle.py --maps installs it).
--   <Map>.Spawns              SpawnLocations tagged ArenaSpawn_A / ArenaSpawn_B (4 each).
--   <Map>.Barriers            spawn barriers tagged ArenaBarrier (up before the fight).
-- Every map sits at its own world origin (newMap), far from the others, so maps
-- being edited in Workspace never overlap. Coordinates in a map script are map
-- space: studs, origin on the floor at the map centre, +X across, +Z along (team A
-- spawns at -Z, team B at +Z), +Y up.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local MATCH_PLACE_ID = 71551303511506
assert(game.PlaceId == MATCH_PLACE_ID, "Map kit: this is not the match place")

-- One line per published section (the bundle returns it).
local REPORT: { string } = {}

local MAP: Model? = nil
local ORIGIN = CFrame.identity

-- Map space to world.
local function W(cf: CFrame): CFrame
	return ORIGIN * cf
end

local function at(x: number, y: number, z: number, yawDeg: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end

-- Creates (or finds) Workspace.<id> at `origin` with its standard folders. A
-- rebuild keeps the Model (so references survive) and clears what it rebuilds.
local function newMap(id: string, origin: CFrame): Model
	local m = workspace:FindFirstChild(id)
	if not (m and m:IsA("Model")) then
		local made = Instance.new("Model")
		made.Name = id
		made.Parent = workspace
		m = made
	end
	local map = m :: Model
	map.WorldPivot = origin
	for _, name in { "Greybox", "Art", "Spawns", "Barriers" } do
		if not map:FindFirstChild(name) then
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = map
		end
	end
	MAP = map
	ORIGIN = origin
	return map
end

local function root(): Model
	assert(MAP, "call newMap first")
	return MAP
end

-- A standard folder of the map (newMap makes them all).
local function layer(name: string): Instance
	local f = root():FindFirstChild(name)
	assert(f, "no folder " .. name .. " (call newMap first)")
	return f
end

-- A fresh <Map>.<Layer>.<Section> folder (the old one goes).
local function section(layerName: string, name: string): Folder
	local parent = layer(layerName)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

export type Look = { material: Enum.Material?, transparency: number?, castShadow: boolean? }

local function make(
	class: string,
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	look: Look?
): BasePart
	local p = Instance.new(class) :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = W(cf)
	p.Color = color
	p.Material = (look and look.material) or Enum.Material.SmoothPlastic
	p.Transparency = (look and look.transparency) or 0
	p.CastShadow = if look and look.castShadow ~= nil then look.castShadow else true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Collision blocks (greybox). `cf` is the centre, in map space.
local function box(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	look: Look?
): BasePart
	return make("Part", parent, name, size, cf, color, look)
end

-- A ramp: rises toward the part's -Z face (WedgePart's sloped face looks +Z... up),
-- so `cf` should face the way you walk up.
local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	look: Look?
): BasePart
	return make("WedgePart", parent, name, size, cf, color, look)
end

local function cyl(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	look: Look?
): BasePart
	local p = make(
		"Part",
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		look
	) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Decoration only: no collision, no queries (bullets pass), no touch.
local function decor(p: Instance)
	for _, d in (if p:IsA("BasePart") then { p } else p:GetDescendants()) :: { Instance } do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

-- The art replaced this greybox part: invisible, keeps its collision.
local function hide(p: Instance)
	for _, d in (if p:IsA("BasePart") then { p } else p:GetDescendants()) :: { Instance } do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CastShadow = false
		elseif d:IsA("Texture") or d:IsA("Decal") then
			d:Destroy()
		end
	end
end

-- Team "A" (team 1) or "B" (team 2) spawn pad `index` (1-4): an invisible
-- SpawnLocation tagged for MapService, standing on the floor at `cf`.
local function spawnPad(team: string, index: number, cf: CFrame): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = string.format("Spawn_%s%d", team, index)
	s.Anchored = true
	s.Size = Vector3.new(4, 0.2, 4)
	s.CFrame = W(cf * CFrame.new(0, 0.1, 0))
	s.Transparency = 1
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.Neutral = true
	s.Duration = 0
	s.Parent = layer("Spawns")
	CollectionService:AddTag(s, "ArenaSpawn_" .. team)
	return s
end

-- A spawn barrier (up before the fight, MapService.setBarriers).
local function barrier(name: string, size: Vector3, cf: CFrame): BasePart
	local b = make("Part", layer("Barriers"), name, size, cf, Color3.fromRGB(61, 139, 255), {
		transparency = 0.6,
		castShadow = false,
	})
	b:SetAttribute("UpTransparency", 0.6)
	CollectionService:AddTag(b, "ArenaBarrier")
	return b
end

local function spawnsClear()
	layer("Spawns"):ClearAllChildren()
	layer("Barriers"):ClearAllChildren()
end

-- Art: the installed kit piece `piece` of this map (ServerStorage.MapKit.<Map>.<piece>).
local function kit(piece: string): Model?
	local lib = ServerStorage:FindFirstChild("MapKit")
	local group = lib and lib:FindFirstChild(root().Name)
	local m = group and group:FindFirstChild(piece, true)
	return if m and m:IsA("Model") then m else nil
end

-- Places a clone of kit piece `piece` with its pivot (the Blender origin) at `cf`
-- (map space). Returns nil (and notes it) when the kit isn't installed yet.
local missingKit: { [string]: boolean } = {}
local function put(parent: Instance, piece: string, cf: CFrame, name: string?): Model?
	local src = kit(piece)
	if not src then
		missingKit[piece] = true
		return nil
	end
	local m = src:Clone()
	m.Name = name or piece
	m:PivotTo(W(cf))
	decor(m)
	m.Parent = parent
	return m
end

local function report(line: string)
	table.insert(REPORT, line)
	print("[map] " .. line)
end

local function missingReport(): string
	local list = {}
	for k in missingKit do
		table.insert(list, k)
	end
	table.sort(list)
	return if #list > 0
		then "kit pieces not installed: " .. table.concat(list, ", ")
		else "all kit pieces found"
end
