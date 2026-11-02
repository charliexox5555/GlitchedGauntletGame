--!strict
-- Loads a match map: clones the template from ServerStorage.Maps into
-- workspace.ActiveMap. A map still sitting in Workspace (being edited in
-- Studio) moves into ServerStorage.Maps first, for this run only. It finds the
-- map's spawns and barriers by tag: ArenaSpawn_A / ArenaSpawn_B, ArenaBarrier.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local MapService = {}

local BARRIER_TAG = "ArenaBarrier"
local SPAWN_TAGS = { "ArenaSpawn_A", "ArenaSpawn_B" }

local active: Model? = nil

local function mapsFolder(): Folder
	local folder = ServerStorage:FindFirstChild("Maps")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "Maps"
	made.Parent = ServerStorage
	return made
end

local function template(id: string): Model?
	local folder = mapsFolder()
	local stored = folder:FindFirstChild(id)
	if stored and stored:IsA("Model") then
		return stored
	end
	local inWorkspace = workspace:FindFirstChild(id)
	if inWorkspace and inWorkspace:IsA("Model") then
		inWorkspace.Parent = folder
		return inWorkspace
	end
	return nil
end

-- Loads the map (replacing any loaded one) and switches off every spawn that
-- isn't its own. Returns false if the map doesn't exist.
function MapService.load(id: string): boolean
	local source = template(id)
	if not source then
		warn("[MapService] no map named", id)
		return false
	end
	if active then
		active:Destroy()
	end
	local map = source:Clone()
	map.Name = "ActiveMap"
	-- Whole map loaded for everyone, so an enemy never streams out mid-fight.
	map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	map.Parent = workspace
	active = map
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = d:IsDescendantOf(map)
			d.Duration = 0 -- no spawn shield: the barrier protects you until the fight
		end
	end
	return true
end

-- The loaded map's spawns for team 1 or team 2, in a fixed order.
function MapService.spawns(team: number): { SpawnLocation }
	local list: { SpawnLocation } = {}
	local tag = SPAWN_TAGS[team]
	if active and tag then
		for _, s in CollectionService:GetTagged(tag) do
			if s:IsA("SpawnLocation") and s:IsDescendantOf(active) then
				table.insert(list, s)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

-- Up: solid and visible. Down: no collision, no bullets stopped, not seen.
function MapService.setBarriers(up: boolean)
	if not active then
		return
	end
	for _, b in CollectionService:GetTagged(BARRIER_TAG) do
		if b:IsA("BasePart") and b:IsDescendantOf(active) then
			b.CanCollide = up
			b.CanQuery = up
			b.Transparency = if up then (b:GetAttribute("UpTransparency") or 0.6) :: number else 1
			for _, t in b:GetChildren() do
				if t:IsA("Texture") then
					t.Transparency = if up then 0 else 1
				end
			end
		end
	end
end

-- From map space (the map's own pivot) to the world.
function MapService.toWorld(position: Vector3): Vector3?
	if not active then
		return nil
	end
	return active:GetPivot():PointToWorldSpace(position)
end

function MapService.map(): Model?
	return active
end

return MapService
